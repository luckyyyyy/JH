-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-02 11:12:18
local _L = JH.LoadLangPack
-- val
local ARENAMAP             = false
local RGES_CACHE           = {}
local RGES_ALL_TYPE        = { "Buff", "Debuff", "Casting", "Npc" }
local RGES_DATA_PATH       = "RGES/"
local RGES_INI_PATH        = JH.GetAddonInfo().szRootPath .. "RaidGrid_EventScrutiny/ui/"
local RGES_CLIENT_PLAYER   =  "NONE"
local RGES_TABLE_NPC_FIGHT = {}
-- local RGES_TABLE_NPC_LIFE  = {}
local function HashChange(tRecords)
	local Hash = {}
	local Hash2 = {}
	for k, v in ipairs(tRecords) do
		if v.dwID then
			Hash[v.dwID] = true
		end
		if v.nLevel then
			Hash2[v.dwID] = Hash2[v.dwID] or {}
			Hash2[v.dwID][v.nLevel] = true
		end
	end
	tRecords.Hash = Hash
	tRecords.Hash2 = Hash2
end

-- 获取内容
do
	for k, v in ipairs(RGES_ALL_TYPE) do
		RGES_CACHE[v] = setmetatable({}, { __mode = "v" })
	end
end

local function GetData(tab, szType, dwID, nLevel)
	for i = 1, #tab do
		if tab[i].dwID == dwID and (not tab[i].bAlwaysCheckLevel or tab[i].nLevel == nLevel) then
			RGES_CACHE[szType][dwID] = i
			return tab[i]
		end
	end
end

local function GetCacheData(szType, dwID, nLevel)
	local tab = RaidGrid_EventScrutiny.tRecords[szType]
	if tab.Hash[dwID] then
		if RGES_CACHE[szType][dwID] then
			local data = tab[RGES_CACHE[szType][dwID]]
			if data.dwID == dwID and (not data.bAlwaysCheckLevel or data.nLevel == nLevel) then
				-- Log(szType .. " " .. dwID .. "_" .. (nLevel or 0) ..  " HIT")
				return data
			else
				-- Log(szType .. " " .. dwID .. "_" .. (nLevel or 0) ..  " RELOOKUP")
				return GetData(tab, szType, dwID, nLevel)
			end
		else
			-- Log(szType .. " " .. dwID .. "_" .. (nLevel or 0) ..  " LOOKUP")
			return GetData(tab, szType, dwID, nLevel)
		end
	end
end

local function ClearCacheData()
	local tTab = RaidGrid_EventScrutiny.tRecords["Npc"]
	for i = 1, #tTab do
		tTab[i].szIconPath = nil
		tTab[i].bChatAlertCDEnd = nil
		tTab[i].bChatAlertCDEnd2 = nil
		tTab[i].bChatAlertCDEnd3 = nil
		tTab[i].nEventScrutinyCDEnd = nil
		tTab[i].szDescription = nil
		tTab[i].nRemoveDelayTime = nil
		tTab[i].szSoundFile = nil
		tTab[i].fLastNpcAppearTime = nil
		tTab[i].fEventTimeStart = nil
		tTab[i].fEventTimeEnd = nil
		tTab[i].fMinTime = nil
		tTab[i].bIsVisible = nil
		tTab[i].tTimerSet = nil
		tTab[i].szLinkNpcName = nil
		tTab[i].dwLinkNpcTID = nil
		if tTab[i].tRGAlertColor then
			tTab[i].tRGAlertColor = nil
			tTab[i].bFullScreenAlert = true
		end
	end
	local tTab2 = RaidGrid_EventScrutiny.tRecords["Casting"]
	for i = 1, #tTab2 do
		tTab2[i].bChatAlertCDEnd = nil
		tTab2[i].bChatAlertCDEnd2 = nil
		tTab2[i].bChatAlertCDEnd3 = nil
		tTab2[i].nEventScrutinyCDEnd = nil
		tTab2[i].szDescription = nil
		tTab2[i].nRemoveDelayTime = nil
		tTab2[i].szSoundFile = nil
		tTab2[i].fLastSkillAppearTime = nil
		tTab2[i].fEventTimeStart = nil
		tTab2[i].fEventTimeEnd = nil
		tTab2[i].fMinTime = nil
		tTab2[i].tTimerSet = nil
		if tTab2[i].tRGAlertColor then
			tTab2[i].tRGAlertColor = nil
			tTab2[i].bFullScreenAlert = true
		end
	end
	local tTab3 = RaidGrid_EventScrutiny.tRecords["Buff"]
	for i = 1, #tTab3 do
		tTab3[i].buff = nil
		tTab3[i].bIsDebuff = nil
		tTab3[i].bChatAlertCDEnd = nil
		tTab3[i].bChatAlertCDEnd2 = nil
		tTab3[i].bChatAlertCDEnd3 = nil
		tTab3[i].nEventScrutinyCDEnd = nil
		tTab3[i].szDescription = nil
		tTab3[i].nRemoveDelayTime = nil
		tTab3[i].szSoundFile = nil
		tTab3[i].fKeepTime = nil
		tTab3[i].fEventTimeStart = nil
		tTab3[i].fEventTimeEnd = nil
		tTab3[i].bIsVisible = nil
		if tTab3[i].tRGAlertColor then
			tTab3[i].tRGAlertColor = nil
			tTab3[i].bFullScreenAlert = true
		end
	end
	local tTab4 = RaidGrid_EventScrutiny.tRecords["Debuff"]
	for i = 1, #tTab4 do
		tTab4[i].buff = nil
		tTab4[i].bIsDebuff = nil
		tTab4[i].bChatAlertCDEnd = nil
		tTab4[i].bChatAlertCDEnd2 = nil
		tTab4[i].bChatAlertCDEnd3 = nil
		tTab4[i].nEventScrutinyCDEnd = nil
		tTab4[i].szDescription = nil
		tTab4[i].nRemoveDelayTime = nil
		tTab4[i].szSoundFile = nil
		tTab4[i].fKeepTime = nil
		tTab4[i].fEventTimeStart = nil
		tTab4[i].fEventTimeEnd = nil
		tTab4[i].bIsVisible = nil
		if tTab4[i].tRGAlertColor then
			tTab4[i].tRGAlertColor = nil
			tTab4[i].bFullScreenAlert = true
		end
	end
end

local function CheckNpcFightState()
	local dat = RGES_TABLE_NPC_FIGHT
	for k, v in pairs(dat) do
		local bChangeFSFlag
		for kk, vv in ipairs(v.tList) do
			local npc = GetNpc(vv)
			if npc then
				if npc.bFightState then
					if npc.bFightState ~= v.bFightState then
						bChangeFSFlag = true
						v.bFightState = true
						break
					end
				else
					if kk == #v.tList and npc.bFightState ~= v.bFightState then
						bChangeFSFlag = false
						v.bFightState = false
					end
				end
			else
				v.tList[kk] = nil
				if #v.tList == 0 then
					if v.bFightState then
						bChangeFSFlag = false
					end
					dat[k] = nil
				end
			end
		end
		if bChangeFSFlag then
			local data = GetCacheData("Npc", k)
			JH.Sysmsg(_L("[%s] Enter Fight.", data.szName))
			v.nSec = GetTime()
			if data.szTimerSet then
				FireEvent("JH_ST_CREATE", JH_ST_TYPE.NPC_FIGHT, data.dwID .. "F", {
					nTime  = data.szTimerSet,
					nIcon  = data.nIconID or 2026,
					bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
				})
			end
			if data.bSkillTimer2Enable and data.nSkillTimer2 and data.nSkillTimer2>0 then
				FireEvent("JH_ST_CREATE", JH_ST_TYPE.NPC_FIGHT, data.dwID .. "C2", {
					nTime  = data.nSkillTimer2,
					szName = data.szSkillName2 or data.szName,
					nIcon  = data.nIconID or 2026,
					bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
				})
			end
		elseif bChangeFSFlag == false then
			local data = GetCacheData("Npc", k)
			local nTime = GetTime() - (v.nSec or GetTime())
			v.nSec = nil
			JH.Sysmsg(_L("[%s] Leave Fight, time:%s.", data.szName, JH.FormatTimeString(nTime / 1000)))
			FireEvent("JH_ST_DEL", JH_ST_TYPE.NPC_FIGHT, data.dwID .. "F", true) -- kill
		end
	end
end

JH.BreatheCall("CheckNpcFightState", CheckNpcFightState)

RaidGrid_EventScrutiny = {}
local RaidGrid_EventScrutiny = RaidGrid_EventScrutiny
local _RE = {
	tNpcLife = {},
}

function RaidGrid_EventScrutiny.OnFrameCreate()
	this:RegisterEvent("BUFF_UPDATE")
	this:RegisterEvent("NPC_ENTER_SCENE")
	this:RegisterEvent("NPC_LEAVE_SCENE")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("DO_SKILL_CAST")
	this:RegisterEvent("SYS_MSG")
	RaidGrid_EventScrutiny.wnd = this:Lookup("Wnd_Scrutiny")
	RaidGrid_EventScrutiny.frameSelf = this
	RaidGrid_EventScrutiny.handleMain = this:Lookup("Wnd_Scrutiny"):Lookup("", "")
	RaidGrid_EventScrutiny.handleRecords = this:Lookup("Wnd_Scrutiny"):Lookup("", "Handle_Records")
	RaidGrid_EventScrutiny.handleMain:Lookup("Handle_RecordDummy"):Hide()
	RaidGrid_EventScrutiny.InitRecordHandles()
	RaidGrid_EventScrutiny.SwitchPageType("Scrutiny")
	RaidGrid_EventScrutiny.UpdateAnchor(this)
end

local bSendDataToTeamStart = false
local tSyncQueue = {}
JH.RegisterEvent("ON_BG_CHANNEL_MSG", function()
	local me = GetClientPlayer()
	local data = JH.BgHear("RGES")
	if data then
		 -- 开始发送
		if data[1] == "RE_SendSOpen" and not bSendDataToTeamStart then
			if data[2] ~= me.szName and data[2] ~= "ALL" then
				return
			end
			bSendDataToTeamStart = true
			tSyncQueue = {}
		end
		-- 接收
		if data[1] == "RE_SyncQueue" and bSendDataToTeamStart then
			table.insert(tSyncQueue, data[2])
		end
		-- 结束
		if data[1] == "RE_SendClose" and bSendDataToTeamStart then
			bSendDataToTeamStart = false
			local str = table.concat(tSyncQueue, "")
			local tData,err = JH.JsonDecode(JH.AscIIDecode(str))
			if err then
				return JH.Debug(err)
			end
			local author = arg3
			local szDataName = tData["szName"] or _L["Unknown"]
			JH.Confirm(_L("Data Update TIPS\nTeammate: %s sent a [%s] for you, whether to join the monitoring list?", author, szDataName), function()
				JH.Talk(author,_L["Joined your data"])
				RaidGrid_EventScrutiny.Macro(tData,data[2])
			end)
		end
	end
end)

function RaidGrid_EventScrutiny.OnFrameDragEnd()
	this:CorrectPos()
	RaidGrid_EventScrutiny.tAnchor = GetFrameAnchor(this, "TOPLEFT")
end

function RaidGrid_EventScrutiny.UpdateAnchor(frame)
	local a = RaidGrid_EventScrutiny.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
	this:CorrectPos()
end

function RaidGrid_EventScrutiny.OnEvent(szEvent)
	local player = GetClientPlayer()
	if not player then
		return
	end
	if not RaidGrid_EventScrutiny.bEnable then
		return
	end
	if szEvent == "BUFF_UPDATE" then
		RaidGrid_EventScrutiny.OnUpdateBuffData(arg0, arg1, arg2, arg4, arg5, arg6, arg8, arg9, arg3)
	elseif szEvent == "NPC_ENTER_SCENE" then
		local npc = GetNpc(arg0)
		if npc then
			local dwTemplateID = npc.dwTemplateID
			RaidGrid_EventScrutiny.OnNpcCreationEvent(dwTemplateID, npc)
		end
	elseif szEvent == "NPC_LEAVE_SCENE" then
		local npc = GetNpc(arg0)
		if npc then
			local dwTemplateID = npc.dwTemplateID
			RaidGrid_EventScrutiny.OnNpcLeaveEvent(dwTemplateID, npc)
		end
	elseif szEvent == "LOADING_END" then
		RaidGrid_EventScrutiny.UpdateAnchor(this)
	elseif szEvent == "UI_SCALED" then
		RaidGrid_EventScrutiny.UpdateAnchor(this)
	elseif szEvent == "DO_SKILL_CAST" then
		RaidGrid_EventScrutiny.OnSkillCasting("DO_SKILL_CAST", arg0, arg1, arg2)--arg3 == Target.szName
	elseif szEvent == "SYS_MSG" then
		if arg0 == "UI_OME_SKILL_CAST_LOG" then
			RaidGrid_EventScrutiny.OnSkillCasting(arg0, arg1, arg2, arg3)
		elseif RaidGrid_EventScrutiny.bCastingScrutinyAllEnable then
			if arg0 == "UI_OME_SKILL_EFFECT_LOG" and arg4 == SKILL_EFFECT_TYPE.SKILL then
				RaidGrid_EventScrutiny.OnSkillCasting(arg0, arg1, arg5, arg6, arg2)
			elseif arg3 == SKILL_EFFECT_TYPE.SKILL and (arg0 == "UI_OME_SKILL_BLOCK_LOG" or arg0 == "UI_OME_SKILL_SHIELD_LOG" or arg0 == "UI_OME_SKILL_MISS_LOG" or arg0 == "UI_OME_SKILL_DODGE_LOG" or arg0 == "UI_OME_SKILL_HIT_LOG") then
				RaidGrid_EventScrutiny.OnSkillCasting(arg0, arg1, arg4, arg5, arg2)
			end
		end
	end
end


function _RE.AutoEnable(bEnable)
	if ARENAMAP then
		return JH.Sysmsg(_L["Arena not use the plug."])
	end
	local enable = RaidGrid_EventScrutiny.bEnable
	if RaidGrid_EventScrutiny.AutoEnable then
		if JH.IsInDungeon(true) then
			enable = true
		else
			enable = false
		end
	end
	if type(bEnable) == "boolean" then
		if bEnable then
			enable = true
		else
			enable = false
		end
	end
	if enable then
		if not RaidGrid_EventScrutiny.bEnable then
			RaidGrid_EventScrutiny.bEnable = true
			RaidGrid_EventScrutiny.OpenPanel()
		end
	else
		if RaidGrid_EventScrutiny.bEnable then
			RaidGrid_EventScrutiny.bEnable = false
			FireEvent("JH_ST_CLEAR")
			RaidGrid_EventScrutiny.ClosePanel()
		end
	end
end

----------------------------------------------------------------
----RaidGrid_Base.lua----
----------------------------------------------------------------
RaidGrid_Base = {}

RaidGrid_Base.version = 1
RegisterCustomData("RaidGrid_Base.version")

function RaidGrid_Base.TeamMarkOrg(dwID, nMark)
	local me = GetClientPlayer()
	local team = GetClientTeam()
	if me.IsInParty() and JH.IsMark() then
		local tPartyMark = team.GetTeamMark()
		if not tPartyMark[dwID] or tPartyMark[dwID] == 0 then
			team.SetTeamMark(nMark, dwID)
		end
	end
end

function RaidGrid_Base.SetTargetOrg(dwTargetID)
end

-- 发送数据给全团
function RaidGrid_Base.SendDataToTeam(data, szDataType, szClientName)
	local player = GetClientPlayer()
	local szDataType = szDataType or data.szType
	local szClientName = szClientName or "ALL"

	if player.IsInParty() then
		local team = GetClientTeam()
		local _GetName = team.GetClientTeamMemberName
		local szLeader = _GetName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER))
		if szLeader ~= player.szName then
			if not IsCtrlKeyDown() then
				return JH.Alert(_L["You are not team leader or not in team"])
			end
		end
		local str = JH.AscIIEncode(JH.JsonEncode(data))
		local nMax = 200
		local nTotle = math.ceil(#str / nMax)
		JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "RGES", "RE_SendSOpen", szClientName)
		for i = 1, nTotle do
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "RGES", "RE_SyncQueue", string.sub(str ,(i-1) * nMax + 1, i * nMax))
		end
		JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "RGES", "RE_SendClose", szDataType)
		JH.Sysmsg(_L["Send success, please wait 5 seconds."])
	else
		return JH.Alert(_L["You are not team leader or not in team"])
	end
end

function RaidGrid_Base.IsOutOfEventTime(tRecord, nRemoveDelayTime)
	nRemoveDelayTime = nRemoveDelayTime or 0
	if not tRecord.fEventTimeStart or not tRecord.fEventTimeEnd then
		tRecord.fEventTimeStart = nil
		tRecord.fEventTimeEnd = nil
		return true
	end

	local fCurrentLogicTime = JH.GetLogicTime()
	if fCurrentLogicTime < tRecord.fEventTimeStart or fCurrentLogicTime > tRecord.fEventTimeEnd + nRemoveDelayTime then
		return true
	end

	return false
end

function RaidGrid_Base.LowAverage(tNumbers)
	local nAvg = 0
	local nMax = 0
	local nMax2 = 0
	local nMax3 = 0
	if tNumbers then
		for j = 1, #tNumbers do
			if type(tNumbers[j]) == "number" then
				nAvg = nAvg + tNumbers[j]
				if tNumbers[j] > nMax then
					nMax3 = nMax2
					nMax2 = nMax
					nMax = tNumbers[j]
				elseif tNumbers[j] > nMax2 then
					nMax3 = nMax2
					nMax2 = tNumbers[j]
				elseif tNumbers[j] > nMax3 then
					nMax3 = tNumbers[j]
				end
			end
		end
		if #tNumbers >= 4 then
			nAvg = (nAvg - nMax - nMax2 - nMax3) / (#tNumbers - 3)
		elseif #tNumbers >= 1 then
			nAvg = nAvg / #tNumbers
		end
	end
	return nAvg
end

function RaidGrid_Base.GetNameAndTypeFromId(dwID)
	local KGTarget
	if dwID <= 0 then
		return _L["Unknown"]
	end
	if IsPlayer(dwID) then
		KGTarget = GetPlayer(dwID)
	else
		KGTarget = GetNpc(dwID)
	end
	if not KGTarget then
		return _L["Unknown"]
	else
		if IsPlayer(dwID) then
			return _L["(player)"] .. KGTarget.szName
		else
			return JH.GetTemplateName(KGTarget)
		end
	end
end

function RaidGrid_Base.OutputRecord(data,szType)
	JH.Alert(_L["You can modify the json, but do not modify the table."])
	local txt = ""
	if data then
		if szType then data.szType = szType end
		txt = JH.JsonEncode(data,true)
	end
	local wnd = GUI.CreateFrame("RGES_Info",{ w = 720,h = 500,title = _L["Json Data"],drag = true,close = true })
	wnd:Append("WndEdit","WndEdit",{ w = 660, h = 350, x = 0, y = 0, color = { 255,255,0 }, multi = true, limit = 999999,txt = txt }).data = data
	wnd:Append("WndButton3",{ x = 10, y = 370,txt = _L["import"] }):Click(function()
		local json = wnd:Fetch("WndEdit"):Text()
		local data = JH.JsonToTable(json)
		if not data or not data.szType then
			return JH.Alert("data is invalid")
		end
		RaidGrid_EventScrutiny.Macro(data)
		wnd:Fetch("WndEdit"):Text("")
	end)
	wnd:Append("WndButton3",{ x = 260, y = 370, txt = _L["decode"] }):Enable(JH.bDebug):Click(function()
		local json = wnd:Fetch("WndEdit"):Text()
		local data = JH.JsonToTable(json)
		if not data or not data.szType then
			return JH.Alert("data is invalid")
		end
		wnd:Fetch("WndEdit"):Text(var2str(data)).data = data
	end)
	wnd:Append("WndButton3",{ x = 510, y = 370, txt = _L["encode"] }):Enable(JH.bDebug):Click(function()
		if wnd:Fetch("WndEdit").data then
			local data = wnd:Fetch("WndEdit").data
			wnd:Fetch("WndEdit"):Text(JH.JsonEncode(data,true))
		else
			return JH.Alert("Please decode")
		end
	end)
end

function RaidGrid_Base.SaveSettingsNew()
	local _, _, szLang = GetVersion()
	local szName = "RGES-" .. szLang .. FormatTime("-%Y-%m-%d_%H.%M.%S", GetCurrentTime()) .. ".jx3dat"
	RaidGrid_Base.OutputSettingsFileNew(szName)
end

function RaidGrid_Base.LoadSettingsNew(bOverride)
	GetUserInput(_L["Please enter the file name"], function(szText)
		RaidGrid_Base.LoadSettingsFileNew(szText, bOverride)
	end)
end

function RaidGrid_Base.OutputSettingsFileNew(szName)
	local szFullName = "\\Interface\\JH\\RaidGrid_EventScrutiny\\alldat\\" .. szName
	local data = {}
	-- fix table.insert
	local tab, dat = {}, {}
	for k,v in ipairs(RaidGrid_BossCallAlert.tRecords.tWarningMessages) do
		if not tab[v.szText] then
			tab[v.szText] = true
			table.insert(dat, v)
		end
	end
	RaidGrid_BossCallAlert.tRecords.tWarningMessages = dat

	local tab, dat = {}, {}
	for k,v in ipairs(RaidGrid_BossCallAlert.tRecords.tBossCall) do
		if not tab[v.szText] then
			tab[v.szText] = true
			table.insert(dat, v)
		end
	end
	RaidGrid_BossCallAlert.tRecords.tBossCall = dat


	data.EventScrutinyRecords = RaidGrid_EventScrutiny.tRecords
	if RaidGrid_EventScrutiny.bOutputBossFaceData and type(Circle) ~= "nil" then
		data.Circle = Circle.GetData()
	end
	if RaidGrid_EventScrutiny.bOutputBossCallAlertRecords then
		data.BossCallAlertRecords = RaidGrid_BossCallAlert.tRecords
	end
	if RaidGrid_EventScrutiny.bOutputEventCacheRecords then
		data.EventCacheRecords = RaidGrid_EventCache.tRecords
	end
	local __DATA__ = clone(data)

	for k, v in pairs(RGES_ALL_TYPE) do -- 缩小数据
		__DATA__.EventScrutinyRecords[v].Hash = nil
		__DATA__.EventScrutinyRecords[v].Hash2 = nil
	end
	SaveLUAData(szFullName, __DATA__)
	JH.Alert(_L("Export complete\nPath:%s", GetRootPath().. szFullName))
end

function RaidGrid_Base.LoadSettingsFileNew(szName, bOverride)
	local szPath = "\\Interface\\JH\\RaidGrid_EventScrutiny\\alldat\\" .. szName

	local data = LoadLUAData(szPath)
	if not data then
		JH.Sysmsg2(_L["file path:"] .. GetRootPath() .. szPath)
		JH.Sysmsg2(_L["load Failed, Please check the file exists"])
		return
	else
		for k, v in pairs(RGES_ALL_TYPE) do -- 重建Hash
			data.EventScrutinyRecords[v].Hash = nil
			data.EventScrutinyRecords[v].Hash2 = nil
			HashChange(data.EventScrutinyRecords[v])
		end
	end

	if bOverride then
		if not data.EventScrutinyRecords then
			if data.Debuff then
				data.Scrutiny = RaidGrid_EventScrutiny.tRecords.Scrutiny
				RaidGrid_EventScrutiny.tRecords = data
				JH.Sysmsg(_L("Override %s data done", "RGES"))
			end
		else
			if RaidGrid_EventScrutiny.bOutputBossFaceData then
				if data.Circle and type(Circle) ~= "nil" then
					Circle.LoadCircleData(data, true)
				end
			end
			if RaidGrid_EventScrutiny.bOutputBossCallAlertRecords then
				if data.BossCallAlertRecords then
					RaidGrid_BossCallAlert.tRecords = data.BossCallAlertRecords
					JH.Sysmsg(_L("Override %s data done", "RaidGrid_BossCallAlert"))
				end
			end
			if RaidGrid_EventScrutiny.bOutputEventCacheRecords then
				if data.EventCacheRecords then
					RaidGrid_EventCache.tRecords = data.EventCacheRecords
					JH.Sysmsg(_L("Override %s data done", "RaidGrid_EventCache"))
				end
			end
			data.EventScrutinyRecords.Scrutiny = RaidGrid_EventScrutiny.tRecords.Scrutiny
			RaidGrid_EventScrutiny.tRecords = data.EventScrutinyRecords
			JH.Sysmsg(_L("Override %s data done", "RGES"))
		end
	else
		local _data = {}
		if not data.EventScrutinyRecords then -- 兼容之前的版本数据
			if data.Debuff then
				_data = data
			end
		else
			_data = data.EventScrutinyRecords
		end
		_data.Scrutiny = RaidGrid_EventScrutiny.tRecords.Scrutiny
		for szType, tInfo in pairs(_data) do
			if szType ~= "Scrutiny" then
				for i = #tInfo, 1, -1 do
					local dwID = tInfo[i].dwID
					if dwID then
						RaidGrid_EventScrutiny.AddRecordToList(tInfo[i], szType)
					end
				end
			end
		end
		JH.Sysmsg(_L("Merge %s data done","RGES"))
		if RaidGrid_EventScrutiny.bOutputBossFaceData then
			if data.Circle and type(Circle) ~= "nil" then
				Circle.LoadCircleMergeData(data)
			end
		end
		if RaidGrid_EventScrutiny.bOutputBossCallAlertRecords then -- 合并喊话数据
			if data.BossCallAlertRecords then
				for _,tInfo in pairs(data.BossCallAlertRecords.tBossCall) do
					table.insert(RaidGrid_BossCallAlert.tRecords.tBossCall,tInfo)
				end
				for _,tInfo in pairs(data.BossCallAlertRecords.tWarningMessages) do
					table.insert(RaidGrid_BossCallAlert.tRecords.tWarningMessages,tInfo)
				end
				JH.Sysmsg(_L("Merge %s data done","RaidGrid_BossCallAlert"))
			end
		end
	end

	-- fix table.insert
	local tab, data = {}, {}
	for k,v in ipairs(RaidGrid_BossCallAlert.tRecords.tWarningMessages) do
		if not tab[v.szText] then
			tab[v.szText] = true
			table.insert(data,v)
		end
	end
	RaidGrid_BossCallAlert.tRecords.tWarningMessages = data

	local tab, data = {}, {}
	for k,v in ipairs(RaidGrid_BossCallAlert.tRecords.tBossCall) do
		if not tab[v.szText] then
			tab[v.szText] = true
			table.insert(data,v)
		end
	end
	RaidGrid_BossCallAlert.tRecords.tBossCall = data

	RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
	JH.Sysmsg(_L["Loaded:"] .. GetRootPath() .. szPath)
	GUI.UnRegisterPanel(_L["Set Data"])
	collectgarbage("collect")
end

----------------------------------------------------------------
----RaidGrid_Base.lua----
----------------------------------------------------------------

----------------------------------------------------------------
----RaidGrid_EventCache.lua----
----------------------------------------------------------------

-- 每个BUFF或者DEBUFF需要有个功能就是提示团队里面那些人没有
-- 监控面板就是分成N页, 每页8个监控, 混合放
-- 监控倒计时过程是绿色和黄色, 实际发生了则变成红色重新读条
-- 提供复制粘贴功能

local szLastSearchText = ""
local nLastSearchIndex = 1
local szIniFileCache = RGES_INI_PATH .. "RaidGrid_EventCache.ini"

RaidGrid_EventCache = {}
RaidGrid_EventCache.bCheckBoxRecall = true
RaidGrid_EventCache.frameSelf = nil
RaidGrid_EventCache.wnd = nil
RaidGrid_EventCache.handleMain = nil
RaidGrid_EventCache.handleRecords = nil

RaidGrid_EventCache.tSyncEnemyChar = {}

RaidGrid_EventCache.szListIndex = "Buff";											RegisterCustomData("RaidGrid_EventCache.szListIndex")
RaidGrid_EventCache.tListPage = {Buff = 1, Debuff = 1, Npc = 1, Casting = 1};		RegisterCustomData("RaidGrid_EventCache.tListPage")
RaidGrid_EventCache.tRecords = {
	Buff = {Hash = {},Hash2 = {}},
	Debuff = {Hash = {},Hash2 = {}},
	Npc = {Hash = {},Hash2 = {}},
	Casting = {Hash = {},Hash2 = {}},
}

function RaidGrid_EventCache.OnFrameCreate()
	this:RegisterEvent("RENDER_FRAME_UPDATE")
	this:RegisterEvent("BUFF_UPDATE")
	this:RegisterEvent("NPC_ENTER_SCENE")
	this:RegisterEvent("NPC_LEAVE_SCENE")
	this:RegisterEvent("DO_SKILL_CAST")
	this:RegisterEvent("SYS_MSG")
	this:RegisterEvent("PLAYER_ENTER_SCENE")
end

function RaidGrid_EventCache.OnEvent(szEvent)
	if szEvent == "RENDER_FRAME_UPDATE" then
		if RaidGrid_EventScrutiny.frameSelf and RaidGrid_EventScrutiny.frameSelf:IsVisible() and RaidGrid_EventCache.frameSelf and RaidGrid_EventCache.frameSelf:IsVisible() then
			local cFrame = RaidGrid_EventCache.frameSelf
			local nW, nH = Station.GetClientSize()
			local nX, nY = RaidGrid_EventScrutiny.frameSelf:GetRelPos()
			local nThisW, nThisH = cFrame:GetSize()
			local nScrutinyW, nScrutinyH = RaidGrid_EventScrutiny.frameSelf:GetSize()
			if nX <= nW / 2 then
				cFrame:SetRelPos(nX + nScrutinyW, nY)
			else
				cFrame:SetRelPos(nX - nThisW, nY)
			end
		end
	elseif szEvent == "BUFF_UPDATE" then
		RaidGrid_EventCache.OnUpdateBuffDataOrg(arg0, arg1, arg2, arg4, arg5, arg6, arg8, arg9, arg3, arg7)
	elseif szEvent == "NPC_ENTER_SCENE" then
		local target = GetNpc(arg0)
		if target then
			RaidGrid_EventCache.tSyncEnemyChar[arg0] = target
			RaidGrid_EventCache.CheckEnemyNpcCreationOrg(target)

			local dwTemplateID = target.dwTemplateID
			local data = GetCacheData("Npc", dwTemplateID)
			if data then
				if data.bLinkNpcFightState then -- 需要检查战斗
					RGES_TABLE_NPC_FIGHT[dwTemplateID] = RGES_TABLE_NPC_FIGHT[dwTemplateID] or { bFightState = false, tList = {} }
					table.insert(RGES_TABLE_NPC_FIGHT[dwTemplateID].tList, arg0)
				end
				-- if data.tNpcLife then
				-- end
			end
		end
	elseif szEvent == "NPC_LEAVE_SCENE" then
		RaidGrid_EventCache.tSyncEnemyChar[arg0] = nil
	elseif szEvent == "DO_SKILL_CAST" then
		RaidGrid_EventCache.OnSkillCastingOrg(arg0, arg1, arg2)--arg3 == Target.szName
	elseif szEvent == "SYS_MSG" then
		if arg0 == "UI_OME_SKILL_CAST_LOG" then
			RaidGrid_EventCache.OnSkillCastingOrg(arg1, arg2, arg3)
		end
	elseif szEvent == "PLAYER_ENTER_SCENE" then
		local player = GetClientPlayer()
		if not player then
			return
		end
	end
end

function RaidGrid_EventCache.OnCheckBoxCheck()
	if not RaidGrid_EventCache.bCheckBoxRecall then
		return
	end
	local szName = this:GetName()
	if szName:match("CheckBox_Page_") then
		local szListIndex = szName:sub(15)
		RaidGrid_EventCache.SwitchPageType(szListIndex)
		if RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.wnd then
			RaidGrid_EventScrutiny.SwitchPageType(szListIndex)
		end
	end
end

function RaidGrid_EventCache.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_PrePage" then
		if IsCtrlKeyDown() then
			RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] = 1
		else
			RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] = math.max(1, RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] - 1)
		end
		RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)
	elseif szName == "Btn_NextPage" then
		local tTab = RaidGrid_EventCache.tRecords[RaidGrid_EventCache.szListIndex] or {}
		local nMaxPage = math.max(math.ceil(#tTab / 14), 1)
		local nCurrentPage = math.min((RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] or 0) + 1, nMaxPage)
		if IsCtrlKeyDown() then
			RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] = nMaxPage
		else
			RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] = nCurrentPage
		end
		RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)
	elseif szName == "Btn_Search" then
		local editSearch = RaidGrid_EventCache.wnd:Lookup("Edit_Search")
		local szText = editSearch:GetText()
		if szText and szText ~= "" then
			if not IsCtrlKeyDown() then
				local tTab = RaidGrid_EventCache.tRecords[RaidGrid_EventCache.szListIndex] or {}
				if szText ~= szLastSearchText or nLastSearchIndex >= #tTab then
					szLastSearchText = szText
					nLastSearchIndex = 1
				end
				local nLoopIndex = nLastSearchIndex
				for i = nLastSearchIndex, #tTab do
					nLoopIndex = nLoopIndex + 1
					local tInfo = tTab[i]
					if tInfo.szName and tostring(tInfo.szName):match(szText) then
						local nMaxPage = math.max(math.ceil(#tTab / 14), 1)
						local nCurrentPage = math.ceil(i / 14)
						RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] = nCurrentPage
						RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)

						local nShownIndex = i % 14
						if nShownIndex == 0 then
							nShownIndex = 14
						end
						local handleRecord = RaidGrid_EventCache.handleRecords:Lookup("Handle_Record_" .. nShownIndex)
						handleRecord:Lookup("Image_Search"):Show()
						break
					end
				end
				nLastSearchIndex = nLoopIndex
				if nLastSearchIndex >= #tTab then
					--JH.Sysmsg("已经搜索到列表结尾。")
				end
			elseif RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.wnd then
				local tTab = RaidGrid_EventScrutiny.tRecords[RaidGrid_EventCache.szListIndex] or {}
				if szText ~= szLastSearchText or nLastSearchIndex >= #tTab then
					szLastSearchText = szText
					nLastSearchIndex = 1
				end
				local nLoopIndex = nLastSearchIndex
				for i = nLastSearchIndex, #tTab do
					nLoopIndex = nLoopIndex + 1
					local tInfo = tTab[i]
					if tInfo.szName and tostring(tInfo.szName):match(szText) then
						local nMaxPage = math.max(math.ceil(#tTab / 8), 1)
						local nCurrentPage = math.ceil(i / 8)
						RaidGrid_EventScrutiny.tListPage[RaidGrid_EventCache.szListIndex] = nCurrentPage
						RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventCache.szListIndex)
						break
					end
				end
				for i = 0, 8 do
					nLastSearchIndex = nLoopIndex + i
					if nLastSearchIndex % 8 == 1 then
						break
					end
				end
			end
		end
	elseif szName == "Btn_DelPage" then
		if IsCtrlKeyDown() then
			local tTab = RaidGrid_EventCache.tRecords[RaidGrid_EventCache.szListIndex] or {}
			local nCurrentPage = RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] or 1
			local nStartIndex = (nCurrentPage - 1) * 14 + 1
			for i = 0, 13 do
				if tTab[nStartIndex] and tTab[nStartIndex].dwID then
					if tTab.Hash2[tTab[nStartIndex].dwID] and tTab[nStartIndex].nLevel then
						tTab.Hash2[tTab[nStartIndex].dwID][tTab[nStartIndex].nLevel] = nil
					end
					if not tTab.Hash2[tTab[nStartIndex].dwID] or IsTableEmpty(tTab.Hash2[tTab[nStartIndex].dwID]) then
						tTab.Hash2[tTab[nStartIndex].dwID] = nil
						tTab.Hash[tTab[nStartIndex].dwID] = nil
					end
					table.remove(tTab, nStartIndex)
				end
			end
			local nMaxPage = math.max(math.ceil(#tTab / 14), 1)
			RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] = math.min(nCurrentPage, nMaxPage)
			RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)
		elseif IsShiftKeyDown() then
			RaidGrid_EventCache.tRecords[RaidGrid_EventCache.szListIndex] = {Hash = {},Hash2 = {}}
			RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] = 1
			RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)
		end
	elseif szName == "Btn_Close" then
		RaidGrid_EventCache.ClosePanel()
	end
