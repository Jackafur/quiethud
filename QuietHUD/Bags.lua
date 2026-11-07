-- Open bags. The default UI stacks the open bag windows from a corner of the screen and does not let you move them: the first
-- window is anchored to the screen and each next one sits on top of the one before. So moving the first window's anchor moves
-- the whole stack. Dragging any open bag (by its title bar or an empty part of it) moves them all together, and where you put
-- them is remembered (bagX, bagY). The offset is added after the game has placed the windows, and never twice. Nothing is
-- moved during combat; it is applied afterwards. The opacity of the open bags is the Opacity page slider (bagAlpha). The bags
-- never go past the edge of the screen (a saved spot off the screen would leave them out of reach): see keepOnScreen.
-- Moving them is an Extras option, off by default (moveBags), and QuietHUD never moves them while BlizzMove is loaded:
-- BlizzMove puts the first bag back at its own spot whenever anything else moves it, so the two would fight over it (bags
-- stuck, jumping around or going off the screen). With moving off, only the opacity is applied.
local _, ns = ...
local DB, settingChanged = ns.DB, ns.settingChanged

local resetBagPosition -- puts the open bags back where the game places them (set in the block below)
do
	local dragging
	local shownX, shownY -- the offset the bags are at now, after keepOnScreen (nil when no bag window was moved)
	local dragDriver = CreateFrame("Frame")

	local function bagFrames()
		local list = {}
		for i = 1, (NUM_CONTAINER_FRAMES or 13) do
			local f = _G["ContainerFrame" .. i]
			if f then list[#list + 1] = f end
		end
		if ContainerFrameCombinedBags then list[#list + 1] = ContainerFrameCombinedBags end
		return list
	end

	local function blizzMoveLoaded()
		local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
		if not isLoaded then return false end
		local ok, loaded = pcall(isLoaded, "BlizzMove")
		return ok and loaded and true or false
	end

	-- With QuietHUD switched off the bags go back to the game's spot and full opacity (the saved spot and opacity are kept).
	local function canMoveBags()
		return DB.enabled and DB.moveBags and not blizzMoveLoaded()
	end

	local function bagOpacity()
		if not DB.enabled then return 1 end
		local a = DB.bagAlpha or 1
		if a <= 0 then return DB.base or 0.75 end -- 0 is Global: the "When active" opacity
		return math.max(a, 0.1)
	end

	-- Moves the bag windows by (dx, dy) from where the game put them. Returns how big one unit of that offset is on the screen (in
	-- UIParent units), or nil when no open window was moved.
	local function placeBags(dx, dy)
		local unit
		for _, f in ipairs(bagFrames()) do
			local ok, point, rel, relPoint, x, y = pcall(f.GetPoint, f, 1)
			if ok and point and type(x) == "number" then
				rel = rel or f:GetParent()
				-- Only a window anchored to the screen side (the first open bag) is moved; the game hangs all the others from it.
				if rel == f:GetParent() or rel == UIParent then
					local applied = f.qhApplied
					if not (applied and applied.rel == rel and math.abs(x - applied.x) < 0.01 and math.abs(y - applied.y) < 0.01) then
						f.qhBase = { point = point, rel = rel, relPoint = relPoint, x = x, y = y } -- the game placed it: its normal spot
					end
					local base = f.qhBase
					local nx, ny = base.x + dx, base.y + dy
					if math.abs(x - nx) > 0.01 or math.abs(y - ny) > 0.01 then
						f:ClearAllPoints()
						f:SetPoint(base.point, base.rel, base.relPoint, nx, ny)
					end
					f.qhApplied = { rel = rel, x = nx, y = ny }
					local ui = UIParent:GetEffectiveScale()
					if ui and ui > 0 and f:IsShown() then unit = f:GetEffectiveScale() / ui end
				else
					f.qhBase, f.qhApplied = nil, nil
				end
			end
		end
		return unit
	end

	-- How far the open bags stick out past the edges of the screen, as the move (in UIParent units) that brings them back in. A
	-- stack wider or taller than the screen keeps its left and top edges on the screen, where the title bars are.
	local function overflow()
		local ui, w, h = UIParent:GetEffectiveScale(), UIParent:GetWidth(), UIParent:GetHeight()
		if not (ui and ui > 0 and w and w > 0 and h and h > 0) then return 0, 0 end
		local l, r, b, t
		for _, f in ipairs(bagFrames()) do
			if f:IsShown() then
				local fl, fr, fb, ft = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
				if fl and fr and fb and ft then
					local k = f:GetEffectiveScale() / ui
					l, r = math.min(l or fl * k, fl * k), math.max(r or fr * k, fr * k)
					b, t = math.min(b or fb * k, fb * k), math.max(t or ft * k, ft * k)
				end
			end
		end
		if not l then return 0, 0 end
		local cx, cy = 0, 0
		if r - l > w or l < 0 then cx = -l elseif r > w then cx = w - r end
		if t - b > h or t > h then cy = h - t elseif b < 0 then cy = -b end
		return cx, cy
	end

	-- The offset after moving it by c to stay on the screen. Only an offset you made is changed, and never past 0: where the game
	-- itself puts the bags is left alone.
	local function keepOnScreen(offset, c)
		if offset == 0 or c == 0 then return offset end
		local n = offset + c
		if (offset > 0 and n < 0) or (offset < 0 and n > 0) then return 0 end
		return n
	end

	-- Moving switched off (or BlizzMove loaded): a window QuietHUD moved and nothing has moved since goes back to the game's spot,
	-- and QuietHUD forgets it. One that something else has moved since is left where it is.
	local function releaseBags()
		for _, f in ipairs(bagFrames()) do
			local base, applied = f.qhBase, f.qhApplied
			if base and applied then
				local ok, _, rel, _, x, y = pcall(f.GetPoint, f, 1)
				if ok and rel == applied.rel and type(x) == "number" and math.abs(x - applied.x) < 0.01 and math.abs(y - applied.y) < 0.01 then
					f:ClearAllPoints()
					f:SetPoint(base.point, base.rel, base.relPoint, base.x, base.y)
				end
			end
			f.qhBase, f.qhApplied = nil, nil
		end
		shownX, shownY = nil, nil
	end

	local function applyBags()
		local alpha = bagOpacity()
		-- (nothing is moved during combat; this runs again when it ends)
		if not InCombatLockdown() then
			if not canMoveBags() then
				releaseBags()
			else
				local dx, dy = DB.bagX or 0, DB.bagY or 0
				local unit = placeBags(dx, dy)
				shownX, shownY = nil, nil
				if unit and unit > 0 then
					local cx, cy = overflow()
					local nx, ny = keepOnScreen(dx, cx / unit), keepOnScreen(dy, cy / unit)
					if nx ~= dx or ny ~= dy then placeBags(nx, ny) end
					shownX, shownY = nx, ny
				end
				-- The title bar takes the mouse only while QuietHUD moves the bags (the windows themselves always do).
				for _, f in ipairs(bagFrames()) do
					local title = f.TitleContainer
					if not f.qhTitleMouse and title and title.EnableMouse then
						title:EnableMouse(true)
						f.qhTitleMouse = true
					end
				end
			end
		end
		for _, f in ipairs(bagFrames()) do
			if alpha ~= 1 or f.qhAlpha then
				f:SetAlpha(alpha)
				f.qhAlpha = alpha ~= 1
			end
		end
	end

	local function endDrag()
		if not dragging then return end
		dragging = nil
		dragDriver:SetScript("OnUpdate", nil)
		settingChanged()
	end

	local function dragStep()
		if not dragging then return end
		if not IsMouseButtonDown("LeftButton") then
			endDrag()
			return
		end
		local cx, cy = GetCursorPosition()
		local scale = dragging.frame:GetEffectiveScale()
		if scale and scale > 0 then
			DB.bagX = dragging.x0 + (cx - dragging.cx) / scale
			DB.bagY = dragging.y0 + (cy - dragging.cy) / scale
			applyBags()
			-- Held at the edge of the screen: the drag goes on from where they stopped, so moving back moves them straight away,
			-- and the spot that is saved is on the screen.
			if shownX and (shownX ~= DB.bagX or shownY ~= DB.bagY) then
				dragging.x0 = dragging.x0 + shownX - DB.bagX
				dragging.y0 = dragging.y0 + shownY - DB.bagY
				DB.bagX, DB.bagY = shownX, shownY
			end
		end
	end

	local function startDrag(frame, button)
		if button ~= "LeftButton" or InCombatLockdown() or not canMoveBags() then return end
		local cx, cy = GetCursorPosition()
		dragging = { frame = frame, cx = cx, cy = cy, x0 = DB.bagX or 0, y0 = DB.bagY or 0 }
		dragDriver:SetScript("OnUpdate", dragStep)
	end

	-- The hooks stay for the whole session (a hook cannot be taken off); with moving off they only keep the opacity.
	local function hookFrame(f)
		if f.qhHooked then return end
		f.qhHooked = true
		f:HookScript("OnMouseDown", function(self, button) startDrag(self, button) end)
		f:HookScript("OnMouseUp", endDrag)
		f:HookScript("OnShow", function(self)
			local alpha = bagOpacity()
			if alpha ~= 1 then self:SetAlpha(alpha) end
			if C_Timer and C_Timer.After then C_Timer.After(0, applyBags) end
		end)
		local title = f.TitleContainer
		if title and title.HookScript then
			title:HookScript("OnMouseDown", function(_, button) startDrag(f, button) end)
			title:HookScript("OnMouseUp", endDrag)
		end
	end

	-- Applies the bag settings. (Called after every settings change and when a drag ends.)
	ns.applyExtras = applyBags

	-- The Reset position button (the opacity is left as it is; /qhud bags reset puts both back).
	resetBagPosition = function()
		DB.bagX, DB.bagY = 0, 0
		applyBags()
	end

	local bagEvents = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
		pcall(bagEvents.RegisterEvent, bagEvents, e)
	end
	bagEvents:SetScript("OnEvent", function()
		for _, f in ipairs(bagFrames()) do pcall(hookFrame, f) end
		applyBags()
	end)
	-- The game lays the windows out again whenever a bag opens or closes.
	if UpdateContainerFrameAnchors then
		hooksecurefunc("UpdateContainerFrameAnchors", function() applyBags() end)
	end
	for _, f in ipairs(bagFrames()) do pcall(hookFrame, f) end
end

-- For the files after this one (QuietHUD.toc).
ns.resetBagPosition = resetBagPosition
