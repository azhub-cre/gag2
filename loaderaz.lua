-- ==========================================
-- HỆ THỐNG ANTI-AFK VẬT LÝ (TỰ ĐỘNG CHẠY MỖI 8 PHÚT)
-- ==========================================
task.spawn(function()
    local player = game:GetService("Players").LocalPlayer
    local VirtualUser = game:GetService("VirtualUser")
    
    -- Lớp bảo vệ 1: Gửi click ảo nếu Roblox báo Idled
    player.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)

    -- Lớp bảo vệ 2: Cứ 8 phút (480 giây) tự động nhảy + đi sang trái rồi về chỗ cũ
    while true do
        task.wait(480) 
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            
            if humanoid and hrp then
                local originCFrame = hrp.CFrame
                humanoid.Jump = true
                task.wait(0.5)
                local leftTarget = originCFrame.Position - (originCFrame.RightVector * 4)
                humanoid:MoveTo(leftTarget)
                humanoid.MoveToFinished:Wait(2)
                task.wait(0.5)
                humanoid:MoveTo(originCFrame.Position)
                humanoid.MoveToFinished:Wait(2)
                hrp.CFrame = originCFrame
            end
        end
    end
end)

-- ==========================================
-- 1. CẤU HÌNH CƠ BẢN VÀ API
-- ==========================================
local API_URL = "https://license.longpt.net/autosendmail/api.php"

local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local HWID = RbxAnalyticsService:GetClientId()
local UserKey = getgenv().script_key or ""
local SessionToken = HttpService:GenerateGUID(false)
local player = game:GetService("Players").LocalPlayer

local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
if not requestFunc then
    warn("Executor không hỗ trợ Http Request!")
    return
end

local function callAPI(key)
    local success, res = pcall(function()
        return requestFunc({
            Url = API_URL .. "?action=check&key=" .. key .. "&hwid=" .. HWID .. "&session=" .. SessionToken,
            Method = "GET"
        })
    end)
    return success, res
end

-- ==========================================
-- 1.5. HỆ THỐNG LƯU TRỮ NHẬT KÝ GIAO DỊCH (FILE SYSTEM)
-- ==========================================
local FOLDER_NAME = "LongPT_MailLogs"
local FILE_NAME = FOLDER_NAME .. "/" .. player.Name .. ".txt"

-- Tạo thư mục nếu chưa có
if isfolder and not isfolder(FOLDER_NAME) then
    pcall(makefolder, FOLDER_NAME)
end

local function writeTransaction(targetAcc, itemName, amount)
    local timeStr = os.date("%H:%M:%S %d/%m/%Y")
    local logString = string.format("%s gửi mail cho %s - %s\n%s x%s\n--------------------------------\n", player.Name, targetAcc, timeStr, itemName, tostring(amount))
    
    if isfile and writefile and readfile then
        pcall(function()
            if appendfile then
                if not isfile(FILE_NAME) then writefile(FILE_NAME, "") end
                appendfile(FILE_NAME, logString)
            else
                -- Fallback nếu Executor không hỗ trợ appendfile
                local currentContent = ""
                if isfile(FILE_NAME) then
                    local s, c = pcall(readfile, FILE_NAME)
                    if s then currentContent = c end
                end
                writefile(FILE_NAME, currentContent .. logString)
            end
        end)
    end
end

local function clearTransactions()
    if delfile and isfile and isfile(FILE_NAME) then
        pcall(delfile, FILE_NAME)
    end
end

-- ==========================================
-- 2. LÕI GAME (BACKEND MAILBOX THÔNG MINH)
-- ==========================================
local RS = game:GetService("ReplicatedStorage")
local Net = require(RS:WaitForChild("SharedModules"):WaitForChild("Networking"))
local PS = require(RS:WaitForChild("ClientModules"):WaitForChild("PlayerStateClient"))
local workspace = game:GetService("Workspace")

local STACK = { Sprinklers=1, WateringCans=1, Mushrooms=1, Gnomes=1, Raccoons=1, Crates=1, SeedPacks=1, Trowels=1, Props=1, Seeds=1, HarvestedFruits=1, Flashbangs=1, EmptyPots=1 }

local function getInv()
    local ok, r = pcall(function() return PS:WaitForLocalReplica(5) end)
    return ok and r and r.Data and type(r.Data.Inventory) == "table" and r.Data.Inventory
end

