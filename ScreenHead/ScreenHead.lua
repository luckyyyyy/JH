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
local unpack = unpack
local GetPlayer = GetPlayer
local GetClientPlayer, GetClientTeam = GetClientPlayer, GetClientTeam

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

_ScreenHead.Init = function()
	_ScreenHead.handle = JH.GetShadowHandle("ScreenHead")
end

_ScreenHead.GetListText = function(tab)
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
	if data.type and data.type ~= "Other" then
		if data.type == "Buff" or data.type == "Debuff" then
			local bExist,tBuff = JH.HasBuff(data.dwID,obj) -- 只判断dwID 反正不可能同时获得不同lv
			if bExist then
				if tBuff.nStackNum > 1 then
					txt = string.format("%s(%d)_%s", data.szName or JH.GetBuffName(tBuff.dwID, tBuff.nLevel), tBuff.nStackNum, JH.GetBuffTimeString(JH.GetEndTime(tBuff.nEndFrame), 5999))
				else
					txt = string.format("%s_%s", data.szName or JH.GetBuffName(tBuff.dwID, tBuff.nLevel), JH.GetBuffTimeString(JH.GetEndTime(tBuff.nEndFrame), 5999))
				end
			else
				return self:Remove(dwID,nIndex)
			end
		elseif data.type == "Life" or data.type == "Mana" then
			if obj.nMoveState == MOVE_STATE.ON_DEATH then
				return self:Remove(dwID, nIndex)
			end
			if data.type == "Life" then
				if lifeper > ScreenHead.nTeamHp then
					return self:Remove(dwID, nIndex)
				end
				txt = g_tStrings.STR_SKILL_H_LIFE_COST .. string.format("%d/%d", info.nCurrentLife, info.nMaxLife)
			elseif data.type == "Mana" then
				if manaper > ScreenHead.nTeamMp then
					return self:Remove(dwID, nIndex)
				end
				txt = g_tStrings.STR_SKILL_H_MANA_COST .. string.format("%d/%d", info.nCurrentMana, info.nMaxMana)
			end
		elseif data.type == "Skill" then
			tManaCol = { 255,128,0 }
			local bIsPrepare, dwSkillID, dwSkillLevel
			bIsPrepare, dwSkillID, dwSkillLevel, manaper = obj.GetSkillPrepareState()
			if bIsPrepare then
				txt = data.txt or JH.GetSkillName(dwSkillID, dwSkillLevel)
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
		self.handle:AppendItemFromString(string.format("<handle> name=\"%s\" </handle>", dwID))
		handle = self.handle:Lookup(tostring(dwID))
		handle.Arrow = handle:AppendItemFromIni(self.szItemIni, "shadow", dwID .. "Arrow")
		handle.Text = handle:AppendItemFromIni(self.szItemIni, "shadow", dwID .. "Text")
		handle.BG = handle:AppendItemFromIni(self.szItemIni, "shadow", dwID .. "BG")
		handle.Life = handle:AppendItemFromIni(self.szItemIni, "shadow", dwID .. "Life")
		handle.Mana = handle:AppendItemFromIni(self.szItemIni, "shadow", dwID .. "Mana")
		handle.fY = 0
		handle.s = 0
	end
	handle.nIndex = nIndex
	local r, g, b
	if data.col then
		r, g, b = unpack(data.col)
	else
		r, g, b = unpack(self.tArrowCol[data.type])
	end
	local cX, cY, cA = unpack(self.tPointC)
	local fX, fY = 25,50
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
	local nDistance = tonumber(string.format("%.1f", JH.GetDistance(obj)))

	if nDistance > 30 then
		nDistance = 30
	end
	fX = fX - fX * nDistance * 0.011
	local value = 1 - nDistance * 0.01
	
	handle.Arrow:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	handle.Arrow:SetD3DPT(D3DPT.TRIANGLEFAN)
	handle.Arrow:ClearTriangleFanPoint()
	handle.Arrow:AppendCharacterID(dwID, true, r, g, b, cA, { 0, 0, 0, cX * value - fX, cY * value - fY })
	for k,v in ipairs(self.tPoint) do
		local x, y, a = unpack(v)
		handle.Arrow:AppendCharacterID(dwID, true, r, g, b, a, { 0, 0, 0, x * value - fX, y * value - fY })
	end
	local x, y, a = unpack(self.tPoint[1])
	handle.Arrow:AppendCharacterID(dwID, true, r, g, b, a, { 0, 0, 0, x * value - fX, y * value - fY })
	---
	
	handle.Text:SetTriangleFan(GEOMETRY_TYPE.TEXT)
	handle.Text:ClearTriangleFanPoint()
	local r, g, b = unpack(self.tFontCol[data.type])
	local szName = obj.szName
	if not IsPlayer(obj.dwID) then
		szName = JH.GetTemplateName(obj)
	end
	handle.Text:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, 0, -80 }, ScreenHead.nFont, txt, 1, 1)
	handle.Text:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, 0, -95 }, ScreenHead.nFont, _L("%.1f feet", JH.GetDistance(obj)), 1, 1)
	handle.Text:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, 0, -110 }, ScreenHead.nFont, szName, 1, 1)

	local bcX, bcY = -50 , -50
	for k,v in ipairs({ handle.Life, handle.Mana, handle.BG }) do
		v:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
		v:SetD3DPT(D3DPT.TRIANGLEFAN)
		v:ClearTriangleFanPoint()
	end
	handle.BG:AppendCharacterID(dwID, true, 255, 255, 255, 255, { 0, 0, 0, bcX, bcY })
	handle.BG:AppendCharacterID(dwID, true, 255, 255, 255, 255, { 0, 0, 0, bcX + 100, bcY })
	handle.BG:AppendCharacterID(dwID, true, 255, 255, 255, 255, { 0, 0, 0, bcX + 100, bcY - 10 })
	handle.BG:AppendCharacterID(dwID, true, 255, 255, 255, 255, { 0, 0, 0, bcX, bcY - 10 })
	local r, g, b = unpack(tManaCol)
	handle.Mana:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, bcX, bcY })
	handle.Mana:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, bcX + (100 * manaper), bcY })
	handle.Mana:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, bcX + (100 * manaper), bcY - 5 })
	handle.Mana:AppendCharacterID(dwID, true, r, g, b, 255, { 0, 0, 0, bcX, bcY - 5 })
	
	local bcX ,bcY = -50 , -55
	handle.Life:AppendCharacterID(dwID, true, 220, 40, 0, 255, { 0, 0, 0, bcX, bcY })
	handle.Life:AppendCharacterID(dwID, true, 220, 40, 0, 255, { 0, 0, 0, bcX + (100 * lifeper), bcY })
	handle.Life:AppendCharacterID(dwID, true, 220, 40, 0, 255, { 0, 0, 0, bcX + (100 * lifeper), bcY - 5 })
	handle.Life:AppendCharacterID(dwID, true, 220, 40, 0, 255, { 0, 0, 0, bcX, bcY - 5 })	
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

