-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-10 12:45:11
local _L = JH.LoadLangPack
PartyBuffList = {
	bEnable = true,
	bEnableRGES = true,
	bHoverSelect = false,
	tList = {},
	tAnchor = {},
}
JH.RegisterCustomData("PartyBuffList")

local PartyBuffList = PartyBuffList
local ipairs, pairs = ipairs, pairs
local GetPlayer = GetPlayer
local GetClientPlayer, GetClientTeam, UI_GetPlayerMountKungfuID = GetClientPlayer, GetClientTeam, UI_GetPlayerMountKungfuID
local CACHE_LIST = setmetatable({}, { __mode = "v" })
local PBL_INI_FILE = JH.GetAddonInfo().szRootPath ..  "RPartyBuffList/ui/PartyBuffList.ini"
local PBL = {}

function PartyBuffList.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("BUFF_UPDATE")
	this:RegisterEvent("TARGET_CHANGE")
	this:RegisterEvent("JH_PARTYBUFFLIST")
	PBL.UpdateAnchor(this)
	PBL.frame = this
	PBL.handle = this:Lookup("", "Handle_List")
	PBL.bg = this:Lookup("", "Image_Bg")
	PBL.handle:Clear()
	local ui = GUI(this)
	ui:Title(_L["PartyBuffList"])
	ui:Fetch("Btn_Close"):Click(function()
		PBL.handle:Clear()
		PBL.SwitchPanel(0)
	end)
	ui:Fetch("Btn_Style"):Click(function()
		JH.OpenPanel(_L["PartyBuffList"])
	end)
end

function PartyBuffList.OnEvent(event)
	if event == "UI_SCALED" then
		PBL.UpdateAnchor(this)
	elseif event == "BUFF_UPDATE" then
		if arg1 then return end
		local szName = JH.GetBuffName(arg4, arg8)
		if PartyBuffList.tList[szName] and Table_BuffIsVisible(arg4, arg8) then
			PBL.OnTableInsert(arg0, arg4, arg8)
		end
	elseif event == "TARGET_CHANGE" then
		PBL.SwitchSelect()
	elseif event == "JH_PARTYBUFFLIST" then
		if not PartyBuffList.bEnableRGES then return end
		PBL.OnTableInsert(arg0, arg1, arg2)
	elseif event == "ON_ENTER_CUSTOM_UI_MODE" or event == "ON_LEAVE_CUSTOM_UI_MODE" then
		if event == "ON_ENTER_CUSTOM_UI_MODE" then
			PBL.frame:Show()
		else
			PBL.SwitchPanel(PBL.handle:GetItemCount())
		end
		UpdateCustomModeWindow(this, _L["PartyBuffList"])
	end
end

function PartyBuffList.OnFrameBreathe()
	local me = GetClientPlayer()
	if not me then return end
	local dwKungfuID = UI_GetPlayerMountKungfuID()
	local DISTANCE = 20
	if dwKungfuID == 10080 then -- 奶秀修正
		DISTANCE = 22
	elseif dwKungfuID == 10028 then -- 奶花修正
		DISTANCE = 24
	end
	for i = PBL.handle:GetItemCount() -1, 0, -1 do
		local h = PBL.handle:Lookup(i)
		if h and h:IsValid() then
			local data = h.data
			local p, info = PBL.GetPlayer(data.dwID)
			local bExist, tBuff
			if p then
				bExist, tBuff = JH.HasBuff(data.dwBuffID, p)
			end
			if p and info and bExist then
				local nDistance = JH.GetDistance(p)
				h:Lookup("Image_life"):SetPercentage(info.nCurrentLife / math.max(info.nMaxLife, 1))
				h:Lookup("Text_Name"):SetText(i + 1 .. " " .. info.szName)
				if nDistance > DISTANCE then
					h:Lookup("Image_life"):SetAlpha(150)
				else
					h:Lookup("Image_life"):SetAlpha(255)
				end
				local box = h:Lookup("Box_Icon")
				local nSec = JH.GetEndTime(tBuff.nEndFrame)
				if nSec < 60 then
					box:SetOverText(1, 1 .. "\"")
				end
				if tBuff.nStackNum > 1 then
					box:SetOverText(0, tBuff.nStackNum)
				end
			else
				PBL.handle:RemoveItem(h)
				PBL.handle:FormatAllItemPos()
				PBL.SwitchPanel(PBL.handle:GetItemCount())
			end
		end
	end
end

function PartyBuffList.OnFrameDragEnd()
	this:CorrectPos()
	PartyBuffList.tAnchor = GetFrameAnchor(this, "TOPCENTER")
end

function PBL.OpenPanel()
	local frame = PBL.frame or Wnd.OpenWindow(PBL_INI_FILE, "PartyBuffList")
	PBL.SwitchPanel(0)
end

function PBL.UpdateAnchor(frame)
	local a = PartyBuffList.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 400, 0)
	end
end

function PBL.SwitchSelect()
	local dwID, dwType = Target_GetTargetData()
	for i = PBL.handle:GetItemCount() -1, 0, -1 do
		local h = PBL.handle:Lookup(i)
		if h and h:IsValid() then
			if dwID == h.data.dwID then
				h:Lookup("Image_Select"):Show()
			else
				h:Lookup("Image_Select"):Hide()
			end
		end
	end
end

function PBL.SwitchPanel(nCount)
	local h = 40
	PBL.frame:SetH(h * nCount + 30)
	PBL.bg:SetH(h * nCount + 30)
	PBL.handle:SetH(h * nCount)
	if nCount == 0 then
		PBL.frame:Hide()
	else
		PBL.frame:Show()
	end
