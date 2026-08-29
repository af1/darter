local LrDevelopController = import 'LrDevelopController'
local LrApplicationView   = import 'LrApplicationView'
local LrApplication       = import 'LrApplication'
local LrTasks             = import 'LrTasks'
local Log                 = require 'Logger'

-- Tool shortcuts should work from anywhere in Lightroom: pressing Tab in
-- the Library switches to Develop and then opens the Crop tool, instead of
-- silently doing nothing. Switching is asynchronous, so poll (up to ~2s)
-- until the Develop module reports active before touching its controller.
-- NOTE: LrTasks.sleep yields, so this must never be called inside a pcall.
local function ensureDevelopModule()
    if LrApplicationView.getCurrentModuleName() == "develop" then
        return true
    end
    LrApplicationView.switchToModule("develop")
    for _ = 1, 20 do
        LrTasks.sleep(0.1)
        if LrApplicationView.getCurrentModuleName() == "develop" then
            return true
        end
    end
    Log:warn("ensureDevelopModule: switch to develop never completed")
    return false
end

-- Short names (used by the Mac app / URL query) mapped to the actual
-- LrDevelopController parameter names. These are unsuffixed on purpose,
-- per Adobe's SDK reference for LrDevelopController (its adjustPanel
-- parameter list). The "2012"-suffixed keys that show up elsewhere belong
-- to a different API (photo:applyDevelopSettings on catalog photos), not
-- LrDevelopController's live Develop-panel controller, which is all this
-- plugin uses.
local PARAM_MAP = {
    Temperature = "Temperature",
    Tint        = "Tint",
    Exposure    = "Exposure",
    Contrast    = "Contrast",
    Highlights  = "Highlights",
    Shadows     = "Shadows",
    Saturation  = "Saturation",
    CropAngle   = "straightenAngle",
}

-- Short tool names (Mac app's "Open Tool" section) mapped to
-- LrDevelopController.selectTool's identifiers. Confirmed valid values per
-- Adobe's SDK reference: crop, dust (spot removal), redeye, gradient,
-- circularGradient, localized (adjustment brush), upright.
--
-- Note: "AutoStraighten" (the crop tool's own Auto button) is NOT handled
-- here -- confirmed via a before/after diff of every candidate develop
-- parameter that only straightenAngle changes when that button is clicked,
-- and there's no exposed API to compute the angle Lightroom picks. The Mac
-- app instead presses that real button via the Accessibility API
-- (see LightroomUIAutomation.swift) after asking this plugin to open the
-- Crop tool.
local TOOL_MAP = {
    Crop    = "crop",
    Masking = "masking", -- selectTool("masking") requires Lightroom SDK 11+
}

local function activateTool(toolName)
    if not ensureDevelopModule() then
        return
    end

    -- The modern Remove tool isn't a selectTool identifier -- newer
    -- Lightroom SDKs expose it as LrDevelopController.goToRemove(). Fall
    -- back to the legacy "dust" (spot removal) tool on older Lightroom
    -- versions where goToRemove doesn't exist.
    if toolName == "Remove" then
        local ok, err = pcall(function()
            if LrDevelopController.goToRemove ~= nil then
                LrDevelopController.goToRemove()
            else
                LrDevelopController.selectTool("dust")
            end
        end)
        if not ok then
            Log:warnf("activateTool(Remove) failed: %s", tostring(err))
        end
        return
    end

    -- Equivalent of the crop panel's Reset button. Unlike Auto Straighten
    -- (whose angle-detection has no scripting hook), this is a real SDK call
    -- -- no Accessibility button-pressing needed. Opens the crop tool first
    -- so the reset is visible in context when triggered from elsewhere.
    if toolName == "ResetCrop" then
        local ok, err = pcall(function()
            if LrDevelopController.getSelectedTool() ~= "crop" then
                LrDevelopController.selectTool("crop")
            end
            LrDevelopController.resetCrop()
        end)
        if not ok then
            Log:warnf("activateTool(ResetCrop) failed: %s", tostring(err))
        end
        return
    end

    local toolId = TOOL_MAP[toolName]
    if toolId == nil then
        Log:warnf("Unknown tool: %s", tostring(toolName))
        return
    end

    local ok, err = pcall(function()
        -- Skip if already active: re-selecting the current tool can
        -- commit/restart its session and mint a spurious history state.
        if LrDevelopController.getSelectedTool() ~= toolId then
            LrDevelopController.selectTool(toolId)
        end
    end)
    if not ok then
        Log:warnf("activateTool(%s) failed: %s", tostring(toolName), tostring(err))
    end
end

-- One history state per deliberate adjustment, not one per key-repeat
-- tick: consecutive setValue calls within this window merge into a single
-- history step (the SDK equivalent of dragging a slider in one motion).
local adjustmentThresholdSet = false
local function ensureAdjustmentThreshold()
    if adjustmentThresholdSet then return end
    local ok = pcall(function()
        LrDevelopController.setMultipleAdjustmentThreshold(2)
    end)
    adjustmentThresholdSet = ok
end

-- Raw formats keep absolute white-balance sliders (Kelvin); everything else
-- (JPG, TIFF, PSD, PNG) uses the relative -100..100 scale, where the raw
-- step is far too big. Read the current photo's format only when a relative
-- step was actually supplied (WB sliders), so ordinary sliders pay nothing.
local function isRelativeWhiteBalancePhoto()
    -- NOT wrapped in pcall: photo:getRawMetadata yields the coroutine to
    -- fetch metadata, and yielding across a pcall (C-call) boundary throws
    -- "Yielding is not allowed within a C or metamethod call". This runs
    -- inside the URLHandler's async task (with no pcall above it here), so
    -- yielding is allowed.
    local photo = LrApplication.activeCatalog():getTargetPhoto()
    if photo == nil then return false end
    local fmt = photo:getRawMetadata("fileFormat")
    return fmt ~= "RAW" and fmt ~= "DNG"
end

local function applyDelta(shortName, delta, reldelta)
    if LrApplicationView.getCurrentModuleName() ~= "develop" then
        Log:tracef("Ignoring %s: not in develop module", tostring(shortName))
        return
    end

    local param = PARAM_MAP[shortName]
    if param == nil then
        Log:warnf("Unknown param: %s", tostring(shortName))
        return
    end

    ensureAdjustmentThreshold()

    -- Only select the crop tool if it isn't already active: re-selecting
    -- the active tool can commit/restart the crop session, which minted an
    -- extra history state on every angle keypress.
    if shortName == "CropAngle" then
        local okTool, selected = pcall(LrDevelopController.getSelectedTool)
        if not okTool or selected ~= "crop" then
            LrDevelopController.selectTool("crop")
        end
    end

    local effectiveDelta = delta
    if reldelta ~= nil and isRelativeWhiteBalancePhoto() then
        effectiveDelta = reldelta
    end

    local ok, err = pcall(function()
        local current = LrDevelopController.getValue(param)
        local min, max = LrDevelopController.getRange(param)
        local new = current + effectiveDelta
        if new < min then new = min end
        if new > max then new = max end
        LrDevelopController.setValue(param, new)
        Log:tracef("%s: %s -> %s", param, tostring(current), tostring(new))
    end)

    if not ok then
        Log:warnf("applyDelta(%s, %s) failed: %s", tostring(shortName), tostring(delta), tostring(err))
    end
end

return {
    applyDelta = applyDelta,
    activateTool = activateTool,
}
