RaidGridEx = RaidGridEx or {}
RaidGridEx.tOptions = {}

function RaidGridEx.OpenRaidDragPanel(dwMemberID)
	local hTeam = GetClientTeam()
	local tMemberInfo = hTeam.GetMemberInfo(dwMemberID)
	if not tMemberInfo then
		return
	end
	
	local hFrame = Wnd.OpenWindow("RaidDragPanel")
	
	local nX, nY = Cursor.GetPos()
	hFrame:SetAbsPos(nX, nY)
	hFrame:StartMoving()
	
	hFrame.dwID = dwMemberID
	local hMember = hFrame:Lookup("", "")
	
	local szPath, nFrame = GetForceImage(tMemberInfo.dwForceID)
	hMember:Lookup("Image_Force"):FromUITex(szPath, nFrame)
	
	local hTextName = hMember:Lookup("Text_Name")
	hTextName:SetText(tMemberInfo.szName)
	
	local hImageLife = hMember:Lookup("Image_Health")
	local hImageMana = hMember:Lookup("Image_Mana")
	if tMemberInfo.bIsOnLine then
		if tMemberInfo.nMaxLife > 0 then
			hImageLife:SetPercentage(tMemberInfo.nCurrentLife / tMemberInfo.nMaxLife)
		end
		if tMemberInfo.nMaxMana > 0 and tMemberInfo.nMaxMana ~= 1 then
			hImageMana:SetPercentage(tMemberInfo.nCurrentMana / tMemberInfo.nMaxMana)
		end
	else
		hImageLife:SetPercentage(0)
		hImageMana:SetPercentage(0)
	end
	
	hMember:Show()
end

function RaidGridEx.CloseRaidDragPanel()
	local hFrame = Station.Lookup("Normal/RaidDragPanel")
	if hFrame then
		hFrame:EndMoving()
		Wnd.CloseWindow(hFrame)
	end
end

function RaidGridEx.EditBox_AppendLinkPlayer(szPlayerName)
	local frame = Station.Lookup("Lowest2/EditBox")
	if not frame or not frame:IsVisible() then
		return false
	end

	local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
	edit:InsertObj("["..szPlayerName.."]", {type = "name", text = "["..szPlayerName.."]", name = szPlayerName})
	
	Station.SetFocusWindow(edit)
	return true
end

