-- @Author: Webster
-- @Date:   2015-05-13 16:06:53
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-10-18 01:50:52

local _L = JH.LoadLangPack
local ipairs, pairs, select = ipairs, pairs, select
local setmetatable, tonumber, type, tostring, unpack = setmetatable, tonumber, type, tostring, unpack
local tinsert, tconcat = table.insert, table.concat
local floor = math.floor
local GetTime, GetLogicFrameCount, GetCurrentTime, IsPlayer = GetTime, GetLogicFrameCount, GetCurrentTime, IsPlayer
local GetClientPlayer, GetClientTeam, GetPlayer, GetNpc = GetClientPlayer, GetClientTeam, GetPlayer, GetNpc
local FireUIEvent, Table_BuffIsVisible, Table_IsSkillShow = FireUIEvent, Table_BuffIsVisible, Table_IsSkillShow
local GetPureText, GetFormatText, GetHeadTextForceFontColor = GetPureText, GetFormatText, GetHeadTextForceFontColor
local JH_Split, JH_Trim = JH.Split, JH.Trim
local DBM_PLAYER_NAME = "NONE"
local DBM_TYPE, DBM_SCRUTINY_TYPE = DBM_TYPE, DBM_SCRUTINY_TYPE
local DBM_MAX_INTERVAL = 300
local DBM_MAX_CACHE = 2000 -- 最大的cache数量 主要是UI的问题
local DBM_DEL_CACHE = 1000 -- 每次清理的数量 然后会做一次gc
local DBM_INIFILE  = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM.ini"

local DBM_SHARE_QUEUE = {}
local DBM_MARK_QUEUE  = {}
local DBM_MARK_FIRST  = true -- 标记事件
----
local DBM_LEFT_LINE  = GetFormatText(_L["["], 44, 255, 255, 255)
local DBM_RIGHT_LINE = GetFormatText(_L["]"], 44, 255, 255, 255)
----
local DBM_TYPE_LIST = { "BUFF", "DEBUFF", "CASTING", "NPC", "TALK" }

local function GetDataPath()
	if DBM.bCommon then
		return "DBM/Common/DBM.jx3dat"
	else
		return "DBM/" .. DBM_PLAYER_NAME .. "/DBM.jx3dat"
	end
end

local CACHE = {
	TEMP       = {}, -- 近期事件记录MAP 这里用弱表 方便处理
	MAP        = {},
	NPC_LIST   = {},
	SKILL_LIST = {},
	INTERVAL   = {},
	DUNGEON    = {},
}

