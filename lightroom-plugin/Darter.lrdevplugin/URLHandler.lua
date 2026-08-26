local LrTasks       = import 'LrTasks'
local Log           = require 'Logger'
local CommandHandler = require 'CommandHandler'
local PresetHandler  = require 'PresetHandler'

local function urlDecode(s)
    -- Only decode %xx escapes. Deliberately does NOT treat "+" as a space:
    -- that's the application/x-www-form-urlencoded convention, but the Mac
    -- app builds proper RFC-3986 URLs (URLComponents encodes spaces as %20
    -- and leaves "+" literal), so a "+" here is a real plus -- e.g. preset
    -- names like "PS08 + Contrast".
    return (s:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function parseQuery(url)
    local query = url:match("%?(.*)$") or ""
    local params = {}
    for key, value in query:gmatch("([^&=]+)=([^&=]*)") do
        params[urlDecode(key)] = urlDecode(value)
    end
    return params
end

local handler = {}

function handler.URLHandler(url)
    Log:tracef("Received URL: %s", url)

    local params = parseQuery(url)

    if params.tool ~= nil then
        LrTasks.startAsyncTask(function()
            CommandHandler.activateTool(params.tool)
        end)
        return
    end

    if params.action == "nextPhoto" or params.action == "previousPhoto" then
        local goNext = (params.action == "nextPhoto")
        LrTasks.startAsyncTask(function()
            CommandHandler.navigatePhoto(goNext)
        end)
        return
    end

    if params.action == "listPresets" then
        LrTasks.startAsyncTask(function()
            PresetHandler.listPresets()
        end)
        return
    end

    if params.action == "applyPreset" then
        LrTasks.startAsyncTask(function()
            PresetHandler.applyPreset(params.folder, params.preset)
        end)
        return
    end

    local name = params.name
    local delta = tonumber(params.delta)
    local reldelta = tonumber(params.reldelta) -- optional; nil unless present

    if name == nil or delta == nil then
        Log:warnf("Malformed URL, missing name/delta: %s", url)
        return
    end

    LrTasks.startAsyncTask(function()
        CommandHandler.applyDelta(name, delta, reldelta)
    end)
end

return handler
