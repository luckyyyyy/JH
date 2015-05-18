-- @Author: Webster
-- @Date:   2015-05-14 13:59:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-18 22:09:10

local _L = JH.LoadLangPack
local DBMUI_INIFILE    = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_UI.ini"
local DBMUI_ITEM_L     = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_ITEM_L.ini"
local DBMUI_ITEM_R     = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_ITEM_R.ini"
local DBMUI_TYPE       = { "BUFF", "DEBUFF", "CASTING", "NPC", "CIRCLE", "TALK" }
local DBMUI_SELECT_MAP = -1
local DBMUI = {
	tAnchor = {}
}

DBM_UI = {}

function DBM_UI.OnFrameCreate()
	this:RegisterEvent("DBMUI_TEMP_UPDATE")
	this:RegisterEvent("DBMUI_DATA_UPDATE")
	this:RegisterEvent("DBMUI_TEMP_RELOAD")
	this:RegisterEvent("DBMUI_DATA_RELOAD")
	this:RegisterEvent("UI_SCALED")
	DBMUI.frame = this
	DBMUI.pageset = this:Lookup("PageSet_Main")
	DBMUI.pageset.szType = DBMUI_TYPE[1]
	this:Lookup("Btn_Close").OnLButtonClick = DBMUI.ClosePanel
	DBMUI.UpdateAnchor(this)
	local ui = GUI(this)
	ui:Append("WndComboBox", "Select_Class", { x = 700, y = 52, txt = g_tStrings.CHANNEL_COMMON }):Menu(DBMUI.GetClassMenu)
	-- 首次加载
	local nPage = DBMUI.pageset:GetActivePageIndex()
	FireEvent("DBMUI_TEMP_RELOAD")
	FireEvent("DBMUI_DATA_RELOAD")
end

function DBM_UI.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		DBMUI.UpdateAnchor(this)
	elseif szEvent == "DBMUI_TEMP_UPDATE" then
		DBMUI.UpdateRList(szEvent, arg0, arg1, arg2)
	elseif szEvent == "DBMUI_DATA_UPDATE" then
	elseif szEvent == "DBMUI_TEMP_RELOAD" then
		DBMUI.UpdateRList(szEvent, arg0, arg1, arg2)
	elseif szEvent == "DBMUI_DATA_RELOAD" then
		DBMUI.UpdateLList(szEvent, arg0, arg1, arg2)
	end
end

function DBM_UI.OnFrameDragEnd()
	this:CorrectPos()
	DBMUI.tAnchor = GetFrameAnchor(this)
end

function DBM_UI.OnActivePage()
	local nPage = this:GetActivePageIndex()
	this.szType = DBMUI_TYPE[nPage + 1]
	FireEvent("DBMUI_TEMP_RELOAD", DBMUI_TYPE[nPage + 1])
	FireEvent("DBMUI_DATA_RELOAD", DBMUI_TYPE[nPage + 1])
end

function DBMUI.GetClassMenu()
	local txt = this:GetParent():Lookup("", "Text_Default")
	local menu, tClass, tDungeon = {}, {}, DBM_API.GetDungeon()
	table.insert(menu, { szOption = g_tStrings.CHANNEL_COMMON, fnAction = function( ... )
		txt:SetText(g_tStrings.CHANNEL_COMMON)
		DBMUI_SELECT_MAP = -1
		FireEvent("DBMUI_DATA_RELOAD")
	end })
	table.insert(menu, { bDevide = true })
	for k, v in ipairs(tDungeon) do
		if not tClass[v.szLayer3Name] then
			tClass[v.szLayer3Name] = { szOption = v.szLayer3Name }
			table.insert(menu, tClass[v.szLayer3Name])
		end
		table.insert(tClass[v.szLayer3Name], { szOption = Table_GetMapName(v.dwMapID), fnAction = function()
			txt:SetText(Table_GetMapName(v.dwMapID))
			DBMUI_SELECT_MAP = v.dwMapID
			FireEvent("DBMUI_DATA_RELOAD")
		end })
	end
	-- TODO： 元表，并且要根据分类来获取菜单
	return menu
