-- @Author: Webster
-- @Date:   2015-12-06 02:44:30
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-12-07 22:22:02

local _L = JH.LoadLangPack

local UI_GetClientPlayerID = UI_GetClientPlayerID
local pairs, unpack = pairs, unpack
local floor, ceil = math.floor, math.ceil

local COMBAT_TEXT_INIFILE        = JH.GetAddonInfo().szRootPath .. "JH_CombatText/JH_CombatText_Render.ini"
local COMBAT_TEXT_MAX_ALPHA      = 240 -- 文字的最大 alpha 就是透明度
local COMBAT_TEXT_RENDER         = true
local COMBAT_TEXT_TIME           = 40 -- 这里 乘以 COMBAT_TEXT_TOTAL 就是总出现时间
local COMBAT_TEXT_TOTAL          = 32 -- 如果修改这里 请注意其他也要跟着改
local COMBAT_TEXT_MAX_COUNT      = 50 -- 最多同事出现的文字 大于此值的都忽略 别太大了 小心崩
local COMBAT_TEXT_FADE_IN_FRAME  = 4  -- 设置淡入的桢数
local COMBAT_TEXT_FADE_OUT_FRAME = 8  -- 设置淡出的桢数
local COMBAT_TEXT_UI_SCALE       = 1  -- 需要对文字做调整哦
local COMBAT_TEXT_FONT           = 19
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
		4,   8,   12,  16,  20,  24,  28,  32,
		35,  38,  41,  44,  47,  50,  53,  60,
		63,  66,  69,  72,  75,  78,  81,  84,
		89,  94,  99,  104, 110, 118, 128, 136,
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
local COMBAT_TEXT_COLOR = {
	["EXP"]                                  = { 255, 0,   255 }, -- 阅历
	["DODGE"]                                = { 255, 0,   0   }, -- 闪避
	["DAMAGE"]                               = { 255, 0,   0   }, -- 自己受到的伤害
	[SKILL_RESULT_TYPE.THERAPY]              = { 0,   255, 0   }, -- 治疗
	["BUFF"]                                 = { 255, 255, 0   }, -- BUFF
	["DEBUFF"]                               = { 255, 0,   0   }, -- DEBUFF
	[SKILL_RESULT_TYPE.PHYSICS_DAMAGE]       = { 255, 255, 255 }, -- 外公
	[SKILL_RESULT_TYPE.SOLAR_MAGIC_DAMAGE]   = { 255, 128, 128 }, -- 阳
	[SKILL_RESULT_TYPE.NEUTRAL_MAGIC_DAMAGE] = { 255, 255, 0   }, -- 混元
	[SKILL_RESULT_TYPE.LUNAR_MAGIC_DAMAGE]   = { 12,  242, 255 }, -- 阴
	[SKILL_RESULT_TYPE.POISON_DAMAGE]        = { 128, 255, 128 }, -- 有毒啊
	[SKILL_RESULT_TYPE.REFLECTIED_DAMAGE]    = { 255, 128, 128 }, -- 反弹 ？？
}
setmetatable(COMBAT_TEXT_COLOR, { __index = function() return { 255, 255, 255 } end })

local CombatText = {
	tFree    = {}, -- 所有空闲的shadow 合集
	tShadows = {}  -- 所有伤害UI的合集 shadow -> data
}
setmetatable(CombatText.tFree, { __mode = "v" })
setmetatable(CombatText.tShadows, { __mode = "k" })
JH_CombatText = {
	bEnable = false;
}
JH.RegisterCustomData("JH_CombatText")

function JH_CombatText.OnFrameCreate()
	this:RegisterEvent("FIGHT_HINT")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("COMMON_HEALTH_TEXT")
	this:RegisterEvent("SKILL_EFFECT_TEXT")
	this:RegisterEvent("SKILL_MISS")
	this:RegisterEvent("SKILL_DODGE")
	this:RegisterEvent("SKILL_BUFF")
	this:RegisterEvent("BUFF_IMMUNITY")
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
		end
	end
end

