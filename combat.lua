--a combat acript which also makes a dummy
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = ReplicatedStorage:FindFirstChild("PhantomCombatRemote") or Instance.new("RemoteEvent")
Remote.Name = "PhantomCombatRemote"
Remote.Parent = ReplicatedStorage

local Config = {
    Damage = {10, 10, 12, 18},
    ComboReset = 1.2,
    AttackCooldown = 0.35,
    DashCooldown = 2,
    DashSpeed = 65,
    Range = 8
}

local State = {}

local function getState(player)
    State[player] = State[player] or {
        Combo = 0,
        LastAttack = 0,
        LastCombo = 0,
        LastDash = 0,
        Blocking = false
    }
    return State[player]
end

local function getCharacter(player)
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return end
    return character, humanoid, root
end

local function createArena()
    local arena = workspace:FindFirstChild("PhantomArena")
    if arena then return end

    arena = Instance.new("Folder")
    arena.Name = "PhantomArena"
    arena.Parent = workspace

    local floor = Instance.new("Part")
    floor.Name = "TrainingFloor"
    floor.Size = Vector3.new(100, 1, 100)
    floor.Position = Vector3.new(0, 0, 0)
    floor.Anchored = true
    floor.Material = Enum.Material.Slate
    floor.Color = Color3.fromRGB(35, 39, 55)
    floor.Parent = arena

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "PhantomSpawn"
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = Vector3.new(0, 2, 0)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Parent = arena

    local dummy = Instance.new("Model")
    dummy.Name = "TrainingDummy"
    dummy.Parent = arena

    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2, 2, 1)
    root.Position = Vector3.new(0, 4, -12)
    root.Anchored = true
    root.Parent = dummy

    local body = Instance.new("Part")
    body.Name = "Torso"
    body.Size = Vector3.new(2, 2, 1)
    body.Position = root.Position
    body.Anchored = true
    body.Color = Color3.fromRGB(90, 120, 255)
    body.Parent = dummy

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.5, 1.5, 1.5)
    head.Position = root.Position + Vector3.new(0, 1.75, 0)
    head.Anchored = true
    head.Parent = dummy

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 500
    humanoid.Health = 500
    humanoid.Parent = dummy

    dummy.PrimaryPart = root

    local function syncDummy()
        if humanoid.Health <= 0 then
            task.wait(3)
            if dummy.Parent then
                humanoid.Health = humanoid.MaxHealth
            end
        end
    end

    humanoid.HealthChanged:Connect(syncDummy)
end

createArena()

local function attack(player)
    local state = getState(player)
    local character, humanoid, root = getCharacter(player)
    if not character or state.Blocking then return end

    local now = os.clock()
    if now - state.LastAttack < Config.AttackCooldown then return end
    state.LastAttack = now

    if now - state.LastCombo > Config.ComboReset then
        state.Combo = 0
    end

    state.Combo = state.Combo % 4 + 1
    state.LastCombo = now

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}

    local boxCFrame = root.CFrame * CFrame.new(0, 0, -Config.Range / 2)
    local parts = workspace:GetPartBoundsInBox(
        boxCFrame,
        Vector3.new(6, 5, Config.Range),
        params
    )

    local hitModels = {}
    for _, part in ipairs(parts) do
        local model = part:FindFirstAncestorOfClass("Model")
        local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
        if model and model ~= character and targetHumanoid
            and targetHumanoid.Health > 0 and not hitModels[targetHumanoid] then

            hitModels[targetHumanoid] = true
            targetHumanoid:TakeDamage(Config.Damage[state.Combo])

            local targetRoot = model:FindFirstChild("HumanoidRootPart")
            if targetRoot and not targetRoot.Anchored then
                local direction = targetRoot.Position - root.Position
                if direction.Magnitude > 0 then
                    targetRoot:ApplyImpulse(
                        (direction.Unit * 25 + Vector3.new(0, 8, 0))
                        * targetRoot.AssemblyMass
                    )
                end
            end
        end
    end

    Remote:FireClient(player, "Combo", state.Combo)
end

Remote.OnServerEvent:Connect(function(player, action, value)
    if typeof(action) ~= "string" then return end

    local state = getState(player)
    local character, humanoid, root = getCharacter(player)
    if not character then return end

    if action == "Attack" then
        attack(player)

    elseif action == "Block" then
        if typeof(value) == "boolean" then
            state.Blocking = value
        end

    elseif action == "Dash" then
        local now = os.clock()
        if now - state.LastDash < Config.DashCooldown then return end
        state.LastDash = now

        local direction = humanoid.MoveDirection
        if direction.Magnitude == 0 then
            direction = root.CFrame.LookVector
        end

        root:ApplyImpulse(direction.Unit * Config.DashSpeed * root.AssemblyMass)
        Remote:FireClient(player, "DashCooldown", Config.DashCooldown)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    State[player] = nil
end)
