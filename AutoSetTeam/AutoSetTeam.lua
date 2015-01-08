local _L = JH.LoadLangPack
JH_AutoSetTeam = {
	bAppendMark = true,
	bRequestList = true,
	bTeamInfo = true,
}
JH.RegisterCustomData("JH_AutoSetTeam")

local AutoSetTeam = {
	bKeepMark = true,
	bKeepForm = true,
	Mark = {},
	tMarkName = { _L["Cloud"], _L["Sword"], _L["Ax"], _L["Hook"], _L["Drum"], _L["Shear"], _L["Stick"], _L["Jade"], _L["Dart"], _L["Fan"] },
	szDataFile = "AutoSetTeam.jx3dat",
	szMarkImage = PARTY_MARK_ICON_PATH,
	tMarkFrame = PARTY_MARK_ICON_FRAME_LIST,
}

AutoSetTeam.SaveList = JH.LoadLUAData(AutoSetTeam.szDataFile) or {}

AutoSetTeam.Save = function(n)
	local tList, tList2, me, team = {}, {}, GetClientPlayer(), GetClientTeam()
	if not me or not me.IsInParty() then
		return JH.Sysmsg(_L["You are not in a team"])
	end
	AutoSetTeam.SaveList[n] = {}
	AutoSetTeam.SaveList[n].szLeader = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER))
	AutoSetTeam.SaveList[n].szMark = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK))
	AutoSetTeam.SaveList[n].szDistribute = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE))
	AutoSetTeam.SaveList[n].nLootMode = team.nLootMode
	local tMark = team.GetTeamMark()
	
	for nGroup = 0, team.nGroupNum - 1 do
		local tGroupInfo = team.GetGroupInfo(nGroup)
		tList2[nGroup] = {}
		for _, dwID in ipairs(tGroupInfo.MemberList) do
			local szName = team.GetClientTeamMemberName(dwID)
			local info = team.GetMemberInfo(dwID)
			if szName then
				local item = {}
				item.nGroup = nGroup
				item.nMark = tMark[dwID]
				item.bForm = dwID == tGroupInfo.dwFormationLeader
				tList[szName] = item
				table.insert(tList2[nGroup],{dwMountKungfuID = info.dwMountKungfuID, nMark = tMark[dwID], bForm = dwID == tGroupInfo.dwFormationLeader,nGroup = nGroup } )
			end
		end
	end
	-- saved ok
	AutoSetTeam.SaveList[n].data = tList
	AutoSetTeam.SaveList[n].data2 = tList2
	JH.SaveLUAData(AutoSetTeam.szDataFile,AutoSetTeam.SaveList)
	JH.Sysmsg(_L["Team list data saved"])
end
AutoSetTeam.Delete = function(n)
	AutoSetTeam.SaveList[n] = nil
	JH.SaveLUAData(AutoSetTeam.szDataFile,AutoSetTeam.SaveList)
end
AutoSetTeam.SyncMember = function(team, dwID, szName, state)
	if AutoSetTeam.bKeepForm and state.bForm then --如果这货之前有阵眼
		team.SetTeamFormationLeader(dwID, state.nGroup) -- 阵眼给他
		JH.Sysmsg("restore formation of " .. string.format("%d", state.nGroup + 1) .. " group: " .. szName)
	end
	if AutoSetTeam.bKeepMark and state.nMark then -- 如果这货之前有标记
		team.SetTeamMark(state.nMark, dwID) -- 标记给他
		JH.Sysmsg("restore player marked as [" .. AutoSetTeam.tMarkName[state.nMark] .. "]: " .. szName)
	end
end

AutoSetTeam.GetWrongIndex = function(tWrong, bState)
	for k, v in ipairs(tWrong) do
		if not bState or v.state then
			return k
		end
	end
end

