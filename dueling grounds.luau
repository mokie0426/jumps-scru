-- ═══════════════════════════════════════════════════════════════════════════
-- DUELING GROUNDS TRAINER — Complete Single-File Luau Script (FIXED)
-- Mobile-first (Android + PC). No external modules required.
-- ═══════════════════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")
local Camera            = Workspace.CurrentCamera

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

for _, name in ipairs({
    "DGTrainerGui", "ParryTrainerGui", "DodgeTrainerGui",
    "CooldownHudGui", "TargetHighlightGui"
}) do
    local g = PlayerGui:FindFirstChild(name)
    if g then g:Destroy() end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PALETTE + SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════
local P = {
    bg      = Color3.fromRGB(14, 10, 22),
    panel   = Color3.fromRGB(22, 16, 32),
    panel2  = Color3.fromRGB(32, 24, 48),
    stroke  = Color3.fromRGB(90, 60, 160),
    accent  = Color3.fromRGB(180, 120, 255),
    accent2 = Color3.fromRGB(110, 60, 200),
    text    = Color3.fromRGB(232, 226, 255),
    textDim = Color3.fromRGB(150, 140, 180),
    on      = Color3.fromRGB(120, 200, 140),
    off     = Color3.fromRGB(70, 70, 90),
    danger  = Color3.fromRGB(220, 80, 100),
}

local Settings = {
    uiScale         = 1.0,
    popupSize       = 52,
    popupOpacity    = 0.85,
    fov             = 70,
    walkSpeed       = 16,
    jumpPower       = 50,
    highlightColor  = Color3.fromRGB(160, 90, 255),
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TOUCH CONTROLLER
-- ═══════════════════════════════════════════════════════════════════════════
local Touch = {}

function Touch.makeDraggable(frame, handle, opts)
    opts = opts or {}
    local constrain  = opts.constrain ~= false
    local onStart    = opts.onStart
    local onEnd      = opts.onEnd
    local dragging   = false
    local startInput = Vector2.new(0, 0)
    local startPos   = frame.Position
    local moved      = 0
    local startTime  = 0
    local conns      = {}

    table.insert(conns, handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            startInput = Vector2.new(input.Position.X, input.Position.Y)
            startPos   = frame.Position
            moved      = 0
            startTime  = tick()
            if onStart then pcall(onStart) end
        end
    end))

    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local cur   = Vector2.new(input.Position.X, input.Position.Y)
            local delta = cur - startInput
            moved = math.max(moved, delta.Magnitude)
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y
            if constrain then
                local vp = Camera.ViewportSize
                local sz = frame.AbsoluteSize
                newX = math.clamp(newX, 0, math.max(0, vp.X - sz.X))
                newY = math.clamp(newY, 0, math.max(0, vp.Y - sz.Y))
            end
            frame.Position = UDim2.new(0, newX, 0, newY)
        end
    end))

    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                if onEnd then pcall(onEnd, moved, tick() - startTime) end
            end
        end
    end))

    return {
        Disconnect = function()
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        end,
    }
end

function Touch.makeTapDraggable(frame, handle, onTap, opts)
    return Touch.makeDraggable(frame, handle, {
        constrain = opts and opts.constrain,
        onEnd = function(moved, dt)
            if moved < 12 and dt < 0.35 then
                if onTap then pcall(onTap) end
            end
        end,
    })
end

function Touch.clampToScreen(frame)
    local vp  = Camera.ViewportSize
    local pos = frame.AbsolutePosition
    local sz  = frame.AbsoluteSize
    local x = math.clamp(pos.X, 0, math.max(0, vp.X - sz.X))
    local y = math.clamp(pos.Y, 0, math.max(0, vp.Y - sz.Y))
    frame.Position = UDim2.new(0, x, 0, y)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════
local Notify = {}
local notifyContainer

function Notify:Init(parent)
    local c = Instance.new("Frame")
    c.Name = "NotificationContainer"
    c.Size = UDim2.new(0, 300, 0, 300)
    c.Position = UDim2.new(1, -312, 0, 12)
    c.BackgroundTransparency = 1
    c.ZIndex = 500
    c.Parent = parent
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = c
    notifyContainer = c
end

local NOTIF_COLORS = {
    info    = Color3.fromRGB(160, 90, 255),
    success = Color3.fromRGB(120, 200, 140),
    warn    = Color3.fromRGB(240, 170, 60),
    error   = Color3.fromRGB(230, 80, 80),
}

