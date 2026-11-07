-- The quest-mob key (experimental): a key that targets the next mob your highlighted quest needs, through a secure button.
local _, ns = ...
local SKULL = ns.SKULL
local DB, trace = ns.DB, ns.trace

local function singular(s)
	s = s:lower()
	s = s:gsub("ves$", "f")
	s = s:gsub("ies$", "y")
	s = s:gsub("s$", "")
	return s
end

local function objectiveName(text)
	local n = text:gsub("^%s*%-?%s*", "")
	n = n:gsub("^%d+/%d+%s*", "")
	n = n:gsub(":%s*%d+/%d+%s*$", "")
	n = n:gsub("%s+slain%s*$", "")
	return n
end

local function highlightedQuestID()
	local id
	if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
		id = C_SuperTrack.GetSuperTrackedQuestID()
	elseif GetSuperTrackedQuestID then
		id = GetSuperTrackedQuestID()
	end
	if id and id ~= 0 then return id end
end

-- Adds the open objectives of one quest to names (kill objectives) and needles (everything else, matched
-- against the mob's tooltip). Returns how many open objectives the quest has.
local function collectNames(names, needles, questID)
	local open = 0
	for _, o in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
		if not o.finished and o.text then
			open = open + 1
			local n = objectiveName(o.text)
			if o.type == "monster" then
				names[singular(n)] = n
			elseif n ~= "" then
				needles[#needles + 1] = n
			end
		end
	end
	return open
end

local function questNames(questID)
	local names, needles = {}, {}
	if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return names, needles end
	if questID then
		collectNames(names, needles, questID)
		local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
		if title and title ~= "" then needles[#needles + 1] = title end
	elseif C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
		-- No quest highlighted: every quest with open objectives, checked the same way as a highlighted one.
		for i = 1, C_QuestLog.GetNumQuestLogEntries() do
			local info = C_QuestLog.GetInfo(i)
			if info and not info.isHeader and info.questID and collectNames(names, needles, info.questID) > 0 then
				local title = info.title
				if (not title or title == "") and C_QuestLog.GetTitleForQuestID then
					title = C_QuestLog.GetTitleForQuestID(info.questID)
				end
				if title and title ~= "" then needles[#needles + 1] = title end
			end
		end
	end
	return names, needles
end

-- Returns found, the needle that matched and the tooltip line it matched in (the last two are for /qhud debug).
local function tooltipMentions(unit, needles)
	local ok, found, needle, line = pcall(function()
		local data = C_TooltipInfo.GetUnit(unit)
		if not data or not data.lines then return false end
		for _, l in ipairs(data.lines) do
			local text = l.leftText
			if type(text) == "string" then
				for _, n in ipairs(needles) do
					if text:find(n, 1, true) then return true, n, text end
				end
			end
		end
		return false
	end)
	return ok and found, needle, line
end

-- Returns whether the unit is a quest mob, and why (used by /qhud debug).
local function isQuestUnit(unit, names, needles)
	local n = UnitName(unit)
	if n and names[singular(n)] then return true, "its name is a kill objective" end
	if C_TooltipInfo and C_TooltipInfo.GetUnit then
		if #needles == 0 then return false end
		local found, needle, line = tooltipMentions(unit, needles)
		if found then return true, 'tooltip line "' .. tostring(line) .. '" contains "' .. tostring(needle) .. '"' end
		return false
	end
	-- Only clients without the tooltip API fall back to the game's looser "related to a quest" flag.
	if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
		local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
		return ok and related and true or false, "the game flags it as related to a quest"
	end
	return false
end

-- Quest-mob targeting. Addons cannot change the target themselves, and the game lets only one targeting change take
-- effect per key press, so a chain of Tabs cannot skip the mobs that are not quest mobs. Instead the addon looks at the
-- enemy nameplates just before the press, works out which quest mob comes next after the one you have (nearest first,
-- then round again, like Tab) and has the key target it by name with the skull. Targeting a nameplate directly was tried
-- and the game does not allow it here (the target ended up on the player), so identical mobs cannot be told apart: a name
-- always goes to the nearest one, and the key steps between different kinds of quest mob, skipping the identical ones. When no
-- quest mob is on a nameplate, because it is too far for one, a kill objective is still targeted by name, which reaches as
-- far as /target does.
local run = { active = false, names = {}, needles = {}, plan = nil }

-- The quest mobs among the visible enemy nameplates, nearest first. Returns nil when there are no nameplates at
-- all (for example when enemy nameplates are turned off).
local function questMobsOnScreen(names, needles)
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return nil end
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	if not ok or type(plates) ~= "table" or #plates == 0 then return nil end
	local list = {}
	local others = 0 -- attackable, living enemies on nameplates that are not quest mobs
	for _, plate in ipairs(plates) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit then
			local okUnit, mob, why = pcall(function()
				if not UnitCanAttack("player", unit) or UnitIsDead(unit) then return false end
				if UnitIsTapDenied and UnitIsTapDenied(unit) then return false end
				return isQuestUnit(unit, names, needles)
			end)
			if ns.debugOn then
				pcall(function()
					trace(string.format("  plate %s: attackable=%s dead=%s tapped=%s -> quest=%s%s", tostring(UnitName(unit)),
						tostring(UnitCanAttack("player", unit)), tostring(UnitIsDead(unit)),
						tostring(UnitIsTapDenied and UnitIsTapDenied(unit)), tostring(okUnit and mob),
						(okUnit and mob and why) and (", because " .. why) or ""))
				end)
			end
			if not (okUnit and mob) then
				local okA, attackable = pcall(function() return UnitCanAttack("player", unit) and not UnitIsDead(unit) end)
				if okA and attackable then others = others + 1 end
			end
			if okUnit and mob then
				local dist
				if UnitDistanceSquared then
					local okDist, d = pcall(UnitDistanceSquared, unit)
					if okDist and type(d) == "number" and not (issecretvalue and issecretvalue(d)) then dist = d end
				end
				local name = UnitName(unit)
				if name and not (issecretvalue and issecretvalue(name)) then
					list[#list + 1] = { name = name, dist = dist, unit = unit, order = #list + 1 }
				end
			end
		end
	end
	table.sort(list, function(a, b)
		local da, db = a.dist or math.huge, b.dist or math.huge
		if da ~= db then return da < db end
		return a.order < b.order
	end)
	return list, others
end

-- The next quest mob after the one you have targeted (nearest first, then round again), or the nearest one when your
-- target is not one of them. Because the key targets by name, a mob with the same name as the current target is skipped
-- (the name would just give the same one again); when every quest mob has that name, the nearest one is used.
local function chooseNextMob(list)
	for i, mob in ipairs(list) do
		local okSame, same = pcall(UnitIsUnit, "target", mob.unit)
		if okSame and same then
			for offset = 1, #list - 1 do
				local candidate = list[(i - 1 + offset) % #list + 1]
				if candidate.name ~= mob.name then return candidate, "the next kind of quest mob" end
			end
			return list[1], "the nearest quest mob"
		end
	end
	return list[1], "the nearest quest mob"
end

local targetButton = CreateFrame("Button", "QuietHUDTargetButton", UIParent, "SecureActionButtonTemplate")

-- The game locks addon changes to secure buttons during combat, so in combat the key can only do what it was set up to do
-- beforehand. Out of combat every press replaces the button's action with the quest mob it picks. For combat the button
-- is left holding a macro that targets the nearest quest mob kind by name, worked out while you were still out of combat
-- (see run.prepare below). Without a quest mob to name, it is a plain Tab plus the skull. (A secure snippet that could
-- cycle a whole list in combat does not work in this client: the game cannot compile snippet text here.) The button itself
-- is set up here too, so QuietHUD loaded in a fight (a /reload) sets it up when the fight ends.
local COMBAT_MACRO = "/targetenemy\n/tm 0\n/tm " .. SKULL
ns.armEntry = function()
	if InCombatLockdown() then return end
	targetButton:RegisterForClicks("AnyDown", "AnyUp")
	targetButton:SetAttribute("type", "macro")
	targetButton:SetAttribute("unit", nil)
	targetButton:SetAttribute("macrotext", DB.questTarget and (run.combatMacro or COMBAT_MACRO) or "")
end
ns.armEntry()

-- Which quest the key works from, and the name it uses in combat, kept current out of combat.
do
	-- The quest the key is working from: the one you picked, unless it is complete or gone from the log.
	run.current = function()
		local trackedID = highlightedQuestID()
		local questID = run.pinned or trackedID
		if run.pinned then
			local okLog, gone = pcall(function()
				if C_QuestLog.GetLogIndexForQuestID and not C_QuestLog.GetLogIndexForQuestID(run.pinned) then return true end
				if C_QuestLog.IsComplete and C_QuestLog.IsComplete(run.pinned) then return true end
				return false
			end)
			if okLog and gone then
				run.pinned = nil
				questID = trackedID
			end
		end
		local ok, names, needles = pcall(questNames, questID)
		return questID, trackedID, names, needles, ok
	end

	-- The quest key does not chat about what a press did (that is only shown in debug mode). The few messages that explain why a
	-- press did nothing go through here, at most one every 3 seconds, so pressing the key over and over does not fill the chat.
	run.say = function(text)
		local now = GetTime()
		if run.lastSay and now - run.lastSay < 3 then return end
		run.lastSay = now
		print(text)
	end

	-- Picks the name the key will use in combat: the nearest quest mob on the nameplates, else the first kill objective.
	-- Only possible out of combat, and it does not touch the button (armEntry does that).
	run.prepare = function(mobs, names, others)
		if InCombatLockdown() then return end
		-- When every enemy around is a quest mob, the game's own Tab is quest-only, and it steps through identical mobs too.
		run.combatTab = (mobs and #mobs >= 2 and (others or 1) == 0) and true or false
		local name = mobs and mobs[1] and mobs[1].name
		if not name then
			local kills = {}
			for _, n in pairs(names or {}) do
				if type(n) == "string" then kills[#kills + 1] = n end
			end
			table.sort(kills)
			name = kills[1]
		end
		local label = run.combatTab and "a plain Tab, every enemy nearby is a quest mob"
			or (name and (name .. " by name")) or "a plain Tab, no quest mob is known"
		if label ~= run.combatLabel then
			run.combatLabel = label
			trace("QuietHUD: in combat the key will be " .. label)
		end
		run.combatName = (not run.combatTab) and name or nil
		run.combatMacro = (name and not run.combatTab) and ("/targetexact " .. name .. "\n/tm 0\n/tm " .. SKULL) or nil
	end

	-- Keep that current while you are out of combat.
	local pending = false
	local function refresh()
		pending = false
		if not DB.questTarget or InCombatLockdown() then return end
		local _, _, names, needles, ok = run.current()
		if not ok then return end
		local okMobs, mobs, others = pcall(questMobsOnScreen, names, needles)
		run.prepare(okMobs and mobs or nil, names, others)
		ns.armEntry()
	end
	local function schedule()
		if pending or not (C_Timer and C_Timer.After) then return end
		pending = true
		C_Timer.After(0.5, refresh)
	end
	local armFrame = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
		"QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "SUPER_TRACKING_CHANGED", "PLAYER_REGEN_ENABLED" }) do
		pcall(armFrame.RegisterEvent, armFrame, e)
	end
	armFrame:SetScript("OnEvent", schedule)
end
local function isActionClick(down)
	local useDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and true or false
	return (down and true or false) == useDown
end

targetButton:SetScript("PreClick", function(self, _, down)
	if not isActionClick(down) then return end
	run.plan = nil
	if not DB.questTarget then
		run.say("QuietHUD: quest targeting is off. Turn it on in /qhud, Extras.")
		return
	end
	if InCombatLockdown() then
		if not run.combatWarned then
			run.combatWarned = true
			if run.combatName then
				trace("QuietHUD: in combat the key targets " .. run.combatName .. " by name, picked before the fight, because the game locks addon changes in combat")
			elseif run.combatTab then
				trace("QuietHUD: in combat the key is a plain Tab, because every enemy near you was a quest mob before the fight and the game locks addon changes in combat")
			else
				trace("QuietHUD: in combat the key works as a plain Tab, because the game locks addon changes in combat and no quest mob was known before the fight")
			end
		end
		return
	end
	local questID, trackedID, names, needles, ok = run.current()
	if not ok then
		self:SetAttribute("macrotext", "")
		run.say("QuietHUD: could not read your quests just now")
		return
	end
	run.names, run.needles = names, needles
	-- Say which quest this press is working from, so it is clear when no quest is tracked and every quest in the log is used.
	local forText = "all your quests, because none is tracked"
	if questID then
		local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
		forText = (title and title ~= "") and title or ("quest " .. tostring(questID))
		if trackedID and trackedID ~= questID then forText = forText .. " (the game is tracking another quest, the key stays on this one)" end
	end
	if ns.debugOn then
		local kills = {}
		for _, n in pairs(names) do kills[#kills + 1] = tostring(n) end
		trace("QuietHUD: --- key press. start target=" .. tostring(UnitName("target")))
		trace("QuietHUD: tracked quest id " .. tostring(trackedID) .. ", using quest id " .. tostring(questID) .. ", kill names: [" .. table.concat(kills, ", ")
			.. "], tooltip needles: [" .. table.concat(needles, ", ") .. "]")
	end
	local mobs, others = questMobsOnScreen(names, needles)
	run.prepare(mobs, names, others)
	if mobs and #mobs > 0 then
		if #mobs >= 2 and others == 0 then
			-- Every enemy on a nameplate is a quest mob, so the game's own Tab only goes to quest mobs, and unlike a name it
			-- steps through identical ones.
			run.plan = "by Tab, every enemy nearby is a quest mob, for " .. forText
			self:SetAttribute("macrotext", COMBAT_MACRO)
			trace("QuietHUD: " .. #mobs .. " quest mobs and no other enemy on the nameplates, so this press is a plain Tab")
			return
		end
		local mob, why = chooseNextMob(mobs)
		run.plan = why .. " for " .. forText .. ", by name"
		local text = "/targetexact " .. mob.name .. "\n/tm 0\n/tm " .. SKULL
		trace("QuietHUD: " .. #mobs .. " quest mob(s) on the nameplates, going to " .. why .. " by name: " .. text:gsub("\n", " | "))
		self:SetAttribute("macrotext", text)
		return
	end
	-- Nothing on a nameplate (none at all, or none of them a quest mob): a kill objective can still be targeted by name,
	-- which reaches as far as /target does. With several kill objectives each press takes the next one.
	local kills = {}
	for _, n in pairs(names) do
		if type(n) == "string" then kills[#kills + 1] = n end
	end
	table.sort(kills)
	if #kills > 0 then
		run.rotor = (run.rotor or 0) % #kills + 1
		local name = kills[run.rotor]
		run.plan = "by name, nothing is on a nameplate, for " .. forText
		local text = "/targetexact " .. name .. "\n/tm 0\n/tm " .. SKULL
		trace("QuietHUD: no quest mob on the nameplates, trying " .. name .. " by name: " .. text:gsub("\n", " | "))
		self:SetAttribute("macrotext", text)
		return
	end
	self:SetAttribute("macrotext", "")
	if not mobs then
		if not run.plateWarned then
			run.plateWarned = true
			run.say("QuietHUD quest key: no enemy nameplates to look at. Turn on enemy nameplates so the key can find quest mobs (shown once per session, or untick the quest key in /qhud, Extras).")
		end
		trace("QuietHUD: there are no nameplates, so nothing was pressed")
	else
		run.say("QuietHUD: no quest mob found among the nearby enemies")
		trace("QuietHUD: no quest mob on the nameplates, so nothing was pressed")
	end
end)

targetButton:SetScript("PostClick", function(_, _, down)
	if not InCombatLockdown() then ns.armEntry() end
	if not isActionClick(down) then return end
	if run.plan then
		local name = UnitName("target")
		if name and not (issecretvalue and issecretvalue(name)) then
			trace("QuietHUD: " .. name .. " (" .. run.plan .. ")")
		end
		run.plan = nil
	end
end)

-- For the files after this one (QuietHUD.toc).
ns.highlightedQuestID, ns.run = highlightedQuestID, run
