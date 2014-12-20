local _L = JH.LoadLangPack

TS = {
	bEnable = true, -- 开启
	bInDungeon = true, -- 只有副本内才开启
	nBGAlpha = 30, -- 背景透明度
	szThreatPercentAccuracy = "%.0f%%", --显示几个小数点 没啥意义 不让更改了
	nMaxBarCount = 5, -- 最大列表
	bForceColor = true, --根据门派着色
	nOTAlertLevel = 1, -- OT提醒 必须判断< 1.2 不然强制注视也算OT了
	bOTAlertSound = true, -- OT 播放声音
	tAnchor = {},
	nStyle = 1,
}

local TS = TS
local ipairs, pairs = ipairs, pairs
local GetPlayer, IsPlayer, ApplyCharacterThreatRankList = GetPlayer, IsPlayer, ApplyCharacterThreatRankList

local _TS = {
	szIniFile = JH.GetAddonInfo().szRootPath .. "TS/ui/TS.ini",
	dwTargetID = 0,
	dwLockTargetID = 0,
	bSelfTreatRank = 0,
}
_TS.OpenPanel = function()
	local frame = _TS.frame or Wnd.OpenWindow(_TS.szIniFile, "TS")
	frame:Hide()
	return frame
end

_TS.ClosePanel = function()
	Wnd.CloseWindow(_TS.frame)
	JH.UnBreatheCall("TS")
	-- 释放变量
	_TS.frame = nil
	_TS.bg = nil
	_TS.handle = nil
	_TS.txt = nil
	_TS.CastBar = nil
	_TS.dwLockTargetID = 0
	_TS.dwTargetID = 0
	_TS.bSelfTreatRank = 0
end

function TS.OnFrameCreate()
	this:RegisterEvent("CHARACTER_THREAT_RANKLIST")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("UPDATE_SELECT_TARGET")
	_TS.UpdateAnchor(this)
	_TS.frame = this
	_TS.bg = this:Lookup("", "Image_Background")
	_TS.bg:SetAlpha(255 * TS.nBGAlpha / 100)
	_TS.handle = this:Lookup("", "Handle_List")
	_TS.txt = this:Lookup("","Handle_TargetInfo"):Lookup("Text_Name")
	_TS.CastBar = this:Lookup("","Handle_TargetInfo"):Lookup("Image_Cast_Bar")
	local ui = GUI(this)
	ui:Title(_L["ThreatScrutiny"]):Fetch("CheckBox_ScrutinyLock"):Click(function(bChecked)
		local dwID, dwType = Target_GetTargetData()
		if bChecked then
			if dwType == TARGET.NPC then
				_TS.dwLockTargetID = dwID
			end
		else
			_TS.dwLockTargetID = 0
			if not dwID then
				_TS.frame:Hide()
			end
		end
	end)
	ui:Fetch("Btn_Setting"):Click(function()
		JH.OpenPanel(_L["ThreatScrutiny"])
	end)
	TS.OnEvent("UPDATE_SELECT_TARGET")
end

function TS.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		_TS.UpdateAnchor(this)
	elseif szEvent == "UPDATE_SELECT_TARGET" then
		local dwID, dwType = Target_GetTargetData()
		if dwType == TARGET.NPC or GetNpc(_TS.dwLockTargetID) then
			if GetNpc(_TS.dwLockTargetID) then
				_TS.dwTargetID = _TS.dwLockTargetID
			else
				_TS.dwTargetID = dwID
			end
			local p = GetNpc(_TS.dwTargetID)
			_TS.txt:SetText(JH.GetTemplateName(p))
			_TS.txt:SetFontColor(GetHeadTextForceFontColor(p.dwID, UI_GetClientPlayerID()))
			JH.BreatheCall("TS", _TS.OnBreathe)
			this:Show()
		else
			JH.UnBreatheCall("TS")
			_TS.dwTargetID = 0
			this:Hide()
		end
	elseif szEvent == "CHARACTER_THREAT_RANKLIST" then
		if arg0 == _TS.dwTargetID then
			_TS.UpdateThreatBars(arg0, arg1)
		end
	end
end

function TS.OnFrameDragEnd()
	this:CorrectPos()
	TS.tAnchor = GetFrameAnchor(this)
end

