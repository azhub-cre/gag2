-- MM2 HALLOWEEN 2026 - CORE LOADER
-- Configuration must be assigned to getgenv().Config before this file runs.
local Config = getgenv().Config
if type(Config) ~= "table" then
    error("MM2 loader: getgenv().Config is missing. Run script.txt first.")
end

-- MM2 FARM + GUI
-- ================================

print("Info | Loading script")

Autofarm_Enable = false

-- Gom service vao dau file de cac ham o ben duoi dung chung mot nguon
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")

-- ================================
-- ANTI-AFK
-- Giu nguoi choi khong bi kick khi dung yen qua lau
-- ================================
local function anti_afk()
    Player.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    end)
end

-- ================================
-- BASEPLATE CHONG VOI
-- ================================
local function create_baseplate()
    local part = Instance.new("Part")
    part.Size = Vector3.new(100, 1, 100)
    part.Position = Vector3.new(0, 0.5, 0)
    part.Anchored = true
    part.BrickColor = BrickColor.new("Bright green")
    part.Parent = Workspace
end

anti_afk()
create_baseplate()

-- ================================
-- TOI UU GIAM LAG
-- - Xoa lobby mac dinh neu co
-- - Tat bong va mot so hieu ung anh sang
-- - Giam do phuc tap cua map
-- - Khong tac dong vao coin de khong lam hong autofarm
-- ================================
local function get_coin_container()
    for _, v in Workspace:GetChildren() do
        local CoinContainer = v:FindFirstChild("CoinContainer")
        if CoinContainer then
            return CoinContainer
        end
    end
end

local function optimize_safely(obj)
    local coinContainer = get_coin_container()

    -- Bo qua coin va cac phan tu ben trong coin container
    if obj.Name:find("Coin") or obj:IsDescendantOf(coinContainer or Workspace) then
        return
    end

    -- Tat cac hieu ung nang ve hinh anh
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Light") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
        obj.Enabled = false
        return
    end

    -- Lam trong suot decal/texture de giam so luong vat phai render
    if obj:IsA("Decal") or obj:IsA("Texture") then
        obj.Transparency = 1
        return
    end

    -- Giam do nang cua part con lai
    if obj:IsA("BasePart") then
        obj.Material = Enum.Material.SmoothPlastic
        obj.Reflectance = 0
        obj.CastShadow = false
    end
end

task.spawn(function()
    print("Info | Applying graphics optimizations")

    -- Xoa lobby mac dinh neu map co dung RegularLobby
    local regularLobby = Workspace:FindFirstChild("RegularLobby")
    if regularLobby then
        regularLobby:Destroy()
        print("Info | RegularLobby removed")
    end

    -- Tat anh sang va bong de giam tai render
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9

    -- Tat cac post effect trong Lighting
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") then
            effect.Enabled = false
        end
    end

    -- Quet toan bo Workspace va toi uu tung object
    for _, obj in pairs(Workspace:GetDescendants()) do
        pcall(function()
            optimize_safely(obj)
        end)
    end
end)

-- ================================
-- SERVICES / JOUEUR
-- ================================
local Camera = Workspace.CurrentCamera
local OriginalCameraType = Camera.CameraType
local OriginalCameraSubject = Camera.CameraSubject

local nickname = Player.Name

-- ================================
-- GUI
-- ================================
Main = Instance.new("ScreenGui")
Main.Name = "Main"
Main.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Main.IgnoreGuiInset = true
Main.DisplayOrder = 999999
Main.Parent = PlayerGui
Main.ResetOnSpawn = false

Main2 = Instance.new("Frame")
Main2.Name = "Main"
Main2.Position = UDim2.new(0, 0, 0, 0)
Main2.Size = UDim2.new(1, 0, 1, 0)
Main2.BackgroundColor3 = Color3.fromRGB(9, 4, 16)
Main2.BorderSizePixel = 0
Main2.BorderColor3 = Color3.new(0, 0, 0)
Main2.ZIndex = 1
Main2.Parent = Main

local BackgroundGradient = Instance.new("UIGradient")
BackgroundGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(7, 3, 12)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(28, 8, 43)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 4, 18)),
})
BackgroundGradient.Rotation = 115
BackgroundGradient.Parent = Main2

