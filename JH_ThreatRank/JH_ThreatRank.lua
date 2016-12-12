-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2016-12-13 01:03:53
local _L = JH.LoadLangPack

TS = {
	bEnable       = true,  -- 开启
	bInDungeon    = true, -- 只有副本内才开启
	nBGAlpha      = 30,    -- 背景透明度
	nMaxBarCount  = 7,     -- 最大列表
	bForceColor   = false, -- 根据门派着色
	bForceIcon    = true,  -- 显示门派图标 团队时显示心法
	nOTAlertLevel = 1,     -- OT提醒
	bOTAlertSound = true,  -- OT 播放声音
	bSpecialSelf  = true,  -- 特殊颜色显示自己
	bTopTarget    = true,  -- 置顶当前目标
	tAnchor       = {},
	nStyle        = 2,
}
JH.RegisterCustomData("TS")

local TS = TS
local ipairs, pairs = ipairs, pairs
local GetPlayer, GetNpc, IsPlayer, ApplyCharacterThreatRankList = GetPlayer, GetNpc, IsPlayer, ApplyCharacterThreatRankList
local GetClientPlayer, GetClientTeam = GetClientPlayer, GetClientTeam
local UI_GetClientPlayerID, GetTime = UI_GetClientPlayerID, GetTime
local HATRED_COLLECT = g_tStrings.HATRED_COLLECT
local GetBuff, GetBuffName, GetEndTime, GetObjName, GetForceColor =
	  JH.GetBuff, JH.GetBuffName, JH.GetEndTime, JH.GetTemplateName, JH.GetForceColor
local GetNpcIntensity = GetNpcIntensity
local GetTime = GetTime

local TS_INIFILE = JH.GetAddonInfo().szRootPath .. "JH_ThreatRank/ui/JH_ThreatRank.ini"

local _TS = {
	tStyle = LoadLUAData(JH.GetAddonInfo().szRootPath .. "JH_ThreatRank/ui/style.jx3dat"),
}

function TS.OnFrameCreate()
	this:RegisterEvent("CHARACTER_THREAT_RANKLIST")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("TARGET_CHANGE")
	this:RegisterEvent("FIGHT_HINT")
	this:RegisterEvent("LOADING_END")
	this.hItemData      = this:CreateItemData(JH.GetAddonInfo().szRootPath .. "JH_ThreatRank/ui/Handle_ThreatBar.ini", "Handle_ThreatBar")
	this.dwTargetID     = 0
	this.nTime          = 0
	this.bSelfTreatRank = 0
	this.bg         = this:Lookup("", "Image_Background")
	this.bg:SetAlpha(255 * TS.nBGAlpha / 100)
	this.handle     = this:Lookup("", "Handle_List")
	this.txt        = this:Lookup("", "Handle_TargetInfo"):Lookup("Text_Name")
	this.CastBar    = this:Lookup("", "Handle_TargetInfo"):Lookup("Image_Cast_Bar")
	this.Life       = this:Lookup("", "Handle_TargetInfo"):Lookup("Image_Life")
	this:Lookup("", "Text_Title"):SetText(g_tStrings.HATRED_COLLECT)
	_TS.UpdateAnchor(this)
	TS.OnEvent("TARGET_CHANGE")
end

function TS.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		_TS.UpdateAnchor(this)
	elseif szEvent == "TARGET_CHANGE" then
		local dwType, dwID = Target_GetTargetData()
		local dwTargetID
		-- check tar
		if dwType == TARGET.NPC or GetNpc(this.dwLockTargetID) then
			if GetNpc(this.dwLockTargetID) then
				dwTargetID = this.dwLockTargetID
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
			this.dwTargetID = dwTargetID
			this:Show()
		else
			_TS.UnBreathe()
		end
	elseif szEvent == "CHARACTER_THREAT_RANKLIST" then
		if arg0 == this.dwTargetID then
			_TS.UpdateThreatBars(arg1, arg2, arg0)
		end
	elseif szEvent == "FIGHT_HINT" then
		if not arg0 then
			this.nTime = GetTime()
		end
	elseif szEvent == "LOADING_END" then
		this.dwTargetID     = 0
		this.nTime          = 0
		this.bSelfTreatRank = 0
	end
end