function Notify:Show(msg, kind)
    if not notifyContainer or not notifyContainer.Parent then return end
    kind = kind or "info"
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 42)
    f.BackgroundColor3 = Color3.fromRGB(22, 18, 30)
    f.BorderSizePixel = 0
    f.ZIndex = 501
    f.Parent = notifyContainer
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = f
    local s = Instance.new("UIStroke")
    s.Color = NOTIF_COLORS[kind] or NOTIF_COLORS.info
    s.Thickness = 1
    s.Parent = f
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = msg
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.fromRGB(235, 230, 255)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextWrapped = true
    lbl.ZIndex = 502
    lbl.Parent = f
    task.delay(3, function()
        if not f or not f.Parent then return end
        TweenService:Create(f, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
        task.wait(0.3)
        if f and f.Parent then f:Destroy() end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UICONTROLLER
-- ═══════════════════════════════════════════════════════════════════════════
local UI = {}
UI.__index = UI

local TAB_NAMES = { "Combat", "Visuals", "Movement", "Settings", "Utilities" }

function UI.new(parent)
    local self = setmetatable({}, UI)
    self.Parent      = parent
    self.Connections = {}
    self.TabButtons  = {}
    self.TabFrames   = {}
    self.TabItems    = {}
    self.ActiveTab   = nil
    self.Minimized   = false
    self.SearchQuery = ""
    self:_build()
    return self
end

function UI:_track(c)
    table.insert(self.Connections, c)
    return c
end

function UI:_build()
    local gui = Instance.new("ScreenGui")
    gui.Name = "DGTrainerGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 800
    gui.Parent = self.Parent
    self.ScreenGui = gui

    local panel = Instance.new("Frame")
    panel.Name = "MainPanel"
    panel.Size = UDim2.new(0, 460, 0, 580)
    panel.Position = UDim2.new(0.5, -230, 0.5, -290)
    panel.BackgroundColor3 = P.panel
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Parent = gui
    self.MainPanel = panel

    local scale = Instance.new("UIScale")
    scale.Parent = panel
    self.UIScale = scale

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = P.stroke
    stroke.Thickness = 1.5
    stroke.Parent = panel

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundColor3 = P.bg
    titleBar.BorderSizePixel = 0
    titleBar.Parent = panel
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 12); tc.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -110, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚔  Dueling Grounds Trainer"
    title.TextColor3 = P.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    self:_titleButton(titleBar, "–", UDim2.new(1, -86, 0, 8), function() self:Minimize() end, P.panel2)
    self:_titleButton(titleBar, "✕", UDim2.new(1, -44, 0, 8), function() self:Close() end, P.danger)

    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, -16, 0, 36)
    tabBar.Position = UDim2.new(0, 8, 0, 52)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = panel
    self.TabBar = tabBar

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabBar

    local searchFrame = Instance.new("Frame")
    searchFrame.Size = UDim2.new(1, -16, 0, 34)
    searchFrame.Position = UDim2.new(0, 8, 0, 96)
    searchFrame.BackgroundColor3 = P.panel2
    searchFrame.BorderSizePixel = 0
    searchFrame.Parent = panel
    local sfc = Instance.new("UICorner"); sfc.CornerRadius = UDim.new(0, 8); sfc.Parent = searchFrame

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -16, 1, 0)
    searchBox.Position = UDim2.new(0, 8, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.PlaceholderText = "🔍  Search features..."
    searchBox.PlaceholderColor3 = P.textDim
    searchBox.Text = ""
    searchBox.TextColor3 = P.text
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 13
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = searchFrame
    self:_track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self.SearchQuery = string.lower(searchBox.Text)
        self:_applySearch()
    end))

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -142)
    content.Position = UDim2.new(0, 8, 0, 138)
    content.BackgroundTransparency = 1
    content.Parent = panel
    self.Content = content

    for _, name in ipairs(TAB_NAMES) do
        self:_addTab(name)
    end
    self:ShowTab("Combat")

    self.DragController = Touch.makeDraggable(panel, titleBar, { constrain = true })

    self:_updateScale()
    self:_track(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        self:_updateScale()
    end))

    self:_track(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if self.Minimized then
                self:Restore()
            elseif self.MainPanel.Visible then
                self:Minimize()
            end
        end
    end))
end

function UI:_updateScale()
    local vp = Camera.ViewportSize
    local base
    if vp.X < 600 or vp.Y < 700 then
        base = math.clamp(math.min(vp.X / 480, vp.Y / 640), 0.6, 1.0)
    else
        base = math.clamp(math.min(vp.X / 900, vp.Y / 720), 0.85, 1.15)
    end
    self.UIScale.Scale = base * (Settings.uiScale or 1)
end

function UI:_titleButton(parent, text, pos, cb, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 34, 0, 28)
    b.Position = pos
    b.BackgroundColor3 = color or P.panel2
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = P.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = b
    self:_track(b.MouseButton1Click:Connect(function() if cb then pcall(cb) end end))
    return b
end

function UI:_addTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 82, 1, 0)
    btn.BackgroundColor3 = P.panel2
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = P.textDim
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = self.TabBar
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn

    self:_track(btn.MouseButton1Click:Connect(function() self:ShowTab(name) end))

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 6
    content.ScrollBarImageColor3 = P.accent
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Visible = false
    content.Parent = self.Content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = content

    self.TabButtons[name] = btn
    self.TabFrames[name]  = content
    self.TabItems[name]   = {}
end

function UI:ShowTab(name)
    if not self.TabFrames[name] then return end
    for tabName, frame in pairs(self.TabFrames) do
        local active = (tabName == name)
        frame.Visible = active
        local btn = self.TabButtons[tabName]
        if btn then
            btn.BackgroundColor3 = active and P.accent2 or P.panel2
            btn.TextColor3 = active and P.text or P.textDim
        end
    end
    self.ActiveTab = name
    self:_applySearch()
end

function UI:GetTabFrame(name) return self.TabFrames[name] end

function UI:_registerItem(frame, text)
    local tab = self.ActiveTab
    if not tab then return end
    table.insert(self.TabItems[tab], { frame = frame, text = string.lower(text) })
end

function UI:_applySearch()
    local q = self.SearchQuery
    for _, items in pairs(self.TabItems) do
        for _, item in ipairs(items) do
            if item.frame and item.frame.Parent then
                item.frame.Visible = (q == "") or (item.text:find(q, 1, true) ~= nil)
            end
        end
    end
end

function UI:CreateHeader(text)
    local frame = self.TabFrames[self.ActiveTab]
    if not frame then return end
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = P.accent
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    self:_registerItem(lbl, text)
    return lbl
end

