local Flump = CreateFrame("frame")

local OUTPUT = "RAID"			-- Which channel should the announcements be sent to?
local MIN_TANK_HP = 55000		-- How much health must a player have to be considered a tank?
local MIN_HEALER_MANA = 20000	-- How much mana must a player have to be considered a healer?
local DIVINE_PLEA = true		-- Announce when (holy) Paladins cast Divine Plea? (-50% healing)

local status = "|cff39d7e5Flump: %s|r"

local bot	 = "%s used a %s!"
local used	 = "%s used %s!"
local sw	 = "%s faded from %s!"
local cast	 = "%s cast %s on %s!"
local fade	 = "%s's %s faded from %s!"
local feast  = "%s prepares a %s!"
local gs	 = "%s's %s consumed: %s heal!"
local ad	 = "%s%s's %s consumed!"
local res	 = "%s's %s resurrected %s!"
local portal = "%s opened a %s!"
local create = "%s is creating a %s!"
local dispel = "%s's %s failed to dispel %s's %s!"
local ss	 = "%s died with a %s!"

local on = "|cff00ff00On|r"
local off = "|cffff0000Off|r"

local sacrifice  = {}
local soulstones = {}
local ad_heal	 = false

local HEROISM	= UnitFactionGroup("player") == "Horde" and 2825 or 32182	-- Horde = "Bloodlust" / Alliance = "Heroism"
local REBIRTH 	= GetSpellInfo(20484)										-- "Rebirth"
local HOP 		= GetSpellInfo(1022)										-- "Hand of Protection"
local SOULSTONE = GetSpellInfo(20707)										-- "Soulstone Resurrection"
local CABLES	= GetSpellInfo(54732)										-- "Defibrillate

-- Upvalues
local UnitInRaid, UnitAffectingCombat = UnitInRaid, UnitAffectingCombat
local UnitHealthMax, UnitManaMax = UnitHealthMax, UnitManaMax
local GetSpellLink, UnitAffectingCombat, format = GetSpellLink, UnitAffectingCombat, string.format

-- http://www.wowhead.com/?search=portal#abilities
local port = {
	-- Mage
	[53142] = true, -- Portal: Dalaran        (Alliance/Horde)
	[11419] = true, -- Portal: Darnassus      (Alliance)
	[32266] = true, -- Portal: Exodar         (Alliance)
	[11416] = true, -- Portal: Ironforge      (Alliance)
	[11417] = true, -- Portal: Orgrimmar      (Horde)
	[33691] = true, -- Portal: Shattrath      (Alliance)
	[35717] = true, -- Portal: Shattrath      (Horde)
	[32267] = true, -- Portal: Silvermoon     (Horde)
	[49361] = true, -- Portal: Stonard        (Horde)
	[10059] = true, -- Portal: Stormwind      (Alliance)
	[49360] = true, -- Portal: Theramore      (Alliance)
	[11420] = true, -- Portal: Thunder Bluff  (Horde)
	[11418] = true, -- Portal: Undercity      (Horde)
}

local rituals = {
	-- Mage
	[58659] = true, -- Ritual of Refreshment
	-- Warlock
	[58887] = true, -- Ritual of Souls
	[698]	= true,	-- Ritual of Summoning
}

local spells = {
	-- Paladin
	[48788] = true, -- Lay on Hands
	[6940] = true,	-- Длань жертвенности
	[1044] = true,	-- Длань свободы
	[1038] = true,	-- Длань спасения
	[19752] = true,	-- Божественное вмешательство
	-- Priest
	[47788] = true, -- Guardian Spirit
	[33206] = true, -- Pain Suppression
	[10060] = true,	-- Придание сил
	--Druid
	[29166] = true, -- Озарение
	--DK
	[49016] = true, -- Истерия
	--Hunter
	[20736] = true, -- Отвлекающий выстрел
	[19801] = true, -- Усмиряющий выстрел
	[34477] = true, -- Перенаправление
	--Rogue
	[57934] = true, -- Маленькие хитрости
}

local bots = {
	-- Engineering
	[22700] = true,	-- Field Repair Bot 74A
	[44389] = true,	-- Field Repair Bot 110G
	[67826] = true,	-- Jeeves
	[54710] = true,	-- MOLL-E
	[54711] = true,	-- Scrapbot
}

local use = {
	-- Death Knight
	[48707] = true,	-- Anti-Magic Shell
	[48792] = true,	-- Icebound Fortitude
	[55233] = true,	-- Vampiric Blood
	-- Druid
	[22812] = true,	-- Barkskin
	[22842] = true,	-- Frenzied Regeneration
	[61336] = true,	-- Survival Instincts
	-- Warrior
	[12975] = true,	-- Last Stand [Gain]
	[871] 	= true,	-- Shield Wall
	-- Paladin
	[498] 	= true, -- Divine Protection
	[642]	= true, -- Бабл
	-- Mage
	[45438] = true,	-- Ледяная глыба
}

