-- The action bars: which bars fade (the Action bars page), buttons another addon moved out of their bar, and the shorter or
-- hidden hotkey text.
local _, ns = ...
local BAR_DEFS, EXTRA_BUTTONS = ns.BAR_DEFS, ns.EXTRA_BUTTONS
local DB, LISTS, elsewhere, woc, rebuildLists = ns.DB, ns.LISTS, ns.elsewhere, ns.woc, ns.rebuildLists
local applyList, barBit = ns.applyList, ns.barBit

local barExcluded = {} -- per bar: true once it was put back to full because it is not picked on the Action bars page

-- The buttons of one bar, by their name prefix and count. (A button that is also in a list other than the bars,
-- /qhud add hidden ActionButton1, belongs to that list.)
local function applyButtons(prefix, count, a)
	for j = 1, count do
		local name = prefix .. j
		local b = _G[name]
		local owner = woc.owner[name]
		if b and b.SetAlpha and (owner == nil or owner == "bars" or owner:find("^bar%d")) then woc.write(b, a) end
	end
end

-- A bar's opacity reaches its buttons through the frame tree, unless another addon has moved them out of the bar (see
-- checkElsewhere): those are faded by name, along with the bar.
local function applyBars(a, respectMask)
	applyList("bars", a)
	for k, set in ipairs(EXTRA_BUTTONS) do
		if elsewhere.extra[k] then applyButtons(set[1], set[2], a) end
	end
	for i = 1, #BAR_DEFS do
		if respectMask and woc.mouseBar(i) then
			barExcluded[i] = false -- (fades by itself, woc.mouseBars)
		elseif (not respectMask) or barBit(DB.barFade, i) then
			-- (Low health or Low mana column: the game's opacity from them goes over this bar's writes, see below)
			local kind = woc.lowGroupA == a and respectMask and woc.lowKind(i)
			local low = kind and woc.lowAlphaFor(kind, a, woc.barsPeak)
			if low then woc.lowAlpha, woc.lowFor = low, a end
			applyList("bar" .. i, a)
			if elsewhere.bars[i] then applyButtons(BAR_DEFS[i].buttons, 12, a) end
			if low then woc.lowAlpha, woc.lowFor = nil, nil end
			barExcluded[i] = false
		elseif not barExcluded[i] then
			applyList("bar" .. i, 1)
			if elsewhere.bars[i] then applyButtons(BAR_DEFS[i].buttons, 12, 1) end
			barExcluded[i] = true
		end
	end
end

-- The Action bars page's Mouse over column (the owner, 2026-11-05: "a seperate tick boxes in action bars for mouse over on
-- each bar"). A ticked bar, with its Fade ticked and Action bars fading on the Elements page, leaves the group: it fades by
-- itself and comes up only while the mouse is on it (its frames, or its buttons when another addon moved them out), never
-- for a fight, a target or the weapon. Mouse over on it does not wake the other bars either (woc.groupHover). In Edit Mode,
-- with QuietHUD off or Action bars not fading, it is back in the group. Cost: see woc.moStep (Triggers.lua).
-- Which bars fade by themselves, worked out at the start of each update, before the group is written (audit F1: worked
-- out after it, a bar could be skipped by the group with nobody writing it). A change rewrites every group (woc.forget).
woc.mouseMembership = function(on)
	local mask = 0
	if on and DB.fadeBars and (DB.barMouse or 0) > 0 then
		for i = 1, #BAR_DEFS do
			if barBit(DB.barMouse, i) and barBit(DB.barFade, i) then mask = mask + 2 ^ (i - 1) end
		end
	end
	if mask ~= (woc.mbMask or 0) then
		woc.mbMask = mask
		woc.forget()
	end
end
woc.mouseBar = function(i)
	return barBit(woc.mbMask or 0, i)