end

-----------------------------------------------------------------------------------------------------------------------------
function RaidGrid_EventCache.SwitchPageType(szListIndex)
	if not RaidGrid_EventCache.tListPage[szListIndex] then
		return
	end
	if not RaidGrid_EventCache.bCheckBoxRecall then
		return
	end
	RaidGrid_EventCache.bCheckBoxRecall = false

	RaidGrid_EventCache.szListIndex = szListIndex
	for szKey, _ in pairs(RaidGrid_EventCache.tListPage) do
		local checkBox = RaidGrid_EventCache.wnd:Lookup("CheckBox_Page_" .. szKey)
		if szListIndex == szKey then
			checkBox:Check(true)
			checkBox:Enable(false)
		else
			checkBox:Check(false)
			checkBox:Enable(true)
		end
	end
	RaidGrid_EventCache.UpdateRecordList(szListIndex)

	RaidGrid_EventCache.bCheckBoxRecall = true
end


function RaidGrid_EventCache.OnSkillCastingOrg(dwID, dwSkillID, dwSkillLevel, szTargetIDOrName)
	local player = GetClientPlayer()
	if not player then
		return
	end

	if not RaidGrid_EventScrutiny.bEnable then
		return
	end

	if not RaidGrid_EventScrutiny.bCacheEnable then
		return
	end


	local bUpdate = false

	local target
	if GetPlayer(dwID) then
		target = GetPlayer(dwID)
	elseif GetNpc(dwID) then
		target = GetNpc(dwID)
	else
		return
	end

	if target then
		if (not RaidGrid_EventCache.tRecords.Casting.Hash2[dwSkillID] or not RaidGrid_EventCache.tRecords.Casting.Hash2[dwSkillID][dwSkillLevel]) then
			local szSkillName = Table_GetSkillName(dwSkillID, dwSkillLevel)
			if not szSkillName or szSkillName == "" then
				szSkillName = _L["NONE"] .. tostring(dwSkillID)
				if not JH.bDebugClient then
					return -- 和谐
				end
			end
			if szSkillName then
				local tRecord = {}
				tRecord.szType = "Casting"

				tRecord.dwID = dwSkillID
				tRecord.nLevel = dwSkillLevel
				tRecord.szName = szSkillName
				tRecord.nIconID = Table_GetSkillIconID(dwSkillID, dwSkillLevel) or 332
				if tRecord.nIconID <= 0 then
					tRecord.nIconID = 332
				end
				tRecord.szMapName = Table_GetMapName(player.GetMapID()) or _L["Unknown"]
				tRecord.szCasterName = target.szName or _L["Unknown"]

				RaidGrid_EventCache.tRecords.Casting.Hash[dwSkillID] = true
				RaidGrid_EventCache.tRecords.Casting.Hash2[dwSkillID] = RaidGrid_EventCache.tRecords.Casting.Hash2[dwSkillID] or {}
				RaidGrid_EventCache.tRecords.Casting.Hash2[dwSkillID][dwSkillLevel] = true

				table.insert(RaidGrid_EventCache.tRecords.Casting, 1, tRecord)

				if RaidGrid_EventScrutiny.nCastingAutoRemoveCachePage then
					local nStartLoopIndex = 14 * RaidGrid_EventScrutiny.nCastingAutoRemoveCachePage + 1
					for i = nStartLoopIndex, #RaidGrid_EventCache.tRecords.Casting do
						if RaidGrid_EventCache.tRecords.Casting.Hash2[RaidGrid_EventCache.tRecords.Casting[i].dwID] then
							RaidGrid_EventCache.tRecords.Casting.Hash2[RaidGrid_EventCache.tRecords.Casting[i].dwID][RaidGrid_EventCache.tRecords.Casting[i].nLevel] = nil
						end
						if not RaidGrid_EventCache.tRecords.Casting.Hash2[RaidGrid_EventCache.tRecords.Casting[i].dwID] or IsTableEmpty(RaidGrid_EventCache.tRecords.Casting.Hash2[RaidGrid_EventCache.tRecords.Casting[i].dwID]) then
							RaidGrid_EventCache.tRecords.Casting.Hash2[RaidGrid_EventCache.tRecords.Casting[i].dwID] = nil
							RaidGrid_EventCache.tRecords.Casting.Hash[RaidGrid_EventCache.tRecords.Casting[i].dwID] = nil
						end
						RaidGrid_EventCache.tRecords.Casting[i] = nil
					end
				end
				bUpdate = true
			end
		end
	end

	if RaidGrid_EventCache.szListIndex == "Casting" and bUpdate then
		RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)
	end
end

function RaidGrid_EventCache.CheckEnemyNpcCreationOrg(npc)
	local player = GetClientPlayer()
	if not player then
		return
	end

	if not npc then
		return
	end

	if not RaidGrid_EventScrutiny.bEnable then
		return
	end

	if not RaidGrid_EventScrutiny.bCacheEnable then
		return
	end

	if RaidGrid_EventCache.tRecords.Npc.Hash[npc.dwTemplateID] then
		return
	end

	local tRecord = {}
	tRecord.szType = "Npc"
	local szNpcName = JH.GetTemplateName(npc)
	tRecord.dwID = npc.dwTemplateID
	tRecord.szName = szNpcName
	if not tRecord.szName or tRecord.szName == "" then
		tRecord.szName = tostring(npc.dwTemplateID)
	end
	local _, nIconFrame = GetNpcHeadImage(npc.dwID)
	tRecord.nIconFrame = nIconFrame

	if IsEnemy(player.dwID, npc.dwID) then
		tRecord.bEnemy = true
	else
		tRecord.bEnemy = false
	end

	tRecord.szMapName = Table_GetMapName(player.GetMapID()) or _L["Unknown"]
	if GetNpcIntensity(npc) >= 4 then
		tRecord.bBossIntensity = true
	end

	RaidGrid_EventCache.tRecords.Npc.Hash[npc.dwTemplateID] = true
	table.insert(RaidGrid_EventCache.tRecords.Npc, 1, tRecord)

	if RaidGrid_EventScrutiny.nNpcAutoRemoveCachePage then
		local nStartLoopIndex = 14 * RaidGrid_EventScrutiny.nNpcAutoRemoveCachePage + 1
		for i = nStartLoopIndex, #RaidGrid_EventCache.tRecords.Npc do
			RaidGrid_EventCache.tRecords.Npc.Hash[RaidGrid_EventCache.tRecords.Npc[i].dwID] = nil
			RaidGrid_EventCache.tRecords.Npc[i] = nil
		end
	end
	if RaidGrid_EventCache.szListIndex == "Npc" then
		RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)
	end
end

-- On BUFF_UPDATE [dwMemberID:arg0, bIsRemoved:arg1, nIndex:arg2, dwBuffID:arg4, nStackNum:arg5, nEndFrame:arg6, nLevel:arg8]
function RaidGrid_EventCache.OnUpdateBuffDataOrg(dwMemberID, bIsRemoved, nIndex, dwBuffID, nStackNum, nEndFrame, nLevel, dwSkillSrcID, Arg3, Arg7)
	nLevel = nLevel or 1
	local player = GetClientPlayer()

	if not RaidGrid_EventScrutiny.bEnable then
		return
	end

	if not RaidGrid_EventScrutiny.bCacheEnable then
		return
	end

	local playerMember
	if IsPlayer(dwMemberID) then
		playerMember = GetPlayer(dwMemberID)
	else
		playerMember = GetNpc(dwMemberID)
	end

	if bIsRemoved or not player or not playerMember then
		return
	end

	if not dwBuffID or dwBuffID <= 0 then
		return
	end

	if nLevel <= 0 then
		return
	end

	local bIsVisible = Table_BuffIsVisible(dwBuffID, nLevel)
	if not bIsVisible and not JH.bDebugClient then
		return
	end
	local szBuffName = Table_GetBuffName(dwBuffID, nLevel)
	if not szBuffName or szBuffName == "" then
		szBuffName = _L["NONE"] .. tostring(dwBuffID)
	end
	local _,buff = JH.HasBuff(dwBuffID,playerMember)
	local tTab = RaidGrid_EventCache.tRecords.Buff
	if not Arg3 then
		tTab = RaidGrid_EventCache.tRecords.Debuff
	end
	if tTab.Hash2[dwBuffID] and tTab.Hash2[dwBuffID][nLevel] then
		return
	end

	local tRecord = {}
	tRecord.szType = "Buff"
	if not Arg3 then
		tRecord.szType = "Debuff"
	end

	tRecord.dwID = dwBuffID
	tRecord.nLevel = nLevel
	tRecord.szName = szBuffName
	tRecord.nIconID = Table_GetBuffIconID(dwBuffID, nLevel) or 1435
	if tRecord.nIconID <= 0 then
		tRecord.nIconID = 1435
	end

	local nLogicFrame = GetLogicFrameCount()
	nEndFrame = nEndFrame or nLogicFrame
	tRecord.fKeepTime = ((nEndFrame - nLogicFrame) / GLOBAL.GAME_FPS) or 0

	tRecord.szMapName = Table_GetMapName(player.GetMapID()) or _L["Unknown"]

	if buff.dwSkillSrcID and buff.dwSkillSrcID>0 then
		tRecord.szCasterName = RaidGrid_Base.GetNameAndTypeFromId(buff.dwSkillSrcID)
	end

	if IsBuffDispel then
		if IsBuffDispel(dwBuffID, nLevel) then
			tRecord.bIsBuffDispel = true
		end
	end

	tTab.Hash[dwBuffID] = true
	tTab.Hash2[dwBuffID] = tTab.Hash2[dwBuffID] or {}
	tTab.Hash2[dwBuffID][nLevel] = true

	table.insert(tTab, 1, tRecord)

	if RaidGrid_EventScrutiny.nBuffAutoRemoveCachePage then
		local nStartLoopIndex = 14 * RaidGrid_EventScrutiny.nBuffAutoRemoveCachePage + 1
		for i = nStartLoopIndex, #tTab do
			if tTab.Hash2[tTab[i].dwID] then
				tTab.Hash2[tTab[i].dwID][tTab[i].nLevel] = nil
			end
			if not tTab.Hash2[tTab[i].dwID] or IsTableEmpty(tTab.Hash2[tTab[i].dwID]) then
				tTab.Hash2[tTab[i].dwID] = nil
				tTab.Hash[tTab[i].dwID] = nil
			end
			tTab[i] = nil
		end
	end
	if RaidGrid_EventCache.szListIndex == tRecord.szType then
		RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)
	end
end

function RaidGrid_EventCache.InitRecordHandles()
	local handle = RaidGrid_EventCache.handleRecords
	if not handle then
		return
	end
	handle:Clear()

	for i = 1, 14 do
		local handleRecord = handle:AppendItemFromIni(szIniFileCache, "Handle_RecordDummy", "Handle_Record_" .. i)
		handleRecord:SetRelPos(0, (i - 1) * 24.7 + 3)
		handleRecord.OnItemMouseEnter = function()
			this.imageCover:Show()
		end
		handleRecord.OnItemMouseLeave = function()
			this.imageCover:Hide()
		end
		handleRecord.OnItemLButtonClick = function()

		end
		handleRecord.OnItemRButtonClick = function()
			RaidGrid_EventCache.PopRBOptions(this)
		end

		handleRecord.box = handleRecord:Lookup("Box_Icon")
		handleRecord.box:Show()
		handleRecord.box:SetObject(1,0)
		handleRecord.box:ClearObjectIcon()
		handleRecord.box:SetObjectIcon(1435)
		handleRecord.box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
		handleRecord.box:SetOverTextFontScheme(0, 15)
		handleRecord.box:SetOverText(0, "")
		handleRecord.box.handleParent = handleRecord
		handleRecord.box.OnItemMouseEnter = function()
			local tRecord = this.handleParent.tRecord
			if tRecord and tRecord.dwID then
				local x, y = this:GetAbsPos()
				local w, h = this:GetSize()
				if tRecord.szType == "Buff" or tRecord.szType == "Debuff" then
					OutputBuffTip(GetClientPlayer().dwID, tRecord.dwID, tRecord.nLevel or 1, 1, false, 999, {x, y, w, h})
				elseif tRecord.szType == "Npc" then
					OutputNpcTip2(tRecord.dwID, {x, y, w, h})
				elseif tRecord.szType == "Casting" then
					OutputSkillTip(tRecord.dwID, tRecord.nLevel or 1, {x, y, w, h})
				end
			end
		end
		handleRecord.box.OnItemMouseLeave = function()
			HideTip()
		end

		handleRecord.imageBoxBG = handleRecord:Lookup("Image_BGBox")
		handleRecord.imageBoxBG.handleParent = handleRecord
		handleRecord.imageBoxBG.OnItemMouseEnter = handleRecord.box.OnItemMouseEnter
		handleRecord.imageBoxBG.OnItemMouseLeave = handleRecord.box.OnItemMouseLeave

		handleRecord.text = handleRecord:Lookup("Text_Name")
		handleRecord.text:SetText("")

		handleRecord.imageGrid = handleRecord:Lookup("Image_BGGrid")
		handleRecord.imageGrid.nFrame = 999

		handleRecord.imageCover = handleRecord:Lookup("Image_Cover")

		handleRecord:Hide()
	end

	handle:FormatAllItemPos()
end

function RaidGrid_EventCache.ClearRecordHandle(handleRecord)
	if not handleRecord then
		return
	end
	handleRecord.box:SetObjectIcon(1435)
	handleRecord.dwID = nil
	handleRecord.tRecord = nil
	handleRecord:Hide()
end

function RaidGrid_EventCache.ShowRecordHandle(handleRecord, tRecord)
	if not handleRecord or not tRecord then
		return
	end

	handleRecord:Lookup("Image_Search"):Hide()

	handleRecord.dwID = tRecord.dwID
	handleRecord.tRecord = tRecord

	local szName = tRecord.szName
	if tRecord.bIsBuffDispel then
		szName = szName .. _L["`dispel"]
	end
	handleRecord.text:SetText(szName)



	if tRecord.bEnemy == true then
		handleRecord.text:SetFontColor(255, 128, 128)
	elseif tRecord.bEnemy == false then
		handleRecord.text:SetFontColor(255, 255, 128)
	else
		handleRecord.text:SetFontColor(255, 255, 255)
	end

	if RaidGrid_EventScrutiny.IsRecordInList(tRecord, RaidGrid_EventCache.szListIndex) then
		handleRecord.text:SetFontColor(155,155,155)
		handleRecord.box:IconToGray()
	else
		handleRecord.box:IconToNormal()
	end

	if tRecord.szType == "Debuff" and handleRecord.imageGrid.nFrame ~= 1 then
		handleRecord.imageGrid:SetFrame(1)
	elseif tRecord.szType == "Buff" and handleRecord.imageGrid.nFrame ~= 13 then
		handleRecord.imageGrid:SetFrame(13)
	elseif handleRecord.imageGrid.nFrame ~= 14 then
		handleRecord.imageGrid:SetFrame(14)
	end

	handleRecord.box:SetObjectIcon(tRecord.nIconID or 1435)
	if tRecord.szType == "Npc" then
		handleRecord.box:Hide()
		if tRecord.nIconFrame then
			handleRecord.imageBoxBG:FromUITex("ui/Image/TargetPanel/Target.UITex", tRecord.nIconFrame)
		else
			handleRecord.imageBoxBG:FromTextureFile("ui/Image/TargetPanel/Target.UITex")
		end
	else
		handleRecord.box:Show()
	end

	handleRecord:Show()
end

function RaidGrid_EventCache.UpdateRecordList(szListIndex)
	local handle = RaidGrid_EventCache.handleRecords
	if not handle then
		return
	end

	local tTab = RaidGrid_EventCache.tRecords[RaidGrid_EventCache.szListIndex]
	if not tTab then
		return
	end

	local nMaxPage = math.max(math.ceil(#tTab / 14), 1)
	local nCurrentPage = math.min(RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] or 1, nMaxPage)
	RaidGrid_EventCache.tListPage[szListIndex] = nCurrentPage
	RaidGrid_EventCache.handleMain:Lookup("Text_PageCurrent"):SetText(nCurrentPage)

	local nStartIndex = 14 * (nCurrentPage - 1) + 1
	for i = 1, 14 do
		local handleRecord = handle:Lookup("Handle_Record_" .. i)
		if handleRecord then
			local tRecord = tTab[nStartIndex + i - 1]
			if tRecord then
				RaidGrid_EventCache.ShowRecordHandle(handleRecord, tRecord)
			else
				RaidGrid_EventCache.ClearRecordHandle(handleRecord)
			end
		end
	end
end

function RaidGrid_EventCache.OpenPanel()
	local frame = Station.Lookup("Normal/RaidGrid_EventCache")
	if not frame then
		frame = Wnd.OpenWindow(RGES_INI_PATH .. "RaidGrid_EventCache.ini", "RaidGrid_EventCache")
	end
	frame:Show()
	frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)

	RaidGrid_EventCache.frameSelf = frame
	RaidGrid_EventCache.wnd = frame:Lookup("Wnd_Cache")
	RaidGrid_EventCache.handleMain = RaidGrid_EventCache.wnd:Lookup("", "")
	RaidGrid_EventCache.handleRecords = RaidGrid_EventCache.handleMain:Lookup("Handle_Caches")

	RaidGrid_EventCache.handleMain:Lookup("Handle_RecordDummy"):Hide()

	RaidGrid_EventCache.InitRecordHandles()
	RaidGrid_EventCache.SwitchPageType(RaidGrid_EventCache.szListIndex)
end

function RaidGrid_EventCache.IsOpened()
	local frame = Station.Lookup("Normal/RaidGrid_EventCache")
	if frame then
		return frame:IsVisible()
	end
end

function RaidGrid_EventCache.ClosePanel()
	local frame = Station.Lookup("Normal/RaidGrid_EventCache")
	if frame then
		frame:Hide()
	end
end

----------------------------------------------------------------
----RaidGrid_EventCache.lua----
----------------------------------------------------------------

----------------------------------------------------------------
----RaidGrid_EventScrutiny.lua----
----------------------------------------------------------------

local szIniFileScrutiny = RGES_INI_PATH .. "RaidGrid_EventScrutiny.ini"
AUTO_EVENTTIME_MODE = {NONE = 1, AVG = 2, MIN = 3}


RaidGrid_EventScrutiny.bCheckBoxRecall = true
RaidGrid_EventScrutiny.frameSelf = nil
RaidGrid_EventScrutiny.wnd = nil
RaidGrid_EventScrutiny.handleMain = nil
RaidGrid_EventScrutiny.handleRecords = nil

RaidGrid_EventScrutiny.szListIndex = "Scrutiny";													RegisterCustomData("RaidGrid_EventScrutiny.szListIndex")
RaidGrid_EventScrutiny.tListPage = {Buff = 1, Debuff = 1, Npc = 1, Casting = 1, Scrutiny = 1};		RegisterCustomData("RaidGrid_EventScrutiny.tListPage")
RaidGrid_EventScrutiny.tRecords = {
	Buff = {Hash = {},Hash2 = {}},
	Debuff = {Hash = {},Hash2 = {}},
	Npc = {Hash = {},Hash2 = {}},
	Casting = {Hash = {},Hash2 = {}},
	Scrutiny = {Hash = {},Hash2 = {}},
};

