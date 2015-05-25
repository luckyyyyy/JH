-- @Author: Webster
-- @Date:   2015-05-24 08:26:53
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-25 13:19:25

local _L = JH.LoadLangPack
local BL_INIFILE = JH.GetAddonInfo().szRootPath .. "DBM/ui/BL_UI.ini"
local BL_CACHE = setmetatable({}, { __mode = "V" })
local BL = {}
BL_UI = {
	tAnchor = {},
	nCount = 8,
	fScale = 1,
}
JH.RegisterCustomData("BL_UI")
-- FireEvent("JH_BL_CREATE", 103, 1, { 255, 0, 0 })
local function CreateBuffList(dwID, nLevel, col, tArgs)
	local key = dwID .. "." .. nLevel
	local ui = BL_CACHE[key]
	col = col or { 255, 255, 0 }
	if ui and ui:IsValid() then
		ui:SetAlpha(255)
		ui:Lookup("Box"):SetObjectSparking(true)
		ui:Lookup("Animate_Update"):SetAlpha(255)
		ui.bDelete = nil
	else
		if BL.handle:GetItemCount() < BL_UI.nCount then
			local bExist, tBuff = JH.HasBuff(dwID)
			if bExist then
				tArgs = tArgs or {}
				local nSec = JH.GetEndTime(tBuff.nEndFrame)
				if nSec < 0 then nSec = 0 end
				local szTime = JH.GetBuffTimeString(nSec, 5999)
				local h = BL.handle:AppendItemFromIni(BL_INIFILE, "Handle_Item")
				local szName, nIcon = JH.GetBuffName(dwID, nLevel)
				h.dwID = dwID
				h:Lookup("Text_Name"):SetText(tArgs.szName or szName)
				h:Lookup("Text_Name"):SetFontColor(unpack(col))
				local box = h:Lookup("Box")
				box:SetObjectIcon(tArgs.nIcon or nIcon)
				box:SetObjectSparking(true)
				box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
				box:SetOverTextFontScheme(0, 15)
				if tBuff.nStackNum > 1 then
					box:SetOverText(0, tBuff.nStackNum)
				end
				h:Lookup("Text_Time"):SetText(szTime)
				h:Lookup("Text_Time"):SetFontColor(unpack(col))
				BL.handle:FormatAllItemPos()
				BL_CACHE[key] = h
				h:Scale(BL_UI.fScale, BL_UI.fScale)
			end
		end
	end
end

function BL_UI.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("JH_BL_CREATE")
	BL.handle = this:Lookup("", "")
	BL.handle:Clear()
	BL.handle:SetW(55 * BL_UI.nCount)
	this:SetW(55 * BL_UI.nCount)
	this:Scale(BL_UI.fScale, BL_UI.fScale)
	BL.UpdateAnchor(this)
end

function BL_UI.OnEvent(szEvent)
	if szEvent == "JH_BL_CREATE" then
		CreateBuffList(arg0, arg1, arg2, arg3)
	elseif szEvent == "UI_SCALED" then
		BL.UpdateAnchor(this)
	elseif szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, _L["Buff List"])
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
				local bExist, tBuff = JH.HasBuff(h.dwID)
				if bExist then
					local nSec = JH.GetEndTime(tBuff.nEndFrame)
					if nSec < 0 then nSec = 0 end
					local szTime = JH.GetBuffTimeString(nSec, 5999)
					h:Lookup("Text_Time"):SetText(szTime)
					local nAlpha = h:Lookup("Animate_Update"):GetAlpha()
					if nAlpha > 0 then
						h:Lookup("Animate_Update"):SetAlpha(math.max(0, nAlpha - 8))
					end
					if tBuff.nStackNum > 1 then
						h:Lookup("Box"):SetOverText(0, tBuff.nStackNum)
					else
						h:Lookup("Box"):SetOverText(0, "")
					end
				else
					h.bDelete = true
				end
			end
		end
	end
end

function BL_UI.OnFrameDragEnd()
	this:CorrectPos()
	BL_UI.tAnchor = GetFrameAnchor(this, "TOPLEFT")
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