end
-- gone: Hide in combat is ticked on Action bars and you are in a fight. Then a Mouse over bar is gone too, hovered or not, at
-- 0 whatever the Faded opacity (audit 2026-11-06 pre-1.6.0 F1); showing the whole HUD on demand (all) still wins.
woc.mouseBars = function(dt, all, gone)
	local busy = false
	for i = 1, #BAR_DEFS do
		if woc.mouseBar(i) then
			local over = all
			if not over then
				local names = LISTS["bar" .. i] or {}
				for j = 1, #names do
					if ns.hovered(_G[names[j]]) then over = true break end
				end
			end
			if not over and elsewhere.bars[i] then
				for j = 1, 12 do
					if ns.hovered(_G[BAR_DEFS[i].buttons .. j]) then over = true break end
				end
			end
			if gone and not all then over = false end
			local target = over and 1 or 0
			local c = woc.moStep(woc.mbCur[i] or 0, target, dt)
			if c ~= target then busy = true end
			woc.mbCur[i] = c
			local ov = DB.ovBars
			local peak = (ov and ov > 0) and math.max(ov, 0.1) or (DB.base or 0.6)
			local low = math.min(gone and 0 or DB.idle or 0, peak)
			local a = low + (peak - low) * c
			if woc.mbA[i] ~= a then
				woc.mbA[i] = a
				-- (Low health or Low mana on a Mouse over bar: up while low too, see the two columns below)
				local kind = woc.lowOn and a < peak - 0.001 and woc.lowKind(i)
				local lowA = kind and woc.lowAlphaFor(kind, a, peak) or nil
				if lowA then woc.lowAlpha, woc.lowFor = lowA, a end
				applyList("bar" .. i, a)
				if elsewhere.bars[i] then applyButtons(BAR_DEFS[i].buttons, 12, a) end
				if lowA then woc.lowAlpha, woc.lowFor = nil, nil end
			end
		else
			woc.mbCur[i], woc.mbA[i] = nil, nil -- (back to the group: woc.mouseMembership had it written again)
		end
	end
	return busy