function UI:CreateToggle(label, default, cb)
    local frame = self.TabFrames[self.ActiveTab]
    if not frame then return end
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 44)
    row.BackgroundColor3 = P.panel2
    row.BorderSizePixel = 0
    row.Parent = frame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -110, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = P.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 76, 0, 28)
    btn.Position = UDim2.new(1, -86, 0.5, -14)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = row
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 14); tc.Parent = btn

    local state = default and true or false
    local function render()
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and P.on or P.off
        btn.TextColor3 = P.text
    end
    render()

    self:_track(btn.MouseButton1Click:Connect(function()
        state = not state
        render()
        if cb then pcall(cb, state) end
    end))

    self:_registerItem(row, label)
    return {
        Set = function(_, v) state = v and true or false; render() end,
        Get = function() return state end,
    }
end

function UI:CreateButton(label, cb, color)
    local frame = self.TabFrames[self.ActiveTab]
    if not frame then return end
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 40)
    btn.BackgroundColor3 = color or P.accent2
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = P.text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.Parent = frame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = btn
    self:_track(btn.MouseButton1Click:Connect(function() if cb then pcall(cb) end end))
    self:_registerItem(btn, label)
    return btn
end

function UI:CreateSlider(label, minV, maxV, defaultV, cb)
    local frame = self.TabFrames[self.ActiveTab]
    if not frame then return end
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 54)
    row.BackgroundColor3 = P.panel2
    row.BorderSizePixel = 0
    row.Parent = frame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 0, 20)
    lbl.Position = UDim2.new(0, 14, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.format("%s: %.2f", label, defaultV)
    lbl.TextColor3 = P.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 14)
    track.Position = UDim2.new(0, 14, 0, 30)
    track.BackgroundColor3 = P.bg
    track.BorderSizePixel = 0
    track.Parent = row
    local tcc = Instance.new("UICorner"); tcc.CornerRadius = UDim.new(0, 7); tcc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = P.accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 7); fc.Parent = fill

    local value = defaultV
    local function render()
        local alpha = (value - minV) / (maxV - minV)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        lbl.Text = string.format("%s: %.2f", label, value)
    end
    render()

    local isDrag = false
    local function applyAt(screenX)
        local ap = track.AbsolutePosition
        local as = track.AbsoluteSize
        if as.X <= 0 then return end
        local rel = math.clamp((screenX - ap.X) / as.X, 0, 1)
        value = minV + (maxV - minV) * rel
        render()
        if cb then pcall(cb, value) end
    end

    self:_track(track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            isDrag = true
            applyAt(input.Position.X)
        end
    end))
    self:_track(UserInputService.InputChanged:Connect(function(input)
        if not isDrag then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            applyAt(input.Position.X)
        end
    end))
    self:_track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            isDrag = false
        end
    end))

    self:_registerItem(row, label)
    return {
        Set = function(_, v) value = math.clamp(v, minV, maxV); render() end,
        Get = function() return value end,
    }
end

function UI:CreateDropdown(label, options, defaultIdx, cb)
    local frame = self.TabFrames[self.ActiveTab]
    if not frame then return end
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 44)
    row.BackgroundColor3 = P.panel2
    row.BorderSizePixel = 0
    row.Parent = frame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -170, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = P.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local drop = Instance.new("TextButton")
    drop.Size = UDim2.new(0, 140, 0, 32)
    drop.Position = UDim2.new(1, -150, 0.5, -16)
    drop.BackgroundColor3 = P.bg
    drop.BorderSizePixel = 0
    drop.Text = tostring(options[defaultIdx] or "")
    drop.TextColor3 = P.text
    drop.Font = Enum.Font.Gotham
    drop.TextSize = 12
    drop.Parent = row
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0, 6); dc.Parent = drop

    local idx = defaultIdx or 1
    self:_track(drop.MouseButton1Click:Connect(function()
        idx = idx + 1
        if idx > #options then idx = 1 end
        drop.Text = tostring(options[idx])
        if cb then pcall(cb, options[idx], idx) end
    end))

    self:_registerItem(row, label)
    return {
        Set = function(_, i) idx = math.clamp(i, 1, #options); drop.Text = tostring(options[idx]) end,
        Get = function() return options[idx], idx end,
    }
end

function UI:Minimize()
    if not self.MainPanel or not self.MainPanel.Visible then return end
    self.MainPanel.Visible = false
    self.Minimized = true
    if self.OnMinimize then pcall(self.OnMinimize) end
end

function UI:Restore()
    if not self.MainPanel or self.MainPanel.Visible then return end
    self.MainPanel.Visible = true
    self.Minimized = false
    if self.OnRestore then pcall(self.OnRestore) end
end

function UI:Close()
    if self.OnClose then pcall(self.OnClose) end
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    if self.DragController then self.DragController:Disconnect() end
    if self.ScreenGui then self.ScreenGui:Destroy() end
    self.Connections = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FLOATING BUTTON
-- ═══════════════════════════════════════════════════════════════════════════
local Floating = {}
Floating.__index = Floating

function Floating.new(parent, onTap)
    local self = setmetatable({}, Floating)
    self.OnTap = onTap
    self.Size = Settings.popupSize

    local btn = Instance.new("TextButton")
    btn.Name = "FloatingButton"
    btn.Size = UDim2.new(0, self.Size, 0, self.Size)
    btn.Position = UDim2.new(0, 20, 0, 200)
    btn.BackgroundColor3 = Color3.fromRGB(24, 18, 36)
    btn.BackgroundTransparency = 1 - Settings.popupOpacity
    btn.BorderSizePixel = 0
    btn.Text = "⚔"
    btn.TextColor3 = P.text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = math.floor(self.Size * 0.5)
    btn.AutoButtonColor = false
    btn.Visible = false
    btn.ZIndex = 900
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(180, 120, 255)
    stroke.Thickness = 2
    stroke.Parent = btn

    self.Button = btn
    self.Drag = Touch.makeTapDraggable(btn, btn, function()
        if self.OnTap then pcall(self.OnTap) end
    end, { constrain = true })

    self._vpConn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if self.Button and self.Button.Visible then Touch.clampToScreen(self.Button) end
    end)
    return self