AutoSetTeam.Restore = function(n)
	-- 获取自己和团队操作对象
	local me, team = GetClientPlayer(), GetClientTeam()
	-- update之前保存的团队列表
	AutoSetTeam.SaveList = JH.LoadLUAData(AutoSetTeam.szDataFile) or {}
	
	if not me or not me.IsInParty() then
		return JH.Sysmsg(_L["You are not in a team"])
	elseif not AutoSetTeam.SaveList[n] then
		return JH.Sysmsg(_L["You have not saved team list data"])
	end
	-- get perm
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) ~= me.dwID then
		local nGroup = team.GetMemberGroupIndex(me.dwID) + 1
		local szLeader = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER))
		return JH.Sysmsg(_L["You are not team leader, permission denied"])
	end
	
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK) ~= me.dwID then 
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK, me.dwID)
	end
	
	--parse wrong member
	local tSaved, tWrong, dwLeader, dwMark = AutoSetTeam.SaveList[n].data, {}, 0, 0
	for nGroup = 0, team.nGroupNum - 1 do
		tWrong[nGroup] = {}
		local tGroupInfo = team.GetGroupInfo(nGroup)
		for _, dwID in pairs(tGroupInfo.MemberList) do
			local szName = team.GetClientTeamMemberName(dwID)
			if not szName then
				JH.Sysmsg("unable get player of " .. string.format("%d", nGroup + 1) .. " group: #" .. dwID)
			else
				if not tSaved[szName] then
					szName = string.gsub(szName, "@.*", "")
				end
				local state = tSaved[szName]
				if not state then
					table.insert(tWrong[nGroup], { dwID = dwID, szName = szName, state = nil })
					JH.Sysmsg("unknown status: " .. szName)
				elseif state.nGroup == nGroup then 
					AutoSetTeam.SyncMember(team, dwID, szName, state)
					JH.Sysmsg("need not adjust: " .. szName)
				else
					table.insert(tWrong[nGroup], { dwID = dwID, szName = szName, state = state })
				end
				if szName == AutoSetTeam.SaveList[n].szLeader then
					dwLeader = dwID
				end
				if szName == AutoSetTeam.SaveList[n].szMark then
					dwMark = dwID
				end
				if szName == AutoSetTeam.SaveList[n].szDistribute and dwID ~= team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) then
					team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE,dwID)
					JH.Sysmsg("restore distributor: " .. szName)
				end
			end
		end
	end
	-- loop to restore
	for nGroup = 0, team.nGroupNum - 1 do
		local nIndex = AutoSetTeam.GetWrongIndex(tWrong[nGroup], true)
		while nIndex do
			-- wrong user to be adjusted
			local src = tWrong[nGroup][nIndex]
			local dIndex = AutoSetTeam.GetWrongIndex(tWrong[src.state.nGroup], false)
			table.remove(tWrong[nGroup], nIndex)
			-- do adjust
			if not dIndex then
				team.ChangeMemberGroup(src.dwID, src.state.nGroup, 0) -- 直接丢过去
			else
				local dst = tWrong[src.state.nGroup][dIndex]
				table.remove(tWrong[src.state.nGroup], dIndex)
				team.ChangeMemberGroup(src.dwID, src.state.nGroup, dst.dwID)
				if not dst.state or dst.state.nGroup ~= nGroup then
					table.insert(tWrong[nGroup], dst)
				else -- bingo
					JH.Sysmsg("change group of [" .. dst.szName .. "] to " .. string.format("%d", nGroup + 1))
					AutoSetTeam.SyncMember(team, dst.dwID, dst.szName, dst.state)
				end
			end
			JH.Sysmsg("change group of [" .. src.szName .. "] to " .. string.format("%d", src.state.nGroup + 1))
			AutoSetTeam.SyncMember(team, src.dwID, src.szName, src.state)
			nIndex = AutoSetTeam.GetWrongIndex(tWrong[nGroup], true) -- update nIndex
		end
	end
	-- restore others
	if team.nLootMode ~= AutoSetTeam.SaveList[n].nLootMode then
		team.SetTeamLootMode(AutoSetTeam.SaveList[n].nLootMode)
	end
	if dwLeader ~= 0 and dwLeader ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER, dwLeader)
		JH.Sysmsg("restore team leader: " .. AutoSetTeam.SaveList[n].szLeader)
	end
	if dwMark  ~= 0 and dwMark ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK, dwMark)
		JH.Sysmsg("restore team marker: " .. AutoSetTeam.SaveList[n].szMark)
	end
	JH.Sysmsg(_L["Team list restored"])
end

