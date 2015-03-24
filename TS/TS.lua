-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-03-25 07:39:19
local _L = JH.LoadLangPack

TS = {
	bEnable = true, -- 开启
	bInDungeon = false, -- 只有副本内才开启
	nBGAlpha = 30, -- 背景透明度
	nMaxBarCount = 7, -- 最大列表
	bForceColor = false, --根据门派着色
	bForceIcon = true, -- 显示门派图标 团队时显示心法
	nOTAlertLevel = 1, -- OT提醒
	bOTAlertSound = true, -- OT 播放声音
	bSpecialSelf = true, -- 特殊颜色显示自己
	bTopTarget = true, -- 置顶当前目标
	tAnchor = {},
	nStyle = 2,
}
JH.RegisterCustomData("TS")

local TS = TS
local ipairs, pairs = ipairs, pairs
local GetPlayer, GetNpc, IsPlayer, ApplyCharacterThreatRankList = GetPlayer, GetNpc, IsPlayer, ApplyCharacterThreatRankList
local GetClientPlayer, GetClientTeam = GetClientPlayer, GetClientTeam
local UI_GetClientPlayerID, GetTime = UI_GetClientPlayerID, GetTime
local MY_Recount_GetData
local HATRED_COLLECT = g_tStrings.HATRED_COLLECT
local HasBuff, GetBuffName, GetEndTime = JH.HasBuff, JH.GetBuffName, JH.GetEndTime
local GetNpcIntensity = GetNpcIntensity

local _TS = {
	tStyle = LoadLUAData(JH.GetAddonInfo().szRootPath .. "TS/ui/style.jx3dat"),
	szIniFile = JH.GetAddonInfo().szRootPath .. "TS/ui/TS.ini",
	dwTargetID = 0,
	dwLockTargetID = 0,
	bSelfTreatRank = 0,
	dwDropTargetPlayerID = 0,
	DPS_TIME  = 0,
	DPS_TOTAL = 0
}
function _TS.OpenPanel()
	local frame = _TS.frame or Wnd.OpenWindow(_TS.szIniFile, "TS")
	local dwID, dwType = Target_GetTargetData()
	if dwType ~= TARGET.NPC then
		frame:Hide()
	end
	return frame
end

function _TS.ClosePanel()
	Wnd.CloseWindow(_TS.frame)
	JH.UnBreatheCall("TS")
	JH.UnBreatheCall("TS_DPS")
	-- 释放变量
	_TS.frame = nil
	_TS.bg = nil
	_TS.handle = nil
	_TS.txt = nil
	_TS.CastBar = nil
	_TS.Life = nil
	_TS.dwLockTargetID = 0
	_TS.dwTargetID = 0
	_TS.bSelfTreatRank = 0
	_TS.dwDropTargetPlayerID = 0
	_TS.DPS_TIME  = 0
	_TS.DPS_TOTAL = 0
end

function TS.OnFrameCreate()
	this:RegisterEvent("CHARACTER_THREAT_RANKLIST")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("TARGET_CHANGE")
	this:RegisterEvent("FIGHT_HINT")
	this:RegisterEvent("MY_FIGHT_HINT")

	_TS.UpdateAnchor(this)
	_TS.frame = this
	_TS.bg = this:Lookup("", "Image_Background")
	_TS.bg:SetAlpha(255 * TS.nBGAlpha / 100)
	_TS.handle = this:Lookup("", "Handle_List")
	_TS.txt = this:Lookup("","Handle_TargetInfo"):Lookup("Text_Name")
	_TS.CastBar = this:Lookup("","Handle_TargetInfo"):Lookup("Image_Cast_Bar")
	_TS.Life = this:Lookup("","Handle_TargetInfo"):Lookup("Image_Life")
	local ui = GUI(this)
	ui:Title(g_tStrings.HATRED_COLLECT):Fetch("CheckBox_ScrutinyLock"):Click(function(bChecked)
		local dwID, dwType = Target_GetTargetData()
		if bChecked then
			_TS.dwLockTargetID = _TS.dwTargetID
		else
			_TS.dwLockTargetID = 0
			if dwID then
				_TS.dwTargetID = dwID
			else
				_TS.UnBreathe()
			end
		end
	end)
	ui:Fetch("Btn_Setting"):Click(function()
		JH.OpenPanel(g_tStrings.HATRED_COLLECT)
	end)
	TS.OnEvent("TARGET_CHANGE")
	if not MY_Recount_GetData and MY_Recount and MY_Recount.Data and MY_Recount.Data.Get then
		MY_Recount_GetData = MY_Recount.Data.Get
	end
