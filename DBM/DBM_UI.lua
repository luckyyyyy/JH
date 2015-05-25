-- @Author: Webster
-- @Date:   2015-05-14 13:59:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-25 15:07:29

local _L = JH.LoadLangPack
local DBMUI_INIFILE     = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_UI.ini"
local DBMUI_ITEM_L      = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_ITEM_L.ini"
local DBMUI_TALK_L      = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_TALK_L.ini"
local DBMUI_ITEM_R      = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_ITEM_R.ini"
local DBMUI_TALK_R      = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_TALK_R.ini"
local DBMUI_TYPE        = { "BUFF", "DEBUFF", "CASTING", "NPC", "CIRCLE", "TALK" }
local DBMUI_SELECT_TYPE = DBMUI_TYPE[1]
local DBMUI_SELECT_MAP  = _L["All Data"]
local CIRCLE_SELECT_MAP = _L["All Data"]
local DBMUI_SEARCH
local DBMUI_GLOBAL_SEARCH = false
local DBMUI_PANEL_ANCHOR = { s = "CENTER", r = "CENTER", x = 0, y = 0 }

local DBMUI = {
	tAnchor = {}
}

DBM_UI = {}

function DBM_UI.OnFrameCreate()
	this:RegisterEvent("DBMUI_TEMP_UPDATE")
	this:RegisterEvent("DBMUI_TEMP_RELOAD")
	this:RegisterEvent("DBMUI_DATA_RELOAD")
	this:RegisterEvent("CIRCLE_DRAW_UI")
	this:RegisterEvent("UI_SCALED")
	DBMUI_SEARCH = nil -- 重置搜索
	DBMUI.frame = this
	DBMUI.pageset = this:Lookup("PageSet_Main")
	DBMUI_SELECT_TYPE = DBMUI_TYPE[1]
	GUI(this):Title(_L["JX3 DBM Plug-in"]):RegisterClose(DBMUI.ClosePanel)
	for k, v in ipairs(DBMUI_TYPE) do
		local txt = DBMUI.pageset:Lookup("CheckBox_" .. v, "Text_Page_" .. v)
		txt:SetText(_L[v])
		if v == "CIRCLE" and type(Circle) == "nil" then
			DBMUI.pageset:Lookup("CheckBox_" .. v):Enable(false)
			txt:SetFontColor(192, 192, 192)
		end
	end
	this:Lookup("Btn_Close").OnLButtonClick = DBMUI.ClosePanel
	DBMUI.UpdateAnchor(this)
	local ui = GUI(this)
	ui:Append("WndComboBox", "Select_Class", { x = 700, y = 52, txt = _L["All Data"] }):Menu(DBMUI.GetClassMenu)
	-- 首次加载
	-- local nPage = DBMUI.pageset:GetActivePageIndex()
	FireEvent("DBMUI_TEMP_RELOAD")
	FireEvent("DBMUI_DATA_RELOAD")
	-- debug
	if JH.bDebugClient then
		ui:Append("WndButton", { txt = "debug", x = 10, y = 10 }):Click(ReloadUIAddon)
		ui:Append("WndButton", { txt = "Enable", x = 110, y = 10 }):Click(function()
			DBM_API.Enable(true)
		end)
		ui:Append("WndButton", { txt = "Disable", x = 210, y = 10 }):Click(function()
			DBM_API.Enable(false)
		end)
	end
	ui:Fetch("PageSet_Main"):Append("WndEdit", "WndEdit_Search", { x = 50, y = 38, txt = g_tStrings.SEARCH, w = 500, h = 25 }):Focus(function()
		if this:GetText() == g_tStrings.SEARCH then
			this:SetText("")
		end
	end):Change(function(szText)
		if JH.Trim(szText) == "" then
			DBMUI_SEARCH = nil
		else
			DBMUI_SEARCH = JH.Trim(szText)
		end
		FireEvent("DBMUI_TEMP_RELOAD")
		if DBMUI_SELECT_TYPE == "CIRCLE" then
			FireEvent("CIRCLE_DRAW_UI")
		else
			FireEvent("DBMUI_DATA_RELOAD")
		end
	end)
	ui:Fetch("PageSet_Main"):Append("WndCheckBox", { x = 560, y = 38, checked = DBMUI_GLOBAL_SEARCH, txt = _L["Global Search"] }):Click(function(bCheck)
		DBMUI_GLOBAL_SEARCH = bCheck
		FireEvent("DBMUI_DATA_RELOAD")
	end)
	ui:Fetch("PageSet_Main"):Append("WndButton2", { x = 760, y = 40, txt = _L["Clear Temp Record"] }):Click(function()
		DBM_API.ClearTemp(DBMUI_SELECT_TYPE)
	end)
end

function DBM_UI.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		DBMUI.UpdateAnchor(this)
	elseif szEvent == "DBMUI_TEMP_UPDATE" then
		DBMUI.UpdateRList(szEvent, arg0, arg1)
	elseif szEvent == "DBMUI_TEMP_RELOAD" then
		DBMUI.UpdateRList(szEvent, arg0, arg1)
	elseif szEvent == "DBMUI_DATA_RELOAD" then
		DBMUI.UpdateLList(szEvent, arg0, arg1)
	elseif szEvent == "CIRCLE_DRAW_UI" then
		CIRCLE_SELECT_MAP = arg0 or CIRCLE_SELECT_MAP
		if DBMUI_SELECT_TYPE == "CIRCLE" then
			local txt = this:Lookup("Select_Class", "Text_Default")
			if type(arg0) == "string" then
				txt:SetText(CIRCLE_SELECT_MAP)
			elseif type(arg0) == "number" then
				txt:SetText(Circle.GetMapName(CIRCLE_SELECT_MAP))
			end
			DBMUI.UpdateLList(szEvent, "CIRCLE")
		end
	end
end

function DBM_UI.OnFrameDragEnd()
	DBMUI.tAnchor = GetFrameAnchor(this)
end

function DBM_UI.OnActivePage()
	local nPage = this:GetActivePageIndex()
	local txt = DBMUI.frame:Lookup("Select_Class", "Text_Default")
	DBMUI_SELECT_TYPE = DBMUI_TYPE[nPage + 1]
	FireEvent("DBMUI_TEMP_RELOAD", DBMUI_TYPE[nPage + 1])
	if DBMUI_SELECT_TYPE ~= "CIRCLE" then
		FireEvent("DBMUI_DATA_RELOAD", DBMUI_TYPE[nPage + 1])
		if DBMUI_SELECT_MAP == -1 then
			txt:SetText(g_tStrings.CHANNEL_COMMON)
		elseif DBMUI_SELECT_MAP == _L["All Data"] then
			txt:SetText(_L["All Data"])
		else
			txt:SetText(Table_GetMapName(DBMUI_SELECT_MAP))
		end
	else
		FireEvent("CIRCLE_DRAW_UI", CIRCLE_SELECT_MAP)
	end
end

