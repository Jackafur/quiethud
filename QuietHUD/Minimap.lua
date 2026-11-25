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
	-- Forever Dual Gathering takes the map out of the cluster for its scans (see mapMoved, below). mapLifted: the map is out;
	-- mapBackAt: the time of the frame it was handed back in (what it puts back in that frame is its saved copy, not news).
	local mapLifted, mapBackAt = false, nil
	local function mapOut() return mapLifted or mapBackAt == GetTime() end
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
		-- (not while Forever Dual Gathering has the map out, or as it hands it back: it hides the clock and others for its
		-- scan, then puts back the faded opacity it saved, which is not their own; see mapMoved)
		if mapBusy or not mapFactor or not mapParts or type(a) ~= "number" or (issecretvalue and issecretvalue(a))
			or not onMap(part) or mapOut() then return end
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

	-- Every part of a frame: its regions, and its child frames except the map and our own layers (the frames between the
	-- cluster and the map are gone through, not taken as parts).
	local function eachMapPart(frame, fn)
		for _, child in ipairs({ frame:GetChildren() }) do
			if child ~= Minimap and child ~= mapOverlay and child ~= mapCover then
				if mapAncestors[child] then
					eachMapPart(child, fn)
				else
					fn(child)
				end
			end
		end
		for _, region in ipairs({ frame:GetRegions() }) do fn(region) end
	end
	local function fadeMapParts(frame, factor)
		eachMapPart(frame, function(part) fadeMapPart(part, factor) end)
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
		-- (not while Forever Dual Gathering has the map out: it hides some parts for its scan; mapMoved puts them back after)
		local ok, err = true, nil
		if not mapLifted then
			ok, err = pcall(function()
				fadeMapParts(MinimapCluster, a)
				fadeMapParts(Minimap, a)
			end)
		end
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
		-- (never above the map's up opacity: a Faded over the Shown would stop the map fading and make it brighter when up;
		-- audit Nov 13)
		floor = math.min(floor, woc.mapPeak or 1)
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
			-- (set while Forever Dual Gathering has the map out, or put back as it hands it over: the faded mask of ours it saved
			-- at the start, not the map's own; ours is set again at the next update)
			if mapOut() then
				if mapMaskStep then mapMaskStep = -1 end
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
				-- (while Forever Dual Gathering has the map out the mask waits: mapMaskStep stays, so it is set at the hand-back)
				if not mapLifted then
					mapMaskStep, mapMaskFactor = nil, nil
					setMapMask(originalMask(mapMaskShape or shape))
				end
				restoreMapParts()
			end
			applyMapList(1)
			return
		end
		local level = math.max(0, math.floor(a * 20 + 0.5))
		if (level ~= mapMaskStep or shape ~= mapMaskShape) and not mapLifted then
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

	-- Our own player arrow, for Questie players (the owner, Nov 13: "so lets draw our own mini map marker?"). The game draws
	-- its arrow and its other icons on the map (quest givers, herbs and ore, party members) itself, and they ignore opacity and
	-- the mask; its only control over them is Minimap:SetIconScale, which sizes them all at once. With /qhud myarrow on
	-- (mapArrow, off by default; a command only, no box, so nobody misses their herbs by accident) and Questie loaded,
	-- while the map is below full opacity (fading, or up at a Shown below 1: the owner's map is up at 0.65 and fades out in 0.35 seconds, so an
	-- arrow only while it fades was never seen) the game's icons are sized to nothing and this arrow stands in for the
	-- game's. It is a child of the map like a pin, so it fades with the other parts; Questie's own minimap icons (its "!" and "?", addon frames) fade with them too,
	-- so the quest givers stay on the map. Tried once before (Oct 22) and taken out: without Questie the quest "!" was lost
	-- (the game tells addons nothing about quest givers). Not with the dark layer (it dims the game's icons), not at full
	-- opacity, and not where the game does not say which way you face (GetPlayerFacing is nil in dungeons).
	-- Cost: while the arrow shows, one GetPlayerFacing per map update, and every frame only while you turn (the turning and
	-- mouse-look messages) or have lost control of your character (a flight, a fear).
	local ARROW_SIZE = 32 -- (a guess at the game's arrow at icon size 1, to be matched in game)
	local arrow, arrowOn, arrowFacing, iconsSetting, iconScale, questie = nil, false, nil, false, nil, nil
	local iconStep, iconsShrunk = nil, false -- (the game's icons sized with the fade while our arrow is not up: sizeIcons)
	local iconPrev, iconAt = nil, nil -- (the size before the last one taken from outside, and when: see mapMoved)
	local turning = {}

	local function questieLoaded()
		if questie == nil then
			local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
			local ok, v = pcall(isLoaded, "Questie")
			if not ok then return false end
			questie = v and true or false
		end
		return questie
	end

	-- Tracking (the owner, Nov 13: herb and ore nodes, "yellow circles with a c in them", show only while you track): while a
	-- tracking spell is on (Find Herbs, Find Minerals, Find Treasure, a hunter's tracks, Sense Demons or Undead), the game's
	-- icons stay and our arrow stands aside, so nothing you track goes missing. (Since Nov 17 they are sized with the map's
	-- fade like every game icon, sizeIcons: whole while the map is up, going out with it; the owner: "same for when it IS
	-- on".) The town ticks in the tracking menu (flight masters, innkeepers) are not spells and do not count. Read once, again only after the game says tracking changed.
	local tracking, trackingName -- (nil: read it at the next update; the spell's name, for /qhud myarrow)
	local function trackingOn()
		if tracking == nil then
			tracking = false
			local api = rawget(_G, "C_Minimap")
			local okN, n = false, nil
			if type(api) == "table" then okN, n = pcall(api.GetNumTrackingTypes) end
			if okN and type(n) == "number" then
				for i = 1, n do
					-- (a table on this client; name, texture, active, kind on older ones)
					local ok, info, _, active, kind = pcall(api.GetTrackingInfo, i)
					if ok and type(info) == "table" then active, kind = info.active, info.type end
					if ok and active and kind == "spell" then
						tracking, trackingName = true, type(info) == "table" and info.name or info
						break
					end
				end
			end
		end
		return tracking
	end

	-- The game's own icon size: the last one anyone but QuietHUD set (Edit Mode's), or else Edit Mode's setting.
	local function gameIconScale()
		if iconScale then return iconScale end
		local ok, v = pcall(function()
			local key = Enum.EditModeMinimapSetting.IconScale
			if MinimapCluster:HasSetting(key) then return MinimapCluster:GetSettingValue(key) / 100 end
		end)
		return ok and type(v) == "number" and v > 0 and v or 1
	end

	local function setIconScale(scale)
		iconsSetting = true
		if not pcall(Minimap.SetIconScale, Minimap, scale) and scale == 0 then pcall(Minimap.SetIconScale, Minimap, 0.01) end
		iconsSetting = false
	end

	local function getArrow()
		if arrow then return arrow end
		arrow = CreateFrame("Frame", nil, Minimap)
		arrow:SetPoint("CENTER", Minimap, "CENTER")
		arrow:SetFrameLevel(Minimap:GetFrameLevel() + 5)
		arrow.tex = arrow:CreateTexture(nil, "OVERLAY")
		arrow.tex:SetAllPoints()
		arrow.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
		arrow:Hide()
		return arrow
	end

	-- Its size is a setting since Nov 24 (mapArrowSize, /qhud myarrow size; the owner: "Can we just give him a smaller arrow
	-- that we draw?", "lets add the size"): a player's ask for a smaller arrow with the other icons left alone, and the way
	-- to match the guess above in game. A command like the rest of the own arrow, no bar: the arrow has no box on purpose.
	local function sizeArrow()
		local own = tonumber(DB.mapArrowSize) or ARROW_SIZE
		local size = math.max(12, math.min(own, 48)) * gameIconScale()
		getArrow():SetSize(size, size)
	end
	ns.sizeArrow = function() if arrow then sizeArrow() end end -- (for the command: the arrow, once made, at its new size)

	-- Points the arrow the way you face (straight up on a minimap that turns with you). False where the game does not say.
	local function turnArrow()
		local ok, facing = pcall(GetPlayerFacing)
		if not (ok and type(facing) == "number") then return false end
		local okR, rotates = pcall(C_CVar.GetCVarBool, "rotateMinimap")
		if okR and rotates then facing = 0 end
		if facing ~= arrowFacing then
			arrowFacing = facing
			getArrow().tex:SetRotation(facing)
		end
		return true
	end

	if Minimap and Minimap.SetIconScale then
		hooksecurefunc(Minimap, "SetIconScale", function(_, scale)
			if iconsSetting or type(scale) ~= "number" then return end
			-- (Forever Dual Gathering's scan hides the icons, and as it hands the map back it puts back the size it saved at
			-- the start, which was QuietHUD's shrunk one: not the icons' own size; ours is set again at the next update)
			if mapOut() then
				iconStep = nil
				if arrowOn and not mapLifted then setIconScale(0) end -- (handed back with our arrow up: the game's stay off)
				return
			end
			iconPrev, iconAt = iconScale, GetTime()
			iconScale = scale
			iconStep = nil -- (Edit Mode set a size: the shrink goes on from that one at the next update)
			if arrowOn then -- (Edit Mode set a size while the map is faded: the game's icons stay off, ours takes the size)
				sizeArrow()
				setIconScale(0)
			end
		end)
	end

	-- Every frame only while you turn: the game says when turning with the keys or the mouse starts and stops, and when it
	-- takes control of your character.
	local arrowDriver = CreateFrame("Frame")
	local turnEvents = {
		PLAYER_STARTED_TURNING = "keys", PLAYER_STOPPED_TURNING = "keys",
		PLAYER_STARTED_LOOKING = "mouse", PLAYER_STOPPED_LOOKING = "mouse",
		PLAYER_CONTROL_LOST = "control", PLAYER_CONTROL_GAINED = "control",
	}
	local function watchTurning()
		arrowDriver:SetScript("OnUpdate", (arrowOn and next(turning)) and turnArrow or nil)
	end
	local watchDots -- (the party dots, below)
	arrowDriver:SetScript("OnEvent", function(_, event)
		if event == "GROUP_ROSTER_UPDATE" then if watchDots then watchDots() end return end
		if event == "MINIMAP_UPDATE_TRACKING" then tracking = nil return end -- (the map group is applied every update: it follows)
		turning[turnEvents[event]] = (event:find("STARTED", 1, true) or event:find("LOST", 1, true)) and true or nil
		if arrowOn then turnArrow() end
		watchTurning()
	end)
	for e in pairs(turnEvents) do pcall(arrowDriver.RegisterEvent, arrowDriver, e) end

	-- Party and raid dots of our own while the game's icons are off (the owner, Nov 13: "can we draw the party dots to"):
	-- the game says where group members are in the open world (UnitPosition), so each gets a dot in its class colour at its
	-- spot, placed the way HereBeDragons places map pins (yards from you over the map's view radius). Children of the map
	-- like the arrow, so they fade with it. Someone past the edge is not shown. Cost: a pass ten times a second, only while
	-- our arrow shows and you are in a group.
	local dots, dotTicker = {}, nil
	-- /qhud myarrow test (the owner, Nov 13: "can you do a test party to see"): for 30 seconds our arrow shows and four
	-- made-up members stand around you (yards from you, the way UnitPosition gives them), so the sizes can be seen solo.
	local testUntil
	local TEST_PARTY = { { 30, 0, "MAGE" }, { 0, -40, "WARRIOR" }, { -25, 25, "PRIEST" }, { 45, 35, "HUNTER" } }
	local DOT_SIZE = 18 -- (the owner, Nov 13, after the test party: 10 "kinda small", then 13, 15, then his "do 18")
	local function getDot(i)
		if dots[i] then return dots[i] end
		local d = CreateFrame("Frame", nil, Minimap)
		d:SetSize(DOT_SIZE, DOT_SIZE)
		d:SetFrameLevel(Minimap:GetFrameLevel() + 4)
		d.tex = d:CreateTexture(nil, "OVERLAY")
		d.tex:SetAllPoints()
		d.tex:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
		d:Hide()
		dots[i] = d
		-- (a new dot takes the map's opacity at once, not at the next pass over the parts)
		if mapFactor and mapParts then pcall(fadeMapPart, d, mapFactor) end
		return d
	end
	local function hideDots(from)
		for i = from or 1, #dots do dots[i]:Hide() end
	end
	local function placeDots()
		local okP, py, px, _, pInst = pcall(UnitPosition, "player")
		local okR, radius = pcall(function() return C_Minimap.GetViewRadius() end)
		if not (okP and px and py and okR and type(radius) == "number" and radius > 0) then hideDots() return end
		local w, h = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
		local okRot, rotates = pcall(function() return C_CVar.GetCVarBool("rotateMinimap") end)
		local sinF, cosF
		if okRot and rotates then
			local okF, facing = pcall(GetPlayerFacing)
			if not (okF and type(facing) == "number") then hideDots() return end
			sinF, cosF = math.sin(facing), math.cos(facing)
		end
		local square = mapShape() == "SQUARE"
		local testing = testUntil and GetTime() < testUntil
		local raid = not testing and IsInRaid and IsInRaid()
		local n = testing and #TEST_PARTY or raid and GetNumGroupMembers() or GetNumSubgroupMembers()
		local used = 0
		for i = 1, n do
			local unit = (raid and "raid" or "party") .. i
			if testing or not UnitIsUnit(unit, "player") then
				local fake = testing and TEST_PARTY[i]
				local ok, uy, ux, _, uInst
				if fake then ok, uy, ux, uInst = true, py - fake[2], px - fake[1], pInst
				else ok, uy, ux, _, uInst = pcall(UnitPosition, unit) end
				if ok and ux and uy and uInst == pInst then
					local xd, yd = px - ux, py - uy
					if sinF then xd, yd = xd * cosF - yd * sinF, xd * sinF + yd * cosF end
					local dx, dy = xd / radius, yd / radius
					local dist = square and math.max(dx * dx, dy * dy) or (dx * dx + dy * dy)
					if dist <= 0.81 then
						used = used + 1
						local d = getDot(used)
						local class = fake and fake[3] or select(2, UnitClass(unit))
						local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
						if c then d.tex:SetVertexColor(c.r, c.g, c.b) else d.tex:SetVertexColor(1, 1, 1) end
						d:ClearAllPoints()
						d:SetPoint("CENTER", Minimap, "CENTER", dx * w, -dy * h)
						d:Show()
					end
				end
			end
		end
		hideDots(used + 1)
	end
	watchDots = function()
		local want = arrowOn and ((testUntil and GetTime() < testUntil) or (IsInGroup and IsInGroup()))
		if want and not dotTicker then
			placeDots()
			dotTicker = C_Timer.NewTicker(0.1, placeDots)
		elseif not want and dotTicker then
			dotTicker:Cancel()
			dotTicker = nil
			hideDots()
		end
	end
	pcall(arrowDriver.RegisterEvent, arrowDriver, "GROUP_ROSTER_UPDATE")
	pcall(arrowDriver.RegisterEvent, arrowDriver, "MINIMAP_UPDATE_TRACKING")

	local function showArrow(want)
		if want and not turnArrow() then want = false end
		if want == arrowOn then return end
		arrowOn = want
		iconStep, iconsShrunk = nil, false -- (the arrow sets the icons' size itself; the shrink starts again from it)
		if want then
			sizeArrow()
			getArrow():Show()
			setIconScale(0)
		else
			getArrow():Hide()
			setIconScale(gameIconScale())
		end
		mapLog(want and "QuietHUD's arrow stands in for the game's minimap icons" or "the game's minimap icons are back")
		watchTurning()
		watchDots()
	end

	-- Without our arrow up (the command off, a tracking spell on, no Questie), the game's icons on the map (your arrow, town
	-- icons, party members, what you track) ignore opacity and the mask, so they stayed whole while the map faded and went only
	-- when it was gone. Their size is the one control, so while the map fades they are sized with it: whole at the map's up
	-- opacity, gone at 0, going out together with the map (the owner, Nov 17: "if myarrow isnt on i want the icons and the map
	-- to fade at the same time", "that should always be like that"). Not with the dark layer, which dims them already. Put back
	-- only after QuietHUD changed it. Cost: in 20 steps, written on change, so at most 20 calls a fade, none while it holds.
	-- "Shrink its icons" unticked (mapShrinkIcons, Nov 24, a player who keeps the map faded at 0.35 and still reads it: his
	-- quest icons sat at a third of their size; the owner: "yea lets make a tick box for it then"): the icons stay whole while
	-- any of the map shows and go only with it, as before 1.7.4. The box is on the minimap's row of the Faded per element
	-- list (Config.lua) and counts only while the minimap is on that list: off the list there is no box, so no effect.
	local function sizeIcons(a, mode)
		local peak = woc.mapPeak or 1
		local share = (mode ~= "dark" and peak > 0) and math.max(0, math.min(1, a / peak)) or 1
		local step = math.floor(share * 20 + 0.5)
		if step > 0 and DB.mapShrinkIcons == false and (DB.fdMap or -1) >= 0 then step = 20 end -- (whole until the map is gone)
		if step == iconStep then return end
		iconStep = step
		if step >= 20 then
			if iconsShrunk then setIconScale(gameIconScale()) end
			iconsShrunk = false
		else
			setIconScale(gameIconScale() * step / 20)
			iconsShrunk = true
		end
	end

	-- The arrow cover (a player's ask, Nov 13, the owner: "we can put on his dumb circle over the arrow"): the game's arrow
	-- ignores opacity, so on a faded map it stays bright in the middle. A small dark circle of a fixed opacity sits over it
	-- while the map is below full. It is not one of the faded parts (a cover that faded with the map would dim the arrow
	-- least when the map is faintest). Opacity 0 (Off, the default) and it is never made. Written on change.
	local coverAlpha, coverSize = nil, nil
	local function applyCover(a)
		local want = DB.mapCover
		-- (faded = below the map's up opacity, not below 1: with the map up at a Global Shown of 0.75 the cover stayed on;
		-- audit Nov 13)
		want = (type(want) == "number" and want > 0 and a < (woc.mapPeak or 1) - 0.005) and math.min(want, 1) or 0
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
	-- Forever Dual Gathering (2.7.0, its auto scanning): after each herb or ore switch it takes the map out of the cluster for
	-- about two seconds, invisible, to read the herbs and ore under the cursor, and draws a picture of the map in its place
	-- (FDGTerrainMinimap, set back to full opacity every tenth of a second), which showed at full over the faded map. The
	-- picture fades with the map here, its player arrow too (that ignores the picture's opacity); a set back to full is
	-- undone at once by woc.write's hook. While the map is out QuietHUD leaves the map's mask and icon size alone (the scan
	-- hides the icons), takes nothing set then as the map's own, and sets its own again once the map is back. Only while
	-- Forever Dual Gathering is loaded. Cost: a few calls per scan, when the map moves; one comparison per update while it
	-- is out.
	local mapA, standInA = nil, nil -- (the map's opacity at the last update; the picture's, last written)
	local function fadeStandIn(a)
		-- (FDG makes the picture a moment after it takes the map, on the first scan of a session: until then each update tries)
		local f = rawget(_G, "FDGTerrainMinimap")
		if type(f) ~= "table" or not f.SetAlpha then return end
		standInA = a
		woc.write(f, a)
		local ok, kids = pcall(function() return { f:GetChildren() } end)
		if not ok then return end
		for _, c in ipairs(kids) do
			local okI, own = pcall(c.IsIgnoringParentAlpha, c)
			if okI and own then woc.write(c, a) end
		end
	end
	local function underCluster()
		local f = Minimap:GetParent()
		for _ = 1, 20 do
			if not f or f == UIParent then return false end
			if f == MinimapCluster then return true end
			f = f:GetParent()
		end
		return false
	end
	-- The parts' own opacity when the map was taken out. FDG hides some of them (the clock, the calendar, the map's border)
	-- for its scan and, as it hands the map back, puts back the opacity it saved, which was QuietHUD's faded one. A frame
	-- later, when it is done, each gets its own back (faded again if the map is faded).
	local liftOwn
	local function rememberParts()
		prepMapParts()
		liftOwn = {}
		local function remember(part)
			local own = mapParts[part]
			if own == nil then
				local ok, a = pcall(part.GetAlpha, part)
				if ok and type(a) == "number" and not (issecretvalue and issecretvalue(a)) then own = a end
			end
			if own ~= nil then liftOwn[part] = own end
		end
		pcall(eachMapPart, MinimapCluster, remember)
		pcall(eachMapPart, Minimap, remember)
	end
	local function putPartsBack()
		local own = liftOwn
		liftOwn = nil
		if not own or mapLifted then return end
		mapBusy = true
		for part, a in pairs(own) do
			if mapFactor then
				mapParts[part] = a
				mapPartSet[part] = a * mapFactor
				pcall(part.SetAlpha, part, a * mapFactor)
			else
				pcall(part.SetAlpha, part, a)
			end
		end
		mapBusy = false
	end
	local fdgSaid = false
	local function mapMoved()
		local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
		local okL, fdg = pcall(isLoaded, "ForeverDualGathering")
		if not (okL and fdg) then return end
		local out = not underCluster()
		if out == mapLifted then return end
		mapLifted = out
		if out then
			-- (its scan hid the icons just before it took the map, in the same frame: that was not the icons' own size. Its HUD
			-- does not hide them, and keeps the map out for as long as it is on: there they get their own size back meanwhile)
			if iconAt == GetTime() then
				iconScale = iconPrev
				if arrowOn then sizeArrow() end -- (our arrow took that 0 as its size too)
			elseif iconsShrunk then
				setIconScale(gameIconScale())
				iconsShrunk = false
			end
			rememberParts()
			fadeStandIn(mapA or 1)
			if not fdgSaid then
				fdgSaid = true
				mapLog("Forever Dual Gathering took the minimap out for a scan: its picture of the map fades with the map")
			end
		else
			mapBackAt = GetTime()
			mapMaskStep = -1 -- (our mask, or the map's own at full, set again at the next update)
			iconStep = nil
			C_Timer.After(0, putPartsBack)
		end
		if ns.wakeLoop then ns.wakeLoop() end
	end
	if Minimap and Minimap.SetParent then hooksecurefunc(Minimap, "SetParent", mapMoved) end

	local mapMode
	applyMap = function(a)
		mapA = a
		if mapLifted and a ~= standInA then fadeStandIn(a) end
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
		-- (before the parts are faded, so a new arrow fades with them)
		-- (not while Forever Dual Gathering has the map out: its scan keeps the game's icons hidden; see mapMoved)
		if not mapLifted then
			showArrow(((testUntil and GetTime() < testUntil) or (DB.mapArrow and mode ~= "dark" and a < 0.995 and questieLoaded()
				and not trackingOn())) and true or false)
			if not arrowOn then sizeIcons(a, mode) end
		end
		if mode == "mask" then
			applyMinimapMask(a)
		elseif mode == "dark" then
			applyMinimapAlpha(a)
		else
			applyMapList(a)
		end
	end

	-- /qhud myarrow test: the arrow and the made-up party for 30 seconds, then back to what the setting says.
	ns.arrowTest = function()
		testUntil = GetTime() + 30
		if arrowOn then watchDots() end
		C_Timer.After(30.1, function()
			testUntil = nil
			if watchDots then watchDots() end
			if ns.wakeLoop then ns.wakeLoop() end
		end)
		if ns.wakeLoop then ns.wakeLoop() end
	end

	-- Why the own arrow is not showing right now, in words for the player (nil: nothing is in its way), and whether it shows
	-- (/qhud myarrow says it; the owner, Nov 24, on a flight with the game's bright arrow: "i think myarrow isnt actually on").
	-- The same conditions as applyMap's, in the order a player can do something about them.
	ns.arrowWhy = function()
		local why
		if not DB.mapArrow then
			why = "it is OFF"
		elseif not questieLoaded() then
			why = "Questie is not loaded"
		elseif DB.enabled == false then
			why = "QuietHUD is switched off"
		elseif DB.fadeMinimap == false then
			why = "Fade is unticked on the Minimap row (Elements page), so the minimap stays as the game draws it"
		elseif DB.mapDarken then
			why = "Darken the minimap is ticked (Opacity page), and the dark layer dims the game's arrow already"
		elseif mapMaskContested then
			why = "another addon holds the minimap's shape, so the minimap is darkened and the dark layer dims the game's arrow"
		elseif trackingOn() then
			why = "a tracking spell is on (" .. tostring(trackingName or "see the tracking button on the minimap")
				.. "), and it steps aside so what you track stays on the map"
		elseif mapLifted then
			why = "Forever Dual Gathering is scanning with the minimap"
		else
			local ok, facing = pcall(GetPlayerFacing)
			if not (ok and type(facing) == "number") then
				why = "the game does not say which way you face here (a dungeon or raid)"
			elseif (mapA or 1) >= 0.995 then
				why = "the minimap is at full opacity right now"
			end
		end
		return why, arrowOn
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

-- A frame placed next to the minimap in Edit Mode can end up anchored to it (Edit Mode's snapping saves the minimap cluster
-- as its anchor). Shrinking the cluster pulled such a frame along: the buffs slid right into the corner every time the faded
-- minimap shrank (Nov 8, in the WoW Forever tab). So while the map is shrunk, a frame of this short list that hangs on the
-- cluster hangs on a stand-in instead: an empty frame with the cluster's own anchors, size and full scale, so the frame sits
-- exactly where it sat and follows a UI scale or window size change the same way. When the minimap grows back its own
-- anchors are put back, unless something (Edit Mode, another addon) moved it meanwhile: then that is its place now. A frame
-- anchored anywhere else, or on a part inside the cluster, is never touched. Edit Mode lays its frames out again on a layout
-- change or a spec change without touching the cluster's scale, which hangs the buffs on the shrunk cluster again; those
-- events pin them again, with Edit Mode's new anchors as the ones put back (audit of Nov 14). The game's own SetPointBase and
-- ClearAllPointsBase, as in Shift.lua, so Edit Mode's records are not marked changed.
local pinMapNeighbours, unpinMapNeighbours
do
	local MAP_NEIGHBOURS = { "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame", "TotemFrame" }
	local mapPinned = {} -- frame -> { anchors = its own (put back), pins = what was set (still ours?) }
	local mapGhost

	local function hangsOnCluster(rel)
		for _ = 1, 8 do
			if rel == nil or rel == UIParent then return false end
			if rel == MinimapCluster then return true end
			local ok, p = pcall(rel.GetParent, rel)
			if not ok then return false end
			rel = p
		end
		return false
	end
	local function lockedFrame(f)
		return InCombatLockdown and InCombatLockdown() and f.IsProtected and f:IsProtected()
	end
	local function readAnchors(f)
		local t = {}
		for i = 1, f:GetNumPoints() do
			local p, rel, rp, x, y = f:GetPoint(i)
			t[i] = { p, rel, rp, x or 0, y or 0 }
		end
		return t
	end
	local function setAnchors(f, t)
		local clear, set = f.ClearAllPointsBase or f.ClearAllPoints, f.SetPointBase or f.SetPoint
		clear(f)
		for _, a in ipairs(t) do set(f, a[1], a[2], a[3], a[4], a[5]) end
	end
	local function stillPinned(f, rec)
		local now = readAnchors(f)
		if #now ~= #rec.pins then return false end
		for i, a in ipairs(rec.pins) do
			local b = now[i]
			if b[1] ~= a[1] or b[2] ~= a[2] or b[3] ~= a[3] or type(b[4]) ~= "number" or type(b[5]) ~= "number"
				or math.abs(b[4] - a[4]) > 0.01 or math.abs(b[5] - a[5]) > 0.01 then return false end
		end
		return true
	end

	-- The stand-in, set again at every pin (the cluster may have been moved meanwhile). nil when the cluster's anchors
	-- cannot be copied (none, or on something inside itself).
	local function placeGhost()
		local c = MinimapCluster
		local anchors = readAnchors(c)
		if #anchors == 0 then return nil end
		for _, a in ipairs(anchors) do
			if a[2] == nil then a[2] = c:GetParent() end
			if a[2] == c or hangsOnCluster(a[2]) then return nil end
		end
		if not mapGhost then mapGhost = CreateFrame("Frame", nil, UIParent) end
		mapGhost:SetParent(c:GetParent() or UIParent)
		mapGhost:SetScale(ns.mapSavedScale or c:GetScale())
		mapGhost:SetSize(c:GetWidth(), c:GetHeight())
		mapGhost:ClearAllPoints()
		for _, a in ipairs(anchors) do mapGhost:SetPoint(a[1], a[2], a[3], a[4], a[5]) end
		return mapGhost
	end

	local function pinOne(f, ghost)
		local rec = mapPinned[f]
		if rec and stillPinned(f, rec) then return end
		mapPinned[f] = nil -- (moved since, or never pinned: looked at afresh)
		local anchors, pins, onCluster = readAnchors(f), {}, false
		for i, a in ipairs(anchors) do
			if a[2] == MinimapCluster then
				onCluster = true
				pins[i] = { a[1], ghost, a[3], a[4], a[5] }
			elseif hangsOnCluster(a[2]) then
				return -- (on a part inside the cluster: no stand-in for that)
			else
				pins[i] = a
			end
		end
		if not (onCluster and ghost) then return end
		setAnchors(f, pins)
		mapPinned[f] = { anchors = anchors, pins = pins }
	end

	pinMapNeighbours = function()
		local okG, ghost = pcall(placeGhost)
		if not okG then return end
		for _, name in ipairs(MAP_NEIGHBOURS) do
			local f = _G[name]
			if f and f.GetNumPoints and not (f.IsForbidden and f:IsForbidden()) and not lockedFrame(f) then
				pcall(pinOne, f, ghost)
			end
		end
	end
	unpinMapNeighbours = function()
		for f, rec in pairs(mapPinned) do
			if not lockedFrame(f) then
				mapPinned[f] = nil
				pcall(function()
					if stillPinned(f, rec) then setAnchors(f, rec.anchors) end
				end)
			end
		end
	end

	-- Edit Mode's own handler for these lays the frames out again; the pin runs on the next frame, after it.
	local watch = CreateFrame("Frame")
	for _, e in ipairs({ "EDIT_MODE_LAYOUTS_UPDATED", "PLAYER_SPECIALIZATION_CHANGED" }) do pcall(watch.RegisterEvent, watch, e) end
	watch:SetScript("OnEvent", function()
		if not (ns.mapSavedScale and C_Timer and C_Timer.After) then return end
		C_Timer.After(0, function() if ns.mapSavedScale then pinMapNeighbours() end end)
	end)
end

-- Guild OS (since about 1.33, Nov 18) puts a row of guildmate dots under the minimap, each with a black border one screen
-- pixel wide, and works that pixel out again on every alt-tab, UI scale change or scale change of its own window
-- (GuildOS.UI:RefreshHairlines). Done while the faded minimap is shrunk to 0.001, "one pixel" came out a thousand times too
-- big: when the map grew back, the borders made a black box across half the screen (a CurseForge comment, 2026-11-22,
-- with a screenshot; only while a guildmate is in the zone, often right after an alt-tab). So when the minimap grows back
-- Guild OS works its pixels out again at the real scale. Only while Guild OS is loaded; one call per grow-back.
local function refreshGuildOSPixels()
	local g = _G.GuildOS
	local ui = type(g) == "table" and g.UI
	if type(ui) == "table" and type(ui.RefreshHairlines) == "function" then pcall(ui.RefreshHairlines, ui) end
end

local function setMinimapVisible(visible, alpha)
	if not MinimapCluster then return true end
	if not canScaleMap() then return false end
	if visible then
		if ns.mapSavedScale then
			setMapScale(ns.mapSavedScale)
			ns.mapSavedScale = nil
			refreshGuildOSPixels()
			unpinMapNeighbours()
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
		pinMapNeighbours()
		setMapScale(0.001)
	end
	mapLog(string.format("minimap %s (cluster alpha %.2f, scale %.3f)", visible and "shown" or "hidden", alpha or -1,
		MinimapCluster:GetScale()))
	return true
end

-- For the files after this one (QuietHUD.toc).
ns.mapLog, ns.applyMap, ns.refreshMapMask, ns.rememberMapRect = mapLog, applyMap, refreshMapMask, rememberMapRect
ns.mouseInMapRect, ns.setMinimapVisible, ns.canScaleMap, ns.setMapScale = mouseInMapRect, setMinimapVisible, canScaleMap, setMapScale
ns.pinMapNeighbours = pinMapNeighbours