local Card = Instance.new("Frame")
Card.Name = "HalloweenCard"
Card.AnchorPoint = Vector2.new(0.5, 0.5)
Card.Position = UDim2.new(0.5, 0, 0.5, 0)
Card.Size = UDim2.new(0.76, 0, 0.76, 0)
Card.BackgroundColor3 = Color3.fromRGB(18, 9, 28)
Card.BackgroundTransparency = 0.08
Card.BorderSizePixel = 0
Card.ZIndex = 2
Card.Parent = Main2

local CardSize = Instance.new("UISizeConstraint")
CardSize.MinSize = Vector2.new(330, 390)
CardSize.MaxSize = Vector2.new(720, 500)
CardSize.Parent = Card

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 22)
CardCorner.Parent = Card

local CardStroke = Instance.new("UIStroke")
CardStroke.Color = Color3.fromRGB(255, 126, 24)
CardStroke.Thickness = 3
CardStroke.Transparency = 0.08
CardStroke.Parent = Card

local CardGradient = Instance.new("UIGradient")
CardGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 13, 55)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(20, 8, 31)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 17, 24)),
})
CardGradient.Rotation = 90
CardGradient.Parent = Card

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Position = UDim2.new(0, 10, 0, 18)
Content.Size = UDim2.new(1, -20, 1, -28)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ZIndex = 3
Content.Parent = Card

local TopAccent = Instance.new("Frame")
TopAccent.Name = "TopAccent"
TopAccent.AnchorPoint = Vector2.new(0.5, 0)
TopAccent.Position = UDim2.new(0.5, 0, 0, 11)
TopAccent.Size = UDim2.new(0.72, 0, 0, 3)
TopAccent.BackgroundColor3 = Color3.fromRGB(255, 135, 28)
TopAccent.BorderSizePixel = 0
TopAccent.ZIndex = 3
TopAccent.Parent = Card

local TopAccentCorner = Instance.new("UICorner")
TopAccentCorner.CornerRadius = UDim.new(1, 0)
TopAccentCorner.Parent = TopAccent

local UIList = Instance.new("UIListLayout")
UIList.Parent = Content
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIList.VerticalAlignment = Enum.VerticalAlignment.Center
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 8)

Nick = Instance.new("TextLabel")
Nick.Name = "Nick"
Nick.LayoutOrder = 2
Nick.Position = UDim2.new(0.5, 0, 0.14, 0)
Nick.Size = UDim2.new(0.9, 0, 0, 46)
Nick.BackgroundColor3 = Color3.new(1, 1, 1)
Nick.BackgroundTransparency = 1
Nick.BorderSizePixel = 0
Nick.BorderColor3 = Color3.new(0, 0, 0)
Nick.ZIndex = 999
Nick.AnchorPoint = Vector2.new(0.5, 0.5)
Nick.Text = nickname
Nick.TextColor3 = Color3.fromRGB(226, 194, 255)
Nick.TextSize = 51
Nick.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
Nick.TextScaled = true
Nick.TextWrapped = true
Nick.Parent = Content

Coin = Instance.new("TextLabel")
Coin.Name = "Coin"
Coin.LayoutOrder = 3
Coin.Position = UDim2.new(0.5, 0, 0.41, 0)
Coin.Size = UDim2.new(0.9, 0, 0, 52)
Coin.BackgroundColor3 = Color3.new(1, 1, 1)
Coin.BackgroundTransparency = 1
Coin.BorderSizePixel = 0
Coin.BorderColor3 = Color3.new(0, 0, 0)
Coin.ZIndex = 999
Coin.AnchorPoint = Vector2.new(0.5, 0.5)
Coin.Text = "Candy: 0 / 0"
Coin.TextColor3 = Color3.fromRGB(255, 174, 45)
Coin.TextSize = 38
Coin.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
Coin.TextScaled = true
Coin.TextWrapped = true
Coin.Parent = Content

Level = Instance.new("TextLabel")
Level.Name = "Level"
Level.LayoutOrder = 4
Level.Position = UDim2.new(0.5, 0, 0.5, 0)
Level.Size = UDim2.new(0.9, 0, 0, 40)
Level.BackgroundColor3 = Color3.new(1, 1, 1)
Level.BackgroundTransparency = 1
Level.BorderSizePixel = 0
Level.BorderColor3 = Color3.new(0, 0, 0)
Level.ZIndex = 999
Level.AnchorPoint = Vector2.new(0.5, 0.5)
Level.Text = "Level: ???"
Level.TextColor3 = Color3.fromRGB(201, 134, 255)
Level.TextSize = 38
Level.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
Level.TextScaled = true
Level.TextWrapped = true
Level.Parent = Content

