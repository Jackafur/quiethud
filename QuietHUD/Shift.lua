-- Pixel shift (opt-in, experimental). OLED panels can burn in from shapes that stay in one place, so every few minutes the
-- frames in the shift group are moved a couple of pixels along a small circle. Nothing saved is ever changed: a frame's
-- anchors are remembered when it is first moved and put back exactly when the option is turned off, when Edit Mode opens
-- and at logout. Nothing is moved during combat. If the game or another addon moves a frame while it is shifted, the shift
-- steps aside and takes the new position as the normal one, so a restore can never drag a frame back to an old spot.
local _, ns = ...
local DB, LISTS = ns.DB, ns.LISTS
local refreshMapMask = ns.refreshMapMask

local tickShift, restoreShift, shiftNow, shiftReport
do
	local SHIFT_STEPS = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 } }
	local shiftIndex, shiftNextAt, shiftWantX, shiftWantY, shiftClock, lastEdit = 1, 0, 0, 0, 0, false
	local shiftState, shiftLastError = {}, nil
	local contested = {}   -- frames another addon keeps putting back, left alone (see syncFrame)

	local function anchorList(f)
		local t = {}
		for i = 1, f:GetNumPoints() do
			local point, rel, relPoint, x, y = f:GetPoint(i)
			t[i] = { point, rel, relPoint, x or 0, y or 0 }
		end
		return t
	end

	local function anchorSig(t)
		local parts = {}
		for i, a in ipairs(t) do
			parts[i] = tostring(a[1]) .. "|" .. tostring(a[2]) .. "|" .. tostring(a[3]) .. "|" .. string.format("%.3f|%.3f", a[4], a[5])
		end
		return table.concat(parts, ";")
	end

	-- An Edit Mode frame (the minimap, the tracker, the action bars, the unit frames) has its SetPoint and ClearAllPoints
	-- replaced by Edit Mode, which keeps the game's own as SetPointBase and ClearAllPointsBase. Its replacement also marks
	-- Edit Mode's layout as changed; set from QuietHUD, that mark was QuietHUD's, and when the game later laid out the right
	-- action bars in a fight it was blocked in QuietHUD's name (Nov 5: "Interface action failed", MultiBarRight:SetPointBase()).
	-- So the game's own are used: the frame moves, Edit Mode's records are not touched.
	local function setAnchors(f, t, dx, dy)
		local clear = f.ClearAllPointsBase or f.ClearAllPoints
		local set = f.SetPointBase or f.SetPoint
		clear(f)
		for _, a in ipairs(t) do
			set(f, a[1], a[2], a[3], a[4] + dx, a[5] + dy)
		end
		refreshMapMask() -- the minimap's mask is set again where the map is now
	end

	local function anchoredToListed(t, listed, f)
		for _, a in ipairs(t) do
			if a[2] and a[2] ~= f and listed[a[2]] then return true end
		end
		return false
	end

	local function syncFrame(f, listed)
		local c = contested[f]
		if c and c.off then return end
		local now = anchorList(f)
		if #now == 0 then return end
		local sig = anchorSig(now)
		local st = shiftState[f]
		if st and st.sig ~= sig then
			-- Something else moved it since: that position is the new normal, and ours is forgotten. An addon that puts the
			-- frame back every time (ClassicUI Forever lays its bar out again whenever the game's bar frames move, so the
			-- bags jumped once a second) would be fought for ever, so after three such moves within ten seconds the frame is
			-- left alone until the option is turned on again.
			st = nil
			shiftState[f] = nil
			local t = GetTime()
			if not c or t - c.since > 10 then
				c = { since = t, n = 0 }
				contested[f] = c
			end
			c.n = c.n + 1
			if c.n >= 3 then
				c.off = true
				return
			end
		end
		-- A frame anchored to another frame of the group moves along with it, so it is not shifted a second time.
		if anchoredToListed(now, listed, f) then
			if st then
				setAnchors(f, st.base, 0, 0)
				shiftState[f] = nil
			end
			return
		end
		if shiftWantX == 0 and shiftWantY == 0 then
			if st then
				setAnchors(f, st.base, 0, 0)
				shiftState[f] = nil
			end
			return
		end
		-- Offsets are in the frame's own units. A frame that is shrunk (the faded minimap) is left alone until it is back to size.
		local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
		if not (k >= 0.5 and k <= 2) then return end
		if not st then st = { base = now } end
		if st.wx ~= shiftWantX or st.wy ~= shiftWantY then
			setAnchors(f, st.base, shiftWantX / k, shiftWantY / k)
			st.wx, st.wy = shiftWantX, shiftWantY
			st.sig = anchorSig(anchorList(f))
			shiftState[f] = st
		end
	end

	-- Frames found on the screen (the owner, Nov 10: "i want that stuff to shift automatically by default so in the future i
	-- dont have to make those changes"): besides the listed ones, every shown frame placed against the screen itself is moved
	-- too, so a new addon's pieces move without a change to QuietHUD. Looked for once per reload (his "maybe only do this
	-- once per reload ... not polling i hope"), at the first move at least 10 seconds after loading, out of combat, hidden
	-- frames too (they move while hidden, so one that shows later is in place): the children of UIParent, and inside a frame
	-- as big as the screen (Warlock HUD's rows sit in such holders) its children, down to four levels, at most 3000 frames.
	-- The frames found are written only when the shift moves, not on the once-a-second check. Left out, as moving them from
	-- an addon can get the game's own code
	-- blocked later (Nov 5, MultiBarRight): protected frames, Edit Mode and managed frames (their layout is the game's), the
	-- game's panel windows (UIPanelWindows), tooltips; and a frame placed against anything but the screen, which moves with
	-- what it hangs on.
	local found, foundFor, searched = {}, nil, false
	local loadedAt = GetTime()
	-- Audit 2026-11-10 evening: a frame the game made itself (its global name set by the game's own code, or one of its
	-- managed containers and widget holders, which the game places again by itself) is left out too, and so is a frame
	-- holding protected buttons (an addon's bar: its art would drift away from buttons that cannot move). Each frame is
	-- looked at on its own, so one whose size or place cannot be read (a hidden value) is skipped, not the whole search.
	local function gameMade(name)
		if not name then return false end
		if name:find("ManagedFrameContainer", 1, true) or name:find("^UIWidget") then return true end
		return issecurevariable and issecurevariable(_G, name) or false
	end
	local function hasProtectedChild(f)
		for _, c in ipairs({ f:GetChildren() }) do
			if c.IsProtected and c:IsProtected() then return true end
		end
		return false
	end
	local function num(v) return type(v) == "number" and not (issecretvalue and issecretvalue(v)) end
	-- "use" (move it), "inside" (as big as the screen: look at what is inside it) or nil.
	local function classify(f, uw, uh)
		if f.IsForbidden and f:IsForbidden() then return nil end
		if not (f.GetNumPoints and f.GetPoint) then return nil end
		if f.IsProtected and f:IsProtected() then return nil end
		if f.system or f.isManagedFrame or f.layoutParent then return nil end
		if f.IsObjectType and f:IsObjectType("GameTooltip") then return nil end
		local name = f.GetName and f:GetName()
		if name and UIPanelWindows and UIPanelWindows[name] then return nil end
		if gameMade(name) then return nil end
		local w, h = f:GetWidth(), f:GetHeight()
		if num(w) and num(h) and w >= uw * 0.9 and h >= uh * 0.9 then return "inside" end
		local n = f:GetNumPoints()
		if not num(n) or n == 0 then return nil end
		for i = 1, n do
			local _, rel = f:GetPoint(i)
			if rel ~= nil and rel ~= UIParent then return nil end
		end
		if hasProtectedChild(f) then return nil end
		return "use"
	end
	local function discover()
		found = {}
		local seen, uw, uh = 0, UIParent:GetWidth(), UIParent:GetHeight()
		local function walk(parent, depth)
			local ok, kids = pcall(function() return { parent:GetChildren() } end)
			if not ok then return end
			for _, f in ipairs(kids) do
				seen = seen + 1
				if seen > 3000 then return end
				local okC, kind = pcall(classify, f, uw, uh)
				if okC and kind == "use" then
					found[#found + 1] = f
				elseif okC and kind == "inside" and depth < 4 then
					walk(f, depth + 1) -- (a holder as big as the screen: what is inside it)
				end
			end
		end
		walk(UIParent, 1)
	end

	local function syncShift()
		if InCombatLockdown() then return end
		-- (Warlock HUD's rows, which it makes anew at each build: named again when the shift moves, not every second)
		if foundFor ~= shiftWantX .. "," .. shiftWantY and ns.woc.nameWarlockRows then ns.woc.nameWarlockRows() end
		local listed, frames = {}, {}
		for _, name in ipairs(LISTS.shift) do
			local f = _G[name]
			if f and f.GetNumPoints and f.GetPoint and not (f.IsForbidden and f:IsForbidden()) and not listed[f] then
				listed[f] = true
				frames[#frames + 1] = { f, name }
			end
		end
		if not searched and (shiftWantX ~= 0 or shiftWantY ~= 0) and GetTime() - loadedAt >= 10 then
			discover()
			searched = true
		end
		-- (the found ones count as listed every second, so nothing hanging on them moves twice and none is put back; they
		-- are written only when the shift has moved since)
		local want = shiftWantX .. "," .. shiftWantY
		local moveFound = foundFor ~= want

		for _, f in ipairs(found) do
			if not listed[f] then
				listed[f] = true
				if moveFound then frames[#frames + 1] = { f, (f.GetName and f:GetName()) or "a frame found on the screen" } end
			end
		end
		if searched then foundFor = want end
		for _, rec in ipairs(frames) do
			local ok, err = pcall(syncFrame, rec[1], listed)
			if not ok then shiftLastError = rec[2] .. ": " .. tostring(err) end
		end
		-- Frames taken out of the group are put back.
		for f, st in pairs(shiftState) do
			if not listed[f] then
				pcall(function()
					if anchorSig(anchorList(f)) == st.sig then setAnchors(f, st.base, 0, 0) end
				end)
				shiftState[f] = nil
			end
		end
	end

	local function stepShift(now, edit)
		local on = DB.enabled and DB.pixelShift -- (switching QuietHUD off puts the frames back too)
		if not on and next(contested) ~= nil then contested = {} end
		if not on and next(shiftState) == nil then return end
		if on and not edit then
			if now >= shiftNextAt then
				shiftIndex = shiftIndex % #SHIFT_STEPS + 1
				shiftNextAt = now + (DB.shiftMinutes or 3) * 60
			end
			local s = SHIFT_STEPS[shiftIndex]
			local px = DB.shiftPixels or 2
			shiftWantX, shiftWantY = s[1] * px, s[2] * px
		else
			shiftWantX, shiftWantY = 0, 0
		end
		syncShift()
	end

	-- Once a second, and at once when Edit Mode opens or closes.
	tickShift = function(dt, now, edit)
		shiftClock = shiftClock + dt
		if shiftClock > 1 or edit ~= lastEdit then
			shiftClock = 0
			lastEdit = edit
			local ok, err = pcall(stepShift, now, edit)
			if not ok then shiftLastError = tostring(err) end
		end
	end

	restoreShift = function()
		shiftWantX, shiftWantY = 0, 0
		syncShift()
	end

	-- For WackyBars (audit Nov 10: moving, nudging or resizing a shifted WackyBars bar saved the shift into its place, a few
	-- pixels more each time). The offset the shift has on a frame right now, in UIParent units: 0, 0 when it is not shifted
	-- or was moved since. And a pause while its Move bars is open, as for Edit Mode: the frames go back to their places.
	function QuietHUD_ShiftOffset(f)
		local st = type(f) == "table" and shiftState[f]
		if not (st and st.wx and st.sig) then return 0, 0 end
		local ok, now = pcall(anchorList, f)
		if not ok or #now == 0 or anchorSig(now) ~= st.sig then return 0, 0 end
		return st.wx, st.wy
	end
	-- For an addon that places its shifted frame again by itself (Spy, whenever its list grows or shrinks): called right
	-- after it did. fromSaved: it put the frame at its saved spot, which has no shift in it, so the shift goes back on top.
	-- Otherwise it started from where the frame is now, shift included, so the shift is taken back out of the new normal
	-- (else the shift would add up into its place, a few pixels more each time). Out of combat only; in a fight the shift
	-- steps aside as for any other move.
	-- x, y (when the addon says where it put the frame): a spot equal to where the shifted frame was is "from now", whatever
	-- the addon saved. Spy's Window scale slider saves the shifted spot and places it there on every step, which crept by
	-- one shift a step when that counted as "saved" (audit Nov 13).
	ns.shiftOwnerPlaced = function(f, fromSaved, x, y)
		local st = type(f) == "table" and shiftState[f]
		if not (st and st.wx and st.sig) or (InCombatLockdown and InCombatLockdown()) then return end
		local okNow, now = pcall(anchorList, f)
		if not okNow or #now == 0 then return end
		local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
		if not (k >= 0.5 and k <= 2) then return end
		local dx, dy = st.wx / k, st.wy / k
		local old = st.base and st.base[1]
		if fromSaved and type(x) == "number" and type(y) == "number" and old and type(old[4]) == "number" and type(old[5]) == "number"
			and math.abs(x - (old[4] + dx)) < 0.5 and math.abs(y - (old[5] + dy)) < 0.5 then
			fromSaved = false
		end
		local base = {}
		for i, a in ipairs(now) do
			base[i] = { a[1], a[2], a[3], fromSaved and a[4] or a[4] - dx, fromSaved and a[5] or a[5] - dy }
		end
		st.base = base
		if fromSaved then pcall(setAnchors, f, base, dx, dy) end
		st.sig = anchorSig(anchorList(f))
	end
	function QuietHUD_ShiftPause(on)
		ns.shiftPaused = on and true or false
		if ns.wakeLoop then ns.wakeLoop() end
	end

	shiftNow = function()
		shiftNextAt = 0
	end

	shiftReport = function()
		print("QuietHUD pixel shift (experimental): " .. (DB.pixelShift and (DB.enabled and "on" or "on, but QuietHUD is switched off") or "off") .. ", offset now " .. shiftWantX .. "," .. shiftWantY .. " pixels, a move every " .. (DB.shiftMinutes or 3) .. " minutes, /qhud shift on, off or now")
		local named = {}
		for _, name in ipairs(LISTS.shift) do if _G[name] then named[_G[name]] = true end end
		local extra = {}
		for _, f in ipairs(found) do
			if not named[f] then
				local st = shiftState[f]
				extra[#extra + 1] = ((f.GetName and f:GetName()) or "(no name)") .. (st and "" or " (not moved)")
			end
		end
		if #extra > 0 then print("  found on the screen (" .. #extra .. "): " .. table.concat(extra, ", ")) end
		for _, name in ipairs(LISTS.shift) do
			local f = _G[name]
			local st = f and shiftState[f]
			local c = f and contested[f]
			print("  " .. name .. ": " .. (not f and "no frame with that name" or (c and c.off and "left alone, another addon keeps moving it back")
				or (st and ("shifted by " .. (st.wx or 0) .. "," .. (st.wy or 0)) or "at its normal position")))
		end
		if shiftLastError then print("  last problem: " .. shiftLastError) end
	end
end

-- For the files after this one (QuietHUD.toc).
ns.tickShift, ns.restoreShift, ns.shiftNow, ns.shiftReport = tickShift, restoreShift, shiftNow, shiftReport
