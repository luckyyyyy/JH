-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2017-05-29 02:23:38
local _L = JH.LoadLangPack
local _JH_About = {
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
	local ini = "interface/JH/JH_0Base/About.ini"
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
			JH.GetAddonInfo().szVersion,
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

local Panel = {
	About    = {},
	Feedback = {},
}
function Panel.GetMemory()
	return string.format("Memory:%.1fMB", collectgarbage("count") / 1024)
end

function Panel.About.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Image", "Animate0", { x = 5, y = 0, w = 730, h = 150}):File("interface/JH/JH_0Base/background.tga"):Pos_()
	nX, nY = ui:Append("Text", "Animate1", { x = 10, y = nY + 5, txt = _L["Free & open source, Utility, Focus on PVE!"], font = 27 }):Toggle(false):Pos_()
	nX, nY = ui:Append("Text", "Animate2", { x = 20, y = nY + 10, w = 720 , h = 70, multi = true, txt = _L["ABOUT_TIPS"] }):Toggle(false):Pos_()
	nY = nY + 70
	nX, nY = ui:Append("Text", "Animate3", { x = 10, y = nY - 15, txt = _L["Version"], font = 27 }):Toggle(false):Pos_()
	local info = JH.GetAddonInfo()
	local txt = info.szName .. " v" ..  info.szVersion .. " (Build: " .. info.szBuildDate .. ")"
	nX, nY = ui:Append("Text", "Animate4", { x = 20, y = nY + 5, txt = txt }):Toggle(false):Pos_()
	nX, nY = ui:Append("Text", "Animate5", { x = 10, y = nY + 5, txt = _L["Other"], font = 27 }):Toggle(false):Pos_()
	-- nX, nY = ui:Append("Text", "Animate6", { x = 20, y = nY + 5, txt = _L["WeiBo"] .. " http://weibo.com/2128637385", w = 250, h = 28 }):Click(function()
	-- 	OpenInternetExplorer("http://weibo.com/2128637385")
	-- end, { 255, 255, 255 }):Toggle(false):Pos_()
	-- nX, nY = ui:Append("Text", "Animate7", { x = 20, y = nY + 5, txt = _L["official website"] .. " http://www.j3ui.com", w = 250, h = 28 }):Click(function()
	-- 	OpenInternetExplorer("http://www.j3ui.com")
	-- end, { 255, 255, 255 }):Toggle(false):Pos_()
	nX, nY = ui:Append("Text", "Animate8", { x = 20, y = nY + 5, txt = _L["GitHub"] .. " https://github.com/Webster-jx3/JH", w = 270, h = 28 }):Click(function()
		OpenInternetExplorer("https://github.com/Luckyyyyy/JH")
	end, { 255, 255, 255 }):Toggle(false):Pos_()
	if JH.bDebugClient then
		nX = ui:Append("WndButton4", { x = 130, y = 400, txt = _L["Check Install"] }):Click(_JH_About.CheckInstall):Pos_()
		ui:Append("Text", "Memory", { x = 10, y = 400, alpha = 150, txt = Panel.GetMemory() }):Click(function()
			collectgarbage("collect")
			ui:Fetch("Memory"):Text(Panel.GetMemory())
		end)
	end
	ui:Append("Text", { x = 10, y = 400, w = 730, h = 25, txt = JH.GetAddonInfo().szAuthor, align = 2, alpha = 120 })

	-- animate test
	JH.Animate(ui:Fetch("Animate0").self):FadeIn():Pos({ 0, -20 })
	JH.Animate(ui:Fetch("Animate1").self):FadeIn():Pos({ -20, 0 })
	JH.Animate(ui:Fetch("Animate2").self):FadeIn():Pos({ -20, 0 }, function()
		JH.Animate(ui:Fetch("Animate3").self):FadeIn():Pos({ -20, 0 })
		JH.Animate(ui:Fetch("Animate4").self):FadeIn():Pos({ -20, 0 }, function()
			JH.Animate(ui:Fetch("Animate5").self):FadeIn():Pos({ -20, 0 })
			-- JH.Animate(ui:Fetch("Animate6").self):FadeIn():Pos({ -20, 0 })
			-- JH.Animate(ui:Fetch("Animate7").self):FadeIn():Pos({ -20, 0})
			JH.Animate(ui:Fetch("Animate8").self):FadeIn():Pos({ -20, 0 })
		end)
	end)
end
function Panel.Feedback.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	local szServer   = select(6, GetUserServer())
	local szName     = GetUserRoleName()
	local szSystem   = "Windows 7 x64"
	local szType     = "bug"
	local szDesc     = ""
	local szEmail    = ""
	nX, nY = ui:Append("Image", { x = 5, y = 0, w = 730, h = 150}):File("interface/JH/JH_0Base/feedback.tga"):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = 160, txt = _L["Fadeback"], font = 27 }):Pos_()
	-- player name
	nX = ui:Append("Text", { txt = _L["Name"], x = 20, y = nY + 10 }):Pos_()
	nX, nY = ui:Append("WndEdit", { txt = szName .. "@" .. szServer, x = nX + 5, y = nY + 12, enable = false }):Pos_()

	nX = ui:Append("Text", { txt = _L["OS"], x = 20, y = nY + 10 }):Pos_()
	nX = ui:Append("WndComboBox", "System",  { txt = szSystem, x = nX + 5, y = nY + 12 }):Menu(function()
		local menu = {}
		for k, v in ipairs({
			"Windows 7 x64",
			"Windows 7 x86",
			"Windows 8 x64",
			"Windows 8 x86",
			"Windows 10 x64",
			"Windows 10 x86",
			"Windows XP x86",
			"Other"
		}) do
			table.insert(menu, {
				szOption = v,
				bChecked = szSystem == v,
				fnAction = function()
					szSystem = v
					ui:Fetch("System"):Text(v)
				end
			})
		end
		return menu
	end):Pos_()
	nX = ui:Append("Text", { txt = _L["Label"], x = nX + 10, y = nY + 10 }):Pos_()
	nX = ui:Append("WndComboBox", "Type",  { txt = szType, x = nX + 5, y = nY + 12 }):Menu(function()
		local menu = {}
		for k, v in ipairs({
			"bug",
			"Issues",
			"enhancement",
			"question",
		}) do
			table.insert(menu, {
				szOption = v,
				bChecked = szType == v,
				fnAction = function()
					szSystem = v
					ui:Fetch("Type"):Text(v)
				end
			})
		end
		return menu
	end):Pos_()
	nX = ui:Append("Text", { txt = _L["Email"], x = nX + 10, y = nY + 10 }):Pos_()
	nX, nY = ui:Append("WndEdit", { txt = szEmail, x = nX + 5, y = nY + 12, enable = false }):Change(function(szEmail)
		szEmail = szText
	end):Pos_()
	-- description
	nX, nY = ui:Append("WndEdit", { multi = true, txt = "description...", x = 20, y = nY + 12, w = 700, h = 100 }):Change(function(szText)
		szDesc = szText
	end)
	ui:Append("WndButton2", { x = 630, y = 390, txt = _L["feedback"] }):Click(function()
	end)
end
-- public
JH_Panel = setmetatable({}, { __metatable = true, __index = Panel, __newindex = function() end } )