end

function Floating:Show()
    if not self.Button then return end
    self.Button.Visible = true
    Touch.clampToScreen(self.Button)
    TweenService:Create(self.Button, TweenInfo.new(0.15), {
        BackgroundTransparency = 1 - Settings.popupOpacity,
        Size = UDim2.new(0, self.Size, 0, self.Size),
    }):Play()
end

function Floating:Hide()
    if not self.Button then return end
    TweenService:Create(self.Button, TweenInfo.new(0.15), {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, self.Size * 0.7, 0, self.Size * 0.7),
    }):Play()
    task.delay(0.16, function()
        if self.Button and self.Button.Parent then self.Button.Visible = false end
    end)
end

function Floating:SetSize(sz)
    self.Size = sz
    if self.Button then
        self.Button.Size = UDim2.new(0, sz, 0, sz)
        self.Button.TextSize = math.floor(sz * 0.5)
    end
end

function Floating:SetOpacity(op)
    if self.Button and self.Button.Visible then
        self.Button.BackgroundTransparency = 1 - op
    end
end

function Floating:Destroy()
    if self.Drag then self.Drag:Disconnect() end
    if self._vpConn then self._vpConn:Disconnect() end
    if self.Button then self.Button:Destroy() end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMBAT TRAINER
-- ═══════════════════════════════════════════════════════════════════════════
local Combat = {}
Combat.__index = Combat

function Combat.new(ui)
    local self = setmetatable({}, Combat)
    self.UI = ui
    self.Connections = {}
    self.ParryGui   = nil
    self.ParryConns = {}
    self.DodgeGui   = nil
    self.DodgeConns = {}
    self.CooldownGui   = nil
    self.CooldownConns = {}
    self.State = {
        Difficulty = 1,
        HitCount = 0,
        Combo = 0,
    }
    self:_buildTab()
    return self
end

function Combat:_track(c)
    table.insert(self.Connections, c)
    return c
end

function Combat:_trackParry(c) table.insert(self.ParryConns, c); return c end
function Combat:_trackDodge(c) table.insert(self.DodgeConns, c); return c end
function Combat:_trackCooldown(c) table.insert(self.CooldownConns, c); return c end

function Combat:_buildTab()
    if not self then return end
    local ui = self.UI
    if not ui then return end
    ui:ShowTab("Combat")

    ui:CreateHeader("— Training Tools —")

    ui:CreateToggle("Parry Timing Trainer", false, function(on)
        if on then self:_startParry() else self:_stopParry() end
    end)

    ui:CreateToggle("Dodge Timing Trainer", false, function(on)
        if on then self:_startDodge() else self:_stopDodge() end
    end)

    ui:CreateToggle("Attack Cooldown HUD", false, function(on)
        if on then self:_startCooldown() else self:_stopCooldown() end
    end)

    ui:CreateSlider("Practice Difficulty (1-5)", 1, 5, 1, function(v)
        self.State.Difficulty = math.floor(v + 0.5)
    end)

    ui:CreateHeader("— Stats —")
    self.StatLabel = ui:CreateHeader("Hits: 0   |   Combo: 0")

    ui:CreateButton("Reset Stats", function()
        self.State.HitCount = 0
        self.State.Combo = 0
        self:_updateStats()
        Notify:Show("Stats reset", "success")
    end)

    ui:CreateButton("Teleport to Nearest Target", function()
        self:_lockNearestTarget()
    end)

    ui:CreateHeader("— Combat Log —")
    local logFrame = Instance.new("ScrollingFrame")
    logFrame.Size = UDim2.new(1, -8, 0, 160)
    logFrame.BackgroundColor3 = P.bg
    logFrame.BorderSizePixel = 0
    logFrame.ScrollBarThickness = 4
    logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    logFrame.Parent = ui:GetTabFrame("Combat")
    local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, 6); lc.Parent = logFrame
    local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 2); ll.Parent = logFrame
    self.LogFrame = logFrame
end

function Combat:_log(msg)
    if not self.LogFrame or not self.LogFrame.Parent then return end
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -8, 0, 16)
    l.BackgroundTransparency = 1
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(180, 200, 230)
    l.Font = Enum.Font.Code
    l.TextSize = 11
    l.Text = "> " .. msg
    l.Parent = self.LogFrame
    print("[DGTrainer/Combat]", msg)
end

function Combat:_updateStats()
    if self.StatLabel and self.StatLabel.Parent then
        self.StatLabel.Text = string.format("Hits: %d   |   Combo: %d",
            self.State.HitCount, self.State.Combo)
    end
end

