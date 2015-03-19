-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-03-20 07:18:58
local _L = JH.LoadLangPack

ScreenHead = {
	tList = {},
	tNpcList = {},
	bEnable = true,
	bEnableRGES = true,
	bTeamAlert = false,
	bIsMe = false,
	nTeamHp = 0.3,--0.3,
	nTeamMp = 0.1,
	nTime = 5,
	nFont = 40,
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
local GetTarget, HasBuff, GetEndTime, GetBuffName, GetBuffTimeString, GetSkillName, GetDistance, GetTemplateName, IsParty =
	  JH.GetTarget, JH.HasBuff, JH.GetEndTime, JH.GetBuffName, JH.GetBuffTimeString, JH.GetSkillName, JH.GetDistance, JH.GetTemplateName, IsParty
local SCREEN_SELECT_FIX = 0.3

local _ScreenHead = {
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
		["Buff"]   = { 255, 128, 0   },
		["Debuff"] = { 255, 0,   255 },
		["Life"]   = { 130, 255, 130 },
		["Mana"]   = { 255, 255, 128 },
		["Other"]  = { 128, 255, 255 },
		["Object"] = { 0,   255, 255 },
		["Skill"]  = { 150, 200, 255 },
	},
	tArrowCol = {
		["Buff"]   = { 0,   255, 0   },
		["Debuff"] = { 255, 0,   0   },
		["Life"]   = { 255, 0,   0   },
		["Mana"]   = { 0,   0,   255 },
		["Other"]  = { 255, 0,   0   },
		["Object"] = { 0,   128, 255 },
		["Skill"]  = { 255, 128, 0   },
	},
	szItemIni = JH.GetAddonInfo().szShadowIni,
}

function _ScreenHead.Init()
	_ScreenHead.handle = JH.GetShadowHandle("ScreenHead")
end

function _ScreenHead.GetListText(tab)
	local tName = {}
	for k, _ in pairs(tab) do
		if type(k) == "string" then
			table.insert(tName, k)
		end
	end
	return table.concat(tName, "\n")
end

function _ScreenHead:Create(obj, info, nIndex)
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
	local _r, _g, _b
	if data.type and data.type ~= "Other" then
		if data.type == "Buff" or data.type == "Debuff" then
			local bExist, tBuff = HasBuff(data.dwID, obj) -- 只判断dwID 反正不可能同时获得不同lv
			if bExist then
				local nSec = GetEndTime(tBuff.nEndFrame)
				if nSec < 5 then
					_r, _g, _b = 255, 0, 0
				end
				if nSec < 0 then
					nSec = 0
				end
				if tBuff.nStackNum > 1 then
					txt = sFormat("%s(%d)_%s", data.szName or GetBuffName(tBuff.dwID, tBuff.nLevel), tBuff.nStackNum, GetBuffTimeString(nSec, 5999))
				else
					txt = sFormat("%s_%s", data.szName or GetBuffName(tBuff.dwID, tBuff.nLevel), GetBuffTimeString(nSec, 5999))
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
		elseif data.type == "Skill" then
			tManaCol = { 255,128,0 }
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
	local value

	if nDistance > 30 then
		fX = fX - fX * 30 * 0.011
		value = 1 - 30 * 0.01
	else
		fX = fX - fX * nDistance * 0.011
		value = 1 - nDistance * 0.01
	end

	handle.Arrow:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	handle.Arrow:SetD3DPT(D3DPT.TRIANGLEFAN)
	handle.Arrow:ClearTriangleFanPoint()
	handle.Arrow:AppendCharacterID(dwID, true, r, g, b, cA, { 0, 0, 0, cX * value - fX, cY * value - fY })

	if KTarget and KTarget.dwID == dwID then
		r, g, b = mMin(255, r + r * SCREEN_SELECT_FIX), mMin(255, g + g * SCREEN_SELECT_FIX), mMin(255, b + b * SCREEN_SELECT_FIX)
	end
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
	local szName = IsPlayer(obj.dwID) and obj.szName or GetTemplateName(obj)

	handle.Text:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, 0, -110 }, ScreenHead.nFont, szName, 1, 1)
	if dwID == UI_GetClientPlayerID() then
		handle.Text:AppendCharacterID(dwID, true, 255, 0, 0, 255, { 0, 0, 0, 0, -95 }, ScreenHead.nFont, _L["_ME_"], 1, 1)
	else
		handle.Text:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, 0, -95 }, ScreenHead.nFont, _L("%.1f feet", nDistance), 1, 1)
	end
	if _r then r, g, b = _r, _g, _b end -- 5秒内显示红色倒计时
	handle.Text:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, 0, -80 }, ScreenHead.nFont, txt, 1, 1)

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
		handle.BG2:AppendCharacterID(dwID, true, 80, 80, 80, 80, { 0, 0, 0, bcX, bcY })
		handle.BG2:AppendCharacterID(dwID, true, 80, 80, 80, 80, { 0, 0, 0, bcX + 100 - 2, bcY })
		handle.BG2:AppendCharacterID(dwID, true, 80, 80, 80, 80, { 0, 0, 0, bcX + 100 - 2, bcY + 12 - 2 })
		handle.BG2:AppendCharacterID(dwID, true, 80, 80, 80, 80, { 0, 0, 0, bcX, bcY + 12 - 2})
		handle.Init = nil
	end
	bcX, bcY = -49, -59
	local r, g ,b = 220, 40, 0
	if KTarget and KTarget.dwID == dwID then
		r, g, b = mMin(255, r + r * SCREEN_SELECT_FIX), mMin(255, g + g * SCREEN_SELECT_FIX), mMin(255, b + b * SCREEN_SELECT_FIX)
	end
	handle.Life:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY })
	handle.Life:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (100 * lifeper) - 2, bcY })
	handle.Life:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (100 * lifeper) - 2, bcY + 5 })
	handle.Life:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY + 5 })
	local r, g, b = unpack(tManaCol)
	if KTarget and KTarget.dwID == dwID then
		r, g, b = mMin(255, r + r * SCREEN_SELECT_FIX), mMin(255, g + g * SCREEN_SELECT_FIX), mMin(255, b + b * SCREEN_SELECT_FIX)
	end
	bcX, bcY = -49, -54
	handle.Mana:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY })
	handle.Mana:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (100 * manaper) - 2, bcY })
	handle.Mana:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (100 * manaper) - 2, bcY + 5 })
	handle.Mana:AppendCharacterID(dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY + 5 })
