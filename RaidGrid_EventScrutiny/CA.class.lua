-- @Author: Webster
-- @Date:   2015-05-04 09:29:09
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-06 13:48:09

local _L = JH.LoadLangPack
local CA_INIFILE = JH.GetAddonInfo().szRootPath .. "RaidGrid_EventScrutiny/ui/CA_UI.ini"
local type, ipairs, pairs, assert, unpack = type, ipairs, pairs, assert, unpack
local min, max = math.min, math.max
local GetTime = GetTime
local CA = {}

CA_UI = {
	tAnchor = {}
}
JH.RegisterCustomData("CA_UI")
-- FireEvent("JH_CA_CREATE", "test", 3)
local function CreateCentralAlert(szMsg, nTime, bXml)
	nTime = nTime or 3
	CA.nTime = nTime
	local msg = CA.msg
	msg:Clear()
	if not bXml then
		msg:SetHandleStyle(0)
		msg:SetRelPos(0, -4)
		CA.handle:FormatAllItemPos()
		local txt = msg:AppendItemFromIni(CA_INIFILE, "Text_Message")
		txt:SetText(szMsg)
		msg:FormatAllItemPos()
	else
		msg:SetHandleStyle(3)
		msg:AppendItemFromString(szMsg)
		msg:FormatAllItemPos()
		local w, h = msg:GetAllItemSize()
		msg:SetRelPos((480 - w) / 2, (45 - h) / 2)
		CA.handle:FormatAllItemPos()
	end
	msg.nTime = nTime
	msg.nCreate = GetTime()
	msg.nUp = true
	CA.frame:SetAlpha(155)
	CA.frame:Show()
end

function CA_UI.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("JH_CA_CREATE")
	CA.frame  = this
	CA.handle = this:Lookup("", "")
	CA.msg    = this:Lookup("", "MessageBox")
	CA.UpdateAnchor(this)
end

function CA_UI.OnFrameBreathe()
	local nNow = GetTime()
	local msg = CA.msg
	if msg.nCreate then
		if (nNow - msg.nCreate) / 1000 > msg.nTime then
			msg.nCreate = nil
			CA.frame:Hide()
		else
			if msg.bUp then
				local nAlpha = min(255, CA.frame:GetAlpha() + 10)
				CA.frame:SetAlpha(nAlpha)
				if nAlpha == 255 then
					msg.bUp = false
				end
			else
				local nAlpha = max(155, CA.frame:GetAlpha() - 10)
				CA.frame:SetAlpha(nAlpha)
				if nAlpha == 155 then
					msg.bUp = true
				end
			end
		end
	end
end

function CA_UI.OnEvent(szEvent)
	if szEvent == "JH_CA_CREATE" then
		CreateCentralAlert(arg0, arg1, arg2)
	elseif szEvent == "UI_SCALED" then
		CA.UpdateAnchor(this)
	elseif szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, _L["CenterAlarm"])
		if szEvent == "ON_ENTER_CUSTOM_UI_MODE" then
			this:Show()
		else
			this:Hide()
		end
	end
end

function CA_UI.OnFrameDragEnd()
	this:CorrectPos()
	ST_UI.tAnchor = GetFrameAnchor(this)
end

function CA.UpdateAnchor(frame)
	local a = CA_UI.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, -150)
	end
end

function CA.Init()
	local frame =  Wnd.OpenWindow(CA_INIFILE, "CA_UI")
	frame:Hide()
end

JH.RegisterEvent("LOGIN_GAME", CA.Init)
