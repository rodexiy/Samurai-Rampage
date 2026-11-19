return function(Service: any, Context: any, Resources: any): string
	local Checks = 0
	local Player = {}
	local Asset = Instance.new("Part")
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Count(Name: string): number
		local Total = 0
		for _, Item in Context.Data.Inventory do
			if Item.Name == Name then
				Total += Item.Stack
			end
		end

		return Total
	end
	Context.Data = {
		Inventory = { { Name = "WoodLog", Stack = 1 }, { Name = "WoodLog", Stack = 2 },
			{ Name = "Stone", Stack = 5 }, { Name = "IronOre", Stack = 3 }, { Name = "PlantFiber", Stack = 4 } },
		Realm = { PendingResourceRefunds = {} },
	}
	Context.Capacity = math.huge
	Service.KnitInit()
	local Success, Error = pcall(function()
		Asset:SetAttribute("Cost_WoodLog", 2)
		Asset:SetAttribute("Cost_PlantFiber", 1)
		Check(Resources.GetCost(Asset).WoodLog == 2, "Read item-specific resource attributes")
		Check(Resources.GetCost(Asset).PlantFiber == 1, "Support resources beyond the initial three")
		Check(not Resources.IsValid({ Unknown = 2 }) and not Resources.IsValid({ WoodLog = -1 })
			and not Resources.IsValid({ Stone = 1.5 }) and not Resources.IsValid({ Stone = math.huge }), "Reject invalid costs")
		Asset:SetAttribute("Cost_Stone", "2")
		Check(Resources.GetCost(Asset) == nil, "An invalid recipe cannot silently become free")
		Asset:SetAttribute("Cost_Stone", nil)
		Check(not Service:Spend(Player, { WoodLog = 2, Stone = 6 }) and Count("WoodLog") == 3 and Count("Stone") == 5,
			"A missing ingredient leaves every resource unchanged")
		Check(Service:Spend(Player, { WoodLog = 3, Stone = 2, IronOre = 1, PlantFiber = 1 }), "Pay a recipe across several stacks")
		Check(Count("WoodLog") == 0 and Count("Stone") == 3 and Count("IronOre") == 2 and Count("PlantFiber") == 3,
			"Debit the exact costs from the inventory")
		Service:Credit(Player, { WoodLog = 2 })
		Check(Count("WoodLog") == 2 and Context.Data.Realm.PendingResourceRefunds.WoodLog == 0,
			"Available refunds return to the inventory immediately")
		Context.Capacity = 0
		Service:Credit(Player, { WoodLog = 4 })
		Check(Count("WoodLog") == 2 and Context.Data.Realm.PendingResourceRefunds.WoodLog == 4,
			"A full inventory preserves the refund in saved pending credits")
		Check(not Service:Spend(Player, { WoodLog = 3 }, false), "New builds require inventory materials")
		Check(Service:Spend(Player, { WoodLog = 5 }, true), "History can reverse queued and delivered credits together")
		Check(Count("WoodLog") == 1 and Context.Data.Realm.PendingResourceRefunds.WoodLog == 0, "Reverse each credit exactly once")
		Check(not Service:Spend(Player, { WoodLog = 5 }, true) and Count("WoodLog") == 1, "Consumed refunds cannot be reversed twice")
		Service:Credit(Player, { Stone = 3 })
		Context.Capacity = 2
		Service:FlushPending(Player)
		Check(Count("Stone") == 5 and Context.Data.Realm.PendingResourceRefunds.Stone == 1, "Keep the undelivered remainder after a partial refund")
		Context.Capacity = math.huge
		Service:FlushPending(Player)
		Check(Count("Stone") == 6 and Context.Data.Realm.PendingResourceRefunds.Stone == 0, "Deliver pending resources when inventory space opens")
		Service:FlushPending(Player)
		Check(Count("Stone") == 6, "Repeated flushes never duplicate resources")
	end)
	Asset:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm resource checks passed"
end
