-- Tooltip opacity: the whole tooltip is faded, text included. Untouched while the setting is at 1. The game puts a tooltip
-- back to full opacity each time it is shown, and an addon can re-show one many times a second (RestedXP does when it
-- redraws its map pins), so the opacity is also applied the moment a tooltip is shown, or it would flash at full
-- opacity before the next update. A tooltip the game is fading out is left alone: only one that is more opaque than
-- wanted is lowered.
local _, ns = ...
local DB, loop = ns.DB, ns.loop

local applyTooltips
do
	local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }
	local tooltipTouched = false
	applyTooltips = function()
		local a = DB.enabled and DB.tooltipAlpha or 1 -- (with QuietHUD switched off they go back to full)
		if a <= 0 then a = DB.base or 0.75 elseif a < 0.1 then a = 0.1 end -- 0 is Global: the "When active" opacity
		local restoring = false
		if a >= 0.999 then
			if not tooltipTouched then loop.tips = false return end
			a = 1
			restoring = true
		end
		local shown = false
		for i = 1, #TOOLTIPS do
			local f = _G[TOOLTIPS[i]]
			if f and f.SetAlpha and f.GetAlpha then
				local now = f:GetAlpha()
				if issecretvalue and issecretvalue(now) then now = -1 end -- (a hidden value cannot be compared: write ours)
				if (restoring and math.abs(now - a) > 0.01) or (not restoring and now > a + 0.01) then f:SetAlpha(a) end
				if not restoring and f.IsShown and f:IsShown() then shown = true end
			end
		end
		-- (the sleeping loop looks at the tooltips every frame while one is on screen below full opacity: see the driver in
		-- Loop.lua)
		loop.tips = shown
		tooltipTouched = a < 1
	end
	-- The game also puts a tooltip back to full opacity when it gets new content while it is already shown (moving the mouse
	-- quickly from one thing to the next, even onto something new while the last tooltip is still fading out), which does
	-- not count as being shown again and flickered. So the opacity is also applied right after every Show call and after
	-- the tooltip's own update each frame.
	local function onTip() applyTooltips() end
	for i = 1, #TOOLTIPS do
		local f = _G[TOOLTIPS[i]]
		if f and f.HookScript then
			pcall(f.HookScript, f, "OnShow", onTip)
			pcall(f.HookScript, f, "OnUpdate", onTip)
		end
		if f and f.Show then pcall(hooksecurefunc, f, "Show", onTip) end
	end
end

-- For the files after this one (QuietHUD.toc).
ns.applyTooltips = applyTooltips
