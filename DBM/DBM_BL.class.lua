-- @Author: Webster
-- @Date:   2015-05-24 08:26:53
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-06-22 13:07:47

local _L = JH.LoadLangPack
local BL_INIFILE = JH.GetAddonInfo().szRootPath .. "DBM/ui/BL_UI.ini"
local GetBuff = JH.GetBuff
local BL = {}
BL_UI = {
	tAnchor = {},
	nCount = 8,
	fScale = 1,
}
JH.RegisterCustomData("BL_UI")

-- FireUIEvent("JH_BL_CREATE", 103, 1, { 255, 0, 0 })
local function CreateBuffList(dwID, nLevel, col, tArgs)
	local key = tostring(dwID) -- .. "." .. nLevel
	col = col or { 255, 255, 0 }
	tArgs = tArgs or {}
	local KBuff = GetBuff(dwID, tArgs.bCheckLevel and nLevel or nil)
	if KBuff then
		local ui = BL.handle:Lookup(key) or BL.handle:AppendItemFromData(BL.hItem, key)
		local szName, nIcon = JH.GetBuffName(dwID, nLevel)
		ui.dwID = dwID
		ui.nLevel = tArgs.bCheckLevel and nLevel or nil
		ui:Lookup("Text_Name"):SetText(tArgs.szName or szName)
		ui:Lookup("Text_Name"):SetFontColor(unpack(col))
		local box = ui:Lookup("Box")
		box:SetObjectIcon(tArgs.nIcon or nIcon)
		box:SetObjectSparking(true)
		box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
		box:SetOverTextFontScheme(0, 15)
		if KBuff.nStackNum > 1 then
			box:SetOverText(0, KBuff.nStackNum)
		end
		box:SetObject(UI_OBJECT_NOT_NEED_KNOWN, dwID, nLevel)
		ui:Lookup("Text_Time"):SetFontColor(unpack(col))
		ui:Scale(BL_UI.fScale, BL_UI.fScale)
		BL.handle:FormatAllItemPos()
	end
end

function BL_UI.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("JH_BL_CREATE")
	this:RegisterEvent("JH_BL_RESIZE")
	BL.hItem = this:CreateItemData(BL_INIFILE, "Handle_Item")
	BL.handle = this:Lookup("", "")
	BL.handle:Clear()
	BL.ReSize(BL_UI.fScale, BL_UI.nCount)
	BL.UpdateAnchor(this)
end

function BL_UI.OnEvent(szEvent)
	if szEvent == "JH_BL_CREATE" then
		CreateBuffList(arg0, arg1, arg2, arg3)
	elseif szEvent == "JH_BL_RESIZE" then
		BL.ReSize(arg0, arg1)
	elseif szEvent == "UI_SCALED" then
		BL.UpdateAnchor(this)
	elseif szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, _L["Buff List"])
	end
end
function BL_UI.OnItemMouseEnter()
	local h = this:GetParent()
	local KBuff = GetBuff(h.dwID, h.nLevel)
	if KBuff then
		this:SetObjectMouseOver(true)
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		OutputBuffTipA(KBuff.dwID, KBuff.nLevel, { x, y, w, h }, JH.GetEndTime(KBuff.GetEndTime()))
	end
end

function BL_UI.OnItemRButtonClick()
	local h = this:GetParent()
	local KBuff = GetBuff(h.dwID, h.nLevel)
	if KBuff then
		GetClientPlayer().CancelBuff(KBuff.nIndex)
	end
end

function BL_UI.OnItemMouseLeave()
	if this:IsValid() then
		this:SetObjectMouseOver(false)
		HideTip()
	end
end

function BL_UI.OnFrameBreathe()
	local me = GetClientPlayer()
	if not me then return end
	for i = BL.handle:GetItemCount() -1, 0, -1 do
		local h = BL.handle:Lookup(i)
		if h and h:IsValid() then
			if h.bDelete then
				local nAlpha = h:GetAlpha()
				if nAlpha == 0 then
					BL.handle:RemoveItem(h)
					BL.handle:FormatAllItemPos()
				else
					h:SetAlpha(math.max(0, nAlpha - 30))
					h:Lookup("Animate_Update"):SetAlpha(0)
				end
			else
				local KBuff = GetBuff(h.dwID, h.nLevel)
				if KBuff then
					local nSec = JH.GetEndTime(KBuff.GetEndTime())
					if nSec < 0 then nSec = 0 end
					local szTime
					if nSec > 24 * 60 * 60 then
						szTime = ""
					else
						szTime = JH.FormatTimeString(nSec, 1)
					end
					h:Lookup("Text_Time"):SetText(szTime)
					local nAlpha = h:Lookup("Animate_Update"):GetAlpha()
					if nAlpha > 0 then
						h:Lookup("Animate_Update"):SetAlpha(math.max(0, nAlpha - 8))
					end
					if KBuff.nStackNum > 1 then
						h:Lookup("Box"):SetOverText(0, KBuff.nStackNum)
					else
						h:Lookup("Box"):SetOverText(0, "")
					end
				else
					h.bDelete = true
				end
			end
		end
	end
	if not IsInUICustomMode() then
		this:SetMousePenetrable(not IsCtrlKeyDown())
	else
		this:SetMousePenetrable(false)
	end
end

function BL_UI.OnFrameDragEnd()
	this:CorrectPos()
	BL_UI.tAnchor = GetFrameAnchor(this, "TOPLEFT")
end

function BL.ReSize(fScale, nCount)
	if fScale then
		local fNewScale = fScale / BL_UI.fScale
		this:Scale(fNewScale, fNewScale)
		BL_UI.fScale = fScale
	end
	nCount = nCount or BL_UI.nCount
	this:SetSize(nCount * 55 * BL_UI.fScale, 90 * BL_UI.fScale)
	BL.handle:SetSize(nCount * 55 * BL_UI.fScale, 90 * BL_UI.fScale)
	BL_UI.nCount = nCount
	BL.handle:FormatAllItemPos()
end

function BL.UpdateAnchor(frame)
	local a = BL_UI.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, -350)
	end
end

function BL.Init()
	local frame =  Wnd.OpenWindow(BL_INIFILE, "BL_UI")
end

JH.RegisterEvent("LOGIN_GAME", BL.Init)
