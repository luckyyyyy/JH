-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2016-12-13 01:10:32
local _L = JH.LoadLangPack

TargetFace = {
	bTTName = true, -- 显示目标的目标名字
	bSelfFace = false, -- 绘制自身面向
	tSelfFace = {
		{ bEnable = false, col = { 255, 255, 255 }, nAlpha = 100, nAngle = 360, nRadius = 2  },
		{ bEnable = true, col = { 255, 128, 0 }, nAlpha = 100, nAngle = 45, nRadius = 6  }
	},
	bTargetFace = false, -- 绘制目标面向
	tTargetFace = {
		{ bEnable = false, col = { 255, 255, 0 }, nAlpha = 100, nAngle = 360, nRadius = 2  },
		{ bEnable = true, col = { 255, 128, 0 }, nAlpha = 100, nAngle = 90, nRadius = 8  }
	},
	bConnect = true,				-- 启用目标追踪线
	bTTConnect = true,		-- 显示目标与目标的目标连接线
	nConnWidth = 3,				-- 连接线宽度
	fScale = 1,
	nConnAlpha = 150,			-- 连接线不透明度
	tConnColor = { 0, 255, 0 },	-- 颜色
	tTTConnColor = { 255, 0, 0 },	-- 颜色
	bDirection = false,
	tAnchor = {},
	bOnlyPlane = false,
	-- 仇恨显示
	bHatred = false,
	tHatredAnchor = { nX = -86, nY = -18},
	bHatredLockPanel = false,
	bHatredShowBG = true,
}
JH.RegisterCustomData("TargetFace")

Direction, Hatred = {}, {}
local Direction, Hatred, TargetFace = Direction, Hatred, TargetFace
local _Direction = {
	szIniFile = JH.GetAddonInfo().szRootPath .. "JH_TargetMon/ui/Direction.ini"
}
local _Hatred = {
	dwTarget = 0,
	szIniFile = JH.GetAddonInfo().szRootPath .. "JH_TargetMon/ui/Hatred.ini"
}
local _TargetFace = {
	bReRender = false,
	tCache = {
		nTarget    = -1,
		nSelf      = -1,
		dwTargetID = 0,
		dwTTID     = 0,
	},
}

function _TargetFace.Init()
	local handle = JH.GetShadowHandle("TargetFace")
	-- shadows
	for _, v in ipairs({ "hTargetFace1", "hTargetFace2", "hSelfFace1", "hSelfFace2", "hTLine", "hTTLine", "hName" }) do
		_TargetFace[v]  = handle:AppendItemFromIni(JH.GetAddonInfo().szShadowIni, "shadow", v)
	end
	_TargetFace.hName:SetTriangleFan(GEOMETRY_TYPE.TEXT)
	JH.BreatheCall("TargetFace", _TargetFace.OnBreathe)
end

function _TargetFace.DrawText(tar, txt, bSelf)
	local sha = _TargetFace.hName
	_TargetFace.hName:ClearTriangleFanPoint()
	local r, g, b = 255, 255, 0
	if bSelf then
		r, g, b = 255, 255, 255
	end
	sha:AppendCharacterID(tar.dwID, false, r, g, b, 255, 50, 40, txt, 1, TargetFace.fScale)
	sha:Show()
end

function _TargetFace.DrawLine(tar, ttar, sha, col, nAlpha)
	sha:SetTriangleFan(GEOMETRY_TYPE.LINE, TargetFace.nConnWidth)
	sha:ClearTriangleFanPoint()
	local r, g, b = unpack(col)
	sha:AppendCharacterID(tar.dwID, true, r, g, b, nAlpha)
	sha:AppendCharacterID(ttar.dwID, true, r, g, b, nAlpha)
	sha:Show()
