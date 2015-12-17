-- @Author: Webster
-- @Date:   2015-12-06 02:44:30
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-12-18 01:13:38

local _L = JH.LoadLangPack

local UI_GetClientPlayerID, GetUserRoleName = UI_GetClientPlayerID, GetUserRoleName
local pairs, unpack = pairs, unpack
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local GetPlayer, GetNpc, IsPlayer = GetPlayer, GetNpc, IsPlayer
local GetSkill = GetSkill

local COMBAT_TEXT_INIFILE        = JH.GetAddonInfo().szRootPath .. "JH_CombatText/JH_CombatText_Render.ini"
local COMBAT_TEXT_CONFIG         = JH.GetAddonInfo().szRootPath .. "JH_CombatText/config.jx3dat"
local COMBAT_TEXT_TOTAL          = 32 -- 如果修改这里 请注意其他也要跟着改
local COMBAT_TEXT_UI_SCALE       = 1  -- 需要对文字做调整哦
local COMBAT_TEXT_CRITICAL = { -- 需要会心跳帧的伤害类型
	[SKILL_RESULT_TYPE.PHYSICS_DAMAGE]       = true,
	[SKILL_RESULT_TYPE.SOLAR_MAGIC_DAMAGE]   = true,
	[SKILL_RESULT_TYPE.NEUTRAL_MAGIC_DAMAGE] = true,
	[SKILL_RESULT_TYPE.LUNAR_MAGIC_DAMAGE]   = true,
	[SKILL_RESULT_TYPE.POISON_DAMAGE]        = true,
	[SKILL_RESULT_TYPE.THERAPY]              = true,
	--[SKILL_RESULT_TYPE.EFFECTIVE_THERAPY]= true,	--然并卵 无strike信息  即使会心也可能是过量治疗
	[SKILL_RESULT_TYPE.REFLECTIED_DAMAGE]    = true,
	[SKILL_RESULT_TYPE.STEAL_LIFE]           = true,
	["EXP"]                                  = true,
}

local COMBAT_TEXT_IGNORE = {
	-- [15] = true,
}
local COMBAT_TEXT_EVENT  = { "COMMON_HEALTH_TEXT", "SKILL_EFFECT_TEXT", "SKILL_MISS", "SKILL_DODGE", "SKILL_BUFF", "BUFF_IMMUNITY" }
local COMBAT_TEXT_STRING = { -- 需要变成特定字符串的伤害类型
	[SKILL_RESULT_TYPE.SHIELD_DAMAGE]  = g_tStrings.STR_MSG_ABSORB,
	[SKILL_RESULT_TYPE.ABSORB_DAMAGE]  = g_tStrings.STR_MSG_ABSORB,
	[SKILL_RESULT_TYPE.PARRY_DAMAGE]   = g_tStrings.STR_MSG_COUNTERACT,
	[SKILL_RESULT_TYPE.INSIGHT_DAMAGE] = g_tStrings.STR_MSG_INSIGHT,
}

local COMBAT_TEXT_SCALE = { -- 各种伤害的缩放帧数 一共32帧
	CRITICAL = { -- 会心
		1, 2, 3, 5, 5, 3, 2, 2,
		2, 2, 2, 2, 2, 2, 2, 2,
		2, 2, 2, 2, 2, 2, 2, 2,
		2, 2, 2, 2, 2, 2, 2, 2,
	},
	NORMAL = { -- 普通伤害
		1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
		1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
		1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
		1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
	},
}

local COMBAT_TEXT_POINT = {
	TOP = { -- 伤害 往上的 分四组 普通 慢 慢 块~~
		6,   12,  18,  24,  30,  36,  42,  48,
		53,  58,  63,  68,  73,  78,  83,  88,
		93,  98,  103, 108, 113, 118, 123, 128,
		136, 142, 150, 158, 166, 172, 180, 188,
	},
	RIGHT = { -- 从左往右的
		8,   16,  24,  32,  40,  48,  56,  64,
		72,  80,  88,  96,  104, 112, 120, 128,
		136, 142, 142, 142, 142, 142, 142, 142,
		142, 142, 142, 142, 142, 142, 142, 142,
	},
	LEFT = { -- 从右到左
		8,   16,  24,  32,  40,  48,  56,  64,
		72,  80,  88,  96,  104, 112, 120, 128,
		136, 142, 142, 142, 142, 142, 142, 142,
		142, 142, 142, 142, 142, 142, 142, 142,
	},
	BOTTOM_LEFT = { -- 左下角
		6,   12,  18,  24,  30,  36,  42,  48,
		54,  60,  66,  72,  78,  84,  90,  96,
		100, 100, 100, 100, 100, 100, 100, 100,
		100, 100, 100, 100, 100, 100, 100, 100,
	},
	BOTTOM_RIGHT = {
		6,   12,  18,  24,  30,  36,  42,  48,
		54,  60,  66,  72,  78,  84,  90,  96,
		100, 100, 100, 100, 100, 100, 100, 100,
		100, 100, 100, 100, 100, 100, 100, 100,
	},
}

