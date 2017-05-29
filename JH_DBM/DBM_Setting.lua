-- @Author: Webster
-- @Date:   2015-05-25 13:13:46
-- @Last Modified by:   Administrator
-- @Last Modified time: 2017-05-29 02:26:30

local _L = JH.LoadLangPack
local PS = {}

function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0

	ui:Append("WndButton2", { x = 400, y = 20, txt = g_tStrings.HELP_PANEL }):Click(function()
		OpenInternetExplorer("https://github.com/luckyyyyy/JH/blob/dev/JH_DBM/README.md")
	end)

	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Master switch"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Enable DBM Plugin"], checked = DBM.bEnable }):Click(function(bCheck)
		DBM_API.Enable(bCheck, true)
		DBM.bEnable = bCheck
	end):Pos_()
	if Circle then
		nY = 17
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = Circle.bEnable, txt = _L["Circle Enable"] }):Click(function(bCheck)
			Circle.Enable(bCheck)
			if bCheck then
				FireUIEvent("CIRCLE_RELOAD")
			end
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = Circle.bBorder, txt = _L["Circle Border"] }):Click(function(bCheck)
			Circle.bBorder = bCheck
			FireUIEvent("CIRCLE_RELOAD")
		end):Pos_()
	end
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Enable alarm (master switch)"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true), checked = DBM.bPushTeamChannel }):Click(function(bCheck)
		DBM.bPushTeamChannel = bCheck
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true), checked = DBM.bPushWhisperChannel }):Click(function(bCheck)
		DBM.bPushWhisperChannel = bCheck
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Buff List"], checked = DBM.bPushBuffList }):Click(function(bCheck)
		DBM.bPushBuffList = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Center Alarm"], checked = DBM.bPushCenterAlarm }):Click(function(bCheck)
		DBM.bPushCenterAlarm = bCheck
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Big Font Alarm"], checked = DBM.bPushBigFontAlarm }):Click(function(bCheck)
		DBM.bPushBigFontAlarm = bCheck
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, txt = _L["Full Screen Alarm"], checked = DBM.bPushFullScreen }):Click(function(bCheck)
		DBM.bPushFullScreen = bCheck
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, txt = _L["Party Buff List"], checked = DBM.bPushPartyBuffList }):Click(function(bCheck)
		DBM.bPushPartyBuffList = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, txt = _L["Screen Head Alarm"], checked = DBM.bPushScreenHead }):Click(function(bCheck)
		DBM.bPushScreenHead = bCheck
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Team Panel Bind Show Buff"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Team Panel Bind Show Buff"], checked = DBM.bPushTeamPanel }):Click(function(bCheck)
		DBM.bPushTeamPanel = bCheck
		FireUIEvent("DBM_CREATE_CACHE")
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Buff List"], font = 27 }):Pos_()
	nX = ui:Append("WndComboBox", { x = 10, y = nY + 10, txt = _L["Max Buff Count"] }):Menu(function()
		local menu = {}
		for k, v in ipairs({ 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }) do
			table.insert(menu, { szOption = v, bMCheck = true, bChecked = BL_UI.nCount == v, fnAction = function()
				FireUIEvent("JH_BL_RESIZE", nil, v)
			end })
		end
		return menu
	end):Pos_()
	nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 10, txt = _L["Buff Size"] }):Menu(function()
		local menu = {}
		for k, v in ipairs({ 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 100 }) do
			table.insert(menu, { szOption = v, bMCheck = true, bChecked = BL_UI.fScale == v / 55, fnAction = function()
				FireUIEvent("JH_BL_RESIZE", v / 55)
			end })
		end
		return menu
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Data save mode"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Use common data"], checked = DBM.bCommon }):Click(function(bCheck)
		DBM.bCommon = bCheck
	end):Pos_()
	nX = ui:Append("WndButton2", { x = 5, y = nY + 15, txt = _L["Data Panel"] }):Click(DBM_UI.TogglePanel):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 5, y = nY + 15, txt = _L["Export Data"] }):Click(DBM_UI.OpenExportPanel):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 5, y = nY + 15, txt = _L["Import Data"] }):Click(function()
		local szLang = select(3, GetVersion())
		local menu = {}
		table.insert(menu, { szOption = _L["Import Data (local)"], fnAction = function() DBM_UI.OpenImportPanel() end }) -- 有传惨 不要改
		local szLang = select(3, GetVersion())
		if szLang == "zhcn" or szLang == "zhtw" then
			table.insert(menu, { szOption = _L["Import Data (web)"], fnAction = DBM_RemoteRequest.TogglePanel })
		end
		PopupMenu(menu)
	end):Pos_()
end

GUI.RegisterPanel(_L["DBM"], { "ui/Image/UICommon/FBlist.uitex", 34 }, _L["Dungeon"], PS)