end
-- draw shape
function _TargetFace.DrawShape(tar, sha, nDegree, nRadius, nAlpha, col)
	nRadius = nRadius * 64
	local nFace = math.ceil(128 * nDegree / 360)
	local dwRad1 = math.pi * (tar.nFaceDirection - nFace) / 128
	if tar.nFaceDirection > (256 - nFace) then
		dwRad1 = dwRad1 - math.pi - math.pi
	end
	local dwRad2 = dwRad1 + (nDegree / 180 * math.pi)
	local nStep = 18
	if nDegree == 360 then
		dwRad2 = dwRad2 + math.pi / 20
	end
	if nDegree <= 45 then nStep = 180 end
	local r, g, b = unpack(col)
	-- orgina point
	sha:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	sha:SetD3DPT(D3DPT.TRIANGLEFAN)
	sha:ClearTriangleFanPoint()
	sha:AppendCharacterID(tar.dwID, false, r, g, b, nAlpha)
	sha:Show()
	-- relative points
	local sX, sZ = Scene_PlaneGameWorldPosToScene(tar.nX, tar.nY)
	repeat
		local sX_, sZ_ = Scene_PlaneGameWorldPosToScene(tar.nX + math.cos(dwRad1) * nRadius, tar.nY + math.sin(dwRad1) * nRadius)
		sha:AppendCharacterID(tar.dwID, false, r, g, b, nAlpha --[[nAlpha2]], { sX_ - sX, 0, sZ_ - sZ })
		dwRad1 = dwRad1 + math.pi / nStep
	until dwRad1 >= dwRad2
end

function _TargetFace.OnBreathe()
	local _t, t, ttar = _TargetFace, TargetFace, nil
	local me = GetClientPlayer()
	if not me then return end
	local tar = JH.GetTarget()
	-- target face
	if not tar then
		_t.tCache.nTarget = -1
		_t.tCache.dwTargetID = 0
	else
		_t.tCache.dwTargetID = tar.dwID
		ttar = JH.GetTarget(tar.GetTarget())
	end
	-- target face
	if t.bTargetFace and tar then
		if tar.dwID ~= me.dwID or not t.bSelfFace then
			if _t.tCache.nTarget ~= tar.nFaceDirection or _t.bReRender then
				for k, v in ipairs(t.tTargetFace) do
					if v.bEnable then
						_t.DrawShape(tar, _t["hTargetFace" .. k], v.nAngle, v.nRadius, v.nAlpha, v.col)
					else
						_t["hTargetFace" .. k]:Hide()
					end
				end
				_t.tCache.nTarget = tar.nFaceDirection
			end
		else
			_t.hTargetFace1:Hide()
			_t.hTargetFace2:Hide()
		end
	else
		_t.hTargetFace1:Hide()
		_t.hTargetFace2:Hide()
	end
	-- self face
	if t.bSelfFace and me then
		if _t.tCache.nSelf ~= me.nFaceDirection or _t.bReRender then
			for k, v in ipairs(t.tSelfFace) do
				if v.bEnable then
					_t.DrawShape(me, _t["hSelfFace" .. k], v.nAngle, v.nRadius, v.nAlpha, v.col)
				else
					_t["hSelfFace" .. k]:Hide()
				end
			end
			_t.tCache.nSelf = me.nFaceDirection
		end
	else
		_t.hSelfFace1:Hide()
		_t.hSelfFace2:Hide()
	end
	-- show name
	if t.bTTName and tar and ttar then
		local szName = JH.GetTemplateName(ttar, true)
		if _t.bReRender or _t.tCache.dwTTID ~= ttar.dwID then
			_t.DrawText(tar, _L[">>"] .. szName .. _L["<<"], ttar.dwID == me.dwID)
		end
	else
		_t.hName:Hide()
	end

	-- shoe connect
	if t.bConnect
		and tar
		and tar.dwID ~= me.dwID
		and (not ttar or not t.bTTConnect or (ttar and ttar.dwID ~= me.dwID))
	then
		if _t.bReRender or (ttar and _t.tCache.dwTTID ~= ttar.dwID) or _t.tCache.dwTargetID ~= tar.dwID or (not ttar and _t.tCache.dwTTID ~= 0) then
			_TargetFace.DrawLine(me, tar, _t.hTLine, t.tConnColor, t.nConnAlpha)
		end
	else
		_t.hTLine:Hide()
	end

	if t.bTTConnect and tar and ttar then
		if _t.bReRender or _t.tCache.dwTTID ~= ttar.dwID then
			_TargetFace.DrawLine(tar, ttar, _t.hTTLine, t.tTTConnColor, t.nConnAlpha)
		end
	else
		_t.hTTLine:Hide()
	end
	if ttar then
		_t.tCache.dwTTID = ttar.dwID
	else
		_t.tCache.dwTTID = 0
	end
	if t.bDirection then
		if tar and tar.dwID ~= me.dwID then
			_Direction.frame:Show()
			_Direction.UpdateGPS(tar)
		else
			_Direction.frame:Hide()
		end
	end
	_t.bReRender = false