function Combat:_startParry()
    self:_stopParry()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ParryTrainerGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 850
    gui.Parent = PlayerGui
    self.ParryGui = gui

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 360, 0, 60)
    bar.Position = UDim2.new(0.5, -180, 0.82, 0)
    bar.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.Parent = gui
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 8); bc.Parent = bar
    local bs = Instance.new("UIStroke"); bs.Color = P.accent; bs.Thickness = 2; bs.Parent = bar
    self:_trackParry(Touch.makeDraggable(bar, bar, { constrain = true }))

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -16, 0, 18)
    hint.Position = UDim2.new(0, 8, 0, 4)
    hint.BackgroundTransparency = 1
    hint.Text = "SPACE / tap bar when indicator enters green zone"
    hint.TextColor3 = Color3.fromRGB(200, 180, 255)
    hint.Font = Enum.Font.GothamBold
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = bar

    local zone = Instance.new("Frame")
    zone.Size = UDim2.new(0.16, 0, 0, 20)
    zone.Position = UDim2.new(0.42, 0, 0, 28)
    zone.BackgroundColor3 = Color3.fromRGB(120, 200, 140)
    zone.BackgroundTransparency = 0.35
    zone.BorderSizePixel = 0
    zone.Parent = bar
    local zc = Instance.new("UICorner"); zc.CornerRadius = UDim.new(0, 4); zc.Parent = zone

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 4, 0, 20)
    indicator.Position = UDim2.new(0, 0, 0, 28)
    indicator.BackgroundColor3 = Color3.fromRGB(220, 130, 255)
    indicator.BorderSizePixel = 0
    indicator.Parent = bar

    local progress = 0
    local speed = 0.9 + self.State.Difficulty * 0.25
    local resolved = false

    local function resolve(hit)
        if resolved then return end
        resolved = true
        if hit then
            self.State.HitCount = self.State.HitCount + 1
            self.State.Combo = self.State.Combo + 1
            self:_log("Parry HIT! Combo: " .. self.State.Combo)
            zone.BackgroundColor3 = Color3.fromRGB(140, 255, 160)
        else
            self.State.Combo = 0
            self:_log("Parry MISS")
            zone.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
        end
        self:_updateStats()
        task.delay(0.4, function()
            if gui.Parent then
                progress = 0
                resolved = false
                zone.BackgroundColor3 = Color3.fromRGB(120, 200, 140)
            end
        end)
    end

    self:_trackParry(RunService.Heartbeat:Connect(function(dt)
        if not gui.Parent or resolved then return end
        progress = progress + dt * speed
        if progress > 1 then
            progress = 0
            resolve(false)
            return
        end
        indicator.Position = UDim2.new(progress, 0, 0, 28)
    end))

    self:_trackParry(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Space then
            resolve(progress >= 0.42 and progress <= 0.58)
        end
    end))

    self:_trackParry(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            resolve(progress >= 0.42 and progress <= 0.58)
        end
    end))
end

function Combat:_stopParry()
    if self.ParryGui then self.ParryGui:Destroy(); self.ParryGui = nil end
    for _, c in ipairs(self.ParryConns) do pcall(function() c:Disconnect() end) end
    self.ParryConns = {}
end

function Combat:_startDodge()
    self:_stopDodge()
    local gui = Instance.new("ScreenGui")
    gui.Name = "DodgeTrainerGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 850
    gui.Parent = PlayerGui
    self.DodgeGui = gui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 340, 0, 80)
    panel.Position = UDim2.new(0.5, -170, 0.72, 0)
    panel.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Parent = gui
    local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 8); pc.Parent = panel
    local ps = Instance.new("UIStroke"); ps.Color = P.accent; ps.Thickness = 2; ps.Parent = panel
    self:_trackDodge(Touch.makeDraggable(panel, panel, { constrain = true }))

    local prompt = Instance.new("TextLabel")
    prompt.Size = UDim2.new(1, -16, 0, 24)
    prompt.Position = UDim2.new(0, 8, 0, 6)
    prompt.BackgroundTransparency = 1
    prompt.Text = "Waiting..."
    prompt.TextColor3 = Color3.fromRGB(200, 180, 255)
    prompt.Font = Enum.Font.GothamBold
    prompt.TextSize = 14
    prompt.TextXAlignment = Enum.TextXAlignment.Left
    prompt.Parent = panel

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -16, 0, 12)
    track.Position = UDim2.new(0, 8, 0, 38)
    track.BackgroundColor3 = P.bg
    track.BorderSizePixel = 0
    track.Parent = panel
    local tcc = Instance.new("UICorner"); tcc.CornerRadius = UDim.new(0, 6); tcc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(220, 100, 100)
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 6); fc.Parent = fill

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -16, 0, 16)
    hint.Position = UDim2.new(0, 8, 0, 58)
    hint.BackgroundTransparency = 1
    hint.Text = "Press Q / tap when 'DODGE!' appears"
    hint.TextColor3 = Color3.fromRGB(150, 140, 180)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = panel

    local incoming = false
    local incomingTimer = 0
    local incomingTotal = math.max(0.4, 1.2 - self.State.Difficulty * 0.1)
    local pauseTimer = 1.5
    local resolved = false

    local function trigger()
        incoming = true
        resolved = false
        incomingTimer = incomingTotal
        prompt.Text = "⚡ DODGE!"
        prompt.TextColor3 = Color3.fromRGB(255, 220, 130)
        fill.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
    end

    local function resolve(hit)
        if resolved or not incoming then return end
        resolved = true
        incoming = false
        if hit then
            self.State.HitCount = self.State.HitCount + 1
            self.State.Combo = self.State.Combo + 1
            self:_log("Dodge HIT! Combo: " .. self.State.Combo)
            prompt.Text = "✔ Dodged!"
            prompt.TextColor3 = Color3.fromRGB(140, 255, 160)
        else
            self.State.Combo = 0
            self:_log("Dodge MISS")
            prompt.Text = "✘ Failed to dodge"
            prompt.TextColor3 = Color3.fromRGB(255, 120, 120)
        end
        self:_updateStats()
        fill.Size = UDim2.new(0, 0, 1, 0)
        pauseTimer = math.max(0.6, 1.8 - self.State.Difficulty * 0.15)
    end

    self:_trackDodge(RunService.Heartbeat:Connect(function(dt)
        if not gui.Parent then return end
        if incoming then
            incomingTimer = incomingTimer - dt
            local alpha = math.clamp(incomingTimer / incomingTotal, 0, 1)
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            if incomingTimer <= 0 then resolve(false) end
        else
            pauseTimer = pauseTimer - dt
            if pauseTimer <= 0 then trigger() end
        end
    end))

    self:_trackDodge(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Q then
            resolve(incomingTimer <= incomingTotal * 0.7)
        end
    end))

    self:_trackDodge(panel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            resolve(incomingTimer <= incomingTotal * 0.7)
        end
    end))
