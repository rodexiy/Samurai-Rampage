local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RewardService = Knit.CreateService({
	Name = "RewardService",
	Client = {},
})

local MobService
local TetsuService
local LevelService
local ItemService
local InventoryService
local ArtifactService
local FloorDropService
local StanceService

function RewardService:GetRandomRewardFromWeight(Rewards: { any }, LuckBoost: number?)
	local LuckBoost = LuckBoost or 0
	local totalWeight = 0
	for _, reward in Rewards do
		totalWeight = totalWeight + reward.Weight * (1 + LuckBoost / 100)
	end

	local randomNumber = math.random() * totalWeight

	local cumulativeWeight = 0
	for _, reward in Rewards do
		cumulativeWeight = cumulativeWeight + reward.Weight * (1 + LuckBoost / 100)
		if randomNumber <= cumulativeWeight then
			local Amount = reward.Amount or 1
			if type(Amount) == "table" then
				Amount = math.random(Amount[1], Amount[2] or Amount[1])
			end

			return reward.Name, Amount
		end
	end
end

function RewardService:GetPlayersFromDamageValues(Enemy: Model, min: number?)
	local min = min or 5
	local PlayersDamage = {}
	local PlayersToReturn = {}

	local TotalDamage = 0
	for UserId, Damage in Enemy.DamageFolder:GetChildren() do
		TotalDamage += Damage.value
	end

	for _, DamageValue in Enemy.DamageFolder:GetChildren() do
		local Player = Players:GetPlayerByUserId(DamageValue.Name)

		if not Player then
			continue
		end

		if not PlayersDamage[Player] then
			PlayersDamage[Player] = 0
		end

		PlayersDamage[Player] += DamageValue.value
	end

	for Player, Damage in PlayersDamage do
		local Percentage = (Damage / TotalDamage) * 100
		if Percentage >= min then
			PlayersToReturn[Player] = Percentage
		end
	end
	return PlayersToReturn
end

function RewardService:GiveTetsuReward(Player: Player, Tetsu)
	if not Tetsu then
		return
	end
	if type(Tetsu) == "table" then
		Tetsu = math.random(Tetsu[1], Tetsu[2])
	end

	TetsuService:AddTetsu(Player, Tetsu)
end

function RewardService:GiveRewards(Character: Model, Position: Vector3)
	if Character:GetAttribute("NoRewards") or Character:GetAttribute("WisdomWorldMob") then
		return
	end

	local DamageFolder = Character:FindFirstChild("DamageFolder")
	if not DamageFolder then
		return
	end

	local MobData = MobService:GetMobData(Character)
	if not MobData then
		return
	end

	local Players = RewardService:GetPlayersFromDamageValues(Character)

	for Player, Percentage in Players do
		if Percentage < 5 then
			continue
		end
		local Exp = MobData.Rewards.Exp

		for _ in MobData.Rewards.Items or {} do
			local ItemName, Amount = RewardService:GetRandomRewardFromWeight(MobData.Rewards.Items or {})
			if ItemName == "Nothing" then
				continue
			end

			if ItemService:GetItemData(ItemName).Class == "Artifact" then
				ArtifactService:PickArtifact(Player, ItemName, true)
				continue
			end

			if Position then
				local ItemInInventory = InventoryService:GetPlayerItemByName(Player, ItemName)
				if ItemInInventory then
					local ItemData = ItemService:GetItemData(ItemName)
					if ItemInInventory.MaxStack == 1 then
						return
					end
					Amount = math.min(Amount, ItemData.MaxStack - ItemInInventory.Stack)
				else
					FloorDropService:DropItems({ { Name = ItemName, Amount = Amount } }, Position, Player)
				end
			else
				local Item = ItemService:CreateItem(ItemName, Amount)
				InventoryService:GiveItemToPlayer(Player, Item)
			end
		end

		RewardService:GiveTetsuReward(Player, MobData.Rewards.Tetsu)
		LevelService:GiveExp(Player, Exp)
	end
end

function RewardService.KnitInit()
	TetsuService = Knit.GetService("TetsuService")
	LevelService = Knit.GetService("LevelService")
	MobService = Knit.GetService("MobService")
	ItemService = Knit.GetService("ItemService")
	InventoryService = Knit.GetService("InventoryService")
	ArtifactService = Knit.GetService("ArtifactService")
	FloorDropService = Knit.GetService("FloorDropService")
	StanceService = Knit.GetService("StanceService")
end

function RewardService.KnitStart() end

return RewardService
