--[[
#########################################
# IWinDruid Discord Agamemnoth#5566  #
#########################################
]]--

---- For Druids ----
if UnitClass("player") ~= "Druid" then return end

---- Loading ----
IWin = CreateFrame("frame",nil,UIParent)
IWin.t = CreateFrame("GameTooltip", "IWin_T", UIParent, "GameTooltipTemplate")
IWin_CombatVar = {
	["reservedRage"] = 0,
	["reservedEnergy"] = 0,
	["queue"] = true,
}
local Cast = CastSpellByName

---- Event Register ----
IWin:RegisterEvent("ADDON_LOADED")
IWin:SetScript("OnEvent", function()
	if event == "ADDON_LOADED" and arg1 == "IWinDruid" then
		DEFAULT_CHAT_FRAME:AddMessage("|cff0066ff IWinDruid system loaded.|r")
		if IWin_Druid == nil then IWin_Druid = {} end
		if IWin_Druid["rageTimeToReserveBuffer"] == nil then IWin_Druid["rageTimeToReserveBuffer"] = 1.5 end
		if IWin_Druid["energyTimeToReserveBuffer"] == nil then IWin_Druid["energyTimeToReserveBuffer"] = 0 end
		if IWin_Druid["ragePerSecondPrediction"] == nil then IWin_Druid["ragePerSecondPrediction"] = 10 end
		if IWin_Druid["energyPerSecondPrediction"] == nil then IWin_Druid["energyPerSecondPrediction"] = 10 end
		if IWin_Druid["outOfRaidCombatLength"] == nil then IWin_Druid["outOfRaidCombatLength"] = 25 end
		if IWin_Druid["playerToNPCHealthRatio"] == nil then IWin_Druid["playerToNPCHealthRatio"] = 0.75 end
		if IWin_Druid["frontShred"] == nil then IWin_Druid["frontShred"] = "off" end
		IWin.hasSuperwow = SetAutoloot and true or false
		IWin:UnregisterEvent("ADDON_LOADED")
	end
end)

---- Spell data ----
function IWin:GetTalentRank(tabIndex, talentIndex)
	local _, _, _, _, currentRank = GetTalentInfo(tabIndex, talentIndex)
	return currentRank
end

IWin_RageCost = {
	["Bash"] = 10,
	["Challenging Roar"] = 15,
	["Demoralizing Roar"] = 10,
	["Enrage"] = 0 - IWin:GetTalentRank(2, 12) * 5,
	["Feral Charge"] = 5,
	["Maul"] = 15 - IWin:GetTalentRank(2, 1),
	["Savage Bite"] = 30 - IWin:GetTalentRank(2, 1),
	["Swipe"] = 20 - IWin:GetTalentRank(2, 1),
}

IWin_EnergyCost = {
	["Claw"] = 45 - IWin:GetTalentRank(2, 1),
	["Cower"] = 20,
	["Ferocious Bite"] = 35,
	["Mangle"] = 45,
	["Pounce"] = 50,
	["Rake"] = 40 - IWin:GetTalentRank(2, 1),
	["Ravage"] = 60,
	["Rip"] = 30,
	["Shred"] = 60 - IWin:GetTalentRank(2, 13) * 6,
	["Tiger's Fury"] = 30,
}

IWin_Taunt = {
	"Taunt",
	"Mocking Blow",
	"Challenging Shout",
	"Growl",
	"Challenging Roar",
	"Hand of Reckoning",
}

IWin_Root = {
	"Net",
	"Ret",
	"Web Explosion",
	"Hooked Net",
	"Web",
	"Entangling Roots",
	"Frost Nova",
	"Encasing Web",
}

