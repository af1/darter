local LrApplication       = import 'LrApplication'
local LrDevelopController = import 'LrDevelopController'
local LrPathUtils         = import 'LrPathUtils'
local LrFileUtils         = import 'LrFileUtils'
local Log                 = require 'Logger'

-- Shared file the Mac app reads to populate its preset pickers. Written to
-- the same Application Support dir the Mac app keeps its own config in, so
-- both sides agree on the location. TSV (folder<TAB>name per line) rather
-- than JSON to avoid hand-rolling JSON string escaping in Lua -- preset and
-- folder names won't contain tabs or newlines.
local function presetsFilePath()
    local dir = LrPathUtils.getStandardFilePath('home')
    dir = LrPathUtils.child(dir, "Library")
    dir = LrPathUtils.child(dir, "Application Support")
    dir = LrPathUtils.child(dir, "Darter")
    LrFileUtils.createAllDirectories(dir)
    return LrPathUtils.child(dir, "presets.tsv")
end

-- Enumerate every Develop preset in every folder and write the list out for
-- the Mac app, via the standard SDK walk:
-- LrApplication.developPresetFolders -> folder:getDevelopPresets -> preset:getName.
-- Tabs and newlines are the TSV framing characters; a preset or folder name
-- containing one would corrupt the file, so squash any control character to
-- a space at export time. (applyPreset still matches: it compares against
-- live getName() values, and the Mac app sends back what we exported, so
-- sanitize consistently in both places.)
local function sanitizeName(s)
    return (s:gsub("%c", " "))
end

local function listPresets()
    local lines = {}
    for _, folder in ipairs(LrApplication.developPresetFolders()) do
        local folderName = sanitizeName(folder:getName())
        for _, preset in ipairs(folder:getDevelopPresets()) do
            lines[#lines + 1] = folderName .. "\t" .. sanitizeName(preset:getName())
        end
    end

    local path = presetsFilePath()
    local file = io.open(path, "w")
    if file == nil then
        Log:warnf("Could not open presets file for writing: %s", path)
        return
    end
    file:write(table.concat(lines, "\n"))
    file:write("\n")
    file:close()
    Log:tracef("Wrote %d presets to %s", #lines, path)
end

-- Apply a preset identified by folder name + preset name to the current
-- photo. Folder is part of the identity because the same preset name can
-- exist in two different folders.
local function applyPreset(folderName, presetName)
    local target = nil
    for _, folder in ipairs(LrApplication.developPresetFolders()) do
        if sanitizeName(folder:getName()) == folderName then
            for _, preset in ipairs(folder:getDevelopPresets()) do
                if sanitizeName(preset:getName()) == presetName then
                    target = preset
                    break
                end
            end
        end
        if target ~= nil then break end
    end

    if target == nil then
        Log:warnf("Preset not found: %s / %s", tostring(folderName), tostring(presetName))
        return
    end

    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()
    if photo == nil then
        Log:trace("applyPreset: no target photo")
        return
    end

    -- Settle any in-flight live slider adjustment first. Slider nudges go
    -- through LrDevelopController (the live Develop view's own state), while
    -- a preset writes to the catalog -- two layers that desync if the live
    -- one is mid-edit. Committing the live state via stopTracking means the
    -- preset applies over a clean, in-sync state, so it reliably shows on
    -- the first press instead of after a few. (pcall-safe: stopTracking
    -- doesn't yield.)
    pcall(function() LrDevelopController.stopTracking() end)

    -- Not wrapped in pcall, and with a timeout: without a timeout,
    -- withWriteAccessDo fails immediately if another write is in flight
    -- (Lightroom often has one when you're actively in Develop). The timeout
    -- makes it wait for the lock instead -- but its wait yields the
    -- coroutine, and yielding across a pcall (C-call) boundary throws
    -- "Yielding is not allowed within a C or metamethod call", so this must
    -- stay outside any pcall. (Getting that wrong once deadlocks Lightroom's
    -- write access for the rest of the session.)
    catalog:withWriteAccessDo("Apply Preset", function()
        photo:applyDevelopPreset(target)
    end, {
        timeout = 5,
        callback = function()
            Log:warnf("applyPreset(%s / %s): TIMED OUT waiting for write access",
                tostring(folderName), tostring(presetName))
        end,
    })
end

return {
    listPresets = listPresets,
    applyPreset = applyPreset,
}
