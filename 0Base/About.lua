-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-11-02 17:13:22
local _L = JH.LoadLangPack
local _JH_About = {
	PS   = {},
	INFO = {},
}
-- author
function _JH_About.PS.GetAuthorInfo()
	return _L["JH @ Double Dream Town"]
end

function _JH_About.CheckInstall()
	local me = GetClientPlayer()
	local me, team = GetClientPlayer(), GetClientTeam()
	if me.IsInParty() and JH.IsLeader() or JH.bDebugClient then
		if IsCtrlKeyDown() and JH.bDebugClient then
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "JH_ABOUT", "Author")
			JH.Sysmsg2(_L["Checking command sent, please see talk channel"])
		else
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "JH_ABOUT", "JH_CHECK")
			JH.Sysmsg(_L["Checking command sent, please see talk channel"])
		end
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
	if data[1] == "JH_CHECK" then
		-- check plugin
		JH.Talk(PLAYER_TALK_CHANNEL.RAID, _L["I have installed JH plug-in v"] .. JH.GetVersion())
	elseif data[1] == "Author" then -- 版本检查 自用 可以绘制详细表格
		local me, szTong = GetClientPlayer(), ""
		if me.dwTongID > 0 then
			szTong = GetTongClient().ApplyGetTongName(me.dwTongID)
			if not szTong then szTong = "Failed" end
		end
		local _,szServer = GetUserServer()
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
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Free & open source, Utility, Focus on PVE!"], font = 27 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY + 10, w = 500 , h = 80, multi = true, txt = _L["ABOUT_TIPS"] }):Pos_()
	nY = nY + 70
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Version"], font = 27 }):Pos_()
	local info = JH.GetAddonInfo()
	local txt = info.szName .. " v" ..  info.szVersion .. " (Build: " .. info.szBuildDate .. ")"
	nX, nY = ui:Append("Text", { x = 0, y = nY + 10, txt = txt }):Pos_()

	nX, nY = ui:Append("Text", { x = 0, y = nY + 20, txt = _L["Other"], font = 27 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY + 15, txt = _L["WeiBo"] .. " http://weibo.com/techvicky", w = 250, h = 28 }):Click(function()
		OpenInternetExplorer("http://weibo.com/techvicky")
	end, { 255, 255, 255 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY + 5, txt = _L["official website"] .. " http://www.j3ui.com", w = 250, h = 28 }):Click(function()
		OpenInternetExplorer("http://www.j3ui.com")
	end, { 255, 255, 255 }):Pos_()
	nX, nY = ui:Append("Text", { x = 10, y = nY + 5, txt = _L["GitHub"] .. " https://github.com/Webster-jx3/JH", w = 250, h = 28 }):Click(function()
		OpenInternetExplorer("https://github.com/Webster-jx3/JH")
	end, { 255, 255, 255 }):Pos_()
	nX = ui:Append("WndButton2", { x = 10, y = nY + 12, txt = _L["Check Install"] }):Click(_JH_About.CheckInstall):Pos_()
	ui:Append("WndCheckBox", "DEBUG", { x = 380, y = 340, checked = JH.bDebug, txt = "Enable Debug" }):Click(function(bChecked)
		if not JH.bDebug then
			JH.Confirm(_L["Warning: plugin will ignore the authority when the debugging mode is on, showing action can not be operate when cross the authorit, but none of this coud be accept by the server,do not select if you are not the developer, avoid making misunderstanding, please do not try it when set up a team, this may creat problem like messing up the record."],function()
				JH.bDebug = not JH.bDebug
			end, function()
				ui:Fetch("DEBUG"):Check(JH.bDebug)
			end)
		else
			JH.bDebug = not JH.bDebug
		end
	end)
	ui:Append("Text", "Memory", { x = 0, y = 340, alpha = 30, txt = _JH_About.GetMemory() }):Click(function()
		collectgarbage("collect")
		ui:Fetch("Memory"):Text(_JH_About.GetMemory())
	end)
end

function _JH_About.PS.OnTaboxCheck(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Image",{ x = 10, y = 0, w = 500, h = 195}):File("interface/JH/0Base/background.tga"):Pos_()
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

GUI.RegisterPanel(_L["About"], { "ui/Image/UICommon/PlugIn.uitex", 5 }, _L["Recreation"], _JH_About.PS)

JH.RegisterEvent("CALL_LUA_ERROR", function()
	if JH.bDebug then
		OutputMessage("MSG_SYS", arg0)
	end
end)

-- public
local _About = {
	OnTaboxCheck  = _JH_About.PS.OnTaboxCheck,
	OnPanelActive = _JH_About.PS.OnPanelActive,
	GetAuthorInfo = _JH_About.PS.GetAuthorInfo,
}
JH_About = setmetatable({}, { __metatable = true, __index = _About, __newindex = function() end } )
