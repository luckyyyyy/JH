-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-11-25 14:06:37
local _L = JH.LoadLangPack
local ARENAMAP = false
ScreenHead = {
	tList       = {},
	tNpcList    = {},
	bTeamAlert  = false,
	bIsMe       = true,
	nTeamHp     = 0.3,
	nTeamMp     = 0.1,
	nTime       = 5,
	nFont       = 40,
}
JH.RegisterCustomData("ScreenHead")

local ScreenHead = ScreenHead
local ipairs, pairs = ipairs, pairs
local unpack, tostring, tonumber, sFormat =
	  unpack, tostring, tonumber, string.format
local mMin = math.min
local GetTime, IsPlayer = GetTime, IsPlayer
local GetPlayer, GetClientPlayer, GetClientTeam =
	  GetPlayer, GetClientPlayer, GetClientTeam
local UI_GetClientPlayerID = UI_GetClientPlayerID
local GetTarget, GetBuff, GetEndTime, GetBuffName, FormatTimeString, GetSkillName, GetDistance, GetObjName, JH_IsParty =
	  JH.GetTarget, JH.GetBuff, JH.GetEndTime, JH.GetBuffName, JH.FormatTimeString, JH.GetSkillName, JH.GetDistance, JH.GetTemplateName, JH.IsParty
local SCREEN_SELECT_FIX = 0.3

local SH = {
	tList = {},
	tCache = {
		["Life"] = {},
		["Mana"] = {},
	},
	tPointC = { 25, 25, 180 },
	tPoint = {
		{ 15, 0,  100 },
		{ 35, 0,  100 },
		{ 35, 25, 180 },
		{ 43, 25, 255 },
		{ 25, 50, 180 },
		{ 7,  25, 255 },
		{ 15, 25, 180 },
	},
	tFontCol = { -- font col
		["BUFF"]    = { 255, 128, 0   },
		["DEBUFF"]  = { 255, 0,   255 },
		["Life"]    = { 130, 255, 130 },
		["Mana"]    = { 255, 255, 128 },
		["Other"]   = { 128, 255, 255 },
		["Object"]  = { 0,   255, 255 },
		["CASTING"] = { 150, 200, 255 },
	},
	tArrowCol = {
		["BUFF"]    = { 0,   255, 0   },
		["DEBUFF"]  = { 255, 0,   0   },
		["Life"]    = { 255, 0,   0   },
		["Mana"]    = { 0,   0,   255 },
		["Other"]   = { 255, 0,   0   },
		["Object"]  = { 0,   128, 255 },
		["CASTING"] = { 255, 128, 0   },
	},
	szItemIni = JH.GetAddonInfo().szShadowIni,
}

SH.tFontCol  = LoadLUAData(JH.GetAddonInfo().szRootPath .. "ScreenHead/tFontCol.jx3dat")  or SH.tFontCol
SH.tArrowCol = LoadLUAData(JH.GetAddonInfo().szRootPath .. "ScreenHead/tArrowCol.jx3dat") or SH.tArrowCol

function SH.Init()
	SH.handle = JH.GetShadowHandle("ScreenHead")
end

function SH.GetListText(tab)
	local tName = {}
	for k, _ in pairs(tab) do
		if type(k) == "string" then
			table.insert(tName, k)
		end
	end
	return table.concat(tName, "\n")
end