end

function _TargetFace.CalcFace(me, tar, nDis)
	local nX = tar.nX - me.nX
	local nY = tar.nY - me.nY
	local nFace =  me.nFaceDirection / 256 * 360
	local nDeg = 0
	if nY == 0 then
		if nX < 0 then
			nDeg = 180
		end
	elseif nX == 0 then
		if nY > 0 then
			nDeg = 90
		else
			nDeg = 270
		end
	else
		nDeg = math.deg(math.atan(nY / nX))
		if nX < 0 then
			nDeg = 180 + nDeg
		elseif nY < 0 then
			nDeg = 360 + nDeg
		end
	end
	local nAngle = nFace - nDeg
	if nAngle < -180 then
		nAngle = nAngle + 360
	elseif nAngle > 180 then
		nAngle = nAngle - 360
	end
	return math.abs(nAngle)
end

function _Direction.OpenPanel()
	local frame = _Direction.frame or Wnd.OpenWindow(_Direction.szIniFile,"Direction")
	return frame
end

function _Direction.ClosePanel()
	Wnd.CloseWindow(_Direction.frame)
	_Direction.frame = nil
	_Direction.Arrow = nil
	_Direction.txt = nil
end

function Direction.OnFrameCreate()
	_Direction.frame = this
	_Direction.Arrow = this:Lookup("", "Handle_Main/Image_Player")
	_Direction.Arrow:FromUITex(JH.GetAddonInfo().szRootPath .. "JH_TargetMon/ui/Direction.uitex", 1)
	this:Lookup("", "Handle_Main/Image_Arrow"):FromUITex(JH.GetAddonInfo().szRootPath .. "JH_TargetMon/ui/Direction.uitex", 0)
	_Direction.txt = this:Lookup("", "Handle_Main/Text_Distance")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	_Direction.UpdateAnchor(this)
end

function Direction.OnEvent(szEvent)
	if szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, _L["Direction"])
	elseif szEvent == "UI_SCALED" then
		_Direction.UpdateAnchor(this)
	end
end

function Direction.OnFrameDragEnd()
	this:CorrectPos()
	TargetFace.tAnchor = GetFrameAnchor(this)
end

function _Direction.UpdateAnchor(frame)
	local a = TargetFace.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 250, 100)
	end
	frame:CorrectPos()
end

function _Direction.UpdateGPS(tar)
	local me = GetClientPlayer()
	local dwRad1 = math.atan2(tar.nY - me.nY, tar.nX - me.nX)
	local dwRad2 = me.nFaceDirection / 128 * math.pi
	_Direction.Arrow:SetRotate(1.5 * math.pi + dwRad2 - dwRad1)
	if TargetFace.bOnlyPlane then
		_Direction.txt:SetText(_L("%.1f feet", JH.GetDistance(tar.nX, tar.nY)))
	else
		_Direction.txt:SetText(_L("%.1f feet", JH.GetDistance(tar)))
	end
end

-- 仇恨
function _Hatred.OpenPanel()
	local frame = _Hatred.frame or Wnd.OpenWindow(_Hatred.szIniFile, "Hatred")
	return frame
end

function _Hatred.ClosePanel()
	Wnd.CloseWindow(_Hatred.frame)
	JH.BreatheCall("Hatred")
	_Hatred.dwTarget = 0
	_Hatred.text = nil
	_Hatred.frame = nil
end

function Hatred.OnFrameCreate()
	this:RegisterEvent("TARGET_CHANGE")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("CHARACTER_THREAT_RANKLIST")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:EnableDrag(not TargetFace.bHatredLockPanel)
	this:SetMousePenetrable(TargetFace.bHatredLockPanel)
	if TargetFace.bHatredShowBG then
		this:Lookup("", "Image_Bg"):Show()
	else
		this:Lookup("", "Image_Bg"):Hide()
	end
	_Hatred.frame = this
	_Hatred.text = this:Lookup("", "Text_Label")
	this:Hide()