AutoSetTeam.Restore2 = function(n)
	local me, team = GetClientPlayer(), GetClientTeam()
	AutoSetTeam.SaveList = JH.LoadLUAData(AutoSetTeam.szDataFile) or {}
	if not me or not me.IsInParty() then
		return JH.Sysmsg(_L["You are not in a team"])
	elseif not AutoSetTeam.SaveList[n] then
		return JH.Sysmsg(_L["You have not saved team list data"])
	end
	-- get perm
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) ~= me.dwID then
		local nGroup = team.GetMemberGroupIndex(me.dwID) + 1
		local szLeader = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER))
		return JH.Sysmsg(_L["You are not team leader, permission denied"])
	end
	
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK) ~= me.dwID then 
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK, me.dwID)
	end

	local tSaved, tWrong, dwLeader, dwMark = AutoSetTeam.SaveList[n].data2, {}, 0, 0
	for nGroup = 0, team.nGroupNum - 1 do
		local tGroupInfo = team.GetGroupInfo(nGroup)
		for k,v in pairs(tGroupInfo.MemberList) do
			local info = team.GetMemberInfo(v)
			tWrong[v] = { nGroup = nGroup, dwMountKungfuID = info.dwMountKungfuID }
		end
	end
	
	local fnAction = function(dwMountKungfuID,nGroup,dwID)
		for k,v in pairs(tWrong) do
			if dwMountKungfuID and v.dwMountKungfuID == dwMountKungfuID then -- 只要内功匹配的人
				return k,v
			elseif nGroup and v.nGroup == nGroup and k ~= dwID then -- 不是自己的同组人要一个
				return k,v
			end
		end
		return false,false
	end
	
	for nGroup,tGroup in pairs(tSaved) do
		for k,v in ipairs(tGroup) do
			local tGroupInfo = team.GetGroupInfo(nGroup)
			local dwID,tab = fnAction(v.dwMountKungfuID)
			if dwID then
				local info = team.GetMemberInfo(dwID)
				if nGroup == tab.nGroup then
					tWrong[dwID] = nil
					JH.Sysmsg("need not adjust: " .. info.szName)
					AutoSetTeam.SyncMember(team, dwID, info.szName, v)
				else
					if #tGroupInfo.MemberList < 5 then
						team.ChangeMemberGroup(dwID,nGroup,0)
						tWrong[dwID] = nil
						JH.Sysmsg("change group of [" .. info.szName .. "] to " .. string.format("%d", nGroup + 1))
						AutoSetTeam.SyncMember(team, dwID, info.szName, v)
					else
						local ddwID,dtab = fnAction(false,nGroup,dwID)
						if ddwID then
							team.ChangeMemberGroup(dwID,nGroup,ddwID)
							tWrong[ddwID].nGroup = tab.nGroup -- update
							tWrong[dwID] = nil
							JH.Sysmsg("change group of [" .. info.szName .. "] to " .. string.format("%d", nGroup + 1))
							AutoSetTeam.SyncMember(team, dwID, info.szName, v)
						end
					end
				end
			end
		end
	end
	-- restore others
	if team.nLootMode ~= AutoSetTeam.SaveList[n].nLootMode then
		team.SetTeamLootMode(AutoSetTeam.SaveList[n].nLootMode)
	end
	if dwLeader ~= 0 and dwLeader ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER, dwLeader)
		JH.Sysmsg("restore team leader: " .. AutoSetTeam.SaveList[n].szLeader)
	end
	if dwMark  ~= 0 and dwMark ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK, dwMark)
		JH.Sysmsg("restore team marker: " .. AutoSetTeam.SaveList[n].szMark)
	end
	JH.Sysmsg(_L["Team list restored"])
end

do
	for k,v in ipairs(AutoSetTeam.tMarkName) do
		JH.AddHotKey("AutoSetTeam" .. k,_L["Mark"] .. " [" .. v .. "]",function()
			local dwID,_ = Target_GetTargetData()
			GetClientTeam().SetTeamMark(k,dwID) 
		end)
	end
end

local AppendMark = function()
	local WorldMark = Station.Lookup("Normal1/WorldMark")
	if not WorldMark or WorldMark.bAppend then
		return
	end
	local Wnd_WorldMark = WorldMark:Lookup("Wnd_WorldMark")
	local w,h = Wnd_WorldMark:Lookup("","Image_Bg"):GetSize()
	WorldMark:SetSize(w,h*2+22)
	Wnd_WorldMark:SetSize(w,h*2+22)
	local handle = Wnd_WorldMark:Lookup("","")
	handle:SetSize(w,h*2)
	Wnd_WorldMark:Lookup("","Image_Bg"):SetSize(w,h*2)
	handle:AppendItemFromString("<handle>w=195 h=82 name=\"Mark\"</handle>")
	local Mark = Wnd_WorldMark:Lookup("","Mark")
	Mark:SetHandleStyle(3)
	Mark:SetRelPos(5,82+22)
	handle:FormatAllItemPos()
	local tTeamMark,tMark = GetClientTeam().GetTeamMark() or {},{}
	for k,v in pairs(tTeamMark) do
		tMark[v] = true
	end
	for k,v in ipairs(AutoSetTeam.tMarkFrame) do
		Mark:AppendItemFromString(GetFormatImage(AutoSetTeam.szMarkImage,v,33,33,816,"Mark" ..k))
		local img = Mark:Lookup("Mark" ..k)
		if tMark[k] then
			img:SetAlpha(50)
			img.alpha = 50
		else
			img:SetAlpha(180)
			img.alpha = 180
		end
		img.OnItemLButtonClick = function()
			local dwID,_ = Target_GetTargetData()
			GetClientTeam().SetTeamMark(k,dwID) 
		end
		img.OnItemRButtonClick = function()
			GetClientTeam().SetTeamMark(k,0)
		end
		img.OnItemMouseEnter = function()
			this:SetAlpha(255)
		end
		img.OnItemMouseLeave = function()
			this:SetAlpha(this.alpha)
		end
		AutoSetTeam.Mark[k] = img
	end
	Mark:FormatAllItemPos()
	WorldMark.bAppend = true
