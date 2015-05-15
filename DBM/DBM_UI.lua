-- @Author: Webster
-- @Date:   2015-05-14 13:59:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-15 19:30:07

local _L = JH.LoadLangPack
local DBMUI_INIFILE = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_UI.ini"
local DBMUI_ITEM_L  = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_ITEM_L.ini"
local DBMUI_ITEM_R  = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM_ITEM_R.ini"
local DBMUI_TYPE = { "BUFF", "DEBUFF", "CASTING", "NPC", "CIRCLE", "TALK" }
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
	-- 首次加载
	local nPage = DBMUI.pageset:GetActivePageIndex()
	FireEvent("DBMUI_TEMP_RELOAD")
	FireEvent("DBMUI_DATA_RELOAD")
end

function DBM_UI.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		DBMUI.UpdateAnchor(this)
	elseif szEvent == "DBMUI_TEMP_UPDATE" then
		DBM.UpdateRList(szEvent, arg0, arg1, arg2, arg3)
	elseif szEvent == "DBMUI_DATA_UPDATE" then
	elseif szEvent == "DBMUI_TEMP_RELOAD" then
		DBM.UpdateRList(szEvent, arg0, arg1, arg2, arg3)
	elseif szEvent == "DBMUI_DATA_RELOAD" then
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

function DBM.UpdateRList(szEvent, szType, data, bDelete)
	szType = szType or DBMUI.pageset.szType
	if szType ~= DBMUI.pageset.szType then
		return
	end
	if szEvent == "DBMUI_TEMP_UPDATE" then
		DBM.DrawTableR(szType, data, true)
	elseif szEvent == "DBMUI_TEMP_RELOAD" then
		local tab = DBM_API.GetTable(szType, true)
		if tab then
			DBM.DrawTableR(szType, tab)
		end
	end
end

local function SetBuffItemAction(h, dat)
	local szName, nIcon = JH.GetBuffName(dat.dwID, dat.nLevel)
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

local function SetCastingItemAction(h, dat)
	local szName, nIcon = JH.GetSkillName(dat.dwID, dat.nLevel)
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

local function SetNpcItemAction(h, dat)
	local KTemplate = GetNpcTemplate(dat.dwID)
	local szName = JH.GetTemplateName(KTemplate)
	h:Lookup("Text"):SetText(szName)
	h:Lookup("Text"):SetFontColor(unpack(dat.col))
	local box = h:Lookup("Box")
	box:ClearObjectIcon()
	box:SetExtentImage("ui/Image/TargetPanel/Target.UITex", dat.nFrame)
	h.OnItemMouseEnter = function()
		box:SetObjectMouseOver(true)
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		OutputNpcTip2(dat.dwID, { x, y, w, h })
	end
	h.OnItemMouseLeave = function()
		box:SetObjectMouseOver(false)
		HideTip()
	end
end

function DBM.DrawTableR(szType, data, bInsert, bDelete)
	local page = DBMUI.pageset:GetActivePage()
	local handle = page:Lookup("WndScroll_" .. szType .. "_R", "Handle_" .. szType .. "_List_R")
	local function SetDataAction(h, t)
		if szType == "BUFF" or szType == "DEBUFF" then
			SetBuffItemAction(h, t)
		elseif szType == "CASTING" then
			SetCastingItemAction(h, t)
		elseif szType == "NPC" or szType == "CIRCLE" then
			SetNpcItemAction(h, t)
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
			handle:FormatAllItemPos()
		end
	else
		handle:InsertItemFromIni(0, false, DBMUI_ITEM_R, "Handle_R")
		SetDataAction(handle:Lookup(0), data)
		handle:FormatAllItemPos()
	end
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