function RaidGrid_EventScrutiny._SetItemUI(szName,obj,boolean)
	local _U = tRaidGrid_EventScrutinyTextUI
	if _U[szName] then
		if not boolean then
			obj:Lookup(_U[szName][1]):SetFontColor(_U[szName][2][1],_U[szName][2][2],_U[szName][2][3])
		else
			local r,g,b = _U[szName][3][1],_U[szName][3][2],_U[szName][3][3]
			obj:Lookup(_U[szName][1]):SetFontColor(r,g,b)
		end
	end
end

tRaidGrid_EventScrutinyTextUI = {
	Image_WBox = {
		"Text_WBox",{120,120,120},{255,0,255},"bChatAlertW",nil,_L["WhisperAlert"]
	},
	Image_TBox = {
		"Text_TBox",{120,120,120},{64,128,255},"bChatAlertT",nil,_L["RaidAlert"]
	},
	Image_SBox = {
		"Text_SBox",{120,120,120},{250,100,15},"bBigFontAlarm",nil,_L["LargeText"]
	},
	Image_TSBox = {
		"Text_TSBox",{120,120,120},{250,100,15},"tRGAutoSelect",nil,"该功能已无效"
	},
	Image_ABox = {
		"Text_ABox",{120,120,120},{250,100,15},"tRGCenterAlarm",nil,_L["CenterAlarm"]
	},
	Image_ASBox = {
		"Text_ASBox",{120,120,120},{250,100,15},"bFullScreenAlert",nil,_L["FlashAlert"]},
}

function RaidGrid_EventScrutiny.OnItemMouseEnter()
	local szName = this:GetName()
	local handleRecord = this:GetParent()
	local _U = tRaidGrid_EventScrutinyTextUI
	local x, y = this:GetAbsPos()
	local w, h = this:GetSize()
	if _U[szName] then
		local szText="<text>text=\"".._U[szName][6].."\" font=15 </text>"
		local r,g,b = _U[szName][3][1],_U[szName][3][2],_U[szName][3][3]
		handleRecord:Lookup(_U[szName][1]):SetFontColor(r,g,b)
		OutputTip(szText, 450, {x, y, w, h})
	end
end

function RaidGrid_EventScrutiny.SetItemUI(szName,obj,tRecord,action)
	local _U = tRaidGrid_EventScrutinyTextUI
	if _U[szName] then
		if tRecord[_U[szName][4]] then
			if action == "OnItemLButtonClick" then
				if type(_U[szName][5]) == "function" then
					_U[szName][5](szName,obj,tRecord)
				else
					tRecord[_U[szName][4]] = nil
					return obj:Lookup(_U[szName][1]):SetFontColor(_U[szName][2][1],_U[szName][2][2],_U[szName][2][3])
				end
			end
			local r,g,b = _U[szName][3][1],_U[szName][3][2],_U[szName][3][3]
			obj:Lookup(_U[szName][1]):SetFontColor(r,g,b)
		else
			if action == "OnItemLButtonClick" then
				if type(_U[szName][5]) == "function" then
					_U[szName][5](szName,obj,tRecord)
				else
					tRecord[_U[szName][4]] = true
					return obj:Lookup(_U[szName][1]):SetFontColor(_U[szName][3][1],_U[szName][3][2],_U[szName][3][3])
				end
			end
			obj:Lookup(_U[szName][1]):SetFontColor(_U[szName][2][1],_U[szName][2][2],_U[szName][2][3])
		end
	end

end

function RaidGrid_EventScrutiny.OnItemMouseLeave()
	local szName = this:GetName()
	local handleRecord = this:GetParent()
	RaidGrid_EventScrutiny.SetItemUI(szName,handleRecord,handleRecord.tRecord,false)
end

function RaidGrid_EventScrutiny.OnItemLButtonClick()
	local szName = this:GetName()
	local handleRecord = this:GetParent()
	RaidGrid_EventScrutiny.SetItemUI(szName,handleRecord,handleRecord.tRecord,"OnItemLButtonClick")
end


function RaidGrid_EventScrutiny.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_PrePage" then
		if IsCtrlKeyDown() then
			RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] = 1
		else
			RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] = math.max(1, RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] - 1)
		end
		RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
	elseif szName == "Btn_NextPage" then
		local tTab = RaidGrid_EventScrutiny.tRecords[RaidGrid_EventScrutiny.szListIndex] or {}
		local nMaxPage = math.max(math.ceil(#tTab / 8), 1)
		local nCurrentPage = math.min((RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] or 0) + 1, nMaxPage)
		if IsCtrlKeyDown() then
			RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] = nMaxPage
		else
			RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] = nCurrentPage
		end
		RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
	elseif szName == "Btn_DelPage" then
		if IsCtrlKeyDown() then
			local tTab = RaidGrid_EventScrutiny.tRecords[RaidGrid_EventScrutiny.szListIndex] or {}
			local nCurrentPage = RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] or 1
			local nStartIndex = (nCurrentPage - 1) * 8 + 1
			for i = 0, 7 do
				if tTab[nStartIndex] and tTab[nStartIndex].dwID then
					if tTab.Hash2[tTab[nStartIndex].dwID] and tTab[nStartIndex].nLevel then
						tTab.Hash2[tTab[nStartIndex].dwID][tTab[nStartIndex].nLevel] = nil
					end
					if not tTab.Hash2[tTab[nStartIndex].dwID] or IsTableEmpty(tTab.Hash2[tTab[nStartIndex].dwID]) then
						tTab.Hash2[tTab[nStartIndex].dwID] = nil
						tTab.Hash[tTab[nStartIndex].dwID] = nil
					end
					table.remove(tTab, nStartIndex)
				end
			end
			local nMaxPage = math.max(math.ceil(#tTab / 8), 1)
			RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] = math.min(nCurrentPage, nMaxPage)
			RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
		elseif IsShiftKeyDown() then
			RaidGrid_EventScrutiny.tRecords[RaidGrid_EventScrutiny.szListIndex] = {Hash = {},Hash2 = {}}
			RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] = 1
			RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
		end
	elseif szName == "Btn_Close" then
		RaidGrid_EventScrutiny.ClosePanel()
	elseif szName == "Btn_Options" then
		RaidGrid_EventScrutiny.PopMainOptions()
	end
end

function RaidGrid_EventScrutiny.OnCheckBoxCheck()
	if not RaidGrid_EventScrutiny.bCheckBoxRecall then
		return
	end

	local szName = this:GetName()
	if szName:match("CheckBox_Page_") then
		local szListIndex = szName:sub(15)
		RaidGrid_EventScrutiny.SwitchPageType(szListIndex)
		if szListIndex ~= "Scrutiny" then
			if not RaidGrid_EventCache.IsOpened() then
				RaidGrid_EventCache.OpenPanel()
			end
			RaidGrid_EventCache.SwitchPageType(szListIndex)
		else
			RaidGrid_EventCache.ClosePanel()
		end
	elseif szName:match("CheckBox_SelfBuff") then
		RaidGrid_EventScrutiny.bBuffChatAlertEnable = true
		RaidGrid_EventScrutiny.bCastingChatAlertEnable = true
		RaidGrid_EventScrutiny.bNpcChatAlertEnable = true
		RaidGrid_BossCallAlert.bChatAlertEnable = true
		RaidGrid_EventScrutiny.bSkillTimerSay = true
	end
end

function RaidGrid_EventScrutiny.OnCheckBoxUncheck()
	if not RaidGrid_EventScrutiny.bCheckBoxRecall then
		return
	end
	local szName = this:GetName()
	if szName:match("CheckBox_SelfBuff") then
		RaidGrid_EventScrutiny.bBuffChatAlertEnable = false
		RaidGrid_EventScrutiny.bCastingChatAlertEnable = false
		RaidGrid_EventScrutiny.bNpcChatAlertEnable = false
		RaidGrid_BossCallAlert.bChatAlertEnable = false
		RaidGrid_EventScrutiny.bSkillTimerSay = false
	end
end

function RaidGrid_EventScrutiny.UpdateAlarmAndSelectOrg(dwTargetID, tRecord, msg, bNotSelect)
	if not tRecord then
		return
	end

	if not bNotSelect and tRecord.tRGAutoSelect then
		RaidGrid_Base.SetTargetOrg(dwTargetID)
	end

	if RaidGrid_EventScrutiny.bRedAlarmEnable or RaidGrid_EventScrutiny.bCenterAlarmEnable then
		local player = GetClientPlayer()
		local bOtherPlayer = false
		if player.dwID ~= dwTargetID and IsPlayer(dwTargetID) and player.IsPlayerInMyParty(dwTargetID) then
			bOtherPlayer = true
		end

		local nRGRAR, nRGRAG, nRGRAB = 255, 0, 0
		local bRedAlarm = false
		local bCenterAlarm = false
		if RaidGrid_EventScrutiny.bRedAlarmEnable and tRecord.tRGRedAlarm then
			nRGRAR, nRGRAG, nRGRAB = tRecord.tRGRedAlarm[1], tRecord.tRGRedAlarm[2], tRecord.tRGRedAlarm[3]
			bRedAlarm = true
		end
		if RaidGrid_EventScrutiny.bCenterAlarmEnable and tRecord.tRGCenterAlarm then
			bCenterAlarm = true
		end

		if tRecord.tRGRedAlarmSelf and bOtherPlayer then
			bRedAlarm = false
		end
		if tRecord.tRGCenterAlarmSelf and bOtherPlayer then
			bCenterAlarm = false
		end
		if bRedAlarm or bCenterAlarm then
			RaidGrid_RedAlarm.FlashOrg(RaidGrid_EventScrutiny.nCenterAlarmTime, msg, bRedAlarm, bCenterAlarm, nRGRAR, nRGRAG, nRGRAB)
		end
	end

end

-- On BUFF_UPDATE [dwMemberID:arg0, bIsRemoved:arg1, nIndex:arg2, dwBuffID:arg4, nStackNum:arg5, nEndFrame:arg6, nLevel:arg8]
function RaidGrid_EventScrutiny.OnUpdateBuffData(dwMemberID, bIsRemoved, nIndex, dwBuffID, nStackNum, nEndFrame, nLevel, dwSkillSrcID, Arg3)
	nLevel = nLevel or 1
	local player = GetClientPlayer()

	if not player then
		return
	end

	if not RaidGrid_EventScrutiny.bEnable then
		return
	end

	local playerMember
	if IsPlayer(dwMemberID) then
		playerMember = GetPlayer(dwMemberID)
	else
		playerMember = GetNpc(dwMemberID)
	end
	if not playerMember then
		return
	end

	if not dwBuffID or dwBuffID <= 0 then
		return
	end

	if nLevel <= 0 then
		return
	end

	local szType = "Debuff"
	if Arg3 then
		szType = "Buff"
	end

	local nLogicFrame = GetLogicFrameCount()
	nEndFrame = nEndFrame or nLogicFrame
	local fLogicTime = -1
	if not bIsRemoved then
		fLogicTime = (nEndFrame - nLogicFrame) / GLOBAL.GAME_FPS
	end
	local data = GetCacheData(szType, dwBuffID, nLevel)
	if data then
		if data.nRelScrutinyType then
			if data.nRelScrutinyType == 1 then
				--szRelScrutinyType = "只监控自己"
				if player.dwID ~= dwMemberID then
					return
				end
			elseif data.nRelScrutinyType == 2 then
				--szRelScrutinyType = "队友和自己"
				if player.dwID ~= dwMemberID and not player.IsPlayerInMyParty(dwMemberID) then
					return
				end
			elseif data.nRelScrutinyType == -1 then
				--szRelScrutinyType = "只监控敌方"
				if not IsEnemy(player.dwID, dwMemberID) then
					return
				end
			elseif data.nRelScrutinyType == -2 then
				--szRelScrutinyType = "只监控非队友"
				if player.dwID == dwMemberID or player.IsPlayerInMyParty(dwMemberID) then
					return
				end
			end
		end
		local szBuffName = Table_GetBuffName(dwBuffID, nLevel)
		if not szBuffName then return end -- 和谐
		if not szBuffName or szBuffName == "" then
			szBuffName = data.szName or "????"
		end
		if fLogicTime <= 0 then
			if player.dwID == dwMemberID then
				RaidGrid_SelfBuffAlert.UpdateSelfBuffAlertOrg(data, dwMemberID, bIsRemoved, nIndex, dwBuffID, nStackNum, nEndFrame, nLevel)
			end
			data.fEventTimeEnd = JH.GetLogicTime()
		elseif not data.nEventAlertStackNum or (data.nEventAlertStackNum <= nStackNum) then
			data.fEventTimeStart = JH.GetLogicTime()
			data.nEventAlertTime = fLogicTime
			data.fEventTimeEnd = data.fEventTimeStart + data.nEventAlertTime
			if player.dwID == dwMemberID then
				if not data.bNotAddSelfBuffAlert then
					RaidGrid_SelfBuffAlert.UpdateSelfBuffAlertOrg(data, dwMemberID, bIsRemoved, nIndex, dwBuffID, nStackNum, nEndFrame, nLevel)
				end
				if data.bFullScreenAlert and RaidGrid_EventScrutiny.bColorAlertEnable then
					FireEvent("JH_FS_CREATE", "bUFF"--[[data.dwID .. "_"  ..data.nLevel]], {
						nTime = 3,
						col = data.tRGBuffColor,
						tBindBuff = { data.dwID, data.nLevel }
					})
				end
			end
			if playerMember and ((not data.bManyMembers) or ((data.bChatAlertCDEnd or 0) <= data.fEventTimeStart)) then
				local sztInfoadd = ""
				if data.bManyMembers then
					data.bChatAlertCDEnd = data.fEventTimeStart + tonumber(data.nMinChatAlertCD or 7)
					sztInfoadd = "（多人或连续）"
				end
				if RaidGrid_EventScrutiny.bBuffChatAlertEnable and (data.bChatAlertW or data.bChatAlertT) then
					local msg = "★ [" .. playerMember.szName .. "]" .. sztInfoadd .. "获得效果: " .. szBuffName .. " x" .. nStackNum .. "。" .. (data.tAlarmAddInfo or "")
					if data.bChatAlertW then
						if player.dwID == dwMemberID or (IsPlayer(dwMemberID) and player.IsPlayerInMyParty(dwMemberID)) then
							local tInfo2 = 	{{type = "text", text = "★你★获得效果: " .. szBuffName .. " x" .. nStackNum .. "。" .. (data.tAlarmAddInfo or "")},}
							JH.Talk(playerMember.szName,tInfo2)
						else
							JH.WhisperToTeamMember(msg)
						end
					end
					if data.bChatAlertT and player.IsInParty() then
						JH.Talk(msg)
					end
				end
			end
			if ((data.bChatAlertCDEnd2 or 0) <= data.fEventTimeStart) then
				if data.bSkillTimer2Enable and data.nSkillTimer2 and data.nSkillTimer2>0 then
					FireEvent("JH_ST_CREATE", JH_ST_TYPE.BUFF_ENTER, data.dwID .. "." .. data.nLevel, {
						nTime  = data.nSkillTimer2,
						szName = data.szSkillName2 or data.szName,
						nIcon  = data.nIconID,
						bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
					})
				end
				data.bChatAlertCDEnd2 = data.fEventTimeStart + tonumber(data.nMinEventCD or 10)
			end
			local szmsgpre = "[" .. playerMember.szName .. "]获得效果: "
			if player.dwID == dwMemberID then
				szmsgpre = "★你★获得效果: "
			end
			local msg = szmsgpre .. szBuffName .. " x" .. nStackNum .. "。".. (data.tAlarmAddInfo or "")
			RaidGrid_EventScrutiny.UpdateAlarmAndSelectOrg(dwMemberID, data, msg)
			if data.bBigFontAlarm then
				if data.tAlarmAddInfo then
					msg = data.tAlarmAddInfo
				end
				FireEvent("JH_LARGETEXT", msg, { GetHeadTextForceFontColor(dwMemberID,player.dwID) }, player.dwID == dwMemberID )
			end
			if RaidGrid_EventScrutiny.bAutoMarkEnable and data.tAutoTeamMark and data.tAutoTeamMark ~= 0 then
				RaidGrid_Base.TeamMarkOrg(dwMemberID, data.tAutoTeamMark)
			end
			if IsPlayer(dwMemberID) and data.bPartyBuffList and (GetClientPlayer().IsPlayerInMyParty(dwMemberID) or dwMemberID == player.dwID) then
				FireEvent("JH_PARTYBUFFLIST", dwMemberID, data.dwID, data.nLevel)
			end
			if not data.bOnlySelfSrcAddCTM or dwSkillSrcID == player.dwID then
				if RaidGrid_EventScrutiny.bBuffTeamScrutinyEnable then
					if not data.bNotAddToCTM then
						FireEvent("JH_RAID_REC_BUFF", dwMemberID, dwBuffID, nLevel, data.tRGBuffColor)
					end
				end
			end
			if data.bScreenHead then
				FireEvent("JH_SCREENHEAD", dwMemberID, { type = data.szType, dwID = data.dwID, szName = data.szName, col = data.tRGBuffColor })
			end
		end
	end
end

function RaidGrid_EventScrutiny.OnNpcCreationEvent(dwTemplateID, npc)
	local player = GetClientPlayer()
	if not npc or not player then
		return
	end

	if not RaidGrid_EventScrutiny.bEnable then
		return
	end
	local fLogicTime = JH.GetLogicTime()
	local data = GetCacheData("Npc", dwTemplateID)

	if data and not data.bNotAppearScrutiny then
		local bEventCanFire = true
		if data.nEventAlertCount and data.nEventAlertCount > 1 then
			if math.abs(JH.GetLogicTime() - (data.fLastEventCountTime or 0)) > tonumber(data.nMinChatAlertCD or 7) then
				data.nEventCount = nil
			end
			data.fLastEventCountTime = JH.GetLogicTime()
			data.nEventCount = (data.nEventCount or 0) + 1
			if data.nEventCount == data.nEventAlertCount then
				data.nEventCount = nil
				bEventCanFire = true
			else
				bEventCanFire = false
			end
		end
		if data.bAutoTeamMarkAll and RaidGrid_EventScrutiny.bAutoMarkEnable then
			if data.nMarkCount and (data.nMarkCount >= (data.nMaxMarkCount or 10)) then
				data.nMarkCount = nil
				data.fLastMarkCountTime = nil
			end
			local TeamMarkIndex = 1
			if data.tAutoTeamMark and data.tAutoTeamMark ~= 0 then
				TeamMarkIndex = data.tAutoTeamMark
			end
			data.nMarkCount = (data.nMarkCount or 0) + 1
			if (TeamMarkIndex + data.nMarkCount - 1) <= 10 then
				TeamMarkIndex = TeamMarkIndex + data.nMarkCount - 1
			else
				data.nMarkCount = 1
			end
			if TeamMarkIndex>=1 and TeamMarkIndex<=10 then
				RaidGrid_Base.TeamMarkOrg(npc.dwID, TeamMarkIndex)
			end
		end
		if data.bScreenHead then
			FireEvent("JH_SCREENHEAD", npc.dwID, { type = "Object", txt = data.tAlarmAddInfo, col = data.tRGBuffColor })
		end
		if bEventCanFire and data.nEventAlertTime and data.nEventAlertTime > 0 then
			-- 记录平均数
			if dwTemplateID and data.fLastNpcAppearTime and fLogicTime >= tonumber(data.nMinChatAlertCD or 7) + data.fLastNpcAppearTime and fLogicTime <= 1200 + data.fLastNpcAppearTime then
				local npc2 = GetNpcTemplate(dwTemplateID)
				if npc2 then
					local fTimeLast = fLogicTime - data.fLastNpcAppearTime
					data.tEventTimeCache = data.tEventTimeCache or {}
					table.insert(data.tEventTimeCache, 1, fTimeLast)
					data.tEventTimeCache[11] = nil
					if fTimeLast < (data.fMinTime or 999999) then
						data.fMinTime = fTimeLast
					end
					if data.nAutoEventTimeMode == AUTO_EVENTTIME_MODE.MIN then
						if data.fMinTime and data.fMinTime > 0 then
							data.nEventAlertTime = math.floor(data.fMinTime)
						end
					elseif data.nAutoEventTimeMode == AUTO_EVENTTIME_MODE.AVG then
						local nAvg = RaidGrid_Base.LowAverage(data.tEventTimeCache or {})
						if nAvg and nAvg > 0 then
							data.nEventAlertTime = math.floor(nAvg)
						end
					end
				end
			end
			data.fLastNpcAppearTime = fLogicTime
			-- 事件监控倒计时触发设置
			if (data.nEventScrutinyCDEnd or 0) <= fLogicTime then
				data.fEventTimeStart = fLogicTime
				data.fEventTimeEnd = data.fEventTimeStart + data.nEventAlertTime
				if not data.bNotAddToScrutiny then
					RaidGrid_EventScrutiny.AddRecordToList(data, "Scrutiny")
				end
				data.nEventScrutinyCDEnd = fLogicTime + tonumber(data.nMinEventScrutinyCD or 7)
			end
			local szNpcName = JH.GetTemplateName(npc)
			if ((data.bChatAlertCDEnd2 or 0) <= fLogicTime) then
				if RaidGrid_EventScrutiny.bAutoNewSkillTimer and data.bAddToSkillTimer then
					FireEvent("JH_ST_CREATE", JH_ST_TYPE.NPC_ENTER, data.dwID .. "C", { -- 这个好像是中央倒计时
						nTime  = data.nEventAlertTime,
						szName = data.szName,
						nIcon  = data.nIconID or 2026,
						bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
					})
				end
				if data.bSkillTimer2Enable and data.nSkillTimer2 and data.nSkillTimer2>0 then
					FireEvent("JH_ST_CREATE", JH_ST_TYPE.NPC_ENTER, data.dwID .. "C2", { -- 第二中央倒计时的
						nTime  = data.nSkillTimer2,
						szName = data.szSkillName2 or data.szName,
						nIcon  = data.nIconID or 2026,
						bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
					})
				end
				if data.szTimerSet then
					FireEvent("JH_ST_CREATE", JH_ST_TYPE.NPC_ENTER, data.dwID .. "F", { -- 分段倒计时
						nTime  = data.szTimerSet,
						nIcon  = data.nIconID or 2026,
						bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
					})
				end
				data.bChatAlertCDEnd2 = fLogicTime + tonumber(data.nMinEventCD or 10)
			end
			if (data.bChatAlertCDEnd or 0) <= fLogicTime then
				if player.IsInParty() and RaidGrid_EventScrutiny.bNpcChatAlertEnable and (data.bChatAlertW or data.bChatAlertT) then
					local msg = _L("* [%s] enter %s",szNpcName,data.tAlarmAddInfo or "")
					if data.bChatAlertW then
						JH.WhisperToTeamMember(msg)
					end
					if data.bChatAlertT then
						JH.Talk(msg)
					end
				end
				local msg = _L("[%s] enter %s",szNpcName,data.tAlarmAddInfo or "")
				RaidGrid_EventScrutiny.UpdateAlarmAndSelectOrg(npc.dwID, data, msg)
				if data.bBigFontAlarm then
					FireEvent("JH_LARGETEXT", msg, { GetHeadTextForceFontColor(npc.dwID, player.dwID) }, true)
				end
				if not data.bAutoTeamMarkAll and RaidGrid_EventScrutiny.bAutoMarkEnable and data.tAutoTeamMark and data.tAutoTeamMark ~= 0 then
					RaidGrid_Base.TeamMarkOrg(npc.dwID, data.tAutoTeamMark)
				end
				data.bChatAlertCDEnd = fLogicTime + tonumber(data.nMinChatAlertCD or 7)
			end
		end
	end
end

function RaidGrid_EventScrutiny.OnNpcLeaveEvent(dwTemplateID, npc)
	local player = GetClientPlayer()
	if not npc or not player then
		return
	end

	if not RaidGrid_EventScrutiny.bEnable then
		return
	end

	local data = GetCacheData("Npc", dwTemplateID)
	if data then
		if not data.bNpcLeaveScrutiny then return end
		local bEventCanFire = true
		if data.bNpcAllLeave then
			local aNpc = JH.GetAllNpc()
			for k, v in pairs(aNpc) do
				if v.dwTemplateID == dwTemplateID and v.dwID ~= npc.dwID then
					bEventCanFire = false
					return
				end
			end
		end
		if bEventCanFire then
			local szNpcName = JH.GetTemplateName(npc)
			if not szNpcName or szNpcName == "" then
				szNpcName = data.szName
				if szNpcName == "" then
					szNpcName = tostring(dwTemplateID)
				end
			end
			if player.IsInParty() and RaidGrid_EventScrutiny.bNpcChatAlertEnable and (data.bChatAlertW or data.bChatAlertT) then
				local msg = _L("* [%s] leave",szNpcName)
				if data.bChatAlertW then
					JH.WhisperToTeamMember(msg)
				end
				if data.bChatAlertT then
					JH.Talk(msg)
				end
			end
			local msg = _L("[%s] leave",szNpcName)
			RaidGrid_EventScrutiny.UpdateAlarmAndSelectOrg(npc.dwID, data, msg, true)
			if data.bBigFontAlarm then
				FireEvent("JH_LARGETEXT", msg, { GetHeadTextForceFontColor(npc.dwID, player.dwID ) }, true)
			end
		end
	end
end