local CombatText = {
	tCache   = {},
	tFree    = {}, -- 所有空闲的shadow 合集
	tShadows = {}  -- 所有伤害UI的合集 shadow -> data
}
setmetatable(CombatText.tFree, { __mode = "v" })
setmetatable(CombatText.tShadows, { __mode = "k" })
JH_CombatText = {
	bEnable      = true;
	bRender      = true,
	nMaxAlpha    = 240,
	nTime        = 40,
	nMaxCount    = 80,
	nFadeIn      = 4,
	nFadeOut     = 8,
	nFont        = 19,
	bImmunity    = false,
	tCritical    = false,
	tCriticalC   = { 255, 255, 255 },
	tCriticalH   = { 0,   255, 0   },
	tCriticalB   = { 255, 0,   0   },
	-- $name 名字 $sn   技能名 $crit 会心 $val  数值
	szSkill      = "$sn" .. g_tStrings.STR_COLON .. "$crit $val",
	szTherapy    = "$sn" .. g_tStrings.STR_COLON .. "$crit +$val",
	szDamage     = "$sn" .. g_tStrings.STR_COLON .. "$crit -$val",
	bCasterNotI  = false,
	bSnShorten2  = false,
	bTherEffOnly = false,
	col = { -- 颜色呗
		["DAMAGE"]                               = { 255, 0,   0   }, -- 自己受到的伤害
		[SKILL_RESULT_TYPE.THERAPY]              = { 0,   255, 0   }, -- 治疗
		[SKILL_RESULT_TYPE.PHYSICS_DAMAGE]       = { 255, 255, 255 }, -- 外公
		[SKILL_RESULT_TYPE.SOLAR_MAGIC_DAMAGE]   = { 255, 128, 128 }, -- 阳
		[SKILL_RESULT_TYPE.NEUTRAL_MAGIC_DAMAGE] = { 255, 255, 0   }, -- 混元
		[SKILL_RESULT_TYPE.LUNAR_MAGIC_DAMAGE]   = { 12,  242, 255 }, -- 阴
		[SKILL_RESULT_TYPE.POISON_DAMAGE]        = { 128, 255, 128 }, -- 有毒啊
		[SKILL_RESULT_TYPE.REFLECTIED_DAMAGE]    = { 255, 128, 128 }, -- 反弹 ？？
	}
}
JH.RegisterCustomData("JH_CombatText", 2)

local JH_CombatText = JH_CombatText

function JH_CombatText.OnFrameCreate()
	for k, v in ipairs(COMBAT_TEXT_EVENT) do
		this:RegisterEvent(v)
	end
	-- this:RegisterEvent("PLAYER_ENTER_SCENE")
	-- this:RegisterEvent("PLAYER_LEAVE_SCENE")
	-- this:RegisterEvent("NPC_ENTER_SCENE")
	-- this:RegisterEvent("NPC_LEAVE_SCENE")
	this:RegisterEvent("SYS_MSG")
	this:RegisterEvent("FIGHT_HINT")
	this:RegisterEvent("UI_SCALED")
	CombatText.handle = this:Lookup("", "")
end

function JH_CombatText.OnEvent(szEvent)
	if szEvent == "FIGHT_HINT" then -- 进出战斗文字
		if arg0 then
			OutputMessage("MSG_ANNOUNCE_RED", g_tStrings.STR_MSG_ENTER_FIGHT)
		else
			OutputMessage("MSG_ANNOUNCE_YELLOW", g_tStrings.STR_MSG_LEAVE_FIGHT)
		end
	elseif szEvent == "COMMON_HEALTH_TEXT" then
		if arg1 ~= 0 then
			CombatText.OnCommonHealth(arg0, arg1)
		end
	elseif szEvent == "SKILL_EFFECT_TEXT" then
		CombatText.OnSkillText(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7)
	elseif szEvent == "SKILL_BUFF" then
		CombatText.OnSkillBuff(arg0, arg1, arg2, arg3)
	elseif szEvent == "BUFF_IMMUNITY" then
		if not JH_CombatText.bImmunity then
			CombatText.OnBuffImmunity(arg0)
		end
	elseif szEvent == "SKILL_MISS" then
		if arg0 == UI_GetClientPlayerID() then
			CombatText.OnSkillMiss(arg1)
		end
	elseif szEvent == "UI_SCALED" then
		COMBAT_TEXT_UI_SCALE = Station.GetUIScale() --字体会与UI_SCALE一致，可能需注释掉？
	elseif szEvent == "SKILL_DODGE" then
		if arg0 == UI_GetClientPlayerID() then
			CombatText.OnSkillDodge(arg1)
		end
	elseif szEvent == "SYS_MSG" then
		if arg0 == "UI_OME_EXP_LOG" then
			if arg2 > 0 then
				CombatText.OnExpLog(arg1, arg2)
			end
		elseif arg0 == "UI_OME_SKILL_EFFECT_LOG" then
			local value = arg9[SKILL_RESULT_TYPE.STEAL_LIFE]
			if value and value > 0 then
				CombatText.OnStealLife(arg1, arg2, arg7, value)
			end
		end
	elseif szEvent == "NPC_ENTER_SCENE" or szEvent == "PLAYER_ENTER_SCENE" then
		CombatText.tCache[arg0] = true
	elseif szEvent == "NPC_LEAVE_SCENE" or szEvent == "PLAYER_LEAVE_SCENE" then
		CombatText.tCache[arg0] = nil
	end