function SH:Create(obj, info, nIndex)
	local dwID = obj.dwID
	local txt, handle, lifeper, manaper, data
	local tManaCol = { 50, 100, 255 }
	handle = self.handle:Lookup(tostring(dwID))
	if not nIndex then
		assert(handle)
		nIndex = handle.nIndex
	end
	data = self.tList[dwID][nIndex]
	if not data then return end
	if info.nMaxLife == 0 then info.nMaxLife = 1 end
	if info.nMaxMana == 0 then info.nMaxMana = 1 end
	lifeper = info.nCurrentLife / info.nMaxLife
	manaper = info.nCurrentMana / info.nMaxMana -- 苍云啥的懒得修正了 反正没意义
	if manaper > 1 then manaper = 1 end
	if lifeper > 1 then lifeper = 1 end
	local nSec
	if data.type and data.type ~= "Other" then
		if data.type == "BUFF" or data.type == "DEBUFF" then
			local KBuff = GetBuff(data.dwID, obj) -- 只判断dwID 反正不可能同时获得不同lv
			if KBuff then
				nSec = GetEndTime(KBuff.GetEndTime())
				if KBuff.nStackNum > 1 then
					txt = sFormat("%s(%d)_%s", data.txt or GetBuffName(KBuff.dwID, KBuff.nLevel), KBuff.nStackNum, FormatTimeString(nSec, 1, true))
				else
					txt = sFormat("%s_%s", data.txt or GetBuffName(KBuff.dwID, KBuff.nLevel), FormatTimeString(nSec, 1, true))
				end
			else
				return self:Remove(dwID, nIndex)
			end
		elseif data.type == "Life" or data.type == "Mana" then
			if obj.nMoveState == MOVE_STATE.ON_DEATH then
				return self:Remove(dwID, nIndex)
			end
			if data.type == "Life" then
				if lifeper > ScreenHead.nTeamHp then
					return self:Remove(dwID, nIndex)
				end
				txt = g_tStrings.STR_SKILL_H_LIFE_COST .. sFormat("%d/%d", info.nCurrentLife, info.nMaxLife)
			elseif data.type == "Mana" then
				if manaper > ScreenHead.nTeamMp then
					return self:Remove(dwID, nIndex)
				end
				txt = g_tStrings.STR_SKILL_H_MANA_COST .. sFormat("%d/%d", info.nCurrentMana, info.nMaxMana)
			end
		elseif data.type == "CASTING" then
			tManaCol = { 255, 128, 0 }
			local bIsPrepare, dwSkillID, dwSkillLevel
			bIsPrepare, dwSkillID, dwSkillLevel, manaper = obj.GetSkillPrepareState()
			if bIsPrepare then
				txt = data.txt or GetSkillName(dwSkillID, dwSkillLevel)
				-- txt = txt .. sFormat("%d%%", manaper * 100) -- 还是不加了 避免影响判断
			else
				return self:Remove(dwID, nIndex)
			end
		elseif data.type == "Object" then
			txt = data.txt or _L["aim"]
		end
	else
		if not data.nNow then
			data.nNow = GetTime()
		else
			if (GetTime() - data.nNow) / 1000 > ScreenHead.nTime then
				return self:Remove(dwID, nIndex)
			end
		end
		txt = data.txt or _L["Call Alert"]
		data.type = data.type or "Other"
	end

	if not handle then
		self.handle:AppendItemFromString(sFormat("<handle> name=\"%s\" </handle>", dwID))
		handle       = self.handle:Lookup(tostring(dwID))
		handle.Init  = true
		handle.Arrow = handle:AppendItemFromIni(self.szItemIni, "shadow", "Arrow")
		handle.Text  = handle:AppendItemFromIni(self.szItemIni, "shadow", "Text")
		handle.BG    = handle:AppendItemFromIni(self.szItemIni, "shadow", "BG")
		handle.BG2   = handle:AppendItemFromIni(self.szItemIni, "shadow", "BG2")
		handle.Life  = handle:AppendItemFromIni(self.szItemIni, "shadow", "Life")
		handle.Mana  = handle:AppendItemFromIni(self.szItemIni, "shadow", "Mana")
		handle.fY    = 0
		handle.s     = 0
	end
	handle.nIndex = nIndex
	local KTarget = GetTarget()
	local r, g, b
	if data.col then
		r, g, b = unpack(data.col)
	else
		r, g, b = unpack(self.tArrowCol[data.type])
	end
	local cX, cY, cA = unpack(self.tPointC)
	local fX, fY = 25, 50
	if handle.s == 1 then
		handle.fY = handle.fY + 2
		if handle.fY >= 10 then
			handle.s = 0
		end
	else
		handle.fY = handle.fY - 2
		if handle.fY <= 0 then
			handle.s = 1
		end
	end
	fY = fY - handle.fY
	local nDistance = GetDistance(obj)
	nDistance = math.max(15, nDistance)
	fX = fX - fX * mMin(30, nDistance) * 0.012
 	local value = 1 - mMin(30, nDistance) * 0.01
	handle.Arrow:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	handle.Arrow:SetD3DPT(D3DPT.TRIANGLEFAN)
	handle.Arrow:ClearTriangleFanPoint()
	if KTarget and KTarget.dwID == dwID then
		r, g, b = mMin(255, r + r * SCREEN_SELECT_FIX), mMin(255, g + g * SCREEN_SELECT_FIX), mMin(255, b + b * SCREEN_SELECT_FIX)
	end
	handle.Arrow:AppendCharacterID(dwID, true, r, g, b, cA, { 0, 0, 0, cX * value - fX, cY * value - fY })
	for k,v in ipairs(self.tPoint) do
		local x, y, a = unpack(v)
		handle.Arrow:AppendCharacterID(dwID, true, r, g, b, a, { 0, 0, 0, x * value - fX, y * value - fY })
	end
	local x, y, a = unpack(self.tPoint[1])
	handle.Arrow:AppendCharacterID(dwID, true, r, g, b, a, { 0, 0, 0, x * value - fX, y * value - fY })

	handle.Text:SetTriangleFan(GEOMETRY_TYPE.TEXT)
	handle.Text:ClearTriangleFanPoint()
	local r, g, b = unpack(self.tFontCol[data.type])
	if KTarget and KTarget.dwID == dwID then
		r, g, b = mMin(255, r + r * SCREEN_SELECT_FIX), mMin(255, g + g * SCREEN_SELECT_FIX), mMin(255, b + b * SCREEN_SELECT_FIX)
	end
	local szName = data.szName or GetObjName(obj)
	handle.Text:AppendCharacterID(dwID, true, r, g, b, 240, { 0, 0, 0, 0, -100 }, ScreenHead.nFont, szName, 1, 1)
	if nSec and nSec < 5 then
		handle.Text:AppendCharacterID(dwID, true, 255, 0, 0, 240, { 0, 0, 0, 0, -80 }, ScreenHead.nFont, txt, 1, 1)
	else
		handle.Text:AppendCharacterID(dwID, true, r, g, b, 240, { 0, 0, 0, 0, -80 }, ScreenHead.nFont, txt, 1, 1)
	end

	for k,v in ipairs({ handle.Life, handle.Mana }) do
		v:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
		v:SetD3DPT(D3DPT.TRIANGLEFAN)
		v:ClearTriangleFanPoint()
	end

	local bcX, bcY = -50, -60
	if handle.Init then -- 绘制边框 免得每次刷新
		for k,v in ipairs({ handle.BG, handle.BG2 }) do
			v:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
			v:SetD3DPT(D3DPT.TRIANGLEFAN)
			v:ClearTriangleFanPoint()
		end
		handle.BG:AppendCharacterID(dwID, true, 255, 255, 255, 200, { 0, 0, 0, bcX, bcY })
		handle.BG:AppendCharacterID(dwID, true, 255, 255, 255, 200, { 0, 0, 0, bcX + 100, bcY })
		handle.BG:AppendCharacterID(dwID, true, 255, 255, 255, 200, { 0, 0, 0, bcX + 100, bcY + 12 })
		handle.BG:AppendCharacterID(dwID, true, 255, 255, 255, 200, { 0, 0, 0, bcX, bcY + 12 })
		bcX, bcY = -49, -59
		handle.BG2:AppendCharacterID(dwID, true, 120, 120, 120, 80, { 0, 0, 0, bcX, bcY })
		handle.BG2:AppendCharacterID(dwID, true, 120, 120, 120, 80, { 0, 0, 0, bcX + 100 - 2, bcY })
		handle.BG2:AppendCharacterID(dwID, true, 120, 120, 120, 80, { 0, 0, 0, bcX + 100 - 2, bcY + 12 - 2 })
		handle.BG2:AppendCharacterID(dwID, true, 120, 120, 120, 80, { 0, 0, 0, bcX, bcY + 12 - 2})
		handle.Init = nil
	end
	bcX, bcY = -49, -59
	if lifeper ~= 0 then
		local r, g ,b = 220, 40, 0
		if KTarget and KTarget.dwID == dwID then
			r, g, b = mMin(255, r + r * SCREEN_SELECT_FIX), mMin(255, g + g * SCREEN_SELECT_FIX), mMin(255, b + b * SCREEN_SELECT_FIX)
		end
		handle.Life:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY })
		handle.Life:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (98 * lifeper), bcY })
		handle.Life:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (98 * lifeper), bcY + 5 })
		handle.Life:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY + 5 })
	end
	bcX, bcY = -49, -54
	if manaper ~= 0 then
		local r, g, b = unpack(tManaCol)
		if KTarget and KTarget.dwID == dwID then
			r, g, b = mMin(255, r + r * SCREEN_SELECT_FIX), mMin(255, g + g * SCREEN_SELECT_FIX), mMin(255, b + b * SCREEN_SELECT_FIX)
		end
		handle.Mana:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY })
		handle.Mana:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (98 * manaper), bcY })
		handle.Mana:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (98 * manaper), bcY + 5 })
		handle.Mana:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY + 5 })
	end
