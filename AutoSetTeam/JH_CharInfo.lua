-- @Author: Webster
-- @Date:   2016-01-04 15:18:23
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-01-20 09:34:24
local _L = JH.LoadLangPack

JH_CharInfo = {
	bEnable = true,
}
JH.RegisterCustomData("JH_CharInfo")

local CharInfo = {}

-- 获取的是一个表 data[1] 一定是装备分
function CharInfo.GetInfo()
	local data = { GetClientPlayer().GetTotalEquipScore() }
	local frame = Station.Lookup("Normal/CharInfo")
	if not frame or not frame:IsVisible() then
		if frame then
			Wnd.CloseWindow("CharInfo") -- 强制kill
		end
		Wnd.OpenWindow("CharInfo"):Hide()
	end
	local hCharInfo = Station.Lookup("Normal/CharInfo")
	local handle = hCharInfo:Lookup("WndScroll_Property", "")
	for i = 0, handle:GetVisibleItemCount() -1 do
		local h = handle:Lookup(i)
		table.insert(data, {
			szTip = h.szTip,
			label = h:Lookup(0):GetText(),
			value = h:Lookup(1):GetText(),
		})
	end
	return data
end

function CharInfo.CreateFrame(dwID, szName, info)
	local ui = GUI.CreateFrame("JH_CharInfo" .. dwID, { w = 240, h = 400, title = g_tStrings.STR_EQUIP_ATTR, close = true })
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	local nX, nY = ui:Append("Image", { x = 20, y = 50, w = 30, h = 30, icon = select(2, JH.GetSkillName(info.dwMountKungfuID, 1)) }):Pos_()
	ui:Append("Text", { x = nX + 5, y = 52, txt = wstring.sub(szName, 1, 6), color = { JH.GetForceColor(info.dwForceID) } }) -- UI超了
	ui:Append("WndButton2", "LOOKUP", { x = 70, y = 360, txt = g_tStrings.STR_LOOKUP }):Click(function()
		ViewInviteToPlayer(dwID)
	end)
	local info  = ui:Append("Text", "info", { x = 20, y = 72, txt = _L["Asking..."], w = 200, h = 70, font = 27, multi = true })
	frame.ui    = ui
	frame.data  = {}
	frame.info  = info
end

function CharInfo.ClearFrame(dwID)
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	if frame then
		frame.data = {}
		frame.info:Toggle(true)
	end
end

function CharInfo.RefuseFrame(dwID)
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	if frame then
		frame.data = {}
		frame.info:Toggle(true):Text(_L["Refuse request"])
	end
end

function CharInfo.CreateContent(dwID, szContent)
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	if frame and frame.data then
		table.insert(frame.data, szContent)
		frame.info:Text(_L["Syncing..."])
	end
end

function CharInfo.CreateComplete(dwID)
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	if frame then
		local data = JH.JsonDecode(table.concat(frame.data))
		if data and type(data) == "table" then
			frame.info:Toggle(false)
			local ui = frame.ui
			local self_data = CharInfo.GetInfo()
			local function GetSelfValue(label, value)
				for i = 2, #self_data do
					local v = self_data[i]
					if v.label == label then
						local sc = tonumber(clone(v.value:gsub("%%", "")))
						local tc = tonumber(clone(value:gsub("%%", "")))
						if sc and tc then
							return tc > sc and { 200, 255, 200 } or tc < sc and { 255, 200, 200 } or { 255, 255, 255 }
						end
					end
				end
				return { 255, 255, 255 }
			end
			-- 避免大小不够
			ui:Size(240, 60 + 65 + (#data - 1) * 25)
			ui:Fetch("LOOKUP"):Pos(70, 60 + #data * 25)
			for i = 2, #data do
				local v = data[i]
				ui:Append("Text", { x = 20, y = (i - 1) * 25 + 60, w = 200, h = 25, align = 0, txt = v.label })
				ui:Append("Text", { x = 20, y = (i - 1) * 25 + 60, w = 200, h = 25, align = 2, txt = v.value, color = GetSelfValue(v.label, v.value) }):Hover(function(bHover)
					if bHover then
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						OutputTip(v.szTip, 550, { x, y, w, h })
					else
						HideTip()
					end
				end)
			end
			frame.data = nil
		else
			frame.info:Text("Json Decode Error")
		end
	end
end

JH.RegisterBgMsg("CHAR_INFO", function(nChannel, dwID, szName, data, bIsSelf)
	if not bIsSelf and data[2] == UI_GetClientPlayerID() then
		if data[1] == "ASK"  then
			if JH_CharInfo.bEnable or data[3] == "DEBUG" then
				local str = JH.JsonEncode(CharInfo.GetInfo())
				local nMax = 500
				local nTotle = math.ceil(#str / nMax)
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "START", dwID)
				for i = 1, nTotle do
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "CONTENT", dwID, string.sub(str, (i-1) * nMax + 1, i * nMax))
				end
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "STOP", dwID)
			else
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "REFUSE", dwID)
			end
		elseif data[1] == "REFUSE" then
			CharInfo.RefuseFrame(dwID)
		elseif data[1] == "START" then
			CharInfo.ClearFrame(dwID)
		elseif data[1] == "CONTENT" then
			CharInfo.CreateContent(dwID, data[3])
		elseif data[1] == "STOP" then
			CharInfo.CreateComplete(dwID)
		end
	end
end)

-- public API
function ViewCharInfoToPlayer(dwID)
	if JH.IsParty(dwID) then
		local team = GetClientTeam()
		local info = team.GetMemberInfo(dwID)
		if info then
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "ASK", dwID, JH.bDebugClient and "DEBUG")
			CharInfo.CreateFrame(dwID, info.szName, info)
		end
	else
		JH.Alert(_L["Party limit"])
	end
end

Target_AppendAddonMenu({ function(dwID, dwType)
	if dwType == TARGET.PLAYER and dwID ~= UI_GetClientPlayerID() then
		return {{
			szOption = g_tStrings.STR_LOOK .. g_tStrings.STR_EQUIP_ATTR,
			fnAction = function()
				ViewCharInfoToPlayer(dwID)
			end
		}}
	else
		return {}
	end
end })