end

function Combat:_stopDodge()
    if self.DodgeGui then self.DodgeGui:Destroy(); self.DodgeGui = nil end
    for _, c in ipairs(self.DodgeConns) do pcall(function() c:Disconnect() end) end
    self.DodgeConns = {}
end

function Combat:_startCooldown()
    self:_stopCooldown()
    local gui = Instance.new("ScreenGui")
    gui.Name = "CooldownHudGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 840
    gui.Parent = PlayerGui
    self.CooldownGui = gui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 240, 0, 50)
    panel.Position = UDim2.new(0.5, -120, 0.62, 0)
    panel.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Parent = gui
    local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 8); pc.Parent = panel
    local ps = Instance.new("UIStroke"); ps.Color = P.accent; ps.Thickness = 2; ps.Parent = panel
    self:_trackCooldown(Touch.makeDraggable(panel, panel, { constrain = true }))

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 0, 20)
    lbl.Position = UDim2.new(0, 8, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Attack Cooldown — Ready"
    lbl.TextColor3 = P.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = panel

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -16, 0, 12)
    track.Position = UDim2.new(0, 8, 0, 30)
    track.BackgroundColor3 = P.bg
    track.BorderSizePixel = 0
    track.Parent = panel
    local tcc = Instance.new("UICorner"); tcc.CornerRadius = UDim.new(0, 6); tcc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(140, 255, 160)
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 6); fc.Parent = fill

    local cooldown = 0.6
    local timer = 0

    self:_trackCooldown(RunService.Heartbeat:Connect(function(dt)
        if not gui.Parent then return end
        timer = math.max(0, timer - dt)
        local alpha = 1 - (timer / cooldown)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        if timer <= 0 then
            fill.BackgroundColor3 = Color3.fromRGB(140, 255, 160)
            lbl.Text = "Attack Cooldown — Ready"
        else
            fill.BackgroundColor3 = Color3.fromRGB(140, 200, 255)
            lbl.Text = string.format("Attack Cooldown — %.2fs", timer)
        end
    end))

    self:_trackCooldown(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if timer <= 0 then timer = cooldown end
        end
    end))
end

function Combat:_stopCooldown()
    if self.CooldownGui then self.CooldownGui:Destroy(); self.CooldownGui = nil end
    for _, c in ipairs(self.CooldownConns) do pcall(function() c:Disconnect() end) end
    self.CooldownConns = {}
end

function Combat:_lockNearestTarget()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then Notify:Show("No character", "warn"); return end

    local best, bestDist = nil, math.huge
    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") then
            local n = string.lower(model.Name)
            if (n:find("dummy") or n:find("target")) and model:FindFirstChild("HumanoidRootPart") then
                local d = (model.HumanoidRootPart.Position - root.Position).Magnitude
                if d < bestDist then bestDist = d; best = model end
            end
        end
    end

    if best then
        root.CFrame = CFrame.new(best.HumanoidRootPart.Position + Vector3.new(0, 0, 5),
            best.HumanoidRootPart.Position)
        self:_log(string.format("Locked '%s' at %.1f studs", best.Name, bestDist))
        Notify:Show("Target locked", "success")
        return
    end

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= LP and other.Character then
            local hrp = other.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - root.Position).Magnitude
                if d < bestDist then bestDist = d; best = hrp end
            end
        end
    end
    if best and bestDist < 250 then
        root.CFrame = CFrame.new(best.Position + Vector3.new(0, 0, 5), best.Position)
        self:_log(string.format("Locked player at %.1f studs (test-place only)", bestDist))
        Notify:Show("Player target locked", "info")
    else
        self:_log("No target found")
        Notify:Show("No target found", "warn")
    end
end

function Combat:Destroy()
    self:_stopParry()
    self:_stopDodge()
    self:_stopCooldown()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VISUAL CONTROLLER
-- ═══════════════════════════════════════════════════════════════════════════
local Visual = {}
Visual.__index = Visual

function Visual.new(ui)
    local self = setmetatable({}, Visual)
    self.UI = ui
    self.Connections = {}
    self.Highlight = nil
    self.DistanceGui = nil
    self.Target = nil
    self.Enabled = false
    self.ShowDistance = false
    self.ShowDebug = false
    self:_buildTab()
    return self
end

function Visual:_track(c) table.insert(self.Connections, c); return c end

