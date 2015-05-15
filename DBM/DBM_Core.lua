-- @Author: Webster
-- @Date:   2015-05-13 16:06:53
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-15 20:21:45
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
local DBM_DATAPATH = JH.GetAddonInfo().szDataPath
local DBM_INIFILE  = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM.ini"
local CACHE = {
	TEMP = {
		BUFF    = setmetatable({}, { __mode = "v" }),
		DEBUFF  = setmetatable({}, { __mode = "v" }),
		CASTING = setmetatable({}, { __mode = "v" }),
		NPC     = setmetatable({}, { __mode = "v" }),
	}
}
local D = {
	TEMP = {
		BUFF    = {},
		DEBUFF  = {},
		CASTING = {},
		NPC     = {},
	}
}

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
	end
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
			local count = #tTemp
			if #tTemp > 500 then
				table.remove(tTemp, 1)
			end
			FireEvent("DBMUI_TEMP_UPDATE", szType, t)
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
		local count = #tTemp
		if #tTemp > 500 then
			table.remove(tTemp, 1)
		end
		FireEvent("DBMUI_TEMP_UPDATE", "CASTING", t)
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
				local count = #tTemp
				if #tTemp > 500 then
					table.remove(tTemp, 1)
				end
				FireEvent("DBMUI_TEMP_UPDATE", "NPC", t)
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
function D.GetTable(szType, bTemp)
	if bTemp then
		if szType == "CIRCLE" then -- 如果请求圈圈的近期数据 返回NPC的
			szType = "NPC"
		end
		return D.TEMP[szType]
	else
	end
end

-- 公开接口
local ui = {
	GetTable = D.GetTable
}
DBM_API = setmetatable({}, { __index = ui, __newindex = function() end, __metatable = true })

JH.RegisterEvent("LOADING_END", D.Init)
