-- Tools for the slash commands: adding frames by hand (/qhud add, remove) and finding a frame by the text it shows (/qhud
-- find).
local _, ns = ...
local EXTRA_GROUPS = ns.EXTRA_GROUPS
local DB, rebuildLists, mergeExtra, settingChanged = ns.DB, ns.rebuildLists, ns.mergeExtra, ns.settingChanged

local function frameUnderMouse()
	local f
	if GetMouseFoci then
		local t = GetMouseFoci()
		f = t and t[1]
	elseif GetMouseFocus then
		f = GetMouseFocus()
	end
	while f do
		local p = f.GetParent and f:GetParent()
		if not p or p == UIParent or p == WorldFrame then break end
		f = p
	end
	local name = f and f.GetName and f:GetName()
	if name == "UIParent" or name == "WorldFrame" then name = nil end
	return name
end

local function addExtra(group, name)
	if not mergeExtra(group, name) then return end
	rebuildLists()
	settingChanged()
end

local function removeExtra(name)
	local removed = false
	for _, g in ipairs(EXTRA_GROUPS) do
		local list = DB.extra[g] or {}
		for i = #list, 1, -1 do
			if list[i] == name then
				table.remove(list, i)
				removed = true
			end
		end
	end
	rebuildLists()
	settingChanged()
	return removed
end

-- Finding a frame by the text it shows, for things like a notice you want to hide
local function frameChain(f)
	local parts = {}
	while f and #parts < 6 do
		local ok, name = pcall(f.GetName, f)
		parts[#parts + 1] = (ok and name) or ("<" .. tostring(f.GetObjectType and f:GetObjectType()) .. ">")
		local okParent, parent = pcall(f.GetParent, f)
		if not okParent or parent == UIParent or parent == WorldFrame then break end
		f = parent
	end
	return table.concat(parts, " < ")
end

local function scanFrame(frame, needle, hits)
	if frame.IsForbidden and frame:IsForbidden() then return end
	if not frame:IsVisible() then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "FontString" and region:IsVisible() then
			local text = region:GetText()
			if type(text) == "string" and not (issecretvalue and issecretvalue(text)) and text:lower():find(needle, 1, true) then
				hits[#hits + 1] = { chain = frameChain(frame), text = text }
				return
			end
		end
	end
end

local function scanForText(needle)
	needle = needle:lower()
	local hits = {}
	local frame = EnumerateFrames()
	while frame do
		pcall(scanFrame, frame, needle, hits)
		frame = EnumerateFrames(frame)
	end
	return hits
end

local function reportHits(text, hits)
	-- Also kept in the trace, so it can be read from the saved-variables file after a /reload.
	local function say(msg)
		print(msg)
		DB.trace = DB.trace or {}
		DB.trace[#DB.trace + 1] = string.format("%.1f find: %s", GetTime(), tostring(msg))
	end
	say('QuietHUD: "' .. text .. '" is shown by (frame, then the frames that hold it):')
	for i = 1, math.min(#hits, 6) do
		say("  " .. hits[i].chain .. ' : "' .. hits[i].text:sub(1, 60) .. '"')
	end
	say("QuietHUD: to hide one, use /qhud add hidden <a frame name from the list>")
end

local finder
local function findText(text)
	if finder then
		finder:Cancel()
		finder = nil
	end
	local hits = scanForText(text)
	if #hits > 0 then
		reportHits(text, hits)
		return
	end
	print('QuietHUD: nothing on screen contains "' .. text .. '" right now. Watching for 30 minutes, I will report when it shows up.')
	if not (C_Timer and C_Timer.NewTicker) then return end
	local tries = 0
	finder = C_Timer.NewTicker(1, function(ticker)
		tries = tries + 1
		local found = scanForText(text)
		if #found > 0 then
			ticker:Cancel()
			finder = nil
			reportHits(text, found)
		elseif tries >= 1800 then
			ticker:Cancel()
			finder = nil
			print('QuietHUD: stopped watching for "' .. text .. '"')
		end
	end)
end

-- For the files after this one (QuietHUD.toc).
ns.frameUnderMouse, ns.addExtra, ns.removeExtra, ns.frameChain = frameUnderMouse, addExtra, removeExtra, frameChain
ns.findText = findText
