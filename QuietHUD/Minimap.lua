-- The minimap: faded through its mask (or a dark layer) while the cluster stays solid, its parts faded one by one, and shrunk
-- to almost nothing when it is faded out.
local _, ns = ...
local DB, LISTS, woc = ns.DB, ns.LISTS, ns.woc
local applyList = ns.applyList

-- A short log of the minimap decisions, saved with the settings on /reload. It is kept even without debug mode,
-- so a minimap that does not show can be diagnosed afterwards.
local function mapLog(msg)
	DB.mapLog = DB.mapLog or {}
	DB.mapLog[#DB.mapLog + 1] = string.format("%.1f %s", GetTime(), msg)
	if #DB.mapLog > 80 then table.remove(DB.mapLog, 1) end
end

local applyMap, refreshMapMask
do
	-- At partial opacity the game draws a blank map in cities and interiors, so the minimap cluster is never faded
	-- with its own opacity. The map itself is faded with its mask instead (see applyMinimapMask), or, for the "darken it"
	-- option, with a black overlay on the map (which also dims the player and quest arrows the game draws on it). The other
	-- parts of the cluster are faded one by one. The cluster and the frames the map sits in keep opacity 1.
	local mapOverlay, mapParts, mapPartSet, mapDimApplied, mapAncestors, mapCover
	local mapDimFloor = 0 -- (the darkened map's own Faded the dark layer was last set with, see applyMinimapAlpha)
	local mapDimPartsAt = 0 -- (the dark layer's next look at the parts, see applyMinimapAlpha)
	-- An addon that sets a part's opacity while the map is faded (RestedXP sets its step pin again as it redraws) would
	-- show it at that opacity until the next half-second pass, which looks like blinking. So each part's SetAlpha is hooked
	-- once, and an outside change is adopted as the part's own opacity and multiplied at once, before the frame is drawn.
	local mapFactor, mapBusy = nil, false
	local mapHooked = setmetatable({}, { __mode = "k" })
	-- A part is on the map while its parent is the minimap, the cluster or a frame between them. Questie takes its minimap
	-- icons and its world map icons from one pool, so an icon faded here can turn up on the world map later.
	local function onMap(part)
		local ok, p = pcall(part.GetParent, part)
		return ok and p ~= nil and (p == Minimap or p == MinimapCluster or (mapAncestors and mapAncestors[p])) and true or false
	end
	local function keepMapPart(part, a)
		if mapBusy or not mapFactor or not mapParts or type(a) ~= "number" or (issecretvalue and issecretvalue(a))
			or not onMap(part) then return end
		if mapPartSet[part] and math.abs(a - mapPartSet[part]) < 0.01 then return end
		mapParts[part] = a
		local want = a * mapFactor
		mapBusy = true
		pcall(part.SetAlpha, part, want)
		mapBusy = false
		mapPartSet[part] = want
	end
	-- A faded part that is moved off the map gets its own opacity back (unless its owner has set one since) and is let go.
	local function leftMapPart(part)
		if mapBusy or not mapParts or mapParts[part] == nil or onMap(part) then return end
		if mapPartSet[part] and math.abs(part:GetAlpha() - mapPartSet[part]) < 0.01 then
			mapBusy = true
			pcall(part.SetAlpha, part, mapParts[part])
			mapBusy = false
		end
		mapParts[part], mapPartSet[part] = nil, nil
	end

	-- The minimap's shape. Addons that change it (Leatrix Plus's square minimap, for example) say so through GetMinimapShape,
	-- which other addons read too.
	local function mapShape()
		local shapeFn = rawget(_G, "GetMinimapShape")
		if shapeFn then
			local ok, shape = pcall(shapeFn)
			if ok and type(shape) == "string" then return shape end
		end
		return "ROUND"
	end

	-- The dark layer, cut round, or square for a square minimap.
	local function getMapOverlay()
		if mapOverlay then return mapOverlay end
		local frame = CreateFrame("Frame", nil, Minimap)
		frame:SetAllPoints(Minimap)
		frame:SetFrameLevel(Minimap:GetFrameLevel() + 20)
		local round = frame:CreateTexture(nil, "OVERLAY")
		round:SetAllPoints()
		round:SetColorTexture(0, 0, 0, 1)
		if frame.CreateMaskTexture then
			local mask = frame:CreateMaskTexture()
			mask:SetAllPoints(round)
			mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			round:AddMaskTexture(mask)
		end
		local square = frame:CreateTexture(nil, "OVERLAY")
		square:SetAllPoints()
		square:SetColorTexture(0, 0, 0, 1)
		square:Hide()
		frame.round, frame.square = round, square
		frame:Hide()
		mapOverlay = frame
		return frame
	end

	local function prepMapParts()
		mapParts = mapParts or {}
		mapPartSet = mapPartSet or {}
		if not mapAncestors then
			mapAncestors = {}
			local f = Minimap:GetParent()
			while f and f ~= UIParent do
				mapAncestors[f] = true
				f = f:GetParent()
			end
		end
	end

	-- A part keeps its own opacity (remembered the first time it is faded), and the fade multiplies it. When its owner changes
	-- it while it is faded (an addon's map pin, for example), the new value is taken as its own opacity from then on.
	local function fadeMapPart(part, factor)
		local now = part:GetAlpha()
		if mapParts[part] == nil or (mapPartSet[part] and math.abs(now - mapPartSet[part]) > 0.01) then mapParts[part] = now end
		local want = mapParts[part] * factor
		if not mapHooked[part] and part.SetAlpha then
			mapHooked[part] = true
			pcall(hooksecurefunc, part, "SetAlpha", keepMapPart)
			if part.SetParent then pcall(hooksecurefunc, part, "SetParent", leftMapPart) end
		end
		-- Written on change: a part already at its opacity (every part on every half-second pass while the map holds a faded
		-- opacity) is not written again. Cost: the one opacity read above, per part per pass.
		if math.abs(now - want) > 0.001 then
			mapBusy = true
			part:SetAlpha(want)
			mapBusy = false
		end
		mapPartSet[part] = want
	end

	local function fadeMapParts(frame, factor)
		for _, child in ipairs({ frame:GetChildren() }) do
			if child ~= Minimap and child ~= mapOverlay and child ~= mapCover then
				if mapAncestors[child] then
					fadeMapParts(child, factor)
				else
					fadeMapPart(child, factor)
				end
			end
		end
		for _, region in ipairs({ frame:GetRegions() }) do fadeMapPart(region, factor) end
	end

	-- Puts back the parts' own opacity, except on a part whose owner has changed it since.
	local function restoreMapParts()
		mapFactor = nil
		for part, alpha in pairs(mapParts or {}) do
			if not (mapPartSet[part] and math.abs(part:GetAlpha() - mapPartSet[part]) > 0.01) then part:SetAlpha(alpha) end
		end
		mapParts, mapPartSet = {}, {}
	end

	-- Everything around the map at opacity a: the cluster stays at 1, its parts and the frames added to the map group fade.
	-- The cluster is written to 1 once (that releases the hold the opacity mode put on it, or the hook would dim it again),
	-- then only when the map group wrote it since (clusterFree) or its opacity is not 1 any more. Cost: one opacity read per
	-- half-second scan of the parts while the map is faded; it was a write each scan.
	local clusterFree = false
	local function fadeMapAround(a)
		local okA, ca = pcall(MinimapCluster.GetAlpha, MinimapCluster)
		if not clusterFree or not (okA and type(ca) == "number" and not (issecretvalue and issecretvalue(ca)) and ca >= 0.999) then
			woc.write(MinimapCluster, 1)
			clusterFree = true
		end
		mapFactor = a
		local ok, err = pcall(function()
			fadeMapParts(MinimapCluster, a)
			fadeMapParts(Minimap, a)
		end)
		if not ok then mapLog("could not fade the minimap parts: " .. tostring(err)) end
		for _, name in ipairs(LISTS.map) do
			local f = name ~= "MinimapCluster" and _G[name]
			if f and f.SetAlpha and (woc.owner[name] or "map") == "map" then woc.write(f, a) end
		end
		woc.applied.map = nil -- (the group's frames were set here, not by applyMapList: it writes again at the next change)
	end

	-- The frames of the map group (the cluster and anything added to the group), written when their opacity changes.
	local function applyMapList(a)
		if woc.applied.map == a then return end
		woc.applied.map = a
		applyList("map", a)
		clusterFree = false -- (the cluster is in the map group: written here)
	end

	-- Building interiors and cities (the game's rest areas: Stormwind's streets count as outdoors, but are rest areas). The map is
	-- redrawn as you move through them, so it must not be partly transparent there. Called through pcall, every frame.
	local function mapNeedsSolidAlpha()
		local okIn, indoors = pcall(IsIndoors)
		if okIn and indoors then return true end
		local okRest, resting = pcall(IsResting)
		return (okRest and resting) and true or false
	end

	local function applyMinimapAlpha(a)
		if not (Minimap and MinimapCluster) then return end
		prepMapParts()
		if a >= 0.995 then
			if mapDimApplied then
				mapDimApplied = nil
				if mapOverlay then mapOverlay:Hide() end
				restoreMapParts()
			end
			applyMapList(1)
			return
		end
		-- The parts again every half second while the opacity holds, for map pins that addons add and frames added to the map
		-- group while the map is faded (as with the mask, below).
		local now = GetTime()
		-- The darkened map's own Faded (Opacity page, 0 = Global): the dark layer never goes darker than that, so a faded
		-- map is not a black hole in the screen (a player's ask, Nov 13: on an OLED the map's circle burns in less than the
		-- rest). Only the map and the icons on it; the parts around it fade to the Global Faded as before.
		local floor = DB.mapDarkFloor
		floor = (type(floor) == "number" and floor > 0) and math.min(floor, 0.95) or 0
		if mapDimApplied and math.abs(mapDimApplied - a) < 0.004 and mapDimFloor == floor then
			if now < mapDimPartsAt then return end
			mapDimPartsAt = now + 0.5
			fadeMapAround(a)
			return
		end
		mapDimApplied, mapDimPartsAt, mapDimFloor = a, now + 0.5, floor
		local overlay = getMapOverlay()
		local square = mapShape() == "SQUARE"
		overlay.square:SetShown(square)
		overlay.round:SetShown(not square)
		overlay:SetAlpha(1 - math.max(a, floor))
		overlay:Show()
		fadeMapAround(a)
	end

	-- The game cuts the round map out of the square one with a mask image. QuietHUD swaps in one of its own masks
	-- (masks\m0.tga to m100.tga for a round minimap, s0.tga to s100.tga for a square one, in 5% steps), which have the opacity
	-- built into the image, so the map fades while every frame keeps opacity 1 and the map of a building or a city is never
	-- drawn blank (masks swapped 20 times a second while walking through Northshire Abbey never blanked the map in the
	-- game). The mask that was there before (Blizzard's, or another addon's) is put back when the map is fully
	-- shown. mapMaskStep is nil while that mask is on, the step of ours otherwise, or -1 when ours has to be set again (after
	-- the map was shrunk or moved, or something else changed the mask).
	local mapMaskOrig, mapMaskStep, mapMaskOurs, mapMaskFactor, mapMaskPartsAt, mapMaskShape = nil, nil, false, nil, 0, nil
	-- Another addon's hook can put its own mask straight back inside QuietHUD's call (Leatrix Plus's Square minimap does since
	-- 1.60.17: the parts around the map faded, the map picture never did). A mask set back inside QuietHUD's own call, while
	-- one of its faded masks is being set, can only mean that, so the first one gives the mask up for the session: the
	-- minimap fades with the dark layer instead, as if "Darken the minimap" were ticked (at login the map starts faded, so
	-- it is known from the first frame). Said once in chat and in the map log.
	local mapMaskSetting, mapMaskFading, mapMaskContested = nil, false, false
	local function maskFought(asset)
		mapMaskOrig = asset -- (the other addon's own mask: the one to put back at full)
		if mapMaskContested then return end
		mapMaskContested = true
		mapLog("another addon puts its minimap mask back whenever QuietHUD sets one (Leatrix Plus's Square minimap does): the minimap fades with the dark layer from now on")
		print("QuietHUD: another addon keeps putting the minimap mask back (Leatrix Plus's Square minimap does), so the minimap fades with the dark layer instead.")
	end

	-- The mask to put back: the last one another addon set, or else the game's round one, or a plain square for a square
	-- minimap whose addon set its mask before QuietHUD was loaded.
	local function originalMask(shape)
		if mapMaskOrig then return mapMaskOrig end
		return shape == "SQUARE" and "Interface\\ChatFrame\\ChatFrameBackground" or "ui-hud-minimap-frame-generic-mask"
	end

	-- faded: one of QuietHUD's faded masks, not the one put back at full (only those count as a fight when set back).
	local function setMapMask(asset, faded)
		mapMaskOurs, mapMaskSetting, mapMaskFading = true, asset, faded and true or false
		local ok, err = pcall(Minimap.SetMaskTexture, Minimap, asset)
		mapMaskOurs = false
		if not ok then mapLog("could not set the minimap mask: " .. tostring(err)) end
	end

	if Minimap and Minimap.SetMaskTexture then
		hooksecurefunc(Minimap, "SetMaskTexture", function(_, asset)
			if mapMaskOurs then
				if mapMaskFading and asset ~= mapMaskSetting then maskFought(asset) end
				return
			end
			mapMaskOrig = asset
			if mapMaskStep then mapMaskStep = -1 end
		end)
	end

	-- A round or a square minimap. Other shapes (SexyMap has some) keep their own mask.
	local function mapMaskUsable()
		if not (Minimap and Minimap.SetMaskTexture) then return false end
		local shape = mapShape()
		return shape == "ROUND" or shape == "SQUARE"
	end

	local function applyMinimapMask(a)
		if not (Minimap and MinimapCluster) then return end
		prepMapParts()
		local shape = mapShape()
		if a >= 0.995 then
			if mapMaskStep then
				mapMaskStep, mapMaskFactor = nil, nil
				setMapMask(originalMask(mapMaskShape or shape))
				restoreMapParts()
			end
			applyMapList(1)
			return
		end
		local level = math.max(0, math.floor(a * 20 + 0.5))
		if level ~= mapMaskStep or shape ~= mapMaskShape then
			mapMaskStep, mapMaskShape = level, shape
			local prefix = shape == "SQUARE" and "s" or "m"
			setMapMask(level >= 20 and originalMask(shape) or ("Interface\\AddOns\\QuietHUD\\masks\\" .. prefix .. level * 5 .. ".tga"), level < 20)
		end
		-- The parts again every half second, for map pins that addons add or change while the map is faded.
		local now = GetTime()
		if mapMaskFactor and math.abs(mapMaskFactor - a) < 0.004 and now < mapMaskPartsAt then return end
		mapMaskFactor, mapMaskPartsAt = a, now + 0.5
		fadeMapAround(a)
	end

	-- The arrow cover (a player's ask, Nov 13, the owner: "we can put on his dumb circle over the arrow"): the game's arrow
	-- ignores opacity, so on a faded map it stays bright in the middle. A small dark circle of a fixed opacity sits over it
	-- while the map is below full. It is not one of the faded parts (a cover that faded with the map would dim the arrow
	-- least when the map is faintest). Opacity 0 (Off, the default) and it is never made. Written on change.
	local coverAlpha, coverSize = nil, nil
	local function applyCover(a)
		local want = DB.mapCover
		want = (type(want) == "number" and want > 0 and a < 0.995) and math.min(want, 1) or 0
		if want == 0 then
			if mapCover and coverAlpha ~= 0 then mapCover:Hide() coverAlpha = 0 end
			return
		end
		if not mapCover then
			mapCover = CreateFrame("Frame", nil, Minimap)
			mapCover:SetPoint("CENTER", Minimap, "CENTER")
			mapCover:SetFrameLevel(Minimap:GetFrameLevel() + 21)
			local tex = mapCover:CreateTexture(nil, "OVERLAY")
			tex:SetAllPoints()
			tex:SetColorTexture(0, 0, 0, 1)
			if mapCover.CreateMaskTexture then
				local mask = mapCover:CreateMaskTexture()
				mask:SetAllPoints(tex)
				mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				tex:AddMaskTexture(mask)
			end
		end
		local size = DB.mapCoverSize
		size = type(size) == "number" and math.max(4, math.min(size, 64)) or 20
		if size ~= coverSize then mapCover:SetSize(size, size) coverSize = size end
		if want ~= coverAlpha then
			mapCover:SetAlpha(want)
			mapCover:Show()
			coverAlpha = want
		end
	end

	-- How the minimap is faded: with the mask; with the dark layer for the "darken" option; and for a minimap that is neither
	-- round nor square, the dark layer in buildings and cities and plain opacity in the open world.
	local mapMode
	applyMap = function(a)
		local mode = "alpha"
		if DB.mapDarken or mapMaskContested then
			mode = "dark"
		elseif mapMaskUsable() then
			mode = "mask"
		elseif mapNeedsSolidAlpha() then
			mode = "dark"
		end
		if mode ~= mapMode then
			mapLog("minimap fades with " .. (mode == "mask" and "its mask" or mode == "dark" and "the dark layer" or "its opacity"))
			mapMode = mode
			woc.applied.map = nil -- (each mode sets the group's frames its own way: written again)
		end
		if mode ~= "mask" and mapMaskStep then applyMinimapMask(1) end
		if mode ~= "dark" and mapDimApplied then applyMinimapAlpha(1) end
		applyCover(a)
		if mode == "mask" then
			applyMinimapMask(a)
		elseif mode == "dark" then
			applyMinimapAlpha(a)
		else
			applyMapList(a)
		end
	end

	-- After the map was shrunk or moved: our mask, if it is on, is set again at the next update.
	refreshMapMask = function()
		if mapMaskStep then mapMaskStep = -1 end
	end
end
-- A faded-out minimap is shrunk to almost nothing (see below), so its own rectangle can no longer be hovered. The rectangle
-- it has at full size is remembered, and the mouse is compared with that one instead. The values are in UIParent units.
ns.mapRect = nil
local function rememberMapRect()
	local f = MinimapCluster
	if not (f and f.GetRect and f:GetScale() > 0.5) then return end
	local l, b, w, h = f:GetRect()
	if not (l and b and w and h and w > 20 and h > 20) then return end
	local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
	ns.mapRect = { l * k, b * k, (l + w) * k, (b + h) * k }
end
local function mouseInMapRect()
	if not ns.mapRect or not GetCursorPosition then return false end
	local x, y = GetCursorPosition()
	local k = UIParent:GetEffectiveScale()
	x, y = x / k, y / k
	return x >= ns.mapRect[1] and x <= ns.mapRect[3] and y >= ns.mapRect[2] and y <= ns.mapRect[4]
end

-- Hiding the Minimap frame and showing it again breaks the map in cities and interiors (it does not come back until
-- the game redraws it), and the player arrow, quest arrow and quest-area overlays ignore opacity, so a faded minimap
-- can be neither hidden nor made transparent. Instead it is shrunk to almost nothing, which takes those along, and
-- put back to its size when it is wanted again. The frame itself is never hidden.
ns.mapSavedScale = nil

-- Shrinking the minimap has a side effect on other addons that put frames on it: text is measured in whole pixels, so a
-- label measured while the minimap is shrunk comes out thousands of units wide (RestedXP's step pins ended up 6670 wide).
-- When the minimap comes back, that oversized frame sits invisibly over a large part of the screen, takes the mouse and
-- swallows right-clicks that should turn the camera. So whenever the minimap comes back, any frame on it that is much
-- bigger than the minimap itself is cut down to a small hover target (its own owner sets the size again the next time it
-- redraws it, and by then the minimap is not shrunk). Frames of any addon are treated the same, and nothing is switched
-- off, so a pin still shows its tooltip when the mouse is on it.
local function guardOversizedMinimapKids()
	if not (Minimap and Minimap.GetChildren) then return end
	local okKids, kids = pcall(function() return { Minimap:GetChildren() } end)
	if not okKids then return end
	for _, f in ipairs(kids) do
		local okBig, big = pcall(function()
			return f.SetSize and f:GetWidth() * f:GetEffectiveScale() > Minimap:GetWidth() * Minimap:GetEffectiveScale() * 1.5
		end)
		-- (not a protected frame in a fight: the game would refuse it; the grow at a fight's start runs this 0.5 s into it)
		if okBig and big and not (InCombatLockdown and InCombatLockdown() and f.IsProtected and f:IsProtected()) then
			pcall(f.SetSize, f, 24, 24)
			local okT, owner = pcall(function() return GameTooltip:IsShown() and GameTooltip:GetOwner() end)
			if okT and owner == f then GameTooltip:Hide() end
		end
	end
end

-- In a fight the game refuses an addon's SetScale on the minimap (its cluster is protected then: "QuietHUD tried to call the
-- protected function MinimapCluster:SetScaleBase()"), and the minimap stayed shrunk, gone, for the whole fight; worse, the
-- refused grow-back was taken as done, so the next fade saved the tiny scale as the real one and the minimap stayed gone
-- until a /reload. So in a fight nothing is scaled and this returns false: the loop asks again on its next update, and the
-- fight's end wakes it. A minimap the fight brings up is grown back as the fight starts (PLAYER_REGEN_DISABLED, the last
-- moment the game still allows it; see Loop.lua).
local function canScaleMap()
	return not (InCombatLockdown and InCombatLockdown() and MinimapCluster.IsProtected and MinimapCluster:IsProtected())
end
-- The plain SetScaleBase, not Edit Mode's SetScale: Edit Mode's moves the cluster's anchors through its own SetPoint, which
-- marks its layout changed, and can run ManageFramePositions, all in QuietHUD's name (the kind of thing that got
-- MultiBarRight:SetPointBase() blocked on Nov 5, see the pixel shift). The minimap always grows back to exactly the scale it
-- was shrunk from, so its anchors never need moving. (ChatGPT's audit of Nov 6, question 2.)
local function setMapScale(s)
	if MinimapCluster.SetScaleBase then MinimapCluster:SetScaleBase(s) else MinimapCluster:SetScale(s) end
end

local function setMinimapVisible(visible, alpha)
	if not MinimapCluster then return true end
	if not canScaleMap() then return false end
	if visible then
		if ns.mapSavedScale then
			setMapScale(ns.mapSavedScale)
			ns.mapSavedScale = nil
			guardOversizedMinimapKids()
			-- Our mask is set again at its new size, now and once more when the size has settled.
			refreshMapMask()
			if C_Timer and C_Timer.After then
				C_Timer.After(0.5, function()
					guardOversizedMinimapKids()
					refreshMapMask()
				end)
			end
		end
	else
		pcall(rememberMapRect)
		if not ns.mapSavedScale then ns.mapSavedScale = MinimapCluster:GetScale() end
		setMapScale(0.001)
	end
	mapLog(string.format("minimap %s (cluster alpha %.2f, scale %.3f)", visible and "shown" or "hidden", alpha or -1,
		MinimapCluster:GetScale()))
	return true
end

-- For the files after this one (QuietHUD.toc).
ns.mapLog, ns.applyMap, ns.refreshMapMask, ns.rememberMapRect = mapLog, applyMap, refreshMapMask, rememberMapRect
ns.mouseInMapRect, ns.setMinimapVisible, ns.canScaleMap, ns.setMapScale = mouseInMapRect, setMinimapVisible, canScaleMap, setMapScale
