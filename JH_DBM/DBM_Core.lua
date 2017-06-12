-- @Author: Webster
-- @Date:   2015-05-13 16:06:53
-- @Last Modified by:   William Chan
-- @Last Modified time: 2017-06-12 14:29:11

local _L = JH.LoadLangPack
local ipairs, pairs, select = ipairs, pairs, select
local setmetatable, tonumber, type, tostring, unpack = setmetatable, tonumber, type, tostring, unpack
local tinsert, tconcat = table.insert, table.concat
local floor = math.floor
local GetTime, GetLogicFrameCount, GetCurrentTime, IsPlayer = GetTime, GetLogicFrameCount, GetCurrentTime, IsPlayer
local GetClientPlayer, GetClientTeam, GetPlayer, GetNpc = GetClientPlayer, GetClientTeam, GetPlayer, GetNpc
local FireUIEvent, Table_BuffIsVisible, Table_IsSkillShow = FireUIEvent, Table_BuffIsVisible, Table_IsSkillShow
local GetPureText, GetFormatText, GetHeadTextForceFontColor = GetPureText, GetFormatText, GetHeadTextForceFontColor
local TargetPanel_SetOpenState = TargetPanel_SetOpenState
local JH_Split, JH_Trim = JH.Split, JH.Trim
local DBM_TYPE, DBM_SCRUTINY_TYPE = DBM_TYPE, DBM_SCRUTINY_TYPE
-- 核心优化变量
local DBM_CORE_PLAYERID = 0
local DBM_CORE_NAME     = 0

local DBM_MAX_INTERVAL  = 300
local DBM_MAX_CACHE     = 3000 -- 最大的cache数量 主要是UI的问题
local DBM_DEL_CACHE     = 1000 -- 每次清理的数量 然后会做一次gc
local DBM_INIFILE       = JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/DBM.ini"

local DBM_SHARE_QUEUE = {}
local DBM_MARK_QUEUE  = {}
local DBM_MARK_FREE   = true -- 标记空闲
----
local DBM_LEFT_LINE  = GetFormatText(_L["["], 44, 255, 255, 255)
local DBM_RIGHT_LINE = GetFormatText(_L["]"], 44, 255, 255, 255)
----
local DBM_TYPE_LIST = { "BUFF", "DEBUFF", "CASTING", "NPC", "DOODAD", "TALK", "CHAT" }

local DBM_EVENTS = {
	"NPC_ENTER_SCENE",
	"NPC_LEAVE_SCENE",
	"DBM_NPC_FIGHT",
	"DBM_NPC_ENTER_SCENE",
	"DBM_NPC_ALLLEAVE_SCENE",
	"DBM_NPC_LIFE_CHANGE",
	"DBM_NPC_MANA_CHANGE",

	"DOODAD_ENTER_SCENE",
	"DOODAD_LEAVE_SCENE",
	"DBM_DOODAD_ENTER_SCENE",
	"DBM_DOODAD_ALLLEAVE_SCENE",

	"BUFF_UPDATE",
	"SYS_MSG",
	"DO_SKILL_CAST",

	"PLAYER_SAY",
	"ON_WARNING_MESSAGE",

	"DBM_SET_MARK",
	"PARTY_SET_MARK",
}

local function GetDataPath()
	local szPath = DBM.bCommon and "DBM/Common/DBM.jx3dat" or "DBM/" .. GetUserRoleName() .. "/DBM.jx3dat"
	Log("[DBM] data path: " .. szPath)
	return szPath
end

local CACHE = {
	TEMP        = {}, -- 近期事件记录MAP 这里用弱表 方便处理
	MAP         = {},
	NPC_LIST    = {},
	DOODAD_LIST = {},
	SKILL_LIST  = {},
	INTERVAL    = {},
	DUNGEON     = {},
	STR         = {},
}

local D = {
	FILE  = {}, -- 文件原始数据
	TEMP  = {}, -- 近期事件记录
	DATA  = {},  -- 需要监控的数据合集
}

-- 初始化table 虽然写法没有直接写来得好 但是为了方便以后改动
do
	for k, v in ipairs(DBM_TYPE_LIST) do
		D.FILE[v]         = {}
		D.DATA[v]         = {}
		D.TEMP[v]         = {}
		CACHE.MAP[v]      = {}
		CACHE.INTERVAL[v] = {}
		CACHE.TEMP[v]     = setmetatable({}, { __mode = "v" })
		if v == "TALK" or v == "CHAT" then -- init talk stru
			CACHE.MAP[v].HIT   = {}
			CACHE.MAP[v].OTHER = {}
		end
	end
end

DBM = {
	bEnable             = true,
	bCommon             = true,
	bPushScreenHead     = true,
	bPushCenterAlarm    = true,
	bPushBigFontAlarm   = true,
	bPushTeamPanel      = true, -- 面板buff监控
	bPushFullScreen     = true, -- 全屏泛光
	bPushTeamChannel    = false, -- 团队报警
	bPushWhisperChannel = false, -- 密聊报警
	bPushBuffList       = true,
	bPushPartyBuffList  = true,
}
JH.RegisterCustomData("DBM")
local DBM = DBM

function DBM.OnFrameCreate()
	this:RegisterEvent("DBM_LOADING_END")
	this:RegisterEvent("DBM_CREATE_CACHE")
	this:RegisterEvent("LOADING_END")
	D.Enable(DBM.bEnable)
	D.Log("init success!")
	JH.BreatheCall("DBM_CACHE_CLEAR", function()
		for k, v in ipairs(DBM_TYPE_LIST) do
			if #D.TEMP[v] > DBM_MAX_CACHE then
				D.FreeCache(v)
			end
		end
		for k, v in pairs(CACHE.INTERVAL) do
			for kk, vv in pairs(v) do
				if #vv > DBM_MAX_INTERVAL then
					CACHE.INTERVAL[k][kk] = {}
				end
			end
		end
	end, 60 * 2 * 1000) -- 2min
end

function DBM.OnFrameBreathe()
	local me = GetClientPlayer()
	if not me then return end
	-- local dwType, dwID = me.GetTarget()
	for k, v in pairs(CACHE.NPC_LIST) do
		local data = D.GetData("NPC", k)
		if data then
			-- local bTempTarget = false
			-- for kk, vv in ipairs(data.tCountdown or {}) do
			-- 	if vv.nClass == DBM_TYPE.NPC_MANA then
			-- 		bTempTarget = true
			-- 		break
			-- 	end
			-- end
			local bFightFlag = false
			local fLifePer = 1
			local fManaPer = 1
			-- TargetPanel_SetOpenState(true)
			for kk, vv in ipairs(v.tList) do
				local npc = GetNpc(vv)
				if npc then
					-- if bTempTarget then
					-- 	JH.SetTarget(TARGET.NPC, vv)
					-- 	JH.SetTarget(dwType, dwID)
					-- end
					local fLife = npc.nCurrentLife / npc.nMaxLife
					local fMana = npc.nCurrentMana / npc.nMaxMana
					if fLife < fLifePer then -- 取血量最少的NPC
						fLifePer = fLife
					end
					-- if fMana < fManaPer then -- 取蓝量最少的NPC
					-- 	fManaPer = fMana
					-- end
					-- 战斗标记检查
					if npc.bFightState then
						bFightFlag = true
						break
					end
				end
			end
			-- TargetPanel_SetOpenState(false)
			if bFightFlag ~= v.bFightState then
				CACHE.NPC_LIST[k].bFightState = bFightFlag
			else
				bFightFlag = nil
			end
			fLifePer = floor(fLifePer * 100)
			-- fManaPer = floor(fManaPer * 100)
			if v.nLife > fLifePer then
				local nCount, step = v.nLife - fLifePer, 1
				if nCount > 50 then
					step = 2
				end
				for i = 1, nCount, step do
					FireUIEvent("DBM_NPC_LIFE_CHANGE", k, v.nLife - i)
				end
			end
			-- if bTempTarget then
			-- 	if v.nMana < fManaPer then
			-- 		local nCount, step = fManaPer - v.nMana, 1
			-- 		if nCount > 50 then
			-- 			step = 2
			-- 		end
			-- 		for i = 1, nCount, step do
			-- 			FireUIEvent("DBM_NPC_MANA_CHANGE", k, v.nMana + i)
			-- 		end
			-- 	end
			-- end
			v.nLife = fLifePer
			-- v.nMana = fManaPer
			if bFightFlag then
				local nTime = GetTime()
				v.nSec = GetTime()
				FireUIEvent("DBM_NPC_FIGHT", k, true, nTime)
			elseif bFightFlag == false then
				local nTime = GetTime() - (v.nSec or GetTime())
				v.nSec = nil
				FireUIEvent("DBM_NPC_FIGHT", k, false, nTime)
			end
		end
	end
end

