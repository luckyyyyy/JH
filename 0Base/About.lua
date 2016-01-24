-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-01-24 07:29:08
local _L = JH.LoadLangPack
local _JH_About = {
	PS   = {},
	INFO = {},
}

function _JH_About.CheckInstall()
	local me = GetClientPlayer()
	local me, team = GetClientPlayer(), GetClientTeam()
	if me.IsInParty() and JH.IsLeader() or JH.bDebugClient then
		JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "JH_ABOUT", "Author")
		JH.Sysmsg2(_L["Checking command sent, please see talk channel"])
	else
		JH.Sysmsg(_L["You are not team leader or not in team"])
	end
end

function _JH_About.ShowInfo(dwID, dat)
	_JH_About.INFO[dwID] = dat
	local me = GetClientPlayer()
	local ini = "interface/JH/0Base/About.ini"
	local frame = Wnd.OpenWindow(ini, "JH_ABOUT")
	if not frame then return end
	GUI(frame):Point():RegisterClose(function() Wnd.CloseWindow(frame) end)
	local list = GetClientTeam().GetTeamMemberList()
	local h = frame:Lookup("WndScroll"):Lookup("", "Handle_List")
	local _ = "--"
	h:Clear()
	for k, v in ipairs(list) do
		local data = _JH_About.INFO[v] or {}
		local info = GetClientTeam().GetMemberInfo(v)
		local item = h:AppendItemFromIni(ini, "Handle_Item",k)
		item.OnItemLButtonClick = function()
			ViewInviteToPlayer(v)
		end
		item:Lookup("Text_1"):SetText(data[7] or _)
		item:Lookup("Text_2"):SetText(info.szName)
		item:Lookup("Text_3"):SetText(data[4] or _)
		item:Lookup("Text_4"):SetText(data[2] or _)
		item:Lookup("Text_5"):SetText(v)
		item:Lookup("Image_6"):FromIconID(Table_GetSkillIconID(tonumber(info.dwMountKungfuID)))
		local role = { [1] = "成男", [2] = "成女", [3] = "--" , [5] = "正太" , [6] = "萝莉" }
		item:Lookup("Text_7"):SetText(role[tonumber(data[5] or 3)])
		local camp = { [0] = -1, [1] = 43, [2] = 40 }
		item:Lookup("Image_8"):FromUITex("UI/Image/Button/ShopButton.uitex", camp[tonumber(info.nCamp)])
		item:Lookup("Text_9"):SetText(data[6] or _)
		local r, g, b, txt = 255, 0, 0, "No"
		if data[8] then
			r, g, b, txt = 0, 255, 0, "Yes"
		end
		item:Lookup("Text_10"):SetText(txt)
		item:Lookup("Text_10"):SetFontColor(r, g, b)
	end
	h:FormatAllItemPos()
	h:Show()
end

function _JH_About.GetMemory()
	return string.format("Memory:%.1fMB", collectgarbage("count") / 1024)
end

JH.RegisterBgMsg("JH_ABOUT", function(nChannel, dwID, szName, data, bIsSelf)
	if data[1] == "Author" then -- 版本检查 自用 可以绘制详细表格
		local me, szTong = GetClientPlayer(), ""
		if me.dwTongID > 0 then
			szTong = GetTongClient().ApplyGetTongName(me.dwTongID)
			if not szTong then szTong = "Failed" end
		end
		local szServer = select(2, GetUserServer())
		JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "JH_ABOUT", "info",
			me.GetTotalEquipScore(),
			me.GetMapID(),
			szTong,
			me.nRoleType,
			JH.GetVersion(),
			szServer,
			JH.GetBuff(3219)
		)
	elseif data[1] == "info" and JH.bDebugClient then
		_JH_About.ShowInfo(dwID, data)
	elseif data[1] == "TeamAuth" then -- 防止有人睡着 遇到了不止一次了
		local team = GetClientTeam()
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER, dwID)
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK, dwID)
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE, dwID)
	end
end)