function CombatText.OnFrameRender()
	local nTime = GetTime()
	for k, v in pairs(CombatText.tShadows) do
		local nFrame = (nTime - v.nTime) / COMBAT_TEXT_TIME + 1 -- 每一帧是多少毫秒 这里越小 动画越快
		local nBefore = floor(nFrame)
		local nAfter  = ceil(nFrame)
		local fDiff   = nFrame - nBefore
		k:ClearTriangleFanPoint()
		if nBefore < COMBAT_TEXT_TOTAL then
			local nTop   = 0
			local nLeft  = 0
			local nAlpha = COMBAT_TEXT_MAX_ALPHA
			local fScale = 1
			local bTop   = true
			if nFrame < COMBAT_TEXT_FADE_IN_FRAME then
				nAlpha = COMBAT_TEXT_MAX_ALPHA * nFrame / COMBAT_TEXT_FADE_IN_FRAME
			elseif nFrame > COMBAT_TEXT_TOTAL - COMBAT_TEXT_FADE_OUT_FRAME then
				nAlpha = COMBAT_TEXT_MAX_ALPHA * (COMBAT_TEXT_TOTAL - nFrame) / COMBAT_TEXT_FADE_OUT_FRAME
			end
			if v.szPoint == "TOP" then
				local tTop = COMBAT_TEXT_POINT[v.szPoint]
				nTop = -80 + v.nSort * -40 - (tTop[nBefore] + (tTop[nAfter] - tTop[nBefore]) * fDiff)
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
				-- if v.szPoint == "BOTTOM_RIGHT" and v.nType == SKILL_RESULT_TYPE.THERAPY and v.bCriticalStrike then
				-- 	fScale = 1.5 -- 右下角的治疗文字 不跳帧
				-- else
					local tScale  = v.bCriticalStrike and COMBAT_TEXT_SCALE.CRITICAL or COMBAT_TEXT_SCALE.NORMAL
					fScale  = tScale[nBefore]
					if tScale[nBefore] > tScale[nAfter] then
						fScale = fScale - ((tScale[nBefore] - tScale[nAfter]) * fDiff)
					elseif tScale[nBefore] < tScale[nAfter] then
						fScale = fScale + ((tScale[nAfter] - tScale[nBefore]) * fDiff)
					end
				-- end
			end
			local r, g, b = unpack(v.col)
			k:AppendCharacterID(v.dwTargetID, bTop, r, g, b, nAlpha, { 0, 0, 0, nLeft * COMBAT_TEXT_UI_SCALE, nTop * COMBAT_TEXT_UI_SCALE}, COMBAT_TEXT_FONT, v.szText, 1, fScale)
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
	then
		return
	end
	local dwID = UI_GetClientPlayerID()
	if (nType == SKILL_RESULT_TYPE.STEAL_LIFE and nEffectType == SKILL_EFFECT_TYPE.BUFF) or nType == SKILL_RESULT_TYPE.REFLECTIED_DAMAGE then
		local _    = dwCasterID
		dwCasterID = dwTargetID
		dwTargetID = _
	end
	if dwCasterID ~= dwID and dwTargetID ~= dwID then -- 和我没什么卵关系
		return
	end
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local nTime = GetTime()
	-- 对某些 一次性出现多次伤害的技能 做排序
	local nSort = 0
	for k, v in pairs(CombatText.tShadows) do
		if v.dwTargetID == dwTargetID and v.nFrame <= nSort * 2 + 2 then
			v.nSort = v.nSort + 1
			nSort = nSort + 1
		end
	end
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
	local col     = COMBAT_TEXT_COLOR[nType]
	if nType == SKILL_RESULT_TYPE.STEAL_LIFE then
		col     = COMBAT_TEXT_COLOR[SKILL_RESULT_TYPE.THERAPY]
		szText  = "+" .. nValue
		if dwTargetID == dwID then
			szPoint = "BOTTOM_RIGHT"
		else
			szPoint = "TOP"
		end
	elseif COMBAT_TEXT_STRING[nType] then
		szText = COMBAT_TEXT_STRING[nType]
		if dwTargetID == dwID then
			szPoint = "LEFT"
			col = COMBAT_TEXT_COLOR["BUFF"]
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
		col = COMBAT_TEXT_COLOR["DAMAGE"]
		if bCriticalStrike then
			szText = (szName or "") .. g_tStrings.STR_COLON .. g_tStrings.STR_CS_NAME ..  " -" .. nValue
		else
			szText = (szName or "") .. g_tStrings.STR_COLON .. "-" .. nValue
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
	local col = bCanCancel and COMBAT_TEXT_COLOR.BUFF or COMBAT_TEXT_COLOR.DEBUFF
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
	local nSort = 0
	for k, v in pairs(CombatText.tShadows) do
		if v.dwTargetID == dwTargetID and v.nFrame <= nSort * 2 + 2 then
			v.nSort = v.nSort + 1
			nSort = nSort + 1
		end
	end
	CombatText.tShadows[shadow] = {
		szPoint    = dwTargetID == UI_GetClientPlayerID() and "LEFT" or "TOP",
		dwTargetID = dwTargetID,
		nSort      = nSort,
		szText     = g_tStrings.STR_MSG_MISS,
		nType      = "SKILL_MISS",
		nTime      = nTime,
		nFrame     = 0,
		col        = COMBAT_TEXT_COLOR["SKILL_MISS"],
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
		col        = COMBAT_TEXT_COLOR["BUFF_IMMUNITY"],
	}
