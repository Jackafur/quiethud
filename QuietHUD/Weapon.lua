-- The weapon: whether it is drawn (the Weapon drawn column), the sheath key, and drawing it again after the game put it
-- away (the Keep my weapon drawn box).
local _, ns = ...
local wakeLoop, trace = ns.wakeLoop, ns.trace

-- Whether the weapon is drawn. The game says so: GetSheathState is 1 sheathed, 2 melee weapon, 3 ranged weapon or wand.
-- A guess that flips on every press of the Toggle Sheath key goes wrong with a wand (three states, not two) and after a
-- fight, so that guess (ns.drawn) is only the fallback, for a client without GetSheathState. With flip, /qhud toggle turns what counts
-- the other way until the weapon state next changes. Returns the drawn state and the game's number (nil if unknown).
-- In an animal form (a shaman's Ghost Wolf, every druid form) there is no weapon, but the game still says it is drawn, so the
-- HUD stayed up the whole time (a CurseForge report, 2026-11-07). There the weapon counts as put away. Druids and shamans only:
-- a warrior's stance or a rogue's stealth is a form to the game too, and they still hold a weapon. Asked only when the weapon
-- is (while a row has Weapon ticked); the game's form message already wakes the loop (Loop.lua).
local inAnimalForm
do
	local class
	inAnimalForm = function()
		if not class then
			local ok, _, file = pcall(UnitClass, "player")
			if not ok or type(file) ~= "string" or (issecretvalue and issecretvalue(file)) then return false end
			class = file
		end
		if (class ~= "DRUID" and class ~= "SHAMAN") or not GetShapeshiftForm then return false end
		local ok, form = pcall(GetShapeshiftForm)
		return ok and not (issecretvalue and issecretvalue(form)) and type(form) == "number" and form > 0 or false
	end
end

local weaponDrawn
do
	local seen, byHand
	weaponDrawn = function(flip)
		-- (no state either, so Keep my weapon drawn leaves the weapon alone in the form and after it)
		if inAnimalForm() then return false, nil end
		local ok, state = false, nil
		if GetSheathState then ok, state = pcall(GetSheathState) end
		-- (a value the game hides from addons is checked for first: comparing one is an error)
		local known = ok and not (issecretvalue and issecretvalue(state)) and type(state) == "number"
		if known and state ~= seen then seen, byHand = state, nil end
		local current
		if not known then
			current = ns.drawn
		elseif byHand ~= nil then
			current = byHand
		else
			current = state ~= 1
		end
		if flip then
			current = not current
			if known then byHand = current end
		end
		-- The guess starts from the truth whenever the game answers, so it is right if the game stops answering.
		if known or flip then ns.drawn = current end
		return current, known and state or nil
	end
end

local function toggleDrawn()
	print("QuietHUD: the weapon counts as " .. (weaponDrawn(true) and "drawn" or "put away"))
end

-- The fallback guess follows the Toggle Sheath key (see weaponDrawn). ownSheath is up while QuietHUD itself draws the
-- weapon (see keepDrawn): that is not a key press. sheathKeyAt is the last press that no weapon change has answered yet.
local lastSheath, ownSheath, sheathKeyAt = 0, false, nil
ns.sheathHooked = false -- whether ToggleSheath is hooked (Events.lua, at login)
local function sheathToggled(source)
	wakeLoop()
	if ownSheath then return end
	local now = GetTime()
	if now - lastSheath < 0.25 then return end
	lastSheath, sheathKeyAt = now, now
	ns.drawn = not ns.drawn
	-- (the game changes its sheath state a moment after the key, so the line waits for it)
	if ns.debugOn and C_Timer and C_Timer.After then
		C_Timer.After(0.5, function()
			local isDrawn, state = weaponDrawn()
			print("QuietHUD: sheath key via " .. source .. ", now the game says " .. tostring(state)
				.. " (1 sheathed, 2 melee, 3 ranged), weapon " .. (isDrawn and "drawn" or "put away"))
		end)
	end
end

-- "Keep my weapon drawn after spells, chests and crafting" (Show when page, off by default). The game puts the weapon away
-- by itself for a cast out of combat (a buff, opening a chest, a lock, crafting, looting), which would drop the HUD with it.
-- With the box ticked QuietHUD draws the weapon again a moment later, so the weapon and the HUD never disagree: one press of
-- the sheath key puts both away. Told apart by the key: a weapon that went away with no press of the Toggle Sheath key
-- before it was put away by the game. Left alone while mounted, swimming, dead, on a flight path or in a fight (the game
-- handles the weapon itself there), and while a cast is still running (it waits for the cast to end, so a craft is never
-- disturbed and a row of crafts gets one draw at the end). A press of the key while a draw is on its way calls the draw
-- off: the weapon is yours again. It rides the main loop and the sheath state that loop already reads: no timer of its
-- own, and nothing at all with the box unticked.
-- Returns true while a draw is on its way, so the HUD stays up through the gap.
local keepDrawn
do
	local SETTLE = 0.4 -- seconds after the weapon went away, or after the cast ended, before it is drawn again
	local prev, want, dueAt, calls, calledAt, armedAt
	-- True when the game says yes, and also when it will not say (then the weapon is left alone).
	local function says(fn, ...)
		if not fn then return false end
		local ok, v = pcall(fn, ...)
		if not ok or (issecretvalue and issecretvalue(v)) then return true end
		return v and true or false
	end
	-- Whether fn (the game's cast or channel question) names a cast of yours: true, false, or nil when it cannot be asked.
	-- (a name the game hides is still a cast)
	local function busyWith(fn)
		if not fn then return nil end
		local ok, name = pcall(fn, "player")
		if not ok then return nil end
		if issecretvalue and issecretvalue(name) then return true end
		return name ~= nil
	end
	-- Casting or channeling, asked of the game itself: a cast bar addon can switch the game's own cast bar off, and that
	-- bar then never hears of a cast (or keeps an old one). Only when the game cannot be asked does its cast bar decide.
	local function casting()
		local cast, channel = busyWith(UnitCastingInfo), busyWith(UnitChannelInfo)
		if cast or channel then return true end
		if cast == false and channel == false then return false end
		local castBar = PlayerCastingBarFrame or CastingBarFrame
		return (castBar and (castBar.casting or castBar.channeling)) and true or false
	end
	keepDrawn = function(on, now, state, combat)
		if not on or not state or not ToggleSheath then
			prev, want = state, nil
			return false
		end
		if state ~= prev then
			local byKey = sheathKeyAt and now - sheathKeyAt < 1.5
			sheathKeyAt = nil
			if byKey then
				want = nil -- your own key: the weapon is yours again
			elseif state == 1 and prev and not want then
				want, dueAt, calls, calledAt, armedAt = prev, now + SETTLE, 0, 0, now
				trace("QuietHUD: the game put the weapon away, drawing it again")
			end
			prev = state
		end
		if not want then return false end
		-- A press of the key since then, also one the weapon has not answered (or never will): the weapon is yours again.
		if lastSheath > armedAt then
			want = nil
			return false
		end
		-- Out again (or somewhere the key would only put it away): done. From melee one more step reaches the wand.
		if state == want or (state ~= 1 and not (state == 2 and want == 3)) then
			want = nil
			return false
		end
		if combat or says(IsMounted) or says(IsSwimming) or says(UnitIsDeadOrGhost, "player") or says(UnitOnTaxi, "player") then
			want = nil
			return false
		end
		if casting() then
			dueAt = now + SETTLE
			return true
		end
		-- (the game changes its state a moment after a call, so each one gets time to show)
		if now < dueAt or now - calledAt < 1.5 then return true end
		if calls >= 3 then
			want = nil -- the game does not draw it (a shapeshift form, for example): give up
			return false
		end
		calls, calledAt = calls + 1, now
		ownSheath = true
		pcall(ToggleSheath)
		ownSheath = false
		return true
	end
end

local function bindingPressed(binding, key)
	if not binding or binding:match("([^%-]+)$") ~= key then return false end
	local alt = binding:find("ALT%-") ~= nil
	local ctrl = binding:find("CTRL%-") ~= nil
	local shift = binding:find("SHIFT%-") ~= nil
	return alt == (IsAltKeyDown() and true or false)
		and ctrl == (IsControlKeyDown() and true or false)
		and shift == (IsShiftKeyDown() and true or false)
end

-- The sheath key is seen by a frame that takes every key press and passes it on. Taking keys without passing them on would
-- swallow every key, and the game refuses a change to the passing on to addons in a fight (QuietHUD loaded by a /reload in a
-- fight). So the keys are taken only once the passing on took: then, or after the fight.
local keys = CreateFrame("Frame")
if keys.SetPropagateKeyboardInput then
	local listening = false
	local function listen()
		if listening or (InCombatLockdown and InCombatLockdown()) then return end
		pcall(keys.SetPropagateKeyboardInput, keys, true)
		if keys.GetPropagateKeyboardInput then
			local ok, passes = pcall(keys.GetPropagateKeyboardInput, keys)
			if not (ok and passes) then return end
		end
		listening = true
		keys:EnableKeyboard(true)
		pcall(keys.UnregisterEvent, keys, "PLAYER_REGEN_ENABLED")
	end
	keys:SetScript("OnKeyDown", function(_, key)
		local a, b = GetBindingKey("TOGGLESHEATH")
		if bindingPressed(a, key) or bindingPressed(b, key) then sheathToggled("key") end
	end)
	keys:SetScript("OnEvent", listen)
	pcall(keys.RegisterEvent, keys, "PLAYER_REGEN_ENABLED")
	listen()
end

-- For the files after this one (QuietHUD.toc).
ns.weaponDrawn, ns.toggleDrawn, ns.sheathToggled, ns.keepDrawn = weaponDrawn, toggleDrawn, sheathToggled, keepDrawn
ns.inAnimalForm = inAnimalForm