function RaidGrid_EventScrutiny.OnSkillCasting(szCastType, dwID, dwSkillID, dwSkillLevel, szTargetIDOrName)
	local player = GetClientPlayer()
	if not player then
		return
	end
	if not RaidGrid_EventScrutiny.bEnable then
		return
	end

	local fLogicTime = JH.GetLogicTime()

	local target = IsPlayer(dwID) and GetPlayer(dwID) or GetNpc(dwID)
	local sarg0 = arg0
	local data = GetCacheData("Casting", dwSkillID, dwSkillLevel)
	if target and data then
		if data.bTargetSkillOnly then
			local tarType, tardwID = player.GetTarget()
			if not tardwID or dwID ~= tardwID then
				return
			end
		end
		if data.nRelScrutinyType then
			if data.nRelScrutinyType == 1 then
				--szRelScrutinyType = "只监控自己"
				if player.dwID ~= dwID then
					return
				end
			elseif data.nRelScrutinyType == 2 then
				--szRelScrutinyType = "队友和自己"
				if player.dwID ~= dwID and not player.IsPlayerInMyParty(dwID) then
					return
				end
			elseif data.nRelScrutinyType == -1 then
				--szRelScrutinyType = "只监控敌方"
				if not IsEnemy(player.dwID, dwID) then
					return
				end
			elseif data.nRelScrutinyType == -2 then
				--szRelScrutinyType = "只监控非队友"
				if player.dwID == dwID or player.IsPlayerInMyParty(dwID) then
					return
				end
			end
		end
		local szSkillName = Table_GetSkillName(dwSkillID, dwSkillLevel)
		if not szSkillName then return end -- 和谐
		if not szSkillName or szSkillName == "" then
			szSkillName = data.szName or "????"
		end
		if data.nEventAlertTime and data.nEventAlertTime > 0 then
			-- 记录平均数
			if dwSkillID and data.fLastSkillAppearTime and fLogicTime >= tonumber(data.nMinChatAlertCD or 7) + data.fLastSkillAppearTime and fLogicTime <= 1200 + data.fLastSkillAppearTime then
				local fTimeLast = fLogicTime - data.fLastSkillAppearTime
				data.tEventTimeCache = data.tEventTimeCache or {}
				table.insert(data.tEventTimeCache, 1, fTimeLast)
				data.tEventTimeCache[11] = nil
				if fTimeLast < (data.fMinTime or 999999) then
					data.fMinTime = fTimeLast
				end
				if data.nAutoEventTimeMode == AUTO_EVENTTIME_MODE.MIN then
					if data.fMinTime and data.fMinTime > 0 then
						data.nEventAlertTime = math.floor(data.fMinTime)
					end
				elseif data.nAutoEventTimeMode == AUTO_EVENTTIME_MODE.AVG then
					local nAvg = RaidGrid_Base.LowAverage(data.tEventTimeCache or {})
					if nAvg and nAvg > 0 then
						data.nEventAlertTime = math.floor(nAvg)
					end
				end
			end
			if ((data.bChatAlertCDEnd2 or 0) <= fLogicTime) then
				if RaidGrid_EventScrutiny.bAutoNewSkillTimer and data.bAddToSkillTimer then
					FireEvent("JH_ST_CREATE", JH_ST_TYPE.SKILL_END, data.dwID .. data.nLevel .. "C", { -- 这个好像是中央倒计时
						nTime  = data.nEventAlertTime,
						szName = data.szName,
						nIcon  = data.nIconID or 13,
						bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
					})
					data.bChatAlertCDEnd2 = fLogicTime + tonumber(data.nMinEventCD or 10)
				end
				if data.bSkillTimer2Enable and data.nSkillTimer2 and data.nSkillTimer2>0 then
					FireEvent("JH_ST_CREATE", JH_ST_TYPE.SKILL_END, data.dwID .. "_" .. data.nLevel .. "C2", { -- 这个好像是中央倒计时
						nTime  = data.nSkillTimer2,
						szName = data.szSkillName2 or data.szName,
						nIcon  = data.nIconID or 13,
						bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
					})
					data.bChatAlertCDEnd2 = fLogicTime + tonumber(data.nMinEventCD or 10)
				end
			end
			data.fLastSkillAppearTime = fLogicTime
			-- 事件监控倒计时触发设置
			if (data.nEventScrutinyCDEnd or 0) <= fLogicTime then
				data.fEventTimeStart = fLogicTime
				data.fEventTimeEnd = data.fEventTimeStart + data.nEventAlertTime
				if not data.bNotAddToScrutiny then
					RaidGrid_EventScrutiny.AddRecordToList(data, "Scrutiny")
				end
				data.nEventScrutinyCDEnd = fLogicTime + tonumber(data.nMinEventScrutinyCD or 7)
			end
			if ((data.bChatAlertCDEnd or 0) <= fLogicTime) then
				if data.bFullScreenAlert and RaidGrid_EventScrutiny.bColorAlertEnable then
					FireEvent("JH_FS_CREATE", "Casting"--[[data.dwID .. "_" .. data.nLevel]], { nTime = 3, col = data.tRGBuffColor })
				end
				local szTargetName = _L["Unknown"]
				local bTargetNameIsPlayer = false
				if RaidGrid_EventScrutiny.bCastingTargetScrutinyEnable and (not data.bNotCastTargetScrutinyEnable) then
					if (not szTargetIDOrName or tonumber(szTargetIDOrName) <= 0) then
						local nTargetTargetType, dwTargetTargetID = target.GetTarget()
						if not (not dwTargetTargetID or dwTargetTargetID <= 0) then
							if IsPlayer(dwTargetTargetID) then
								if GetPlayer(dwTargetTargetID) then
									szTargetName = GetPlayer(dwTargetTargetID).szName
									bTargetNameIsPlayer = true
								end
							else
								szTargetName = JH.GetTemplateName(GetNpc(dwTargetTargetID))
							end
						end
					else
						local dwTargetTargetID = tonumber(szTargetIDOrName)
						if not (not dwTargetTargetID or dwTargetTargetID <= 0) then
							if IsPlayer(dwTargetTargetID) then
								if GetPlayer(dwTargetTargetID) then
									szTargetName = GetPlayer(dwTargetTargetID).szName
									bTargetNameIsPlayer = true
								end
							else
								szTargetName = JH.GetTemplateName(GetNpc(dwTargetTargetID))
							end
						end
					end
				end
				local szInfoTemp = "。"
				if szTargetName and szTargetName ~= "" and szTargetName ~= _L["Unknown"] then
					szInfoTemp = "，目标：[" .. szTargetName .. "]。"
					if player.szName == szTargetName then
						szInfoTemp = "，目标：★" .. szTargetName .. "★。"
					end
				end
				local szInfoTemp2 = "]释放了："
				if szCastType == "UI_OME_SKILL_CAST_LOG" then
					szInfoTemp2 = "]开始吟唱："
				end
				local szName = JH.GetTemplateName(target)
				if RaidGrid_EventScrutiny.bCastingChatAlertEnable and RaidGrid_EventScrutiny.bCastTargetChatAlertEnable and bTargetNameIsPlayer and szInfoTemp ~= "。" and data.bCastTargetChatAlertW then
					local tInfo2 = {{type = "text", text = "★ [" .. szName .. szInfoTemp2 .. szSkillName .. "，目标为：★你★。" .. (data.tAlarmAddInfo or "")},}
					JH.Talk(szTargetName,tInfo2)
				end
				if player.IsInParty() and RaidGrid_EventScrutiny.bCastingChatAlertEnable and (data.bChatAlertW or data.bChatAlertT) then
					local tInfo =  "★ [" .. szName .. szInfoTemp2 .. szSkillName .. szInfoTemp .. (data.tAlarmAddInfo or "")
					if data.bChatAlertW then
						JH.WhisperToTeamMember(tInfo)
					end
					if data.bChatAlertT then
						JH.Talk(tInfo)
					end
				end
				local msg = "[" .. szName .. szInfoTemp2 .. szSkillName .. szInfoTemp .. (data.tAlarmAddInfo or "")
				RaidGrid_EventScrutiny.UpdateAlarmAndSelectOrg(dwID, data, msg)
				if data.bBigFontAlarm then
					FireEvent("JH_LARGETEXT", msg, { GetHeadTextForceFontColor(dwID, player.dwID) }, true)
				end
				data.bChatAlertCDEnd = fLogicTime + tonumber(data.nMinChatAlertCD or 7)
			end
		end
		if sarg0 == "UI_OME_SKILL_CAST_LOG" and data.bScreenHead then
			FireEvent("JH_SCREENHEAD", target.dwID, { type = "Skill", txt = data.szName, col = data.tRGBuffColor })
		end
		if RaidGrid_EventScrutiny.bCastingReadingBar and sarg0 == "UI_OME_SKILL_CAST_LOG" and not data.bNotReadingBar then
			RaidGrid_ReadingBar.putOrg(target)
		end
	end
end


function RaidGrid_EventScrutiny.CheckNpcLifeAndAlarmOrg()
	if not RaidGrid_EventScrutiny.bEnable then
		return
	end

	local player = GetClientPlayer()
	if not player then
		return
	end
	if not player.bFightState then
		_RE.tNpcLife = {}
		return
	end
	for dwID, target in pairs(RaidGrid_EventCache.tSyncEnemyChar) do
		local dwTemplateID = target.dwTemplateID
		local data = GetCacheData("Npc", dwTemplateID)
		if data then
			if data.tNpcLife then
				if not _RE.tNpcLife[dwTemplateID] then
					_RE.tNpcLife[dwTemplateID] = {}
				end
				local nCurrentLife,nMaxLife = target.nCurrentLife,target.nMaxLife
				local nPercentLife = nCurrentLife / nMaxLife
				for k, v in pairs(data.tNpcLife) do
					if nPercentLife < v[1] and not _RE.tNpcLife[dwTemplateID][v[1]] then
						RaidGrid_RedAlarm.FlashOrg(3,v[2], false, true, 255, 0, 0)
						FireEvent("JH_LARGETEXT", v[2], { 255, 128, 0 }, true)
						if v[3] then
							FireEvent("JH_ST_CREATE", JH_ST_TYPE.NPC_LIFE, data.dwID, {
								nTime  = v[3],
								szName = v[2],
								nIcon  = data.nIconID or 2026,
								bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
							})
						end
						local fLogicTime = JH.GetLogicTime()
						if (data.bChatAlertCDEnd or 0) <= fLogicTime then
							if player.IsInParty() and RaidGrid_EventScrutiny.bNpcChatAlertEnable and (data.bChatAlertW or data.bChatAlertT) then
								local tInfo = v[2]
								if data.bChatAlertW then
									JH.WhisperToTeamMember(tInfo)
								end
								if data.bChatAlertT then
									JH.Talk(tInfo)
								end
							end
							data.bChatAlertCDEnd = fLogicTime + tonumber(data.nMinChatAlertCD or 7)
						end
						_RE.tNpcLife[dwTemplateID][v[1]] = true
						break
					end
				end
			end
		end
	end
end

function RaidGrid_EventScrutiny.RefreshEventHandle()
	local player = GetClientPlayer()
	if not player then
		return
	end
	local handle = RaidGrid_EventScrutiny.handleRecords
	if not handle then
		return
	end

	local tTab = RaidGrid_EventScrutiny.tRecords["Scrutiny"]
	local fLogicTime = JH.GetLogicTime()

	local tRemoveList = {}
	for i = 1, #tTab do
		local tRecord = tTab[i]
		local szType = tRecord.szType
		if szType == "Npc" or szType == "Casting" then
			if RaidGrid_Base.IsOutOfEventTime(tRecord, 0) then
				tRecord.fEventTimeStart = nil
				tRecord.fEventTimeEnd = nil
				if tTab.Hash2[tRecord.dwID] and tRecord.nLevel then
					tTab.Hash2[tRecord.dwID][tRecord.nLevel] = nil
				end
				if not tTab.Hash2[tRecord.dwID] or IsTableEmpty(tTab.Hash2[tRecord.dwID]) then
					tTab.Hash2[tRecord.dwID] = nil
					tTab.Hash[tRecord.dwID] = nil
				end
				table.insert(tRemoveList, 1, i)
			end
		elseif szType == "Buff" or szType == "Debuff" then
			if RaidGrid_Base.IsOutOfEventTime(tRecord, 0) then
				tRecord.fEventTimeStart = nil
				tRecord.fEventTimeEnd = nil
				if tTab.Hash2[tRecord.dwID] and tRecord.nLevel then
					tTab.Hash2[tRecord.dwID][tRecord.nLevel] = nil
				end
				if not tTab.Hash2[tRecord.dwID] or IsTableEmpty(tTab.Hash2[tRecord.dwID]) then
					tTab.Hash2[tRecord.dwID] = nil
					tTab.Hash[tRecord.dwID] = nil
				end
				table.insert(tRemoveList, 1, i)
			end
		end
	end

	for i = 1, #tRemoveList do
		table.remove(tTab, tRemoveList[i])
	end
	if RaidGrid_EventScrutiny.szListIndex == "Scrutiny" then
		RaidGrid_EventScrutiny.UpdateRecordList("Scrutiny")
	end

	for i = 1, 8 do
		local handleRecord = handle:Lookup("Handle_Record_" .. i)
		if handleRecord and handleRecord.tRecord and
		(handleRecord.tRecord.szType == "Npc" or handleRecord.tRecord.szType == "Casting" or handleRecord.tRecord.szType == "Buff" or handleRecord.tRecord.szType == "Debuff") then
			if RaidGrid_EventScrutiny.szListIndex == "Scrutiny" and handleRecord.tRecord.nEventAlertTime and handleRecord.tRecord.nEventAlertTime > 0 then
				local fTimeRemain = handleRecord.tRecord.fEventTimeEnd - fLogicTime
				local fP = 1
				local nFrame = 32
				if fTimeRemain >= 0 then		-- 时间没到
					if handleRecord.tRecord.szType == "Buff" then
						fP = fTimeRemain / handleRecord.tRecord.nEventAlertTime
						nFrame = 32
					elseif handleRecord.tRecord.szType == "Debuff" then
						fP = fTimeRemain / handleRecord.tRecord.nEventAlertTime
						nFrame = 30
					else
						fP = 1 - fTimeRemain / handleRecord.tRecord.nEventAlertTime
						if fP >= 0.975 or fTimeRemain < 5 then
							nFrame = 30
						elseif fP >= 0.5 then
							nFrame = 31
						end
					end
				else							-- 时间到了延迟删除
					fTimeRemain = math.abs(fTimeRemain)
					nFrame = 30
				end
				if not handleRecord.imageTimeBar.nFrame or handleRecord.imageTimeBar.nFrame ~= nFrame then
					handleRecord.imageTimeBar.nFrame = nFrame
					handleRecord.imageTimeBar:SetFrame(nFrame)
				end
				if not handleRecord.tRecord.bNormalCountdownType then
					handleRecord:Lookup("Image_TimeBar"):SetSize(125 * fP, 17)
					handleRecord.textEventTime:SetText(JH.GetBuffTimeString(fTimeRemain))
				else
					handleRecord:Lookup("Image_TimeBar"):SetSize(125 * fP, 17)
					handleRecord.textEventTime:SetText(JH.GetBuffTimeString(fLogicTime - handleRecord.tRecord.fEventTimeStart))
				end
			else
				handleRecord:Lookup("Image_TimeBar"):SetSize(0, 17)
				if not handleRecord.tRecord.bNotAddToScrutiny and handleRecord.tRecord.szType ~= "Buff" and handleRecord.tRecord.szType ~= "Debuff" then
					handleRecord.textEventTime:SetText("事件倒计时")
				else
					handleRecord.textEventTime:SetText("无倒计时")
				end
				for k,v in pairs(RaidGrid_EventScrutiny.tSkillTimerName) do
					if handleRecord.tRecord[k] then
						handleRecord.textEventTime:SetText(v)
					end
				end
			end
		end
	end
end

RaidGrid_EventScrutiny.tSkillTimerName = {
	bSkillTimer2Enable  = "中央倒计时二",
	bAddToSkillTimer = "中央倒计时",
	szTimerSet = "分段倒计时",
}

function RaidGrid_EventScrutiny.SwitchPageType(szListIndex)
	if not RaidGrid_EventScrutiny.tListPage[szListIndex] then
		return
	end
	if not RaidGrid_EventScrutiny.bCheckBoxRecall then
		return
	end
	RaidGrid_EventScrutiny.bCheckBoxRecall = false

	RaidGrid_EventScrutiny.szListIndex = szListIndex
	for szKey, _ in pairs(RaidGrid_EventScrutiny.tListPage) do
		local checkBox = RaidGrid_EventScrutiny.wnd:Lookup("CheckBox_Page_" .. szKey)
		if szListIndex == szKey then
			checkBox:Check(true)
			checkBox:Enable(false)
		else
			checkBox:Check(false)
			checkBox:Enable(true)
		end
	end

	local tTitle = {Buff = _L["Buff"], Debuff = _L["DeBuff"], Casting = _L["Casting"], Npc = _L["Npc"], Scrutiny = _L["RaidGrid_EventScrutiny"]}
	local textTitle = RaidGrid_EventScrutiny.handleMain:Lookup("Text_Title")
	textTitle:SetText(tTitle[szListIndex] or _L["RGES"])

	RaidGrid_EventScrutiny.UpdateRecordList(szListIndex)
	RaidGrid_EventScrutiny.RefreshEventHandle()

	if szListIndex == "Scrutiny" then
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_TL"):SetAlpha(64)
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_TR"):SetAlpha(64)
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_L"):Hide()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_M"):Hide()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_R"):Hide()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_BL"):Hide()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_B"):Hide()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_BR"):Hide()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_List"):Hide()
		RaidGrid_EventScrutiny.wnd:Lookup("CheckBox_SelfBuff"):Hide()
		RaidGrid_EventScrutiny.wnd:Lookup("Btn_PrePage"):Hide()
		RaidGrid_EventScrutiny.wnd:Lookup("Btn_NextPage"):Hide()
		RaidGrid_EventScrutiny.wnd:Lookup("Btn_DelPage"):Hide()
		RaidGrid_EventScrutiny.handleMain:Lookup("Text_PageCurrent"):Hide()

	else
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_TL"):SetAlpha(255)
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_TR"):SetAlpha(255)
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_L"):Show()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_M"):Show()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_R"):Show()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_BL"):Show()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_B"):Show()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_BR"):Show()
		RaidGrid_EventScrutiny.handleMain:Lookup("Handle_BG"):Lookup("Image_BG_List"):Show()
		RaidGrid_EventScrutiny.wnd:Lookup("CheckBox_SelfBuff"):Show()
		RaidGrid_EventScrutiny.wnd:Lookup("Btn_PrePage"):Show()
		RaidGrid_EventScrutiny.wnd:Lookup("Btn_NextPage"):Show()
		RaidGrid_EventScrutiny.wnd:Lookup("Btn_DelPage"):Show()
		RaidGrid_EventScrutiny.handleMain:Lookup("Text_PageCurrent"):Show()
	end

	RaidGrid_EventScrutiny.bCheckBoxRecall = true
end

function RaidGrid_EventScrutiny.Macro(tRecord,szListIndex)
	if not tRecord.szName then return end
	szListIndex = szListIndex or tRecord.szType
	if not szListIndex then return end
	GUI.UnRegisterPanel(_L["Set Data"])
	local t = RaidGrid_EventScrutiny.tRecords[szListIndex]
	if not t then
		return JH.Alert("data is invalid")
	end
	for i = 1, #t do
		if t[i].dwID == tRecord.dwID and (not tRecord.nLevel or (t[i].nLevel == tRecord.nLevel)) then
			t[i] = tRecord
			return JH.Alert(_L(" * cover data %s (%s)",szListIndex,tRecord.szName))
		end
	end
	RaidGrid_EventScrutiny.AddRecordToList(tRecord,tRecord.szType)
	return JH.Alert(_L(" * import data %s (%s)",szListIndex,tRecord.szName))
end



function RaidGrid_EventScrutiny.AddRecordToList(tRecord, szListIndex)
	if not tRecord or not szListIndex then
		return
	end

	local tListTable = RaidGrid_EventScrutiny.tRecords[szListIndex]
	if not tListTable or not tListTable.Hash2 then
		return
	end

	if tListTable.Hash[tRecord.dwID] or tListTable.Hash2[tRecord.dwID] then
		if not tRecord.nLevel or (tListTable.Hash2[tRecord.dwID] and tListTable.Hash2[tRecord.dwID][tRecord.nLevel]) then
			return
		end
	end

	tRecord.nEventAlertTime = tRecord.nEventAlertTime or math.floor(tRecord.fKeepTime or 1200)

	if szListIndex ~= "Scrutiny" then
		table.insert(tListTable, 1, tRecord)
	else
		table.insert(tListTable, tRecord)
	end
	tListTable.Hash[tRecord.dwID] = true
	if tRecord.nLevel then
		tListTable.Hash2[tRecord.dwID] = tListTable.Hash2[tRecord.dwID] or {}
		tListTable.Hash2[tRecord.dwID][tRecord.nLevel] = true
	end
	if RaidGrid_EventScrutiny.szListIndex == szListIndex then
		RaidGrid_EventScrutiny.UpdateRecordList(szListIndex)
	end
end

function RaidGrid_EventScrutiny.IsRecordInList(tRecord, szListIndex)
	if not tRecord or not szListIndex then
		return
	end
	local tListTable = RaidGrid_EventScrutiny.tRecords[szListIndex]
	if not tListTable or not tListTable.Hash or not tListTable.Hash[tRecord.dwID] then
		return
	end
	if tRecord.nLevel then
		if not tListTable.Hash2[tRecord.dwID] or not tListTable.Hash2[tRecord.dwID][tRecord.nLevel] then
			return
		end
	end
	return true
end

