-- @Author: Webster
-- @Date:   2015-05-13 16:06:53
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-23 01:13:06

-- 简单性能测试统计：
-- +------------------------------------------------------------------+
-- |   测试项目   | 插件名称 | 执行次数 | 耗时(ms) |       备注       |
-- +------------------------------------------------------------------+
-- | BUFF_UPDATE  |   DBM    |  1,0000  |  32      |  命中缓存        |
-- | BUFF_UPDATE  |   DBM    |  1,0000  |  63      |  创建报警        |
-- | BUFF_UPDATE  |   RGES   |  1,0000  |  217     |  创建报警        |
-- | BUFF_UPDATE  |   RGES   |  1,0000  |  422     |  优化之前的版本  |
-- | 近期记录     |   DBM    |  1,0000  |  71      |                  |
-- | 近期记录     |   DBM    |  1,0000  |  636     |  自动执行gc      |
-- | 近期记录     |   RGES   |  1,0000  |  2134    |                  |
-- | 近期记录     |   RGES   |  1,0000  |  2676    |  优化之前的版本  |
-- | 内存占用     |   DBM    |   ----   |          |  约 100  KB      |
-- | 内存占用     |   RGES   |   ----   |          |  约 1300 KB      |
-- +------------------------------------------------------------------+

-- 性能测试总结：
-- 由于 RGES 也经过我的优化 性能差距不是非常大
-- 但是 DBM 功能和灵活度远超于 RGES
-- RGES 是时候退出历史舞台了

local _L = JH.LoadLangPack
local ipairs, pairs = ipairs, pairs
local setmetatable, tonumber, type, tostring, unpack = setmetatable, tonumber, type, tostring, unpack
local tinsert, tconcat = table.insert, table.concat
local GetTime, IsPlayer = GetTime, IsPlayer
local GetClientPlayer, GetClientTeam, GetPlayer, GetNpc = GetClientPlayer, GetClientTeam, GetPlayer, GetNpc
local FireEvent, Table_BuffIsVisible, Table_IsSkillShow = FireEvent, Table_BuffIsVisible, Table_IsSkillShow
local GetPureText = GetPureText
local JH_Split, JH_Trim = JH.Split, JH.Trim
local DBM_PLAYER_NAME = "NONE"
local DBM_TYPE, DBM_SCRUTINY_TYPE = DBM_TYPE, DBM_SCRUTINY_TYPE
local DBM_MAX_CACHE = 1000 -- 最大的cache数量 主要是UI的问题
local DBM_DEL_CACHE = 500  -- 每次清理的数量 然后会做一次gc
local DBM_INIFILE  = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM.ini"
local function GetDataPath()
	return "DBM/" .. DBM_PLAYER_NAME .. "/DBM.jx3dat"
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
	bPushbScreenHead    = true,
	bPushCenterAlarm    = true,
	bPushbBigFontAlarm  = true,
	bBigFontAlarm       = true,
	bPushTeamPanel      = true, -- 面板buff监控
	bPushFullScreen     = true, -- 全屏泛光
	bPushTeamChannel    = true, -- 团队报警
	bPushWhisperChannel = true, -- 密聊报警
	bPushBuffList       = true,
	bMonSkillTarget     = true,
}

local DBM = DBM

function DBM.OnFrameCreate()
	this:RegisterEvent("NPC_ENTER_SCENE")
	this:RegisterEvent("NPC_LEAVE_SCENE")
	this:RegisterEvent("BUFF_UPDATE")
	this:RegisterEvent("SYS_MSG")
	this:RegisterEvent("DO_SKILL_CAST")
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("DBM_CREATE_CACHE")
	this:RegisterEvent("PLAYER_SAY")
	this:RegisterEvent("JH_NPC_FIGHT")
	this:RegisterEvent("JH_NPC_ALLLEAVE_SCENE")
	this:RegisterEvent("ON_WARNING_MESSAGE")
	this:RegisterEvent("JH_NPC_LIFE_CHANGE")
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
	elseif szEvent == "PLAYER_SAY" then
		if not IsPlayer(arg1) then
			D.OnCallMessage(GetPureText(arg0), arg3)
		end
	elseif szEvent == "ON_WARNING_MESSAGE" then
		D.OnCallMessage(arg1)
	elseif szEvent == "NPC_ENTER_SCENE" then
		local npc = GetNpc(arg0)
		if npc then
			D.OnNpcEvent(npc, true)
		end
	elseif szEvent == "NPC_LEAVE_SCENE" then
		local npc = GetNpc(arg0)
		if npc then
			D.OnNpcEvent(npc, false)
		end
	elseif szEvent == "JH_NPC_ALLLEAVE_SCENE" then
		D.OnNpcAllLeave(arg0)
	elseif szEvent == "JH_NPC_FIGHT" then
		-- Output(arg0, arg1)
		D.OnNpcFight(arg0, arg1)
	elseif szEvent == "JH_NPC_LIFE_CHANGE" then
		D.OnNpcLife(arg0, arg1)
	elseif szEvent == "LOADING_END" or szEvent == "DBM_CREATE_CACHE" then
		D.CreateData(szEvent)
	end