end

function SH:Remove(dwID, nIndex)
	local handle = self.handle:Lookup(tostring(dwID))
	local data = self.tList[dwID]
	if nIndex then
		table.remove(data, nIndex)
		if #data == 0 then
			self.tList[dwID] = nil
		end
	else
		self.tList[dwID] = nil
	end
	self.handle:RemoveItem(tostring(dwID))
end

function SH.Clear()
	SH.tList = {}
	SH.handle:Clear()
	local _, _, szLang = GetVersion()
	if szLang == "zhcn" and JH.IsInArena() and not JH.bDebugClient then
		ARENAMAP = true
	else
		ARENAMAP = false
	end
end

function SH.GetObject(dwID)
	local p, info
	if IsPlayer(dwID) then
		local me = GetClientPlayer()
		if dwID == me.dwID then
			p, info = me, me
		elseif JH_IsParty(dwID) then
			p, info = GetPlayer(dwID), GetClientTeam().GetMemberInfo(dwID)
		else
			p, info = GetPlayer(dwID), GetPlayer(dwID)
		end
	else
		p, info = GetNpc(dwID), GetNpc(dwID)
	end
	return p, info
end

function SH.OnBreathe()
	local me = GetClientPlayer()
	if not me then return end
	for dwID, t in pairs(SH.tList) do
		local p, info = SH.GetObject(dwID)
		if not p then
			SH:Remove(dwID)
		else
			local handle = SH.handle:Lookup(tostring(dwID))
			if not handle then
				if #t > 0 then
					SH:Create(p, info, #t)
				end
			else
				SH:Create(p, info)
			end
		end
	end
end

function SH.KillBreathe()
	JH.BreatheCall("ScreenHead_Fight")
	SH.tCache["Mana"] = {}
	SH.tCache["Life"] = {}
end

function SH.OnBreatheFight()
	local me = GetClientPlayer()
	if not me then return end
	if not me.bFightState then -- kill fix bug
		SH.KillBreathe()
	end
	local team = GetClientTeam()
	local list = {}
	if me.IsInParty() and not ScreenHead.bIsMe then
		list = team.GetTeamMemberList()
	else
		list[1] = me.dwID
	end
	for k, v in ipairs(list) do
		local p, info = SH.GetObject(v)
		if p and info then
			if p.nMoveState == MOVE_STATE.ON_DEATH then
				SH.tCache["Mana"][v] = nil
				SH.tCache["Life"][v] = nil
			else
				if info.nMaxLife == 0 then info.nMaxLife = 1 end
				if info.nMaxMana == 0 then info.nMaxMana = 1 end
				local lifeper = info.nCurrentLife / info.nMaxLife
				local manaper = info.nCurrentMana / info.nMaxMana
				if lifeper < ScreenHead.nTeamHp then
					if not SH.tCache["Life"][v] then
						SH.tCache["Life"][v] = true
						SH.RegisterHead(v,{  type = "Life" })
					end
				else
					SH.tCache["Life"][v] = nil
				end
				if manaper < ScreenHead.nTeamMp and p.dwForceID < 7 then
					if not SH.tCache["Mana"][v] then
						SH.tCache["Mana"][v] = true
						SH.RegisterHead(v,{  type = "Mana" })
					end
				else
					SH.tCache["Mana"][v] = nil
				end
			end
		end
	end
end

function SH.RegisterFight()
	if arg0 and ScreenHead.bTeamAlert then
		JH.BreatheCall("ScreenHead_Fight", SH.OnBreatheFight)
	else
		SH.KillBreathe()
	end
end

function SH.RegisterHead(dwID, tab)
	if ARENAMAP then return end
	if not SH.tList[dwID] then
		SH.tList[dwID] = {}
	end
	if not tab then tab = {} end
	if tab.type and tab.type == "BUFF" or tab.type == "DEBUFF" then
		for k, v in ipairs(SH.tList[dwID]) do
			if v.type == tab.type and v.dwID == tab.dwID then
				return
			end
		end
	end
	table.insert(SH.tList[dwID], tab)
	local p, info = SH.GetObject(dwID)
	if p and info then
		SH:Create(p, info, #SH.tList[dwID])
	end
end

function SH.OnBuffUpdate()
	if arg1 then return end
	local szName = GetBuffName(arg4,arg8)
	if ScreenHead.tList[szName] and Table_BuffIsVisible(arg4, arg8) then
		local type = arg3 and "BUFF" or "DEBUFF"
		SH.RegisterHead(arg0, { type = type, dwID = arg4 })
	end
end

function SH.OnNpcUpdate()
	local szName = GetObjName(GetNpc(arg0))
	if ScreenHead.tNpcList[szName] then
		SH.RegisterHead(arg0,{ type = "Object", txt = _L["aim"] })
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["HeadAlert"], font = 27 }):Pos_()
	ui:Append("WndButton2", { x = 400, y = 20, txt = g_tStrings.FONT })
	:Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			ScreenHead.nFont = nFont
		end)
	end)
	nX = ui:Append("WndCheckBox",{ x = 10, y = nY + 10, checked = ScreenHead.bTeamAlert })
	:Text(_L["less life/mana HeadAlert"]):Click(function(bChecked)
		ScreenHead.bTeamAlert = bChecked
		ui:Fetch("Track_MP"):Enable(bChecked)
		ui:Fetch("Track_HP"):Enable(bChecked)
		ui:Fetch("bIsMe"):Enable(bChecked)
		local me = GetClientPlayer()
		if bChecked and me.bFightState then
			JH.BreatheCall("ScreenHead_Fight",SH.OnBreatheFight)
		else
			SH.KillBreathe()
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bIsMe", { x = nX + 10, y = nY + 10, checked = ScreenHead.bIsMe,enable = ScreenHead.bTeamAlert })
	:Text(_L["only Monitor self"]):Click(function(bChecked)
		ScreenHead.bIsMe = bChecked
	end):Pos_()

	nX = ui:Append("Text", { txt = _L["While HP less than"], x = 10, y = nY }):Pos_()
	nX,nY = ui:Append("WndTrackBar", "Track_HP", { x = nX +10, y = nY + 3, enable = ScreenHead.bTeamAlert })
	:Range(0,100,100):Value(ScreenHead.nTeamHp * 100):Change(function(nVal) ScreenHead.nTeamHp = nVal / 100 end):Pos_()

	nX = ui:Append("Text", { txt = _L["While MP less than"], x = 10, y = nY }):Pos_()
	nX,nY = ui:Append("WndTrackBar", "Track_MP", { x = nX + 10, y = nY + 3, enable = ScreenHead.bTeamAlert })
	:Range(0,100,100):Value(ScreenHead.nTeamMp * 100):Change(function(nVal) ScreenHead.nTeamMp = nVal / 100 end):Pos_()

	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Manually add (One per line)"], font = 27 }):Pos_()
	nX,nY =ui:Append("WndEdit",{ x = 10, y = nY + 10, w = 450, h = 70, limit = 4096,multi = true})
	:Text(SH.GetListText(ScreenHead.tList)):Change(function(szText)
		local t = {}
		for _, v in ipairs(JH.Split(szText, "\n")) do
			v = JH.Trim(v)
			if v ~= "" then
				t[v] = true
			end
		end
		ScreenHead.tList = t
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Manually add Npc Name (One per line)"], font = 27 }):Pos_()
	ui:Append("WndEdit",{ x = 10, y = nY + 10, w = 450, h = 70, limit = 4096,multi = true})
	:Text(SH.GetListText(ScreenHead.tNpcList)):Change(function(szText)
		local t = {}
		for _, v in ipairs(JH.Split(szText, "\n")) do
			v = JH.Trim(v)
			if v ~= "" then
				t[v] = true
			end
		end
		ScreenHead.tNpcList = t
	end)
end

JH.RegisterInit("ScreenHead",
	{ "Breathe", SH.OnBreathe },
	{ "LOADING_END", SH.Clear },
	{ "FIGHT_HINT", SH.RegisterFight },
	{ "LOGIN_GAME", SH.Init },
	{ "BUFF_UPDATE", SH.OnBuffUpdate },
	{ "NPC_ENTER_SCENE", SH.OnNpcUpdate },
	{ "JH_SCREENHEAD", function()
			SH.RegisterHead(arg0, arg1)
	end }
)

GUI.RegisterPanel(_L["HeadAlert"], 431, _L["Dungeon"], PS)
