-- @Author: Webster
-- @Date:   2016-02-24 00:09:06
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-02-24 00:23:32

local _L = JH.LoadLangPack

local pairs, ipairs = pairs, ipairs
local GetClientTeam, GetClientPlayer = GetClientTeam, GetClientPlayer
local tinsert = table.insert
local GetPlayer, GetNpc, IsPlayer = GetPlayer, GetNpc, IsPlayer
local SKILL_RESULT_TYPE = SKILL_RESULT_TYPE
local JH_IsParty, JH_GetSkillName, JH_GetBuffName = JH.IsParty, JH.GetSkillName, JH.GetBuffName

local PLAYER_ID  = 0
local DAMAGE_LOG = {}
local DEATH_LOG  = {}

local function OnSkillEffectLog(dwCaster, dwTarget, nEffectType, dwSkillID, dwLevel, bCriticalStrike, nCount, tResult)
	if not tResult[SKILL_RESULT_TYPE.REFLECTIED_DAMAGE] then -- 没有反弹的情况下
		if not IsPlayer(dwTarget) or not JH_IsParty(dwTarget) and dwTarget ~= PLAYER_ID then -- 目标不是队友也不是自己
			return
		end
	else
		if not IsPlayer(dwCaster) or not JH_IsParty(dwCaster) and dwCaster ~= PLAYER_ID then -- 目标不是队友也不是自己
			return
		end
	end
	local KCaster = IsPlayer(dwCaster) and GetPlayer(dwCaster) or GetNpc(dwCaster)
	local KTarget = IsPlayer(dwTarget) and GetPlayer(dwTarget) or GetNpc(dwTarget)

	local szSkill = nEffectType == SKILL_EFFECT_TYPE.SKILL and JH_GetSkillName(dwSkillID, dwLevel) or JH_GetBuffName(dwSkillID, dwLevel)
	-- 普通伤害
	if IsPlayer(dwTarget) then
		-- 五类伤害
		local szCaster
		if KCaster then
			if IsPlayer(dwCaster) then
				szCaster = KCaster.szName
			else
				szCaster = JH.GetTemplateName(KCaster)
			end
		else
			szCaster = _L["OUTER GUEST"]
		end
		for k, v in ipairs({ "PHYSICS_DAMAGE", "SOLAR_MAGIC_DAMAGE", "NEUTRAL_MAGIC_DAMAGE", "LUNAR_MAGIC_DAMAGE", "POISON_DAMAGE" }) do
			if tResult[SKILL_RESULT_TYPE[v]] and tResult[SKILL_RESULT_TYPE[v]] ~= 0 then
				DAMAGE_LOG[dwTarget == PLAYER_ID and "self" or dwTarget] = {
					szCaster        = szCaster,
					szSkill         = szSkill .. (nEffectType == SKILL_EFFECT_TYPE.BUFF and "(BUFF)" or ""),
					tResult         = tResult,
					bCriticalStrike = bCriticalStrike,
				}
				break
			end
		end
	end
	-- 有反弹伤害
	if tResult[SKILL_RESULT_TYPE.REFLECTIED_DAMAGE] and IsPlayer(dwCaster) then
		local szTarget
		if KTarget then
			if IsPlayer(dwTarget) then
				szTarget = KTarget.szName
			else
				szTarget = JH.GetTemplateName(KTarget)
			end
		else
			szTarget = _L["OUTER GUEST"]
		end
		DAMAGE_LOG[dwCaster == PLAYER_ID and "self" or dwCaster] = {
			szCaster        = szTarget,
			szSkill         = szSkill .. (nEffectType == SKILL_EFFECT_TYPE.BUFF and "(BUFF)" or ""),
			tResult         = tResult,
			bCriticalStrike = bCriticalStrike,
		}
	end
end

-- 意外摔伤 会触发这个日志
local function OnCommonHealthLog(dwCharacterID, nDeltaLife)
	-- 过滤非玩家和治疗日志
	if not IsPlayer(dwCharacterID) or nDeltaLife > 0 then
		return
	end
	local p = GetPlayer(dwCharacterID)
	if not p then
		return
	end
	if JH_IsParty(dwCharacterID) or dwCharacterID == PLAYER_ID then
		DAMAGE_LOG[dwCharacterID == PLAYER_ID and "self" or dwCharacterID] = {
			nCount = nDeltaLife * -1,
		}
	end
end

local function OnSkill(dwCaster, dwSkillID, dwLevel)
	local p = GetPlayer(dwCaster)
	if not p then
		return
	end
	DAMAGE_LOG[dwCaster == PLAYER_ID and "self" or dwCaster] = {
		szCaster = p.szName,
		szSkill  = JH_GetSkillName(dwSkillID, dwLevel),
	}
end
-- 这里的szKiller有个很大的坑
-- 因为策划不喜欢写模板名称 导致NPC名字全是空的 摔死和淹死也是空
-- 这就特别郁闷
local function OnDeath(dwCharacterID, szKiller)
	local me = GetClientPlayer()
	if IsPlayer(dwCharacterID) and (JH_IsParty(dwCharacterID) or dwCharacterID == me.dwID) then
		dwCharacterID = dwCharacterID == me.dwID and "self" or dwCharacterID
		DEATH_LOG[dwCharacterID] = DEATH_LOG[dwCharacterID] or {}
		local nCurrentTime = GetCurrentTime()
		if DAMAGE_LOG[dwCharacterID] then
			DAMAGE_LOG[dwCharacterID].nCurrentTime = nCurrentTime
			tinsert(DEATH_LOG[dwCharacterID], DAMAGE_LOG[dwCharacterID])
		else
			tinsert(DEATH_LOG[dwCharacterID], {
				nCurrentTime = nCurrentTime,
				szCaster     = szKiller ~= "" and szKiller or nil
			})
		end
		DAMAGE_LOG[dwCharacterID] = nil
		FireUIEvent("JH_RAIDTOOLS_DEATH", dwCharacterID)
	end
end

RegisterEvent("LOADING_END", function()
	DAMAGE_LOG = {}
	PLAYER_ID  = UI_GetClientPlayerID()
end)

RegisterEvent("SYS_MSG", function()
	if arg0 == "UI_OME_DEATH_NOTIFY" then -- 死亡记录
		OnDeath(arg1, arg3)
	elseif arg0 == "UI_OME_SKILL_EFFECT_LOG" then -- 技能记录
		OnSkillEffectLog(arg1, arg2, arg4, arg5, arg6, arg7, arg8, arg9)
	elseif arg0 == "UI_OME_COMMON_HEALTH_LOG" then
		OnCommonHealthLog(arg1, arg2)
	end
end)

RegisterEvent("DO_SKILL_CAST", function()
	if arg1 == 608 and IsPlayer(arg0) then -- 自觉经脉
		OnSkill(arg0, arg1, arg2)
	end
end)

function RaidTools.GetDeathLog()
	return DEATH_LOG
end

function RaidTools.ClearDeathLog()
	DEATH_LOG = {}
	FireUIEvent("JH_RAIDTOOLS_DEATH")
end
