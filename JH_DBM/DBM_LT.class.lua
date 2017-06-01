-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2017-06-01 15:53:17
local _L = JH.LoadLangPack

DBM_LT = {
	tAnchor      = {},
	fScale       = 1.5,
	fPause       = 1,
	fFadeOut     = 0.3,
	dwFontScheme = 23,
}
JH.RegisterCustomData("DBM_LT")

local INIFILE = JH.GetAddonInfo().szRootPath ..  "JH_DBM/ui/LT_UI.ini"
local LT = {}
function DBM_LT.OnFrameCreate()
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("JH_LARGETEXT")
	LT.UpdateAnchor(this)
	LT.frame = this
	LT.txt = this:Lookup("", "Text_Total")
end

function DBM_LT.OnEvent(szEvent)
	if szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		if szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
			LT.frame:Hide()
		else
			LT.frame:FadeIn(0)
			LT.frame:SetAlpha(255)
			LT.frame:Show()
		end
		UpdateCustomModeWindow(this, _L["LargeText"], true)
	elseif szEvent == "UI_SCALED" then
		LT.UpdateAnchor(this)
	elseif szEvent == "JH_LARGETEXT" then
		LT.UpdateText(arg0, arg1)
	end
end

function DBM_LT.OnFrameDragEnd()
	this:CorrectPos()
	DBM_LT.tAnchor = GetFrameAnchor(this)
end

function LT.UpdateAnchor(frame)
	local a = DBM_LT.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

function LT.Init()
	local frame = LT.frame or Wnd.OpenWindow(INIFILE, "DBM_LT")
	return frame
end

function LT.UpdateText(txt, col)
	if not col then
		col = { 255, 128, 0 }
	end
	LT.txt:SetText(txt)
	LT.txt:SetFontScheme(DBM_LT.dwFontScheme)
	LT.txt:SetFontScale(1.5)
	LT.txt:SetFontColor(unpack(col))
	LT.frame:FadeIn(0)
	LT.frame:SetAlpha(255)
	LT.frame:Show()
	LT.nTime = GetTime()
	JH.BreatheCall("DBM_LT", LT.OnBreathe)
end

function LT.OnBreathe()
	local nTime = GetTime()
	if LT.nTime and (nTime - LT.nTime) / 1000 > DBM_LT.fPause then
		LT.nTime = nil
		LT.frame:FadeOut(DBM_LT.fFadeOut * 10)
		JH.BreatheCall("DBM_LT")
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["LargeText"], font = 27 }):Pos_()
	-- nX = ui:Append("Text", { txt = _L["Font Scale"], x = 10, y = nY + 10 }):Pos_()
	-- nX, nY = ui:Append("WndTrackBar", { x = nX + 10, y = nY + 13, txt = "" }):Range(1, 1.5, 5):Value(DBM_LT.fScale):Change(function(nVal)
	-- 	DBM_LT.fScale = nVal
	-- 	ui:Fetch("preview"):Font(DBM_LT.dwFontScheme):Scale(DBM_LT.fScale)
	-- end):Pos_()

	nX = ui:Append("Text", { txt = _L["Pause time"], x = 10, y = nY }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 10, y = nY + 3, txt = _L["s"] }):Range(0.5, 3, 25):Value(DBM_LT.fPause):Change(function(nVal)
		DBM_LT.fPause = nVal
	end):Pos_()

	nX = ui:Append("Text", { txt = _L["FadeOut time"], x = 10, y = nY }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 10, y = nY + 3, txt = _L["s"] }):Range(0, 3, 30):Value(DBM_LT.fFadeOut):Change(function(nVal)
		DBM_LT.fFadeOut = nVal
	end):Pos_()

	nX = ui:Append("WndButton2", { x = 10, y = nY + 5, txt = g_tStrings.FONT }):Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			DBM_LT.dwFontScheme = nFont
			ui:Fetch("preview"):Font(DBM_LT.dwFontScheme):Scale(1.5)
		end)
	end):Pos_()
	ui:Append("WndButton2", { txt = _L["preview"], x = nX + 10, y = nY + 5 }):Click(function()
		LT.UpdateText(_L("%s are welcome to use JH plug-in", GetUserRoleName()))
	end)
	ui:Append("Text", "preview", { x = 20, y = nY + 50, txt = _L["JX3"], font = DBM_LT.dwFontScheme}):Scale(1.5)
	nX, nY = ui:Append("Text", { txt = _L["Tips"], x = 0, y = 230, font = 27 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY + 10, w = 500 , h = 20, multi = true, txt = _L["Enable KG3DEngineDX11 better effect"] }):Pos_()
end
GUI.RegisterPanel(_L["LargeText"], { "ui/Image/TargetPanel/Target.uitex", 59 }, _L["Dungeon"], PS)

JH.RegisterEvent("LOGIN_GAME", LT.Init)