end

function D.Log(szMsg)
	if JH.bDebug then
		Log("[DBM] " .. szMsg)
	end
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
	D.Log("Create " .. szType .. " data Success!")
end

local function CreateTalkData(dwMapID)
	-- 单独重建TALK数据
	local talk = D.FILE.TALK
	if talk[-1] then -- 通用数据
		for k, v in ipairs(talk[-1]) do
			D.DATA.TALK[#talk + 1] = v
		end
	end
	if talk[dwMapID] then -- 本地图数据
		for k, v in ipairs(talk[-1]) do
			D.DATA.TALK[#talk + 1] = v
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
	if szEvent == "LOADING_END" then
		CACHE.NPC_LIST   = {}
		CACHE.SKILL_LIST = {}
	end
	D.Log("MAPID: " .. dwMapID ..  " Create data Succeed:" .. GetTime() - nTime  .. "ms")
end

function D.FreeCache(szType)
	D.Log(szType .. " cache clear!")
	local t = {}
	local tTemp = D.TEMP[szType]
	for i = DBM_DEL_CACHE, #tTemp do
		t[#t + 1] = tTemp[i]
	end
	D.TEMP[szType] = t
	collectgarbage("collect")
	FireEvent("DBMUI_TEMP_RELOAD", szType)
end

function D.CheckScrutinyType(nScrutinyType, dwID)
	if nScrutinyType == DBM_SCRUTINY_TYPE.SELF and dwID ~= UI_GetClientPlayerID() then
		return false
	elseif nScrutinyType == DBM_SCRUTINY_TYPE.TEAM and not JH.IsParty(dwID) then
		return false
	elseif nScrutinyType == DBM_SCRUTINY_TYPE.ENEMY and not IsEnemy(UI_GetClientPlayerID(), dwID) then
		return false
	end
	return true
end

-- 智能标记逻辑
-- 例 勾选了 白云 红谷 棒槌
-- 如果是NPC   从头抓到尾 比如白云不是这个NPC  那就把白云给他 如果是的话 就给红谷 以此类推
-- 如果是BUFF  从头抓到尾 比如白云没有这个BUFF 那就把白云给他 如果是的话 就给红谷 以此类推
-- 如果是技能 无条件给标记
function D.SetTeamMark(szType, tMark, dwCharacterID, dwID, nLevel)
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
-- 倒计时处理 支持定义无限的倒计时
function D.FireCountdownEvent(data, nClass)
	if data.tCountdown then
		for k, v in ipairs(data.tCountdown) do
			if nClass == v.nClass then
				FireEvent("JH_ST_CREATE", nClass, v.key or (k .. "." .. (data.dwID or 0) .. "." .. (data.nLevel or 0)), {
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

-- 通用的事件发送
function D.FireAlertEvent(data, cfg, xml, dwID, nClass)
	-- 中央报警
	if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
		FireEvent("JH_CA_CREATE", tconcat(xml), 3, true)
	end
	-- 特大文字
	if DBM.bBigFontAlarm and cfg.bBigFontAlarm then
		local txt = GetPureText(tconcat(xml))
		FireEvent("JH_LARGETEXT", txt, { GetHeadTextForceFontColor(dwID, UI_GetClientPlayerID()) }, UI_GetClientPlayerID() == dwID )
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
					bIsPlayer = IsPlayer(dwSkillSrcID)
				}
				tWeak[key] = t
				tTemp[#tTemp + 1] = tWeak[key]
				if #tTemp > DBM_MAX_CACHE then
					D.FreeCache(szType)
				else
					FireEvent("DBMUI_TEMP_UPDATE", szType, t)
				end
			end
		end
	end
	if data then
		if data.nScrutinyType and not D.CheckScrutinyType(data.nScrutinyType, dwCaster) then -- 监控对象检查
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
				return D.Log("ERROR " .. szType .. " object:" .. dwCaster .. " does not exist!")
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
			-- 通用的报警事件处理
			D.FireAlertEvent(data, cfg, xml, dwCaster, nClass)
			-- 获得处理
			if nClass == DBM_TYPE.BUFF_GET then
				if JH.bDebugClient and cfg.bSelect then
					SetTarget(IsPlayer(dwCaster) and TARGET.PLAYER or TARGET.NPC, dwCaster)
				end
				if cfg.tMark then
					D.SetTeamMark(szType, cfg.tMark, dwCaster, dwBuffID, nBuffLevel)
				end
				-- 重要Buff列表
				if IsPlayer(dwCaster) and cfg.bPartyBuffList and (JH.IsParty(dwCaster) or me.dwID == dwCaster) then
					FireEvent("JH_PARTYBUFFLIST", dwCaster, data.dwID, data.nLevel)
				end
				-- 头顶报警
				if DBM.bPushbScreenHead and cfg.bScreenHead then
					FireEvent("JH_SCREENHEAD", dwCaster, { type = szType, dwID = data.dwID, szName = data.szName or szName, col = data.col })
				end
				if me.dwID == dwCaster then
					if DBM.bPushBuffList and cfg.bBuffList then
						-- TODO push BUFF状态栏
					end
					-- 全屏泛光
					if DBM.bPushFullScreen and cfg.bFullScreen then
						FireEvent("JH_FS_CREATE", data.dwID .. "_"  .. data.nLevel, {
							nTime = 3,
							col = data.col,
							tBindBuff = { data.dwID, data.nLevel }
						})
					end
				end
				-- 添加到团队面板
				if DBM.bPushTeamPanel and cfg.bTeamPanel and ( not cfg.bOnlySelfSrc or dwSkillSrcID == me.dwID) then
					FireEvent("JH_RAID_REC_BUFF", dwCaster, data.dwID, data.nLevel, data.col)
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
				bIsPlayer = IsPlayer(dwCaster)
			}
			tWeak[key] = t
			tTemp[#tTemp + 1] = tWeak[key]
			if #tTemp > DBM_MAX_CACHE then
				D.FreeCache("CASTING")
			else
				FireEvent("DBMUI_TEMP_UPDATE", "CASTING", t)
			end
		end
	end
	-- 监控数据
	if data then
		if data.nScrutinyType and not D.CheckScrutinyType(data.nScrutinyType, dwCaster) then -- 监控对象检查
			return
		end
		local szName, nIcon = JH.GetSkillName(dwCastID, dwLevel)
		local KObject = IsPlayer(dwCaster) and GetPlayer(dwCaster) or GetNpc(dwCaster)
		if not KObject then
			return D.Log("ERROR CASTING object:" .. dwCaster .. " does not exist!")
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
			if DBM.bMonSkillTarget and szTargetName then
				tinsert(xml, GetFormatText(g_tStrings.TARGET, 44, 255, 255, 255))
				tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
				tinsert(xml, GetFormatText(szTargetName == me.szName and g_tStrings.STR_YOU or szTargetName, 44, 255, 255, 0))
				tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
			end
			if data.szNote then
				tinsert(xml, " " .. GetFormatText(data.szNote, 44, 255, 255, 255))
			end
			local txt = GetPureText(tconcat(xml))
			-- 通用的报警事件处理
			D.FireAlertEvent(data, cfg, xml, dwCaster, nClass)
			if JH.bDebugClient and cfg.bSelect then
				SetTarget(IsPlayer(dwCaster) and TARGET.PLAYER or TARGET.NPC, dwCaster)
			end
			if cfg.tMark then
				D.SetTeamMark("CASTING", cfg.tMark, dwCaster, dwSkillID, dwLevel)
			end
			-- 头顶报警
			if DBM.bPushbScreenHead and cfg.bScreenHead then
				FireEvent("JH_SCREENHEAD", dwCaster, { type = "CASTING", txt = data.szName or szName, col = data.col })
			end
			-- 全屏泛光
			if DBM.bPushFullScreen and cfg.bFullScreen then
				FireEvent("JH_FS_CREATE", data.dwID .. "#SKILL#"  .. data.nLevel, { nTime = 3, col = data.col})
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
				FireEvent("DBMUI_TEMP_UPDATE", "NPC", t)
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
							FireEvent("JH_NPC_FIGHT", npc.dwTemplateID, false, nTime)
						end
						CACHE.NPC_LIST[npc.dwTemplateID] = nil
						FireEvent("JH_NPC_ALLLEAVE_SCENE", npc.dwTemplateID)
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
			if data.nCount and data.nCount > #CACHE.NPC_LIST[npc.dwTemplateID].tList then
				return
			end
			if cfg then
				if cfg.tMark then
					D.SetTeamMark("NPC", cfg.tMark, npc.dwID, npc.dwTemplateID)
				end
				if cfg.bScreenHead then
					FireEvent("JH_SCREENHEAD", npc.dwID, { type = "Object", txt = data.szNote, col = data.col })
				end
			end
			if nTime - CACHE.NPC_LIST[npc.dwTemplateID].nTime < 500 then -- 0.5秒内进入相同的NPC直接忽略
				return D.Log("IGNORE NPC ENTER SCENE ID:" .. npc.dwTemplateID .. " TIME:" .. nTime .. " TIME2:" .. CACHE.NPC_LIST[npc.dwTemplateID].nTime)
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
			D.FireAlertEvent(data, cfg, xml, dwCaster, nClass)
			if DBM.bPushTeamChannel and cfg.bTeamChannel then
				JH.Talk(txt)
			end
			if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
				D.FireTeamWhisper(txt)
			end
			local txt = GetPureText(tconcat(xml))
			if nClass == DBM_TYPE.NPC_ENTER then
				if JH.bDebugClient and cfg.bSelect then
					SetTarget(TARGET.NPC, npc.dwID)
				end
				if DBM.bPushFullScreen and cfg.bFullScreen then
					FireEvent("JH_FS_CREATE", "NPC", { nTime  = 3, col = data.col, bFlash = true })
				end
			end
		end
	end
end

-- 系统和NPC喊话处理
function D.OnCallMessage(szContent, szNpcName)
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
			FireEvent("DBMUI_TEMP_UPDATE", "TALK", t)
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
				if szContent:match(c:gsub("$team", team.GetClientTeamMemberName(vv))) and v.szTarget == szNpcName then -- hit
					tInfo = { dwID = vv, szName = team.GetClientTeamMemberName(vv) }
					bHit = true
					break
				end
			end
		else
			if szContent:match(content) and v.szTarget == szNpcName then -- hit
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
					if cfg.bScreenHead then
						FireEvent("JH_SCREENHEAD", tInfo.dwID, { txt = _L("%s Call Name", szNpcName or g_tStrings.SYSTEM)})
					end
					if JH.bDebugClient and cfg.bSelect then
						SetTarget(TARGET.PLAYER, tInfo.dwID)
					end
				end

				-- 中央报警
				if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
					FireEvent("JH_CA_CREATE", #xml > 0 and tconcat(xml) or txt, 3, #xml > 0)
				end
				-- 特大文字
				if DBM.bBigFontAlarm and cfg.bBigFontAlarm then
					FireEvent("JH_LARGETEXT", txt, { 255, 128, 0 }, true )
				end
				if DBM.bPushFullScreen and cfg.bFullScreen then
					FireEvent("JH_FS_CREATE", "TALK", { nTime  = 3, col = v.col or { 0, 255, 0 }, bFlash = true })
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
			JH.DelayCall(300, function() -- 因为击杀的时候并没有直接消失
				if not CACHE.NPC_LIST[dwTemplateID] then
					D.FireCountdownEvent(data, DBM_TYPE.NPC_ALLDEATH)
				end
			end)
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
						FireEvent("JH_ST_DEL", v.nClass, v.key or (k .. "."  .. data.dwID .. "." .. (data.nLevel or 0)), true) -- try kill
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
				local t = JH_Split(tTime, ";")
				for kk, vv in ipairs(t) do
					local time = JH_Split(v, ",")
					if time[1] and time[2] and time[3] and tonumber(JH_Trim(time[1])) and tonumber(JH_Trim(time[2])) and JH_Trim(time[3]) ~= "" then
						if tonumber(JH_Trim(time[1])) == nLife then -- hit
							FireEvent("JH_ST_CREATE", DBM_TYPE.NPC_LIFE, v.key or (k .. "." .. dwTemplateID .. "." .. kk), {
								nTime    = tonumber(JH_Trim(time[2])),
								szName   = time[3],
								nIcon    = v.nIcon,
								bTalk    = DBM.bPushTeamChannel and v.bTeamChannel
							})
							if DBM.bPushCenterAlarm then
								FireEvent("JH_CA_CREATE", time[3], 3, true)
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
					FireEvent("JH_NPC_LIFE_CHANGE", k, v.nLife - i)
				end
			end
			v.nLife = fNpcPer
			if bFightFlag then
				local nTime = GetTime()
				v.nSec = GetTime()
				FireEvent("JH_NPC_FIGHT", k, true, nTime)
			elseif bFightFlag == false then
				local nTime = GetTime() - (v.nSec or GetTime())
				v.nSec = nil
				FireEvent("JH_NPC_FIGHT", k, false, nTime)
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
	end
end

function D.Enable(bEnable)
	if bEnable then
		local res, err = pcall(D.Open)
		if not res then
			JH.Sysmsg2(err)
		end
	else
		D.Close()
	end
end

function D.Init()
	if DBM_PLAYER_NAME == "NONE" then
		local me = GetClientPlayer()
		if me and not IsRemotePlayer(me.dwID) then
			DBM_PLAYER_NAME = me.szName
			local data = JH.LoadLUAData(GetDataPath())
			if data then
				for k, v in pairs(D.FILE) do
					D.FILE[k] = data[k] or {}
				end
			end
		end
	end
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
			return a.dwMapID > b.dwMapID
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
	D.Log("LOOKUP TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
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
				if data and data.dwID == dwID and (not data.bheckLevel or data.nLevel == nLevel) then
					D.Log("HIT TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
					return data
				else
					D.Log("RELOOKUP TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
					return GetData(tab, szType, dwID, nLevel)
				end
			else -- 不能直接命中的情况下 遍历下面的level /(ㄒoㄒ)/~~
				for k, v in pairs(cache) do
					local data = tab[cache[k]]
					if data and data.dwID == dwID and (not data.bheckLevel or data.nLevel == nLevel) then -- 能直接命中是最好了 ;-)
						D.Log("HIT TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
						return data
					else -- 不能命中的话 就一次机会 直接lookup
						D.Log("RELOOKUP TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. nLevel)
						return GetData(tab, szType, dwID, k) -- 这里必须传k 不要乱改 O__O "…"
					end
				end
			end
		else
			local data = tab[cache]
			if data and data.dwID == dwID then
				D.Log("HIT TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:0")
				return data
			else
				D.Log("RELOOKUP TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:0")
				return GetData(tab, szType, dwID)
			end
		end
	else
		-- D.Log("IGNORE TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. (nLevel or 0))
	end
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
			FireEvent("DBM_CREATE_CACHE")
		end
		FireEvent("DBMUI_DATA_RELOAD", szType)
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
		FireEvent("DBM_CREATE_CACHE")
		FireEvent("DBMUI_DATA_RELOAD", szType)
		JH.Sysmsg(_L["Succeed"])
	end
end

function D.AddData(szType, dwMapID, data)
	D.FILE[szType][dwMapID] = D.FILE[szType][dwMapID] or {}
	table.insert(D.FILE[szType][dwMapID], data)
	FireEvent("DBM_CREATE_CACHE")
	FireEvent("DBMUI_DATA_RELOAD", szType)
	JH.Sysmsg(_L["Succeed"])
	return D.FILE[szType][dwMapID][#D.FILE[szType][dwMapID]]
end

function D.ClearTemp(szType)
	if szType == "CIRCLE" then -- 如果请求圈圈的近期数据 返回NPC的
		szType = "NPC"
	end
	D.Log(szType .. " cache clear!")
	D.TEMP[szType] = {}
	collectgarbage("collect")
	FireEvent("DBMUI_TEMP_RELOAD")
end
-- 公开接口
local ui = {
	GetTable        = D.GetTable,
	GetDungeon      = D.GetDungeon,
	GetData         = D.GetData,
	GetFileData     = D.GetFileData,
	RemoveData      = D.RemoveData,
	MoveData        = D.MoveData,
	CheckRepeatData = D.CheckRepeatData,
	ClearTemp       = D.ClearTemp,
	AddData         = D.AddData
}
DBM_API = setmetatable({}, { __index = ui, __newindex = function() end, __metatable = true })

JH.RegisterEvent("LOADING_END", D.Init)
JH.RegisterEvent("GAME_EXIT", D.SaveData)
JH.RegisterEvent("PLAYER_EXIT_GAME", D.SaveData)