end

function TS.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		_TS.UpdateAnchor(this)
	elseif szEvent == "TARGET_CHANGE" then
		local dwID, dwType = Target_GetTargetData()
		local dwTargetID
		-- check tar
		if dwType == TARGET.NPC or GetNpc(_TS.dwLockTargetID) then
			if GetNpc(_TS.dwLockTargetID) then
				dwTargetID = _TS.dwLockTargetID
			else
				dwTargetID = dwID
			end
		elseif dwType == TARGET.PLAYER and GetPlayer(dwID) then
			local tdwTpye, tdwID = GetPlayer(dwID).GetTarget()
			if tdwTpye == TARGET.NPC then
				dwTargetID = tdwID
			end
		end
		-- so ...
		if dwTargetID then
			_TS.dwTargetID = dwTargetID
			_TS.frame.nCount = 0
			JH.BreatheCall("TS", _TS.OnBreathe)
			JH.BreatheCall("TS_DPS", _TS.OnDpsBreathe, 2000)
			this:Show()
		else
			_TS.UnBreathe()
		end
	elseif szEvent == "CHARACTER_THREAT_RANKLIST" then
		if arg0 == _TS.dwTargetID then
			_TS.UpdateThreatBars(arg1, arg2, arg0)
		end
	elseif szEvent == "FIGHT_HINT" then
		if not arg0 then
			_TS.dwDropTargetPlayerID = GetTime()
		end
	elseif szEvent == "MY_FIGHT_HINT" then
		if not arg0 then
			_TS.DPS_TIME  = 0
			_TS.DPS_TOTAL = 0
			_TS.frame:Lookup("", "Text_Title").szText = ""
		end
	end
end

function TS.OnFrameDragEnd()
	this:CorrectPos()
	TS.tAnchor = GetFrameAnchor(this)
end

function _TS.OnDpsBreathe()
	-- DPS统计 需要茗伊插件
	if MY_Recount_GetData then
		local me = GetClientPlayer()
		if not me then return end
		if me.bFightState then
			local dps = MY_Recount_GetData(0)
			local nTotalEffect = 0
			for k, v in pairs(dps["Damage"]) do
				nTotalEffect = nTotalEffect + v["nTotalEffect"]
			end
			local nTime  = GetTime() - _TS.DPS_TIME
			if _TS.DPS_TIME ~= 0 then
				local nTotal = nTotalEffect - _TS.DPS_TOTAL
				local nTime  = GetTime() - _TS.DPS_TIME
				local nDps   = math.ceil(nTotal / (nTime / 1000))
				_TS.frame:Lookup("", "Text_Title").szText = string.format(" - DPS:%.1fw", nDps / 10000)
				-- debug 方便我调试
				if JH.bDebug then
					JH.Debug(string.format("Total DPS:%.1fw", nDps / 10000))
					local KTarget, KdwType = JH.GetTarget()
					if KdwType == TARGET.NPC and nDps > 0 then
						JH.Debug(string.format("Kill:%d(s)", KTarget.nCurrentLife / nDps))
					end
				end
			end
			_TS.DPS_TIME  = GetTime()
			_TS.DPS_TOTAL = nTotalEffect
		end
	end
end