end

local SetMark = function()
	if AutoSetTeam.Mark then
		local tTeamMark,tMark = GetClientTeam().GetTeamMark() or {},{}
		for k,v in pairs(tTeamMark) do
			tMark[v] = true
		end
		for k,v in ipairs(AutoSetTeam.Mark) do
			if tMark[k] then
				v:SetAlpha(50)
				v.alpha = 50
			else
				v:SetAlpha(180)
				v.alpha = 180
			end
		end
	end
end
local GetEvent = function()
	if JH_AutoSetTeam.bAppendMark then
		return 
			{ "Breathe", AppendMark, 500 },
			{ "PARTY_SET_MARK", SetMark }
	end
end
JH.RegisterEvent("LOGIN_GAME", function()
	JH.RegisterInit("Append_Mark", GetEvent())
end)

-- RequestList
RequestList = {
	-- bEnable = true,
}
local _RequestList = {
	tRequestList = {},
	tRequestCache = {},
	tDetails = {},
	szIniFile = JH.GetAddonInfo().szRootPath .. "AutoSetTeam/ui/RequestList.ini",
}
function RequestList.OnFrameCreate()
	_RequestList.frame = this
	_RequestList.bg = this:Lookup("", "Image_Bg")
	local ui = GUI(this)
	ui:Point():Title(_L["RequestList"]):RegisterClose(_RequestList.ClosePanel, false, true)
end
_RequestList.OpenPanel = function()
	local frame = _RequestList.frame or Wnd.OpenWindow(_RequestList.szIniFile,"RequestList")
	frame:Hide()
	return frame
end
_RequestList.ClosePanel = function(bCompulsory)
	if bCompulsory then
		Wnd.CloseWindow(_RequestList.frame)
		_RequestList.tRequestList = {}
		_RequestList.tRequestCache = {}
		_RequestList.frame = nil
	else
		JH.Confirm(_L["Clear list and close?"],function()
			Wnd.CloseWindow(_RequestList.frame)
			_RequestList.tRequestList = {}
			_RequestList.tRequestCache = {}
			_RequestList.frame = nil
		end)
	end
end
_RequestList.OnApplyRequest = function()
	if not JH_AutoSetTeam.bRequestList then return end
	local MsgBox,szName = Station.Lookup("Topmost/MB_ATMP_" .. arg0), "ATMP_" .. arg0
	if not MsgBox then
		MsgBox,szName = Station.Lookup("Topmost/MB_IMTP_" .. arg0), "IMTP_" .. arg0
	end
	if MsgBox then
		local btn = MsgBox:Lookup("Wnd_All/Btn_Option1")
		local btn2 = MsgBox:Lookup("Wnd_All/Btn_Option2")
		if btn and btn:IsEnabled() then
			if not _RequestList.tRequestCache[arg0] then
				table.insert(_RequestList.tRequestList,{
					szName = arg0,
					nCamp = arg1,
					dwForce = arg2,
					nLevel = arg3,
					fnAction = function()
						pcall(btn.fnAction)
					end,
					fnCancelAction = function()
						pcall(btn2.fnAction)
					end
				})
			end
			MsgBox.fnAutoClose = nil
			MsgBox.fnCancelAction = nil
			MsgBox.szCloseSound = nil
			CloseMessageBox(szName)
			_RequestList.tRequestCache[arg0] = true
			pcall(_RequestList.UpdateFrame)
		end
	end
end