local function buildBatch(inv, items)
    local out, max = {}, 20
    local totalPacked = 0 
    for name, amt in pairs(items) do
        if #out >= max then break end
        local want = math.max(1, math.floor(tonumber(amt) or 1))
        
        if type(inv.Pets) == "table" then
            for key, p in pairs(inv.Pets) do
                if want <= 0 or #out >= max then break end
                if type(p) == "table" and p.Id and not p.Equipped and tostring(p.Name) == name then
                    out[#out + 1] = { Category = "Pets", ItemKey = key, Count = 1 }
                    want = want - 1
                    totalPacked = totalPacked + 1
                end
            end
        end
        if want > 0 then
            for cat, _ in pairs(STACK) do
                local t = inv[cat]
                if type(t) == "table" and type(t[name]) == "number" and t[name] > 0 then
                    local available = t[name]
                    local leftToPack = math.min(want, available)
                    
                    while leftToPack > 0 and #out < max do
                        local takeAmount = math.min(leftToPack, 5000)
                        out[#out + 1] = { Category = cat, ItemKey = name, Count = takeAmount }
                        totalPacked = totalPacked + takeAmount
                        leftToPack = leftToPack - takeAmount
                        want = want - takeAmount
                    end
                    break
                end
            end
        end
    end
    return out, totalPacked
end

local function buildSendAllBatch(inv)
    local out, max = {}, 20
    local totalPacked = 0 
    
    if type(inv.Pets) == "table" then
        for key, p in pairs(inv.Pets) do
            if #out >= max then break end
            if type(p) == "table" and p.Id and not p.Equipped then
                out[#out + 1] = { Category = "Pets", ItemKey = key, Count = 1 }
                totalPacked = totalPacked + 1
            end
        end
    end
    
    for cat, _ in pairs(STACK) do
        if type(inv[cat]) == "table" then
            for name, amt in pairs(inv[cat]) do
                local leftToPack = amt
                while leftToPack > 0 and #out < max do
                    local takeAmount = math.min(leftToPack, 5000)
                    out[#out + 1] = { Category = cat, ItemKey = name, Count = takeAmount }
                    totalPacked = totalPacked + takeAmount
                    leftToPack = leftToPack - takeAmount
                end
            end
        end
    end
    return out, totalPacked
end

local function getServerMails()
    local success, mailList = pcall(function()
        if Net.Mailbox.List.Invoke then return Net.Mailbox.List:Invoke()
        elseif Net.Mailbox.List.Fire then return Net.Mailbox.List:Fire() end
    end)
    if success and type(mailList) == "table" then return mailList end
    return {}
end

local function clickUI(btn)
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        elseif getconnections then
            for _, eventName in ipairs({"MouseButton1Click", "Activated"}) do
                if btn[eventName] then
                    for _, connection in pairs(getconnections(btn[eventName])) do
                        if type(connection.Function) == "function" then connection:Fire() end
                    end
                end
            end
        end
    end)
end

local function isReallyVisible(guiObj)
    local current = guiObj
    while current and current:IsA("GuiObject") do
        if not current.Visible then return false end
        current = current.Parent
    end
    return true
end

local function openMailboxPhysical()
    local found = false
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local actionText = string.lower(obj.ActionText or "")
            local objectText = string.lower(obj.ObjectText or "")
            local parentName = string.lower(obj.Parent and obj.Parent.Name or "")
            
            if string.find(actionText, "mail") or string.find(objectText, "mail") 
            or string.find(parentName, "mail") or string.find(actionText, "open") then
                if fireproximityprompt then
                    local oldMax = obj.MaxActivationDistance
                    obj.MaxActivationDistance = 999999
                    task.wait(0.1)
                    fireproximityprompt(obj)
                    obj.MaxActivationDistance = oldMax
                    found = true
                    break
                end
            end
        end
    end
    return found
end

-- ==========================================
-- 3. XÓA UI CŨ VÀ TẠO TOAST
-- ==========================================
local CoreGui = game:GetService("CoreGui")
local successCore = pcall(function() local _ = CoreGui.Name end)
local ParentGui = successCore and CoreGui or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
if ParentGui:FindFirstChild("LongPTMailExploitUI") then ParentGui.LongPTMailExploitUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LongPTMailExploitUI"
ScreenGui.Parent = ParentGui

local function showToast(message, color)
    task.spawn(function()
        local toastGui = Instance.new("ScreenGui")
        toastGui.Name = "ToastNotification"
        toastGui.Parent = ParentGui
        
        local toastFrame = Instance.new("Frame", toastGui)
        toastFrame.Size = UDim2.new(0, 300, 0, 45)
        toastFrame.Position = UDim2.new(0.5, -150, 0.85, 0)
        toastFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        Instance.new("UICorner", toastFrame).CornerRadius = UDim.new(0, 8)
        
        local stroke = Instance.new("UIStroke", toastFrame)
        stroke.Color = color or Color3.fromRGB(200, 200, 200)
        stroke.Thickness = 1.5
        
        local textLabel = Instance.new("TextLabel", toastFrame)
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = message
        textLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        textLabel.TextSize = 13
        textLabel.Font = Enum.Font.GothamBold
        
        local TS = game:GetService("TweenService")
        local slideUp = TS:Create(toastFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -150, 0.75, 0)})
        slideUp:Play()
        task.wait(2.5)
        local fadeOut = TS:Create(toastFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
        local textFade = TS:Create(textLabel, TweenInfo.new(0.5), {TextTransparency = 1})
        local strokeFade = TS:Create(stroke, TweenInfo.new(0.5), {Transparency = 1})
        fadeOut:Play(); textFade:Play(); strokeFade:Play()
        fadeOut.Completed:Wait()
        toastGui:Destroy()
    end)
end

-- ==========================================
-- 4. GIAO DIỆN CHÍNH (TAB MENU STYLE)
-- ==========================================
local function LoadMainUI()
    task.spawn(function()
        while true do
            task.wait(30)
            local success, res = callAPI(UserKey)
            if success and res and res.Body then
                local data = HttpService:JSONDecode(res.Body)
                if data.status == "error" then
                    ScreenGui:Destroy()
                    player:Kick("Phiên Key kết thúc: " .. data.message)
                    break
                end
            end
        end
    end)

    local BG_COLOR = Color3.fromRGB(22, 22, 26)
    local SIDE_COLOR = Color3.fromRGB(16, 16, 20)
    local PANEL_COLOR = Color3.fromRGB(30, 30, 35)
    local ACCENT_COLOR = Color3.fromRGB(0, 190, 255)
    local BORDER_COLOR = Color3.fromRGB(50, 50, 60)

    local function addStroke(parent, color)
        local stroke = Instance.new("UIStroke")
        stroke.Color = color or BORDER_COLOR
        stroke.Thickness = 1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = parent
    end

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Size = UDim2.new(0, 480, 0, 365)
    MainFrame.Position = UDim2.new(0.5, -240, 0.5, -182)
    MainFrame.BackgroundColor3 = BG_COLOR
    MainFrame.Active = true
    MainFrame.Draggable = true 
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
    addStroke(MainFrame)

    local TopBar = Instance.new("Frame", MainFrame)
    TopBar.Size = UDim2.new(1, 0, 0, 35)
    TopBar.BackgroundTransparency = 1

    local Title = Instance.new("TextLabel", TopBar)
    Title.Size = UDim2.new(0, 200, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Sendmail Script Hub"
    Title.TextColor3 = ACCENT_COLOR 
    Title.TextSize = 14
    Title.Font = Enum.Font.GothamBlack
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local CloseBtn = Instance.new("TextButton", TopBar)
    CloseBtn.Size = UDim2.new(0, 35, 0, 35)
    CloseBtn.Position = UDim2.new(1, -35, 0, 0)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    CloseBtn.TextSize = 16
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    local MinBtn = Instance.new("TextButton", TopBar)
    MinBtn.Size = UDim2.new(0, 35, 0, 35)
    MinBtn.Position = UDim2.new(1, -70, 0, 0)
    MinBtn.BackgroundTransparency = 1
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    MinBtn.TextSize = 16
    MinBtn.Font = Enum.Font.GothamBold

    local BodyFrame = Instance.new("Frame", MainFrame)
    BodyFrame.Size = UDim2.new(1, 0, 1, -35)
    BodyFrame.Position = UDim2.new(0, 0, 0, 35)
    BodyFrame.BackgroundTransparency = 1

    local SideBar = Instance.new("Frame", BodyFrame)
    SideBar.Size = UDim2.new(0, 130, 1, -10)
    SideBar.Position = UDim2.new(0, 10, 0, 0)
    SideBar.BackgroundColor3 = SIDE_COLOR
    Instance.new("UICorner", SideBar).CornerRadius = UDim.new(0, 6)
    addStroke(SideBar)

    local function createMenuBtn(text, posY)
        local btn = Instance.new("TextButton", SideBar)
        btn.Size = UDim2.new(0.9, 0, 0, 35)
        btn.Position = UDim2.new(0.05, 0, 0, posY)
        btn.BackgroundColor3 = SIDE_COLOR
        btn.TextColor3 = Color3.fromRGB(150, 150, 150)
        btn.Text = text
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        return btn
    end

    local BtnConfig  = createMenuBtn("⚙ Cấu Hình", 10)
    local BtnList    = createMenuBtn("👥 Danh Sách", 50)
    local BtnLog     = createMenuBtn("📝 Log", 90) 
    local BtnHistory = createMenuBtn("📜 Nhật Ký", 130)

    local ContentArea = Instance.new("Frame", BodyFrame)
    ContentArea.Size = UDim2.new(1, -160, 1, -10)
    ContentArea.Position = UDim2.new(0, 150, 0, 0)
    ContentArea.BackgroundTransparency = 1

    -- =================== TAB 1: CẤU HÌNH ===================
    local ConfigTab = Instance.new("Frame", ContentArea)
    ConfigTab.Size = UDim2.new(1, 0, 1, 0)
    ConfigTab.BackgroundTransparency = 1
    ConfigTab.Visible = true

    local function createInput(parent, ph, posY)
        local tb = Instance.new("TextBox", parent)
        tb.Size = UDim2.new(1, 0, 0, 35)
        tb.Position = UDim2.new(0, 0, 0, posY)
        tb.BackgroundColor3 = PANEL_COLOR
        tb.TextColor3 = Color3.fromRGB(255, 255, 255)
        tb.PlaceholderText = ph
        tb.Text = ""
        tb.TextSize = 12
        tb.Font = Enum.Font.Gotham
        tb.ZIndex = 1
        Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 5)
        addStroke(tb)
        return tb
    end

    local SingleUserBox = createInput(ConfigTab, "Username người nhận...", 0)
    local AmountBox = createInput(ConfigTab, "Tổng số lượng muốn gửi...", 90)

    local selectedItemName = ""
    local selectedItemDisplay = ""
    
    local ItemSelectBtn = Instance.new("TextButton", ConfigTab)
    ItemSelectBtn.Size = UDim2.new(1, 0, 0, 35)
    ItemSelectBtn.Position = UDim2.new(0, 0, 0, 45)
    ItemSelectBtn.BackgroundColor3 = PANEL_COLOR
    ItemSelectBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    ItemSelectBtn.Text = "  Bấm để quét túi đồ... ▼"
    ItemSelectBtn.TextSize = 12
    ItemSelectBtn.Font = Enum.Font.Gotham
    ItemSelectBtn.TextXAlignment = Enum.TextXAlignment.Left
    ItemSelectBtn.ZIndex = 3
    Instance.new("UICorner", ItemSelectBtn).CornerRadius = UDim.new(0, 5)
    addStroke(ItemSelectBtn)

    local DropdownScroll = Instance.new("ScrollingFrame", ConfigTab)
    DropdownScroll.Size = UDim2.new(1, 0, 0, 120)
    DropdownScroll.Position = UDim2.new(0, 0, 0, 83)
    DropdownScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    DropdownScroll.BorderSizePixel = 0
    DropdownScroll.ScrollBarThickness = 3
    DropdownScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    DropdownScroll.Visible = false
    DropdownScroll.ZIndex = 10
    Instance.new("UICorner", DropdownScroll).CornerRadius = UDim.new(0, 5)
    addStroke(DropdownScroll)

    local DropdownLayout = Instance.new("UIListLayout", DropdownScroll)
    DropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function populateDropdown()
        for _, child in pairs(DropdownScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local inv = getInv()
        if not inv then
            local btn = Instance.new("TextButton", DropdownScroll)
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundTransparency = 1
            btn.Text = "  [!] Đang tải dữ liệu, thử lại sau..."
            btn.TextColor3 = Color3.fromRGB(255, 80, 80)
            btn.TextSize = 11
            btn.Font = Enum.Font.Gotham
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.ZIndex = 11
            return
        end
        
        local itemCounts = {}
        if type(inv.Pets) == "table" then
            for _, p in pairs(inv.Pets) do
                if type(p) == "table" and p.Name and not p.Equipped then
                    local pName = tostring(p.Name)
                    itemCounts[pName] = (itemCounts[pName] or 0) + 1
                end
            end
        end
        for cat, _ in pairs(STACK) do
            if type(inv[cat]) == "table" then
                for name, amt in pairs(inv[cat]) do
                    if amt > 0 then 
                        local iName = tostring(name)
                        itemCounts[iName] = (itemCounts[iName] or 0) + amt 
                    end
                end
            end
        end
        
        local sortedItems = {}
        for name, _ in pairs(itemCounts) do table.insert(sortedItems, name) end
        table.sort(sortedItems)
        
        if #sortedItems == 0 then
            local btn = Instance.new("TextButton", DropdownScroll)
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundTransparency = 1
            btn.Text = "  Túi đồ trống!"
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
            btn.TextSize = 11
            btn.Font = Enum.Font.Gotham
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.ZIndex = 11
            return
        end
        
        for _, name in ipairs(sortedItems) do
            local displayString = name .. " - x" .. tostring(itemCounts[name])
            local btn = Instance.new("TextButton", DropdownScroll)
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundTransparency = 1
            btn.Text = "  " .. displayString
            btn.TextColor3 = Color3.fromRGB(220, 220, 220)
            btn.TextSize = 12
            btn.Font = Enum.Font.Gotham
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.ZIndex = 11
            
            btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0; btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50) end)
            btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end)
            
            btn.MouseButton1Click:Connect(function()
                selectedItemName = name 
                selectedItemDisplay = displayString
                ItemSelectBtn.Text = "  " .. selectedItemDisplay .. " ▼"
                ItemSelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                DropdownScroll.Visible = false
            end)
        end
    end

    ItemSelectBtn.MouseButton1Click:Connect(function()
        DropdownScroll.Visible = not DropdownScroll.Visible
        if DropdownScroll.Visible then
            ItemSelectBtn.Text = (selectedItemDisplay == "" and "  Đang làm mới... ▲" or "  " .. selectedItemDisplay .. " ▲")
            populateDropdown()
        else
            ItemSelectBtn.Text = (selectedItemDisplay == "" and "  Bấm để quét túi đồ... ▼" or "  " .. selectedItemDisplay .. " ▼")
        end
    end)

    local useList = false
    local CheckBoxBtn = Instance.new("TextButton", ConfigTab)
    CheckBoxBtn.Size = UDim2.new(1, 0, 0, 30)
    CheckBoxBtn.Position = UDim2.new(0, 0, 0, 135)
    CheckBoxBtn.BackgroundTransparency = 1
    CheckBoxBtn.Text = "⬜ Gửi theo list Danh sách User"
    CheckBoxBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    CheckBoxBtn.TextSize = 12
    CheckBoxBtn.Font = Enum.Font.Gotham
    CheckBoxBtn.TextXAlignment = Enum.TextXAlignment.Left

    CheckBoxBtn.MouseButton1Click:Connect(function()
        useList = not useList
        if useList then
            CheckBoxBtn.Text = "✅ Gửi theo list Danh sách User"
            CheckBoxBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
            SingleUserBox.Text = ""
            SingleUserBox.PlaceholderText = "[Đang dùng danh sách bên Tab 👥]"
            SingleUserBox.TextEditable = false
        else
            CheckBoxBtn.Text = "⬜ Gửi theo list Danh sách User"
            CheckBoxBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            SingleUserBox.PlaceholderText = "Username người nhận..."
            SingleUserBox.TextEditable = true
        end
    end)

    local autoClaim = false
    local AutoClaimCheckBox = Instance.new("TextButton", ConfigTab)
    AutoClaimCheckBox.Size = UDim2.new(1, 0, 0, 30)
    AutoClaimCheckBox.Position = UDim2.new(0, 0, 0, 160)
    AutoClaimCheckBox.BackgroundTransparency = 1
    AutoClaimCheckBox.Text = "⬜ Tự động nhận thư (Auto Claim)"
    AutoClaimCheckBox.TextColor3 = Color3.fromRGB(200, 200, 200)
    AutoClaimCheckBox.TextSize = 12
    AutoClaimCheckBox.Font = Enum.Font.Gotham
    AutoClaimCheckBox.TextXAlignment = Enum.TextXAlignment.Left

    local sendAll = false
    local SendAllCheckBox = Instance.new("TextButton", ConfigTab)
    SendAllCheckBox.Size = UDim2.new(1, 0, 0, 30)
    SendAllCheckBox.Position = UDim2.new(0, 0, 0, 185)
    SendAllCheckBox.BackgroundTransparency = 1
    SendAllCheckBox.Text = "⬜ Gửi tất cả đồ trong túi (Send All)"
    SendAllCheckBox.TextColor3 = Color3.fromRGB(200, 200, 200)
    SendAllCheckBox.TextSize = 12
    SendAllCheckBox.Font = Enum.Font.Gotham
    SendAllCheckBox.TextXAlignment = Enum.TextXAlignment.Left

    SendAllCheckBox.MouseButton1Click:Connect(function()
        sendAll = not sendAll
        if sendAll then
            SendAllCheckBox.Text = "✅ Gửi tất cả đồ trong túi (Send All)"
            SendAllCheckBox.TextColor3 = Color3.fromRGB(100, 255, 100)
            AmountBox.TextEditable = false
            AmountBox.PlaceholderText = "[Đang bật chế độ Gửi Tất Cả]"
            ItemSelectBtn.Text = "  [Đang bật chế độ Gửi Tất Cả] ▼"
        else
            SendAllCheckBox.Text = "⬜ Gửi tất cả đồ trong túi (Send All)"
            SendAllCheckBox.TextColor3 = Color3.fromRGB(200, 200, 200)
            AmountBox.TextEditable = true
            AmountBox.PlaceholderText = "Tổng số lượng muốn gửi..."
            ItemSelectBtn.Text = "  Bấm để quét túi đồ... ▼"
            selectedItemName = ""
            selectedItemDisplay = ""
        end
    end)

    local SendButton = Instance.new("TextButton", ConfigTab)
    SendButton.Size = UDim2.new(0.48, 0, 0, 45)
    SendButton.Position = UDim2.new(0, 0, 0, 220)
    SendButton.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    SendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SendButton.Text = "BẮT ĐẦU GỬI"
    SendButton.TextSize = 13
    SendButton.Font = Enum.Font.GothamBold
    Instance.new("UICorner", SendButton).CornerRadius = UDim.new(0, 5)

    local ClaimButton = Instance.new("TextButton", ConfigTab)
    ClaimButton.Size = UDim2.new(0.48, 0, 0, 45)
    ClaimButton.Position = UDim2.new(0.52, 0, 0, 220)
    ClaimButton.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    ClaimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClaimButton.Text = "NHẬN THƯ (0)"
    ClaimButton.TextSize = 13
    ClaimButton.Font = Enum.Font.GothamBold
    Instance.new("UICorner", ClaimButton).CornerRadius = UDim.new(0, 5)

    -- =================== TAB 2: DANH SÁCH ===================
    local ListTab = Instance.new("Frame", ContentArea)
    ListTab.Size = UDim2.new(1, 0, 1, 0)
    ListTab.BackgroundTransparency = 1
    ListTab.Visible = false

    local ListScroll = Instance.new("ScrollingFrame", ListTab)
    ListScroll.Size = UDim2.new(1, 0, 1, -45)
    ListScroll.Position = UDim2.new(0, 0, 0, 0)
    ListScroll.BackgroundColor3 = PANEL_COLOR
    ListScroll.BorderSizePixel = 0
    ListScroll.ScrollBarThickness = 4
    ListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", ListScroll).CornerRadius = UDim.new(0, 5)
    addStroke(ListScroll)

    local UserListText = Instance.new("TextBox", ListScroll)
    UserListText.Size = UDim2.new(1, -10, 0, 0)
    UserListText.AutomaticSize = Enum.AutomaticSize.Y 
    UserListText.BackgroundTransparency = 1
    UserListText.TextColor3 = Color3.fromRGB(220, 220, 220)
    UserListText.Text = ""
    UserListText.PlaceholderText = "Nhấn (Ctrl + V) để dán danh sách User vào đây\nMỗi dòng 1 tên..."
    UserListText.TextSize = 12
    UserListText.Font = Enum.Font.Gotham
    UserListText.TextYAlignment = Enum.TextYAlignment.Top
    UserListText.TextXAlignment = Enum.TextXAlignment.Left
    UserListText.MultiLine = true
    UserListText.ClearTextOnFocus = false

    local ClearListBtn = Instance.new("TextButton", ListTab)
    ClearListBtn.Size = UDim2.new(1, 0, 0, 35)
    ClearListBtn.Position = UDim2.new(0, 0, 1, -35)
    ClearListBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    ClearListBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClearListBtn.Text = "XÓA TRỐNG DANH SÁCH"
    ClearListBtn.TextSize = 12
    ClearListBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", ClearListBtn).CornerRadius = UDim.new(0, 5)
    ClearListBtn.MouseButton1Click:Connect(function() UserListText.Text = "" end)

    -- =================== TAB 3: LOG (Tạm Thời) ===================
    local LogTab = Instance.new("Frame", ContentArea)
    LogTab.Size = UDim2.new(1, 0, 1, 0)
    LogTab.BackgroundTransparency = 1
    LogTab.Visible = false

    local LogScroll = Instance.new("ScrollingFrame", LogTab)
    LogScroll.Size = UDim2.new(1, 0, 1, 0)
    LogScroll.BackgroundColor3 = PANEL_COLOR
    LogScroll.BorderSizePixel = 0
    LogScroll.ScrollBarThickness = 3
    LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", LogScroll).CornerRadius = UDim.new(0, 5)
    addStroke(LogScroll)

    local LogLayout = Instance.new("UIListLayout", LogScroll)
    LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LogLayout.Padding = UDim.new(0, 4)

    local currentLogOrder = 0
    local function addLog(text, color)
        local LogLabel = Instance.new("TextLabel", LogScroll)
        LogLabel.Size = UDim2.new(1, -10, 0, 18)
        LogLabel.Position = UDim2.new(0, 5, 0, 0)
        LogLabel.BackgroundTransparency = 1
        LogLabel.Text = " " .. text
        LogLabel.TextColor3 = color or Color3.fromRGB(220, 220, 220)
        LogLabel.TextSize = 11
        LogLabel.Font = Enum.Font.Code 
        LogLabel.TextXAlignment = Enum.TextXAlignment.Left
        currentLogOrder = currentLogOrder - 1
        LogLabel.LayoutOrder = currentLogOrder
    end

    -- =================== TAB 4: NHẬT KÝ (Lưu Vĩnh Viễn) ===================
    local HistoryTab = Instance.new("Frame", ContentArea)
    HistoryTab.Size = UDim2.new(1, 0, 1, 0)
    HistoryTab.BackgroundTransparency = 1
    HistoryTab.Visible = false

    local HistoryScroll = Instance.new("ScrollingFrame", HistoryTab)
    HistoryScroll.Size = UDim2.new(1, 0, 1, -45)
    HistoryScroll.Position = UDim2.new(0, 0, 0, 0)
    HistoryScroll.BackgroundColor3 = PANEL_COLOR
    HistoryScroll.BorderSizePixel = 0
    HistoryScroll.ScrollBarThickness = 3
    HistoryScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", HistoryScroll).CornerRadius = UDim.new(0, 5)
    addStroke(HistoryScroll)

    local HistoryLayout = Instance.new("UIListLayout", HistoryScroll)
    HistoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
    HistoryLayout.Padding = UDim.new(0, 5)

    -- Hàm tự động vẽ các Card Giao dịch đẹp mắt
    local function renderHistoryUI()
        -- Xóa các Card cũ trước khi vẽ lại
        for _, child in pairs(HistoryScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
        end
        
        local data = ""
        if isfile and readfile and isfile(FILE_NAME) then
            local success, c = pcall(readfile, FILE_NAME)
            if success and c then data = c end
        end
        
        if data == "" then
            local emptyMsg = Instance.new("TextLabel", HistoryScroll)
            emptyMsg.Size = UDim2.new(1, 0, 0, 50)
            emptyMsg.BackgroundTransparency = 1
            emptyMsg.Text = "Chưa có giao dịch nào được lưu."
            emptyMsg.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyMsg.Font = Enum.Font.Gotham
            emptyMsg.TextSize = 12
            return
        end
        
        local logs = {}
        -- Bóc tách dữ liệu từ file txt
        for sender, target, timeStr, item, amount in string.gmatch(data, "(.-) gửi mail cho (.-) %- ([^\n]+)\n(.-) x(%d+)\n%-+") do
            table.insert(logs, {
                target = target, 
                time = timeStr, 
                item = string.gsub(item, "^%s*(.-)%s*$", "%1"), 
                amount = amount
            })
        end
        
        -- Nếu format bị lỗi, in ra chữ gốc
        if #logs == 0 then
            local rawMsg = Instance.new("TextLabel", HistoryScroll)
            rawMsg.Size = UDim2.new(1, -10, 0, 0)
            rawMsg.AutomaticSize = Enum.AutomaticSize.Y
            rawMsg.BackgroundTransparency = 1
            rawMsg.Text = data
            rawMsg.TextColor3 = Color3.fromRGB(200, 200, 200)
            rawMsg.Font = Enum.Font.Gotham
            rawMsg.TextSize = 11
            rawMsg.TextXAlignment = Enum.TextXAlignment.Left
            rawMsg.TextYAlignment = Enum.TextYAlignment.Top
            return
        end
        
        -- Vẽ Card từ Mới nhất -> Cũ nhất
        for i = #logs, 1, -1 do
            local logInfo = logs[i]
            
            local card = Instance.new("Frame", HistoryScroll)
            card.Size = UDim2.new(1, -10, 0, 45)
            card.Position = UDim2.new(0, 5, 0, 0)
            card.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
            
            local icon = Instance.new("TextLabel", card)
            icon.Size = UDim2.new(0, 35, 1, 0)
            icon.BackgroundTransparency = 1
            icon.Text = "📤"
            icon.TextSize = 18
            
            local targetLbl = Instance.new("TextLabel", card)
            targetLbl.Size = UDim2.new(1, -145, 0, 22)
            targetLbl.Position = UDim2.new(0, 35, 0, 2)
            targetLbl.BackgroundTransparency = 1
            targetLbl.Text = "Gửi tới: " .. logInfo.target
            targetLbl.TextColor3 = ACCENT_COLOR
            targetLbl.Font = Enum.Font.GothamBold
            targetLbl.TextSize = 12
            targetLbl.TextXAlignment = Enum.TextXAlignment.Left
            
            local itemLbl = Instance.new("TextLabel", card)
            itemLbl.Size = UDim2.new(1, -45, 0, 20)
            itemLbl.Position = UDim2.new(0, 35, 0, 22)
            itemLbl.BackgroundTransparency = 1
            itemLbl.Text = logInfo.item .. " x" .. logInfo.amount
            itemLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
            itemLbl.Font = Enum.Font.Gotham
            itemLbl.TextSize = 11
            itemLbl.TextXAlignment = Enum.TextXAlignment.Left
            
            local timeLbl = Instance.new("TextLabel", card)
            timeLbl.Size = UDim2.new(0, 100, 1, 0)
            timeLbl.Position = UDim2.new(1, -105, 0, 0)
            timeLbl.BackgroundTransparency = 1
            timeLbl.Text = logInfo.time
            timeLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
            timeLbl.Font = Enum.Font.Gotham
            timeLbl.TextSize = 10
            timeLbl.TextXAlignment = Enum.TextXAlignment.Right
        end
    end

    local ClearHistoryBtn = Instance.new("TextButton", HistoryTab)
    ClearHistoryBtn.Size = UDim2.new(1, 0, 0, 35)
    ClearHistoryBtn.Position = UDim2.new(0, 0, 1, -35)
    ClearHistoryBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    ClearHistoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClearHistoryBtn.Text = "XÓA NHẬT KÝ GIAO DỊCH"
    ClearHistoryBtn.TextSize = 12
    ClearHistoryBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", ClearHistoryBtn).CornerRadius = UDim.new(0, 5)
    
    ClearHistoryBtn.MouseButton1Click:Connect(function()
        clearTransactions()
        renderHistoryUI()
        showToast("Đã xóa Nhật ký giao dịch!", Color3.fromRGB(255, 100, 100))
    end)


    -- =================== LOGIC CHUYỂN TAB ===================
    local function SwitchTab(tabName)
        ConfigTab.Visible  = (tabName == "Config")
        ListTab.Visible    = (tabName == "List")
        LogTab.Visible     = (tabName == "Log")
        HistoryTab.Visible = (tabName == "History")

        BtnConfig.BackgroundColor3 = (tabName == "Config") and PANEL_COLOR or SIDE_COLOR
        BtnConfig.TextColor3 = (tabName == "Config") and ACCENT_COLOR or Color3.fromRGB(150, 150, 150)
        
        BtnList.BackgroundColor3 = (tabName == "List") and PANEL_COLOR or SIDE_COLOR
        BtnList.TextColor3 = (tabName == "List") and ACCENT_COLOR or Color3.fromRGB(150, 150, 150)
        
        BtnLog.BackgroundColor3 = (tabName == "Log") and PANEL_COLOR or SIDE_COLOR
        BtnLog.TextColor3 = (tabName == "Log") and ACCENT_COLOR or Color3.fromRGB(150, 150, 150)

        BtnHistory.BackgroundColor3 = (tabName == "History") and PANEL_COLOR or SIDE_COLOR
        BtnHistory.TextColor3 = (tabName == "History") and ACCENT_COLOR or Color3.fromRGB(150, 150, 150)

        if tabName == "History" then
            renderHistoryUI()
        end
    end

    BtnConfig.MouseButton1Click:Connect(function() SwitchTab("Config") end)
    BtnList.MouseButton1Click:Connect(function() SwitchTab("List") end)
    BtnLog.MouseButton1Click:Connect(function() SwitchTab("Log") end)
    BtnHistory.MouseButton1Click:Connect(function() SwitchTab("History") end)
    SwitchTab("Config")

    local isMinimized = false
    MinBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            BodyFrame.Visible = false
            MainFrame.Size = UDim2.new(0, 480, 0, 35)
            MinBtn.Text = "＋"
        else
            BodyFrame.Visible = true
            MainFrame.Size = UDim2.new(0, 480, 0, 365)
            MinBtn.Text = "—"
        end
    end)

    addLog("[+] Xác thực Key thành công.", Color3.fromRGB(100, 255, 100))
    addLog("[+] Hệ thống Mailbox đã sẵn sàng.", ACCENT_COLOR)

    -- ==========================================
    -- LOGIC BẮT ĐẦU GỬI ĐỒ
    -- ==========================================
    local isSending = false
    SendButton.MouseButton1Click:Connect(function()
        if isSending then
            isSending = false
            SendButton.Text = "ĐANG DỪNG LẠI..."
            return
        end
        
        local userList = {}
        if useList then
            for line in string.gmatch(UserListText.Text, "[^\r\n]+") do
                local cleanName = string.match(line, "[%w_]+") 
                if cleanName and cleanName ~= "" then table.insert(userList, cleanName) end
            end
        else
            local single = string.match(SingleUserBox.Text, "[%w_]+")
            if single and single ~= "" then table.insert(userList, single) end
        end

        local itemName = selectedItemName
        local amountPerSend = tonumber(AmountBox.Text)
        
        if not sendAll then
            if #userList == 0 or itemName == "" or not amountPerSend or amountPerSend <= 0 then
                addLog("[-] Lỗi: Điền thiếu thông tin / Chưa chọn Item / Chưa có User!", Color3.fromRGB(255, 80, 80))
                SendButton.Text = "LỖI INFO!"
                SendButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
                task.wait(1.5)
                if not isSending then
                    SendButton.Text = "BẮT ĐẦU GỬI"
                    SendButton.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
                end
                return
            end
        else
            if #userList == 0 then
                addLog("[-] Lỗi: Cần nhập ít nhất 1 Username người nhận!", Color3.fromRGB(255, 80, 80))
                SendButton.Text = "LỖI INFO!"
                SendButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
                task.wait(1.5)
                if not isSending then
                    SendButton.Text = "BẮT ĐẦU GỬI"
                    SendButton.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
                end
                return
            end
        end

        isSending = true
        SendButton.Text = "ĐANG GỬI... (BẤM DỪNG)"
        SendButton.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        SwitchTab("Log") 
        
        if sendAll then
            addLog(string.format("[*] Bắt đầu GỬI TẤT CẢ (Send All) cho %d acc...", #userList), Color3.fromRGB(255, 200, 0))
        else
            addLog(string.format("[*] Bắt đầu gửi %d %s cho %d acc...", amountPerSend, itemName, #userList), Color3.fromRGB(255, 200, 0))
        end

        task.spawn(function()
            local isInventoryEmpty = false
            
            for userIndex, targetUser in ipairs(userList) do
                if not isSending then break end 
                
                if isInventoryEmpty then
                    addLog("[-] Túi đồ đã trống, tự động hủy bỏ các User còn lại.", Color3.fromRGB(255, 180, 50))
                    break
                end
                
                addLog("[?] Đang check UID: " .. targetUser, Color3.fromRGB(180, 180, 180))
                local ok, uid = pcall(function() return Net.Mailbox.LookupPlayer:Fire(targetUser) end)
                
                if ok and type(uid) == "number" and uid > 0 then
                    local subTurn = 1
                    
                    if sendAll then
                        while true do
                            if not isSending then break end
                            local inv = getInv()
                            if not inv then addLog("[-] Lỗi tải túi đồ!", Color3.fromRGB(255, 80, 80)) break end
                            
                            local batch, actualPacked = buildSendAllBatch(inv)
                            
                            if #batch == 0 or actualPacked == 0 then 
                                addLog("[-] Đã sạch túi đồ!", Color3.fromRGB(255, 180, 50))
                                isInventoryEmpty = true
                                break 
                            end
                            
                            local mailNote = string.format("Send All x%d Items", actualPacked)
                            local success, msg = pcall(function() return Net.Mailbox.SendBatch:Fire(uid, batch, mailNote) end)
                            
                            if success then
                                addLog(string.format("[+] Đã gửi kiện hàng %d: %d items -> %s", subTurn, actualPacked, targetUser), Color3.fromRGB(100, 255, 100))
                                writeTransaction(targetUser, "Nhiều Vật Phẩm (Send All)", actualPacked)
                                subTurn = subTurn + 1
                            else
                                addLog(string.format("[-] Lỗi gửi đợt %d cho %s: %s", subTurn, targetUser, tostring(msg)), Color3.fromRGB(255, 80, 80))
                                isSending = false break
                            end
                            
                            addLog("[~] Chờ 10s...", Color3.fromRGB(150, 150, 150))
                            for w = 10, 1, -1 do
                                if not isSending then break end
                                task.wait(1)
                            end
                        end
                    else
                        local remaining = amountPerSend
                        while remaining > 0 do
                            if not isSending then break end
                            
                            local currentChunk = remaining
                            local inv = getInv()
                            if not inv then addLog("[-] Lỗi tải túi đồ!", Color3.fromRGB(255, 80, 80)) break end
                            
                            local batch, actualPacked = buildBatch(inv, { [itemName] = currentChunk })
                            
                            if #batch == 0 or actualPacked == 0 then 
                                addLog("[-] Đã sạch túi đồ: " .. itemName, Color3.fromRGB(255, 180, 50))
                                isSending = false break 
                            end
                            
                            local mailNote = string.format("x%d %s", actualPacked, itemName)
                            local success, msg = pcall(function() return Net.Mailbox.SendBatch:Fire(uid, batch, mailNote) end)
                            
                            if success then
                                addLog(string.format("[+] Đã gửi đợt %d: %d %s -> %s", subTurn, actualPacked, itemName, targetUser), Color3.fromRGB(100, 255, 100))
                                writeTransaction(targetUser, itemName, actualPacked)
                                remaining = remaining - actualPacked
                                subTurn = subTurn + 1
                            else
                                addLog(string.format("[-] Lỗi gửi đợt %d cho %s: %s", subTurn, targetUser, tostring(msg)), Color3.fromRGB(255, 80, 80))
                                isSending = false break
                            end
                            
                            addLog("[~] Chờ 10s...", Color3.fromRGB(150, 150, 150))
                            for w = 10, 1, -1 do
                                if not isSending then break end
                                task.wait(1)
                            end
                        end
                    end
                else
                    addLog(string.format("[-] Bỏ qua User (Không tồn tại): %s", targetUser), Color3.fromRGB(255, 100, 100))
                    task.wait(1)
                end
            end
            
            isSending = false
            SendButton.Text = "BẮT ĐẦU GỬI"
            SendButton.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
            addLog("[=] HOÀN TẤT TIẾN TRÌNH GỬI.", ACCENT_COLOR)
        end)
    end)

    -- ==========================================
    -- LOGIC QUÉT VÀ NHẬN THƯ FRONTEND (30 LẦN/CHU KỲ)
    -- ==========================================
    local isClaiming = false

    local function executeFrontendClaim()
        local totalClaimed = 0
        
        while isClaiming do
            local opened = openMailboxPhysical()
            if not opened then
                addLog("[-] Không tìm thấy Hòm thư trên bản đồ. Tool không thể thao tác!", Color3.fromRGB(255, 80, 80))
                return totalClaimed
            end
            
            task.wait(2) 
            
            local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
            local mailboxUI = playerGui:FindFirstChild("MailboxUI")
            if not mailboxUI or not mailboxUI:FindFirstChild("Frame") then
                addLog("[-] Lỗi: Giao diện Hộp thư không hiện ra!", Color3.fromRGB(255, 80, 80))
                return totalClaimed
            end
            
            local frame = mailboxUI.Frame
            local header = frame:FindFirstChild("Header")
            local toggleBtn = header and header:FindFirstChild("ToggleButtonSend")
            local receiveFrame = frame:FindFirstChild("RecieveFrame")
            
            if toggleBtn and isReallyVisible(toggleBtn) and (not receiveFrame or not receiveFrame.Visible) then
                addLog("[~] Đang lật sang Tab Nhận Thư...", Color3.fromRGB(200, 200, 200))
                clickUI(toggleBtn)
                task.wait(1.5)
                receiveFrame = frame:FindFirstChild("RecieveFrame")
            end
            
            local batchClaimed = 0
            if receiveFrame and receiveFrame.Visible then
                local foundMore = true
                while foundMore and isClaiming and batchClaimed < 30 do
                    foundMore = false
                    for _, obj in pairs(receiveFrame:GetDescendants()) do
                        if not isClaiming or batchClaimed >= 30 then break end
                        
                        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                            local isClaimBtn = false
                            if string.find(string.lower(obj.Name), "claim") then isClaimBtn = true end
                            if obj:IsA("TextButton") and obj.Text and string.find(string.lower(obj.Text), "claim") then isClaimBtn = true end
                            
                            if not isClaimBtn then
                                for _, child in pairs(obj:GetChildren()) do
                                    if child:IsA("TextLabel") and child.Text and string.find(string.lower(child.Text), "claim") then
                                        isClaimBtn = true; break
                                    end
                                end
                            end

                            if isClaimBtn and isReallyVisible(obj) then
                                local isTemplate = false
                                local tParent = obj.Parent
                                while tParent and tParent ~= receiveFrame do
                                    if string.find(string.lower(tParent.Name), "template") then isTemplate = true; break end
                                    tParent = tParent.Parent
                                end

                                if not isTemplate then
                                    clickUI(obj)
                                    batchClaimed = batchClaimed + 1
                                    totalClaimed = totalClaimed + 1
                                    addLog(string.format("[+] Đã click nhận thư thứ %d!", totalClaimed), Color3.fromRGB(100, 255, 100))
                                    foundMore = true
                                    task.wait(0.8) 
                                end
                            end
                        end
                    end
                    if foundMore and batchClaimed < 30 then task.wait(0.5) end
                end
            else
                addLog("[-] Không tìm thấy Tab Nhận Thư!", Color3.fromRGB(255, 80, 80))
                break 
            end
            
            local exitBtn = header and header:FindFirstChild("ExitButton")
            if exitBtn and isReallyVisible(exitBtn) then
                addLog("[~] Đang đóng Hộp thư...", Color3.fromRGB(200, 200, 200))
                clickUI(exitBtn)
                task.wait(1)
            end
            
            if batchClaimed == 0 then
                break
            end
            
            if batchClaimed >= 30 and isClaiming then
                addLog("[!] Đạt mốc 30 thư, chuẩn bị load lại Hộp thư chống lag...", Color3.fromRGB(255, 200, 0))
                task.wait(1.5)
            end
        end
        
        return totalClaimed
    end

    AutoClaimCheckBox.MouseButton1Click:Connect(function()
        autoClaim = not autoClaim
        if autoClaim then
            AutoClaimCheckBox.Text = "✅ Tự động nhận thư (Đang bật)"
            AutoClaimCheckBox.TextColor3 = Color3.fromRGB(100, 255, 100)
            addLog("[+] Đã BẬT tự quét và click nhận thư.", Color3.fromRGB(100, 255, 100))
        else
            AutoClaimCheckBox.Text = "⬜ Tự động nhận thư (Auto Claim)"
            AutoClaimCheckBox.TextColor3 = Color3.fromRGB(200, 200, 200)
            addLog("[-] Đã TẮT tự động nhận thư.", Color3.fromRGB(255, 150, 150))
        end
    end)
    
    task.spawn(function()
        local mails = getServerMails()
        local count = 0
        for _ in pairs(mails) do count = count + 1 end
        ClaimButton.Text = "NHẬN THƯ (" .. count .. ")"

        while task.wait(15) do
            if autoClaim and not isClaiming then
                local currentMails = getServerMails()
                local currentCount = 0
                for _ in pairs(currentMails) do currentCount = currentCount + 1 end
                
                ClaimButton.Text = "NHẬN THƯ (" .. currentCount .. ")"
                
                if currentCount > 0 then
                    isClaiming = true
                    ClaimButton.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
                    ClaimButton.Text = "AUTO CLICK..."
                    
                    addLog(string.format("[Auto] Có %d thư mới, tiến hành chuỗi Click...", currentCount), Color3.fromRGB(0, 255, 255))
                    
                    local claimed = executeFrontendClaim()
                    
                    addLog(string.format("[=] [Auto] Chu trình hoàn tất, húp được %d thư!", claimed), Color3.fromRGB(0, 255, 255))
                    
                    isClaiming = false
                    ClaimButton.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
                    
                    local remainingMails = getServerMails()
                    local remainingCount = 0
                    for _ in pairs(remainingMails) do remainingCount = remainingCount + 1 end
                    ClaimButton.Text = "NHẬN THƯ (" .. remainingCount .. ")"
                end
            end
        end
    end)

    ClaimButton.MouseButton1Click:Connect(function()
        if isClaiming then
            isClaiming = false
            autoClaim = false 
            AutoClaimCheckBox.Text = "⬜ Tự động nhận thư (Auto Claim)"
            AutoClaimCheckBox.TextColor3 = Color3.fromRGB(200, 200, 200)
            
            ClaimButton.Text = "ĐANG DỪNG LẠI..."
            ClaimButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
            return
        end
        
        local currentMails = getServerMails()
        local count = 0
        for _ in pairs(currentMails) do count = count + 1 end
        
        if count == 0 then
            showToast("KHÔNG CÓ THƯ MỚI ĐỂ NHẬN!", Color3.fromRGB(255, 100, 100))
            ClaimButton.Text = "NHẬN THƯ (0)"
            return
        end
        
        isClaiming = true
        ClaimButton.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        ClaimButton.Text = "ĐANG CLICK..."
        SwitchTab("Log")
        addLog(string.format("[*] Đã phát hiện %d thư, tiến hành chuỗi Click...", count), Color3.fromRGB(255, 200, 0))
        
        task.spawn(function()
            local claimed = executeFrontendClaim()
            
            if not isClaiming then
                addLog(string.format("[=] ĐÃ DỪNG LẠI! Click thành công %d thư.", claimed), Color3.fromRGB(255, 150, 0))
            else
                addLog(string.format("[=] Chu trình hoàn tất, nhận xong %d thư!", claimed), ACCENT_COLOR)
            end
            
            isClaiming = false
            ClaimButton.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
            
            local remainingMails = getServerMails()
            local remainingCount = 0
            for _ in pairs(remainingMails) do remainingCount = remainingCount + 1 end
            ClaimButton.Text = "NHẬN THƯ (" .. remainingCount .. ")"
        end)
    end)
end

-- ==========================================
-- 5. GIAO DIỆN XÁC THỰC (LOGIN KEY)
-- ==========================================
local function ShowLoginUI(errorMsg)
    local LoginFrame = Instance.new("Frame", ScreenGui)
    LoginFrame.Size = UDim2.new(0, 260, 0, 160)
    LoginFrame.Position = UDim2.new(0.5, -130, 0.5, -80)
    LoginFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    LoginFrame.Active = true
    LoginFrame.Draggable = true 
    Instance.new("UICorner", LoginFrame).CornerRadius = UDim.new(0, 8)
    
    local stroke = Instance.new("UIStroke", LoginFrame)
    stroke.Color = Color3.fromRGB(50, 50, 60)
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local Title = Instance.new("TextLabel", LoginFrame)
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundTransparency = 1
    Title.Text = "XÁC THỰC SCRIPT"
    Title.TextColor3 = Color3.fromRGB(0, 190, 255)
    Title.TextSize = 14
    Title.Font = Enum.Font.GothamBlack

    local SubTitle = Instance.new("TextLabel", LoginFrame)
    SubTitle.Size = UDim2.new(1, 0, 0, 20)
    SubTitle.Position = UDim2.new(0, 0, 30)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = errorMsg or "Nhấn (Ctrl + V) để nhập Key tại đây"
    SubTitle.TextColor3 = errorMsg and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(150, 150, 150)
    SubTitle.TextSize = 11
    SubTitle.Font = Enum.Font.Gotham

    local KeyInput = Instance.new("TextBox", LoginFrame)
    KeyInput.Size = UDim2.new(0.9, 0, 0, 35)
    KeyInput.Position = UDim2.new(0.05, 0, 0, 60)
    KeyInput.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyInput.PlaceholderText = "Nhập Key tại đây..."
    KeyInput.Text = UserKey
    KeyInput.TextSize = 12
    KeyInput.Font = Enum.Font.Gotham
    Instance.new("UICorner", KeyInput).CornerRadius = UDim.new(0, 5)
    
    local inputStroke = Instance.new("UIStroke", KeyInput)
    inputStroke.Color = Color3.fromRGB(60, 60, 70)
    inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local CheckBtn = Instance.new("TextButton", LoginFrame)
    CheckBtn.Size = UDim2.new(0.9, 0, 0, 40)
    CheckBtn.Position = UDim2.new(0.05, 0, 0, 105)
    CheckBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    CheckBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CheckBtn.Text = "KIỂM TRA KEY"
    CheckBtn.TextSize = 13
    CheckBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", CheckBtn).CornerRadius = UDim.new(0, 5)

    CheckBtn.MouseButton1Click:Connect(function()
        local input = KeyInput.Text
        if input == "" then return end
        
        CheckBtn.Text = "ĐANG XÁC THỰC..."
        CheckBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        
        local success, res = callAPI(input)
        
        if success and res and res.Body then
            local data = HttpService:JSONDecode(res.Body)
            if data.status == "success" then
                UserKey = input
                LoginFrame:Destroy()
                LoadMainUI()
            else
                SubTitle.Text = "Lỗi: " .. data.message
                SubTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
                CheckBtn.Text = "KIỂM TRA LẠI"
                CheckBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
            end
        else
            SubTitle.Text = "Lỗi kết nối tới Server API!"
            SubTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
            CheckBtn.Text = "KIỂM TRA LẠI"
            CheckBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
        end
    end)
end

-- ==========================================
-- 6. LOGIC KHỞI ĐỘNG 
-- ==========================================
if UserKey ~= "" then
    local success, res = callAPI(UserKey)
    if success and res and res.Body then
        local data = HttpService:JSONDecode(res.Body)
        if data.status == "success" then
            LoadMainUI()
        else
            ShowLoginUI("Key bị lỗi: " .. data.message)
        end
    else
        ShowLoginUI("Lỗi mạng khi kiểm tra Key tự động.")
    end
else
    ShowLoginUI()
end