
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ITEMS = {
    Apple = {
        Color = Color3.fromRGB(255, 65, 65),
        Material = Enum.Material.SmoothPlastic,
        StackLimit = 10
    },
    Wood = {
        Color = Color3.fromRGB(130, 80, 45),
        Material = Enum.Material.Wood,
        StackLimit = 25
    },
    Crystal = {
        Color = Color3.fromRGB(80, 190, 255),
        Material = Enum.Material.Neon,
        StackLimit = 5
    }
}

local pickupFolder = Workspace:FindFirstChild("InventoryPickups")
if not pickupFolder then
    pickupFolder = Instance.new("Folder")
    pickupFolder.Name = "InventoryPickups"
    pickupFolder.Parent = Workspace
end

local function getInventory(player)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end

    return backpack
end

local function findStack(player, itemName)
    local containers = {
        player:FindFirstChildOfClass("Backpack"),
        player.Character
    }

    for _, container in ipairs(containers) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool")
                    and tool:GetAttribute("ItemType") == itemName
                    and (tool:GetAttribute("Quantity") or 1)
                        < ITEMS[itemName].StackLimit then
                    return tool
                end
            end
        end
    end
end

local function updateToolName(tool)
    local amount = tool:GetAttribute("Quantity") or 1
    local itemName = tool:GetAttribute("ItemType")
    tool.Name = itemName .. " x" .. amount
end

local function createTool(itemName, amount, player)
    local definition = ITEMS[itemName]
    if not definition then return end

    local tool = Instance.new("Tool")
    tool.RequiresHandle = true
    tool.CanBeDropped = true
    tool:SetAttribute("ItemType", itemName)
    tool:SetAttribute("Quantity", amount)

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1, 1, 1)
    handle.Color = definition.Color
    handle.Material = definition.Material
    handle.CanCollide = false
    handle.Anchored = false
    handle.Parent = tool

    updateToolName(tool)

    tool.Parent = getInventory(player)
    return tool
end

local function giveItem(player, itemName)
    local definition = ITEMS[itemName]
    if not definition then return false end

    local remaining = 1

    while remaining > 0 do
        local stack = findStack(player, itemName)

        if stack then
            local current = stack:GetAttribute("Quantity") or 1
            local amount = math.min(
                remaining,
                definition.StackLimit - current
            )

            stack:SetAttribute("Quantity", current + amount)
            updateToolName(stack)
            remaining -= amount
        else
            createTool(itemName, 1, player)
            remaining -= 1
        end
    end

    return true
end

local function createPickup(itemName, position)
    local definition = ITEMS[itemName]
    if not definition then return end

    local pickup = Instance.new("Part")
    pickup.Name = itemName .. "Pickup"
    pickup.Size = Vector3.new(2, 2, 2)
    pickup.Position = position
    pickup.Anchored = true
    pickup.Color = definition.Color
    pickup.Material = definition.Material
    pickup.Parent = pickupFolder

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect"
    prompt.ObjectText = itemName
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 10
    prompt.Parent = pickup

    local collected = false

    prompt.Triggered:Connect(function(player)
        if collected or not player.Parent then return end

        local backpack = getInventory(player)
        if not backpack then return end

        collected = true
        prompt.Enabled = false

        if giveItem(player, itemName) then
            pickup:Destroy()
        else
            collected = false
            prompt.Enabled = true
        end
    end)
end

local function setupPlayer(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
    end)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

createPickup("Red", Vector3.new(0, 3, 0))
createPickup("Dragon", Vector3.new(5, 3, 0))
createPickup("X", Vector3.new(10, 3, 0))
createPickup("RedDragonX", Vector3.new(15, 3, 0))

print("Inventory system loaded successfully")
