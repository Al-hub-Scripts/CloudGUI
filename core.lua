-- core.lua
-- Services, theme table, shared helpers, the window constructor, drag system,
-- and real tab switching. Returns a function that installs everything onto the
-- shared table handed in by loader.lua.

return function(shared)
    local Services = shared.Services
    local UIS         = Services.UIS
    local TS          = Services.TS
    local RunService  = Services.RunService
    local CoreGui     = Services.CoreGui

    local Cloud = shared.Cloud

    --------------------------------------------------------------------------
    -- Theme table (swappable). Cloud is the soft "sleepy cloud" default.
    --------------------------------------------------------------------------
    local themes = {
        Cloud = {
            BG              = Color3.fromRGB(232, 238, 248),
            Button          = Color3.fromRGB(214, 224, 242),
            ButtonHover     = Color3.fromRGB(224, 230, 248),
            ButtonActive    = Color3.fromRGB(196, 208, 236),
            Notification    = Color3.fromRGB(226, 232, 246),
            NotificationBar = Color3.fromRGB(168, 182, 224),
            Text            = Color3.fromRGB(92, 104, 148),
            TextDim         = Color3.fromRGB(150, 162, 196),
            Divider         = Color3.fromRGB(208, 218, 238),
            Accent          = Color3.fromRGB(160, 176, 224),
        },
        Cherry = {
            BG              = Color3.fromRGB(255, 238, 242),
            Button          = Color3.fromRGB(255, 210, 221),
            ButtonHover     = Color3.fromRGB(255, 190, 205),
            ButtonActive    = Color3.fromRGB(240, 160, 180),
            Notification    = Color3.fromRGB(255, 220, 230),
            NotificationBar = Color3.fromRGB(220, 130, 155),
            Text            = Color3.fromRGB(180, 80, 110),
            TextDim         = Color3.fromRGB(210, 150, 170),
            Divider         = Color3.fromRGB(245, 200, 215),
            Accent          = Color3.fromRGB(200, 140, 160),
        },
    }
    shared.themes = themes
    Cloud.themes  = themes

    --------------------------------------------------------------------------
    -- Shared font + slow easing constant (the "sleepy" feel, reused everywhere)
    --------------------------------------------------------------------------
    local font = Font.new("rbxasset://fonts/families/GrenzeGotisch.json", Enum.FontWeight.Regular)
    shared.font = font

    local SLOW = 0.7
    local EASE = TweenInfo.new(SLOW, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    shared.SLOW = SLOW

    --------------------------------------------------------------------------
    -- create(class, props, children): the Instance.new factory.
    -- Applies props (Parent last), parents any children, returns the instance.
    --------------------------------------------------------------------------
    local function create(class, props, children)
        local obj = Instance.new(class)
        if props then
            for k, v in pairs(props) do
                if k ~= "Parent" then
                    obj[k] = v
                end
            end
        end
        if children then
            for _, child in ipairs(children) do
                child.Parent = obj
            end
        end
        if props and props.Parent then
            obj.Parent = props.Parent
        end
        return obj
    end
    shared.create = create

    --------------------------------------------------------------------------
    -- tween(obj, props, dur?, style?, dir?): plays and returns a tween.
    -- Defaults to the slow Quad/Out easing the drag uses.
    --------------------------------------------------------------------------
    local function tween(obj, props, dur, style, dir)
        local info = EASE
        if dur or style or dir then
            info = TweenInfo.new(
                dur or SLOW,
                style or Enum.EasingStyle.Quad,
                dir or Enum.EasingDirection.Out
            )
        end
        local t = TS:Create(obj, info, props)
        t:Play()
        return t
    end
    shared.tween = tween

    --------------------------------------------------------------------------
    -- Cloud:frame(titletext, subtitletext, theme) -> window
    --------------------------------------------------------------------------
    function Cloud:frame(titletext, subtitletext, theme)
        theme = theme or themes.Cloud

        local window = {}
        window.theme  = theme
        window.tabs   = {}
        window.active = nil

        local gui = create("ScreenGui", {
            Name = "." .. titletext,
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            Parent = CoreGui,
        })
        window.gui = gui

        local frame = create("Frame", {
            Name = titletext,
            Size = UDim2.new(0.3, 0, 0.6, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3 = theme.BG,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Parent = gui,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 10) }),
        })
        window.frame = frame

            local frameoutline = create("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = theme.Accent,
                Transparency = 0.6,
                Parent = frame,
            })

            local title = create("TextLabel", {
                Name = "Title",
                BackgroundTransparency = 1,
                Position = UDim2.new(0.007, 0, 0.005, 0),
                Size = UDim2.new(1, 0, 0.05, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = titletext,
                FontFace = font,
                TextScaled = true,
                TextColor3 = theme.Text,
                Parent = frame,
            })

            local subtitle = create("TextLabel", {
                Name = "SubTitle",
                BackgroundTransparency = 1,
                Position = UDim2.new(0.007, 0, 0.05, 0),
                Size = UDim2.new(1, 0, 0.05, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = subtitletext,
                FontFace = font,
                TextScaled = true,
                TextColor3 = theme.TextDim,
                Parent = frame,
            })

            -- Holder that every tab's content CanvasGroup is parented into.
            local content = create("Frame", {
                Name = "Content",
                BackgroundTransparency = 1,
                Position = UDim2.new(0.02, 0, 0.12, 0),
                Size = UDim2.new(0.96, 0, 0.84, 0),
                Parent = frame,
            })
            window.content = content

            local dragbar = create("Frame", {
                Name = "DragBar",
                Size = UDim2.new(0.2, 0, 0.03, 0),
                Position = UDim2.new(0.5, 0, 0.84, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = theme.BG,
                BackgroundTransparency = 0.3,
                Parent = gui,
            }, {
                create("UICorner", { CornerRadius = UDim.new(0, 5) }),
            })
            window.dragbar = dragbar

                local dragbaroutline = create("UIStroke", {
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Color = theme.Accent,
                    Transparency = 0.6,
                    Parent = dragbar,
                })

                local minbutton = create("TextButton", {
                    Name = "MinButton",
                    Size = UDim2.new(0.1, 0, 1, 0),
                    Position = UDim2.new(0.9, 0, -0.1, 0),
                    BackgroundTransparency = 1,
                    TextScaled = true,
                    FontFace = font,
                    TextColor3 = theme.Text,
                    Text = "-",
                    ZIndex = 2,
                    Parent = dragbar,
                })
                    local fullsize = frame.Size
                    local min = false
                    minbutton.MouseButton1Click:Connect(function()
                        if min == false then
                            min = true
                            title.Visible = false
                            subtitle.Visible = false
                            content.Visible = false
                            minbutton.Text = "+"
                            minbutton.Position = UDim2.new(0.9, 0, 0, 0)
                            local mints = tween(frame, { Size = UDim2.new(0, 0, 0, 0) }, 0.5)
                            mints.Completed:Once(function()
                                frameoutline.Transparency = 1
                            end)
                        else
                            min = false
                            frameoutline.Transparency = 0.6
                            title.Visible = true
                            subtitle.Visible = true
                            content.Visible = true
                            minbutton.Text = "-"
                            minbutton.Position = UDim2.new(0.9, 0, -0.1, 0)
                            tween(frame, { Size = UDim2.new(fullsize.X.Scale, 0, fullsize.Y.Scale, 0) }, 0.5)
                        end
                    end)

                local draghitbox = create("TextButton", {
                    Name = "Hitbox",
                    Size = UDim2.new(1.3, 0, 3, 0),
                    Position = UDim2.new(-0.15, 0, -1, 0),
                    BackgroundTransparency = 1,
                    Text = "",
                    Parent = dragbar,
                })

                ----------------------------------------------------------------
                -- Drag system: track delta for THIS frame only, retarget a
                -- continuously-lerped position on RenderStepped. Keeps the slow,
                -- buttery feel without spawning a tween per mouse move.
                ----------------------------------------------------------------
                local dragging = false
                local mousestart, framestart, barstart
                local frametarget, bartarget

                draghitbox.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        dragging   = true
                        mousestart = input.Position
                        framestart = frame.Position
                        barstart   = dragbar.Position
                        frametarget = frame.Position
                        bartarget   = dragbar.Position
                    end
                end)
                UIS.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch) then
                        local distance = input.Position - mousestart
                        frametarget = framestart + UDim2.fromOffset(distance.X, distance.Y)
                        bartarget   = barstart + UDim2.fromOffset(distance.X, distance.Y)
                    end
                end)
                UIS.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)
                RunService.RenderStepped:Connect(function(dt)
                    if frametarget and gui.Parent then
                        local alpha = 1 - math.exp(-dt * 6)
                        frame.Position   = frame.Position:Lerp(frametarget, alpha)
                        dragbar.Position = dragbar.Position:Lerp(bartarget, alpha)
                    end
                end)

                local tabbar = create("ScrollingFrame", {
                    Name = "Tabs",
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0.01, 0, 0.1, 0),
                    Size = UDim2.new(0.65, 0, 0.95, 0),
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollingDirection = Enum.ScrollingDirection.X,
                    ScrollBarThickness = 0,
                    Parent = dragbar,
                })
                window.tabbar = tabbar

                    local tabslayout = create("UIListLayout", {
                        Padding = UDim.new(0.02, 0),
                        FillDirection = Enum.FillDirection.Horizontal,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Parent = tabbar,
                    })
                    tabslayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                        local tabcount = #tabbar:GetChildren() - 1
                        tabbar.CanvasSize = UDim2.new(0.2 * tabcount + 0.05 * (tabcount - 1), 0, 0, 0)
                    end)

        ------------------------------------------------------------------------
        -- Tab switching: each tab owns a CanvasGroup so the whole content fades
        -- as one. Show fades the chosen tab in and the previous one out.
        ------------------------------------------------------------------------
        local function show(entry)
            if window.active == entry then return end

            if window.active then
                local old = window.active
                tween(old.canvas, { GroupTransparency = 1 })
                tween(old.button, { BackgroundColor3 = theme.Button, BackgroundTransparency = 0.5 })
                task.delay(SLOW, function()
                    if window.active ~= old then
                        old.canvas.Visible = false
                    end
                end)
            end

            window.active = entry
            entry.canvas.Visible = true
            tween(entry.canvas, { GroupTransparency = 0 })
            tween(entry.button, { BackgroundColor3 = theme.ButtonActive, BackgroundTransparency = 0.2 })
        end

        --------------------------------------------------------------------------
        -- window:tab(name) -> tab object with component methods attached
        --------------------------------------------------------------------------
        function window:tab(name)
            local entry = {}

            local tab = create("TextButton", {
                Name = name,
                Text = name,
                Size = UDim2.new(0.15, 0, 0.8, 0),
                BackgroundTransparency = 0.5,
                BackgroundColor3 = theme.Button,
                FontFace = font,
                TextScaled = true,
                TextColor3 = theme.Text,
                Parent = tabbar,
            }, {
                create("UICorner", { CornerRadius = UDim.new(0, 6) }),
                create("UIStroke", {
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Color = theme.Accent,
                    Transparency = 0.7,
                }),
            })
            entry.button = tab

            tab.MouseEnter:Connect(function()
                if window.active ~= entry then
                    tween(tab, { BackgroundColor3 = theme.ButtonHover, BackgroundTransparency = 0.3 })
                end
            end)
            tab.MouseLeave:Connect(function()
                if window.active ~= entry then
                    tween(tab, { BackgroundColor3 = theme.Button, BackgroundTransparency = 0.5 })
                end
            end)

            local canvas = create("CanvasGroup", {
                Name = name .. "Content",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                GroupTransparency = 1,
                Visible = false,
                Parent = content,
            })
            entry.canvas = canvas

                local scroll = create("ScrollingFrame", {
                    Name = "Items",
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = theme.Accent,
                    ScrollingDirection = Enum.ScrollingDirection.Y,
                    Parent = canvas,
                }, {
                    create("UIListLayout", {
                        Padding = UDim.new(0, 6),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    create("UIPadding", {
                        PaddingTop = UDim.new(0, 4),
                        PaddingLeft = UDim.new(0, 4),
                        PaddingRight = UDim.new(0, 4),
                        PaddingBottom = UDim.new(0, 4),
                    }),
                })
            entry.container = scroll

            tab.MouseButton1Click:Connect(function()
                show(entry)
            end)

            -- Context handed to every component builder.
            local ctx = {
                container = scroll,
                theme     = theme,
                shared    = shared,
                window    = window,
                entry     = entry,
            }
            entry.ctx = ctx

            -- Attach every registered component as a chainable method.
            for methodName, builder in pairs(shared.components or {}) do
                entry[methodName] = function(_, opts)
                    return builder(ctx, opts)
                end
            end

            table.insert(window.tabs, entry)
            if not window.active then
                show(entry)
            end
            return entry
        end

        return window
    end
end