---- Functions ----
function IWin:GetBuffIndex(unit, spell)
	if unit == "player" then
		if not IWin.hasSuperwow then
	    	DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFbalakethelock's SuperWoW|r required:")
	        DEFAULT_CHAT_FRAME:AddMessage("https://github.com/balakethelock/SuperWoW")
	    	return 0
		end
	    local index = 0
	    while true do
	        spellID = GetPlayerBuffID(index)
	        if not spellID then break end
	        if spell == SpellInfo(spellID) then
	        	return index
	        end
	        index = index + 1
	    end
	else
		local index = 1
		while UnitBuff(unit, index) do
			IWin_T:SetOwner(WorldFrame, "ANCHOR_NONE")
			IWin_T:ClearLines()
			IWin_T:SetUnitBuff(unit, index)
			local buffName = IWin_TTextLeft1:GetText()
			if buffName == spell then
				return index
			end
			index = index + 1
		end
	end
	return nil
end

function IWin:GetDebuffIndex(unit, spell)
	index = 1
	while UnitDebuff(unit, index) do
		IWin_T:SetOwner(WorldFrame, "ANCHOR_NONE")
		IWin_T:ClearLines()
		IWin_T:SetUnitDebuff(unit, index)
		local buffName = IWin_TTextLeft1:GetText()
		if buffName == spell then 
			return index
		end
		index = index + 1
	end	
	return nil
end

function IWin:GetBuffStack(unit, spell)
	local index = IWin:GetBuffIndex(unit, spell)
	if index then
		local _, stack = UnitBuff(unit, index)
		return stack
	end
	local index = IWin:GetDebuffIndex(unit, spell)
	if index then
		local _, stack = UnitDebuff(unit, index)
		return stack
	end
	return 0
end

function IWin:IsBuffStack(unit, spell, stack)
	return IWin:GetBuffStack(unit, spell) == stack
end

function IWin:IsBuffActive(unit, spell)
	return IWin:GetBuffRemaining(unit, spell) ~= 0
end

function IWin:GetBuffRemaining(unit, spell)
	if unit == "player" then
		local index = IWin:GetBuffIndex(unit, spell)
		if index then
			return GetPlayerBuffTimeLeft(index)
		end
		local index = IWin:GetDebuffIndex(unit, spell)
		if index then
			return GetPlayerBuffTimeLeft(index)
		end
	elseif unit == "target" then
		local libdebuff = pfUI and pfUI.api and pfUI.api.libdebuff or ShaguTweaks and ShaguTweaks.libdebuff
		if not libdebuff then
	    	DEFAULT_CHAT_FRAME:AddMessage("Either pfUI or ShaguTweaks required")
	    	return 0
		end
		local index = IWin:GetDebuffIndex(unit, spell)
		if index then
			local _, _, _, _, _, _, timeleft = libdebuff:UnitDebuff("target", index)
			return timeleft
		end
	end
	return 0
end

function IWin:GetCooldownRemaining(spell)
	local spellID = 1
	local bookspell = GetSpellName(spellID, "BOOKTYPE_SPELL")
	while bookspell do	
		if spell == bookspell then
			local start, duration = GetSpellCooldown(spellID, "BOOKTYPE_SPELL")
			if start ~= 0 and duration ~= 1.5 then
				return duration - (GetTime() - start)
			else
				return 0
			end
		end
		spellID = spellID + 1
		bookspell = GetSpellName(spellID, "BOOKTYPE_SPELL")
	end
	return false
end

function IWin:IsOnCooldown(spell)
	return IWin:GetCooldownRemaining(spell) ~= 0
end

function IWin:IsSpellLearnt(spell)
	local spellID = 1
	local bookspell = GetSpellName(spellID, "BOOKTYPE_SPELL")
	while bookspell do
		if bookspell == spell then
			return true
		end
		spellID = spellID + 1
		bookspell = GetSpellName(spellID, "BOOKTYPE_SPELL")
	end
	return false
end

function IWin:IsCharging()
	local chargeTimeActive = GetTime() - IWin_CombatVar["charge"]
	return chargeTimeActive < 1
end

function IWin:IsStanceActive(stance)
	local forms = GetNumShapeshiftForms()
	for index = 1, forms do
		local _, name, active = GetShapeshiftFormInfo(index)
		if name == stance then
			return active == 1
		end
	end
	return false
end

