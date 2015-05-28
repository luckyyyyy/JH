-- @Author: Webster
-- @Date:   2015-05-13 16:06:53
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-28 15:10:37

local _L = JH.LoadLangPack
local ipairs, pairs = ipairs, pairs
local setmetatable, tonumber, type, tostring, unpack = setmetatable, tonumber, type, tostring, unpack
local tinsert, tconcat = table.insert, table.concat
local GetTime, IsPlayer = GetTime, IsPlayer
local GetClientPlayer, GetClientTeam, GetPlayer, GetNpc = GetClientPlayer, GetClientTeam, GetPlayer, GetNpc
local FireUIEvent, Table_BuffIsVisible, Table_IsSkillShow = FireUIEvent, Table_BuffIsVisible, Table_IsSkillShow
local GetPureText = GetPureText
local JH_Split, JH_Trim = JH.Split, JH.Trim
local DBM_PLAYER_NAME = "NONE"
local DBM_TYPE, DBM_SCRUTINY_TYPE = DBM_TYPE, DBM_SCRUTINY_TYPE
local DBM_MAX_CACHE = 1000 -- 最大的cache数量 主要是UI的问题
local DBM_DEL_CACHE = 500  -- 每次清理的数量 然后会做一次gc
local DBM_INIFILE  = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM.ini"
local DBM_MARK_QUEUE = {}
local DBM_MARK_TIME  = 0 -- 标记事件
local function GetDataPath()
	if DBM.bCommon then
		return "DBM/Common/DBM.jx3dat"
	else
		return "DBM/" .. DBM_PLAYER_NAME .. "/DBM.jx3dat"
	end
end

local CACHE = {
	TEMP = { -- 近期事件记录MAP 这里用弱表 方便处理
		BUFF    = setmetatable({}, { __mode = "v" }),
		DEBUFF  = setmetatable({}, { __mode = "v" }),
		CASTING = setmetatable({}, { __mode = "v" }),
		NPC     = setmetatable({}, { __mode = "v" }),
		TALK    = setmetatable({}, { __mode = "v" }),
	},
	MAP = { -- 需要监控的数据MAP TALK分类不需要 因为不是唯一命中 是模糊命中
		BUFF    = {},
		DEBUFF  = {},
		CASTING = {},
		NPC     = {},
	},
	NPC_LIST = {},
	SKILL_LIST = {},
}

local D = {
	tDungeonList = {},
	FILE = { -- 文件原始数据
		BUFF    = {},
		DEBUFF  = {},
		CASTING = {},
		NPC     = {},
		TALK    = {},
	},
	TEMP = { -- 近期事件记录
		BUFF    = {},
		DEBUFF  = {},
		CASTING = {},
		NPC     = {},
		TALK    = {},
	},
	DATA = { -- 需要监控的数据合集
		BUFF    = {},
		DEBUFF  = {},
		CASTING = {},
		NPC     = {},
		TALK    = {},
	}
}

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
	this:RegisterEvent("PARTY_SET_MARK")
end

function DBM.OnFrameBreathe()
	D.CheckNpcState()
end