end

function CombatText.OnFrameRender()
	local nTime = GetTime()
	for k, v in pairs(CombatText.tShadows) do
		local nFrame = (nTime - v.nTime) / JH_CombatText.nTime + 1 -- 每一帧是多少毫秒 这里越小 动画越快
		local nBefore = floor(nFrame)
		local nAfter  = ceil(nFrame)
		local fDiff   = nFrame - nBefore
		k:ClearTriangleFanPoint()
		if nBefore < COMBAT_TEXT_TOTAL then
			local nTop   = 0
			local nLeft  = 0
			local nAlpha = JH_CombatText.nMaxAlpha
			local fScale = 1
			local bTop   = true
			if nFrame < JH_CombatText.nFadeIn then
				nAlpha = JH_CombatText.nMaxAlpha * nFrame / JH_CombatText.nFadeIn
			elseif nFrame > COMBAT_TEXT_TOTAL - JH_CombatText.nFadeOut then
				nAlpha = JH_CombatText.nMaxAlpha * (COMBAT_TEXT_TOTAL - nFrame) / JH_CombatText.nFadeOut
			end
			if v.szPoint == "TOP" then
				local tTop = COMBAT_TEXT_POINT[v.szPoint]
				nTop = -70 + v.nSort * -40 - (tTop[nBefore] + (tTop[nAfter] - tTop[nBefore]) * fDiff)
			elseif v.szPoint == "LEFT" then
				local tLeft = COMBAT_TEXT_POINT[v.szPoint]
				nLeft = -100 - (tLeft[nBefore] + (tLeft[nAfter] - tLeft[nBefore]) * fDiff)
			elseif v.szPoint == "RIGHT" then
				local tLeft = COMBAT_TEXT_POINT[v.szPoint]
				nLeft = 100 + (tLeft[nBefore] + (tLeft[nAfter] - tLeft[nBefore]) * fDiff)
			elseif v.szPoint == "BOTTOM_LEFT" or v.szPoint == "BOTTOM_RIGHT" then
				local tLeft = COMBAT_TEXT_POINT[v.szPoint]
				local tTop = COMBAT_TEXT_POINT[v.szPoint]
				if v.szPoint == "BOTTOM_LEFT" then
					nLeft = -100 - (tLeft[nBefore] + (tLeft[nAfter] - tLeft[nBefore]) * fDiff)
				else
					nLeft = 100 + (tLeft[nBefore] + (tLeft[nAfter] - tLeft[nBefore]) * fDiff)
				end
				nTop = 50 + tTop[nBefore] + (tTop[nAfter] - tTop[nBefore]) * fDiff
				fScale = 1.5
			end
			if COMBAT_TEXT_CRITICAL[v.nType] then
				local tScale  = v.bCriticalStrike and COMBAT_TEXT_SCALE.CRITICAL or COMBAT_TEXT_SCALE.NORMAL
				fScale  = tScale[nBefore]
				if tScale[nBefore] > tScale[nAfter] then
					fScale = fScale - ((tScale[nBefore] - tScale[nAfter]) * fDiff)
				elseif tScale[nBefore] < tScale[nAfter] then
					fScale = fScale + ((tScale[nAfter] - tScale[nBefore]) * fDiff)
				end
			end
			-- if CombatText.tCache[v.dwTargetID] then -- 这样还不行 有死亡的问题
				local r, g, b = unpack(v.col)
				k:AppendCharacterID(v.dwTargetID, bTop, r, g, b, nAlpha, { 0, 0, 0, nLeft * COMBAT_TEXT_UI_SCALE, nTop * COMBAT_TEXT_UI_SCALE}, JH_CombatText.nFont, v.szText, 1, fScale) --fSacle*COMBAT_TEXT_UI_SCALE
			-- end
			v.nFrame = nFrame
		else
			k.free = true
			CombatText.tShadows[k] = nil
		end
	end