function RaidGridEx.InsertChangeGroupMenu(tMenu, dwMemberID)
	local hTeam = GetClientTeam()
	local tSubMenu = { szOption = g_tStrings.STR_RAID_MENU_CHANG_GROUP }
	
	local nCurGroupID = hTeam.GetMemberGroupIndex(dwMemberID)
	for i = 0, hTeam.nGroupNum - 1 do
		if i ~= nCurGroupID then
			local tGroupInfo = hTeam.GetGroupInfo(i)
			if tGroupInfo and tGroupInfo.MemberList then
				local tSubSubMenu = 
				{
					szOption = g_tStrings.STR_NUMBER[i + 1],
					bDisable = (#tGroupInfo.MemberList >= 5),
					fnAction = function() GetClientTeam().ChangeMemberGroup(dwMemberID, i, 0) end,
					fnAutoClose = function() return true end,
				}
				table.insert(tSubMenu, tSubSubMenu)
			end
		end
	end
	
	if #tSubMenu > 0 then
		table.insert(tMenu, tSubMenu)
	end
end
RaidGridEx.bLockPanel = false;					RegisterCustomData("RaidGridEx.bLockPanel")
RaidGridEx.bShowSystemRaidPanel = false;			RegisterCustomData("RaidGridEx.bShowSystemRaidPanel")
-- RaidGridEx.bControlPartyInRaid = true;			RegisterCustomData("RaidGridEx.bControlPartyInRaid")
RaidGridEx.bShowInRaid = true;					RegisterCustomData("RaidGridEx.bShowInRaid")
RaidGridEx.bAutoScalePanel = true;				RegisterCustomData("RaidGridEx.bAutoScalePanel")
RaidGridEx.bAutoDistColor = true;				RegisterCustomData("RaidGridEx.bAutoDistColor")
RaidGridEx.nDistColorInterval = 12;				RegisterCustomData("RaidGridEx.nDistColorInterval")
RaidGridEx.szDistColor_0 = "White";				RegisterCustomData("RaidGridEx.szDistColor_0")
RaidGridEx.szDistColor_8 = "Green";				RegisterCustomData("RaidGridEx.szDistColor_8")
RaidGridEx.szDistColor_20 = "Green";				RegisterCustomData("RaidGridEx.szDistColor_20")
RaidGridEx.szDistColor_24 = "Orange";				RegisterCustomData("RaidGridEx.szDistColor_24")
RaidGridEx.szDistColor_999 = "Red";				RegisterCustomData("RaidGridEx.szDistColor_999")

RaidGridEx.bAutoBUFFColor = true;				RegisterCustomData("RaidGridEx.bAutoBUFFColor")
RaidGridEx.nBuffFlashAlpha = 225;				RegisterCustomData("RaidGridEx.nBuffFlashAlpha")
RaidGridEx.nBuffCoverAlpha = 96;					RegisterCustomData("RaidGridEx.nBuffCoverAlpha")
RaidGridEx.nBuffFlashTime = 15;					RegisterCustomData("RaidGridEx.nBuffFlashTime")

RaidGridEx.bFightNameAlpha = true;				RegisterCustomData("RaidGridEx.bFightNameAlpha")

RaidGridEx.bShowNameColorByCondition = 1;		RegisterCustomData("RaidGridEx.bShowNameColorByKungfu")
RaidGridEx.bShowKungfu = true;					RegisterCustomData("RaidGridEx.bShowKungfu")
RaidGridEx.bShowKungfuIcon = true;				RegisterCustomData("RaidGridEx.bShowKungfuIcon")
RaidGridEx.bShowMark = true;						RegisterCustomData("RaidGridEx.bShowMark")
RaidGridEx.bShowLifeValue = true;				RegisterCustomData("RaidGridEx.bShowLifeValue")
RaidGridEx.bShowLastLife = true;					RegisterCustomData("RaidGridEx.bShowLastLife")
RaidGridEx.fontScale = 1;						RegisterCustomData("RaidGridEx.fontScale")
RaidGridEx.nDis1 = 8;							RegisterCustomData("RaidGridEx.nDis1")
RaidGridEx.nDis2 = 20;							RegisterCustomData("RaidGridEx.nDis2")
RaidGridEx.nDis3 = 24;							RegisterCustomData("RaidGridEx.nDis3")
RaidGridEx.bLockGroup = false;					RegisterCustomData("RaidGridEx.bLockGroup")
RaidGridEx.bShowPartyPanel = true;				RegisterCustomData("RaidGridEx.bShowPartyPanel")
RaidGridEx.szFontScheme = 15,					RegisterCustomData("RaidGridEx.szFontScheme")
RaidGridEx.bLifePercent = false;				RegisterCustomData("RaidGridEx.bLifePercent")
RaidGridEx.bLifeSimplify = true;				RegisterCustomData("RaidGridEx.bLifeSimplify")
-- 生成实际的菜单
function RaidGridEx.PopOptions()
	RaidGridEx.tOptions = {
		{
			szOption = "◆锁定插件面板位置", bCheck = true, bChecked = RaidGridEx.bLockPanel, fnAction =
			function(UserData, bCheck)
				RaidGridEx.bLockPanel = bCheck;
				if RaidGridEx.bLockPanel then
					RaidGridEx.frameSelf:EnableDrag(false)
				else
					RaidGridEx.frameSelf:EnableDrag(true)
				end
			end,
		},
		{
			szOption = "　重新加载团队界面", bCheck = true, bChecked = false, fnAction = function(UserData, bCheck) GetPopupMenu():Hide(); RaidGridEx.OnMemberChangeGroup() end,
		},
		{
			szOption = "　Debuff监视管理",fnAction = RaidGridEx.OpenDebuffSettingPanel
		},
		{bDevide = true},
		{
			szOption = "　团队就位确认", 
			{
				szOption = "开始就位确认", bCheck = false, bChecked = false, fnAction =
				function()
					if RaidGridEx.GetLeader() ~= GetClientPlayer().dwID then
						OutputMessage("MSG_ANNOUNCE_YELLOW", "你不是队长，不能执行这个操作")
						RaidGridEx.Message("错误：你不是队长，不能执行这个操作！")
						return
					end
					local tMsg = 
					{
						szMessage = g_tStrings.STR_RAID_MSG_START_READY_CONFIRM,
						szName = "StartReadyConfirm",
						{szOption = g_tStrings.STR_HOTKEY_SURE, fnAction = function() Send_RaidReadyConfirm(); RaidGridEx.ReadyCheck() end,},
						{szOption = g_tStrings.STR_HOTKEY_CANCEL, },
					}
					MessageBox(tMsg)
				end
			},
			{
				szOption = "重置确认状态", bCheck = false, bChecked = false, fnAction = 
				function(UserData, bCheck)
					GetPopupMenu():Hide(); RaidGridEx.OnMemberChangeGroup()
				end,
			},
		},
	
		{
			szOption = "◆锁定小队分组",
			bCheck = true,
			bChecked = RaidGridEx.bLockGroup,
			fnAction = function(UserData,bCheck)
				RaidGridEx.bLockGroup = bCheck
				if bCheck then
					OutputMessage("MSG_ANNOUNCE_YELLOW", "小队分组已锁定，你需要按住Shift才能进行分组")
					RaidGridEx.Message("小队分组已锁定，你需要 按住Shift 才能进行分组！")
				else
					OutputMessage("MSG_ANNOUNCE_YELLOW", "小队分组已解锁，执行拖动动作时请小心，以免误拖")
					RaidGridEx.Message("小队分组已解锁，执行拖动动作时请小心，以免误拖！")
				end
			end,
		},
		{bDevide = true},
		{
			szOption = "◆开启队友内功显示",
			bCheck = true,
			bChecked = RaidGridEx.bShowKungfu,
			fnAction = function(UserData,bCheck) RaidGridEx.bShowKungfu = bCheck; RaidGridEx.ReloadEntireTeamInfo(true) end,
			{
				szOption = "显示内功名字",
				bMCheck = true,
				bChecked = not RaidGridEx.bShowKungfuIcon,
				fnDisable = function() return not RaidGridEx.bShowKungfu end,
				fnAction = function() RaidGridEx.bShowKungfuIcon = false; RaidGridEx.ReloadEntireTeamInfo(true) end,
			},
			{
				szOption = "显示内功图标",
				bMCheck = true,
				bChecked = RaidGridEx.bShowKungfuIcon,
				fnDisable = function() return not RaidGridEx.bShowKungfu end,
				fnAction = function() RaidGridEx.bShowKungfuIcon = true; RaidGridEx.ReloadEntireTeamInfo(true) end,
			},
		},
		{
			szOption = "　队友名字着色模式",
			{
				szOption = "按门派着色",
				bMCheck = true,
				bChecked = RaidGridEx.bShowNameColorByCondition == 1,
				fnAction = function() RaidGridEx.bShowNameColorByCondition = 1; RaidGridEx.ReloadEntireTeamInfo(true) end,
			},
			{
				szOption = "按内功着色",
				bMCheck = true,
				bChecked = RaidGridEx.bShowNameColorByCondition == 2,
				fnAction = function() RaidGridEx.bShowNameColorByCondition = 2; RaidGridEx.ReloadEntireTeamInfo(true) end,
			},
			{
				szOption = "按阵营着色",
				bMCheck = true,
				bChecked = RaidGridEx.bShowNameColorByCondition == 3,
				fnAction = function() RaidGridEx.bShowNameColorByCondition = 3; RaidGridEx.ReloadEntireTeamInfo(true) end,
			},
		},
		{
			szOption = "　队友名字字体样式",
			{
				szOption = "样式一(默认样式)",
				bMCheck = true,
				bChecked = RaidGridEx.szFontScheme == 15,
				fnAction = function() RaidGridEx.szFontScheme = 15;RaidGridEx.ReloadEntireTeamInfo(true) end,
			},
			{
				szOption = "样式二(描边样式·小)",
				bMCheck = true,
				bChecked = RaidGridEx.szFontScheme == 7,
				fnAction = function() RaidGridEx.szFontScheme = 7;RaidGridEx.ReloadEntireTeamInfo(true) end,				
			},
			{
				szOption = "样式三(描边样式·大)",
				bMCheck = true,
				bChecked = RaidGridEx.szFontScheme == 23,
				fnAction = function() RaidGridEx.szFontScheme = 23;RaidGridEx.ReloadEntireTeamInfo(true) end,				
			},
		},
		{bDevide = true},
		{
			szOption = "◆开启标记图标显示",
			bCheck = true,
			bChecked = RaidGridEx.bShowMark,
			fnAction = function(UserData,bCheck) RaidGridEx.bShowMark = bCheck; RaidGridEx.ReloadEntireTeamInfo(true) end,
		},
		{
			szOption = "◆开启队友血量显示",
			bCheck = true,
			bChecked = RaidGridEx.bShowLifeValue,
			fnAction = function(UserData,bCheck) RaidGridEx.bShowLifeValue = bCheck; RaidGridEx.ReloadEntireTeamInfo(true) end,
			
			{
				szOption = "精简显示",
				bCheck = true,
				bChecked = RaidGridEx.bLifeSimplify,
				fnDisable = function() return not RaidGridEx.bShowLifeValue end,
				fnAction = function(UserData,bCheck) RaidGridEx.bLifeSimplify = not RaidGridEx.bLifeSimplify; RaidGridEx.ReloadEntireTeamInfo(true) end,
			},
			{
				szOption = "显示%",
				bCheck = true,
				bChecked = RaidGridEx.bLifePercent,
				fnDisable = function() return not RaidGridEx.bShowLifeValue end,
				fnAction = function(UserData,bCheck) RaidGridEx.bLifePercent = not RaidGridEx.bLifePercent; RaidGridEx.ReloadEntireTeamInfo(true) end,
			},

			{
				szOption = "显示剩余血量",
				bMCheck = true,
				bChecked = RaidGridEx.bShowLastLife,
				fnDisable = function() return not RaidGridEx.bShowLifeValue end,
				fnAction = function(UserData,bCheck) RaidGridEx.bShowLastLife = true; RaidGridEx.ReloadEntireTeamInfo(true) end,
			},
			{
				szOption = "显示损耗血量",
				bMCheck = true,
				bChecked = not RaidGridEx.bShowLastLife,
				fnDisable = function() return not RaidGridEx.bShowLifeValue end,
				fnAction = function(UserData,bCheck) RaidGridEx.bShowLastLife = false; RaidGridEx.ReloadEntireTeamInfo(true) end,
			},
		},
		{
			szOption = "　队友血量文字缩放",
			bCheck = false,
			{szOption = "0.8", bMCheck = true, bChecked = RaidGridEx.fontScale == 0.8, fnAction = function() RaidGridEx.fontScale = 0.8; RaidGridEx.ReloadEntireTeamInfo(true) end},
			{szOption = "0.9", bMCheck = true, bChecked = RaidGridEx.fontScale == 0.9, fnAction = function() RaidGridEx.fontScale = 0.9; RaidGridEx.ReloadEntireTeamInfo(true) end},
			{szOption = "1.0", bMCheck = true, bChecked = RaidGridEx.fontScale == 1, fnAction = function() RaidGridEx.fontScale = 1; RaidGridEx.ReloadEntireTeamInfo(true) end},
			{szOption = "1.1", bMCheck = true, bChecked = RaidGridEx.fontScale == 1.1, fnAction = function() RaidGridEx.fontScale = 1.1; RaidGridEx.ReloadEntireTeamInfo(true) end},
			{szOption = "1.3", bMCheck = true, bChecked = RaidGridEx.fontScale == 1.3, fnAction = function() RaidGridEx.fontScale = 1.3; RaidGridEx.ReloadEntireTeamInfo(true) end},
			{szOption = "1.5", bMCheck = true, bChecked = RaidGridEx.fontScale == 1.5, fnAction = function() RaidGridEx.fontScale = 1.5; RaidGridEx.ReloadEntireTeamInfo(true) end},
		},
		{bDevide = true},
		{
			szOption = "◆开启系统团队面板", bCheck = true, bChecked = RaidGridEx.bShowSystemRaidPanel, fnAction = function(UserData, bCheck) RaidGridEx.bShowSystemRaidPanel = bCheck; RaidGridEx.EnableRaidPanel(bCheck) end,
		},
		{
			szOption = "◆只在团队时才显示", bCheck = true, bChecked = RaidGridEx.bShowInRaid, fnAction = function(UserData, bCheck)
				RaidGridEx.bShowInRaid = bCheck
				if not RaidGridEx.IsInRaid() then
					if bCheck then
						RaidGridEx.ClosePanel()
					else
						RaidGridEx.OpenPanel()
					end
				end
				RaidGridEx.TeammatePanel_Switch()
			end,
		},
		{bDevide = true},
		{
			szOption = "◆开启自动精简模式", bCheck = true, bChecked = RaidGridEx.bAutoScalePanel, fnAction = function(UserData, bCheck) RaidGridEx.bAutoScalePanel = bCheck; RaidGridEx.AutoScalePanel() end,
		},
		{
			szOption = "◆战斗中半透明名字", bCheck = true, bChecked = RaidGridEx.bFightNameAlpha, fnAction = function(UserData, bCheck) RaidGridEx.bFightNameAlpha = bCheck end,
		},
		{bDevide = true},
		{
			szOption = "◆开启距离着色模式", bCheck = true, bChecked = RaidGridEx.bAutoDistColor, fnAction = function(UserData, bCheck) RaidGridEx.bAutoDistColor = bCheck end,
			{
				szOption = "　０～"..RaidGridEx.GetFullSizeNumber(RaidGridEx.nDis1).."米的颜色",
				{szOption = "红色", bMCheck = true, bChecked = RaidGridEx.szDistColor_8 == "Red", fnAction = function() RaidGridEx.szDistColor_8 = "Red" end},
				{szOption = "橙色", bMCheck = true, bChecked = RaidGridEx.szDistColor_8 == "Orange", fnAction = function() RaidGridEx.szDistColor_8 = "Orange" end},
				{szOption = "蓝色", bMCheck = true, bChecked = RaidGridEx.szDistColor_8 == "Blue", fnAction = function() RaidGridEx.szDistColor_8 = "Blue" end},
				{szOption = "绿色", bMCheck = true, bChecked = RaidGridEx.szDistColor_8 == "Green", fnAction = function() RaidGridEx.szDistColor_8 = "Green" end},
				{szOption = "白色", bMCheck = true, bChecked = RaidGridEx.szDistColor_8 == "White", fnAction = function() RaidGridEx.szDistColor_8 = "White" end},
			},
			{
				szOption = RaidGridEx.GetFullSizeNumber(RaidGridEx.nDis1).."～"..RaidGridEx.GetFullSizeNumber(RaidGridEx.nDis2).."米的颜色",
				{szOption = "红色", bMCheck = true, bChecked = RaidGridEx.szDistColor_20 == "Red", fnAction = function() RaidGridEx.szDistColor_20 = "Red" end},
				{szOption = "橙色", bMCheck = true, bChecked = RaidGridEx.szDistColor_20 == "Orange", fnAction = function() RaidGridEx.szDistColor_20 = "Orange" end},
				{szOption = "蓝色", bMCheck = true, bChecked = RaidGridEx.szDistColor_20 == "Blue", fnAction = function() RaidGridEx.szDistColor_20 = "Blue" end},
				{szOption = "绿色", bMCheck = true, bChecked = RaidGridEx.szDistColor_20 == "Green", fnAction = function() RaidGridEx.szDistColor_20 = "Green" end},
				{szOption = "白色", bMCheck = true, bChecked = RaidGridEx.szDistColor_20 == "White", fnAction = function() RaidGridEx.szDistColor_20 = "White" end},
			},
			{
				szOption = RaidGridEx.GetFullSizeNumber(RaidGridEx.nDis2).."～"..RaidGridEx.GetFullSizeNumber(RaidGridEx.nDis3).."米的颜色",
				{szOption = "红色", bMCheck = true, bChecked = RaidGridEx.szDistColor_24 == "Red", fnAction = function() RaidGridEx.szDistColor_24 = "Red" end},
				{szOption = "橙色", bMCheck = true, bChecked = RaidGridEx.szDistColor_24 == "Orange", fnAction = function() RaidGridEx.szDistColor_24 = "Orange" end},
				{szOption = "蓝色", bMCheck = true, bChecked = RaidGridEx.szDistColor_24 == "Blue", fnAction = function() RaidGridEx.szDistColor_24 = "Blue" end},
				{szOption = "绿色", bMCheck = true, bChecked = RaidGridEx.szDistColor_24 == "Green", fnAction = function() RaidGridEx.szDistColor_24 = "Green" end},
				{szOption = "白色", bMCheck = true, bChecked = RaidGridEx.szDistColor_24 == "White", fnAction = function() RaidGridEx.szDistColor_24 = "White" end},
			},
			{
				szOption = RaidGridEx.GetFullSizeNumber(RaidGridEx.nDis3).."～同步范围的颜色",
				{szOption = "红色", bMCheck = true, bChecked = RaidGridEx.szDistColor_999 == "Red", fnAction = function() RaidGridEx.szDistColor_999 = "Red" end},
				{szOption = "橙色", bMCheck = true, bChecked = RaidGridEx.szDistColor_999 == "Orange", fnAction = function() RaidGridEx.szDistColor_999 = "Orange" end},
				{szOption = "蓝色", bMCheck = true, bChecked = RaidGridEx.szDistColor_999 == "Blue", fnAction = function() RaidGridEx.szDistColor_999 = "Blue" end},
				{szOption = "绿色", bMCheck = true, bChecked = RaidGridEx.szDistColor_999 == "Green", fnAction = function() RaidGridEx.szDistColor_999 = "Green" end},
				{szOption = "白色", bMCheck = true, bChecked = RaidGridEx.szDistColor_999 == "White", fnAction = function() RaidGridEx.szDistColor_999 = "White" end},
			},
			{
				szOption = "超出同步范围的颜色",
				{szOption = "红色", bMCheck = true, bChecked = RaidGridEx.szDistColor_0 == "Red", fnAction = function() RaidGridEx.szDistColor_0 = "Red" end},
				{szOption = "橙色", bMCheck = true, bChecked = RaidGridEx.szDistColor_0 == "Orange", fnAction = function() RaidGridEx.szDistColor_0 = "Orange" end},
				{szOption = "蓝色", bMCheck = true, bChecked = RaidGridEx.szDistColor_0 == "Blue", fnAction = function() RaidGridEx.szDistColor_0 = "Blue" end},
				{szOption = "绿色", bMCheck = true, bChecked = RaidGridEx.szDistColor_0 == "Green", fnAction = function() RaidGridEx.szDistColor_0 = "Green" end},
				{szOption = "白色", bMCheck = true, bChecked = RaidGridEx.szDistColor_0 == "White", fnAction = function() RaidGridEx.szDistColor_0 = "White" end},
			},
		},
		{
			szOption = "　自定义各分级距离",
			{
				szOption = "第一级",
				{szOption = "　２米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 2, fnAction = function() RaidGridEx.nDis1 = 2 end},
				{szOption = "　３米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 3, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,3) end, fnAction = function() RaidGridEx.nDis1 = 3 end},
				{szOption = "　４米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 4, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,4) end, fnAction = function() RaidGridEx.nDis1 = 4 end},
				{szOption = "　５米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 5, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,5) end, fnAction = function() RaidGridEx.nDis1 = 5 end},
				{szOption = "　６米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 6, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,6) end, fnAction = function() RaidGridEx.nDis1 = 6 end},
				{szOption = "　７米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 7, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,7) end, fnAction = function() RaidGridEx.nDis1 = 7 end},
				{szOption = "　８米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 8, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,8) end, fnAction = function() RaidGridEx.nDis1 = 8 end},
				{szOption = "　９米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 9, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,9) end, fnAction = function() RaidGridEx.nDis1 = 9 end},
				{szOption = "１０米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 10, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,10) end, fnAction = function() RaidGridEx.nDis1 = 10 end},
				{szOption = "１１米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 11, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,11) end, fnAction = function() RaidGridEx.nDis1 = 11 end},
				{szOption = "１２米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 12, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,12) end, fnAction = function() RaidGridEx.nDis1 = 12 end},
				{szOption = "１３米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 13, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,13) end, fnAction = function() RaidGridEx.nDis1 = 13 end},
				{szOption = "１４米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 14, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,14) end, fnAction = function() RaidGridEx.nDis1 = 14 end},
				{szOption = "１５米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 15, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,15) end, fnAction = function() RaidGridEx.nDis1 = 15 end},
				{szOption = "１６米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 16, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,16) end, fnAction = function() RaidGridEx.nDis1 = 16 end},
				{szOption = "１７米", bMCheck = true, bChecked = RaidGridEx.nDis1 == 17, fnDisable = function() return RaidGridEx.IsDistanceDisable(1,17) end, fnAction = function() RaidGridEx.nDis1 = 17 end},
			},
			{
				szOption = "第二级",
				{szOption = "　３米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 3, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,3) end, fnAction = function() RaidGridEx.nDis2 = 3 end},
				{szOption = "　４米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 4, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,4) end, fnAction = function() RaidGridEx.nDis2 = 4 end},
				{szOption = "　５米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 5, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,5) end, fnAction = function() RaidGridEx.nDis2 = 5 end},
				{szOption = "　６米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 6, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,6) end, fnAction = function() RaidGridEx.nDis2 = 6 end},
				{szOption = "　７米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 7, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,7) end, fnAction = function() RaidGridEx.nDis2 = 7 end},
				{szOption = "　８米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 8, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,8) end, fnAction = function() RaidGridEx.nDis2 = 8 end},
				{szOption = "　９米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 9, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,9) end, fnAction = function() RaidGridEx.nDis2 = 9 end},
				{szOption = "１０米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 10, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,10) end, fnAction = function() RaidGridEx.nDis2 = 10 end},
				{szOption = "１１米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 11, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,11) end, fnAction = function() RaidGridEx.nDis2 = 11 end},
				{szOption = "１２米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 12, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,12) end, fnAction = function() RaidGridEx.nDis2 = 12 end},
				{szOption = "１３米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 13, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,13) end, fnAction = function() RaidGridEx.nDis2 = 13 end},
				{szOption = "１４米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 14, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,14) end, fnAction = function() RaidGridEx.nDis2 = 14 end},
				{szOption = "１５米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 15, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,15) end, fnAction = function() RaidGridEx.nDis2 = 15 end},
				{szOption = "１６米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 16, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,16) end, fnAction = function() RaidGridEx.nDis2 = 16 end},
				{szOption = "１７米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 17, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,17) end, fnAction = function() RaidGridEx.nDis2 = 17 end},
				{szOption = "１８米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 18, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,18) end, fnAction = function() RaidGridEx.nDis2 = 18 end},
				{szOption = "１９米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 19, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,19) end, fnAction = function() RaidGridEx.nDis2 = 19 end},
				{szOption = "２０米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 20, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,20) end, fnAction = function() RaidGridEx.nDis2 = 20 end},
				{szOption = "２１米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 21, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,21) end, fnAction = function() RaidGridEx.nDis2 = 21 end},
				{szOption = "２２米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 22, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,22) end, fnAction = function() RaidGridEx.nDis2 = 22 end},
				{szOption = "２３米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 23, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,23) end, fnAction = function() RaidGridEx.nDis2 = 23 end},
				{szOption = "２４米", bMCheck = true, bChecked = RaidGridEx.nDis2 == 24, fnDisable = function() return RaidGridEx.IsDistanceDisable(2,24) end, fnAction = function() RaidGridEx.nDis2 = 24 end},
			},
			{
				szOption = "第三级",
				{szOption = "１６米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 16, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,16) end, fnAction = function() RaidGridEx.nDis3 = 16 end},
				{szOption = "１７米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 17, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,17) end, fnAction = function() RaidGridEx.nDis3 = 17 end},
				{szOption = "１８米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 18, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,18) end, fnAction = function() RaidGridEx.nDis3 = 18 end},
				{szOption = "１９米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 19, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,19) end, fnAction = function() RaidGridEx.nDis3 = 19 end},
				{szOption = "２０米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 20, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,20) end, fnAction = function() RaidGridEx.nDis3 = 20 end},
				{szOption = "２１米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 21, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,21) end, fnAction = function() RaidGridEx.nDis3 = 21 end},
				{szOption = "２２米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 22, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,22) end, fnAction = function() RaidGridEx.nDis3 = 22 end},
				{szOption = "２３米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 23, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,23) end, fnAction = function() RaidGridEx.nDis3 = 23 end},
				{szOption = "２４米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 24, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,24) end, fnAction = function() RaidGridEx.nDis3 = 24 end},
				{szOption = "２５米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 25, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,25) end, fnAction = function() RaidGridEx.nDis3 = 25 end},
				{szOption = "２６米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 26, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,26) end, fnAction = function() RaidGridEx.nDis3 = 26 end},
				{szOption = "２７米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 27, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,27) end, fnAction = function() RaidGridEx.nDis3 = 27 end},
				{szOption = "２８米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 28, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,28) end, fnAction = function() RaidGridEx.nDis3 = 28 end},
				{szOption = "２９米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 29, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,29) end, fnAction = function() RaidGridEx.nDis3 = 29 end},
				{szOption = "３０米", bMCheck = true, bChecked = RaidGridEx.nDis3 == 30, fnDisable = function() return RaidGridEx.IsDistanceDisable(3,30) end, fnAction = function() RaidGridEx.nDis3 = 30 end},
			},
		},
		{
			szOption = "　距离着色处理间隔",
			{szOption = "０.２５秒", bMCheck = true, bChecked = RaidGridEx.nDistColorInterval == 4, fnAction = function() RaidGridEx.nDistColorInterval = 4 end},
			{szOption = "０.５　秒", bMCheck = true, bChecked = RaidGridEx.nDistColorInterval == 8, fnAction = function() RaidGridEx.nDistColorInterval = 8 end},
			{szOption = "０.７５秒", bMCheck = true, bChecked = RaidGridEx.nDistColorInterval == 12, fnAction = function() RaidGridEx.nDistColorInterval = 12 end},
			{szOption = "１.０　秒", bMCheck = true, bChecked = RaidGridEx.nDistColorInterval == 16, fnAction = function() RaidGridEx.nDistColorInterval = 16 end},
			{szOption = "１.５　秒", bMCheck = true, bChecked = RaidGridEx.nDistColorInterval == 24, fnAction = function() RaidGridEx.nDistColorInterval = 24 end},
		},
		{bDevide = true},
		{
			szOption = "◆开启Debuff监视模式", bCheck = true, bChecked = RaidGridEx.bAutoBUFFColor, fnAction = function(UserData, bCheck)
				RaidGridEx.bAutoBUFFColor = bCheck;
				for dwMemberID, _ in pairs(RaidGridEx.tRoleIDList) do
					RaidGridEx.UpdateMemberBuff(dwMemberID)
				end
			end,
			{
				szOption = "图标闪烁速度",
				{szOption = "不闪烁", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 0, fnAction = function() RaidGridEx.nBuffFlashTime = 0 end},
				{szOption = "３", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 3, fnAction = function() RaidGridEx.nBuffFlashTime = 3 end},
				{szOption = "６", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 6, fnAction = function() RaidGridEx.nBuffFlashTime = 6 end},
				{szOption = "９", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 9, fnAction = function() RaidGridEx.nBuffFlashTime = 9 end},
				{szOption = "１２", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 12, fnAction = function() RaidGridEx.nBuffFlashTime = 12 end},
				{szOption = "１５", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 15, fnAction = function() RaidGridEx.nBuffFlashTime = 15 end},
				{szOption = "１８", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 18, fnAction = function() RaidGridEx.nBuffFlashTime = 18 end},
				{szOption = "２１", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 21, fnAction = function() RaidGridEx.nBuffFlashTime = 21 end},
				{szOption = "２５", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 25, fnAction = function() RaidGridEx.nBuffFlashTime = 25 end},
				{szOption = "３０", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 30, fnAction = function() RaidGridEx.nBuffFlashTime = 30 end},
				{szOption = "３５", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 35, fnAction = function() RaidGridEx.nBuffFlashTime = 35 end},
				{szOption = "４０", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 40, fnAction = function() RaidGridEx.nBuffFlashTime = 40 end},
				{szOption = "５０", bMCheck = true, bChecked = RaidGridEx.nBuffFlashTime == 50, fnAction = function() RaidGridEx.nBuffFlashTime = 50 end},
			},
			{
				szOption = "图标最大不透明度",
				{szOption = "８５", bMCheck = true, bChecked = RaidGridEx.nBuffFlashAlpha == 85, fnAction = function() RaidGridEx.nBuffFlashAlpha = 85 end},
				{szOption = "１００", bMCheck = true, bChecked = RaidGridEx.nBuffFlashAlpha == 100, fnAction = function() RaidGridEx.nBuffFlashAlpha = 100 end},
				{szOption = "１２５", bMCheck = true, bChecked = RaidGridEx.nBuffFlashAlpha == 125, fnAction = function() RaidGridEx.nBuffFlashAlpha = 125 end},
				{szOption = "１５０", bMCheck = true, bChecked = RaidGridEx.nBuffFlashAlpha == 150, fnAction = function() RaidGridEx.nBuffFlashAlpha = 150 end},
				{szOption = "１７５", bMCheck = true, bChecked = RaidGridEx.nBuffFlashAlpha == 175, fnAction = function() RaidGridEx.nBuffFlashAlpha = 175 end},
				{szOption = "２００", bMCheck = true, bChecked = RaidGridEx.nBuffFlashAlpha == 200, fnAction = function() RaidGridEx.nBuffFlashAlpha = 200 end},
				{szOption = "２２５", bMCheck = true, bChecked = RaidGridEx.nBuffFlashAlpha == 225, fnAction = function() RaidGridEx.nBuffFlashAlpha = 225 end},
				{szOption = "２５０", bMCheck = true, bChecked = RaidGridEx.nBuffFlashAlpha == 250, fnAction = function() RaidGridEx.nBuffFlashAlpha = 250 end},
			},
			{
				szOption = "辅助背景色透明度",
				{szOption = "３２", bMCheck = true, bChecked = RaidGridEx.nBuffCoverAlpha == 32, fnAction = function() RaidGridEx.nBuffCoverAlpha = 32 end},
				{szOption = "６４", bMCheck = true, bChecked = RaidGridEx.nBuffCoverAlpha == 64, fnAction = function() RaidGridEx.nBuffCoverAlpha = 64 end},
				{szOption = "９６", bMCheck = true, bChecked = RaidGridEx.nBuffCoverAlpha == 96, fnAction = function() RaidGridEx.nBuffCoverAlpha = 96 end},
				{szOption = "１２８", bMCheck = true, bChecked = RaidGridEx.nBuffCoverAlpha == 128, fnAction = function() RaidGridEx.nBuffCoverAlpha = 128 end},
				{szOption = "１６０", bMCheck = true, bChecked = RaidGridEx.nBuffCoverAlpha == 160, fnAction = function() RaidGridEx.nBuffCoverAlpha = 160 end},
				{szOption = "１９２", bMCheck = true, bChecked = RaidGridEx.nBuffCoverAlpha == 192, fnAction = function() RaidGridEx.nBuffCoverAlpha = 192 end},
			},
		},
		{
			bDevide = true
		},
		
		{
			szOption = "　团队界面缩放",
			{szOption = "0.8", bMCheck = true, 	bChecked = RaidGridEx.fScale == 0.8, fnAction = function() RaidGridEx.SetScale(0.8, RaidGridEx.fScale);RaidGridEx.fScale = 0.8 end},
			{szOption = "1.2", bMCheck = true, 	bChecked = RaidGridEx.fScale == 1.2, fnAction = function() RaidGridEx.SetScale(1.2, RaidGridEx.fScale);RaidGridEx.fScale = 1.2 end},
			{szOption = "1.4", bMCheck = true, 	bChecked = RaidGridEx.fScale == 1.4, fnAction = function() RaidGridEx.SetScale(1.4, RaidGridEx.fScale);RaidGridEx.fScale = 1.4 end},
			{szOption = "1.6", bMCheck = true, 	bChecked = RaidGridEx.fScale == 1.6, fnAction = function() RaidGridEx.SetScale(1.6, RaidGridEx.fScale);RaidGridEx.fScale = 1.6 end},
			{szOption = "1.8", bMCheck = true, 	bChecked = RaidGridEx.fScale == 1.8, fnAction = function() RaidGridEx.SetScale(1.8, RaidGridEx.fScale);RaidGridEx.fScale = 1.8 end},
			{szOption = "2", bMCheck = true, 	bChecked = RaidGridEx.fScale == 2, fnAction = function() RaidGridEx.SetScale(2, RaidGridEx.fScale);RaidGridEx.fScale = 2 end},
			{szOption = "2.2", bMCheck = true, 	bChecked = RaidGridEx.fScale == 2.2, fnAction = function() RaidGridEx.SetScale(2.2, RaidGridEx.fScale);RaidGridEx.fScale = 2.2 end},
			{szOption = "2.4", bMCheck = true, 	bChecked = RaidGridEx.fScale == 2.4, fnAction = function() RaidGridEx.SetScale(2.4, RaidGridEx.fScale);RaidGridEx.fScale = 2.4 end},
			{szOption = "2.6", bMCheck = true, 	bChecked = RaidGridEx.fScale == 2.6, fnAction = function() RaidGridEx.SetScale(2.6, RaidGridEx.fScale);RaidGridEx.fScale = 2.6 end},
			{szOption = "2.8", bMCheck = true, 	bChecked = RaidGridEx.fScale == 2.8, fnAction = function() RaidGridEx.SetScale(2.8, RaidGridEx.fScale);RaidGridEx.fScale = 2.8 end},
			{szOption = "3", bMCheck = true, 	bChecked = RaidGridEx.fScale == 3, fnAction = function() RaidGridEx.SetScale(3, RaidGridEx.fScale);RaidGridEx.fScale = 3 end},
			{szOption = "5", bMCheck = true, 	bChecked = RaidGridEx.fScale == 5, fnAction = function() RaidGridEx.SetScale(5, RaidGridEx.fScale);RaidGridEx.fScale = 5 end},
			{szOption = "【复位】", bMCheck = true, bChecked = RaidGridEx.fScale == 1, fnAction = function() RaidGridEx.SetScale(1, 0);RaidGridEx.fScale = 1 end},
		},
		

		--------------------------------------------------------
		fnAction = function(UserData, bCheck)
		end,
		fnChangeColor = function(UserData, r, g, b)
		end,
		fnCancelAction = function()
		end,
		fnAutoClose = function()
			return false
		end,
	}
	
	local nX, nY = Cursor.GetPos(true)
	RaidGridEx.tOptions.x, RaidGridEx.tOptions.y = nX + 15, nY + 15
	
	local tForceList = {}
	local hTeam = GetClientTeam()
	for nGroupID = 0, hTeam.nGroupNum - 1 do
		local tGroupInfo = hTeam.GetGroupInfo(nGroupID)
		for _, dwMemberID in ipairs(tGroupInfo.MemberList) do
			local tMemberInfo = hTeam.GetMemberInfo(dwMemberID)
			if not tForceList[tMemberInfo.dwForceID] then
				tForceList[tMemberInfo.dwForceID] = 0
			end
			tForceList[tMemberInfo.dwForceID] = tForceList[tMemberInfo.dwForceID] + 1
		end
	end
	local tSubMenu = { szOption = "　查看人数统计：" }
	for dwForceID, nCount in pairs(tForceList) do
		table.insert(tSubMenu, { szOption = g_tStrings.tForceTitle[dwForceID] .. "   " .. nCount })
	end
	table.insert(RaidGridEx.tOptions, tSubMenu)
	
	
	PopupMenu(RaidGridEx.tOptions)
end

function RaidGridEx.SetScale(fScale, fOldScale)
	if fOldScale == 0 then
		RaidGridEx.fScale = 1
		Wnd.CloseWindow(RaidGridEx.frameSelf)
		RaidGridEx.OpenPanel(true)		
		return
	else
		RaidGridEx.fScale = fScale
		Wnd.CloseWindow(RaidGridEx.frameSelf)
		RaidGridEx.OpenPanel(true)
		return
	end	
end

function RaidGridEx.PopMemberOptions()
end


function RaidGridEx.IsDistanceDisable(nLevel,nDis)
	if nLevel == 1 then
		if nDis >= RaidGridEx.nDis2 then
			return true
		end
	elseif nLevel == 2 then
		if nDis <= RaidGridEx.nDis1 or nDis >= RaidGridEx.nDis3 then
			return true
		end
	elseif nLevel == 3 then
		if nDis <= RaidGridEx.nDis2 then
			return true
		end
	end
	return false
end

function RaidGridEx.GetFullSizeNumber(szNum) -- 输入数值为半角数字,长度为数串长度
	szNum = tostring(szNum)
	local tFullSizeNumber = {"０","１","２","３","４","５","６","７","８","９"}
	for i = 0, 9, 1 do
		while string.find(szNum, tostring(i)) do
			szNum = szNum:gsub(tostring(i), tFullSizeNumber[i+1])
		end
	end
	if #szNum == 2 then -- 输出值为全角数字,长度为数串长度的二倍
		szNum = "　"..szNum
	end
	return szNum
end

function RaidGridEx.ReadyCheck()
	local team = GetClientTeam()
	if GetClientPlayer().IsInParty() then
		for nGroupIndex = 0, 4, 1 do
			local tGroupInfo = team.GetGroupInfo(nGroupIndex)
			if tGroupInfo then
				RaidGridEx.tGroupList[nGroupIndex] = RaidGridEx.tGroupList[nGroupIndex] or {}		
				for nSortIndex = 1, #tGroupInfo.MemberList do
					local dwMemberID = tGroupInfo.MemberList[nSortIndex]
					if RaidGridEx.GetLeader() ~= dwMemberID then
						local handleRole = RaidGridEx.GetRoleHandleByID(dwMemberID)
						local imgReadyCheck = handleRole:Lookup("Image_ReadyCheck")
						imgReadyCheck:SetAlpha(160)
						imgReadyCheck:Show()
					end
				end
			end
		end
	end
end