function DBM.OnEvent(szEvent)
	if szEvent == "BUFF_UPDATE" then
		D.OnBuff(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
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
	elseif szEvent == "PARTY_SET_MARK" then
		if #DBM_MARK_QUEUE >= 1 then
			local r = table.remove(DBM_MARK_QUEUE, 1)
			local res, err = pcall(r.fnAction)
			if not res then
				JH.Debug("DBM_Mark ERROR: " .. err)
			end
		else
			DBM_MARK_TIME = 0
		end
	elseif szEvent == "PLAYER_SAY" then
		if not IsPlayer(arg1) then
			D.OnCallMessage(GetPureText(arg0), arg3)
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
	elseif szEvent == "DBM_NPC_LIFE_CHANGE" then
		D.OnNpcLife(arg0, arg1)
	elseif szEvent == "LOADING_END" or szEvent == "DBM_CREATE_CACHE" or szEvent == "DBM_LOADING_END" then
		D.CreateData(szEvent)
	end
end

function D.Log(szMsg)
	Log("[DBM] " .. szMsg)
end

function D.FireTeamWhisper(szMsg)
	local me = GetClientPlayer()
	if me and me.IsInParty() then
		local team = GetClientTeam()
		for _, v in ipairs(team.GetTeamMemberList()) do
			local szName = team.GetClientTeamMemberName(v)
			JH.Talk(szName, szMsg:gsub(_L["["] .. szName .. _L["]"], _L["["] .. g_tStrings.STR_YOU ..  _L["]"]))
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
end

function D.CreateData(szEvent)
	local szLang = select(3, GetVersion())
	local me = GetClientPlayer()
	local dwMapID = me.GetMapID()
	local nTime = GetTime()
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
	D.Log("Create TALK data Succeed!")

	-- 重建metatable
	for k, v in pairs(D.FILE)  do
		setmetatable(D.FILE[k], { __index = function(me, index)
			if index == _L["All Data"] then
				local t = {}
				for k, v in pairs(D.FILE[k]) do
					for kk, vv in ipairs(v) do
						t[#t +1] = setmetatable(vv, { __index = function(me, val)
							if val == "dwMapID" then
								return k
							elseif val == "nIndex" then
								return kk
							end
						end })
					end
				end
				return t
			end
		end })
	end
	-- 清空缓存
	if szEvent == "LOADING_END" or szEvent == "DBM_LOADING_END" then
		CACHE.NPC_LIST   = {}
		CACHE.SKILL_LIST = {}
	end
	if DBM.bPushTeamPanel then
		local tBuff = {}
		for k, v in ipairs(D.DATA.BUFF) do
			if v.bTeamPanel then
				tinsert(tBuff, v.dwID)
			end
		end
		for k, v in ipairs(D.DATA.DEBUFF) do
			if v.bTeamPanel then
				tinsert(tBuff, v.dwID)
			end
		end
		Raid_MonitorBuffs(tBuff)
	else
		Raid_MonitorBuffs({})
	end
	D.Log("MAPID: " .. dwMapID ..  " Create data Succeed:" .. GetTime() - nTime  .. "ms")
end