function DBMUI.OutputTip(szType, data, rect)
	if szType == "BUFF" or szType == "DEBUFF" then
		OutputBuffTipA(data.dwID, data.nLevel, rect)
	elseif szType == "CASTING" then
		OutputSkillTip(data.dwID, data.nLevel, rect)
	elseif szType == "NPC" then
		OutputNpcTip2(data.dwID or data.key, rect)
	elseif szType == "TALK" then
		OutputTip(GetFormatText((data.szTarget or _L["Warning Box"]) .. "\t", 41, 255, 255, 0) .. GetFormatText(DBMUI.GetMapName(data.dwMapID) .. "\n", 41, 255, 255, 255) .. GetFormatText(data.szContent, 41, 255, 255, 255), 300, rect)
	end
end

function DBMUI.InsertDungeonMenu(menu, fnAction)
	local tClass, tDungeon, nCount = {}, DBM_API.GetDungeon()
	local data = DBM_API.GetTable(DBMUI_SELECT_TYPE)
	table.insert(menu, { szOption = g_tStrings.CHANNEL_COMMON .. " (" .. (data[-1] and #data[-1] or 0) .. ")", fnAction = function()
		if fnAction then
			fnAction(-1)
		end
	end })
	table.insert(menu, { bDevide = true })
	for k, v in ipairs(tDungeon) do
		if not tClass[v.szLayer3Name] then
			tClass[v.szLayer3Name] = { szOption = v.szLayer3Name }
			table.insert(menu, tClass[v.szLayer3Name])
		end
		table.insert(tClass[v.szLayer3Name], { szOption = Table_GetMapName(v.dwMapID) .. " (" .. (data[v.dwMapID] and #data[v.dwMapID] or 0) .. ")", rgb = { 255, 128, 0 }, fnAction = function()
			if fnAction then
				fnAction(v.dwMapID)
			end
		end })
	end
end

function DBMUI.OpenImportPanel(szFileName)
	if Station.Lookup("Normal/DBM_DatatPanel") then
		Wnd.CloseWindow(Station.Lookup("Normal/DBM_DatatPanel"))
	end
	GUI.CreateFrame("DBM_DatatPanel", { w = 550, h = 300, title = _L["Import Data"], close = true }):RegisterClose()
	local ui = GUI(Station.Lookup("Normal/DBM_DatatPanel"))
	local nX, nY = ui:Append("Text", { x = 20, y = 50, txt = _L["includes"], font = 27 }):Pos_()
	nX = 25
	for k, v in ipairs(DBMUI_TYPE) do
		nX = ui:Append("WndCheckBox", v, { x = nX + 5, y = nY + 5, checked = true, txt = _L[v] }):Pos_()
	end
	nY = 100
	local szFileName = szFileName or ""
	nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["File Name"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndEdit", { x = 30, y = nY + 10, w = 500, h = 25, txt = szFileName }):Change(function(szText)
		szFileName = szText
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["Import mode"], font = 27 }):Pos_()
	local nType = 1
	nX = ui:Append("WndRadioBox", { x = 30, y = nY + 10, txt = _L["Cover"], group = "type", checked = true }):Click(function()
		nType = 1
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = _L["Merge"], group = "type" }):Click(function()
		nType = 2
	end):Pos_()
	ui:Append("WndButton3", { x = 205, y = nY + 30, txt = g_tStrings.STR_HOTKEY_SURE }):Click(function()
		local config = {
			szFileName = szFileName,
			nMode = nType,
			tList = {}
		}
		for k, v in ipairs(DBMUI_TYPE) do
			if ui:Fetch(v):Check() then
				config.tList[v] = true
			end
		end
		local bStatus, path = DBM_API.LoadConfigureFile(config)
		if bStatus then
			JH.Sysmsg(_L("Import success %s", path))
			ui:Remove()
		else
			JH.Sysmsg2(_L("Import failed %s", path))
		end
	end)
end

function DBMUI.OpenExportPanel()
	if Station.Lookup("Normal/DBM_DatatPanel") then
		Wnd.CloseWindow(Station.Lookup("Normal/DBM_DatatPanel"))
	end
	GUI.CreateFrame("DBM_DatatPanel", { w = 550, h = 300, title = _L["Export Data"], close = true }):RegisterClose()
	local ui = GUI(Station.Lookup("Normal/DBM_DatatPanel"))
	local nX, nY = ui:Append("Text", { x = 20, y = 50, txt = _L["includes"], font = 27 }):Pos_()
	nX = 25
	for k, v in ipairs(DBMUI_TYPE) do
		nX = ui:Append("WndCheckBox", v, { x = nX + 5, y = nY + 5, checked = true, txt = _L[v] }):Pos_()
	end
	nY = 100
	local szFileName = "DBM-" .. select(3, GetVersion()) .. FormatTime("-%Y-%m-%d_%H.%M.%S", GetCurrentTime()) .. ".jx3dat"
	nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["File Name"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndEdit", { x = 30, y = nY + 10, w = 500, h = 25, txt = szFileName }):Change(function(szText)
		szFileName = szText
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["File Format"], font = 27 }):Pos_()
	local nType = 1
	nX = ui:Append("WndRadioBox", { x = 30, y = nY + 10, txt = _L["LUA TABLE"], group = "type", checked = true }):Click(function()
		nType = 1
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = _L["JSON"], group = "type" }):Click(function()
		nType = 2
	end):Pos_()
	ui:Append("WndCheckBox", "Format", { x = 20, y = nY + 50, txt = _L["Format content"] })
	ui:Append("WndButton3", { x = 205, y = nY + 30, txt = g_tStrings.STR_HOTKEY_SURE }):Click(function()
		local config = {
			bFormat = ui:Fetch("Format"):Check(),
			szFileName = szFileName,
			bJson = nType == 2,
			tList = {}
		}
		for k, v in ipairs(DBMUI_TYPE) do
			if ui:Fetch(v):Check() then
				config.tList[v] = true
			end
		end
		local path = DBM_API.SaveConfigureFile(config)
		JH.Alert(_L("Export success %s", path))
		ui:Remove()
	end)
end

function DBMUI.GetClassMenu()
	if DBMUI_SELECT_TYPE == "CIRCLE" then
		return Circle.GetMemu()
	end
	local txt = this:GetParent():Lookup("", "Text_Default")
	local menu, tClass, tDungeon = {}, {}, DBM_API.GetDungeon()
	table.insert(menu, { szOption = _L["All Data"], fnAction = function()
		txt:SetText(_L["All Data"])
		DBMUI_SELECT_MAP = _L["All Data"]
		FireEvent("DBMUI_DATA_RELOAD")
	end })
	table.insert(menu, { bDevide = true })
	DBMUI.InsertDungeonMenu(menu, function(dwMapID)
		txt:SetText(DBMUI.GetMapName(dwMapID))
		DBMUI_SELECT_MAP = dwMapID
		FireEvent("DBMUI_DATA_RELOAD")
	end)
	table.insert(menu, { bDevide = true })
	table.insert(menu, { szOption = _L["Import Data"], fnAction = DBMUI.OpenImportPanel })
	table.insert(menu, { szOption = _L["import Data (web)"], fnAction = DBM_RemoteRequest.OpenPanel })
	table.insert(menu, { szOption = _L["Export Data"], fnAction = DBMUI.OpenExportPanel })
	return menu
