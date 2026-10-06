--[[ OBSIDIAN UI LIBRARY banner
    ██████╗ ██████╗ ███████╗██╗██████╗ ██╗ █████╗ ███╗   ██╗
   ██╔═══██╗██╔══██╗██╔════╝██║██╔══██╗██║██╔══██╗████╗  ██║
   ██║   ██║██████╔╝███████╗██║██║  ██║██║███████║██╔██╗ ██║
   ██║   ██║██╔══██╗╚════██║██║██║  ██║██║██╔══██║██║╚██╗██║
   ╚██████╔╝██████╔╝███████║██║██████╔╝██║██║  ██║██║ ╚████║
    ╚═════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
                                                              UI LIBRARY
]]

--[[
    Obsidian UI Library
    -------------------
    经典纯色（黑色系）Roblox UI 库。全部组件、动画、反馈、主题、音效、
    配置持久化（writefile / readfile）与通知系统，开箱即用。

    用法：
        local Obsidian = loadstring(game:HttpGet(".../ObsidianUI.lua"))()
        local Window   = Obsidian:CreateWindow({ Title = "My Script" })

    兼容：Roblox Luau / Lua 5.1 语法（不依赖任何仅 Luau 的特性）。
]]

local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService     = game:GetService("RunService")
local Players        = game:GetService("Players")
local TextService    = game:GetService("TextService")
local SoundService   = game:GetService("SoundService")
local Debris         = game:GetService("Debris")
local HttpService     = game:GetService("HttpService")

-- ============================ 基础工具 ============================
local function isFn(v) return type(v) == "function" end
local function clamp(v, lo, hi) return math.min(hi, math.max(lo, v)) end
local function rgb(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
local function UDim2Offset(x, y) return UDim2.new(0, x, 0, y) end
local function UDim2Scale(x, y) return UDim2.new(x, 0, y, 0) end
local function lerpColor(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local taskLib = (type(task) == "table") and task or nil
local function defer(fn)
    if taskLib and taskLib.defer then taskLib.defer(fn) else spawn(fn) end
end

local function safeCall(fn, ...)
    if not isFn(fn) then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[Obsidian] Callback error: " .. tostring(err)) end
end

-- 执行器全局（writefile / readfile / setclipboard 等），统一做保护
local writefile   = isFn(writefile) and writefile or nil
local readfile    = isFn(readfile) and readfile or nil
local makefolder  = isFn(makefolder) and makefolder or nil
local isfolder    = isFn(isfolder) and isfolder or nil
local setclipboard = isFn(setclipboard) and setclipboard or nil

local function findContainer()
    if isFn(gethui) then
        local ok, ui = pcall(gethui)
        if ok and ui then return ui end
    end
    if isFn(get_hidden_gui) then
        local ok, ui = pcall(get_hidden_gui)
        if ok and ui then return ui end
    end
    local plr = Players.LocalPlayer
    if plr then
        local pg = plr:FindFirstChildOfClass("PlayerGui")
        if pg then return pg end
    end
    return game:GetService("CoreGui")
end

-- ============================ 实例构造 ============================
local function Create(class, props)
    local inst = Instance.new(class)
    if props then
        local parent = props.Parent
        props.Parent = nil
        for k, v in pairs(props) do
            inst[k] = v
        end
        if parent then inst.Parent = parent end
    end
    return inst
end

local function newCorner(parent, radius)
    return Create("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius) })
end

local function newStroke(parent, color, thickness, transparency)
    return Create("UIStroke", {
        Parent = parent, Color = color or Color3.new(1, 1, 1),
        Thickness = thickness or 1, Transparency = transparency or 0,
    })
end

local function tween(inst, time, props, easing, dir)
    local info = TweenInfo.new(time or 0.2, easing or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, 0)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

local function ripple(parent, color)
    local pos = UserInputService:GetMouseLocation()
    local rel = Vector2.new(pos.X - parent.AbsolutePosition.X, pos.Y - parent.AbsolutePosition.Y)
    local size = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.4
    local circle = Create("Frame", {
        Parent = parent, Size = UDim2Offset(6, 6), Position = UDim2Offset(rel.X, rel.Y),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color or Color3.new(1, 1, 1),
        BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 10,
    })
    newCorner(circle, 999)
    local t = TweenService:Create(circle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2Offset(size, size), BackgroundTransparency = 1,
    })
    t:Play()
    t.Completed:Connect(function() circle:Destroy() end)
end

-- 图标按钮（最小化 / 关闭 / 复制等）的悬停反馈
local function hoverButton(btn, baseColor, hoverColor, win)
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = baseColor
    btn.BorderSizePixel = 0
    btn.MouseEnter:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = hoverColor })
        if win then win:PlaySound("Hover") end
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = baseColor })
    end)
    btn.MouseButton1Click:Connect(function()
        if win then win:PlaySound("Click") end
    end)
end

-- 绘制式 V 形箭头（不依赖字体字形，保证渲染）
local function makeChevron(parent, color, size, pointRight)
    local holder = Create("Frame", {
        Parent = parent, Size = UDim2Offset(size, size), Position = UDim2Offset(0, -size / 2),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6,
    })
    local function bar(rot, yScale)
        return Create("Frame", {
            Parent = holder, Size = UDim2Offset(math.ceil(size * 0.6), 2),
            Position = UDim2.new(0.5, 0, yScale, 0), AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = color, BorderSizePixel = 0, Rotation = rot, ZIndex = 7,
        })
    end
    local top = bar(-45, 0.38)
    local bottom = bar(45, 0.62)
    holder.SetExpanded = function(expanded)
        if expanded then tween(holder, 0.18, { Rotation = 90 }) else tween(holder, 0.18, { Rotation = 0 }) end
    end
    holder.SetColor = function(c) top.BackgroundColor3 = c; bottom.BackgroundColor3 = c end
    holder.Rotation = pointRight and 0 or 90
    return holder
end

-- 通用交互反馈（悬停变色 + 按下缩放 + 波纹 + 音效）
local function styleInteractive(frame, colors, opts)
    opts = opts or {}
    local function base() return opts.BaseColor or colors.Surface2 end
    local function hover() return opts.HoverColor or colors.SurfaceHover end
    local pressScale = opts.PressScale or 0.97
    local win = opts.Window
    local clickSound = opts.SoundName or "Click"
    local hoverSound = opts.HoverSound or "Hover"

    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2Scale(1, 1)
    frame.BackgroundColor3 = base()
    frame.BorderSizePixel = 0
    if frame:IsA("GuiButton") then frame.AutoButtonColor = false end
    if opts.Clips then frame.ClipsDescendants = true end

    local accentBar
    if opts.AccentBar then
        accentBar = Create("Frame", {
            Parent = frame, Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, 1, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = colors.Accent,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
        })
        newCorner(accentBar, 999)
    end

    local function play(s) if win then win:PlaySound(s) end end

    frame.MouseEnter:Connect(function()
        tween(frame, 0.16, { BackgroundColor3 = hover() })
        if accentBar then accentBar.BackgroundColor3 = colors.Accent; tween(accentBar, 0.16, { BackgroundTransparency = 0, Size = UDim2.new(0, 3, 0.5, 0) }) end
        play(hoverSound)
        if opts.OnHover then opts.OnHover() end
    end)
    frame.MouseLeave:Connect(function()
        tween(frame, 0.16, { BackgroundColor3 = base() })
        tween(frame, 0.12, { Size = UDim2Scale(1, 1) })
        if accentBar then tween(accentBar, 0.16, { BackgroundTransparency = 1, Size = UDim2.new(0, 3, 0, 0) }) end
        if opts.OnLeave then opts.OnLeave() end
    end)
    frame.MouseButton1Down:Connect(function()
        tween(frame, 0.09, { Size = UDim2Scale(pressScale, pressScale) })
        if opts.OnPress then opts.OnPress() end
    end)
    frame.MouseButton1Up:Connect(function()
        tween(frame, 0.12, { Size = UDim2Scale(1, 1) })
        if opts.OnRelease then opts.OnRelease() end
    end)
    frame.MouseButton1Click:Connect(function()
        play(clickSound)
        if opts.Ripple ~= false then ripple(frame, colors.Accent) end
        safeCall(opts.OnClick)
    end)
    return frame
end

local rowOrder = 0
local sectionOrder = 0

-- 非交互行（滑块 / 文本框 / 分割线等）
local function newRow(parent, colors, height)
    local row = Create("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, height or 40),
        BackgroundColor3 = colors.Surface2, BorderSizePixel = 0, ZIndex = 2,
    })
    newCorner(row, 7)
    newStroke(row, colors.Border, 1, 0.5)
    rowOrder = rowOrder + 1
    row.LayoutOrder = rowOrder
    return row
end

-- 可点击行（按钮 / 开关 / 下拉 / 键位 / 取色等）
local function newButtonRow(parent, colors, height, window, opts)
    opts = opts or {}
    local row = Create("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, height or 40),
        BackgroundColor3 = colors.Surface2, BorderSizePixel = 0, ZIndex = 2,
    })
    newCorner(row, 7)
    newStroke(row, colors.Border, 1, 0.5)
    rowOrder = rowOrder + 1
    row.LayoutOrder = rowOrder
    local inner = Create("TextButton", {
        Parent = row, Size = UDim2Scale(1, 1), Position = UDim2Scale(0, 0),
        BackgroundColor3 = colors.Surface2, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3,
    })
    newCorner(inner, 7)
    styleInteractive(inner, colors, {
        Window = window, AccentBar = opts.AccentBar, SoundName = opts.SoundName,
        HoverColor = opts.HoverColor, OnClick = opts.OnClick, Clips = true,
    })
    return row, inner
end

local function newTitle(parent, colors, text, widthScale)
    local lbl = Create("TextLabel", {
        Parent = parent, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(widthScale or 0.5, -12, 1, 0),
        BackgroundTransparency = 1, Text = text or "", TextColor3 = colors.Text,
        Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
    })
    return lbl
end

-- 可拖拽滑块（供 Slider / 取色器复用）
local function makeDraggableSlider(track, knob, onFraction, window)
    local dragging = false
    local function updateFromMouse()
        local mousePos = UserInputService:GetMouseLocation()
        local abs = track.AbsolutePosition
        local size = track.AbsoluteSize
        if size.X <= 0 then return end
        local t = clamp((mousePos.X - abs.X) / size.X, 0, 1)
        onFraction(t)
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromMouse()
        end
    end)
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromMouse()
        end
    end)
    local ended = UserInputService.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and dragging then
            dragging = false
        end
    end)
    local changed = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromMouse()
        end
    end)
    if window then
        window:AddCleanup(ended)
        window:AddCleanup(changed)
    end
    return updateFromMouse
