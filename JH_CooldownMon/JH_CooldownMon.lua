-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2016-12-13 01:16:40
local _L = JH.LoadLangPack

SkillCD = {
	bEnable       = true,
	bMini         = true,
	bInDungeon    = true,
	tAnchor       = {},
	nMaxCountdown = 10,
	tMonitor = {
		[371]  = true,
		[551]  = true,
		[2235] = true,
		[2234] = true,
	},
	tCustom = {
		[17] = 10, -- 打坐测试
	},
}
JH.RegisterCustomData("SkillCD", 2)

local SkillCD = SkillCD
local ipairs, pairs = ipairs, pairs
local tinsert, tsort, tremove, tconcat = table.insert, table.sort, table.remove, table.concat
local floor, min = math.floor, math.min
local GetPlayer, IsPlayer, UI_GetClientPlayerID = GetPlayer, IsPlayer, UI_GetClientPlayerID
local GetClientPlayer, GetClientTeam = GetClientPlayer, GetClientTeam
local GetLogicFrameCount, GetFormatText = GetLogicFrameCount, GetFormatText
local SC = {
	szIniFile = JH.GetAddonInfo().szRootPath .. "JH_CooldownMon/ui/JH_CooldownMon.ini",
	tCD = {},
	tIgnore = {},
}

local aSkillList = {
	[371]   = 300,  -- 震山河
	[551]   = 660,  -- 心鼓弦
	[131]   = 150,  -- 碧水滔天
	[252]   = 25,   -- 大狮子吼
	[2235]  = 90,   -- 千蝶吐瑞
	[3985]  = 300,  -- 朝圣言
	[2234]  = 120,  -- 仙王蛊鼎
	[411]   = 90,   -- 掠如火
	[3971]  = 45,   -- 极乐引
	[2663]  = 120,  -- 听风吹雪
	[2220]  = 1500, -- 凤凰谷
	[259]   = 300,  -- 轮回决
	[1645]  = 120,  -- 风来吴山
	[2957]  = 18,   -- 圣手
	[13072] = 90,   -- 盾护
	[555]   = 40,   -- 风秀
	[569]   = 15,   -- 王母
	[132]   = 36,   -- 春泥
	[258]   = 45,   -- 舍身
	[568]   = 120,  -- 梵音
	[6800]  = 180,  -- 收盾
	[14084] = 180,  -- 长歌ZF
	[14075] = 80,   -- 长歌 伤害平摊
	[15132] = 40,   -- 五毒草
	[15115] = 180,  -- 号令三军
	[14963] = 105,  -- 奶花免死
	[14081] = 180,  -- 孤影化双
	[14073] = 80,   -- 笑傲光阴
	[3981]  = 45,   -- 归寂道
}

function SkillCD.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("SYS_MSG")
	-- this:RegisterEvent("BUFF_UPDATE")
	this:RegisterEvent("DO_SKILL_CAST")
	this:RegisterEvent("PARTY_DISBAND")
	this:RegisterEvent("PARTY_DELETE_MEMBER")
	this:RegisterEvent("PARTY_ADD_MEMBER")
	this:RegisterEvent("PARTY_UPDATE_MEMBER_INFO")
	this:RegisterEvent("PARTY_SET_MEMBER_ONLINE_FLAG")
	this:RegisterEvent("SKILL_MOUNT_KUNG_FU")
	this:RegisterEvent("LOADING_END")
    SC.UpdateAnchor(this)
	SC.frame = this
	SC.handle = this:Lookup("Wnd_List"):Lookup("", "")
	this:Lookup("", "Text_Title"):SetText(_L["Skill Cooldown"])
	this:Lookup("Check_Minimize"):Check(SkillCD.bMini)
	SC.UpdateMonitorCache()
	SC.UpdateCount()
end

function SkillCD.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Setting" then
		JH.OpenPanel(_L["Skill Cooldown"])
	end
end

function SkillCD.OnCheckBoxCheck()
	local szName = this:GetName()
	if szName == "Check_Minimize" then
		SC.SwitchPanel(true)
	end
end

function SkillCD.OnCheckBoxUncheck()
	local szName = this:GetName()
	if szName == "Check_Minimize" then
		SC.SwitchPanel(false)
	end
