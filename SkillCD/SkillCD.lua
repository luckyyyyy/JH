-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-10-21 13:29:28
local _L = JH.LoadLangPack

SkillCD = {
	bEnable = true,
	bSelf = false,
	bMini = true,
	bInDungeon = true,
	tAnchor = {},
	nMaxCountdown = 10,
	tMonitor = {
		[371] = true,
		[551] = true,
		[2235] = true,
		[2234] = true,
	}
}
JH.RegisterCustomData("SkillCD")

local SkillCD = SkillCD
local ipairs, pairs = ipairs, pairs
local tinsert, tsort, tremove, tconcat = table.insert, table.sort, table.remove, table.concat
local floor, min = math.floor, math.min
local GetPlayer, IsPlayer, UI_GetClientPlayerID = GetPlayer, IsPlayer, UI_GetClientPlayerID
local GetClientPlayer, GetClientTeam = GetClientPlayer, GetClientTeam
local GetLogicFrameCount, GetFormatText = GetLogicFrameCount, GetFormatText
local _SkillCD = {
	szIniFile = JH.GetAddonInfo().szRootPath .. "SkillCD/ui/SkillCD.ini",
	tCD = {},
	tIgnore = {},
}
do
	local dat = LoadLUAData(JH.GetAddonInfo().szRootPath .. "SkillCD/Skill.jx3dat")
	_SkillCD.tSkill = dat["tSkill"]
	_SkillCD.tBuffEx = dat["tBuffEx"]
	_SkillCD.tKungfu = dat["tKungfu"]
end

function SkillCD.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("SYS_MSG")
	this:RegisterEvent("BUFF_UPDATE")
	this:RegisterEvent("DO_SKILL_CAST")
	this:RegisterEvent("PARTY_DISBAND")
	this:RegisterEvent("PARTY_DELETE_MEMBER")
	this:RegisterEvent("PARTY_ADD_MEMBER")
	this:RegisterEvent("PARTY_UPDATE_MEMBER_INFO")
	this:RegisterEvent("PARTY_SET_MEMBER_ONLINE_FLAG")
	this:RegisterEvent("SKILL_MOUNT_KUNG_FU")
	this:RegisterEvent("LOADING_END")
    _SkillCD.UpdateAnchor(this)
	_SkillCD.frame = this
	_SkillCD.handle = this:Lookup("Wnd_List"):Lookup("", "")
	GUI(this):Title(_L["SkillCD"]):Fetch("Check_Minimize"):Click(function(bChecked)
		_SkillCD.SwitchPanel(bChecked)
	end):Check(SkillCD.bMini)
	this:Lookup("Btn_Setting").OnLButtonClick = function()
		JH.OpenPanel(_L["SkillCD"])
	end
	_SkillCD.UpdateMonitorCache()
	_SkillCD.UpdateCount()
end

function SkillCD.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		_SkillCD.UpdateAnchor(this)
	elseif szEvent == "SYS_MSG" then
		if arg0 == "UI_OME_SKILL_HIT_LOG" and arg3 == SKILL_EFFECT_TYPE.SKILL then
			_SkillCD.OnSkillCast(arg1, arg4, arg5, arg0)
		elseif arg0 == "UI_OME_SKILL_EFFECT_LOG" and arg4 == SKILL_EFFECT_TYPE.SKILL then
			_SkillCD.OnSkillCast(arg1, arg5, arg6, arg0)
		elseif (arg0 == "UI_OME_SKILL_BLOCK_LOG" or arg0 == "UI_OME_SKILL_SHIELD_LOG"
				or arg0 == "UI_OME_SKILL_MISS_LOG" or arg0 == "UI_OME_SKILL_DODGE_LOG")
			and arg3 == SKILL_EFFECT_TYPE.SKILL
		then
			_SkillCD.OnSkillCast(arg1, arg4, arg5, arg0)
		end
	elseif szEvent == "BUFF_UPDATE" then
		if _SkillCD.tBuffEx[arg4] and not arg1 then
			_SkillCD.OnSkillCast(arg9, _SkillCD.tBuffEx[arg4], arg8, "BUFF_UPDATE")
		end
	elseif szEvent == "DO_SKILL_CAST" then
		_SkillCD.OnSkillCast(arg0, arg1, arg2, "DO_SKILL_CAST")
	elseif szEvent == "LOADING_END" then
		_SkillCD.tCD = {}
		_SkillCD.UpdateCount()
	else
		_SkillCD.UpdateCount()
	end
end

