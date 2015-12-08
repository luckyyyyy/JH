-- @Author: Webster
-- @Date:   2015-12-06 02:44:30
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-12-08 20:38:42

local _L = JH.LoadLangPack

local UI_GetClientPlayerID = UI_GetClientPlayerID
local pairs, unpack = pairs, unpack
local floor, ceil = math.floor, math.ceil

local COMBAT_TEXT_INIFILE        = JH.GetAddonInfo().szRootPath .. "JH_CombatText/JH_CombatText_Render.ini"
local COMBAT_TEXT_TOTAL          = 32 -- 如果修改这里 请注意其他也要跟着改
local COMBAT_TEXT_UI_SCALE       = 1  -- 需要对文字做调整哦
local COMBAT_TEXT_CRITICAL = { -- 需要会心跳帧的伤害类型
	[SKILL_RESULT_TYPE.PHYSICS_DAMAGE]       = true,
	[SKILL_RESULT_TYPE.SOLAR_MAGIC_DAMAGE]   = true,
	[SKILL_RESULT_TYPE.NEUTRAL_MAGIC_DAMAGE] = true,
	[SKILL_RESULT_TYPE.LUNAR_MAGIC_DAMAGE]   = true,
	[SKILL_RESULT_TYPE.POISON_DAMAGE]        = true,
	[SKILL_RESULT_TYPE.THERAPY]              = true,
	[SKILL_RESULT_TYPE.REFLECTIED_DAMAGE]    = true,
	[SKILL_RESULT_TYPE.STEAL_LIFE]           = true,
	["EXP"]                                  = true,
}

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
	bEnable   = false;
	bRender   = true,
	bShowName = false,
	nMaxAlpha = 240,
	nTime     = 40,
	nMaxCount = 80,
	nFadeIn   = 4,
	nFadeOut  = 8,
	nFont     = 19,
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
	this:RegisterEvent("FIGHT_HINT")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("COMMON_HEALTH_TEXT")
	this:RegisterEvent("SKILL_EFFECT_TEXT")
	this:RegisterEvent("SKILL_MISS")
	this:RegisterEvent("SKILL_DODGE")
	this:RegisterEvent("SKILL_BUFF")
	this:RegisterEvent("BUFF_IMMUNITY")
	-- this:RegisterEvent("PLAYER_ENTER_SCENE")
	-- this:RegisterEvent("PLAYER_LEAVE_SCENE")
	-- this:RegisterEvent("NPC_ENTER_SCENE")
	-- this:RegisterEvent("NPC_LEAVE_SCENE")
	this:RegisterEvent("SYS_MSG")
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
		CombatText.OnBuffImmunity(arg0)
	elseif szEvent == "SKILL_MISS" then
		if arg0 == UI_GetClientPlayerID() then
			CombatText.OnSkillMiss(arg1)
		end
	elseif szEvent == "UI_SCALED" then
		COMBAT_TEXT_UI_SCALE = Station.GetUIScale()
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
					nTop = 50 + tTop[nBefore] + (tTop[nAfter] - tTop[nBefore]) * fDiff
				else
					nLeft = 100 + (tLeft[nBefore] + (tLeft[nAfter] - tLeft[nBefore]) * fDiff)
					nTop = 50 + tTop[nBefore] + (tTop[nAfter] - tTop[nBefore]) * fDiff
				end
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
				k:AppendCharacterID(v.dwTargetID, bTop, r, g, b, nAlpha, { 0, 0, 0, nLeft * COMBAT_TEXT_UI_SCALE, nTop * COMBAT_TEXT_UI_SCALE}, JH_CombatText.nFont, v.szText, 1, fScale)
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
	or nType == SKILL_RESULT_TYPE.EFFECTIVE_THERAPY
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
	if dwCasterID ~= dwID and dwTargetID ~= dwID then -- 和我没什么卵关系
		return
	end
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local nTime = GetTime()
	-- 会心 剑破虚空：20000
	-- 翔舞：会心 + 2000
	local szName = nEffectType == SKILL_EFFECT_TYPE.BUFF and Table_GetBuffName(dwSkillID, dwSkillLevel) or Table_GetSkillName(dwSkillID, dwSkillLevel)
	local szText
	if nType == SKILL_RESULT_TYPE.THERAPY then
		if bCriticalStrike then
			szText = (szName or "") .. g_tStrings.STR_COLON  .. g_tStrings.STR_CS_NAME .. " +" .. nValue
		else
			szText = (szName or "") .. g_tStrings.STR_COLON .. "+" .. nValue
		end
	else
		if bCriticalStrike then
			szText = (szName or "") .. g_tStrings.STR_COLON .. g_tStrings.STR_CS_NAME .. " " .. nValue
		else
			szText = (szName or "") .. g_tStrings.STR_COLON .. nValue
		end
	end
	local szPoint = "TOP"
	local col     = JH_CombatText.col[nType]
	if COMBAT_TEXT_STRING[nType] then
		szText = COMBAT_TEXT_STRING[nType]
		if dwTargetID == dwID then
			szPoint = "LEFT"
			col = { 255, 255, 0 }
		end
	else
		if nType == SKILL_RESULT_TYPE.THERAPY then
			if dwTargetID == dwID then
				szPoint = "BOTTOM_RIGHT"
			end
		else
			if dwTargetID == dwID then
				szPoint = "BOTTOM_LEFT"
			end
		end
	end
	if szPoint == "BOTTOM_LEFT" then -- 左下角肯定是伤害
		if nType ~= SKILL_RESULT_TYPE.REFLECTIED_DAMAGE then
			col = JH_CombatText.col["DAMAGE"]
		end
		if bCriticalStrike then
			szText = (szName or "") .. g_tStrings.STR_COLON .. g_tStrings.STR_CS_NAME ..  " -" .. nValue
		else
			szText = (szName or "") .. g_tStrings.STR_COLON .. "-" .. nValue
		end
	end

	if JH_CombatText.bShowName then
		local p = IsPlayer(dwCasterID) and GetPlayer(dwCasterID) or GetNpc(dwCasterID)
		if p and p.szName ~= "" then
			szText = p.szName .. g_tStrings.STR_CONNECT .. szText
		end
	end
	-- 对某些 一次性出现多次伤害的技能 做排序
	local nSort = 0
	if szPoint == "TOP" then
		for k, v in pairs(CombatText.tShadows) do
			if v.dwTargetID == dwTargetID and v.nFrame <= v.nSort * 5 + 5 and v.szPoint == "TOP" then
				nSort = nSort + 1
				v.nSort = v.nSort + nSort - v.nSort
			end
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
				v.nSort = v.nSort + nSort - v.nSort
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
	if JH_CombatText.bRender then
		COMBAT_TEXT_INIFILE = JH.GetAddonInfo().szRootPath .. "JH_CombatText/JH_CombatText_Render.ini"
	else
		COMBAT_TEXT_INIFILE = JH.GetAddonInfo().szRootPath .. "JH_CombatText/JH_CombatText.ini"
	end
	local path = JH.GetAddonInfo().szRootPath .. "JH_CombatText/config.jx3dat"
	local bExist = IsFileExist(path)
	if bExist then
		local data = LoadLUAData(path)
		if data then
			COMBAT_TEXT_CRITICAL       = data.COMBAT_TEXT_CRITICAL or COMBAT_TEXT_CRITICAL
			COMBAT_TEXT_SCALE          = data.COMBAT_TEXT_SCALE or COMBAT_TEXT_SCALE
			COMBAT_TEXT_POINT          = data.COMBAT_TEXT_POINT or COMBAT_TEXT_POINT
			JH.Sysmsg(_L["CombatText Config loaded"])
		else
			JH.Sysmsg(_L["CombatText Config failed"])
		end
	end