end

function SkillCD.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		SC.UpdateAnchor(this)
	elseif szEvent == "SYS_MSG" then
		if arg0 == "UI_OME_SKILL_HIT_LOG" and arg3 == SKILL_EFFECT_TYPE.SKILL then
			SC.OnSkillCast(arg1, arg4, arg5, arg0)
		elseif arg0 == "UI_OME_SKILL_EFFECT_LOG" and arg4 == SKILL_EFFECT_TYPE.SKILL then
			SC.OnSkillCast(arg1, arg5, arg6, arg0)
		elseif (arg0 == "UI_OME_SKILL_BLOCK_LOG" or arg0 == "UI_OME_SKILL_SHIELD_LOG"
				or arg0 == "UI_OME_SKILL_MISS_LOG" or arg0 == "UI_OME_SKILL_DODGE_LOG")
			and arg3 == SKILL_EFFECT_TYPE.SKILL
		then
			SC.OnSkillCast(arg1, arg4, arg5, arg0)
		end
	elseif szEvent == "DO_SKILL_CAST" then
		SC.OnSkillCast(arg0, arg1, arg2, "DO_SKILL_CAST")
	elseif szEvent == "LOADING_END" then
		SC.tCD = {}
		SC.UpdateCount()
	else
		SC.UpdateCount()
	end
end

function SkillCD.OnFrameBreathe()
	local data = {}
	-- 排序
	for k, v in pairs(SC.tCD) do
		for kk, vv in ipairs(v) do
			local nSec = aSkillList[vv.dwSkillID] or 0
			local pre = min(1, JH.GetEndTime(vv.nEnd) / nSec)
			if pre > 0 then
				vv.pre = pre
				tinsert(data, vv)
			else
				tremove(SC.tCD[k], kk)
				SC.UpdateCount()
			end
		end
	end
	-- 更新倒计时条
	if SkillCD.bMini then return end
	if GetLogicFrameCount() % 4 == 0 then -- 其实也只是防止倒计时太多占用性能 ...
		local handle = SC.handle
		handle:Clear()
		tsort(data, function(a, b) return a.nEnd < b.nEnd end)
		for k, v in ipairs(data) do
			if not SC.tIgnore[v.dwSkillID] then
				local item = handle:AppendItemFromIni(SC.szIniFile, "Handle_Lister", i)
				local fP = min(1, JH.GetEndTime(v.nEnd) / v.nTotal)
				if fP < 0.15 then
					item:Lookup("Image_LPlayer"):SetFrame(206)
				end
				local txt = JH.FormatTimeString(floor(JH.GetEndTime(v.nEnd)), 2)
				item:Lookup("Image_LPlayer"):SetPercentage(fP)
				item:Lookup("Text_LLife"):SetText(txt)
				item:Lookup("Text_Player"):SetText(v.szPlayer .. "_" .. v.szName)
				item:Lookup("Skill_Icon"):FromIconID(v.dwIconID)
				item:Show()
			end
		end
		handle:FormatAllItemPos()
		SC.SetUISize(handle:GetItemCount())
	end
end

function SkillCD.OnFrameDragEnd()
	this:CorrectPos()
	SkillCD.tAnchor = GetFrameAnchor(this, "TOPLEFT")
end

function SC.UpdateAnchor(frame)
	local a = SkillCD.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 450, -150)
	end
end

function SC.SwitchPanel(bMini)
	SkillCD.bMini = bMini
	if not SC.frame then
		return
	end
	if bMini then
		SC.frame:Lookup("Wnd_List"):Hide()
		SC.frame:Lookup("Wnd_Count"):SetRelPos(0, 29)
		SC.frame:Lookup("", "Image_Bg"):SetSize(240, 30)
	else
		SC.frame:Lookup("Wnd_List"):Show()
	end
end

function SC.SetUISize(nCount)
	if not SkillCD.bMinit then
		local h = min(SkillCD.nMaxCountdown * 20, nCount * 20)
		local wnd = SC.frame:Lookup("Wnd_List")
		wnd:SetH(h)
		wnd:Lookup("Scroll_List"):SetH(h)
		wnd:Lookup("", ""):SetH(h)
		SC.frame:Lookup("", "Image_Bg"):SetH(30 + h)
		SC.frame:Lookup("Wnd_Count"):SetRelPos(0, 29 + h)
	end