function Visual:_buildTab()
    if not self then return end
    local ui = self.UI
    if not ui then return end
    ui:ShowTab("Visuals")
    ui:CreateHeader("— Camera —")
    ui:CreateSlider("Field of View", 30, 120, Settings.fov, function(v)
        Settings.fov = v
        Camera.FieldOfView = v
    end)
    ui:CreateSlider("UI Scale", 0.6, 1.8, Settings.uiScale, function(v)
        Settings.uiScale = v
        ui:_updateScale()
    end)

    ui:CreateHeader("— Target ESP —")
    ui:CreateToggle("Highlight Nearest Target", false, function(on)
        self.Enabled = on
        if not on then self:_clearHighlight() end
    end)
    ui:CreateToggle("Show Distance to Target", false, function(on)
        self.ShowDistance = on
        if not on then self:_clearDistance() end
    end)
    ui:CreateSlider("Highlight Red", 0, 255, Settings.highlightColor.R * 255, function(v)
        Settings.highlightColor = Color3.new(v/255, Settings.highlightColor.G, Settings.highlightColor.B)
        if self.Highlight then self.Highlight.FillColor = Settings.highlightColor end
    end)
    ui:CreateSlider("Highlight Green", 0, 255, Settings.highlightColor.G * 255, function(v)
        Settings.highlightColor = Color3.new(Settings.highlightColor.R, v/255, Settings.highlightColor.B)
        if self.Highlight then self.Highlight.FillColor = Settings.highlightColor end
    end)
    ui:CreateSlider("Highlight Blue", 0, 255, Settings.highlightColor.B * 255, function(v)
        Settings.highlightColor = Color3.new(Settings.highlightColor.R, Settings.highlightColor.G, v/255)
        if self.Highlight then self.Highlight.FillColor = Settings.highlightColor end
    end)

    ui:CreateHeader("— Debug —")
    self.DebugLabel = ui:CreateHeader("Ping: —  FPS: —  Pos: —")
    ui:CreateToggle("Show Debug Overlay", false, function(on)
        self.ShowDebug = on
        if self.DebugLabel then self.DebugLabel.Visible = on end
    end)
    if self.DebugLabel then self.DebugLabel.Visible = false end

    self:_startLoop()
end

function Visual:_clearHighlight()
    if self.Highlight then self.Highlight:Destroy(); self.Highlight = nil end
end

function Visual:_clearDistance()
    if self.DistanceGui then self.DistanceGui:Destroy(); self.DistanceGui = nil end
end

function Visual:_findTarget()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local best, bestDist = nil, math.huge
    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and model ~= char then
            local n = string.lower(model.Name)
            if n:find("dummy") or n:find("target") then
                local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                if hrp then
                    local d = (hrp.Position - root.Position).Magnitude
                    if d < bestDist then bestDist = d; best = model end
                end
            end
        end
    end
    if best then return best, bestDist end

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= LP and other.Character then
            local hrp = other.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - root.Position).Magnitude
                if d < bestDist then bestDist = d; best = other.Character end
            end
        end
    end
    if best and bestDist < 250 then return best, bestDist end
    return nil
end

function Visual:_startLoop()
    local selfRef = self
    local ui = self.UI
    local fps = 60
    local frames = 0
    local lastT = tick()

    selfRef:_track(RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        if tick() - lastT >= 1 then
            fps = frames / (tick() - lastT)
            frames = 0
            lastT = tick()
        end
    end))

    task.spawn(function()
        while true do
            task.wait(0.4)
            if not selfRef then return end
            if not ui then return end
            if not ui.ScreenGui or not ui.ScreenGui.Parent then return end

            if selfRef.ShowDebug and selfRef.DebugLabel and selfRef.DebugLabel.Parent then
                local char = LP.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local pos = root and string.format("(%.0f, %.0f, %.0f)",
                    root.Position.X, root.Position.Y, root.Position.Z) or "(n/a)"
                local ping = 0
                pcall(function() ping = math.floor(LP:GetNetworkPing() * 1000) end)
                selfRef.DebugLabel.Text = string.format("Ping: %dms  FPS: %d  Pos: %s",
                    ping, math.floor(fps + 0.5), pos)
            end

            if selfRef.Enabled then
                local target, dist = selfRef:_findTarget()
                if target ~= selfRef.Target then
                    selfRef:_clearHighlight()
                    selfRef.Target = target
                    if target then
                        local h = Instance.new("Highlight")
                        h.Name = "DGTargetHighlight"
                        h.FillColor = Settings.highlightColor
                        h.FillTransparency = 0.6
                        h.OutlineColor = Settings.highlightColor
                        h.OutlineTransparency = 0
                        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        h.Parent = target
                        selfRef.Highlight = h
                    end
                end
                if selfRef.Highlight and target then
                    selfRef.Highlight.FillColor = Settings.highlightColor
                    selfRef.Highlight.OutlineColor = Settings.highlightColor
                end
            else
                selfRef:_clearHighlight()
            end

            if selfRef.ShowDistance then
                local target, dist = selfRef:_findTarget()
                if target then
                    local hrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
                    if hrp then
                        if not selfRef.DistanceGui or selfRef.DistanceGui.Parent ~= hrp then
                            selfRef:_clearDistance()
                            local bb = Instance.new("BillboardGui")
                            bb.Name = "DGTargetDist"
                            bb.Size = UDim2.new(0, 140, 0, 30)
                            bb.StudsOffset = Vector3.new(0, 4, 0)
                            bb.AlwaysOnTop = true
                            bb.Parent = hrp
                            local lbl = Instance.new("TextLabel")
                            lbl.Size = UDim2.new(1, 0, 1, 0)
                            lbl.BackgroundTransparency = 1
                            lbl.TextColor3 = Color3.fromRGB(255, 220, 130)
                            lbl.TextStrokeTransparency = 0
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextSize = 14
                            lbl.Parent = bb
                            selfRef.DistanceGui = bb
                        end
                        local lbl = selfRef.DistanceGui:FindFirstChildOfClass("TextLabel")
                        if lbl then
                            lbl.Text = string.format("%s | %.0f studs", target.Name, dist)
                        end
                    end
                else
                    selfRef:_clearDistance()
                end
            else
                selfRef:_clearDistance()
            end
        end
    end)