_ScreenHead.Clear = function()
	_ScreenHead.tList = {}
	_ScreenHead.handle:Clear()
end

_ScreenHead.GetObject = function(dwID)
	local p, info
	if IsPlayer(dwID) then
		local me = GetClientPlayer()
		if dwID == me.dwID then
			p, info = me, me
		elseif JH.IsParty(dwID) then
			p, info = GetPlayer(dwID), GetClientTeam().GetMemberInfo(dwID)
		else
			p, info = GetPlayer(dwID), GetPlayer(dwID)
		end
	else
		p, info = GetNpc(dwID), GetNpc(dwID)
	end
	return p, info
end

_ScreenHead.OnBreathe = function()
	local me = GetClientPlayer()
	if not me then return end
	for dwID, t in pairs(_ScreenHead.tList) do
		local p, info = _ScreenHead.GetObject(dwID)
		if not p then
			_ScreenHead.Remove(dwID)	
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

_ScreenHead.KillBreathe = function()
	JH.BreatheCall("ScreenHead_Fight")
	_ScreenHead.tCache["Mana"] = {}
	_ScreenHead.tCache["Life"] = {}
end

_ScreenHead.OnBreatheFight = function()
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

_ScreenHead.RegisterFight = function(bEnable)
	if arg0 and ScreenHead.bTeamAlert then
		JH.BreatheCall("ScreenHead_Fight", _ScreenHead.OnBreatheFight)
	else
		_ScreenHead.KillBreathe()
	end
end

_ScreenHead.RegisterHead = function(dwID, tab)
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

_ScreenHead.OnBuffUpdate = function()
	if not ScreenHead.bEnable then return end
	if arg1 then return end
	local szName = JH.GetBuffName(arg4,arg8)
	if ScreenHead.tList[szName] then
		local type = arg3 and "Buff" or "Debuff"
		_ScreenHead.RegisterHead(arg0, { type = type, dwID = arg4 })
	end
end

_ScreenHead.OnNpcUpdate = function()
	local szName = JH.GetTemplateName(GetNpc(arg0))
	if ScreenHead.tNpcList[szName] then
		_ScreenHead.RegisterHead(arg0,{ type = "Object", txt = _L["aim"] })
	end
end

local PS = {}
PS.OnPanelActive = function(frame)
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

