-- loader.lua
-- The ONLY file the user touches:
--   local Cloud = loadstring(game:HttpGet("<BASE_URL>/loader.lua"))()
-- It fetches every module, loadstrings each, wires them onto one shared table,
-- and returns the fully assembled Cloud library.

-- >>> Set this to the raw base URL the modules are hosted at (no trailing slash).
local BASE_URL = "https://raw.githubusercontent.com/Al-hub-Scripts/CloudGUI/refs/heads/main"

local shared = {}

shared.Services = {
    UIS         = game:GetService("UserInputService"),
    TS          = game:GetService("TweenService"),
    RunService  = game:GetService("RunService"),
    HttpService = game:GetService("HttpService"),
    CoreGui     = game:GetService("CoreGui"),
}

-- The assembled library + the single shared flags table.
local Cloud = {}
Cloud.flags        = {}
shared.Cloud        = Cloud
shared.flags        = Cloud.flags
shared.flagControls = {}
shared.components   = {}

local function fetch(file)
    local source = game:HttpGet(BASE_URL .. "/" .. file)
    local chunk, err = loadstring(source)
    if not chunk then
        error("Cloud: failed to compile " .. file .. ": " .. tostring(err))
    end
    return chunk()
end

-- Order matters: core defines helpers + window, components/config register
-- methods, notifications attaches Cloud:notify.
fetch("core.lua")(shared)
fetch("components.lua")(shared)
fetch("notifications.lua")(shared)
fetch("config.lua")(shared)

return Cloud
