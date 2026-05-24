-- notifications.lua
-- Queued toast notifications. They slide in slow from the right, hold for
-- Duration, fade out, and the rest slide up to fill the gap. Installs
-- Cloud:notify onto the shared Cloud table.

return function(shared)
    local create = shared.create
    local tween  = shared.tween
    local font   = shared.font
    local CoreGui = shared.Services.CoreGui
    local Cloud  = shared.Cloud
    local SLOW   = shared.SLOW
    local anim   = shared.anim

    local TOAST_W = 260
    local TOAST_H = 64
    local GAP = 10
    local MARGIN = 16

    local gui = create("ScreenGui", {
        Name = ".CloudNotifications",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
        Parent = CoreGui,
    })

    local active = {}

    local function reflow()
        for i, toast in ipairs(active) do
            local y = -MARGIN - (i - 1) * (TOAST_H + GAP)
            tween(toast.frame, { Position = UDim2.new(1, -MARGIN, 1, y) })
        end
    end

    function Cloud:notify(opts)
        opts = opts or {}
        local theme = opts.Theme or shared.themes.Cloud
        local duration = opts.Duration or 4

        local frame = create("Frame", {
            Name = "Toast",
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, TOAST_W + MARGIN, 1, -MARGIN),
            Size = UDim2.new(0, TOAST_W, 0, TOAST_H),
            BackgroundColor3 = theme.Notification,
            BackgroundTransparency = 0.1,
            BorderSizePixel = 0,
            Parent = gui,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 8) }),
            create("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = theme.Accent,
                Transparency = 0.5,
            }),
        })

        create("Frame", {
            Name = "Bar",
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 4, 1, 0),
            BackgroundColor3 = theme.NotificationBar,
            BorderSizePixel = 0,
            Parent = frame,
        }, {
            create("UICorner", { CornerRadius = UDim.new(0, 4) }),
        })

        create("TextLabel", {
            Name = "Title",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 8),
            Size = UDim2.new(1, -22, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = opts.Title or "Notification",
            FontFace = font,
            TextSize = 17,
            TextColor3 = theme.Text,
            Parent = frame,
        })
        local body = create("TextLabel", {
            Name = "Body",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 28),
            Size = UDim2.new(1, -22, 1, -34),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Text = opts.Text or "",
            FontFace = font,
            TextSize = 14,
            TextColor3 = theme.TextDim,
            Parent = frame,
        })
        if anim then
            anim.typewriter(body, opts.Text or "", math.min((duration or 4) * 0.35, 1.4))
        end

        -- Progress bar draining along the bottom edge over Duration.
        local progress = create("Frame", {
            Name = "Progress",
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = theme.NotificationBar,
            BorderSizePixel = 0,
            Parent = frame,
        })

        local toast = { frame = frame }
        table.insert(active, 1, toast)
        reflow()

        if anim then
            local sc = anim.ensureScale(frame)
            sc.Scale = 0.85
            anim.tween(sc, { Scale = 1 }, "softBack")
            anim.progress(progress, duration)
        end

        local dismissed = false
        local function dismiss()
            if dismissed then return end
            dismissed = true
            local idx = table.find(active, toast)
            if idx then table.remove(active, idx) end
            tween(frame, { Position = UDim2.new(1, TOAST_W + MARGIN, frame.Position.Y.Scale, frame.Position.Y.Offset) })
            tween(frame, { BackgroundTransparency = 1 })
            task.delay(SLOW, function()
                frame:Destroy()
            end)
            reflow()
        end

        task.delay(duration, dismiss)
        return { Dismiss = dismiss }
    end
end