end

-- 移动数据
function DBMUI.MoveData( ... )
	DBM_API.MoveData(DBMUI_SELECT_TYPE, ... )
end

function DBMUI.RemoveData(dwMapID, nIndex, szMsg, bConfirm)
	local function fnAction()
		DBM_API.RemoveData(DBMUI_SELECT_TYPE, dwMapID, nIndex)
	end
	if bConfirm then
		JH.Confirm(FormatString(g_tStrings.MSG_DELETE_NAME, szMsg), fnAction)
	else
		fnAction()
	end
end

-- 更新监控数据
function DBMUI.UpdateLList(szEvent, szType, data)
	szType = szType or DBMUI_SELECT_TYPE
	if szType ~= DBMUI_SELECT_TYPE then
		return
	end
	if szEvent == "DBMUI_DATA_RELOAD" then
		local tab = DBM_API.GetTable(szType)
		if tab then
			local dat, dat2 = tab[DBMUI_SELECT_MAP] or {}, {}
			if DBMUI_SEARCH then
				for k, v in ipairs(dat) do
					local szName = DBMUI.GetBoxInfo(v, szType)
					if szName:match(DBMUI_SEARCH)
						or (v.dwID and tostring(v.dwID):match(DBMUI_SEARCH))
						or (v.szTarget and tostring(v.szTarget):match(DBMUI_SEARCH))
						or (DBMUI_GLOBAL_SEARCH and JH.JsonEncode(v):match(DBMUI_SEARCH))
					then
						table.insert(dat2, v)
					end
				end
			else
				dat2 = dat
			end
			DBMUI.DrawTableL(szType, dat2)
		end
	elseif szEvent == "CIRCLE_DRAW_UI" then
		local tab = DBM_API.GetTable(szType)
		if tab then
			local dat, dat2 = tab[CIRCLE_SELECT_MAP] or {}, {}
			if DBMUI_SEARCH then
				for k, v in ipairs(dat) do
					if tostring(v.key):match(DBMUI_SEARCH) or (v.szNote and tostring(v.szNote):match(DBMUI_SEARCH)) then
						table.insert(dat2, v)
					end
				end
			else
				dat2 = dat
			end
			DBMUI.DrawTableL(szType, dat2)
		end
	end
end

function DBMUI.GetBoxInfo(data, szType)
	local szName, nIcon
	if szType == "CASTING" then
		szName, nIcon = JH.GetSkillName(data.dwID, data.nLevel)
	elseif szType == "NPC" or szType == "CIRCLE" then
		local KTemplate = GetNpcTemplate(data.dwID)
		szName = KTemplate.szName
		if szName == "" then
			szName = Table_GetNpcTemplateName(data.dwID)
		end
		if JH.Trim(szName) == "" then
			szName = tostring(data.dwID)
		end
		nIocn = data.nFrame
	elseif szType == "TALK" then
		szName = data.szContent
	else
		szName, nIcon = JH.GetBuffName(data.dwID, data.nLevel)
	end
	nIcon = data.nIcon or nIcon
	szName = data.szName or szName
	return szName, nIcon
end

function DBMUI.SetBuffItemAction(h, dat)
	local szName, nIcon = DBMUI.GetBoxInfo(dat)
	h:Lookup("Text"):SetText(szName)
	if dat.col then
		h:Lookup("Text"):SetFontColor(unpack(dat.col))
	end
	local box = h:Lookup("Box")
	box:SetObjectIcon(nIcon)
	if dat.nCount then
		box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
		box:SetOverTextFontScheme(0, 15)
		box:SetOverText(0, dat.nCount)
	end
	h.OnItemMouseEnter = function()
		box:SetObjectMouseOver(true)
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		DBMUI.OutputTip("BUFF", dat, { x, y, w, h })
	end
	h.OnItemMouseLeave = function()
		box:SetObjectMouseOver(false)
		HideTip()
	end
end

function DBMUI.SetCastingItemAction(h, dat)
	local szName, nIcon = DBMUI.GetBoxInfo(dat, "CASTING")
	h:Lookup("Text"):SetText(szName)
	if dat.col then
		h:Lookup("Text"):SetFontColor(unpack(dat.col))
	end
	local box = h:Lookup("Box")
	box:SetObjectIcon(nIcon)
	h.OnItemMouseEnter = function()
		box:SetObjectMouseOver(true)
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		DBMUI.OutputTip("CASTING", dat, { x, y, w, h })
	end
	h.OnItemMouseLeave = function()
		box:SetObjectMouseOver(false)
		HideTip()
	end
end

function DBMUI.SetNpcItemAction(h, dat)
	local szName = DBMUI.GetBoxInfo(dat, "NPC")
	h:Lookup("Text"):SetText(szName)
	if dat.col then
		h:Lookup("Text"):SetFontColor(unpack(dat.col))
	end
	local box = h:Lookup("Box")
	box:ClearObjectIcon()
	box:SetExtentImage("ui/Image/TargetPanel/Target.UITex", dat.nFrame)
	h.OnItemMouseEnter = function()
		if this:IsValid() then
			box:SetObjectMouseOver(true)
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			DBMUI.OutputTip("NPC", dat, { x, y, w, h })
		end
	end
	h.OnItemMouseLeave = function()
		if this:IsValid() then
			box:SetObjectMouseOver(false)
			HideTip()
		end
	end
end

function DBMUI.SetCircleItemAction(h, dat)
	h:Lookup("Text"):SetText(dat.szNote and string.format("%s (%s)", dat.key, dat.szNote) or dat.key)
	local box = h:Lookup("Box")
	box:SetObjectIcon(2673)
	h.OnItemMouseEnter = function()
		if this:IsValid() then
			box:SetObjectMouseOver(true)
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			if tonumber(dat.key) then
				DBMUI.OutputTip("NPC", dat, { x, y, w, h })
			else
				OutputTip(GetFormatText((dat.szNote and string.format("%s (%s)", dat.key, dat.szNote) or dat.key) .. "\n" .. Circle.GetMapName(dat.id or CIRCLE_SELECT_MAP), 41, 255, 255, 255), 300, { x, y, w, h })
			end
		end
	end
	h.OnItemMouseLeave = function()
		if this:IsValid() then
			box:SetObjectMouseOver(false)
			HideTip()
		end
	end
end

function DBMUI.SetTalkItemAction(h, t, i)
	h:Lookup("Text_Name"):SetText(t.szTarget or _L["Warning Box"])
	if not t.szTarget then
		h:Lookup("Text_Name"):SetFontColor(255, 255, 0)
	end
	h:Lookup("Text_Content"):SetText(t.szContent)
	if t.col then
		h:Lookup("Text_Content"):SetFontColor(unpack(t.col))
	end
	h.OnItemMouseEnter = function()
		if this:IsValid() then
			this:Lookup("Image_Light"):Show()
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			DBMUI.OutputTip("TALK", t, { x, y, w, h })
		end
	end
	h.OnItemMouseLeave = function()
		if this:IsValid() then
			this:Lookup("Image_Light"):Hide()
			HideTip()
		end
	end