_RequestList.UpdateFrame = function()
	if not _RequestList.frame then
		_RequestList.OpenPanel()
	end
	-- update
	if #_RequestList.tRequestList == 0 then
		return _RequestList.ClosePanel(true)
	end
	local camp = { [0] = -1, [1] = 43, [2] = 40 }
	local container = _RequestList.frame:Lookup("WndContainer_Request")
	container:Clear()
	local cover = "ui/Image/Common/CoverShadow.UITex"
	for k,v in ipairs(_RequestList.tRequestList) do
		local wnd = container:AppendContentFromIni(_RequestList.szIniFile, "WndWindow_Item", k)
		local ui = GUI(wnd)
		local dat = _RequestList.tDetails[v.szName]
		if dat then
			ui:Append("Image",{ x = 5, y = 5, w = 40, h = 40 }):File(Table_GetSkillIconID(dat.dwKungfuID,1))
			if dat.nGongZhan == 1 then
				ui:Append("Image",{ x = 25, y = 30, w = 15, h = 15 }):File(Table_GetBuffIconID(3219,1))
			end
		else
			ui:Append("Image",{ x = 5, y = 5, w = 40, h = 40 }):File(GetForceImage(v.dwForce))
		end
		ui:Append("Image",{ x = 215, y = 15, w = 20, h = 20 }):File("UI/Image/Button/ShopButton.uitex",camp[v.nCamp])
		ui:Append("Image",{ x = 0, y = 42, w = 420, h = 8 }):File("UI/Image/UICommon/CommonPanel.UITex",45)
		ui:Append("Image", "Cover", { x = 0, y = 0, w = 420, h = 50 }):File(cover,2):Toggle(false)
		ui:Hover(function()
			ui:Fetch("Cover"):File(cover,2):Toggle(true)
		end,function()
			ui:Fetch("Cover"):Toggle(false)
		end).self.OnRButtonDown = function()
			JH.SwitchChat(v.szName)
			Station.SetFocusWindow(Station.Lookup("Lowest2/EditBox/Edit_Input"))
		end
		ui:Append("Text",{ x = 47, y = 8, txt = v.szName, font = 15  })
		ui:Append("Text",{ x = 5, y = 25, txt = v.nLevel, font = 215 })
		wnd.OnLButtonDown = function()
			if IsCtrlKeyDown() then
				local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
				edit:InsertObj("[" .. v.szName .. "]",{ type = "name" , name = v.szName , text = v.szName})
				Station.SetFocusWindow(edit)
			end
		end
		ui:Append("WndButton2",{ x = 240, y = 10,w = 60, h = 34, txt = _L["Accept"] }):Click(function()
			v.fnAction()
			table.remove(_RequestList.tRequestList,k)
			_RequestList.tRequestCache[v.szName] = nil
			_RequestList.UpdateFrame()
		end):Hover(function()
			ui:Fetch("Cover"):File(cover,3):Toggle(true)
		end,function()
			ui:Fetch("Cover"):Toggle(false)
		end)
		ui:Append("WndButton2",{ x = 305, y = 10,w = 60, h = 34, txt = _L["Refuse"] }):Click(function()
			v.fnCancelAction()
			table.remove(_RequestList.tRequestList,k)
			_RequestList.tRequestCache[v.szName] = nil
			_RequestList.UpdateFrame()
		end):Hover(function()
			ui:Fetch("Cover"):File(cover,4):Toggle(true)
		end,function()
			ui:Fetch("Cover"):Toggle(false)
		end)
		if dat then
			ui:Append("WndButton2","Details",{ x = 370, y = 10,w = 90, h = 34, txt = _L["View Equip"] }):Click(function()
				ViewInviteToPlayer(dat.dwID)
			end):Hover(function()
				ui:Fetch("Cover"):File(cover,1):Toggle(true)
			end,function()
				ui:Fetch("Cover"):Toggle(false)
			end)
		else
			ui:Append("WndButton2","Details",{ x = 370, y = 10,w = 90, h = 34, txt = _L["Details"] }):Click(function()
				JH.BgTalk(v.szName,"JH_AutoSetTeam","JH_Details")
				ui:Fetch("Details"):Enable(false):Text(_L["loading..."])
				JH.Sysmsg(_L["If it is always loading, the target may not install plugin or refuse."])
			end):Hover(function()
				ui:Fetch("Cover"):File(cover,1):Toggle(true)
			end,function()
				ui:Fetch("Cover"):Toggle(false)
			end)
		end
	end
	local w, h = 470, 50
	local n = container:GetAllContentCount()
	container:SetSize(w, h * n)
	_RequestList.frame:SetSize(w, h * n + 30)
	_RequestList.frame:SetDragArea(0,0,w, h * n + 30)
	_RequestList.bg:SetSize(w, h * n + 30)
	container:FormatAllContentPos()
	_RequestList.frame:Show()
end
_RequestList.OnBgTalk = function()
	local data = JH.BgHear("JH_AutoSetTeam")
	if data then
		if data[1] == "JH_Details" then
			local dwTarget, szTarget = arg0, arg3
			JH.Confirm(_L("[%s] want to see your info, OK?",szTarget),function()
				local me,nGongZhan = GetClientPlayer(),0
				if JH.HasBuff(3219) then
					nGongZhan = 1
				end
				JH.BgTalk(szTarget,"JH_AutoSetTeam","JH_Feedback",me.dwID,UI_GetPlayerMountKungfuID(),nGongZhan)
			end)
		elseif data[1] == "JH_Feedback" then
			_RequestList.Feedback(arg3,data)
		end
	end