function SkillCD.OnFrameBreathe()
	local data = {}
	-- 排序
	for k, v in pairs(_SkillCD.tCD) do
		for kk, vv in ipairs(v) do
			local nSec = _SkillCD.tSkill[vv.dwSkillID]
			local pre = min(1, JH.GetEndTime(vv.nEnd) / nSec)
			if pre > 0 then
				vv.pre = pre
				tinsert(data, vv)
			else
				tremove(_SkillCD.tCD[k], kk)
				_SkillCD.UpdateCount()
			end
		end
	end
	-- 更新倒计时条
	if SkillCD.bMini then return end
	if GetLogicFrameCount() % 4 == 0 then -- 其实也只是防止倒计时太多占用性能 ...
		local handle = _SkillCD.handle
		handle:Clear()
		tsort(data, function(a, b) return a.nEnd < b.nEnd end)
		for k, v in ipairs(data) do
			if not _SkillCD.tIgnore[v.dwSkillID] then
				local item = handle:AppendItemFromIni(_SkillCD.szIniFile, "Handle_Lister", i)
				local nSec = _SkillCD.tSkill[v.dwSkillID]
				local fP = min(1, JH.GetEndTime(v.nEnd) / nSec)
				local szSec = floor(JH.GetEndTime(v.nEnd))
				if fP < 0.15 then
					item:Lookup("Image_LPlayer"):SetFrame(215)
				end
				local txt = szSec .. _L["s"]
				if szSec > 60 then
					txt = _L("%dm%ds", szSec / 60, szSec % 60)
				end
				item:Lookup("Image_LPlayer"):SetPercentage(fP)
				item:Lookup("Text_LLife"):SetText(txt)
				item:Lookup("Text_Player"):SetText(v.szPlayer .. "_" .. v.szName)
				item:Lookup("Skill_Icon"):FromIconID(v.dwIconID)
				item:Show()
			end
		end
		handle:FormatAllItemPos()
		_SkillCD.SetUISize(handle:GetItemCount())
	end
end

function SkillCD.OnFrameDragEnd()
	this:CorrectPos()
	SkillCD.tAnchor = GetFrameAnchor(this, "TOPLEFT")
end

function _SkillCD.UpdateAnchor(frame)
	local a = SkillCD.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 450, -150)
	end
end

function _SkillCD.SwitchPanel(bMini)
	SkillCD.bMini = bMini
	if not _SkillCD.frame then
		return
	end
	if bMini then
		_SkillCD.frame:Lookup("Wnd_List"):Hide()
		_SkillCD.frame:Lookup("Wnd_Count"):SetRelPos(0, 29)
		_SkillCD.frame:Lookup("", "Image_Bg"):SetSize(240, 30)
	else
		_SkillCD.frame:Lookup("Wnd_List"):Show()
	end
end

function _SkillCD.SetUISize(nCount)
	if not SkillCD.bMinit then
		local h = min(SkillCD.nMaxCountdown * 20, nCount * 20)
		local wnd = _SkillCD.frame:Lookup("Wnd_List")
		wnd:SetH(h)
		wnd:Lookup("Scroll_List"):SetH(h)
		wnd:Lookup("", ""):SetH(h)
		_SkillCD.frame:Lookup("", "Image_Bg"):SetH(30 + h)
		_SkillCD.frame:Lookup("Wnd_Count"):SetRelPos(0, 29 + h)
	end
end

function _SkillCD.OpenPanel()
	local frame = _SkillCD.frame or Wnd.OpenWindow(_SkillCD.szIniFile, "SkillCD")
	return frame
end

function _SkillCD.ClosePanel()
	Wnd.CloseWindow(_SkillCD.frame)
	_SkillCD.frame = nil
	_SkillCD.tCD = {}
end

function _SkillCD.IsPanelOpened()
	return _SkillCD.frame and _SkillCD.frame:IsVisible()
end