end

function Hatred.OnEvent(szEvent)
	if szEvent == "ON_LEAVE_CUSTOM_UI_MODE" or szEvent == "UI_SCALED" then
		_Hatred.UpdateAnchor(this)
	elseif szEvent == "TARGET_CHANGE" then
		_Hatred.UpdateAnchor(this)
		local dwType, dwID = Target_GetTargetData()
		if dwType == TARGET.NPC then
			_Hatred.dwTarget = dwID
			JH.BreatheCall("Hatred", function() ApplyCharacterThreatRankList(dwID) end)
		else
			_Hatred.dwTarget = 0
			this:Hide()
			JH.BreatheCall("Hatred")
		end
	elseif szEvent == "CHARACTER_THREAT_RANKLIST" then
		if arg0 == _Hatred.dwTarget then
			if arg2 and arg1[arg2] then
				this:Show()
				local dwTargetRank = arg1[arg2]
				if dwTargetRank == 0 then
					dwTargetRank = 65535
				end
				local myRank = arg1[UI_GetClientPlayerID()] or 0
				local fP = myRank / dwTargetRank * 100
				local r, g, b = 255, 255, 255
				if fP > 85 and fP < 100 then
					r, g, b = 255, 255, 0
				elseif fP > 100 then
					r, g, b = 255, 128, 0
				elseif fP == 100 then
					r, g, b = 255, 0, 0
				end
				_Hatred.text:SetText(FixFloat(fP, 1) .. "%")
				_Hatred.text:SetFontColor(r, g, b)
			elseif IsEmpty(arg1) then
				this:Hide()
			end
		end
	end
end

function Hatred.OnFrameDragEnd()
	local hTarget = Station.Lookup("Normal/Target")
	if hTarget then
		local hX, hY = hTarget:GetAbsPos()
		local nX, nY = this:GetAbsPos()
		TargetFace.tHatredAnchor.nX = hX - nX
		TargetFace.tHatredAnchor.nY = hY - nY
	end
	_Hatred.UpdateAnchor(this)
end