QuestProgress = Instance.new("TextLabel")
QuestProgress.Name = "QuestProgress"
QuestProgress.LayoutOrder = 5
QuestProgress.Position = UDim2.new(0.5, 0, 0.6, 0)
QuestProgress.Size = UDim2.new(0.94, 0, 0, 38)
QuestProgress.BackgroundColor3 = Color3.new(1, 1, 1)
QuestProgress.BackgroundTransparency = 1
QuestProgress.BorderSizePixel = 0
QuestProgress.BorderColor3 = Color3.new(0, 0, 0)
QuestProgress.ZIndex = 999
QuestProgress.AnchorPoint = Vector2.new(0.5, 0.5)
QuestProgress.Text = "DAILY | EVENT | CANDY : ??? | ??? | ???"
QuestProgress.TextColor3 = Color3.fromRGB(255, 213, 92)
QuestProgress.TextSize = 28
QuestProgress.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
QuestProgress.TextScaled = true
QuestProgress.TextWrapped = false
QuestProgress.TextXAlignment = Enum.TextXAlignment.Center
QuestProgress.TextYAlignment = Enum.TextYAlignment.Center
QuestProgress.Parent = Content

Discord = Instance.new("TextLabel")
Discord.Name = "Discord"
Discord.LayoutOrder = 1
Discord.Position = UDim2.new(0.19, 0, 0.88, 0)
Discord.Size = UDim2.new(0.9, 0, 0, 42)
Discord.BackgroundColor3 = Color3.new(0.117647, 0.117647, 0.117647)
Discord.BackgroundTransparency = 1
Discord.BorderSizePixel = 0
Discord.BorderColor3 = Color3.new(0, 0, 0)
Discord.ZIndex = 999
Discord.AnchorPoint = Vector2.new(0.5, 0.5)
Discord.Text = "LONGPT  •  HALLOWEEN 2026"
Discord.TextColor3 = Color3.fromRGB(255, 115, 24)
Discord.TextSize = 29
Discord.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
Discord.TextScaled = true
Discord.TextWrapped = true
Discord.Parent = Content

Time = Instance.new("TextLabel")
Time.Name = "Time"
Time.LayoutOrder = 7
Time.Position = UDim2.new(0.5, 0, 0.71, 0)
Time.Size = UDim2.new(0.65, 0, 0, 32)
Time.BackgroundColor3 = Color3.new(1, 1, 1)
Time.BackgroundTransparency = 1
Time.BorderSizePixel = 0
Time.BorderColor3 = Color3.new(0, 0, 0)
Time.ZIndex = 999
Time.AnchorPoint = Vector2.new(0.5, 0.5)
Time.Text = "Time: ???"
Time.TextColor3 = Color3.fromRGB(191, 170, 208)
Time.TextSize = 38
Time.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
Time.TextScaled = true
Time.TextWrapped = true
Time.Parent = Content

Status = Instance.new("TextLabel")
Status.Name = "Status"
Status.LayoutOrder = 6
Status.Position = UDim2.new(0.5, 0, 0.82, 0)
Status.Size = UDim2.new(0.95, 0, 0, 48)
Status.BackgroundColor3 = Color3.new(1, 1, 1)
Status.BackgroundTransparency = 1
Status.BorderSizePixel = 0
Status.BorderColor3 = Color3.new(0, 0, 0)
Status.ZIndex = 999
Status.AnchorPoint = Vector2.new(0.5, 0.5)
Status.Text = "Status: Waiting..."
Status.TextColor3 = Color3.fromRGB(124, 255, 114)
Status.TextSize = 38
Status.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
Status.TextScaled = true
Status.TextWrapped = true
Status.Parent = Content

for _, label in ipairs({ Discord, Nick, Coin, Level, QuestProgress, Status, Time }) do
    label.TextStrokeColor3 = Color3.fromRGB(8, 3, 13)
    label.TextStrokeTransparency = 0.25
end