local D = {
	FILE = {}, -- 文件原始数据
	TEMP = {}, -- 近期事件记录
	DATA = {}  -- 需要监控的数据合集
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
	this:RegisterEvent("NPC_ENTER_SCENE")
	this:RegisterEvent("DBM_NPC_ENTER_SCENE")
	this:RegisterEvent("NPC_LEAVE_SCENE")
	this:RegisterEvent("BUFF_UPDATE")
	this:RegisterEvent("SYS_MSG")
	this:RegisterEvent("DO_SKILL_CAST")
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("PLAYER_SAY")
	this:RegisterEvent("ON_WARNING_MESSAGE")
	this:RegisterEvent("DBM_LOADING_END")
	this:RegisterEvent("DBM_CREATE_CACHE")
	this:RegisterEvent("DBM_NPC_FIGHT")
	this:RegisterEvent("DBM_NPC_ALLLEAVE_SCENE")
	this:RegisterEvent("DBM_NPC_LIFE_CHANGE")
	this:RegisterEvent("DBM_NPC_MANA_CHANGE")
	this:RegisterEvent("DBM_SET_MARK")
	this:RegisterEvent("PARTY_SET_MARK")
end

function DBM.OnFrameBreathe()
	D.CheckNpcState()
	-- timer
	-- 注意玩家机器受限 并不保证这个时间会一定被执行 用于不重要的内容
	local nFrameCount = GetLogicFrameCount()
	if nFrameCount % 160 == 0 then
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
	end
end

function DBM.OnEvent(szEvent)
	if szEvent == "BUFF_UPDATE" then
		D.OnBuff(arg0, arg1, arg3, arg4, arg5, arg8, arg9)
	elseif szEvent == "SYS_MSG" then
		if arg0 == "UI_OME_DEATH_NOTIFY" then
			if not IsPlayer(arg1) then
				D.OnDeath(arg1, arg3)
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
			DBM_MARK_FIRST = true
		end
	elseif szEvent == "PLAYER_SAY" then
		if not IsPlayer(arg1) then
			D.OnCallMessage(GetPureText(arg0), arg3, arg1)
		end
	elseif szEvent == "ON_WARNING_MESSAGE" then
		D.OnCallMessage(arg1)
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
	Log("[DBM] " .. szMsg)
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
	D.Log("Create " .. szType .. " data Succeed!")
end

local function CreateTalkData(dwMapID)
	-- 单独重建TALK数据
	local data = D.FILE.TALK
	local talk = D.DATA.TALK
	if data[dwMapID] then -- 本地图数据
		for k, v in JH.bpairs(data[dwMapID]) do
			talk[#talk + 1] = v
		end
	end
	-- 不要改顺序 通用放后面
	if data[-1] then -- 通用数据
		for k, v in JH.bpairs(data[-1]) do
			talk[#talk + 1] = v
		end
	end
	D.Log("Create TALK data Succeed!")
end

function D.CreateMeTaTable()
	-- 重建metatable 获取ALL数据的方法
	for kType, vTable in pairs(D.FILE)  do
		setmetatable(D.FILE[kType], { __index = function(me, index)
			if index == _L["All Data"] then
				local t = {}
				for k, v in pairs(vTable) do
					for kk, vv in ipairs(v) do
						t[#t +1] = vv
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
	D.Log("Create MeTaTable Succeed!")
end

function D.CreateData(szEvent)
	D.CreateMeTaTable()
	local szLang = select(3, GetVersion())
	local me = GetClientPlayer()
	local dwMapID = me.GetMapID()
	local nTime = GetTime()
	dwMapID = JH_MAP_NAME_FIX[dwMapID] or dwMapID -- 修正地图重名的问题
	-- 清空当前数据和MAP
	for k, v in pairs(D.DATA) do
		D.DATA[k] = {}
	end
	for k, v in pairs(CACHE.MAP) do
		CACHE.MAP[k] = {}
	end
	D.DATA.TALK = {}
	if JH.IsInArena() and szLang == "zhcn" and not JH.bDebugClient then
		JH.Sysmsg(_L["Arena not use the plug."])
		D.Log("MAPID: " .. dwMapID ..  " Create data Failed:" .. GetTime() - nTime  .. "ms")
		return
	end
	-- 重建MAP
	for _, szType in ipairs({ "BUFF", "DEBUFF", "CASTING", "NPC" }) do
		local data  = D.DATA[szType]
		local cache = CACHE.MAP[szType]
		if D.FILE[szType][-1] then -- 通用数据
			CreateCache(szType, D.FILE[szType][-1])
		end
		if D.FILE[szType][dwMapID] then -- 本地图数据
			CreateCache(szType, D.FILE[szType][dwMapID])
		end
	end
	CreateTalkData(dwMapID)

	-- 清空缓存
	if szEvent == "LOADING_END" or szEvent == "DBM_LOADING_END" then
		CACHE.NPC_LIST   = {}
		CACHE.SKILL_LIST = {}
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
	else
		pcall(Raid_MonitorBuffs) -- clear
	end
	-- gc
	if szEvent ~= "DBM_CREATE_CACHE" then
		D.Log("collectgarbage(\"count\") " .. collectgarbage("count"))
		collectgarbage("collect")
		D.Log("collectgarbage(\"collect\") " .. collectgarbage("count"))
	end
	D.Log("MAPID: " .. dwMapID ..  " Create data Succeed:" .. GetTime() - nTime  .. "ms")
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

function D.CheckScrutinyType(nScrutinyType, dwID, me)
	if nScrutinyType == DBM_SCRUTINY_TYPE.SELF and dwID ~= me.dwID then
		return false
	elseif nScrutinyType == DBM_SCRUTINY_TYPE.TEAM and (not JH.IsParty(dwID) and dwID ~= me.dwID) then
		return false
	elseif nScrutinyType == DBM_SCRUTINY_TYPE.ENEMY and not IsEnemy(me.dwID, dwID) then
		return false
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
	if DBM_MARK_FIRST then
		DBM_MARK_FIRST = false
		local f = table.remove(DBM_MARK_QUEUE, 1)
		pcall(f.fnAction)
	end
end
-- 倒计时处理 支持定义无限的倒计时
function D.CountdownEvent(data, nClass)
	if data.tCountdown then
		for k, v in ipairs(data.tCountdown) do
			if nClass == v.nClass then
				local szKey = k .. "." .. (data.dwID or 0) .. "." .. (data.nLevel or 0)
				local tParam = {
					key      = v.key,
					nFrame   = v.nFrame,
					nTime    = v.nTime,
					nRefresh = v.nRefresh,
					szName   = v.szName or data.szName,
					nIcon    = v.nIcon or data.nIcon,
					bTalk    = v.bTeamChannel
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
		return JH.GetObjName(KObject)
	else
		return dwID
	end
end

-- local a=GetTime();for i=1, 10000 do FireUIEvent("BUFF_UPDATE",96980,false,1,true,i,1,1,1,1,0) end;Output(GetTime()-a)
-- 事件操作
function D.OnBuff(dwCaster, bDelete, bCanCancel, dwBuffID, nCount, nBuffLevel, dwSkillSrcID)
	local me = GetClientPlayer()
	local szType = bCanCancel and "BUFF" or "DEBUFF"
	local key = dwBuffID .. "_" .. nBuffLevel
	local data = D.GetData(szType, dwBuffID, nBuffLevel)
	local nTime = GetTime()
	if not bDelete then
		-- 近期记录
		if Table_BuffIsVisible(dwBuffID, nBuffLevel) or JH.bDebugClient then
			local tWeak, tTemp = CACHE.TEMP[szType], D.TEMP[szType]
			if not tWeak[key] then
				local t = {
					dwMapID      = me.GetMapID(),
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
		if data.nScrutinyType and not D.CheckScrutinyType(data.nScrutinyType, dwCaster, me) then -- 监控对象检查
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
			szName = data.szName or szName
			nIcon  = data.nIcon or nIcon
			local szSrcName = JH.GetObjName(KObject)
			local xml = {}
			tinsert(xml, DBM_LEFT_LINE)
			tinsert(xml, GetFormatText(szSrcName == me.szName and g_tStrings.STR_YOU or szSrcName, 44, 255, 255, 0))
			tinsert(xml, DBM_RIGHT_LINE)
			if nClass == DBM_TYPE.BUFF_GET then
				tinsert(xml, GetFormatText(_L["Get Buff"], 44, 255, 255, 255))
				tinsert(xml, GetFormatText(szName .. " x" .. nCount, 44, 255, 255, 0))
				if data.szNote then
					tinsert(xml, GetFormatText(" " .. data.szNote, 44, 255, 255, 255))
				end
			else
				tinsert(xml, GetFormatText(_L["Lose Buff"], 44, 255, 255, 255))
				tinsert(xml, GetFormatText(szName, 44, 255, 255, 0))
			end
			local txt = GetPureText(tconcat(xml))
			if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
				FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
			end
			-- 特大文字
			if DBM.bPushBigFontAlarm and cfg.bBigFontAlarm then
				FireUIEvent("JH_LARGETEXT", txt, { GetHeadTextForceFontColor(dwCaster, me.dwID) }, me.dwID == dwCaster or not IsPlayer(dwCaster) )
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
				if DBM.bPushPartyBuffList and IsPlayer(dwCaster) and cfg.bPartyBuffList and (JH.IsParty(dwCaster) or me.dwID == dwCaster) then
					FireUIEvent("JH_PARTYBUFFLIST", dwCaster, data.dwID, data.nLevel, data.nIcon)
				end
				-- 头顶报警
				if DBM.bPushScreenHead and cfg.bScreenHead then
					FireUIEvent("JH_SCREENHEAD", dwCaster, { type = szType, dwID = data.dwID, col = data.col, txt = szName })
				end
				if me.dwID == dwCaster then
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
				if DBM.bPushTeamPanel and cfg.bTeamPanel and ( not cfg.bOnlySelfSrc or dwSkillSrcID == me.dwID) then
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
	if CACHE.SKILL_LIST[dwCaster][key] and nTime - CACHE.SKILL_LIST[dwCaster][key] < 100 then -- 0.1秒内 直接忽略
		return
	end
	if dwCastID == 13165 then -- 内功切换
		if szEvent == "UI_OME_SKILL_CAST_LOG" then
			FireUIEvent("JH_KUNGFU_SWITCH", dwCaster)
		end
	end
	CACHE.INTERVAL.CASTING[key] = CACHE.INTERVAL.CASTING[key] or {}
	CACHE.INTERVAL.CASTING[key][#CACHE.INTERVAL.CASTING[key] + 1] = nTime
	CACHE.SKILL_LIST[dwCaster][key] = nTime
	local tWeak, tTemp = CACHE.TEMP.CASTING, D.TEMP.CASTING
	local me = GetClientPlayer()
	local data = D.GetData("CASTING", dwCastID, dwLevel)
	if not tWeak[key] then
		if Table_IsSkillShow(dwCastID, dwLevel) or JH.bDebugClient then
			local t = {
				dwMapID      = me.GetMapID(),
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
	end
	-- 监控数据
	if data then
		if data.nScrutinyType and not D.CheckScrutinyType(data.nScrutinyType, dwCaster, me) then -- 监控对象检查
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
		szName = data.szName or szName
		nIcon  = data.nIcon or nIcon
		local szSrcName = JH.GetObjName(KObject)
		local dwTargetType, dwTargetID = KObject.GetTarget()
		local szTargetName
		if dwTargetID > 0 then
			szTargetName = JH.GetObjName(IsPlayer(dwTargetID) and GetPlayer(dwTargetID) or GetNpc(dwTargetID))
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
			tinsert(xml, GetFormatText(data.szName or szName, 44, 255, 255, 0))
			tinsert(xml, DBM_RIGHT_LINE)
			if data.bMonTarget and szTargetName then
				tinsert(xml, GetFormatText(g_tStrings.TARGET, 44, 255, 255, 255))
				tinsert(xml, DBM_LEFT_LINE)
				tinsert(xml, GetFormatText(szTargetName == me.szName and g_tStrings.STR_YOU or szTargetName, 44, 255, 255, 0))
				tinsert(xml, DBM_RIGHT_LINE)
			end
			if data.szNote then
				tinsert(xml, " " .. GetFormatText(data.szNote, 44, 255, 255, 255))
			end
			local txt = GetPureText(tconcat(xml))
			if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
				FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
			end
			-- 特大文字
			if DBM.bPushBigFontAlarm and cfg.bBigFontAlarm then
				FireUIEvent("JH_LARGETEXT", txt, { GetHeadTextForceFontColor(dwCaster, me.dwID) }, true )
			end
			if JH.bDebugClient and cfg.bSelect then
				SetTarget(IsPlayer(dwCaster) and TARGET.PLAYER or TARGET.NPC, dwCaster)
			end
			if cfg.tMark then
				D.SetTeamMark("CASTING", cfg.tMark, dwCaster, dwSkillID, dwLevel)
			end
			-- 头顶报警
			if DBM.bPushScreenHead and cfg.bScreenHead then
				FireUIEvent("JH_SCREENHEAD", dwCaster, { type = "CASTING", txt = data.szName or szName, col = data.col })
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
	local me = GetClientPlayer()
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
				dwMapID      = me.GetMapID(),
				dwID         = npc.dwTemplateID,
				nFrame       = select(2, GetNpcHeadImage(npc.dwID)),
				col          = { GetHeadTextForceFontColor(npc.dwID, me.dwID) },
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
		local cfg, nClass
		if data.tKungFu and not D.CheckKungFu(data.tKungFu) then -- 自身身法需求检查
			return
		end
		if bEnter then
			cfg, nClass = data[DBM_TYPE.NPC_ENTER], DBM_TYPE.NPC_ENTER
		else
			cfg, nClass = data[DBM_TYPE.NPC_LEAVE], DBM_TYPE.NPC_LEAVE
		end
		if nClass == DBM_TYPE.NPC_LEAVE then
			if data.bAllLeave and CACHE.NPC_LIST[npc.dwTemplateID] then
				return
			end
		else
			-- 场地上的NPC数量没达到预期数量
			if data.nCount and #CACHE.NPC_LIST[npc.dwTemplateID].tList < data.nCount then
				return
			end
			if cfg then
				if cfg.tMark then
					D.SetTeamMark("NPC", cfg.tMark, npc.dwID, npc.dwTemplateID)
				end
				if DBM.bPushScreenHead and cfg.bScreenHead then
					FireUIEvent("JH_SCREENHEAD", npc.dwID, { type = "Object", txt = data.szNote, col = data.col, szName = data.szName })
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
			local szName = JH.GetObjName(npc)
			local xml = {}
			tinsert(xml, DBM_LEFT_LINE)
			tinsert(xml, GetFormatText(data.szName or szName, 44, 255, 255, 0))
			tinsert(xml, DBM_RIGHT_LINE)
			if nClass == DBM_TYPE.NPC_ENTER then
				tinsert(xml, GetFormatText(_L["Appear"], 44, 255, 255, 255))
				if data.szNote then
					tinsert(xml, GetFormatText(" " .. data.szNote, 44, 255, 255, 255))
				end
			else
				tinsert(xml, GetFormatText(_L["leave"], 44, 255, 255, 255))
			end

			local txt = GetPureText(tconcat(xml))
			if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
				FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
			end
			-- 特大文字
			if DBM.bPushBigFontAlarm and cfg.bBigFontAlarm then
				FireUIEvent("JH_LARGETEXT", txt, { GetHeadTextForceFontColor(npc.dwID, me.dwID) }, true )
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

-- 系统和NPC喊话处理
function D.OnCallMessage(szContent, szNpcName, dwNpcID)
	if szNpcName == "" then
		szNpcName = "%"
	end
	-- 近期记录
	local me = GetClientPlayer()
	local key = (szNpcName or "sys") .. "::" .. szContent
	local tWeak, tTemp = CACHE.TEMP.TALK, D.TEMP.TALK
	if not tWeak[key] then
		local t = {
			dwMapID      = me.GetMapID(),
			szContent    = szContent,
			szTarget     = szNpcName,
			nCurrentTime = GetCurrentTime()
		}
		tWeak[key] = t
		tTemp[#tTemp + 1] = tWeak[key]
		FireUIEvent("DBMUI_TEMP_UPDATE", "TALK", t)
	end
	for k, v in ipairs(D.DATA.TALK) do
		local content = v.szContent
		local bHit, tInfo
		if v.szContent:find("$me") then
			tInfo = { dwID = me.dwID, szName = me.szName }
			content = v.szContent:gsub("$me", me.szName) -- 转换me是自己名字
		end
		if me.IsInParty() and content:find("$team") then
			local team = GetClientTeam()
			local c = content
			for kk, vv in ipairs(team.GetTeamMemberList()) do
				if szContent:match(c:gsub("$team", team.GetClientTeamMemberName(vv))) and (v.szTarget == szNpcName or v.szTarget == "%") then -- hit
					tInfo = { dwID = vv, szName = team.GetClientTeamMemberName(vv) }
					bHit = true
					break
				end
			end
		else
			if szContent:match(content) and (v.szTarget == szNpcName or v.szTarget == "%") then -- hit
				bHit = true
			end
		end
		if bHit then -- hit
			-- 倒计时
			if v.tCountdown then
				for kk, vv in ipairs(v.tCountdown) do
					if vv.nClass == DBM_TYPE.TALK_MONITOR then
						local szKey = k .. "." .. kk
						local tParam = {
							key      = vv.key,
							nFrame   = vv.nFrame,
							nTime    = vv.nTime,
							nRefresh = vv.nRefresh,
							szName   = vv.szName or v.szNote,
							nIcon    = vv.nIcon or 340,
							bTalk    = vv.bTeamChannel
						}
						D.FireCountdownEvent(vv.nClass, szKey, tParam)
					end
				end
			end

			local cfg = v[DBM_TYPE.TALK_MONITOR]
			if cfg then
				local xml, txt = {}, v.szNote or szContent
				if tInfo and not v.szNote then
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
						FireUIEvent("JH_SCREENHEAD", tInfo.dwID, { txt = _L("%s Call Name", szNpcName or g_tStrings.SYSTEM)})
					end
					if JH.bDebugClient and cfg.bSelect then
						SetTarget(TARGET.PLAYER, tInfo.dwID)
					end
				else
					if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
						D.Talk(txt, true)
					end
					if DBM.bPushScreenHead and cfg.bScreenHead then
						FireUIEvent("JH_SCREENHEAD", dwNpcID or me.dwID, { txt = txt })
					end
				end

				-- 中央报警
				if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
					FireUIEvent("JH_CA_CREATE", #xml > 0 and tconcat(xml) or txt, 3, #xml > 0)
				end
				-- 特大文字
				if DBM.bPushBigFontAlarm and cfg.bBigFontAlarm then
					FireUIEvent("JH_LARGETEXT", txt, { 255, 128, 0 }, true )
				end
				if DBM.bPushFullScreen and cfg.bFullScreen then
					if (tInfo and tInfo.dwID == me.dwID) or not tInfo then
						FireUIEvent("JH_FS_CREATE", "TALK", { nTime  = 3, col = v.col or { 0, 255, 0 }, bFlash = true })
					end
				end
				if DBM.bPushTeamChannel and cfg.bTeamChannel then
					if tInfo and not v.szNote then
						local talk = txt:gsub(_L["["] .. g_tStrings.STR_YOU .. _L["]"], _L["["] .. tInfo.szName .. _L["]"])
						D.Talk(talk)
					else
						D.Talk(txt)
					end
				end
			end
			break
		end
	end
end

-- NPC死亡事件 触发倒计时
function D.OnDeath(dwCharacterID, szKiller)
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
		else
			if data.tCountdown then
				for k, v in ipairs(data.tCountdown) do
					if v.nClass == DBM_TYPE.NPC_FIGHT then
						local class = v.key and DBM_TYPE.COMMON or v.nClass
						FireUIEvent("JH_ST_DEL", class, v.key or (k .. "."  .. data.dwID .. "." .. (data.nLevel or 0)), true) -- try kill
					end
				end
			end
		end
	end
end

-- NPC 血量倒计时处理 这个很可能以后会是 最大的性能消耗 格外留意
function D.OnNpcInfoChange(szEvent, dwTemplateID, nPer)
	local data = D.GetData("NPC", dwTemplateID)
	if data and data.tCountdown then
		local dwType = szEvent == "DBM_NPC_LIFE_CHANGE" and DBM_TYPE.NPC_LIFE or DBM_TYPE.NPC_MANA
		for k, v in ipairs(data.tCountdown) do
			if v.nClass == dwType then
				local t = JH_Split(v.nTime, ";")
				for kk, vv in ipairs(t) do
					local time = JH_Split(vv, ",")
					if time[1] and time[2] and tonumber(JH_Trim(time[1])) and JH_Trim(time[2]) ~= "" then
						local nVper = tonumber(JH_Trim(time[1])) * 100
						if nVper == nPer then -- hit
							local szName = v.szName or JH.GetTemplateName(dwTemplateID)
							local szMsg = dwType == DBM_TYPE.NPC_LIFE and _L("%s life has left %d%.", szName, nVper) or _L("%s mana has reached %d%.", szName, nVper)
							if DBM.bPushCenterAlarm then
								FireUIEvent("JH_CA_CREATE", szMsg .. " " .. time[2], 3)
							end
							if DBM.bPushBigFontAlarm then
								FireUIEvent("JH_LARGETEXT", szMsg .. " " .. time[2], { 255, 128, 0 }, true)
							end
							FireUIEvent("JH_LARGETEXT", 12345, { 255, 128, 0 }, true)
							if DBM.bPushTeamChannel and v.bTeamChannel then
								D.Talk(szMsg)
							end
							if time[3] and tonumber(time[3]) then
								local szKey = k .. "." .. dwTemplateID .. "." .. kk
								local tParam = {
									key    = v.key,
									nFrame = v.nFrame,
									nTime  = tonumber(JH_Trim(time[3])),
									szName = time[2],
									nIcon  = v.nIcon,
									bTalk  = v.bTeamChannel
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
end
-- NPC 全部消失的倒计时处理
function D.OnNpcAllLeave(dwTemplateID)
	local data = D.GetData("NPC", dwTemplateID)
	if data then
		D.CountdownEvent(data, DBM_TYPE.NPC_ALLLEAVE)
	end
end

function D.CheckNpcState()
	for k, v in pairs(CACHE.NPC_LIST) do
		local data = D.GetData("NPC", k)
		if data then
			local bFightFlag = false
			local fLifePer = 1
			local fManaPer = 1
			for kk, vv in ipairs(v.tList) do
				local npc = GetNpc(vv)
				if npc then
					local fLife = npc.nCurrentLife / npc.nMaxLife
					local fMana = npc.nCurrentMana / npc.nMaxMana
					if fLife < fLifePer then -- 取血量最少的NPC
						fLifePer = fLife
					end
					if fMana < fManaPer then -- 取蓝量最少的NPC
						fManaPer = fMana
					end
					-- 战斗标记检查
					if npc.bFightState then
						bFightFlag = true
						break
					end
				end
			end
			if bFightFlag ~= v.bFightState then
				CACHE.NPC_LIST[k].bFightState = bFightFlag
			else
				bFightFlag = nil
			end
			fLifePer = floor(fLifePer * 100)
			fManaPer = floor(fManaPer * 100)
			if v.nLife > fLifePer then
				local nCount, step = v.nLife - fLifePer, 1
				if nCount > 50 then
					step = 2
				end
				for i = 1, nCount, step do
					FireUIEvent("DBM_NPC_LIFE_CHANGE", k, v.nLife - i)
				end
			end
			if v.nMana < fManaPer then
				local nCount, step = fManaPer - v.nMana, 1
				if nCount > 50 then
					step = 2
				end
				for i = 1, nCount, step do
					FireUIEvent("DBM_NPC_MANA_CHANGE", k, v.nMana + i)
				end
			end
			v.nLife = fLifePer
			v.nMana = fManaPer
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

-- UI操作
function D.GetFrame()
	return Station.Lookup("Normal/DBM")
end

function D.Open()
	if not D.GetFrame() then
		Wnd.OpenWindow(DBM_INIFILE, "DBM")
	end
end

function D.Close()
	if D.GetFrame() then
		Wnd.CloseWindow(D.GetFrame()) -- kill all event
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
	D.Enable(DBM.bEnable)
end

function D.SaveData()
	JH.SaveLUAData(GetDataPath(), D.FILE)
end

function D.GetDungeon()
	if IsEmpty(CACHE.DUNGEON) then
		local tCache = {}
		for k, v in JH.bpairs(GetMapList()) do
			local a = g_tTable.DungeonInfo:Search(v)
			if a and a.dwClassID == 3 then
				if not tCache[a.szLayer3Name] then
					local i = #CACHE.DUNGEON + 1
					CACHE.DUNGEON[i] = { szLayer3Name = a.szLayer3Name, aList = {} }
					tCache[a.szLayer3Name] = CACHE.DUNGEON[i]
				end
				tinsert(tCache[a.szLayer3Name].aList, a.dwMapID)
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
			if cache[nLevel] then -- 如果可以直接命中 O(∩_∩)O
				local data = tab[cache[nLevel]]
				if data and data.dwID == dwID and (not data.bCheckLevel or data.nLevel == nLevel) then
					-- D.Log("HIT TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
					return data
				else
					-- D.Log("RELOOKUP TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
					return GetData(tab, szType, dwID, nLevel)
				end
			else -- 不能直接命中的情况下 遍历下面的level /(ㄒoㄒ)/~~
				for k, v in pairs(cache) do
					local data = tab[cache[k]]
					if data and data.dwID == dwID and (not data.bCheckLevel or data.nLevel == nLevel) then -- 能直接命中是最好了 ;-)
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
	if DBM_PLAYER_NAME == "NONE" then
		local me = GetClientPlayer()
		if me then
			if IsRemotePlayer(me.dwID) and not DBM.bCommon then
				return
			end
			DBM_PLAYER_NAME = me.szName
			local data = JH.LoadLUAData(GetDataPath())
			if data then
				for k, v in pairs(D.FILE) do
					D.FILE[k] = data[k] or {}
				end
			else
				local szLang = select(3, GetVersion())
				local config = {
					nMode = 1,
					tList = { -- 初始化读取的数据 以后会增加 doodad
						BUFF    = true,
						DEBUFF  = true,
						CASTING = true,
						NPC     = true,
						TALK    = true,
						CIRCLE  = true
					},
					szFileName = szLang ..  "_default.jx3dat",
				}
				D.LoadConfigureFile(config)
			end
		end
	end
end

function D.LoadConfigureFile(config)
	local root, path = GetRootPath(), "/".. JH.GetAddonInfo().szRootPath .. "DBM/data/" .. config.szFileName
	local data = LoadLUAData(path)
	root = root:gsub("\\", "/")
	if not data then
		return false, root .. path
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
		elseif config.nMode == 2 then -- 原文件优先
			if config.tList["CIRCLE"] then
				if type(Circle) ~= "nil" then
					local dat = { Circle = data["CIRCLE"] }
					Circle.LoadCircleMergeData(dat)
				end
				config.tList["CIRCLE"] = nil
			end
			for szType, _ in pairs(config.tList) do
				if data[szType] then
					for k, v in pairs(data[szType]) do
						for kk, vv in ipairs(v) do
							if not D.CheckRepeatData(szType, k, vv.dwID or vv.szContent, vv.nLevel or vv.szTarget) then
								D.FILE[szType][k] = D.FILE[szType][k] or {}
								table.insert(D.FILE[szType][k], vv)
							end
						end
					end
				end
			end
		end
		FireUIEvent("DBM_CREATE_CACHE")
		FireUIEvent("DBMUI_DATA_RELOAD")
		return true, root .. path
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
	local root, path = GetRootPath(), "/" .. JH.GetAddonInfo().szRootPath .. "DBM/data/" .. config.szFileName
	root = root:gsub("\\", "/")
	if config.bJson then
		SaveLUAData(path, JH.JsonEncode(data, config.bFormat), nil, false)
	else
		SaveLUAData(path, data, config.bFormat and "\t", false)
	end
	return root .. path
end

-- 删除 移动 添加 清空
function D.RemoveData(szType, dwMapID, nIndex)
	if D.FILE[szType][dwMapID] and D.FILE[szType][dwMapID][nIndex] then
		table.remove(D.FILE[szType][dwMapID], nIndex)
		if #D.FILE[szType][dwMapID] == 0 then
			D.FILE[szType][dwMapID] = nil
		end
		FireUIEvent("DBM_CREATE_CACHE")
		FireUIEvent("DBMUI_DATA_RELOAD")
	end
end

function D.MoveOrder(szType, dwMapID, nIndex, bUp)
	if D.FILE[szType][dwMapID] then
		if bUp then
			if nIndex ~= 1 then
				D.FILE[szType][dwMapID][nIndex], D.FILE[szType][dwMapID][nIndex - 1] = D.FILE[szType][dwMapID][nIndex - 1], D.FILE[szType][dwMapID][nIndex]
			end
		else
			if nIndex ~= #D.FILE[szType][dwMapID] then
				D.FILE[szType][dwMapID][nIndex], D.FILE[szType][dwMapID][nIndex + 1] = D.FILE[szType][dwMapID][nIndex + 1], D.FILE[szType][dwMapID][nIndex]
			end
		end
		FireUIEvent("DBM_CREATE_CACHE")
		FireUIEvent("DBMUI_DATA_RELOAD")
	end
end

function D.CheckRepeatData(szType, dwMapID, dwID, nLevel)
	if D.FILE[szType][dwMapID] then
		for k, v in ipairs(D.FILE[szType][dwMapID]) do
			if type(dwID) == "string" then
				if dwID == v.szContent and nLevel == v.szTarget then
					return k, v
				end
			else
				if dwID == v.dwID and nLevel == v.nLevel then
					return k, v
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
		if D.CheckRepeatData(szType, dwTargetMapID, data.dwID or data.szContent, data.nLevel or data.szTarget) then
			return JH.Alert(_L["same data Exist"])
		end
		D.FILE[szType][dwTargetMapID] = D.FILE[szType][dwTargetMapID] or {}
		tinsert(D.FILE[szType][dwTargetMapID], clone(D.FILE[szType][dwMapID][nIndex]))
		if not bCopy then
			D.RemoveData(szType, dwMapID, nIndex)
		end
		FireUIEvent("DBM_CREATE_CACHE")
		FireUIEvent("DBMUI_DATA_RELOAD")
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
				local nIndex = D.CheckRepeatData(t.szType, t.dwMapID, data.dwID or data.szContent, data.nLevel or data.szTarget)
				if nIndex then
					D.RemoveData(t.szType, t.dwMapID, nIndex)
				end
				D.AddData(t.szType, t.dwMapID, data)
			else
				local data = t.tData
				local nIndex = Circle.CheckRepeatData(t.dwMapID, data.key, data.dwType)
				if nIndex then
					Circle.RemoveData(t.dwMapID, nIndex)
				end
				Circle.AddData(t.dwMapID, data)
			end
			table.remove(DBM_SHARE_QUEUE, 1)
			JH.DelayCall(100, D.ConfirmShare)
		end, function()
			table.remove(DBM_SHARE_QUEUE, 1)
			JH.DelayCall(100, D.ConfirmShare)
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
	CheckRepeatData   = D.CheckRepeatData,
	ClearTemp         = D.ClearTemp,
	AddData           = D.AddData,
	SaveConfigureFile = D.SaveConfigureFile,
	LoadConfigureFile = D.LoadConfigureFile,
	MoveOrder         = D.MoveOrder,
}
DBM_API = setmetatable({}, { __index = ui, __newindex = function() end, __metatable = true })

JH.RegisterEvent("LOGIN_GAME", D.Init)
JH.RegisterEvent("LOADING_END", D.LoadUserData)
JH.RegisterExit(D.SaveData)
JH.RegisterBgMsg("DBM_SHARE", D.OnShare)