end

JH_CombatText.OnFrameBreathe = CombatText.OnFrameRender
JH_CombatText.OnFrameRender  = CombatText.OnFrameRender

function CombatText.OnSkillText(dwCasterID, dwTargetID, bCriticalStrike, nType, nValue, dwSkillID, dwSkillLevel, nEffectType)
	-- 过滤 有效治疗 有效伤害 西区内力 化解治疗
	if nType == SKILL_RESULT_TYPE.EFFECTIVE_DAMAGE
--	or nType == SKILL_RESULT_TYPE.EFFECTIVE_THERAPY
	or (nType == SKILL_RESULT_TYPE.EFFECTIVE_THERAPY and not JH_CombatText.bTherEffOnly)
	or (nType == SKILL_RESULT_TYPE.THERAPY and JH_CombatText.bTherEffOnly)
	or nType == SKILL_RESULT_TYPE.TRANSFER_MANA
	or nType == SKILL_RESULT_TYPE.ABSORB_THERAPY
	or nType == SKILL_RESULT_TYPE.TRANSFER_LIFE
	or nType == SKILL_RESULT_TYPE.STEAL_LIFE
	then
		return
	end
	local dwID = UI_GetClientPlayerID()
	if nType == SKILL_RESULT_TYPE.REFLECTIED_DAMAGE then
		local _    = dwCasterID
		dwCasterID = dwTargetID
		dwTargetID = _
	-- elseif nType == SKILL_RESULT_TYPE.STEAL_LIFE then -- 太奇葩了 WTF！
		-- if --[[(IsPlayer(dwCasterID) and not IsPlayer(dwTargetID)) or ]]nEffectType == SKILL_EFFECT_TYPE.BUFF then
		-- if dwTargetID ~= dwID and nEffectType ~= SKILL_EFFECT_TYPE.BUFF or nEffectType == SKILL_EFFECT_TYPE.BUFF then
		-- 	local _    = dwCasterID
		-- 	dwCasterID = dwTargetID
		-- 	dwTargetID = _
		-- end
	end
	if COMBAT_TEXT_IGNORE[dwSkillID] and dwCasterID == dwID then
		return
	end
	-- 把两种归类为一种 方便处理
	nType = nType == SKILL_RESULT_TYPE.EFFECTIVE_THERAPY and SKILL_RESULT_TYPE.THERAPY or nType

	if nType == SKILL_RESULT_TYPE.THERAPY and nValue == 0 then
		return
	end

	local bIsPlayer = GetPlayer(dwCasterID)
	local p = bIsPlayer and GetPlayer(dwCasterID) or GetNpc(dwCasterID)
	local employer, dwEmployerID
	if not bIsPlayer and p then
		dwEmployerID = p.dwEmployer
		if dwEmployerID ~= 0 then -- NPC要算归属圈
			employer = GetPlayer(dwEmployerID)
		end
	end
	if dwCasterID ~= dwID and dwTargetID ~= dwID and dwEmployerID ~= dwID then -- 和我没什么卵关系
		return
	end
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end

	local nTime = GetTime()
	local szName = nEffectType == SKILL_EFFECT_TYPE.BUFF and Table_GetBuffName(dwSkillID, dwSkillLevel) or Table_GetSkillName(dwSkillID, dwSkillLevel)
	local szText, szReplaceText
	if nType == SKILL_RESULT_TYPE.THERAPY then
		szReplaceText = JH_CombatText.szTherapy
	else
		szReplaceText = JH_CombatText.szSkill
	end
	local szPoint = "TOP"
	local col     = JH_CombatText.col[nType]
	if COMBAT_TEXT_STRING[nType] then
		szText = COMBAT_TEXT_STRING[nType]
		if dwTargetID == dwID then
			szPoint = "LEFT"
			col = { 255, 255, 0 }
		end
	elseif nType == SKILL_RESULT_TYPE.THERAPY then
		if dwTargetID == dwID then
			szPoint = "BOTTOM_RIGHT"
		end
		if bCriticalStrike and JH_CombatText.tCritical then
			col = JH_CombatText.tCriticalH
		end
	else
		if dwTargetID == dwID then
			szPoint = "BOTTOM_LEFT"
		end
	end
	if szPoint == "BOTTOM_LEFT" then -- 左下角肯定是伤害
		 -- 苍云反弹技能修正颜色
		if p and p.dwID ~= dwID and  p.dwForceID == 21 and nEffectType ~= SKILL_EFFECT_TYPE.BUFF then
			local hSkill = GetSkill(dwSkillID, dwSkillLevel)
			if hSkill and hSkill.dwBelongSchool ~= 18 and hSkill.dwBelongSchool ~= 0 then
				nType = SKILL_RESULT_TYPE.REFLECTIED_DAMAGE
				col = JH_CombatText.col[SKILL_RESULT_TYPE.REFLECTIED_DAMAGE]
			end
		end
		if nType ~= SKILL_RESULT_TYPE.REFLECTIED_DAMAGE then
			col = JH_CombatText.col["DAMAGE"]
			if bCriticalStrike and JH_CombatText.tCritical then
				col = JH_CombatText.tCriticalB
			end
		end
		szReplaceText = JH_CombatText.szDamage
	end

	local szCasterName = ""
	if p then
		if employer then
			szCasterName = employer.szName
		else
			szCasterName = p.szName
		end
	end

	if not szText then -- 还未被定义的
		szText = szReplaceText
		szText = szText:gsub("(%s?)$crit(%s?)", (bCriticalStrike and "%1".. g_tStrings.STR_CS_NAME .. "%2" or ""))
		if JH_CombatText.bCasterNotI and szCasterName == GetUserRoleName() then
			szCasterName = ""
		end
		szText = szText:gsub("$name", szCasterName)
		if JH_CombatText.bSnShorten2 then
			szName = wstring.sub(szName, 1, 2) -- wstring是兼容台服的 台服utf-8
		end
		szText = szText:gsub("$sn", szName)
		szText = szText:gsub("$val", nValue or "")
	end
	-- 对某些 一次性出现多次伤害的技能 做排序
	local nSort = 0
	if szPoint == "TOP" then
		for k, v in pairs(CombatText.tShadows) do
			if v.dwTargetID == dwTargetID and v.nFrame <= v.nSort * 5 + 5 and v.szPoint == "TOP" then
				nSort = nSort + 1
				v.nSort = min(3 / COMBAT_TEXT_UI_SCALE, v.nSort + max(nSort - v.nSort, 0))
			end
		end
		if bCriticalStrike and nType ~= SKILL_RESULT_TYPE.THERAPY and JH_CombatText.tCritical then
			col = JH_CombatText.tCriticalC
		end
	end
	CombatText.tShadows[shadow] = {
		szPoint         = szPoint,
		nSort           = 0,
		dwTargetID      = dwTargetID,
		szText          = szText,
		nType           = nType,
		nTime           = nTime,
		nFrame          = 0,
		bCriticalStrike = bCriticalStrike,
		col             = col,
	}
