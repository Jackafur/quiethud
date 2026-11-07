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

	local function syncShift()
		if InCombatLockdown() then return end
		local listed, frames = {}, {}
		for _, name in ipairs(LISTS.shift) do
			local f = _G[name]
			if f and f.GetNumPoints and f.GetPoint and not (f.IsForbidden and f:IsForbidden()) and not listed[f] then
				listed[f] = true
				frames[#frames + 1] = { f, name }
			end
		end
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

	shiftNow = function()
		shiftNextAt = 0
	end

	shiftReport = function()
		print("QuietHUD pixel shift (experimental): " .. (DB.pixelShift and (DB.enabled and "on" or "on, but QuietHUD is switched off") or "off") .. ", offset now " .. shiftWantX .. "," .. shiftWantY .. " pixels, a move every " .. (DB.shiftMinutes or 3) .. " minutes, /qhud shift on, off or now")
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