end

function PBL.ClosePanel()
	Wnd.CloseWindow(PBL.frame)
	PBL.frame = nil
end

function PBL.GetListText()
	local tName = {}
	for k, _ in pairs(PartyBuffList.tList) do
		if type(k) == "string" then
			table.insert(tName, k)
		end
	end
	return table.concat(tName, "\n")
end

function PBL.GetPlayer(dwID)
	local me = GetClientPlayer()
	local team = GetClientTeam()
	local p, info
	if dwID == UI_GetClientPlayerID() then
		p = me
		info = {
			dwMountKungfuID = UI_GetPlayerMountKungfuID(),
			szName = me.szName,
			nMaxLife = me.nMaxLife,
			nCurrentLife = me.nCurrentLife,
			dwForce = me.dwForce,
		}
	else
		p = GetPlayer(dwID)
		info = team.GetMemberInfo(dwID)
	end
	return p, info
end

function PBL.OnTableInsert(dwID, dwBuffID, nLevel)
	local team = GetClientTeam()
	local p, info = PBL.GetPlayer(dwID)
	if not p or not info then
		return
	end
	local key = dwID .. "_" .. dwBuffID .. "_" .. nLevel -- 主要担心窗口名称太长
	if CACHE_LIST[key] and CACHE_LIST[key]:IsValid() then
		return
	end
	local bExist, tBuff = JH.HasBuff(dwBuffID, p)
	if not bExist then
		return
	end
	local data = { dwID = dwID, dwBuffID = dwBuffID, nLevel = nLevel }
	local h = PBL.handle:AppendItemFromIni(PBL_INI_FILE, "Handle_Item")
	local nCount = PBL.handle:GetItemCount()
	h:Lookup("Image_KungFu"):FromIconID(Table_GetSkillIconID(info.dwMountKungfuID) or 1435)
	h:Lookup("Text_Name"):SetText(nCount .. " " .. info.szName)
	h:Lookup("Image_life"):SetPercentage(info.nCurrentLife / math.max(info.nMaxLife, 1))
	local box = h:Lookup("Box_Icon")
	box:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
	box:SetObjectIcon(Table_GetBuffIconID(dwBuffID, nLevel))
	box:SetObjectStaring(true)
	box:SetOverTextPosition(1, ITEM_POSITION.LEFT_TOP)
	box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
	box:SetOverTextFontScheme(1, 8)
	box:SetOverTextFontScheme(0, 7)
	local nSec = JH.GetEndTime(tBuff.nEndFrame)
	if nSec < 60 then
		box:SetOverText(1, 1 .. "\"")
	end
	if tBuff.nStackNum > 1 then
		box:SetOverText(0, tBuff.nStackNum)
	end
	h.OnItemLButtonDown = function()
		SetTarget(TARGET.PLAYER, dwID)
		FireEvent("JH_TAR_TEMP_UPDATE", dwID)
	end
	h.OnItemMouseLeave = function()
		if PartyBuffList.bHoverSelect then
			JH.SetTempTarget(dwID, false)
		end
	end
	h.OnItemMouseEnter = function()
		if PartyBuffList.bHoverSelect then
			JH.SetTempTarget(dwID, true)
		end
	end
	h.data = data
	h:Show()
	PBL.handle:FormatAllItemPos()
	PBL.SwitchPanel(nCount)
	CACHE_LIST[key] = h
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	ui:Append("Text", { x = 0, y = 0, txt = _L["PartyBuffList"], font = 27 })
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = 28, checked = PartyBuffList.bEnable })
	:Text(_L["Enable PartyBuffList"]):Click(function(bChecked)
		PartyBuffList.bEnable = bChecked
		if bChecked then
			PBL.OpenPanel()
		else
			PBL.ClosePanel()
		end
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = PartyBuffList.bEnableRGES })
	:Text(_L["Bind RGES"]):Click(function(bChecked)
		PartyBuffList.bEnableRGES = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = PartyBuffList.bHoverSelect })
	:Text(_L["Mouse Enter select"]):Click(function(bChecked)
		PartyBuffList.bHoverSelect = bChecked
	end):Pos_()

	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Manually add (One per line)"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndEdit",{ x = 10, y = nY + 10, w = 450, h = 100, limit = 4096,multi = true})
	:Text(PBL.GetListText()):Change(function(szText)
		local t = {}
		for _, v in ipairs(JH.Split(szText, "\n")) do
			v = JH.Trim(v)
			if v ~= "" then
				t[v] = true
			end
		end
		PartyBuffList.tList = t
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Tips"], font = 27 }):Pos_()
	nX,nY = ui:Append("Text", { x = 10, y = nY + 10, w = 500 , h = 40, multi = true, txt = _L["PartyBuffList_TIPS"] }):Pos_()
end

GUI.RegisterPanel(_L["PartyBuffList"], 1453, _L["RGES"], PS)
JH.RegisterEvent("LOGIN_GAME", PBL.OpenPanel)
JH.AddonMenu(function()
	return {
		szOption = _L["PartyBuffList"], bCheck = true, bChecked = PartyBuffList.bEnable, fnAction = function()
			if not PartyBuffList.bEnable then
				PartyBuffList.bEnable = true
				PBL.OpenPanel()
			else
				PartyBuffList.bEnable = false
				PBL.ClosePanel()
			end
		end
	}
end)