end

function SC.OpenPanel()
	local frame = SC.frame or Wnd.OpenWindow(SC.szIniFile, "SkillCD")
	return frame
end

function SC.ClosePanel()
	if SC.frame then
		Wnd.CloseWindow(SC.frame)
		SC.frame = nil
		SC.tCD = {}
	end
end

function SC.IsPanelOpened()
	return SC.frame and SC.frame:IsVisible()
end

function SC.OnSkillCast(dwCaster, dwSkillID, dwLevel, szEvent)
	if not IsPlayer(dwCaster) then
		return
	end

	if not SkillCD.tMonitor[dwSkillID] then
		return
	end

	local nSec = aSkillList[dwSkillID]
	if not nSec then
		return
	end
	if not JH.IsParty(dwCaster) and dwCaster ~= UI_GetClientPlayerID() then
		return
	end
	-- get name
	local p = GetPlayer(dwCaster)
	if not p then return end
	local szName, dwIconID = JH.GetSkillName(dwSkillID, dwLevel)

	if not SC.tCD[dwCaster] then
		SC.tCD[dwCaster] = {}
	end
	local nEnd = GetLogicFrameCount() + nSec * 16
	local find = false
	local data = {
		nEnd      = nEnd,
		nTotal    = nSec,
		dwSkillID = dwSkillID,
		dwLevel   = dwLevel,
		dwIconID  = dwIconID,
		szName    = szName,
		szPlayer  = p.szName
	}
	for k, v in ipairs(SC.tCD[dwCaster]) do
		if v.dwSkillID == dwSkillID then
			SC.tCD[dwCaster][k] = data
			find = true
			break
		end
	end
	if not find then
		tinsert(SC.tCD[dwCaster], data)
	end
	SC.UpdateCount()
end

-- 生成监控列表
function SC.UpdateMonitorCache()
	local tKungfuMain = { [0] = {} }
	for k, v in pairs(JH_KUNGFU_LIST) do
		local dwKungfuID = v[1]
		local hSkill = GetSkill(dwKungfuID, 1)
		tKungfuMain[hSkill.dwBelongSchool] = tKungfuMain[hSkill.dwBelongSchool] or {}
		tinsert(tKungfuMain[hSkill.dwBelongSchool], dwKungfuID)
		tinsert(tKungfuMain[0], dwKungfuID)
	end
	local kungfu = {}
	for k, v in pairs(SkillCD.tMonitor) do
		if aSkillList[k] then
			local hSkill = GetSkill(k, 1)
			if hSkill.dwMountRequestDetail ~= 0 then
				if hSkill.dwMountRequestDetail == 10144 or hSkill.dwMountRequestDetail == 10145 then -- cj fix
					kungfu[10144] = kungfu[10144] or {}
					kungfu[10145] = kungfu[10145] or {}
					tinsert(kungfu[10144], k)
					tinsert(kungfu[10145], k)
				else
					kungfu[hSkill.dwMountRequestDetail] = kungfu[hSkill.dwMountRequestDetail] or {}
					tinsert(kungfu[hSkill.dwMountRequestDetail], k)
				end
			else
				for kk, vv in ipairs(tKungfuMain[hSkill.dwMountRequestType] or {}) do
					kungfu[vv] = kungfu[vv] or {}
					tinsert(kungfu[vv], k)
				end
			end
		else
			SkillCD.tMonitor[k] = nil
		end
	end
	SC.tCache = kungfu
end