function _TS.OnBreathe()
	local p = GetNpc(_TS.dwTargetID)
	if p then
		-- 官方的代码 直接抄
		local frame = _TS.frame
		if not frame.nCount or frame.nCount > 16 then
			frame.nCount = 0
			ApplyCharacterThreatRankList(_TS.dwTargetID)
		end
		frame.nCount = frame.nCount + 1

		local bIsPrepare, dwSkillID, dwSkillLevel, per = p.GetSkillPrepareState()
		if bIsPrepare then
			_TS.CastBar:Show()
			_TS.CastBar:SetPercentage(per)
			local szName = JH.GetSkillName(dwSkillID, dwSkillLevel)
			_TS.txt:SetText(szName)
		else
			local lifeper = p.nCurrentLife / p.nMaxLife
			_TS.CastBar:Hide()
			_TS.txt:SetText(JH.GetTemplateName(p) .. string.format(" (%0.1f%%)", lifeper * 100))
			_TS.Life:SetPercentage(lifeper)
		end

		-- 无威胁提醒
		local bExist, tBuff = HasBuff({ 917, 4487, 926, 775, 4101, 8422 })
		local hText = _TS.frame:Lookup("", "Text_Title")
		local szText = hText.szText or ""
		if bExist then
			local szName = GetBuffName(tBuff.dwID, tBuff.nLevel)
			hText:SetText(string.format("%s (%ds)", szName, math.floor(GetEndTime(tBuff.nEndFrame))) .. szText)
			hText:SetFontColor(0, 255, 0)
		else
			hText:SetText(HATRED_COLLECT .. szText)
			hText:SetFontColor(255, 255, 255)
			hText.bBuff = nil
		end

		-- 开怪提醒
		if _TS.dwDropTargetPlayerID >= 0 and GetTime() - _TS.dwDropTargetPlayerID > 1000 * 7 and GetNpcIntensity(p) > 2 then
			local me = GetClientPlayer()
			if not me.bFightState then return end
			_TS.dwDropTargetPlayerID = -1
			JH.DelayCall(1000, function()
				if not me.IsInParty() then return end
				if p and p.dwDropTargetPlayerID and p.dwDropTargetPlayerID ~= 0 then
					if IsParty(me.dwID, p.dwDropTargetPlayerID) or me.dwID == p.dwDropTargetPlayerID then
						local team = GetClientTeam()
						local szMember = team.GetClientTeamMemberName(p.dwDropTargetPlayerID)
						local nGroup = team.GetMemberGroupIndex(p.dwDropTargetPlayerID) + 1
						local name = JH.GetTemplateName(p)
						JH.Sysmsg2(_L("Well done! %s in %d group first to attack %s!!", nGroup, szMember, name), g_tStrings.HATRED_COLLECT, { 150, 250, 230 })
					end
				end
			end)
		end
	else
		_TS.frame:Hide()
	end
end

function _TS.UnBreathe()
	JH.UnBreatheCall("TS")
	_TS.frame:Hide()
	_TS.dwTargetID = 0
	_TS.handle:Clear()
	_TS.bg:SetSize(240, 55)
	_TS.txt:SetText(_L["Loading..."])
	_TS.Life:SetPercentage(0)
	-- 取消DPS的统计
	JH.UnBreatheCall("TS_DPS")
	_TS.DPS_TIME  = 0
	_TS.DPS_TOTAL = 0
	_TS.frame:Lookup("", "Text_Title").szText = ""
end

function _TS.UpdateAnchor(frame)
	local a = TS.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("TOPRIGHT", -300, 300, "TOPRIGHT", 0, 0)
	end
	this:CorrectPos()
end