end

function Visual:Destroy()
    self:_clearHighlight()
    self:_clearDistance()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MOVEMENT CONTROLLER
-- ═══════════════════════════════════════════════════════════════════════════
local Movement = {}
Movement.__index = Movement

function Movement.new(ui)
    local self = setmetatable({}, Movement)
    self.UI = ui
    self.Connections = {}
    self:_buildTab()
    self:_bindCharacter()
    return self
end

function Movement:_track(c) table.insert(self.Connections, c); return c end

function Movement:_applyToCharacter()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum.WalkSpeed = Settings.walkSpeed
        hum.UseJumpPower = true
        hum.JumpPower = Settings.jumpPower
    end)
end

function Movement:_bindCharacter()
    self:_applyToCharacter()
    self:_track(LP.CharacterAdded:Connect(function()
        task.wait(0.5)
        self:_applyToCharacter()
    end))
end

function Movement:_buildTab()
    if not self then return end
    local ui = self.UI
    if not ui then return end
    ui:ShowTab("Movement")

    ui:CreateHeader("— Client Movement (server-authoritative in live games) —")

    self.WalkSlider = ui:CreateSlider("Walk Speed", 0, 200, Settings.walkSpeed, function(v)
        Settings.walkSpeed = v
        self:_applyToCharacter()
    end)

    self.JumpSlider = ui:CreateSlider("Jump Power", 0, 500, Settings.jumpPower, function(v)
        Settings.jumpPower = v
        self:_applyToCharacter()
    end)

    ui:CreateHeader("— Actions —")
    ui:CreateButton("Dash Forward (Studio only)", function()
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = root.CFrame + root.CFrame.LookVector * 15
            Notify:Show("Dashed", "success")
        else
            Notify:Show("No character", "warn")
        end
    end)

    ui:CreateButton("High Jump (temporary boost)", function()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            local orig = hum.JumpPower
            hum.JumpPower = 200
            hum.Jump = true
            task.delay(0.6, function()
                if hum and hum.Parent then hum.JumpPower = orig end
            end)
            Notify:Show("Boosted jump", "success")
        end
    end)

    ui:CreateButton("Reset Speed & Jump", function()
        Settings.walkSpeed = 16
        Settings.jumpPower = 50
        if self.WalkSlider then self.WalkSlider:Set(16) end
        if self.JumpSlider then self.JumpSlider:Set(50) end
        self:_applyToCharacter()
        Notify:Show("Reset to defaults", "success")
    end)

    ui:CreateButton("Respawn Character", function()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0; Notify:Show("Respawn requested", "info") end
    end)

    ui:CreateHeader("— Collision —")
    ui:CreateToggle("Disable Character Collision", false, function(on)
        local char = LP.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function() p.CanCollide = not on end)
            end
        end
        Notify:Show(on and "Collision disabled" or "Collision restored", "info")
    end)
end

function Movement:Destroy()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════════════════
local ui = UI.new(PlayerGui)
Notify:Init(ui.ScreenGui)

local floating = Floating.new(ui.ScreenGui, function() ui:Restore() end)
ui.OnMinimize = function() floating:Show() end
ui.OnRestore  = function() floating:Hide() end

local combat   = Combat.new(ui)
local visuals  = Visual.new(ui)
local movement = Movement.new(ui)

ui:ShowTab("Settings")
ui:CreateHeader("— Appearance —")
ui:CreateSlider("UI Scale", 0.6, 1.8, Settings.uiScale, function(v)
    Settings.uiScale = v
    ui:_updateScale()
end)
ui:CreateSlider("Floating Button Size", 36, 96, Settings.popupSize, function(v)
    Settings.popupSize = v
    floating:SetSize(v)
end)
ui:CreateSlider("Floating Button Opacity", 0.2, 1.0, Settings.popupOpacity, function(v)
    Settings.popupOpacity = v
    floating:SetOpacity(v)
end)
ui:CreateSlider("Field of View", 30, 120, Settings.fov, function(v)
    Settings.fov = v
    Camera.FieldOfView = v
end)
ui:CreateButton("Reset All Settings", function()
    Settings.uiScale = 1.0
    Settings.popupSize = 52
    Settings.popupOpacity = 0.85
    Settings.fov = 70
    Settings.walkSpeed = 16
    Settings.jumpPower = 50
    Settings.highlightColor = Color3.fromRGB(160, 90, 255)
    ui:_updateScale()
    floating:SetSize(52)
    floating:SetOpacity(0.85)
    Camera.FieldOfView = 70
    movement:_applyToCharacter()
    Notify:Show("Settings reset", "success")
end)

ui:ShowTab("Utilities")
ui:CreateHeader("— Utility Actions —")
ui:CreateButton("Minimize Panel (show floating button)", function()
    ui:Minimize()
end)
ui:CreateButton("Rejoin Server", function()
    pcall(function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
    end)
end)
ui:CreateButton("Close Trainer", function()
    ui:Close()
end, P.danger)
ui:CreateHeader("— Info —")
ui:CreateHeader("Parry/Dodge trainers are local timing minigames.")
ui:CreateHeader("Movement changes are client-side only.")
ui:CreateHeader("RightShift toggles minimize/restore.")

ui.OnClose = function()
    floating:Destroy()
    combat:Destroy()
    visuals:Destroy()
    movement:Destroy()
end

ui:ShowTab("Combat")
Notify:Show("Trainer loaded — RightShift to minimize", "info")
