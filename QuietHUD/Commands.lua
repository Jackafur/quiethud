-- The slash commands (/qhud and what follows it). Loaded last: it uses something from nearly every file.
local _, ns = ...
local BAR_DEFS, EXTRA_BUTTONS, EXTRA_GROUPS = ns.BAR_DEFS, ns.EXTRA_BUTTONS, ns.EXTRA_GROUPS
local DB, LISTS, woc, wakeLoop, settingChanged = ns.DB, ns.LISTS, ns.woc, ns.wakeLoop, ns.settingChanged
local shortHotkey, shortened = ns.shortHotkey, ns.shortened
local T, inDungeonOrRaid, mouseActive, playerChanging = ns.T, ns.inDungeonOrRaid, ns.mouseActive, ns.playerChanging
local bumpChat = ns.bumpChat
local weaponDrawn, toggleDrawn, inAnimalForm = ns.weaponDrawn, ns.toggleDrawn, ns.inAnimalForm
local navHosts = ns.navHosts
local mouseInMapRect = ns.mouseInMapRect
local shiftNow, shiftReport = ns.shiftNow, ns.shiftReport
local hiddenMmButtons = ns.hiddenMmButtons
local syncControls, resetDefaults, toggleConfig = ns.syncControls, ns.resetDefaults, ns.toggleConfig
local frameUnderMouse, addExtra, removeExtra = ns.frameUnderMouse, ns.addExtra, ns.removeExtra
local frameChain, findText = ns.frameChain, ns.findText