function IWin:GetTimeToDie()
	local ttd = 0
	if UnitInRaid("player") or UnitIsPVP("target") then
		ttd = 999
	elseif GetNumPartyMembers() ~= 0 then
		ttd = UnitHealth("target") / UnitHealthMax("player") * IWin_Druid["playerToNPCHealthRatio"] * IWin_Druid["outOfRaidCombatLength"] / GetNumPartyMembers() * 2
	else
		ttd = UnitHealth("target") / UnitHealthMax("player") * IWin_Druid["playerToNPCHealthRatio"] * IWin_Druid["outOfRaidCombatLength"]
	end
	return ttd
end

function IWin:GetHealthPercent(unit)
	return UnitHealth(unit) / UnitHealthMax(unit)
end

function IWin:IsExecutePhase()
	return IWin:GetHealthPercent("target") <= 0.2
end

function IWin:IsInRange(spell)
	if not IsSpellInRange
		or not spell
		or not IWin:IsSpellLearnt(spell) then
        	return CheckInteractDistance("target", 3) ~= nil
	else
		return IsSpellInRange(spell, "target") == 1
	end
end

function IWin:IsRageAvailable(spell)
	local rageRequired = IWin_RageCost[spell] + IWin_CombatVar["reservedRage"]
	return UnitMana("player") >= rageRequired
end

function IWin:IsRageCostAvailable(spell)
	return UnitMana("player") >= IWin_RageCost[spell]
end

function IWin:GetRageToReserve(spell, trigger, unit)
	local spellTriggerTime = 0
	if trigger == "nocooldown" then
		return IWin_RageCost[spell]
	elseif trigger == "cooldown" then
		spellTriggerTime = IWin:GetCooldownRemaining(spell) or 0
	elseif trigger == "buff" or trigger == "partybuff" then
		spellTriggerTime = IWin:GetBuffRemaining(unit, spell) or 0
	end
	local reservedRageTime = 0
	if IWin_Druid["ragePerSecondPrediction"] > 0 then
		reservedRageTime = IWin_CombatVar["reservedRage"] / IWin_Druid["ragePerSecondPrediction"]
	end
	local timeToReserveRage = math.max(0, spellTriggerTime - IWin_Druid["rageTimeToReserveBuffer"] - reservedRageTime)
	if trigger == "partybuff" or IWin:IsSpellLearnt(spell) then
		return math.max(0, IWin_RageCost[spell] - IWin_Druid["ragePerSecondPrediction"] * timeToReserveRage)
	end
	return 0
end

function IWin:IsTimeToReserveRage(spell, trigger, unit)
	return IWin:GetRageToReserve(spell, trigger, unit) ~= 0
end

function IWin:SetReservedRage(spell, trigger, unit)
	IWin_CombatVar["reservedRage"] = IWin_CombatVar["reservedRage"] + IWin:GetRageToReserve(spell, trigger, unit)
end

function IWin:IsEnergyAvailable(spell)
	local energyRequired = IWin_EnergyCost[spell] + IWin_CombatVar["reservedEnergy"]
	return UnitMana("player") >= energyRequired
end

function IWin:IsEnergyCostAvailable(spell)
	return UnitMana("player") >= IWin_EnergyCost[spell]
end

function IWin:GetEnergyToReserve(spell, trigger, unit)
	local spellTriggerTime = 0
	local energyPerSecondPrediction = 0
	if IWin:IsBuffActive("player", "Tiger's Fury") then
		energyPerSecondPrediction = IWin_Druid["energyPerSecondPrediction"] + 3.3
	else
		energyPerSecondPrediction = IWin_Druid["energyPerSecondPrediction"]
	end
	if trigger == "nocooldown" then
		return IWin_EnergyCost[spell]
	elseif trigger == "cooldown" then
		spellTriggerTime = IWin:GetCooldownRemaining(spell) or 0
	elseif trigger == "buff" or trigger == "partybuff" then
		spellTriggerTime = IWin:GetBuffRemaining(unit, spell) or 0
	end
	local reservedEnergyTime = 0
	if energyPerSecondPrediction > 0 then
		reservedEnergyTime = IWin_CombatVar["reservedEnergy"] / energyPerSecondPrediction
	end
	local timeToReserveEnergy = math.max(0, spellTriggerTime - IWin_Druid["energyTimeToReserveBuffer"] - reservedEnergyTime)
	if trigger == "partybuff" or IWin:IsSpellLearnt(spell) then
		return math.max(0, IWin_EnergyCost[spell] - energyPerSecondPrediction * timeToReserveEnergy)
	end
	return 0
