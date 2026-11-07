-- 3D models (portraits drawn as a live model, for example by Animated Blizzard Portraits, which also puts them on RestedXP's
-- target buttons) do not take the opacity of the frames they sit in, so they stay solid while their frame fades. Their own
-- model opacity (SetModelAlpha) does work, so each model found under the frames of these groups is given the opacity it would
-- have if it followed its frames, times any opacity its own addon gave it. Setting a new unit or model can put the model back
-- to full, so those calls are hooked and the opacity goes back on at once (the loop would only catch it a frame later).
local _, ns = ...
local DB, LISTS, trace = ns.DB, ns.LISTS, ns.trace

local fadeModels
do
	local ROOT_GROUPS = { "player", "hud", "target", "pet", "party", "rxp" }
	local MODEL_TYPES = { Model = true, PlayerModel = true, DressUpModel = true, CinematicModel = true, TabardModel = true }
	local DEPTH = 5
	local models, owner, touched, lastSet = {}, {}, {}, {}
	local said, counts = { late = {}, once = {} }, { late = {}, once = {} }
	local calls = setmetatable({}, { __mode = "k" })
	local busy, scanAt = false, 0
	local function whereIs(m)
		local p = m
		for _ = 1, 8 do
			local ok, parent = pcall(p.GetParent, p)
			p = ok and parent or nil
			if not p then break end
			local okN, name = pcall(p.GetName, p)
			if okN and type(name) == "string" then return name end
		end
		return "an unnamed frame"
	end
	-- With /qhud debug on, the last calls made on each model are kept: what was called, when (seconds), and the model's own
	-- opacity right after it. They are printed with a blink, so the line shows what happened to the model just before.
	local function note(m, what)
		if not ns.debugOn then return end
		local list = calls[m]
		if not list then
			list = {}
			calls[m] = list
		end
		local ok, a = pcall(m.GetModelAlpha, m)
		local alpha = (ok and type(a) == "number" and not (issecretvalue and issecretvalue(a))) and string.format("%.2f", a) or "?"
		list[#list + 1] = string.format("%s %.2f=%s", what, GetTime() % 1000, alpha)
		if #list > 10 then table.remove(list, 1) end
	end
	local function history(m)
		local okS, shown = pcall(m.IsVisible, m)
		return string.format("now %.2f, on screen %s, last calls: %s", GetTime() % 1000, tostring(okS and shown and true or false),
			calls[m] and table.concat(calls[m], ", ") or "none")
	end
	-- With /qhud debug on, a model whose opacity was put back by something QuietHUD does not hook is named (at most every 2
	-- seconds each, with how many times it happened): the update caught it a frame late, which shows as a blink. One put back
	-- by a call QuietHUD does hook is named too (after: the call), though that one is faded again before the screen is drawn.
	local function sayBlink(m, have, want, after)
		local kind = after and "once" or "late"
		local now = GetTime()
		counts[kind][m] = (counts[kind][m] or 0) + 1
		if now - (said[kind][m] or -10) < 2 then return end
		said[kind][m] = now
		local count = counts[kind][m]
		counts[kind][m] = 0
		if after then
			trace(string.format("QuietHUD: a 3D model under %s was set back to %.2f by %s and faded to %.2f again at once (%d since the last line; %s)",
				whereIs(m), have, after, want, count, history(m)))
		else
			trace(string.format("QuietHUD: a 3D model under %s was set back to %.2f between updates (a blink, %d since the last line), faded to %.2f again (%s)",
				whereIs(m), have, count, want, history(m)))
		end
	end
	-- fromLoop: called by the update loop, not by one of the hooks below (after: the hooked call it follows).
	local function apply(m, fromLoop, after)
		if busy then return end
		local want = owner[m] or 1
		if DB.enabled then
			local eff = m:GetEffectiveAlpha()
			-- A secret opacity (the game can set one, for example on a party member out of range) cannot be used: left alone.
			if type(eff) ~= "number" or (issecretvalue and issecretvalue(eff)) then return end
			want = want * eff
		elseif not touched[m] then
			return
		end
		local have = m:GetModelAlpha()
		local readable = type(have) == "number" and not (issecretvalue and issecretvalue(have))
		if readable and math.abs(have - want) < 0.005 then return end
		if ns.debugOn and readable and lastSet[m] and math.abs(have - lastSet[m]) > 0.005 and (fromLoop or after) then
			sayBlink(m, have, want, (not fromLoop) and after or nil)
		end
		busy = true
		pcall(m.SetModelAlpha, m, want)
		busy = false
		lastSet[m] = want
		touched[m] = want < (owner[m] or 1) - 0.005 or nil
	end
	-- The model's own addon set its opacity: kept, and multiplied in.
	local function ownerSet(m, a)
		if busy or type(a) ~= "number" or (issecretvalue and issecretvalue(a)) then return end
		owner[m], lastSet[m] = a, a
		note(m, "SetModelAlpha (its addon)")
		pcall(apply, m)
	end
	-- Besides a new unit or model, the opacity goes back on after the calls Animated Blizzard Portraits makes each time it
	-- redraws a face (animation, zoom, showing it), in case the game puts the model back to full on any of them.
	local AGAIN_AFTER = { "SetUnit", "SetDisplayInfo", "SetCreature", "SetModel", "ClearModel", "SetAnimation", "SetPortraitZoom",
		"SetCamDistanceScale", "SetPosition", "RefreshUnit", "RefreshCamera", "Show" }
	-- The faded frames a model can sit under (the frames of the groups above).
	local function rootSet()
		local roots = {}
		for _, g in ipairs(ROOT_GROUPS) do
			local list = LISTS[g]
			for i = 1, list and #list or 0 do
				local r = _G[list[i]]
				if type(r) == "table" then roots[r] = true end
			end
		end
		return roots
	end
	-- The game also puts a model back to full when the opacity of a frame above it is set (RestedXP sets its targets window's
	-- opacity about ten times a second while the mouse moves over mobs, and each time the faces on it were solid until the
	-- next update, a blink). So the frames between a model and its faded
	-- frame are watched too, and the model's opacity goes back on in the same call.
	local watched, below = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
	local function watchAbove(m)
		local roots, f = rootSet(), m
		for _ = 1, DEPTH + 1 do
			local ok, parent = pcall(f.GetParent, f)
			if not (ok and type(parent) == "table") or parent == UIParent then break end
			f = parent
			if not below[f] then below[f] = setmetatable({}, { __mode = "k" }) end
			below[f][m] = true
			if not watched[f] and f.SetAlpha and not (f.IsForbidden and f:IsForbidden()) then
				watched[f] = true
				pcall(hooksecurefunc, f, "SetAlpha", function(self)
					local what = "SetAlpha above"
					if ns.debugOn then
						local okN, name = pcall(self.GetName, self)
						what = "SetAlpha on " .. ((okN and type(name) == "string") and name or "a frame above")
					end
					for model in pairs(below[self] or {}) do
						note(model, what)
						pcall(apply, model, false, what)
					end
				end)
			end
			if roots[f] then break end
		end
	end
	local function hookScript(m, script)
		pcall(m.HookScript, m, script, function(self)
			note(self, script)
			pcall(apply, self, false, script)
		end)
	end
	local function adopt(m)
		models[m] = true
		if ns.debugOn then trace("QuietHUD: took on a 3D model under " .. whereIs(m)) end
		pcall(hooksecurefunc, m, "SetModelAlpha", ownerSet)
		for _, fn in ipairs(AGAIN_AFTER) do
			if m[fn] then
				pcall(hooksecurefunc, m, fn, function(self)
					note(self, fn)
					pcall(apply, self, false, fn)
				end)
			end
		end
		pcall(hooksecurefunc, m, "Hide", function(self) note(self, "Hide") end)
		hookScript(m, "OnModelLoaded")
		hookScript(m, "OnShow")
		pcall(watchAbove, m)
		-- Its addon setting its own script replaces the hook (Animated Blizzard Portraits sets OnModelLoaded right after it makes
		-- a face, and a model is taken on as it is made), so the hook is put back each time. Without it a face that finished
		-- loading stayed at the full opacity the game gives it until the next update: a blink.
		pcall(hooksecurefunc, m, "SetScript", function(self, script)
			if script == "OnModelLoaded" or script == "OnShow" then
				note(self, "SetScript " .. script)
				hookScript(self, script)
			end
		end)
	end
	local function walk(depth, ...)
		for i = 1, select("#", ...) do
			local c = select(i, ...)
			if type(c) == "table" and not (c.IsForbidden and c:IsForbidden()) then
				if not models[c] and c.GetObjectType and MODEL_TYPES[c:GetObjectType()] and c.SetModelAlpha and c.GetModelAlpha then
					adopt(c)
				end
				if depth > 1 and c.GetChildren then walk(depth - 1, c:GetChildren()) end
			end
		end
	end
	local function walkRoot(f) walk(DEPTH, f:GetChildren()) end
	-- Looked for soon after the things that can put a new portrait up: a new target, focus, party or pet, entering the world, an
	-- addon loading, the frame lists changing, QuietHUD being switched on, and any 3D model being made (Animated Blizzard
	-- Portraits makes its faces with CreateFrame), never on a timer. Nothing is looked for while QuietHUD is switched off; the
	-- models it faded get their opacity back once.
	local function soonScan() scanAt = math.min(scanAt, GetTime() + 0.1) end
	local soon = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE", "UNIT_PET", "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
		pcall(soon.RegisterEvent, soon, e)
	end
	soon:SetScript("OnEvent", soonScan)
	local MODEL_KINDS = {}
	for kind in pairs(MODEL_TYPES) do MODEL_KINDS[kind:lower()] = true end
	-- Whether a frame is one of the faded frames above, or under one (within DEPTH).
	local function underRoot(f)
		local roots = rootSet()
		for _ = 1, DEPTH do
			if roots[f] then return true end
			local ok, p = pcall(f.GetParent, f)
			if not (ok and type(p) == "table") then return false end
			f = p
		end
		return false
	end
	-- A model made under a faded frame is taken on at once, so its hooks are on before its addon first shows it (Animated
	-- Blizzard Portraits shows a new face straight away: on a new RestedXP target button it was solid until the next look).
	pcall(hooksecurefunc, "CreateFrame", function(kind, _, parent)
		if type(kind) == "string" and MODEL_KINDS[kind:lower()] then
			if DB.enabled and type(parent) == "table" and parent.GetChildren then
				pcall(function() if underRoot(parent) then walk(1, parent:GetChildren()) end end)
			end
			soonScan()
		end
	end)
	-- With /qhud debug on, a /reload (or logging out) writes every model's last calls to the trace, blink or no blink.
	local atLogout = CreateFrame("Frame")
	pcall(atLogout.RegisterEvent, atLogout, "PLAYER_LOGOUT")
	atLogout:SetScript("OnEvent", function()
		if not ns.debugOn then return end
		for m in pairs(models) do
			local okA, a = pcall(m.GetModelAlpha, m)
			pcall(trace, string.format("QuietHUD: at reload, 3D model under %s: opacity %s, last set to %s (%s)", whereIs(m),
				(okA and type(a) == "number") and string.format("%.2f", a) or "?", lastSet[m] and string.format("%.2f", lastSet[m]) or "never", history(m)))
		end
	end)
	local seenLists, wasEnabled = nil, false
	fadeModels = function(now)
		if not DB.enabled then
			wasEnabled = false
			if next(touched) == nil then return end
		elseif not wasEnabled or seenLists ~= LISTS[ROOT_GROUPS[1]] then
			wasEnabled, seenLists = true, LISTS[ROOT_GROUPS[1]]
			scanAt = 0
		end
		if DB.enabled and now >= scanAt then
			scanAt = math.huge
			for _, g in ipairs(ROOT_GROUPS) do
				local list = LISTS[g]
				for i = 1, list and #list or 0 do
					local f = _G[list[i]]
					if type(f) == "table" and f.GetChildren then pcall(walkRoot, f) end
				end
			end
		end
		for m in pairs(models) do pcall(apply, m, true) end
	end
end

-- For the files after this one (QuietHUD.toc).
ns.fadeModels = fadeModels
