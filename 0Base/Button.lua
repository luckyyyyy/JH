-- @Author: Webster
-- @Date:   2015-09-16 18:12:29
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-09-16 19:14:07

-- 只有存在文件的情况下才会开启
local isEnable = IsFileExist(JH.GetAddonInfo().szDataPath .. "EnableButton")
if isEnable then
	local Container = Station.Lookup("Normal/TopMenu/WndContainer_List")
	if Container then
		if not Container:Lookup("JH_Window") then
			local wnd = Container:AppendContentFromIni(JH.GetAddonInfo().szRootPath .. "0Base/ui/JH_Button.ini", "JH_Window")
			if wnd then
				Container:FormatAllContentPos()
			end
		end
		local wnd = Container:Lookup("JH_Window")
		if wnd then
			local btn = wnd:Lookup("Btn_JH")
			RegisterEvent("RELOAD_UI_ADDON_BEGIN", function()
				-- free(ui)
				btn.OnLButtonClick = nil
				btn.OnRButtonClick = nil
			end)
			btn.OnLButtonClick = JH.TogglePanel
			btn.OnRButtonClick = function()
				PopupMenu(JH.GetPlayerAddonMenu()[1])
			end
		end
	end
end