function TS.OnFrameBreathe()
	local p = GetNpc(this.dwTargetID)
	if p then
		ApplyCharacterThreatRankList(this.dwTargetID)
		local bIsPrepare, dwSkillID, dwSkillLevel, per = p.GetSkillPrepareState()
		if bIsPrepare then
			this.CastBar:Show()
			this.CastBar:SetPercentage(per)
			local szName = JH.GetSkillName(dwSkillID, dwSkillLevel)
			this.txt:SetText(szName)
		else
			local lifeper = p.nCurrentLife / p.nMaxLife
			this.CastBar:Hide()
			this.txt:SetText(GetObjName(p, true) .. string.format(" (%0.1f%%)", lifeper * 100))
			this.Life:SetPercentage(lifeper)
		end

		-- 无威胁提醒
		local KBuff = GetBuff({
			[917]  = 0,
			[4487] = 0,
			[926]  = 0,
			[775]  = 0,
			[4101] = 0,
			[8422] = 0
		})
		local hText = this:Lookup("", "Text_Title")
		local szText = hText.szText or ""
		if KBuff then
			local szName = GetBuffName(KBuff.dwID, KBuff.nLevel)
			hText:SetText(string.format("%s (%ds)", szName, math.floor(GetEndTime(KBuff.GetEndTime()))) .. szText)
			hText:SetFontColor(0, 255, 0)
		else
			hText:SetText(HATRED_COLLECT .. szText)
			hText:SetFontColor(255, 255, 255)
			hText.bBuff = nil
		end

		-- 开怪提醒
		if this.nTime >= 0 and GetTime() - this.nTime > 1000 * 7 and GetNpcIntensity(p) > 2 then
			local me = GetClientPlayer()
			if not me.bFightState then return end
			this.nTime = -1
			JH.DelayCall(function()
				if not me.IsInParty() then return end
				if p and p.dwDropTargetPlayerID and p.dwDropTargetPlayerID ~= 0 then
					if IsParty(me.dwID, p.dwDropTargetPlayerID) or me.dwID == p.dwDropTargetPlayerID then
						local team = GetClientTeam()
						local szMember = team.GetClientTeamMemberName(p.dwDropTargetPlayerID)
						local nGroup = team.GetMemberGroupIndex(p.dwDropTargetPlayerID) + 1
						local name = GetObjName(p)
						JH.Sysmsg2(_L("Well done! %s in %d group first to attack %s!!", nGroup, szMember, name), g_tStrings.HATRED_COLLECT, { 150, 250, 230 })
					end
				end
			end, 1000)
		end
	else
		this:Hide()
	end
end

function TS.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Setting" then
		JH.OpenPanel(g_tStrings.HATRED_COLLECT)
	end
end

function TS.OnCheckBoxCheck()
	local szName = this:GetName()
	if szName == "CheckBox_ScrutinyLock" then
		local dwType, dwID = Target_GetTargetData()
		local frame = this:GetRoot()
		frame.dwLockTargetID = frame.dwTargetID
	end
end

function TS.OnCheckBoxUncheck()
	local szName = this:GetName()
	if szName == "CheckBox_ScrutinyLock" then
		local dwType, dwID = Target_GetTargetData()
		local frame = this:GetRoot()
		frame.dwLockTargetID = 0
		if dwID then
			frame.dwTargetID = dwID
		else
			_TS.UnBreathe()
		end
	end
end

function TS.OnFrameDragEnd()
	this:CorrectPos()
	TS.tAnchor = GetFrameAnchor(this)
end

function _TS.GetFrame()
	return Station.Lookup("Normal/TS")
end

function _TS.CheckOpen()
	if TS.bEnable then
		if TS.bInDungeon then
			if JH.IsInDungeon(true) then
				_TS.OpenPanel()
			else
				_TS.ClosePanel()
			end
		else
			_TS.OpenPanel()
		end
	else
		_TS.ClosePanel()
	end
end

function _TS.OpenPanel()
	local frame = _TS.GetFrame()
	if not frame then
		frame = Wnd.OpenWindow(TS_INIFILE, "TS")
		local dwType = Target_GetTargetData()
		if dwType ~= TARGET.NPC then
			frame:Hide()
		end
	end
	return frame
end

function _TS.ClosePanel()
	if _TS.GetFrame() then
		Wnd.CloseWindow(_TS.GetFrame())
	end
end