end

-- 吸血
function CombatText.OnStealLife(dwCaster, dwTarget, bCriticalStrike, nValue)
	local dwID = UI_GetClientPlayerID()
	if dwCaster ~= dwID and dwTarget ~= dwID then
		return
	end
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local nTime = GetTime()
	if dwCaster == dwID then
		szPoint = "BOTTOM_RIGHT"
	else
		szPoint = "TOP"
	end
	CombatText.tShadows[shadow] = {
		szPoint    = szPoint,
		nSort      = 0,
		dwTargetID = dwCaster,
		szText     = "+" .. nValue,
		nType      = SKILL_RESULT_TYPE.STEAL_LIFE,
		nTime      = nTime,
		nFrame     = 0,
		col        = JH_CombatText.col[SKILL_RESULT_TYPE.THERAPY],
	}
end

function CombatText.OnSkillBuff(dwCharacterID, bCanCancel, dwID, nLevel)
	if not Table_BuffIsVisible(dwID, nLevel) then
		return
	end
	local szBuffName = Table_GetBuffName(dwID, nLevel)
	if szBuffName == "" then
		return
	end
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local col = bCanCancel and { 255, 255, 0 } or { 255, 0, 0}
	local nTime = GetTime()
	CombatText.tShadows[shadow] = {
		szPoint    = "RIGHT",
		nSort      = 0,
		dwTargetID = dwCharacterID,
		szText     = szBuffName,
		nType      = "SKILL_BUFF",
		nTime      = nTime,
		nFrame     = 0,
		col        = col,
	}
end