end
-- The frames whose mouse over wakes the action bars: all of them but the bars ticked for Mouse over and any frame another
-- list owns (one also in the mouseover list; audit F2). Kept until the lists or the column change.
woc.groupHover = function()
	local all = ns.barHover
	local mask = woc.mbMask or 0
	local cache = woc.ghCache
	if cache and cache.list == all and cache.mask == mask and cache.owner == woc.owner then return cache.out end
	local skip = {}
	for i = 1, #BAR_DEFS do
		if barBit(mask, i) then
			for _, n in ipairs(LISTS["bar" .. i] or {}) do skip[n] = true end
			for j = 1, 12 do skip[BAR_DEFS[i].buttons .. j] = true end
		end
	end
	local out = {}
	for _, n in ipairs(all) do
		local o = woc.owner[n]
		if not skip[n] and not (o and o ~= "bars" and not o:find("^bar%d")) then out[#out + 1] = n end
	end
	woc.ghCache = { list = all, mask = mask, owner = woc.owner, out = out }
	return out
end

-- The frames added with /qhud add bars whose children count for the group's mouse over: only those the bars list owns (a
-- frame also in the mouseover list, or a bar's own frame, is left out; audit F2). Kept until the lists or the column change.
woc.groupExtras = function()
	local extra = DB.extra.bars
	if not extra or #extra == 0 then return nil end
	local cache = woc.geCache
	if cache and cache.extra == extra and cache.n == #extra and cache.owner == woc.owner then return cache.out end
	local out = {}
	for _, n in ipairs(extra) do
		if woc.owner[n] == "bars" then out[#out + 1] = n end
	end
	woc.geCache = { extra = extra, n = #extra, owner = woc.owner, out = out }
	return out
end

-- Whether a button's bar is no longer above it in the frame tree: another addon has put the button into a frame of its own.
-- ClassicUI Forever hangs every action button under a holder of its own on UIParent, and copies the bar's opacity into the
-- holder only when it lays the bar out again, so the buttons stayed solid while the bar faded, and after a target change
-- they came up faded while everything else woke.
-- A bar of another addon that QuietHUD fades itself (Dominos' bars, in the bars or the dominos list) counts as the button's bar: the
-- button just follows it. Without that, Dominos' reused game buttons were faded by name and told to ignore their bar, and
-- stayed visible when Dominos hid the bar with its own fade.
local function inList(list, p)
	for i = 1, list and #list or 0 do
		if _G[list[i]] == p then return true end
	end
	return false
end
local function outsideBar(button, frames)
	local f = button
	for _ = 1, 16 do
		local p = f:GetParent()
		if not p or p == f or p == UIParent then return true end
		if inList(frames, p) or inList(LISTS.bars, p) or inList(LISTS.dominos, p) then return false end
		f = p
	end
	return false
end

-- Twice a second: which bars have their buttons elsewhere. Those buttons are faded by name (applyBars) and count for mouse
-- over (rebuildLists), and while QuietHUD fades their bar they ignore their parent's opacity, so the holder's copy of the
-- bar's opacity neither fades them a second time nor holds them faded. They follow their parent again once they are back
-- in their bar, or when their bar is not faded. Out of combat only, in case the buttons are protected then.
local function checkElsewhere()
	if InCombatLockdown() then return end
	local changed, flipped = false, false
	local fadeOn = DB.enabled and DB.fadeBars
	local function look(kind, key, prefix, count, frames, ticked)
		local first = _G[prefix .. "1"]
		local away = (first and first.GetParent and outsideBar(first, frames)) and true or false
		if (kind[key] or false) ~= away then
			kind[key] = away
			changed = true
		end
		local ignore = (away and fadeOn and ticked) and true or false
		for j = 1, count do
			local b = _G[prefix .. j]
			if b and b.SetIgnoreParentAlpha and (elsewhere.ignoring[b] or false) ~= ignore then
				elsewhere.ignoring[b] = ignore or nil
				b:SetIgnoreParentAlpha(ignore)
				if not ignore then woc.write(b, 1) end
				flipped = true
			end
		end
	end
	for i, def in ipairs(BAR_DEFS) do look(elsewhere.bars, i, def.buttons, 12, def.frames, barBit(DB.barFade, i)) end
	for k, set in ipairs(EXTRA_BUTTONS) do look(elsewhere.extra, k, set[1], set[2], set[3], true) end
	if changed then
		rebuildLists()
	elseif flipped then
		woc.forget() -- (the buttons were told to ignore, or follow, their holder: their bar is written again)
	end
end

-- Shorter hotkey text, for keys such as the number pad or mouse buttons whose full names do not fit on an action
-- button (they show up as "NUM..."): Num Pad 1 becomes N1, Mouse Button 4 becomes M4, Shift- becomes s-, and so on.
-- Matching ignores case and only the parts that match are changed.
local function ci(word)
	return (word:gsub(".", function(c)
		if c:match("%a") then return "[" .. c:lower() .. c:upper() .. "]" end
		if c == " " then return "%s*" end
		return "%" .. c
	end))
end
local SHORT_RULES = {
	{ ci("shift") .. "[%-%+]", "s-" }, { ci("ctrl") .. "[%-%+]", "c-" }, { ci("alt") .. "[%-%+]", "a-" },
	{ ci("num pad") .. "%s*(%d+)", "N%1" }, { ci("num") .. "%s+(%d+)", "N%1" },
	{ ci("num pad") .. "%s*([%+%-%*/%.])", "N%1" },
	{ ci("num pad plus"), "N+" }, { ci("num pad minus"), "N-" }, { ci("num pad multiply"), "N*" },
	{ ci("num pad divide"), "N/" }, { ci("num pad decimal"), "N." }, { ci("num lock"), "NL" },
	{ ci("left mouse button"), "M1" }, { ci("right mouse button"), "M2" }, { ci("middle mouse button"), "M3" },
	{ ci("middle mouse"), "M3" }, { ci("mouse button") .. "%s*(%d+)", "M%1" },
	{ ci("mouse wheel up"), "MwU" }, { ci("mouse wheel down"), "MwD" },
	{ ci("page up"), "PgU" }, { ci("page down"), "PgD" }, { ci("insert"), "Ins" }, { ci("delete"), "Del" },
	{ ci("backspace"), "Bk" }, { ci("caps lock"), "Cap" }, { ci("escape"), "Esc" }, { ci("space"), "Sp" },
}
local function shortHotkey(text)
	for _, rule in ipairs(SHORT_RULES) do text = text:gsub(rule[1], rule[2]) end
	-- The slot on a button is only about three characters wide, so drop the dash after a modifier as well:
	-- c-N1 becomes cN1 and s-1 becomes s1.
	local prefix = ""
	while true do
		local mod, rest = text:match("^([scaSCA])%-(.+)$")
		if not mod then break end
		prefix, text = prefix .. mod, rest
	end
	return prefix .. text
end
local shortened = {}

-- Shortens (or, with wantShort false, restores) the hotkey text of one button.
local function shortenOne(fs, wantShort)
	local okText, text = pcall(fs.GetText, fs)
	if not (okText and type(text) == "string") or (issecretvalue and issecretvalue(text)) then return end
	local rec = shortened[fs]
	if wantShort then
		-- Blizzard writes the long text again on binding and page changes, so redo it when it changed.
		if not (rec and text == rec.short) then
			local short = shortHotkey(text)
			if short ~= text then
				-- The slot is narrow, so give the shorter text the width of the whole button as well.
				local width = rec and rec.width or fs:GetWidth()
				local parent = fs:GetParent()
				local room = parent and parent:GetWidth() or width
				shortened[fs] = { orig = text, short = short, width = width }
				fs:SetText(short)
				if room > width then fs:SetWidth(room) end
			else
				shortened[fs] = nil
			end
		end
	elseif rec and text == rec.short then
		fs:SetText(rec.orig)
		if rec.width then fs:SetWidth(rec.width) end
		shortened[fs] = nil
	end
end
local TEXT_SPECS = { { "HotKey", "barHotkeys" }, { "Name", "barNames" } }

-- The Low health and Low mana columns of the Action bars page (off by default; the owner, 2026-11-06: "bars appearing when
-- health is low. same percent that naowh uses to show that potion icon", then "specific bars ... checkboxes for 1234", then
-- "low mana and low hp it should pop up"). Below the threshold a ticked bar, faded, is at its Shown opacity. The game keeps
-- your health and mana from addons (hidden values, also outside a fight: his test of Nov 6), so QuietHUD cannot tell when
-- they are low: as Naowh does for its Low Health icon, it hands the game a step curve (Shown below the threshold, the bar's
-- faded opacity above it) and the game sets the bar's opacity from it (woc.write, Core.lua). So the bars come up and go at
-- once, with no fade (his "instant pop is fine"). Health's threshold is Naowh's Low Health "Show Below" while Naowh is
-- loaded, else 35% (Naowh's default); mana's is 35%. One of the two per bar (ticking one unticks the other, Config.lua):
-- nothing, not even the game's helpers, can combine two hidden values into "health or mana low".
-- Not in Edit Mode, not while dead, and not in a fight when Hide in combat is ticked for Action bars. A bar without Fade never
-- gets it (applyBars). A Mouse over bar does (woc.mouseBars; his Nov 6 test had Low health only on Bar 8, a Mouse over bar,
-- and nothing came up): it comes up under the mouse or while low, the one way it shows in a fight. Low mana never counts for
-- a class without mana.
-- Cost: nothing with no bar ticked (no events listened to). Ticked: per health change (Low health) or mana change (Low mana),
-- the bars are written again at the next update while they are faded (one curve and two SetAlpha per bar frame); no timer
-- and no poll of its own, but a change every frame in a fight means a write every frame then. Naowh's threshold changing
-- writes them again too (a hook on its settings save, ChatGPT's audit of Nov 6, F2).
do
	local STEP_EDGE = 0.001
	local MANA_BELOW = 0.35
	local NO_MANA = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, DEMONHUNTER = true }
	local curve
	local function below()
		local ok, v = pcall(function()
			local N = _G.NaowhForever
			local S = N and (N.AuraBuffSettings or (N.AuraBuffs and N.AuraBuffs.Settings))
			return S and S.Get("lowHealthBelow")
		end)
		if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) and v > 0 and v < 100 then return v / 100 end
		return 0.35
	end
	local function usesMana()
		local ok, _, class = pcall(UnitClass, "player")
		return not (ok and NO_MANA[class])
	end
	-- Which of the two a bar has: "health", "mana" or nil.
	woc.lowKind = function(i)
		if barBit(DB.barLow, i) then return "health" end
		if barBit(DB.barMana, i) then return "mana" end
		return nil
	end
	-- The opacity the game works out for a bar at a with Shown peak (a hidden value), or nil if it does not count or this
	-- client cannot.
	woc.lowAlphaFor = function(kind, a, peak)
		if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return nil end
		if kind == "mana" and not (UnitPowerPercent and usesMana()) then return nil end
		if kind == "health" and not UnitHealthPercent then return nil end
		local ok, v = pcall(function()
			local at = kind == "mana" and MANA_BELOW or below()
			curve = curve or C_CurveUtil.CreateCurve()
			curve:SetType(Enum.LuaCurveType.Step)
			curve:ClearPoints()
			curve:AddPoint(0, peak)
			curve:AddPoint(at - STEP_EDGE, peak)
			curve:AddPoint(at, a)
			curve:AddPoint(1, a)
			if kind == "mana" then return UnitPowerPercent("player", 0, false, curve) end
			return UnitHealthPercent("player", true, curve)
		end)
		if ok then return v end
		return nil
	end
	-- Health and mana changes, each listened to only while a bar has its column ticked (woc.lowListen, from the loop): the
	-- bars are written again.
	local function rewrite()
		if woc.lowOn then
			woc.applied.bars, woc.mbA = nil, {} -- (the group and the Mouse over bars)
			ns.loop.wake = true
		end
	end
	local ev = CreateFrame("Frame")
	ev:SetScript("OnEvent", function(_, event, _, powerType)
		if event == "UNIT_POWER_UPDATE" and powerType ~= "MANA" then return end -- (rage, energy: not mana)
		rewrite()
	end)
	local listening, naowhHooked = { health = false, mana = false }, false
	local EVENTS = { health = { "UNIT_HEALTH", "UNIT_MAXHEALTH" }, mana = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" } }
	local function listen(kind, on)
		if on == listening[kind] then return end
		listening[kind] = on
		for _, e in ipairs(EVENTS[kind]) do
			if on then
				if not pcall(ev.RegisterUnitEvent, ev, e, "player") then pcall(ev.RegisterEvent, ev, e) end
			else
				pcall(ev.UnregisterEvent, ev, e)
			end
		end
	end
	woc.lowListen = function(health, mana)
		listen("health", health and true or false)
		listen("mana", mana and true or false)
		if health and not naowhHooked then
			local N = _G.NaowhForever
			local S = type(N) == "table" and (N.AuraBuffSettings or (N.AuraBuffs and N.AuraBuffs.Settings))
			if type(S) == "table" and type(S.Set) == "function" then
				naowhHooked = pcall(hooksecurefunc, S, "Set", function(key)
					if listening.health and key == "lowHealthBelow" then rewrite() end
				end) or false
			end
		end
	end
end

-- For the files after this one (QuietHUD.toc).
ns.applyBars, ns.checkElsewhere, ns.shortHotkey, ns.shortened = applyBars, checkElsewhere, shortHotkey, shortened
ns.shortenOne, ns.TEXT_SPECS = shortenOne, TEXT_SPECS
