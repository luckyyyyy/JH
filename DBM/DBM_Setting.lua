-- @Author: Webster
-- @Date:   2015-05-25 13:13:46
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-25 16:36:43

local _L = JH.LoadLangPack
local PS = {}

function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0

	ui:Append("WndButton2", { x = 400, y = 20, txt = g_tStrings.HELP_PANEL }):Click(function()
		OpenInternetExplorer("http://www.j3ui.com/DBM/")
	end)

	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Master switch"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Enable DBM Plugin"], checked = DBM.bEnable }):Click(function(bCheck)
		DBM_API.Enable(bCheck, true)
		DBM.bEnable = bCheck
	end):Pos_()
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
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, txt = _L["Screen Head Alert"], checked = DBM.bPushScreenHead }):Click(function(bCheck)
		DBM.bPushScreenHead = bCheck
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Team Panel Bind Show Buff"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Team Panel Bind Show Buff"], checked = DBM.bPushTeamPanel }):Click(function(bCheck)
		DBM.bPushTeamPanel = bCheck
		FireEvent("DBM_CREATE_CACHE")
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Buff List"], font = 27 }):Pos_()
	nX = ui:Append("WndComboBox", { x = 10, y = nY + 10, txt = _L["Max Buff Count"] }):Menu(function()
		local menu = {}
		for k, v in ipairs({ 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }) do
			table.insert(menu, { szOption = v, bMCheck = true, bChecked = BL_UI.nCount == v, fnAction = function() BL_UI.nCount = v end })
		end
		return menu
	end):Pos_()
	nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 10, txt = _L["Buff Size"] }):Menu(function()
		local menu = {}
		for k, v in ipairs({ 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 100 }) do
			table.insert(menu, { szOption = v, bMCheck = true, bChecked = BL_UI.fScale == v / 55, fnAction = function() BL_UI.fScale = v / 55 end })
		end
		return menu
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Data save mode"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Use common data"], checked = DBM.bCommon }):Click(function(bCheck)
		DBM.bCommon = bCheck
	end):Pos_()
	ui:Append("WndButton3", { x = 185, y = nY + 20, txt = _L["Open DBM Panel"] }):Click(DBM_UI.TogglePanel)
end

GUI.RegisterPanel(_L["DBM"], 2041, _L["Dungeon"], PS)