function CombatText.OnSkillMiss(dwTargetID)
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local nTime = GetTime()
	local szPoint = dwTargetID == UI_GetClientPlayerID() and "LEFT" or "TOP"
	local nSort = 0
	if szPoint == "TOP" then
		for k, v in pairs(CombatText.tShadows) do
			if v.dwTargetID == dwTargetID and v.nFrame <= v.nSort * 5 + 5 and v.szPoint == "TOP" then
				nSort = nSort + 1
				v.nSort = min(3 / COMBAT_TEXT_UI_SCALE, v.nSort + max(nSort - v.nSort, 0))
			end
		end
	end
	CombatText.tShadows[shadow] = {
		szPoint    = szPoint,
		dwTargetID = dwTargetID,
		nSort      = nSort,
		szText     = g_tStrings.STR_MSG_MISS,
		nType      = "SKILL_MISS",
		nTime      = nTime,
		nFrame     = 0,
		col        = JH_CombatText.col["SKILL_MISS"],
	}
end

function CombatText.OnBuffImmunity(dwTargetID)
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local nTime = GetTime()
	CombatText.tShadows[shadow] = {
		szPoint    = "LEFT",
		nSort      = 0,
		dwTargetID = dwTargetID,
		szText     = g_tStrings.STR_MSG_IMMUNITY,
		nType      = "BUFF_IMMUNITY",
		nTime      = nTime,
		nFrame     = 0,
		col        = JH_CombatText.col["BUFF_IMMUNITY"],
	}
end
-- FireUIEvent("COMMON_HEALTH_TEXT", GetClientPlayer().dwID, -8888)
function CombatText.OnCommonHealth(dwCharacterID, nDeltaLife)
	local dwID = UI_GetClientPlayerID()
	if nDeltaLife < 0 and dwCharacterID ~= dwID then
		return
	end
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local nTime = GetTime()
	local szPoint = "BOTTOM_LEFT"
	if nDeltaLife > 0 then
		if dwCharacterID ~= dwID then
			szPoint = "TOP"
		else
			szPoint = "BOTTOM_RIGHT"
		end
	end
	CombatText.tShadows[shadow] = {
		szPoint    = szPoint,
		nSort      = 0,
		dwTargetID = dwCharacterID,
		szText     = nDeltaLife > 0 and "+" .. nDeltaLife or nDeltaLife,
		nType      = "COMMON_HEALTH",
		nTime      = nTime,
		nFrame     = 0,
		col        = nDeltaLife > 0 and JH_CombatText.col[SKILL_RESULT_TYPE.THERAPY] or JH_CombatText.col["DAMAGE"],
	}
end

function CombatText.OnSkillDodge(dwTargetID)
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local nTime = GetTime()
	CombatText.tShadows[shadow] = {
		szPoint    = "LEFT",
		nSort      = 0,
		dwTargetID = dwTargetID,
		szText     = g_tStrings.STR_MSG_DODGE,
		nType      = "SKILL_DODGE",
		nTime      = nTime,
		nFrame     = 0,
		col        = { 255, 0, 0 },
	}
end

function CombatText.OnExpLog(dwCharacterID, nExp)
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local nTime = GetTime()
	CombatText.tShadows[shadow] = {
		nSort           = 0,
		bCriticalStrike = true,
		dwTargetID      = dwCharacterID,
		szText          = g_tStrings.STR_COMBATMSG_EXP .. nExp,
		nType           = "EXP",
		nTime           = nTime,
		nFrame          = 0,
		col             = { 255, 0, 255 },
	}
end

function CombatText.GetFreeShadow()
	local handle = CombatText.handle
	for k, v in ipairs(CombatText.tFree) do
		if v.free then
			v.free = false
			return v
		end
	end
	if #CombatText.tFree < JH_CombatText.nMaxCount then
		local sha = handle:AppendItemFromIni(COMBAT_TEXT_INIFILE, "Shadow_Content")
		sha:SetTriangleFan(GEOMETRY_TYPE.TEXT)
		sha:ClearTriangleFanPoint()
		table.insert(CombatText.tFree, sha)
		return sha
	end
end

function CombatText.LoadConfig()
	local bExist = IsFileExist(COMBAT_TEXT_CONFIG)
	if bExist then
		local data = LoadLUAData(COMBAT_TEXT_CONFIG)
		if data then
			COMBAT_TEXT_CRITICAL = data.COMBAT_TEXT_CRITICAL or COMBAT_TEXT_CRITICAL
			COMBAT_TEXT_SCALE    = data.COMBAT_TEXT_SCALE    or COMBAT_TEXT_SCALE
			COMBAT_TEXT_POINT    = data.COMBAT_TEXT_POINT    or COMBAT_TEXT_POINT
			COMBAT_TEXT_IGNORE   = data.COMBAT_TEXT_IGNORE   or COMBAT_TEXT_IGNORE
			COMBAT_TEXT_EVENT    = data.COMBAT_TEXT_EVENT    or COMBAT_TEXT_EVENT
			JH.Sysmsg(_L["CombatText Config loaded"])
		else
			JH.Sysmsg(_L["CombatText Config failed"])
		end
	end