end
_RequestList.Feedback = function(szName,data)
	local dat = {
		dwID = data[2],
		dwKungfuID = data[3],
		nGongZhan = data[4],
	}
	_RequestList.tDetails[szName] = dat
	pcall(_RequestList.UpdateFrame)
end

_RequestList.GetEvent = function()
	if JH_AutoSetTeam.bRequestList then
		return 
			{ "PARTY_INVITE_REQUEST", _RequestList.OnApplyRequest },
			{ "PARTY_APPLY_REQUEST", _RequestList.OnApplyRequest },
			{ "ON_BG_CHANNEL_MSG", _RequestList.OnBgTalk }
	end
end

JH.RegisterEvent("LOGIN_GAME", function()
	JH.RegisterInit("RequestList", _RequestList.GetEvent())
end)

-------------------------------------------------
-- PARTY_UPDATE_MEMBER_POSITION	刷新队伍成员位置	arg0,arg1	arg0:dwTeamID  arg1:dwMemberID  	dwTeamID：队伍ID dwMemberID：成员ID 
-- PARTY_UPDATE_MEMBER_LMR	刷新队伍成员血量	arg0,arg1	arg0:dwTeamID  arg1:dwMemberID  	dwTeamID：队伍ID dwMemberID：成员ID 
-- PARTY_UPDATE_MEMBER_INFO	刷新队伍成员信息	arg0,arg1	arg0:dwTeamID  arg1:dwMemberID  	dwTeamID：队伍ID dwMemberID：成员ID 
-- PARTY_UPDATE_BASE_INFO	刷新队伍基本信息	arg0,arg1,arg2,arg3,arg4	arg0:dwTeamID  arg1:dwLeaderID  arg2:nLootMode  arg3:nRollQuality  arg4:bAddTeamMemberFlag   	dwTeamID：队伍ID :dwLeaderID：队长ID nLootMode  nRollQuality：需要Roll点的物品  bAddTeamMemberFlag：是否能增加队伍成员   
-- PARTY_SYNC_MEMBER_DATA	同步队伍成员数据	arg0,arg1,arg2	arg0:dwTeamID  arg1:dwMemberID  arg2:nGroupIndex  	dwTeamID：队伍ID dwMemberID：成员ID nGroupIndex ：分组ID 
-- PARTY_SET_MEMBER_ONLINE_FLAG	同步队伍成员是否在线状态	arg0,arg1,arg2	arg0:dwTeamID  arg1:dwMemberID  arg2:bOnlineFlag  	dwTeamID：队伍ID dwMemberID：成员ID bOnlineFlag：是否在线 
-- PARTY_SET_MARK	队伍设置标记	
-- PARTY_SET_FORMATION_LEADER	队伍设置阵眼	arg0	arg0:dwFormationLeader  	dwFormationLeader：阵眼成员ID
-- PARTY_SET_DISTRIBUTE_MAN	队伍设置分配者	arg0	arg0:dwDistributeMan  	dwDistributeMan：分配者ID
-- PARTY_ROLL_QUALITY_CHANGED	队伍需要Roll点物品品质改变	arg0,arg1	arg0:dwTeamID  arg1:nRollQuality  	dwTeamID：队伍ID nRollQuality：需要Roll点品质
-- PARTY_RESET	队伍重置	
-- PARTY_NOTIFY_SIGNPOST	队伍通知集合点	arg0,arg1	arg0:nX  arg1:nY  	nX,nY:坐标点
-- PARTY_MESSAGE_NOTIFY	队伍信息通知	arg0,arg1	arg0:nCode  arg1:szName  	nCode：见枚举型[[PARTY_NOTIFY_CODE]] szName:对应玩家名
-- PARTY_LOOT_MODE_CHANGED	队伍拾取模式更改	arg0,arg1	arg0:dwTeamID  arg1:nLootMode  	dwTeamID：队伍ID nLootMode：拾取模式，见枚举型[[PARTY_LOOT_MODE]]
-- PARTY_LEVEL_UP_RAID	队伍调整为团队模式	
-- PARTY_LEADER_CHANGED	更换队长	arg0,arg1	arg0:dwTeamID  arg1:dwNewLeaderID  	dwTeamID：队伍ID dwNewLeaderID：新的队长ID
-- PARTY_INVITE_REQUEST	邀请入队请求	arg0,arg1,arg2,arg3	arg0:szInviteSrc  arg1:dwSrcCamp  arg2:dwSrcForceID  arg3:dwSrcLevel  	szInviteSrc：邀请者 dwSrcCamp：邀请者阵营 dwSrcForceID：邀请者势力ID dwSrcLevel：邀请者等级 
-- PARTY_DISBAND	队伍解散	arg0	arg0:dwTeamID  	dwTeamID：队伍ID 
-- PARTY_DELETE_MEMBER	队伍删除成员	arg0,arg1,arg2,arg3	arg0:dwTeamID  arg1:dwMemberID  arg2:szName  arg3:nGroupIndex  	dwTeamID：队伍ID dwMemberID：成员ID szName：成员名 nGroupIndex：分组编号
-- PARTY_CAMP_CHANGE	队伍阵营变更	
-- PARTY_APPLY_REQUEST	申请入队请求	arg0,arg1,arg2,arg3	arg0:szApplySrc  arg1:dwSrcCamp  arg2:dwSrcForceID  arg3:dwSrcLevel  	szApplySrc：申请者名 dwSrcCamp：申请者阵营  dwSrcForceID：申请者势力ID dwSrcLevel：申请者等级
-- PARTY_ADD_MEMBER	队伍增加成员	arg0,arg1,arg2	arg0:dwTeamID  arg1:dwMemberID  arg2:nGroupIndex  	dwTeamID：队伍ID dwMemberID：成员ID nGroupIndex：分组编号
-------------------------------------------------
local TI = {}