function _SkillCD.OnSkillCast(dwCaster, dwSkillID, dwLevel, szEvent)
	if not SkillCD.bEnable then
		return _SkillCD.ClosePanel()
	end

	if not IsPlayer(dwCaster) then
		return
	end

	if not SkillCD.tMonitor[dwSkillID] then
		return
	end

	local nSec = _SkillCD.tSkill[dwSkillID]
	if not nSec then
		return
	end
	if SkillCD.bSelf and dwCaster ~= UI_GetClientPlayerID() then
		return
	end
	-- get name
	local p = GetPlayer(dwCaster)
	if not p then return end
	local szName, dwIconID = JH.GetSkillName(dwSkillID, dwLevel)

	if not _SkillCD.tCD[dwCaster] then
		_SkillCD.tCD[dwCaster] = {}
	end

	local nTotal = nSec * 16
	local nEnd = GetLogicFrameCount() + nTotal
	local find = false
	local data = {
		nEnd      = nEnd,
		nTotal    = nTotal,
		dwSkillID = dwSkillID,
		dwLevel   = dwLevel,
		dwIconID  = dwIconID,
		szName    = szName,
		szPlayer  = p.szName
	}
	for k, v in ipairs(_SkillCD.tCD[dwCaster]) do
		if v.dwSkillID == dwSkillID then
			_SkillCD.tCD[dwCaster][k] = data
			find = true
			break
		end
	end
	if not find then
		tinsert(_SkillCD.tCD[dwCaster], data)
	end
	_SkillCD.UpdateCount()
end

-- 生成监控列表
function _SkillCD.UpdateMonitorCache()
	local kungfu = {}
	for k, v in pairs(SkillCD.tMonitor) do
		for kk, vv in pairs(_SkillCD.tKungfu) do
			for kkk, vvv in ipairs(vv) do
				if vvv == k then
					if not kungfu[kk] then
						kungfu[kk] = {}
					end
					tinsert(kungfu[kk], k)
					break
				end
			end
		end
	end
	_SkillCD.tCache = kungfu
end

