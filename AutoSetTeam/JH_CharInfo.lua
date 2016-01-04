-- @Author: Webster
-- @Date:   2016-01-04 15:18:23
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-01-04 17:54:44
local _L = JH.LoadLangPack

local JH_CharInfo = {}

-- 获取的是一个表 data[1] 一定是装备分
function JH_CharInfo.GetInfo()
	local data = { GetClientPlayer().GetTotalEquipScore() }
	local frame = Station.Lookup("Normal/CharInfo")
	local function fnGetInfo()
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
	end
	if not frame then
		Wnd.OpenWindow("CharInfo")
		fnGetInfo()
		Wnd.CloseWindow("CharInfo")
	else
		fnGetInfo()
	end
	return data
end

function JH_CharInfo.CreateFrame(dwID, szName, dwForceID)
	GUI.CreateFrame("JH_CharInfo" .. dwID, { w = 240, h = 400, title = szName .. g_tStrings.STR_EQUIP_ATTR, close = true })
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	local ui = GUI(frame) -- 历史原因 先不管
	local nX, nY = ui:Append("Image", { x = 20, y = 50, w = 30, h = 30 }):File(GetForceImage(dwForceID)):Pos_()
	ui:Append("Text", "Name", { x = nX + 5, y = 52, txt = szName })
	ui:Append("WndButton2", { x = 70, y = 360, txt = g_tStrings.STR_LOOKUP }):Click(function()
		ViewInviteToPlayer(dwID)
	end)
	local info  = ui:Append("Text", "info", { x = 20, y = 72, txt = _L["Asking..."], w = 200, h = 70, font = 27, multi = true })
	frame.ui    = ui
	frame.data  = {}
	frame.info  = info
end

function JH_CharInfo.ClearFrame(dwID)
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	if frame then
		frame.data = {}
		frame.info:Toggle(true)
	end
end

function JH_CharInfo.RefuseFrame(dwID)
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	if frame then
		frame.data = {}
		frame.info:Toggle(true):Text(_L["Refuse request"])
	end
end

function JH_CharInfo.CreateContent(dwID, szContent)
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	if frame and frame.data then
		table.insert(frame.data, szContent)
		frame.info:Text(_L["Syncing..."])
	end
end

function JH_CharInfo.CreateComplete(dwID)
	local frame = Station.Lookup("Normal/JH_CharInfo" .. dwID)
	if frame then
		local data = JH.JsonDecode(table.concat(frame.data))
		if data and type(data) == "table" then
			frame.info:Toggle(false)
			local ui = frame.ui
			local self_data = JH_CharInfo.GetInfo()
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
			for i = 2, #data do
				local v = data[i]
				ui:Append("Text", { x = 20, y = (i - 1) * 25 + 70, w = 200, h = 25, align = 0, txt = v.label })
				ui:Append("Text", { x = 20, y = (i - 1) * 25 + 70, w = 200, h = 25, align = 2, txt = v.value, color = GetSelfValue(v.label, v.value) }):Hover(function(bHover)
					if bHover then
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						OutputTip(v.szTip, 500, { x, y, w, h })
					else
						HideTip()
					end
				end)
			end
			local name = ui:Fetch("Name")
			name:Text(name:Text() .. " (" .. data[1] .. ")")
			frame.data = nil
		end
	end
end

JH.RegisterBgMsg("CHAR_INFO", function(nChannel, dwID, szName, data, bIsSelf)
	if not bIsSelf and data[2] == UI_GetClientPlayerID() then
		if data[1] == "ASK"  then
			local fnAction = function()
				local str = JH.JsonEncode(JH_CharInfo.GetInfo())
				local nMax = 600
				local nTotle = math.ceil(#str / nMax)
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "START", dwID)
				for i = 1, nTotle do
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "CONTENT", dwID, string.sub(str, (i-1) * nMax + 1, i * nMax))
				end
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "STOP", dwID)
			end
			if data[3] == "DEBUG" then
				fnAction()
			else
				JH.Confirm(_L("[%s] want to see your char info, OK?", szName), fnAction, function()
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "REFUSE", dwID)
				end)
			end
		elseif data[1] == "REFUSE" then
			JH_CharInfo.RefuseFrame(dwID)
		elseif data[1] == "START" then
			JH_CharInfo.ClearFrame(dwID)
		elseif data[1] == "CONTENT" then
			JH_CharInfo.CreateContent(dwID, data[3])
		elseif data[1] == "STOP" then
			JH_CharInfo.CreateComplete(dwID)
		end
	end
end)

Target_AppendAddonMenu({ function(dwID, dwType)
	if dwType == TARGET.PLAYER and dwID ~= UI_GetClientPlayerID() then
		return {{
			szOption = g_tStrings.STR_LOOK .. g_tStrings.STR_EQUIP_ATTR,
			fnAction = function()
				if JH.IsParty(dwID) then
					local p = GetPlayer(dwID)
					if p then
						JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "CHAR_INFO", "ASK", dwID, JH.bDebugClient and "DEBUG")
						JH_CharInfo.CreateFrame(dwID, p.szName, p.dwForceID)
					end
				else
					JH.Alert(_L["Party limit"])
				end
			end
		}}
	else
		return {}
	end
end })
