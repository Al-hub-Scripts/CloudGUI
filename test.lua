-- test.lua
-- Comprehensive feature test / demo for the Cloud GUI library. Run in an executor:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Al-hub-Scripts/CloudGUI/refs/heads/main/test.lua"))()
--
-- This exercises EVERY public feature: all components and their option variants,
-- multi-tab switching, the notification queue, theme swapping (a second window),
-- and the programmatic APIs (component :Set / :Get, Cloud.flags, and the
-- savePreset / loadPreset / listPresets preset round-trip).

local Cloud = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Al-hub-Scripts/CloudGUI/refs/heads/main/loader.lua"
))()

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function humanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local win  = Cloud:frame("Cloud", "comprehensive feature test", Cloud.themes.Cloud)
local combat   = win:tab("combat")
local movement = win:tab("movement")
local visuals  = win:tab("visuals")
local config   = win:tab("config")

-- Handles kept so the config tab can drive them programmatically via :Set.
local handles = {}

----------------------------------------------------------------------
-- COMBAT: buttons, toggles, keybinds
----------------------------------------------------------------------
combat:section("Actions")
combat:button({ Text = "Kill All (demo)", Callback = function()
    Cloud:notify({ Title = "Combat", Text = "Kill All triggered.", Duration = 3 })
end })
combat:button({ Text = "Reset Character", Callback = function()
    if player.Character then player.Character:BreakJoints() end
end })

combat:section("Toggles")
handles.god = combat:toggle({ Text = "God Mode", Flag = "godmode", Default = false,
    Callback = function(s) Cloud:notify({ Title = "God Mode", Text = s and "ON" or "OFF", Duration = 2 }) end })
combat:toggle({ Text = "Auto Parry", Flag = "autoparry", Default = true })
combat:toggle({ Text = "Kill Aura", Flag = "killaura", Default = false })
combat:toggle({ Text = "Infinite Ammo", Flag = "infammo", Default = false })

combat:section("Tuning")
handles.range = combat:slider({ Text = "Hit Range", Min = 5, Max = 100, Default = 20, Flag = "range" })
combat:slider({ Text = "Crit Chance", Min = 0, Max = 1, Default = 0.25, Decimals = 2, Flag = "crit" })

combat:section("Binds")
combat:keybind({ Text = "Toggle UI", Default = Enum.KeyCode.RightShift, Flag = "uikey",
    Callback = function() win.gui.Enabled = not win.gui.Enabled end })
combat:keybind({ Text = "Panic Disable", Default = Enum.KeyCode.End, Flag = "panic" })

----------------------------------------------------------------------
-- MOVEMENT: sliders driving real character properties
----------------------------------------------------------------------
movement:section("Speed")
handles.ws = movement:slider({ Text = "WalkSpeed", Min = 16, Max = 250, Default = 16, Flag = "ws",
    Callback = function(v) local h = humanoid() if h then h.WalkSpeed = v end end })
movement:slider({ Text = "JumpPower", Min = 50, Max = 500, Default = 50, Flag = "jump",
    Callback = function(v) local h = humanoid() if h then h.JumpPower = v end end })

movement:section("Camera")
movement:slider({ Text = "FOV", Min = 70, Max = 120, Default = 70, Flag = "fov",
    Callback = function(v) workspace.CurrentCamera.FieldOfView = v end })

movement:section("Modes")
handles.mode = movement:dropdown({ Text = "Move Style", Options = { "Walk", "Run", "Fly", "Noclip" },
    Default = "Walk", Multi = false, Flag = "movestyle",
    Callback = function(c) Cloud:notify({ Title = "Move", Text = "Style: " .. tostring(c), Duration = 2 }) end })
movement:toggle({ Text = "Auto Sprint", Flag = "sprint", Default = true })
movement:label("Tip: drag the bar at the bottom to move the window.")