end

function DBM.GetBoxInfo(data, szType)
	local fnAction = JH.GetBuffName
	if szType == "CASTING" then
		fnAction = JH.GetSkillName
	end
	local szName, nIcon = fnAction(data.dwID, data.nLevel)
	nIcon = data.nIcon or nIcon
	szName = data.szName or szName
	return szName, nIcon
end

function DBMUI.SetBuffItemAction(h, dat)
	local szName, nIcon = DBM.GetBoxInfo(dat)
	h:Lookup("Text"):SetText(szName)
	local box = h:Lookup("Box")
	box:SetObjectIcon(nIcon)
	h.OnItemMouseEnter = function()
		box:SetObjectMouseOver(true)
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		OutputBuffTip(0, dat.dwID, dat.nLevel, nil, nil, nil, { x, y, w, h })
	end
	h.OnItemMouseLeave = function()
		box:SetObjectMouseOver(false)
		HideTip()
	end
end

function DBMUI.SetCastingItemAction(h, dat)
	local szName, nIcon = DBM.GetBoxInfo(dat.dwID, dat.nLevel)
	h:Lookup("Text"):SetText(szName)
	local box = h:Lookup("Box")
	box:SetObjectIcon(nIcon)
	h.OnItemMouseEnter = function()
		box:SetObjectMouseOver(true)
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		OutputSkillTip(dat.dwID, dat.nLevel, { x, y, w, h })
	end
	h.OnItemMouseLeave = function()
		box:SetObjectMouseOver(false)
		HideTip()
	end
end

function DBMUI.SetNpcItemAction(h, dat)
	local KTemplate = GetNpcTemplate(dat.dwID)
	local szName = KTemplate.szName
	if szName == "" then
		szName = Table_GetNpcTemplateName(dwID)
	end
	if JH.Trim(szName) == "" then
		szName = tostring(dwID)
	end
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
			OutputNpcTip2(dat.dwID, { x, y, w, h })
		end
	end
	h.OnItemMouseLeave = function()
		if this:IsValid() then
			box:SetObjectMouseOver(false)
			HideTip()
		end
	end
end
-- 更新监控数据
function DBMUI.UpdateLList(szEvent, szType, data)
	szType = szType or DBMUI.pageset.szType
	if szType ~= DBMUI.pageset.szType then
		return
	end
	if szEvent == "DBMUI_DATA_UPDATE" then
		DBMUI.DrawTableL(szType, data, true)
	elseif szEvent == "DBMUI_DATA_RELOAD" then
		local tab = DBM_API.GetTable(szType)
		if tab then
			DBMUI.DrawTableL(szType, tab[DBMUI_SELECT_MAP] or {})
		end
	end
end

function DBMUI.SetLBuffItemAction(h, t)
	h.OnItemLButtonClick = function()
		DBMUI.OpenSettingPanel(t, "BUFF")
	end
end

function DBMUI.DrawTableL(szType, data, bInsert)
	local page = DBMUI.pageset:GetActivePage()
	local handle = page:Lookup("WndScroll_" .. szType .. "_L", "Handle_" .. szType .. "_List_L")
	local function SetDataAction(h, t)
		if szType == "BUFF" or szType == "DEBUFF" then
			DBMUI.SetBuffItemAction(h, t)
			DBMUI.SetLBuffItemAction(h, t)
		elseif szType == "CASTING" then
			DBMUI.SetCastingItemAction(h, t)
		elseif szType == "NPC" or szType == "CIRCLE" then
			DBMUI.SetNpcItemAction(h, t)
		end
	end
	if not bInsert then
		handle:Clear()
		if #data > 0 then
			for i = #data, 1, -1 do
				local dat = data[i]
				local h = handle:AppendItemFromIni(DBMUI_ITEM_L, "Handle_L")
				SetDataAction(h, dat)
			end
		end
	else
		handle:InsertItemFromIni(0, false, DBMUI_ITEM_R, "Handle_R")
		SetDataAction(handle:Lookup(0), data)
	end
	handle:FormatAllItemPos()
