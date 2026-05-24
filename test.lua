-- test.lua
-- Feature test / demo for the Cloud GUI library. Run this in an executor:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Al-hub-Scripts/CloudGUI/refs/heads/main/test.lua"))()
-- It loads the library through the single loader, then builds one window that
-- touches every component, the notification queue, theme swapping, and the
-- full preset save/load round-trip.

local Cloud = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Al-hub-Scripts/CloudGUI/refs/heads/main/loader.lua"
))()

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local win  = Cloud:frame("Cloud", "feature test build", Cloud.themes.Cloud)
local main = win:tab("main")
local vis  = win:tab("visuals")
local sets = win:tab("settings")

----------------------------------------------------------------------
-- main tab: the core interactive components
----------------------------------------------------------------------
main:section("Buttons & Toggles")

main:button({
    Text = "Notify me",
    Callback = function()
        Cloud:notify({ Title = "Button", Text = "You clicked the button.", Duration = 4 })
    end,
})

main:toggle({
    Text = "God Mode",
    Flag = "godmode",
    Default = false,
    Callback = function(state)
        Cloud:notify({ Title = "God Mode", Text = state and "ON" or "OFF", Duration = 3 })
    end,
})

main:section("Sliders")

main:slider({
    Text = "WalkSpeed",
    Min = 16, Max = 200, Default = 16,
    Flag = "ws",
    Callback = function(value)
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = value end
    end,
})

main:slider({
    Text = "FOV",
    Min = 70, Max = 120, Default = 70, Decimals = 0,
    Flag = "fov",
    Callback = function(value)
        workspace.CurrentCamera.FieldOfView = value
    end,
})

main:divider()

main:section("Selection")

main:dropdown({
    Text = "Single mode",
    Options = { "Walk", "Run", "Fly" },
    Default = "Walk",
    Multi = false,
    Flag = "mode",
    Callback = function(choice)
        Cloud:notify({ Title = "Mode", Text = "Picked " .. tostring(choice), Duration = 3 })
    end,
})

main:dropdown({
    Text = "Multi ESP",
    Options = { "Boxes", "Names", "Health", "Tracers" },
    Default = { "Boxes", "Names" },
    Multi = true,
    Flag = "esp",
    Callback = function(list)
        Cloud:notify({ Title = "ESP", Text = #list .. " enabled", Duration = 3 })
    end,
})

main:keybind({
    Text = "Toggle (rebindable)",
    Default = Enum.KeyCode.RightShift,
    Flag = "uikey",
    Callback = function(key)
        win.gui.Enabled = not win.gui.Enabled
    end,
})

----------------------------------------------------------------------
-- visuals tab: textbox, colorpicker, label, paragraph
----------------------------------------------------------------------
vis:section("Text & Color")

vis:textbox({
    Text = "Player name",
    Placeholder = "type here...",
    Flag = "name",
    Callback = function(text)
        Cloud:notify({ Title = "Textbox", Text = "Got: " .. text, Duration = 3 })
    end,
})

vis:colorpicker({
    Text = "ESP Color",
    Default = Color3.fromRGB(160, 176, 224),
    Flag = "espcolor",
    Callback = function(color)
        -- drag the SV plane / hue bar to change this live
    end,
})

vis:label("This is a plain label.")
vis:divider()
vis:paragraph({
    Title = "Note",
    Text = "Every animation here reuses the same slow Quad/Out easing as the "
        .. "drag bar. Try dragging the bar at the bottom, switching tabs, and "
        .. "expanding the dropdowns to feel it.",
})

----------------------------------------------------------------------
-- settings tab: theme swap, notification queue test, preset round-trip
----------------------------------------------------------------------
sets:section("Notifications")

sets:button({
    Text = "Queue two toasts",
    Callback = function()
        Cloud:notify({ Title = "First", Text = "This one stacks on top.", Duration = 5 })
        Cloud:notify({ Title = "Second", Text = "This slides in below it.", Duration = 5 })
    end,
})

sets:section("Presets")
sets:presetNameBox({ Text = "Preset name", Placeholder = "my preset" })
sets:savePresetButton({ Text = "Save current settings" })
sets:loadPresetDropdown({ Text = "Load preset" })

sets:divider()
sets:paragraph({
    Title = "Preset round-trip",
    Text = "1) change some controls.  2) type a name + Save.  3) change them "
        .. "again.  4) pick the name in Load — every flag and its on-screen "
        .. "control snaps back to the saved state.",
})

----------------------------------------------------------------------
-- ready
----------------------------------------------------------------------
Cloud:notify({ Title = "Cloud", Text = "Feature test loaded. Flags live in Cloud.flags", Duration = 5 })

return Cloud
