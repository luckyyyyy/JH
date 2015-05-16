-- @Author: Webster
-- @Date:   2015-05-13 16:06:53
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-16 21:00:07
--[[
DBM_TYPE = {
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
collectgarbage("collect")
]]
local DBM_SCRUTINY_TYPE = {
	ALL   = 0,
	SELF  = 1,
	TEAM  = 2,
	ENEMY = 3
}
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
	}
}
local D = {
	tDungeonList = {},
	FILE = { -- 文件原始数据
		BUFF    = {
			[-1] = {
				{ dwID = 103, nLevel = 1 },
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
		NPC     = {},
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
setmetatable(D.FILE, { __index = function(me, index)
	if index == "ALL" then
		local t = {}
		for k, v in pairs(D.FILE) do
			for _, vv in ipairs(v) do
				t[#t +1] = vv
			end
		end
		return t
	end
end })

DBM = {
	bEnable = true,
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
	this:RegisterEvent("ON_WARNING_MESSAGE")
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
		D.OnNpcEvent(arg0, true)
	elseif szEvent == "NPC_LEAVE_SCENE" then
		D.OnNpcEvent(arg0, false)
	elseif szEvent == "LOADING_END" or szEvent == "DBM_CREATE_CACHE" then
		D.CreateData()
	end
end


local function CreateCache(szType, tab)
	local data  = D.DATA[szType]
	local cache = CACHE.MAP[szType]
	for k, v in ipairs(tab) do
		data[#data + 1] = v
		cache[v.dwID] = cache[v.dwID] or {}
		cache[v.dwID][v.nLevel] = k
	end
	Log("[DBM] Create " .. szType .. " data Success!")
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
	Log("[DBM] MAPID: " .. dwMapID ..  " Create data Success:" .. GetTime() - nTime  .. "ms")
	Output(CACHE.MAP, D.DATA)
end

function D.FreeCache(szType)
	Log("[DBM] " .. szType .. " cache clear!")
	local t = {}
	local tTemp = D.TEMP[szType]
	for i = DBM_DEL_CACHE, #tTemp do
		t[#t + 1] = tTemp[i]
	end
	D.TEMP[szType] = t
	collectgarbage("collect")
	FireEvent("DBMUI_TEMP_RELOAD", szType)
end

-- 事件操作
function D.OnBuff(dwPlayerID, bDelete, nIndex, bCanCancel, dwBuffID, nCount, nEndFrame, bInit, nBuffLevel, dwSkillSrcID)
	local key = dwBuffID .. "_" .. nBuffLevel
	local me = GetClientPlayer()
	local szType = "BUFF"
	if not bCanCancel then -- Buff
		szType = "DEBUFF"
	end
	if bDelete then -- 删除Buff处理
	else -- 获得Buff处理
		local tWeak, tTemp = CACHE.TEMP[szType], D.TEMP[szType]
		-- 近期记录
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
-- 技能事件
function D.OnSkillCast(dwCaster, dwCastID, dwLevel, szEvent)
	local tWeak, tTemp = CACHE.TEMP.CASTING, D.TEMP.CASTING
	local key = dwCastID .. "_" .. dwLevel
	local me = GetClientPlayer()
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
	end
end
-- NPC事件
function D.OnNpcEvent(dwID, bEnter)
	local me = GetClientPlayer()
	local npc = GetNpc(arg0)
	if npc then
		if bEnter then -- NPC进入处理
			local tWeak, tTemp = CACHE.TEMP.NPC, D.TEMP.NPC
			if not tWeak[npc.dwTemplateID] then
				local t = {
					dwMapID = me.GetMapID(),
					dwID    = npc.dwTemplateID,
					nFrame  = select(2, GetNpcHeadImage(dwID)),
					col     = { GetHeadTextForceFontColor(dwID, me.dwID) }
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
	for k, v in ipairs(tab) do
		if v.dwID == dwID and (not v.bAlwaysCheckLevel or v.nLevel == nLevel) then
			CACHE.MAP[szType][dwID][nLevel] = k
			return v
		end
	end
end

-- 获取监控数据
function D.GetData(szType, dwID, nLevel)
	local tab = D.DATA[szType]
	local cache = CACHE.MAP[szType][dwID]
	if cache then
		if cache[nLevel] then -- 如果可以直接命中
			local data = tab[cache[nLevel]]
			if data and data.dwID == dwID and (not data.bheckLevel or data.nLevel == nLevel) then
				return data
			else
				return GetData(tab, szType, dwID, nLevel)
			end
		else -- 不能直接命中的情况下 检索下面的所有level
			for k, v in pairs(cache) do
				local data = tab[cache[k]]
				if data and data.dwID == dwID and (not data.bheckLevel or data.nLevel == nLevel) then
					return data
				else
					return GetData(tab, szType, dwID, nLevel)
				end
			end
		end
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