end

-- 更新临时数据
function DBMUI.UpdateRList(szEvent, szType, data)
	szType = szType or DBMUI.pageset.szType
	if szType ~= DBMUI.pageset.szType then
		return
	end
	if szEvent == "DBMUI_TEMP_UPDATE" then
		DBMUI.DrawTableR(szType, data, true)
	elseif szEvent == "DBMUI_TEMP_RELOAD" then
		local tab = DBM_API.GetTable(szType, true)
		if tab then
			DBMUI.DrawTableR(szType, tab)
		end
	end
end

function DBMUI.DrawTableR(szType, data, bInsert)
	local page = DBMUI.pageset:GetActivePage()
	local handle = page:Lookup("WndScroll_" .. szType .. "_R", "Handle_" .. szType .. "_List_R")
	local function SetDataAction(h, t)
		if szType == "BUFF" or szType == "DEBUFF" then
			DBMUI.SetBuffItemAction(h, t)
		elseif szType == "CASTING" then
			DBMUI.SetCastingItemAction(h, t)
		elseif szType == "NPC" or szType == "CIRCLE" then
			DBMUI.SetNpcItemAction(h, t)
		end
	end
	if not bInsert then
		handle:Clear()
		if #data > 0 then
			for i = #data, 1, -1 do
				local dat = data[i]
				local h = handle:AppendItemFromIni(DBMUI_ITEM_R, "Handle_R")
				SetDataAction(h, dat)
			end
		end
	else
		handle:InsertItemFromIni(0, false, DBMUI_ITEM_R, "Handle_R")
		SetDataAction(handle:Lookup(0), data)
	end
	handle:FormatAllItemPos()
end

local function GetScrutinyTypeMenu(data)
	local menu = {
		{ szOption = g_tStrings.STR_GUILD_ALL, bMCheck = true, bChecked = type(data.nScrutinyType) == "nil", fnAction = function() data.nScrutinyType = nil end },
		{ bDevide = true },
		{ szOption = g_tStrings.MENTOR_SELF, bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.SELF, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.SELF end },
		{ szOption = _L["Team"], bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.TEAM, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.TEAM end },
		{ szOption = _L["Enemy"], bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.ENEMY, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.ENEMY end },
	}
	return menu
end

local function SetDataClass(data, nClass, key, value)
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
local function GetSettingPanelAnchor()
	local a = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
	local frame = Station.Lookup("Normal/DBM_SettingPanel")
	if frame then
		a = GetFrameAnchor(frame)
	end
	return a
