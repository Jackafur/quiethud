-- The chat: its windows and buttons, fading them, and what shows them (typing, the mouse over them, a message).
local _, ns = ...
local CHAT_EXTRAS = ns.CHAT_EXTRAS
local DB, LISTS, woc = ns.DB, ns.LISTS, ns.woc
local setAlpha = ns.setAlpha
local hovered, anyHoveredDeep = ns.hovered, ns.anyHoveredDeep

-- the chat windows and the frames around them, their names, and the buttons among them and their names (see buildChat)
local chatList, chatNames, chatButtons, chatButtonNames = {}, {}, {}, {}

-- The chat's opacity. It also fades the frames you added to the chat group (/qhud add chat <frame name>), for example the window or
-- background of a chat replacement addon. The pictures of the buttons around a chat window (the scroll arrows, the menu
-- and channel buttons) can be set by another addon to ignore the window's opacity (ClassicUI Forever restyles the arrows
-- that way, so they stayed solid while the chat faded): the pictures that do are faded on their own. The blink on the "to
-- the bottom" button (it blinks while the chat is scrolled up) is drawn the same way, but the game plays its opacity with an
-- animation, which overrides any opacity or colour set on it (fading its colour did nothing in game). So while the chat is
-- faded the blink is made to follow its button, and with it the chat, again; once the chat is fully up it gets back the
-- setting its addon gave it. The addon setting it again while the chat is faded is noted and put right at once (a hook),
-- so the blink never shows for a frame. A button that belongs to another list (/qhud add hidden QuickJoinToastButton) takes its
-- pictures and its blink along: they get that list's opacity, and the blink follows the button as long as it belongs there.
local applyChat
do
	local STATE_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }
	local flashOwn, flashBusy, chatA = {}, false, 1
	local flashHeld = setmetatable({}, { __mode = "k" }) -- the blinks of buttons that belong to another list
	local function setFlash(flash)
		local want = flashOwn[flash]
		if chatA < 0.999 or flashHeld[flash] then want = false end
		if (flash:IsIgnoringParentAlpha() and true or false) ~= want then
			flashBusy = true
			pcall(flash.SetIgnoreParentAlpha, flash, want)
			flashBusy = false
		end
	end
	local function flashSet(flash, on)
		if flashBusy then return end
		flashOwn[flash] = on and true or false
		if on and (chatA < 0.999 or flashHeld[flash]) then setFlash(flash) end
	end
	-- The opacity for the pictures of a button the list owner gives: the chat's own, hidden's (0 while QuietHUD hides, as in
	-- update in Loop.lua), or another list's last written opacity.
	local function ownerAlpha(owner, a)
		if owner == nil or owner == "chat" then return a end
		if owner == "hidden" then
			local edit = EditModeManagerFrame and EditModeManagerFrame:IsShown()
			return (DB.enabled and not edit) and 0 or 1
		end
		return woc.applied[owner] or a
	end
	applyChat = function(a)
		chatA = a
		-- (a frame that is also in a list, /qhud add hidden ChatFrame1Tab, belongs to that list)
		for i = 1, #chatList do
			local owner = woc.owner[chatNames[i]]
			if owner == nil or owner == "chat" then woc.write(chatList[i], a) end
		end
		setAlpha(LISTS.chat, a, nil, "chat")
		for i = 1, #chatButtons do
			local b = chatButtons[i]
			local owner = chatButtonNames[i] and woc.owner[chatButtonNames[i]] or nil
			local ta = ownerAlpha(owner, a)
			for k = 1, #STATE_TEXTURES do
				local get = b[STATE_TEXTURES[k]]
				local tex = get and get(b)
				if type(tex) == "table" and tex.IsIgnoringParentAlpha and tex:IsIgnoringParentAlpha() then woc.write(tex, ta) end
			end
			local flash = b.Flash
			if type(flash) == "table" and flash.IsIgnoringParentAlpha and flash.SetIgnoreParentAlpha then
				if flashOwn[flash] == nil then
					flashOwn[flash] = flash:IsIgnoringParentAlpha() and true or false
					pcall(hooksecurefunc, flash, "SetIgnoreParentAlpha", flashSet)
				end
				flashHeld[flash] = (owner ~= nil and owner ~= "chat") or nil
				setFlash(flash)
			end
		end
	end
end

local function chatTyping()
	return ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and true or false
end

local function chatHovered()
	for i = 1, #chatList do
		if hovered(chatList[i]) then return true end
	end
	-- Deep, because a chat replacement addon's frame can be an empty container with the window as its child.
	return anyHoveredDeep(LISTS.chat)
end

local function bumpChat()
	ns.chatUntil = GetTime() + (DB.chatSeconds or 8)
end

local function buildChat()
	chatList, chatNames, chatButtons, chatButtonNames = {}, {}, {}, {}
	local function button(b)
		if type(b) == "table" and b.GetNormalTexture then
			local n = #chatButtons + 1
			local okN, name = pcall(b.GetName, b)
			chatButtons[n], chatButtonNames[n] = b, okN and type(name) == "string" and name or false
		end
	end
	local function add(name)
		local f = _G[name]
		if type(f) ~= "table" or not f.SetAlpha then return nil end
		local n = #chatList + 1
		chatList[n], chatNames[n] = f, name
		return f
	end
	-- Every chat window the game has: its own ten and the temporary ones it makes for a whisper in a tab of its own
	-- (ChatFrame11 and up). CHAT_FRAMES is the game's list of their names.
	local names = rawget(_G, "CHAT_FRAMES")
	if type(names) ~= "table" then
		names = {}
		for i = 1, NUM_CHAT_WINDOWS or 10 do names[i] = "ChatFrame" .. i end
	end
	for _, name in ipairs(names) do
		local main = type(name) == "string" and add(name)
		if main then
			for _, suffix in ipairs({ "Tab", "ButtonFrame", "EditBox" }) do add(name .. suffix) end
		end
		-- The window's scroll arrows and its "to the bottom" button, for applyChat.
		local bar = main and main.ScrollBar
		if type(bar) == "table" then
			button(bar.Back)
			button(bar.Forward)
		end
		if main then button(main.ScrollToBottomButton) end
	end
	for i = 1, #CHAT_EXTRAS do
		local f = add(CHAT_EXTRAS[i])
		if f then button(f) end
	end
	woc.forget()
end
-- A whisper that opens a tab of its own makes a temporary chat window (or takes one back that was closed): the list is
-- built again, so it fades with the chat.
if rawget(_G, "FCF_OpenTemporaryWindow") then pcall(hooksecurefunc, "FCF_OpenTemporaryWindow", function() buildChat() end) end

-- For the files after this one (QuietHUD.toc).
ns.applyChat, ns.chatTyping, ns.chatHovered, ns.bumpChat = applyChat, chatTyping, chatHovered, bumpChat
ns.buildChat = buildChat