local misc = {
	[42650] = true, -- Войско мертвых
	[48447] = true, -- Спокойствие
}

local bonus = {
	-- Death Knight
	[70654] = true, -- Blood Armor [4P T10]
	-- Druid
	[70725] = true, -- Enraged Defense [4P T10]

}

local trinkets = {
	-- Trinkets
	[71638] = 50364, -- Sindragosa's claw Heroic
	[71635] = 50361, -- Sindragosa's claw
	[71586] = 50356, -- Key
	[75495] = 54589, -- Хиловская чешка гер
	[75490] = 54573, -- Хиловская чешка
	[67699] = UnitFactionGroup("player") == "Horde" and 47290 or 47080, -- Жизненная сила владыки мира
	[67753] = UnitFactionGroup("player") == "Horde" and 47451 or 47088, -- Жизненная сила владыки мира Her.
	}

local feasts = {
	[57426] = true, -- Fish Feast
	[57301] = true, -- Great Feast
	[66476] = true, -- Bountiful Feast
}

local special = {
	-- Paladin
	[31821] = true, -- Aura Mastery
	-- Priest
	[64843] = true, -- Divine Hymn
	[64901] = true, -- Гимн надежды
}

local toys = {
	[61031] = true, -- Toy Train Set
}

local fails = {
	-- The Lich King
	["Necrotic Plague"] = true,
	-- Shambling Horror
	["Enrage"] = "Shambling Horror",
}

Flump:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

local function send(msg)
	SendChatMessage(msg, OUTPUT)
end

local function icon(name)
	local n = GetRaidTargetIndex(name)
	return n and format("{rt%d}", n) or ""
end