end

function CombatText.CheckEnable()
	local CombatTextWnd = Station.Lookup("Lowest/CombatTextWnd")
	local ui = Station.Lookup("Lowest/JH_CombatText")
	local events = { "SKILL_EFFECT_TEXT", "COMMON_HEALTH_TEXT", "SKILL_MISS", "SKILL_DODGE", "SKILL_BUFF", "BUFF_IMMUNITY", "SYS_MSG", "FIGHT_HINT" }
	if JH_CombatText.bRender then
		COMBAT_TEXT_INIFILE = JH.GetAddonInfo().szRootPath .. "JH_CombatText/JH_CombatText_Render.ini"
	else
		COMBAT_TEXT_INIFILE = JH.GetAddonInfo().szRootPath .. "JH_CombatText/JH_CombatText.ini"
	end
	if JH_CombatText.bEnable then
		if CombatTextWnd then
			for k, v in ipairs(events) do
				CombatTextWnd:UnRegisterEvent(v)
			end
		end
		CombatText.LoadConfig()
		Wnd.CloseWindow(ui)
		CombatText.tFree    = {}
		CombatText.tShadows = {}
		Wnd.OpenWindow(COMBAT_TEXT_INIFILE, "JH_CombatText")
	else
		if CombatTextWnd then
			for k, v in ipairs(events) do
				CombatTextWnd:UnRegisterEvent(v)
			end
			for k, v in ipairs(events) do
				CombatTextWnd:RegisterEvent(v)
			end
		end
		if ui then
			Wnd.CloseWindow(ui)
			CombatText.tFree    = {}
			CombatText.tShadows = {}
			collectgarbage("collect")
		end
	end
	setmetatable(JH_CombatText.col, { __index = function() return { 255, 255, 255 } end })
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["CombatText"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Enable CombatText"], color = { 255, 128, 0 } , checked = JH_CombatText.bEnable }):Click(function(bCheck)
		JH_CombatText.bEnable = bCheck
		CombatText.CheckEnable()
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Enable Render"], checked = JH_CombatText.bRender }):Click(function(bCheck)
		JH_CombatText.bRender = bCheck
		CombatText.CheckEnable()
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Disable Immunity"], checked = JH_CombatText.bImmunity }):Click(function(bCheck)
		JH_CombatText.bImmunity = bCheck
	end):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY - 1, txt = g_tStrings.STR_QUESTTRACE_CHANGE_ALPHA, color = { 255, 255, 200 } }):Pos_()
	nX = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = "" }):Range(1, 255, 254):Value(JH_CombatText.nMaxAlpha):Change(function(nVal)
		JH_CombatText.nMaxAlpha = nVal
	end):Pos_()
	nX = ui:Append("Text", { x = 240, y = nY - 1, txt = _L["Hold time"], color = { 255, 255, 200 } }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = _L["ms"] }):Range(500, 3000, 2500):Value(JH_CombatText.nTime * COMBAT_TEXT_TOTAL):Change(function(nVal)
		JH_CombatText.nTime = nVal / COMBAT_TEXT_TOTAL
	end):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY - 1, txt = _L["FadeIn time"], color = { 255, 255, 200 } }):Pos_()
	nX = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = _L["Frame"] }):Range(0, 15, 15):Value(JH_CombatText.nFadeIn):Change(function(nVal)
		JH_CombatText.nFadeIn = nVal
	end):Pos_()
	nX = ui:Append("Text", { x = 240, y = nY - 1, txt = _L["FadeOut time"], color = { 255, 255, 200 } }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = _L["Frame"] }):Range(0, 15, 15):Value(JH_CombatText.nFadeOut):Change(function(nVal)
		JH_CombatText.nFadeOut = nVal
	end):Pos_()

	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Text Style"], font = 27 }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 10, txt = _L["Skill Style"], color = { 255, 255, 200 } }):Pos_()
	local nY2 = nY
	nX, nY = ui:Append("WndEdit", { x = nX + 10, y = nY + 12, w = 250, h = 25, txt = JH_CombatText.szSkill, limit = 30 }):Change(function(szText)
		JH_CombatText.szSkill = szText
	end):Pos_()
	if JH_CombatText.tCritical then
		nX = ui:Append("Text", { x = nX + 15, y = nY2 + 10, txt = _L["critical beat"]}):Pos_() --会心伤害
		ui:Append("Shadow", { x = nX + 5, y = nY2 + 10 + 6, color = JH_CombatText.tCriticalC, w = 15, h = 15 }):Click(function()
			local ui = this
			GUI.OpenColorTablePanel(function(r, g, b)
				JH_CombatText.tCriticalC = { r, g, b }
				ui:SetColorRGB(r, g, b)
			end)
		end)
	end
	nX = ui:Append("Text", { x = 10, y = nY, txt = _L["Damage Style"], color = { 255, 255, 200 } }):Pos_()
	nY2 = nY
	nX, nY = ui:Append("WndEdit", { x = nX + 10, y = nY + 2, w = 250, h = 25, txt = JH_CombatText.szDamage, limit = 30 }):Change(function(szText)
		JH_CombatText.szDamage = szText
	end):Pos_()
	if JH_CombatText.tCritical then
		nX = ui:Append("Text", { x = nX+15, y = nY2 + 2, txt = _L["critical beaten"]}):Pos_() --会心承伤
		nX = ui:Append("Shadow", { x = nX + 5, y = nY2 + 2 + 6, color = JH_CombatText.tCriticalB, w = 15, h = 15 }):Click(function()
			local ui = this
			GUI.OpenColorTablePanel(function(r, g, b)
				JH_CombatText.tCriticalB = { r, g, b }
				ui:SetColorRGB(r, g, b)
			end)
		end):Pos_()
	end
	nX = ui:Append("Text", { x = 10, y = nY, txt = _L["Therapy Style"], color = { 255, 255, 200 } }):Pos_()
	nY2 = nY
	nX, nY = ui:Append("WndEdit", { x = nX + 10, y = nY + 2, w = 250, h = 25, txt = JH_CombatText.szTherapy, limit = 30 }):Change(function(szText)
		JH_CombatText.szTherapy = szText
	end):Pos_()
	if JH_CombatText.tCritical then
		nX = ui:Append("Text", { x = nX+15, y = nY2 + 2, txt = _L["critical heaten"]}):Pos_() --会心承疗
		nX = ui:Append("Shadow", { x = nX + 5, y = nY2 + 2 + 6, color = JH_CombatText.tCriticalH, w = 15, h = 15 }):Click(function()
			local ui = this
			GUI.OpenColorTablePanel(function(r, g, b)
				JH_CombatText.tCriticalH = { r, g, b }
				ui:SetColorRGB(r, g, b)
			end)
		end):Pos_()
	end
	nX, nY = ui:Append("Text", { x = 10, y = nY, txt = _L["CombatText Tips"], color = { 196, 196, 196 } }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["$name not me"], checked = JH_CombatText.bCasterNotI }):Click(function(bCheck)
		JH_CombatText.bCasterNotI = bCheck
	end):Pos_() -- name为自己时不显示
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["$sn shorten(2)"], checked = JH_CombatText.bSnShorten2 }):Click(function(bCheck)
		JH_CombatText.bSnShorten2 = bCheck
	end):Pos_()	--sn 显示为技能缩写（前2字
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["therapy effective only"], checked = JH_CombatText.bTherEffOnly }):Click(function(bCheck)
		JH_CombatText.bTherEffOnly = bCheck
	end):Pos_()	-- 这个是不需要单独着色的，跟着治疗的颜色一起的
	ui:Append("WndButton3", { x = 350, y = nY + 10, txt = _L["Font edit"] }):Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			JH_CombatText.nFont = nFont
		end)
	end)
	nX, nY = ui:Append("Text", { x = 0, y = nY + 5, txt = _L["Color edit"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Critical Color"], checked = JH_CombatText.tCritical and true or false }):Click(function(bCheck)
		JH_CombatText.tCritical = bCheck
		JH.OpenPanel(_L["CombatText"])
	end):Pos_()

	local i = 0
	for k, v in pairs(JH_CombatText.col) do
		if k ~= SKILL_RESULT_TYPE.EFFECTIVE_THERAPY then
			ui:Append("Text", { x = (i % 8) * 65 + 10, y = nY + 30 * floor(i / 8), txt = _L["CombatText Color " .. k] })
			ui:Append("Shadow", { x = (i % 8) * 65 + 45, y = nY + 30 * floor(i / 8) + 6, color = v, w = 15, h = 15 }):Click(function()
				local ui = this
				GUI.OpenColorTablePanel(function(r, g, b)
					JH_CombatText.col[k] = { r, g, b }
					ui:SetColorRGB(r, g, b)
				end)
			end)
			i = i + 1
		end
	end

	if IsFileExist(COMBAT_TEXT_CONFIG) then
		ui:Append("WndButton3", { x = 350, y = 0, txt = _L["Load CombatText Config"] }):Click(CombatText.CheckEnable)
	end
end
GUI.RegisterPanel(_L["CombatText"], 2041, g_tStrings.CHANNEL_CHANNEL, PS)

JH.RegisterEvent("LOGIN_GAME", CombatText.CheckEnable)
