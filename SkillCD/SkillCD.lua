local _L = JH.LoadLangPack

SkillCD = {
	bEnable = true,
	bSelf = false,
	bMini = true,
	bInDungeon = true,
	tAnchor = {},
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
local tinsert, tsort, tremove = table.insert, table.sort, table.remove
local floor, min = math.floor, math.min
local GetPlayer, IsPlayer, UI_GetClientPlayerID = GetPlayer, IsPlayer, UI_GetClientPlayerID
local GetClientPlayer, GetClientTeam = GetClientPlayer, GetClientTeam

local _SkillCD = {
	szIniFile = JH.GetAddonInfo().szRootPath .. "SkillCD/ui/SkillCD.ini",
	tCD = {},
}
do
	local dat = LoadLUAData(JH.GetAddonInfo().szRootPath .. "SkillCD/Skill.jx3dat")
	_SkillCD.tSkill = dat["tSkill"]
	_SkillCD.tBuffEx = dat["tBuffEx"]
	_SkillCD.tKungfu = dat["tKungfu"]
end
-- setmetatable(_SkillCD.tSkill,{ __index = function() return 60 end })
function SkillCD.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
    _SkillCD.UpdateAnchor(this)
	_SkillCD.frame = this
	_SkillCD.handle = this:Lookup("Wnd_List"):Lookup("","")
	GUI(this):Title(_L["SkillCD"]):Fetch("Check_Minimize"):Click(function(bChecked)
		_SkillCD.SwitchPanel(bChecked)
	end):Check(SkillCD.bMini)
	this:Lookup("Btn_Setting").OnLButtonClick = function()
		JH.OpenPanel(_L["SkillCD"])
	end
	_SkillCD.UpdateMonitorCache()
	_SkillCD.Init()
	_SkillCD.UpdateCount()
end

function SkillCD.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		_SkillCD.UpdateAnchor(this)
	end
end

function SkillCD.OnFrameDragEnd()
	this:CorrectPos()
	SkillCD.tAnchor = GetFrameAnchor(this)
end

_SkillCD.UpdateAnchor = function(frame)
	local a = SkillCD.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 450, -150, "CENTER", 0, 0)
	end
end
_SkillCD.SwitchPanel = function(bMini)
	SkillCD.bMini = bMini
	if bMini then
		_SkillCD.frame:Lookup("Wnd_List"):Hide()
		_SkillCD.frame:Lookup("Wnd_Count"):SetRelPos(0,30)
		_SkillCD.frame:Lookup("","Image_Bg"):SetSize(240,30)
	else
		_SkillCD.frame:Lookup("Wnd_List"):Show()
		_SkillCD.frame:Lookup("Wnd_Count"):SetRelPos(0,230)
		_SkillCD.frame:Lookup("","Image_Bg"):SetSize(240,230)
	end
end
_SkillCD.OpenPanel = function()
	local frame = _SkillCD.frame or Wnd.OpenWindow(_SkillCD.szIniFile,"SkillCD")
	return frame
end

_SkillCD.ClosePanel = function()
	JH.UnRegisterInit("SkillCD")
	Wnd.CloseWindow(_SkillCD.frame)
	_SkillCD.frame = nil
	_SkillCD.tCD = {}
end
_SkillCD.IsPanelOpened = function()
	return _SkillCD.frame and _SkillCD.frame:IsVisible()
end
_SkillCD.OnSkillCast = function(dwCaster, dwSkillID, dwLevel, szEvent)
	if not SkillCD.bEnable then
		return _SkillCD.ClosePanel()
	end
	if szEvent == "UI_OME_SKILL_CAST_LOG" then
		return
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
		nEnd = nEnd, nTotal = nTotal,
		dwSkillID = dwSkillID, dwLevel = dwLevel,
		dwIconID = dwIconID, szName = szName,
		szPlayer = p.szName
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
	_SkillCD.UpdateFrame()
	_SkillCD.UpdateCount()
end

-- 生成监控列表
_SkillCD.UpdateMonitorCache = function()
	local kungfu = {}
	for k, v in pairs(SkillCD.tMonitor) do
		for kk,vv in pairs(_SkillCD.tKungfu) do
			for kkk,vvv in ipairs(vv) do
				if vvv == k then
					if not kungfu[kk] then
						kungfu[kk] = {}
					end
					tinsert(kungfu[kk],k)
					break
				end
			end
		end
	end
	_SkillCD.tCache = kungfu