-- ================================
-- NUT AN / HIEN UI
-- Nut nay nam ngoai Main2 nen van bam duoc ngay ca khi an giao dien chinh
-- ================================
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleUI"
ToggleButton.Size = UDim2.new(0, 110, 0, 36)
ToggleButton.Position = UDim2.new(0, 10, 0, 10)
ToggleButton.BackgroundColor3 = Color3.fromRGB(75, 24, 98)
ToggleButton.BorderSizePixel = 0
ToggleButton.ZIndex = 1000
ToggleButton.Text = "HIDE UI"
ToggleButton.TextColor3 = Color3.fromRGB(255, 181, 64)
ToggleButton.TextSize = 18
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Parent = Main

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0.2, 0)
ToggleCorner.Parent = ToggleButton

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(255, 126, 24)
ToggleStroke.Thickness = 2
ToggleStroke.Parent = ToggleButton

ToggleButton.MouseButton1Click:Connect(function()
    Main2.Visible = not Main2.Visible
    ToggleButton.Text = Main2.Visible and "HIDE UI" or "SHOW UI"
end)

-- ================================
-- DONG HO DEM THOI GIAN
-- ================================
task.spawn(function()
    local SecondsPassed = 0
    while true do
        task.wait(1)
        SecondsPassed += 1
        local hours = math.floor(SecondsPassed / 3600)
        local minutes = math.floor((SecondsPassed % 3600) / 60)
        local seconds = SecondsPassed % 60
        Time.Text = string.format("%d:%02d:%02d", hours, minutes, seconds)
    end
end)

-- ================================
-- THONG TIN TU SERVER
-- Lay timer, level va pass level de cap nhat vao GUI
-- ================================
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemotesExtras = Remotes:WaitForChild("Extras")
local RemotesMisc = Remotes:WaitForChild("Misc")
local RemotesGameplay = Remotes:WaitForChild("Gameplay")
local Halloween2026Remotes = Remotes:WaitForChild("Events"):WaitForChild("Halloween2026Remotes")
local OpenCrate = Remotes:WaitForChild("Shop"):WaitForChild("OpenCrate")
local CrateComplete = Remotes:WaitForChild("Shop"):FindFirstChild("CrateComplete")

local QuestProgressData = {
    DailyCoins = nil,
    EventCoins = nil,
    Candies = nil,
}

local function refreshQuestProgressText()
    local daily = QuestProgressData.DailyCoins
    local event = QuestProgressData.EventCoins
    local candies = QuestProgressData.Candies

    QuestProgress.Text = string.format(
        "DAILY | EVENT | CANDY : %s | %s | %s",
        tostring(daily or "???"),
        tostring(event or "???"),
        tostring(candies or "???")
    )
end

local function readNested(data, ...)
    local current = data
    for _, key in ipairs({ ... }) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[key]
    end
    return current
end

local function applyPlayerData(data)
    if type(data) ~= "table" then
        return
    end

    local candies = tonumber(readNested(data, "Materials", "Owned", "Candies2026")) or 0
    local daily = readNested(data, "Halloween2026", "Quests", "DailyCoins", "Progress")
    local event = readNested(data, "Halloween2026", "Quests", "EventCoins", "Progress")

    if candies ~= nil then
        Level:SetAttribute("Candies", candies)
        QuestProgressData.Candies = candies
    end
    if daily ~= nil then
        QuestProgressData.DailyCoins = daily
    end
    if event ~= nil then
        QuestProgressData.EventCoins = event
    end

    refreshQuestProgressText()
end

local function getPlayerData()
    local ok, data = pcall(function()
        return RemotesExtras.GetData2:InvokeServer()
    end)
    return ok and type(data) == "table" and data or nil
end

local function getCandyCount(data)
    return readNested(data, "Materials", "Owned", "Candies2026")
end

local function getDiscordImageUrl(image)
    if not image then
        return nil
    end

    local raw = tostring(image)
    local assetId = raw:match("[?&]id=(%d+)")
        or raw:match("[?&]assetId=(%d+)")
        or raw:match("rbxassetid://(%d+)")

    if assetId then
        return "https://cdn.yummytrackstat.com/asset?assetid=" .. assetId
    end

    if raw:match("^https://") then
        return raw
    end
end

local function listContains(list, value)
    if type(list) ~= "table" or value == nil then
        return false
    end

    for _, entry in ipairs(list) do
        if tostring(entry) ~= "" and tostring(entry):lower() == tostring(value):lower() then
            return true
        end
    end
    return false
end

local function getItemDatabase()
    local database = ReplicatedStorage:FindFirstChild("Database")
    local sync = database and database:FindFirstChild("Sync")
    local itemModule = sync and sync:FindFirstChild("Item")
    if not itemModule or not itemModule:IsA("ModuleScript") then
        return nil
    end

    local ok, data = pcall(require, itemModule)
    return ok and type(data) == "table" and data or nil