TI.GetEvent = function()
	if JH_AutoSetTeam.bTeamInfo then
		return
			{ "PARTY_LEVEL_UP_RAID", function()
				if TI.IsLeader() then
					JH.Confirm(_L["Edit team info?"], function()
						TI.CreateFrame()
					end)
				end
			end },
			{ "PARTY_DISBAND", TI.CloseFrame },
			{ "PARTY_DELETE_MEMBER", function() if arg1 == UI_GetClientPlayerID() then TI.CloseFrame() end end },
			{ "PARTY_ADD_MEMBER", function() 
				if TI.IsLeader() and Station.Lookup("Normal/Team_Info") then 
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI","reply", arg1, TI.szYY, TI.szIntroduction) 
				end 
			end },
			{ "ON_BG_CHANNEL_MSG", TI.OnMsg}
	end
end

TI.IsLeader = function()
	return GetClientTeam().GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) == GetClientPlayer().dwID
end

TI.OnMsg = function()
	local data = JH.BgHear("TI")
	local me = GetClientPlayer()
	local team = GetClientTeam()
	if team and data then
		if data[1] == "ASK" and TI.IsLeader() then
			if Station.Lookup("Normal/Team_Info") then
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI","reply", arg3, TI.szYY, TI.szIntroduction) 
			end
		elseif data[1] == "Edit" then
			TI.CreateFrame(data[2], data[3])
		elseif data[1] == "reply" and (tonumber(data[2]) == UI_GetClientPlayerID() or data[2] == me.szName) then
			TI.CreateFrame(data[3], data[4])
		elseif data[1] == "Close" then
			TI.CloseFrame()
		end
	end
end

TI.CreateFrame = function(a, b)
	local an = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
	if Station.Lookup("Normal/Team_Info") then
		an = GetFrameAnchor(Station.Lookup("Normal/Team_Info"))
		Wnd.CloseWindow(Station.Lookup("Normal/Team_Info"))
	end
	local ui = GUI.CreateFrame2("Team_Info", { w = 300, h = 200, close = true, title = _L["Team_Info"]}):Point(an.s, 0, 0, an.r, an.x, an.y)
	local nX, nY = ui:Append("Text", { x = 10, y = 5, txt = _L["YY:"], font = 48 }):Pos_()
	nX = ui:Append("WndEdit", "YY", { w = 140, h = 26, x = nX + 5, y = 5, font = 48, color = { 128, 255, 0 }, txt = a })
	:Change(function(szText)
		if TI.IsLeader() then
			TI.szYY = szText
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "Edit", szText, ui:Fetch("introduction"):Text())
		else
			JH.Sysmsg(_L["You are not team leader."])
		end
	end):Pos_()
	nX, nY = ui:Append("WndButton2", { x = nX + 5, y = 5, txt = _L["Paste YY"]})
	:Click(function()
		local yy = ui:Fetch("YY"):Text()
		if yy ~= "" then JH.Talk(yy) end
	end):Pos_()
	ui:Append("WndEdit", "introduction", { w = 280, h = 80, x = 10, y = nY + 5, multi = true, txt = b or g_tStrings.STR_GUILD_EDIT_INTRODUCTION})
	:Change(function(szText)
		if TI.IsLeader() then
			TI.szIntroduction = szText
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "Edit", ui:Fetch("YY"):Text(), szText)
		else
			JH.Sysmsg(_L["You are not team leader."])
		end
	end)
	ui:Append("Text", { txt = _L["TI_TIP"], x = 10, y = 112, w = 280, h = 60, alpha = 80, multi = true })
	TI.szYY = ui:Fetch("YY"):Text()
	TI.szIntroduction = ui:Fetch("introduction"):Text()
	ui.self:Lookup("Btn_Close").OnLButtonClick = function()
		if TI.IsLeader() then
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "Close")
		end
		TI.CloseFrame()
	end
	ui:RegisterSetting(function() JH.OpenPanel(_L["AutoSetTeam"]) end)