end

local function warnIcon(t)
    if t == "Error" then return "×"
    elseif t == "Success" then return "✓"
    elseif t == "Warning" then return "!"
    else return "i" end
end

local function contrastColor(c)
    local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
    if lum > 0.6 then return Color3.new(0, 0, 0) else return Color3.new(1, 1, 1) end
end

local function keyName(key)
    if not key or not key.Name then return "无" end
    local n = key.Name
    local map = {
        LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
        LeftAlt = "LAlt", RightAlt = "RAlt", MouseButton1 = "LMB", MouseButton2 = "RMB",
        MouseButton3 = "MMB", MouseButton4 = "M4", MouseButton5 = "M5",
    }
    return map[n] or n
end

-- ============================ 颜色转换 ============================
local function color3ToHSV(c)
    local r, g, b = c.R, c.G, c.B
    local maxV = math.max(r, g, b)
    local minV = math.min(r, g, b)
    local delta = maxV - minV
    local h, s, v = 0, 0, maxV
    if delta > 0 then
        s = delta / maxV
        if maxV == r then
            h = ((g - b) / delta) % 6
        elseif maxV == g then
            h = (b - r) / delta + 2
        else
            h = (r - g) / delta + 4
        end
        h = h / 6
        if h < 0 then h = h + 1 end
    end
    return h, s, v
end

local function hsvToColor3(h, s, v)
    h = h % 1
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    i = i % 6
    if i == 0 then return Color3.new(v, t, p)
    elseif i == 1 then return Color3.new(q, v, p)
    elseif i == 2 then return Color3.new(p, v, t)
    elseif i == 3 then return Color3.new(p, q, v)
    elseif i == 4 then return Color3.new(t, p, v)
    else return Color3.new(v, p, q) end
end

local function toHexByte(n)
    n = clamp(math.floor(n + 0.5), 0, 255)
    local digits = "0123456789ABCDEF"
    return digits:sub(math.floor(n / 16) + 1, math.floor(n / 16) + 1) .. digits:sub((n % 16) + 1, (n % 16) + 1)
end

local function color3ToHex(c)
    return "#" .. toHexByte(c.R * 255) .. toHexByte(c.G * 255) .. toHexByte(c.B * 255)
end

local function hexToColor3(hex)
    if type(hex) ~= "string" then return nil end
    hex = hex:gsub("#", ""):upper()
    if #hex == 3 then
        hex = hex:sub(1, 1) .. hex:sub(1, 1) .. hex:sub(2, 2) .. hex:sub(2, 2) .. hex:sub(3, 3) .. hex:sub(3, 3)
    end
    if #hex ~= 6 then return nil end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return Color3.new(r / 255, g / 255, b / 255)
end

local function hueGradient()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, rgb(255, 0, 0)),
        ColorSequenceKeypoint.new(1 / 6, rgb(255, 255, 0)),
        ColorSequenceKeypoint.new(2 / 6, rgb(0, 255, 0)),
        ColorSequenceKeypoint.new(3 / 6, rgb(0, 255, 255)),
        ColorSequenceKeypoint.new(4 / 6, rgb(0, 0, 255)),
        ColorSequenceKeypoint.new(5 / 6, rgb(255, 0, 255)),
        ColorSequenceKeypoint.new(1, rgb(255, 0, 0)),
    })
end

-- ============================ JSON（HttpService 失败时回退） ============================
local JSON = {}
local function jsonEscape(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\"", "\\\"")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    s = string.gsub(s, "\b", "\\b")
    s = string.gsub(s, "\f", "\\f")
    return s
end

local function jsonIsArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
        n = n + 1
    end
    if n == 0 then return true end
    for i = 1, n do if t[i] == nil then return false end end
    return true
end

