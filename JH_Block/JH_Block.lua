-- @Author: Webster
-- @Date:   2016-03-16 18:13:51
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-03-16 21:56:08

local _L = JH.LoadLangPack

local Black = {
	{ "IMTP_",                  _L["Kill Team invite"] },
	{ "ATMP_",                  _L["Kill Team Apply"] },
	{ "IsAddFoe",               _L["Kill Add Foe"] },
	{ "NeedAddFriend",          _L["Kill Add Friend"] },
	{ "TradingInvite",          _L["Kill Trading invite"] },
	{ "ArenaCorps_beInvite",    _L["Kill Corps invite"] },
	{ "ApplyDuel",              _L["Kill Duel invite"] },
	{ "OnInviteJoinTong",       _L["Kill Tong invite"] },
	{ "A_M_",                   _L["Kill Apprentice invite"] },
	{ "A_E_M_",                 _L["Kill tong banner invite"] },
	{ "OnInviteEmotionAction_", _L["Kill Emotion Action"] },
	{ "OnInviteFollow",         _L["Kill Invite Follow"] },
}

local function Black_Commom()
	for k, v in ipairs(Black) do
		if v[3] then
			if arg0:sub(0, v[1]:len()) == v[1] then
				JH.DoMessageBox(arg0, 2)
			end
		end
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 30
	ui:Append("Text", { x = 0, y = 0, txt = _L["Kill MessageBox"], font = 27 })
	for k, v in ipairs(Black) do
		nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = v[2], color = { 255, 255, 255 } , checked = v[3] == true }):Click(function(bCheck)
			v[3] = bCheck
			if bCheck then
				JH.RegisterEvent("ON_MESSAGE_BOX_OPEN.BLACK", Black_Commom)
			else
				local find = true
				for k, v in ipairs(Black) do
					if v[3] then
						find = false
						break
					end
				end
				if find then JH.UnRegisterEvent("ON_MESSAGE_BOX_OPEN.BLACK") end
			end
			if JH_PartyRequest then
				JH_PartyRequest.bEnable = not bCheck
			end
		end):Pos_()
	end
	nX, nY = ui:Append("WndButton4", { x = 10, y = nY, txt = g_tStrings.tNpcSearchMenu[1] }):Click(function()
		local find = true
		for k, v in ipairs(Black) do
			if v[3] then
				find = false
				break
			end
		end
		for k, v in ipairs(Black) do v[3] = find end
		if find then
			JH.RegisterEvent("ON_MESSAGE_BOX_OPEN.BLACK", Black_Commom)
		else
			JH.UnRegisterEvent("ON_MESSAGE_BOX_OPEN.BLACK")
		end
		if JH_PartyRequest then
			JH_PartyRequest.bEnable = not find
		end
		JH.OpenPanel(_L["Kill MessageBox"])
	end):Pos_()
	ui:Append("Text", { x = 0, y = nY, txt = _L["Kill Tips"], color = { 192, 192, 192 } })
end

GUI.RegisterPanel(_L["Kill MessageBox"], 11, g_tStrings.CHANNEL_CHANNEL, PS)