function _Hatred.UpdateAnchor(frame)
	local hTarget = Station.Lookup("Normal/Target")
	if hTarget then
		local an = GetFrameAnchor(hTarget, "TOPLEFT")
		local nX, nY = TargetFace.tHatredAnchor.nX, TargetFace.tHatredAnchor.nY
		frame:SetPoint(an.s, 0, 0, an.r, an.x - nX, an.y - nY)
		frame:CorrectPos()
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("WndCheckBox", { txt = _L["Display the sector of target facing"], font = 27, checked = TargetFace.bTargetFace })
	:Click(function(bChecked)
		TargetFace.bTargetFace = bChecked
		_TargetFace.bReRender = true
	end):Pos_()
	for k, v in ipairs(TargetFace.tTargetFace) do
		nX = ui:Append("WndCheckBox", { x = 10, y = nY - 3, txt = _L("Circle %d", k), checked = v.bEnable })
		:Click(function(bChecked)
			v.bEnable = bChecked
			_TargetFace.bReRender = true
		end):Pos_()
		nX = ui:Append("Shadow", "Color_TargetFace" .. k, { x = nX, y = nY + 2, w = 18, h = 18, color = v.col })
		:Click(function()
			GUI.OpenColorTablePanel(function(r, g, b)
				ui:Fetch("Color_TargetFace" .. k):Color(r, g, b)
				v.col = { r, g, b }
				_TargetFace.bReRender = true
			end)
		end):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 8, y = nY, w = 35, h = 23, txt = v.nAngle })
		:Change(function(nVal)
			v.nAngle = tonumber(nVal) or 0
			_TargetFace.bReRender = true
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 2, y = nY - 2, txt = _L[" degree"] }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 8, y = nY, w = 35, h = 23, txt = v.nRadius, limit = 2 })
		:Change(function(nVal)
			v.nRadius = tonumber(nVal) or 0
			_TargetFace.bReRender = true
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 2, y = nY - 2, txt = _L[" feet"] }):Pos_()
		nX, nY = ui:Append("WndComboBox", { x = nX + 2, y = nY, w = 75, h = 25, txt = g_tStrings.STR_ALPHA }):Menu(function()
			local menu = {}
			for kk, vv in ipairs({25, 50, 75, 100}) do
				table.insert(menu, { szOption = vv, bMCheck = true, bChecked = v.nAlpha == vv, fnAction = function()
					v.nAlpha = vv
					_TargetFace.bReRender = true
				end })
			end
			return menu
		end):Pos_()
	end
	nX,nY = ui:Append("WndCheckBox", { txt = _L["Display the sector of Self facing"], font = 27, checked = TargetFace.bSelfFace })
	:Pos(0, 72):Click(function(bChecked)
		TargetFace.bSelfFace = bChecked
		_TargetFace.bReRender = true
	end):Pos_()
	for k, v in ipairs(TargetFace.tSelfFace) do
		nX = ui:Append("WndCheckBox", { x = 10, y = nY - 3, txt = _L("Circle %d", k), checked = v.bEnable })
		:Click(function(bChecked)
			v.bEnable = bChecked
			_TargetFace.bReRender = true
		end):Pos_()
		nX = ui:Append("Shadow", "Color_TargetFace2" .. k, { x = nX, y = nY + 2, w = 18, h = 18, color = v.col })
		:Click(function()
			GUI.OpenColorTablePanel(function(r, g, b)
				ui:Fetch("Color_TargetFace2" .. k):Color(r, g, b)
				v.col = { r, g, b }
				_TargetFace.bReRender = true
			end)
		end):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 8, y = nY, w = 35, h = 23, txt = v.nAngle })
		:Change(function(nVal)
			v.nAngle = tonumber(nVal) or 0
			_TargetFace.bReRender = true
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 2, y = nY - 2, txt = _L[" degree"] }):Pos_()

		nX = ui:Append("WndEdit", { x = nX + 8, y = nY, w = 35, h = 23, txt = v.nRadius, limit = 2 })
		:Change(function(nVal)
			v.nRadius = tonumber(nVal) or 0
			_TargetFace.bReRender = true
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 2, y = nY - 2, txt = _L[" feet"] }):Pos_()
		nX, nY = ui:Append("WndComboBox", { x = nX + 2, y = nY, w = 75, h = 25, txt = g_tStrings.STR_ALPHA }):Menu(function()
			local menu = {}
			for kk, vv in ipairs({25, 50, 75, 100}) do
				table.insert(menu, { szOption = vv, bMCheck = true, bChecked = v.nAlpha == vv, fnAction = function()
					v.nAlpha = vv
					_TargetFace.bReRender = true
				end })
			end
			return menu
		end):Pos_()
	end
	-- line
	nX, nY = ui:Append("Text", { txt = _L["Target connect line"], x = 0, y = 142, font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = TargetFace.bConnect })
	:Text(_L["Draw line from target to you"]):Click(function(bChecked)
		TargetFace.bConnect = bChecked
	end):Pos_()
	nX = ui:Append("Shadow", "tConnColor", { x = nX + 5, y = nY + 15, w = 18, h = 18 })
	:Color(unpack(TargetFace.tConnColor)):Click(function()
		GUI.OpenColorTablePanel(function(r, g, b)
			ui:Fetch("tConnColor"):Color(r, g, b)
			TargetFace.tConnColor = { r, g, b }
			_TargetFace.bReRender = true
		end)
	end):Pos_()

	nX = ui:Append("WndCheckBox", { x = nX + 20, y = nY + 10, checked = TargetFace.bTTConnect })
	:Text(_L["Draw line from target to target target"]):Click(function(bChecked)
		TargetFace.bTTConnect = bChecked
	end):Pos_()
	nX,nY = ui:Append("Shadow", "tTTConnColor", { x = nX + 5, y = nY + 15, w = 18, h = 18 })
	:Color(unpack(TargetFace.tTTConnColor)):Click(function()
		GUI.OpenColorTablePanel(function(r, g, b)
			ui:Fetch("tTTConnColor"):Color(r, g, b)
			TargetFace.tTTConnColor = { r, g, b }
			_TargetFace.bReRender = true
		end)
	end):Pos_()
	nX = ui:Append("WndTrackBar", { x = 14, y = nY + 5, txt = _L[" alpha"] })
	:Range(30, 255, 225):Value(TargetFace.nConnAlpha):Change(function(nVal)
		TargetFace.nConnAlpha = nVal
		_TargetFace.bReRender = true
	end):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = 240, y = nY + 5, txt = _L[" feet"] })
	:Range(1, 8, 7):Value(TargetFace.nConnWidth):Change(function(nVal)
		TargetFace.nConnWidth = nVal
		_TargetFace.bReRender = true
	end):Pos_()
	-- target dir
	nX, nY = ui:Append("Text", { txt = _L["Target"], x = 0, y = nY, font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = TargetFace.bDirection })
	:Text(_L["Show direction (adjust position by SHIFT-U)"]):Click(function(bChecked)
		TargetFace.bDirection = bChecked
		if bChecked then
			_Direction.OpenPanel()
		else
			_Direction.ClosePanel()
		end
		ui:Fetch("bOnlyPlane"):Enable(bChecked)
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bOnlyPlane", { x = nX + 5, y = nY + 10, checked = TargetFace.bOnlyPlane })
	:Enable(TargetFace.bDirection):Text(_L["OnlyPlane direction"]):Click(function(bChecked)
		TargetFace.bOnlyPlane = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY, checked = TargetFace.bTTName })
	:Text(_L["Show TTarget Name"]):Click(function(bChecked)
		TargetFace.bTTName = bChecked
		_TargetFace.bReRender = true
		ui:Fetch("fScale"):Enable(bChecked)
	end):Pos_()
	nX = ui:Append("Text", { txt = _L["Text Scale"], x = nX + 2, y = nY - 2 }):Pos_()
	nX, nY = ui:Append("WndTrackBar", "fScale", { x = nX + 5, y = nY + 2, txt = "" })
	:Enable(TargetFace.bTTName):Range(1, 1.5, 5):Value(TargetFace.fScale):Change(function(nVal)
		TargetFace.fScale = nVal
		_TargetFace.bReRender = true
	end):Pos_()

	nX = ui:Append("WndCheckBox", { x = 10, y = nY, checked = TargetFace.bHatred })
	:Text(_L["Show Target Hatred"]):Click(function(bChecked)
		TargetFace.bHatred = bChecked
		ui:Fetch("bHatredLockPanel"):Enable(bChecked)
		ui:Fetch("bHatredShowBG"):Enable(bChecked)
		if bChecked then
			_Hatred.OpenPanel()
		else
			_Hatred.ClosePanel()
		end
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bHatredLockPanel", { x = nX + 5, y = nY, checked = TargetFace.bHatredLockPanel })
	:Enable(TargetFace.bHatred):Text(_L["Lock Panel"]):Click(function(bChecked)
		TargetFace.bHatredLockPanel = bChecked
		if _Hatred.frame then
			_Hatred.frame:EnableDrag(not bChecked)
			_Hatred.frame:SetMousePenetrable(bChecked)
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bHatredShowBG", { x = nX + 5, y = nY, checked = TargetFace.bHatredShowBG })
	:Enable(TargetFace.bHatred):Text(_L["Show Background"]):Click(function(bChecked)
		TargetFace.bHatredShowBG = bChecked
		if _Hatred.frame then
			if bChecked then
				_Hatred.frame:Lookup("", "Image_Bg"):Show()
			else
				_Hatred.frame:Lookup("", "Image_Bg"):Hide()
			end
		end
	end):Pos_()
	nX, nY = ui:Append("Text", { txt = _L["Tips"], x = 0, y = nY, font = 27 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY + 10, w = 500 , h = 20, multi = true, txt = _L["Enable KG3DEngineDX11 better effect"] }):Pos_()
end

JH.RegisterInit("TargetFace",
	{ "LOGIN_GAME", function()
		_TargetFace.Init()
		if TargetFace.bDirection then
			_Direction.OpenPanel()
		end
		if TargetFace.bHatred then
			_Hatred.OpenPanel()
		end
	end },
	{ "TARGET_CHANGE", function() _TargetFace.bReRender = true end },
	{ "LOADING_END", function() _TargetFace.bReRender = true end }
)

GUI.RegisterPanel(_L["TargetFace"], { "ui/Image/TargetPanel/Target.uitex", 47 }, g_tStrings.CHANNEL_CHANNEL, PS)