_TS.OnBreathe = function()
	local p = GetNpc(_TS.dwTargetID)
	if p then
		ApplyCharacterThreatRankList(_TS.dwTargetID)
		local bIsPrepare, dwSkillID, dwSkillLevel, per = p.GetSkillPrepareState()
		if bIsPrepare then
			_TS.CastBar:SetPercentage(per)
			_TS.txt:SetText(JH.GetSkillName(dwSkillID, dwSkillLevel))
		else
			_TS.CastBar:Hide()
			_TS.txt:SetText(JH.GetTemplateName(p))
		end
	end
end

_TS.UpdateAnchor = function(frame)
	local a = TS.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("TOPRIGHT", -300, 300, "TOPRIGHT", 0, 0)
	end
	this:CorrectPos()
end

_TS.UpdateThreatBars = function(dwTargetID, tList)
	local me = GetClientPlayer()
	local tar = GetNpc(dwTargetID)
	local _, ttarID = 0, 0
	if tar then
		_, ttarID = tar.GetTarget()
	end
	
	local tThreat = {}
	for dwThreatID, nThreatRank in pairs(tList) do
		if ttarID == dwThreatID then
			table.insert(tThreat, 1, { id = dwThreatID, val = nThreatRank })
		else
			table.insert(tThreat, { id = dwThreatID, val = nThreatRank })
		end
	end
	_TS.bg:SetSize(208, 55 + 24 * math.min(#tThreat, TS.nMaxBarCount))
	_TS.handle:SetSize(208, 24 * math.min(#tThreat, TS.nMaxBarCount))
	_TS.handle:Clear()
	if #tThreat > 0 then
		this:Show()
		if #tThreat >= 2 then
			local _t = tThreat[1]
			table.remove(tThreat, 1)
			table.sort(tThreat, function(a, b) return a.val > b.val end)
			table.insert(tThreat, 1, _t)
		end
		for k, v in ipairs(tThreat) do
			if k > TS.nMaxBarCount then
				break
			end
			local item = _TS.handle:AppendItemFromIni(JH.GetAddonInfo().szRootPath .. "TS/ui/style/" .. TS.nStyle .. ".ini", "Handle_ThreatBar", k)
			if v.val > 0.01 and tThreat[1].val > 0.01 then
				item:Lookup("Text_ThreatValue"):SetText((TS.szThreatPercentAccuracy):format(100 * v.val / tThreat[1].val))
			end
			local r, g, b = 162, 162, 162
			local szName = v.id
			if IsPlayer(v.id) then
				local p = GetPlayer(v.id)
				if p then
					if TS.bForceColor then
						r, g, b = JH.GetForceColor(p.dwForceID)
					else
						r, g, b = 255, 255, 255
					end
					szName = p.szName
				end
			else
				local p = GetNpc(v.id)
				if p then
					szName = p.szName
				end
			end
			item:Lookup("Text_ThreatName"):SetText(szName)
			item:Lookup("Text_ThreatName"):SetFontColor(r, g, b)
			
			local nThreatPercentage = v.val / tThreat[1].val * (100 / 124)
			
			if me.dwID == v.id then
				if TS.nOTAlertLevel > 0 then
					if _TS.bSelfTreatRank < TS.nOTAlertLevel and v.val / tThreat[1].val >= TS.nOTAlertLevel then
						OutputMessage("MSG_ANNOUNCE_YELLOW", _L("** You Threat more than %.1f, 120% is Out of Taunt! **", TS.nOTAlertLevel * 100))
						if TS.bOTAlertSound then
							PlaySound(SOUND.UI_SOUND, _L["SOUND_nat_view2"])
						end
					end
				end
				_TS.bSelfTreatRank = v.val / tThreat[1].val
			end
			if nThreatPercentage >= 0.83 then
				item:Lookup("Image_Treat_Bar_Red"):Show()
				item:Lookup("Image_Treat_Bar_Red"):SetPercentage(nThreatPercentage)
			elseif nThreatPercentage >= 0.54 then
				item:Lookup("Image_Treat_Bar_Yellow"):Show()
				item:Lookup("Image_Treat_Bar_Yellow"):SetPercentage(nThreatPercentage)
			elseif nThreatPercentage >= 0.30 then
				item:Lookup("Image_Treat_Bar_Green"):Show()
				item:Lookup("Image_Treat_Bar_Green"):SetPercentage(nThreatPercentage)
			elseif nThreatPercentage >= 0.01 then
				item:Lookup("Image_Treat_Bar_White"):Show()
				item:Lookup("Image_Treat_Bar_White"):SetPercentage(nThreatPercentage)
			end
			item:Show()
		end
		_TS.handle:FormatAllItemPos()
	-- else
		-- this:Hide()
	end
end

local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["ThreatScrutiny"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = TS.bEnable, txt = _L["Enable ThreatScrutiny"] }):Click(function(bChecked)
		TS.bEnable = bChecked
		ui:Fetch("bInDungeon"):Enable(bChecked)
		if bChecked then
			if TS.bInDungeon then
				if JH.IsInDungeon2() then
					_TS.OpenPanel()
				end
			else
				_TS.OpenPanel()
			end
		else
			_TS.ClosePanel()
		end
		JH.OpenPanel(_L["ThreatScrutiny"])
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", "bInDungeon", { x = 25, y = nY, checked = TS.bInDungeon })
	:Enable(TS.bEnable):Text(_L["Only in the map type is Dungeon Enable plug-in"]):Click(function(bChecked)
		TS.bInDungeon = bChecked
		if bChecked then
			if JH.IsInDungeon2() then
				_TS.OpenPanel()
			else
				_TS.ClosePanel()
			end
		else
			_TS.OpenPanel()
		end
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Alert Setting"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = TS.nOTAlertLevel == 1, txt = _L["OT Alert"] }):Click(function(bChecked)
		if bChecked then -- 以后可以做% 暂时先不管
			TS.nOTAlertLevel = 1
		else
			TS.nOTAlertLevel = 0
		end
		ui:Fetch("bOTAlertSound"):Enable(bChecked)
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bOTAlertSound", { x = nX + 5 , y = nY + 10, checked = TS.bOTAlertSound, txt = _L["OT Alert Sound"] })
	:Enable(TS.nOTAlertLevel == 1):Click(function(bChecked)
		TS.bOTAlertSound = bChecked
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Style Setting"], font = 27 }):Pos_()
	
	nX = ui:Append("WndCheckBox", { x = 10 , y = nY + 10, checked = TS.bForceColor, txt = _L["Force Color"] })
	:Click(function(bChecked)
		TS.bForceColor = bChecked
	end):Pos_()
	
	nX = ui:Append("Text", { x = nX + 10, y = nY + 9, txt = _L["Background Alpha"] }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 11, txt = _L[" alpha"] })
	:Range(0, 100, 100):Value(TS.nBGAlpha):Change(function(nVal)
		TS.nBGAlpha = nVal
		if _TS.frame then
			_TS.bg:SetAlpha(255 * TS.nBGAlpha / 100)
		end
	end):Pos_()	
	nX = ui:Append("WndComboBox", { x = 10, y = nY, txt = _L["Style Select"] })
	:Menu(function()
		local t = {}
		for i = 1, 10 do
			table.insert(t, {
				szOption = _L("Style %d", i),
				bMCheck = true,
				bChecked = TS.nStyle == i,
				bDisable = not IsFileExist(JH.GetAddonInfo().szRootPath .. "TS/ui/style/" .. i .. ".ini"),
				fnAction = function()
					TS.nStyle = i
				end,				
			})
		end
		return t
	end):Pos_()
	nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY, txt = _L["Max Count"] })
	:Menu(function()
		local t = {}
		for k, v in ipairs({5, 10, 15, 20, 25, 30}) do
			table.insert(t, {
				szOption = v,
				bMCheck = true,
				bChecked = TS.nMaxBarCount == v,
				fnAction = function()
					TS.nMaxBarCount = v
				end,				
			})
		end
		return t
	end):Pos_()
	nX, nY = ui:Append("Text", { txt = _L["Tips"], x = 0, y = nY, font = 27 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY + 10, w = 500 , h = 20, multi = true, txt = _L["Style folder:"] .. JH.GetAddonInfo().szRootPath .. "TS/ui/style/" }):Pos_()
end

GUI.RegisterPanel(_L["ThreatScrutiny"], 2047, _L["General"], PS)

JH.RegisterEvent("LOADING_END", function()
	if not TS.bEnable then return end
	if TS.bInDungeon then
		if JH.IsInDungeon2() then
			_TS.OpenPanel()
		else
			_TS.ClosePanel()
		end
	end
	_TS.dwLockTargetID = 0
	_TS.dwTargetID = 0
	_TS.bSelfTreatRank = 0
end)

JH.AddonMenu(function()
	return {
		szOption = _L["ThreatScrutiny"], bCheck = true, bChecked = TS.bEnable, fnAction = function()
			TS.bEnable = not TS.bEnable
			if TS.bEnable then
				if TS.bInDungeon then
					if JH.IsInDungeon2() then
						_TS.OpenPanel()
					end
				else
					_TS.OpenPanel()
				end
			else
				_TS.ClosePanel()
			end
		end
	}
end)