end

local function getRequestFunction()
    return request or http_request or (syn and syn.request)
end

local function getConfigValue(value)
    if type(value) == "table" then
        return value[1]
    end
    return value
end

local accountHasGodly = false

local function updateAccountHasGodly(data)
    if type(data) ~= "table" then
        return accountHasGodly
    end

    local itemDatabase = getItemDatabase()
    if type(itemDatabase) ~= "table" then
        return accountHasGodly
    end

    for _, groupName in ipairs({ "Weapons", "Radios", "Perks", "Pets", "Emotes", "Toys" }) do
        local owned = readNested(data, groupName, "Owned")
        if type(owned) == "table" then
            for itemId, amount in pairs(owned) do
                if tonumber(amount) and tonumber(amount) > 0 then
                    local metadata = itemDatabase[itemId]
                    local rarity = type(metadata) == "table" and tostring(metadata.Rarity or "") or ""
                    if rarity:lower() == "godly" then
                        accountHasGodly = true
                        return true
                    end
                end
            end
        end
    end

    return accountHasGodly
end

local function getCrateArguments(boxName)
    if boxName == "Halloween2026Box" then
        return { "Halloween2026Box", "MysteryBox", "Candies2026" }
    end

    if boxName == "Mystery Box 2" then
        boxName = "MysteryBox2"
    end

    return { boxName, "MysteryBox", "Coins" }
end

task.spawn(function()
    if not Config["Auto_Change"] then
        return
    end

    local mode = tostring(Config["Change_Mode"] or "")
    local consecutiveMatches = 0

    while true do
        task.wait(120)

        local data = getPlayerData()
        updateAccountHasGodly(data)
        local candiesValue = readNested(data, "Materials", "Owned", "Candies2026")
        local candies = data and (tonumber(candiesValue) or 0) or nil
        local claimedSix = readNested(data, "Halloween2026", "Quests", "DailyCoins", "Claimed", 6)
        if claimedSix == nil then
            claimedSix = readNested(data, "Halloween2026", "Quests", "DailyCoins", "Claimed", "6")
        end

        if candies ~= nil and candies < 120 and claimedSix == true then
            consecutiveMatches += 1
        else
            consecutiveMatches = 0
        end

        if consecutiveMatches >= 2 then
            Status.Text = "Status: Change Forder..."

            if mode == "Farmsyn" then
                local client = getgenv().client
                local folderFrom = getConfigValue(Config["Folder_From"])
                local folderTo = accountHasGodly and getConfigValue(Config["Folder_Godly"]) or getConfigValue(Config["Folder_To"])

                if client and type(client.ChangeToFolder) == "function" and folderFrom and folderTo then
                    local ok, err = pcall(function()
                        return client:ChangeToFolder(folderFrom, folderTo, false, nil)
                    end)
                    if not ok then
                        warn("Farmsyn Auto Change failed:", err)
                    end
                else
                    warn("Farmsyn Auto Change missing client or folder config")
                end
            elseif mode == "FarmV5" then
                local apiKey = tostring(Config["ak_key"] or "")
                local requestFunction = getRequestFunction()
                local option = accountHasGodly and tonumber(Config["Option_Godly"]) or tonumber(Config["Option_Change"])
                if apiKey == "" then
                    warn("FarmV5 Auto Change skipped: ak_key is empty")
                elseif not requestFunction then
                    warn("FarmV5 Auto Change skipped: HTTP request API unavailable")
                else
                    local ok, response = pcall(function()
                        return requestFunction({
                            Url = "https://accountops.org/api/accounts/autoswap-complete",
                            Method = "POST",
                            Headers = {
                                ["X-Api-Key"] = apiKey,
                                ["Content-Type"] = "application/json",
                            },
                            Body = HttpService:JSONEncode({
                                username = Player.Name,
                                option = option or 1,
                            }),
                        })
                    end)
                    if not ok then
                        warn("FarmV5 Auto Change failed:", response)
                    end
                end
            else
                warn("Unknown Change_Mode:", mode)
            end

            consecutiveMatches = 0
        end
    end
end)