end
-- 设置面板
function DBMUI.OpenSettingPanel(data, szType)
	local a = GetSettingPanelAnchor()
	local file = "ui/Image/UICommon/Feedanimials.uitex"
	local szNam, nIcon = DBM.GetBoxInfo(data, szType)
	local wnd = GUI.CreateFrame("DBM_SettingPanel", { w = 750, h = 450, title = szNam, close = true }):RegisterClose():Point(a.s, 0, 0, a.r, a.x, a.y)
	local ui = GUI(Station.Lookup("Normal/DBM_SettingPanel"))
	local nX, nY = 0, 0
	if szType == "BUFF" or szType == "DEBUFF" then
		nX, nY = ui:Append("Box", "Box_Icon", { w = 48, h = 48, x = 351, y = 40, icon = nIcon }):Pos_()
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = g_tStrings.CHANNEL_COMMON, font = 27 }):Pos_()
		nX = ui:Append("WndComboBox", { x = 30, y = nY + 12, txt = _L["Scrutiny Type"] }):Menu(function()
			return GetScrutinyTypeMenu(data)
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 5, y = nY + 10, txt = _L["Count Achieve"] }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 2, y = nY + 12, w = 30, h = 26, txt = data.nCount or 1 }):Type(0):Change(function(nNum)
			data.nCount = UI_tonumber(nNum)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bCheckLevel, txt = _L["Check Level"] }):Click(function(bCheck)
			data.bCheckLevel = bCheck and true or nil
		end):Pos_()
		nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Get Buff"], font = 27 }):Pos_()
		local cfg = data[DBM_TYPE.BUFF_GET] or {}
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bScreenHead, txt = _L["Screen Head Alert"] }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bScreenHead", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bFullScreen", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bPartyBuffList, txt = _L["Push Party Buff List"] }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bPartyBuffList", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBuffList, txt = _L["Push Buff List"] }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bBuffList", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bTeamPanel, txt = _L["Push Team Panel"] }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bTeamPanel", bCheck)
			ui:Fetch("bOnlySelfSrc"):Enable(bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", "bOnlySelfSrc", { x = nX + 5, y = nY, checked = cfg.bOnlySelfSrc, txt = _L["Only Source Self"] }):Enable(cfg.bTeamPane == true):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_GET, "bOnlySelfSrc", bCheck)
		end):Pos_()
		--TODO 标记
		nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Lose Buff"], font = 27 }):Pos_()
		local cfg = data[DBM_TYPE.BUFF_LOSE] or {}
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_LOSE, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_LOSE, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_LOSE, "bCenterAlarm", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(data, DBM_TYPE.BUFF_LOSE, "bBigFontAlarm", bCheck)
		end):Pos_()
	end
	-- 倒计时
	nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Countdown"], font = 27 }):Pos_()
	nY = nY + 10
	for k, v in ipairs(data.tCountdown or {}) do
		nX = ui:Append("WndComboBox", "Countdown" .. k, { x = 30, y = nY, txt = v.nClass == -1 and _L["Please Select Type"] or _L["Countdown TYPE " ..  v.nClass] }):Menu(function()
			local menu = {}
			if v.nClass == -1 then
				table.insert(menu, { szOption = _L["Please Select Type"], bMCheck = true, bChecked = v.nClass == -1, fnAction = function()
					v.nClass = -1
					ui:Fetch("Countdown" .. k):Text(_L["Please Select Type"])
				end })
			end
			if szType == "BUFF" or szType == "DEBUFF" then
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.BUFF_GET], bMCheck = true, bChecked = v.nClass == DBM_TYPE.BUFF_GET, fnAction = function()
					v.nClass = DBM_TYPE.BUFF_GET
					ui:Fetch("Countdown" .. k):Text(_L["Countdown TYPE " ..  v.nClass])
				end })
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.BUFF_LOSE], bMCheck = true, bChecked = v.nClass == DBM_TYPE.BUFF_LOSE, fnAction = function()
					v.nClass = DBM_TYPE.BUFF_LOSE
					ui:Fetch("Countdown" .. k):Text(_L["Countdown TYPE " ..  v.nClass])
				end })
			elseif szType == "CASTING" then
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.SKILL_END], bMCheck = true, bChecked = v.nClass == DBM_TYPE.SKILL_END, fnAction = function()
					v.nClass = DBM_TYPE.SKILL_END
					ui:Fetch("Countdown" .. k):Text(_L["Countdown TYPE " ..  v.nClass])
				end })
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.SKILL_BEGIN], bMCheck = true, bChecked = v.nClass == DBM_TYPE.SKILL_BEGIN, fnAction = function()
					v.nClass = DBM_TYPE.SKILL_BEGIN
					ui:Fetch("Countdown" .. k):Text(_L["Countdown TYPE " ..  v.nClass])
				end })
			elseif szType == "NPC" then
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.NPC_ENTER], bMCheck = true, bChecked = v.nClass == DBM_TYPE.NPC_ENTER, fnAction = function()
					v.nClass = DBM_TYPE.NPC_ENTER
					ui:Fetch("Countdown" .. k):Text(_L["Countdown TYPE " ..  v.nClass])
				end })
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.NPC_LEAVE], bMCheck = true, bChecked = v.nClass == DBM_TYPE.NPC_LEAVE, fnAction = function()
					v.nClass = DBM_TYPE.NPC_LEAVE
					ui:Fetch("Countdown" .. k):Text(_L["Countdown TYPE " ..  v.nClass])
				end })
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.NPC_ALLLEAVE], bMCheck = true, bChecked = v.nClass == DBM_TYPE.NPC_ALLLEAVE, fnAction = function()
					v.nClass = DBM_TYPE.NPC_ALLLEAVE
					ui:Fetch("Countdown" .. k):Text(_L["Countdown TYPE " ..  v.nClass])
				end })
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.NPC_FIGHT], bMCheck = true, bChecked = v.nClass == DBM_TYPE.NPC_FIGHT, fnAction = function()
					v.nClass = DBM_TYPE.NPC_FIGHT
					ui:Fetch("Countdown" .. k):Text(_L["Countdown TYPE " ..  v.nClass])
				end })
				table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.NPC_DEATH], bMCheck = true, bChecked = v.nClass == DBM_TYPE.NPC_DEATH, fnAction = function()
					v.nClass = DBM_TYPE.NPC_DEATH
					ui:Fetch("Countdown" .. k):Text(_L["Countdown TYPE " ..  v.nClass])
				end })
			end
			-- TODO 其他类型
			return menu
		end):Pos_()
		nX = ui:Append("Box", { x = nX + 5, y = nY, w = 24, h = 24, icon = v.nIcon or nIcon }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 5, y = nY, w = 400, h = 25, txt = v.nTime }):Change(function(szNum)
			v.nTime = UI_tonumber(szNum, szNum)
		end):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 5, y = nY, w = 30, h = 25, txt = v.nRefresh }):Type(0):Change(function(szNum)
			v.nRefresh = UI_tonumber(szNum)
		end):Pos_()
		nX, nY = ui:Append("Image", { x = nX + 5, y = nY, w = 26, h = 26}):File(file, 86):Event(525311)
		:Hover(function() this:SetFrame(87) end, function() this:SetFrame(86) end):Click(function()
			FireEvent("JH_ST_DEL", v.nClass, k .. "."  .. data.dwID .. "." .. (data.nLevel or 0), true) -- 拟定删除一次
			if #data.tCountdown == 1 then
				data.tCountdown = nil
			else
				table.remove(data.tCountdown, k)
			end
			DBMUI.OpenSettingPanel(data, szType)
		end):Pos_()
	end
	if data.tCountdown and  #data.tCountdown > 0 then
		local w, h = wnd:Size()
		local a = GetSettingPanelAnchor()
		wnd:Size(w, h + #data.tCountdown * 25):Point(a.s, 0, 0, a.r, a.x, a.y)
	end
	ui:Append("WndButton2", { x = 30, y = nY + 5, txt = _L["Add Countdown"] }):Enable(not (data.tCountdown and #data.tCountdown > 10)):Click(function()
		if szType == "BUFF" or szType == "DEBUFF" then
			data.tCountdown = data.tCountdown or {}
			table.insert(data.tCountdown, { nTime = "10,Countdown Name;", nClass = -1 })
			DBMUI.OpenSettingPanel(data, szType)
		end
	end)
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
	Wnd.OpenWindow(DBMUI_INIFILE, "DBM_UI")
	PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
end

function DBMUI.ClosePanel()
	Wnd.CloseWindow(DBMUI.frame)
	PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
end
DBM_UI.TogglePanel = DBMUI.TogglePanel
JH.RegisterEvent("LOGIN_GAME", DBMUI.OpenPanel)