end

function _ScreenHead:Remove(dwID, nIndex)
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

function _ScreenHead.Clear()
	_ScreenHead.tList = {}
	_ScreenHead.handle:Clear()
end

function _ScreenHead.GetObject(dwID)
	local p, info
	if IsPlayer(dwID) then
		local me = GetClientPlayer()
		if dwID == me.dwID then
			p, info = me, me
		elseif IsParty(dwID) then
			p, info = GetPlayer(dwID), GetClientTeam().GetMemberInfo(dwID)
		else
			p, info = GetPlayer(dwID), GetPlayer(dwID)
		end
	else
		p, info = GetNpc(dwID), GetNpc(dwID)
	end
	return p, info
end

function _ScreenHead.OnBreathe()
	local me = GetClientPlayer()
	if not me then return end
	for dwID, t in pairs(_ScreenHead.tList) do
		local p, info = _ScreenHead.GetObject(dwID)
		if not p then
			_ScreenHead:Remove(dwID)
		else
			local handle = _ScreenHead.handle:Lookup(tostring(dwID))
			if not handle then
				if #t > 0 then
					_ScreenHead:Create(p, info, #t)
				end
			else
				_ScreenHead:Create(p, info)
			end
		end
	end
end

function _ScreenHead.KillBreathe()
	JH.BreatheCall("ScreenHead_Fight")
	_ScreenHead.tCache["Mana"] = {}
	_ScreenHead.tCache["Life"] = {}
end

function _ScreenHead.OnBreatheFight()
	local me = GetClientPlayer()
	if not me then return end
	if not me.bFightState then -- kill fix bug
		_ScreenHead.KillBreathe()
	end
	local team = GetClientTeam()
	local list = {}
	if me.IsInParty() and not ScreenHead.bIsMe then
		list = team.GetTeamMemberList()
	else
		list[1] = me.dwID
	end
	for k,v in ipairs(list) do
		local p,info = _ScreenHead.GetObject(v)
		if p and info then
			if p.nMoveState == MOVE_STATE.ON_DEATH then
				_ScreenHead.tCache["Mana"][v] = nil
				_ScreenHead.tCache["Life"][v] = nil
			else
				if info.nMaxLife == 0 then info.nMaxLife = 1 end
				if info.nMaxMana == 0 then info.nMaxMana = 1 end
				local lifeper = info.nCurrentLife / info.nMaxLife
				local manaper = info.nCurrentMana / info.nMaxMana
				if lifeper < ScreenHead.nTeamHp then
					if not _ScreenHead.tCache["Life"][v] then
						_ScreenHead.tCache["Life"][v] = true
						_ScreenHead.RegisterHead(v,{  type = "Life" })
					end
				else
					_ScreenHead.tCache["Life"][v] = nil
				end
				if manaper < ScreenHead.nTeamMp and p.dwForceID < 7 then
					if not _ScreenHead.tCache["Mana"][v] then
						_ScreenHead.tCache["Mana"][v] = true
						_ScreenHead.RegisterHead(v,{  type = "Mana" })
					end
				else
					_ScreenHead.tCache["Mana"][v] = nil
				end
			end
		end
	end
end

function _ScreenHead.RegisterFight(bEnable)
	if arg0 and ScreenHead.bTeamAlert then
		JH.BreatheCall("ScreenHead_Fight", _ScreenHead.OnBreatheFight)
	else
		_ScreenHead.KillBreathe()
	end
end

function _ScreenHead.RegisterHead(dwID, tab)
	if not ScreenHead.bEnable then return end
	if not _ScreenHead.tList[dwID] then
		_ScreenHead.tList[dwID] = {}
	end
	if not tab then tab = {} end
	if tab.type and tab.type == "Buff" or tab.type == "Debuff" then
		for k, v in ipairs(_ScreenHead.tList[dwID]) do
			if v.type == tab.type and v.dwID == tab.dwID then
				return
			end
		end
	end
	table.insert(_ScreenHead.tList[dwID], tab)
	local p, info = _ScreenHead.GetObject(dwID)
	if p and info then
		_ScreenHead:Create(p, info, #_ScreenHead.tList[dwID])
	end
end

function _ScreenHead.OnBuffUpdate()
	if not ScreenHead.bEnable then return end
	if arg1 then return end
	local szName = GetBuffName(arg4,arg8)
	if ScreenHead.tList[szName] and Table_BuffIsVisible(arg4, arg8) then
		local type = arg3 and "Buff" or "Debuff"
		_ScreenHead.RegisterHead(arg0, { type = type, dwID = arg4 })
	end
end

function _ScreenHead.OnNpcUpdate()
	local szName = GetTemplateName(GetNpc(arg0))
	if ScreenHead.tNpcList[szName] then
		_ScreenHead.RegisterHead(arg0,{ type = "Object", txt = _L["aim"] })
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	ui:Append("Text", { x = 0, y = 0, txt = _L["HeadAlert"], font = 27 })
	ui:Append("WndButton2", { x = 400, y = 20, txt = g_tStrings.FONT })
	:Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			ScreenHead.nFont = nFont
		end)
	end)
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = 28, checked = ScreenHead.bEnable })
	:Text(_L["Enable ScreenHead"]):Click(function(bChecked)
		ScreenHead.bEnable = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = ScreenHead.bEnableRGES })
	:Text(_L["Bind RGES"]):Click(function(bChecked)
		ScreenHead.bEnableRGES = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox",{ x = 10, y = nY, checked = ScreenHead.bTeamAlert })
	:Text(_L["less life/mana HeadAlert"]):Click(function(bChecked)
		ScreenHead.bTeamAlert = bChecked
		ui:Fetch("Track_MP"):Enable(bChecked)
		ui:Fetch("Track_HP"):Enable(bChecked)
		ui:Fetch("bIsMe"):Enable(bChecked)
		local me = GetClientPlayer()
		if bChecked and me.bFightState then
			JH.BreatheCall("ScreenHead_Fight",_ScreenHead.OnBreatheFight)
		else
			_ScreenHead.KillBreathe()
		end
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox","bIsMe",{ x = nX + 10, y = nY, checked = ScreenHead.bIsMe,enable = ScreenHead.bTeamAlert })
	:Text(_L["only Monitor self"]):Click(function(bChecked)
		ScreenHead.bIsMe = bChecked
	end):Pos_()

	nX = ui:Append("Text", { txt = _L["While HP less than"], x = 10, y = nY }):Pos_()
	nX,nY = ui:Append("WndTrackBar", "Track_HP", { x = nX +10, y = nY + 3, enable = ScreenHead.bTeamAlert })
	:Range(0,100,50):Value(ScreenHead.nTeamHp * 100):Change(function(nVal) ScreenHead.nTeamHp = nVal / 100 end):Pos_()

	nX = ui:Append("Text", { txt = _L["While MP less than"], x = 10, y = nY }):Pos_()
	nX,nY = ui:Append("WndTrackBar", "Track_MP", { x = nX + 10, y = nY + 3, enable = ScreenHead.bTeamAlert })
	:Range(0,100,50):Value(ScreenHead.nTeamMp * 100):Change(function(nVal) ScreenHead.nTeamMp = nVal / 100 end):Pos_()

	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Manually add (One per line)"], font = 27 }):Pos_()
	nX,nY =ui:Append("WndEdit",{ x = 10, y = nY + 10, w = 450, h = 70, limit = 4096,multi = true})
	:Text(_ScreenHead.GetListText(ScreenHead.tList)):Change(function(szText)
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
	:Text(_ScreenHead.GetListText(ScreenHead.tNpcList)):Change(function(szText)
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
	{ "Breathe", _ScreenHead.OnBreathe },
	{ "LOADING_END", _ScreenHead.Clear },
	{ "FIGHT_HINT", _ScreenHead.RegisterFight },
	{ "LOGIN_GAME", _ScreenHead.Init },
	{ "BUFF_UPDATE", _ScreenHead.OnBuffUpdate },
	{ "NPC_ENTER_SCENE", _ScreenHead.OnNpcUpdate },
	{ "JH_SCREENHEAD", function()
		if not ScreenHead.bEnableRGES then return end
		_ScreenHead.RegisterHead(arg0, arg1)
	end }
)

GUI.RegisterPanel(_L["HeadAlert"], 2789, _L["RGES"], PS)