end

TI.CloseFrame = function()
	if Station.Lookup("Normal/Team_Info") then
		Wnd.CloseWindow(Station.Lookup("Normal/Team_Info"))
	end
end

JH.RegisterEvent("LOGIN_GAME", function()
	JH.RegisterInit("TI", TI.GetEvent())
end)

JH.AddonMenu(function()
	return {
		szOption = _L["Enable TeamInfo"], fnDisable = function() local me = GetClientPlayer(); return not me.IsInRaid() end, fnAction = function()
			local me = GetClientPlayer()
			if JH_AutoSetTeam.bTeamInfo and  Station.Lookup("Normal/Team_Info") then
				TI.CloseFrame()
			else
				JH_AutoSetTeam.bTeamInfo = true
				JH.RegisterInit("TI", TI.GetEvent())
				if me.IsInRaid() then
					if TI.IsLeader() then
						TI.CreateFrame()
					else
						JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI","ASK") 
					end
				end
			end
		end
	}
end)

local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["AutoSetTeam"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 15, checked = JH_AutoSetTeam.bAppendMark, txt = _L["Append Mark"] }):Click(function(bChecked)
		JH_AutoSetTeam.bAppendMark = bChecked
		JH.RegisterInit("Append_Mark", GetEvent())
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 10, y = nY + 15, checked = JH_AutoSetTeam.bRequestList, txt = _L["RequestList"] }):Click(function(bChecked)
		JH_AutoSetTeam.bRequestList = bChecked
		JH.RegisterInit("RequestList", _RequestList.GetEvent())
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = JH_AutoSetTeam.bTeamInfo, txt = _L["Enable TeamInfo"] }):Click(function(bChecked)
		JH_AutoSetTeam.bTeamInfo = bChecked
		JH.RegisterInit("TI", TI.GetEvent())
	end):Pos_()
	
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Mark Target"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndButton2", { x = 10, y = nY + 15, txt = _L["Hotkey"] }):Click(JH.SetHotKey):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["SetTeam"], font = 27 }):Pos_()
	nY = nY + 10
	for i = 1,5 do
		local bEnable = false
		if AutoSetTeam.SaveList[i] then
			bEnable = true
		end
		nX = ui:Append("Text", { x = 0, y = nY, txt = _L("Team %d:",i)}):Pos_()
		nX = ui:Append("WndButton2", { x = nX + 5, y = nY, txt = _L["Save Team"]})
		:Enable(not bEnable):Click(function()
			AutoSetTeam.Save(i)
			JH.OpenPanel(_L["AutoSetTeam"])
		end):Pos_()
		local _nY = nY

		nX,nY = ui:Append("WndButton2", { x = nX + 5, y = nY, txt = _L["Recovery Team"]})
		:Enable(bEnable):Click(function()
			if IsCtrlKeyDown() then
				AutoSetTeam.Restore2(i)
			else
				AutoSetTeam.Restore(i)
			end
		end):Pos_()
		if bEnable then
			nX = ui:Append("WndComboBox", { x = nX + 5, y = _nY,w = 130, h = 30 , txt = _L["View Team"]})
			:Menu(function()
				local menu = {}
				local t = AutoSetTeam.SaveList[i]
				table.insert(menu,{szOption = _L("Leader:%s",t["szLeader"])})
				table.insert(menu,{szOption = _L("Distribute:%s",t["szDistribute"])})
				table.insert(menu,{szOption = _L("Mark:%s",t["szMark"])})
				table.insert(menu,{bDevide = true})
				for i = 1,5 do
					table.insert(menu,{szOption = _L("Party %d",i)})
				end
				for kk,vv in pairs(t["data"]) do
					table.insert(menu[5 + vv.nGroup],{szOption = kk})
				end
				return menu
			end):Pos_()
			ui:Append("WndButton2", { x = nX + 5, y = _nY, txt = _L["Delete"]})
			:Enable(bEnable):Click(function()
				AutoSetTeam.Delete(i)
				JH.OpenPanel(_L["AutoSetTeam"])
			end)
			
		end
	end
end
GUI.RegisterPanel(_L["AutoSetTeam"], 5962, _L["General"],PS)