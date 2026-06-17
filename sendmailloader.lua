-- ==========================================
-- 1. CẤU HÌNH CƠ BẢN VÀ API
-- ==========================================
local API_URL = "https://license.longpt.net/autosendmail/api.php"

local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local HWID = RbxAnalyticsService:GetClientId()
local UserKey = getgenv().script_key or ""
local SessionToken = HttpService:GenerateGUID(false)

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

local function getClip(btn)
    if getclipboard then
        local success, res = pcall(getclipboard)
        if success and type(res) == "string" and res ~= "" then return res end
    end
    if btn then
        local oldText = btn.Text
        local oldColor = btn.BackgroundColor3
        btn.Text = "Ctrl+V"
        btn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        task.wait(1.5)
        btn.Text = oldText
        btn.BackgroundColor3 = oldColor
    end
    return ""
end

-- ==========================================
-- 2. LÕI GAME (BACKEND MAILBOX THÔNG MINH)
-- ==========================================
local RS = game:GetService("ReplicatedStorage")
local Net = require(RS:WaitForChild("SharedModules"):WaitForChild("Networking"))
local PS = require(RS:WaitForChild("ClientModules"):WaitForChild("PlayerStateClient"))

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
                    local takeAmount = math.min(want, t[name])
                    out[#out + 1] = { Category = cat, ItemKey = name, Count = takeAmount }
                    totalPacked = totalPacked + takeAmount
                    break
                end
            end
        end
    end
    return out, totalPacked
end

-- Hàm lấy danh sách Mail ẩn dưới Server
local function getServerMails()
    local success, mailList = pcall(function()
        if Net.Mailbox.List.Invoke then
            return Net.Mailbox.List:Invoke()
        elseif Net.Mailbox.List.Fire then
            return Net.Mailbox.List:Fire()
        end
    end)
    if success and type(mailList) == "table" then
        return mailList
    end
    return {}
end

-- ==========================================
-- 3. XÓA UI CŨ
-- ==========================================
local CoreGui = game:GetService("CoreGui")
local successCore = pcall(function() local _ = CoreGui.Name end)
local ParentGui = successCore and CoreGui or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
if ParentGui:FindFirstChild("LongPTMailExploitUI") then ParentGui.LongPTMailExploitUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LongPTMailExploitUI"
ScreenGui.Parent = ParentGui

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
                    game.Players.LocalPlayer:Kick("Phiên Key kết thúc: " .. data.message)
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
    MainFrame.Size = UDim2.new(0, 480, 0, 340) -- Tăng một chút chiều cao cho UI
    MainFrame.Position = UDim2.new(0.5, -240, 0.5, -170)
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

    local BtnConfig = createMenuBtn("⚙ Cấu Hình", 10)
    local BtnList   = createMenuBtn("👥 Danh Sách", 50)
    local BtnLog    = createMenuBtn("📝 Nhật Ký", 90)

    local ContentArea = Instance.new("Frame", BodyFrame)
    ContentArea.Size = UDim2.new(1, -160, 1, -10)
    ContentArea.Position = UDim2.new(0, 150, 0, 0)
    ContentArea.BackgroundTransparency = 1

    -- TAB 1: CẤU HÌNH SEND & CLAIM
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

    -- DROPDOWN MENU CHỌN ITEM
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

    -- CHECKBOX 1: GỬI THEO LIST
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
    CheckBoxBtn.ZIndex = 1

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

    -- CHECKBOX 2: TỰ ĐỘNG GOM THƯ NGẦM (MỚI)
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
    AutoClaimCheckBox.ZIndex = 1

    -- CHIA ĐÔI KHU VỰC NÚT BẤM (Đẩy Y xuống 195 để nhường chỗ cho Checkbox mới)
    local SendButton = Instance.new("TextButton", ConfigTab)
    SendButton.Size = UDim2.new(0.48, 0, 0, 45)
    SendButton.Position = UDim2.new(0, 0, 0, 195)
    SendButton.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    SendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SendButton.Text = "BẮT ĐẦU GỬI"
    SendButton.TextSize = 13
    SendButton.Font = Enum.Font.GothamBold
    SendButton.ZIndex = 1
    Instance.new("UICorner", SendButton).CornerRadius = UDim.new(0, 5)

    local ClaimButton = Instance.new("TextButton", ConfigTab)
    ClaimButton.Size = UDim2.new(0.48, 0, 0, 45)
    ClaimButton.Position = UDim2.new(0.52, 0, 0, 195)
    ClaimButton.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    ClaimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClaimButton.Text = "NHẬN THƯ (0)"
    ClaimButton.TextSize = 13
    ClaimButton.Font = Enum.Font.GothamBold
    ClaimButton.ZIndex = 1
    Instance.new("UICorner", ClaimButton).CornerRadius = UDim.new(0, 5)

    -- TAB 2: DANH SÁCH USER
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

    -- TAB 3: NHẬT KÝ (LOGS)
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

    -- LOGIC CHUYỂN TAB 
    local function SwitchTab(tabName)
        ConfigTab.Visible = (tabName == "Config")
        ListTab.Visible   = (tabName == "List")
        LogTab.Visible    = (tabName == "Log")

        BtnConfig.BackgroundColor3 = (tabName == "Config") and PANEL_COLOR or SIDE_COLOR
        BtnConfig.TextColor3 = (tabName == "Config") and ACCENT_COLOR or Color3.fromRGB(150, 150, 150)
        
        BtnList.BackgroundColor3 = (tabName == "List") and PANEL_COLOR or SIDE_COLOR
        BtnList.TextColor3 = (tabName == "List") and ACCENT_COLOR or Color3.fromRGB(150, 150, 150)
        
        BtnLog.BackgroundColor3 = (tabName == "Log") and PANEL_COLOR or SIDE_COLOR
        BtnLog.TextColor3 = (tabName == "Log") and ACCENT_COLOR or Color3.fromRGB(150, 150, 150)
    end

    BtnConfig.MouseButton1Click:Connect(function() SwitchTab("Config") end)
    BtnList.MouseButton1Click:Connect(function() SwitchTab("List") end)
    BtnLog.MouseButton1Click:Connect(function() SwitchTab("Log") end)
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
            MainFrame.Size = UDim2.new(0, 480, 0, 340)
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

        isSending = true
        SendButton.Text = "ĐANG GỬI... (BẤM ĐỂ DỪNG)"
        SendButton.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        SwitchTab("Log") 
        addLog(string.format("[*] Bắt đầu gửi %d %s cho %d acc...", amountPerSend, itemName, #userList), Color3.fromRGB(255, 200, 0))

        task.spawn(function()
            for userIndex, targetUser in ipairs(userList) do
                if not isSending then break end 
                
                addLog("[?] Đang check UID: " .. targetUser, Color3.fromRGB(180, 180, 180))
                local ok, uid = pcall(function() return Net.Mailbox.LookupPlayer:Fire(targetUser) end)
                
                if ok and type(uid) == "number" and uid > 0 then
                    local remaining = amountPerSend
                    local subTurn = 1
                    
                    while remaining > 0 do
                        if not isSending then break end
                        
                        local currentChunk = math.min(remaining, 5000)
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
    -- LOGIC QUÉT VÀ NHẬN THƯ (BẤM THỦ CÔNG HOẶC AUTO)
    -- ==========================================
    local isClaiming = false

    -- Nút Tích Chọn Bật / Tắt Auto
    AutoClaimCheckBox.MouseButton1Click:Connect(function()
        autoClaim = not autoClaim
        if autoClaim then
            AutoClaimCheckBox.Text = "✅ Tự động nhận thư (Đang bật)"
            AutoClaimCheckBox.TextColor3 = Color3.fromRGB(100, 255, 100)
            addLog("[+] Đã BẬT tự quét và nhận thư tự động.", Color3.fromRGB(100, 255, 100))
        else
            AutoClaimCheckBox.Text = "⬜ Tự động nhận thư (Auto Claim)"
            AutoClaimCheckBox.TextColor3 = Color3.fromRGB(200, 200, 200)
            addLog("[-] Đã TẮT nhận thư tự động.", Color3.fromRGB(255, 150, 150))
        end
    end)
    
    -- Vòng lặp quét hòm thư định kỳ (Mỗi 5 giây)
    task.spawn(function()
        local mails = getServerMails()
        local count = 0
        for _ in pairs(mails) do count = count + 1 end
        ClaimButton.Text = "NHẬN THƯ (" .. count .. ")"

        while task.wait(15) do
            if not isClaiming then
                local currentMails = getServerMails()
                local claimList = {}
                local currentCount = 0
                
                for mailId, _ in pairs(currentMails) do 
                    currentCount = currentCount + 1 
                    table.insert(claimList, mailId)
                end
                
                ClaimButton.Text = "NHẬN THƯ (" .. currentCount .. ")"
                
                -- NẾU CÓ THƯ VÀ ĐANG BẬT AUTO -> TỰ KÍCH HOẠT QUÁ TRÌNH NHẬN
                if autoClaim and currentCount > 0 then
                    isClaiming = true
                    ClaimButton.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
                    ClaimButton.Text = "AUTO NHẬN..."
                    
                    -- SwitchTab("Log")
                    addLog(string.format("[Auto] Đã phát hiện %d thư, tiến hành Claim...", currentCount), Color3.fromRGB(0, 255, 255))
                    
                    local successCount = 0
                    local processedCount = 0
                    local targetCount = currentCount
                    
                    for i, mailId in ipairs(claimList) do
                        if not autoClaim or not isClaiming then 
                            targetCount = i - 1
                            break 
                        end
                        
                        local senderName = "Ẩn danh"
                        if currentMails[mailId] and currentMails[mailId].FromName then
                            senderName = tostring(currentMails[mailId].FromName)
                        end
                        
                        task.spawn(function()
                            local ok = pcall(function()
                                if Net.Mailbox.Claim.Invoke then return Net.Mailbox.Claim:Invoke(mailId)
                                elseif Net.Mailbox.Claim.Fire then return Net.Mailbox.Claim:Fire(mailId) end
                            end)
                            
                            if ok then
                                successCount = successCount + 1
                                addLog(string.format("[+] [Auto] Đã nhận thư của: %s", senderName), Color3.fromRGB(150, 255, 150))
                            end
                            processedCount = processedCount + 1
                        end)
                        task.wait(0.01)
                    end
                    
                    while processedCount < targetCount and isClaiming do
                        task.wait(0.1)
                    end
                    
                    addLog(string.format("[=] [Auto] Đã nhận thư thành công, húp được %d thư!", successCount), Color3.fromRGB(0, 255, 255))
                    
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

    -- Sự kiện khi bấm Thủ Công vào Nút Claim / Dừng
    ClaimButton.MouseButton1Click:Connect(function()
        if isClaiming then
            isClaiming = false
            autoClaim = false -- Tắt luôn Auto nếu đang bật mà user ép dừng
            AutoClaimCheckBox.Text = "⬜ Tự động nhận thư (Auto Claim)"
            AutoClaimCheckBox.TextColor3 = Color3.fromRGB(200, 200, 200)
            
            ClaimButton.Text = "ĐANG DỪNG LẠI..."
            ClaimButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
            return
        end
        
        isClaiming = true
        ClaimButton.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        ClaimButton.Text = "ĐANG TẢI DỮ LIỆU..."
        
        task.spawn(function()
            local mails = getServerMails()
            local claimList = {}
            
            for mailId, _ in pairs(mails) do
                table.insert(claimList, mailId)
            end

            local total = #claimList
            if total == 0 then
                SwitchTab("Log")
                addLog("[-] Hộp thư máy chủ trống, không có gì để nhận.", Color3.fromRGB(255, 180, 50))
                isClaiming = false
                ClaimButton.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
                ClaimButton.Text = "NHẬN THƯ (0)"
                return
            end
            
            SwitchTab("Log")
            addLog(string.format("[*] Đã kết nối Server: Tự động Claim đa luồng %d thư...", total), Color3.fromRGB(255, 200, 0))
            
            local successCount = 0
            local processedCount = 0
            local targetCount = total

            for i, mailId in ipairs(claimList) do
                if not isClaiming then 
                    targetCount = i - 1
                    break 
                end
                
                ClaimButton.Text = string.format("DỪNG NHẬN (%d/%d)", i, total)
                
                local senderName = "Ẩn danh"
                if mails[mailId] and mails[mailId].FromName then
                    senderName = tostring(mails[mailId].FromName)
                end
                
                task.spawn(function()
                    local ok, res = pcall(function()
                        if Net.Mailbox.Claim.Invoke then
                            return Net.Mailbox.Claim:Invoke(mailId)
                        elseif Net.Mailbox.Claim.Fire then
                            return Net.Mailbox.Claim:Fire(mailId)
                        end
                    end)
                    
                    if ok then
                        successCount = successCount + 1
                        addLog(string.format("[+] Đã nhận thư từ: %s", senderName), Color3.fromRGB(100, 255, 100))
                    else
                        addLog(string.format("[-] Lỗi nhận thư từ: %s", senderName), Color3.fromRGB(255, 80, 80))
                    end
                    processedCount = processedCount + 1
                end)
                task.wait(0.02)
            end
            
            while processedCount < targetCount and isClaiming do
                task.wait(0.1)
            end
            
            if not isClaiming then
                addLog(string.format("[=] ĐÃ dừng nhận thư! Đã Claim: %d/%d thư.", successCount, total), Color3.fromRGB(255, 150, 0))
            else
                addLog(string.format("[=] Đã nhận xong toàn bộ %d/%d thư!", successCount, total), ACCENT_COLOR)
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
    SubTitle.Position = UDim2.new(0, 0, 0, 30)
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
            ShowLoginUI("Key lưu sẵn bị lỗi: " .. data.message)
        end
    else
        ShowLoginUI("Lỗi mạng khi kiểm tra Key tự động.")
    end
else
    ShowLoginUI()
end