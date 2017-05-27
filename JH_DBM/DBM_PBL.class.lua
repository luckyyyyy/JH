-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2017-05-27 16:58:02

-- 这个需要重写 构思已有 就是没时间。。
local _L = JH.LoadLangPack
PartyBuffList = {
	bHoverSelect = false,
	tAnchor = {},
}
JH.RegisterCustomData("PartyBuffList")

local PartyBuffList = PartyBuffList
local ipairs, pairs = ipairs, pairs
local GetPlayer = GetPlayer
local GetBuff = JH.GetBuff
local GetClientPlayer, GetClientTeam, UI_GetPlayerMountKungfuID = GetClientPlayer, GetClientTeam, UI_GetPlayerMountKungfuID
local CACHE_LIST = setmetatable({}, { __mode = "v" })
local PBL_INI_FILE = JH.GetAddonInfo().szRootPath ..  "JH_DBM/ui/DBM_PBL.ini"
local PBL = {}

function PartyBuffList.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("TARGET_CHANGE")
	this:RegisterEvent("JH_PARTYBUFFLIST")
	PBL.hItem = this:CreateItemData(PBL_INI_FILE, "Handle_Item")
	PBL.frame = this
	PBL.handle = this:Lookup("", "Handle_List")
	PBL.bg = this:Lookup("", "Image_Bg")
	PBL.handle:Clear()
	this:Lookup("", "Text_Title"):SetText(_L["PartyBuffList"])
	PBL.UpdateAnchor(this)
end

function PartyBuffList.OnEvent(event)
	if event == "UI_SCALED" then
		PBL.UpdateAnchor(this)
	elseif event == "TARGET_CHANGE" then
		PBL.SwitchSelect()
	elseif event == "JH_PARTYBUFFLIST" then
		PBL.OnTableInsert(arg0, arg1, arg2, arg3)
	elseif event == "ON_ENTER_CUSTOM_UI_MODE" or event == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, _L["PartyBuffList"])
		if event == "ON_ENTER_CUSTOM_UI_MODE" then
			PBL.frame:Show()
		else
			PBL.SwitchPanel(PBL.handle:GetItemCount())
			PBL.frame:EnableDrag(true) -- 还是支持拖动的
			PBL.frame:SetDragArea(0, 0, 200, 30)
		end
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
			local KBuff
			if p then
				KBuff = GetBuff(data.dwBuffID, p)
			end
			if p and info and KBuff then
				local nDistance = JH.GetDistance(p)
				h:Lookup("Image_life"):SetPercentage(info.nCurrentLife / math.max(info.nMaxLife, 1))
				h:Lookup("Text_Name"):SetText(i + 1 .. " " .. info.szName)
				if nDistance > DISTANCE then
					h:Lookup("Image_life"):SetAlpha(150)
				else
					h:Lookup("Image_life"):SetAlpha(255)
				end
				local box = h:Lookup("Box_Icon")
				local nSec = JH.GetEndTime(KBuff.GetEndTime())
				if nSec < 60 then
					box:SetOverText(1, JH.FormatTimeString(nSec, 1, true))
				else
					box:SetOverText(1, "")
				end
				if KBuff.nStackNum > 1 then
					box:SetOverText(0, KBuff.nStackNum)
				end
			else
				PBL.handle:RemoveItem(h)
				PBL.handle:FormatAllItemPos()
				PBL.SwitchPanel(PBL.handle:GetItemCount())
			end
		end
	end
end

function PartyBuffList.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Style" then
		local menu = {
			{ szOption = _L["Mouse Enter select"], bCheck = true, bChecked = PartyBuffList.bHoverSelect, fnAction = function()
				PartyBuffList.bHoverSelect = not PartyBuffList.bHoverSelect
			end }
		}
		PopupMenu(menu)
	elseif szName == "Btn_Close" then
		PBL.handle:Clear()
		PBL.SwitchPanel(0)
	end
end

function PartyBuffList.OnItemLButtonDown()
	if this:GetName() == "Handle_Item" then
		SetTarget(TARGET.PLAYER, this.data.dwID)
		FireUIEvent("JH_TAR_TEMP_UPDATE", this.data.dwID)
	end
end

function PartyBuffList.OnItemMouseLeave()
	if this:GetName() == "Handle_Item" then
		if PartyBuffList.bHoverSelect then
			JH.SetTempTarget(this.data.dwID, false)
		end
	end
end

function PartyBuffList.OnItemMouseEnter()
	if this:GetName() == "Handle_Item" then
		if PartyBuffList.bHoverSelect then
			JH.SetTempTarget(this.data.dwID, true)
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
	local dwType, dwID = Target_GetTargetData()
	for i = PBL.handle:GetItemCount() -1, 0, -1 do
		local h = PBL.handle:Lookup(i)
		if h and h:IsValid() then
			local sel = h:Lookup("Image_Select")
			if sel and sel:IsValid() then
				if dwID == h.data.dwID then
					sel:Show()
				else
					sel:Hide()
				end
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
		}
	else
		p = GetPlayer(dwID)
		info = team.GetMemberInfo(dwID)
	end
	return p, info
end

function PBL.OnTableInsert(dwID, dwBuffID, nLevel, nIcon)
	if PBL.handle and PBL.handle:GetItemCount() > 7 then
		return
	end
	local team = GetClientTeam()
	local p, info = PBL.GetPlayer(dwID)
	if not p or not info then
		return
	end
	local key = dwID .. "_" .. dwBuffID .. "_" .. nLevel -- 主要担心窗口名称太长
	if CACHE_LIST[key] and CACHE_LIST[key]:IsValid() then
		return
	end
	local KBuff = GetBuff(dwBuffID, p)
	if not KBuff then
		return
	end
	local dwTargetType, dwTargetID = Target_GetTargetData()
	local data = { dwID = dwID, dwBuffID = dwBuffID, nLevel = nLevel }
	local h = PBL.handle:AppendItemFromData(PBL.hItem)
	local nCount = PBL.handle:GetItemCount()
	if dwTargetID == dwID then
		h:Lookup("Image_Select"):Show()
	end
	h:Lookup("Image_KungFu"):FromIconID(Table_GetSkillIconID(info.dwMountKungfuID) or 1435)
	h:Lookup("Text_Name"):SetText(nCount .. " " .. info.szName)
	h:Lookup("Image_life"):SetPercentage(info.nCurrentLife / math.max(info.nMaxLife, 1))
	local box = h:Lookup("Box_Icon")
	local _, icon = JH.GetBuffName(dwBuffID, nLevel)
	if nIcon then
		icon = nIcon
	end
	box:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
	box:SetObjectIcon(icon)
	box:SetObjectStaring(true)
	box:SetOverTextPosition(1, ITEM_POSITION.LEFT_TOP)
	box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
	box:SetOverTextFontScheme(1, 8)
	box:SetOverTextFontScheme(0, 7)
	local nSec = JH.GetEndTime(KBuff.GetEndTime())
	if nSec < 60 then
		box:SetOverText(1, math.floor(nSec) .. "\"")
	end
	if KBuff.nStackNum > 1 then
		box:SetOverText(0, KBuff.nStackNum)
	end
	h.data = data
	h:Show()
	PBL.handle:FormatAllItemPos()
	PBL.SwitchPanel(nCount)
	CACHE_LIST[key] = h
end

JH.RegisterEvent("LOGIN_GAME", PBL.OpenPanel)