function _SkillCD.UpdateCount()
	local me, team = GetClientPlayer(), GetClientTeam()
	if not me then return end
	local tMonitor, member, tKungfu, tCount = _SkillCD.tCache, {}, {}, {}
	for k, v in pairs(SkillCD.tMonitor) do
		if _SkillCD.tSkill[k] then
			tCount[k] = {}
			tCount[k].nCount = 0
			tCount[k].tList = {}
		end
	end
	if me.IsInParty() and not SkillCD.bSelf then
		member = team.GetTeamMemberList()
	else
		tinsert(member,me.dwID)
	end
	-- 获取 id -> 心法 对应表
	for k, v in ipairs(member) do
		tKungfu[v] = {}
		if JH.IsParty(v) then
			local info = team.GetMemberInfo(v)
			tKungfu[v] = {
				bDeathFlag      = info.bDeathFlag,
				bIsOnLine       = info.bIsOnLine,
				dwMountKungfuID = info.dwMountKungfuID,
				szName          = team.GetClientTeamMemberName(v),
			}
		else
			tKungfu[v] = {
				bDeathFlag      = me.nMoveState == MOVE_STATE.ON_DEATH,
				bIsOnLine       = true,
				dwMountKungfuID = UI_GetPlayerMountKungfuID(),
				szName          = me.szName
			}
		end
	end
	for k ,v in pairs(tKungfu) do
		if tMonitor[v.dwMountKungfuID] then -- 如果心法在监控内
			for kk, vv in ipairs(tMonitor[v.dwMountKungfuID]) do
				if _SkillCD.tCD[k] then -- 如果有记录
					local find, nEnd
					for _, vvv in ipairs(_SkillCD.tCD[k]) do
						if vvv.dwSkillID == vv then
							find = true
							nEnd = vvv.nEnd
							break
						end
					end
					if not find then
						tCount[vv].nCount = tCount[vv].nCount + 1
						tinsert(tCount[vv].tList, { nSec = 0, info = v })
					else
						tinsert(tCount[vv].tList, { nSec = nEnd, info = v })
					end
				else -- 无条件
					tCount[vv].nCount = tCount[vv].nCount + 1
					tinsert(tCount[vv].tList, { nSec = 0, info = v  })
				end
			end
		end
	end
	local handle = _SkillCD.frame:Lookup("Wnd_Count"):Lookup("", "Handle_CList")
	handle:Clear()
	for k, v in pairs(tCount) do
		local item = handle:AppendItemFromIni(_SkillCD.szIniFile, "Handle_CLister", k)
		local szName, dwIconID = JH.GetSkillName(k)
		local box = item:Lookup("Box_Icon")
		tsort(v.tList, function(a, b)
			if a.nSec == b.nSec then
				return a.info.szName < a.info.szName
			else
				return a.nSec < b.nSec
			end
		end)
		if #v.tList > 0 then
			if _SkillCD.tIgnore[k] then
				box:SetObjectCoolDown(true)
				box:SetCoolDownPercentage(0)
			else
				box:SetObjectCoolDown(false)
			end
		end
		item.OnItemRefreshTip = function()
			if box:IsValid() then
				if #v.tList > 0 then
					box:SetObjectMouseOver(true)
					local x, y = box:GetAbsPos()
					local w, h = box:GetSize()
					local xml = {}
					tinsert(xml, GetFormatText("[" .. szName .. "]\n", 23 ,255 ,255 ,255))
					for k, v in ipairs(v.tList) do
						local dwMountKungfuID = v.info.dwMountKungfuID or 0
						local nIocn = select(2, JH.GetSkillName(dwMountKungfuID))
						tinsert(xml, GetFormatImage("fromiconid", nIocn, 25, 25))
						tinsert(xml, GetFormatText(v.info.szName, 23, 255, 255, 0))
						if v.info.bDeathFlag then
							tinsert(xml, GetFormatText(" (" .. g_tStrings.FIGHT_DEATH .. ")", 23, 255, 128, 0))
						elseif not v.info.bIsOnLine then
							tinsert(xml, GetFormatText(" (" .. g_tStrings.STR_FRIEND_NOT_ON_LINE .. ")", 23, 192, 192, 192))
						end
						if v.nSec == 0 then
							tinsert(xml, GetFormatText("\t" .. _L["ready"], 24, 0, 255, 0))
						else
							local szSec = floor(JH.GetEndTime(v.nSec))
							local txt = szSec .. _L["s"]
							if szSec > 60 then
								txt = _L("%dm%ds", szSec / 60, szSec % 60)
							end
							tinsert(xml, GetFormatText("\t" .. txt, 24, 255, 0, 0))
						end
					end
					OutputTip(tconcat(xml), 300, { x, y, w, h })
				end
			end
		end

		item.OnItemRButtonClick = function()
			if #v.tList > 0 then
				if _SkillCD.tIgnore[k] then
					_SkillCD.tIgnore[k] = nil
					box:SetObjectCoolDown(false)
				else
					_SkillCD.tIgnore[k] = true
					box:SetObjectCoolDown(true)
					box:SetCoolDownPercentage(0)
				end
			end
		end

		item.OnItemLButtonClick = function()
			if #v.tList > 0 then
				if me.IsInParty() then
					JH.Talk(_L("Team %s info", _L["["] .. szName .. _L["]"]))
					for k, v in ipairs(v.tList) do
						local tSay = {}
						tinsert(tSay, { type = "name", name = v.info.szName })
						if v.info.bDeathFlag then
							tinsert(tSay, { type = "text", text = " (" .. g_tStrings.FIGHT_DEATH .. ")" })
						elseif not v.info.bIsOnLine then
							tinsert(tSay, { type = "text", text = " (" .. g_tStrings.STR_FRIEND_NOT_ON_LINE .. ")" })
						end
						if v.nSec == 0 then
							tinsert(tSay, { type = "text", text = g_tStrings.STR_ONE_CHINESE_SPACE .. _L["ready"] })
						else
							local szSec = floor(JH.GetEndTime(v.nSec))
							local txt = szSec .. _L["s"]
							if szSec > 60 then
								txt = _L("%dm%ds", szSec / 60, szSec % 60)
							end
							tinsert(tSay, { type = "text", text = g_tStrings.STR_ONE_CHINESE_SPACE ..txt })
						end
						JH.Talk(tSay)
					end
				end
			end
		end
		item.OnItemMouseLeave = function()
			if box:IsValid() then
				box:SetObjectMouseOver(false)
				HideTip()
			end
		end
		box:SetObject(UI_OBJECT_NOT_NEED_KNOWN) -- 其实是技能 不过用不到
		box:SetObjectIcon(dwIconID)
		-- box:SetObjectSparking(true)
		item:Lookup("Text_Count"):SetText(v.nCount)
		if v.nCount > 0 then
			item:Lookup("Text_Count"):SetFontColor(0, 255, 0)
		else
			item:Lookup("Text_Count"):SetFontColor(255, 0, 0)
		end
		if #v.tList == 0 then
			item:SetAlpha(100)
			box:IconToGray()
			item:Lookup("Text_Count"):SetFontColor(156, 156, 156)
		end

		item:Show()
		item:FormatAllItemPos()
	end

	handle:FormatAllItemPos()
	local w, h = handle:GetAllItemSize()
	_SkillCD.frame:Lookup("Wnd_Count"):SetSize(240, h + 5)
	_SkillCD.frame:Lookup("Wnd_Count"):Lookup("", "Image_CBg"):SetSize(240, h + 5)
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["SkillCD"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = SkillCD.bEnable, txt = _L["Enable SkillCD"] }):Click(function(bChecked)
		SkillCD.bEnable = bChecked
		ui:Fetch("bSelf"):Enable(bChecked)
		ui:Fetch("bInDungeon"):Enable(bChecked)
		if bChecked then
			if SkillCD.bInDungeon then
				if JH.IsInDungeon(true) then
					_SkillCD.OpenPanel()
				end
			else
				_SkillCD.OpenPanel()
			end
		else
			_SkillCD.ClosePanel()
		end
		JH.OpenPanel(_L["SkillCD"])
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bSelf", { x = 25, y = nY, checked = SkillCD.bSelf })
	:Enable(SkillCD.bEnable):Text(_L["only Monitor self"]):Click(function(bChecked)
		SkillCD.bSelf = bChecked
		if _SkillCD.IsPanelOpened() then
			_SkillCD.UpdateCount()
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bInDungeon", { x = 25, y = nY, checked = SkillCD.bInDungeon })
	:Enable(SkillCD.bEnable):Text(_L["Only in the map type is Dungeon Enable plug-in"]):Click(function(bChecked)
		SkillCD.bInDungeon = bChecked
		if bChecked then
			if JH.IsInDungeon(true) then
				_SkillCD.OpenPanel()
			else
				_SkillCD.ClosePanel()
			end
		else
			_SkillCD.OpenPanel()
		end
		JH.OpenPanel(_L["SkillCD"])
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Countdown"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = not SkillCD.bMini, txt = _L["Show Countdown"] }):Click(function(bChecked)
		_SkillCD.SwitchPanel(not bChecked)
		ui:Fetch("nMaxCountdown"):Enable(bChecked)
	end):Pos_()
	nX, nY = ui:Append("WndComboBox", "nMaxCountdown", { x = nX + 10, y = nY + 10, txt = g_tStrings.STR_SHOW_HATRE_COUNTS })
	:Enable(not SkillCD.bMini):Menu(function()
		local t = {}
		for k, v in ipairs({3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 50}) do
			table.insert(t, {
				szOption = v,
				bMCheck = true,
				bChecked = SkillCD.nMaxCountdown == v,
				fnAction = function()
					SkillCD.nMaxCountdown = v
				end,
			})
		end
		return t
	end):Pos_()

	-- nMaxCountdown
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Monitor"], font = 27 }):Pos_()
	local i = 0
	for k, v in pairs(_SkillCD.tSkill) do
		local a = 100
		if SkillCD.tMonitor[k] then a = 255 end
		ui:Append("Box", { x = (i % 9) * 56, y = nY + floor(i / 9 ) * 55 + 15, alpha = a } ):Icon(Table_GetSkillIconID(k))
		:ToGray(not _SkillCD.IsPanelOpened()):Staring(SkillCD.tMonitor[k] or false):Hover(function(bHover)
			if bHover then
				local x, y = this:GetAbsPos()
				local w, h = this:GetSize()
				OutputSkillTip(k,1,{ x, y, w, h })
				if a == 100 then this:SetAlpha(200) end
				this:SetObjectMouseOver(true)
			else
				HideTip()
				this:SetAlpha(a)
				this:SetObjectMouseOver(false)
			end
		end):Click(function()
			if not _SkillCD.IsPanelOpened() then return end
			if SkillCD.tMonitor[k] then
				SkillCD.tMonitor[k] = nil
			else
				SkillCD.tMonitor[k] = true
			end
			_SkillCD.UpdateMonitorCache()
			_SkillCD.UpdateCount()
			JH.OpenPanel(_L["SkillCD"])
		end)
		i = i + 1
	end
end
GUI.RegisterPanel(_L["SkillCD"], 889, _L["Dungeon"], PS)

JH.RegisterEvent("LOADING_END", function()
	if not SkillCD.bEnable then return end
	if SkillCD.bInDungeon then
		if JH.IsInDungeon(true) then
			_SkillCD.OpenPanel()
		else
			_SkillCD.ClosePanel()
		end
	else
		_SkillCD.OpenPanel()
	end
end)

JH.AddonMenu(function()
	return {
		szOption = _L["SkillCD"], bCheck = true, bChecked = type(_SkillCD.frame) ~= "nil", fnAction = function()
			SkillCD.bInDungeon = false
			if  type(_SkillCD.frame) == "nil" then
				SkillCD.bEnable = true
				_SkillCD.OpenPanel()
			else
				SkillCD.bEnable = false
				_SkillCD.ClosePanel()
			end
		end
	}
end)