function _TS.UnBreathe()
	local frame = _TS.GetFrame()
	frame:Hide()
	frame.dwTargetID = 0
	frame.handle:Clear()
	frame.bg:SetSize(240, 55)
	frame.txt:SetText(_L["Loading..."])
	frame.Life:SetPercentage(0)
	frame:Lookup("", "Text_Title").szText = ""
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
	local tThreat, tRank, tMyRank, nTopRank = {}, {}, {}, 1
	-- 修复arg2反馈不准 当前目标才修复 非当前目标也不准。。
	local dwType, dwID = Target_GetTargetData()
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
		table.insert(tThreat, { id = k, val = v })
	end
	table.sort(tThreat, function(a, b) return a.val > b.val end) -- 进行排序
	for k, v in ipairs(tThreat) do
		v.sort = k
		if v.id == UI_GetClientPlayerID() then
			tMyRank = v
		end
	end
	this.bg:SetH(55 + 24 * math.min(#tThreat, TS.nMaxBarCount))
	this.handle:Clear()
	local KGnpc = GetNpc(dwApplyID)
	if #tThreat > 0 and KGnpc then
		this:Show()
		if #tThreat >= 2 then
			if TS.bTopTarget and tList[dwTargetID] then
				for k, v in ipairs(tThreat) do
					if v.id == dwTargetID then
						table.insert(tThreat, 1, table.remove(tThreat, k))
						break
					end
				end
			end
		end

		if tThreat[1].val ~= 0 then
			nTopRank = tThreat[1].val
		else
			tThreat[1].val = nTopRank -- 修正一些无仇恨的技能，这样单人会显示0%，很不好看。
		end

		local dat = _TS.tStyle[TS.nStyle] or _TS.tStyle[1]
		local show = false
		for k, v in ipairs(tThreat) do
			if k > TS.nMaxBarCount then break end
			if UI_GetClientPlayerID() == v.id then
				if TS.nOTAlertLevel > 0 and GetNpcIntensity(KGnpc) > 2 then
					if this.bSelfTreatRank < TS.nOTAlertLevel and v.val / nTopRank >= TS.nOTAlertLevel then
						JH.Topmsg(_L("** You Threat more than %d, 120% is Out of Taunt! **", TS.nOTAlertLevel * 100))
						if TS.bOTAlertSound then
							PlaySound(SOUND.UI_SOUND, _L["SOUND_nat_view2"])
						end
					end
				end
				this.bSelfTreatRank = v.val / nTopRank
				show = true
			elseif k == TS.nMaxBarCount and not show and tList[UI_GetClientPlayerID()] then -- 始终显示自己的
				v = tMyRank
			end

			local item = this.handle:AppendItemFromData(this.hItemData, k)
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
					dwForceID = p.dwForceID
					szName    = p.szName
				else
					if MY_Farbnamen and MY_Farbnamen.Get then
						local data = MY_Farbnamen.Get(v.id)
						if data then
							szName    = data.szName
							dwForceID = data.dwForceID
						end
					end
				end
				if TS.bForceColor then
					r, g, b = GetForceColor(p.dwForceID)
				else
					r, g, b = 255, 255, 255
				end
			else
				local p = GetNpc(v.id)
				if p then
					szName = JH.GetTemplateName(p, true)
					if tonumber(szName) then
						szName = v.id
					end
				end
			end
			item:Lookup("Text_ThreatName"):SetText(v.sort .. "." .. szName)
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
		this.handle:FormatAllItemPos()
		this.handle:SetSizeByAllItemSize()
	-- else
		-- this:Hide()
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.HATRED_COLLECT, font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = TS.bEnable, txt = _L["Enable ThreatScrutiny"] }):Click(function(bChecked)
		TS.bEnable = bChecked
		ui:Fetch("bInDungeon"):Enable(bChecked)
		_TS.CheckOpen()
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", "bInDungeon", { x = 25, y = nY, checked = TS.bInDungeon })
	:Enable(TS.bEnable):Text(_L["Only in the map type is Dungeon Enable plug-in"]):Click(function(bChecked)
		TS.bInDungeon = bChecked
		_TS.CheckOpen()
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
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = "" })
	:Range(0, 100, 100):Value(TS.nBGAlpha):Change(function(nVal)
		TS.nBGAlpha = nVal
		local frame = _TS.GetFrame()
		if frame then
			frame.bg:SetAlpha(255 * TS.nBGAlpha / 100)
		end
	end):Pos_()
end

GUI.RegisterPanel(g_tStrings.HATRED_COLLECT, 632, g_tStrings.CHANNEL_CHANNEL, PS)
JH.RegisterEvent("LOADING_END", _TS.CheckOpen)
JH.AddonMenu(function()
	return {
		szOption = g_tStrings.HATRED_COLLECT, bCheck = true, bChecked = _TS.GetFrame(), fnAction = function()
			TS.bInDungeon = false
			if not _TS.GetFrame() then -- 这样才对嘛  按按钮应该强制开启和关闭
				TS.bEnable = true
			else
				TS.bEnable = false
			end
			_TS.CheckOpen()
		end
	}
end)