end

function CombatText.CheckEnable()
	local CombatTextWnd = Station.Lookup("Lowest/CombatTextWnd")
	local ui = Station.Lookup("Lowest/JH_CombatText")
	if JH_CombatText.bEnable then
		if CombatTextWnd then
			for k, v in ipairs({ "SKILL_EFFECT_TEXT", "COMMON_HEALTH_TEXT", "SKILL_MISS", "SKILL_DODGE", "SKILL_BUFF", "BUFF_IMMUNITY", "SYS_MSG", "FIGHT_HINT" }) do
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
			for k, v in ipairs({ "SKILL_EFFECT_TEXT", "COMMON_HEALTH_TEXT", "SKILL_MISS", "SKILL_DODGE", "SKILL_BUFF", "BUFF_IMMUNITY", "SYS_MSG", "FIGHT_HINT" }) do
				CombatTextWnd:UnRegisterEvent(v)
			end
			for k, v in ipairs({ "SKILL_EFFECT_TEXT", "COMMON_HEALTH_TEXT", "SKILL_MISS", "SKILL_DODGE", "SKILL_BUFF", "BUFF_IMMUNITY", "SYS_MSG", "FIGHT_HINT" }) do
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
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Enable CombatText"], checked = JH_CombatText.bEnable }):Click(function(bCheck)
		JH_CombatText.bEnable = bCheck
		CombatText.CheckEnable()
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Enable Render"], checked = JH_CombatText.bRender }):Click(function(bCheck)
		JH_CombatText.bRender = bCheck
		CombatText.CheckEnable()
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = g_tStrings.STR_GUILD_NAME, checked = JH_CombatText.bShowName }):Click(function(bCheck)
		JH_CombatText.bShowName = bCheck
	end):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY - 1, txt = g_tStrings.STR_QUESTTRACE_CHANGE_ALPHA }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = _L[" alpha"] }):Range(1, 255, 254):Value(JH_CombatText.nMaxAlpha):Change(function(nVal)
		JH_CombatText.nMaxAlpha = nVal
	end):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY - 1, txt = _L["Hold time"] }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = _L["ms"] }):Range(500, 3000, 2500):Value(JH_CombatText.nTime * COMBAT_TEXT_TOTAL):Change(function(nVal)
		JH_CombatText.nTime = nVal / COMBAT_TEXT_TOTAL
	end):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY - 1, txt = _L["FadeIn time"] }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = _L["Frame"] }):Range(0, 15, 15):Value(JH_CombatText.nFadeIn):Change(function(nVal)
		JH_CombatText.nFadeIn = nVal
	end):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY - 1, txt = _L["FadeOut time"] }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 1, txt = _L["Frame"] }):Range(0, 15, 15):Value(JH_CombatText.nFadeOut):Change(function(nVal)
		JH_CombatText.nFadeOut = nVal
	end):Pos_()
	nX, nY = ui:Append("WndButton3", { x = 10, y = nY + 10, txt = _L["Font edit"] }):Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			JH_CombatText.nFont = nFont
		end)
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Color edit"], font = 27 }):Pos_()
	nY = nY + 10
	local i = 0
	for k, v in pairs(JH_CombatText.col) do
		ui:Append("Text", { x = (i % 4) * 80, y = nY + 30 * floor(i / 4), txt = _L["CombatText Color " .. k] })
		ui:Append("Shadow", { x = (i % 4) * 80 + 40, y = nY + 30 * floor(i / 4), color = v, w = 25, h = 25 }):Click(function()
			local ui = this
			GUI.OpenColorTablePanel(function(r, g, b)
				JH_CombatText.col[k] = { r, g, b }
				ui:SetColorRGB(r, g, b)
			end)
		end)
		i = i + 1
	end
	if IsFileExist(JH.GetAddonInfo().szRootPath .. "JH_CombatText/config.jx3dat") then
		ui:Append("WndButton3", { x = 10, y = nY + 10, txt = _L["Load CombatText Config"] }):Click(CombatText.CheckEnable)
	end
end
GUI.RegisterPanel(_L["CombatText"], 2041, g_tStrings.CHANNEL_CHANNEL, PS)

JH.RegisterEvent("LOGIN_GAME", CombatText.CheckEnable)