end

function IWin:IsTimeToReserveEnergy(spell, trigger, unit)
	return IWin:GetEnergyToReserve(spell, trigger, unit) ~= 0
end

function IWin:SetReservedEnergy(spell, trigger, unit)
	IWin_CombatVar["reservedEnergy"] = IWin_CombatVar["reservedEnergy"] + IWin:GetEnergyToReserve(spell, trigger, unit)
end

function IWin:IsTanking()
	return UnitIsUnit("targettarget", "player")
end

function IWin:GetItemID(itemLink)
	for itemID in string.gfind(itemLink, "|c%x+|Hitem:(%d+):%d+:%d+:%d+|h%[(.-)%]|h|r$") do
		return itemID
	end
end

IWin_UnitClassification = {
	["worldboss"] = true,
	["rareelite"] = true,
	["elite"] = true,
	["rare"] = false,
	["normal"] = false,
	["trivial"] = false,
}

function IWin:IsElite()
	local classification = UnitClassification("target")
	return IWin_UnitClassification[classification]
end

function IWin:IsTaunted()
	local index = 1
	while IWin_Taunt[index] do
		local taunt = IWin:IsBuffActive("target", IWin_Taunt[index])
		if taunt then
			return true
		end
		index = index + 1
	end
	return false
end

---- General Actions ----
function IWin:TargetEnemy()
	if not UnitExists("target") or UnitIsDead("target") or UnitIsFriend("target", "player") then
		TargetNearestEnemy()
	end
end

function IWin:StartAttack()
	local attackActionFound = false
	for action = 1, 172 do
		if IsAttackAction(action) then
			attackActionFound = true
			if not IsCurrentAction(action) then
				UseAction(action)
			end
		end
	end
	if not attackActionFound
		and not PlayerFrame.inCombat then
			AttackTarget()
	end
end

function IWin:MarkSkull()
	if UnitExists("target")
		and GetRaidTargetIndex("target") ~= 8
		and not UnitIsFriend("player", "target")
		and not UnitInRaid("player")
		and GetNumPartyMembers() ~= 0 then
			SetRaidTarget("target", 8)
	end
end

function IWin:CancelPlayerBuff(spell)
	local index = IWin:GetBuffIndex("player", spell)
	if index then
		CancelPlayerBuff(index)
	end
end

function IWin:CancelForm()
	IWin:CancelPlayerBuff("Bear Form")
	IWin:CancelPlayerBuff("Cat Form")
end

function IWin:CancelRoot()
	if not IWin:IsInRange()
		or not IWin:IsTanking() then
			for root in IWin_Root do
				if IWin:IsBuffActive("player", IWin_Root[root]) then
					IWin:CancelForm()
					break
				end
			end
	end
end

---- Class Actions ----
function IWin:BearForm()
	if IWin:IsSpellLearnt("Bear Form")
		and not IWin:IsStanceActive("Bear Form")
		and IWin_CombatVar["queue"] then
			Cast("Bear Form")
	end
end

function IWin:CatForm()
	if IWin:IsSpellLearnt("Cat Form")
		and not IWin:IsStanceActive("Cat Form")
		and IWin_CombatVar["queue"] then
			Cast("Cat Form")
	end
end

function IWin:Claw()
	if IWin:IsSpellLearnt("Claw")
		and IWin:IsStanceActive("Cat Form")
		and IWin:IsEnergyAvailable("Claw") then
			Cast("Claw")
	end
end

