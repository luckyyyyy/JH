-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-11-19 07:51:19
local _L = JH.LoadLangPack

LargeText = {
	tAnchor      = {},
	fScale       = 1.5,
	fPause       = 1,
	fFadeOut     = 0.3,
	dwFontScheme = 23,
}
JH.RegisterCustomData("LargeText", 2)

local LT = {
	szIniFile = JH.GetAddonInfo().szRootPath ..  "DBM/ui/LT_UI.ini",
}

function LargeText.OnFrameCreate()
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("JH_LARGETEXT")
	LT.UpdateAnchor(this)
	LT.frame = this
	LT.txt = this:Lookup("", "Text_Total")
end

function LargeText.OnEvent(szEvent)
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

function LargeText.OnFrameDragEnd()
	this:CorrectPos()
	LargeText.tAnchor = GetFrameAnchor(this)
end

function LT.UpdateAnchor(frame)
	local a = LargeText.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

function LT.Init()
	local frame = LT.frame or Wnd.OpenWindow(LT.szIniFile, "LargeText")
	return frame
end

function LT.UpdateText(txt, col)
	if not col then
		col = { 255, 128, 0 }
	end
	LT.txt:SetText(txt)
	LT.txt:SetFontScheme(LargeText.dwFontScheme)
	LT.txt:SetFontScale(LargeText.fScale)
	LT.txt:SetFontColor(unpack(col))
	LT.frame:FadeIn(0)
	LT.frame:SetAlpha(255)
	LT.frame:Show()
	LT.nTime = GetTime()
	JH.BreatheCall("LargeText", LT.OnBreathe)
end

function LT.OnBreathe()
	local nTime = GetTime()
	if LT.nTime and (nTime - LT.nTime) / 1000 > LargeText.fPause then
		LT.nTime = nil
		LT.frame:FadeOut(LargeText.fFadeOut * 10)
		JH.BreatheCall("LargeText")
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["LargeText"], font = 27 }):Pos_()
	ui:Append("WndButton2", { x = 400, y = 20, txt = g_tStrings.FONT })
	:Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			LargeText.dwFontScheme = nFont
			ui:Fetch("preview"):Font(LargeText.dwFontScheme):Scale(LargeText.fScale)
		end)
	end)
	nX = ui:Append("Text", { txt = _L["Font Scale"], x = 10, y = nY + 5 }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 10, y = nY + 8, txt = "" })
	:Range(1, 2, 10):Value(LargeText.fScale):Change(function(nVal)
		LargeText.fScale = nVal
		ui:Fetch("preview"):Font(LargeText.dwFontScheme):Scale(LargeText.fScale)
	end):Pos_()
	nX = ui:Append("Text", { txt = _L["Pause time"], x = 10, y = nY }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 10, y = nY + 3, txt = _L["s"]  })
	:Range(0.5, 3, 25):Value(LargeText.fPause):Change(function(nVal)
		LargeText.fPause = nVal
	end):Pos_()
	nX = ui:Append("Text", { txt = _L["FadeOut time"], x = 10, y = nY }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 10, y = nY + 3, txt = _L["s"]  })
	:Range(0, 3, 30):Value(LargeText.fFadeOut):Change(function(nVal)
		LargeText.fFadeOut = nVal
	end):Pos_()
	ui:Append("WndButton2", { txt = _L["preview"], x = 10, y = nY }):Click(function()
		LT.UpdateText(_L("%s are welcome to use JH plug-in",GetClientPlayer().szName),{ 255, 128, 0 }, true)
	end)
	ui:Append("Text", "preview", { x = 20, y = nY + 50, txt = _L["JX3"], font = LargeText.dwFontScheme}):Scale(LargeText.fScale)
	nX, nY = ui:Append("Text", { txt = _L["Tips"], x = 0, y = 230, font = 27 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY + 10, w = 500 , h = 20, multi = true, txt = _L["Enable KG3DEngineDX11 better effect"] }):Pos_()
end
GUI.RegisterPanel(_L["LargeText"], { "ui/Image/TargetPanel/Target.uitex", 59 }, _L["Dungeon"], PS)

JH.RegisterEvent("LOGIN_GAME", LT.Init)