function RaidGrid_EventScrutiny.UpdateRecordList(szListIndex)
	local handle = RaidGrid_EventScrutiny.handleRecords
	if not handle then
		return
	end
	szListIndex = szListIndex or RaidGrid_EventScrutiny.szListIndex

	local tTab = RaidGrid_EventScrutiny.tRecords[szListIndex]
	if not tTab then
		return
	end

	local nMaxPage = math.max(math.ceil(#tTab / 8), 1)
	local nCurrentPage = math.min(RaidGrid_EventScrutiny.tListPage[szListIndex] or 1, nMaxPage)
	RaidGrid_EventScrutiny.tListPage[szListIndex] = nCurrentPage
	RaidGrid_EventScrutiny.handleMain:Lookup("Text_PageCurrent"):SetText(nCurrentPage)

	local nStartIndex = 8 * (nCurrentPage - 1) + 1
	local nShownCount = 0
	for i = 1, 8 do
		local handleRecord = handle:Lookup("Handle_Record_" .. i)
		if handleRecord then
			local tRecord = tTab[nStartIndex + i - 1]
			if tRecord then
				nShownCount = nShownCount + 1
				RaidGrid_EventScrutiny.ShowRecordHandle(handleRecord, tRecord)
			else
				RaidGrid_EventScrutiny.ClearRecordHandle(handleRecord)
			end
		end
	end

	if szListIndex == "Scrutiny" then
		RaidGrid_EventScrutiny.frameSelf:SetSize(235, 50 + 48 * nShownCount)
	else
		RaidGrid_EventScrutiny.frameSelf:SetSize(235, 455)
	end
end

function RaidGrid_EventScrutiny.InitRecordHandles()
	local handle = RaidGrid_EventScrutiny.handleRecords
	if not handle then
		return
	end
	handle:Clear()

	for i = 1, 8 do
		local handleRecord = handle:AppendItemFromIni(szIniFileScrutiny, "Handle_RecordDummy", "Handle_Record_" .. i)
		handleRecord:SetRelPos(0, (i - 1) * 46 + 1)
		handleRecord.OnItemMouseEnter = function()
			this.imageCover:Show()
		end
		handleRecord.OnItemMouseLeave = function()
			this.imageCover:Hide()
		end
		handleRecord.OnItemLButtonClick = function()
		end
		handleRecord.OnItemRButtonClick = function()
			RaidGrid_EventScrutiny.PopRBOptions(this)
		end

		handleRecord.box = handleRecord:Lookup("Box_Icon")
		handleRecord.box:Show()
		handleRecord.box:SetObject(1,0)
		handleRecord.box:ClearObjectIcon()
		handleRecord.box:SetObjectIcon(1435)
		handleRecord.box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
		handleRecord.box:SetOverTextFontScheme(0, 15)
		handleRecord.box:SetOverText(0, "")
		handleRecord.box.handleParent = handleRecord
		handleRecord.box.OnItemMouseEnter = function()
			local tRecord = this.handleParent.tRecord
			if tRecord and tRecord.dwID then
				local x, y = this:GetAbsPos()
				local w, h = this:GetSize()
				if tRecord.szType == "Buff" or tRecord.szType == "Debuff" then
					OutputBuffTip(GetClientPlayer().dwID, tRecord.dwID, tRecord.nLevel or 1, 1, false, 999, {x, y, w, h})
				elseif tRecord.szType == "Npc" then
					OutputNpcTip2(tRecord.dwID, {x, y, w, h})
				elseif tRecord.szType == "Casting" then
					OutputSkillTip(tRecord.dwID, tRecord.nLevel or 1, {x, y, w, h})
				end
			end
		end
		handleRecord.box.OnItemMouseLeave = function()
			HideTip()
		end

		handleRecord.imageBoxBG = handleRecord:Lookup("Image_BGBox")
		handleRecord.imageBoxBG.handleParent = handleRecord
		handleRecord.imageBoxBG.OnItemMouseEnter = handleRecord.box.OnItemMouseEnter
		handleRecord.imageBoxBG.OnItemMouseLeave = handleRecord.box.OnItemMouseLeave

		handleRecord.text = handleRecord:Lookup("Text_Name")
		handleRecord.text:SetText("")

		handleRecord.imageGrid = handleRecord:Lookup("Image_BGGrid")
		handleRecord.imageGrid.nFrame = 999

		handleRecord.textTime = handleRecord:Lookup("Text_Time")
		handleRecord.textTime:SetText("")

		handleRecord.textEventTime = handleRecord:Lookup("Text_EventTime")
		handleRecord.textEventTime:SetText("")

		handleRecord.textEventAlertTime = handleRecord:Lookup("Text_EventAlertTime")
		handleRecord.textEventAlertTime:SetFontColor(255,128,0)
		handleRecord.textEventAlertTime:SetText("")

		handleRecord.textEventAlertCount = handleRecord:Lookup("Text_Count")
		handleRecord.textEventAlertCount:SetText("")

		handleRecord.imageCover = handleRecord:Lookup("Image_Cover")
		handleRecord.imageTimeBar = handleRecord:Lookup("Image_TimeBar")
		handleRecord.imageTimeAlertBG = handleRecord:Lookup("Image_TimeAlertBG")
		handleRecord.shadowBuffColor = handleRecord:Lookup("Shadow_BuffColor")

		handleRecord.imageFSLink = handleRecord:Lookup("Image_FSLink")

		handleRecord:Hide()
	end

	handle:FormatAllItemPos()
end

function RaidGrid_EventScrutiny.ClearRecordHandle(handleRecord)
	if not handleRecord then
		return
	end
	handleRecord.box:SetObjectIcon(1435)
	handleRecord.dwID = nil
	handleRecord.tRecord = nil
	handleRecord:Hide()
end

function RaidGrid_EventScrutiny.ShowRecordHandle(handleRecord, tRecord)
	if not handleRecord or not tRecord then
		return
	end

	handleRecord.dwID = tRecord.dwID
	handleRecord.tRecord = tRecord
	if tRecord.bIsBuffDispel then
		handleRecord.text:SetText(tRecord.szName .. "(驱)")
	else
		handleRecord.text:SetText(tRecord.szName)
	end
	if tRecord.bEnemy == true then
		handleRecord.text:SetFontColor(255, 128, 128)
	elseif tRecord.bEnemy == false then
		handleRecord.text:SetFontColor(255, 255, 128)
	else
		handleRecord.text:SetFontColor(255, 255, 255)
	end

	if tRecord.szType == "Debuff" and handleRecord.imageGrid.nFrame ~= 1 then
		handleRecord.imageGrid:SetFrame(1)
	elseif tRecord.szType == "Buff" and handleRecord.imageGrid.nFrame ~= 13 then
		handleRecord.imageGrid:SetFrame(13)
	elseif handleRecord.imageGrid.nFrame ~= 14 then
		handleRecord.imageGrid:SetFrame(14)
	end

	handleRecord.box:SetObjectIcon(tRecord.nIconID or 1435)
	if tRecord.szType == "Npc" then
		handleRecord.box:Hide()
		if tRecord.nIconFrame then
			handleRecord.imageBoxBG:FromUITex("ui/Image/TargetPanel/Target.UITex", tRecord.nIconFrame)
		else
			handleRecord.imageBoxBG:FromTextureFile("ui/Image/TargetPanel/Target.UITex")
		end
	else
		handleRecord.box:Show()
	end

	if handleRecord.tRecord.nEventAlertTime then
		handleRecord.textEventAlertTime:SetText(JH.GetBuffTimeString(handleRecord.tRecord.nEventAlertTime))
	else
		handleRecord.textEventAlertTime:SetText("")
	end

	if handleRecord.tRecord.nEventAlertCount and handleRecord.tRecord.nEventAlertCount > 1 then
		handleRecord.textEventAlertCount:SetText(handleRecord.tRecord.nEventAlertCount)
	elseif handleRecord.tRecord.nEventAlertStackNum and handleRecord.tRecord.nEventAlertStackNum > 1 then
		handleRecord.textEventAlertCount:SetText(handleRecord.tRecord.nEventAlertStackNum)
	else
		handleRecord.textEventAlertCount:SetText("")
	end

	handleRecord.tRecord.nAutoEventTimeMode = handleRecord.tRecord.nAutoEventTimeMode or AUTO_EVENTTIME_MODE.AVG
	if handleRecord.tRecord.nAutoEventTimeMode == AUTO_EVENTTIME_MODE.AVG then
		handleRecord.imageTimeAlertBG:SetFrame(23)
	elseif handleRecord.tRecord.nAutoEventTimeMode == AUTO_EVENTTIME_MODE.MIN then
		handleRecord.imageTimeAlertBG:SetFrame(22)
	else
		handleRecord.imageTimeAlertBG:SetFrame(21)
	end

	if handleRecord.tRecord.tRGBuffColor then
		handleRecord.shadowBuffColor:SetColorRGB(handleRecord.tRecord.tRGBuffColor[1] or 0, handleRecord.tRecord.tRGBuffColor[2] or 0, handleRecord.tRecord.tRGBuffColor[3] or 0)
	else
		handleRecord.shadowBuffColor:SetColorRGB(0, 0, 0)
	end

	for _, v in pairs(tRaidGrid_EventScrutinyTextUI) do
		if handleRecord.tRecord[v[4]] then
			local r,g,b = v[3][1],v[3][2],v[3][3]
			handleRecord:Lookup(v[1]):SetFontColor(r,g,b)
		else
			handleRecord:Lookup(v[1]):SetFontColor(v[2][1],v[2][2],v[2][3])
		end
	end

	if handleRecord.tRecord.bLinkNpcFightState then
		handleRecord.imageFSLink:Show()
	else
		handleRecord.imageFSLink:Hide()
	end

	handleRecord:Show()
end

function RaidGrid_EventScrutiny.OpenPanel()
	local frame = Station.Lookup("Normal/RaidGrid_EventScrutiny")
	if not frame then
		frame = Wnd.OpenWindow(RGES_INI_PATH .. "RaidGrid_EventScrutiny.ini", "RaidGrid_EventScrutiny")
	end
	frame:Show()
end

function RaidGrid_EventScrutiny.ClosePanel()
	local frame = Station.Lookup("Normal/RaidGrid_EventScrutiny")
	if frame then
		frame:Hide()
	end
end


----------------------------------------------------------------
----RaidGrid_EventScrutiny.lua----
----------------------------------------------------------------




----------------------------------------------------------------
----RaidGrid_SelfBuffAlert.lua----
----------------------------------------------------------------

local szIniFileSelfBuffAlert = RGES_INI_PATH .. "RaidGrid_SelfBuffAlert.ini"

RaidGrid_SelfBuffAlert = RaidGrid_SelfBuffAlert or {}
RaidGrid_SelfBuffAlert.frameSelf = nil
RaidGrid_SelfBuffAlert.handleMain = nil

RaidGrid_SelfBuffAlert.tLastLoc = {nX = -1, nY = -1};									RegisterCustomData("RaidGrid_SelfBuffAlert.tLastLoc")
RaidGrid_SelfBuffAlert.nScaleXandY = 1;												RegisterCustomData("RaidGrid_SelfBuffAlert.nScaleXandY")
RaidGrid_SelfBuffAlert.bShowBuffName = true;											RegisterCustomData("RaidGrid_SelfBuffAlert.bShowBuffName")

RaidGrid_SelfBuffAlert.nBoxMax = 8;

function RaidGrid_SelfBuffAlert.OnFrameBreathe()
	local player = GetClientPlayer()
	if not player then
		return
	end

	RaidGrid_SelfBuffAlert.RefreshSelfBuffHandle()

	if RaidGrid_EventScrutiny.bCtrlandAltMove and IsCtrlKeyDown() and IsAltKeyDown() then
		for i = 1, 8 do
			RaidGrid_SelfBuffAlert.handleMain:Lookup("Image_DragBG_" .. i):Show()
		end
		RaidGrid_SelfBuffAlert.frameSelf:SetSize(376*RaidGrid_SelfBuffAlert.nScaleXandY, 46*RaidGrid_SelfBuffAlert.nScaleXandY)
	else
		for i = 1, 8 do
			RaidGrid_SelfBuffAlert.handleMain:Lookup("Image_DragBG_" .. i):Hide()
		end
		RaidGrid_SelfBuffAlert.frameSelf:SetSize(0, 0)
	end

	local nX, nY = RaidGrid_SelfBuffAlert.frameSelf:GetRelPos()
	if RaidGrid_SelfBuffAlert.tLastLoc.nX ~= nX and RaidGrid_SelfBuffAlert.tLastLoc.nY ~= nY then
		RaidGrid_SelfBuffAlert.SetPanelPos(nX, nY)
	end
end

function RaidGrid_SelfBuffAlert.RefreshSelfBuffHandle(dwBuffID, bIsRemoved)
	dwBuffID = dwBuffID or -1
	local dwRemoveID = -1
	if bIsRemoved then
		dwRemoveID = dwBuffID
	end

	local nLogic = GetLogicFrameCount()
	local handleBoxEmpty = nil
	for i = 1, RaidGrid_SelfBuffAlert.nBoxMax do
		local handleBox = RaidGrid_SelfBuffAlert.handleMain:Lookup("Handle_Box_" .. i)

		if not handleBox.tInfo or not handleBox.nEndFrame or handleBox.nEndFrame <= nLogic or handleBox.tInfo.dwID == dwRemoveID then
			handleBox:SetAlpha(math.max(0, handleBox:GetAlpha() - 26))
			handleBox.ani:SetAlpha(0)
			handleBox.box:SetOverText(0, "")
			handleBox.textBuffName:SetText("")
			handleBox.tInfo = nil
			handleBox.nEndFrame = nil
		else
			handleBox.text:SetText(JH.GetBuffTimeString(((handleBox.nEndFrame or nLogic) - nLogic) / GLOBAL.GAME_FPS))
			handleBox.ani:SetAlpha(math.max(0, handleBox.ani:GetAlpha() - 8))
		end

		if (not handleBoxEmpty and not handleBox.tInfo) or (handleBox.tInfo and handleBox.tInfo.dwID == dwBuffID) then
			handleBoxEmpty = handleBox
		end
	end

	return handleBoxEmpty
end


function RaidGrid_SelfBuffAlert.UpdateSelfBuffAlertOrg(tRecord, dwMemberID, bIsRemoved, nIndex, dwBuffID, nStackNum, nEndFrame, nLevel)
	if not tRecord or not RaidGrid_EventScrutiny.bBuffListExEnable then
		return
	end

	local handleBoxEmpty = RaidGrid_SelfBuffAlert.RefreshSelfBuffHandle(dwBuffID, bIsRemoved)
	if not handleBoxEmpty then
		return
	end

	if bIsRemoved then
		handleBoxEmpty.tInfo = nil
		handleBoxEmpty.nEndFrame = nil
		return
	end

	handleBoxEmpty.tInfo = tRecord
	handleBoxEmpty.nEndFrame = nEndFrame

	handleBoxEmpty:SetAlpha(215)
	handleBoxEmpty.ani:SetAlpha(215)
	handleBoxEmpty.box:SetObjectSparking(true)

	handleBoxEmpty.box:SetObjectIcon(tRecord.nIconID or 1435)

	if RaidGrid_SelfBuffAlert.bShowBuffName then
		handleBoxEmpty.textBuffName:SetText(tRecord.szName)
	end

	if tRecord.szType == "Debuff" then
		handleBoxEmpty.textBuffName:SetFontColor(255, 64, 64)
		handleBoxEmpty.text:SetFontColor(255, 64, 64)
	else
		handleBoxEmpty.textBuffName:SetFontColor(64, 255, 64)
		handleBoxEmpty.text:SetFontColor(64, 255, 64)
	end
	if nStackNum > 1 then
		handleBoxEmpty.box:SetOverText(0, " x" .. tostring(nStackNum))
	else
		handleBoxEmpty.box:SetOverText(0, "")
	end
end


function RaidGrid_SelfBuffAlert.InitBuffBoxes()
	for i = 1, RaidGrid_SelfBuffAlert.nBoxMax do
		local handleBox = RaidGrid_SelfBuffAlert.handleMain:AppendItemFromIni(szIniFileSelfBuffAlert, "Handle_BuffBoxDummy", "Handle_Box_" .. i)
		handleBox:SetRelPos((i - 1) * 47, 0)

		local box = handleBox:Lookup("Box_Icon")
		local textBuffName = handleBox:Lookup("Text_BuffName")
		local text = handleBox:Lookup("Text_Time")
		local ani = handleBox:Lookup("Animate_Update")
		handleBox.box = box
		handleBox.textBuffName = textBuffName
		handleBox.text = text
		handleBox.ani = ani

		handleBox.ani:SetAlpha(0)
		textBuffName:SetText("")
		text:SetText("")
		box:SetObject(1,0)
		box:ClearObjectIcon()
		box:SetOverTextPosition(0, ITEM_POSITION.LEFT_BOTTOM)
		box:SetOverTextFontScheme(0, 15)
		box:SetOverText(0, "")

		handleBox.box.handleParent = handleBox
		handleBox.box.OnItemMouseEnter = function()
			local tRecord = this.handleParent.tInfo
			if tRecord and tRecord.dwID then
				local x, y = this:GetAbsPos()
				local w, h = this:GetSize()
				if tRecord.szType == "Buff" or tRecord.szType == "Debuff" then
					OutputBuffTip(GetClientPlayer().dwID, tRecord.dwID, tRecord.nLevel or 1, 1, false, 999, {x, y, w, h})
				end
			end
		end
		handleBox.box.OnItemMouseLeave = function()
			HideTip()
		end
		handleBox.box.OnItemRButtonClick = function()
			local tRecord = this.handleParent.tInfo
			if tRecord and tRecord.dwID then
				local player = GetClientPlayer()
				if not player then return end
				local tBuffList = {}
				if player then
					tBuffList = JH.GetBuffList(player)
				end
				local bExist, tBuff = JH.HasBuff(tRecord.dwID,player)
				local bCanceled = false
				if bExist and tBuff.bCanCancel then
					bCanceled = true
					player.CancelBuff(tBuff.nIndex)
				end
				if not bCanceled then
					local handleBox1 = this.handleParent
					handleBox1.text:SetText("")
					handleBox1:SetAlpha(math.max(0, handleBox1:GetAlpha() - 26))
					handleBox1.ani:SetAlpha(0)
					handleBox1.box:SetOverText(0, "")
					handleBox1.textBuffName:SetText("")
					handleBox1.tInfo = nil
					handleBox1.nEndFrame = nil
				end
			end
		end

		handleBox:Show()
	end
	RaidGrid_SelfBuffAlert.handleMain:FormatAllItemPos()
end

function RaidGrid_SelfBuffAlert.SetPanelPos(nX, nY)
	if not nX or not nY then
		RaidGrid_SelfBuffAlert.frameSelf:SetPoint("CENTER", -1 * 47 * 4, -200, "CENTER", 0, 0)
	else
		local nW, nH = Station.GetClientSize(true)
		if nX < 0 then nX = 0 end
		if nX > nW - 100 then nX = nW - 100 end
		if nY < 0 then nY = 0 end
		if nY > nH - 110 then nY = nH - 110 end
		RaidGrid_SelfBuffAlert.frameSelf:SetRelPos(nX, nY)
	end
	RaidGrid_SelfBuffAlert.tLastLoc.nX, RaidGrid_SelfBuffAlert.tLastLoc.nY = RaidGrid_SelfBuffAlert.frameSelf:GetRelPos()
end

function RaidGrid_SelfBuffAlert.OpenPanel()
	local frame = Station.Lookup("Topmost2/RaidGrid_SelfBuffAlert")
	if not frame then
		frame = Wnd.OpenWindow(RGES_INI_PATH ..  "RaidGrid_SelfBuffAlert.ini", "RaidGrid_SelfBuffAlert")
	end
	frame:Show()
	RaidGrid_SelfBuffAlert.frameSelf = frame
	RaidGrid_SelfBuffAlert.handleMain = frame:Lookup("", "")
	RaidGrid_SelfBuffAlert.handleMain:Lookup("Handle_BuffBoxDummy"):Hide()
	----------------------------------------------------------------------------------------------------------------------------
	RaidGrid_SelfBuffAlert.InitBuffBoxes()
	if RaidGrid_SelfBuffAlert.nScaleXandY > 0 and RaidGrid_SelfBuffAlert.nScaleXandY ~= 1 then
		frame:Scale(RaidGrid_SelfBuffAlert.nScaleXandY, RaidGrid_SelfBuffAlert.nScaleXandY)
	end
end

----------------------------------------------------------------
----RaidGrid_SelfBuffAlert.lua----
----------------------------------------------------------------


----------------------------------------------------------------
----RaidGrid_CenterAlarm.lua----
----------------------------------------------------------------

RaidGrid_CenterAlarm ={
	Anchor = {
		s = "CENTER",
		r = "CENTER",
		x = 0,
		y = -150,
	}
}
RegisterCustomData("RaidGrid_CenterAlarm.Anchor")

function RaidGrid_CenterAlarm.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("CUSTOM_DATA_LOADED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")

end


function RaidGrid_CenterAlarm.UpdateText(msg)
	Station.Lookup("Normal/RaidGrid_CenterAlarm"):Lookup("",""):Lookup("Text_CampText"):SetText(msg)
end

function RaidGrid_CenterAlarm.UpdateAlpha(alpha)
	Station.Lookup("Normal/RaidGrid_CenterAlarm"):Lookup("",""):SetAlpha(alpha)
end

function RaidGrid_CenterAlarm.UpdateAnchor(frame)
	local anchor = RaidGrid_CenterAlarm.Anchor
	frame:SetPoint(anchor.s, 0, 0, anchor.r, anchor.x, anchor.y)
	frame:CorrectPos()
end
function RaidGrid_CenterAlarm.OnFrameDragEnd()
	this:CorrectPos()
	RaidGrid_CenterAlarm.Anchor = GetFrameAnchor(this)
end

function RaidGrid_CenterAlarm.OnEvent(event)
	if event=="UI_SCALED" or (event=="CUSTOM_DATA_LOADED" and arg0=="Role") then
		RaidGrid_CenterAlarm.UpdateAnchor(this)
	elseif event == "ON_ENTER_CUSTOM_UI_MODE" or event == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, _L["CenterAlarm"], true)
	end
end


Wnd.OpenWindow(RGES_INI_PATH .. "RaidGrid_CenterAlarm.ini", "RaidGrid_CenterAlarm")

----------------------------------------------------------------
----RaidGrid_CenterAlarm.lua----
----------------------------------------------------------------




----------------------------------------------------------------
----RaidGrid_RedAlarm.lua----
----------------------------------------------------------------

RaidGrid_RedAlarm = {
	bRedAlarm = true,
	bCenterAlarm = true,
	r = 255,
	g = 0,
	b = 0,
	pRed = nil,
	bUp = true,
	nMaxAlpha = 128,
	nAlpha = 0,
	nTime = 0,
	nSpeed = 16,
}


function RaidGrid_RedAlarm.OnFrameCreate()
	local frame = Station.Lookup("Topmost/RaidGrid_RedAlarm")
	local handle = frame:Lookup("", "")
	RaidGrid_RedAlarm.pRed = handle:Lookup("Shadow_Info")
end

function RaidGrid_RedAlarm.OnFrameRender()
	local fps = GetFPS()
	local passed_time = 1000.0 / fps

	if RaidGrid_RedAlarm.nTime > 0 then
		if RaidGrid_RedAlarm.bUp then
			RaidGrid_RedAlarm.nAlpha = RaidGrid_RedAlarm.nAlpha + RaidGrid_RedAlarm.nSpeed * passed_time / 67
		else
			RaidGrid_RedAlarm.nAlpha = RaidGrid_RedAlarm.nAlpha - RaidGrid_RedAlarm.nSpeed * passed_time / 67
		end
		if RaidGrid_RedAlarm.nAlpha > RaidGrid_RedAlarm.nMaxAlpha then
			RaidGrid_RedAlarm.nAlpha = RaidGrid_RedAlarm.nMaxAlpha
			RaidGrid_RedAlarm.bUp = false
		end
		if RaidGrid_RedAlarm.nAlpha < 0 then
			RaidGrid_RedAlarm.nAlpha = 0
			RaidGrid_RedAlarm.bUp = true
			RaidGrid_RedAlarm.nTime = RaidGrid_RedAlarm.nTime - 1
		end
		local red_alpha = RaidGrid_RedAlarm.nAlpha
		local center_alpha = RaidGrid_RedAlarm.nAlpha + 128
		if not RaidGrid_RedAlarm.bRedAlarm then
			red_alpha = 0
		end
		if not RaidGrid_RedAlarm.bCenterAlarm then
			center_alpha = 0
		end
		RaidGrid_RedAlarm.Draw( red_alpha )
		RaidGrid_CenterAlarm.UpdateAlpha( center_alpha )
	else
		RaidGrid_RedAlarm.Draw( 0 )
		RaidGrid_CenterAlarm.UpdateAlpha( 0 )
	end
end


function RaidGrid_RedAlarm.FlashOrg(t, msg, bRed, bCenter, r, g, b)
	if not t or tonumber(t)<=0 then
		return
	end
	RaidGrid_RedAlarm.r = r
	RaidGrid_RedAlarm.g = g
	RaidGrid_RedAlarm.b = b
	RaidGrid_RedAlarm.bRedAlarm = bRed
	RaidGrid_RedAlarm.bCenterAlarm = bCenter
	RaidGrid_RedAlarm.nTime = t
	RaidGrid_RedAlarm.bUp = true
	RaidGrid_RedAlarm.nAlpha = 0
	RaidGrid_CenterAlarm.UpdateText(msg)
end

function RaidGrid_RedAlarm.Draw(alpha)
	local xScreen, yScreen = Station.GetClientSize()
	local nR, nG, nB = RaidGrid_RedAlarm.r, RaidGrid_RedAlarm.g, RaidGrid_RedAlarm.b
	RaidGrid_RedAlarm.pRed:SetTriangleFan(true)
	RaidGrid_RedAlarm.pRed:ClearTriangleFanPoint()
	RaidGrid_RedAlarm.pRed:AppendTriangleFanPoint(xScreen/2, 	yScreen/2, 	nR, nG, nB, 0)
	RaidGrid_RedAlarm.pRed:AppendTriangleFanPoint(0, 					0, 					nR, nG, nB, alpha)
	RaidGrid_RedAlarm.pRed:AppendTriangleFanPoint(0, 					yScreen, 		nR, nG, nB, alpha)
	RaidGrid_RedAlarm.pRed:AppendTriangleFanPoint(xScreen, 		yScreen, 		nR, nG, nB, alpha)
	RaidGrid_RedAlarm.pRed:AppendTriangleFanPoint(xScreen, 		0, 					nR, nG, nB, alpha)
	RaidGrid_RedAlarm.pRed:AppendTriangleFanPoint(0, 					0, 					nR, nG, nB, alpha)
end

Wnd.OpenWindow(RGES_INI_PATH .. "RaidGrid_RedAlarm.ini", "RaidGrid_RedAlarm")

----------------------------------------------------------------
----RaidGrid_RedAlarm.lua----
----------------------------------------------------------------

----------------------------------------------------------------
----RaidGrid_ReadingBar.lua----
----------------------------------------------------------------

RaidGrid_ReadingBar = {
	target={},
	TOTAL=8,--ini中总栏个数，非自动追加，需要修改ini调整，所以只能小于等于8，不能大于8
	}
RaidGrid_ReadingBar.loc = {
	x=150;
	y=250;
	}
RegisterCustomData("RaidGrid_ReadingBar.loc")

function RaidGrid_ReadingBar.show()
	local frame = Station.Lookup("Normal/RaidGrid_ReadingBar")
	if frame then
		if not frame:IsVisible() then
			frame:Show()
		end
	else
		frame = Wnd.OpenWindow(RGES_INI_PATH .. "RaidGrid_ReadingBar.ini", "RaidGrid_ReadingBar")
		frame:Show()
	end
end

function RaidGrid_ReadingBar.hide()
	local frame = Station.Lookup("Normal/RaidGrid_ReadingBar")
	if frame then
		if frame:IsVisible() then
			frame:Hide()
		end
	end
end


function RaidGrid_ReadingBar.putOrg(szTarget)
	if table.getn(RaidGrid_ReadingBar.target)>=RaidGrid_ReadingBar.TOTAL then
		return
	else
		--  msg(szTarget.szName..szname)
		for _,tar in ipairs(RaidGrid_ReadingBar.target) do
			if szTarget.dwID==tar.caster.dwID then
				return
			end
		end
		table.insert(RaidGrid_ReadingBar.target,{caster=szTarget, shown=true})
		RaidGrid_ReadingBar.show()
    end
end

function RaidGrid_ReadingBar.OnFrameBreathe()
	if not GetClientPlayer() then
		return
	end
    local frame = Station.Lookup("Normal/RaidGrid_ReadingBar")
    local tarType, tarID = GetClientPlayer().GetTarget()
    local m=1
	for i,targ in ipairs(RaidGrid_ReadingBar.target) do
		m=i
		if targ then
			local tar = targ.caster
			local handle = frame:Lookup("", "Handle_Bar_"..tostring(i))
			if not i or not tar then
				handle:Hide()
			elseif not GetPlayer(targ.caster.dwID) and not GetNpc(targ.caster.dwID)then
				handle:Hide()
				table.remove(RaidGrid_ReadingBar.target,i)
			else
			-----照抄自target ui
				local bPrePare, dwID, dwLevel, fP = tar.GetSkillPrepareState()
				if bPrePare and handle.nActionState ~= ACTION_STATE.PREPARE then
					handle:SetAlpha(255)
					handle:Show()
					handle:Lookup("Image_Progress_"..i):Show()
					handle:Lookup("Image_FlashS_"..i):Hide()
					handle:Lookup("Image_FlashF_"..i):Hide()
					handle:Lookup("Text_Name_"..i):SetText(Table_GetSkillName(dwID, dwLevel))
					handle:Lookup("Text_Caster_"..i):SetText(tar.szName)
					if tarID==targ.caster.dwID then
						handle:Lookup("Text_Caster_"..i):SetFontColor(255,255,0)
					else
						handle:Lookup("Text_Caster_"..i):SetFontColor(255,255,255)
					end
					handle.nActionState = ACTION_STATE.PREPARE
				elseif not bPrePare and handle.nActionState == ACTION_STATE.PREPARE then
					handle.nActionState = ACTION_STATE.DONE
				end

				if handle.nActionState == ACTION_STATE.PREPARE then
					handle:Lookup("Image_Progress_"..i):SetPercentage(fP)
				elseif handle.nActionState == ACTION_STATE.DONE then
					handle:Lookup("Image_FlashS_"..i):Show()
					handle.nActionState = ACTION_STATE.FADE
				elseif handle.nActionState == ACTION_STATE.BREAK then
					handle:Lookup("Image_FlashF_"..i):Show()
					handle.nActionState = ACTION_STATE.FADE
				elseif handle.nActionState == ACTION_STATE.FADE then
					local nAlpha = handle:GetAlpha()
					nAlpha = nAlpha - 10
					if nAlpha > 0 then
						handle:SetAlpha(nAlpha)
					else
						handle:SetAlpha(0)
						handle.nActionState = ACTION_STATE.NONE
						handle:Hide()
						table.remove(RaidGrid_ReadingBar.target,i)
					end
				else
					handle:Hide()
					targ.shown=false
				end
			end
		end
	end
	for i,targ in ipairs(RaidGrid_ReadingBar.target)do
		if targ.shown==false then
			frame:Lookup("", "Handle_Bar_"..tostring(i)):Hide()
			table.remove(RaidGrid_ReadingBar.target,i)
		end
	end
	if m<8 then
		for t=m+1,8 do
			Station.Lookup("Normal/RaidGrid_ReadingBar"):Lookup("", "Handle_Bar_"..tostring(t)):Hide()
		end
	end
	local le=table.getn(RaidGrid_ReadingBar.target)
	if le>0 then
		--frame.hide()
	--else
		frame:SetSize(300,le*30)
	end
end

function RaidGrid_ReadingBar.OnFrameCreate()
	this:SetRelPos(RaidGrid_ReadingBar.loc.x,RaidGrid_ReadingBar.loc.y)
	this:RegisterEvent("CUSTOM_DATA_LOADED")
	this:RegisterEvent("UI_SCALED")
    this:RegisterEvent("NPC_LEAVE_SCENE")
    this:RegisterEvent("OT_ACTION_PROGRESS_BREAK")
    this:RegisterEvent("PLAYER_LEAVE_SCENE")
end

function RaidGrid_ReadingBar.OnActionBreak(frame,k)
	local handle = frame:Lookup("", "Handle_Bar_"..k)
	handle.nActionState = ACTION_STATE.BREAK
end

function RaidGrid_ReadingBar.OnEvent(event)--处理读条被打断事件
    if event == "OT_ACTION_PROGRESS_BREAK" then
		for i,targ in ipairs(RaidGrid_ReadingBar.target) do
			if arg0 == targ.caster.dwID then
			local frame = Station.Lookup("Normal/RaidGrid_ReadingBar")
				RaidGrid_ReadingBar.OnActionBreak(frame,i)
			end
		end
    elseif event == "PLAYER_LEAVE_SCENE" then
		local player = GetClientPlayer()
        for i,targ in ipairs(RaidGrid_ReadingBar.target) do
			if targ.caster.dwType == TARGET.PLAYER and (targ.caster.dwID == arg0)then
				Station.Lookup("Normal/RaidGrid_ReadingBar"):Lookup("", "Handle_Bar_"..tostring(i)):Hide()
				table.remove(RaidGrid_ReadingBar.target,i)
				return
			end
        end
	elseif event == "NPC_LEAVE_SCENE" then
		for i,targ in ipairs(RaidGrid_ReadingBar.target) do
			if targ.caster.dwType == TARGET.NPC and targ.caster.dwID == arg0 then
				Station.Lookup("Normal/RaidGrid_ReadingBar"):Lookup("", "Handle_Bar_"..tostring(i)):Hide()
				table.remove(RaidGrid_ReadingBar.target,i)
				return
			end
        end
    elseif event=="UI_SCALED" then
        this:SetRelPos(RaidGrid_ReadingBar.loc.x,RaidGrid_ReadingBar.loc.y)
    elseif event=="CUSTOM_DATA_LOADED" then
        this:SetRelPos(RaidGrid_ReadingBar.loc.x,RaidGrid_ReadingBar.loc.y)
    end
end

function RaidGrid_ReadingBar.OnLButtonUp()
	RaidGrid_ReadingBar.loc.x,RaidGrid_ReadingBar.loc.y=  Station.Lookup("Normal/RaidGrid_ReadingBar"):GetRelPos()
end

----------------------------------------------------------------
----RaidGrid_ReadingBar.lua----
----------------------------------------------------------------



----------------------------------------------------------------
----RaidGrid_BossCallAlert.lua----
----------------------------------------------------------------

RaidGrid_BossCallAlert = {}

RaidGrid_BossCallAlert.TalkMonitor = true
RaidGrid_BossCallAlert.bWarningMessageMonitor = true
RaidGrid_BossCallAlert.bDungeonOnly = false
RaidGrid_BossCallAlert.bBossOnly = false
RaidGrid_BossCallAlert.bPartyOnly = false
RaidGrid_BossCallAlert.macthall = true
RaidGrid_BossCallAlert.WHISPER = false
RaidGrid_BossCallAlert.RAID = false
RaidGrid_BossCallAlert.Flash = true
RaidGrid_BossCallAlert.CenterAlarm = true
RaidGrid_BossCallAlert.bChatAlertEnable = false

RaidGrid_BossCallAlert.tRGRedAlarm = {0, 255, 0, 1}

RegisterCustomData("RaidGrid_BossCallAlert.TalkMonitor")
RegisterCustomData("RaidGrid_BossCallAlert.bWarningMessageMonitor")
RegisterCustomData("RaidGrid_BossCallAlert.bDungeonOnly")
RegisterCustomData("RaidGrid_BossCallAlert.bBossOnly")
RegisterCustomData("RaidGrid_BossCallAlert.bPartyOnly")
RegisterCustomData("RaidGrid_BossCallAlert.macthall")
RegisterCustomData("RaidGrid_BossCallAlert.WHISPER")
RegisterCustomData("RaidGrid_BossCallAlert.RAID")
RegisterCustomData("RaidGrid_BossCallAlert.Flash")
RegisterCustomData("RaidGrid_BossCallAlert.CenterAlarm")
RegisterCustomData("RaidGrid_BossCallAlert.tRGRedAlarm")
RegisterCustomData("RaidGrid_BossCallAlert.bChatAlertEnable")

function RaidGrid_BossCallAlert.ChannelSay(szTargetTargetName, szTargetName)
	local playerClient = GetClientPlayer()

	local r, g, b = unpack(RaidGrid_BossCallAlert.tRGRedAlarm)
		if playerClient.szName == szTargetTargetName then
			if RaidGrid_BossCallAlert.Flash or RaidGrid_BossCallAlert.CenterAlarm then
				RaidGrid_RedAlarm.FlashOrg(RaidGrid_EventScrutiny.nCenterAlarmTime, szTargetName.."点【你】名了！！！", RaidGrid_BossCallAlert.Flash, RaidGrid_BossCallAlert.CenterAlarm, r, g, b)
			end
		elseif RaidGrid_BossCallAlert.CenterAlarm then
			RaidGrid_RedAlarm.FlashOrg(RaidGrid_EventScrutiny.nCenterAlarmTime, szTargetName.."点【"..szTargetTargetName.."】名了！！！", false, true, r, g, b)
		end
	if RaidGrid_BossCallAlert.bChatAlertEnable and RaidGrid_BossCallAlert.WHISPER then
		JH.Talk(szTargetTargetName, {{type = "text", text = szTargetName.."点【你】名了！！！"}})
	end

	if RaidGrid_BossCallAlert.bChatAlertEnable and RaidGrid_BossCallAlert.RAID then
		JH.Talk({{type = "text", text = szTargetName.."点【"..szTargetTargetName.."】名了！！！"}})
	end
end

function RaidGrid_BossCallAlert.CallProcess(bossname, saydata)
	local Clientplayer = GetClientPlayer()
	if not Clientplayer then return end
	if not Clientplayer.IsInParty() and RaidGrid_BossCallAlert.bPartyOnly then
		--OutputMessage("MSG_ANNOUNCE_YELLOW","你并未组队")
		return
	end

	if string.find(saydata,Clientplayer.szName) then
		RaidGrid_BossCallAlert.ChannelSay(Clientplayer.szName, bossname)
		if RaidGrid_EventScrutiny.bCalledTimerHeadEnable then
			FireEvent("JH_SCREENHEAD", Clientplayer.dwID, { txt = _L("%s Call Name",bossname)})
		end
		--return
	end

	if Clientplayer.IsInParty() and RaidGrid_BossCallAlert.macthall then
		local hTeam = GetClientTeam()
		local nGroupNum = hTeam.nGroupNum
		for i = 0, nGroupNum - 1 do
			local tGroupInfo = hTeam.GetGroupInfo(i)
			if tGroupInfo and tGroupInfo.MemberList then
				for _,dwID in pairs(tGroupInfo.MemberList) do
					local player = hTeam.GetMemberInfo(dwID)
					if player then
						if string.find(saydata,player.szName) then
							if player.szName ~= Clientplayer.szName then
								RaidGrid_BossCallAlert.ChannelSay(player.szName, bossname)
								if RaidGrid_EventScrutiny.bCalledTimerHeadEnable then
									FireEvent("JH_SCREENHEAD", dwID, { txt = _L("%s Call Name",bossname)})
								end
								--return
							end
						end
					end
				end
			end
		end
	end
end

function RaidGrid_BossCallAlert.ProcessBossCallSet(bossname, saydata)
	local Clientplayer = GetClientPlayer()
	if not Clientplayer or not RaidGrid_BossCallAlert.tRecords or not RaidGrid_BossCallAlert.tRecords.tBossCall then
		return
	end
	for i = 1, #RaidGrid_BossCallAlert.tRecords.tBossCall, 1 do
		local tRecord = RaidGrid_BossCallAlert.tRecords.tBossCall[i]
		if tRecord.bOn and tRecord.szText and tRecord.szText ~= "" and string.find(saydata,tRecord.szText) then
			if not tRecord.szBossName or tRecord.szBossName == "" or tRecord.szBossName == bossname then
				local nRGRAR, nRGRAG, nRGRAB = RaidGrid_BossCallAlert.tRGRedAlarm[1], RaidGrid_BossCallAlert.tRGRedAlarm[2], RaidGrid_BossCallAlert.tRGRedAlarm[3]
				RaidGrid_RedAlarm.FlashOrg(RaidGrid_EventScrutiny.nCenterAlarmTime, tRecord.szName or saydata, tRecord.bFlash, tRecord.bCenterAlarm, nRGRAR, nRGRAG, nRGRAB)

				local tInfo = tRecord.szName or saydata
				if RaidGrid_BossCallAlert.bChatAlertEnable and tRecord.bRAID then
					JH.Talk(tInfo)
				end
				if RaidGrid_BossCallAlert.bChatAlertEnable and tRecord.bWHISPER then
					JH.WhisperToTeamMember(tInfo)
				end

				if tRecord.nTime1 and tRecord.nTime1>0 then
					FireEvent("JH_ST_CREATE", JH_ST_TYPE.NPC_TALK, i .. "T1", {
						szName = tRecord.szName or tRecord.szText,
						nTime  = tRecord.nTime1,
						nIcon  = tRecord.nIconID or 340,
						bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
					})
				end
				if tRecord.nTime2 and tRecord.nTime2>0 then
					FireEvent("JH_ST_CREATE", JH_ST_TYPE.NPC_TALK, i .. "T2", {
						szName = tRecord.szName2 or tRecord.szText,
						nTime  = tRecord.nTime2,
						nIcon  = tRecord.nIconID or 340,
						bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
					})
				end
				return
			end
		end
	end
end

function RaidGrid_BossCallAlert.BossCall(event)
	--event=PLAYER_SAY arg0=喊话内容 arg1=喊话者ID arg2=频道 arg3=喊话者名称
	if event == "PLAYER_SAY" then
		if RaidGrid_EventScrutiny.bEnable and RaidGrid_BossCallAlert.TalkMonitor then
			local npc=GetNpc(arg1)
			if not npc then return end
			if RaidGrid_BossCallAlert.bDungeonOnly and not JH.IsInDungeon(true) then return end
			if RaidGrid_BossCallAlert.bBossOnly and GetNpcIntensity(npc)<4 then return end
			local bossname = JH.GetTemplateName(npc) or tostring(arg3)
			local saydata = arg0
			RaidGrid_BossCallAlert.ProcessBossCallSet(bossname, saydata)
			RaidGrid_BossCallAlert.CallProcess(bossname, saydata)
		end
	end
end
RegisterEvent("PLAYER_SAY",RaidGrid_BossCallAlert.BossCall)


RaidGrid_BossCallAlert.szGetMessageText1 = ""
RaidGrid_BossCallAlert.szGetMessageTimeEnd1 = 0
RaidGrid_BossCallAlert.szGetMessageText2 = ""
RaidGrid_BossCallAlert.szGetMessageTimeEnd2 = 0
RaidGrid_BossCallAlert.nGetMessageTimeCD = 5


function RaidGrid_BossCallAlert.GetWarningMessageOrg()
	if not RaidGrid_EventScrutiny.bEnable then
		return
	end

	if not RaidGrid_BossCallAlert.bWarningMessageMonitor then
		return
	end
	local szText = ""
	local fLogicTime = JH.GetLogicTime()
	local hFrame = Station.Lookup("Topmost/WarningTipPanel1")
	if hFrame then
		local hText = hFrame:Lookup("", "Text_Tip")
		if hText then
			szText = hText:GetText()
			if szText and szText ~= "" then
				if (szText ~= RaidGrid_BossCallAlert.szGetMessageText1) or (RaidGrid_BossCallAlert.szGetMessageTimeEnd1 <= fLogicTime) then
					RaidGrid_BossCallAlert.szGetMessageText1 = szText
					RaidGrid_BossCallAlert.szGetMessageTimeEnd1 = fLogicTime + RaidGrid_BossCallAlert.nGetMessageTimeCD
					RaidGrid_BossCallAlert.OutputWarningMessageAdd(szText)
				end
			end
		end
	end
	local szText2 = ""
	local hFrame2 = Station.Lookup("Topmost/WarningTipPanel2")
	if hFrame2 then
		local hText2 = hFrame2:Lookup("", "Text_Tip")
		if hText2 then
			szText2 = hText2:GetText()
			if szText2 and szText2 ~= "" then
				if (szText2 ~= RaidGrid_BossCallAlert.szGetMessageText2) or (RaidGrid_BossCallAlert.szGetMessageTimeEnd2 <= fLogicTime) then
					RaidGrid_BossCallAlert.szGetMessageText2 = szText2
					RaidGrid_BossCallAlert.szGetMessageTimeEnd2 = fLogicTime + RaidGrid_BossCallAlert.nGetMessageTimeCD
					RaidGrid_BossCallAlert.OutputWarningMessageAdd(szText2)
				end
			end
		end
	end
end

RaidGrid_BossCallAlert.tWarningMessages = {}
function RaidGrid_BossCallAlert.ProcessWarningMessagesSet(saydata)
	local Clientplayer = GetClientPlayer()
	if not Clientplayer or not RaidGrid_BossCallAlert.tRecords or not RaidGrid_BossCallAlert.tRecords.tWarningMessages then
		return
	end
	for i = 1, #RaidGrid_BossCallAlert.tRecords.tWarningMessages, 1 do
		local tRecord = RaidGrid_BossCallAlert.tRecords.tWarningMessages[i]
		if tRecord.bOn and tRecord.szText and tRecord.szText ~= "" and string.find(saydata,tRecord.szText) then
			local nRGRAR, nRGRAG, nRGRAB = RaidGrid_BossCallAlert.tRGRedAlarm[1], RaidGrid_BossCallAlert.tRGRedAlarm[2], RaidGrid_BossCallAlert.tRGRedAlarm[3]
			RaidGrid_RedAlarm.FlashOrg(RaidGrid_EventScrutiny.nCenterAlarmTime, tRecord.szName or saydata, tRecord.bFlash, tRecord.bCenterAlarm, nRGRAR, nRGRAG, nRGRAB)

			local tInfo = tRecord.szName or saydata
			if RaidGrid_BossCallAlert.bChatAlertEnable and tRecord.bRAID then
				JH.Talk(tInfo)
			end
			if RaidGrid_BossCallAlert.bChatAlertEnable and tRecord.bWHISPER then
				JH.WhisperToTeamMember(tInfo)
			end

			if tRecord.nTime1 and tRecord.nTime1>0 then
				FireEvent("JH_ST_CREATE", JH_ST_TYPE.SYS_TALK, i .. "T1", {
					szName = tRecord.szName or tRecord.szText,
					nTime  = tRecord.nTime1,
					nIcon  = tRecord.nIconID or 340,
					bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
				})
			end
			if tRecord.nTime2 and tRecord.nTime2>0 then
				FireEvent("JH_ST_CREATE", JH_ST_TYPE.SYS_TALK, i .. "T2", {
					szName = tRecord.szName2 or tRecord.szText,
					nTime  = tRecord.nTime2,
					nIcon  = tRecord.nIconID or 340,
					bTalk  = RaidGrid_EventScrutiny.bSkillTimerSay
				})
			end
			return
		end
	end
end

function RaidGrid_BossCallAlert.OutputWarningMessageAdd(szText)
	local Clientplayer = GetClientPlayer()
	if not Clientplayer then
		return
	end

	if RaidGrid_BossCallAlert.bDungeonOnly and not JH.IsInDungeon(true) then
		return
	end

	if RaidGrid_BossCallAlert.bPartyOnly and not Clientplayer.IsInParty() then
		return
	end

	if not szText then
		return
	end

	local saydata = tostring(szText)
	RaidGrid_BossCallAlert.ProcessWarningMessagesSet(saydata)

	if string.find(saydata,Clientplayer.szName) then
		RaidGrid_BossCallAlert.WarningMessageAlarm(Clientplayer.szName, saydata)
		if RaidGrid_EventScrutiny.bCalledTimerHeadEnable then
			FireEvent("JH_SCREENHEAD", Clientplayer.dwID, nil)
		end
	end

	if Clientplayer.IsInParty() and RaidGrid_BossCallAlert.macthall then
		local hTeam = GetClientTeam()
		local nGroupNum = hTeam.nGroupNum
		for i = 0, nGroupNum - 1 do
			local tGroupInfo = hTeam.GetGroupInfo(i)
			if tGroupInfo and tGroupInfo.MemberList then
				for _,dwID in pairs(tGroupInfo.MemberList) do
					local player = hTeam.GetMemberInfo(dwID)
					if player then
						if string.find(saydata,player.szName) then
							if player.szName ~= Clientplayer.szName then
								RaidGrid_BossCallAlert.WarningMessageAlarm(player.szName, saydata)
								if RaidGrid_EventScrutiny.bCalledTimerHeadEnable then
									FireEvent("JH_SCREENHEAD", dwID, nil)
								end
							end
						end
					end
				end
			end
		end
	end
end

function RaidGrid_BossCallAlert.WarningMessageAlarm(szTargetTargetName, saydata)
	local playerClient = GetClientPlayer()

	local r, g, b = unpack(RaidGrid_BossCallAlert.tRGRedAlarm)
	if playerClient.szName == szTargetTargetName then
		if RaidGrid_BossCallAlert.Flash or RaidGrid_BossCallAlert.CenterAlarm then
			RaidGrid_RedAlarm.FlashOrg(RaidGrid_EventScrutiny.nCenterAlarmTime, "【你】被点名了！！！", RaidGrid_BossCallAlert.Flash, RaidGrid_BossCallAlert.CenterAlarm, r, g, b)
		end
	else
		if RaidGrid_BossCallAlert.CenterAlarm then
			RaidGrid_RedAlarm.FlashOrg(RaidGrid_EventScrutiny.nCenterAlarmTime, "【"..szTargetTargetName.."】被点名了！！！", false, true, r, g, b)
		end

		if RaidGrid_BossCallAlert.bChatAlertEnable and RaidGrid_BossCallAlert.WHISPER then
			JH.Talk(szTargetTargetName,{{type = "text", text = "【你】被点名了！！！"}})
		end

		if RaidGrid_BossCallAlert.bChatAlertEnable and RaidGrid_BossCallAlert.RAID then
			JH.Talk({{type = "text", text = "【"..szTargetTargetName.."】被点名了！！！"}})
		end
	end

end

---------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------自定义监控数据菜单相关--------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------

RaidGrid_BossCallAlert.tRecords = {
	tWarningMessages = {},
	tBossCall = {},
}
RaidGrid_BossCallAlert.tDefaultSetForAdd = {
		["bRAID"] = false,
		["bWHISPER"] = false,
		["bFlash"] = true,
		["bCenterAlarm"] = true,
		["bOn"] = true,
	}
function RaidGrid_BossCallAlert.SetNewName(handleRecord)
	if not handleRecord then
		return
	end
	local Recall = function(szText)
		if not szText or szText == "" then
			return
		end
		handleRecord.szName = szText
	end
	GetUserInput("输入新名字：", Recall, nil, function() end, nil, handleRecord.szName, 310)
end
function RaidGrid_BossCallAlert.SetNewName2(handleRecord)
	if not handleRecord then
		return
	end
	local Recall = function(szText)
		if not szText or szText == "" then
			return
		end
		handleRecord.szName2 = szText
	end
	GetUserInput("输入倒计时名字2：", Recall, nil, function() end, nil, handleRecord.szName2, 310)
end
function RaidGrid_BossCallAlert.SetNewBossName(handleRecord)
	if not handleRecord then
		return
	end
	local Recall = function(szText)
		handleRecord.szBossName = szText
	end
	GetUserInput("输入新Boss名字：", Recall, nil, function() end, nil, handleRecord.szBossName, 31)
end
function RaidGrid_BossCallAlert.SetNewText(handleRecord)
	if not handleRecord then
		return
	end
	local Recall = function(szText)
		if not szText or szText == "" then
			return
		end
		handleRecord.szText = szText
	end
	GetUserInput("输入新喊话内容：", Recall, nil, function() end, nil, handleRecord.szText, 310)
end
function RaidGrid_BossCallAlert.SetNewTime1(handleRecord)
	if not handleRecord then
		return
	end
	local Recall = function(szText)
		if not szText or szText == "" then
			return
		end
		local nCount = tonumber(szText)
		if not nCount then
			return
		end
		if nCount >= 0 then
			handleRecord.nTime1 = nCount
		end
	end
	GetUserInput("输入新倒计时1：", Recall, nil, function() end, nil, handleRecord.nTime1, 31)
end
function RaidGrid_BossCallAlert.SetNewTime2(handleRecord)
	if not handleRecord then
		return
	end
	local Recall = function(szText)
		if not szText or szText == "" then
			return
		end
		local nCount = tonumber(szText)
		if not nCount then
			return
		end
		if nCount >= 0 then
			handleRecord.nTime2 = nCount
		end
	end
	GetUserInput("输入新倒计时2：", Recall, nil, function() end, nil, handleRecord.nTime2, 31)
end
function RaidGrid_BossCallAlert.AddList(szType, szName)
	if not szName or szName == "" then
		return
	end
	local tNewRecord = clone(RaidGrid_BossCallAlert.tDefaultSetForAdd)
	tNewRecord.szName = szName
	tNewRecord.szText = szName
	tNewRecord.szType = szType
	table.insert(RaidGrid_BossCallAlert.tRecords[szType], tNewRecord)
end
RaidGrid_BossCallAlert.tRecordsNames = {
	["tWarningMessages"] = "官方自带提示栏喊话监控设置：",
	["tBossCall"] = "聊天栏NPC喊话监控设置：",
}
function RaidGrid_BossCallAlert.tPopOptions(szType)
	local tOptions = {
				szOption = RaidGrid_BossCallAlert.tRecordsNames[szType],
			}
	for i = 1, #RaidGrid_BossCallAlert.tRecords[szType], 1 do
		local tRecord = RaidGrid_BossCallAlert.tRecords[szType][i]
		local tMenu = {
			szOption = tRecord.szName,
			bCheck = true,
			bChecked = tRecord.bOn,
			fnAction = function()
				tRecord.bOn = not tRecord.bOn
			end,
			fnAutoClose = function() return true end}
		local tMenuNewName = {
			szOption = "定义名字：" .. tRecord.szName,
			bCheck = false,
			bChecked = false,
			fnAction = function()
				RaidGrid_BossCallAlert.SetNewName(tRecord)
			end,
			fnAutoClose = function() return true end}
		local tMenuNewBossName = {
			szOption = "NPC名字：" .. (tRecord.szBossName or "未定义"),
			bCheck = false,
			bChecked = false,
			fnAction = function()
				RaidGrid_BossCallAlert.SetNewBossName(tRecord)
			end,
			fnAutoClose = function() return true end}
		local tMenuNewText = {
			szOption = "喊话内容：" .. (tRecord.szText or "未定义"),
			bCheck = false,
			bChecked = false,
			fnAction = function()
				RaidGrid_BossCallAlert.SetNewText(tRecord)
			end,
			fnAutoClose = function() return true end}
		local tMenuNewTime1 = {
			szOption = "倒计时1：" .. tostring(tRecord.nTime1 or 0) .. "秒",
			bCheck = false,
			bChecked = false,
			fnAction = function()
				RaidGrid_BossCallAlert.SetNewTime1(tRecord)
			end,
			fnAutoClose = function() return true end}
		local tMenuNewName2 = {
			szOption = "倒计时名字2：" .. (tRecord.szName2 or "未定义"),
			bCheck = false,
			bChecked = false,
			fnAction = function()
				RaidGrid_BossCallAlert.SetNewName2(tRecord)
			end,
			fnAutoClose = function() return true end}
		local tMenuNewTime2 = {
			szOption = "倒计时2：" .. tostring(tRecord.nTime2 or 0) .. "秒",
			bCheck = false,
			bChecked = false,
			fnAction = function()
				RaidGrid_BossCallAlert.SetNewTime2(tRecord)
			end,
			fnAutoClose = function() return true end}
		local tMenuCheck1 = {
				szOption = "开启团队频道通报", bCheck = true, bChecked = tRecord.bRAID, fnAction = function(UserData, bCheck)
					tRecord.bRAID = bCheck
				end
			}
		local tMenuCheck2 = {
				szOption = "开启密语频道通报", bCheck = true, bChecked = tRecord.bWHISPER, fnAction = function(UserData, bCheck)
					tRecord.bWHISPER = bCheck
				end
			}
		local tMenuCheck3 = {
				szOption = "开启全屏泛光提示", bCheck = true, bChecked = tRecord.bFlash, fnAction = function(UserData, bCheck)
					tRecord.bFlash = bCheck
				end
			}
		local tMenuCheck4 = {
				szOption = "开启中央文字提示", bCheck = true, bChecked = tRecord.bCenterAlarm, fnAction = function(UserData, bCheck)
					tRecord.bCenterAlarm = bCheck
				end
			}
		local tMenuRemove = {
			szOption = "删除该项",
			fnAction = function()
				table.remove(RaidGrid_BossCallAlert.tRecords[szType], i)
			end}
		table.insert(tMenu, tMenuNewName)
		table.insert(tMenu, {bDevide = true} )
		if szType == "tBossCall" then
			table.insert(tMenu, tMenuNewBossName)
		end
		table.insert(tMenu, tMenuNewText)
		table.insert(tMenu, {bDevide = true} )
		table.insert(tMenu, tMenuNewTime1)
		table.insert(tMenu, {bDevide = true} )
		table.insert(tMenu, tMenuNewName2)
		table.insert(tMenu, tMenuNewTime2)
		table.insert(tMenu, {bDevide = true} )
		table.insert(tMenu, tMenuCheck1)
		table.insert(tMenu, tMenuCheck2)
		table.insert(tMenu, {bDevide = true} )
		table.insert(tMenu, tMenuCheck3)
		table.insert(tMenu, tMenuCheck4)
		table.insert(tMenu, {bDevide = true} )
		table.insert(tMenu, tMenuRemove)
		table.insert(tOptions, tMenu)
	end
	table.insert(tOptions, {bDevide = true})
	local tMenuAdd = {
		szOption = "添加设置",
		fnAction = function()
			GetUserInput("输入名字：", function(szText) RaidGrid_BossCallAlert.AddList(szType, szText) end, nil, nil, nil, nil)
		end}
	table.insert(tOptions, tMenuAdd)
	return tOptions
end


----------------------------------------------------------------
----RaidGrid_BossCallAlert.lua----
----------------------------------------------------------------

----------------------------------------------------------------
----RaidGrid_Options.lua----
----------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------
RaidGrid_EventScrutiny.bEnable = true;						RegisterCustomData("RaidGrid_EventScrutiny.bEnable")
RaidGrid_EventScrutiny.bCacheEnable = false;				RegisterCustomData("RaidGrid_EventScrutiny.bCacheEnable")
RaidGrid_EventScrutiny.tAnchor = {};						RegisterCustomData("RaidGrid_EventScrutiny.tAnchor")
RaidGrid_EventScrutiny.bBuffTeamScrutinyEnable = true;		RegisterCustomData("RaidGrid_EventScrutiny.bBuffTeamScrutinyEnable")
RaidGrid_EventScrutiny.bBuffChatAlertEnable = false;			RegisterCustomData("RaidGrid_EventScrutiny.bBuffChatAlertEnable")
RaidGrid_EventScrutiny.nBuffShowShadowAlpha = 0.6;			RegisterCustomData("RaidGrid_EventScrutiny.nBuffShowShadowAlpha")
RaidGrid_EventScrutiny.nBuffAutoRemoveCachePage = 50;		RegisterCustomData("RaidGrid_EventScrutiny.nBuffAutoRemoveCachePage")

RaidGrid_EventScrutiny.bCastingChatAlertEnable = false;		RegisterCustomData("RaidGrid_EventScrutiny.bCastingChatAlertEnable")
RaidGrid_EventScrutiny.bCastingReadingBar = true;			RegisterCustomData("RaidGrid_EventScrutiny.bCastingReadingBar")
RaidGrid_EventScrutiny.nCastingAutoRemoveCachePage = 50;	RegisterCustomData("RaidGrid_EventScrutiny.nCastingAutoRemoveCachePage")
RaidGrid_EventScrutiny.bCastingScrutinyAllEnable = false;	RegisterCustomData("RaidGrid_EventScrutiny.bCastingScrutinyAllEnable")
RaidGrid_EventScrutiny.bCastingTargetScrutinyEnable = false;RegisterCustomData("RaidGrid_EventScrutiny.bCastingTargetScrutinyEnable")
RaidGrid_EventScrutiny.bCastTargetChatAlertEnable = true;	RegisterCustomData("RaidGrid_EventScrutiny.bCastTargetChatAlertEnable")

RaidGrid_EventScrutiny.bNpcChatAlertEnable = false;			RegisterCustomData("RaidGrid_EventScrutiny.bNpcChatAlertEnable")
RaidGrid_EventScrutiny.nNpcAutoRemoveCachePage = 50;		RegisterCustomData("RaidGrid_EventScrutiny.nNpcAutoRemoveCachePage")

RaidGrid_EventScrutiny.bBuffListExEnable = true;			RegisterCustomData("RaidGrid_EventScrutiny.bBuffListExEnable")
RaidGrid_EventScrutiny.bColorAlertEnable = true;			RegisterCustomData("RaidGrid_EventScrutiny.bColorAlertEnable")

RaidGrid_EventScrutiny.bRedAlarmEnable = false;				RegisterCustomData("RaidGrid_EventScrutiny.bRedAlarmEnable")
RaidGrid_EventScrutiny.bCenterAlarmEnable = true;			RegisterCustomData("RaidGrid_EventScrutiny.bCenterAlarmEnable")
RaidGrid_EventScrutiny.bAutoMarkEnable = true;				RegisterCustomData("RaidGrid_EventScrutiny.bAutoMarkEnable")

RaidGrid_EventScrutiny.bCtrlandAltMove = true;				RegisterCustomData("RaidGrid_EventScrutiny.bCtrlandAltMove")
RaidGrid_EventScrutiny.bAutoNewSkillTimer = true;			RegisterCustomData("RaidGrid_EventScrutiny.bAutoNewSkillTimer")

RaidGrid_EventScrutiny.bSkillTimerSay = false;				RegisterCustomData("RaidGrid_EventScrutiny.bSkillTimerSay")
RaidGrid_EventScrutiny.nCenterAlarmTime = 2;				RegisterCustomData("RaidGrid_EventScrutiny.nCenterAlarmTime")
RaidGrid_EventScrutiny.nSkillTimerCountdown = 5;			RegisterCustomData("RaidGrid_EventScrutiny.nSkillTimerCountdown")
RaidGrid_EventScrutiny.nSayChannel = PLAYER_TALK_CHANNEL.RAID; RegisterCustomData("RaidGrid_EventScrutiny.nSayChannel")

RaidGrid_EventScrutiny.nSoundChannel = SOUND.FRESHER_TIP;
RaidGrid_EventScrutiny.bCalledTimerHeadEnable = true;		RegisterCustomData("RaidGrid_EventScrutiny.bCalledTimerHeadEnable")
RaidGrid_EventScrutiny.bOutputEventCacheRecords = false;	RegisterCustomData("RaidGrid_EventScrutiny.bOutputEventCacheRecords")
RaidGrid_EventScrutiny.bOutputBossCallAlertRecords = true;	RegisterCustomData("RaidGrid_EventScrutiny.bOutputBossCallAlertRecords")
RaidGrid_EventScrutiny.bOutputBossFaceData = true;			RegisterCustomData("RaidGrid_EventScrutiny.bOutputBossFaceData")
RaidGrid_EventScrutiny.AutoEnable = false;					RegisterCustomData("RaidGrid_EventScrutiny.AutoEnable")



local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	ui:Append("Text", { x = 0, y = 0, txt = _L["RaidGrid_EventScrutiny"], font = 27 })
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = 28, checked = RaidGrid_EventScrutiny.bEnable })
	:Text(_L["Enable All"]):Click(function(bChecked)
		ui:Fetch("bCacheEnable"):Enable(bChecked)
		ui:Fetch("AutoEnable"):Enable(bChecked)
		_RE.AutoEnable(bChecked)
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", "AutoEnable", { x = 25, y = nY, checked = RaidGrid_EventScrutiny.AutoEnable })
	:Text(_L["Only in the map type is Dungeon Enable plug-in"]):Enable(RaidGrid_EventScrutiny.bEnable):Click(function(bChecked)
		RaidGrid_EventScrutiny.AutoEnable = bChecked
		if bChecked then
			_RE.AutoEnable()
		else
			_RE.AutoEnable(true)
		end
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", "bCacheEnable", { x = 25, y = nY, checked = RaidGrid_EventScrutiny.bCacheEnable })
	:Text(_L["Enable EventCache"]):Enable(RaidGrid_EventScrutiny.bEnable):Click(function(bChecked)
		RaidGrid_EventScrutiny.bCacheEnable = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox" ,{ x = 10, y = nY, checked = RaidGrid_EventScrutiny.bCtrlandAltMove })
	:Text(_L["Hold down the Ctrl+Alt mobile UI"]):Click(function(bChecked)
		RaidGrid_EventScrutiny.bCtrlandAltMove = bChecked
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Import/export Setting"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY + 12, checked = RaidGrid_EventScrutiny.bOutputBossFaceData })
	:Text(_L["Import/export BossFaceData"]):Click(function(bChecked)
		RaidGrid_EventScrutiny.bOutputBossFaceData = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = RaidGrid_EventScrutiny.bOutputBossCallAlertRecords })
	:Text(_L["Import/export BossCallAlert"]):Click(function(bChecked)
		RaidGrid_EventScrutiny.bOutputBossCallAlertRecords = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = RaidGrid_EventScrutiny.bOutputEventCacheRecords })
	:Text(_L["Import/export EventCache"]):Click(function(bChecked)
		RaidGrid_EventScrutiny.bOutputEventCacheRecords = bChecked
	end):Pos_()
	nX,nY =ui:Append("Text", { x = 0, y = nY, txt = _L["Import/export data"], font = 27 }):Pos_()
	nX = 32
	nX = ui:Append("WndButton2", { x = nX, y = nY + 12 })
	:Text(_L["Export data"]):Click(function(bChecked)
		ClearCacheData()
		RaidGrid_Base.SaveSettingsNew()
	end):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 18, y = nY + 12 })
	:Text(_L["Cover data"]):Click(function(bChecked)
		RaidGrid_Base.LoadSettingsNew(true)
	end):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 18, y = nY + 12 })
	:Text(_L["Merge data"]):Click(function(bChecked)
		RaidGrid_Base.LoadSettingsNew()
	end):Pos_()
	nX,nY = ui:Append("WndButton2", { x = nX + 18, y = nY + 12,color = {255,255,0} })
	:Text(_L["Network data"]):Click(function()
		local _, _, szLang = GetVersion()
		if szLang ~= "zhcn" and szLang ~= "zhtw" then
			return JH.Sysmsg(_L["Sorry, Does not support this function"])
		end
		WebSyncData.OpenPanel()
	end):Pos_()
	nX = ui:Append("WndButton2", { x = 32, y = nY + 12 })
	:Text("BUFF"):Click(function(bChecked)
		if RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.wnd then
			RaidGrid_EventScrutiny.SwitchPageType("Buff")
			RaidGrid_EventCache.SwitchPageType("Buff")
			RaidGrid_EventCache.OpenPanel()
		end
	end):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 18, y = nY + 12 })
	:Text("DEBUFF"):Click(function(bChecked)
		if RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.wnd then
			RaidGrid_EventScrutiny.SwitchPageType("Debuff")
			RaidGrid_EventCache.SwitchPageType("Debuff")
			RaidGrid_EventCache.OpenPanel()
		end
	end):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 18, y = nY + 12 })
	:Text(_L["Casting"]):Click(function(bChecked)
		if RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.wnd then
			RaidGrid_EventScrutiny.SwitchPageType("Casting")
			RaidGrid_EventCache.SwitchPageType("Casting")
			RaidGrid_EventCache.OpenPanel()
		end
	end):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 18, y = nY + 12 })
	:Text(_L["NPC"]):Click(function(bChecked)
		if RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.wnd then
			RaidGrid_EventScrutiny.SwitchPageType("Npc")
			RaidGrid_EventCache.SwitchPageType("Npc")
			RaidGrid_EventCache.OpenPanel()
		end
	end):Pos_()
