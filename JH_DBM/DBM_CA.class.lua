-- @Author: Webster
-- @Date:   2015-05-04 09:29:09
-- @Last Modified by:   Administrator
-- @Last Modified time: 2016-12-13 01:07:49

local _L = JH.LoadLangPack
local CA_INIFILE = JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/CA_UI.ini"
local type, ipairs, pairs, assert, unpack = type, ipairs, pairs, assert, unpack
local floor = math.floor
local GetTime = GetTime
local CA = {}

CA_UI = {
	tAnchor = {}
}
JH.RegisterCustomData("CA_UI")
-- FireUIEvent("JH_CA_CREATE", "test", 3)
local function CreateCentralAlert(szMsg, nTime, bXml)
	local msg = CA.msg
	nTime = nTime or 3
	msg:Clear()
	if not bXml then
		szMsg = GetFormatText(szMsg, 44, 255, 255, 255)
	end
	msg:AppendItemFromString(szMsg)
	msg:FormatAllItemPos()
	local w, h = msg:GetAllItemSize()
	msg:SetRelPos((480 - w) / 2, (45 - h) / 2 - 1)
	CA.handle:FormatAllItemPos()
	msg.nTime   = nTime
	msg.nCreate = GetTime()
	CA.frame:SetAlpha(255)
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

function CA_UI.OnFrameRender()
	local nNow = GetTime()
	if CA.msg.nCreate then
		local nTime = ((nNow - CA.msg.nCreate) / 1000)
		local nLeft  = CA.msg.nTime - nTime
		if nLeft < 0 then
			CA.msg.nCreate = nil
			CA.frame:Hide()
		else
			local nTimeLeft = nTime * 1000 % 750
			local nAlpha = 50 * nTimeLeft / 750
			if floor(nTime / 0.75) % 2 == 1 then
				nAlpha = 50 - nAlpha
			end
			CA.frame:SetAlpha(255 - nAlpha)
		end
	end
end

function CA_UI.OnEvent(szEvent)
	if szEvent == "JH_CA_CREATE" then
		CreateCentralAlert(arg0, arg1, arg2)
	elseif szEvent == "UI_SCALED" then
		CA.UpdateAnchor(this)
	elseif szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, _L["Center Alarm"])
		if szEvent == "ON_ENTER_CUSTOM_UI_MODE" then
			this:Show()
		else
			this:Hide()
		end
	end
end

function CA_UI.OnFrameDragEnd()
	this:CorrectPos()
	CA_UI.tAnchor = GetFrameAnchor(this)
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
