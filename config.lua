-- config.lua
-- Preset save/load to disk as JSON. Serializes the shared flags table
-- (Color3 and EnumItem made JSON-safe), and on load pushes values back into
-- both flags and the live UI via each component's :Set. All file IO is guarded
-- so executors missing writefile/etc. degrade to a silent no-op.

return function(shared)
    local components   = shared.components
    local HttpService  = shared.Services.HttpService
    local flags        = shared.flags
    local flagControls = shared.flagControls
    local Cloud        = shared.Cloud

    local FOLDER  = "Cloud"
    local PRESETS = "Cloud/presets"

    local presetName = ""
    local dropdownApi

    --------------------------------------------------------------------------
    -- JSON-safe (de)serialization of flag values
    --------------------------------------------------------------------------
    local function serialize(value)
        local t = typeof(value)
        if t == "Color3" then
            return { __type = "Color3", value = { value.R, value.G, value.B } }
        elseif t == "EnumItem" then
            return { __type = "EnumItem", enum = tostring(value.EnumType), name = value.Name }
        elseif t == "table" then
            local out = {}
            for k, v in pairs(value) do out[k] = serialize(v) end
            return out
        else
            return value
        end
    end

    local function deserialize(value)
        if type(value) == "table" then
            if value.__type == "Color3" then
                local c = value.value
                return Color3.new(c[1], c[2], c[3])
            elseif value.__type == "EnumItem" then
                local short = (value.enum or ""):gsub("^Enum%.", "")
                local ok, item = pcall(function() return Enum[short][value.name] end)
                return ok and item or nil
            else
                local out = {}
                for k, v in pairs(value) do out[k] = deserialize(v) end
                return out
            end
        else
            return value
        end
    end

    --------------------------------------------------------------------------
    -- Guarded file IO
    --------------------------------------------------------------------------
    local function ioReady()
        return writefile and isfolder and makefolder and true or false
    end

    local function ensureFolders()
        if not ioReady() then return false end
        local ok = pcall(function()
            if not isfolder(FOLDER) then makefolder(FOLDER) end
            if not isfolder(PRESETS) then makefolder(PRESETS) end
        end)
        return ok
    end

    local function savePreset(name)
        if not name or name == "" then return false end
        if not ensureFolders() then return false end
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(serialize(flags))
        end)
        if not ok then return false end
        return (pcall(function()
            writefile(PRESETS .. "/" .. name .. ".json", encoded)
        end))
    end

    local function listPresets()
        if not (listfiles and isfolder) then return {} end
        local names = {}
        pcall(function()
            if not isfolder(PRESETS) then return end
            for _, path in ipairs(listfiles(PRESETS)) do
                local file = path:match("[^/\\]+$") or path
                if file:match("%.json$") then
                    table.insert(names, (file:gsub("%.json$", "")))
                end
            end
        end)
        return names
    end

    local function loadPreset(name)
        if not readfile or not name or name == "" then return false end
        local ok, content = pcall(function()
            return readfile(PRESETS .. "/" .. name .. ".json")
        end)
        if not ok or not content then return false end
        local ok2, decoded = pcall(function() return HttpService:JSONDecode(content) end)
        if not ok2 or type(decoded) ~= "table" then return false end
        for flag, raw in pairs(decoded) do
            local value = deserialize(raw)
            if flagControls[flag] then
                flagControls[flag]:Set(value)
            else
                flags[flag] = value
            end
        end
        return true
    end

    --------------------------------------------------------------------------
    -- Programmatic API
    --------------------------------------------------------------------------
    Cloud.savePreset  = function(_, name) return savePreset(name) end
    Cloud.loadPreset  = function(_, name) return loadPreset(name) end
    Cloud.listPresets = function() return listPresets() end

    --------------------------------------------------------------------------
    -- Components for a settings tab
    --------------------------------------------------------------------------
    function components.presetNameBox(ctx, opts)
        opts = opts or {}
        return components.textbox(ctx, {
            Text = opts.Text or "Preset name",
            Placeholder = opts.Placeholder or "my preset",
            Callback = function(text)
                presetName = text
                if opts.Callback then opts.Callback(text) end
            end,
        })
    end

    function components.savePresetButton(ctx, opts)
        opts = opts or {}
        return components.button(ctx, {
            Text = opts.Text or "Save preset",
            Callback = function()
                if presetName == nil or presetName == "" then
                    Cloud:notify({ Title = "Preset", Text = "Type a name first.", Duration = 3 })
                    return
                end
                local saved = savePreset(presetName)
                if dropdownApi then dropdownApi.SetOptions(listPresets()) end
                Cloud:notify({
                    Title = "Preset",
                    Text = saved and ("Saved '" .. presetName .. "'") or "Saving unavailable on this executor.",
                    Duration = 3,
                })
            end,
        })
    end

    function components.loadPresetDropdown(ctx, opts)
        opts = opts or {}
        dropdownApi = components.dropdown(ctx, {
            Text = opts.Text or "Load preset",
            Options = listPresets(),
            Callback = function(choice)
                if type(choice) == "string" and choice ~= "" and choice ~= "none" then
                    if loadPreset(choice) then
                        Cloud:notify({ Title = "Preset", Text = "Loaded '" .. choice .. "'", Duration = 3 })
                    end
                end
            end,
        })
        return dropdownApi
    end
end