local webhookLastSent = {}
local function sendWebhookItem(itemId, boxName)
    local webhookUrl = tostring(Config["Webhook URL"] or "")
    if webhookUrl == "" then
        return
    end

    if webhookLastSent[itemId] and os.clock() - webhookLastSent[itemId] < 3 then
        return
    end

    local itemDatabase = getItemDatabase()
    local metadata = itemDatabase and itemDatabase[itemId]
    if type(metadata) ~= "table" then
        warn("Webhook item metadata not found:", itemId)
        return
    end

    local itemName = tostring(metadata.ItemName or metadata.Name or itemId)
    local rarity = tostring(metadata.Rarity or "Unknown")
    if rarity:lower() == "godly" then
        accountHasGodly = true
    end
    local nameMatch = listContains(Config["Webhook Name Items"], itemName)
        or listContains(Config["Webhook Name Items"], itemId)
    local rarityMatch = listContains(Config["Webhook Rarity Items"], rarity)
    if not nameMatch and not rarityMatch then
        return
    end

    webhookLastSent[itemId] = os.clock()

    local requestFunction = getRequestFunction()
    if not requestFunction then
        warn("Webhook skipped: HTTP request API is not available")
        return
    end

    local embed = {
        title = itemName,
        description = string.format(
            "Rarity: **%s**\nBox: **%s**",
            rarity,
            tostring(boxName or "Unknown")
        ),
        color = 5793266,
        footer = {
            text = "LONGPT - " .. Player.DisplayName,
        },
        timestamp = DateTime.now():ToIsoDate(),
    }

    local imageUrl = getDiscordImageUrl(metadata.Image)
    if imageUrl then
        embed.thumbnail = {
            url = imageUrl,
        }
    end

    local ok, response = pcall(function()
        return requestFunction({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = HttpService:JSONEncode({
                username = "MM2 Inventory Bot",
                embeds = { embed },
            }),
        })
    end)

    if not ok then
        warn("Item webhook failed:", response)
    end
end

local function handleCrateResult(result, boxName)
    local itemId
    if type(result) == "string" then
        itemId = result
    elseif type(result) == "table" then
        itemId = result.ItemID or result.ItemId or result.DataID or result.Name
    end

    if itemId then
        task.spawn(sendWebhookItem, tostring(itemId), boxName)
    end
end

local lastOpenedBox
if CrateComplete and CrateComplete:IsA("RemoteEvent") then
    CrateComplete.OnClientEvent:Connect(function(result)
        handleCrateResult(result, lastOpenedBox)
    end)
else
    warn("CrateComplete listener unavailable; using inventory diff only")
end

