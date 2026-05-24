-- components.lua
-- Every tab-attached component. Each builder takes (ctx, opts) where ctx
-- carries the container to parent into, the theme, and the shared helpers.
-- Components that accept a Flag write their live value into shared.flags and
-- register a :Set on shared.flagControls so presets can drive the UI.

return function(shared)
    local create = shared.create
    local tween  = shared.tween
    local font   = shared.font
    local flags  = shared.flags
    local UIS    = shared.Services.UIS
    local SLOW   = shared.SLOW

    shared.flagControls = shared.flagControls or {}
    local flagControls = shared.flagControls

    local C = {}

    --------------------------------------------------------------------------
    -- helpers
    --------------------------------------------------------------------------
    local function register(opts, default, setter)
        if opts and opts.Flag ~= nil then
            flags[opts.Flag] = default
            flagControls[opts.Flag] = { Set = setter }
        end
    end

    local function makeRow(ctx, height)
        return create("Frame", {
            Name = "Row",
            Size = UDim2.new(1, 0, 0, height or 36),
            BackgroundColor3 = ctx.theme.Button,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Parent = ctx.container,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            create("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = ctx.theme.Accent,
                Transparency = 0.7,
            }),
        })
    end

    local function rowLabel(row, theme, text)
        return create("TextLabel", {
            Name = "Label",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(0.6, -10, 0, 36),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text or "",
            FontFace = font,
            TextSize = 16,
            TextColor3 = theme.Text,
            Parent = row,
        })
    end

    --------------------------------------------------------------------------
    -- button
    --------------------------------------------------------------------------
    function C.button(ctx, opts)
        opts = opts or {}
        local theme = ctx.theme

        local row = makeRow(ctx, 36)
        local btn = create("TextButton", {
            Name = "Button",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = opts.Text or "Button",
            FontFace = font,
            TextSize = 16,
            TextColor3 = theme.Text,
            Parent = row,
        })

        btn.MouseEnter:Connect(function()
            tween(row, { BackgroundColor3 = theme.ButtonHover, BackgroundTransparency = 0.3 })
        end)
        btn.MouseLeave:Connect(function()
            tween(row, { BackgroundColor3 = theme.Button, BackgroundTransparency = 0.5 })
        end)
        btn.MouseButton1Down:Connect(function()
            tween(row, { BackgroundColor3 = theme.ButtonActive, BackgroundTransparency = 0.2 }, 0.2)
        end)
        btn.MouseButton1Up:Connect(function()
            tween(row, { BackgroundColor3 = theme.ButtonHover, BackgroundTransparency = 0.3 })
        end)
        btn.MouseButton1Click:Connect(function()
            if opts.Callback then opts.Callback() end
        end)

        return { instance = row }
    end

    --------------------------------------------------------------------------
    -- toggle
    --------------------------------------------------------------------------
    function C.toggle(ctx, opts)
        opts = opts or {}
        local theme = ctx.theme
        local state = opts.Default or false

        local row = makeRow(ctx, 36)
        rowLabel(row, theme, opts.Text)

        local pill = create("Frame", {
            Name = "Pill",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 42, 0, 20),
            BackgroundColor3 = theme.ButtonActive,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Parent = row,
        }, {
            create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })
        local knob = create("Frame", {
            Name = "Knob",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 2, 0.5, 0),
            Size = UDim2.new(0, 16, 0, 16),
            BackgroundColor3 = theme.BG,
            BorderSizePixel = 0,
            Parent = pill,
        }, {
            create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })

        local function setState(value, fire)
            state = value and true or false
            if state then
                tween(pill, { BackgroundColor3 = theme.Accent, BackgroundTransparency = 0 })
                tween(knob, { Position = UDim2.new(1, -18, 0.5, 0) })
            else
                tween(pill, { BackgroundColor3 = theme.ButtonActive, BackgroundTransparency = 0.2 })
                tween(knob, { Position = UDim2.new(0, 2, 0.5, 0) })
            end
            if opts.Flag ~= nil then flags[opts.Flag] = state end
            if fire ~= false and opts.Callback then opts.Callback(state) end
        end

        local btn = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = "",
            Parent = row,
        })
        btn.MouseButton1Click:Connect(function()
            setState(not state)
        end)

        local api = { instance = row }
        function api.Set(value) setState(value) end
        register(opts, state, api.Set)
        setState(state, false)
        return api
    end

    --------------------------------------------------------------------------
    -- slider
    --------------------------------------------------------------------------
    function C.slider(ctx, opts)
        opts = opts or {}
        local theme = ctx.theme
        local min = opts.Min or 0
        local max = opts.Max or 100
        local decimals = opts.Decimals or 0
        local value = opts.Default or min

        local function round(v)
            local m = 10 ^ decimals
            return math.floor(v * m + 0.5) / m
        end

        local row = makeRow(ctx, 50)
        rowLabel(row, theme, opts.Text)

        local valueLabel = create("TextLabel", {
            Name = "Value",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 0),
            Size = UDim2.new(0.35, 0, 0, 30),
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = tostring(value),
            FontFace = font,
            TextSize = 15,
            TextColor3 = theme.TextDim,
            Parent = row,
        })

        local track = create("Frame", {
            Name = "Track",
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -10),
            Size = UDim2.new(1, -20, 0, 6),
            BackgroundColor3 = theme.ButtonActive,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Parent = row,
        }, {
            create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })
        local fill = create("Frame", {
            Name = "Fill",
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = theme.Accent,
            BorderSizePixel = 0,
            Parent = track,
        }, {
            create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })

        local function setValue(v, fire, animate)
            v = round(math.clamp(v, min, max))
            value = v
            local alpha = (max > min) and (v - min) / (max - min) or 0
            local props = { Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0) }
            if animate == false then
                fill.Size = props.Size
            else
                tween(fill, props)
            end
            valueLabel.Text = tostring(v)
            if opts.Flag ~= nil then flags[opts.Flag] = v end
            if fire ~= false and opts.Callback then opts.Callback(v) end
        end

        local dragging = false
        local function updateFromX(x)
            local alpha = (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
            setValue(min + math.clamp(alpha, 0, 1) * (max - min))
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromX(input.Position.X)
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromX(input.Position.X)
            end
        end)
        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        local api = { instance = row }
        function api.Set(v) setValue(v) end
        register(opts, value, api.Set)
        setValue(value, false, false)
        return api
    end

    --------------------------------------------------------------------------
    -- dropdown (single or multi select)
    --------------------------------------------------------------------------
    function C.dropdown(ctx, opts)
        opts = opts or {}
        local theme = ctx.theme
        local options = opts.Options or {}
        local multi = opts.Multi or false
        local optHeight = 28

        -- selection state: multi = set of name->true, single = string
        local selected
        if multi then
            selected = {}
            if type(opts.Default) == "table" then
                for _, v in ipairs(opts.Default) do selected[v] = true end
            elseif opts.Default ~= nil then
                selected[opts.Default] = true
            end
        else
            selected = opts.Default
        end

        local container = create("Frame", {
            Name = "Dropdown",
            Size = UDim2.new(1, 0, 0, 36),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = theme.Button,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Parent = ctx.container,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            create("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = theme.Accent,
                Transparency = 0.7,
            }),
            create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
        })

        local header = create("TextButton", {
            Name = "Header",
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            Text = "",
            LayoutOrder = 0,
            Parent = container,
        })
        local label = create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(0.5, -10, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = opts.Text or "Dropdown",
            FontFace = font,
            TextSize = 16,
            TextColor3 = theme.Text,
            Parent = header,
        })
        local valueLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -28, 0, 0),
            Size = UDim2.new(0.5, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = "",
            FontFace = font,
            TextSize = 15,
            TextColor3 = theme.TextDim,
            Parent = header,
        })
        local arrow = create("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0, 18),
            Size = UDim2.new(0, 16, 0, 16),
            Text = "v",
            FontFace = font,
            TextSize = 14,
            TextColor3 = theme.TextDim,
            Parent = header,
        })

        local holder = create("Frame", {
            Name = "Holder",
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            LayoutOrder = 1,
            Parent = container,
        }, {
            create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
            create("UIPadding", {
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6),
                PaddingBottom = UDim.new(0, 6),
            }),
        })

        local function displayText()
            if multi then
                local names = {}
                for _, name in ipairs(options) do
                    if selected[name] then table.insert(names, name) end
                end
                return #names > 0 and table.concat(names, ", ") or "none"
            else
                return selected ~= nil and tostring(selected) or "none"
            end
        end

        local function currentValue()
            if multi then
                local list = {}
                for _, name in ipairs(options) do
                    if selected[name] then table.insert(list, name) end
                end
                return list
            else
                return selected
            end
        end

        local open = false
        local function fullHeight()
            return #options * (optHeight + 2) + 6
        end
        local function setOpen(value)
            open = value
            if open then
                tween(holder, { Size = UDim2.new(1, 0, 0, fullHeight()) })
                tween(arrow, { Rotation = 180 })
            else
                tween(holder, { Size = UDim2.new(1, 0, 0, 0) })
                tween(arrow, { Rotation = 0 })
            end
        end

        local optionButtons = {}
        local function refreshHighlights()
            for name, b in pairs(optionButtons) do
                local on = multi and selected[name] or (selected == name)
                tween(b, {
                    BackgroundColor3 = on and theme.Accent or theme.ButtonActive,
                    BackgroundTransparency = on and 0 or 0.4,
                })
            end
            valueLabel.Text = displayText()
        end

        local function commit(fire)
            if opts.Flag ~= nil then flags[opts.Flag] = currentValue() end
            if fire ~= false and opts.Callback then opts.Callback(currentValue()) end
        end

        local function buildOptions()
            for _, b in pairs(optionButtons) do b:Destroy() end
            optionButtons = {}
            for i, name in ipairs(options) do
                local ob = create("TextButton", {
                    Name = name,
                    Size = UDim2.new(1, 0, 0, optHeight),
                    BackgroundColor3 = theme.ButtonActive,
                    BackgroundTransparency = 0.4,
                    BorderSizePixel = 0,
                    Text = name,
                    FontFace = font,
                    TextSize = 15,
                    TextColor3 = theme.Text,
                    LayoutOrder = i,
                    Parent = holder,
                }, {
                    create("UICorner", { CornerRadius = UDim.new(0, 5) }),
                })
                optionButtons[name] = ob
                ob.MouseButton1Click:Connect(function()
                    if multi then
                        selected[name] = not selected[name] or nil
                        refreshHighlights()
                        commit()
                    else
                        selected = name
                        refreshHighlights()
                        commit()
                        setOpen(false)
                    end
                end)
            end
            refreshHighlights()
        end

        header.MouseButton1Click:Connect(function()
            setOpen(not open)
        end)

        local api = { instance = container }
        function api.Set(value, fire)
            if multi then
                selected = {}
                if type(value) == "table" then
                    for _, v in ipairs(value) do selected[v] = true end
                elseif value ~= nil then
                    selected[value] = true
                end
            else
                selected = value
            end
            refreshHighlights()
            commit(fire)
        end
        function api.SetOptions(newOptions)
            options = newOptions or {}
            buildOptions()
            if open then tween(holder, { Size = UDim2.new(1, 0, 0, fullHeight()) }) end
        end

        buildOptions()
        register(opts, currentValue(), function(v) api.Set(v) end)
        valueLabel.Text = displayText()
        return api
    end

    --------------------------------------------------------------------------
    -- keybind
    --------------------------------------------------------------------------
    function C.keybind(ctx, opts)
        opts = opts or {}
        local theme = ctx.theme
        local current = opts.Default
        local listening = false

        local row = makeRow(ctx, 36)
        rowLabel(row, theme, opts.Text)

        local function keyName()
            return current and current.Name or "none"
        end

        local btn = create("TextButton", {
            Name = "Bind",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 90, 0, 24),
            BackgroundColor3 = theme.ButtonActive,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Text = keyName(),
            FontFace = font,
            TextSize = 14,
            TextColor3 = theme.Text,
            Parent = row,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 5) }),
        })

        local function setKey(key, fire)
            if type(key) == "string" then
                key = Enum.KeyCode[key]
            end
            current = key
            btn.Text = keyName()
            if opts.Flag ~= nil then flags[opts.Flag] = current end
            if fire ~= false and opts.Callback then opts.Callback(current) end
        end

        btn.MouseButton1Click:Connect(function()
            listening = true
            btn.Text = "..."
        end)

        UIS.InputBegan:Connect(function(input, gameProcessed)
            if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                setKey(input.KeyCode)
            elseif not gameProcessed and not listening and current
                and input.KeyCode == current then
                if opts.Callback then opts.Callback(current) end
            end
        end)

        local api = { instance = row }
        function api.Set(key) setKey(key, false) end
        register(opts, current, function(k) setKey(k) end)
        return api
    end

    --------------------------------------------------------------------------
    -- textbox
    --------------------------------------------------------------------------
    function C.textbox(ctx, opts)
        opts = opts or {}
        local theme = ctx.theme

        local row = makeRow(ctx, 36)
        rowLabel(row, theme, opts.Text)

        local box = create("TextBox", {
            Name = "Box",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0.45, -10, 0, 24),
            BackgroundColor3 = theme.ButtonActive,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Text = opts.Default or "",
            PlaceholderText = opts.Placeholder or "",
            PlaceholderColor3 = theme.TextDim,
            FontFace = font,
            TextSize = 14,
            TextColor3 = theme.Text,
            ClearTextOnFocus = false,
            Parent = row,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 5) }),
            create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
        })

        local function setText(text, fire)
            box.Text = text or ""
            if opts.Flag ~= nil then flags[opts.Flag] = box.Text end
            if fire ~= false and opts.Callback then opts.Callback(box.Text) end
        end

        box.Focused:Connect(function()
            tween(box, { BackgroundColor3 = theme.ButtonHover, BackgroundTransparency = 0 })
        end)
        box.FocusLost:Connect(function()
            tween(box, { BackgroundColor3 = theme.ButtonActive, BackgroundTransparency = 0.2 })
            setText(box.Text)
        end)

        local api = { instance = row }
        function api.Set(text) setText(text, false) end
        api.Get = function() return box.Text end
        register(opts, box.Text, api.Set)
        return api
    end

    --------------------------------------------------------------------------
    -- colorpicker (HSV: saturation/value plane + hue bar, expandable)
    --------------------------------------------------------------------------
    function C.colorpicker(ctx, opts)
        opts = opts or {}
        local theme = ctx.theme
        local color = opts.Default or Color3.new(1, 1, 1)
        local h, s, v = color:ToHSV()

        local container = create("Frame", {
            Name = "ColorPicker",
            Size = UDim2.new(1, 0, 0, 36),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = theme.Button,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Parent = ctx.container,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            create("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = theme.Accent,
                Transparency = 0.7,
            }),
            create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
        })

        local header = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            Text = "",
            LayoutOrder = 0,
            Parent = container,
        })
        create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(0.6, -10, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = opts.Text or "Color",
            FontFace = font,
            TextSize = 16,
            TextColor3 = theme.Text,
            Parent = header,
        })
        local swatch = create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 30, 0, 18),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = header,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 4) }),
            create("UIStroke", { Color = theme.Accent, Transparency = 0.5 }),
        })

        local holder = create("Frame", {
            Name = "Holder",
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            LayoutOrder = 1,
            Parent = container,
        })

        local pad = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 4),
            Size = UDim2.new(1, -16, 0, 100),
            Parent = holder,
        })

        local svBox = create("Frame", {
            Name = "SV",
            Size = UDim2.new(1, -26, 1, 0),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel = 0,
            Parent = pad,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 5) }),
        })
        -- saturation: white(left) -> transparent(right)
        local satGrad = create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = svBox,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 5) }),
            create("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
            }),
        })
        -- value: transparent(top) -> black(bottom)
        local valGrad = create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0,
            Parent = svBox,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 5) }),
            create("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0),
                }),
            }),
        })
        local svDot = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, 8, 0, 8),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = svBox,
        }, {
            create("UICorner", { CornerRadius = UDim.new(1, 0) }),
            create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.4 }),
        })

        local hueBar = create("Frame", {
            Name = "Hue",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0, 18, 1, 0),
            BorderSizePixel = 0,
            Parent = pad,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 5) }),
            create("UIGradient", {
                Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0, 1, 1)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1, 1, 1)),
                }),
            }),
        })
        local hueDot = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(1, 4, 0, 4),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = hueBar,
        }, {
            create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.4 }),
        })

        local function applyVisual()
            color = Color3.fromHSV(h, s, v)
            svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            tween(swatch, { BackgroundColor3 = color }, 0.3)
            svDot.Position = UDim2.new(s, 0, 1 - v, 0)
            hueDot.Position = UDim2.new(0.5, 0, h, 0)
        end

        local function commit(fire)
            applyVisual()
            if opts.Flag ~= nil then flags[opts.Flag] = color end
            if fire ~= false and opts.Callback then opts.Callback(color) end
        end

        -- SV plane input
        local svDragging = false
        local function updateSV(pos)
            local rx = (pos.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X
            local ry = (pos.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y
            s = math.clamp(rx, 0, 1)
            v = 1 - math.clamp(ry, 0, 1)
            commit()
        end
        svBox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                svDragging = true
                updateSV(input.Position)
            end
        end)

        -- Hue bar input
        local hueDragging = false
        local function updateHue(pos)
            local ry = (pos.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y
            h = math.clamp(ry, 0, 1)
            commit()
        end
        hueBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                hueDragging = true
                updateHue(input.Position)
            end
        end)

        UIS.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                if svDragging then updateSV(input.Position) end
                if hueDragging then updateHue(input.Position) end
            end
        end)
        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                svDragging = false
                hueDragging = false
            end
        end)

        local open = false
        header.MouseButton1Click:Connect(function()
            open = not open
            tween(holder, { Size = UDim2.new(1, 0, 0, open and 108 or 0) })
        end)

        local api = { instance = container }
        function api.Set(c)
            if typeof(c) == "Color3" then
                color = c
                h, s, v = c:ToHSV()
                commit(false)
            end
        end
        register(opts, color, function(c) api.Set(c); if opts.Callback then opts.Callback(color) end end)
        applyVisual()
        return api
    end

    --------------------------------------------------------------------------
    -- label
    --------------------------------------------------------------------------
    function C.label(ctx, opts)
        local theme = ctx.theme
        local text = type(opts) == "table" and (opts.Text or "") or tostring(opts)
        local lbl = create("TextLabel", {
            Name = "Label",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            FontFace = font,
            TextSize = 16,
            TextColor3 = theme.Text,
            Parent = ctx.container,
        }, {
            create("UIPadding", { PaddingLeft = UDim.new(0, 4) }),
        })
        local api = { instance = lbl }
        function api.Set(t) lbl.Text = t end
        return api
    end

    --------------------------------------------------------------------------
    -- section (grouping header)
    --------------------------------------------------------------------------
    function C.section(ctx, opts)
        local theme = ctx.theme
        local text = type(opts) == "table" and (opts.Text or "") or tostring(opts)
        local holder = create("Frame", {
            Name = "Section",
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Parent = ctx.container,
        })
        create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 4, 0, 0),
            Size = UDim2.new(1, -8, 0, 22),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            FontFace = font,
            TextSize = 18,
            TextColor3 = theme.Accent,
            Parent = holder,
        })
        create("Frame", {
            Position = UDim2.new(0, 4, 1, -3),
            Size = UDim2.new(1, -8, 0, 1),
            BackgroundColor3 = theme.Divider,
            BorderSizePixel = 0,
            Parent = holder,
        })
        return { instance = holder }
    end

    --------------------------------------------------------------------------
    -- divider
    --------------------------------------------------------------------------
    function C.divider(ctx)
        local theme = ctx.theme
        local holder = create("Frame", {
            Name = "Divider",
            Size = UDim2.new(1, 0, 0, 8),
            BackgroundTransparency = 1,
            Parent = ctx.container,
        })
        create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, -12, 0, 1),
            BackgroundColor3 = theme.Divider,
            BorderSizePixel = 0,
            Parent = holder,
        })
        return { instance = holder }
    end

    --------------------------------------------------------------------------
    -- paragraph
    --------------------------------------------------------------------------
    function C.paragraph(ctx, opts)
        opts = opts or {}
        local theme = ctx.theme

        local row = create("Frame", {
            Name = "Paragraph",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = theme.Button,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Parent = ctx.container,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            create("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = theme.Accent,
                Transparency = 0.7,
            }),
            create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
            create("UIPadding", {
                PaddingTop = UDim.new(0, 8),
                PaddingBottom = UDim.new(0, 8),
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
            }),
        })

        local titleLbl = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = opts.Title or "",
            FontFace = font,
            TextSize = 16,
            TextColor3 = theme.Text,
            LayoutOrder = 0,
            Parent = row,
        })
        local bodyLbl = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Text = opts.Text or "",
            FontFace = font,
            TextSize = 14,
            TextColor3 = theme.TextDim,
            LayoutOrder = 1,
            Parent = row,
        })

        local api = { instance = row }
        function api.Set(t) bodyLbl.Text = t end
        return api
    end

    shared.components = C
end