function IWin:DemoralizingRoar()
	if IWin:IsSpellLearnt("Demoralizing Roar")
		and IWin:IsRageAvailable("Demoralizing Roar")
		and IWin:IsInRange()
		and not IWin:IsBuffActive("target", "Demoralizing Roar")
		and IWin:GetTimeToDie() > 10 then
			Cast("Demoralizing Roar")
	end
end

function IWin:Enrage()
	if IWin:IsSpellLearnt("Enrage")
		and not IWin:IsOnCooldown("Enrage")
		and UnitMana("player") < 50 then
			Cast("Enrage")
	end
end

function IWin:FaerieFireFeral()
	if IWin:IsSpellLearnt("Faerie Fire (Feral)")
		and not IWin:IsBuffActive("target", "Faerie Fire (Feral)")
		and (
				IWin:IsStanceActive("Cat Form")
				or IWin:IsStanceActive("Bear Form")
				or IWin:IsStanceActive("Dire Bear Form")
			) then
			Cast("Faerie Fire (Feral)(Rank 3)")
			Cast("Faerie Fire (Feral)(Rank 2)")
			Cast("Faerie Fire (Feral)(Rank 1)")
	end
end

function IWin:FerociousBite()
	if IWin:IsSpellLearnt("Ferocious Bite")
		and IWin:IsStanceActive("Cat Form")
		and IWin:IsEnergyAvailable("Ferocious Bite")
		and GetComboPoints() > 3 then
			Cast("Ferocious Bite")
	end
end

function IWin:Growl()
	if IWin:IsSpellLearnt("Growl")
		and not IWin:IsTanking()
		and not IWin:IsOnCooldown("Growl")
		and not IWin:IsTaunted() then
			if not IWin:IsStanceActive("Bear Form") then
				Cast("Bear Form")
			else
				Cast("Growl")
			end
	end
end

function IWin:MarkOfTheWild()
	if IWin:IsSpellLearnt("Mark of the Wild")
		and IWin_CombatVar["queue"]
		and not (CheckInteractDistance("target", 4) ~= nil)
		and IWin:GetBuffRemaining("player","Mark of the Wild") < 60
		and not UnitAffectingCombat("player") then
			IWin_CombatVar["queue"] = false
			IWin:CancelForm()
			Cast("Mark of the Wild","player")
	end
end

function IWin:Maul()
	if IWin:IsSpellLearnt("Maul")
		and IWin:IsStanceActive("Bear Form") then
			if IWin:IsRageAvailable("Maul") then
				Cast("Maul")
			else
				--SpellStopCasting()
			end
	end
end

function IWin:Moonfire()
	if IWin:IsSpellLearnt("Moonfire")
		--and IWin_CombatVar["queue"]
		and not IWin:IsBuffActive("target", "Moonfire") then
			IWin_CombatVar["queue"] = false
			Cast("Moonfire")
	end
end

function IWin:Rake()
	if IWin:IsSpellLearnt("Rake")
		and IWin:IsStanceActive("Cat Form")
		and IWin:IsEnergyAvailable("Rake")
		and not IWin:IsBuffActive("target", "Rake")
		and not (
					UnitCreatureType("target") == "Undead"
					or UnitCreatureType("target") == "Mechanical"
					or UnitCreatureType("target") == "Elemental"
				) then
			Cast("Rake")
	end
end

function IWin:SetReservedEnergyRake()
	if not (
				UnitCreatureType("target") == "Undead"
				or UnitCreatureType("target") == "Mechanical"
				or UnitCreatureType("target") == "Elemental"
			) then
			IWin:SetReservedEnergy("Rake", "debuff", "target")
	end
end

function IWin:Rip()
	if IWin:IsSpellLearnt("Rip")
		and IWin:IsStanceActive("Cat Form")
		and IWin:IsEnergyAvailable("Rip")
		and not IWin:IsBuffActive("target","Rip")
		and GetComboPoints() > 2
		and IWin:GetTimeToDie() > 10
		and not (
					UnitCreatureType("target") == "Undead"
					or UnitCreatureType("target") == "Mechanical"
					or UnitCreatureType("target") == "Elemental"
				) then
			Cast("Rip")
	end