task.spawn(function()
    if not Config["Unbox Debug Verified"] then
        warn("Auto Unbox locked: Halloween box arguments have not been verified")
        return
    end

    local selectedBoxes = Config["Selected Box"] or {}
    local boxIndex = 0
    local candyCost = 600
    local lastDataWarning = 0

    if not OpenCrate:IsA("RemoteFunction") then
        warn("Auto Unbox stopped: Remotes.Shop.OpenCrate is not a RemoteFunction")
        return
    end

    while true do
        task.wait(10)

        if Config["Auto Unbox"] and not Autofarm_Enable and #selectedBoxes > 0 then
            local data = getPlayerData()
            local candiesValue = readNested(data, "Materials", "Owned", "Candies2026")
            local candies = data and tonumber(candiesValue) or nil
            local now = os.clock()

            if not data or candies == nil then
                if now - lastDataWarning >= 30 then
                    lastDataWarning = now
                    warn(
                        "Auto Unbox skipped: missing GetData2 data or Candies2026",
                        "Candies =",
                        candies
                    )
                end
                continue
            elseif candies < candyCost then
                Status.Text = string.format("Status: Saving Candy (%d/%d)", candies, candyCost)
                continue
            else
                boxIndex = (boxIndex % #selectedBoxes) + 1
                local boxName = selectedBoxes[boxIndex]
                lastOpenedBox = boxName
                local beforeData = data
                local crateArguments = getCrateArguments(boxName)
                local ok, result = pcall(function()
                    return OpenCrate:InvokeServer(table.unpack(crateArguments))
                end)

                if not ok then
                    warn("Auto Unbox error:", result)
                else
                    if result ~= nil then
                        warn(
                            "Auto Unbox response:",
                            result,
                            "Box:",
                            boxName,
                            "Args:",
                            table.concat(crateArguments, ", ")
                        )
                    end
                    handleCrateResult(result, boxName)
                    task.delay(1, function()
                        local afterData = getPlayerData()
                        if not afterData then
                            return
                        end

                        for _, groupName in ipairs({ "Weapons", "Radios", "Perks", "Pets", "Emotes", "Toys" }) do
                            local beforeOwned = readNested(beforeData, groupName, "Owned") or {}
                            local afterOwned = readNested(afterData, groupName, "Owned") or {}
                            for itemId, amount in pairs(afterOwned) do
                                if tonumber(amount) and tonumber(amount) > (tonumber(beforeOwned[itemId]) or 0) then
                                    handleCrateResult(itemId, boxName)
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
end)

task.spawn(function()
    if not Config["Enable Auto Hop"] then
        return
    end

    local checkTime = math.max(1, tonumber(Config["Check Time"]) or 1800)
    local minCandy = math.max(0, tonumber(Config["Min Candy"]) or 160)
    local sampleInterval = math.min(120, checkTime)
    local coinHistory = {}
    local previousCandies

    while true do
        local currentTime = os.clock()
        local data = getPlayerData()
        local currentCandies = tonumber(getCandyCount(data))

        if currentCandies ~= nil then
            if previousCandies ~= nil and currentCandies < previousCandies then
                coinHistory = {}
            end
            previousCandies = currentCandies

            table.insert(coinHistory, {
                time = currentTime,
                candies = currentCandies,
            })

            local targetTime = currentTime - checkTime
            local oldSample
            for _, sample in ipairs(coinHistory) do
                if sample.time <= targetTime then
                    oldSample = sample
                end
            end

            if oldSample then
                local earnedCandies = currentCandies - oldSample.candies
                if earnedCandies < minCandy then
                    Status.Text = string.format(
                        "Status: Auto Hop (%d/%d candy / %d min)",
                        earnedCandies,
                        minCandy,
                        math.floor(checkTime / 60)
                    )
                    pcall(function()
                        TeleportService:Teleport(game.PlaceId, Player)
                    end)
                    return
                end

                for index = #coinHistory, 1, -1 do
                    if coinHistory[index].time < oldSample.time then
                        table.remove(coinHistory, index)
                    end
                end
            end
        end

        task.wait(sampleInterval)
    end
end)

refreshQuestProgressText()

task.spawn(function()
    while true do
        task.wait(1)
        if not Autofarm_Enable then
            local ok, SecondsPassed = pcall(function()
                return RemotesExtras.GetTimer:InvokeServer()
            end)
            if ok and SecondsPassed and SecondsPassed > 1 then
                local minutes = math.floor(SecondsPassed / 60)
                local seconds = SecondsPassed % 60
                Status.Text = "Status: Wait End Game " .. string.format("%02d:%02d", minutes, seconds)
            end
        end
    end
end)

local EventQuestProgressed = Halloween2026Remotes:WaitForChild("EventQuestProgressed")

EventQuestProgressed.OnClientEvent:Connect(function(questName, progress)
    if questName == "DailyCoins" then
        QuestProgressData.DailyCoins = progress
    elseif questName == "EventCoins" then
        QuestProgressData.EventCoins = progress
        QuestProgressData.Candies = progress
        Level:SetAttribute("Candies", progress)
    end

    refreshQuestProgressText()
    print("Quest progress updated:", questName, progress)
end)

task.spawn(function()
    while true do
        local ok, datalevel = pcall(function()
            return RemotesMisc.GetPlayerProfile:InvokeServer(nickname)
        end)

        local playerData = getPlayerData()

        if playerData then
            applyPlayerData(playerData)
        end

        local levelValue = datalevel and datalevel.Level or Player:GetAttribute("Level")
        local candies = Level:GetAttribute("Candies")
        if levelValue ~= nil or candies ~= nil then
            Level.Text = string.format(
                "Level: %s | Candies: %s",
                tostring(levelValue or "???"),
                tostring(candies or "???")
            )
        end
        task.wait(120)
    end
end)

task.spawn(function()
    while true do
        local playerGui = PlayerGui
        local keepGuiName = "Main"
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name ~= keepGuiName then
                gui.Enabled = false
                gui.ResetOnSpawn = false
            end
        end
        task.wait(60)
    end
end)

-- ================================
-- EVENT CUA TRAN
-- Bat cac su kien RoundStart / RoundEnd / CoinCollected
-- ================================
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

Player.CharacterAdded:Connect(function(char)
    Character = char
    local newHumanoid = char:WaitForChild("Humanoid")
    Humanoid = newHumanoid

    newHumanoid.Died:Connect(function()
        print("Died")
        Autofarm_Enable = false
        Status.Text = "Status: Wait..."
        Camera.CameraType = OriginalCameraType
        Camera.CameraSubject = OriginalCameraSubject
        task.wait(10)
        if Player.Character then
            Player.Character:SetPrimaryPartCFrame(CFrame.new(0, 5, 0))
        end
    end)
end)

local RoundStartEvent = RemotesGameplay:WaitForChild("RoundStart")
RoundStartEvent.OnClientEvent:Connect(function()
    print("Start event round")
    Autofarm_Enable = true
    Status.Text = "Status: Collect Candy..."
end)

local RoundEndEvent = RemotesGameplay:WaitForChild("RoundEndFade")
RoundEndEvent.OnClientEvent:Connect(function()
    print("End event round")
    Autofarm_Enable = false
    Status.Text = "Status: End Game"
    Camera.CameraType = OriginalCameraType
    Camera.CameraSubject = OriginalCameraSubject
    task.wait(5)
    if Player.Character then
        Player.Character:SetPrimaryPartCFrame(CFrame.new(0, 5, 0))
    end
end)

local CoinCollectedEvent = RemotesGameplay:WaitForChild("CoinCollected")
CoinCollectedEvent.OnClientEvent:Connect(function(coinType, current, max)
    if tostring(coinType) ~= "Candy" then
        return
    end
    print(current, max)
    Coin.Text = "Candy: " .. tostring(current) .. " / " .. tostring(max)
    Status.Text = "Status: Collect Candy (" .. tostring(current) .. " / " .. tostring(max) .. ")"
    if tonumber(current) == tonumber(max) then
        Autofarm_Enable = false
        Status.Text = "Status: Max Candy"
        if Player.Character and Player.Character:FindFirstChild("Humanoid") then
            Player.Character.Humanoid.Health = 0
        end
        Camera.CameraType = OriginalCameraType
        Camera.CameraSubject = OriginalCameraSubject
    end
end)

-- ================================
-- AUTO FARM
-- Tim coin gan nhat va tu dong di toi de nhat
-- ================================
local attemptedCoins = {}
local coin, tween

local function GetCoinContainer()
    for _, v in Workspace:GetChildren() do
        local CoinContainer = v:FindFirstChild("CoinContainer")
        if CoinContainer then
            return CoinContainer
        end
    end
end

local function GetCoin()
    local CoinContainer = GetCoinContainer()
    if CoinContainer then
        local nearestRange, bestCoin = math.huge, nil
        for _, v in CoinContainer:GetChildren() do
            if v:IsA("BasePart")
                and v:GetAttribute("CoinID") == "Candy"
                and v:FindFirstChild("TouchInterest")
                and not attemptedCoins[v] then
                local Magnitude = (Character:GetPivot().Position - v.Position).Magnitude
                if Magnitude < nearestRange then
                    nearestRange, bestCoin = Magnitude, v
                end
            end
        end
        return nearestRange, bestCoin
    end
end

local function SetupDescendantRemoving()
    Workspace.DescendantRemoving:Connect(function(descendant)
        if descendant == coin or descendant.Parent == coin then
            if tween then
                tween:Cancel()
                tween = nil
            end
            attemptedCoins[coin] = nil
            coin = nil
        end
    end)
end

local function Tick()
    local success, err = pcall(function()
        if Character and Character.PrimaryPart then
            local _, foundCoin = GetCoin()
            coin = foundCoin
            if coin then
                attemptedCoins[coin] = true

                Humanoid.PlatformStand = true
                Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

                local cameraHeight = 5
                Camera.CameraType = Enum.CameraType.Scriptable
                Camera.CFrame = CFrame.new(coin.Position + Vector3.new(0, cameraHeight, 0), coin.Position)

                tween = TweenService:Create(
                    Character.PrimaryPart,
                    TweenInfo.new((Character.PrimaryPart.Position - coin.Position).Magnitude / Humanoid.WalkSpeed, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
                    {CFrame = coin.CFrame}
                )

                tween:Play()
                tween.Completed:Wait()
                tween = nil
            else
                attemptedCoins = {}
            end
        end
    end)

    if not success then
        warn("Error:", err)
    end
end

SetupDescendantRemoving()

while task.wait() do
    if Autofarm_Enable then
        Tick()
    end
end