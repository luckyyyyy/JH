-- @Author: Webster
-- @Date:   2015-05-13 16:06:53
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-17 19:43:18
local _L = JH.LoadLangPack
local DEBUG = true
local DBM_TYPE = DBM_TYPE or {
	OTHER       = 0,
	BUFF_GET    = 1,
	BUFF_LOSE   = 2,
	NPC_ENTER   = 3,
	NPC_LEAVE   = 4,
	NPC_TALK    = 5,
	NPC_LIFE    = 6,
	NPC_FIGHT   = 7,
	SKILL_BEGIN = 8,
	SKILL_END   = 9,
	SYS_TALK    = 10,
}
local DBM_SCRUTINY_TYPE = { SELF  = 1, TEAM  = 2, ENEMY = 3 }
local DBM_MAX_CACHE = 1000 -- 最大的cache数量 主要是UI的问题
local DBM_DEL_CACHE = 500  -- 每次清理的数量 然后会做一次gc
local DBM_DATAPATH = JH.GetAddonInfo().szDataPath
local DBM_INIFILE  = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM.ini"
local CACHE = {
	TEMP = { -- 近期事件记录MAP 这里用弱表 方便处理
		BUFF    = setmetatable({}, { __mode = "v" }),
		DEBUFF  = setmetatable({}, { __mode = "v" }),
		CASTING = setmetatable({}, { __mode = "v" }),
		NPC     = setmetatable({}, { __mode = "v" }),
	},
	MAP = { -- 需要监控的数据MAP
		BUFF    = {},
		DEBUFF  = {},
		CASTING = {},
		NPC     = {},
	},
	NPC_FIGHT = {}
}
local D = {
	tDungeonList = {},
	FILE = { -- 文件原始数据
		BUFF    = {
			[-1] = {
				{ dwID = 103, nLevel = 1, [DBM_TYPE.BUFF_GET] = { bCenterAlarm = true }, [DBM_TYPE.BUFF_LOSE] = { bCenterAlarm = true } },
				{ dwID = 208, nLevel = 1 },
				{ dwID = 208, nLevel = 2 },
				{ dwID = 208, nLevel = 3 },
				{ dwID = 208, nLevel = 4 },
				{ dwID = 208, nLevel = 5 },
				{ dwID = 208, nLevel = 6 },
				{ dwID = 208, nLevel = 7 },
				{ dwID = 208, nLevel = 8 },
				{ dwID = 208, nLevel = 9 },
				{ dwID = 208, nLevel = 10 },
				{ dwID = 208, nLevel = 11 },
				{ dwID = 6243, nLevel = 1 },
				{ dwID = 112, nLevel = 4 },
				{ dwID = 112, nLevel = 1 },
				{ dwID = 208, nLevel = 3 },
				{ dwID = 208, nLevel = 5 },
			}
		},
		DEBUFF  = {},
		CASTING = {},
		NPC     = {
			[-1] = {
				{ dwID = 17189, nFrame = 1, [DBM_TYPE.NPC_ENTER] = { bCenterAlarm = true }, [DBM_TYPE.NPC_LEAVE] = { bCenterAlarm = true } },
				{ dwID = 4980, nFrame = 1, [DBM_TYPE.NPC_ENTER] = { bCenterAlarm = true }, [DBM_TYPE.NPC_LEAVE] = { bCenterAlarm = true } },
				{ dwID = 4981, nFrame = 1, [DBM_TYPE.NPC_ENTER] = { bCenterAlarm = true }, [DBM_TYPE.NPC_LEAVE] = { bCenterAlarm = true } },
				{ dwID = 4976, nFrame = 1, [DBM_TYPE.NPC_ENTER] = { bCenterAlarm = true }, [DBM_TYPE.NPC_LEAVE] = { bCenterAlarm = true } },
				{ dwID = 9891, nFrame = 1, [DBM_TYPE.NPC_ENTER] = { bCenterAlarm = true }, [DBM_TYPE.NPC_LEAVE] = { bCenterAlarm = true } },
				{ dwID = 14310, nFrame = 1, [DBM_TYPE.NPC_ENTER] = { bCenterAlarm = true }, [DBM_TYPE.NPC_LEAVE] = { bCenterAlarm = true } },
				{ dwID = 14311, nFrame = 1, [DBM_TYPE.NPC_ENTER] = { bCenterAlarm = true }, [DBM_TYPE.NPC_LEAVE] = { bCenterAlarm = true } },
			}
		},
		TALK    = {},
	},
	TEMP = { -- 近期事件记录
		BUFF    = {},
		DEBUFF  = {},
		CASTING = {},
		NPC     = {},
	},
	DATA = { -- 需要监控的数据合集
		BUFF    = {},
		DEBUFF  = {},
		CASTING = {},
		NPC     = {},
		TALK    = {},
	}
}

