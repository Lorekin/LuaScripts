local AutoBuyItems = {}
local myPlayer, myHero, Time, gold, spent, CheckTome, Courier
local itemCount = {}
local JSON = require 'assets.JSON'
local itemsJSON = nil
local FList = io.open('assets/data/items.json', 'r+')
local FItems = FList:read('*a')
FList:close()
itemsJSON = JSON:decode(FItems).DOTAAbilities


AutoBuyItems.AutoBuyBook = Menu.AddOptionBool({"Utility", "AutoBuyItems"}, "AutoBuy Tome of Knowledge", false)
AutoBuyItems.AutoBuySentry = Menu.AddOptionBool({"Utility", "AutoBuyItems", "Sentry Wards"}, "AutoBuy Sentry", false)
AutoBuyItems.AutoBuyDusts = Menu.AddOptionBool({"Utility", "AutoBuyItems", "Dust of Appearance"}, "AutoBuy Dust", false)
AutoBuyItems.SliderForSentry = Menu.AddOptionSlider({"Utility", "AutoBuyItems", "Sentry Wards"}, "Amount", 1, 10, 1)
AutoBuyItems.SliderForDust = Menu.AddOptionSlider({"Utility", "AutoBuyItems", "Dust of Appearance"}, "Amount", 1, 10, 1)
AutoBuyItems.BuyDelay = 0.035
AutoBuyItems.DelaySentry, AutoBuyItems.DelayDust = 0, 0

function AutoBuyItems.GetItemCost(item)
	if item == 0 or not item then return 0 end
    local name = Ability.GetName(item)
    local multiplier = 1
    if name == "item_ward_dispenser" then
        return Item.GetCurrentCharges(item) * 75 + Item.GetSecondaryCharges(item) * 100
    end
    if not name or not itemsJSON or not itemsJSON[name] or not itemsJSON[name].ItemCost then
      	return 0
    end
    return itemsJSON[name].ItemCost
end

function AutoBuyItems.Init()
	myPlayer = Players.GetLocal()
	myHero = Heroes.GetLocal()
	-----
	if not myHero then return end
	Time = ((GameRules.GetGameTime() - GameRules.GetGameStartTime()) / 60) % 10
	local PlayerID = Player.GetPlayerID(myPlayer)
	itemCount.SentryCount = 0
	itemCount.DustCount = 0
	for i = 0, 15 do
		local item = NPC.GetItemByIndex(myHero, i)
		if item ~= 0 then
			itemName = Ability.GetName(item)	
			if itemName == "item_ward_dispenser" then
				itemCount.SentryCount = itemCount.SentryCount + Item.GetSecondaryCharges(item)
			elseif itemName == "item_ward_sentry" then
				itemCount.SentryCount = itemCount.SentryCount + Item.GetCurrentCharges(item)
			elseif itemName == "item_dust" then
				itemCount.DustCount = itemCount.DustCount + Item.GetCurrentCharges(item)
			end
		end
	end
	local isCourier, npc
	if not Courier then
		for i = 1, NPCs.Count() do 
			npc = NPCs.Get(i)
			isCourier = NPC.IsCourier(npc)	
			if isCourier and Entity.GetTeamNum(myHero) == Entity.GetTeamNum(npc) then 
				Courier = npc
				break
			end
		end
	end

	if Courier then 
		for i = 0, 8 do
			local item = NPC.GetItemByIndex(Courier, i)
			if item ~= 0 and PlayerID == Item.GetPlayerOwnerID(item) then
				itemName = Ability.GetName(item)
				if itemName == "item_ward_dispenser" then
					itemCount.SentryCount = itemCount.SentryCount + Item.GetSecondaryCharges(item)
				elseif itemName == "item_ward_sentry" then
					itemCount.SentryCount = itemCount.SentryCount + Item.GetCurrentCharges(item) 
				elseif itemName == "item_dust" then
					itemCount.DustCount = itemCount.DustCount + Item.GetCurrentCharges(item) 
				end
			end
		end
	end
end
function AutoBuyItems.Gold()
	gold = 0
	spent = 0
	myPlayer = Players.GetLocal()
	myHero = Heroes.GetLocal()
	local PlayerID = Player.GetPlayerID(myPlayer)
	for i = 0, 15 do
		item = NPC.GetItemByIndex(myHero, i)
		spent = spent + AutoBuyItems.GetItemCost(item)
	end
	if Courier then 
		for i = 0, 8 do
			item = NPC.GetItemByIndex(Courier, i)
			if item ~= 0 and PlayerID == Item.GetPlayerOwnerID(item) then
				spent = spent + AutoBuyItems.GetItemCost(item)
			end
		end
	end
	gold = Player.GetNetWorth(myPlayer) - spent
end


function AutoBuyItems.OnGameStart()
	AutoBuyItems.Init()
end

function AutoBuyItems.OnUpdate()
	if not Menu.IsEnabled(AutoBuyItems.AutoBuyBook) and not Menu.IsEnabled(AutoBuyItems.AutoBuySentry) and not Menu.IsEnabled(AutoBuyItems.AutoBuyDusts) then return end
	AutoBuyItems.Init()
	AutoBuyItems.Gold()
	if Menu.IsEnabled(AutoBuyItems.AutoBuyBook) and Time > 9.98 or Time < 0.03 and gold < 150 and not CheckTome and NPC.GetCurrentLevel(myHero) ~= 25 and GameRules.GetGameTime() > 240 then
		CheckTome = true
	end
	if Menu.IsEnabled(AutoBuyItems.AutoBuyBook) and CheckTome and gold >= 152 and NPC.GetCurrentLevel(myHero) ~= 25 then
		AutoBuyItems.Book()
		CheckTome = false
	end 
	if Menu.IsEnabled(AutoBuyItems.AutoBuyBook) and Time > 9.98 or Time < 0.03 and gold >= 150 and NPC.GetCurrentLevel(myHero) ~= 25 and GameRules.GetGameTime() > 240 then
		AutoBuyItems.Book()
	end
	if Menu.IsEnabled(AutoBuyItems.AutoBuySentry) and itemCount.SentryCount < Menu.GetValue(AutoBuyItems.SliderForSentry) and GameRules.GetGameTime() > 210 and GameRules.GetGameTime() >= AutoBuyItems.DelaySentry and gold >= 100 then
		AutoBuyItems.DelaySentry = GameRules.GetGameTime() + AutoBuyItems.BuyDelay
		AutoBuyItems.Sentry()
	end
	if Menu.IsEnabled(AutoBuyItems.AutoBuyDusts) and itemCount.DustCount < Menu.GetValue(AutoBuyItems.SliderForDust) and GameRules.GetGameTime() > 210 and GameRules.GetGameTime() >= AutoBuyItems.DelayDust and gold >= 180 then
		AutoBuyItems.DelayDust = GameRules.GetGameTime() + AutoBuyItems.BuyDelay
		AutoBuyItems.Dust()
	end
end

function AutoBuyItems.Book()
	Player.PrepareUnitOrders(myPlayer, Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, 257, Vector(0,0,0), 257, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, myHero)
end	

function AutoBuyItems.Sentry()
	Player.PrepareUnitOrders(myPlayer, Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, 43, Vector(0,0,0), 43, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, myHero)
end

function AutoBuyItems.Dust()
	Player.PrepareUnitOrders(myPlayer, Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, 40, Vector(0,0,0), 40, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, myHero)
end

return AutoBuyItems