end

function IWin:SetReservedEnergyRip()
	if not IWin:IsBuffActive("target","Rip")
		and GetComboPoints() > 2
		and IWin:GetTimeToDie() > 10
		and not (
					UnitCreatureType("target") == "Undead"
					or UnitCreatureType("target") == "Mechanical"
					or UnitCreatureType("target") == "Elemental"
				) then
		IWin:SetReservedEnergy("Rip", "nocooldown")
	end
end

function IWin:Shred()
	if IWin:IsSpellLearnt("Shred")
		and IWin:IsStanceActive("Cat Form")
		and IWin:IsEnergyAvailable("Shred")
		and (
				(
					UnitMana("player") < 100
					and IWin_Druid["frontShred"] == "on"
				)
				or not IWin:IsTanking()
			) then
			Cast("Shred")
	end
end

function IWin:SetReservedEnergyShred()
	if (
			UnitMana("player") < 100
			and IWin_Druid["frontShred"] == "on"
		)
		or not IWin:IsTanking() then
			IWin:SetReservedEnergy("Shred", "nocooldown")
	end
end

function IWin:Swipe()
	if IWin:IsSpellLearnt("Swipe")
		and IWin:IsStanceActive("Bear Form")
		and IWin:IsRageAvailable("Swipe") then
			Cast("Swipe")
	end
end

function IWin:Thorns()
	if IWin:IsSpellLearnt("Thorns")
		and IWin_CombatVar["queue"]
		and not (CheckInteractDistance("target", 4) ~= nil)
		and IWin:GetBuffRemaining("player","Thorns") < 60
		and not UnitAffectingCombat("player") then
			IWin_CombatVar["queue"] = false
			IWin:CancelForm()
			Cast("Thorns","player")
	end
end

function IWin:TigersFury()
	if IWin:IsSpellLearnt("Tiger's Fury")
		and IWin:IsStanceActive("Cat Form")
		and IWin:IsEnergyAvailable("Tiger's Fury")
		and not IWin:IsBuffActive("player", "Tiger's Fury")
		and IWin:GetTimeToDie() > 6 then
			Cast("Tiger's Fury")
	end
end

function IWin:SetReservedEnergyTigersFury()
	if IWin:GetTimeToDie() > 6 then
		IWin:SetReservedEnergy("Tiger's Fury", "buff", "player")
	end
end

function IWin:Wrath()
	if IWin:IsSpellLearnt("Wrath")
		and IWin_CombatVar["queue"] then
			IWin_CombatVar["queue"] = false
			Cast("Wrath")
	end
end

function IWin:WrathOOC()
	if IWin:IsSpellLearnt("Wrath")
		--and IWin_CombatVar["queue"]
		and not UnitAffectingCombat("player") then
			IWin_CombatVar["queue"] = false
			Cast("Wrath")
	end
end

---- idebug button ----
SLASH_IDEBUG1 = '/idebug'
function SlashCmdList.IDEBUG()
	--DEFAULT_CHAT_FRAME:AddMessage()
	IWin:FaerieFireFeral()
end

---- commands ----
SLASH_IWIN1 = "/iwin"
function SlashCmdList.IWIN(command)
	if not command then return end
	local arguments = {}
	for token in string.gfind(command, "%S+") do
		table.insert(arguments, token)
	end
	if arguments[1] == "frontshred" then
		if arguments[2] ~= "on"
			and arguments[2] ~= "off"
			and arguments[2] ~= nil then
				DEFAULT_CHAT_FRAME:AddMessage("Unkown parameter. Possible values: on, off.")
				return
		end
	end
    if arguments[1] == "frontshred" then
        IWin_Druid["frontShred"] = arguments[2]
	    DEFAULT_CHAT_FRAME:AddMessage("Front Shred: " .. IWin_Druid["frontShred"])
	else
		DEFAULT_CHAT_FRAME:AddMessage("Usage:")
		DEFAULT_CHAT_FRAME:AddMessage(" /iwin : Current setup")
		DEFAULT_CHAT_FRAME:AddMessage(" /iwin frontshred [" .. IWin_Druid["frontShred"] .. "] : Setup for Front Shredding")
    end