do
	for k, v in pairs(D.FILE)  do
		setmetatable(D.FILE[k], { __index = function(me, index)
			if index == "ALL" then
				local t = {}
				for k, v in pairs(D.FILE[k]) do
					for _, vv in ipairs(v) do
						t[#t +1] = vv
					end
				end
				return t
			end
		end })
	end
end

DBM = {
	bEnable = true,
	bPushbScreenHead = true,
	bPushCenterAlarm = true,
	bPushbBigFontAlarm = true,
	bPushTeamPanel = true, -- 面板buff监控
	bPushFullScreen = true, -- 全屏泛光
	bPushTeamChannel = false, -- 团队报警
	bPushWhisperChannel = false, -- 密聊报警
	bMonSkillTarget = false,
}

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
	this:RegisterEvent("ON_WARNING_MESSAGE")
end

function DBM.OnFrameBreathe()
	D.CheckNpcFightState()
end

function DBM.OnEvent(szEvent)
	if szEvent == "BUFF_UPDATE" then
		D.OnBuff(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	elseif szEvent == "SYS_MSG" then
		if arg0 == "UI_OME_SKILL_CAST_LOG" then
			D.OnSkillCast(arg1, arg2, arg3, arg0)
		elseif (arg0 == "UI_OME_SKILL_BLOCK_LOG" or arg0 == "UI_OME_SKILL_SHIELD_LOG"
		or arg0 == "UI_OME_SKILL_MISS_LOG" or arg0 == "UI_OME_SKILL_DODGE_LOG"
		or arg0 == "UI_OME_SKILL_HIT_LOG")
		and arg3 == SKILL_EFFECT_TYPE.SKILL then
			D.OnSkillCast(arg1, arg4, arg5, arg0)
		elseif arg0 == "UI_OME_SKILL_EFFECT_LOG" and arg4 == SKILL_EFFECT_TYPE.SKILL then
			D.OnSkillCast(arg1, arg5, arg6, arg0)
		end
	elseif szEvent == "DO_SKILL_CAST" then
		D.OnSkillCast(arg0, arg1, arg2, szEvent)
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
	elseif szEvent == "JH_NPC_FIGHT" then

	elseif szEvent == "LOADING_END" or szEvent == "DBM_CREATE_CACHE" then
		D.CreateData()
	end
end

function D.Log(szMsg)
	if DEBUG then
		Log("[DBM] " .. szMsg)
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

function D.CreateData()
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
	for _, szType in ipairs({ "BUFF", "DEBUFF", "CASTING", "NPC", "TALK" }) do
		local data  = D.DATA[szType]
		local cache = CACHE.MAP[szType]
		if D.FILE[szType][-1] then -- 通用数据
			CreateCache(szType, D.FILE[szType][-1])
		end
		if D.FILE[szType][dwMapID] then -- 本地图数据
			CreateCache(szType, D.FILE[szType][dwMapID])
		end
	end
	D.Log("MAPID: " .. dwMapID ..  " Create data Success:" .. GetTime() - nTime  .. "ms")
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

-- 通用的事件发送
function D.FireAlertEvent(data, cfg, xml, dwID, nClass)
	-- 中央报警
	if DBM.bPushCenterAlarm and cfg.bCenterAlarm then
		FireEvent("JH_CA_CREATE", table.concat(xml), 3, true)
	end
	-- 特大文字
	if DBM.bBigFontAlarm and cfg.bBigFontAlarm then
		local txt = GetPureText(table.concat(xml))
		FireEvent("JH_LARGETEXT", txt, { GetHeadTextForceFontColor(dwID, UI_GetClientPlayerID()) }, UI_GetClientPlayerID() == dwID )
	end
	-- 倒计时处理 支持定义无限的倒计时
	if cfg.tCountdown then
		for k, v in ipairs(cfg.tCountdown) do
			FireEvent("JH_ST_CREATE", nClass, k .. "." .. data.dwID .. "." .. (data.nLevel or 0), {
				nTime  = v.nTime,
				szName = v.szName or data.szName,
				nIcon  = v.nIocn or data.nIocn,
				bTalk  = DBM.bPushTeamChannel and v.bTeamChannel
			})
		end
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
	if data then
		if bDelete then
			cfg, nClass = data[DBM_TYPE.BUFF_LOSE], DBM_TYPE.BUFF_LOSE
		else
			cfg, nClass = data[DBM_TYPE.BUFF_GET], DBM_TYPE.BUFF_GET
		end
	end
	if cfg then
		if data.nScrutinyType and not D.CheckScrutinyType(data.nScrutinyType, dwCaster) then -- 监控对象检查
			return
		end
		if data.nCount and nCount < data.nCount then -- 层数检查
			return
		end
		local szName, nIcon = JH.GetBuffName(dwBuffID, nBuffLevel)
		local KObject = IsPlayer(dwCaster) and GetPlayer(dwCaster) or GetNpc(dwCaster)
		if not KObject then
			return D.Log("ERROR " .. szType .. " object:" .. dwCaster .. " does not exist!")
		end
		szName = data.szName or szName
		nIcon  = data.nIcon or nIcon
		local szSrcName = JH.GetTemplateName(KObject)
		local xml = {}
		table.insert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
		if UI_GetClientPlayerID() == dwMemberID then
			table.insert(xml, GetFormatText(g_tStrings.STR_YOU, 44, 255, 255, 0))
		else
			table.insert(xml, GetFormatText(szSrcName, 44, 255, 255, 0))
		end
		table.insert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
		if nClass == DBM_TYPE.BUFF_GET then
			table.insert(xml, GetFormatText(_L["Get Buff"], 44, 255, 255, 255))
			table.insert(xml, GetFormatText(szName .. " x" .. nCount, 44, 255, 255, 0))
			if data.szNote then
				table.insert(xml, GetFormatText(" " .. data.szNote, 44, 255, 255, 255))
			end
		else
			table.insert(xml, GetFormatText(_L["Lose Buff"], 44, 255, 255, 255))
			table.insert(xml, GetFormatText(szName, 44, 255, 255, 0))
		end
		local txt = GetPureText(table.concat(xml))
		-- 通用的报警事件处理
		D.FireAlertEvent(data, cfg, xml, dwCaster, nClass)
		-- 获得处理
		if nClass == DBM_TYPE.BUFF_GET then
			-- 重要Buff列表
			if IsPlayer(dwCaster) and cfg.bPartyBuffList and (JH.IsParty(dwCaster) or UI_GetClientPlayerID() == dwCaster) then
				FireEvent("JH_PARTYBUFFLIST", dwCaster, data.dwID, data.nLevel)
			end
			-- 头顶报警
			if DBM.bPushbScreenHead and cfg.bScreenHead then
				FireEvent("JH_SCREENHEAD", dwCaster, { type = szType, dwID = data.dwID, szName = data.szName or szName, col = data.col })
			end
			if UI_GetClientPlayerID() == dwCaster then
				-- TODO push BUFF状态栏
				-- 全屏泛光
				if cfg.bPushFullScreen and DBM.bPushFullScreen then
					FireEvent("JH_FS_CREATE", data.dwID .. "_"  .. data.nLevel, {
						nTime = 3,
						col = data.col,
						tBindBuff = { data.dwID, data.nLevel }
					})
				end
			end
			-- 添加到团队面板
			if DBM.bPushTeamPanel and cfg.bPushTeamPanel and ( not cfg.bOnlySelfSrc or dwSkillSrcID == UI_GetClientPlayerID()) then
				FireEvent("JH_RAID_REC_BUFF", dwCaster, dwBuffID, nLevel, data.col)
			end
		end
		if DBM.bPushTeamChannel and cfg.bTeamChannel then
			JH.Talk(txt)
		end
		if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
			JH.Talk(szSrcName, txt:gsub(szSrcName, g_tString.STR_NAME_YOU))
		end
	end
end
-- 技能事件
function D.OnSkillCast(dwCaster, dwCastID, dwLevel, szEvent)
	local tWeak, tTemp = CACHE.TEMP.CASTING, D.TEMP.CASTING
	local key = dwCastID .. "_" .. dwLevel
	local me = GetClientPlayer()
	local data = D.GetData("CASTING", dwCastID, dwLevel)
	if not tWeak[key] then
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
			if cfg then
				local cfg = data[DBM_TYPE.SKILL_BEGIN]
				local xml = {}
				table.insert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
				table.insert(xml, GetFormatText(szSrcName, 44, 255, 255, 0))
				table.insert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
				if nClass == DBM_TYPE.SKILL_END then
					table.insert(xml, GetFormatText(_L["use of"], 44, 255, 255, 255))
				else
					table.insert(xml, GetFormatText(_L["Building"], 44, 255, 255, 255))
				end
				table.insert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
				table.insert(xml, GetFormatText(szName, 44, 255, 255, 0))
				table.insert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
				if DBM.bMonSkillTarget and szTargetName then
					table.insert(xml, GetFormatText(g_tStrings.TARGET, 44, 255, 255, 255))
					table.insert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
					if me.dwID == dwTargetID then
						table.insert(xml, GetFormatText(g_tStrings.STR_YOU, 44, 255, 255, 0))
					else
						table.insert(xml, GetFormatText(szTargetName, 44, 255, 255, 0))
					end
					table.insert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
				end
				if data.szNote then
					table.insert(xml, " " .. GetFormatText(data.szNote, 44, 255, 255, 255))
				end
				-- 通用的报警事件处理
				D.FireAlertEvent(data, cfg, xml, dwCaster, nClass)
				-- 头顶报警
				if DBM.bPushbScreenHead and cfg.bScreenHead then
					FireEvent("JH_SCREENHEAD", dwCaster, { type = "CASTING", txt = data.szName or szName, col = data.col })
				end
				-- 全屏泛光
				if cfg.bPushFullScreen and DBM.bPushFullScreen then
					FireEvent("JH_FS_CREATE", data.dwID .. "#SKILL#"  .. data.nLevel, { nTime = 3, col = data.col})
				end
				if DBM.bPushTeamChannel and cfg.bTeamChannel then
					JH.Talk(txt)
				end
				if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
					--TODO 全团密聊
				end
			end
		end
	end
end

-- NPC事件
function D.OnNpcEvent(npc, bEnter)
	local me = GetClientPlayer()
	local data = D.GetData("NPC", npc.dwTemplateID)
	local cfg, nClass
	if bEnter then
		-- 战斗状态检查入表
		CACHE.NPC_FIGHT[npc.dwTemplateID] = CACHE.NPC_FIGHT[npc.dwTemplateID] or { bFightState = false, tList = {} }
		table.insert(CACHE.NPC_FIGHT[npc.dwTemplateID].tList, npc.dwID)
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
	end
	if data then
		if bEnter then
			cfg, nClass = data[DBM_TYPE.NPC_ENTER], DBM_TYPE.NPC_ENTER
		else
			cfg, nClass = data[DBM_TYPE.NPC_LEAVE], DBM_TYPE.NPC_LEAVE
		end
		if cfg then
			if nClass == DBM_TYPE.NPC_ENTER and cfg.bScreenHead then
				FireEvent("JH_SCREENHEAD", npc.dwID, { type = "Object", txt = data.szNote, col = data.col })
			end		-- TODO 需要放置大量同模型的NPC短时间内再次进入
			-- TODO 需要做现场所有NPC全部消失 所以需要打上标记 创建一个临时 table
			local szName = JH.GetTemplateName(npc)
			local xml = {}
			table.insert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
			table.insert(xml, GetFormatText(szName, 44, 255, 255, 0))
			table.insert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
			if nClass == DBM_TYPE.NPC_ENTER then
				table.insert(xml, GetFormatText(_L["Appear"], 44, 255, 255, 255))
				if data.szNote then
					table.insert(xml, GetFormatText(" " .. data.szNote, 44, 255, 255, 255))
				end
			else
				table.insert(xml, GetFormatText(_L["disappear"], 44, 255, 255, 255))
			end
			D.FireAlertEvent(data, cfg, xml, dwCaster, nClass)
			if DBM.bPushTeamChannel and cfg.bTeamChannel then
				JH.Talk(txt)
			end
			if DBM.bPushWhisperChannel and cfg.bWhisperChannel then
				--TODO 全团密聊
			end
			local txt = GetPureText(table.concat(xml))
			if nClass == DBM_TYPE.NPC_ENTER then
				if cfg.bPushFullScreen and DBM.bPushFullScreen then
					FireEvent("JH_FS_CREATE", "NPC", { nTime  = 3, col = data.col, bFlash = true })
				end
			end
		end
	end
end
-- NPC 进出战斗事件
function D.OnNpcFightState()
	-- TODO ...
end

function D.CheckNpcFightState()
	for k, v in pairs(CACHE.NPC_FIGHT) do
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
					CACHE.NPC_FIGHT[k] = nil
				end
			end
		end
		if bChangeFSFlag then
			local nTime = GetTime()
			v.nSec = GetTime()
			FireEvent("JH_NPC_FIGHT", k, true, nTime)
		elseif bChangeFSFlag == false then
			local nTime = GetTime() - (v.nSec or GetTime())
			v.nSec = nil
			FireEvent("JH_NPC_FIGHT", k, false, nTime)
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
	D.Enable(DBM.bEnable)
end

function D.GetDungeon()
	if IsEmpty(D.tDungeonList) then
		for k, v in ipairs(GetMapList()) do
			local a = g_tTable.DungeonInfo:Search(v)
			if a and a.dwClassID == 3 then
				table.insert(D.tDungeonList, {
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
	local tab = D.DATA[szType]
	local cache = CACHE.MAP[szType][dwID]
	if cache then
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
			if tonumber(cache) then
				local data = tab[cache]
				if data and data.dwID == dwID then
					D.Log("HIT TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:0")
					return data
				else
					D.Log("RELOOKUP TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:0")
					return GetData(tab, szType, dwID)
				end
			end
		end
	else
		D.Log("IGNORE TYPE:" .. szType .. " ID:" .. dwID .. " LEVEL:" .. (nLevel or 0))
	end
end

-- 公开接口
local ui = {
	GetTable = D.GetTable,
	GetDungeon = D.GetDungeon,
	GetData = GetData
}
DBM_API = setmetatable({}, { __index = ui, __newindex = function() end, __metatable = true })

JH.RegisterEvent("LOADING_END", D.Init)