-- 有几个问题
-- 1) 当前目标 结果反馈的是0仇恨 BUG了 fixed
-- 2) 反馈的目标是错误的 也BUG了 fixed
-- 3) 因为是异步 反馈时目标已经更新 也需要同时更新 fixed
-- 4) 反馈的列表中不存在当前目标 fixed
function _TS.UpdateThreatBars(tList, dwTargetID, dwApplyID)
	local team = GetClientTeam()
	local tThreat, nTopRank, nMyRank = {}, 65535, 0
	-- 修复arg2反馈不准 当前目标才修复 非当前目标也不准。。
	local dwID, dwType = Target_GetTargetData()
	if dwID == dwApplyID and dwType == TARGET.NPC then
		local p = GetNpc(dwApplyID)
		if p then
			local _, tdwID = p.GetTarget()
			if tdwID and tdwID ~= 0 and tdwID ~= dwTargetID and tList[tdwID] then -- 原来是0 搞半天。。
				dwTargetID = tdwID
			end
		end
	end
	-- 重构用于排序
	for k, v in pairs(tList) do
		if dwTargetID == k then
			if v ~= 0 then -- 1仇永远不能是0
				nTopRank = v
			end
			table.insert(tThreat, 1, { id = k, val = nTopRank })
		else
			table.insert(tThreat, { id = k, val = v })
		end
		if k == UI_GetClientPlayerID() then
			nMyRank = v
		end
	end

	_TS.bg:SetSize(240, 55 + 24 * math.min(#tThreat, TS.nMaxBarCount))
	_TS.handle:SetSize(240, 24 * math.min(#tThreat, TS.nMaxBarCount))
	_TS.handle:Clear()
	local KGnpc = GetNpc(dwApplyID)
	if #tThreat > 0 and KGnpc then
		this:Show()
		if #tThreat >= 2 then
			if TS.bTopTarget and tList[dwTargetID] then
				local _t = tThreat[1]
				table.remove(tThreat, 1)
				table.sort(tThreat, function(a, b) return a.val > b.val end)
				table.insert(tThreat, 1, _t)
			else
				table.sort(tThreat, function(a, b) return a.val > b.val end)
			end
		end
		-- 我就说 这坑爹的 血战测出来的bug
		if not tList[dwTargetID] then
			nTopRank = tThreat[1].val
		end
		local dat = _TS.tStyle[TS.nStyle] or _TS.tStyle[1]
		local show = false
		for k, v in ipairs(tThreat) do
			if k > TS.nMaxBarCount then break end
			if UI_GetClientPlayerID() == v.id then
				if TS.nOTAlertLevel > 0 and GetNpcIntensity(KGnpc) > 2 then
					if _TS.bSelfTreatRank < TS.nOTAlertLevel and v.val / nTopRank >= TS.nOTAlertLevel then
						OutputMessage("MSG_ANNOUNCE_YELLOW", _L("** You Threat more than %.1f, 120% is Out of Taunt! **", TS.nOTAlertLevel * 100))
						if TS.bOTAlertSound then
							PlaySound(SOUND.UI_SOUND, _L["SOUND_nat_view2"])
						end
					end
				end
				_TS.bSelfTreatRank = v.val / nTopRank
				show = true
			elseif k == TS.nMaxBarCount and not show and tList[UI_GetClientPlayerID()] then -- 始终显示自己的
				v.id, v.val = UI_GetClientPlayerID(), nMyRank
			end

			local item = _TS.handle:AppendItemFromIni(JH.GetAddonInfo().szRootPath .. "TS/ui/Handle_ThreatBar.ini", "Handle_ThreatBar", k)
			local nThreatPercentage, fDiff = 0, 0
			if v.val ~= 0 then
				fDiff = v.val / nTopRank
				nThreatPercentage = fDiff * (100 / 120)
				item:Lookup("Text_ThreatValue"):SetText(math.floor(100 * fDiff) .. "%")
			else
				item:Lookup("Text_ThreatValue"):SetText("0%")
			end
			item:Lookup("Text_ThreatValue"):SetFontScheme(dat[6][2])

			if v.id == dwTargetID then
				if dwTargetID == UI_GetClientPlayerID() then
					item:Lookup("Image_Target"):SetFrame(10)
				end
				item:Lookup("Image_Target"):Show()
			end

			local r, g, b = 188, 188, 188
			local szName, dwForceID = _L["Loading..."], 0
			if IsPlayer(v.id) then
				local p = GetPlayer(v.id)
				if p then
					if TS.bForceColor then
						r, g, b = JH.GetForceColor(p.dwForceID)
					else
						r, g, b = 255, 255, 255
					end
					dwForceID = p.dwForceID
					szName = p.szName
				end
			else
				local p = GetNpc(v.id)
				if p then
					szName = JH.GetTemplateName(p)
				end
			end
			item:Lookup("Text_ThreatName"):SetText(szName)
			item:Lookup("Text_ThreatName"):SetFontScheme(dat[6][1])
			item:Lookup("Text_ThreatName"):SetFontColor(r, g, b)
			if TS.bForceIcon then
				if JH.IsParty(v.id) and IsPlayer(v.id) then
					local dwMountKungfuID =	team.GetMemberInfo(v.id).dwMountKungfuID
					item:Lookup("Image_Icon"):FromIconID(Table_GetSkillIconID(dwMountKungfuID, 1))
				elseif IsPlayer(v.id) then
					item:Lookup("Image_Icon"):FromUITex(GetForceImage(dwForceID))
				else
					item:Lookup("Image_Icon"):FromUITex("ui/Image/TargetPanel/Target.uitex", 57)
				end
				item:Lookup("Text_ThreatName"):SetRelPos(21, 4)
				item:FormatAllItemPos()
			end
			if fDiff > 1 then
				item:Lookup("Image_Treat_Bar"):FromUITex(unpack(dat[4]))
				item:Lookup("Text_ThreatName"):SetFontColor(255, 255, 255) --红色的 无论如何都显示白了 否则看不清
			elseif fDiff >= 0.80 then
				item:Lookup("Image_Treat_Bar"):FromUITex(unpack(dat[3]))
			elseif fDiff >= 0.50 then
				item:Lookup("Image_Treat_Bar"):FromUITex(unpack(dat[2]))
			elseif fDiff >= 0.01 then
				item:Lookup("Image_Treat_Bar"):FromUITex(unpack(dat[1]))
			end
			if TS.bSpecialSelf and v.id == UI_GetClientPlayerID() then
				item:Lookup("Image_Treat_Bar"):FromUITex(unpack(dat[5]))
			end
			item:Lookup("Image_Treat_Bar"):SetPercentage(nThreatPercentage)
			item:Show()
		end
		_TS.handle:FormatAllItemPos()
	-- else
		-- this:Hide()
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.HATRED_COLLECT, font = 27 }):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = TS.bEnable, txt = _L["Enable ThreatScrutiny"] }):Click(function(bChecked)
		TS.bEnable = bChecked
		ui:Fetch("bInDungeon"):Enable(bChecked)
		if bChecked then
			if TS.bInDungeon then
				if JH.IsInDungeon(true) then
					_TS.OpenPanel()
				end
			else
				_TS.OpenPanel()
			end
		else
			_TS.ClosePanel()
		end
		JH.OpenPanel(g_tStrings.HATRED_COLLECT)
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", "bInDungeon", { x = 25, y = nY, checked = TS.bInDungeon })
	:Enable(TS.bEnable):Text(_L["Only in the map type is Dungeon Enable plug-in"]):Click(function(bChecked)
		TS.bInDungeon = bChecked
		if bChecked then
			if JH.IsInDungeon(true) then
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

	nX, nY = ui:Append("WndCheckBox", { x = 10 , y = nY + 10, checked = TS.bTopTarget, txt = _L["Top Target"] })
	:Click(function(bChecked)
		TS.bTopTarget = bChecked
	end):Pos_()

	nX, nY = ui:Append("WndCheckBox", { x = 10 , y = nY, checked = TS.bForceColor, txt = g_tStrings.STR_RAID_COLOR_NAME_SCHOOL })
	:Click(function(bChecked)
		TS.bForceColor = bChecked
	end):Pos_()

	nX, nY = ui:Append("WndCheckBox", { x = 10 , y = nY, checked = TS.bForceIcon, txt = g_tStrings.STR_SHOW_KUNGFU })
	:Click(function(bChecked)
		TS.bForceIcon = bChecked
	end):Pos_()

	nX, nY = ui:Append("WndCheckBox", { x = 10 , y = nY, checked = TS.bSpecialSelf, txt = _L["Special Self"] })
	:Click(function(bChecked)
		TS.bSpecialSelf = bChecked
	end):Pos_()

	nX = ui:Append("WndComboBox", { x = 10, y = nY, txt = _L["Style Select"] })
	:Menu(function()
		local t = {}
		for k, v in ipairs(_TS.tStyle) do
			table.insert(t, {
				szOption = _L("Style %d", k),
				bMCheck = true,
				bChecked = TS.nStyle == k,
				fnAction = function()
					TS.nStyle = k
				end,
			})
		end

		return t
	end):Pos_()
	nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY, txt = g_tStrings.STR_SHOW_HATRE_COUNTS })
	:Menu(function()
		local t = {}
		for k, v in ipairs({2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 50}) do -- 其实服务器最大反馈不到50个
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
	nX = ui:Append("Text", { x = 10, y = nY - 1, txt = g_tStrings.STR_RAID_MENU_BG_ALPHA }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = _L[" alpha"] })
	:Range(0, 100, 100):Value(TS.nBGAlpha):Change(function(nVal)
		TS.nBGAlpha = nVal
		if _TS.frame then
			_TS.bg:SetAlpha(255 * TS.nBGAlpha / 100)
		end
	end):Pos_()

	nX, nY = ui:Append("Text", { txt = _L["Tips"], x = 0, y = nY, font = 27 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY + 10, w = 500 , h = 20, multi = true, txt = _L["Style folder:"] .. JH.GetAddonInfo().szRootPath .. "TS/ui/style.jx3dat" }):Pos_()
end

GUI.RegisterPanel(g_tStrings.HATRED_COLLECT, 2047, _L["General"], PS)

JH.RegisterEvent("LOADING_END", function()
	if not TS.bEnable then return end
	if TS.bInDungeon then
		if JH.IsInDungeon(true) then
			_TS.OpenPanel()
		else
			_TS.ClosePanel()
		end
	else
		_TS.OpenPanel()
	end
	_TS.dwLockTargetID = 0
	_TS.dwTargetID = 0
	_TS.bSelfTreatRank = 0
	_TS.dwDropTargetPlayerID = 0
end)

JH.AddonMenu(function()
	return {
		szOption = g_tStrings.HATRED_COLLECT, bCheck = true, bChecked = type(_TS.frame) ~= "nil", fnAction = function()
			TS.bInDungeon = false
			if type(_TS.frame) == "nil" then -- 这样才对嘛  按按钮应该强制开启和关闭
				TS.bEnable = true
				_TS.OpenPanel()
			else
				TS.bEnable = false
				_TS.ClosePanel()
			end
		end
	}
end)