function D.FreeCache(szType)
	-- D.Log(szType .. " cache clear!")
	local t = {}
	local tTemp = D.TEMP[szType]
	for i = DBM_DEL_CACHE, #tTemp do
		t[#t + 1] = tTemp[i]
	end
	D.TEMP[szType] = t
	collectgarbage("collect")
	FireUIEvent("DBMUI_TEMP_RELOAD", szType)
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

-- 智能标记逻辑
function D.SetTeamMark(szType, tMark, dwCharacterID, dwID, nLevel)
	local fnAction = function()
		if not JH.IsMark() then
			return
		end
		local team = GetClientTeam()
		local tTeamMark, tMarkList = team.GetTeamMark(), {} -- tmd 什么鬼结构。。。
		for k, v in pairs(tTeamMark) do
			tMarkList[v] = k
		end
		if szType == "NPC" then
			for k, v in ipairs(tMark) do
				if v then
					if tMarkList[k] and tMarkList[k] ==	dwCharacterID then
						break
					end
					local p = GetNpc(tMarkList[k])
					if not tMarkList[k] or tMarkList[k] == 0 or not p then
						team.SetTeamMark(k, dwCharacterID)
						break
					elseif p then
						if p.dwTemplateID ~= dwID then
							team.SetTeamMark(k, dwCharacterID)
							break
						end
					end
				end
			end
		elseif szType == "BUFF" or szType == "DEBUFF" then
			for k, v in ipairs(tMark) do
				if v then
					if tMarkList[k] and tMarkList[k] ==	dwCharacterID then
						break
					end
					local bMark = false
					if tMarkList[k] and tMarkList[k] ~= 0 then
						local p = IsPlayer(tMarkList[k]) and GetPlayer(tMarkList[k]) or GetNpc(tMarkList[k])
						if p then
							if not JH.HasBuff(dwID, p) then
								bMark = true
							end
						else
							bMark = true
						end
					else
						bMark = true
					end
					if bMark then
						team.SetTeamMark(k, dwCharacterID)
						break
					end
				end
			end
		elseif szType == "CASTING" then
			for k, v in ipairs(tMark) do
				if v then
					if tMarkList[k] and tMarkList[k] ==	dwCharacterID then
						break
					end
					team.SetTeamMark(k, dwCharacterID)
					break
				end
			end
		end
	end
	tinsert(DBM_MARK_QUEUE, { fnAction = fnAction })
	local nTime = GetTime()
	if nTime - DBM_MARK_TIME > 1000 then
		local f = table.remove(DBM_MARK_QUEUE, 1)
		pcall(f.fnAction)
	end
	DBM_MARK_TIME = nTime
end
-- 倒计时处理 支持定义无限的倒计时
function D.FireCountdownEvent(data, nClass)
	if data.tCountdown then
		for k, v in ipairs(data.tCountdown) do
			if nClass == v.nClass then
				FireUIEvent("JH_ST_CREATE", nClass, v.key or (k .. "." .. (data.dwID or 0) .. "." .. (data.nLevel or 0)), {
					nTime    = v.nTime,
					nRefresh = v.nRefresh,
					szName   = v.szName or data.szName,
					nIcon    = v.nIcon or data.nIcon,
					bTalk    = DBM.bPushTeamChannel and v.bTeamChannel
				})
			end
		end
	end
end

function D.GetSrcName(dwID)
	if not dwID then
		return nil
	end
	local KObject = IsPlayer(dwID) and GetPlayer(dwID) or GetNpc(dwID)
	if KObject then
		return JH.GetTemplateName(KObject)
	else
		return dwID
	end
end

-- 事件操作
function D.OnBuff(dwCaster, bDelete, nIndex, bCanCancel, dwBuffID, nCount, nEndFrame, bInit, nBuffLevel, dwSkillSrcID)
	local me = GetClientPlayer()
	local szType = bCanCancel and "BUFF" or "DEBUFF"
	local data = D.GetData(szType, dwBuffID, nBuffLevel)
	local cfg, nClass
	if not bDelete then
		-- 近期记录
		if Table_BuffIsVisible(dwBuffID, nBuffLevel) or JH.bDebugClient then
			local tWeak, tTemp = CACHE.TEMP[szType], D.TEMP[szType]
			local key = dwBuffID .. "_" .. nBuffLevel
			if not tWeak[key] then
				local t = {
					dwMapID   = me.GetMapID(),
					dwID      = dwBuffID,
					nLevel    = nBuffLevel,
					bIsPlayer = IsPlayer(dwSkillSrcID),
					szSrcName = D.GetSrcName(dwSkillSrcID)
				}
				tWeak[key] = t
				tTemp[#tTemp + 1] = tWeak[key]
				if #tTemp > DBM_MAX_CACHE then
					D.FreeCache(szType)
				else
					FireUIEvent("DBMUI_TEMP_UPDATE", szType, t)
				end
			end
		end
	end
	if data then
		if data.nScrutinyType and not D.CheckScrutinyType(data.nScrutinyType, dwCaster, me) then -- 监控对象检查
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
		D.FireCountdownEvent(data, nClass)
		if cfg then
			local szName, nIcon = JH.GetBuffName(dwBuffID, nBuffLevel)
			local KObject = IsPlayer(dwCaster) and GetPlayer(dwCaster) or GetNpc(dwCaster)
			if not KObject then
				return -- D.Log("ERROR " .. szType .. " object:" .. dwCaster .. " does not exist!")
			end
			szName = data.szName or szName
			nIcon  = data.nIcon or nIcon
			local szSrcName = JH.GetTemplateName(KObject)
			local xml = {}
			tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
			tinsert(xml, GetFormatText(szSrcName == me.szName and g_tStrings.STR_YOU or szSrcName, 44, 255, 255, 0))
			tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
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
					FireUIEvent("JH_PARTYBUFFLIST", dwCaster, data.dwID, data.nLevel)
				end
				-- 头顶报警
				if DBM.bPushScreenHead and cfg.bScreenHead then
					FireUIEvent("JH_SCREENHEAD", dwCaster, { type = szType, dwID = data.dwID, szName = data.szName or szName, col = data.col })
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
					FireUIEvent("JH_RAID_REC_BUFF", dwCaster, data.dwID, data.nLevel, data.col)
				end
			end
			if DBM.bPushTeamChannel and cfg.bTeamChannel then
				local talk = txt:gsub(_L["["] .. g_tStrings.STR_YOU .. _L["]"], _L["["] .. szSrcName .. _L["]"])
				JH.Talk(talk)
			end
			if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
				JH.Talk(szSrcName, txt:gsub(szSrcName, g_tStrings.STR_NAME_YOU))
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
	CACHE.SKILL_LIST[dwCaster][key] = nTime
	local tWeak, tTemp = CACHE.TEMP.CASTING, D.TEMP.CASTING
	local me = GetClientPlayer()
	local data = D.GetData("CASTING", dwCastID, dwLevel)
	if not tWeak[key] then
		if Table_IsSkillShow(dwCastID, dwLevel) or JH.bDebugClient then
			local t = {
				dwMapID   = me.GetMapID(),
				dwID      = dwCastID,
				nLevel    = dwLevel,
				bIsPlayer = IsPlayer(dwCaster),
				szSrcName = D.GetSrcName(dwCaster)
			}
			tWeak[key] = t
			tTemp[#tTemp + 1] = tWeak[key]
			if #tTemp > DBM_MAX_CACHE then
				D.FreeCache("CASTING")
			else
				FireUIEvent("DBMUI_TEMP_UPDATE", "CASTING", t)
			end
		end
	end
	-- 监控数据
	if data then
		if data.nScrutinyType and not D.CheckScrutinyType(data.nScrutinyType, dwCaster, me) then -- 监控对象检查
			return
		end
		local szName, nIcon = JH.GetSkillName(dwCastID, dwLevel)
		local KObject = IsPlayer(dwCaster) and GetPlayer(dwCaster) or GetNpc(dwCaster)
		if not KObject then
			return -- D.Log("ERROR CASTING object:" .. dwCaster .. " does not exist!")
		end
		szName = data.szName or szName
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
		D.FireCountdownEvent(data, nClass)
		if cfg then
			local xml = {}
			tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
			tinsert(xml, GetFormatText(szSrcName, 44, 255, 255, 0))
			tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
			if nClass == DBM_TYPE.SKILL_END then
				tinsert(xml, GetFormatText(_L["use of"], 44, 255, 255, 255))
			else
				tinsert(xml, GetFormatText(_L["Building"], 44, 255, 255, 255))
			end
			tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
			tinsert(xml, GetFormatText(szName, 44, 255, 255, 0))
			tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
			if data.bMonTarget and szTargetName then
				tinsert(xml, GetFormatText(g_tStrings.TARGET, 44, 255, 255, 255))
				tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
				tinsert(xml, GetFormatText(szTargetName == me.szName and g_tStrings.STR_YOU or szTargetName, 44, 255, 255, 0))
				tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
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
					JH.Talk(talk)
				else
					JH.Talk(txt)
				end
			end
			if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
				D.FireTeamWhisper(txt)
			end
		end
	end
end

-- NPC事件
function D.OnNpcEvent(npc, bEnter)
	local me = GetClientPlayer()
	local data = D.GetData("NPC", npc.dwTemplateID)
	local nTime = GetTime()
	local cfg, nClass
	if bEnter then
		CACHE.NPC_LIST[npc.dwTemplateID] = CACHE.NPC_LIST[npc.dwTemplateID] or { bFightState = false, tList = {}, nTime = -1, nLife = math.floor(npc.nCurrentLife / npc.nMaxLife * 100) }
		tinsert(CACHE.NPC_LIST[npc.dwTemplateID].tList, npc.dwID)
		local tWeak, tTemp = CACHE.TEMP.NPC, D.TEMP.NPC
		if not tWeak[npc.dwTemplateID] then
			local t = {
				dwMapID = me.GetMapID(),
				dwID    = npc.dwTemplateID,
				nFrame  = select(2, GetNpcHeadImage(npc.dwID)),
				col     = { GetHeadTextForceFontColor(npc.dwID, me.dwID) }
			}
			tWeak[npc.dwTemplateID] = t
			tTemp[#tTemp + 1] = tWeak[npc.dwTemplateID]
			if #tTemp > DBM_MAX_CACHE then
				D.FreeCache("NPC")
			else
				FireUIEvent("DBMUI_TEMP_UPDATE", "NPC", t)
			end
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
			if data.nCount and data.nCount < #CACHE.NPC_LIST[npc.dwTemplateID].tList then
				return
			end
			if cfg then
				if cfg.tMark then
					D.SetTeamMark("NPC", cfg.tMark, npc.dwID, npc.dwTemplateID)
				end
				if DBM.bPushScreenHead and cfg.bScreenHead then
					FireUIEvent("JH_SCREENHEAD", npc.dwID, { type = "Object", txt = data.szNote, col = data.col })
				end
			end
			if nTime - CACHE.NPC_LIST[npc.dwTemplateID].nTime < 500 then -- 0.5秒内进入相同的NPC直接忽略
				return -- D.Log("IGNORE NPC ENTER SCENE ID:" .. npc.dwTemplateID .. " TIME:" .. nTime .. " TIME2:" .. CACHE.NPC_LIST[npc.dwTemplateID].nTime)
			else
				CACHE.NPC_LIST[npc.dwTemplateID].nTime = nTime
			end
		end
		D.FireCountdownEvent(data, nClass)
		if cfg then
			local szName = JH.GetTemplateName(npc)
			local xml = {}
			tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
			tinsert(xml, GetFormatText(szName, 44, 255, 255, 0))
			tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
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
				JH.Talk(txt)
			end
			if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
				D.FireTeamWhisper(txt)
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
function D.OnCallMessage(szContent, szNpcName)
	if szNpcName == "" then
		szNpcName = "%"
	end
	-- 近期记录
	local me = GetClientPlayer()
	local key = (szNpcName or "sys") .. "::" .. szContent
	local tWeak, tTemp = CACHE.TEMP.TALK, D.TEMP.TALK
	if not tWeak[key] then
		local t = {
			dwMapID   = me.GetMapID(),
			szContent = szContent,
			szTarget  = szNpcName
		}
		tWeak[key] = t
		tTemp[#tTemp + 1] = tWeak[key]
		if #tTemp > DBM_MAX_CACHE then
			D.FreeCache("TALK")
		else
			FireUIEvent("DBMUI_TEMP_UPDATE", "TALK", t)
		end
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
			D.FireCountdownEvent(v, DBM_TYPE.TALK_MONITOR)
			local cfg = v[DBM_TYPE.TALK_MONITOR]
			if cfg then
				local xml, txt = {}, v.szNote or szContent
				if tInfo and not v.szNote then
					tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
					tinsert(xml, GetFormatText(szNpcName or _L["JX3"], 44, 255, 255, 0))
					tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
					tinsert(xml, GetFormatText(_L["is calling"], 44, 255, 255, 255))
					tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
					tinsert(xml, GetFormatText(tInfo.szName == me.szName and g_tStrings.STR_YOU or tInfo.szName, 44, 255, 255, 0))
					tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
					tinsert(xml, GetFormatText(_L["'s name."], 44, 255, 255, 255))
					txt = GetPureText(tconcat(xml))
				end
				txt = txt:gsub("$me", me.szName)
				if tInfo then
					txt = txt:gsub("$team", tInfo.szName)
					if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
						JH.Talk(tInfo.szName, txt:gsub(tInfo.szName, g_tStrings.STR_YOU))
					end
					if DBM.bPushScreenHead and cfg.bScreenHead then
						FireUIEvent("JH_SCREENHEAD", tInfo.dwID, { txt = _L("%s Call Name", szNpcName or g_tStrings.SYSTEM)})
					end
					if JH.bDebugClient and cfg.bSelect then
						SetTarget(TARGET.PLAYER, tInfo.dwID)
					end
				end

				-- 中央报警
				if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
					FireUIEvent("JH_CA_CREATE", #xml > 0 and tconcat(xml) or txt, 3, #xml > 0)
				end
				-- 特大文字
				if DBM.bBigFontAlarm and cfg.bBigFontAlarm then
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
						JH.Talk(talk)
					else
						JH.Talk(txt)
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
			D.FireCountdownEvent(data, DBM_TYPE.NPC_DEATH)
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
				D.FireCountdownEvent(data, DBM_TYPE.NPC_ALLDEATH)
			end
		end
	end
end

-- NPC进出战斗事件 触发倒计时
function D.OnNpcFight(dwTemplateID, bFight)
	local data = D.GetData("NPC", dwTemplateID)
	if data then
		if bFight then
			D.FireCountdownEvent(data, DBM_TYPE.NPC_FIGHT)
		else
			if data.tCountdown then
				for k, v in ipairs(data.tCountdown) do
					if v.nClass == DBM_TYPE.NPC_FIGHT then
						FireUIEvent("JH_ST_DEL", v.nClass, v.key or (k .. "."  .. data.dwID .. "." .. (data.nLevel or 0)), true) -- try kill
					end
				end
			end
		end
	end
end

-- NPC 血量倒计时处理 这个很可能以后会是 最大的性能消耗 格外留意
function D.OnNpcLife(dwTemplateID, nLife)
	local data = D.GetData("NPC", dwTemplateID)
	if data and data.tCountdown then
		for k, v in ipairs(data.tCountdown) do
			if v.nClass == DBM_TYPE.NPC_LIFE then
				local t = JH_Split(v.nTime, ";")
				for kk, vv in ipairs(t) do
					local time = JH_Split(vv, ",")
					if time[1] and time[2] and tonumber(JH_Trim(time[1])) and JH_Trim(time[2]) ~= "" then
						if tonumber(JH_Trim(time[1])) * 100 == nLife then -- hit
							if DBM.bPushCenterAlarm then
								FireUIEvent("JH_CA_CREATE", time[2], 3)
							end
							if DBM.bPushBigFontAlarm then
								FireUIEvent("JH_LARGETEXT", time[2], { 255, 128, 0 }, true)
							end
							if time[3] and tonumber(time[3]) then
								FireUIEvent("JH_ST_CREATE", DBM_TYPE.NPC_LIFE, v.key or (k .. "." .. dwTemplateID .. "." .. kk), {
									nTime  = tonumber(JH_Trim(time[3])),
									szName = time[2],
									nIcon  = v.nIcon,
									bTalk  = DBM.bPushTeamChannel and v.bTeamChannel
								})
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
		D.FireCountdownEvent(data, DBM_TYPE.NPC_ALLLEAVE)
	end
end

function D.CheckNpcState()
	for k, v in pairs(CACHE.NPC_LIST) do
		local data = D.GetData("NPC", k)
		if data then
			local bFightFlag = false
			local fNpcPer = 1
			for kk, vv in ipairs(v.tList) do
				local npc = GetNpc(vv)
				if npc then
					local fPer = npc.nCurrentLife / npc.nMaxLife
					if fPer < fNpcPer then -- 取血量最少的NPC
						fNpcPer = fPer
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
			fNpcPer = math.floor(fNpcPer * 100)
			if v.nLife > fNpcPer then
				local nCount, step = v.nLife - fNpcPer, 1
				if nCount > 50 then -- 如果boss血量一下被干掉50%以上 那直接步进2 【鄙视秒BOSS的 小心扯着蛋
					step = 2
				end
				for i = 1, nCount, step do
					FireUIEvent("DBM_NPC_LIFE_CHANGE", k, v.nLife - i)
				end
			end
			v.nLife = fNpcPer
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
		Wnd.CloseWindow(Station.Lookup("Normal/DBM")) -- kill all event
		FireUIEvent("JH_ST_CLEAR")
		CACHE.NPC_LIST = {}
		CACHE.SKILL_LIST = {}
	end
end

function D.Enable(bEnable, bFireUIEvent)
	if bEnable then
		local res, err = pcall(D.Open)
		if not res then
			JH.Sysmsg2(err)
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
	if IsEmpty(D.tDungeonList) then
		for k, v in ipairs(GetMapList()) do
			local a = g_tTable.DungeonInfo:Search(v)
			if a and a.dwClassID == 3 then
				tinsert(D.tDungeonList, {
					dwMapID      = a.dwMapID,
					szLayer3Name = a.szLayer3Name
				})
			end
		end
		table.sort(D.tDungeonList, function(a, b)
			return a.dwMapID < b.dwMapID
		end)
	end
	return D.tDungeonList
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
		end
		return D.FILE[szType]
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

-- 获取监控数据 注意 不是获取文件内的 如果想找文件内的 请使用 GetFileData
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
	else
		-- D.Log("IGNORE TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. (nLevel or 0))
	end
end

function D.LoadUserData()
	if DBM_PLAYER_NAME == "NONE" then
		local me = GetClientPlayer()
		if me and not IsRemotePlayer(me.dwID) then
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
					tList = {
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
	local data = LoadLUAData("interface/JH/DBM/data/" .. config.szFileName)
	local path = GetRootPath() .."/interface/JH/DBM/data/" .. config.szFileName
	if not data then
		return false, path
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
			FireUIEvent("DBM_CREATE_CACHE")
			FireUIEvent("DBMUI_DATA_RELOAD")
			collectgarbage("collect")
			return true, path
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
			FireUIEvent("DBM_CREATE_CACHE")
			FireUIEvent("DBMUI_DATA_RELOAD")
			collectgarbage("collect")
			return true, path
		end
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
	local root, path = GetRootPath(), "/interface/JH/DBM/data/" .. config.szFileName
	root = root:gsub("\\", "/")
	if config.bJson then
		SaveLUAData(path, JH.JsonEncode(data, config.bFormat))
	else
		SaveLUAData(path, data, config.bFormat and "\t")
	end
	collectgarbage("collect")
	return root .. path
end

function D.GetFileData()
	return D.FILE
end

-- 删除 移动 添加 清空
function D.RemoveData(szType, dwMapID, nIndex)
	if D.FILE[szType][dwMapID] and D.FILE[szType][dwMapID][nIndex] then
		table.remove(D.FILE[szType][dwMapID], nIndex)
		if #D.FILE[szType][dwMapID] == 0 then
			D.FILE[szType][dwMapID] = nil
		end
		if dwMapID == -1 or dwMapID == GetClientPlayer().GetMapID() then
			FireUIEvent("DBM_CREATE_CACHE")
		end
		FireUIEvent("DBMUI_DATA_RELOAD", szType)
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
		table.insert(D.FILE[szType][dwTargetMapID], clone(D.FILE[szType][dwMapID][nIndex]))
		if not bCopy then
			D.RemoveData(szType, dwMapID, nIndex)
		end
		FireUIEvent("DBM_CREATE_CACHE")
		FireUIEvent("DBMUI_DATA_RELOAD", szType)
	end
end

function D.AddData(szType, dwMapID, data)
	D.FILE[szType][dwMapID] = D.FILE[szType][dwMapID] or {}
	table.insert(D.FILE[szType][dwMapID], data)
	FireUIEvent("DBM_CREATE_CACHE")
	FireUIEvent("DBMUI_DATA_RELOAD", szType)
	return D.FILE[szType][dwMapID][#D.FILE[szType][dwMapID]]
end

function D.ClearTemp(szType)
	if szType == "CIRCLE" then -- 如果请求圈圈的近期数据 返回NPC的
		szType = "NPC"
	end
	-- D.Log(szType .. " cache clear!")
	D.TEMP[szType] = {}
	collectgarbage("collect")
	FireUIEvent("DBMUI_TEMP_RELOAD")
end
-- 公开接口
local ui = {
	Enable            = D.Enable,
	GetTable          = D.GetTable,
	GetDungeon        = D.GetDungeon,
	GetData           = D.GetData,
	GetFileData       = D.GetFileData,
	RemoveData        = D.RemoveData,
	MoveData          = D.MoveData,
	CheckRepeatData   = D.CheckRepeatData,
	ClearTemp         = D.ClearTemp,
	AddData           = D.AddData,
	SaveConfigureFile = D.SaveConfigureFile,
	LoadConfigureFile = D.LoadConfigureFile,
}
DBM_API = setmetatable({}, { __index = ui, __newindex = function() end, __metatable = true })

JH.RegisterEvent("LOGIN_GAME", D.Init)
JH.RegisterEvent("LOADING_END", D.LoadUserData)
JH.RegisterEvent("GAME_EXIT", D.SaveData)
JH.RegisterEvent("PLAYER_EXIT_GAME", D.SaveData)