----------------------------------------------------------------------
-- VISUALS: dropdowns, textbox, colorpickers, paragraph
----------------------------------------------------------------------
visuals:section("ESP")
handles.esp = visuals:dropdown({ Text = "ESP Features", Options = { "Boxes", "Names", "Health", "Distance", "Tracers" },
    Default = { "Boxes", "Names" }, Multi = true, Flag = "esp",
    Callback = function(list) Cloud:notify({ Title = "ESP", Text = #list .. " feature(s) on", Duration = 2 }) end })

visuals:section("Colors")
handles.boxcolor = visuals:colorpicker({ Text = "Box Color", Default = Color3.fromRGB(160, 176, 224), Flag = "boxcolor" })
handles.namecolor = visuals:colorpicker({ Text = "Name Color", Default = Color3.fromRGB(255, 255, 255), Flag = "namecolor" })

visuals:section("Misc")
handles.name = visuals:textbox({ Text = "Watermark", Placeholder = "type text...", Default = "cloud",
    Flag = "watermark", Callback = function(t) Cloud:notify({ Title = "Watermark", Text = t, Duration = 2 }) end })
visuals:divider()
visuals:paragraph({ Title = "About", Text = "Every control here writes to Cloud.flags and exposes :Set, "
    .. "so the config tab can save, restore, and drive them. Expand the dropdowns and colour pickers "
    .. "to see the staggered open animations." })

----------------------------------------------------------------------
-- CONFIG: presets + programmatic API demos (:Set, flags, themes)
----------------------------------------------------------------------
config:section("Presets")
config:presetNameBox({ Text = "Preset name", Placeholder = "my preset" })
config:savePresetButton({ Text = "Save current settings" })
config:loadPresetDropdown({ Text = "Load preset" })

config:section("Programmatic API")
config:button({ Text = "Randomize via :Set", Callback = function()
    handles.god:Set(math.random() > 0.5)
    handles.ws:Set(math.random(16, 250))
    handles.range:Set(math.random(5, 100))
    handles.mode:Set(({ "Walk", "Run", "Fly", "Noclip" })[math.random(1, 4)])
    handles.esp:Set({ "Health", "Tracers" })
    handles.boxcolor:Set(Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255)))
    handles.name:Set("randomized")
    Cloud:notify({ Title = "API", Text = ":Set drove every control + flag.", Duration = 3 })
end })
config:button({ Text = "Dump flags", Callback = function()
    local n, sample = 0, {}
    for k in pairs(Cloud.flags) do
        n = n + 1
        if #sample < 4 then table.insert(sample, k) end
    end
    Cloud:notify({ Title = "Flags (" .. n .. ")", Text = table.concat(sample, ", "), Duration = 4 })
end })
config:button({ Text = "List saved presets", Callback = function()
    local list = Cloud:listPresets()
    Cloud:notify({ Title = "Presets", Text = #list > 0 and table.concat(list, ", ") or "none saved", Duration = 4 })
end })

config:section("Notifications")
config:button({ Text = "Queue three toasts", Callback = function()
    Cloud:notify({ Title = "One",   Text = "Stacks on top.",     Duration = 5 })
    Cloud:notify({ Title = "Two",   Text = "Slides in below.",   Duration = 5 })
    Cloud:notify({ Title = "Three", Text = "Reflow on dismiss.", Duration = 5 })
end })

config:section("Themes")
config:button({ Text = "Open Cherry-theme window", Callback = function()
    local cherry = Cloud:frame("Cloud", "cherry theme", Cloud.themes.Cherry)
    local t = cherry:tab("demo")
    t:section("Cherry palette")
    t:toggle({ Text = "Example toggle", Default = true })
    t:slider({ Text = "Example slider", Min = 0, Max = 100, Default = 60 })
    t:button({ Text = "Close", Callback = function() cherry.gui:Destroy() end })
end })
config:paragraph({ Title = "Round-trip", Text = "Change controls, type a name + Save, hit Randomize, "
    .. "then Load your name — every flag and on-screen control snaps back." })

----------------------------------------------------------------------
Cloud:notify({ Title = "Cloud", Text = "Comprehensive test loaded across 4 tabs.", Duration = 5 })

return Cloud
