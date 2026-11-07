-- Quest guides: the nav group (an arrow, faded through a host frame of ours, as every hosted list is) and the RestedXP
-- windows (their opacity put back the moment RestedXP sets its own).
local _, ns = ...
local DB, LISTS, woc, HOSTED = ns.DB, ns.LISTS, ns.woc, ns.HOSTED
local applyList = ns.applyList

-- Frames in a hosted list (Frames.lua: the nav group, for example the direction arrow of a quest guide, and Naowh's alerts)
-- are moved under a small host frame of ours, and the host is what fades. A frame that sets its own opacity to show and hide
-- itself would fight with a fade applied to it directly; under a host the two opacities multiply instead, so it can still
-- show and hide itself. One host per frame, kept per list. A frame another list owns (woc.owner) is left to that list.
local hosts = {}
for g in pairs(HOSTED) do hosts[g] = {} end
local navHosts = hosts.nav
local spare = setmetatable({}, { __mode = "k" }) -- (a host made for a frame that did not move into it yet, kept for the next try)
woc.hostWaits = {} -- per list: a frame waits to go back, or has no host yet (see woc.group)
ns.navLastError = nil -- (the last problem moving a frame into its host, for /qhud nav)
ns.navForce = false   -- /qhud arrow: keeps the nav group visible whatever else is going on
local releaseHosted
local function applyHosted(g, a)
	local wanted, pending = {}, false
	for _, name in ipairs(LISTS[g] or {}) do
		local f = _G[name]
		local owner = woc.owner[name]
		if type(f) == "table" and f.SetParent and (owner == nil or owner == g) then
			wanted[f] = true
			local rec = hosts[g][f]
			-- A protected frame cannot change its parent in a fight, and the game refuses that without an error: it moves into
			-- its host after the fight. A move the game did not make is not counted either: it is tried again at the next update.
			if not rec and InCombatLockdown() and f.IsProtected and f:IsProtected() then
				pending = true
			elseif not rec then
				local okHost, made = pcall(function()
					local host = spare[f] or CreateFrame("Frame", nil, UIParent)
					spare[f] = host
					host:SetAllPoints(UIParent)
					local original = f:GetParent()
					f:SetParent(host)
					if f:GetParent() ~= host then error("the game did not move it into its container", 0) end
					return { host = host, parent = original }
				end)
				if okHost then
					rec = made
					hosts[g][f], spare[f] = rec, nil
				else
					ns.navLastError = tostring(made)
					pending = true
				end
			end
			if rec then rec.host:SetAlpha(a) end
		end
	end
	woc.hostWaits[g] = pending -- (a host that could not be made is tried again at every update; see woc.group and releaseHosted)
	releaseHosted(g, wanted)
end
-- Frames taken out of a list go back where they were. The game blocks that for a protected frame during combat (without
-- an error), so such a frame keeps its record and goes back after the fight (PLAYER_REGEN_ENABLED calls releaseNav, so it
-- also happens when QuietHUD was switched off before the fight ended); until then its host is at full opacity.
releaseHosted = function(g, wanted)
	if not wanted then
		wanted = {}
		for _, name in ipairs(LISTS[g] or {}) do
			local owner = woc.owner[name]
			if _G[name] and (owner == nil or owner == g) then wanted[_G[name]] = true end
		end
	end
	local waiting = false
	for f, rec in pairs(hosts[g]) do
		if not wanted[f] then
			rec.host:SetAlpha(1)
			local back = rec.parent or UIParent
			if not (InCombatLockdown() and f.IsProtected and f:IsProtected()) then
				local ok, err = pcall(f.SetParent, f, back)
				rec.tries = (rec.tries or 0) + 1
				if f:GetParent() == back then
					hosts[g][f] = nil
				elseif rec.tries >= 3 then
					-- (outside combat it should never fail; given up rather than tried on every update)
					ns.navLastError = "could not give a frame back its parent: " .. tostring(ok and "it did not take" or err)
					hosts[g][f] = nil
				end
			end
			if hosts[g][f] then waiting = true end
		end
	end
	-- While a frame waits to go back, or one still has no host, the list goes through every update (see woc.group).
	woc.hostWaits[g] = waiting or woc.hostWaits[g] or false
end
local function applyNav(a) applyHosted("nav", a) end
-- Every hosted list gives back the frames that left it (after a fight, from Events.lua).
local function releaseNav()
	for g in pairs(hosts) do releaseHosted(g) end
end

-- RestedXP sets its targets frame to full opacity each time it redraws the list (on a target change, among others). The
-- main loop would put QuietHUD's opacity back one frame later, which shows as a flicker, so the frames of the RXP group
-- get it back the moment RestedXP (or anything else) changes it.
local applyRxp
do
	local wanted, busy, seen = nil, false, {}
	-- Still in the group right now (a frame taken out of it gets its own opacity back and is left alone).
	local function listed(f)
		for _, name in ipairs(LISTS.rxp) do
			if _G[name] == f then return true end
		end
		return false
	end
	local function keep(f, a)
		if busy or not wanted or not DB.enabled or type(a) ~= "number" or (issecretvalue and issecretvalue(a)) then return end
		if math.abs(a - wanted) < 0.01 or not listed(f) then return end
		-- An outside 0 is someone hiding the window: woc's own hook lets it go (yielded), so it is not put back here first.
		if a < 0.01 then return end
		busy = true
		pcall(woc.write, f, wanted) -- (through woc, so it is not taken for another addon hiding the frame at idle 0)
		busy = false
	end
	applyRxp = function(a)
		wanted = a
		for _, name in ipairs(LISTS.rxp) do
			local f = _G[name]
			if type(f) == "table" and f.SetAlpha and not seen[f] then
				seen[f] = true
				hooksecurefunc(f, "SetAlpha", keep)
			end
		end
		applyList("rxp", a)
	end
end

-- For the files after this one (QuietHUD.toc).
ns.navHosts, ns.releaseNav, ns.applyNav, ns.applyRxp = navHosts, releaseNav, applyNav, applyRxp
ns.hosts, ns.applyHosted = hosts, applyHosted