function _JH_About.PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	-- nX, nY = ui:Append("Image",{ x = 125, y = 0, w = 500, h = 140}):File("interface/JH/0Base/background.tga"):Pos_()
	nX, nY = ui:Append("Text", "Animate1", { x = 10, y = nY + 5, txt = _L["Free & open source, Utility, Focus on PVE!"], font = 27 }):Toggle(false):Pos_()
	nX, nY = ui:Append("Text", "Animate2", { x = 20, y = nY + 10, w = 720 , h = 70, multi = true, txt = _L["ABOUT_TIPS"] }):Toggle(false):Pos_()
	nY = nY + 70
	nX, nY = ui:Append("Text", "Animate3", { x = 10, y = nY - 15, txt = _L["Version"], font = 27 }):Toggle(false):Pos_()
	local info = JH.GetAddonInfo()
	local txt = info.szName .. " v" ..  info.szVersion .. " (Build: " .. info.szBuildDate .. ")"
	nX, nY = ui:Append("Text", "Animate4", { x = 20, y = nY + 5, txt = txt }):Toggle(false):Pos_()
	nX, nY = ui:Append("Text", "Animate5", { x = 10, y = nY + 5, txt = _L["Other"], font = 27 }):Toggle(false):Pos_()
	nX, nY = ui:Append("Text", "Animate6", { x = 20, y = nY + 5, txt = _L["WeiBo"] .. " http://weibo.com/techvicky", w = 250, h = 28 }):Click(function()
		OpenInternetExplorer("http://weibo.com/techvicky")
	end, { 255, 255, 255 }):Toggle(false):Pos_()
	nX, nY = ui:Append("Text", "Animate7", { x = 20, y = nY + 5, txt = _L["official website"] .. " http://www.j3ui.com", w = 250, h = 28 }):Click(function()
		OpenInternetExplorer("http://www.j3ui.com")
	end, { 255, 255, 255 }):Toggle(false):Pos_()
	nX, nY = ui:Append("Text", "Animate8", { x = 20, y = nY + 5, txt = _L["GitHub"] .. " https://github.com/Webster-jx3/JH", w = 250, h = 28 }):Click(function()
		OpenInternetExplorer("https://github.com/Webster-jx3/JH")
	end, { 255, 255, 255 }):Toggle(false):Pos_()
	if JH.bDebugClient then
		nX = ui:Append("WndButton4", { x = 130, y = 400, txt = _L["Check Install"] }):Click(_JH_About.CheckInstall):Pos_()
		ui:Append("Text", "Memory", { x = 10, y = 400, alpha = 150, txt = _JH_About.GetMemory() }):Click(function()
			collectgarbage("collect")
			ui:Fetch("Memory"):Text(_JH_About.GetMemory())
		end)
	end
	ui:Append("Text", { x = 10, y = 400, w = 730, h = 25, txt = JH.GetAddonInfo().szAuthor, align = 2, alpha = 120 })

	-- animate test
	local x, y = ui:Fetch("Animate1"):Pos()
	JH.Animate(ui:Fetch("Animate1").self):FadeIn():Pos({ x - 20, x, y, y }, function()
		JH.Animate(ui:Fetch("Animate2").self):FadeIn(function()
			local x, y = ui:Fetch("Animate3"):Pos()
			JH.Animate(ui:Fetch("Animate3").self):FadeIn():Pos({ x - 20, x, y, y }, function()
				JH.Animate(ui:Fetch("Animate4").self):FadeIn(function()
					local x, y = ui:Fetch("Animate5"):Pos()
					JH.Animate(ui:Fetch("Animate5").self):FadeIn():Pos({ x - 20, x, y, y }, function()
						JH.Animate(ui:Fetch("Animate6").self):FadeIn()
						JH.Animate(ui:Fetch("Animate7").self):FadeIn()
						JH.Animate(ui:Fetch("Animate8").self):FadeIn()
					end)
				end)
			end)
		end)
	end)
end

function _JH_About.PS.OnTaboxCheck(frame)
	local ui, nX, nY = GUI(frame), 10, 0

	nX, nY = ui:Append("Text", { x = 10, y = nY + 15, color = { 255, 255, 0 }, txt = _L("%s are welcome to use JH plug-in", GetUserRoleName()), font = 230 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY, color = { 255, 255, 0 }, txt = _L["Free & open source, Utility, Focus on PVE!"], font = 233 }):Pos_()
	local time = TimeToDate(GetCurrentTime())
	-- year, month, day, hour, minute, second, weekday
	if time.weekday == 0 then
		time.weekday = 7
	end
	local L = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
	local col = { 1, 1, 0, 4, 5, 5, 4 }
	ui:Append("Text", { x = 10, y = nY + 15, color = { GetItemFontColorByQuality(col[time.weekday]) }, txt = _L("Today is %d-%d-%d (%s)", time.year, time.month, time.day, _L[L[time.weekday]]), font = 41 })
end

-- public
local _About = {
	PS            = _JH_About.PS,
	OnTaboxCheck  = _JH_About.PS.OnTaboxCheck,
	OnPanelActive = _JH_About.PS.OnPanelActive,
}
JH_About = setmetatable({}, { __metatable = true, __index = _About, __newindex = function() end } )