local function jsonEncodeValue(v)
    local tv = type(v)
    if v == nil then
        return "null"
    elseif tv == "boolean" then
        return v and "true" or "false"
    elseif tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        return tostring(v)
    elseif tv == "string" then
        return "\"" .. jsonEscape(v) .. "\""
    elseif tv == "table" then
        local parts = {}
        if jsonIsArray(v) then
            for i = 1, #v do parts[#parts + 1] = jsonEncodeValue(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, val in pairs(v) do
                if type(k) == "string" or type(k) == "number" then
                    parts[#parts + 1] = "\"" .. jsonEscape(tostring(k)) .. "\":" .. jsonEncodeValue(val)
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "null"
    end
end
JSON.encode = function(t) return jsonEncodeValue(t) end

local function jsonDecode(str)
    if type(str) ~= "string" then return nil end
    local i = 1
    local len = #str
    local function skipWs()
        while i <= len do
            local c = str:sub(i, i)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then i = i + 1 else break end
        end
    end
    local function parseString()
        i = i + 1
        local out = {}
        while i <= len do
            local c = str:sub(i, i)
            if c == "\\" then
                i = i + 1
                local e = str:sub(i, i)
                if e == "n" then out[#out + 1] = "\n"
                elseif e == "t" then out[#out + 1] = "\t"
                elseif e == "r" then out[#out + 1] = "\r"
                elseif e == "b" then out[#out + 1] = "\b"
                elseif e == "f" then out[#out + 1] = "\f"
                elseif e == "\\" then out[#out + 1] = "\\"
                elseif e == "\"" then out[#out + 1] = "\""
                elseif e == "/" then out[#out + 1] = "/"
                elseif e == "u" then
                    local code = tonumber(str:sub(i + 1, i + 4), 16)
                    if code and code < 256 then out[#out + 1] = string.char(code) else out[#out + 1] = "?" end
                    i = i + 4
                else
                    out[#out + 1] = e
                end
                i = i + 1
            elseif c == "\"" then
                i = i + 1
                return table.concat(out)
            else
                out[#out + 1] = c
                i = i + 1
            end
        end
        return table.concat(out)
    end
    local function parseNumber()
        local start = i
        if str:sub(i, i) == "-" then i = i + 1 end
        while i <= len do
            local c = str:sub(i, i)
            if c:match("[%d]") or c == "." or c == "e" or c == "E" or c == "+" or c == "-" then
                i = i + 1
            else
                break
            end
        end
        return tonumber(str:sub(start, i - 1))
    end
    local function parseValue()
        skipWs()
        local c = str:sub(i, i)
        if c == "{" then return parseObject()
        elseif c == "[" then return parseArray()
        elseif c == "\"" then return parseString()
        elseif c == "t" then i = i + 4; return true
        elseif c == "f" then i = i + 5; return false
        elseif c == "n" then i = i + 4; return nil
        else return parseNumber() end
    end
    parseArray = function()
        i = i + 1
        local t = {}
        skipWs()
        if str:sub(i, i) == "]" then i = i + 1; return t end
        while true do
            t[#t + 1] = parseValue()
            skipWs()
            local c = str:sub(i, i)
            if c == "," then i = i + 1
            elseif c == "]" then i = i + 1; return t
            else error("json") end
        end
    end
    parseObject = function()
        i = i + 1
        local t = {}
        skipWs()
        if str:sub(i, i) == "}" then i = i + 1; return t end
        while true do
            skipWs()
            local key = parseString()
            skipWs()
            if str:sub(i, i) ~= ":" then error("json") end
            i = i + 1
            t[key] = parseValue()
            skipWs()
            local c = str:sub(i, i)
            if c == "," then i = i + 1
            elseif c == "}" then i = i + 1; return t
            else error("json") end
        end
    end
    local ok, res = pcall(function() return parseValue() end)
    if ok then return res end
    return nil
end
JSON.decode = jsonDecode

local function encodeJSON(v)
    if HttpService then
        local ok, res = pcall(function() return HttpService:JSONEncode(v) end)
        if ok then return res end
    end
    return JSON.encode(v)
end

local function decodeJSON(s)
    if HttpService then
        local ok, res = pcall(function() return HttpService:JSONDecode(s) end)
        if ok then return res end
    end
    return JSON.decode(s)
end

-- ============================ 音效 ============================
local DefaultSounds = {
    Click  = "rbxassetid://12221967",
    Hover  = "rbxassetid://12222021",
    Toggle = "rbxassetid://12222067",
    Open   = "rbxassetid://12222139",
    Close  = "rbxassetid://12222162",
    Notify = "rbxassetid://12221987",
    Error  = "rbxassetid://12222067",
    Bind   = "rbxassetid://12222139",
}

-- ============================ 主题 ============================
local function buildTheme(accent)
    local black = Color3.new(0, 0, 0)
    local white = Color3.new(1, 1, 1)
    return {
        Accent = accent,
        AccentDark = lerpColor(accent, black, 0.30),
        AccentLight = lerpColor(accent, white, 0.28),
        Background = rgb(15, 15, 19),
        Surface = rgb(22, 22, 28),
        Surface2 = rgb(29, 29, 37),
        Surface3 = rgb(36, 36, 46),
        SurfaceHover = rgb(43, 43, 54),
        SurfaceActive = lerpColor(rgb(29, 29, 37), accent, 0.30),
        Border = rgb(48, 48, 60),
        Text = rgb(238, 238, 244),
        SubText = rgb(150, 150, 163),
        DisabledText = rgb(98, 98, 110),
        Danger = rgb(232, 71, 76),
        Success = rgb(64, 196, 122),
        Warning = rgb(240, 180, 58),
        Info = rgb(80, 155, 235),
        Shadow = Color3.new(0, 0, 0),
    }
end

local Themes = {
    Black   = buildTheme(rgb(86, 144, 255)),
    Blue    = buildTheme(rgb(70, 150, 250)),
    Red     = buildTheme(rgb(235, 74, 84)),
    Crimson = buildTheme(rgb(200, 60, 80)),
    Emerald = buildTheme(rgb(60, 200, 130)),
    Green   = buildTheme(rgb(90, 200, 90)),
    Violet  = buildTheme(rgb(150, 110, 255)),
    Purple  = buildTheme(rgb(180, 90, 220)),
    Gold    = buildTheme(rgb(240, 180, 60)),
    Cyan    = buildTheme(rgb(60, 200, 230)),
    White   = buildTheme(rgb(210, 210, 220)),
    Pink    = buildTheme(rgb(240, 110, 180)),
    Mono    = buildTheme(rgb(150, 150, 160)),
}

-- ============================ 类 ============================
local Window = {}
local Tab = {}
local Section = {}

local function sanitizeKey(s)
    s = tostring(s or "")
    s = string.gsub(s, "[^%w%._%-]", "_")
    s = string.gsub(s, "_+", "_")
    s = string.gsub(s, "^_+", "")
    s = string.gsub(s, "_+$", "")
    if s == "" then s = "item" end
    return s
end

-- ============================ Window ============================
Window.__index = Window

function Window.new(config)
    config = config or {}
    local self = setmetatable({}, Window)

    self.Title = config.Title or "Obsidian"
    self.SubTitle = config.SubTitle or ""
    self.Colors = Themes[config.Theme or "Black"] or Themes.Black
    self.SoundsEnabled = config.Sounds ~= false
    self.SoundVolume = config.SoundVolume or 1
    self.SoundIds = (type(config.Sounds) == "table") and config.Sounds or DefaultSounds

    self.Config = {
        Enabled = not (config.Config and config.Config.Enabled == false),
        Folder = (config.Config and config.Config.Folder) or "Obsidian",
        File = (config.Config and config.Config.File) or "Config",
        AutoSave = not (config.Config and config.Config.AutoSave == false),
        GlobalFlags = config.Config and config.Config.GlobalFlags,
    }
    self.Config.Data = {}
    self.Flags = {}
    self.UsedKeys = {}
    self.Elements = {}
    self.AllElements = {}
    self.Tabs = {}
    self.AllSections = {}
    self.Cleanup = {}
    self.CurrentTab = nil
    self.Minimized = false
    self.NotifStack = {}
    self.NotifCount = 0

    self:Build(config)
    self:LoadConfig()

    return self
end

function Window:Build(config)
    local colors = self.Colors
    local container = findContainer()

    self.ScreenGui = Create("ScreenGui", {
        Parent = container, Name = "Obsidian_" .. self.Title,
        IgnoreGuiInset = true, ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = config.DisplayOrder or 999999999,
    })

    local size = config.Size or UDim2Offset(620, 520)
    local pos = config.Position or UDim2.new(0.5, 0, 0.5, 0)
    local anchor = config.AnchorPoint or Vector2.new(0.5, 0.5)

    self.Shadow = Create("Frame", {
        Parent = self.ScreenGui, Size = size, Position = pos + UDim2Offset(0, 6), AnchorPoint = anchor,
        BackgroundColor3 = colors.Shadow, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 0,
    })
    newCorner(self.Shadow, 12)

    self.Frame = Create("Frame", {
        Parent = self.ScreenGui, Size = size, Position = pos, AnchorPoint = anchor,
        BackgroundColor3 = colors.Background, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1,
    })
    newCorner(self.Frame, 12)
    self.FrameStroke = newStroke(self.Frame, colors.Border, 1, 0.4)

    -- 标题栏
    self.TitleBar = Create("Frame", {
        Parent = self.Frame, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = colors.Surface, BorderSizePixel = 0, ZIndex = 2,
    })
    self.TitleCluster = Create("Frame", {
        Parent = self.TitleBar, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -120, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
    })
    Create("UIListLayout", {
        Parent = self.TitleCluster, FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8),
    })
    self.TitleDot = Create("Frame", {
        Parent = self.TitleCluster, LayoutOrder = 1, Size = UDim2Offset(8, 8),
        BackgroundColor3 = colors.Accent, BorderSizePixel = 0, ZIndex = 3,
    })
    newCorner(self.TitleDot, 999)
    self.TitleLabel = Create("TextLabel", {
        Parent = self.TitleCluster, LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Text = self.Title,
        TextColor3 = colors.Text, Font = Enum.Font.GothamBold, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 3,
    })
    self.SubTitleLabel = Create("TextLabel", {
        Parent = self.TitleCluster, LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Text = self.SubTitle,
        TextColor3 = colors.SubText, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 3,
    })

    -- 最小化 / 关闭按钮
    self.MinimizeButton = Create("TextButton", {
        Parent = self.TitleBar, Position = UDim2.new(1, -62, 0.5, 0), Size = UDim2Offset(28, 28),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = colors.Surface, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, ZIndex = 4,
    })
    newCorner(self.MinimizeButton, 7)
    self.MinimizeIcon = Create("Frame", {
        Parent = self.MinimizeButton, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2Offset(11, 2),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = colors.SubText, BorderSizePixel = 0, ZIndex = 5,
    })
    self.CloseButton = Create("TextButton", {
        Parent = self.TitleBar, Position = UDim2.new(1, -30, 0.5, 0), Size = UDim2Offset(28, 28),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = colors.Surface, BorderSizePixel = 0, Text = "×",
        TextColor3 = colors.SubText, Font = Enum.Font.GothamBold, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
        AutoButtonColor = false, ZIndex = 4,
    })
    newCorner(self.CloseButton, 7)

    local win = self
    hoverButton(self.MinimizeButton, colors.Surface, colors.SurfaceHover, self)
    hoverButton(self.CloseButton, colors.Surface, colors.Danger, self)
    self.MinimizeButton.MouseButton1Click:Connect(function() self:ToggleMinimize() end)
    self.CloseButton.MouseButton1Click:Connect(function()
        if config.Confirmation ~= false then self:RequestClose() else self:Destroy() end
    end)

    -- 拖动
    local dragConn, dragMove, dragEnd
    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local startPos = Vector2.new(input.Position.X, input.Position.Y)
            local abs = self.Frame.AbsolutePosition
            local parentAbs = self.Frame.Parent and self.Frame.Parent.AbsolutePosition or Vector2.new(0, 0)
            local startWin = UDim2Offset(abs.X - parentAbs.X, abs.Y - parentAbs.Y)
            dragMove = UserInputService.InputChanged:Connect(function(change)
                if change.UserInputType == Enum.UserInputType.MouseMovement or change.UserInputType == Enum.UserInputType.Touch then
                    local delta = Vector2.new(change.Position.X - startPos.X, change.Position.Y - startPos.Y)
                    self.Frame.Position = UDim2Offset(startWin.X.Offset + delta.X, startWin.Y.Offset + delta.Y)
                    self.Shadow.Position = self.Frame.Position + UDim2Offset(0, 6)
                end
            end)
            dragEnd = UserInputService.InputEnded:Connect(function(change)
                if change.UserInputType == Enum.UserInputType.MouseButton1 or change.UserInputType == Enum.UserInputType.Touch then
                    if dragMove then dragMove:Disconnect() end
                    if dragEnd then dragEnd:Disconnect() end
                    self:ClampToScreen()
                end
            end)
        end
    end)

    -- 标签栏
    self.TabBar = Create("Frame", {
        Parent = self.Frame, Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = colors.Surface, BorderSizePixel = 0, ZIndex = 2,
    })
    Create("Frame", {
        Parent = self.TabBar, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = colors.Border, BorderSizePixel = 0, ZIndex = 3,
    })
    Create("UIListLayout", {
        Parent = self.TabBar, FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2),
    })
    Create("UIPadding", { Parent = self.TabBar, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
    self.TabIndicator = Create("Frame", {
        Parent = self.TabBar, Position = UDim2.new(0, 0, 1, -2), Size = UDim2Offset(0, 2),
        BackgroundColor3 = colors.Accent, BorderSizePixel = 0, ZIndex = 3,
    })
    newCorner(self.TabIndicator, 999)

    -- 内容
    self.Content = Create("ScrollingFrame", {
        Parent = self.Frame, Position = UDim2.new(0, 0, 0, 82), Size = UDim2.new(1, 0, 1, -82),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2Offset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
        ScrollBarImageColor3 = colors.Border, ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true, ZIndex = 1,
    })
    Create("UIListLayout", {
        Parent = self.Content, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })
    Create("UIPadding", {
        Parent = self.Content, PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
    })
    self.Content:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:ClosePopups() end)

    -- 弹层（下拉 / 取色器用）
    self.Overlay = Create("Frame", {
        Parent = self.Frame, Size = UDim2Scale(1, 1), Position = UDim2Scale(0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50, Active = true, Visible = false,
    })
    self.Overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then self:ClosePopups() end
    end)

    -- 全局按键切换 UI（可选）
    if config.Keybind then
        self.ToggleKey = config.Keybind
        local kbConn = UserInputService.InputBegan:Connect(function(input, gp)
            if not gp and input.KeyCode == self.ToggleKey then
                self.ScreenGui.Enabled = not self.ScreenGui.Enabled
            end
        end)
        self:AddCleanup(kbConn)
    end
end

function Window:ClampToScreen()
    local camera = workspace.CurrentCamera
    local vs = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
    local size = self.Frame.AbsoluteSize
    local pos = self.Frame.Position
    local x = clamp(pos.X.Offset, 60 - size.X, vs.X - 60)
    local y = clamp(pos.Y.Offset, 0, vs.Y - 44)
    self.Frame.Position = UDim2Offset(x, y)
    self.Shadow.Position = self.Frame.Position + UDim2Offset(0, 6)
end

function Window:AddCleanup(c)
    table.insert(self.Cleanup, c)
end

function Window:PlaySound(name)
    if not self.SoundsEnabled then return end
    local id = self.SoundIds[name] or DefaultSounds[name]
    if not id then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = self.SoundVolume
        s.Parent = SoundService
        s:Play()
        Debris:AddItem(s, 3)
    end)
end

function Window:AddTab(title)
    local tab = Tab.new(self, title)
    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then
        defer(function()
            wait()
            if self.CurrentTab == nil and self.Tabs[1] then self:SelectTab(self.Tabs[1], true) end
        end)
    end
    return tab
end
Window.Tab = Window.AddTab

function Window:AddSection(section)
    table.insert(self.AllSections, section)
end

function Window:SelectTab(tab, instant)
    if not tab then return end
    if self.CurrentTab == tab and not instant then return end
    self.CurrentTab = tab
    for _, t in ipairs(self.Tabs) do
        local active = (t == tab)
        t.Active = active
        tween(t.Button, 0.18, { BackgroundColor3 = active and self.Colors.Surface2 or self.Colors.Surface })
        tween(t.Label, 0.18, { TextColor3 = active and self.Colors.Text or self.Colors.SubText })
    end
    for _, s in ipairs(self.AllSections) do
        s.Container.Visible = (s.Tab == tab)
    end
    local bx = tab.Button.Position.X.Offset
    local bw = tab.Button.Size.X.Offset
    if instant then
        self.TabIndicator.Position = UDim2.new(0, bx, 1, -2)
        self.TabIndicator.Size = UDim2.new(0, bw, 0, 2)
    else
        tween(self.TabIndicator, 0.22, { Position = UDim2.new(0, bx, 1, -2), Size = UDim2.new(0, bw, 0, 2) })
    end
    self.Content.CanvasPosition = Vector2.new(0, 0)
    self:PlaySound("Open")
end

function Window:GenerateKey(tabTitle, sectionTitle, title)
    local base = sanitizeKey(tabTitle) .. "_" .. sanitizeKey(sectionTitle) .. "_" .. sanitizeKey(title)
    local key = base
    local n = 2
    while self.UsedKeys[key] do
        key = base .. "_" .. n
        n = n + 1
    end
    self.UsedKeys[key] = true
    return key
end

function Window:RegisterElement(element)
    self.Elements[element.Key] = element
    table.insert(self.AllElements, element)
    local d = self.Config.Data
    if d and d[element.Key] ~= nil then
        self.Flags[element.Key] = d[element.Key]
    else
        self.Flags[element.Key] = element.Value
    end
end

function Window:UnregisterElement(element)
    self.Elements[element.Key] = nil
    for i, e in ipairs(self.AllElements) do
        if e == element then table.remove(self.AllElements, i); break end
    end
end

function Window:GetElement(name)
    if self.Elements[name] then return self.Elements[name] end
    for _, e in ipairs(self.AllElements) do
        if e.Title == name then return e end
    end
    return nil
end

function Window:GetFlags() return self.Flags end

function Window:GetInitial(key, fallback)
    local d = self.Config.Data
    if d and d[key] ~= nil then return d[key] end
    return fallback
end

function Window:OnElementChanged(element, value)
    self.Flags[element.Key] = value
    if self.Config.Enabled then
        self.Config.Data[element.Key] = value
        if self.Config.AutoSave then self:ScheduleSave() end
    end
end

function Window:ScheduleSave()
    if self.SaveScheduled then return end
    self.SaveScheduled = true
    defer(function()
        wait(0.7)
        self.SaveScheduled = false
        self:SaveConfig()
    end)
end

function Window:SaveConfig()
    if not self.Config.Enabled then return end
    if not writefile then return end
    local ok, encoded = pcall(encodeJSON, self.Config.Data)
    if not ok then return end
    pcall(function()
        if makefolder and not self.FolderCreated then
            if not (isfolder and isfolder(self.Config.Folder)) then makefolder(self.Config.Folder) end
            self.FolderCreated = true
        end
        writefile(self.Config.Folder .. "/" .. self.Config.File .. ".json", encoded)
    end)
end

function Window:LoadConfig()
    if not self.Config.Enabled then return end
    if not readfile then return end
    local ok, raw = pcall(readfile, self.Config.Folder .. "/" .. self.Config.File .. ".json")
    if not ok or type(raw) ~= "string" then return end
    local ok2, data = pcall(decodeJSON, raw)
    if ok2 and type(data) == "table" then
        self.Config.Data = data
    end
end

function Window:ResetConfig()
    self.Config.Data = {}
    self.Flags = {}
    self:SaveConfig()
    self:Notify({ Title = "配置已重置", Content = "已恢复默认设置。", Type = "Info", Duration = 2 })
end

function Window:SetTheme(theme)
    if type(theme) == "string" then theme = Themes[theme] or theme end
    if type(theme) ~= "table" then return end
    for k, v in pairs(theme) do self.Colors[k] = v end
    local c = theme
    self.Frame.BackgroundColor3 = c.Background
    self.FrameStroke.Color = c.Border
    self.TitleBar.BackgroundColor3 = c.Surface
    self.TabBar.BackgroundColor3 = c.Surface
    self.TitleDot.BackgroundColor3 = c.Accent
    self.TitleLabel.TextColor3 = c.Text
    self.SubTitleLabel.TextColor3 = c.SubText
    self.MinimizeButton.BackgroundColor3 = c.Surface
    self.MinimizeIcon.BackgroundColor3 = c.SubText
    self.CloseButton.BackgroundColor3 = c.Surface
    self.TabIndicator.BackgroundColor3 = c.Accent
    self.Content.ScrollBarImageColor3 = c.Border
    for _, t in ipairs(self.Tabs) do t:Recolor(c) end
    for _, s in ipairs(self.AllSections) do s:Recolor(c) end
    for _, e in ipairs(self.AllElements) do if e.Recolor then e.Recolor(c) end end
end

function Window:Minimize()
    if self.Minimized then return end
    self.Minimized = true
    self.SavedSize = self.Frame.Size
    tween(self.Frame, 0.22, { Size = UDim2.new(self.Frame.Size.X.Scale, self.Frame.Size.X.Offset, 0, 44) })
    tween(self.Shadow, 0.22, { Size = UDim2.new(self.Shadow.Size.X.Scale, self.Shadow.Size.X.Offset, 0, 44) })
    self.Content.Visible = false
    self.TabBar.Visible = false
    self:PlaySound("Close")
end

function Window:Restore()
    if not self.Minimized then return end
    self.Minimized = false
    if self.SavedSize then
        tween(self.Frame, 0.22, { Size = self.SavedSize })
        tween(self.Shadow, 0.22, { Size = self.SavedSize })
    end
    self.Content.Visible = true
    self.TabBar.Visible = true
    self:PlaySound("Open")
end

function Window:ToggleMinimize()
    if self.Minimized then self:Restore() else self:Minimize() end
end

function Window:SetTitle(text)
    self.Title = text
    self.TitleLabel.Text = text
end

function Window:SetSubTitle(text)
    self.SubTitle = text
    self.SubTitleLabel.Text = text
end

function Window:Hide()
    self.ScreenGui.Enabled = false
end

function Window:Show()
    self.ScreenGui.Enabled = true
end

function Window:Toggle()
    self.ScreenGui.Enabled = not self.ScreenGui.Enabled
end

function Window:RequestClose()
    self:Confirm({
        Title = "确认关闭？",
        Content = "确定要关闭此菜单吗？关闭后需要重新执行脚本才能再次打开。",
        ConfirmText = "关闭",
        CancelText = "取消",
        ConfirmDanger = true,
        Callback = function(yes)
            if yes then self:Destroy() end
        end,
    })
end

function Window:Confirm(opts)
    opts = opts or {}
    local colors = self.Colors
    local dim = Create("Frame", {
        Parent = self.ScreenGui, Size = UDim2Scale(1, 1), Position = UDim2Scale(0, 0),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ZIndex = 200, Active = true,
    })
    tween(dim, 0.18, { BackgroundTransparency = 0.55 })
    local card = Create("Frame", {
        Parent = dim, Size = UDim2Offset(320, 0), Position = UDim2.new(0.5, -160, 0.5, -75),
        BackgroundColor3 = colors.Surface, BorderSizePixel = 0, ZIndex = 201, ClipsDescendants = true,
    })
    newCorner(card, 12)
    newStroke(card, colors.Border, 1, 0.5)
    Create("UIListLayout", { Parent = card, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) })
    Create("UIPadding", { Parent = card, PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) })
    local titleBar = Create("Frame", { Parent = card, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = colors.Surface2, BorderSizePixel = 0 })
    local title = Create("TextLabel", {
        Parent = titleBar, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, Text = opts.Title or "确认", TextColor3 = colors.Text,
        Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    local content = Create("TextLabel", {
        Parent = card, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1, Text = opts.Content or "", TextColor3 = colors.SubText,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    })
    local btnRow = Create("Frame", { Parent = card, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 })
    local cancelBtn = Create("TextButton", {
        Parent = btnRow, Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2Offset(130, 32),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = colors.Surface3, BorderSizePixel = 0,
        Text = opts.CancelText or "取消", TextColor3 = colors.Text, Font = Enum.Font.GothamSemibold,
        TextSize = 13, AutoButtonColor = false, ZIndex = 202,
    })
    newCorner(cancelBtn, 7)
    local confirmBtn = Create("TextButton", {
        Parent = btnRow, Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2Offset(130, 32),
        AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = opts.ConfirmDanger and colors.Danger or colors.Accent,
        BorderSizePixel = 0, Text = opts.ConfirmText or "确认", TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false, ZIndex = 202,
    })
    newCorner(confirmBtn, 7)

    local function finish(yes)
        tween(dim, 0.15, { BackgroundTransparency = 1 })
        tween(card, 0.15, { Size = UDim2Offset(300, 0), BackgroundTransparency = 1 })
        spawn(function() wait(0.18); dim:Destroy() end)
        self:PlaySound(yes and "Click" or "Close")
        safeCall(opts.Callback, yes)
    end
    hoverButton(cancelBtn, colors.Surface3, colors.SurfaceHover, self)
    hoverButton(confirmBtn, opts.ConfirmDanger and colors.Danger or colors.Accent, opts.ConfirmDanger and lerpColor(colors.Danger, Color3.new(1, 1, 1), 0.2) or colors.AccentLight, self)
    cancelBtn.MouseButton1Click:Connect(function() finish(false) end)
    confirmBtn.MouseButton1Click:Connect(function() finish(true) end)

    local totalH = 40 + 46 + 52
    card.Size = UDim2Offset(320, 0)
    tween(card, 0.18, { Size = UDim2Offset(320, totalH) })
end

function Window:Destroy()
    self:SaveConfig()
    for _, c in ipairs(self.Cleanup) do
        pcall(function() c:Disconnect() end)
    end
    if self.Frame then
        tween(self.Frame, 0.16, { Size = UDim2Offset(self.Frame.AbsoluteSize.X * 0.92, self.Frame.AbsoluteSize.Y * 0.92) })
        spawn(function() wait(0.2) if self.ScreenGui then self.ScreenGui:Destroy() end end)
    end
end

-- ============================ 弹层 ============================
function Window:ClosePopups()
    if self.ActivePopup then
        local popup = self.ActivePopup
        self.ActivePopup = nil
        if popup.Close then popup.Close() end
    end
    self.Overlay.Visible = false
end

function Window:ClosePopup(element)
    local p = element.Popup
    element.Popup = nil
    if p then
        if p.OpenTween then p.OpenTween:Cancel() end
        tween(p, 0.12, { Size = UDim2.new(p.Size.X.Scale, p.Size.X.Offset, 0, 0), BackgroundTransparency = 1 })
        spawn(function() wait(0.15) p:Destroy() end)
    end
end

function Window:OpenDropdown(element)
    self:ClosePopups()
    self.ActivePopup = { Close = function() self:ClosePopup(element) end }
    self.Overlay.Visible = true
    local colors = self.Colors
    local trigger = element.TriggerLabel
    local rel = trigger.AbsolutePosition - self.Frame.AbsolutePosition
    local width = trigger.AbsoluteSize.X
    local list = Create("Frame", {
        Parent = self.Overlay, Position = UDim2Offset(rel.X, rel.Y + trigger.AbsoluteSize.Y + 4),
        Size = UDim2Offset(width, 0), BackgroundColor3 = colors.Surface, BorderSizePixel = 0,
        ClipsDescendants = true, ZIndex = 60,
    })
    newCorner(list, 7)
    newStroke(list, colors.Border, 1, 0.5)
    Create("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) })
    element.Popup = list
    element.CurrentList = list

    local optionHeight = 30
    for idx, opt in ipairs(element.Options) do
        local item = Create("TextButton", {
            Parent = list, LayoutOrder = idx, Size = UDim2.new(1, 0, 0, optionHeight),
            BackgroundColor3 = (opt == element.Selected) and colors.SurfaceActive or colors.Surface,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 61,
        })
        local itemLabel = Create("TextLabel", {
            Parent = item, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -34, 1, 0),
            BackgroundTransparency = 1, Text = tostring(opt),
            TextColor3 = (opt == element.Selected) and colors.Text or colors.SubText,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        local check = Create("TextLabel", {
            Parent = item, Position = UDim2.new(1, -24, 0, 0), Size = UDim2Offset(16, optionHeight),
            BackgroundTransparency = 1, Text = (opt == element.Selected) and "•" or "",
            TextColor3 = colors.Accent, Font = Enum.Font.GothamBold, TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
        })
        item.MouseEnter:Connect(function()
            tween(item, 0.12, { BackgroundColor3 = colors.SurfaceHover })
            itemLabel.TextColor3 = colors.Text
        end)
        item.MouseLeave:Connect(function()
            local sel = (opt == element.Selected)
            tween(item, 0.12, { BackgroundColor3 = sel and colors.SurfaceActive or colors.Surface })
            itemLabel.TextColor3 = sel and colors.Text or colors.SubText
        end)
        item.MouseButton1Click:Connect(function()
            self:PlaySound("Click")
            element:Set(opt)
            self:ClosePopups()
        end)
    end

    local fullHeight = #element.Options * optionHeight
    list.OpenTween = tween(list, 0.18, { Size = UDim2Offset(width, fullHeight) })
    self:PlaySound("Open")
end

local function buildGradientSlider(parent, colors, label, order)
    local holder = Create("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
    local lbl = Create("TextLabel", {
        Parent = holder, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1, Text = label, TextColor3 = colors.SubText, Font = Enum.Font.GothamMedium,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    local track = Create("Frame", {
        Parent = holder, Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    })
    newCorner(track, 4)
    local gradient = Create("UIGradient", { Parent = track, Color = ColorSequence.new(Color3.new(1, 1, 1)) })
    local knob = Create("Frame", {
        Parent = track, Size = UDim2Offset(14, 14), Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
    })
    newCorner(knob, 999)
    newStroke(knob, Color3.new(0, 0, 0), 1, 0.55)
    return { Holder = holder, Track = track, Knob = knob, Gradient = gradient }
end

function Window:OpenColorpicker(element)
    self:ClosePopups()
    self.ActivePopup = { Close = function() self:ClosePopup(element) end }
    self.Overlay.Visible = true
    local colors = self.Colors
    local w = 236
    local rel = element.Swatch.AbsolutePosition - self.Frame.AbsolutePosition
    local frameH = self.Frame.AbsoluteSize.Y
    local fullHeight = 36 + 26 * 3 + 28 + 22 + 10 * 2 + 8 * 5
    local openDown = (rel.Y + 24 + fullHeight) <= (frameH - 10)
    local posY = openDown and (rel.Y + 24) or (rel.Y - fullHeight - 8)
    if posY < 0 then posY = 4 end

    local panel = Create("Frame", {
        Parent = self.Overlay, Position = UDim2Offset(rel.X, posY), Size = UDim2Offset(w, 0),
        BackgroundColor3 = colors.Surface, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 60,
    })
    newCorner(panel, 8)
    newStroke(panel, colors.Border, 1, 0.5)
    Create("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })
    Create("UIPadding", {
        Parent = panel, PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
    })
    element.Popup = panel

    local h, s, v = color3ToHSV(element.Value or Color3.new(1, 1, 1))

    local preview = Create("Frame", {
        Parent = panel, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = element.Value or Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 61,
    })
    newCorner(preview, 6)
    newStroke(preview, colors.Border, 1, 0.5)
    local previewHex = Create("TextLabel", {
        Parent = preview, Size = UDim2Scale(1, 1), BackgroundTransparency = 1,
        Text = color3ToHex(element.Value or Color3.new(1, 1, 1)), TextColor3 = contrastColor(element.Value or Color3.new(1, 1, 1)),
        Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
    })

    local hueSlider = buildGradientSlider(panel, colors, "Hue", 2)
    local satSlider = buildGradientSlider(panel, colors, "Saturation", 3)
    local valSlider = buildGradientSlider(panel, colors, "Value", 4)
    hueSlider.Gradient.Color = hueGradient()

    local function updateSatValGradients()
        local pure = hsvToColor3(h, 1, 1)
        satSlider.Gradient.Color = ColorSequence.new(hsvToColor3(h, 0, 1), pure)
        valSlider.Gradient.Color = ColorSequence.new(Color3.new(0, 0, 0), pure)
    end
    updateSatValGradients()

    local function refresh(fire)
        local c = hsvToColor3(h, s, v)
        preview.BackgroundColor3 = c
        previewHex.Text = color3ToHex(c)
        previewHex.TextColor3 = contrastColor(c)
        hueSlider.Knob.Position = UDim2.new(h, 0, 0.5, 0)
        satSlider.Knob.Position = UDim2.new(s, 0, 0.5, 0)
        valSlider.Knob.Position = UDim2.new(v, 0, 0.5, 0)
        element.Apply(c, fire ~= false)
    end
    element.Refresh = refresh

    makeDraggableSlider(hueSlider.Track, hueSlider.Knob, function(t) h = t; updateSatValGradients(); refresh() end, self)
    makeDraggableSlider(satSlider.Track, satSlider.Knob, function(t) s = t; refresh() end, self)
    makeDraggableSlider(valSlider.Track, valSlider.Knob, function(t) v = t; refresh() end, self)
    refresh(false)

    -- 十六进制输入 + 复制
    local hexRow = Create("Frame", { Parent = panel, LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 })
    local hexBox = Create("TextBox", {
        Parent = hexRow, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, -50, 1, 0),
        BackgroundColor3 = colors.Surface3, BorderSizePixel = 0, Text = color3ToHex(element.Value or Color3.new(1, 1, 1)),
        TextColor3 = colors.Text, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, ZIndex = 61,
    })
    newCorner(hexBox, 6)
    newStroke(hexBox, colors.Border, 1, 0.4)
    hexBox.FocusLost:Connect(function()
        local c = hexToColor3(hexBox.Text)
        if c then h, s, v = color3ToHSV(c); updateSatValGradients(); refresh()
        else hexBox.Text = color3ToHex(element.Value or Color3.new(1, 1, 1)) end
    end)
    local copyBtn = Create("TextButton", {
        Parent = hexRow, Position = UDim2.new(1, -44, 0, 0), Size = UDim2Offset(44, 28),
        BackgroundColor3 = colors.Surface2, BorderSizePixel = 0, Text = "复制", TextColor3 = colors.Text,
        Font = Enum.Font.GothamSemibold, TextSize = 12, AutoButtonColor = false, ZIndex = 61,
    })
    newCorner(copyBtn, 6)
    hoverButton(copyBtn, colors.Surface2, colors.SurfaceHover, self)
    copyBtn.MouseButton1Click:Connect(function()
        if setclipboard then pcall(setclipboard, color3ToHex(element.Value or Color3.new(1, 1, 1))) end
        self:Notify({ Title = "已复制", Content = color3ToHex(element.Value or Color3.new(1, 1, 1)), Type = "Success", Duration = 1.5 })
    end)

    -- 预设色
    local presets = {
        rgb(255, 255, 255), rgb(0, 0, 0), rgb(255, 80, 80), rgb(255, 160, 40), rgb(255, 230, 60),
        rgb(80, 220, 120), rgb(60, 200, 230), rgb(86, 144, 255), rgb(150, 110, 255), rgb(240, 110, 180),
    }
    local presetRow = Create("Frame", { Parent = panel, LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
    Create("UIListLayout", { Parent = presetRow, FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
    for i, pc in ipairs(presets) do
        local sw = Create("TextButton", {
            Parent = presetRow, LayoutOrder = i, Size = UDim2Offset(18, 18),
            BackgroundColor3 = pc, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        })
        newCorner(sw, 4)
        newStroke(sw, colors.Border, 1, 0.5)
        sw.MouseButton1Click:Connect(function()
            h, s, v = color3ToHSV(pc); updateSatValGradients(); refresh()
        end)
    end

    panel.OpenTween = tween(panel, 0.18, { Size = UDim2Offset(w, fullHeight) })
    self:PlaySound("Open")
end

-- ============================ 通知 ============================
function Window:Notify(opts)
    opts = opts or {}
    local typeName = opts.Type or "Info"
    local colors = self.Colors
    local typeColor = colors.Info
    if typeName == "Success" then typeColor = colors.Success
    elseif typeName == "Warning" then typeColor = colors.Warning
    elseif typeName == "Error" then typeColor = colors.Danger end

    if not self.NotifHolder then
        self.NotifHolder = Create("Frame", {
            Parent = self.ScreenGui, Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0),
            Size = UDim2Offset(300, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 300,
        })
    end

    self.NotifCount = self.NotifCount + 1
    local notif = Create("Frame", {
        Parent = self.NotifHolder, Size = UDim2Offset(300, 0), Position = UDim2Offset(0, 0),
        BackgroundColor3 = colors.Surface, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 301,
    })
    newCorner(notif, 8)
    newStroke(notif, colors.Border, 1, 0.5)
    Create("Frame", {
        Parent = notif, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = typeColor, BorderSizePixel = 0, ZIndex = 302,
    })
    local icon = Create("TextLabel", {
        Parent = notif, Position = UDim2.new(0, 12, 0, 12), Size = UDim2Offset(18, 18),
        BackgroundColor3 = typeColor, BorderSizePixel = 0, Text = warnIcon(typeName),
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 302,
    })
    newCorner(icon, 999)
    local tlabel = Create("TextLabel", {
        Parent = notif, Position = UDim2.new(0, 38, 0, 10), Size = UDim2.new(1, -52, 0, 16),
        BackgroundTransparency = 1, Text = opts.Title or typeName, TextColor3 = colors.Text,
        Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 302,
    })
    local clabel = Create("TextLabel", {
        Parent = notif, Position = UDim2.new(0, 38, 0, 27), Size = UDim2.new(1, -52, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = opts.Content or "",
        TextColor3 = colors.SubText, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, RichText = false, ZIndex = 302,
    })
    local closeBtn = Create("TextButton", {
        Parent = notif, Position = UDim2.new(1, -26, 0, 8), Size = UDim2Offset(18, 18),
        BackgroundColor3 = colors.Surface3, BorderSizePixel = 0, Text = "×", TextColor3 = colors.SubText,
        Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center, AutoButtonColor = false, ZIndex = 302,
    })
    newCorner(closeBtn, 999)
    local progress = Create("Frame", {
        Parent = notif, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = typeColor, BorderSizePixel = 0, ZIndex = 303,
    })

    local contentH = TextService:GetTextSize(opts.Content or "", 12, Enum.Font.GothamMedium, Vector2.new(300 - 64, math.huge)).Y
    local h = math.max(58, 44 + math.ceil(contentH))
    notif.Size = UDim2Offset(300, h)

    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        for i, n in ipairs(self.NotifStack) do
            if n == notif then table.remove(self.NotifStack, i); break end
        end
        tween(notif, 0.2, { Position = UDim2Offset(340, notif.Position.Y.Offset), BackgroundTransparency = 1 })
        spawn(function() wait(0.22) notif:Destroy() end)
        self:LayoutNotifs()
    end

    -- 计算位置并滑入
    local y = 0
    for _, n in ipairs(self.NotifStack) do y = y + n.AbsoluteSize.Y + 8 end
    notif.Position = UDim2Offset(340, y)
    table.insert(self.NotifStack, notif)
    tween(notif, 0.25, { Position = UDim2Offset(0, y) })

    self:LayoutNotifs()
    self:PlaySound(typeName == "Error" and "Error" or "Notify")

    closeBtn.MouseButton1Click:Connect(dismiss)
    notif.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dismiss() end
    end)

    local duration = opts.Duration or 3
    if duration and duration > 0 then
        tween(progress, duration, { Size = UDim2.new(0, 0, 0, 2) })
        spawn(function() wait(duration); if not dismissed then dismiss() end end)
    end
end

function Window:LayoutNotifs()
    local y = 0
    for _, n in ipairs(self.NotifStack) do
        tween(n, 0.2, { Position = UDim2Offset(0, y) })
        y = y + n.AbsoluteSize.Y + 8
    end
end

-- ============================ Tab ============================
Tab.__index = Tab

function Tab.new(window, title)
    local self = setmetatable({}, Tab)
    self.Window = window
    self.Title = title or "Tab"
    self.Sections = {}
    self.Active = false
    local colors = window.Colors

    local textW = TextService:GetTextSize(self.Title, 13, Enum.Font.GothamSemibold, Vector2.new(math.huge, 30)).X
    self.Button = Create("TextButton", {
        Parent = window.TabBar, Size = UDim2.new(0, math.ceil(textW) + 28, 1, 0),
        BackgroundColor3 = colors.Surface, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3,
    })
    self.Label = Create("TextLabel", {
        Parent = self.Button, Size = UDim2Scale(1, 1), BackgroundTransparency = 1, Text = self.Title,
        TextColor3 = colors.SubText, Font = Enum.Font.GothamSemibold, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4,
    })
    self.Button.MouseEnter:Connect(function()
        if not self.Active then tween(self.Label, 0.15, { TextColor3 = colors.Text }) end
        window:PlaySound("Hover")
    end)
    self.Button.MouseLeave:Connect(function()
        if not self.Active then tween(self.Label, 0.15, { TextColor3 = colors.SubText }) end
    end)
    self.Button.MouseButton1Click:Connect(function()
        window:SelectTab(self)
    end)

    function self:AddSection(t)
        local section = Section.new(self, t)
        table.insert(self.Sections, section)
        section.Container.Visible = (window.CurrentTab == self)
        return section
    end
    self.Section = self.AddSection

    function self:SetTitle(t)
        self.Title = t
        self.Label.Text = t
        local w = TextService:GetTextSize(t, 13, Enum.Font.GothamSemibold, Vector2.new(math.huge, 30)).X
        self.Button.Size = UDim2.new(0, math.ceil(w) + 28, 1, 0)
        if self.Active then window:SelectTab(self, true) end
    end

    function self:Select()
        window:SelectTab(self)
    end

    function self:Recolor(c)
        self.Button.BackgroundColor3 = self.Active and c.Surface2 or c.Surface
        self.Label.TextColor3 = self.Active and c.Text or c.SubText
    end

    return self
end

-- ============================ Section ============================
Section.__index = Section

function Section.new(tab, title)
    local self = setmetatable({}, Section)
    self.Tab = tab
    self.Window = tab.Window
    self.Title = title or "Section"
    self.Elements = {}
    self.Collapsed = false
    local win = tab.Window
    local colors = win.Colors

    self.Container = Create("Frame", {
        Parent = win.Content, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = colors.Surface, BorderSizePixel = 0, Visible = false, ZIndex = 1,
    })
    newCorner(self.Container, 9)
    self.ContainerStroke = newStroke(self.Container, colors.Border, 1, 0.5)
    sectionOrder = sectionOrder + 1
    self.Container.LayoutOrder = sectionOrder
    Create("UIListLayout", {
        Parent = self.Container, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
    })
    Create("UIPadding", {
        Parent = self.Container, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
    })

    self.Header = Create("TextButton", {
        Parent = self.Container, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = colors.Surface, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 2,
    })
    self.HeaderTitle = Create("TextLabel", {
        Parent = self.Header, Position = UDim2.new(0, 2, 0, 0), Size = UDim2.new(1, -30, 1, 0),
        BackgroundTransparency = 1, Text = self.Title, TextColor3 = colors.Text,
        Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 3,
    })
    self.Chevron = makeChevron(self.Header, colors.SubText, 12, false)
    self.Chevron.Position = UDim2.new(1, -18, 0.5, 0)

    self.Body = Create("Frame", {
        Parent = self.Container, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
    })
    self.ElementList = Create("UIListLayout", {
        Parent = self.Body, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
    })

    local function toggle()
        self.Collapsed = not self.Collapsed
        self.Body.Visible = not self.Collapsed
        self.Chevron.SetExpanded(not self.Collapsed)
        if self.Collapsed then win:PlaySound("Close") else win:PlaySound("Open") end
    end
    self.Header.MouseButton1Click:Connect(function()
        win:PlaySound("Click")
        toggle()
    end)

    function self:Toggle() toggle() end
    function self:Collapse() if not self.Collapsed then toggle() end end
    function self:Expand() if self.Collapsed then toggle() end end
    function self:SetTitle(t) self.Title = t; self.HeaderTitle.Text = t end
    function self:SetVisible(v) self.Container.Visible = v end

    function self:Recolor(c)
        self.Container.BackgroundColor3 = c.Surface
        self.ContainerStroke.Color = c.Border
        self.Header.BackgroundColor3 = c.Surface
        self.HeaderTitle.TextColor3 = c.Text
        self.Chevron.SetColor(c.SubText)
    end

    win:AddSection(self)
    return self
end

-- 元素基类（用闭包实现，便于每个组件覆盖方法）
local function newElement(window, tabTitle, sectionTitle, title, etype)
    local self = {}
    self.Window = window
    self.TabTitle = tabTitle
    self.SectionTitle = sectionTitle
    self.Title = title
    self.Type = etype or "Element"
    self.Key = window:GenerateKey(tabTitle, sectionTitle, title)
    self.Value = nil
    self.Callback = nil
    self.Visible = true
    self.Frame = nil
    self.Popup = nil

    function self:GetValue() return self.Value end
    function self:SetValue(v) self.Value = v; window:OnElementChanged(self, v); return self end
    function self:Set(v) return self:SetValue(v) end
    function self:Get() return self:GetValue() end
    function self:SetCallback(fn) self.Callback = fn; return self end
    function self:SetTitle(text)
        self.Title = text
        if self.TitleLabel then self.TitleLabel.Text = text end
        return self
    end
    function self:SetVisible(v)
        self.Visible = v
        if self.Frame then self.Frame.Visible = v end
        return self
    end
    function self:Destroy()
        if self.Popup then window:ClosePopup(self) end
        window:UnregisterElement(self)
        if self.Frame then self.Frame:Destroy() end
    end
    return self
end

-- ============================ 组件 ============================

function Section:Button(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or "Button", "Button")
    element.Callback = opts.Callback
    local colors = self.Window.Colors
    local row, inner = newButtonRow(self.Body, colors, 40, self.Window, {
        AccentBar = true, SoundName = opts.SoundName or "Click", OnClick = opts.Callback,
    })
    element.Frame = row
    element.Inner = inner
    local title = newTitle(inner, colors, element.Title, 1)
    title.Position = UDim2.new(0, 12, 0, 0)
    element.TitleLabel = title
    if opts.Image then
        Create("ImageLabel", {
            Parent = inner, Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2Offset(16, 16),
            AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Image = opts.Image, ZIndex = 4,
        })
        title.Position = UDim2.new(0, 36, 0, 0)
        title.Size = UDim2.new(1, -36, 1, 0)
    end
    element.Recolor = function(c)
        inner.BackgroundColor3 = c.Surface2
        title.TextColor3 = c.Text
    end
    self.Window:RegisterElement(element)
    return element
end

function Section:Toggle(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or "Toggle", "Toggle")
    element.Callback = opts.Callback
    local colors = self.Window.Colors
    local row, inner = newButtonRow(self.Body, colors, 40, self.Window, {})
    element.Frame = row
    element.Inner = inner
    local title = newTitle(inner, colors, element.Title, 0.6)
    element.TitleLabel = title
    local track = Create("Frame", {
        Parent = inner, Position = UDim2.new(1, -48, 0.5, 0), Size = UDim2Offset(36, 20),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = colors.Surface3, BorderSizePixel = 0, ZIndex = 5,
    })
    newCorner(track, 999)
    local knob = Create("Frame", {
        Parent = track, Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2Offset(16, 16),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = colors.SubText, BorderSizePixel = 0, ZIndex = 6,
    })
    newCorner(knob, 999)
    element.Track = track
    element.Knob = knob

    local function setVal(v, instant, fire)
        v = (v == true)
        element.Value = v
        if v then
            track.BackgroundColor3 = colors.Accent
            knob.BackgroundColor3 = Color3.new(1, 1, 1)
            if instant then knob.Position = UDim2.new(1, -18, 0.5, 0)
            else tween(knob, 0.18, { Position = UDim2.new(1, -18, 0.5, 0) }) end
        else
            track.BackgroundColor3 = colors.Surface3
            knob.BackgroundColor3 = colors.SubText
            if instant then knob.Position = UDim2.new(0, 2, 0.5, 0)
            else tween(knob, 0.18, { Position = UDim2.new(0, 2, 0.5, 0) }) end
        end
        if fire ~= false then
            self.Window:PlaySound("Toggle")
            self.Window:OnElementChanged(element, v)
            safeCall(element.Callback, v)
        end
    end
    function element:Set(v) setVal(v, false, true) end
    function element:Get() return element.Value end
    function element:Toggle() setVal(not element.Value, false, true) end
    inner.MouseButton1Click:Connect(function() setVal(not element.Value, false, true) end)

    element.Recolor = function(c)
        inner.BackgroundColor3 = c.Surface2
        title.TextColor3 = c.Text
        track.BackgroundColor3 = element.Value and c.Accent or c.Surface3
        knob.BackgroundColor3 = element.Value and Color3.new(1, 1, 1) or c.SubText
    end

    local initial = self.Window:GetInitial(element.Key, opts.Default ~= nil and opts.Default or opts.Value)
    if type(initial) ~= "boolean" then initial = false end
    setVal(initial, true, false)
    self.Window:RegisterElement(element)
    return element
end

function Section:Slider(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or "Slider", "Slider")
    element.Callback = opts.Callback
    element.Min = opts.Min or 0
    element.Max = opts.Max or 100
    element.Step = opts.Step
    element.Decimals = opts.Decimals
    element.Suffix = opts.Suffix or ""
    local colors = self.Window.Colors
    local row = newRow(self.Body, colors, 52)
    element.Frame = row

    local title = Create("TextLabel", {
        Parent = row, Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(0.55, -12, 0, 16),
        BackgroundTransparency = 1, Text = element.Title, TextColor3 = colors.Text, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    element.TitleLabel = title
    local valueLabel = Create("TextLabel", {
        Parent = row, Position = UDim2.new(0.55, 0, 0, 6), Size = UDim2.new(0.45, -12, 0, 16),
        BackgroundTransparency = 1, Text = "", TextColor3 = colors.Accent, Font = Enum.Font.GothamBold,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center,
    })
    element.ValueLabel = valueLabel
    local track = Create("Frame", {
        Parent = row, Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(1, -24, 0, 8),
        BackgroundColor3 = colors.Surface3, BorderSizePixel = 0,
    })
    newCorner(track, 4)
    local fill = Create("Frame", {
        Parent = track, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = colors.Accent, BorderSizePixel = 0, ZIndex = 1,
    })
    newCorner(fill, 4)
    local knob = Create("Frame", {
        Parent = track, Size = UDim2Offset(16, 16), Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
    })
    newCorner(knob, 999)
    newStroke(knob, colors.Accent, 2, 0)
    element.Track = track
    element.Fill = fill
    element.Knob = knob

    local function clampVal(v)
        v = clamp(v, element.Min, element.Max)
        if element.Step and element.Step > 0 then
            v = element.Min + math.floor((v - element.Min) / element.Step + 0.5) * element.Step
            v = clamp(v, element.Min, element.Max)
        end
        return v
    end
    local function fmt(v)
        local decimals = element.Decimals
        if decimals == nil then
            decimals = 0
            if element.Step and element.Step > 0 and element.Step < 1 then
                local s = tostring(element.Step)
                local dot = s:find(".", 1, true)
                if dot then decimals = #s - dot end
            end
        end
        return string.format("%." .. decimals .. "f", v)
    end
    local function setVal(v, fromMouse, fire)
        v = clampVal(v)
        element.Value = v
        valueLabel.Text = fmt(v) .. element.Suffix
        local t = (element.Max == element.Min) and 0 or ((v - element.Min) / (element.Max - element.Min))
        if fromMouse then
            fill.Size = UDim2.new(t, 0, 1, 0)
            knob.Position = UDim2.new(t, 0, 0.5, 0)
        else
            tween(fill, 0.15, { Size = UDim2.new(t, 0, 1, 0) })
            tween(knob, 0.15, { Position = UDim2.new(t, 0, 0.5, 0) })
        end
        if fire ~= false then
            self.Window:OnElementChanged(element, v)
            safeCall(element.Callback, v)
        end
    end
    function element:Set(v) setVal(v, false, true) end
    function element:Get() return element.Value end

    makeDraggableSlider(track, knob, function(f)
        local v = element.Min + (element.Max - element.Min) * f
        setVal(v, true, true)
    end, self.Window)

    element.Recolor = function(c)
        title.TextColor3 = c.Text
        valueLabel.TextColor3 = c.Accent
        track.BackgroundColor3 = c.Surface3
        fill.BackgroundColor3 = c.Accent
    end

    local initial = self.Window:GetInitial(element.Key, opts.Default ~= nil and opts.Default or opts.Value)
    if type(initial) ~= "number" then initial = element.Min end
    setVal(initial, true, false)
    self.Window:RegisterElement(element)
    return element
end

function Section:Dropdown(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or "Dropdown", "Dropdown")
    element.Callback = opts.Callback
    element.Options = opts.Options or {}
    element.Selected = opts.Default or (opts.Options and opts.Options[1]) or ""
    local colors = self.Window.Colors
    local row, inner = newButtonRow(self.Body, colors, 40, self.Window, {})
    element.Frame = row
    element.Inner = inner
    local title = newTitle(inner, colors, element.Title, 0.48)
    element.TitleLabel = title
    local trigger = Create("TextLabel", {
        Parent = inner, Position = UDim2.new(0.48, 0, 0, 0), Size = UDim2.new(0.52, -30, 1, 0),
        BackgroundTransparency = 1, Text = tostring(element.Selected), TextColor3 = colors.Text,
        Font = Enum.Font.GothamSemibold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
    })
    element.TriggerLabel = trigger
    local chevron = makeChevron(inner, colors.SubText, 12, true)
    chevron.Position = UDim2.new(1, -22, 0.5, 0)
    element.Chevron = chevron

    local function setSelected(value)
        element.Selected = value
        trigger.Text = tostring(value)
        self.Window:OnElementChanged(element, value)
        safeCall(element.Callback, value)
    end
    function element:Set(v) setSelected(v) end
    function element:Get() return element.Selected end
    function element:SetOptions(list)
        element.Options = list or {}
        local has = false
        for _, o in ipairs(element.Options) do if o == element.Selected then has = true; break end end
        if not has and element.Options[1] then setSelected(element.Options[1]) end
    end
    inner.MouseButton1Click:Connect(function()
        self.Window:OpenDropdown(element)
    end)

    element.Recolor = function(c)
        inner.BackgroundColor3 = c.Surface2
        title.TextColor3 = c.Text
        trigger.TextColor3 = c.Text
        chevron.SetColor(c.SubText)
    end

    local initial = self.Window:GetInitial(element.Key, element.Selected)
    if type(initial) == "string" then
        element.Selected = initial
        trigger.Text = initial
    end
    self.Window:RegisterElement(element)
    return element
end

function Section:TextBox(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or "TextBox", "TextBox")
    element.Callback = opts.Callback
    local colors = self.Window.Colors
    local row = newRow(self.Body, colors, 40)
    element.Frame = row
    local title = newTitle(row, colors, element.Title, 0.42)
    element.TitleLabel = title
    local box = Create("TextBox", {
        Parent = row, Position = UDim2.new(0.42, 0, 0.5, 0), Size = UDim2.new(0.58, -24, 0, 26),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = colors.Surface3, BorderSizePixel = 0, Text = "",
        TextColor3 = colors.Text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, PlaceholderText = opts.Placeholder or "",
        PlaceholderColor3 = colors.SubText, ClearTextOnFocus = false, ZIndex = 4,
    })
    newCorner(box, 6)
    local boxStroke = newStroke(box, colors.Border, 1, 0.4)
    element.Box = box

    local function commit()
        element.Value = box.Text
        self.Window:OnElementChanged(element, box.Text)
        safeCall(element.Callback, box.Text)
    end
    function element:Set(t)
        t = tostring(t)
        box.Text = t
        element.Value = t
        self.Window:OnElementChanged(element, t)
    end
    function element:Get() return box.Text end
    box.FocusLost:Connect(function() commit() end)

    element.Recolor = function(c)
        title.TextColor3 = c.Text
        box.BackgroundColor3 = c.Surface3
        box.TextColor3 = c.Text
        box.PlaceholderColor3 = c.SubText
        boxStroke.Color = c.Border
    end

    local initial = self.Window:GetInitial(element.Key, opts.Default ~= nil and opts.Default or opts.Value)
    if type(initial) == "string" then box.Text = initial; element.Value = initial
    elseif type(initial) == "number" then box.Text = tostring(initial); element.Value = tostring(initial) end
    self.Window:RegisterElement(element)
    return element
end

function Section:Keybind(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or "Keybind", "Keybind")
    element.Callback = opts.Callback
    element.Pressed = opts.Pressed
    local colors = self.Window.Colors
    local row, inner = newButtonRow(self.Body, colors, 40, self.Window, { AccentBar = true })
    element.Frame = row
    element.Inner = inner
    local title = newTitle(inner, colors, element.Title, 0.55)
    element.TitleLabel = title
    local keyLabel = Create("TextLabel", {
        Parent = inner, Position = UDim2.new(0.55, 0, 0, 0), Size = UDim2.new(0.45, -12, 1, 0),
        BackgroundTransparency = 1, Text = "无", TextColor3 = colors.SubText, Font = Enum.Font.GothamBold,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4,
    })
    element.KeyLabel = keyLabel
    local binding = false

    local function setKey(key, fire)
        if key == nil then
            element.Value = nil
            keyLabel.Text = "无"
            keyLabel.TextColor3 = colors.SubText
        else
            element.Value = key
            keyLabel.Text = keyName(key)
            keyLabel.TextColor3 = colors.Text
        end
        if fire ~= false then
            self.Window:OnElementChanged(element, key and key.Name or nil)
            safeCall(element.Callback, key)
        end
    end
    function element:Set(v) setKey(v, true) end
    function element:Get() return element.Value end
    function element:Clear() setKey(nil, true) end

    -- 已绑定按键的按下监听
    local pressConn = UserInputService.InputBegan:Connect(function(input, gp)
        if binding or not element.Value then return end
        if UserInputService:GetFocusedTextBox() then return end
        local matches = false
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            matches = (input.KeyCode == element.Value)
        else
            matches = (input.UserInputType == element.Value)
        end
        if matches then safeCall(element.Pressed, element.Value) end
    end)
    self.Window:AddCleanup(pressConn)

    inner.MouseButton1Click:Connect(function()
        if binding then return end
        binding = true
        keyLabel.Text = "..."
        keyLabel.TextColor3 = colors.Accent
        self.Window:PlaySound("Bind")
        local bindConn
        local function finish()
            bindConn:Disconnect()
            binding = false
        end
        bindConn = UserInputService.InputBegan:Connect(function(input, gp)
            if input.UserInputType == Enum.UserInputType.MouseMovement then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then return end
            if input.KeyCode == Enum.KeyCode.Backspace or input.UserInputType == Enum.UserInputType.MouseButton2 then
                finish()
                setKey(nil, true)
                self.Window:PlaySound("Close")
                return
            end
            local key = (input.KeyCode ~= Enum.KeyCode.Unknown) and input.KeyCode or input.UserInputType
            finish()
            setKey(key, true)
            self.Window:PlaySound("Click")
        end)
        self.Window:AddCleanup(bindConn)
    end)

    element.Recolor = function(c)
        inner.BackgroundColor3 = c.Surface2
        title.TextColor3 = c.Text
        keyLabel.TextColor3 = element.Value and c.Text or c.SubText
    end

    local initial = self.Window:GetInitial(element.Key, opts.Default or opts.Value)
    local loadedKey = nil
    if type(initial) == "string" then
        local k = Enum.KeyCode[initial] or Enum.UserInputType[initial]
        if k and k ~= Enum.KeyCode.Unknown then loadedKey = k end
    elseif type(initial) == "userdata" and initial.Name then
        loadedKey = initial
    end
    setKey(loadedKey, false)
    self.Window:RegisterElement(element)
    return element
end

function Section:Colorpicker(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or "Colorpicker", "Colorpicker")
    element.Callback = opts.Callback
    local colors = self.Window.Colors
    local row, inner = newButtonRow(self.Body, colors, 40, self.Window, {})
    element.Frame = row
    element.Inner = inner
    local title = newTitle(inner, colors, element.Title, 0.6)
    element.TitleLabel = title
    local swatch = Create("Frame", {
        Parent = inner, Position = UDim2.new(1, -72, 0.5, 0), Size = UDim2Offset(18, 18),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5,
    })
    newCorner(swatch, 4)
    local swatchStroke = newStroke(swatch, colors.Border, 1, 0.4)
    local hexLabel = Create("TextLabel", {
        Parent = inner, Position = UDim2.new(1, -48, 0, 0), Size = UDim2.new(0, 40, 1, 0),
        BackgroundTransparency = 1, Text = "#FFFFFF", TextColor3 = colors.SubText, Font = Enum.Font.GothamSemibold,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4,
    })
    element.Swatch = swatch
    element.HexLabel = hexLabel

    local function applyColor(c, fire)
        c = c or Color3.new(1, 1, 1)
        element.Value = c
        swatch.BackgroundColor3 = c
        hexLabel.Text = color3ToHex(c)
        if fire then
            self.Window:OnElementChanged(element, color3ToHex(c))
            safeCall(element.Callback, c)
        end
    end
    element.Apply = applyColor
    function element:Set(v) applyColor(v, true) end
    function element:Get() return element.Value end
    inner.MouseButton1Click:Connect(function()
        self.Window:OpenColorpicker(element)
    end)

    element.Recolor = function(c)
        inner.BackgroundColor3 = c.Surface2
        title.TextColor3 = c.Text
        swatchStroke.Color = c.Border
        hexLabel.TextColor3 = c.SubText
    end

    local def = opts.Default or opts.Value
    local initial = self.Window:GetInitial(element.Key, def)
    if type(initial) == "string" then
        local c = hexToColor3(initial)
        applyColor(c or def or Color3.new(1, 1, 1), false)
    elseif type(initial) == "userdata" and initial.R then
        applyColor(initial, false)
    else
        applyColor(def or Color3.new(1, 1, 1), false)
    end
    self.Window:RegisterElement(element)
    return element
end

function Section:Label(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or opts.Text or "Label", "Label")
    element.Callback = opts.Callback
    local colors = self.Window.Colors
    local height = opts.Height or 30
    local row = newRow(self.Body, colors, height)
    element.Frame = row
    local label = Create("TextLabel", {
        Parent = row, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -24, 1, 0),
        BackgroundTransparency = 1, Text = opts.Text or opts.Title or "", TextColor3 = opts.Color or colors.SubText,
        Font = Enum.Font.GothamMedium, TextSize = opts.Size or 13,
        TextXAlignment = opts.Align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = false, RichText = false, ZIndex = 4,
    })
    element.TitleLabel = label
    element.Recolor = function(c) label.TextColor3 = c.SubText end
    self.Window:RegisterElement(element)
    return element
end

function Section:Paragraph(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or opts.Text or "Paragraph", "Paragraph")
    local colors = self.Window.Colors
    local text = opts.Content or opts.Text or ""
    local fontSize = opts.Size or 12
    local textSize = TextService:GetTextSize(text, fontSize, Enum.Font.GothamMedium, Vector2.new(1000, math.huge))
    local height = math.max(34, math.ceil(textSize.Y) + 16)
    local row = newRow(self.Body, colors, height)
    element.Frame = row
    local label = Create("TextLabel", {
        Parent = row, Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -24, 0, height - 16),
        BackgroundTransparency = 1, Text = text, TextColor3 = opts.Color or colors.SubText,
        Font = Enum.Font.GothamMedium, TextSize = fontSize, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, RichText = false, ZIndex = 4,
    })
    element.TitleLabel = label
    element.Recolor = function(c) label.TextColor3 = c.SubText end
    self.Window:RegisterElement(element)
    return element
end

function Section:Divider(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or "Divider", "Divider")
    local colors = self.Window.Colors
    local row = newRow(self.Body, colors, 18)
    element.Frame = row
    row.BackgroundTransparency = 1
    local line = Create("Frame", {
        Parent = row, Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = colors.Border, BorderSizePixel = 0, ZIndex = 3,
    })
    element.Line = line
    if opts.Title then
        local lbl = Create("TextLabel", {
            Parent = row, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2Offset(80, 14),
            AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = colors.Surface2, BorderSizePixel = 0,
            Text = opts.Title, TextColor3 = colors.SubText, Font = Enum.Font.GothamSemibold, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4,
        })
        element.TitleLabel = lbl
    end
    element.Recolor = function(c)
        line.BackgroundColor3 = c.Border
        if element.TitleLabel then element.TitleLabel.TextColor3 = c.SubText; element.TitleLabel.BackgroundColor3 = c.Surface2 end
    end
    self.Window:RegisterElement(element)
    return element
end

function Section:Warn(opts)
    opts = opts or {}
    local element = newElement(self.Window, self.Tab.Title, self.Title, opts.Title or "Warn", "Warn")
    local colors = self.Window.Colors
    local t = opts.Type or "Warning"
    local typeColor = colors.Warning
    if t == "Error" then typeColor = colors.Danger
    elseif t == "Success" then typeColor = colors.Success
    elseif t == "Info" then typeColor = colors.Info end
    element.TypeName = t
    local row = newRow(self.Body, colors, 46)
    element.Frame = row
    element.Accent = Create("Frame", {
        Parent = row, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = typeColor, BorderSizePixel = 0, ZIndex = 3,
    })
    local icon = Create("TextLabel", {
        Parent = row, Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2Offset(20, 20),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = typeColor, BorderSizePixel = 0, Text = warnIcon(t),
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 3,
    })
    newCorner(icon, 999)
    local title = Create("TextLabel", {
        Parent = row, Position = UDim2.new(0, 42, 0, 6), Size = UDim2.new(1, -70, 0, 15),
        BackgroundTransparency = 1, Text = opts.Title or t, TextColor3 = typeColor, Font = Enum.Font.GothamBold,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 3,
    })
    local content = Create("TextLabel", {
        Parent = row, Position = UDim2.new(0, 42, 0, 23), Size = UDim2.new(1, -70, 0, 15),
        BackgroundTransparency = 1, Text = opts.Content or "", TextColor3 = colors.SubText, Font = Enum.Font.GothamMedium,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
    })
    local closeBtn = Create("TextButton", {
        Parent = row, Position = UDim2.new(1, -28, 0.5, 0), Size = UDim2Offset(18, 18),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = colors.Surface3, BorderSizePixel = 0, Text = "×",
        TextColor3 = colors.SubText, Font = Enum.Font.GothamBold, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, AutoButtonColor = false, ZIndex = 3,
    })
    newCorner(closeBtn, 999)
    hoverButton(closeBtn, colors.Surface3, colors.SurfaceHover, self.Window)

    element.Hide = function()
        self.Window:PlaySound("Close")
        tween(row, 0.18, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 })
        spawn(function() wait(0.2) row.Visible = false end)
    end
    element.Show = function()
        row.Visible = true
        row.BackgroundTransparency = 0
        tween(row, 0.18, { Size = UDim2.new(1, 0, 0, 46) })
    end
    function element:SetVisible(v) if v then element.Show() else element.Hide() end end
    closeBtn.MouseButton1Click:Connect(function() element.Hide() end)

    element.Recolor = function(c)
        local tc = c.Warning
        if t == "Error" then tc = c.Danger elseif t == "Success" then tc = c.Success elseif t == "Info" then tc = c.Info end
        element.Accent.BackgroundColor3 = tc
        icon.BackgroundColor3 = tc
        title.TextColor3 = tc
        content.TextColor3 = c.SubText
        closeBtn.BackgroundColor3 = c.Surface3
    end

    self.Window:RegisterElement(element)
    return element
end

-- ============================ 导出 ============================
local Obsidian = {}
Obsidian.__index = Obsidian
Obsidian.Themes = Themes
Obsidian.CreateWindow = function(a, b)
    local config
    if a == Obsidian then config = b else config = a end
    return Window.new(config or {})
end

return Obsidian