end

function DBMUI.GetMapName(mapid)
	if mapid == -1 then
		return g_tStrings.CHANNEL_COMMON
	else
		return Table_GetMapName(mapid) or mapid
	end
end

function DBMUI.SetLItemAction(szType, h, t)
	h.OnItemLButtonClick = function()
		DBMUI.OpenSettingPanel(t, szType)
	end
	h.OnItemRButtonClick = function()
		local menu = {}
		if szType ~= "TALK" then
			table.insert(menu, { szOption = g_tStrings.CHAT_NAME .. g_tStrings.STR_COLON .. h:Lookup("Text"):GetText(), bDisable = true })
		end
		table.insert(menu, { szOption = _L["Class"] .. g_tStrings.STR_COLON .. DBMUI.GetMapName(t.dwMapID), bDisable = true })
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = g_tStrings.STR_FRIEND_MOVE_TO })
		DBMUI.InsertDungeonMenu(menu[#menu], function(dwMapID)
			DBMUI.MoveData(t.dwMapID, t.nIndex, dwMapID, IsCtrlKeyDown())
		end)
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = g_tStrings.STR_FRIEND_DEL, rgb = { 255, 0, 0 }, fnAction = function()
			DBMUI.RemoveData(t.dwMapID, t.nIndex, h:Lookup("Text") and h:Lookup("Text"):GetText() or t.szContent, true)
		end })
		PopupMenu(menu)
	end
end

function DBMUI.SetLCircleItemAction(h, t, i)
	h.OnItemLButtonClick = function()
		Circle.OpenDataPanel(t.id or CIRCLE_SELECT_MAP, t.index or i)
	end
	h.OnItemRButtonClick = h.OnItemLButtonClick
end

function DBMUI.DrawTableL(szType, data)
	local page = DBMUI.pageset:GetActivePage()
	local handle = page:Lookup("WndScroll_" .. szType .. "_L", "Handle_" .. szType .. "_List_L")
	local function SetDataAction(h, t, i)
		if not t.dwMapID then
			setmetatable(t, { __index = function(me, val)
				if val == "dwMapID" then
					return DBMUI_SELECT_MAP
				elseif val == "nIndex" then
					return i
				end
			end })
		end
		if szType == "BUFF" or szType == "DEBUFF" then
			DBMUI.SetBuffItemAction(h, t)
			DBMUI.SetLItemAction(szType, h, t)
		elseif szType == "CASTING" then
			DBMUI.SetCastingItemAction(h, t)
			DBMUI.SetLItemAction(szType, h, t)
		elseif szType == "NPC" then
			DBMUI.SetNpcItemAction(h, t)
			DBMUI.SetLItemAction(szType, h, t)
		elseif szType == "CIRCLE" then
			DBMUI.SetCircleItemAction(h, t)
			DBMUI.SetLCircleItemAction(h, t, i)
		elseif szType == "TALK" then
			DBMUI.SetTalkItemAction(h, t, i)
			DBMUI.SetLItemAction(szType, h, t)
		end
	end
	local ini = szType == "TALK" and DBMUI_TALK_L or DBMUI_ITEM_L
	handle:Clear()
	if #data > 0 then
		for i = #data, 1, -1 do
			local dat = data[i]
			local h = handle:AppendItemFromIni(ini, "Handle_L")
			SetDataAction(h, dat, i)
		end
	end
	handle:FormatAllItemPos()
end

-- 更新临时数据
function DBMUI.UpdateRList(szEvent, szType, data)
	szType = szType or DBMUI_SELECT_TYPE
	szType = (DBMUI_SELECT_TYPE == "CIRCLE" and szType == "NPC") and "CIRCLE" or szType
	if szType ~= DBMUI_SELECT_TYPE then
		return
	end
	if szEvent == "DBMUI_TEMP_UPDATE" then
		DBMUI.DrawTableR(szType, data, true)
	elseif szEvent == "DBMUI_TEMP_RELOAD" then
		local tab, tab2 = DBM_API.GetTable(szType, true), {}
		if tab then
			if DBMUI_SEARCH then
				for k, v in ipairs(tab) do
					local szName = DBMUI.GetBoxInfo(v, szType)
					if szName:match(DBMUI_SEARCH)
						or (v.dwID and tostring(v.dwID):match(DBMUI_SEARCH))
						or (v.szTarget and tostring(v.szTarget):match(DBMUI_SEARCH))
						or (DBMUI_GLOBAL_SEARCH and JH.JsonEncode(v):match(DBMUI_SEARCH))
					then
						table.insert(tab2, v)
					end
				end
			else
				tab2 = tab
			end
			DBMUI.DrawTableR(szType, tab2)
		end
	end
end

function DBMUI.SetRItemAction(szType, h, t)
	h.OnItemLButtonClick = function()
		DBMUI.OpenAddPanel(szType, t)
	end
	h.OnItemRButtonClick = function()
		local menu = {}
		local szName = DBMUI.GetBoxInfo(t, szType)
		table.insert(menu, { szOption = _L["Add to monitor list"], fnAction = h.OnItemLButtonClick })
		table.insert(menu, { bDevide = true })
		if szType ~= "TALK" then
			table.insert(menu, { szOption = g_tStrings.CHAT_NAME .. g_tStrings.STR_COLON .. szName, bDisable = true })
		end
		table.insert(menu, { szOption = g_tStrings.MAP_TALK .. g_tStrings.STR_COLON .. Table_GetMapName(t.dwMapID), bDisable = true })
		if szType ~= "NPC" and szType ~= "CIRCLE" and szType ~= "TALK" then
			table.insert(menu, { szOption = g_tStrings.STR_SKILL_H_CAST_TIME .. (t.bIsPlayer and _L["(player)"]) .. (t.szSrcName or g_tStrings.STR_CRAFT_NONE), bDisable = true })
		end
		PopupMenu(menu)
	end
end

function DBMUI.DrawTableR(szType, data, bInsert)
	local page = DBMUI.pageset:GetActivePage()
	local handle = page:Lookup("WndScroll_" .. szType .. "_R", "Handle_" .. szType .. "_List_R")
	local function SetDataAction(h, t, i)
		if szType == "BUFF" or szType == "DEBUFF" then
			DBMUI.SetBuffItemAction(h, t)
		elseif szType == "CASTING" then
			DBMUI.SetCastingItemAction(h, t)
		elseif szType == "NPC" or szType == "CIRCLE" then
			DBMUI.SetNpcItemAction(h, t)
		elseif szType == "TALK" then
			DBMUI.SetTalkItemAction(h, t, i)
		end
		DBMUI.SetRItemAction(szType, h, t)
	end
	local ini = szType == "TALK" and DBMUI_TALK_R or DBMUI_ITEM_R
	if not bInsert then
		handle:Clear()
		if #data > 0 then
			for i = #data, 1, -1 do
				local dat = data[i]
				local h = handle:AppendItemFromIni(ini, "Handle_R")
				SetDataAction(h, dat, i)
			end
		end
	else
		handle:InsertItemFromIni(0, false, ini, "Handle_R")
		SetDataAction(handle:Lookup(0), data, 0)
	end
	handle:FormatAllItemPos()
