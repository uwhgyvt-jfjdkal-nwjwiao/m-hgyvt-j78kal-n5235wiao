if not game:IsLoaded() then game.Loaded:Wait() end
    
    local Players      = game:GetService("Players")
    local RunService   = game:GetService("RunService")
    local UIS          = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local Lighting     = game:GetService("Lighting")
    local HttpService  = game:GetService("HttpService")
    local Stats        = game:GetService("Stats")
    local Player    = Players.LocalPlayer
    local Camera    = workspace.CurrentCamera
    local PlayerGui = (gethui and gethui()) or Player:WaitForChild("PlayerGui")
    local Config = {
        FastSpeed           = 54,
        FastSpeedKey        = Enum.KeyCode.T,
        CarrySpeed          = 29,
        BatDist             = 0,
        AutoBatKey          = Enum.KeyCode.V,
        AutoBatSpeed        = 58,
        GrabSpeed           = 0.05,
        GrabRange           = 30,
        ESPEnabled          = false,
        InfJumpEnabled      = false,
        AntiRagdollEnabled  = false,
        RagdollAutoTP       = false,
        FastSpeedState      = false,
        AutoBatState        = false,
        GrabState           = false,
        FpsBoostState       = false,
        NoAnimState         = false,
        FloatHeight         = 18,
        FloatSpeed          = 85,
        FloatState          = false,
        FloatKey            = Enum.KeyCode.F,
        Float2Height        = 10,
        Float2Speed         = 45,
        Float2State         = false,
        Float2Key           = Enum.KeyCode.J,
        NoclipPlayersState  = false,
        AutoTPRState        = false,
        AutoTPLState        = false,
        AutoTPKey           = Enum.KeyCode.G,
        StopOnLeft          = true,
        StopOnRight         = true,
        AutoPlayState       = false,
        AutoPlayKey         = Enum.KeyCode.H,
        AutoKey             = Enum.KeyCode.N,
        AutoPlaySide        = "L",
        Step2Delay          = 0.05,
    }
    local KEYBIND_DEFAULTS = {
        FastSpeedKey = Enum.KeyCode.T,
        AutoBatKey   = Enum.KeyCode.V,
        FloatKey     = Enum.KeyCode.F,
        Float2Key    = Enum.KeyCode.J,
        AutoTPKey    = Enum.KeyCode.G,
        AutoPlayKey  = Enum.KeyCode.H,
        AutoKey      = Enum.KeyCode.N,
    }
    local ConfigFile = "adv1se_final_config.json"
    local StepOffsets = { L = { [1]={}, [2]={} }, R = { [1]={}, [2]={} } }
    local function initOffsets()
        for _, s in ipairs({"L","R"}) do
            for i = 1,5 do StepOffsets[s][1][i] = {x=0,z=0} end
            for i = 1,3 do StepOffsets[s][2][i] = {x=0,z=0} end
        end
    end
    initOffsets()
    local function SaveConfig()
        if not writefile then return end
        local data = {}
        for k, v in pairs(Config) do
            data[k] = typeof(v) == "EnumItem" and tostring(v) or v
        end
        -- serialise StepOffsets as a flat table so JSON can handle it
        local offData = {}
        for _, side in ipairs({"L","R"}) do
            offData[side] = {}
            for _, grp in ipairs({1,2}) do
                offData[side][tostring(grp)] = {}
                for i, off in ipairs(StepOffsets[side][grp]) do
                    offData[side][tostring(grp)][tostring(i)] = {x=off.x, z=off.z}
                end
            end
        end
        data._stepOffsets = offData
        writefile(ConfigFile, HttpService:JSONEncode(data))
    end
    local function LoadConfig()
        if not isfile or not isfile(ConfigFile) then return end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(ConfigFile)) end)
        if not ok or not data then return end
        for k, v in pairs(data) do
            if k == "_stepOffsets" then
                -- restore per-step offsets
                for _, side in ipairs({"L","R"}) do
                    if v[side] then
                        for _, grp in ipairs({1,2}) do
                            local grpData = v[side][tostring(grp)]
                            if grpData then
                                for i = 1, (grp==1 and 5 or 3) do
                                    local entry = grpData[tostring(i)]
                                    if entry then
                                        StepOffsets[side][grp][i] = {
                                            x = tonumber(entry.x) or 0,
                                            z = tonumber(entry.z) or 0,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            elseif KEYBIND_DEFAULTS[k] then
                local name = tostring(v):gsub("Enum.KeyCode.", "")
                Config[k] = Enum.KeyCode[name] or KEYBIND_DEFAULTS[k]
            else
                Config[k] = v
            end
        end
        Config.BatDist = 0; Config.Step2Delay = 0.05
        Config.FloatHeight = 18; Config.FloatSpeed = 85
        Config.Float2Speed = 45; Config.AutoBatSpeed = 58
    end
    LoadConfig()
    for k, default in pairs(KEYBIND_DEFAULTS) do
        if typeof(Config[k]) ~= "EnumItem" then Config[k] = default end
    end

    local sharedSide = Config.AutoPlaySide == "R" and "R" or "L"
    local FastSpeedEnabled        = false
    local AutoBatEnabled          = false
    local GrabActive              = false
    local FloatEnabled            = false
    local FloatTargetY            = nil
    local FloatActiveSpeed        = nil
    local FloatDescending         = false
    local FloatDescendingStarted  = false
    local BrainrotSequenceRunning = false
    local Float2Enabled           = false
    local Float2TargetY           = nil
    local AutoBat_Float2WasActive = false
    local Interacting             = false
    local NoclipPlayersEnabled    = false
    local AutoTPREnabled          = false
    local AutoTPLEnabled          = false
    local AutoPlayEnabled         = false
    local AutoPlayRunning         = false
    local AutoPlayRestarting      = false
    local AutoPlayStartStep       = 1
    local NoAnimEnabled           = false
    local ESPTracers              = {}
    local InternalCache           = {}
    local AntiRagdollConnection   = nil
    local FastSpeedSetState    = nil
    local autoPlaySetState     = nil
    local dropBrainrotSetState = nil
    local float2SetState       = nil
    local _sideRowRefs = {}
    local TitlePills   = { setL = nil, setR = nil }
    local PromptCache  = {}
    local IsRebinding  = false
    local TP_SIDES = {
        R = { Step1 = Vector3.new(-474.95,-7.29,25.85) },
        L = { Step1 = Vector3.new(-474.92,-7.29,95.13) },
    }
    local AutoTPRunning    = false
    local AutoLREnabled    = false
    local AutoLRRunning    = false
    local AutoLRRestarting = false
    local AutoLRStartStep  = 1
    local autoLRSetState   = nil

    -- ── BASE STEP TABLES ────────────────────────────────────────────────────────
    local AutoLRStepsL = {
        Vector3.new(-475.80,-7.20,94.04),
        Vector3.new(-482.86,-5.09,95.34),
        Vector3.new(-476.36,-6.69,93.02),
    }
    local AutoLRStepsR = {
        Vector3.new(-476.19,-6.99,26.26),
        Vector3.new(-483.09,-5.09,26.45),
        Vector3.new(-476.18,-6.76,29.46),
    }
    local AutoPlayStepsL = {
        Vector3.new(-476.50,-6.90,94.54),
        Vector3.new(-482.86,-5.09,95.34),
        Vector3.new(-476.56,-6.69,93.02),
        Vector3.new(-476.44,-6.75,27.55),
        Vector3.new(-485.52,-5.05,27.29),
    }
    local AutoPlayStepsR = {
        Vector3.new(-476.69,-6.99,27.06),
        Vector3.new(-483.09,-5.09,26.45),
        Vector3.new(-476.28,-6.76,28.76),
        Vector3.new(-476.68,-6.59,94.13),
        Vector3.new(-484.26,-5.35,94.00),
    }

    -- ── PER-STEP OFFSETS ────────────────────────────────────────────────────────
    -- StepOffsets[side][group][stepIndex] = {x=0, z=0}
    -- group 1 = AutoPlay (5 steps), group 2 = AutoLR (3 steps)
    local function getOffsetSteps(base, side, group)
        local out = {}
        for i, v in ipairs(base) do
            local off = StepOffsets[side][group][i] or {x=0,z=0}
            table.insert(out, Vector3.new(v.X+off.x, v.Y, v.Z+off.z))
        end
        return out
    end

    -- marker state
    local _offsetMarkers  = {}
    local _markersVisible = false
    -- forward-declared so switchSide wrapper can call it after GUI init
    local showOffsetMarkers, clearOffsetMarkers

    -- ── ZONES / GROUND ──────────────────────────────────────────────────────────
    local ZoneDefs = {
        Left  = { pos = Vector3.new(-496.2,-5.1,100.1), size = Vector3.new(32,6,18) },
        Right = { pos = Vector3.new(-496.7,-5.3, 21.6), size = Vector3.new(32,6,18) },
    }
    local function isInZone(pos, zone)
        local d = pos - zone.pos
        return math.abs(d.X) < zone.size.X/2 and math.abs(d.Z) < zone.size.Z/2
    end
    local _groundCache = {y=0,lastX=0,lastZ=0,lastTick=0}
    local function getGroundHeight(rootPos)
        local now = tick()
        if now-_groundCache.lastTick < 0.1
        and math.abs(rootPos.X-_groundCache.lastX) < 2
        and math.abs(rootPos.Z-_groundCache.lastZ) < 2 then
            return _groundCache.y
        end
        local origin = rootPos + Vector3.new(0,-0.5,0)
        local params = RaycastParams.new()
        local excluded = {}
        if Player.Character then table.insert(excluded, Player.Character) end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= Player and p.Character then table.insert(excluded, p.Character) end
        end
        params.FilterDescendantsInstances = excluded
        params.FilterType = Enum.RaycastFilterType.Exclude
        local remaining = 500
        local cur = origin
        while remaining > 0 do
            local res = workspace:Raycast(cur, Vector3.new(0,-remaining,0), params)
            if not res then break end
            if res.Instance and res.Instance.CanCollide then
                _groundCache.y = res.Position.Y
                _groundCache.lastX = rootPos.X; _groundCache.lastZ = rootPos.Z; _groundCache.lastTick = now
                return res.Position.Y
            end
            local nxt = res.Position + Vector3.new(0,-0.05,0)
            remaining = remaining - (cur.Y - nxt.Y); cur = nxt
        end
        return rootPos.Y - 500
    end

    -- ── THEME ───────────────────────────────────────────────────────────────────
    local T = {
        bg0=Color3.fromRGB(5,8,14),    bg1=Color3.fromRGB(10,16,26),
        bg2=Color3.fromRGB(16,26,40),  bg3=Color3.fromRGB(24,40,60),
        text=Color3.fromRGB(220,235,250), textMid=Color3.fromRGB(140,180,220),
        textLo=Color3.fromRGB(55,90,130), ice=Color3.fromRGB(160,210,240),
        green=Color3.fromRGB(120,200,180), dotOn=Color3.fromRGB(160,210,240),
        dotOff=Color3.fromRGB(30,55,85), trackBg=Color3.fromRGB(20,36,54),
    }
    local function corner(p,r)
        local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 6); return c
    end
    local function lbl(parent,text,size,col,font,xalign)
        local l=Instance.new("TextLabel",parent)
        l.BackgroundTransparency=1; l.Text=text; l.TextColor3=col or T.text
        l.Font=font or Enum.Font.GothamBold; l.TextSize=size or 12
        l.TextScaled=false; l.RichText=false
        l.TextXAlignment=xalign or Enum.TextXAlignment.Left
        return l
    end
    local function tw(obj,t,props)
        TweenService:Create(obj,TweenInfo.new(t,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),props):Play()
    end

    -- ── SWITCH SIDE ─────────────────────────────────────────────────────────────
    local function switchSide(side)
        sharedSide = side; Config.AutoPlaySide = side
        if side=="R" then
            AutoTPREnabled=true; AutoTPLEnabled=false
            Config.AutoTPRState=true; Config.AutoTPLState=false
        else
            AutoTPLEnabled=true; AutoTPREnabled=false
            Config.AutoTPLState=true; Config.AutoTPRState=false
        end
        if side=="L" then Config.StopOnLeft=true;  Config.StopOnRight=false
        else               Config.StopOnRight=true; Config.StopOnLeft=false end
        for _,ref in ipairs(_sideRowRefs) do if ref.setSide then ref.setSide(side) end end
        if TitlePills.setL and TitlePills.setR then
            if side=="L" then TitlePills.setL(true); TitlePills.setR(false)
            else               TitlePills.setR(true); TitlePills.setL(false) end
        end
        if AutoPlayEnabled then AutoPlayRunning=false end
        if AutoLREnabled   then AutoLRRunning=false end
        if _markersVisible and showOffsetMarkers then showOffsetMarkers() end
        SaveConfig()
    end

    -- ── SCREEN GUI ──────────────────────────────────────────────────────────────
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name="adv1se_GUI"; ScreenGui.Parent=PlayerGui; ScreenGui.ResetOnSpawn=false
    local W,H = 300,600
    local MainFrame = Instance.new("Frame",ScreenGui)
    MainFrame.Name="MainFrame"; MainFrame.BackgroundColor3=T.bg0
    MainFrame.BackgroundTransparency=0; MainFrame.Position=UDim2.new(0.5,-W/2,0.04,0)
    MainFrame.Size=UDim2.new(0,W,0,H); MainFrame.BorderSizePixel=0
    MainFrame.Active=true; MainFrame.Draggable=false; corner(MainFrame,10)

    local TitleBar=Instance.new("Frame",MainFrame)
    TitleBar.Size=UDim2.new(1,0,0,52); TitleBar.BackgroundColor3=T.bg1
    TitleBar.BackgroundTransparency=0; TitleBar.BorderSizePixel=0; TitleBar.ZIndex=2; corner(TitleBar,10)
    local TitleMask=Instance.new("Frame",TitleBar)
    TitleMask.Size=UDim2.new(1,0,0.5,0); TitleMask.Position=UDim2.new(0,0,0.5,0)
    TitleMask.BackgroundColor3=T.bg1; TitleMask.BackgroundTransparency=0
    TitleMask.BorderSizePixel=0; TitleMask.Active=false
    do
        local dragging,dragStart,startPos=false,nil,nil
        TitleBar.InputBegan:Connect(function(i,sunk)
            if sunk then return end
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                dragging=true; dragStart=i.Position; startPos=MainFrame.Position end
        end)
        TitleBar.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
        end)
        UIS.InputChanged:Connect(function(i)
            if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
                local d=i.Position-dragStart
                MainFrame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
            end
        end)
    end
    local TitleDot=Instance.new("Frame",TitleBar)
    TitleDot.Size=UDim2.new(0,5,0,5); TitleDot.Position=UDim2.new(0,14,0.5,-2)
    TitleDot.BackgroundColor3=T.ice; TitleDot.BorderSizePixel=0; corner(TitleDot,10)
    local TitleSmall=lbl(TitleBar,"",10,T.textLo,Enum.Font.GothamBlack)
    TitleSmall.Size=UDim2.new(0,60,0,14); TitleSmall.Position=UDim2.new(0,22,0.5,-7); TitleSmall.ZIndex=3
    local NameTag=lbl(TitleBar,"TRIDENT",20,T.text,Enum.Font.GothamBlack)
    NameTag.Size=UDim2.new(1,0,1,0); NameTag.Position=UDim2.new(0,0,0,0)
    NameTag.TextXAlignment=Enum.TextXAlignment.Center; NameTag.ZIndex=3

    local TITLE_H=52; local TAB_H=30; local TAB_TOP=TITLE_H+6
    local PAGE_TOP=TAB_TOP+TAB_H+6; local BOT_H=52
    local TabBar=Instance.new("Frame",MainFrame)
    TabBar.Size=UDim2.new(1,-16,0,TAB_H); TabBar.Position=UDim2.new(0,8,0,TAB_TOP)
    TabBar.BackgroundColor3=T.bg2; TabBar.BackgroundTransparency=0; TabBar.BorderSizePixel=0; corner(TabBar,7)
    local TabLayout=Instance.new("UIListLayout",TabBar)
    TabLayout.FillDirection=Enum.FillDirection.Horizontal; TabLayout.Padding=UDim.new(0,0)
    TabLayout.SortOrder=Enum.SortOrder.LayoutOrder; TabLayout.HorizontalAlignment=Enum.HorizontalAlignment.Left
    local ActiveTab="FEATURES"; local TabPages={}; local TabBtns={}
    local function makeTab(name,order)
        local btn=Instance.new("TextButton",TabBar)
        btn.Size=UDim2.new(0.5,0,1,0); btn.BackgroundColor3=T.bg2
        btn.BackgroundTransparency=0; btn.BorderSizePixel=0
        btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.TextScaled=false
        btn.Text=name; btn.TextColor3=T.textLo; btn.LayoutOrder=order; corner(btn,7)
        local page=Instance.new("ScrollingFrame",MainFrame)
        page.BackgroundTransparency=1; page.Position=UDim2.new(0,8,0,PAGE_TOP)
        page.Size=UDim2.new(1,-16,0,H-PAGE_TOP-BOT_H); page.CanvasSize=UDim2.new(0,0,0,0)
        page.AutomaticCanvasSize=Enum.AutomaticSize.Y; page.ScrollBarThickness=2
        page.ScrollBarImageColor3=Color3.fromRGB(30,55,85); page.BorderSizePixel=0
        page.ScrollingDirection=Enum.ScrollingDirection.Y; page.ClipsDescendants=true
        page.Visible=(name==ActiveTab)
        local layout=Instance.new("UIListLayout",page)
        layout.Padding=UDim.new(0,2); layout.SortOrder=Enum.SortOrder.LayoutOrder
        TabPages[name]=page; TabBtns[name]=btn
        btn.MouseButton1Click:Connect(function()
            ActiveTab=name
            for n,p in pairs(TabPages) do
                p.Visible=(n==name)
                TabBtns[n].TextColor3=n==name and T.text or T.textLo
                TabBtns[n].BackgroundColor3=n==name and T.bg3 or T.bg2
            end
        end)
        if name==ActiveTab then btn.TextColor3=T.text; btn.BackgroundColor3=T.bg3 end
        return page
    end
    local FeatPage=makeTab("FEATURES",1); local SetPage=makeTab("SETTINGS",2)

    -- ── BOTTOM HUD ──────────────────────────────────────────────────────────────
    local BottomHUD=Instance.new("Frame",MainFrame)
    BottomHUD.Size=UDim2.new(1,-16,0,42); BottomHUD.Position=UDim2.new(0,8,1,-48)
    BottomHUD.BackgroundColor3=T.bg1; BottomHUD.BackgroundTransparency=0
    BottomHUD.BorderSizePixel=0; corner(BottomHUD,8)
    local FPSPingLbl=lbl(BottomHUD,"FPS: 00  |  PING: 00ms",9,T.textLo,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    FPSPingLbl.Size=UDim2.new(1,0,0,16); FPSPingLbl.Position=UDim2.new(0,0,0,4)
    local HUDSep=Instance.new("Frame",BottomHUD)
    HUDSep.Size=UDim2.new(1,-16,0,1); HUDSep.Position=UDim2.new(0,8,0,22)
    HUDSep.BackgroundColor3=T.bg3; HUDSep.BorderSizePixel=0
    local ChooseSideLbl=lbl(BottomHUD,"Choose Side",9,T.textLo,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
    ChooseSideLbl.Size=UDim2.new(0,70,0,14); ChooseSideLbl.Position=UDim2.new(1,-172,0,25)
    local SaveBtn=Instance.new("TextButton",BottomHUD)
    SaveBtn.Size=UDim2.new(0,54,0,14); SaveBtn.Position=UDim2.new(0,8,0,25)
    SaveBtn.BackgroundColor3=T.bg3; SaveBtn.BorderSizePixel=0; SaveBtn.Text="Save"
    SaveBtn.TextColor3=T.textMid; SaveBtn.Font=Enum.Font.GothamBold
    SaveBtn.TextSize=10; SaveBtn.TextScaled=false; corner(SaveBtn,4)
    SaveBtn.MouseButton1Click:Connect(function()
        SaveConfig(); SaveBtn.Text="✓"; SaveBtn.TextColor3=T.green
        task.wait(1.2); SaveBtn.Text="Save"; SaveBtn.TextColor3=T.textMid
    end)
    local function makeBottomSidePill(label,xOff,active)
        local btn=Instance.new("TextButton",BottomHUD)
        btn.Size=UDim2.new(0,36,0,14); btn.Position=UDim2.new(1,xOff,0,25)
        btn.Font=Enum.Font.GothamBlack; btn.TextSize=11; btn.TextScaled=false
        btn.Text=label; btn.BorderSizePixel=0; corner(btn,4)
        local function setActive(v)
            btn.BackgroundColor3=v and T.bg3 or T.bg2; btn.TextColor3=v and T.text or T.textLo
        end
        setActive(active)
        btn.MouseButton1Click:Connect(function() switchSide(label) end)
        return setActive
    end
    local bottomSetL=makeBottomSidePill("L",-90,sharedSide=="L")
    local bottomSetR=makeBottomSidePill("R",-50,sharedSide=="R")
    TitlePills.setL=bottomSetL; TitlePills.setR=bottomSetR
    task.spawn(function()
        while task.wait(0.6) do
            FPSPingLbl.Text=string.format("FPS: %d  |  PING: %dms",
                math.floor(Stats.Workspace.Heartbeat:GetValue()),
                math.floor(Player:GetNetworkPing()*1000))
        end
    end)

    -- ── STEAL BAR ───────────────────────────────────────────────────────────────
    local StealBarOuter=Instance.new("Frame",ScreenGui)
    StealBarOuter.Size=UDim2.new(0,320,0,76); StealBarOuter.Position=UDim2.new(0.5,-160,1,-168)
    StealBarOuter.BackgroundColor3=Color3.fromRGB(8,12,20); StealBarOuter.BackgroundTransparency=0
    StealBarOuter.BorderSizePixel=0; StealBarOuter.ZIndex=20; StealBarOuter.Visible=true; corner(StealBarOuter,14)
    local PillTrack=Instance.new("Frame",StealBarOuter)
    PillTrack.Size=UDim2.new(1,-20,0,10); PillTrack.Position=UDim2.new(0,10,0,10)
    PillTrack.BackgroundColor3=Color3.fromRGB(20,36,54); PillTrack.BorderSizePixel=0; PillTrack.ZIndex=21; corner(PillTrack,99)
    local PillFill=Instance.new("Frame",PillTrack)
    PillFill.Size=UDim2.new(0,0,1,0); PillFill.BackgroundColor3=T.ice; PillFill.BorderSizePixel=0; PillFill.ZIndex=22; corner(PillFill,99)
    local BarPctLbl=lbl(StealBarOuter,"0",12,T.textMid,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    BarPctLbl.Size=UDim2.new(1,0,0,16); BarPctLbl.Position=UDim2.new(0,0,0,22); BarPctLbl.ZIndex=22
    local BarSep=Instance.new("Frame",StealBarOuter)
    BarSep.Size=UDim2.new(1,-20,0,1); BarSep.Position=UDim2.new(0,10,0,44)
    BarSep.BackgroundColor3=Color3.fromRGB(24,40,60); BarSep.BorderSizePixel=0; BarSep.ZIndex=21
    local function makeBarInput(labelText,xPos,configKey)
        local l=lbl(StealBarOuter,labelText,11,T.textMid,Enum.Font.GothamBold)
        l.Size=UDim2.new(0,34,0,18); l.Position=UDim2.new(0,xPos,0,48); l.ZIndex=22
        local box=Instance.new("TextBox",StealBarOuter)
        box.Size=UDim2.new(0,46,0,18); box.Position=UDim2.new(0,xPos+36,0,48)
        box.BackgroundColor3=Color3.fromRGB(14,22,36); box.BorderSizePixel=0
        box.TextColor3=T.text; box.Text=tostring(Config[configKey])
        box.Font=Enum.Font.GothamBold; box.TextSize=11; box.TextScaled=false
        box.TextXAlignment=Enum.TextXAlignment.Center; box.ZIndex=22; corner(box,4)
        box.FocusLost:Connect(function()
            local n=tonumber(box.Text)
            if n then Config[configKey]=n; SaveConfig() end
            box.Text=tostring(Config[configKey])
        end)
    end
    makeBarInput("Spd",10,"GrabSpeed"); makeBarInput("Range",170,"GrabRange")

    -- ── AUTO TP ─────────────────────────────────────────────────────────────────
    local function doAutoTP(side)
        if AutoTPRunning then return end
        local data=TP_SIDES[side]; AutoTPRunning=true
        task.spawn(function()
            local root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame=CFrame.new(data.Step1) end
            AutoTPRunning=false
        end)
    end

    -- ── BRAINROT / FLOAT ────────────────────────────────────────────────────────
    local function handleBrainrotToggle(s,setStateFn)
        BrainrotSequenceRunning=false; FloatEnabled=false; FloatTargetY=nil
        FloatActiveSpeed=nil; FloatDescending=false; FloatDescendingStarted=false; Config.FloatState=false
        if not s then return end
        local f2Was=Float2Enabled
        Float2Enabled=false; Float2TargetY=nil; Config.Float2State=false
        if float2SetState then float2SetState(false) end
        if AutoPlayEnabled then
            AutoPlayEnabled=false; AutoPlayRunning=false; Config.AutoPlayState=false
            if autoPlaySetState then autoPlaySetState(false) end
        end
        BrainrotSequenceRunning=true
        task.spawn(function()
            local function getRoot() return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") end
            local function aborted() return not BrainrotSequenceRunning end
            local r=getRoot()
            if not r then BrainrotSequenceRunning=false; if setStateFn then setStateFn(false) end; return end
            local groundY=getGroundHeight(r.Position); local targetY=groundY+Config.FloatHeight
            local isAirborne=(r.Position.Y-groundY)>6
            if not isAirborne and r.Position.Y<targetY-0.5 then
                local prevY,stuck=r.Position.Y,0
                while not aborted() do
                    r=getRoot(); if not r then break end
                    if r.Position.Y>=targetY-0.5 then break end
                    if math.abs(r.Position.Y-prevY)<0.02 then stuck=stuck+1; if stuck>=4 then break end else stuck=0 end
                    prevY=r.Position.Y
                    local diff=targetY-r.Position.Y; local spd=Config.FloatSpeed
                    r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,math.clamp(diff*spd*0.5,1,spd),r.AssemblyLinearVelocity.Z)
                    task.wait(0.03)
                end
                if aborted() then return end
                r=getRoot(); if r then r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,0,r.AssemblyLinearVelocity.Z) end
                task.wait(0.05)
            end
            if isAirborne then
                r=getRoot()
                if r then
                    local gY=getGroundHeight(r.Position)
                    r.CFrame=CFrame.new(Vector3.new(r.Position.X, gY+3, r.Position.Z))
                    r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,0,r.AssemblyLinearVelocity.Z)
                end
            else
                local ds=tick()
                while not aborted() do
                    r=getRoot(); if not r then break end
                    local gY=getGroundHeight(r.Position)
                    if r.Position.Y-gY<=3 then break end
                    if tick()-ds>2 then break end
                    r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,-120,r.AssemblyLinearVelocity.Z)
                    task.wait(0.03)
                end
            end
            if aborted() then return end
            BrainrotSequenceRunning=false; FloatEnabled=false; Config.FloatState=false; FloatTargetY=nil; FloatActiveSpeed=nil
            r=getRoot(); if r then r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,0,r.AssemblyLinearVelocity.Z) end
            if setStateFn then setStateFn(false) end
            if f2Was then
                r=getRoot(); Float2Enabled=true; Config.Float2State=true
                Float2TargetY=r and (r.Position.Y+Config.Float2Height) or nil
                if float2SetState then float2SetState(true) end
            end
        end)
    end
    local function handleFloat2Toggle(s,_)
        Float2Enabled=s; Config.Float2State=s; if not s then Float2TargetY=nil end
    end

    -- ── RAGDOLL ─────────────────────────────────────────────────────────────────
    local ragdollTPCooldown=false; local ragdollTPSetState=nil
    local pendingRagdollTP=false; local lastRagdollTick=0; local ragdollOccurred=false
    local RAGDOLL_STEP2={R=Vector3.new(-482.89,-5.09,26.45),L=Vector3.new(-482.86,-5.09,95.34)}
    local function tryPendingRagdollTP()
        if pendingRagdollTP and (tick()-lastRagdollTick<3) then
            pendingRagdollTP=false
            task.spawn(function()
                local tpSide=sharedSide or "L"; local tpData=TP_SIDES[tpSide]
                local root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if not root then return end
                root.CFrame=CFrame.new(tpData.Step1); task.wait(0.2)
                root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if not root then return end
                root.CFrame=CFrame.new(RAGDOLL_STEP2[tpSide]); task.wait(0.15); AutoPlayStartStep=2
            end)
            return true
        end
        pendingRagdollTP=false; return false
    end
    local function startAntiRagdoll()
        if AntiRagdollConnection then return end
        AntiRagdollConnection=RunService.Heartbeat:Connect(function()
            local char=Player.Character; if not char then return end
            local root=char:FindFirstChild("HumanoidRootPart")
            local hum=char:FindFirstChildOfClass("Humanoid")
            if hum then
                local s=hum:GetState()
                if s==Enum.HumanoidStateType.Physics or s==Enum.HumanoidStateType.Ragdoll or s==Enum.HumanoidStateType.FallingDown then
                    lastRagdollTick=tick(); ragdollOccurred=true
                    AutoPlayEnabled=false; AutoPlayRunning=false; Config.AutoPlayState=false
                    if autoPlaySetState then autoPlaySetState(false) end
                    AutoLREnabled=false; AutoLRRunning=false
                    if autoLRSetState then autoLRSetState(false) end
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                    workspace.CurrentCamera.CameraSubject=hum
                    pcall(function()
                        local pm=Player.PlayerScripts:FindFirstChild("PlayerModule")
                        if pm then require(pm:FindFirstChild("ControlModule")):Enable() end
                    end)
                    if root then root.Velocity=Vector3.new(0,0,0); root.RotVelocity=Vector3.new(0,0,0) end
                    if Config.RagdollAutoTP and not ragdollTPCooldown then
                        pendingRagdollTP=false; ragdollTPCooldown=true
                        local side=sharedSide or (Config.AutoTPRState and "R") or "L"
                        task.spawn(function()
                            task.wait(0.08)
                            local data=TP_SIDES[side]
                            local r=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                            if r then r.CFrame=CFrame.new(data.Step1) end; task.wait(0.2)
                            r=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                            local rs2=side=="R" and Vector3.new(-482.89,-5.09,26.45) or Vector3.new(-482.86,-5.09,95.34)
                            if r then r.CFrame=CFrame.new(rs2+Vector3.new(0,3,0)) end; task.wait(0.2)
                            AutoPlayStartStep=3; AutoPlayEnabled=true; AutoPlayRunning=false
                            if autoPlaySetState then autoPlaySetState(true) end
                            task.wait(2.5); ragdollTPCooldown=false
                        end)
                    end
                end
            end
            for _,obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled=true end
            end
        end)
    end
    local function stopAntiRagdoll()
        if AntiRagdollConnection then AntiRagdollConnection:Disconnect(); AntiRagdollConnection=nil end
    end

    -- ── ESP ─────────────────────────────────────────────────────────────────────
    local function applyESPToChar(plr,char)
        if not char then return end
        local root=char:WaitForChild("HumanoidRootPart",10)
        if not root or root:FindFirstChild("ESP_NameTag") then return end
        local bill=Instance.new("BillboardGui")
        bill.Name="ESP_NameTag"; bill.AlwaysOnTop=true
        bill.Size=UDim2.new(0,100,0,20); bill.StudsOffset=Vector3.new(0,3,0); bill.Enabled=Config.ESPEnabled; bill.Parent=root
        local l=Instance.new("TextLabel",bill)
        l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1; l.Text=plr.DisplayName
        l.TextColor3=Color3.fromRGB(255,255,255); l.TextStrokeTransparency=0
        l.TextStrokeColor3=Color3.fromRGB(0,0,0); l.Font=Enum.Font.GothamBold; l.TextSize=13; l.TextScaled=false
    end
    local function setupESP(plr)
        if plr==Player then return end
        local line=Drawing.new("Line"); line.Thickness=2; line.Color=Color3.fromRGB(255,255,255)
        line.Transparency=0; line.Visible=false; ESPTracers[plr]=line
        if plr.Character then task.spawn(applyESPToChar,plr,plr.Character) end
        plr.CharacterAdded:Connect(function(char) task.wait(1); applyESPToChar(plr,char) end)
    end
    Players.PlayerAdded:Connect(setupESP)
    Players.PlayerRemoving:Connect(function(p) if ESPTracers[p] then ESPTracers[p]:Remove(); ESPTracers[p]=nil end end)
    for _,p in pairs(Players:GetPlayers()) do setupESP(p) end
    local _espFrame=0
    RunService.RenderStepped:Connect(function()
        if not Config.ESPEnabled then return end
        _espFrame=_espFrame+1; if _espFrame%3~=0 then return end
        for plr,line in pairs(ESPTracers) do
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local pos,onScreen=Camera:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)
                line.Visible=onScreen
                if onScreen then
                    line.From=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
                    line.To=Vector2.new(pos.X,pos.Y)
                end
            else line.Visible=false end
        end
    end)

    -- ── NOCLIP ──────────────────────────────────────────────────────────────────
    RunService.Stepped:Connect(function()
        if not NoclipPlayersEnabled then return end
        local char=Player.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for _,p in pairs(Players:GetPlayers()) do
            if p~=Player and p.Character then
                local pr=p.Character:FindFirstChild("HumanoidRootPart")
                if pr and (root.Position-pr.Position).Magnitude<=8 then
                    for _,part in pairs(p.Character:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide=false end
                    end
                end
            end
        end
    end)

    -- ── PROMPT CACHE / STEAL ────────────────────────────────────────────────────
    local function buildCallbacks(prompt)
        if InternalCache[prompt] then return end
        local data={holdCallbacks={},triggerCallbacks={}}
        local ok1,c1=pcall(getconnections,prompt.PromptButtonHoldBegan)
        if ok1 and type(c1)=="table" then
            for _,c in ipairs(c1) do if type(c.Function)=="function" then table.insert(data.holdCallbacks,c.Function) end end
        end
        local ok2,c2=pcall(getconnections,prompt.Triggered)
        if ok2 and type(c2)=="table" then
            for _,c in ipairs(c2) do if type(c.Function)=="function" then table.insert(data.triggerCallbacks,c.Function) end end
        end
        if #data.holdCallbacks>0 or #data.triggerCallbacks>0 then InternalCache[prompt]=data end
    end
    local function executeSteal(prompt,duration)
        local data=InternalCache[prompt]; if not data then return false end
        for _,fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
        task.wait(duration)
        for _,fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
        return true
    end
    local function rebuildPromptCache()
        PromptCache={}
        for _,v in pairs(workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then table.insert(PromptCache,v) end
        end
    end
    workspace.DescendantAdded:Connect(function(v)
        if v:IsA("ProximityPrompt") then table.insert(PromptCache,v) end
    end)
    workspace.DescendantRemoving:Connect(function(v)
        if v:IsA("ProximityPrompt") then
            for i,p in ipairs(PromptCache) do if p==v then table.remove(PromptCache,i); break end end
        end
    end)
    rebuildPromptCache()
    local function lockCooldown(prompt)
        pcall(function()
            prompt.Cooldown=0
            prompt:GetPropertyChangedSignal("Cooldown"):Connect(function() pcall(function() prompt.Cooldown=0 end) end)
        end)
    end
    for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("ProximityPrompt") then lockCooldown(v) end end
    workspace.DescendantAdded:Connect(function(v) if v:IsA("ProximityPrompt") then lockCooldown(v) end end)
    task.spawn(function()
        while true do
            task.wait()
            if not GrabActive or Interacting then continue end
            local char=Player.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            local target,closest=nil,Config.GrabRange
            for _,v in pairs(PromptCache) do
                if v and v.Parent and v.ActionText=="Steal" then
                    local pPos=v.Parent:IsA("Attachment") and v.Parent.WorldPosition
                            or v.Parent:IsA("BasePart") and v.Parent.Position
                            or v.Parent:GetPivot().Position
                    local d=(root.Position-pPos).Magnitude
                    if d<closest then closest=d; target=v end
                end
            end
            if target then
                if not target.Parent then task.wait(0.05)
                else
                    Interacting=true
                    local ok=pcall(function()
                        buildCallbacks(target)
                        local rawDur=(target.HoldDuration and target.HoldDuration>0) and target.HoldDuration or 1
                        local dur=rawDur*Config.GrabSpeed
                        PillFill.Size=UDim2.new(0,0,1,0); BarPctLbl.Text="0"
                        TweenService:Create(PillFill,TweenInfo.new(dur,Enum.EasingStyle.Linear),{Size=UDim2.new(1,0,1,0)}):Play()
                        task.spawn(function()
                            local elapsed=0
                            while elapsed<dur and Interacting do
                                elapsed=elapsed+task.wait(0.05)
                                BarPctLbl.Text=tostring(math.clamp(math.floor((elapsed/dur)*100),1,100))
                            end
                        end)
                        if InternalCache[target] then executeSteal(target,dur) else fireproximityprompt(target) end
                    end)
                    task.wait(0.05); PillFill.Size=UDim2.new(0,0,1,0); BarPctLbl.Text="0"
                    Interacting=false; AutoPlayRunning=false; AutoLRRunning=false
                    if not ok then task.wait(0.1) end
                end
            end
        end
    end)

    -- ── SPEED BILLBOARD ─────────────────────────────────────────────────────────
    local SpeedLabel=nil
    local function setupSpeedBillboard(char)
        local root=char:WaitForChild("HumanoidRootPart",10); if not root then return end
        local old=root:FindFirstChild("MySpeedBill"); if old then old:Destroy() end
        local bill=Instance.new("BillboardGui")
        bill.Name="MySpeedBill"; bill.AlwaysOnTop=true
        bill.Size=UDim2.new(0,160,0,28); bill.StudsOffset=Vector3.new(0,3.8,0); bill.Parent=root
        local l=Instance.new("TextLabel",bill)
        l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
        l.TextColor3=Color3.fromRGB(120,190,230); l.TextStrokeTransparency=0
        l.TextStrokeColor3=Color3.fromRGB(0,0,0); l.Font=Enum.Font.GothamBold
        l.TextSize=30; l.TextScaled=false; l.TextXAlignment=Enum.TextXAlignment.Center; l.Text="Speed: 0.00"
        SpeedLabel=l
    end
    if Player.Character then task.spawn(setupSpeedBillboard,Player.Character) end
    Player.CharacterAdded:Connect(function(char) task.wait(0.5); setupSpeedBillboard(char) end)

    -- ── WALK HELPERS ────────────────────────────────────────────────────────────
    local function stopAutoPlay()
        AutoPlayEnabled=false; AutoPlayRunning=false; Config.AutoPlayState=false
        if not AutoPlayRestarting and autoPlaySetState then autoPlaySetState(false) end
    end
    local function stopAutoLR()
        AutoLREnabled=false; AutoLRRunning=false
        if not AutoLRRestarting and autoLRSetState then autoLRSetState(false) end
    end
    local function walkToPositionAP(root,targetPos,speed,arriveDistance)
        speed=speed or Config.CarrySpeed
        if type(arriveDistance)~="number" then arriveDistance=1 end
        while AutoPlayEnabled do
            local flat=Vector3.new(targetPos.X-root.Position.X,0,targetPos.Z-root.Position.Z)
            if flat.Magnitude<=arriveDistance then break end
            root.AssemblyLinearVelocity=Vector3.new(flat.Unit.X*speed,root.AssemblyLinearVelocity.Y,flat.Unit.Z*speed)
            RunService.Heartbeat:Wait()
        end
        root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0)
    end
    local function walkToPositionLR(root,targetPos,speed,arriveDistance)
        speed=speed or Config.CarrySpeed
        if type(arriveDistance)~="number" then arriveDistance=1 end
        while AutoLREnabled do
            local flat=Vector3.new(targetPos.X-root.Position.X,0,targetPos.Z-root.Position.Z)
            if flat.Magnitude<=arriveDistance then break end
            root.AssemblyLinearVelocity=Vector3.new(flat.Unit.X*speed,root.AssemblyLinearVelocity.Y,flat.Unit.Z*speed)
            RunService.Heartbeat:Wait()
        end
        if AutoLREnabled then root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0) end
    end

    -- ── AUTO LR LOOP ────────────────────────────────────────────────────────────
    task.spawn(function()
        while true do
            task.wait(0.05)
            if not AutoLREnabled or AutoLRRunning then continue end
            AutoLRRunning=true
            local char=Player.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
            if not root then stopAutoLR(); continue end
            local steps=getOffsetSteps(sharedSide=="R" and AutoLRStepsR or AutoLRStepsL,sharedSide,2)
            local startStep=AutoLRStartStep; AutoLRStartStep=1
            if startStep==1 then
                walkToPositionLR(root,steps[1],Config.FastSpeed)
                if not AutoLREnabled then AutoLRRunning=false; continue end
                if FastSpeedEnabled then FastSpeedEnabled=false; Config.FastSpeedState=false; if FastSpeedSetState then FastSpeedSetState(false) end end
                walkToPositionLR(root,steps[2],Config.FastSpeed,0.5)
                task.wait(Config.Step2Delay)
                if not AutoLREnabled then AutoLRRunning=false; continue end
            else
                root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0); task.wait(0.1)
                if not AutoLREnabled then AutoLRRunning=false; continue end
            end
            root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then walkToPositionLR(root,steps[3],Config.CarrySpeed,1) end
            root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0) end
            AutoLREnabled=false; AutoLRRunning=false; if autoLRSetState then autoLRSetState(false) end
        end
    end)

    -- ── AUTO PLAY LOOP ──────────────────────────────────────────────────────────
    task.spawn(function()
        while true do
            task.wait(0.05)
            if not AutoPlayEnabled or AutoPlayRunning then continue end
            AutoPlayRunning=true
            local char=Player.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
            if not root then stopAutoPlay(); continue end
            local steps=getOffsetSteps(Config.AutoPlaySide=="R" and AutoPlayStepsR or AutoPlayStepsL,Config.AutoPlaySide,1)
            local zone=Config.StopOnLeft and ZoneDefs.Left or Config.StopOnRight and ZoneDefs.Right
            local startStep=AutoPlayStartStep; AutoPlayStartStep=1
            if startStep==1 then
                if not (zone and isInZone(root.Position,zone)) then
                    walkToPositionAP(root,steps[1],Config.FastSpeed)
                    if not AutoPlayEnabled then AutoPlayRunning=false; continue end
                end
                if FastSpeedEnabled then FastSpeedEnabled=false; Config.FastSpeedState=false; if FastSpeedSetState then FastSpeedSetState(false) end end
                walkToPositionAP(root,steps[2],Config.FastSpeed,0.5)
                task.wait(Config.Step2Delay)
                if not AutoPlayEnabled then AutoPlayRunning=false; continue end
            else
                root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0); task.wait(0.1)
                if not AutoPlayEnabled then AutoPlayRunning=false; continue end
            end
            root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then walkToPositionAP(root,steps[3],Config.CarrySpeed,false) end
            if not AutoPlayEnabled then AutoPlayRunning=false; continue end
            root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then walkToPositionAP(root,steps[4],Config.CarrySpeed,false) end
            if not AutoPlayEnabled then AutoPlayRunning=false; continue end
            root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then walkToPositionAP(root,steps[5],Config.CarrySpeed,true) end
            stopAutoPlay()
        end
    end)

    -- ── PLAYER CACHE / HEARTBEAT ────────────────────────────────────────────────
    local _playerCache={}; local _playerCacheTick=0
    local function getCachedPlayers()
        local now=tick()
        if now-_playerCacheTick>1 then _playerCache=Players:GetPlayers(); _playerCacheTick=now end
        return _playerCache
    end
    Players.PlayerAdded:Connect(function() _playerCacheTick=0 end)
    Players.PlayerRemoving:Connect(function() _playerCacheTick=0 end)
    local lastClick=0
    RunService.Heartbeat:Connect(function()
        local char=Player.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        if not AutoPlayEnabled and not AutoLREnabled and not AutoBatEnabled and hum.MoveDirection.Magnitude>0 then
            local spd=FastSpeedEnabled and Config.FastSpeed or Config.CarrySpeed
            root.AssemblyLinearVelocity=Vector3.new(hum.MoveDirection.X*spd,root.AssemblyLinearVelocity.Y,hum.MoveDirection.Z*spd)
        end
        if Player:GetAttribute("Stealing")==true and hum.MoveDirection.Magnitude>0 then
            root.AssemblyLinearVelocity=Vector3.new(hum.MoveDirection.X*Config.CarrySpeed,root.AssemblyLinearVelocity.Y,hum.MoveDirection.Z*Config.CarrySpeed)
        end
        if AutoBatEnabled then
            local target,dMin=nil,1000
            for _,p in pairs(getCachedPlayers()) do
                if p~=Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local d=(root.Position-p.Character.HumanoidRootPart.Position).Magnitude
                    if d<dMin then target=p; dMin=d end
                end
            end
            if target and target.Character then
                for _,part in pairs(target.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide=false end end
            end
            if target then
                local tRoot=target.Character.HumanoidRootPart
                local dest=tRoot.Position+tRoot.CFrame.LookVector*Config.BatDist
                local diff=dest-root.Position
                root.AssemblyAngularVelocity=root.CFrame.LookVector:Cross(tRoot.CFrame.LookVector)*20
                local batVel=diff.Magnitude>1 and diff.Unit*Config.AutoBatSpeed or tRoot.AssemblyLinearVelocity
                local yVel=batVel.Y
                if Float2Enabled then
                    local sY=getGroundHeight(root.Position); local ft=sY+Config.Float2Height
                    yVel=math.clamp((ft-root.Position.Y)*Config.Float2Speed,-Config.Float2Speed,Config.Float2Speed)
                end
                root.AssemblyLinearVelocity=Vector3.new(batVel.X,yVel,batVel.Z)
                local tool=char:FindFirstChildOfClass("Tool")
                if tool and tool.Name:lower()=="bat" and tick()-lastClick>0.1 then pcall(mouse1click); lastClick=tick() end
            end
        end
        local spaceHeld=Config.InfJumpEnabled and UIS:IsKeyDown(Enum.KeyCode.Space)
        if Float2Enabled and not spaceHeld then
            local sY=getGroundHeight(root.Position); Float2TargetY=sY+Config.Float2Height
            local fspeed=Config.Float2Speed; local diff=Float2TargetY-root.Position.Y
            root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,math.clamp(diff*fspeed,-fspeed,fspeed),root.AssemblyLinearVelocity.Z)
        elseif FloatEnabled and FloatTargetY and not spaceHeld and not BrainrotSequenceRunning then
            local fspeed=FloatActiveSpeed or Config.FloatSpeed; local diff=FloatTargetY-root.Position.Y
            root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,math.clamp(diff*fspeed,-fspeed,fspeed),root.AssemblyLinearVelocity.Z)
        elseif FloatDescending and not FloatEnabled and not BrainrotSequenceRunning then
            if FloatDescendingStarted and root.AssemblyLinearVelocity.Y>=-2 then
                FloatDescending=false; FloatDescendingStarted=false
            else
                root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,-Config.FloatSpeed,root.AssemblyLinearVelocity.Z)
                FloatDescendingStarted=true
            end
        end
        if AutoPlayEnabled or AutoLREnabled then
            local targetLook=Vector3.new(-0.9999873042106628,0,0.005038774572312832).Unit
            local currentLook=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
            if currentLook.Magnitude>0.01 then
                local cross=currentLook.Unit:Cross(targetLook)
                root.AssemblyAngularVelocity=Vector3.new(0,cross.Y*15,0)
            end
        end
        if SpeedLabel then
            local v=root.AssemblyLinearVelocity
            SpeedLabel.Text=string.format("Speed: %.2f",Vector3.new(v.X,0,v.Z).Magnitude)
        end
    end)

    -- ── NO ANIM ─────────────────────────────────────────────────────────────────
    local noAnimConn=nil; local noAnimHbConn=nil
    local function freezePose(char)
        for _,m in ipairs(char:GetDescendants()) do
            if m:IsA("Motor6D") then m.CurrentAngle=0; m.DesiredAngle=0; m.MaxVelocity=0; m.Transform=CFrame.new() end
        end
    end
    local function applyNoAnim(char)
        if not char then return end
        local animScript=char:WaitForChild("Animate",15)
        if not NoAnimEnabled then return end
        if animScript then animScript.Disabled=true end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if hum then for _,t in ipairs(hum:GetPlayingAnimationTracks()) do pcall(t.Stop,t,0) end end
        if noAnimHbConn then noAnimHbConn:Disconnect(); noAnimHbConn=nil end
        noAnimHbConn=RunService.Heartbeat:Connect(function()
            if not NoAnimEnabled then if noAnimHbConn then noAnimHbConn:Disconnect(); noAnimHbConn=nil end; return end
            if Player.Character then freezePose(Player.Character) end
        end)
    end

    -- ── FPS BOOST ───────────────────────────────────────────────────────────────
    local FPSBoostLocalConn=nil; local FPSBoostCharConn=nil
    local function applyFPSBoostCharacter(char)
        if not char then return end
        pcall(function()
            for _,v in ipairs(char:GetDescendants()) do
                if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then v:Destroy() end
            end
        end)
        char.DescendantAdded:Connect(function(v)
            if not Config.FpsBoostState then return end
            if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then pcall(function() v:Destroy() end) end
        end)
    end
    local function applyFPSBoostWorld()
        for _,v in pairs(workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") then v.CastShadow=false; v.Material=Enum.Material.Plastic
                elseif v:IsA("Decal") then v.Transparency=1
                elseif v:IsA("ParticleEmitter") then v.Enabled=false end
            end)
        end
        Lighting.GlobalShadows=false
    end

    -- ══════════════════════════════════════════════════════════════════════════
    --  GUI WIDGET BUILDERS
    -- ══════════════════════════════════════════════════════════════════════════
    local ROW_H=36
    local function FeatSectionHeader(text,order)
        local row=Instance.new("Frame",FeatPage)
        row.Size=UDim2.new(1,0,0,22); row.BackgroundTransparency=1; row.BorderSizePixel=0; row.LayoutOrder=order
        local l=lbl(row,text,9,T.textLo,Enum.Font.GothamBold); l.Size=UDim2.new(1,-8,1,0); l.Position=UDim2.new(0,4,0,0)
    end
    local function FeatToggle(text,order,onToggle)
        local state=false
        local Frame=Instance.new("Frame",FeatPage)
        Frame.Size=UDim2.new(1,0,0,ROW_H); Frame.BackgroundColor3=T.bg1
        Frame.BackgroundTransparency=0; Frame.BorderSizePixel=0; Frame.LayoutOrder=order; corner(Frame,6)
        local TextLbl=lbl(Frame,text,12,T.textMid,Enum.Font.GothamBold)
        TextLbl.Size=UDim2.new(1,-70,1,0); TextLbl.Position=UDim2.new(0,14,0,0); TextLbl.TextScaled=false
        local Track=Instance.new("Frame",Frame)
        Track.Size=UDim2.new(0,44,0,24); Track.Position=UDim2.new(1,-54,0.5,-12)
        Track.BackgroundColor3=T.trackBg; Track.BorderSizePixel=0; corner(Track,12)
        local Dot=Instance.new("Frame",Track)
        Dot.Size=UDim2.new(0,18,0,18); Dot.Position=UDim2.new(0,3,0.5,-9)
        Dot.BackgroundColor3=T.dotOff; Dot.BorderSizePixel=0; corner(Dot,10)
        local Btn=Instance.new("TextButton",Frame)
        Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.BorderSizePixel=0; Btn.Text=""; Btn.TextScaled=false
        local function refresh()
            if state then tw(Dot,0.3,{BackgroundColor3=T.dotOn, Position=UDim2.new(0,23,0.5,-9)})
            else           tw(Dot,0.3,{BackgroundColor3=T.dotOff,Position=UDim2.new(0,3, 0.5,-9)}) end
        end
        refresh()
        Btn.MouseButton1Click:Connect(function() state=not state; refresh(); onToggle(state) end)
        return Btn,function(s) state=s; refresh() end
    end
    local function FeatToggleWithSide(baseText,order,initialSide,onToggle,onSideSwap)
        local state=false; local side=initialSide or "L"
        local Frame=Instance.new("Frame",FeatPage)
        Frame.Size=UDim2.new(1,0,0,ROW_H); Frame.BackgroundColor3=T.bg1
        Frame.BackgroundTransparency=0; Frame.BorderSizePixel=0; Frame.LayoutOrder=order; corner(Frame,6)
        local TextLbl=lbl(Frame,baseText.." "..side,12,T.textMid,Enum.Font.GothamBold)
        TextLbl.Size=UDim2.new(1,-70,1,0); TextLbl.Position=UDim2.new(0,14,0,0); TextLbl.TextScaled=false
        local Track=Instance.new("Frame",Frame)
        Track.Size=UDim2.new(0,44,0,24); Track.Position=UDim2.new(1,-54,0.5,-12)
        Track.BackgroundColor3=T.trackBg; Track.BorderSizePixel=0; corner(Track,12)
        local Dot=Instance.new("Frame",Track)
        Dot.Size=UDim2.new(0,18,0,18); Dot.Position=UDim2.new(0,3,0.5,-9)
        Dot.BackgroundColor3=T.dotOff; Dot.BorderSizePixel=0; corner(Dot,10)
        local Btn=Instance.new("TextButton",Frame)
        Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.BorderSizePixel=0; Btn.Text=""; Btn.TextScaled=false
        local function refresh()
            TextLbl.Text=baseText.." "..side
            if state then tw(Dot,0.3,{BackgroundColor3=T.dotOn, Position=UDim2.new(0,23,0.5,-9)})
            else           tw(Dot,0.3,{BackgroundColor3=T.dotOff,Position=UDim2.new(0,3, 0.5,-9)}) end
        end
        refresh()
        Btn.MouseButton1Click:Connect(function() state=not state; refresh(); onToggle(state,side) end)
        Btn.MouseButton2Click:Connect(function() side=side=="L" and "R" or "L"; refresh(); if onSideSwap then onSideSwap(side) end end)
        return Btn,function(s) state=s; refresh() end,function(s) side=s; refresh() end
    end
    local function SetSectionHeader(text,order)
        local row=Instance.new("Frame",SetPage)
        row.Size=UDim2.new(1,0,0,22); row.BackgroundTransparency=1; row.BorderSizePixel=0; row.LayoutOrder=order
        local l=lbl(row,text,9,T.textLo,Enum.Font.GothamBold); l.Size=UDim2.new(1,-8,1,0); l.Position=UDim2.new(0,4,0,0)
    end
    local function SetInputRow(text,configKey,order)
        local Frame=Instance.new("Frame",SetPage)
        Frame.Size=UDim2.new(1,0,0,34); Frame.BackgroundColor3=T.bg1
        Frame.BackgroundTransparency=0; Frame.BorderSizePixel=0; Frame.LayoutOrder=order; corner(Frame,6)
        local l=lbl(Frame,text,12,T.textMid,Enum.Font.GothamBold); l.Size=UDim2.new(0.58,-8,1,0); l.Position=UDim2.new(0,14,0,0)
        local Input=Instance.new("TextBox",Frame)
        Input.Size=UDim2.new(0.36,0,0,22); Input.Position=UDim2.new(0.62,0,0.5,-11)
        Input.BackgroundColor3=T.bg3; Input.BackgroundTransparency=0; Input.BorderSizePixel=0
        Input.Text=tostring(Config[configKey]); Input.TextColor3=T.text
        Input.Font=Enum.Font.GothamBold; Input.TextSize=11; Input.TextScaled=false
        Input.TextXAlignment=Enum.TextXAlignment.Center; corner(Input,5)
        Input.Focused:Connect(function() tw(Input,0.12,{BackgroundColor3=T.bg2}) end)
        Input.FocusLost:Connect(function()
            tw(Input,0.12,{BackgroundColor3=T.bg3})
            local n=tonumber(Input.Text)
            if n and n>0 then Config[configKey]=n; SaveConfig() end
            Input.Text=tostring(Config[configKey])
        end)
    end
    local function SetKeybindRow(text,configKey,order)
        local Frame=Instance.new("Frame",SetPage)
        Frame.Size=UDim2.new(1,0,0,34); Frame.BackgroundColor3=T.bg1
        Frame.BackgroundTransparency=0; Frame.BorderSizePixel=0; Frame.LayoutOrder=order; corner(Frame,6)
        local l=lbl(Frame,text,12,T.textMid,Enum.Font.GothamBold); l.Size=UDim2.new(0.58,-8,1,0); l.Position=UDim2.new(0,14,0,0)
        local BindBtn=Instance.new("TextButton",Frame)
        BindBtn.Size=UDim2.new(0.36,0,0,22); BindBtn.Position=UDim2.new(0.62,0,0.5,-11)
        BindBtn.BackgroundColor3=T.bg3; BindBtn.BackgroundTransparency=0; BindBtn.BorderSizePixel=0
        BindBtn.Text=Config[configKey].Name; BindBtn.TextColor3=T.ice
        BindBtn.Font=Enum.Font.GothamBold; BindBtn.TextSize=10; BindBtn.TextScaled=false
        BindBtn.TextXAlignment=Enum.TextXAlignment.Center; corner(BindBtn,5)
        BindBtn.MouseButton1Click:Connect(function()
            BindBtn.Text="..."; BindBtn.TextColor3=T.textLo; local conn; IsRebinding=true
            conn=UIS.InputBegan:Connect(function(i,p)
                if not p and i.UserInputType==Enum.UserInputType.Keyboard then
                    Config[configKey]=i.KeyCode; BindBtn.Text=i.KeyCode.Name; BindBtn.TextColor3=T.ice
                    IsRebinding=false; SaveConfig(); conn:Disconnect()
                end
            end)
        end)
    end
    local function FeatKeybindRow(text,configKey,order)
        local Frame=Instance.new("Frame",FeatPage)
        Frame.Size=UDim2.new(1,0,0,ROW_H); Frame.BackgroundColor3=T.bg1
        Frame.BackgroundTransparency=0; Frame.BorderSizePixel=0; Frame.LayoutOrder=order; corner(Frame,6)
        local l=lbl(Frame,text,12,T.textMid,Enum.Font.GothamBold); l.Size=UDim2.new(0.58,-8,1,0); l.Position=UDim2.new(0,14,0,0)
        local BindBtn=Instance.new("TextButton",Frame)
        BindBtn.Size=UDim2.new(0.36,0,0,22); BindBtn.Position=UDim2.new(0.62,0,0.5,-11)
        BindBtn.BackgroundColor3=T.bg3; BindBtn.BackgroundTransparency=0; BindBtn.BorderSizePixel=0
        BindBtn.Text=Config[configKey].Name; BindBtn.TextColor3=T.ice
        BindBtn.Font=Enum.Font.GothamBold; BindBtn.TextSize=10; BindBtn.TextScaled=false
        BindBtn.TextXAlignment=Enum.TextXAlignment.Center; corner(BindBtn,5)
        BindBtn.MouseButton1Click:Connect(function()
            BindBtn.Text="..."; BindBtn.TextColor3=T.textLo; local conn; IsRebinding=true
            conn=UIS.InputBegan:Connect(function(i,p)
                if not p and i.UserInputType==Enum.UserInputType.Keyboard then
                    Config[configKey]=i.KeyCode; BindBtn.Text=i.KeyCode.Name; BindBtn.TextColor3=T.ice
                    IsRebinding=false; SaveConfig(); conn:Disconnect()
                end
            end)
        end)
    end
    local function FeatInputRow(text,configKey,order)
        local Frame=Instance.new("Frame",FeatPage)
        Frame.Size=UDim2.new(1,0,0,ROW_H); Frame.BackgroundColor3=T.bg1
        Frame.BackgroundTransparency=0; Frame.BorderSizePixel=0; Frame.LayoutOrder=order; corner(Frame,6)
        local l=lbl(Frame,text,12,T.textMid,Enum.Font.GothamBold); l.Size=UDim2.new(0.58,-8,1,0); l.Position=UDim2.new(0,14,0,0)
        local Input=Instance.new("TextBox",Frame)
        Input.Size=UDim2.new(0.36,0,0,22); Input.Position=UDim2.new(0.62,0,0.5,-11)
        Input.BackgroundColor3=T.bg3; Input.BackgroundTransparency=0; Input.BorderSizePixel=0
        Input.Text=tostring(Config[configKey]); Input.TextColor3=T.text
        Input.Font=Enum.Font.GothamBold; Input.TextSize=11; Input.TextScaled=false
        Input.TextXAlignment=Enum.TextXAlignment.Center; corner(Input,5)
        Input.Focused:Connect(function() tw(Input,0.12,{BackgroundColor3=T.bg2}) end)
        Input.FocusLost:Connect(function()
            tw(Input,0.12,{BackgroundColor3=T.bg3})
            local n=tonumber(Input.Text)
            if n and n>0 then Config[configKey]=n; SaveConfig() end
            Input.Text=tostring(Config[configKey])
        end)
    end

    -- ══════════════════════════════════════════════════════════════════════════
    --  FEATURES PAGE
    -- ══════════════════════════════════════════════════════════════════════════
    FeatSectionHeader("SPEED",1)
    do
        local Frame=Instance.new("Frame",FeatPage)
        Frame.Size=UDim2.new(1,0,0,ROW_H); Frame.BackgroundColor3=T.bg1
        Frame.BackgroundTransparency=0; Frame.BorderSizePixel=0; Frame.LayoutOrder=2; corner(Frame,6)
        local statusLbl=lbl(Frame,"Status",12,T.textMid,Enum.Font.GothamBold)
        statusLbl.Size=UDim2.new(0.5,-8,1,0); statusLbl.Position=UDim2.new(0,14,0,0)
        local valueLbl=lbl(Frame,"CARRY",12,T.textLo,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
        valueLbl.Size=UDim2.new(0.45,-14,1,0); valueLbl.Position=UDim2.new(0.55,0,0,0)
        FastSpeedSetState=function(s)
            FastSpeedEnabled=s; Config.FastSpeedState=s
            if s then valueLbl.Text="FAST"; valueLbl.TextColor3=T.text
            else       valueLbl.Text="CARRY"; valueLbl.TextColor3=T.textLo end
        end
        FastSpeedSetState(FastSpeedEnabled)
    end
    FeatKeybindRow("Speed Key","FastSpeedKey",3)
    FeatInputRow("Carry Speed","CarrySpeed",4)
    FeatSectionHeader("MOVEMENT",5)
    local _,autoBatSetState=FeatToggle("Auto Bat",6,function(s)
        AutoBatEnabled=s; Config.AutoBatState=s
        if s then
            if Float2Enabled then AutoBat_Float2WasActive=true; handleFloat2Toggle(false,nil); if float2SetState then float2SetState(false) end
            else AutoBat_Float2WasActive=false end
            if FloatEnabled then
                AutoBat_Float2WasActive=true; BrainrotSequenceRunning=false
                FloatEnabled=false; FloatTargetY=nil; FloatActiveSpeed=nil
                FloatDescending=false; FloatDescendingStarted=false; Config.FloatState=false
                if dropBrainrotSetState then dropBrainrotSetState(false) end
            end
        else
            if AutoBat_Float2WasActive then AutoBat_Float2WasActive=false; handleFloat2Toggle(true,nil); if float2SetState then float2SetState(true) end end
        end
    end)
    local _,_alrSetState,_alrSetSide=FeatToggleWithSide("Auto",7,sharedSide,
        function(s,side)
            AutoLREnabled=s
            if not s then AutoLRRunning=false
            else
                if ragdollOccurred and not ragdollTPCooldown and (tick()-lastRagdollTick<3) then
                    ragdollOccurred=false; ragdollTPCooldown=true
                    local side2=sharedSide or "L"; local data=TP_SIDES[side2]
                    task.spawn(function()
                        AutoLREnabled=false; AutoLRRunning=false; if autoLRSetState then autoLRSetState(false) end; task.wait(0.08)
                        local r=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if r then r.CFrame=CFrame.new(data.Step1) end; task.wait(0.2)
                        r=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        local rs2=side2=="R" and Vector3.new(-483.09,-5.09,26.45) or Vector3.new(-482.86,-5.09,95.34)
                        if r then r.CFrame=CFrame.new(rs2+Vector3.new(0,3,0)) end; task.wait(0.15)
                        AutoLRStartStep=3; AutoLREnabled=true; AutoLRRunning=false
                        if autoLRSetState then autoLRSetState(true) end; task.wait(2.5); ragdollTPCooldown=false
                    end)
                end
            end
        end,
        function(side) switchSide(side) end)
    table.insert(_sideRowRefs,{setSide=_alrSetSide}); autoLRSetState=_alrSetState
    local _,_apSetState,_apSetSide=FeatToggleWithSide("Auto Play",8,sharedSide,
        function(s,side)
            AutoPlayEnabled=s; Config.AutoPlayState=s; Config.AutoPlaySide=side
            if not s then AutoPlayRunning=false
            else
                tryPendingRagdollTP()
                if ragdollOccurred and not ragdollTPCooldown and (tick()-lastRagdollTick<3) then
                    ragdollOccurred=false; ragdollTPCooldown=true
                    local side2=sharedSide or "L"; local data=TP_SIDES[side2]
                    task.spawn(function()
                        AutoPlayEnabled=false; AutoPlayRunning=false; if autoPlaySetState then autoPlaySetState(false) end; task.wait(0.08)
                        local r=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if r then r.CFrame=CFrame.new(data.Step1) end; task.wait(0.2)
                        r=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        local rs2=side2=="R" and Vector3.new(-482.89,-5.09,26.45) or Vector3.new(-482.86,-5.09,95.34)
                        if r then r.CFrame=CFrame.new(rs2+Vector3.new(0,3,0)) end; task.wait(0.15)
                        AutoPlayStartStep=3; AutoPlayEnabled=true; AutoPlayRunning=false
                        if autoPlaySetState then autoPlaySetState(true) end; task.wait(2.5); ragdollTPCooldown=false
                    end)
                end
            end
        end,
        function(side) switchSide(side) end)
    table.insert(_sideRowRefs,{setSide=_apSetSide,setState=_apSetState}); autoPlaySetState=_apSetState
    local _;_,ragdollTPSetState=FeatToggle("TP on Ragdoll",9,function(s) Config.RagdollAutoTP=s end)
    local _,_float2Set=FeatToggle("Float",10,function(s) handleFloat2Toggle(s,nil) end)
    float2SetState=_float2Set
    local _,_dropSet=FeatToggle("Drop Brainrot",11,function(s) handleBrainrotToggle(s,_dropSet) end)
    dropBrainrotSetState=_dropSet
    FeatSectionHeader("DYNAMICS",12)
    local _,noAnimSetState=FeatToggle("No Animation",13,function(s)
        NoAnimEnabled=s; Config.NoAnimState=s; SaveConfig()
        if noAnimConn then noAnimConn:Disconnect(); noAnimConn=nil end
        if noAnimHbConn then noAnimHbConn:Disconnect(); noAnimHbConn=nil end
        if s then
            task.spawn(applyNoAnim,Player.Character)
            noAnimConn=Player.CharacterAdded:Connect(function(c) task.spawn(applyNoAnim,c) end)
        else
            local char=Player.Character; local a=char and char:FindFirstChild("Animate"); if a then a.Disabled=false end
        end
    end)
    local _,fpsSetState=FeatToggle("FPS Boost",15,function(s)
        Config.FpsBoostState=s
        if s then
            applyFPSBoostWorld()
            for _,p in pairs(Players:GetPlayers()) do applyFPSBoostCharacter(p.Character) end
            if FPSBoostLocalConn then FPSBoostLocalConn:Disconnect() end
            FPSBoostLocalConn=Player.CharacterAdded:Connect(function(c) if Config.FpsBoostState then task.wait(0.3); applyFPSBoostCharacter(c) end end)
            if FPSBoostCharConn then FPSBoostCharConn:Disconnect() end
            FPSBoostCharConn=Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function(c) if Config.FpsBoostState then task.wait(0.3); applyFPSBoostCharacter(c) end end) end)
            SaveConfig()
        else
            if FPSBoostLocalConn then FPSBoostLocalConn:Disconnect(); FPSBoostLocalConn=nil end
            if FPSBoostCharConn  then FPSBoostCharConn:Disconnect();  FPSBoostCharConn=nil end
            SaveConfig()
        end
    end)
    local _,espSetState=FeatToggle("ESP",16,function(s)
        Config.ESPEnabled=s
        for plr in pairs(ESPTracers) do
            if plr.Character then
                local r=plr.Character:FindFirstChild("HumanoidRootPart")
                if r then local tag=r:FindFirstChild("ESP_NameTag"); if tag then tag.Enabled=s end end
            end
        end
        if not s then for _,line in pairs(ESPTracers) do line.Visible=false end end
    end)
    local _,ragdollSetState=FeatToggle("No Ragdoll",17,function(s) Config.AntiRagdollEnabled=s; if s then startAntiRagdoll() else stopAntiRagdoll() end end)
    local _,grabSetState=FeatToggle("Grab",18,function(s)
        GrabActive=s; Config.GrabState=s
        if not s then Interacting=false; PillFill.Size=UDim2.new(0,0,1,0); BarPctLbl.Text="0" end
    end)
    local _,infJumpSetState=FeatToggle("Infinite Jump",19,function(s) Config.InfJumpEnabled=s end)
    local _,noclipSetState=FeatToggle("Noclip Players",20,function(s) NoclipPlayersEnabled=s; Config.NoclipPlayersState=s; SaveConfig() end)

    -- ══════════════════════════════════════════════════════════════════════════
    --  SETTINGS TAB — POSITIONS (per-step offset editor + box markers)
    -- ══════════════════════════════════════════════════════════════════════════
    SetSectionHeader("POSITIONS",1)
    do
        -- marker colours: AP = ice-blue, LR = green
        local MCOL={
            AP={L=Color3.fromRGB(160,210,240),R=Color3.fromRGB(100,170,255)},
            LR={L=Color3.fromRGB(120,200,180),R=Color3.fromRGB(80,220,140)},
        }
        -- box dimensions (studs) — standing character silhouette
        local BW,BD,BH=0.6,0.6,5

        clearOffsetMarkers=function()
            for _,m in ipairs(_offsetMarkers) do if m and m.Parent then m:Destroy() end end
            _offsetMarkers={}
        end

        local function spawnBox(pos,col,labelTxt)
            local p=Instance.new("Part")
            p.Name="OffsetMarker"; p.Size=Vector3.new(BW,BH,BD)
            p.Anchored=true; p.CanCollide=false; p.CastShadow=false
            p.Material=Enum.Material.SmoothPlastic; p.Color=col; p.Transparency=0.3
            -- bottom sits at pos.Y
            p.CFrame=CFrame.new(pos+Vector3.new(0,BH/2,0)); p.Parent=workspace

            local bill=Instance.new("BillboardGui",p)
            bill.AlwaysOnTop=true; bill.Size=UDim2.new(0,56,0,20)
            bill.StudsOffset=Vector3.new(0,BH/2+1.4,0)
            local tag=Instance.new("TextLabel",bill)
            tag.Size=UDim2.new(1,0,1,0); tag.BackgroundTransparency=0
            tag.BackgroundColor3=Color3.fromRGB(5,8,14); tag.TextColor3=col
            tag.Font=Enum.Font.GothamBlack; tag.TextSize=13; tag.TextScaled=false; tag.Text=labelTxt
            corner(tag,4)
            table.insert(_offsetMarkers,p)
        end

        showOffsetMarkers=function()
            clearOffsetMarkers()
            local side=sharedSide
            local apBase=side=="R" and AutoPlayStepsR or AutoPlayStepsL
            local lrBase=side=="R" and AutoLRStepsR  or AutoLRStepsL
            local apSteps=getOffsetSteps(apBase,side,1)
            local lrSteps=getOffsetSteps(lrBase,side,2)
            for i,pos in ipairs(apSteps) do spawnBox(pos,MCOL.AP[side],side..tostring(i)) end
        end

        -- open/close button row
        local BtnFrame=Instance.new("Frame",SetPage)
        BtnFrame.Size=UDim2.new(1,0,0,34); BtnFrame.BackgroundColor3=T.bg1
        BtnFrame.BorderSizePixel=0; BtnFrame.LayoutOrder=2; corner(BtnFrame,6)
        local BtnLbl=lbl(BtnFrame,"Edit Positions",12,T.textMid,Enum.Font.GothamBold)
        BtnLbl.Size=UDim2.new(0.6,-8,1,0); BtnLbl.Position=UDim2.new(0,14,0,0)
        local OpenBtn=Instance.new("TextButton",BtnFrame)
        OpenBtn.Size=UDim2.new(0.36,0,0,22); OpenBtn.Position=UDim2.new(0.62,0,0.5,-11)
        OpenBtn.BackgroundColor3=T.bg3; OpenBtn.BorderSizePixel=0
        OpenBtn.Text="Open"; OpenBtn.TextColor3=T.ice
        OpenBtn.Font=Enum.Font.GothamBold; OpenBtn.TextSize=10; OpenBtn.TextScaled=false
        OpenBtn.TextXAlignment=Enum.TextXAlignment.Center; corner(OpenBtn,5)

        -- scrollable sub-panel
        local SubPanel=Instance.new("ScrollingFrame",SetPage)
        SubPanel.Size=UDim2.new(1,0,0,280); SubPanel.BackgroundColor3=T.bg2
        SubPanel.BorderSizePixel=0; SubPanel.LayoutOrder=3; SubPanel.Visible=false
        SubPanel.ScrollBarThickness=2; SubPanel.ScrollBarImageColor3=Color3.fromRGB(30,55,85)
        SubPanel.CanvasSize=UDim2.new(0,0,0,0); SubPanel.AutomaticCanvasSize=Enum.AutomaticSize.Y
        SubPanel.ScrollingDirection=Enum.ScrollingDirection.Y; SubPanel.ClipsDescendants=true; corner(SubPanel,6)
        local subLayout=Instance.new("UIListLayout",SubPanel)
        subLayout.Padding=UDim.new(0,2); subLayout.SortOrder=Enum.SortOrder.LayoutOrder
        local subPad=Instance.new("UIPadding",SubPanel)
        subPad.PaddingLeft=UDim.new(0,6); subPad.PaddingRight=UDim.new(0,6)
        subPad.PaddingTop=UDim.new(0,4); subPad.PaddingBottom=UDim.new(0,4)

        local subOrder=0
        local function subHdr(txt)
            subOrder=subOrder+1
            local f=Instance.new("Frame",SubPanel)
            f.Size=UDim2.new(1,0,0,18); f.BackgroundTransparency=1; f.BorderSizePixel=0; f.LayoutOrder=subOrder
            local l2=lbl(f,txt,9,T.textLo,Enum.Font.GothamBold); l2.Size=UDim2.new(1,0,1,0)
        end

        local stepBoxRefs = {}
        local function makeStepRow(stepIdx)
            subOrder=subOrder+1
            local row=Instance.new("Frame",SubPanel)
            row.Size=UDim2.new(1,0,0,28); row.BackgroundColor3=T.bg1
            row.BackgroundTransparency=0; row.BorderSizePixel=0; row.LayoutOrder=subOrder; corner(row,5)
            local lb=lbl(row,tostring(stepIdx),11,T.textMid,Enum.Font.GothamBold)
            lb.Size=UDim2.new(0,28,1,0); lb.Position=UDim2.new(0,4,0,0)
            local lbX=lbl(row,"X",9,T.textLo,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
            lbX.Size=UDim2.new(0,10,1,0); lbX.Position=UDim2.new(0,34,0,0)
            local xBox=Instance.new("TextBox",row)
            xBox.Size=UDim2.new(0,52,0,20); xBox.Position=UDim2.new(0,46,0.5,-10)
            xBox.BackgroundColor3=T.bg3; xBox.BorderSizePixel=0; xBox.Text="0"; xBox.TextColor3=T.text
            xBox.Font=Enum.Font.GothamBold; xBox.TextSize=10; xBox.TextScaled=false
            xBox.TextXAlignment=Enum.TextXAlignment.Center; corner(xBox,4)
            xBox.Focused:Connect(function() tw(xBox,0.1,{BackgroundColor3=T.bg2}) end)
            xBox.FocusLost:Connect(function() tw(xBox,0.1,{BackgroundColor3=T.bg3}) end)
            local lbZ=lbl(row,"Z",9,T.textLo,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
            lbZ.Size=UDim2.new(0,10,1,0); lbZ.Position=UDim2.new(0,102,0,0)
            local zBox=Instance.new("TextBox",row)
            zBox.Size=UDim2.new(0,52,0,20); zBox.Position=UDim2.new(0,114,0.5,-10)
            zBox.BackgroundColor3=T.bg3; zBox.BorderSizePixel=0; zBox.Text="0"; zBox.TextColor3=T.text
            zBox.Font=Enum.Font.GothamBold; zBox.TextSize=10; zBox.TextScaled=false
            zBox.TextXAlignment=Enum.TextXAlignment.Center; corner(zBox,4)
            zBox.Focused:Connect(function() tw(zBox,0.1,{BackgroundColor3=T.bg2}) end)
            zBox.FocusLost:Connect(function() tw(zBox,0.1,{BackgroundColor3=T.bg3}) end)
            xBox.FocusLost:Connect(function()
                local nx=tonumber(xBox.Text); local nz=tonumber(zBox.Text)
                local s=sharedSide
                if nx then StepOffsets[s][1][stepIdx].x=nx end
                if nz then StepOffsets[s][1][stepIdx].z=nz end
                xBox.Text=tostring(StepOffsets[s][1][stepIdx].x)
                zBox.Text=tostring(StepOffsets[s][1][stepIdx].z)
                if _markersVisible then showOffsetMarkers() end
            end)
            zBox.FocusLost:Connect(function()
                local nx=tonumber(xBox.Text); local nz=tonumber(zBox.Text)
                local s=sharedSide
                if nx then StepOffsets[s][1][stepIdx].x=nx end
                if nz then StepOffsets[s][1][stepIdx].z=nz end
                xBox.Text=tostring(StepOffsets[s][1][stepIdx].x)
                zBox.Text=tostring(StepOffsets[s][1][stepIdx].z)
                if _markersVisible then showOffsetMarkers() end
            end)
            local rstBtn=Instance.new("TextButton",row)
            rstBtn.Size=UDim2.new(0,34,0,20); rstBtn.Position=UDim2.new(1,-38,0.5,-10)
            rstBtn.BackgroundColor3=T.bg3; rstBtn.BorderSizePixel=0; rstBtn.Text="Rst"
            rstBtn.TextColor3=T.textMid; rstBtn.Font=Enum.Font.GothamBold
            rstBtn.TextSize=9; rstBtn.TextScaled=false
            rstBtn.TextXAlignment=Enum.TextXAlignment.Center; corner(rstBtn,4)
            rstBtn.MouseButton1Click:Connect(function()
                StepOffsets[sharedSide][1][stepIdx]={x=0,z=0}
                xBox.Text="0"; zBox.Text="0"
                if _markersVisible then showOffsetMarkers() end
            end)
            table.insert(stepBoxRefs,{xBox=xBox,zBox=zBox,stepIdx=stepIdx})
        end
        subHdr("— AUTO PLAY —")
        for i=1,5 do makeStepRow(i) end
        table.insert(_sideRowRefs,{setSide=function()
            for _,ref in ipairs(stepBoxRefs) do
                local off=StepOffsets[sharedSide][1][ref.stepIdx]
                ref.xBox.Text=tostring(off.x)
                ref.zBox.Text=tostring(off.z)
            end
            if _markersVisible then showOffsetMarkers() end
        end})
    end
    -- reset-all row + open button wired in a fresh scope
    do
        local SubPanel=SetPage:FindFirstChildWhichIsA("ScrollingFrame")
        local OpenBtn=SetPage:FindFirstChild("Frame") and SetPage:FindFirstChild("Frame"):FindFirstChildWhichIsA("TextButton")
        -- find the correct frames by layout order
        local sp,ob
        for _,c in ipairs(SetPage:GetChildren()) do
            if c:IsA("ScrollingFrame") then sp=c end
            if c:IsA("Frame") and c.LayoutOrder==2 then
                ob=c:FindFirstChildWhichIsA("TextButton")
            end
        end
        SubPanel=sp; OpenBtn=ob
        -- reset all button
        local rstAllRow=Instance.new("Frame",SubPanel)
        rstAllRow.Size=UDim2.new(1,0,0,26); rstAllRow.BackgroundTransparency=1
        rstAllRow.BorderSizePixel=0; rstAllRow.LayoutOrder=99
        local rstAll=Instance.new("TextButton",rstAllRow)
        rstAll.Size=UDim2.new(1,0,1,0); rstAll.BackgroundColor3=T.bg3
        rstAll.BorderSizePixel=0; rstAll.Text="Reset All Offsets"
        rstAll.TextColor3=T.textMid; rstAll.Font=Enum.Font.GothamBold
        rstAll.TextSize=10; rstAll.TextScaled=false; corner(rstAll,5)
        rstAll.MouseButton1Click:Connect(function()
            initOffsets()
            for _,child in ipairs(SubPanel:GetChildren()) do
                if child:IsA("Frame") then
                    for _,box in ipairs(child:GetChildren()) do
                        if box:IsA("TextBox") then box.Text="0" end
                    end
                end
            end
            if _markersVisible then showOffsetMarkers() end
        end)
        if OpenBtn then
            OpenBtn.MouseButton1Click:Connect(function()
                local posOpen=SubPanel.Visible
                posOpen=not posOpen; _markersVisible=posOpen
                SubPanel.Visible=posOpen
                OpenBtn.Text=posOpen and "Close" or "Open"
                OpenBtn.TextColor3=posOpen and T.green or T.ice
                if posOpen then showOffsetMarkers() else clearOffsetMarkers() end
            end)
        end
    end

    SetSectionHeader("KEYBINDS",4)
    SetKeybindRow("Drop Key","FloatKey",5)
    SetKeybindRow("Float Key","Float2Key",6)
    SetKeybindRow("Auto Bat","AutoBatKey",7)
    SetKeybindRow("Auto TP","AutoTPKey",8)
    SetKeybindRow("Auto Play","AutoPlayKey",9)
    SetKeybindRow("Auto","AutoKey",10)
    SetSectionHeader("VALUES",11)
    SetInputRow("Speed","FastSpeed",12)
    SetInputRow("Float Height","Float2Height",13)

    -- ── INIT STATE ──────────────────────────────────────────────────────────────
    do
        Config.BatDist=0; Config.Step2Delay=0.05; Config.FloatHeight=18
        Config.FloatSpeed=85; Config.Float2Speed=45; Config.AutoBatSpeed=58
        if Config.FastSpeedState then FastSpeedSetState(true) end
        Config.AutoBatState=false; AutoBatEnabled=false
        if Config.GrabState          then GrabActive=true; grabSetState(true) end
        if Config.AntiRagdollEnabled then ragdollSetState(true); startAntiRagdoll() end
        if Config.RagdollAutoTP      then ragdollTPSetState(true) end
        if Config.NoclipPlayersState then NoclipPlayersEnabled=true; noclipSetState(true) end
        if Config.InfJumpEnabled     then infJumpSetState(true) end
        if Config.ESPEnabled then
            espSetState(true)
            for plr in pairs(ESPTracers) do
                if plr.Character then
                    local r=plr.Character:FindFirstChild("HumanoidRootPart")
                    if r then local t2=r:FindFirstChild("ESP_NameTag"); if t2 then t2.Enabled=true end end
                end
            end
        end
        local savedSide=Config.AutoPlaySide or "L"
        switchSide(savedSide)
        AutoTPREnabled=savedSide=="R"; AutoTPLEnabled=savedSide=="L"
        Config.AutoTPRState=AutoTPREnabled; Config.AutoTPLState=AutoTPLEnabled
        if savedSide=="L" then Config.StopOnLeft=true; Config.StopOnRight=false
        else Config.StopOnRight=true; Config.StopOnLeft=false end
        if Config.Float2State then _float2Set(true); handleFloat2Toggle(true,nil) end
        if Config.FpsBoostState then
            fpsSetState(true)
            task.spawn(function()
                task.wait(1); if not Config.FpsBoostState then return end
                applyFPSBoostWorld()
                for _,p in pairs(Players:GetPlayers()) do applyFPSBoostCharacter(p.Character) end
            end)
        end
        if Config.NoAnimState then
            task.spawn(function()
                NoAnimEnabled=true; noAnimSetState(true)
                noAnimConn=Player.CharacterAdded:Connect(function(c) task.spawn(applyNoAnim,c) end)
                applyNoAnim(Player.Character or Player.CharacterAdded:Wait())
            end)
        end
        if _apSetSide  then _apSetSide(Config.AutoPlaySide or "L") end
        if _alrSetSide then _alrSetSide(Config.AutoPlaySide or "L") end
        -- push loaded offsets into the position editor boxes
        for _, ref in ipairs(_sideRowRefs) do
            if ref.setSide then ref.setSide(sharedSide) end
        end
    end

    -- ── INPUT HANDLER ───────────────────────────────────────────────────────────
    UIS.InputBegan:Connect(function(i,p)
        if p then return end; if IsRebinding then return end
        if i.KeyCode==Enum.KeyCode.Space and Config.InfJumpEnabled then
            task.spawn(function()
                while UIS:IsKeyDown(Enum.KeyCode.Space) and Config.InfJumpEnabled do
                    local char=Player.Character
                    local root=char and char:FindFirstChild("HumanoidRootPart")
                    local hum=char and char:FindFirstChildOfClass("Humanoid")
                    if root and hum and hum.Health>0 then
                        root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,math.random(42,48),root.AssemblyLinearVelocity.Z)
                    end
                    task.wait(0.05)
                end
            end)
        end
        if i.KeyCode==Config.FastSpeedKey then
            if FastSpeedSetState then FastSpeedSetState(not FastSpeedEnabled) end
        elseif i.KeyCode==Config.AutoBatKey then
            AutoBatEnabled=not AutoBatEnabled; Config.AutoBatState=AutoBatEnabled
            if AutoBatEnabled then
                if Float2Enabled then AutoBat_Float2WasActive=true; handleFloat2Toggle(false,nil); if float2SetState then float2SetState(false) end
                else AutoBat_Float2WasActive=false end
                if FloatEnabled then
                    AutoBat_Float2WasActive=true; BrainrotSequenceRunning=false
                    FloatEnabled=false; FloatTargetY=nil; FloatActiveSpeed=nil
                    FloatDescending=false; FloatDescendingStarted=false; Config.FloatState=false
                    if dropBrainrotSetState then dropBrainrotSetState(false) end
                end
            else
                if AutoBat_Float2WasActive then AutoBat_Float2WasActive=false; handleFloat2Toggle(true,nil); if float2SetState then float2SetState(true) end end
            end
            autoBatSetState(AutoBatEnabled)
        elseif i.KeyCode==Config.AutoTPKey then
            local side=AutoTPREnabled and "R" or AutoTPLEnabled and "L" or Config.AutoTPRState and "R" or Config.AutoTPLState and "L"
            if side then doAutoTP(side) end
        elseif i.KeyCode==Config.FloatKey then
            local s=not FloatEnabled; if _dropSet then _dropSet(s) end; handleBrainrotToggle(s,_dropSet)
        elseif i.KeyCode==Config.Float2Key then
            local s=not Float2Enabled; handleFloat2Toggle(s,nil); if _float2Set then _float2Set(s) end; SaveConfig()
        elseif i.KeyCode==Config.AutoPlayKey then
            AutoPlayEnabled=not AutoPlayEnabled; Config.AutoPlayState=AutoPlayEnabled
            if not AutoPlayEnabled then AutoPlayRunning=false
            else
                tryPendingRagdollTP()
                if ragdollOccurred and not ragdollTPCooldown and (tick()-lastRagdollTick<3) then
                    ragdollOccurred=false; ragdollTPCooldown=true
                    local side2=sharedSide or "L"; local data=TP_SIDES[side2]
                    task.spawn(function()
                        AutoPlayEnabled=false; AutoPlayRunning=false; if autoPlaySetState then autoPlaySetState(false) end; task.wait(0.08)
                        local r=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if r then r.CFrame=CFrame.new(data.Step1) end; task.wait(0.2)
                        r=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        local rs2=side2=="R" and Vector3.new(-482.89,-5.09,26.45) or Vector3.new(-482.86,-5.09,95.34)
                        if r then r.CFrame=CFrame.new(rs2+Vector3.new(0,3,0)) end; task.wait(0.15)
                        AutoPlayStartStep=3; AutoPlayEnabled=true; AutoPlayRunning=false
                        if autoPlaySetState then autoPlaySetState(true) end; task.wait(2.5); ragdollTPCooldown=false
                    end)
                end
            end
            if autoPlaySetState then autoPlaySetState(AutoPlayEnabled) end
        elseif i.KeyCode==Config.AutoKey then
            AutoLREnabled=not AutoLREnabled; AutoLRRunning=false
            if autoLRSetState then autoLRSetState(AutoLREnabled) end
        end
    end)
