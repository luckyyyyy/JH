--[[
local map = {
	[198] = true,
	[211] = true,
	[205] = true,
	[191] = true,
}

local function DrawCircle(bDelete)
	if bDelete then
		if Station.Lookup("Normal/JH_25YX") then
			Wnd.CloseWindow(Station.Lookup("Normal/JH_25YX"))
		end
	else
		local w, h = Station.GetClientSize()
		local x, y = (w - 60) / 2, (h - 60) / 2
		local ui = GUI.CreateFrame("JH_25YX", { x = 0, y = 0, empty = true, close = true, w = w, h = h })
		ui:Append("Image", { x = x, y = y, w = 60, h = 60, icon = 2396 })
	end
end

JH.RegisterEvent("LOADING_END", function()
	local dwMapID = GetClientPlayer().GetMapID()
	if map[dwMapID] then
		JH.RegisterEvent("BUFF_UPDATE.25YX", function()
			if arg0 == UI_GetClientPlayerID() and arg4 == 7360 then
				DrawCircle(arg1)
			end
		end)
	else
		JH.UnRegisterEvent("BUFF_UPDATE.25YX")
	end
end)
]]