SLASH_QUIETHUD1 = "/qhud"
SlashCmdList["QUIETHUD"] = function(msg)
	local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" or cmd == "config" then
		toggleConfig()
	elseif cmd == "toggle" then
		toggleDrawn()
	elseif cmd == "target" or cmd == "t" then
		print("QuietHUD: turn quest targeting on in /qhud, Extras, then use the QuietHUD key (Keybindings, AddOns) or the macro /click QuietHUDTargetButton")
	elseif cmd == "quest" or cmd == "q" then
		ns.questUntil = GetTime() + (DB.questSeconds or 10)
	elseif cmd == "map" then
		ns.mapUntil = GetTime() + (DB.questSeconds or 10)
	elseif cmd == "chat" or cmd == "c" then
		bumpChat()
	elseif cmd == "reset" then
		resetDefaults()
		print("QuietHUD: settings reset to defaults")
	elseif cmd == "debug" then
		ns.debugOn = not ns.debugOn
		if ns.debugOn then DB.trace = {} end
		local isDrawn, state = weaponDrawn()
		print("QuietHUD debug " .. (ns.debugOn and "on" or "off") .. ", weapon drawn: " .. tostring(isDrawn) .. " (the game says "
			.. (inAnimalForm() and "nothing: an animal form counts as put away" or state and tostring(state) or "nothing, so QuietHUD guesses from the sheath key") .. "; 1 sheathed, 2 melee, 3 ranged)"
			.. ", sheath key: " .. tostring((GetBindingKey("TOGGLESHEATH"))) .. ", ToggleSheath hooked: " .. tostring(ns.sheathHooked))
	elseif cmd == "state" then
		local ok, err = pcall(function()
			-- Everything this command prints is also kept in the trace, so it can be read from the saved-variables
			-- file after a /reload.
			local function print(text)
				_G.print(text)
				DB.trace = DB.trace or {}
				DB.trace[#DB.trace + 1] = string.format("%.1f state: %s", GetTime(), tostring(text))
			end
			local function alpha(name)
				local f = _G[name]
				return (f and f.GetAlpha) and string.format("%.2f", f:GetAlpha()) or "none"
			end
			print(string.format("QuietHUD state: enabled=%s, shown opacity=%.2f, idle opacity=%.2f, wake: combat=%s weapon=%s target=%s mouse=%s",
				tostring(DB.enabled and true or false), DB.base or 0, DB.idle or 0, tostring((woc.wake or {}).fight or false),
				tostring((woc.wake or {}).weapon or false), tostring((woc.wake or {}).target or false), tostring((woc.wake or {}).mouse or false)))
			print(string.format("QuietHUD triggers: in combat=%s, after-combat linger=%s, weapon drawn=%s, has target=%s, mouse moving=%s",
				tostring(UnitAffectingCombat("player") and true or false), tostring(GetTime() < ns.combatEnd),
				tostring((weaponDrawn())) .. (inAnimalForm() and " (an animal form counts as put away)" or ""), tostring(UnitExists("target") and true or false),
				woc.anyRow(T.MOUSE) and tostring(mouseActive(GetTime())) or "no row has Mouse move"))
			do
				local function shown(fn, ...)
					local ok, v = pcall(fn, ...)
					if not ok then return "unreadable" end
					return (issecretvalue and issecretvalue(v)) and "hidden by the game" or tostring(v)
				end
				local kind = shown(UnitPowerType, "player")
				-- (a look only: it does not start or stop the listening)
				local ago, left = playerChanging(false, GetTime(), true)
				local last = not DB.notFullShows and "option off" or (not ago and "nothing yet")
					or string.format("%.1f seconds ago (the frame stays %.1f more)", ago, left)
				print(string.format("QuietHUD player frame: last health or power change=%s (health %s of %s, power type %s: %s of %s)",
					last, shown(UnitHealth, "player"), shown(UnitHealthMax, "player"),
					kind, shown(UnitPower, "player", tonumber(kind)), shown(UnitPowerMax, "player", tonumber(kind))))
			end
			print("QuietHUD alpha now: PlayerFrame=" .. alpha("PlayerFrame") .. ", MainActionBar=" .. alpha("MainActionBar")
				.. ", TargetFrame=" .. alpha("TargetFrame") .. ", MinimapCluster=" .. alpha("MinimapCluster"))
			local okSpeed, speed = pcall(GetUnitSpeed, "player")
			local speedText = not okSpeed and "unreadable" or ((issecretvalue and issecretvalue(speed)) and "hidden by the game" or tostring(speed))
			print(string.format("QuietHUD minimap: trigger number=%s, Minimap shown=%s, alpha=%s, walking speed=%s, moving detected by=%s, moving window left=%.1fs, zone-change window=%s, indoors=%s, in %s / %s",
				tostring(DB.trigMap), tostring(Minimap and Minimap:IsShown()), alpha("Minimap"), speedText,
				ns.lastMoveReason, math.max(0, ns.moveUntil - GetTime()), tostring(GetTime() < ns.mapUntil),
				tostring(IsIndoors and IsIndoors() or false), tostring(GetZoneText()), tostring(GetSubZoneText())))
				print("QuietHUD minimap area (remembered): " .. (ns.mapRect and string.format("%.0f,%.0f to %.0f,%.0f", ns.mapRect[1], ns.mapRect[2], ns.mapRect[3], ns.mapRect[4]) or "nothing yet")
					.. ", mouse over it now: " .. tostring(mouseInMapRect()))
		end)
		if not ok then print("QuietHUD: could not read the state (" .. tostring(err) .. ")") end
	elseif cmd == "instance" then
		local ok, line = pcall(function()
			local inside, kind = IsInInstance()
			return "IsInInstance = " .. tostring(inside) .. ", " .. tostring(kind) .. ", counts as a dungeon or raid: "
				.. tostring(inDungeonOrRaid()) .. (ns.fakeInstance and " (the fakeinstance test switch is ON)" or "")
		end)
		print("QuietHUD: " .. (ok and line or "could not read the instance state"))
	elseif cmd == "fakeinstance" then
		-- Test switch, not listed in the help: QuietHUD behaves as if you were inside a dungeon or raid, so the "Dungeon or raid"
		-- column can be tried anywhere. It only changes what QuietHUD believes, and a reload ends it.
		if rest == "on" then ns.fakeInstance = true elseif rest == "off" then ns.fakeInstance = false else ns.fakeInstance = not ns.fakeInstance end
		print("QuietHUD test switch: " .. (ns.fakeInstance and "acting as if you were in a dungeon or raid (off again with /qhud fakeinstance off or a /reload)"
			or "back to the real instance state"))
	elseif cmd == "bars" then
		print("QuietHUD action bar frames found: " .. table.concat(ns.discovered, ", "))
	elseif cmd == "where" then
		-- Prints the frame under the mouse and the frames that hold it. With a number, waits that many seconds first,
		-- so the mouse can be moved onto a frame after the command is typed.
		local function report()
			local frame
			if GetMouseFoci then
				local list = GetMouseFoci()
				frame = list and list[1]
			elseif GetMouseFocus then
				frame = GetMouseFocus()
			end
			if not frame then
				print("QuietHUD: nothing is under the mouse")
			else
				print("QuietHUD: under the mouse: " .. frameChain(frame) .. "  (frame names you can use are the words that are not in <angle brackets>)")
			end
		end
		local delay = tonumber(rest)
		if delay and delay > 0 and C_Timer and C_Timer.After then
			print("QuietHUD: move the mouse onto the frame now, reporting in " .. delay .. " seconds")
			C_Timer.After(delay, report)
		else
			report()
		end
	elseif cmd == "minimapbuttons" then
		if rest == "on" then DB.hideMmButtons = true elseif rest == "off" then DB.hideMmButtons = false elseif rest ~= "list" then DB.hideMmButtons = not DB.hideMmButtons end
		syncControls()
		settingChanged()
		if rest == "list" then
			local names = hiddenMmButtons()
			print("QuietHUD: " .. (#names > 0 and ("hiding " .. table.concat(names, ", ")) or "no minimap buttons are hidden") ..
				". Untick the option (or /qhud minimapbuttons off) to bring them back")
		else
			print("QuietHUD: other addons' minimap buttons are " .. (DB.hideMmButtons and "hidden" or "shown again"))
		end
	elseif cmd == "hidepanel" then
		if rest == "on" then DB.hidePanel = true elseif rest == "off" then DB.hidePanel = false else DB.hidePanel = not DB.hidePanel end
		syncControls()
		settingChanged()
		print("QuietHUD: the party panel is " .. (DB.hidePanel and "hidden" or "shown again"))
	elseif cmd == "bags" then
		if rest == "reset" then
			DB.bagX, DB.bagY, DB.bagAlpha = 0, 0, 1
			syncControls()
			ns.applyExtras()
			print("QuietHUD: the open bags are back where the game puts them, at full opacity")
		else
			local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
			local ok, blizzMove = false, false
			if loaded then ok, blizzMove = pcall(loaded, "BlizzMove") end
			local moving = (ok and blizzMove) and "BlizzMove is loaded, so QuietHUD leaves them to it"
				or (DB.moveBags and "drag one to move them all" or "moving them is off (Extras page)")
			print(string.format("QuietHUD: open bags are moved %.0f, %.0f from their normal place, opacity %.2f; %s. /qhud bags reset puts them back",
				DB.bagX or 0, DB.bagY or 0, DB.bagAlpha or 1, moving))
		end
	elseif cmd == "mouse" then
		DB.watchMouse = not DB.watchMouse
		ns.applyMouseWatch()
		if DB.watchMouse and not ns.mouseRegistered then
			DB.watchMouse = false
			print("QuietHUD: this client does not tell addons about mouse presses. Use /qhud where 6 instead and leave the mouse where the camera will not turn")
		else
			settingChanged()
			print(DB.watchMouse and "QuietHUD: watching right-clicks, and it stays on after a reload. It says nothing while the camera works; when a right-click is taken by something else it prints what. /qhud mouse again stops" or "QuietHUD: stopped watching right-clicks")
		end
	elseif cmd == "peek" then
		-- The "hold to show" key sends "down" when it is pressed and "up" when it is released. Typed without either, it toggles.
		-- It runs out after two minutes, so a key release the game never saw (focus lost) cannot leave the HUD stuck on.
		-- The "Toggle the whole HUD" key sends "toggle": it stays on until pressed again (no key release to miss, so no time limit).
		local peekNow = GetTime()
		if rest == "down" then
			ns.peekUntil = peekNow + 120
		elseif rest == "up" then
			ns.peekUntil = 0
		elseif rest == "toggle" then
			ns.peekUntil = peekNow < ns.peekUntil and 0 or math.huge
		else
			ns.peekUntil = peekNow < ns.peekUntil and 0 or peekNow + 120
		end
	elseif cmd == "shift" then
		if rest == "on" or rest == "off" then
			DB.pixelShift = (rest == "on")
			syncControls()
			settingChanged()
			print("QuietHUD: pixel shift is " .. (DB.pixelShift and "on" or "off, and the frames go back where they were (out of combat)"))
		elseif rest == "now" then
			shiftNow()
			print("QuietHUD: pixel shift moves on to its next position within a second")
		else
			shiftReport()
		end
	elseif cmd == "arrow" then
		ns.navForce = not ns.navForce
		print("QuietHUD: the nav group (the arrow) is now " .. (ns.navForce and "kept ON until you use /qhud arrow again" or "back to its automatic behavior"))
	elseif cmd == "nav" then
		print("QuietHUD nav group: " .. (#LISTS.nav == 0 and "empty, add a frame with /qhud add nav <frame name>" or table.concat(LISTS.nav, ", ")))
		for _, name in ipairs(LISTS.nav) do
			local f = _G[name]
			if type(f) ~= "table" then
				print("  " .. name .. ": there is no frame with that name (yet)")
			else
				local rec = navHosts[f]
				local okP, parent = pcall(f.GetParent, f)
				local parentName = (okP and parent and (parent.GetName and parent:GetName() or "<unnamed>")) or "?"
				print(string.format("  %s: moved into our container=%s, parent=%s, own opacity %.2f, container opacity %s, effective opacity %.2f, shown=%s",
					name, tostring(rec ~= nil), tostring(parentName), f:GetAlpha(), rec and string.format("%.2f", rec.host:GetAlpha()) or "n/a",
					f:GetEffectiveAlpha(), tostring(f:IsShown())))
			end
		end
		if ns.navLastError then print("QuietHUD: the last problem moving a frame into the container: " .. ns.navLastError) end
	elseif cmd == "alpha" then
		local name, value = rest:match("^(%S+)%s+([%d%.]+)$")
		local frame = name and _G[name]
		if frame and frame.SetAlpha and tonumber(value) then
			frame:SetAlpha(tonumber(value))
			print("QuietHUD: " .. name .. " opacity set to " .. value .. " (it stays until something fades it again, or a reload)")
		else
			print("QuietHUD: usage /qhud alpha <frame name> <0 to 1>, for example /qhud alpha Minimap 0.6")
		end
	elseif cmd == "chain" then
		local frame = rest ~= "" and _G[rest] or nil
		print("QuietHUD: " .. (frame and frameChain(frame) or "usage /qhud chain <frame name>, for example /qhud chain Minimap"))
	elseif cmd == "hotkeys" then
		-- Lists hotkey text with a modifier first (those are the long ones), and keeps the lines in the trace too.
		local function say(text)
			print(text)
			DB.trace = DB.trace or {}
			DB.trace[#DB.trace + 1] = string.format("%.1f hotkeys: %s", GetTime(), text)
		end
		local found = {}
		for i = 1, #BAR_DEFS do
			for j = 1, BAR_DEFS[i].count or 12 do
				local name = BAR_DEFS[i].buttons .. j .. "HotKey"
				local fs = _G[name]
				if fs then
					local ok, text = pcall(fs.GetText, fs)
					if ok and type(text) == "string" and text ~= "" and not (issecretvalue and issecretvalue(text)) then
						local rec = shortened[fs]
						local original = rec and rec.orig or text
						found[#found + 1] = { name = name, original = original, text = text, width = fs:GetWidth(),
							modifier = original:find("[%-%+]") ~= nil }
					end
				end
			end
		end
		for _, set in ipairs(EXTRA_BUTTONS) do
			for j = 1, set[2] do
				local name = set[1] .. j .. "HotKey"
				local fs = _G[name]
				if fs then
					local ok, text = pcall(fs.GetText, fs)
					if ok and type(text) == "string" and text ~= "" and not (issecretvalue and issecretvalue(text)) then
						local rec = shortened[fs]
						local original = rec and rec.orig or text
						found[#found + 1] = { name = name, original = original, text = text, width = fs:GetWidth(),
							modifier = original:find("[%-%+]") ~= nil }
					end
				end
			end
		end
		table.sort(found, function(a, b)
			if a.modifier ~= b.modifier then return a.modifier end
			return a.name < b.name
		end)
		say(string.format("QuietHUD hotkeys: shortening is %s, %d button(s) with hotkey text", DB.shortHotkeys and "ON" or "OFF", #found))
		for i = 1, math.min(#found, 10) do
			local f = found[i]
			say(string.format('  %s: the game says "%s", it shows "%s", the rules give "%s", width %.0f', f.name, f.original,
				f.text, shortHotkey(f.original), f.width))
		end
		if #found == 0 then say("QuietHUD: no hotkey text found on the action bars") end
	elseif cmd == "methods" then
		local name, filter = rest:match("^(%S*)%s*(.-)%s*$")
		local frame = name ~= "" and _G[name] or nil
		local meta = frame and getmetatable(frame)
		local index = meta and meta.__index
		if type(index) ~= "table" then
			print("QuietHUD: usage /qhud methods <frame name> [part of a method name], for example /qhud methods Minimap texture")
		else
			local found = {}
			for key in pairs(index) do
				if type(key) == "string" and (filter == "" or key:lower():find(filter:lower(), 1, true)) then
					found[#found + 1] = key
				end
			end
			table.sort(found)
			print("QuietHUD: " .. #found .. " method(s) of " .. name .. (filter ~= "" and (' matching "' .. filter .. '"') or "")
				.. ": " .. table.concat(found, ", "))
		end
	elseif cmd == "around" then
		-- Lists the frames and background images that sit over the same area as a frame, to find things like the
		-- background box of a chat window. Everything printed is also kept in the trace (read after a /reload).
		local function say(text)
			print(text)
			DB.trace = DB.trace or {}
			DB.trace[#DB.trace + 1] = string.format("%.1f around: %s", GetTime(), tostring(text))
		end
		local target = rest ~= "" and _G[rest] or nil
		if not (target and target.GetRect) then
			print("QuietHUD: usage /qhud around <frame name>, for example /qhud around ChattynatorHyperlinkHandler")
		else
			local function rectOf(object)
				if object.GetScaledRect then return object:GetScaledRect() end
				return object:GetRect()
			end
			local L, B, W, H = rectOf(target)
			if not L then
				print("QuietHUD: that frame has no position on the screen right now")
			else
				local area = W * H
				local function overlap(l, b, w, h)
					local x = math.max(0, math.min(L + W, l + w) - math.max(L, l))
					local y = math.max(0, math.min(B + H, b + h) - math.max(B, b))
					return x * y
				end
				local found = {}
				local frame = EnumerateFrames()
				while frame do
					pcall(function()
						if (frame.IsForbidden and frame:IsForbidden()) or not frame:IsVisible() then return end
						if frame ~= target then
							local l, b, w, h = rectOf(frame)
							if l and w > 0 and h > 0 and overlap(l, b, w, h) >= 0.6 * area and w * h <= 3 * area then
								found[#found + 1] = { size = w * h, text = string.format("frame  %s  (%.0fx%.0f, strata %s, level %d, alpha %.2f)",
									frameChain(frame), w, h, tostring(frame:GetFrameStrata()), frame:GetFrameLevel(), frame:GetAlpha()) }
							end
						end
						for _, region in ipairs({ frame:GetRegions() }) do
							if region.GetObjectType and region:GetObjectType() == "Texture" and region:IsVisible() then
								local l, b, w, h = rectOf(region)
								if l and w > 0 and h > 0 and overlap(l, b, w, h) >= 0.6 * area and w * h <= 3 * area then
									local okColor, r, g, bl, a = pcall(region.GetVertexColor, region)
									found[#found + 1] = { size = w * h, text = string.format("texture on  %s  (%.0fx%.0f, layer %s, alpha %.2f, colour %s)",
										frameChain(frame), w, h, tostring(region:GetDrawLayer()), region:GetAlpha(),
										okColor and string.format("%.2f/%.2f/%.2f/%.2f", r or 0, g or 0, bl or 0, a or 0) or "?") }
								end
							end
						end
					end)
					frame = EnumerateFrames(frame)
				end
				table.sort(found, function(x, y) return math.abs(x.size - area) < math.abs(y.size - area) end)
				say(string.format("QuietHUD around %s (%.0fx%.0f): %d frame(s) or image(s) cover the same area", rest, W, H, #found))
				for i = 1, math.min(#found, 14) do say("  " .. found[i].text) end
			end
		end
	elseif cmd == "find" then
		if rest == "" then
			print("QuietHUD: usage /qhud find <part of the text>, for example /qhud find refresh")
		else
			findText(rest)
		end
	elseif cmd == "add" then
		local group, explicit = rest:match("^(%S*)%s*(.-)%s*$")
		group = group:lower()
		local name = explicit ~= "" and explicit or frameUnderMouse()
		local valid = false
		for _, g in ipairs(EXTRA_GROUPS) do
			if g == group then valid = true end
		end
		if not valid then
			print("QuietHUD: usage /qhud add bars|player|hud|quest|map|chat|nav|rxp|shift|hidden|mouseover [frame name] (or hover the frame first)")
		elseif not name then
			print("QuietHUD: no named frame under the mouse")
		elseif not _G[name] then
			print("QuietHUD: there is no frame named " .. name)
		elseif type(_G[name]) ~= "table" or not _G[name].SetAlpha then
			print("QuietHUD: " .. name .. " is not a frame")
		else
			addExtra(group, name)
			print("QuietHUD: added " .. name .. " to " .. group)
		end
	elseif cmd == "remove" then
		if rest == "" then
			print("QuietHUD: usage /qhud remove <frame name> (/qhud list shows them)")
		else
			print(removeExtra(rest) and ("QuietHUD: removed " .. rest) or ("QuietHUD: " .. rest .. " is not in your added list"))
		end
	elseif cmd == "list" then
		for _, g in ipairs(EXTRA_GROUPS) do
			print("QuietHUD " .. g .. " extras: " .. table.concat(DB.extra[g] or {}, ", "))
		end
	else
		print("QuietHUD: /qhud (menu), toggle, peek, shift, reset, target, quest, map, chat, bars, instance, state, debug, where, hotkeys, arrow, nav, mouse, alpha <frame> <0-1>, chain <frame>, around <frame>, find <text>, methods <frame> [text], add <group> [name], remove <name>, list")
	end
end
do -- a slash command wakes the loop, so what it changes shows at once
	local slashRun = SlashCmdList["QUIETHUD"]
	SlashCmdList["QUIETHUD"] = function(msg) slashRun(msg) wakeLoop() end
end
