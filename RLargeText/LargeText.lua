local _L = JH.LoadLangPack

LargeText = {
	bEnable = true,
	tAnchor = {},
	fScale = 3,
	nPause = 1.5,
	nCount = 15,
	dwFontScheme = 23,
	bIsMe = true,
}
JH.RegisterCustomData("LargeText")

local _LargeText = {
	szIniFile =  JH.GetAddonInfo().szRootPath ..  "RLargeText/ui/LargeText.ini",
}

function LargeText.OnFrameCreate()
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("JH_LARGETEXT")
	_LargeText.UpdateAnchor(this)
	_LargeText.frame = this
	_LargeText.txt = this:Lookup("","Text_Total")
end

function LargeText.OnEvent(szEvent)
	if szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		if szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
			_LargeText.frame:Hide()
		else
			_LargeText.frame:FadeIn(0)
			_LargeText.frame:SetAlpha(255)
			_LargeText.frame:Show()
		end
		UpdateCustomModeWindow(this,_L["LargeText"],true)
	elseif szEvent == "UI_SCALED" then
		_LargeText.UpdateAnchor(this)
	elseif szEvent == "JH_LARGETEXT" then
		if not LargeText.bEnable then return end
		if not col then
			col = { 255, 128, 0 }
			bMe = true
		end
		_LargeText.UpdateText(arg0, arg1, arg2)
	end
end

function LargeText.OnFrameDragEnd()
	this:CorrectPos()
	LargeText.tAnchor = GetFrameAnchor(this)
end

_LargeText.UpdateAnchor = function(frame)
	local a = LargeText.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

_LargeText.OpenPanel = function()
	local frame = _LargeText.frame or Wnd.OpenWindow(_LargeText.szIniFile,"LargeText")
	return frame
end

_LargeText.UpdateText = function(txt, col, bMe)
	if not bMe and LargeText.bIsMe then
		return
	end
	_LargeText.txt:SetText(txt)
	_LargeText.txt:SetFontScheme(LargeText.dwFontScheme)
	_LargeText.txt:SetFontScale(LargeText.fScale)
	_LargeText.txt:SetFontColor(unpack(col))
	_LargeText.frame:FadeIn(0)
	_LargeText.frame:SetAlpha(255)
	_LargeText.frame:Show()
	_LargeText.nTime = GetTime()
	JH.BreatheCall("LargeText", _LargeText.OnBreathe)
end

_LargeText.OnBreathe = function()
	local nTime = GetTime()
	if _LargeText.nTime and (nTime - _LargeText.nTime) / 1000 > LargeText.nPause then
		_LargeText.nTime = nil
		_LargeText.frame:FadeOut(LargeText.nCount)
		JH.BreatheCall("LargeText")
	end
end

local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	ui:Append("Text", { x = 0, y = 0, txt = _L["LargeText"], font = 27 })
	ui:Append("WndButton2", { x = 400, y = 20, txt = g_tStrings.FONT })
	:Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			LargeText.dwFontScheme = nFont
			ui:Fetch("preview"):Font(LargeText.dwFontScheme):Scale(LargeText.fScale)
		end)
	end)
	
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = 28, checked = LargeText.bEnable })
	:Text(_L["Enable LargeText"]):Click(function(bChecked)
		LargeText.bEnable = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = LargeText.bIsMe })
	:Text(_L["only Monitor self"]):Click(function(bChecked)
		LargeText.bIsMe = bChecked
	end):Pos_()
	nX = ui:Append("Text", { txt = _L["Font Scale"], x = 10, y = nY }):Pos_()
	nX,nY = ui:Append("WndTrackBar", { x = nX +10, y = nY + 3 })
	:Range(1,100):Value(LargeText.fScale * 20):Change(function(nVal) 
		LargeText.fScale = nVal / 20
		ui:Fetch("preview"):Font(LargeText.dwFontScheme):Scale(LargeText.fScale)
	end):Pos_()
	nX = ui:Append("Text", { txt = _L["Pause time(s)"], x = 10, y = nY }):Pos_()
	nX,nY = ui:Append("WndEdit", { x = nX +10, y = nY + 3,txt = LargeText.nPause })
	:Change(function(nVal) LargeText.nPause = tonumber(nVal) end):Pos_()
	nX = ui:Append("Text", { txt = _L["FadeOut time(s)"], x = 10, y = nY }):Pos_()
	nX,nY = ui:Append("WndEdit", { x = nX +10, y = nY + 3,txt = LargeText.nCount / 10 })
	:Change(function(txt)
		if tonumber(txt) then
			txt = tonumber(txt) * 10 
			LargeText.nCount = txt
		end
	end):Pos_()
	ui:Append("WndButton2", { txt = _L["preview"], x = 10, y = nY }):Click(function()
		_LargeText.UpdateText(_L("%s are welcome to use JH plug-in",GetClientPlayer().szName),{ 255, 128, 0 }, true)
	end)
	ui:Append("Text", "preview", { x = 20, y = nY + 50, txt = _L["Hello World"], font = LargeText.dwFontScheme}):Scale(LargeText.fScale)
	nX,nY = ui:Append("Text", { txt = _L["Tips"], x = 0, y = 280, font = 27 }):Pos_()
	nX,nY = ui:Append("Text", { x = 10, y = nY + 10, w = 500 , h = 20, multi = true, txt = _L["Enable KG3DEngineDX11 better effect"] }):Pos_()
end
GUI.RegisterPanel(_L["LargeText"], 1934, _L["RGES"], PS)

JH.RegisterEvent("LOGIN_GAME", _LargeText.OpenPanel)