end
-- 添加面板
function DBMUI.OpenAddPanel(szType, data)
	if szType == "CIRCLE" then
		Circle.OpenAddPanel(DBMUI.GetBoxInfo(data, "NPC"), TARGET.NPC, Table_GetMapName(data.dwMapID))
	else
		if Station.Lookup("Normal/DBM_NewData") then
			Wnd.CloseWindow(Station.Lookup("Normal/DBM_NewData"))
		end
		local szName, nIcon = _L["TALK"], 340
		if szType ~= "TALK" then
			szName, nIcon = DBMUI.GetBoxInfo(data, szType)
		end
		local nClass
		if DBMUI_SELECT_MAP ~= _L["All Data"] then
			nClass = DBMUI_SELECT_MAP
		end
		GUI.CreateFrame("DBM_NewData", { w = 380, h = 250, title = szName, close = true }):RegisterClose()
		local frame = Station.Lookup("Normal/DBM_NewData")
		local nX, nY, ui = 0, 0, GUI(frame)
		frame:RegisterEvent("DBMUI_TEMP_RELOAD")
		frame.OnEvent = function(szEvent)
			if szEvent == "DBMUI_TEMP_RELOAD" then
				ui:Remove()
			end
		end
		if szType ~= "NPC" then
			nX, nY = ui:Append("Box", "Box_Icon", { w = 48, h = 48, x = 166, y = 40, icon = nIcon }):Pos_()
		else
			nX, nY = ui:Append("Box", "Box_Icon", { w = 48, h = 48, x = 166, y = 40, icon = nIcon }):File("ui/Image/TargetPanel/Target.uitex", data.nFrame):Pos_()
		end
		ui:Fetch("Box_Icon"):Hover(function(bHover)
			this:SetObjectMouseOver(bHover)
			if bHover then
				local x, y = this:GetAbsPos()
				local w, h = this:GetSize()
				DBMUI.OutputTip(szType, data, { x, y, w, h })
			else
				HideTip()
			end
		end)
		nX, nY = ui:Append("WndComboBox", "Select_Class", { x = 100, y = nY + 15, txt = nClass and DBMUI.GetMapName(nClass) or _L["Please Select Class"] }):Menu(function()
			local t = {}
			local txt = ui:Fetch("Select_Class")
			DBMUI.InsertDungeonMenu(t, function(dwMapID)
				txt:Text(DBMUI.GetMapName(dwMapID))
				nClass = dwMapID
			end)
			return t
		end):Pos_()
		ui:Append("WndButton3", { x = 120, y = nY + 40, txt = _L["Add"] }):Click(function()
			if not nClass then
				return JH.Alert(_L["Please Select Class"])
			end
			local tab = select(2, DBM_API.CheckRepeatData(szType, nClass, data.dwID or data.szContent, data.nLevel or data.szTarget))
			if tab then
				return JH.Confirm(_L["Data already exists, whether editor?"], function()
					DBMUI.OpenSettingPanel(tab, szType)
					ui:Remove()
				end)
			end
			local dat = {
				dwID      = data.dwID,
				nLevel    = data.nLevel,
				nFrame    = data.nFrame,
				szContent = data.szContent,
				szTarget  = data.szTarget
			}
			DBMUI.OpenSettingPanel(DBM_API.AddData(szType, nClass, dat), szType)
			ui:Remove()
		end)
	end
end
-- 数据调试面板
function DBMUI.OpenJosnPanel(data, fnAction)
	local json = JH.JsonEncode(data, true)
	local wnd = GUI.CreateFrame("DBM_JsonPanel", { w = 720,h = 500, title = _L["Json Data"], close = true }):RegisterClose()
	wnd:Append("WndEdit", "WndEdit",{ w = 660, h = 350, x = 0, y = 0, color = { 255, 255, 0 }, multi = true, limit = 999999,txt = json })
	wnd:Append("WndButton3",{ x = 10, y = 370,txt = _L["import"] }):Click(function()
		local json = wnd:Fetch("WndEdit"):Text()
		local dat = JH.JsonToTable(json)
		if fnAction and dat then
			wnd:Remove()
			return fnAction(dat)
		end
	end)
end