end
GUI.RegisterPanel(_L["RaidGrid_EventScrutiny"], 22, _L["RGES"],PS)
local PS2 = {}
PS2.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	ui:Append("Text", { x = 0, y = 0, txt = _L["BossCallAlert / CallName"], font = 27 })
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = 28, checked = RaidGrid_BossCallAlert.TalkMonitor })
	:Text(_L["BossCall Scrutiny"]):Click(function(bChecked)
		RaidGrid_BossCallAlert.TalkMonitor = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = RaidGrid_BossCallAlert.bWarningMessageMonitor })
	:Text(_L["MessageBox Scrutiny"]):Click(function(bChecked)
		RaidGrid_BossCallAlert.bWarningMessageMonitor = bChecked
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Alert Setting"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 12, checked = RaidGrid_BossCallAlert.RAID })
	:Text(_L["RaidAlert"]):Click(function(bChecked)
		RaidGrid_BossCallAlert.RAID = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 15, y = nY + 12, checked = RaidGrid_BossCallAlert.WHISPER })
	:Text(_L["WhisperAlert"]):Click(function(bChecked)
		RaidGrid_BossCallAlert.WHISPER = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 15, y = nY + 12, checked = RaidGrid_BossCallAlert.bCalledTimerHeadEnable })
	:Text(_L["HeadAlert"]):Enable(type(ScreenHead) ~= "nil"):Click(function(bChecked)
		RaidGrid_BossCallAlert.bCalledTimerHeadEnable = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndComboBox", { x = nX + 15, y = nY + 12 })
	:Text(_L["FlashAlert"]):Menu(function()
		return {
				{szOption = _L["Enable"], bCheck = true, bChecked = RaidGrid_BossCallAlert.Flash , fnAction = function() RaidGrid_BossCallAlert.Flash = not RaidGrid_BossCallAlert.Flash end},
				{szOption = _L["Red []"], bMCheck = true,fnDisable = function() return not RaidGrid_BossCallAlert.Flash end, bChecked = RaidGrid_BossCallAlert.tRGRedAlarm[4] == 3, r = 255, g = 0, b = 0, fnAction = function() RaidGrid_BossCallAlert.tRGRedAlarm = {255, 0, 0, 3} end},
				{szOption = _L["Green []"], bMCheck = true,fnDisable = function() return not RaidGrid_BossCallAlert.Flash end,  bChecked = RaidGrid_BossCallAlert.tRGRedAlarm[4] == 1, r = 0, g = 255, b = 0, fnAction = function() RaidGrid_BossCallAlert.tRGRedAlarm = {0, 255, 0, 1} end},
				{szOption = _L["Blue []"], bMCheck = true,fnDisable = function() return not RaidGrid_BossCallAlert.Flash end,  bChecked = RaidGrid_BossCallAlert.tRGRedAlarm[4] == 0, r = 0, g = 0, b = 255, fnAction = function() RaidGrid_BossCallAlert.tRGRedAlarm = {0, 0, 255, 0} end},
				{szOption = _L["Yellow []"], bMCheck = true,fnDisable = function() return not RaidGrid_BossCallAlert.Flash end,  bChecked = RaidGrid_BossCallAlert.tRGRedAlarm[4] == 5, r = 255, g = 255, b = 0, fnAction = function() RaidGrid_BossCallAlert.tRGRedAlarm = {255, 255, 0, 5} end},
				{szOption = _L["Purple []"], bMCheck = true,fnDisable = function() return not RaidGrid_BossCallAlert.Flash end,  bChecked = RaidGrid_BossCallAlert.tRGRedAlarm[4] == 2, r = 255, g = 0, b = 255, fnAction = function() RaidGrid_BossCallAlert.tRGRedAlarm = {255, 0, 255, 2} end},
				{szOption = _L["White []"], bMCheck = true,fnDisable = function() return not RaidGrid_BossCallAlert.Flash end,  bChecked = RaidGrid_BossCallAlert.tRGRedAlarm[4] == 4, r = 255, g = 255, b = 255, fnAction = function() RaidGrid_BossCallAlert.tRGRedAlarm = {255, 255, 255, 4} end},
			}
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = RaidGrid_BossCallAlert.CenterAlarm })
	:Text(_L["CenterAlarm"]):Click(function(bChecked)
		RaidGrid_BossCallAlert.CenterAlarm = bChecked
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Talk/Call Data"], font = 27 }):Pos_()
	nX = ui:Append("WndComboBox", { x = 10, y = nY + 12 })
	:Text(_L["Boss Call Data"]):Menu(function()
		return RaidGrid_BossCallAlert.tPopOptions("tBossCall")
	end):Pos_()
	nX,nY = ui:Append("WndComboBox", { x = nX + 15, y = nY + 12 })
	:Text(_L["MessageBox Call Data"]):Menu(function()
		return RaidGrid_BossCallAlert.tPopOptions("tWarningMessages")
	end):Pos_()
end
GUI.RegisterPanel(_L["BossCallAlert / CallName"], 340, _L["RGES"],PS2)

local PS3 = {}
PS3.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	ui:Append("Text", { x = 0, y = 0, txt = _L["BUFF/DEBUFF Effect List"], font = 27 })
	nX = ui:Append("WndCheckBox" ,{ x = 10, y = 28, checked = RaidGrid_EventScrutiny.bBuffListExEnable })
	:Text(_L["Enable"]):Click(function(bChecked)
		ui:Fetch("Name"):Enable(bChecked)
		ui:Fetch("Buff_1"):Enable(bChecked)
		RaidGrid_EventScrutiny.bBuffListExEnable = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox","Name" ,{ x = nX + 15, y = 28, checked = RaidGrid_SelfBuffAlert.bShowBuffName })
	:Text(_L["Show Name"]):Enable(RaidGrid_EventScrutiny.bBuffListExEnable):Click(function(bChecked)
		RaidGrid_SelfBuffAlert.bShowBuffName = bChecked
	end):Pos_()
	nX,nY = ui:Append("Text",{ x = nX + 15, y = 26, txt = _L["Icon size"] }):Pos_()
	nX,nY = ui:Append("WndEdit","Buff_1", { x = nX + 5, y = 28, txt = RaidGrid_SelfBuffAlert.nScaleXandY, w = 30, h = 25 })
	:Enable(RaidGrid_EventScrutiny.bBuffListExEnable):Change(function(txt)
		local nSec = tonumber(txt)
		if not nSec then
			return
		end
		if nSec > 0 and nSec ~= RaidGrid_SelfBuffAlert.nScaleXandY then
			RaidGrid_SelfBuffAlert.frameSelf:Scale(nSec/RaidGrid_SelfBuffAlert.nScaleXandY, nSec/RaidGrid_SelfBuffAlert.nScaleXandY)
			RaidGrid_SelfBuffAlert.nScaleXandY = nSec
		end
	end):Pos_()
	nX,nY = ui:Append("Text", { x = nX + 5, y = 26, txt = _L["times"] }):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY + 10, txt = _L["TeamPanel Bind Buff"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox",{ x = 10, y = nY + 12, checked =RaidGrid_EventScrutiny.bBuffTeamScrutinyEnable })
	:Text(_L["System TeamPanel"]):Click(function(bChecked)
		RaidGrid_EventScrutiny.bBuffTeamScrutinyEnable = bChecked
		if bChecked then
			JH.BreatheCall("Raid_MonitorBuffs", _RE.Raid_MonitorBuffs, 10000)
		end
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Skill Scrutiny"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndCheckBox",{ x = 10, y = nY + 12, checked = RaidGrid_EventScrutiny.bCastingScrutinyAllEnable })
	:Text(_L["Skill Scrutiny for Player"]):Click(function(bChecked)
		RaidGrid_EventScrutiny.bCastingScrutinyAllEnable = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox",{ x = 10, y = nY, checked = RaidGrid_EventScrutiny.bCastingTargetScrutinyEnable })
	:Text(_L["show skills release object"]):Click(function(bChecked)
		ui:Fetch("bCastTargetChatAlertEnable"):Enable(bChecked)
		RaidGrid_EventScrutiny.bCastingTargetScrutinyEnable = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox","bCastTargetChatAlertEnable",{ x = nX + 15, y = nY, checked = RaidGrid_EventScrutiny.bCastTargetChatAlertEnable })
	:Text(_L["WhisperAlert"]):Enable(RaidGrid_EventScrutiny.bCastingTargetScrutinyEnable):Click(function(bChecked)
		RaidGrid_EventScrutiny.bCastTargetChatAlertEnable = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox",{ x = 10, y = nY, checked = RaidGrid_EventScrutiny.bCastingReadingBar })
	:Text(_L["Show ReadingBar"]):Click(function(bChecked)
		RaidGrid_EventScrutiny.bCastingReadingBar = bChecked
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = "插件各类模块总开关", font = 27 }):Pos_()
	-- RaidGrid_EventScrutiny.bSoundAlertEnable
	nX,nY = ui:Append("WndCheckBox" ,{ x = 10, y = nY + 10, checked = RaidGrid_EventScrutiny.bColorAlertEnable })
	:Text("全屏泛光报警（总开关）"):Click(function(bChecked)
		RaidGrid_EventScrutiny.bColorAlertEnable = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox" ,{ x = 10, y = nY, checked = RaidGrid_EventScrutiny.bCenterAlarmEnable })
	:Text("中央文字报警（总开关）"):Click(function(bChecked)
		RaidGrid_EventScrutiny.bCenterAlarmEnable = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox" ,{ x = 10, y = nY, checked = RaidGrid_EventScrutiny.bAutoMarkEnable })
	:Text("自动标记（总开关）"):Click(function(bChecked)
		RaidGrid_EventScrutiny.bAutoMarkEnable = bChecked
	end):Pos_()
	local bEnable = false
	if RaidGrid_EventScrutiny.bBuffChatAlertEnable and RaidGrid_EventScrutiny.bCastingChatAlertEnable and RaidGrid_EventScrutiny.bNpcChatAlertEnable
		and RaidGrid_BossCallAlert.bChatAlertEnable and RaidGrid_EventScrutiny.bSkillTimerSay then
		bEnable = true
	end
	nX,nY = ui:Append("WndCheckBox" ,{ x = 10, y = nY, checked = bEnable })
	:Text("聊天框报警（总开关）"):Click(function(bChecked)
		RaidGrid_EventScrutiny.bBuffChatAlertEnable = bChecked
		RaidGrid_EventScrutiny.bCastingChatAlertEnable = bChecked
		RaidGrid_EventScrutiny.bNpcChatAlertEnable = bChecked
		RaidGrid_BossCallAlert.bChatAlertEnable = bChecked
		RaidGrid_EventScrutiny.bSkillTimerSay = bChecked
	end):Pos_()
end
GUI.RegisterPanel(_L["Scrutiny Setting"], 1904, _L["RGES"],PS3)

function RaidGrid_EventScrutiny.PopMainOptions()
	if JH.IsPanelOpened() then
		JH.ClosePanel()
	else
		JH.OpenPanel(_L["RaidGrid_EventScrutiny"])
	end
end

----------------------------------------------------------------------------------------------------------------------------------
function RaidGrid_EventCache.PopRBOptions(handle)
	if not handle then
		return
	end
	local tTab = RaidGrid_EventCache.tRecords[RaidGrid_EventCache.szListIndex] or {}
	local nCurrentPage = RaidGrid_EventCache.tListPage[RaidGrid_EventCache.szListIndex] or 1
	local nListIndex = tonumber(handle:GetName():sub(15))
	local nStartIndex = (nCurrentPage - 1) * 14 + nListIndex
	if not tTab[nStartIndex] then
		return
	end
	local dwID = tTab[nStartIndex].dwID
	if not dwID then
		return
	end

	local tOptions = {
		{
			szOption = "　【"  .. (handle.tRecord.szName or "") .. "】", bCheck = false, bChecked = false, bDisable = true,
		},
		{
			bDevide = true
		},
		{
			szOption = "　★添加到监视列表", bDisable = RaidGrid_EventScrutiny.IsRecordInList(handle.tRecord, RaidGrid_EventCache.szListIndex), fnAction = function(UserData, bCheck)
				handle.tRecord.nEventAlertTime = handle.tRecord.nEventAlertTime or math.floor(handle.tRecord.fKeepTime or 1200)
				RaidGrid_EventScrutiny.AddRecordToList(handle.tRecord, RaidGrid_EventCache.szListIndex)
				RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)
			end,
		},
		{
			bDevide = true
		},
		{
			szOption = "　★" .. _L["Add Face"], rgb = { 255, 255, 0 } ,bCheck = false, bChecked = false, bDisable = handle.tRecord.szType ~= "Npc" or type(Circle) == "nil" , fnAction = function(UserData, bCheck)
				if IsAltKeyDown() then
					Circle.OpenAddPanel(handle.tRecord.dwID, TARGET.NPC, handle.tRecord.szMapName)
				else
					Circle.OpenAddPanel(handle.tRecord.szName, TARGET.NPC, handle.tRecord.szMapName)
				end
			end,
		},
		{
			bDevide = true
		},
		{
			szOption = "　地图:"  .. (handle.tRecord.szMapName or "（未知）"), bCheck = false, bChecked = false, bDisable = true,
		},
		{
			szOption = "　释放者:"  .. (handle.tRecord.szCasterName or "（暂无此项）"), bCheck = false, bChecked = false, bDisable = true,
		},
		{
			szOption = "★打印此项信息", bCheck = false, bChecked = false, fnAction = function(UserData, bCheck)
				RaidGrid_Base.OutputRecord(handle.tRecord)
			end,
		},
		{
			bDevide = true
		},
		{
			szOption = "　删除此条目", bCheck = false, bChecked = false, fnAction = function(UserData, bCheck)
				GetPopupMenu():Hide()
				if tTab.Hash2[dwID] and tTab[nStartIndex].nLevel then
					tTab.Hash2[dwID][tTab[nStartIndex].nLevel] = nil
				end
				if not tTab.Hash2[dwID] or IsTableEmpty(tTab.Hash2[dwID]) then
					tTab.Hash2[dwID] = nil
					tTab.Hash[dwID] = nil
				end
				table.remove(tTab, nStartIndex)
				RaidGrid_EventCache.UpdateRecordList(RaidGrid_EventCache.szListIndex)
			end,
		},
	}

	local nX, nY = Cursor.GetPos(true)
	tOptions.x, tOptions.y = nX + 15, nY + 15
	PopupMenu(tOptions)
end

----------------------------------------------------------------------------------------------------------------------------------

function RaidGrid_EventScrutiny.SyncOptions(tData,szType)
	local tOptions
	if GetClientPlayer().IsInParty() then
		tOptions = {szOption = "★把这个数据共享给团员",rgb = {255,128,192},
			{szOption = "共享给团队所有成员",fnAction = function() RaidGrid_Base.SendDataToTeam(tData,szType)	end},
		}
		table.insert(tOptions,{bDevide = true})
		local hTeam = GetClientTeam()
		for i = 0, hTeam.nGroupNum - 1 do
			local tGroupInfo = hTeam.GetGroupInfo(i)
			for _, dwID in pairs(tGroupInfo.MemberList) do
				local tMemberInfo = hTeam.GetMemberInfo(dwID)
				if tMemberInfo.szName ~= GetClientPlayer().szName then
					local szIcon,nFrame = GetForceImage(tMemberInfo.dwForceID)
					local col = { JH.GetForceColor(tMemberInfo.dwForceID) }
					table.insert(tOptions,{szOption = tMemberInfo.szName,bDisable = not tMemberInfo.bIsOnLine,rgb = col, szIcon = szIcon,szLayer = "ICON_RIGHT",nFrame = nFrame ,fnAction = function() RaidGrid_Base.SendDataToTeam(tData,szType,tMemberInfo.szName)	end})
				end
			end
		end
	else
		tOptions = {szOption = "★共享数据（不在队伍中）",bDisable = true}
	end
	return tOptions
end

function RaidGrid_EventScrutiny.PopRBOptions(handle)
	if not handle then
		return
	end

	local tTab = RaidGrid_EventScrutiny.tRecords[RaidGrid_EventScrutiny.szListIndex] or {}
	local nCurrentPage = RaidGrid_EventScrutiny.tListPage[RaidGrid_EventScrutiny.szListIndex] or 1
	local nListIndex = tonumber(handle:GetName():sub(15))
	local nStartIndex = (nCurrentPage - 1) * 8 + nListIndex
	if not tTab[nStartIndex] then
		return
	end
	local dwID = tTab[nStartIndex].dwID
	if not dwID then
		return
	end


	local tTimeCache = {"无记录", "无记录", "无记录", "无记录", "无记录", "无记录", "无记录", "无记录", "无记录", "无记录"}
	if tTab[nStartIndex].tEventTimeCache then
		for i = 1, #tTab[nStartIndex].tEventTimeCache do
			if type(tTab[nStartIndex].tEventTimeCache[i]) == "number" then
				tTimeCache[i] = JH.GetBuffTimeString(tTab[nStartIndex].tEventTimeCache[i])
			end
		end
	end

	local function GetTimeSelectFunction(nIndex)
		return function(UserData, bCheck)
			if not tTab[nStartIndex] or not tTab[nStartIndex].tEventTimeCache or not tTab[nStartIndex].tEventTimeCache[nIndex] or type(tTab[nStartIndex].tEventTimeCache[nIndex]) ~= "number" then
				return
			end
			tTab[nStartIndex].nEventAlertTime = math.floor(tTab[nStartIndex].tEventTimeCache[nIndex])
			tTab[nStartIndex].nAutoEventTimeMode = AUTO_EVENTTIME_MODE.NONE
			RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
		end
	end

	local tOptions = {}
	local PS = {}
	PS.OnPanelActive = function(frame)
		local ui = GUI(frame)
		local szType = tTab[nStartIndex].szType
		local data = tTab[nStartIndex]
		local _ = 0
		local col = {
			["Buff"] = {0,255,0},
			["Debuff"] = {255,0,0},
			["Casting"] = {255,0,255},
			["Npc"] = {255,128,0},
		}
		ui:Append("Box",{ x = 475, y = 0,w = 48, h = 48}):Icon(data.nIconID or 1475)
		:Hover(function()
			this:SetObjectMouseOver(true)
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			if szType == "Buff" or szType == "Debuff" then
				OutputBuffTip(GetClientPlayer().dwID, data.dwID, data.nLevel or 1, 1, false, 999, {x, y, w, h})
			elseif szType == "Npc" then
				OutputNpcTip2(data.dwID, {x, y, w, h})
			elseif szType == "Casting" then
				OutputSkillTip(data.dwID, data.nLevel or 1, {x, y, w, h})
			end
		end,function()
			this:SetObjectMouseOver(false)
			HideTip()
		end):Click(function()
			if not GetClientPlayer().IsInParty() then return JH.Alert(_L["You are not team leader or not in team"]) end
			PopupMenu(RaidGrid_EventScrutiny.SyncOptions(data))
		end)
		nX,nY = ui:Append("WndEdit",{x = 5, y = 2,txt = data.szName, color = col[szType]}):Change(function(txt)
			if txt ~= "" then
				data.szName = txt
			end
		end):Pos_()
		ui:Append("Shadow","tRGBuffColor",{w = 20, h = 20,x = nX + 2, y = 4,color = data.tRGBuffColor or { 255, 255, 255 }})
		:Click(function()
			local fnAction = function(r, g, b)
				data.tRGBuffColor = { r, g, b }
				RaidGrid_EventScrutiny.UpdateRecordList(szType)
				ui:Fetch("tRGBuffColor"):Color(r, g, b)
			end
			PopupMenu({
				{szOption = "", bColorTable = true, fnChangeColor = function(_,r,g,b) fnAction(r,g,b) end},
				{szOption = _L["Clear"], fnAction = function()
					data.tRGBuffColor = nil
					ui:Fetch("tRGBuffColor"):Color(255,255,255)
					RaidGrid_EventScrutiny.UpdateRecordList(szType)
				end}
			})
		end)
		nX,nY = ui:Append("Text",{ x = 0, y = nY, txt = "事件触发满足下列条件", font = 27}):Pos_()
		if szType == "Buff" or szType == "Debuff" then
			nX = ui:Append("Text",{ x = 10, y = nY + 8, txt = "层数(层)"}):Pos_()
			nX = ui:Append("WndEdit",{x = nX + 5, y = nY + 10,w = 25,h = 25,txt = data.nEventAlertStackNum or 1}):Change(function(txt)
				if tonumber(txt) then
					data.nEventAlertStackNum = tonumber(txt)
				end
			end):Pos_()
		end
		if szType == "Npc" then
			nX = ui:Append("Text",{ x = 10, y = nY + 8, txt = "数量(个)"}):Pos_()
			nX = ui:Append("WndEdit",{x = nX + 5, y = nY + 10, w = 25,h = 25,txt = data.nEventAlertCount or 1}):Change(function(txt)
				if tonumber(txt) then
					data.nEventAlertCount = tonumber(txt)
				end
			end):Pos_()
			nX = ui:Append("WndCheckBox",{ x = nX + 10, y = nY + 10, checked = not data.bNotAppearScrutiny or false })
			:Text("出现"):Click(function(bChecked)
				data.bNotAppearScrutiny = not bChecked
			end):Pos_()
			nX = ui:Append("WndCheckBox",{ x = nX + 10, y = nY + 10, checked = data.bNpcLeaveScrutiny or false })
			:Text("消失"):Click(function(bChecked)
				data.bNpcLeaveScrutiny = bChecked
				ui:Fetch("bNpcAllLeave"):Enable(bChecked)
			end):Pos_()
			nX = ui:Append("WndCheckBox","bNpcAllLeave",{ x = nX +10, y = nY + 10, checked = data.bNpcAllLeave or false })
			:Text("必须全部消失"):Enable(data.bNpcLeaveScrutiny or false):Click(function(bChecked)
				data.bNpcAllLeave = bChecked
			end):Pos_()
		end
		local _nY = nY
		if szType ~= "Npc" then
			if szType == "Casting" then nX = 0 end
			nX = ui:Append("WndCheckBox",{ x = nX + 10, y = nY + 10, checked = data.bAlwaysCheckLevel or false })
			:Text("区分nLevel"):Click(function(bChecked)
				data.bAlwaysCheckLevel = bChecked
			end):Pos_()
			nX,nY = ui:Append("WndComboBox",{ x = nX + 10, y = nY + 10})
			:Text("监控的目标类型"):Menu(function()
				return {
					{szOption = "全部监控", bMCheck = true, bChecked = not data.nRelScrutinyType, fnAction = function() data.nRelScrutinyType = nil end},
					{szOption = "只监控自己", bMCheck = true, bChecked = data.nRelScrutinyType == 1, fnAction = function() data.nRelScrutinyType = 1 end},
					{szOption = "只监控队友和自己", bMCheck = true, bChecked = data.nRelScrutinyType == 2, fnAction = function() data.nRelScrutinyType = 2 end},
					{szOption = "只监控敌方", bMCheck = true, bChecked = data.nRelScrutinyType == -1, fnAction = function() data.nRelScrutinyType = -1 end},
					{szOption = "只监控非队友", bMCheck = true, bChecked = data.nRelScrutinyType == -2, fnAction = function() data.nRelScrutinyType = -2 end},
				}
			end):Pos_()
		end
		if szType ~= "Buff" and szType ~= "Debuff"  then
			nX = ui:Append("Text",{ x = nX + 10, y = _nY + 8, txt = "间隔至少(秒)"}):Pos_()
			nX = ui:Append("WndEdit","nMinChatAlertCD",{x = nX + 5, y = _nY + 10, w = 25,h = 25,txt = data.nMinChatAlertCD or 7})
			:Change(function(txt)
				if tonumber(txt) then
					if tonumber(txt) < 1 then txt = 1 end
					data.nMinChatAlertCD = tonumber(txt)
				end
			end):Pos_()
		end
		nY = 80
		local _nX,_nY = 0,nY + 28
		nX,nY = ui:Append("Text",{ x = 0, y = nY, txt = "报警和触发设置", font = 27}):Pos_()
		if szType ~= "Casting" then
			_nX,_nY = ui:Append("WndComboBox",{ x = 0, y = nY + 10,w = 85,h = 30})
			:Text("标记"):Menu(function()
				local menu = {}
				for nKey, nVal in pairs(PARTY_MARK_ICON_FRAME_LIST) do
					table.insert(menu,{
						szIcon = PARTY_MARK_ICON_PATH,
						nFrame = nVal,
						bMCheck = true,
						bChecked = data.tAutoTeamMark == nKey,
						szLayer = "ICON_CENTER",
						fnAction = function()
							data.tAutoTeamMark = nKey
						end
					})
				end
					table.insert(menu,{
						szOption = g_tStrings.STR_MARK_TARGET_NONE,
						fnAction = function()
							data.tAutoTeamMark = nil
						end
					})
				return menu
			end):Pos_()
			if szType == "Npc" then
				nX = ui:Append("WndCheckBox",{ x = _nX + 15, y = nY + 10, checked = data.bAutoTeamMarkAll or false })
				:Text("同名Npc全部标记"):Click(function(bChecked)
					data.bAutoTeamMarkAll = bChecked
					ui:Fetch("nMaxMarkCount"):Enable(bChecked)
				end):Pos_()
				nX = ui:Append("Text",{ x = nX + 10, y = nY + 8, txt = "最多只标记(个)"}):Pos_()
				nX = ui:Append("WndEdit","nMaxMarkCount",{x = nX + 5, y = nY + 10, w = 25,h = 25,txt = data.nMaxMarkCount or 10})
				:Enable(data.bAutoTeamMarkAll or false):Change(function(txt)
					if tonumber(txt) then
						data.nMaxMarkCount = tonumber(txt)
					end
				end):Pos_()
			end
			if szType == "Buff" or szType == "Debuff" then
				nX = ui:Append("WndCheckBox",{ x = _nX + 15, y = nY + 10, checked = data.bPartyBuffList or false })
				:Text("重要Buff列表"):Enable(type(PartyBuffList) ~= "nil"):Click(function(bChecked)
					data.bPartyBuffList = bChecked
				end):Pos_()
				nX = ui:Append("WndCheckBox",{ x = nX + 5, y = nY + 10, checked = not data.bNotAddSelfBuffAlert or false })
				:Text("效果列表"):Click(function(bChecked)
					data.bNotAddSelfBuffAlert = not bChecked
				end):Pos_()
				nX = ui:Append("WndCheckBox",{ x = nX + 5, y = nY + 10, checked = not data.bNotAddToCTM or false })
				:Text("团队面板"):Click(function(bChecked)
					ui:Fetch("bNotAddToCTM"):Enable(bChecked)
					data.bNotAddToCTM = not bChecked
				end):Pos_()
				nX = ui:Append("WndCheckBox","bNotAddToCTM",{ x = nX + 5, y = nY + 10, checked = data.bOnlySelfSrcAddCTM or false })
				:Text("来源自己"):Enable(not data.bNotAddToCTM or false):Click(function(bChecked)
					data.bOnlySelfSrcAddCTM = bChecked
				end):Pos_()
			end


		end

		nX = ui:Append("WndCheckBox",{ x = 0, y = _nY, checked = data.tRGCenterAlarm or false })
		:Text(_L["CenterAlarm"]):Click(function(bChecked)
			data.tRGCenterAlarm = bChecked
			RaidGrid_EventScrutiny.UpdateRecordList(szType)
		end):Pos_()
		nX = ui:Append("WndCheckBox","bScreenHead",{ x = nX + 10, y = _nY, checked = data.bScreenHead or false })
		:Text(_L["HeadAlert"]):Enable(type(ScreenHead) ~= "nil"):Click(function(bChecked)
			if szType == "Npc" and bChecked then
				JH.Confirm(_L["He has been in the scene, Until killed or leave, Sure to add?"],function()
					data.bScreenHead = bChecked
				end,function()
					ui:Fetch("bScreenHead"):Check(data.bScreenHead)
				end)
			else
				data.bScreenHead = bChecked
			end
		end):Pos_()
		nX = ui:Append("WndCheckBox",{ x = nX + 10, y = _nY, checked = data.bBigFontAlarm or false })
		:Enable(type(LargeText) ~= "nil"):Text(_L["LargeText"]):Click(function(bChecked)
			data.bBigFontAlarm = bChecked
			RaidGrid_EventScrutiny.UpdateRecordList(szType)
		end):Pos_()
		nX = ui:Append("WndCheckBox",{ x = nX + 10, y = _nY, checked = data.bChatAlertT or false })
		:Text(_L["RaidAlert"]):Click(function(bChecked)
			data.bChatAlertT = bChecked
			RaidGrid_EventScrutiny.UpdateRecordList(szType)
		end):Pos_()
		nX,_nY = ui:Append("WndCheckBox",{ x = nX + 10, y = _nY, checked = data.bChatAlertW or false })
		:Text(_L["WhisperAlert"]):Click(function(bChecked)
			data.bChatAlertW = bChecked
			RaidGrid_EventScrutiny.UpdateRecordList(szType)
		end):Pos_()
		nX,nY = ui:Append("WndCheckBox", { x = 0, y = _nY, txt = "泛光",  checked = data.bFullScreenAlert or false}):Click(function(bChecked)
			data.bFullScreenAlert = bChecked
		end):Pos_()
		if szType == "Npc" then
			nX = ui:Append("WndButton2",{ x = nX + 10, y = _nY + 5})
			:Text("血量报警"):Click(function(bChecked)
				local Recall = function(szText)
					data.tNpcLife = nil
					data.szNpcLife = nil
					if not szText or szText == "" or szText == "," or szText == "，" then
						return
					end
					local szString = szText
					local t1 = JH.Split(szString,";")
					local list = {}
					for k,v in pairs(t1) do
						local arr = JH.Split(v,",")
						if arr[1] and arr[2] then
							arr[1] = tonumber(arr[1])
							arr[3] = tonumber(arr[3])
							table.insert(list,arr)
						end
					end
					if #list > 0 then
						table.sort(list,function(a,b) return (a[1] > b[1]) end)
						data.szNpcLife = szText
						data.tNpcLife = list
					end
					RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
				end
				GetUserInput(data.szName.."格式：0.11,Part3;0.41,Part2;0.71,Part1; ...", Recall, nil, function() end, nil, data.szNpcLife or "", 310)
			end):Pos_()
		end
		if szType == "Buff" or szType == "Debuff" then
			nX = ui:Append("WndCheckBox",{ x = nX + 10, y = _nY + 5, checked = data.bManyMembers or false })
			:Text("聊天框防刷屏"):Click(function(bChecked)
				data.bManyMembers = bChecked
			end):Pos_()
		end
		nX,nY = ui:Append("Text",{ x = 0, y = nY, txt = "倒计时相关", font = 27}):Pos_()

		nX = ui:Append("WndCheckBox","bSkillTimer2Enable",{ x = 10, y = nY + 10, checked = data.bSkillTimer2Enable or false })
		:Text("第二中央倒计时"):Click(function(bChecked)
			data.bSkillTimer2Enable = bChecked
			ui:Fetch("szSkillName2"):Enable(bChecked)
			ui:Fetch("nSkillTimer2"):Enable(bChecked)
			RaidGrid_EventScrutiny.UpdateRecordList(szType)
		end):Pos_()
		nX = ui:Append("WndEdit","szSkillName2",{x = nX + 5, y = nY + 10, w = 130,h = 25,txt = data.szSkillName2 or "倒计时名称"})
		:Enable(data.bSkillTimer2Enable or false):Change(function(txt)
			if txt ~= "" then
				data.szSkillName2 = txt
			end
		end):Pos_()
		nX,nY = ui:Append("WndEdit","nSkillTimer2",{x = nX + 5, y = nY + 10, w = 25,h = 25,txt = data.nSkillTimer2 or 0})
		:Enable(data.bSkillTimer2Enable or false):Change(function(txt)
			if tonumber(txt) then
				data.nSkillTimer2 = tonumber(txt)
			end
		end):Pos_()
		_nY = nY
		if szType == "Casting" or szType == "Npc" then
			nX = ui:Append("WndCheckBox",{ x = 10, y = nY, checked = not data.bNotAddToScrutiny or false })
			:Text("事件监控倒计时"):Click(function(bChecked)
				data.bNotAddToScrutiny = not bChecked
				RaidGrid_EventScrutiny.UpdateRecordList(szType)
			end):Pos_()
			nX = ui:Append("WndCheckBox","bAddToSkillTimer",{ x = nX + 5, y = nY, checked = data.bAddToSkillTimer or false })
			:Text("中央倒计时"):Click(function(bChecked)
				data.bAddToSkillTimer = bChecked
				RaidGrid_EventScrutiny.UpdateRecordList(szType)
			end):Pos_()

			if szType == "Npc" then
				nX = ui:Append("WndCheckBox",{ x = nX + 5, y = nY, checked = data.bLinkNpcFightState or false })
				:Text("关联战斗"):Click(function(bChecked)
					if bChecked then
						data.bLinkNpcFightState = true
						data.bNormalCountdownType = true
						data.nEventAlertTime = 1200
						data.bNotAppearScrutiny = true
					else
						data.bLinkNpcFightState = nil
						data.bNormalCountdownType = nil
					end
					RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
				end):Pos_()
			end
			if szType == "Casting" or szType == "Npc" then
				nX = ui:Append("WndButton2",{ x = nX + 5, y = nY })
				:Text("分段倒计时"):Click(function(bChecked)
					local Recall = function(szText)
						data.szTimerSet = nil
						data.tTimerSet = nil
						if not szText or szText == "" then
							return
						end
						local szString = szText
						local t1 = JH.Split(szString,";")
						local list = {}
						for k,v in pairs(t1) do
							local arr = JH.Split(v,",")
							local tab = {}
							if arr[1] and arr[2] then
								tab["nTime"] = tonumber(arr[1])
								tab["szTimerName"] = arr[2]
								if arr[3] then
									tab["szAlert"] = arr[3]
								end
								table.insert(list,tab)
							end
						end

						if #list > 0 then
							data.szTimerSet = szText
						end
						RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
					end
					GetUserInput(data.szName.."（分段时间设置，参考：25,雷涌;40,扫射）", Recall, nil, function() end, nil, data.szTimerSet or "", 999)
				end):Pos_()
			end
			nY = nY + 25
			nX,nY = ui:Append("Text",{ x = 0, y = nY, txt = "倒计时时间设置(事件/中央)", font = 27}):Pos_()
			nX = ui:Append("WndCheckBox",{ x = 10, y = nY + 10, checked = data.nAutoEventTimeMode == AUTO_EVENTTIME_MODE.AVG or false })
			:Text("自动设置最近10次平均值"):Click(function(bChecked)
				if bChecked then
					data.nAutoEventTimeMode = AUTO_EVENTTIME_MODE.AVG
				else
					data.nAutoEventTimeMode = AUTO_EVENTTIME_MODE.NONE
				end
				ui:Fetch("nEventAlertTime"):Enable(data.nAutoEventTimeMode == AUTO_EVENTTIME_MODE.NONE)
			end):Pos_()
			nX = ui:Append("WndEdit","nEventAlertTime",{x = nX + 5, y = nY + 10, w = 40,h = 25,txt = data.nEventAlertTime or 0})
			:Enable(data.nAutoEventTimeMode == AUTO_EVENTTIME_MODE.NONE):Change(function(txt)
				if tonumber(txt) then
					data.nAutoEventTimeMode = AUTO_EVENTTIME_MODE.NONE
					data.nEventAlertTime = tonumber(txt)
				end
			end):Pos_()
			nX,nY = ui:Append("WndComboBox",{ x = nX + 5, y = nY + 8,w = 130,h = 30,color = data.tRGBuffColor or {255,255,255}})
			:Text("查看10次记录"):Menu(function()
				return {
					{szOption = tTimeCache[1], bDisable = tTimeCache[1] == "无记录", fnAction = GetTimeSelectFunction(1)},
					{szOption = tTimeCache[2], bDisable = tTimeCache[2] == "无记录", fnAction = GetTimeSelectFunction(2)},
					{szOption = tTimeCache[3], bDisable = tTimeCache[3] == "无记录", fnAction = GetTimeSelectFunction(3)},
					{szOption = tTimeCache[4], bDisable = tTimeCache[4] == "无记录", fnAction = GetTimeSelectFunction(4)},
					{szOption = tTimeCache[5], bDisable = tTimeCache[5] == "无记录", fnAction = GetTimeSelectFunction(5)},
					{szOption = tTimeCache[6], bDisable = tTimeCache[6] == "无记录", fnAction = GetTimeSelectFunction(6)},
					{szOption = tTimeCache[7], bDisable = tTimeCache[7] == "无记录", fnAction = GetTimeSelectFunction(7)},
					{szOption = tTimeCache[8], bDisable = tTimeCache[8] == "无记录", fnAction = GetTimeSelectFunction(8)},
					{szOption = tTimeCache[9], bDisable = tTimeCache[9] == "无记录", fnAction = GetTimeSelectFunction(9)},
					{szOption = tTimeCache[10], bDisable = tTimeCache[10] == "无记录", fnAction = GetTimeSelectFunction(10)},
				}
			end):Pos_()
			_nY = nY
		end
		nX,nY = ui:Append("Text",{ x = 0, y = _nY, txt = "其他", font = 27}):Pos_()
		nX = ui:Append("WndEdit",{x = 10, y = nY + 10, w = 150,h = 25,txt = data.tAlarmAddInfo or "报警额外提示"})
		:Change(function(txt)
			if txt ~= "" then
				data.tAlarmAddInfo = txt
			else
				data.tAlarmAddInfo = nil
			end
		end):Pos_()
		if szType == "Npc" then
			nX = ui:Append("WndButton2",{ x = nX + 10, y = nY + 10 })
			:Enable(type(Circle) ~= "nil"):Text("添加到面向"):Click(function(bChecked)
				if IsAltKeyDown() then
					Circle.OpenAddPanel(data.dwID, TARGET.NPC, data.szMapName)
				else
					Circle.OpenAddPanel(data.szName, TARGET.NPC, data.szMapName)
				end
			end):Pos_()
		end
		nX = ui:Append("WndButton2",{ x = nX + 10, y = nY + 10 })
		:Text("打印信息"):Click(function(bChecked)
			RaidGrid_Base.OutputRecord(data)
		end):Pos_()
		nX = ui:Append("WndButton2",{ x = nX + 10, y = nY + 10,color = { 255, 0, 0 } })
		:Text(_L["Delete"]):Click(function(bChecked)
			if tTab.Hash2[dwID] and tTab[nStartIndex].nLevel then
				tTab.Hash2[dwID][tTab[nStartIndex].nLevel] = nil
			end
			if not tTab.Hash2[dwID] or IsTableEmpty(tTab.Hash2[dwID]) then
				tTab.Hash2[dwID] = nil
				tTab.Hash[dwID] = nil
			end
			table.remove(tTab, nStartIndex)
			GUI.UnRegisterPanel(_L["Set Data"])
			RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
		end):Pos_()
		nX,nY = ui:Append("Text",{ x = 10, y = nY + 35, txt = "其他操作请按住Ctrl右键", font = 109}):Alpha(180):Pos_()
	end
	if not IsCtrlKeyDown() then
		GUI.RegisterPanel(_L["Set Data"], tTab[nStartIndex].nIconID or 1475, _L["RGES"],PS)
		return JH.OpenPanel(_L["Set Data"])
	end
	table.insert(tOptions, {
		szOption = "　【"  .. (handle.tRecord.szName or "") .. "】 打开设置面板",fnAction = function()
			JH.DelayCall(50,function()
				GUI.RegisterPanel(_L["Set Data"], tTab[nStartIndex].nIconID or 1475, _L["RGES"],PS)
				JH.OpenPanel(_L["Set Data"])
			end)
		end,
	})

	table.insert(tOptions, {bDevide = true})
	table.insert(tOptions, {
		szOption = "　来源地图:"  .. (tTab[nStartIndex].szMapName or _L["Unknown"]), bCheck = false, bChecked = false, bDisable = true,
	})
	if tTab[nStartIndex].szCasterName then
		table.insert(tOptions, {
			szOption = "　技能释放者:"  .. (tTab[nStartIndex].szCasterName or _L["Unknown"]), bCheck = false, bChecked = false, bDisable = true,
		})
	end
	table.insert(tOptions, {
		bDevide = true
	})
	table.insert(tOptions,RaidGrid_EventScrutiny.SyncOptions(tTab[nStartIndex],nil))
	table.insert(tOptions, {bDevide = true})
	table.insert(tOptions, {
		szOption = "　删除此条目",rgb = {255,0,0}, bCheck = false, bChecked = false, fnAction = function(UserData, bCheck)
				if tTab.Hash2[dwID] and tTab[nStartIndex].nLevel then
					tTab.Hash2[dwID][tTab[nStartIndex].nLevel] = nil
				end
				if not tTab.Hash2[dwID] or IsTableEmpty(tTab.Hash2[dwID]) then
					tTab.Hash2[dwID] = nil
					tTab.Hash[dwID] = nil
				end
			table.remove(tTab, nStartIndex)
			GUI.UnRegisterPanel(_L["Set Data"])
			RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
		end,
	})
	table.insert(tOptions, {
		bDevide = true
	})
	table.insert(tOptions, {
		szOption = "　上移此条目", bCheck = false, bChecked = false, bDisable = not tTab[nStartIndex - 1], fnAction = function(UserData, bCheck)
			tTab[nStartIndex], tTab[nStartIndex - 1] = tTab[nStartIndex - 1], tTab[nStartIndex]
			GUI.UnRegisterPanel(_L["Set Data"])
			RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
		end,
	})
	table.insert(tOptions, {
		szOption = "　下移此条目", bCheck = false, bChecked = false, bDisable = not tTab[nStartIndex + 1], fnAction = function(UserData, bCheck)
			tTab[nStartIndex], tTab[nStartIndex + 1] = tTab[nStartIndex + 1], tTab[nStartIndex]
			GUI.UnRegisterPanel(_L["Set Data"])
			RaidGrid_EventScrutiny.UpdateRecordList(RaidGrid_EventScrutiny.szListIndex)
		end,
	})

	local nX, nY = Cursor.GetPos(true)
	tOptions.x, tOptions.y = nX + 15, nY + 15
	PopupMenu(tOptions)
end


function RaidGrid_EventScrutiny.OnCustomDataLoaded()
	if arg0 ~= "Role" then
		return
	end
	RaidGrid_EventScrutiny.tRecords.Scrutiny = {Hash = {},Hash2 = {}}
	RaidGrid_EventCache.OpenPanel()
	RaidGrid_EventCache.ClosePanel()
	RaidGrid_SelfBuffAlert.OpenPanel()
	RaidGrid_EventScrutiny.OpenPanel()
	RaidGrid_EventScrutiny.bCheckBoxRecall = false
	local checkBox = RaidGrid_EventScrutiny.wnd:Lookup("CheckBox_SelfBuff")
	if checkBox and RaidGrid_EventScrutiny.bBuffChatAlertEnable and RaidGrid_EventScrutiny.bCastingChatAlertEnable and RaidGrid_EventScrutiny.bNpcChatAlertEnable and RaidGrid_BossCallAlert and RaidGrid_BossCallAlert.bChatAlertEnable then
		checkBox:Check(true)
	end
	RaidGrid_EventScrutiny.bCheckBoxRecall = true

	if RaidGrid_SelfBuffAlert.tLastLoc.nX <= 0 and RaidGrid_SelfBuffAlert.tLastLoc.nY <= 0 then
		RaidGrid_SelfBuffAlert.SetPanelPos()
	else
		RaidGrid_SelfBuffAlert.SetPanelPos(RaidGrid_SelfBuffAlert.tLastLoc.nX, RaidGrid_SelfBuffAlert.tLastLoc.nY)
	end

	if not RaidGrid_EventScrutiny.bEnable then
		RaidGrid_EventScrutiny.ClosePanel()
	end
end

RegisterEvent("CUSTOM_DATA_LOADED", RaidGrid_EventScrutiny.OnCustomDataLoaded)

RegisterEvent("LOADING_END", function()
	local _, _, szLang = GetVersion()
	if szLang == "zhcn" and JH.IsInArena() and not JH.bDebugClient then
		if RaidGrid_EventScrutiny.bEnable then
			JH.Sysmsg(_L["Arena not use the plug."])
		end
		_RE.AutoEnable(false)
		ARENAMAP = true
	else
		ARENAMAP = false
		_RE.AutoEnable()
	end
end)


JH.BreatheCall("CheckNpcLifeAndAlarmOrg", RaidGrid_EventScrutiny.CheckNpcLifeAndAlarmOrg, 1000)

JH.BreatheCall("RefreshEventHandle", RaidGrid_EventScrutiny.RefreshEventHandle, 250)
JH.BreatheCall("GetWarningMessage", RaidGrid_BossCallAlert.GetWarningMessageOrg)

function _RE.Raid_MonitorBuffs()
	if not GetClientPlayer() then return end
	if not RaidGrid_EventScrutiny.bBuffTeamScrutinyEnable then
		Raid_MonitorBuffs({})
		return JH.BreatheCall("Raid_MonitorBuffs")
	end
	local tBuffs = {}
	for k,v in pairs(RaidGrid_EventScrutiny.tRecords.Buff) do
		if not v.bNotAddToCTM and tonumber(k) then
			table.insert(tBuffs,v.dwID)
		end
	end
	for k,v in pairs(RaidGrid_EventScrutiny.tRecords.Debuff) do
		if not v.bNotAddToCTM and tonumber(k) then
			table.insert(tBuffs,v.dwID)
		end
	end
	Raid_MonitorBuffs(tBuffs)
end

JH.BreatheCall("Raid_MonitorBuffs", _RE.Raid_MonitorBuffs, 10000)
------------------------------------------------------------------

JH.RegisterEvent("LOADING_END", function()
	local _, _, szLang = GetVersion()
	if IsRemotePlayer(UI_GetClientPlayerID()) then
		return
	end
	if RGES_CLIENT_PLAYER then
		local me = GetClientPlayer()
		RGES_CLIENT_PLAYER = me.szName

		if RaidGrid_Base.version == 1 then
			RaidGrid_Base.LoadSettingsFileNew(szLang .. "_default.jx3dat", true)
			RaidGrid_Base.version = 3
		end
		local path = RGES_DATA_PATH .. RGES_CLIENT_PLAYER .. "/"
		if RaidGrid_Base.version == 2 then
			for k, v in ipairs(RGES_ALL_TYPE) do
				local data = JH.LoadLUAData(path .. v)
				if data then
					RaidGrid_EventScrutiny.tRecords[v] = JH.JsonDecode(data)
					HashChange(RaidGrid_EventScrutiny.tRecords[v])
				end
			end
			JH.DelayCall(1000, function()
				for k, v in ipairs({"tWarningMessages", "tBossCall"}) do
					local data = JH.LoadLUAData(path .. v)
					if data then
						RaidGrid_BossCallAlert.tRecords[v] = JH.JsonDecode(data)
					end
				end
			end)
			if RaidGrid_EventScrutiny.bOutputEventCacheRecords then
				JH.DelayCall(2500, function()
					for k, v in ipairs(RGES_ALL_TYPE) do
						local data = JH.LoadLUAData(path .. "cache/" .. v)
						if data then
							RaidGrid_EventCache.tRecords[v] = JH.JsonDecode(data)
							HashChange(RaidGrid_EventCache.tRecords[v])
						end
					end

				end)
			end
			RaidGrid_Base.version = 3
		else
			for k, v in ipairs(RGES_ALL_TYPE) do
				JH.DelayCall(500 * k, function()
					local data = JH.LoadLUAData(path .. v)
					if data then
						RaidGrid_EventScrutiny.tRecords[v] = data
						HashChange(RaidGrid_EventScrutiny.tRecords[v])
					end
				end)
			end
			for k, v in ipairs({"tWarningMessages", "tBossCall"}) do
				JH.DelayCall(1200 * k, function()
					local data = JH.LoadLUAData(path .. v)
					if data then
						RaidGrid_BossCallAlert.tRecords[v] = data
					end
				end)
			end
			if RaidGrid_EventScrutiny.bOutputEventCacheRecords then
				JH.DelayCall(3000, function()
					for k, v in ipairs(RGES_ALL_TYPE) do
						local data = JH.LoadLUAData(path .. "cache/" .. v)
						if data then
							RaidGrid_EventCache.tRecords[v] = data
							HashChange(RaidGrid_EventCache.tRecords[v])
						end
					end
				end)
			end
			JH.DelayCall(10000, ClearCacheData)
		end
	end
end)

local function SaveRGESData()
	ClearCacheData()
	local path = RGES_DATA_PATH .. RGES_CLIENT_PLAYER .. "/"
	for k, v in ipairs(RGES_ALL_TYPE) do
		RaidGrid_EventScrutiny.tRecords[v].Hash = nil
		RaidGrid_EventScrutiny.tRecords[v].Hash2 = nil
		JH.SaveLUAData(path .. v, RaidGrid_EventScrutiny.tRecords[v])
	end
	for k, v in ipairs({"tWarningMessages", "tBossCall"}) do
		JH.SaveLUAData(path .. v, RaidGrid_BossCallAlert.tRecords[v])
	end

	if RaidGrid_EventScrutiny.bOutputEventCacheRecords then
		for k,v in ipairs(RGES_ALL_TYPE) do
			RaidGrid_EventCache.tRecords[v].Hash = nil
			RaidGrid_EventCache.tRecords[v].Hash2 = nil
			JH.SaveLUAData(path .. "cache/" .. v, RaidGrid_EventCache.tRecords[v])
		end
	end
end

JH.RegisterEvent("GAME_EXIT", SaveRGESData)
JH.RegisterEvent("PLAYER_EXIT_GAME", SaveRGESData)