end

_SkillCD.UpdateCount = function()
	local me, team = GetClientPlayer(), GetClientTeam()
	if not me then return end
	local tMonitor, member, tKungfu, tCount = _SkillCD.tCache, {}, {}, {}
	for k, v in pairs(SkillCD.tMonitor) do
		tCount[k] = {}
		tCount[k].nCount = 0
		tCount[k].tList = {}
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
			tKungfu[v] = {
				bDeathFlag = team.GetMemberInfo(v).bDeathFlag,
				dwMountKungfuID = team.GetMemberInfo(v).dwMountKungfuID,
				szName = team.GetClientTeamMemberName(v),
			}
		else
			tKungfu[v] = {
				bDeathFlag = me.nMoveState == MOVE_STATE.ON_DEATH,
				dwMountKungfuID = UI_GetPlayerMountKungfuID(),
				szName = me.szName
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
	for k,v in pairs(tCount) do
		local item = handle:AppendItemFromIni(_SkillCD.szIniFile, "Handle_CLister", k)
		local szName, dwIconID = JH.GetSkillName(k)
		local box = item:Lookup("Box_Icon")
		tsort(v.tList, function(a,b)
			if a.nSec == b.nSec then
				return a.info.szName < a.info.szName
			else
				return a.nSec < b.nSec
			end
		end)
		item.OnItemRefreshTip = function()
			if box:IsValid() then
				if #v.tList > 0 then
					box:SetObjectMouseOver(true)
					local x, y = box:GetAbsPos()
					local w, h = box:GetSize()
					local szXml = GetFormatText(_L["["] .. szName .. _L["]"] .. "\n", 23 ,255 ,255 ,255)
					for k, v in ipairs(v.tList) do
						szXml = szXml .. GetFormatText(v.info.szName, 23, 255, 255, 0)
						local szDeath = GetFormatText(" (" .. _L["Death"] .. ")", 23, 255, 128, 0)
						if v.info.bDeathFlag then
							szXml = szXml .. szDeath
						end
						if v.nSec == 0 then
							szXml = szXml .. GetFormatText("\t" .. _L["ready"], 24, 0, 255, 0)
						else
							local szSec = floor(JH.GetEndTime(v.nSec))
							local txt = szSec .. _L["s"]
							if szSec > 60 then
								txt = _L("%dm%ds",szSec / 60, szSec % 60)
							end
							szXml = szXml .. GetFormatText("\t" .. txt, 24, 255, 0, 0)
						end
					end
					OutputTip(szXml, 300, { x, y, w, h })
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
							tinsert(tSay, { type = "text", text = " (" .. _L["Death"] .. ")" })
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
		if #v.tList == 0 then
			item:SetAlpha(100)
		end
		box:SetObject(UI_OBJECT_ITEM)
		box:SetObjectIcon( dwIconID )
		-- box:SetObjectSparking(true)
		item:Lookup("Text_Count"):SetText( v.nCount )
		if v.nCount > 0 then 
			item:Lookup("Text_Count"):SetFontColor(0, 255, 0)
		else
			item:Lookup("Text_Count"):SetFontColor(255, 0, 0)
		end
		item:Show()
		item:FormatAllItemPos()
	end
	
	handle:FormatAllItemPos()
	local w, h = handle:GetAllItemSize()
	_SkillCD.frame:Lookup("Wnd_Count"):SetSize(240, h + 5)
	_SkillCD.frame:Lookup("Wnd_Count"):Lookup("","Image_CBg"):SetSize(240, h + 5)
end

_SkillCD.UpdateFrame = function()
	local handle = _SkillCD.handle
	handle:Clear()
	local data = {}
	-- 排序
	for k,v in pairs(_SkillCD.tCD) do
		for kk,vv in ipairs(v) do
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
	tsort(data, function(a,b) return a.nEnd < b.nEnd end)
	for k,v in ipairs(data) do
		local item = handle:AppendItemFromIni(_SkillCD.szIniFile, "Handle_Lister", k)
		local nSec = _SkillCD.tSkill[v.dwSkillID]
		local fP = min(1, JH.GetEndTime(v.nEnd) / nSec)
		local szSec = floor(JH.GetEndTime(v.nEnd))
		if fP < 0.15 then
			item:Lookup("Image_LPlayer"):FromUITex("ui/Image/Common/money.uitex",215)
		end
		local txt = szSec .. _L["s"]
		if szSec > 60 then
			txt = _L("%dm%ds",szSec / 60, szSec % 60)
		end
		item:Lookup("Image_LPlayer"):SetPercentage(fP)
		item:Lookup("Text_LLife"):SetText(txt)
		item:Lookup("Text_Player"):SetText(v.szPlayer .. "_" .. v.szName)
		item:Lookup("Skill_Icon"):FromIconID(v.dwIconID)
		item:Show()
	end
	handle:FormatAllItemPos()
	-- Output(handle:GetItemCount())
end

local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["SkillCD"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = SkillCD.bEnable, txt = _L["Enable SkillCD"] }):Click(function(bChecked)
		SkillCD.bEnable = bChecked
		ui:Fetch("bSelf"):Enable(bChecked)
		ui:Fetch("bInDungeon"):Enable(bChecked)
		if bChecked then
			if SkillCD.bInDungeon then
				if JH.IsInDungeon2() then
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
	nX,nY = ui:Append("WndCheckBox", "bSelf", { x = 25, y = nY, checked = SkillCD.bSelf })
	:Enable(SkillCD.bEnable):Text(_L["only Monitor self"]):Click(function(bChecked)
		SkillCD.bSelf = bChecked
		if _SkillCD.IsPanelOpened() then
			_SkillCD.UpdateCount()
		end
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", "bInDungeon", { x = 25, y = nY, checked = SkillCD.bInDungeon })
	:Enable(SkillCD.bEnable):Text(_L["Only in the map type is Dungeon Enable plug-in"]):Click(function(bChecked)
		SkillCD.bInDungeon = bChecked
		if bChecked then
			if JH.IsInDungeon2() then
				_SkillCD.OpenPanel()
			else
				_SkillCD.ClosePanel()
			end
		else
			_SkillCD.OpenPanel()
		end
		JH.OpenPanel(_L["SkillCD"])
	end):Pos_()
	
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Monitor"], font = 27 }):Pos_()
	local i = 0
	for k,v in pairs(_SkillCD.tSkill) do
		local a = 100
		if SkillCD.tMonitor[k] then a = 255 end
		ui:Append("Box", { x = (i % 9) * 56, y = nY + floor(i / 9 ) * 55 + 15, alpha = a } ):Icon(Table_GetSkillIconID(k))
		:ToGray(not _SkillCD.IsPanelOpened()):Staring(SkillCD.tMonitor[k] or false):Hover(function()
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			OutputSkillTip(k,1,{ x, y, w, h })
			if a == 100 then this:SetAlpha(200) end
			this:SetObjectMouseOver(true)
		end,function()
			HideTip()
			this:SetAlpha(a)
			this:SetObjectMouseOver(false)
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
GUI.RegisterPanel(_L["SkillCD"], 13, _L["General"], PS)

_SkillCD.Init = function()
	JH.RegisterInit("SkillCD", 
		{ "Breathe", _SkillCD.UpdateFrame, 1000 },
		{ "SYS_MSG", function()
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
		end },
		{ "BUFF_UPDATE", function()
			if _SkillCD.tBuffEx[arg4] and not arg1 then
				_SkillCD.OnSkillCast(arg9, _SkillCD.tBuffEx[arg4], arg8, "BUFF_UPDATE")
			end
		end },
		{ "DO_SKILL_CAST", function()
			_SkillCD.OnSkillCast(arg0, arg1, arg2, "DO_SKILL_CAST")
		end },
		{ "PARTY_DISBAND", _SkillCD.UpdateCount },
		{ "PARTY_DELETE_MEMBER", _SkillCD.UpdateCount },
		{ "PARTY_ADD_MEMBER", _SkillCD.UpdateCount },
		{ "PARTY_UPDATE_MEMBER_INFO", _SkillCD.UpdateCount },
		{ "SKILL_MOUNT_KUNG_FU", _SkillCD.UpdateCount }
	)
end

JH.RegisterEvent("LOADING_END", function()
	if not SkillCD.bEnable then return end
	if SkillCD.bInDungeon then
		if JH.IsInDungeon2() then
			_SkillCD.OpenPanel()
		else
			_SkillCD.ClosePanel()
		end
	end
	if _SkillCD.frame then
		_SkillCD.tCD = {}
		_SkillCD.UpdateCount()
	end
end)

JH.RegisterEvent("LOGIN_GAME", function()
	if not SkillCD.bEnable then return end
	_SkillCD.OpenPanel()
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


