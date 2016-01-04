-- @Author: Webster
-- @Date:   2016-01-04 14:20:43
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-01-04 14:28:29

local _L = JH.LoadLangPack
local TI = {}

JH_TeamNotice = {
	bEnable = true
}
JH.RegisterCustomData("JH_TeamNotice")

function TI.SaveList()
	JH.SaveLUAData("TI/YY.jx3dat", TI.tList, "\t", false)
end

function TI.GetList()
	if not TI.tList then
		TI.tList = JH.LoadLUAData("TI/YY.jx3dat") or {}
	end
	return TI.tList
end

function TI.GetFrame()
	return Station.Lookup("Normal/JH_TeamNotice")
end

function TI.CreateFrame(a, b)
	local an = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
	if TI.GetFrame() then
		an = GetFrameAnchor(TI.GetFrame())
	end
	local ui = GUI.CreateFrame("JH_TeamNotice", { w = 320, h = 195, close = true, title = _L["Team Message"], nStyle = 2 }):Point(an.s, 0, 0, an.r, an.x, an.y)
	local nX, nY = ui:Append("Text", { x = 10, y = 5, txt = _L["YY:"], font = 48 }):Pos_()
	nX = ui:Append("WndEdit", "YY", { w = 160, h = 26, x = nX + 5, y = 5, font = 48, color = { 128, 255, 0 }, txt = a }):Autocomplete(function()
		TI.tList = TI.GetList()
		local tList = {}
		for k, v in pairs(TI.tList) do
			table.insert(tList, k)
		end
		return tList
	end, nil, function(szText)
		TI.tList[tonumber(szText)] = nil
		TI.SaveList()
	end):Change(function(szText)
		if JH.IsLeader() then
			TI.szYY = szText
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "Edit", szText, ui:Fetch("Message"):Text())
		else
			ui:Fetch("YY"):Text(TI.szYY, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndButton2", { x = nX + 5, y = 5, txt = _L["Paste YY"]}):Click(function()
		local yy = ui:Fetch("YY"):Text()
		if tonumber(yy) then
			TI.tList = TI.GetList()
			if not TI.tList[tonumber(yy)] then
				TI.tList[tonumber(yy)] = true
				TI.SaveList()
			end
		end
		if yy ~= "" then
			for i = 0, 2 do -- 发三次
				JH.Talk(yy)
			end
		end
	end):Pos_()
	ui:Append("WndEdit", "Message", { w = 300, h = 80, x = 10, y = nY + 5, multi = true, limit = 512, txt = b}):Change(function(szText)
		if JH.IsLeader() then
			TI.szNote = szText
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "Edit", ui:Fetch("YY"):Text(), szText)
		else
			ui:Fetch("Message"):Text(TI.szNote, true)
		end
	end)
	nX, nY = 5, 130
	if RaidTools then
		nX = ui:Append("WndButton2", { x = nX, y = nY, txt = _L["Raid Tools"] }):Click(RaidTools.TogglePanel):Pos_()
	end
	if GKP then
		nX = ui:Append("WndButton2", { x = nX + 5, y = nY, txt = _L["GKP Golden Team Record"] }):Click(GKP.TogglePanel):Pos_()
	end
	if DBM_RemoteRequest then
		nX = ui:Append("WndButton2", { x = nX + 5, y = nY, txt = _L["Import Data"] }):Click(DBM_RemoteRequest.TogglePanel):Pos_()
	end
	TI.szYY   = ui:Fetch("YY"):Text()
	TI.szNote = ui:Fetch("Message"):Text()
	ui:Setting(function() JH.OpenPanel(_L["AutoSetTeam"]) end)
	-- 注册事件
	local frame = TI.GetFrame()
	frame.OnFrameKeyDown = nil -- esc close --> nil
	frame:RegisterEvent("PARTY_DISBAND")
	frame:RegisterEvent("PARTY_DELETE_MEMBER")
	frame:RegisterEvent("PARTY_ADD_MEMBER")
	frame.OnEvent = function(szEvent)
		if szEvent == "PARTY_DISBAND" then
			ui:Remove()
		elseif szEvent == "PARTY_DELETE_MEMBER" then
			if arg1 == UI_GetClientPlayerID() then
				ui:Remove()
			end
		elseif szEvent == "PARTY_ADD_MEMBER" then
			if JH.IsLeader() then
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "reply", arg1, TI.szYY, TI.szNote)
			end
		end
	end
end

function JH_TeamNotice.GetEvent()
	if JH_TeamNotice.bEnable then
		return
			{ "PARTY_LEVEL_UP_RAID", function()
				if JH.IsLeader() then
					JH.Confirm(_L["Edit team info?"], function()
						TI.CreateFrame()
					end)
				end
			end },
			{ "FIRST_LOADING_END", function()
				-- 不存在队长不队长的问题了
				local me = GetClientPlayer()
				if me.IsInRaid() then
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "ASK")
				end
			end }
	end
end

JH.RegisterBgMsg("TI", function(nChannel, dwID, szName, data, bIsSelf)
	if not bIsSelf then
		local me = GetClientPlayer()
		local team = GetClientTeam()
		if team then
			if data[1] == "ASK" and JH.IsLeader() then
				if TI.GetFrame() then
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "reply", szName, TI.szYY, TI.szNote)
				end
			elseif data[1] == "Edit" then
				TI.CreateFrame(data[2], data[3])
			elseif data[1] == "reply" and (tonumber(data[2]) == UI_GetClientPlayerID() or data[2] == me.szName) then
				if JH.Trim(data[3]) ~= "" or JH.Trim(data[4]) ~= "" then
					TI.CreateFrame(data[3], data[4])
				end
			end
		end
	end
end)

JH.AddonMenu(function()
	return {
		szOption = _L["Team Message"], fnDisable = function() local me = GetClientPlayer(); return not me.IsInRaid() end, fnAction = function()
			local me = GetClientPlayer()
			JH_TeamNotice.bEnable = true
			JH.RegisterInit("TEAM_NOTICE", JH_TeamNotice.GetEvent())
			if me.IsInRaid() then
				if JH.IsLeader() then
					TI.CreateFrame()
				else
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "ASK")
					JH.Sysmsg(_L["Asking..., If no response in longtime, team leader not enable plug-in."])
				end
			end
		end
	}
end)
