-- Minimap buttons of other addons: the round icons that addons leave around the minimap. Some belong to the minimap and shrink with
-- it when it fades, but many are loose buttons on the screen that never fade, which is what this option is for. With it on they are
-- hidden, and when it is switched off the ones QuietHUD hid are shown again. Two ways of finding them: the LibDBIcon list (Leatrix,
-- RestedXP, GSE, Auctionator and so on), and any small button on the screen or the minimap that wears the round minimap border,
-- which catches the addons that make their own. The game's own minimap controls (inside the minimap cluster) and the map pins
-- (RestedXP's waypoints, for example) are not touched, and neither are buttons that were already hidden by their own addon.
local _, ns = ...
local DB = ns.DB

local hiddenMmButtons -- names of the minimap buttons of other addons that are hidden now (set below)
do
	local hiddenByUs, hookedButtons = {}, {}
	local found, checked = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
	local BORDER_ID, BORDER_NAME = 136430, "minimap%-trackingborder"
	local BLIZZARD = {
		MinimapZoomIn = true, MinimapZoomOut = true, MiniMapTracking = true, MiniMapMailFrame = true, MiniMapBattlefieldFrame = true,
		MiniMapWorldMapButton = true, MiniMapLFGFrame = true, MiniMapInstanceDifficulty = true, MinimapZoneTextButton = true,
		GameTimeFrame = true, QueueStatusButton = true, ExpansionLandingPageMinimapButton = true, GarrisonLandingPageMinimapButton = true,
	}

	local function wearsBorder(frame)
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetObjectType and region:GetObjectType() == "Texture" then
				local tex = region:GetTexture()
				if tex == BORDER_ID or (type(tex) == "string" and tex:lower():find(BORDER_NAME)) then return true end
			end
		end
		return false
	end

	local function isAddonButton(frame)
		if frame:GetObjectType() ~= "Button" or BLIZZARD[frame:GetName() or ""] or frame:IsProtected() then return false end
		local w, h = frame:GetWidth(), frame:GetHeight()
		return w > 0 and h > 0 and w <= 64 and h <= 64 and wearsBorder(frame)
	end

	-- Each button is looked at once, and again only if it gains a texture.
	local function scanChildren(parent)
		if not parent then return end
		local ok, children = pcall(function() return { parent:GetChildren() } end)
		if not ok then return end
		for _, child in ipairs(children) do
			local okN, count = pcall(child.GetNumRegions, child)
			if okN and checked[child] ~= count then
				checked[child] = count
				local okB, isButton = pcall(isAddonButton, child)
				if okB and isButton then found[child] = true end
			end
		end
	end

	local function buttons()
		local set = {}
		local lib = LibStub and LibStub("LibDBIcon-1.0", true)
		if lib and lib.GetButtonList then
			for _, name in ipairs(lib:GetButtonList()) do
				local button = _G["LibDBIcon10_" .. name]
				if button then set[button] = true end
			end
		end
		scanChildren(UIParent)
		scanChildren(Minimap)
		for button in pairs(found) do set[button] = true end
		return set
	end

	local function apply()
		if DB.enabled and DB.hideMmButtons then
			for button in pairs(buttons()) do
				if not hookedButtons[button] then
					-- An addon can show its button again at any time; this hides it as it appears.
					hookedButtons[button] = true
					pcall(button.HookScript, button, "OnShow", function(self)
						if DB.enabled and DB.hideMmButtons then
							hiddenByUs[self] = true
							self:Hide()
						end
					end)
				end
				if button:IsShown() then
					hiddenByUs[button] = true
					pcall(button.Hide, button)
				end
			end
		else
			for button in pairs(hiddenByUs) do
				pcall(button.Show, button)
				hiddenByUs[button] = nil
			end
		end
	end

	hiddenMmButtons = function()
		local names = {}
		for button in pairs(hiddenByUs) do
			local name = button:GetName()
			names[#names + 1] = name or ("(unnamed button, " .. tostring(button:GetObjectType()) .. ")")
		end
		table.sort(names)
		return names
	end

	local previous = ns.applyExtras
	ns.applyExtras = function()
		if previous then previous() end
		apply()
	end

	-- Looked for when they can appear, not on a timer: when an addon loads, at login and entering
	-- the world, when LibDBIcon makes a button (its LibDBIcon_IconCreated callback), and when an addon makes a button on the
	-- minimap or straight on the screen (a CreateFrame hook, only while the option is on). The look is half a second later, so
	-- a new button has its border by then, and at most one every 2 seconds. A button its addon shows again is hidden at once by
	-- its OnShow hook, and switching the option on or off looks at once (applyExtras, above).
	local pending, lastLook, libHooked, libKey = false, -10, false, {}
	local function look()
		pending = false
		lastLook = GetTime()
		apply()
	end
	local function soon()
		if pending or not (C_Timer and C_Timer.After) then return end
		pending = true
		C_Timer.After(math.max(0.5, lastLook + 2 - GetTime()), look)
	end
	-- An addon that puts the round border on its button a moment after making it is missed by that first look, so a button an
	-- addon makes gets one more look about 5 seconds later: one timer for a burst of buttons, and it never repeats.
	local latePending = false
	local function lookLater()
		if latePending or not (C_Timer and C_Timer.After) then return end
		latePending = true
		C_Timer.After(5, function()
			latePending = false
			apply()
		end)
	end
	local function hookLib()
		if libHooked then return end
		local lib = LibStub and LibStub("LibDBIcon-1.0", true)
		if lib and lib.RegisterCallback then
			libHooked = pcall(lib.RegisterCallback, libKey, "LibDBIcon_IconCreated", soon)
		end
	end
	local events = CreateFrame("Frame")
	for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }) do
		pcall(events.RegisterEvent, events, e)
	end
	events:SetScript("OnEvent", function()
		hookLib()
		soon()
	end)
	pcall(hooksecurefunc, "CreateFrame", function(kind, _, parent)
		if parent ~= nil and (parent == Minimap or parent == UIParent) and DB.enabled and DB.hideMmButtons
			and type(kind) == "string" and kind:lower() == "button" then
			soon()
			lookLater()
		end
	end)
	hookLib()
end

-- For the files after this one (QuietHUD.toc).
ns.hiddenMmButtons = hiddenMmButtons