-- 设置面板
function DBMUI.OpenSettingPanel(data, szType)
	local function GetScrutinyTypeMenu()
		local menu = {
			{ szOption = g_tStrings.STR_GUILD_ALL, bMCheck = true, bChecked = type(data.nScrutinyType) == "nil", fnAction = function() data.nScrutinyType = nil end },
			-- { bDevide = true },
			{ szOption = g_tStrings.MENTOR_SELF, bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.SELF, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.SELF end },
			{ szOption = _L["Team"], bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.TEAM, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.TEAM end },
			{ szOption = _L["Enemy"], bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.ENEMY, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.ENEMY end },
		}
		return menu
	end
	local function GetMarkMenu(nClass)
		local menu = {}
		local tMarkName = { _L["Cloud"], _L["Sword"], _L["Ax"], _L["Hook"], _L["Drum"], _L["Shear"], _L["Stick"], _L["Jade"], _L["Dart"], _L["Fan"] }
		for k, v in ipairs(PARTY_MARK_ICON_FRAME_LIST) do
			table.insert(menu, { szOption = tMarkName[k], szIcon = PARTY_MARK_ICON_PATH, nFrame = v, szLayer = "ICON_RIGHT", bCheck = true, bChecked = data[nClass] and data[nClass].tMark and data[nClass].tMark[k], fnAction = function(_, bCheck)
				if bCheck then
					data[nClass] = data[nClass] or {}
					if not data[nClass].tMark then
						data[nClass].tMark = {}
						for kk, vv in ipairs(PARTY_MARK_ICON_FRAME_LIST) do
							data[nClass].tMark[kk] = false
						end
					end
					data[nClass].tMark[k] = true
				else
					data[nClass].tMark[k] = false
					local bDelete = true
					for k, v in ipairs(data[nClass].tMark) do
						if v then
							bDelete = false
							break
						end
					end
					if bDelete then
						data[nClass].tMark = nil
					end
					if IsEmpty(data[nClass]) then data[nClass] = nil end
				end
			end })
		end
		return menu
	end
	local function SetDataClass(nClass, key, value)
		if value then
			data[nClass] = data[nClass] or {}
			data[nClass][key] = value
		else
			data[nClass][key] = nil
			if IsEmpty(data[nClass]) then
				data[nClass] = nil
			end
		end
	end

	local function UI_tonumber(szNum, nDefault)
		if tonumber(szNum) then
			return tonumber(szNum)
		else
			return nDefault
		end
	end

	local function SetCountdownType(dat, val, ui)
		dat.nClass = val
		ui:Text(_L["Countdown TYPE " ..  dat.nClass])
		GetPopupMenu():Hide()
	end

	local function CheckCountdown(tTime)
		if tonumber(tTime) then
			return true
		else
			local tab = {}
			local t = JH.Split(tTime, ";")
			for k, v in ipairs(t) do
				local time = JH.Split(v, ",")
				if time[1] and time[2] and tonumber(JH.Trim(time[1])) and time[2] ~= "" then
					table.insert(tab, { nTime = tonumber(time[1]), szName = time[2] })
				elseif JH.Trim(time[1]) ~= "" and not tonumber(time[1]) then
					return false
				elseif tonumber(time[1]) and (not time[2] or JH.Trim(time[2]) == "") then
					return false
				end
			end
			if IsEmpty(tab) then
				return false
			else
				table.sort(tab, function(a, b)
					return a.nTime < b.nTime
				end)
				return tab
			end
		end
	end
	local tSkillInfo
	local me = GetClientPlayer()
	local file = "ui/Image/UICommon/Feedanimials.uitex"
	local szName, nIcon = _L["TALK"], 340
	if szType ~= "TALK" then
		szName, nIcon = DBMUI.GetBoxInfo(data, szType)
	end
	local wnd = GUI.CreateFrame("DBM_SettingPanel", { w = 770, h = 450, title = szName, close = true }):RegisterClose()
	local frame = Station.Lookup("Normal/DBM_SettingPanel")
	local ui = GUI(frame)
	frame:RegisterEvent("DBMUI_DATA_RELOAD")
	frame.OnEvent = function(szEvent)
		if szEvent == "DBMUI_DATA_RELOAD" then
			ui:Remove()
		end
	end
	frame.OnFrameDragEnd = function()
		DBMUI_PANEL_ANCHOR = GetFrameAnchor(frame, "LEFTTOP")
	end
	local nX, nY, _ = 0, 0, 0

	local function ClickBox()
		local menu, box = {}, this
		if szType ~= "TALK" then
			table.insert(menu, { szOption = _L["Edit Name"], fnAction = function()
				GetUserInput(_L["Edit Name"], function(szText)
					if JH.Trim(szText) == "" then
						data.szName = nil
						wnd:Title(szName)
					else
						data.szName = szText
						wnd:Title(szText)
					end
				end, nil, nil, nil, data.szName or szName)
			end})
			table.insert(menu, { bDevide = true })
		end
		if szType ~= "NPC" and szType ~= "TALK" then
			table.insert(menu, { szOption = _L["Edit Iocn"], fnAction = function()
				GUI.OpenIconPanel(function(nIcon)
					data.nIcon = nIcon
					box:SetObjectIcon(nIcon)
				end)
			end})
			table.insert(menu, { bDevide = true })
		end
		table.insert(menu, { szOption = _L["Edit Color"], fnAction = function()
			GUI.OpenColorTablePanel(function(r, g, b)
				data.col = { r, g, b }
				ui:Fetch("Shadow_Color"):Color(r, g, b):Alpha(255)
			end)
		end })
		if data.col then
			table.insert(menu, { szOption = _L["Clear Color"], fnAction = function()
				data.col = nil
				ui:Fetch("Shadow_Color"):Alpha(0)
			end })
		end
		if JH.bDebugClient then
			table.insert(menu, { bDevide = true })
			table.insert(menu, { szOption = _L["Edit raw data, Please be careful"], color = { 255, 255, 0 }, fnAction = function()
				DBMUI.OpenJosnPanel(data, function(dat)
					for k, v in pairs(dat) do
						data[k] = v
					end
					DBMUI.OpenSettingPanel(data, szType)
				end)
			end })
		end
		PopupMenu(menu)
	end

	ui:Append("Shadow", "Shadow_Color", { w = 52, h = 52, x = 359, y = 38, color = data.col, alpha = data.col and 255 or 0 })
	if szType ~= "NPC" then
		nX, nY = ui:Append("Box", "Box_Icon", { w = 48, h = 48, x = 361, y = 40, icon = nIcon }):Pos_()
	else
		nX, nY = ui:Append("Box", "Box_Icon", { w = 48, h = 48, x = 361, y = 40, icon = nIcon }):File("ui/Image/TargetPanel/Target.uitex", data.nFrame):Pos_()
	end
	ui:Fetch("Box_Icon"):Hover(function(bHover)
		this:SetObjectMouseOver(bHover)
		if bHover then
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			DBMUI.OutputTip(szType, data, { x, y, w, h })
		else
			HideTip()
		end
	end):Click(ClickBox)
	if szType == "BUFF" or szType == "DEBUFF" then
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = g_tStrings.CHANNEL_COMMON, font = 27 }):Pos_()
		nX = ui:Append("WndComboBox", { x = 30, y = nY + 12, txt = _L["Scrutiny Type"] }):Menu(function()
			return GetScrutinyTypeMenu(data)
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 5, y = nY + 10, txt = _L["Count Achieve"] }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 2, y = nY + 12, w = 30, h = 26, txt = data.nCount or 1 }):Type(0):Change(function(nNum)
			data.nCount = UI_tonumber(nNum)
			if data.nCount == 1 then
				data.nCount = nil
			end
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bCheckLevel, txt = _L["Check Level"] }):Click(function(bCheck)
			data.bCheckLevel = bCheck and true or nil
		end):Pos_()
		-- get buff
		local cfg = data[DBM_TYPE.BUFF_GET] or {}
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Get Buff"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 8, w = 60, h = 25, txt = _L["Mark"] }):Menu(function()
			return GetMarkMenu(DBM_TYPE.BUFF_GET)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bScreenHead, txt = _L["Screen Head Alert"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bScreenHead", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bFullScreen", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bPartyBuffList, txt = _L["Party Buff List"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bPartyBuffList", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBuffList, txt = _L["Buff List"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bBuffList", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bTeamPanel, txt = _L["Team Panel"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bTeamPanel", bCheck)
			ui:Fetch("bOnlySelfSrc"):Enable(bCheck)
			FireEvent("DBM_CREATE_CACHE")
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", "bOnlySelfSrc", { x = nX + 5, y = nY, checked = cfg.bOnlySelfSrc, txt = _L["Only Source Self"] }):Enable(cfg.bTeamPanel == true):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bOnlySelfSrc", bCheck)
		end):Pos_()
		-- 失去buff
		local cfg = data[DBM_TYPE.BUFF_LOSE] or {}
		nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Lose Buff"], font = 27 }):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_LOSE, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_LOSE, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_LOSE, "bCenterAlarm", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_LOSE, "bBigFontAlarm", bCheck)
		end):Pos_()
	elseif szType == "CASTING" then
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = g_tStrings.CHANNEL_COMMON, font = 27 }):Pos_()
		nX = ui:Append("WndComboBox", { x = 30, y = nY + 12, txt = _L["Scrutiny Type"] }):Menu(function()
			return GetScrutinyTypeMenu(data)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bCheckLevel, txt = _L["Check Level"] }):Click(function(bCheck)
			data.bCheckLevel = bCheck and true or nil
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bMonTarget, txt = _L["Show Target Name"] }):Click(function(bCheck)
			data.bMonTarget = bCheck and true or nil
		end):Pos_()

		local cfg = data[DBM_TYPE.SKILL_END] or {}
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Skills using a success"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 8, w = 60, h = 25, txt = _L["Mark"] }):Menu(function()
			return GetMarkMenu(DBM_TYPE.SKILL_END)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bFullScreen", bCheck)
		end):Pos_()
		local tRecipeKey = me.GetSkillRecipeKey(data.dwID, data.nLevel)
		tSkillInfo = GetSkillInfo(tRecipeKey)
		if tSkillInfo and tSkillInfo.CastTime ~= 0 then
			local cfg = data[DBM_TYPE.SKILL_BEGIN] or {}
			nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Skills began to release"], font = 27 }):Pos_()
			nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 8, w = 60, h = 25, txt = _L["Mark"] }):Menu(function()
				return GetMarkMenu(DBM_TYPE.SKILL_BEGIN)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bTeamChannel", bCheck)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bWhisperChannel", bCheck)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bCenterAlarm", bCheck)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bBigFontAlarm", bCheck)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bScreenHead, txt = _L["Screen Head Alert"] }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bScreenHead", bCheck)
			end):Pos_()
			nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bFullScreen", bCheck)
			end):Pos_()
		end
	elseif szType == "NPC" then
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = g_tStrings.CHANNEL_COMMON, font = 27 }):Pos_()
		nX = ui:Append("Text", { x = 30, y = nY + 10, txt = _L["Npc Count Achieve"] }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 2, y = nY + 12, w = 30, h = 26, txt = data.nCount or 1 }):Type(0):Change(function(nNum)
			data.nCount = UI_tonumber(nNum)
			if data.nCount == 1 then
				data.nCount = nil
			end
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bAllLeave, txt = _L["Must All leave scene"] }):Click(function(bCheck)
			data.bAllLeave = bCheck and true or nil
			if bCheck then
				ui:Fetch("NPC_LEAVE_TEXT"):Text(_L["Npc All Leave scene"])
			else
				ui:Fetch("NPC_LEAVE_TEXT"):Text(_L["Npc Leave scene"])
			end
		end):Pos_()
		local cfg = data[DBM_TYPE.NPC_ENTER] or {}
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Npc Enter scene"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 8, w = 60, h = 25, txt = _L["Mark"] }):Menu(function()
			return GetMarkMenu(DBM_TYPE.NPC_ENTER)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bScreenHead, txt = _L["Screen Head Alert"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bScreenHead", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bFullScreen", bCheck)
		end):Pos_()
		nX, nY = ui:Append("Text", "NPC_LEAVE_TEXT", { x = 20, y = nY + 5, txt = data.bAllLeave and _L["Npc All Leave scene"] or _L["Npc Leave scene"], font = 27 }):Pos_()
		local cfg = data[DBM_TYPE.NPC_LEAVE] or {}
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_LEAVE, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_LEAVE, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_LEAVE, "bCenterAlarm", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_LEAVE, "bBigFontAlarm", bCheck)
		end):Pos_()
	elseif szType == "TALK" then
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Alert Content"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndEdit", { x = nX + 5, y = nY + 8, txt = data.szNote, w = 650, h = 25 }):Change(function(txt)
			local szText = JH.Trim(txt)
			if szText == "" then
				data.szNote = nil
			else
				data.szNote = szText
			end
		end):Pos_()
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Speaker"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndEdit", { x = nX + 5, y = nY + 8, txt = data.szTarget or _L["Warning Box"], w = 650, h = 25 }):Change(function(txt)
			local szText = JH.Trim(txt)
			if szText == "" or szText == _L["Warning Box"] then
				data.szTarget = nil
			else
				data.szTarget = szText
			end
		end):Pos_()
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Content"], font = 27 }):Pos_()
		_, nY = ui:Append("WndEdit", { x = nX + 5, y = nY + 8, txt = data.szContent, w = 650, h = 55, multi = true }):Change(function(txt)
			data.szContent = JH.Trim(txt)
		end):Pos_()
		nX, nY = ui:Append("Text", { x = nX, y = nY, txt = _L["Tips:$me behalf of self, $team behalf of team, Only allow a time"], alpha = 200 }):Pos_()
		nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Trigger Talk"], font = 27 }):Pos_()
		local cfg = data[DBM_TYPE.TALK_MONITOR] or {}
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bScreenHead, txt = _L["Screen Head Alert"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bScreenHead", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bFullScreen", bCheck)
		end):Pos_()
	end
	if szType ~= "TALK" then
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["Add Content"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndEdit", { x = 30, y = nY + 10, txt = data.szNote, w = 650, h = 25 }):Change(function(txt)
			local szText = JH.Trim(txt)
			if szText == "" then
				data.szNote = nil
			else
				data.szNote = szText
			end
		end):Pos_()
	end
	-- 倒计时
	nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Countdown"], font = 27 }):Pos_()
	nY = nY + 10
	for k, v in ipairs(data.tCountdown or {}) do
		nX = ui:Append("WndComboBox", "Countdown" .. k, { x = 30, w = 155, h = 25, y = nY, txt = v.nClass == -1 and _L["Please Select Type"] or _L["Countdown TYPE " ..  v.nClass] }):Menu(function()
			local menu = {}
			table.insert(menu, { szOption = _L["Please Select Type"], bDisable = true, bChecked = v.nClass == -1 })
			table.insert(menu, { bDevide = true })
			if szType == "BUFF" or szType == "DEBUFF" then
				for kk, vv in ipairs({ DBM_TYPE.BUFF_GET, DBM_TYPE.BUFF_LOSE }) do
					table.insert(menu, { szOption = _L["Countdown TYPE " .. vv], bMCheck = true, bChecked = v.nClass == vv, fnAction = function()
						SetCountdownType(v, vv, ui:Fetch("Countdown" .. k))
					end })
				end
			elseif szType == "CASTING" then
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.SKILL_END], bMCheck = true, bChecked = v.nClass == DBM_TYPE.SKILL_END, fnAction = function()
					SetCountdownType(v, DBM_TYPE.SKILL_END, ui:Fetch("Countdown" .. k))
				end })
				if tSkillInfo and tSkillInfo.CastTime ~= 0 then
					table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.SKILL_BEGIN], bMCheck = true, bChecked = v.nClass == DBM_TYPE.SKILL_BEGIN, fnAction = function()
						SetCountdownType(v, DBM_TYPE.SKILL_BEGIN, ui:Fetch("Countdown" .. k))
					end })
				end
			elseif szType == "NPC" then
				for kk, vv in ipairs({ DBM_TYPE.NPC_ENTER, DBM_TYPE.NPC_LEAVE, DBM_TYPE.NPC_ALLLEAVE, DBM_TYPE.NPC_FIGHT, DBM_TYPE.NPC_DEATH, DBM_TYPE.NPC_ALLDEATH, DBM_TYPE.NPC_LIFE }) do
					table.insert(menu, { szOption = _L["Countdown TYPE " .. vv], bMCheck = true, bChecked = v.nClass == vv, fnAction = function()
						SetCountdownType(v, vv, ui:Fetch("Countdown" .. k))
						if vv == DBM_TYPE.NPC_LIFE then
							JH.Alert(_L["Npc Life Alarm, different format, Recommended reading Help!"])
						end
					end })
				end
			elseif szType == "TALK" then
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.TALK_MONITOR], bMCheck = true, bChecked = v.nClass == DBM_TYPE.TALK_MONITOR, fnAction = function()
					SetCountdownType(v, DBM_TYPE.TALK_MONITOR, ui:Fetch("Countdown" .. k))
				end })
			end
			return menu
		end):Pos_()
		nX = ui:Append("Box", { x = nX + 5, y = nY, w = 24, h = 24, icon = v.nIcon or nIcon }):Hover(function(bHover) this:SetObjectMouseOver(bHover) end):Click(function()
			local box = this
			GUI.OpenIconPanel(function(nIcon)
				v.nIcon = nIcon
				box:SetObjectIcon(nIcon)
			end)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY - 2, txt = _L["TC"], color = GetMsgFontColor("MSG_TEAM", true), checked = v.bTeamChannel }):Click(function(bCheck)
			v.bTeamChannel = bCheck and true or nil
		end):Pos_()
		ui:Append("WndEdit", "CountdownName" .. k, { x = nX + 5, y = nY, w = 295, h = 25, txt = v.szName }):Toggle(tonumber(v.nTime) and true or false):Change(function(szNum)
			v.szName = szNum
		end):Pos_()
		nX = ui:Append("WndEdit", "CountdownTime" .. k, { x = nX + 5 + (tonumber(v.nTime) and 300 or 0), y = nY, w = tonumber(v.nTime) and 100 or 400, h = 25, txt = v.nTime, color = (v.nClass ~= DBM_TYPE.NPC_LIFE and not CheckCountdown(v.nTime)) and { 255, 0, 0 } }):Change(function(szNum)
			v.nTime = UI_tonumber(szNum, szNum)
			local edit = ui:Fetch("CountdownTime" .. k)
			if szNum == "" then
				return
			end
			if v.nClass == DBM_TYPE.NPC_LIFE then
				return
			else
				if tonumber(szNum) then
					if this:GetW() > 200 then
						local x, y = edit:Pos()
						edit:Pos(x + 300, y):Size(100, 25):Color(255, 255, 255)
						ui:Fetch("CountdownName" .. k):Toggle(true):Text(v.szName or g_tStrings.CHAT_NAME)
					end
				else
					if CheckCountdown(szNum) then
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						local xml = { GetFormatText("[DBM] " .. _L["Countdown Preview"] .. "\n", 0, 255, 255, 0) }
						for k, v in ipairs(CheckCountdown(szNum)) do
							table.insert(xml, GetFormatText(v.nTime .. " - " .. v.szName .. "\n"))
						end
						OutputTip(table.concat(xml), 300, { x, y, w, h }, 1, true, "DBM")
						edit:Color(255, 255, 255)
					else
						HideTip()
						edit:Color(255, 0, 0)
					end
					if this:GetW() < 200 then
						local x, y = edit:Pos()
						edit:Pos(x - 300, y):Size(400, 25)
						ui:Fetch("CountdownName" .. k):Toggle(false)
					end
				end
			end
		end):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 5, y = nY, w = 30, h = 25, txt = v.nRefresh }):Type(0):Change(function(szNum)
			v.nRefresh = UI_tonumber(szNum)
		end):Pos_()
		nX, nY = ui:Append("Image", { x = nX + 5, y = nY, w = 26, h = 26}):File(file, 86):Event(525311)
		:Hover(function() this:SetFrame(87) end, function() this:SetFrame(86) end):Click(function()
			if v.nClass ~= -1 then
				FireEvent("JH_ST_DEL", v.nClass, k .. "."  .. data.dwID .. "." .. (data.nLevel or 0), true) -- try kill
			end
			if #data.tCountdown == 1 then
				data.tCountdown = nil
			else
				table.remove(data.tCountdown, k)
			end
			DBMUI.OpenSettingPanel(data, szType)
		end):Pos_()
	end
	nX = ui:Append("WndButton2", { x = 30, y = nY + 10, txt = _L["Add Countdown"] }):Enable(not (data.tCountdown and #data.tCountdown > 10)):Click(function()
		data.tCountdown = data.tCountdown or {}
		table.insert(data.tCountdown, { nTime = _L["10,Countdown Name;25,Countdown Name"], nClass = -1, nIcon = nIcon ~= -1 and nIcon or 13 })
		DBMUI.OpenSettingPanel(data, szType)
	end):Pos_()
	ui:Append("WndButton2", { x = 335, y = nY + 10, txt = g_tStrings.STR_FRIEND_DEL, color = { 255, 0, 0 } }):Click(function()
		DBMUI.RemoveData(data.dwMapID, data.nIndex, szName or _L["This data"], true)
	end)
	nX, nY = ui:Append("WndButton2", { x = 640, y = nY + 10, txt = g_tStrings.HELP_PANEL }):Click(function()
		OpenInternetExplorer("https://github.com/Webster-jx3/JH/tree/master/DBM")
	end):Pos_()
	local w, h = wnd:Size()
	local a = DBMUI_PANEL_ANCHOR
	wnd:Size(w, nY + 25):Point(a.s, 0, 0, a.r, a.x, a.y)
end

function DBMUI.UpdateAnchor(frame)
	local a = DBMUI.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

function DBMUI.IsOpened()
	return Station.Lookup("Normal/DBM_UI")
end

function DBMUI.TogglePanel()
	if DBMUI.IsOpened() then
		DBMUI.ClosePanel()
	else
		DBMUI.OpenPanel()
	end
end
function DBMUI.OpenPanel()
	if not DBMUI.IsOpened() then
		local wnd = Wnd.OpenWindow(DBMUI_INIFILE, "DBM_UI")
		PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
		Station.SetActiveFrame(wnd)
	end
end

function DBMUI.ClosePanel()
	if DBMUI.IsOpened() then
		Wnd.CloseWindow(DBMUI.frame)
		PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
		DBMUI.frame = nil
	end
end

JH.PlayerAddonMenu({ szOption = _L["Open DBM Panel"], fnAction = DBMUI.TogglePanel })
JH.AddHotKey("JH_DBMUI", _L["Open DBM Panel"], DBMUI.TogglePanel)
local ui = {
	TogglePanel     = DBMUI.TogglePanel,
	OpenImportPanel = DBMUI.OpenImportPanel
}
setmetatable(DBM_UI, { __index = ui, __newindex = function() end, __metatable = true })

-- JH.RegisterEvent("LOADING_END", DBMUI.OpenPanel)
