-- animations.lua
-- The motion layer for Cloud. Everything soft, slow, and weighted. Provides a
-- damped-spring solver (one shared RenderStepped driver), a library of slow
-- easing presets, and a deep set of reusable effects (ripple, hover lift, press
-- squish, pop, stagger reveal, breathing glow, shimmer, gradient sweep, number
-- count, progress drain, shake, color cycle). Components, tabs, and toasts all
-- pull their motion from here so the feel stays consistent everywhere.

return function(shared)
    local create      = shared.create
    local RunService  = shared.Services.RunService
    local TS          = shared.Services.TS

    local anim = {}
    shared.anim = anim

    ------------------------------------------------------------------------
    -- Easing presets. All on the slow, gentle side of the curve. delayTime
    -- and looping variants included for staggered reveals and idle motion.
    ------------------------------------------------------------------------
    local Q, S, C  = Enum.EasingStyle.Quad, Enum.EasingStyle.Sine, Enum.EasingStyle.Cubic
    local QUINT    = Enum.EasingStyle.Quint
    local BACK     = Enum.EasingStyle.Back
    local OUT, INOUT, IN = Enum.EasingDirection.Out, Enum.EasingDirection.InOut, Enum.EasingDirection.In

    local function info(t, style, dir, rc, rev, delay)
        return TweenInfo.new(t or 0.7, style or Q, dir or OUT, rc or 0, rev or false, delay or 0)
    end

    anim.ease = {
        soft     = info(0.70, Q, OUT),      -- the base drag easing
        slowSoft = info(1.00, Q, OUT),
        gentle   = info(0.45, S, OUT),
        glide    = info(0.90, QUINT, OUT),
        drift    = info(1.20, S, INOUT),
        settle   = info(0.80, C, OUT),
        softBack = info(0.80, BACK, OUT),   -- gentle overshoot
        pop      = info(0.45, BACK, OUT),
        snapIn   = info(0.35, Q, IN),
        sweep    = info(1.60, Enum.EasingStyle.Linear, OUT),
    }
    local ease = anim.ease

    function anim.info(...) return info(...) end

    -- Looping breathe info (reverses forever).
    function anim.loopInfo(t, style)
        return TweenInfo.new(t or 2.0, style or S, INOUT, -1, true, 0)
    end

    ------------------------------------------------------------------------
    -- tween wrapper that accepts a preset name, a TweenInfo, or a duration.
    ------------------------------------------------------------------------
    function anim.tween(obj, props, how)
        local tinfo
        if type(how) == "string" then
            tinfo = ease[how] or ease.soft
        elseif typeof(how) == "TweenInfo" then
            tinfo = how
        elseif type(how) == "number" then
            tinfo = info(how)
        else
            tinfo = ease.soft
        end
        local t = TS:Create(obj, tinfo, props)
        t:Play()
        return t
    end
    local tween = anim.tween

    ------------------------------------------------------------------------
    -- UIScale cache so repeated scale effects reuse one UIScale per object.
    ------------------------------------------------------------------------
    local scaleCache = setmetatable({}, { __mode = "k" })
    local function ensureScale(obj)
        local s = scaleCache[obj]
        if not s then
            s = create("UIScale", { Scale = 1, Parent = obj })
            scaleCache[obj] = s
        end
        return s
    end
    anim.ensureScale = ensureScale

    ------------------------------------------------------------------------
    -- Damped spring solver. One RenderStepped connection steps every live
    -- spring; settled springs are skipped. Gives weighted, natural motion
    -- for things that benefit from it (tab indicator, toast reflow, knobs).
    ------------------------------------------------------------------------
    local springs = {}
    local springDriverOn = false

    local Spring = {}
    Spring.__index = Spring

    function Spring.new(opts)
        opts = opts or {}
        local self = setmetatable({}, Spring)
        self.value     = opts.value or 0
        self.goal      = self.value
        self.velocity  = 0
        self.frequency = opts.frequency or 4   -- higher = snappier
        self.damping   = opts.damping or 1      -- 1 = critically damped, soft
        self.onStep    = opts.onStep or function() end
        self.epsilon   = opts.epsilon or 0.0005
        self.active    = false
        return self
    end

    function Spring:setGoal(g)
        self.goal = g
        if not self.active then
            self.active = true
            springs[self] = true
            anim._ensureDriver()
        end
    end

    function Spring:setValue(v)
        self.value = v
        self.velocity = 0
        self.onStep(v)
    end

    function Spring:step(dt)
        dt = math.min(dt, 1 / 30)
        local f = self.frequency * 2 * math.pi
        local c = 2 * self.damping * f
        local k = f * f
        local x = self.value - self.goal
        local accel = -k * x - c * self.velocity
        self.velocity = self.velocity + accel * dt
        self.value = self.value + self.velocity * dt
        if math.abs(self.value - self.goal) < self.epsilon and math.abs(self.velocity) < self.epsilon then
            self.value = self.goal
            self.velocity = 0
            self.active = false
            springs[self] = nil
            self.onStep(self.value)
            return false
        end
        self.onStep(self.value)
        return true
    end

    function anim._ensureDriver()
        if springDriverOn then return end
        springDriverOn = true
        RunService.RenderStepped:Connect(function(dt)
            for spring in pairs(springs) do
                spring:step(dt)
            end
        end)
    end

    function anim.spring(opts) return Spring.new(opts) end

    ------------------------------------------------------------------------
    -- Ripple: a soft circle blooming from the center (or a point) of a
    -- button, fading as it grows. Clips to the parent.
    ------------------------------------------------------------------------
    function anim.ripple(parent, theme, originScale)
        if not parent then return end
        parent.ClipsDescendants = true
        local o = originScale or 0.5
        local circle = create("Frame", {
            Name = "Ripple",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(o, 0, 0.5, 0),
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = theme.Accent,
            BackgroundTransparency = 0.55,
            BorderSizePixel = 0,
            ZIndex = 6,
            Parent = parent,
        }, {
            create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })
        tween(circle, { Size = UDim2.new(2.4, 0, 2.4, 0) }, ease.glide)
        local fade = tween(circle, { BackgroundTransparency = 1 }, ease.slowSoft)
        fade.Completed:Once(function()
            circle:Destroy()
        end)
    end

    ------------------------------------------------------------------------
    -- One-shot pop: a quick scale up then settle back, with gentle overshoot.
    ------------------------------------------------------------------------
    function anim.pop(obj, strength)
        local s = ensureScale(obj)
        s.Scale = 1 - (strength or 0.08)
        tween(s, { Scale = 1 }, ease.pop)
    end

    ------------------------------------------------------------------------
    -- Hover: lift (scale) + background warm + stroke brighten. Attaches to a
    -- button/frame's MouseEnter / MouseLeave. Pass the visual row to animate.
    ------------------------------------------------------------------------
    function anim.hover(button, row, theme, opts)
        opts = opts or {}
        local stroke = opts.stroke
        local scale = ensureScale(row)
        local restColor = opts.restColor or theme.Button
        local restTrans = opts.restTrans == nil and 0.5 or opts.restTrans
        button.MouseEnter:Connect(function()
            if opts.guard and opts.guard() then return end
            tween(row, { BackgroundColor3 = theme.ButtonHover, BackgroundTransparency = 0.3 }, ease.gentle)
            tween(scale, { Scale = 1.02 }, ease.softBack)
            if stroke then tween(stroke, { Transparency = 0.35 }, ease.gentle) end
        end)
        button.MouseLeave:Connect(function()
            if opts.guard and opts.guard() then return end
            tween(row, { BackgroundColor3 = restColor, BackgroundTransparency = restTrans }, ease.gentle)
            tween(scale, { Scale = 1 }, ease.settle)
            if stroke then tween(stroke, { Transparency = 0.7 }, ease.gentle) end
        end)
    end

    ------------------------------------------------------------------------
    -- Press: squish down on mouse-down, spring back on up/click.
    ------------------------------------------------------------------------
    function anim.press(button, row, theme)
        local scale = ensureScale(row)
        button.MouseButton1Down:Connect(function()
            tween(row, { BackgroundColor3 = theme.ButtonActive, BackgroundTransparency = 0.2 }, ease.snapIn)
            tween(scale, { Scale = 0.96 }, ease.snapIn)
        end)
        local function release()
            tween(row, { BackgroundColor3 = theme.ButtonHover, BackgroundTransparency = 0.3 }, ease.settle)
            tween(scale, { Scale = 1 }, ease.softBack)
        end
        button.MouseButton1Up:Connect(release)
        button.MouseLeave:Connect(release)
    end

    ------------------------------------------------------------------------
    -- Intro: a staggered pop-in for freshly created rows. Uses the ctx's
    -- running counter so a tab's components cascade in gently.
    ------------------------------------------------------------------------
    function anim.intro(obj, ctx)
        local idx = 0
        if ctx then
            ctx.introIndex = (ctx.introIndex or 0) + 1
            idx = ctx.introIndex
        end
        local s = ensureScale(obj)
        s.Scale = 0.9
        tween(s, { Scale = 1 }, info(0.6, BACK, OUT, 0, false, math.min(idx * 0.04, 0.4)))
    end

    ------------------------------------------------------------------------
    -- Staggered fade-in for a list of items (dropdown options on expand).
    ------------------------------------------------------------------------
    function anim.staggerFade(items, fromTrans, toTrans, perItem)
        for i, it in ipairs(items) do
            it.BackgroundTransparency = fromTrans
            tween(it, { BackgroundTransparency = toTrans },
                info(0.5, Q, OUT, 0, false, (i - 1) * (perItem or 0.05)))
        end
    end

    -- Stagger a pop-in (UIScale) across a list, preserving each item's own
    -- colours/transparency (used for dropdown options on expand).
    function anim.staggerPop(items, perItem)
        for i, it in ipairs(items) do
            local s = ensureScale(it)
            s.Scale = 0.8
            tween(s, { Scale = 1 }, info(0.55, BACK, OUT, 0, false, (i - 1) * (perItem or 0.05)))
        end
    end

    ------------------------------------------------------------------------
    -- Breathing glow on a UIStroke (idle accent shimmer). Returns the tween
    -- so callers can cancel it.
    ------------------------------------------------------------------------
    function anim.glowStroke(stroke, lo, hi, period)
        stroke.Transparency = hi or 0.7
        return tween(stroke, { Transparency = lo or 0.3 }, anim.loopInfo(period or 2.4))
    end

    -- Breathe any numeric property between two values forever.
    function anim.breathe(obj, prop, lo, hi, period)
        obj[prop] = hi
        return tween(obj, { [prop] = lo }, anim.loopInfo(period or 2.0))
    end

    ------------------------------------------------------------------------
    -- Gradient sweep / shimmer: animate a UIGradient offset across an object.
    ------------------------------------------------------------------------
    function anim.shimmer(obj, theme, period)
        local grad = create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.0, theme.Button),
                ColorSequenceKeypoint.new(0.5, theme.ButtonHover),
                ColorSequenceKeypoint.new(1.0, theme.Button),
            }),
            Offset = Vector2.new(-1, 0),
            Parent = obj,
        })
        tween(grad, { Offset = Vector2.new(1, 0) }, anim.loopInfo(period or 1.6))
        return grad
    end

    ------------------------------------------------------------------------
    -- Arrow rotate for expandable headers.
    ------------------------------------------------------------------------
    function anim.arrow(label, open)
        tween(label, { Rotation = open and 180 or 0 }, ease.softBack)
    end

    ------------------------------------------------------------------------
    -- Smooth expand/collapse of a holder's height.
    ------------------------------------------------------------------------
    function anim.expand(holder, open, fullHeight)
        tween(holder, { Size = UDim2.new(1, 0, 0, open and fullHeight or 0) },
            open and ease.glide or ease.settle)
    end

    ------------------------------------------------------------------------
    -- Number count: lerp a displayed number from current to target. Driven by
    -- a spring so it eases naturally. setter(value) is called each step.
    ------------------------------------------------------------------------
    function anim.countNumber(fromValue, toValue, setter, decimals)
        local mult = 10 ^ (decimals or 0)
        local sp = anim.spring({
            value = fromValue,
            frequency = 3.2,
            damping = 1,
            onStep = function(v)
                setter(math.floor(v * mult + 0.5) / mult)
            end,
        })
        sp:setGoal(toValue)
        return sp
    end

    ------------------------------------------------------------------------
    -- Progress drain: shrink a bar's width from full to zero over duration
    -- (used by notifications to show time remaining).
    ------------------------------------------------------------------------
    function anim.progress(bar, duration)
        bar.Size = UDim2.new(1, 0, bar.Size.Y.Scale, bar.Size.Y.Offset)
        return tween(bar, { Size = UDim2.new(0, 0, bar.Size.Y.Scale, bar.Size.Y.Offset) },
            info(duration or 4, Enum.EasingStyle.Linear, OUT))
    end

    ------------------------------------------------------------------------
    -- Shake: small horizontal wobble for invalid input / error feedback.
    ------------------------------------------------------------------------
    function anim.shake(obj, magnitude)
        local base = obj.Position
        local m = magnitude or 6
        local seq = {
            UDim2.new(base.X.Scale, base.X.Offset - m, base.Y.Scale, base.Y.Offset),
            UDim2.new(base.X.Scale, base.X.Offset + m, base.Y.Scale, base.Y.Offset),
            UDim2.new(base.X.Scale, base.X.Offset - m * 0.5, base.Y.Scale, base.Y.Offset),
            base,
        }
        local i = 0
        local function nextStep()
            i = i + 1
            if i > #seq then return end
            local t = tween(obj, { Position = seq[i] }, info(0.08, Q, OUT))
            t.Completed:Once(nextStep)
        end
        nextStep()
    end

    ------------------------------------------------------------------------
    -- Color cycle: loop a color property through a list of theme colors.
    ------------------------------------------------------------------------
    function anim.colorCycle(obj, prop, colors, perColor)
        local i = 1
        local function nextColor()
            i = i % #colors + 1
            local t = tween(obj, { [prop] = colors[i] }, info(perColor or 1.5, S, INOUT))
            t.Completed:Once(nextColor)
        end
        obj[prop] = colors[1]
        nextColor()
    end

    ------------------------------------------------------------------------
    -- Reveal a tab page: soft slide-up + scale pop together.
    ------------------------------------------------------------------------
    function anim.revealPage(page)
        page.Position = UDim2.new(0, 0, 0, 16)
        tween(page, { Position = UDim2.new(0, 0, 0, 0) }, ease.glide)
        local s = ensureScale(page)
        s.Scale = 0.985
        tween(s, { Scale = 1 }, ease.settle)
    end

    ------------------------------------------------------------------------
    -- Knob slide helper: spring a 0..1 alpha and map it onto a knob's
    -- horizontal position between two offsets. Returns a setter(alpha).
    ------------------------------------------------------------------------
    function anim.knobTrack(knob, fromOffset, toOffset)
        local sp = anim.spring({
            value = 0,
            frequency = 5,
            damping = 0.85,
            onStep = function(a)
                local x = fromOffset + (toOffset - fromOffset) * a
                knob.Position = UDim2.new(0, x, 0.5, 0)
            end,
        })
        return function(alpha) sp:setGoal(alpha) end
    end

    ------------------------------------------------------------------------
    -- Focus glow for textboxes: brighten a stroke while focused.
    ------------------------------------------------------------------------
    function anim.focusGlow(stroke, focused, theme)
        if focused then
            tween(stroke, { Transparency = 0.2, Color = theme.Accent }, ease.gentle)
        else
            tween(stroke, { Transparency = 0.7 }, ease.gentle)
        end
    end

    ------------------------------------------------------------------------
    -- Sequence: run a list of tween steps one after another. Each step is
    -- { obj, props, how }. Calls onDone after the last completes.
    ------------------------------------------------------------------------
    function anim.sequence(steps, onDone)
        local i = 0
        local function runNext()
            i = i + 1
            local step = steps[i]
            if not step then
                if onDone then onDone() end
                return
            end
            local t = tween(step[1], step[2], step[3])
            t.Completed:Once(runNext)
        end
        runNext()
    end

    ------------------------------------------------------------------------
    -- Generic fade-in: set each given transparency property to 1, then ease
    -- it back to its intended value. props = { TextTransparency = 0, ... }.
    ------------------------------------------------------------------------
    function anim.fadeIn(obj, props, how)
        for k in pairs(props) do obj[k] = 1 end
        tween(obj, props, how or ease.slowSoft)
    end

    function anim.fadeOut(obj, props, how, onDone)
        local goal = {}
        for k in pairs(props) do goal[k] = 1 end
        local t = tween(obj, goal, how or ease.settle)
        if onDone then t.Completed:Once(onDone) end
        return t
    end

    ------------------------------------------------------------------------
    -- Directional slide-in: nudge the object by (dx, dy) offset, then glide
    -- it home. Captures the object's current position as the destination.
    ------------------------------------------------------------------------
    function anim.slideIn(obj, dx, dy, how)
        local home = obj.Position
        obj.Position = UDim2.new(home.X.Scale, home.X.Offset + (dx or 0),
            home.Y.Scale, home.Y.Offset + (dy or 0))
        tween(obj, { Position = home }, how or ease.glide)
    end

    ------------------------------------------------------------------------
    -- Pulse: grow slightly, then settle back. Heavier than pop, for emphasis.
    ------------------------------------------------------------------------
    function anim.pulse(obj, strength)
        local s = ensureScale(obj)
        local up = 1 + (strength or 0.12)
        anim.sequence({
            { s, { Scale = up }, ease.softBack },
            { s, { Scale = 1 }, ease.settle },
        })
    end

    ------------------------------------------------------------------------
    -- Flash a property to a value, then ease it back to its resting value.
    ------------------------------------------------------------------------
    function anim.flash(obj, prop, flashValue, restValue, how)
        anim.sequence({
            { obj, { [prop] = flashValue }, ease.gentle },
            { obj, { [prop] = restValue }, how or ease.slowSoft },
        })
    end

    ------------------------------------------------------------------------
    -- Wobble: a soft side-to-side rotation that decays back to zero.
    ------------------------------------------------------------------------
    function anim.wobble(obj, degrees)
        local d = degrees or 6
        anim.sequence({
            { obj, { Rotation = -d }, ease.gentle },
            { obj, { Rotation = d * 0.6 }, ease.gentle },
            { obj, { Rotation = -d * 0.3 }, ease.gentle },
            { obj, { Rotation = 0 }, ease.softBack },
        })
    end

    ------------------------------------------------------------------------
    -- Loading spinner: a rotating accent arc. Returns a handle with :Stop().
    ------------------------------------------------------------------------
    function anim.spinner(parent, theme, size)
        local holder = create("Frame", {
            Name = "Spinner",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, size or 28, 0, size or 28),
            BackgroundTransparency = 1,
            Parent = parent,
        }, {
            create("UICorner", { CornerRadius = UDim.new(1, 0) }),
            create("UIStroke", { Thickness = 3, Color = theme.Accent, Transparency = 0.2 }),
            create("UIGradient", {
                Rotation = 0,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
            }),
        })
        local spin = anim.spring({
            value = 0, frequency = 0.4, damping = 0.18,
            onStep = function(v) holder.Rotation = v end,
        })
        spin:setGoal(360)
        local running = true
        local handle = {}
        function handle:Stop()
            running = false
            holder:Destroy()
        end
        RunService.RenderStepped:Connect(function()
            if running and holder.Parent then
                holder.Rotation = (holder.Rotation + 4) % 360
            end
        end)
        return handle, holder
    end

    ------------------------------------------------------------------------
    -- Typewriter: reveal a label's text one grapheme at a time by tweening
    -- MaxVisibleGraphemes. The full text is set immediately so it is always
    -- correct even if the tween is interrupted.
    ------------------------------------------------------------------------
    function anim.typewriter(label, text, duration)
        label.Text = text
        local count = #text
        label.MaxVisibleGraphemes = 0
        tween(label, { MaxVisibleGraphemes = count },
            info(duration or 0.6, Enum.EasingStyle.Linear, OUT)).Completed:Once(function()
            label.MaxVisibleGraphemes = -1
        end)
    end
end