function DBM.OnEvent(szEvent)
	if szEvent == "BUFF_UPDATE" then
		D.OnBuff(arg0, arg1, arg3, arg4, arg5, arg8, arg9)
	elseif szEvent == "SYS_MSG" then
		if arg0 == "UI_OME_DEATH_NOTIFY" then
			if not IsPlayer(arg1) then
				D.OnDeath(arg1, arg2)
			end
		elseif arg0 == "UI_OME_SKILL_CAST_LOG" then
			D.OnSkillCast(arg1, arg2, arg3, arg0)
		elseif (arg0 == "UI_OME_SKILL_BLOCK_LOG"
		or arg0 == "UI_OME_SKILL_SHIELD_LOG" or arg0 == "UI_OME_SKILL_MISS_LOG"
		or arg0 == "UI_OME_SKILL_DODGE_LOG"	or arg0 == "UI_OME_SKILL_HIT_LOG")
		and arg3 == SKILL_EFFECT_TYPE.SKILL then
			D.OnSkillCast(arg1, arg4, arg5, arg0)
		elseif arg0 == "UI_OME_SKILL_EFFECT_LOG" and arg4 == SKILL_EFFECT_TYPE.SKILL then
			D.OnSkillCast(arg1, arg5, arg6, arg0)
		end
	elseif szEvent == "DO_SKILL_CAST" then
		D.OnSkillCast(arg0, arg1, arg2, szEvent)
	elseif szEvent == "PARTY_SET_MARK" or szEvent == "DBM_SET_MARK" then
		if #DBM_MARK_QUEUE >= 1 then
			local r = table.remove(DBM_MARK_QUEUE, 1)
			local res, err = pcall(r.fnAction)
			if not res then
				JH.Debug("DBM_Mark ERROR: " .. err)
			end
		else
			DBM_MARK_FREE = true
		end
	elseif szEvent == "PLAYER_SAY" then
		if not IsPlayer(arg1) then
			local szText = GetPureText(arg0)
			if szText and szText ~= "" then
				D.OnCallMessage("TALK", szText, arg1, arg3 == "" and "%" or arg3)
			else
				JH.Debug("GetPureText ERROR: " .. arg0)
			end
		end
	elseif szEvent == "ON_WARNING_MESSAGE" then
		D.OnCallMessage("TALK", arg1)
	elseif szEvent == "DOODAD_ENTER_SCENE" or szEvent == "DBM_DOODAD_ENTER_SCENE" then
		local doodad = GetDoodad(arg0)
		if doodad then
			D.OnDoodadEvent(doodad, true)
		end
	elseif szEvent == "DOODAD_LEAVE_SCENE" then
		local doodad = GetDoodad(arg0)
		if doodad then
			D.OnDoodadEvent(doodad, false)
		end
	elseif szEvent == "DBM_DOODAD_ALLLEAVE_SCENE" then
		D.OnDoodadAllLeave(arg0)
	elseif szEvent == "NPC_ENTER_SCENE" or szEvent == "DBM_NPC_ENTER_SCENE" then
		local npc = GetNpc(arg0)
		if npc then
			D.OnNpcEvent(npc, true)
		end
	elseif szEvent == "NPC_LEAVE_SCENE" then
		local npc = GetNpc(arg0)
		if npc then
			D.OnNpcEvent(npc, false)
		end
	elseif szEvent == "DBM_NPC_ALLLEAVE_SCENE" then
		D.OnNpcAllLeave(arg0)
	elseif szEvent == "DBM_NPC_FIGHT" then
		D.OnNpcFight(arg0, arg1)
	elseif szEvent == "DBM_NPC_LIFE_CHANGE" or szEvent == "DBM_NPC_MANA_CHANGE" then
		D.OnNpcInfoChange(szEvent, arg0, arg1)
	elseif szEvent == "LOADING_END" or szEvent == "DBM_CREATE_CACHE" or szEvent == "DBM_LOADING_END" then
		D.CreateData(szEvent)
	end
end

function D.Log(szMsg)
	return Log("[DBM] " .. szMsg)
end

function D.Talk(szMsg, szTarget)
	local me = GetClientPlayer()
	if not me then return end
	if not szTarget then
		if me.IsInParty() then
			JH.Talk(PLAYER_TALK_CHANNEL.RAID, szMsg, "DBM." .. szMsg .. GetLogicFrameCount())
		end
	elseif type(szTarget) == "string" then
		local szText = szMsg:gsub(_L["["] .. szTarget .. _L["]"], _L["["] .. g_tStrings.STR_YOU ..  _L["]"])
		if szTarget == me.szName then
			JH.OutputWhisper(szText, "DBM")
		else
			JH.Talk(szTarget, szText, "DBM." .. szMsg .. GetLogicFrameCount())
		end
	elseif type(szTarget) == "boolean" then
		if me.IsInParty() then
			local team = GetClientTeam()
			for _, v in ipairs(team.GetTeamMemberList()) do
				local szName = team.GetClientTeamMemberName(v)
				local szText = szMsg:gsub(_L["["] .. szName .. _L["]"], _L["["] .. g_tStrings.STR_YOU ..  _L["]"])
				if szName == me.szName then
					JH.OutputWhisper(szText, "DBM")
				else
					JH.Talk(szName, szText, "DBM." .. szMsg .. GetLogicFrameCount())
				end
			end
		end
	end
end