function Flump:COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, srcGUID, srcName, srcFlags, destGUID, destName, destFlags, spellID, spellName, school, ...)

	-- [X] died with a Soulstone!
	if UnitInRaid(destName) then -- If the target isn't in the raid group
		if spellName == SOULSTONE and event == "SPELL_AURA_REMOVED" then
			if not soulstones[destName] then soulstones[destName] = {} end
			soulstones[destName].time = GetTime()
		elseif spellID == 27827 and event == "SPELL_AURA_APPLIED" then
			soulstones[destName] = {}
			soulstones[destName].SoR = true -- Workaround for Spirit of Redemption issue
		elseif event == "UNIT_DIED" and soulstones[destName] and not UnitIsFeignDeath(destName) then
			if not soulstones[destName].SoR and (GetTime() - soulstones[destName].time) < 2 then
				send(ss:format(destName, GetSpellLink(6203)))
				SendChatMessage(ss:format(destName, GetSpellLink(6203)), "RAID_WARNING")
			end
			soulstones[destName] = nil
		end
	end

	if not UnitInRaid(srcName) then return end -- If the caster isn't in the raid group

	if UnitAffectingCombat(srcName) then -- If the caster is in combat
	
		if event == "SPELL_CAST_SUCCESS" then
			if spells[spellID] then
				send(cast:format(icon(srcName), srcName, GetSpellLink(spellID), icon(destName), destName)) -- [X] cast [Y] on [Z]
			elseif spellID == 19752 then -- Don't want to announce when it fades, so
				send(cast:format(icon(srcName), srcName, GetSpellLink(spellID), icon(destName), destName)) -- Divine Intervention
			elseif use[spellID] then
				send(used:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] used [Y]
			elseif misc[spellID] then
				send(used:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] used [Y]
			elseif spellID == 64205 then  -- Workaround for Divine Sacrifice issue
				send(used:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] used Divine Sacrifice
				sacrifice[srcGUID] = true
			elseif special[spellID] then -- Workaround for spells which aren't tanking spells
				send(used:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] used Aura Mastery
			elseif DIVINE_PLEA and spellID == 54428 then
				send(used:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] used Divine Plea
			end
			
		elseif event == "SPELL_AURA_APPLIED" then -- [X] cast [Y] on [Z]
			if spellID == 20233 or spellID == 20236 then -- Improved Lay on Hands (Rank 1/Rank 2)
				send(cast:format(icon(srcName), srcName, GetSpellLink(spellID), icon(destName), destName))
			elseif bonus[spellID] then
				send(used:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] used [Z] (bonus)
			elseif spellID == 66233 then
				if not ad_heal then -- If the Ardent Defender heal message hasn't been sent already
					send(ad:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X]'s [Y] consumed
				end
				ad_heal = false
			elseif spellName == HOP then
				send(cast:format(icon(srcName), srcName, GetSpellLink(spellID), icon(destName), destName)) -- [X] cast Hand of Protection on [Z]
			elseif trinkets[spellID] then
				send(used:format(icon(srcName), srcName, select(2, GetItemInfo(trinkets[spellID])))) -- [X] used [Y]
			end
		
		elseif event == "SPELL_HEAL" then
			if spellID == 48153 or spellID == 66235 then -- Guardian Spirit / Ardent Defender
				local amount = ...
				ad_heal = true
				send(gs:format(icon(srcName), srcName, GetSpellLink(spellID), amount)) -- [X]'s [Y] consumed: [Z] heal
			end
		end
		
		elseif event == "SPELL_AURA_REMOVED" then
			if spells[spellID] or (spellName == HOP and UnitHealthMax(destName) >= MIN_TANK_HP) then
				send(fade:format(icon(srcName), srcName, GetSpellLink(spellID), icon(destName), destName)) -- [X]'s [Y] faded from [Z]
			elseif use[spellID] and UnitHealthMax(srcName) >= MIN_TANK_HP then
				send(sw:format(GetSpellLink(spellID), icon(srcName), srcName)) -- [X] faded from [Y]
			elseif bonus[spellID] then
				send(sw:format(GetSpellLink(spellID), icon(srcName), srcName)) -- [X] faded from [Y] (bonus)
			elseif spellID == 64205 and sacrifice[destGUID] then
				send(sw:format(GetSpellLink(spellID), icon(srcName), srcName)) -- Divine Sacrifice faded from [Y]
				sacrifice[destGUID] = nil
			elseif special[spellID] then -- Workaround for spells which aren't tanking spells
				send(sw:format(GetSpellLink(spellID), icon(srcName), srcName)) -- Aura Mastery faded from [X]
			elseif DIVINE_PLEA and spellID == 54428 and UnitManaMax(srcName) >= MIN_HEALER_MANA then
				send(sw:format(GetSpellLink(spellID), icon(srcName), srcName)) -- Divine Plea faded from [X]
			end
		end
	end
	
	if event == "SPELL_CAST_SUCCESS" then
		if spellID == HEROISM then
			send(used:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] used [Y] -- Heroism/Bloodlust
		elseif bots[spellID] then 
			send(bot:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] used a [Y] -- Bots
		elseif rituals[spellID] then
			send(create:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] is creating a [Z] -- Rituals
		end
		
	elseif event == "SPELL_AURA_APPLIED" then -- Check name instead of ID to save checking all ranks
		if spellName == SOULSTONE then
			local _, class = UnitClass(srcName)
			if class == "WARLOCK" then -- Workaround for Spirit of Redemption issue
				send(cast:format(icon(srcName), srcName, GetSpellLink(6203), icon(destName), destName)) -- [X] cast [Y] on [Z] -- Soulstone
			end
		end
		
	elseif event == "SPELL_CREATE" then
		if port[spellID] then
			send(portal:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] opened a [Z] -- Portals
		elseif toys[spellID] then
			send(bot:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] used a [Z]
		end
		
	elseif event == "SPELL_CAST_START" then
		if feasts[spellID] then
			send(feast:format(icon(srcName), srcName, GetSpellLink(spellID))) -- [X] prepares a [Z] -- Feasts
		end
		
	elseif event == "SPELL_RESURRECT" then
		if spellName == REBIRTH then -- Check name instead of ID to save checking all ranks
			send(cast:format(icon(srcName), srcName, GetSpellLink(spellID), icon(destName), destName)) -- [X] cast [Y] on [Z] -- Rebirth
		elseif spellName == CABLES then
			send(res:format(icon(srcName), srcName, GetSpellLink(spellID), icon(destName), destName))
		end	
		
	elseif event == "SPELL_DISPEL_FAILED" then
		local extraID, extraName = ...
		local target = fails[extraName]
		if target or destName == target then
			send(dispel:format(icon(srcName), srcName, GetSpellLink(spellID), icon(destName), destName, GetSpellLink(extraID))) -- [W]'s [X] failed to dispel [Y]'s [Z]
		end
	end
	
end

function Flump:PLAYER_ENTERING_WORLD()
	local _, instance = IsInInstance()
	if instance == "raid" and self.db.enabled then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

function Flump:ADDON_LOADED(addon)
	if addon ~= "Flump" then return end
	FlumpDB = FlumpDB or { enabled = true }
	self.db = FlumpDB
	SLASH_FLUMP1 = "/flump"
	SlashCmdList.FLUMP = function()
		if self.db.enabled then
			self.db.enabled = false
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			print(status:format(off))
		else
			self.db.enabled = true
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			print(status:format(on))
		end
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

Flump:RegisterEvent("ADDON_LOADED")

if GetLocale() == "ruRU" then
	bot	 = "%s%s ставит %s!"
	used = "%s%s использует %s!"
	sw	 = "%s заканчивается на %s%s!"
	cast = "%s%s применяет %s на %s%s!"
	fade = "На %s%s заканчивается %s от %s%s!"
	feast  = "%s%s готовит %s!"
	gs	 = "%s%s's %s прокнул: %d отлечено!"
--	ad	 = "%s%s's %s consumed!"
	res	 = "%s%s применяет %s на %s%s!"
	portal = "%s%s открыл(а) %s!"
	create = "%s%s создал(а) %s!"
--	dispel = "%s%s's %s failed to dispel %s%s's %s!"
	ss = "%s умер с %s!"
	on = "|cff00ff00Включен|r"
	off = "|cffff0000Отключен|r"
end