end
-- FireUIEvent("COMMON_HEALTH_TEXT", GetClientPlayer().dwID, -8888)
function CombatText.OnCommonHealth(dwCharacterID, nDeltaLife)
	local shadow = CombatText.GetFreeShadow()
	if not shadow then -- 没有空闲的shadow
		return
	end
	local nTime = GetTime()
	local szPoint = "BOTTOM_LEFT"
	if nDeltaLife > 0 then
		if dwCharacterID ~= UI_GetClientPlayerID() then
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
		col        = nDeltaLife > 0 and COMBAT_TEXT_COLOR[SKILL_RESULT_TYPE.THERAPY] or COMBAT_TEXT_COLOR["DAMAGE"],
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
		col        = COMBAT_TEXT_COLOR["DODGE"],
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
		col             = COMBAT_TEXT_COLOR["EXP"],
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
	if #CombatText.tFree < COMBAT_TEXT_MAX_COUNT then
		local sha = handle:AppendItemFromIni(COMBAT_TEXT_INIFILE, "Shadow_Content")
		sha:SetTriangleFan(GEOMETRY_TYPE.TEXT)
		sha:ClearTriangleFanPoint()
		table.insert(CombatText.tFree, sha)
		return sha
	end
end

function CombatText.LoadConfig()
	local path = JH.GetAddonInfo().szRootPath .. "JH_CombatText/config.jx3dat"
	local bExist = IsFileExist(path)
	if bExist then
		local data = LoadLUAData(path)
		if data then
			COMBAT_TEXT_RENDER         = type(data.COMBAT_TEXT_RENDER) ~= "nil" and data.COMBAT_TEXT_RENDER or COMBAT_TEXT_RENDER
			if COMBAT_TEXT_RENDER then
				COMBAT_TEXT_INIFILE = JH.GetAddonInfo().szRootPath .. "JH_CombatText/JH_CombatText_Render.ini"
			else
				COMBAT_TEXT_INIFILE = JH.GetAddonInfo().szRootPath .. "JH_CombatText/JH_CombatText.ini"
			end
			COMBAT_TEXT_MAX_ALPHA      = data.COMBAT_TEXT_MAX_ALPHA or COMBAT_TEXT_MAX_ALPHA
			COMBAT_TEXT_TIME           = data.COMBAT_TEXT_TIME or COMBAT_TEXT_TIME
			COMBAT_TEXT_TOTAL          = data.COMBAT_TEXT_TOTAL or COMBAT_TEXT_TOTAL
			COMBAT_TEXT_MAX_COUNT      = data.COMBAT_TEXT_MAX_COUNT or COMBAT_TEXT_MAX_COUNT
			COMBAT_TEXT_FADE_IN_FRAME  = data.COMBAT_TEXT_FADE_IN_FRAME or COMBAT_TEXT_FADE_IN_FRAME
			COMBAT_TEXT_FADE_OUT_FRAME = data.COMBAT_TEXT_FADE_OUT_FRAME or COMBAT_TEXT_FADE_OUT_FRAME
			COMBAT_TEXT_FONT           = data.COMBAT_TEXT_FONT or COMBAT_TEXT_FONT
			COMBAT_TEXT_CRITICAL       = data.COMBAT_TEXT_CRITICAL or COMBAT_TEXT_CRITICAL
			COMBAT_TEXT_COLOR          = data.COMBAT_TEXT_COLOR or COMBAT_TEXT_COLOR
			COMBAT_TEXT_STRING         = data.COMBAT_TEXT_STRING or COMBAT_TEXT_STRING
			COMBAT_TEXT_SCALE          = data.COMBAT_TEXT_SCALE or COMBAT_TEXT_SCALE
			COMBAT_TEXT_POINT          = data.COMBAT_TEXT_POINT or COMBAT_TEXT_POINT
			setmetatable(COMBAT_TEXT_COLOR, { __index = function() return { 255, 255, 255 } end })
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
			CombatTextWnd:Hide()
		end
		CombatText.LoadConfig()
		Wnd.CloseWindow(ui)
		CombatText.tFree    = {}
		CombatText.tShadows = {}
		Wnd.OpenWindow(COMBAT_TEXT_INIFILE, "JH_CombatText")
	else
		if CombatTextWnd then
			CombatTextWnd:Show()
		end
		if ui then
			Wnd.CloseWindow(ui)
			CombatText.tFree    = {}
			CombatText.tShadows = {}
			collectgarbage("collect")
		end
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["CombatText"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Enable CombatText"], checked = JH_CombatText.bEnable }):Click(function(bCheck)
		JH_CombatText.bEnable = bCheck
		CombatText.CheckEnable()
	end):Pos_()
	ui:Append("WndButton3", { x = 10, y = nY + 10, txt = _L["Load CombatText Config"] }):Click(CombatText.CheckEnable)
end
GUI.RegisterPanel(_L["CombatText"], 2041, g_tStrings.CHANNEL_CHANNEL, PS)

JH.RegisterEvent("LOGIN_GAME", CombatText.CheckEnable)