end

---- iblast button ----
SLASH_IBLAST1 = '/iblast'
function SlashCmdList.IBLAST()
	IWin_CombatVar["reservedRage"] = 0
	IWin_CombatVar["queue"] = true
	IWin:TargetEnemy()
	IWin:StartAttack()
	IWin:MarkOfTheWild()
	IWin:Thorns()
	IWin:WrathOOC()
	IWin:Moonfire()
	IWin:Wrath()
end

---- istorm button ----
SLASH_ISTORM1 = '/istorm'
function SlashCmdList.ISTORM()
	IWin_CombatVar["reservedRage"] = 0
	IWin:TargetEnemy()
	IWin:StartAttack()
end

---- iruetoo button ----
SLASH_IRUETOO1 = '/iruetoo'
function SlashCmdList.IRUETOO()
	IWin_CombatVar["reservedEnergy"] = 0
	IWin_CombatVar["queue"] = true
	IWin:TargetEnemy()
	IWin:MarkOfTheWild()
	IWin:Thorns()
	IWin:CancelRoot()
	IWin:CatForm()
	IWin:TigersFury()
	IWin:SetReservedEnergyTigersFury()
	IWin:FaerieFireFeral()
	IWin:Rip()
	IWin:FerociousBite()
	IWin:SetReservedEnergyRip()
	IWin:Rake()
	IWin:SetReservedEnergyRake()
	IWin:Shred()
	IWin:SetReservedEnergyShred()
	IWin:Claw()
	IWin:SetReservedEnergy("Claw", "nocooldown")
	IWin:StartAttack()
end

---- isacat button ----
SLASH_ISACAT1 = '/isacat'
function SlashCmdList.ISACAT()
	IWin_CombatVar["reservedEnergy"] = 0
	IWin_CombatVar["queue"] = true
	IWin:TargetEnemy()

	IWin:StartAttack()
end

---- itank button ----
SLASH_ITANK1 = '/itank'
function SlashCmdList.ITANK()
	IWin_CombatVar["reservedRage"] = 0
	IWin_CombatVar["queue"] = true
	IWin:TargetEnemy()
	IWin:MarkSkull()
	IWin:MarkOfTheWild()
	IWin:Thorns()
	IWin:CancelRoot()
	IWin:BearForm()
	IWin:FaerieFireFeral()
	IWin:DemoralizingRoar()
	IWin:SetReservedRage("Demoralizing Roar", "debuff", "target")
	IWin:Enrage()
	IWin:Swipe()
	IWin:SetReservedRage("Swipe", "nocooldown")
	IWin:Maul()
	IWin:StartAttack()
end

---- ihodor button ----
SLASH_IHODOR1 = '/ihodor'
function SlashCmdList.IHODOR()
	IWin_CombatVar["reservedRage"] = 0
	IWin_CombatVar["queue"] = true
	IWin:TargetEnemy()
	IWin:MarkSkull()
	IWin:MarkOfTheWild()
	IWin:Thorns()
	IWin:BearForm()
	IWin:DemoralizingRoar()
	IWin:SetReservedRage("Demoralizing Roar", "debuff", "target")
	IWin:Swipe()
	IWin:SetReservedRage("Swipe", "nocooldown")
	IWin:FaerieFireFeral()
	IWin:Maul()
	IWin:StartAttack()
end

---- ichase button ----
SLASH_ICHASE1 = '/ichase'
function SlashCmdList.ICHASE()
	IWin:TargetEnemy()
	IWin:Charge()
	IWin:Intercept()
	IWin:Hamstring()
	IWin:StartAttack()
end

---- itaunt button ----
SLASH_ITAUNT1 = '/itaunt'
function SlashCmdList.ITAUNT()
	IWin:TargetEnemy()
	IWin:Growl()
	IWin:StartAttack()
end