function SC.UpdateCount()
	local me, team = GetClientPlayer(), GetClientTeam()
	if not me then return end
	local tMonitor, member, tKungfu, tCount = SC.tCache, {}, {}, {}
	for k, v in pairs(SkillCD.tMonitor) do
		if aSkillList[k] then
			tCount[k] = {}
			tCount[k].nCount = 0
			tCount[k].tList = {}
		end
	end
	if me.IsInParty() then
		member = team.GetTeamMemberList()
	else
		tinsert(member, me.dwID)
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
				local nEnd
				if SC.tCD[k] then -- 如果有记录
					for _, vvv in ipairs(SC.tCD[k]) do
						if vvv.dwSkillID == vv then
							nEnd = vvv.nEnd
							break
						end
					end
				end
				if not nEnd then
					tCount[vv].nCount = tCount[vv].nCount + 1
					tinsert(tCount[vv].tList, { nSec = 0, info = v })
				else
					tinsert(tCount[vv].tList, { nSec = nEnd, info = v })
				end
			end
		end
	end
	local handle = SC.frame:Lookup("Wnd_Count"):Lookup("", "Handle_CList")
	handle:Clear()
	for k, v in pairs(tCount) do
		local item = handle:AppendItemFromIni(SC.szIniFile, "Handle_CLister", k)
		local szName, dwIconID = JH.GetSkillName(k)
		local box = item:Lookup("Box_Icon")
		tsort(v.tList, function(a, b)
			if a.nSec == b.nSec then
				return a.info.szName < a.info.szName
			else
				return a.nSec < b.nSec
			end
		end)
		box:EnableObject(not (SC.tIgnore[k] or false))
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
							tinsert(xml, GetFormatText("\t" .. JH.FormatTimeString(floor(JH.GetEndTime(v.nSec)), 2), 24, 255, 0, 0))
						end
					end
					OutputTip(tconcat(xml), 300, { x, y, w, h })
				end
			end
		end

		item.OnItemRButtonClick = function()
			if #v.tList > 0 then
				if SC.tIgnore[k] then
					SC.tIgnore[k] = nil
				else
					SC.tIgnore[k] = true
				end
				box:EnableObject(not (SC.tIgnore[k] or false))
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
							tinsert(tSay, { type = "text", text = g_tStrings.STR_ONE_CHINESE_SPACE .. JH.FormatTimeString(floor(JH.GetEndTime(v.nSec)), 2) })
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
		local hCount = item:Lookup("Text_Count")
		hCount:SetText(v.nCount)
		if #v.tList == 0 then
			item:SetAlpha(100)
			box:IconToGray()
			hCount:SetFontColor(156, 156, 156)
		else
			if v.nCount > 0 then
				hCount:SetFontColor(0, 255, 0)
			else
				hCount:SetFontColor(255, 0, 0)
			end
		end
		item:SetUserData(#v.tList ~= 0 and k or 999999)
		item:Show()
		item:FormatAllItemPos()
	end
	handle:Sort()
	handle:FormatAllItemPos()
	local w, h = handle:GetAllItemSize()
	SC.frame:Lookup("Wnd_Count"):SetH(h + 5)
	SC.frame:Lookup("Wnd_Count"):Lookup("", "Image_CBg"):SetH(h + 5)
end

function SC.AddSkill()
	local ui = GUI.CreateFrame("SkillCD_Add", { w = 380, h = 250, title = _L["Add"], close = true, focus = true })
	ui:Append("Text", { txt = _L["Skill ID:"], font = 27, w = 105, h = 30, x = 0, y = 80, align = 2 })
	ui:Append("WndEdit", "id", { x = 115, y = 83 }):Type(1)
	ui:Append("Text", { txt = _L["Cool Down:"], font = 27, w = 105, h = 30, x = 0, y = 110, align = 2 })
	ui:Append("WndEdit", "cd", { txt = szMap, x = 115, y = 113 }):Type(1)
	ui:Append("WndButton3", { txt = g_tStrings.STR_HOTKEY_SURE, x = 115, y = 185 }):Click(function()
		local id, cd  = tonumber(ui:Fetch("id"):Text()), tonumber(ui:Fetch("cd"):Text())
		if id and cd then
			if SkillCD.tCustom[id] then
				return JH.Alert(_L["same data Exist"])
			else
				if not GetSkill(id, 1) then
					return JH.Alert(g_tStrings.STR_ERROR_SKILL_INVALID_SKILL)
				end
				SkillCD.tCustom[id]  = cd
				aSkillList[id]       = cd
				JH.OpenPanel(_L["Skill Cooldown"])
				ui:Remove()
			end
		end
	end)
end

function SC.CheckOpen()
	if SkillCD.bEnable then
		if SkillCD.bInDungeon and JH.IsInDungeon(true) or not SkillCD.bInDungeon then
			SC.OpenPanel()
		else
			SC.ClosePanel()
		end
	else
		SC.ClosePanel()
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	ui:Append("WndButton3", { x = 350, y = 10, txt = _L["Add"] }):Click(SC.AddSkill)
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Skill Cooldown"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = SkillCD.bEnable, txt = _L["Enable Skill Cooldown Mon"] }):Click(function(bChecked)
		SkillCD.bEnable = bChecked
		ui:Fetch("bInDungeon"):Enable(bChecked)
		SC.CheckOpen()
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bInDungeon", { x = 25, y = nY, checked = SkillCD.bInDungeon, enable = SkillCD.bEnable })
	:Text(_L["Only in the map type is Dungeon Enable plug-in"]):Click(function(bChecked)
		SkillCD.bInDungeon = bChecked
		SC.CheckOpen()
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Countdown"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = not SkillCD.bMini, txt = _L["Show Countdown"] }):Click(function(bChecked)
		SC.SwitchPanel(not bChecked)
		ui:Fetch("nMaxCountdown"):Enable(bChecked)
	end):Pos_()
	nX, nY = ui:Append("WndComboBox", "nMaxCountdown", { x = nX + 10, y = nY + 10, txt = g_tStrings.STR_SHOW_HATRE_COUNTS, enable = not SkillCD.bMini })
	:Menu(function()
		local t = {}
		for k, v in ipairs({3, 4, 5, 6, 7, 8, 9, 10, 15, 20}) do
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
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Monitor"], font = 27 }):Pos_()
	local tab = {}
	for k, v in pairs(aSkillList) do
		tab[#tab + 1] = { dwID = k, nCD = v }
	end
	table.sort(tab, function(a, b)
		return a.dwID < b.dwID
	end)
	for k, v in ipairs(tab) do
		local i = k - 1
		local dwMaxLevel = GetSkill(v.dwID, 1) and GetSkill(v.dwID, 1).dwMaxLevel or 1
		ui:Append("Box", { x = (i % 13) * 40, y = nY + floor(i / 13 ) * 40 + 15, w = 36, h = 36 }):BoxInfo(UI_OBJECT_SKILL, v.dwID, dwMaxLevel)
		:Enable(SkillCD.tMonitor[v.dwID] or false):Click(function(bCheck)
			if SkillCD.tMonitor[v.dwID] then
				SkillCD.tMonitor[v.dwID] = nil
			else
				SkillCD.tMonitor[v.dwID] = true
			end
			this:EnableObject(SkillCD.tMonitor[v.dwID] or false)
			SC.UpdateMonitorCache()
			if SC.IsPanelOpened() then
				SC.UpdateCount()
			end
		end).self.OnItemRButtonClick = function()
			local menu = {}
			table.insert(menu, { szOption = g_tStrings.STR_FRIEND_DEL .. " " .. JH.GetSkillName(v.dwID, 1), rgb = { 255, 0, 0 }, fnAction = function()
				if SkillCD.tCustom[v.dwID] then
					SkillCD.tCustom[v.dwID]  = nil
					SkillCD.tMonitor[v.dwID] = nil
					aSkillList[v.dwID]       = nil
					JH.OpenPanel(_L["Skill Cooldown"])
					SC.UpdateMonitorCache()
					if SC.IsPanelOpened() then
						SC.UpdateCount()
					end
				else
					JH.Alert(_L["Can not delete default data"])
				end
			end })
			PopupMenu(menu)
		end
	end
end
GUI.RegisterPanel(_L["Skill Cooldown"], 889, _L["Dungeon"], PS)
JH.RegisterEvent("LOADING_END", SC.CheckOpen)
JH.RegisterEvent("LOGIN_GAME", function()
	for k, v in pairs(SkillCD.tCustom) do
		aSkillList[k] = v
	end
end)
JH.AddonMenu(function()
	return {
		szOption = _L["Skill Cooldown"], bCheck = true, bChecked = SC.IsPanelOpened(), fnAction = function()
			SkillCD.bInDungeon = false
			if SC.IsPanelOpened() then
				SkillCD.bEnable = false
			else
				SkillCD.bEnable = true
			end
			SC.CheckOpen()
		end
	}
end)