local function CreateCache(szType, tab)
	local data  = D.DATA[szType]
	local cache = CACHE.MAP[szType]
	for k, v in ipairs(tab) do
		data[#data + 1] = v
		if v.nLevel then
			cache[v.dwID] = cache[v.dwID] or {}
			cache[v.dwID][v.nLevel] = k
		else -- other
			cache[v.dwID] = k
		end
	end
	D.Log("create " .. szType .. " data success!")
end
-- 核心函数 缓存创建 UI缓存创建
function D.CreateData(szEvent)
	local nTime   = GetTime()
	local szLang  = select(3, GetVersion())
	local dwMapID = JH.GetMapID(true)
	local me = GetClientPlayer()
	-- 用于更新 BUFF / CAST / NPC 缓存处理 不需要再获取本地对象
	DBM_CORE_NAME     = me.szName
	DBM_CORE_PLAYERID = me.dwID
	D.Log("get player info cache success!")
	-- 重建metatable 获取ALL数据的方法 主要用于UI 逻辑中毫无作用
	for kType, vTable in pairs(D.FILE)  do
		setmetatable(D.FILE[kType], { __index = function(me, index)
			if index == _L["All Data"] then
				local t = {}
				for k, v in pairs(vTable) do
					if k ~= -9 then
						for kk, vv in ipairs(v) do
							t[#t +1] = vv
						end
					end
				end
				return t
			end
		end })
		-- 重建所有数据的metatable
		for k, v in pairs(vTable) do
			for kk, vv in ipairs(v) do
				setmetatable(vv, { __index = function(_, val)
					if val == "dwMapID" then
						return k
					elseif val == "nIndex" then
						return kk
					end
				end })
			end
		end
	end
	D.Log("create metatable success!")
	-- 清空当前数据和MAP
	for k, v in pairs(D.DATA) do
		D.DATA[k] = {}
	end
	for k, v in pairs(CACHE.MAP) do
		CACHE.MAP[k] = {}
		if k == "TALK" or k == "CHAT" then
			CACHE.MAP[k].HIT   = {}
			CACHE.MAP[k].OTHER = {}
		end
	end
	pcall(Raid_MonitorBuffs) -- clear
	-- 判断战场使用条件
	if JH.IsInArena() and szLang == "zhcn" and not JH.bDebugClient then
		JH.Sysmsg(_L["Arena not use the plug."])
		D.Log("MAPID: " .. dwMapID ..  " create data Failed:" .. GetTime() - nTime  .. "ms")
	else
		-- 重建MAP
		for _, v in ipairs({ "BUFF", "DEBUFF", "CASTING", "NPC", "DOODAD" }) do
			if D.FILE[v][dwMapID] then -- 本地图数据
				CreateCache(v, D.FILE[v][dwMapID])
			end
			if D.FILE[v][-1] then -- 通用数据
				CreateCache(v, D.FILE[v][-1])
			end
		end
		-- 单独重建TALK数据
		do
			for _, vType in ipairs({ "TALK", "CHAT" }) do
				local data  = D.FILE[vType]
				local talk  = D.DATA[vType]
				CACHE.MAP[vType] = {
					HIT   = {},
					OTHER = {},
				}
				local cache = CACHE.MAP[vType]
				if data[-1] then -- 通用数据
					for k, v in ipairs(data[-1]) do
						talk[#talk + 1] = v
					end
				end
				if data[dwMapID] then -- 本地图数据
					for k, v in ipairs(data[dwMapID]) do
						talk[#talk + 1] = v
					end
				end
				for k, v in ipairs(talk) do
					if v.szContent then
						if v.szContent:find("$me") or v.szContent:find("$team") or v.bSearch or v.bReg then
							tinsert(cache.OTHER, v)
						else
							cache.HIT[v.szContent] = cache.HIT[v.szContent] or {}
							cache.HIT[v.szContent][v.szTarget or "sys"] = v
						end
					else
						JH.Sysmsg2("[Warning] " .. vType .. " data is not szContent #" .. k .. ", please do check it!")
					end
				end
				D.Log("create " .. vType .. " data success!")
			end
		end
		if DBM.bPushTeamPanel then
			local tBuff = {}
			for k, v in ipairs(D.DATA.BUFF) do
				if v[DBM_TYPE.BUFF_GET] and v[DBM_TYPE.BUFF_GET].bTeamPanel then
					tinsert(tBuff, v.dwID)
				end
			end
			for k, v in ipairs(D.DATA.DEBUFF) do
				if v[DBM_TYPE.BUFF_GET] and v[DBM_TYPE.BUFF_GET].bTeamPanel then
					tinsert(tBuff, v.dwID)
				end
			end
			pcall(Raid_MonitorBuffs, tBuff)
		end
		D.Log("MAPID: " .. dwMapID ..  " create data success:" .. GetTime() - nTime  .. "ms")
	end
	-- gc
	if szEvent ~= "DBM_CREATE_CACHE" then
		CACHE.NPC_LIST   = {}
		CACHE.SKILL_LIST = {}
		CACHE.STR        = {}
		D.Log("collectgarbage(\"count\") " .. collectgarbage("count"))
		collectgarbage("collect")
		D.Log("collectgarbage(\"collect\") " .. collectgarbage("count"))
	end
	FireUIEvent("DBMUI_FREECACHE")
end

function D.FreeCache(szType)
	local t = {}
	local tTemp = D.TEMP[szType]
	for i = DBM_DEL_CACHE, #tTemp do
		t[#t + 1] = tTemp[i]
	end
	D.TEMP[szType] = t
	collectgarbage("collect")
	FireUIEvent("DBMUI_TEMP_RELOAD", szType)
	D.Log(szType .. " cache clear!")
end

function D.CheckScrutinyType(nScrutinyType, dwID)
	if nScrutinyType == DBM_SCRUTINY_TYPE.SELF and dwID ~= DBM_CORE_PLAYERID then
		return false
	elseif nScrutinyType == DBM_SCRUTINY_TYPE.TEAM and (not JH.IsParty(dwID) and dwID ~= DBM_CORE_PLAYERID) then
		return false
	elseif nScrutinyType == DBM_SCRUTINY_TYPE.ENEMY and not IsEnemy(DBM_CORE_PLAYERID, dwID) then
		return false
	elseif nScrutinyType == DBM_SCRUTINY_TYPE.TARGET then
		local obj = JH.GetTarget()
		if not obj or obj and obj.dwID ~= dwID then
			return false
		end
	end
	return true
end

function D.CheckKungFu(tKungFu)
	if tKungFu["SKILL#" .. UI_GetPlayerMountKungfuID()] then
		return true
	end
	return false
end

-- 智能标记逻辑
function D.SetTeamMark(szType, tMark, dwCharacterID, dwID, nLevel)
	if not JH.IsMark() then return end
	local fnAction = function()
		local team = GetClientTeam()
		local tTeamMark, tMarkList = team.GetTeamMark(), {} -- tmd 什么鬼结构。。。
		for k, v in pairs(tTeamMark) do
			tMarkList[v] = k
		end
		if szType == "NPC" then
			for k, v in ipairs(tMark) do
				if v then
					if not tMarkList[k] or tMarkList[k] == 0 or (tMarkList[k] and tMarkList[k] ~= dwCharacterID) then
						local p = tMarkList[k] and GetNpc(tMarkList[k])
						if not p or (p and p.dwTemplateID ~= dwID) then
							return team.SetTeamMark(k, dwCharacterID)
						end
					end
				end
			end
		elseif szType == "BUFF" or szType == "DEBUFF" then
			for k, v in ipairs(tMark) do
				if v then
					if not tMarkList[k] or tMarkList[k] == 0 or (tMarkList[k] and tMarkList[k] ~= dwCharacterID) then
						local p
						if tMarkList[k] then
							p = IsPlayer(tMarkList[k]) and GetPlayer(tMarkList[k]) or GetNpc(tMarkList[k])
						end
						if not p or (p and not JH.GetBuff(dwID, p)) then
							return team.SetTeamMark(k, dwCharacterID)
						end
					end
				end
			end
		elseif szType == "CASTING" then
			for k, v in ipairs(tMark) do
				if v then
					if not tMarkList[k] or (tMarkList[k] and tMarkList[k] ~= dwCharacterID) then
						return team.SetTeamMark(k, dwCharacterID)
					end
				end
			end
		end
		FireUIEvent("DBM_SET_MARK", false) -- 标记失败的案例
	end
	tinsert(DBM_MARK_QUEUE, { fnAction = fnAction })
	if DBM_MARK_FREE then
		DBM_MARK_FREE = false
		local f = table.remove(DBM_MARK_QUEUE, 1)
		pcall(f.fnAction)
	end
end
-- 倒计时处理 支持定义无限的倒计时
function D.CountdownEvent(data, nClass)
	if data.tCountdown then
		local i = 1
		for k, v in ipairs(data.tCountdown) do
			if nClass == v.nClass then
				if v.nTime ~= 0 then
					if i > 2 then
						break
					else
						i = i + 1
					end
				end
				local szKey = k .. "." .. (data.dwID or 0) .. "." .. (data.nLevel or 0) .. "." .. (data.nIndex or 0)
				local tParam = {
					key      = v.key,
					nFrame   = v.nFrame,
					nTime    = v.nTime,
					nRefresh = v.nRefresh,
					szName   = v.szName or data.szName,
					nIcon    = v.nIcon or data.nIcon or 340,
					bTalk    = v.bTeamChannel,
					bHold    = v.bHold
				}
				D.FireCountdownEvent(nClass, szKey, tParam)
			end
		end
	end
end

-- 发布事件 为了方便日后修改 集中起来
function D.FireCountdownEvent(nClass, szKey, tParam)
	tParam.bTalk = DBM.bPushTeamChannel and tParam.bTalk
	nClass       = tParam.key and DBM_TYPE.COMMON or nClass
	szKey        = tParam.key or szKey
	FireUIEvent("JH_ST_CREATE", nClass, szKey, tParam)
end

function D.GetSrcName(dwID)
	if not dwID then
		return nil
	end
	if dwID == 0 then
		return g_tStrings.COINSHOP_SOURCE_NULL
	end
	local KObject = IsPlayer(dwID) and GetPlayer(dwID) or GetNpc(dwID)
	if KObject then
		return JH.GetTemplateName(KObject)
	else
		return dwID
	end
end

-- local a=GetTime();for i=1, 10000 do FireUIEvent("BUFF_UPDATE",UI_GetClientPlayerID(),false,1,true,i,1,1,1,1,0) end;Output(GetTime()-a)
-- 事件操作
function D.OnBuff(dwCaster, bDelete, bCanCancel, dwBuffID, nCount, nBuffLevel, dwSkillSrcID)
	local szType = bCanCancel and "BUFF" or "DEBUFF"
	local key = dwBuffID .. "_" .. nBuffLevel
	local data = D.GetData(szType, dwBuffID, nBuffLevel)
	local nTime = GetTime()
	if not Table_BuffIsVisible(dwBuffID, nBuffLevel) and not JH.bDebugClient then
		return
	end
	if not bDelete then
		-- 近期记录
		local tWeak, tTemp = CACHE.TEMP[szType], D.TEMP[szType]
		if not tWeak[key] then
			local t = {
				dwMapID      = JH.GetMapID(),
				dwID         = dwBuffID,
				nLevel       = nBuffLevel,
				bIsPlayer    = dwSkillSrcID ~= 0 and IsPlayer(dwSkillSrcID),
				szSrcName    = D.GetSrcName(dwSkillSrcID),
				nCurrentTime = GetCurrentTime()
			}
			tWeak[key] = t
			tTemp[#tTemp + 1] = tWeak[key]
			FireUIEvent("DBMUI_TEMP_UPDATE", szType, t)
		end
		-- 记录时间
		CACHE.INTERVAL[szType][key] = CACHE.INTERVAL[szType][key] or {}
		if #CACHE.INTERVAL[szType][key] > 0 then
			if nTime - CACHE.INTERVAL[szType][key][#CACHE.INTERVAL[szType][key]] > 1000 then
				CACHE.INTERVAL[szType][key][#CACHE.INTERVAL[szType][key] + 1] = nTime
			end
		else
			CACHE.INTERVAL[szType][key][#CACHE.INTERVAL[szType][key] + 1] = nTime
		end
	end
	if data then
		local cfg, nClass
		if data.nScrutinyType and not D.CheckScrutinyType(data.nScrutinyType, dwCaster) then -- 监控对象检查
			return
		end
		if data.tKungFu and not D.CheckKungFu(data.tKungFu) then -- 自身身法需求检查
			return
		end
		if data.nCount and nCount < data.nCount then -- 层数检查
			return
		end
		if bDelete then
			cfg, nClass = data[DBM_TYPE.BUFF_LOSE], DBM_TYPE.BUFF_LOSE
		else
			cfg, nClass = data[DBM_TYPE.BUFF_GET], DBM_TYPE.BUFF_GET
		end
		D.CountdownEvent(data, nClass)
		if cfg then
			local szName, nIcon = JH.GetBuffName(dwBuffID, nBuffLevel)
			local KObject = IsPlayer(dwCaster) and GetPlayer(dwCaster) or GetNpc(dwCaster)
			if not KObject then
				return -- D.Log("ERROR " .. szType .. " object:" .. dwCaster .. " does not exist!")
			end
			-- szName = data.szName or szName
			nIcon  = data.nIcon or nIcon
			local szSrcName = JH.GetTemplateName(KObject)
			local xml = {}
			tinsert(xml, DBM_LEFT_LINE)
			tinsert(xml, GetFormatText(szSrcName == DBM_CORE_NAME and g_tStrings.STR_YOU or szSrcName, 44, 255, 255, 0))
			tinsert(xml, DBM_RIGHT_LINE)
			if nClass == DBM_TYPE.BUFF_GET then
				tinsert(xml, GetFormatText(_L["Get Buff"], 44, 255, 255, 255))
				tinsert(xml, GetFormatText(szName .. " x" .. nCount, 44, 255, 255, 0))
				-- if data.szNote then
				-- 	tinsert(xml, GetFormatText(" " .. data.szNote, 44, 255, 255, 255))
				-- end
			else
				tinsert(xml, GetFormatText(_L["Lose Buff"], 44, 255, 255, 255))
				tinsert(xml, GetFormatText(szName, 44, 255, 255, 0))
			end
			local txt = GetPureText(tconcat(xml))
			if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
				FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
			end
			-- 特大文字
			if DBM.bPushBigFontAlarm and cfg.bBigFontAlarm and (DBM_CORE_PLAYERID == dwCaster or not IsPlayer(dwCaster)) then
				FireUIEvent("JH_LARGETEXT", txt, data.col or { GetHeadTextForceFontColor(dwCaster, DBM_CORE_PLAYERID) })
			end

			-- 获得处理
			if nClass == DBM_TYPE.BUFF_GET then
				if JH.bDebugClient and cfg.bSelect then
					SetTarget(IsPlayer(dwCaster) and TARGET.PLAYER or TARGET.NPC, dwCaster)
				end
				if cfg.tMark then
					D.SetTeamMark(szType, cfg.tMark, dwCaster, dwBuffID, nBuffLevel)
				end
				-- 重要Buff列表
				if DBM.bPushPartyBuffList and IsPlayer(dwCaster) and cfg.bPartyBuffList and (JH.IsParty(dwCaster) or DBM_CORE_PLAYERID == dwCaster) then
					FireUIEvent("JH_PARTYBUFFLIST", dwCaster, data.dwID, data.nLevel, data.nIcon)
				end
				-- 头顶报警
				if DBM.bPushScreenHead and cfg.bScreenHead then
					FireUIEvent("JH_SA_CREATE", szType, dwCaster, { dwID = data.dwID, col = data.col, txt = szName })
				end
				if DBM_CORE_PLAYERID == dwCaster then
					if DBM.bPushBuffList and cfg.bBuffList then
						local col = szType == "BUFF" and { 0, 255, 0 } or { 255, 0, 0 }
						if data.col then
							col = data.col
						end
						FireUIEvent("JH_BL_CREATE", data.dwID, data.nLevel, col, data)
					end
					-- 全屏泛光
					if DBM.bPushFullScreen and cfg.bFullScreen then
						FireUIEvent("JH_FS_CREATE", data.dwID .. "_"  .. data.nLevel, {
							nTime = 3,
							col = data.col,
							tBindBuff = { data.dwID, data.nLevel }
						})
					end
				end
				-- 添加到团队面板
				if DBM.bPushTeamPanel and cfg.bTeamPanel and ( not cfg.bOnlySelfSrc or dwSkillSrcID == DBM_CORE_PLAYERID) then
					FireUIEvent("JH_RAID_REC_BUFF", dwCaster, {
						dwID      = data.dwID,
						nStackNum = data.nCount,
						nLevel    = data.bCheckLevel and data.nLevel or 0,
						nLevelEx  = data.nLevel,
						col       = data.col,
						nIcon     = data.nIcon,
						bOnlySelf = cfg.bOnlySelfSrc,
					})
				end
			end
			if DBM.bPushTeamChannel and cfg.bTeamChannel then
				local talk = txt:gsub(_L["["] .. g_tStrings.STR_YOU .. _L["]"], _L["["] .. szSrcName .. _L["]"])
				D.Talk(talk)
			end
			if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
				D.Talk(txt, szSrcName)
			end
		end
	end
end
-- 技能事件
function D.OnSkillCast(dwCaster, dwCastID, dwLevel, szEvent)
	local key = dwCastID .. "_" .. dwLevel
	local nTime = GetTime()
	CACHE.SKILL_LIST[dwCaster] = CACHE.SKILL_LIST[dwCaster] or {}
	if CACHE.SKILL_LIST[dwCaster][key] and nTime - CACHE.SKILL_LIST[dwCaster][key] < 62.5 then -- 1/16
		return
	end
	if dwCastID == 13165 then -- 内功切换
		if szEvent == "UI_OME_SKILL_CAST_LOG" then
			FireUIEvent("JH_KUNGFU_SWITCH", dwCaster)
		end
	end
	local data = D.GetData("CASTING", dwCastID, dwLevel)
	if not Table_IsSkillShow(dwCastID, dwLevel) and not JH.bDebugClient then
		return
	end
	local tWeak, tTemp = CACHE.TEMP.CASTING, D.TEMP.CASTING
	if not tWeak[key] then
		local t = {
			dwMapID      = JH.GetMapID(),
			dwID         = dwCastID,
			nLevel       = dwLevel,
			bIsPlayer    = IsPlayer(dwCaster),
			szSrcName    = D.GetSrcName(dwCaster),
			nCurrentTime = GetCurrentTime()
		}
		tWeak[key] = t
		tTemp[#tTemp + 1] = tWeak[key]
		FireUIEvent("DBMUI_TEMP_UPDATE", "CASTING", t)
	end
	CACHE.INTERVAL.CASTING[key] = CACHE.INTERVAL.CASTING[key] or {}
	CACHE.INTERVAL.CASTING[key][#CACHE.INTERVAL.CASTING[key] + 1] = nTime
	CACHE.SKILL_LIST[dwCaster][key] = nTime
	-- 监控数据
	if data then
		if data.nScrutinyType and not D.CheckScrutinyType(data.nScrutinyType, dwCaster) then -- 监控对象检查
			return
		end
		if data.tKungFu and not D.CheckKungFu(data.tKungFu) then -- 自身身法需求检查
			return
		end
		local szName, nIcon = JH.GetSkillName(dwCastID, dwLevel)
		local KObject = IsPlayer(dwCaster) and GetPlayer(dwCaster) or GetNpc(dwCaster)
		if not KObject then
			return -- D.Log("ERROR CASTING object:" .. dwCaster .. " does not exist!")
		end
		-- szName = data.szName or szName
		nIcon  = data.nIcon or nIcon
		local szSrcName = JH.GetTemplateName(KObject)
		local dwTargetType, dwTargetID = KObject.GetTarget()
		local szTargetName
		if dwTargetID > 0 then
			szTargetName = JH.GetTemplateName(IsPlayer(dwTargetID) and GetPlayer(dwTargetID) or GetNpc(dwTargetID))
		end
		local cfg, nClass
		if szEvent == "UI_OME_SKILL_CAST_LOG" then
			cfg, nClass = data[DBM_TYPE.SKILL_BEGIN], DBM_TYPE.SKILL_BEGIN
		else
			cfg, nClass = data[DBM_TYPE.SKILL_END], DBM_TYPE.SKILL_END
		end
		D.CountdownEvent(data, nClass)
		if cfg then
			local xml = {}
			tinsert(xml, DBM_LEFT_LINE)
			tinsert(xml, GetFormatText(szSrcName, 44, 255, 255, 0))
			tinsert(xml, DBM_RIGHT_LINE)
			if nClass == DBM_TYPE.SKILL_END then
				tinsert(xml, GetFormatText(_L["use of"], 44, 255, 255, 255))
			else
				tinsert(xml, GetFormatText(_L["Building"], 44, 255, 255, 255))
			end
			tinsert(xml, DBM_LEFT_LINE)
			tinsert(xml, GetFormatText(szName, 44, 255, 255, 0))
			tinsert(xml, DBM_RIGHT_LINE)
			if data.bMonTarget and szTargetName then
				tinsert(xml, GetFormatText(g_tStrings.TARGET, 44, 255, 255, 255))
				tinsert(xml, DBM_LEFT_LINE)
				tinsert(xml, GetFormatText(szTargetName == DBM_CORE_NAME and g_tStrings.STR_YOU or szTargetName, 44, 255, 255, 0))
				tinsert(xml, DBM_RIGHT_LINE)
			end
			-- if data.szNote then
			-- 	tinsert(xml, " " .. GetFormatText(data.szNote, 44, 255, 255, 255))
			-- end
			local txt = GetPureText(tconcat(xml))
			if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
				FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
			end
			-- 特大文字
			if DBM.bPushBigFontAlarm and cfg.bBigFontAlarm then
				FireUIEvent("JH_LARGETEXT", txt, data.col or { GetHeadTextForceFontColor(dwCaster, DBM_CORE_PLAYERID) })
			end
			if JH.bDebugClient and cfg.bSelect then
				SetTarget(IsPlayer(dwCaster) and TARGET.PLAYER or TARGET.NPC, dwCaster)
			end
			if cfg.tMark then
				D.SetTeamMark("CASTING", cfg.tMark, dwCaster, dwSkillID, dwLevel)
			end
			-- 头顶报警
			if DBM.bPushScreenHead and cfg.bScreenHead then
				FireUIEvent("JH_SA_CREATE", "CASTING", dwCaster, { txt = szName, col = data.col })
			end
			-- 全屏泛光
			if DBM.bPushFullScreen and cfg.bFullScreen then
				FireUIEvent("JH_FS_CREATE", data.dwID .. "#SKILL#"  .. data.nLevel, { nTime = 3, col = data.col})
			end
			if DBM.bPushTeamChannel and cfg.bTeamChannel then
				if szTargetName then
					local talk = txt:gsub(_L["["] .. g_tStrings.STR_YOU .. _L["]"], _L["["] .. szTargetName .. _L["]"])
					D.Talk(talk)
				else
					D.Talk(txt)
				end
			end
			if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
				D.Talk(txt, true)
			end
		end
	end
end

-- NPC事件
function D.OnNpcEvent(npc, bEnter)
	local data = D.GetData("NPC", npc.dwTemplateID)
	local nTime = GetTime()
	if bEnter then
		CACHE.NPC_LIST[npc.dwTemplateID] = CACHE.NPC_LIST[npc.dwTemplateID] or {
			bFightState = false,
			tList       = {},
			nTime       = -1,
			nLife       = floor(npc.nCurrentLife / npc.nMaxLife * 100),
			nMana       = floor(npc.nCurrentMana / npc.nMaxMana * 100)
		}
		tinsert(CACHE.NPC_LIST[npc.dwTemplateID].tList, npc.dwID)
		local tWeak, tTemp = CACHE.TEMP.NPC, D.TEMP.NPC
		if not tWeak[npc.dwTemplateID] then
			local t = {
				dwMapID      = JH.GetMapID(),
				dwID         = npc.dwTemplateID,
				nFrame       = select(2, GetNpcHeadImage(npc.dwID)),
				col          = { GetHeadTextForceFontColor(npc.dwID, DBM_CORE_PLAYERID) },
				nCurrentTime = GetCurrentTime()
			}
			tWeak[npc.dwTemplateID] = t
			tTemp[#tTemp + 1] = tWeak[npc.dwTemplateID]
			FireUIEvent("DBMUI_TEMP_UPDATE", "NPC", t)
		end
		CACHE.INTERVAL.NPC[npc.dwTemplateID] = CACHE.INTERVAL.NPC[npc.dwTemplateID] or {}
		if #CACHE.INTERVAL.NPC[npc.dwTemplateID] > 0 then
			if nTime - CACHE.INTERVAL.NPC[npc.dwTemplateID][#CACHE.INTERVAL.NPC[npc.dwTemplateID]] > 500 then
				CACHE.INTERVAL.NPC[npc.dwTemplateID][#CACHE.INTERVAL.NPC[npc.dwTemplateID] + 1] = nTime
			end
		else
			CACHE.INTERVAL.NPC[npc.dwTemplateID][#CACHE.INTERVAL.NPC[npc.dwTemplateID] + 1] = nTime
		end
	else
		if CACHE.NPC_LIST[npc.dwTemplateID] and CACHE.NPC_LIST[npc.dwTemplateID].tList then
			local tab = CACHE.NPC_LIST[npc.dwTemplateID]
			for k, v in ipairs(tab.tList) do
				if v == npc.dwID then
					table.remove(tab.tList, k)
					if #tab.tList == 0 then
						local nTime = GetTime() - (tab.nSec or GetTime())
						if tab.bFightState then
							FireUIEvent("DBM_NPC_FIGHT", npc.dwTemplateID, false, nTime)
						end
						CACHE.NPC_LIST[npc.dwTemplateID] = nil
						FireUIEvent("DBM_NPC_ALLLEAVE_SCENE", npc.dwTemplateID)
					end
					break
				end
			end
		end
	end
	if data then
		local cfg, nClass, nCount
		if data.tKungFu and not D.CheckKungFu(data.tKungFu) then -- 自身身法需求检查
			return
		end
		if bEnter then
			cfg, nClass = data[DBM_TYPE.NPC_ENTER], DBM_TYPE.NPC_ENTER
			nCount = #CACHE.NPC_LIST[npc.dwTemplateID].tList
		else
			cfg, nClass = data[DBM_TYPE.NPC_LEAVE], DBM_TYPE.NPC_LEAVE
		end
		if nClass == DBM_TYPE.NPC_LEAVE then
			if data.bAllLeave and CACHE.NPC_LIST[npc.dwTemplateID] then
				return
			end
		else
			-- 场地上的NPC数量没达到预期数量
			if data.nCount and nCount < data.nCount then
				return
			end
			if cfg then
				if cfg.tMark then
					D.SetTeamMark("NPC", cfg.tMark, npc.dwID, npc.dwTemplateID)
				end
				if DBM.bPushScreenHead and cfg.bScreenHead then
					FireUIEvent("JH_SA_CREATE", "NPC", npc.dwID, { txt = data.szNote, col = data.col, szName = data.szName })
				end
			end
			if nTime - CACHE.NPC_LIST[npc.dwTemplateID].nTime < 500 then -- 0.5秒内进入相同的NPC直接忽略
				return -- D.Log("IGNORE NPC ENTER SCENE ID:" .. npc.dwTemplateID .. " TIME:" .. nTime .. " TIME2:" .. CACHE.NPC_LIST[npc.dwTemplateID].nTime)
			else
				CACHE.NPC_LIST[npc.dwTemplateID].nTime = nTime
			end
		end
		D.CountdownEvent(data, nClass)
		if cfg then
			local szName = JH.GetTemplateName(npc)
			local xml = {}
			tinsert(xml, DBM_LEFT_LINE)
			tinsert(xml, GetFormatText(szName, 44, 255, 255, 0))
			tinsert(xml, DBM_RIGHT_LINE)
			if nClass == DBM_TYPE.NPC_ENTER then
				tinsert(xml, GetFormatText(_L["Appear"], 44, 255, 255, 255))
				if nCount > 1 then
					tinsert(xml, GetFormatText(" x" .. nCount, 44, 255, 255, 0))
				end
				-- if data.szNote then
				-- 	tinsert(xml, GetFormatText(" " .. data.szNote, 44, 255, 255, 255))
				-- end
			else
				tinsert(xml, GetFormatText(_L["leave"], 44, 255, 255, 255))
			end

			local txt = GetPureText(tconcat(xml))
			if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
				FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
			end
			-- 特大文字
			if DBM.bPushBigFontAlarm and cfg.bBigFontAlarm then
				FireUIEvent("JH_LARGETEXT", txt, data.col or { GetHeadTextForceFontColor(npc.dwID, DBM_CORE_PLAYERID) })
			end

			if DBM.bPushTeamChannel and cfg.bTeamChannel then
				D.Talk(txt)
			end
			if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
				D.Talk(txt, true)
			end

			if nClass == DBM_TYPE.NPC_ENTER then
				if JH.bDebugClient and cfg.bSelect then
					SetTarget(TARGET.NPC, npc.dwID)
				end
				if DBM.bPushFullScreen and cfg.bFullScreen then
					FireUIEvent("JH_FS_CREATE", "NPC", { nTime  = 3, col = data.col, bFlash = true })
				end
			end
		end
	end
end

-- DOODAD事件
function D.OnDoodadEvent(doodad, bEnter)
	local data = D.GetData("DOODAD", doodad.dwTemplateID)
	local nTime = GetTime()
	if bEnter then
		CACHE.DOODAD_LIST[doodad.dwTemplateID] = CACHE.DOODAD_LIST[doodad.dwTemplateID] or {
			tList       = {},
			nTime       = -1,
		}
		tinsert(CACHE.DOODAD_LIST[doodad.dwTemplateID].tList, doodad.dwID)
		if doodad.nKind ~= DOODAD_KIND.ORNAMENT or JH.bDebugClient then
			local tWeak, tTemp = CACHE.TEMP.DOODAD, D.TEMP.DOODAD
			if not tWeak[doodad.dwTemplateID] then
				local t = {
					dwMapID      = JH.GetMapID(),
					dwID         = doodad.dwTemplateID,
					nCurrentTime = GetCurrentTime()
				}
				tWeak[doodad.dwTemplateID] = t
				tTemp[#tTemp + 1] = tWeak[doodad.dwTemplateID]
				FireUIEvent("DBMUI_TEMP_UPDATE", "DOODAD", t)
			end
		end
		CACHE.INTERVAL.DOODAD[doodad.dwTemplateID] = CACHE.INTERVAL.DOODAD[doodad.dwTemplateID] or {}
		if #CACHE.INTERVAL.DOODAD[doodad.dwTemplateID] > 0 then
			if nTime - CACHE.INTERVAL.DOODAD[doodad.dwTemplateID][#CACHE.INTERVAL.DOODAD[doodad.dwTemplateID]] > 500 then
				CACHE.INTERVAL.DOODAD[doodad.dwTemplateID][#CACHE.INTERVAL.DOODAD[doodad.dwTemplateID] + 1] = nTime
			end
		else
			CACHE.INTERVAL.DOODAD[doodad.dwTemplateID][#CACHE.INTERVAL.DOODAD[doodad.dwTemplateID] + 1] = nTime
		end
	else
		if CACHE.DOODAD_LIST[doodad.dwTemplateID] and CACHE.DOODAD_LIST[doodad.dwTemplateID].tList then
			local tab = CACHE.DOODAD_LIST[doodad.dwTemplateID]
			for k, v in ipairs(tab.tList) do
				if v == doodad.dwID then
					table.remove(tab.tList, k)
					if #tab.tList == 0 then
						CACHE.DOODAD_LIST[doodad.dwTemplateID] = nil
						FireUIEvent("DBM_DOODAD_ALLLEAVE_SCENE", doodad.dwTemplateID)
					end
					break
				end
			end
		end
	end
	if data then
		local cfg, nClass, nCount
		if data.tKungFu and not D.CheckKungFu(data.tKungFu) then -- 自身身法需求检查
			return
		end
		if bEnter then
			cfg, nClass = data[DBM_TYPE.DOODAD_ENTER], DBM_TYPE.DOODAD_ENTER
			nCount = #CACHE.DOODAD_LIST[doodad.dwTemplateID].tList
		else
			cfg, nClass = data[DBM_TYPE.DOODAD_LEAVE], DBM_TYPE.DOODAD_LEAVE
		end
		if nClass == DBM_TYPE.DOODAD_LEAVE then
			if data.bAllLeave and CACHE.DOODAD_LIST[doodad.dwTemplateID] then
				return
			end
		else
			-- 场地上的DOODAD数量没达到预期数量
			if data.nCount and nCount < data.nCount then
				return
			end
			if cfg then
				if DBM.bPushScreenHead and cfg.bScreenHead then
					FireUIEvent("JH_SA_CREATE", "DOODAD", doodad.dwID, { txt = data.szNote, col = data.col, szName = data.szName })
				end
			end
			if nTime - CACHE.DOODAD_LIST[doodad.dwTemplateID].nTime < 500 then
				return
			else
				CACHE.DOODAD_LIST[doodad.dwTemplateID].nTime = nTime
			end
		end
		D.CountdownEvent(data, nClass)
		if cfg then
			local szName = doodad.szName
			local xml = {}
			tinsert(xml, DBM_LEFT_LINE)
			tinsert(xml, GetFormatText(szName, 44, 255, 255, 0))
			tinsert(xml, DBM_RIGHT_LINE)
			if nClass == DBM_TYPE.DOODAD_ENTER then
				tinsert(xml, GetFormatText(_L["Appear"], 44, 255, 255, 255))
				if nCount > 1 then
					tinsert(xml, GetFormatText(" x" .. nCount, 44, 255, 255, 0))
				end
				-- if data.szNote then
				-- 	tinsert(xml, GetFormatText(" " .. data.szNote, 44, 255, 255, 255))
				-- end
			else
				tinsert(xml, GetFormatText(_L["leave"], 44, 255, 255, 255))
			end

			local txt = GetPureText(tconcat(xml))
			if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
				FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
			end
			-- 特大文字
			if DBM.bPushBigFontAlarm and cfg.bBigFontAlarm then
				FireUIEvent("JH_LARGETEXT", txt, data.col or { 255, 255, 0 })
			end

			if DBM.bPushTeamChannel and cfg.bTeamChannel then
				D.Talk(txt)
			end
			if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
				D.Talk(txt, true)
			end

			if nClass == DBM_TYPE.DOODAD_ENTER then
				if DBM.bPushFullScreen and cfg.bFullScreen then
					FireUIEvent("JH_FS_CREATE", "DOODAD", { nTime  = 3, col = data.col, bFlash = true })
				end
			end
		end
	end
end

function D.OnDoodadAllLeave(dwTemplateID)
	local data = D.GetData("DOODAD", dwTemplateID)
	if data then
		D.CountdownEvent(data, DBM_TYPE.DOODAD_ALLLEAVE)
	end
end
-- 系统和NPC喊话处理
-- OutputMessage("MSG_SYS", 1.."\n")
function D.OnCallMessage(szEvent, szContent, dwNpcID, szNpcName)
	-- 近期记录
	szContent = tostring(szContent)
	local me = GetClientPlayer()
	local key = (szNpcName or "sys") .. "::" .. szContent
	local tWeak, tTemp = CACHE.TEMP[szEvent], D.TEMP[szEvent]
	if not tWeak[key] then
		local t = {
			dwMapID      = me.GetMapID(),
			szContent    = szContent,
			szTarget     = szNpcName,
			nCurrentTime = GetCurrentTime()
		}
		tWeak[key] = t
		tTemp[#tTemp + 1] = tWeak[key]
		FireUIEvent("DBMUI_TEMP_UPDATE", szEvent, t)
	end
	local tInfo, data
	local cache = CACHE.MAP[szEvent]
	if cache.HIT[szContent] then
		if cache.HIT[szContent][szNpcName or "sys"] then
			data = cache.HIT[szContent][szNpcName or "sys"]
		elseif cache.HIT[szContent]["%"] then
			data = cache.HIT[szContent]["%"]
		end
	end
	-- 不适用wstring 性能考虑为前提
	if not data then
		local bInParty = me.IsInParty()
		local team     = GetClientTeam()
		for k, v in JH.bpairs(cache.OTHER) do
			local content = v.szContent
			if v.szContent:find("$me") then
				content = v.szContent:gsub("$me", me.szName) -- 转换me是自己名字
			end
			if bInParty and content:find("$team") then
				local c = content
				for kk, vv in ipairs(team.GetTeamMemberList()) do
					if string.find(szContent, c:gsub("$team", team.GetClientTeamMemberName(vv)), nil, true) and (v.szTarget == szNpcName or v.szTarget == "%") then -- hit
						tInfo = { dwID = vv, szName = team.GetClientTeamMemberName(vv) }
						data = v
						break
					end
				end
			else
				if v.szTarget == szNpcName or v.szTarget == "%" then
					if (v.bReg and string.find(szContent, content)) or
						(not v.bReg and string.find(szContent, content, nil, true))
					then
						data = v
						break
					end
				end
			end
		end
	end
	if data then
		local nClass = szEvent == "TALK" and DBM_TYPE.TALK_MONITOR or DBM_TYPE.CHAT_MONITOR
		D.CountdownEvent(data, nClass)
		local cfg = data[nClass]
		if cfg then
			if data.szContent:find("$me") then
				tInfo = { dwID = me.dwID, szName = me.szName }
			end
			local xml, txt = {}, data.szNote or szContent
			if tInfo and not data.szNote then
				tinsert(xml, DBM_LEFT_LINE)
				tinsert(xml, GetFormatText(szNpcName or _L["JX3"], 44, 255, 255, 0))
				tinsert(xml, DBM_RIGHT_LINE)
				tinsert(xml, GetFormatText(_L["is calling"], 44, 255, 255, 255))
				tinsert(xml, DBM_LEFT_LINE)
				tinsert(xml, GetFormatText(tInfo.szName == me.szName and g_tStrings.STR_YOU or tInfo.szName, 44, 255, 255, 0))
				tinsert(xml, DBM_RIGHT_LINE)
				tinsert(xml, GetFormatText(_L["'s name."], 44, 255, 255, 255))
				txt = GetPureText(tconcat(xml))
			end
			txt = txt:gsub("$me", me.szName)
			if tInfo then
				txt = txt:gsub("$team", tInfo.szName)
				if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
					D.Talk(txt, tInfo.szName)
				end
				if DBM.bPushScreenHead and cfg.bScreenHead then
					FireUIEvent("JH_SA_CREATE", "TIME", tInfo.dwID, { txt = _L("%s Call Name", szNpcName or g_tStrings.SYSTEM)})
				end
				if JH.bDebugClient and cfg.bSelect then
					SetTarget(TARGET.PLAYER, tInfo.dwID)
				end
			else
				if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
					D.Talk(txt, true)
				end
				if DBM.bPushScreenHead and cfg.bScreenHead then
					FireUIEvent("JH_SA_CREATE", "TIME", dwNpcID or me.dwID, { txt = txt })
				end
			end
			-- 中央报警
			if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
				FireUIEvent("JH_CA_CREATE", #xml > 0 and tconcat(xml) or txt, 3, #xml > 0)
			end
			-- 特大文字
			if DBM.bPushBigFontAlarm and cfg.bBigFontAlarm then
				FireUIEvent("JH_LARGETEXT", txt, data.col or { 255, 128, 0 })
			end
			if DBM.bPushFullScreen and cfg.bFullScreen then
				if (tInfo and tInfo.dwID == me.dwID) or not tInfo then
					FireUIEvent("JH_FS_CREATE", szEvent, { nTime  = 3, col = data.col or { 0, 255, 0 }, bFlash = true })
				end
			end
			if DBM.bPushTeamChannel and cfg.bTeamChannel then
				if tInfo and not data.szNote then
					local talk = txt:gsub(_L["["] .. g_tStrings.STR_YOU .. _L["]"], _L["["] .. tInfo.szName .. _L["]"])
					D.Talk(talk)
				else
					D.Talk(txt)
				end
			end
		end
	end
end

-- NPC死亡事件 触发倒计时
function D.OnDeath(dwCharacterID, dwKiller)
	local npc = GetNpc(dwCharacterID)
	if npc then
		local data = D.GetData("NPC", npc.dwTemplateID)
		if data then
			local dwTemplateID = npc.dwTemplateID
			D.CountdownEvent(data, DBM_TYPE.NPC_DEATH)
			local bAllDeath = true
			if CACHE.NPC_LIST[dwTemplateID] then
				for k, v in ipairs(CACHE.NPC_LIST[dwTemplateID].tList) do
					local npc = GetNpc(v)
					if npc and npc.nMoveState ~= MOVE_STATE.ON_DEATH then
						bAllDeath = false
						break
					end
				end
			end
			if bAllDeath then
				D.CountdownEvent(data, DBM_TYPE.NPC_ALLDEATH)
			end
		end
	end
end

-- NPC进出战斗事件 触发倒计时
function D.OnNpcFight(dwTemplateID, bFight)
	local data = D.GetData("NPC", dwTemplateID)
	if data then
		if bFight then
			D.CountdownEvent(data, DBM_TYPE.NPC_FIGHT)
		elseif data.tCountdown then -- 脱离的时候清空下
			for k, v in ipairs(data.tCountdown) do
				if v.nClass == DBM_TYPE.NPC_FIGHT and not v.bFightHold then
					local class = v.key and DBM_TYPE.COMMON or v.nClass
					FireUIEvent("JH_ST_DEL", class, v.key or (k .. "."  .. data.dwID .. "." .. (data.nLevel or 0)), true) -- try kill
				end
			end
		end
	end
end

function D.GetStringStru(szString)
	if CACHE.STR[szString] then
		return CACHE.STR[szString]
	else
		local data = {}
		for k, v in ipairs(JH_Split(szString, ";")) do
			local line = JH_Split(v, ",")
			if line[1] and line[2] and tonumber(JH_Trim(line[1])) and JH_Trim(line[2]) ~= "" then
				line[1] = tonumber(JH_Trim(line[1]))
				line[2] = JH_Trim(line[2])
				tinsert(data, line)
			end
		end
		CACHE.STR[szString] = data
		return data
	end
end
-- 不该放在倒计时中 需要重构
function D.OnNpcInfoChange(szEvent, dwTemplateID, nPer)
	local data = D.GetData("NPC", dwTemplateID)
	if data and data.tCountdown then
		local dwType = szEvent == "DBM_NPC_LIFE_CHANGE" and DBM_TYPE.NPC_LIFE or DBM_TYPE.NPC_MANA
		for k, v in ipairs(data.tCountdown) do
			if v.nClass == dwType then
				local tLife = D.GetStringStru(v.nTime)
				for kk, vv in ipairs(tLife) do
					local nVper = vv[1] * 100
					if nVper == nPer then -- hit
						local szName = v.szName or JH.GetTemplateName(dwTemplateID)
						local xml = {}
						tinsert(xml, DBM_LEFT_LINE)
						tinsert(xml, GetFormatText(szName, 44, 255, 255, 0))
						tinsert(xml, DBM_RIGHT_LINE)
						tinsert(xml, GetFormatText(dwType == DBM_TYPE.NPC_LIFE and _L["life has left"] or _L["mana has reached"], 44, 255, 255, 255))
						tinsert(xml, GetFormatText(" " .. nVper .. "%", 44, 255, 255, 0))
						tinsert(xml, GetFormatText(" " .. vv[2], 44, 255, 255, 255))
						local txt = GetPureText(tconcat(xml))
						if DBM.bPushCenterAlarm then
							FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
						end
						if DBM.bPushBigFontAlarm then
							FireUIEvent("JH_LARGETEXT", txt, data.col or { 255, 128, 0 })
						end
						if DBM.bPushTeamChannel and v.bTeamChannel then
							D.Talk(txt)
						end
						if vv[3] and tonumber(JH_Trim(vv[3])) then
							local szKey = k .. "." .. dwTemplateID .. "." .. kk
							local tParam = {
								key    = v.key,
								nFrame = v.nFrame,
								nTime  = tonumber(JH_Trim(vv[3])),
								szName = vv[2],
								nIcon  = v.nIcon,
								bTalk  = v.bTeamChannel,
								bHold  = v.bHold
							}
							D.FireCountdownEvent(v.nClass, szKey, tParam)
						end
						break
					end
				end
			end
		end
	end
end
-- NPC 全部消失的倒计时处理
function D.OnNpcAllLeave(dwTemplateID)
	local data = D.GetData("NPC", dwTemplateID)
	if data then
		D.CountdownEvent(data, DBM_TYPE.NPC_ALLLEAVE)
	end
end

-- RegisterMsgMonitor
function D.RegisterMessage(bEnable)
	if bEnable then
		JH.RegisterMsgMonitor("DBM_MON", function(szMsg, nFont, bRich)
			if not GetClientPlayer() then
				return
			end
			if bRich then
				szMsg = GetPureText(szMsg)
			end
			-- local res, err = pcall(D.OnCallMessage, "CHAT", szMsg:gsub("\r", ""))
			-- if not res then
			-- 	return JH.Sysmsg2(err)
			-- end
			D.OnCallMessage("CHAT", szMsg:gsub("\r", ""))
		end, { "MSG_SYS" })
	else
		JH.RegisterMsgMonitor("DBM_MON")
	end
end

-- UI操作
function D.GetFrame()
	return Station.Lookup("Normal/DBM")
end

function D.Open()
	local frame = D.GetFrame()
	if frame then
		for k, v in ipairs(DBM_EVENTS) do
			frame:UnRegisterEvent(v)
			frame:RegisterEvent(v)
		end
		D.RegisterMessage(true)
	end
end
-- DBM.OnCallMessage = D.OnCallMessage
-- DBM.OnCallMessage("CHAT", "1")
function D.Close()
	local frame = D.GetFrame()
	if frame then
		for k, v in ipairs(DBM_EVENTS) do
			frame:UnRegisterEvent(v)  -- kill all event
		end
		D.RegisterMessage(false)
		FireUIEvent("JH_ST_CLEAR")
		CACHE.NPC_LIST = {}
		CACHE.SKILL_LIST = {}
		collectgarbage("collect")
	end
end

function D.Enable(bEnable, bFireUIEvent)
	if bEnable then
		local res, err = pcall(D.Open)
		if not res then
			return JH.Sysmsg2(err)
		end
		if bFireUIEvent then
			FireUIEvent("DBM_LOADING_END")
			for k, v in pairs(JH.GetAllNpcID()) do
				FireUIEvent("DBM_NPC_ENTER_SCENE", k)
			end
		end
	else
		D.Close()
	end
end

function D.Init()
	D.LoadUserData()
	Wnd.OpenWindow(DBM_INIFILE, "DBM")
end

function D.SaveData()
	JH.SaveLUAData(GetDataPath(), D.FILE, nil, false)
end

function D.GetDungeon()
	if IsEmpty(CACHE.DUNGEON) then
		local tCache = {}
		for k, v in JH.bpairs(GetMapList()) do
			if not JH_MAP_NAME_FIX[v] then
				local a = g_tTable.DungeonInfo:Search(v) or {}
				if a.dwClassID or not JH.IsDungeon(v) and JH.IsDungeon(v, true) then
					a.dwClassID = a.dwClassID or 1
					local szLayer3Name = a.dwClassID == 3 and a.szLayer3Name or g_tStrings.STR_FT_DUNGEON
					if not tCache[szLayer3Name] then
						local i = #CACHE.DUNGEON + 1
						CACHE.DUNGEON[i] = { szLayer3Name = szLayer3Name, aList = {} }
						tCache[szLayer3Name] = CACHE.DUNGEON[i]
					end
					tinsert(tCache[szLayer3Name].aList, v)
				end
			end
		end
		table.sort(CACHE.DUNGEON, function(a, b) return a.szLayer3Name > b.szLayer3Name end)
	end
	return CACHE.DUNGEON
end

-- 获取整个表
function D.GetTable(szType, bTemp)
	if bTemp then
		if szType == "CIRCLE" then -- 如果请求圈圈的近期数据 返回NPC的
			szType = "NPC"
		end
		return D.TEMP[szType]
	else
		if szType == "CIRCLE" then -- 如果请求圈圈
			return Circle.GetData()
		else
			return D.FILE[szType]
		end
	end
end

local function GetData(tab, szType, dwID, nLevel)
	-- D.Log("LOOKUP TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
	if nLevel then
		for k, v in ipairs(tab) do
			if v.dwID == dwID and (not v.bCheckLevel or v.nLevel == nLevel) then
				CACHE.MAP[szType][dwID][nLevel] = k
				return v
			end
		end
	else
		for k, v in ipairs(tab) do
			if v.dwID == dwID then
				CACHE.MAP[szType][dwID] = k
				return v
			end
		end
	end
end

-- 获取监控数据 注意 不是获取文件内的 如果想找文件内的 请使用 GetTable
function D.GetData(szType, dwID, nLevel)
	local cache = CACHE.MAP[szType][dwID]
	if cache then
		local tab = D.DATA[szType]
		if nLevel then
			if cache[nLevel] then
				local data = tab[cache[nLevel]]
				if data and data.dwID == dwID and (not data.bCheckLevel or data.nLevel == nLevel) then
					-- D.Log("HIT TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
					return data
				else
					-- D.Log("RELOOKUP TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
					return GetData(tab, szType, dwID, nLevel)
				end
			else
				for k, v in pairs(cache) do
					local data = tab[cache[k]]
					if data and data.dwID == dwID and (not data.bCheckLevel or data.nLevel == nLevel) then
						return data
					end
				end
				return GetData(tab, szType, dwID, nLevel)
			end
		else
			local data = tab[cache]
			if data and data.dwID == dwID then
				-- D.Log("HIT TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:0")
				return data
			else
				-- D.Log("RELOOKUP TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:0")
				return GetData(tab, szType, dwID)
			end
		end
	-- else
		-- D.Log("IGNORE TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. (nLevel or 0))
	end
end

function D.LoadUserData()
	local data = JH.LoadLUAData(GetDataPath())
	if data then
		for k, v in pairs(D.FILE) do
			D.FILE[k] = data[k] or {}
		end
	else
		local szLang = select(3, GetVersion())
		local config = {
			nMode = 1,
			tList = {},
			szFileName = szLang ..  "_default.jx3dat",
		}
		-- default data
		for _, v in ipairs(DBM_TYPE_LIST) do
			config.tList[v] = true
		end
		D.LoadConfigureFile(config)
	end
	D.Log("load custom data success!")
end

function D.LoadConfigureFile(config)
	local path = JH.GetAddonInfo().szRootPath .. "JH_DBM\\data\\" .. config.szFileName
	local szFullPath = config.bFullPath and config.szFileName or path
	local szFilePath = path
	if config.bFullPath then
		local s, exp = szFullPath:lower():gsub(".*interface", "")
		if exp > 0 then
			szFilePath = "interface" .. s
		end
	end
	if not IsFileExist(szFilePath) then
		return false, "the file does not exist"
	end
	local data = LoadLUAData(szFilePath)
	if not data then
		return false, "can not read data file."
	else
		if config.nMode == 1 then
			if config.tList["CIRCLE"] then
				if type(Circle) ~= "nil" then
					local dat = { Circle = data["CIRCLE"] }
					Circle.LoadCircleData(dat)
				end
				config.tList["CIRCLE"] = nil
			end
			for k, v in pairs(config.tList) do
				D.FILE[k] = data[k] or {}
			end
		elseif config.nMode == 2 or config.nMode == 3 then
			if config.tList["CIRCLE"] then
				if type(Circle) ~= "nil" then
					local dat = { Circle = data["CIRCLE"] }
					Circle.LoadCircleMergeData(dat, config.nMode == 3 and true or false)
				end
				config.tList["CIRCLE"] = nil
			end
			local fnMergeData = function(tab_data)
				for szType, _ in pairs(config.tList) do
					if tab_data[szType] then
						for k, v in pairs(tab_data[szType]) do
							for kk, vv in ipairs(v) do
								if not D.CheckSameData(szType, k, vv.dwID or vv.szContent, vv.nLevel or vv.szTarget) then
									D.FILE[szType][k] = D.FILE[szType][k] or {}
									table.insert(D.FILE[szType][k], vv)
								end
							end
						end
					end
				end
			end
			if config.nMode == 2 then -- 源文件优先
				fnMergeData(data)
			elseif config.nMode == 3 then -- 新文件优先
				-- 其实就是交换下顺序
				local tab_data = clone(D.FILE)
				for k, v in pairs(config.tList) do
					D.FILE[k] = data[k] or {}
				end
				fnMergeData(tab_data)
			end
		end
		FireUIEvent("DBM_CREATE_CACHE")
		FireUIEvent("DBMUI_DATA_RELOAD")
		return true, szFullPath:gsub("\\", "/")
	end
end

function D.SaveConfigureFile(config)
	local data = {}
	for k, v in pairs(config.tList) do
		data[k] = D.FILE[k]
	end
	if config.tList["CIRCLE"] then
		if type(Circle) ~= "nil" then
			data["CIRCLE"] = Circle.GetData()
		end
	end
	-- HM.20170504: add meta data
	data["__meta"] = {
		szLang = select(3, GetVersion()),
		szAuthor = GetUserRoleName(),
		szServer = select(4, GetUserServer()),
		nTimeStamp = GetCurrentTime()
	}
	local root, path = GetRootPath(), "/" .. JH.GetAddonInfo().szRootPath .. "JH_DBM/data/" .. config.szFileName
	root = root:gsub("\\", "/")
	if config.bJson then
		path = path .. ".json"
		Log(path, JH.JsonEncode(data, config.bFormat), "close")
		-- SaveLUAData(path, JH.JsonEncode(data, config.bFormat), nil, false)
	else
		SaveLUAData(path, data, config.bFormat and "\t", false)
	end
	return root .. path
end

-- 删除 移动 添加 清空
function D.RemoveData(szType, dwMapID, nIndex)
	if nIndex then
		if D.FILE[szType][dwMapID] and D.FILE[szType][dwMapID][nIndex] then
			if dwMapID == -9 then
				table.remove(D.FILE[szType][dwMapID], nIndex)
				if #D.FILE[szType][dwMapID] == 0 then
					D.FILE[szType][dwMapID] = nil
				end
				FireUIEvent("DBM_CREATE_CACHE")
				FireUIEvent("DBMUI_DATA_RELOAD")
			else
				D.MoveData(szType, dwMapID, nIndex, -9)
			end
		end
	else
		if D.FILE[szType][dwMapID] then
			D.FILE[szType][dwMapID] = nil
			FireUIEvent("DBM_CREATE_CACHE")
			FireUIEvent("DBMUI_DATA_RELOAD")
		end
	end
end

function D.CheckSameData(szType, dwMapID, dwID, nLevel)
	if D.FILE[szType][dwMapID] then
		if dwMapID ~= -9 then
			for k, v in ipairs(D.FILE[szType][dwMapID]) do
				if type(dwID) == "string" then
					if dwID == v.szContent and nLevel == v.szTarget then
						return k, v
					end
				else
					if dwID == v.dwID and (not v.bCheckLevel or nLevel == v.nLevel) then
						return k, v
					end
				end
			end
		end
	end
end

function D.MoveData(szType, dwMapID, nIndex, dwTargetMapID, bCopy)
	if dwMapID == dwTargetMapID then
		return
	end
	if D.FILE[szType][dwMapID] and D.FILE[szType][dwMapID][nIndex] then
		local data = D.FILE[szType][dwMapID][nIndex]
		if D.CheckSameData(szType, dwTargetMapID, data.dwID or data.szContent, data.nLevel or data.szTarget) then
			return JH.Alert(_L["same data Exist"])
		end
		D.FILE[szType][dwTargetMapID] = D.FILE[szType][dwTargetMapID] or {}
		tinsert(D.FILE[szType][dwTargetMapID], clone(D.FILE[szType][dwMapID][nIndex]))
		if not bCopy then
			table.remove(D.FILE[szType][dwMapID], nIndex)
			if #D.FILE[szType][dwMapID] == 0 then
				D.FILE[szType][dwMapID] = nil
			end
		end
		FireUIEvent("DBM_CREATE_CACHE")
		FireUIEvent("DBMUI_DATA_RELOAD")
	end
end
-- 交换 其实没用 满足强迫症
function D.Exchange(szType, dwMapID, nIndex1, nIndex2)
	if nIndex1 == nIndex2 then
		return
	end
	if D.FILE[szType][dwMapID] then
		local data1 = D.FILE[szType][dwMapID][nIndex1]
		local data2 = D.FILE[szType][dwMapID][nIndex2]
		if data1 and data2 then
			-- local data = table.remove(D.FILE[szType][dwMapID], nIndex1)
			-- table.insert(D.FILE[szType][dwMapID], nIndex2 + 1, data)
			D.FILE[szType][dwMapID][nIndex1] = data2
			D.FILE[szType][dwMapID][nIndex2] = data1
			FireUIEvent("DBM_CREATE_CACHE")
			FireUIEvent("DBMUI_DATA_RELOAD")
		end
	end
end

function D.AddData(szType, dwMapID, data)
	D.FILE[szType][dwMapID] = D.FILE[szType][dwMapID] or {}
	tinsert(D.FILE[szType][dwMapID], data)
	FireUIEvent("DBM_CREATE_CACHE")
	FireUIEvent("DBMUI_DATA_RELOAD")
	return D.FILE[szType][dwMapID][#D.FILE[szType][dwMapID]]
end

function D.ClearTemp(szType)
	if szType == "CIRCLE" then -- 如果请求圈圈的近期数据 返回NPC的
		szType = "NPC"
	end
	CACHE.INTERVAL[szType] = {}
	D.TEMP[szType] = {}
	FireUIEvent("DBMUI_TEMP_RELOAD")
	collectgarbage("collect")
	D.Log("clear " .. szType .. " cache success!")
end

function D.GetIntervalData(szType, key)
	if szType == "CIRCLE" then -- 如果请求圈圈的近期数据 返回NPC的
		szType = "NPC"
	end
	if CACHE.INTERVAL[szType] then
		return CACHE.INTERVAL[szType][key]
	end
end

function D.ConfirmShare()
	if #DBM_SHARE_QUEUE > 0 then
		local t = DBM_SHARE_QUEUE[1]
		JH.Confirm(_L("%s share a %s data to you, accept?", t.szName, _L[t.szType]), function()
			if t.szType ~= "CIRCLE" then
				local data = t.tData
				local nIndex = D.CheckSameData(t.szType, t.dwMapID, data.dwID or data.szContent, data.nLevel or data.szTarget)
				if nIndex then
					D.RemoveData(t.szType, t.dwMapID, nIndex)
				end
				D.AddData(t.szType, t.dwMapID, data)
			else
				local data = t.tData
				local nIndex = Circle.CheckSameData(t.dwMapID, data.key, data.dwType)
				if nIndex then
					Circle.RemoveData(t.dwMapID, nIndex)
				end
				Circle.AddData(t.dwMapID, data)
			end
			table.remove(DBM_SHARE_QUEUE, 1)
			JH.DelayCall(D.ConfirmShare, 100)
		end, function()
			table.remove(DBM_SHARE_QUEUE, 1)
			JH.DelayCall(D.ConfirmShare, 100)
		end)
	end
end

function D.OnShare(nChannel, dwID, szName, data, bIsSelf)
	if not bIsSelf then
		if (data[1] == "CIRCLE" and type(Circle) ~= "nil") or data[1] ~= "CIRCLE" then
			tinsert(DBM_SHARE_QUEUE, {
				szType  = data[1],
				tData   = data[3],
				szName  = szName,
				dwMapID = data[2]
			})
			D.ConfirmShare()
		end
	end
end
-- 公开接口
local ui = {
	Enable            = D.Enable,
	GetTable          = D.GetTable,
	GetDungeon        = D.GetDungeon,
	GetData           = D.GetData,
	GetIntervalData   = D.GetIntervalData,
	RemoveData        = D.RemoveData,
	MoveData          = D.MoveData,
	CheckSameData     = D.CheckSameData,
	ClearTemp         = D.ClearTemp,
	AddData           = D.AddData,
	SaveConfigureFile = D.SaveConfigureFile,
	LoadConfigureFile = D.LoadConfigureFile,
	Exchange          = D.Exchange,
}
DBM_API = setmetatable({}, { __index = ui, __newindex = function() end, __metatable = true })

JH.RegisterEvent("LOGIN_GAME", D.Init)
JH.RegisterExit(D.SaveData)
JH.RegisterBgMsg("DBM_SHARE", D.OnShare)
