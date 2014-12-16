RaidGridEx = RaidGridEx or {}
RaidGridEx.nSteper = -1
RaidGridEx.frameSelf = nil
RaidGridEx.handleMain = nil
RaidGridEx.handleBG = nil
RaidGridEx.handleDummy = nil
RaidGridEx.handleRoles = nil
RaidGridEx.tLootModeImage = nil
RaidGridEx.tRollQualityImage = nil

RaidGridEx.szTitleText = "V2.1"

RaidGridEx.nColLength = 64
RaidGridEx.nRowLength = 45
RaidGridEx.nLeftBound = 10
RaidGridEx.nBottomBound = 8
RaidGridEx.nTopBound = 28
RaidGridEx.nTitleHeight = 24

RaidGridEx.handleLastSelect = nil
RaidGridEx.bDrag = false
RaidGridEx.TeamGroupInfo = {}

RaidGridEx.tLastLoc = {nX = 0, nY = 0};		RegisterCustomData("RaidGridEx.tLastLoc")
RaidGridEx.fScale = 1.4
RegisterCustomData("RaidGridEx.fScale")

local szIniFile = "Interface/JH/RaidGridEx/RaidGridEx.ini"
local tLootTip = 
{
	Image_LootColor_Green	= "【绿色品质】",
	Image_LootColor_Blue	= "【蓝色品质】",
	Image_LootColor_Purple	= "【紫色品质】",
	Image_LootColor_Orange	= "【橙色品质】",
	Image_LootMode_Free		= "【自由拾取】",
	Image_LootMode_Looter	= "【分配者分配】",
	Image_LootMode_Roll		= "【队伍拾取】",
	LEADER = "（右键设置）",
}

-- ---------------------------------------------------------------
-- 事件相关
-- ---------------------------------------------------------------

function RaidGridEx.OnCustomDataLoaded()
	if arg0 ~= "Role" then
		return
	end
	RaidGridEx.frameSelf = Wnd.OpenWindow("Interface\\JH\\RaidGridEx\\RaidGridEx.ini", "RaidGridEx")
	Wnd.OpenWindow("Interface\\JH\\RaidGridEx\\DebuffSettingPanel.ini", "DebuffSettingPanel"):Hide()
	if not RaidGridEx.fScale then
		RaidGridEx.fScale = 1
		RaidGridEx.SetScale(1, 0)
	end	
	if RaidGridEx.tLastLoc.nX == 0 and RaidGridEx.tLastLoc.nY == 0 then
		RaidGridEx.SetPanelPos()
	elseif RaidGridEx.frameSelf then
		RaidGridEx.SetPanelPos(RaidGridEx.tLastLoc.nX, RaidGridEx.tLastLoc.nY)
	end
end

function RaidGridEx.OnFrameCreate()
	this:RegisterEvent("PARTY_SYNC_MEMBER_DATA")
	this:RegisterEvent("PARTY_ADD_MEMBER")
	this:RegisterEvent("PARTY_DISBAND")
	this:RegisterEvent("PARTY_DELETE_MEMBER")
	this:RegisterEvent("PARTY_UPDATE_MEMBER_INFO")
	this:RegisterEvent("PARTY_UPDATE_MEMBER_LMR")
	this:RegisterEvent("PARTY_SET_MEMBER_ONLINE_FLAG")
	this:RegisterEvent("PLAYER_STATE_UPDATE")
	this:RegisterEvent("PARTY_SET_MARK")
	this:RegisterEvent("BUFF_UPDATE")
	this:RegisterEvent("UPDATE_PLAYER_SCHOOL_ID")
	this:RegisterEvent("RIAD_READY_CONFIRM_RECEIVE_ANSWER")
	this:RegisterEvent("UI_SCALED")	
	this:RegisterEvent("TEAM_AUTHORITY_CHANGED")
	this:RegisterEvent("PARTY_SET_FORMATION_LEADER")	
	this:RegisterEvent("PARTY_LOOT_MODE_CHANGED")
	this:RegisterEvent("PARTY_ROLL_QUALITY_CHANGED")
	this:RegisterEvent("TEAM_CHANGE_MEMBER_GROUP")
	local frame = Station.Lookup("Normal/RaidGridEx")
	RaidGridEx.frameSelf = frame
	if RaidGridEx.bLockPanel then
		frame:EnableDrag(false)
	else
		frame:EnableDrag(true)
	end
end

function RaidGridEx.OnEvent(szEvent)
	local player = GetClientPlayer()
	if not player then return end
	local frame = Station.Lookup("Normal/RaidGridEx")
	if szEvent == "PARTY_SYNC_MEMBER_DATA" then
		RaidGridEx.OnMemberJoinTeam(arg1, arg2)
		RaidGridEx.ShowRoleHandle(nil, nil, RaidGridEx.GetRoleHandleByID(arg1))
		RaidGridEx.RedrawMemberHandleHPnMP(arg1)
		RaidGridEx.RedrawMemberHandleState(arg1)
		RaidGridEx.UpdateMemberSpecialState(arg1)
		RaidGridEx.AutoScalePanel()
	elseif szEvent == "PARTY_ADD_MEMBER" then
		RaidGridEx.OnMemberJoinTeam(arg1, arg2)
		RaidGridEx.ShowRoleHandle(nil, nil, RaidGridEx.GetRoleHandleByID(arg1))
		RaidGridEx.RedrawMemberHandleHPnMP(arg1)
		RaidGridEx.RedrawMemberHandleState(arg1)
		RaidGridEx.UpdateMemberSpecialState(arg1)
		RaidGridEx.AutoScalePanel()
		RaidGridEx.ReloadEntireTeamInfo(true)
		if not RaidGridEx.IsInRaid() then
			if RaidGridEx.bShowInRaid then
				RaidGridEx.ClosePanel()		
			else
				RaidGridEx.OpenPanel()
			end
		end
	elseif szEvent == "PARTY_DELETE_MEMBER" then
		if GetClientPlayer().dwID == arg1 then
			-- if RaidGridEx.bShowInRaid then
				RaidGridEx.ClosePanel()
			-- else
				-- RaidGridEx.OnMemberChangeGroup()
			-- end
		else
			RaidGridEx.OnMemberChangeGroup()
		end
	elseif szEvent == "PARTY_DISBAND" then
		-- if RaidGridEx.bShowInRaid then
			RaidGridEx.ClosePanel()
		-- else
			-- RaidGridEx.OnMemberChangeGroup()
		-- end
	elseif szEvent == "PARTY_UPDATE_MEMBER_INFO" then
		RaidGridEx.RedrawMemberHandleState(arg1)
		RaidGridEx.UpdateMemberSpecialState(arg1)
	elseif szEvent == "UPDATE_PLAYER_SCHOOL_ID" then
		if player.IsPlayerInMyParty(arg0) then
			RaidGridEx.RedrawMemberHandleState(arg0)
			RaidGridEx.UpdateMemberSpecialState(arg0)
		end
	elseif szEvent == "PARTY_UPDATE_MEMBER_LMR" then
		RaidGridEx.RedrawMemberHandleHPnMP(arg1)
	elseif szEvent == "PLAYER_STATE_UPDATE" then
		if player.IsPlayerInMyParty(arg0) then
			RaidGridEx.RedrawMemberHandleState(arg0)
		end
	elseif szEvent == "PARTY_SET_MEMBER_ONLINE_FLAG" then
		RaidGridEx.RedrawMemberHandleHPnMP(arg1)
		RaidGridEx.RedrawMemberHandleState(arg1)
		RaidGridEx.UpdateMemberSpecialState(arg1)
		RaidGridEx.ReloadEntireTeamInfo(true)
	elseif szEvent == "PARTY_SET_MARK" then
		RaidGridEx.ReloadEntireTeamInfo(true)
	elseif szEvent == "BUFF_UPDATE" then
		if player.IsPlayerInMyParty(arg0) then
			RaidGridEx.OnUpdateBuffData(arg0, arg1, arg2, arg4, arg5, arg6, arg8)
		end
	elseif szEvent == "TEAM_AUTHORITY_CHANGED" then
		RaidGridEx.RedrawMemberHandleState(arg2)
		RaidGridEx.RedrawMemberHandleState(arg3)
	elseif szEvent == "PARTY_SET_FORMATION_LEADER" then
		RaidGridEx.OnMemberChangeGroup()
	elseif szEvent == "PARTY_LOOT_MODE_CHANGED" then
		for i = 1, 3 do
			if arg1 == i then
				RaidGridEx.tLootModeImage[i]:SetAlpha(255)
			else
				RaidGridEx.tLootModeImage[i]:SetAlpha(64)
			end
		end
	elseif szEvent == "PARTY_ROLL_QUALITY_CHANGED" then
		for i = 2, 5 do
			if arg1 == i then
				RaidGridEx.tRollQualityImage[i]:SetAlpha(255)
			else
				RaidGridEx.tRollQualityImage[i]:SetAlpha(64)
			end
		end
	elseif szEvent == "RIAD_READY_CONFIRM_RECEIVE_ANSWER" then
		RaidGridEx.ChangeReadyConfirm(arg0, arg1)
	elseif szEvent == "UI_SCALED" then
		if RaidGridEx.tLastLoc.nX == 0 and RaidGridEx.tLastLoc.nY == 0 then
			RaidGridEx.SetPanelPos()
		else
			RaidGridEx.SetPanelPos(RaidGridEx.tLastLoc.nX, RaidGridEx.tLastLoc.nY)
		end
	elseif szEvent == "TEAM_CHANGE_MEMBER_GROUP" then
		if not RaidGridEx.IsOpened() and RaidGridEx.bShowInRaid then
			frame:Show()
		end
	end
end

-- ---------------------------------------------------------------
-- 鼠标点击相关
-- ---------------------------------------------------------------
function RaidGridEx.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Option" then
		RaidGridEx.PopOptions()
	elseif szName == "Btn_WorldMark" then
		Wnd.ToggleWindow("WorldMark")
	end
end

function RaidGridEx.OnItemLButtonClick()
	local szName = this:GetName()	
	if szName:match("Handle_Role_") and this:GetAlpha() == 255 then
		local dwMemberID = RaidGridEx.tGroupList[this.nGroupIndex][this.nSortIndex]
		if dwMemberID and dwMemberID > 0 and IsPlayer(dwMemberID) then 
			local player = GetPlayer(dwMemberID)
			local tMemberInfo = RaidGridEx.GetTeamMemberInfo(dwMemberID)
			if tMemberInfo then
				if RaidGridEx.handleLastSelect then
					RaidGridEx.handleLastSelect:Lookup("Animate_SelectRole"):Hide()
					RaidGridEx.handleLastSelect = nil
				end				
				if IsCtrlKeyDown() then													
					--if IsGMPanelReceivePlayer() then
					--	GMPanel_LinkPlayerID(tMemberInfo.dwID)
					--else
						RaidGridEx.EditBox_AppendLinkPlayer(tMemberInfo.szName)
					--end					
				else
					if player then
						RaidGridEx.SetTarget(dwMemberID)
					end
				end
			end
		end
	end
end

function RaidGridEx.OnItemRButtonClick()
	local szName = this:GetName()
	local team = GetClientTeam()
	if not team then
		return
	end
	
	local tLootMode = {Image_LootMode_Free = PARTY_LOOT_MODE.FREE_FOR_ALL, Image_LootMode_Looter = PARTY_LOOT_MODE.DISTRIBUTE, Image_LootMode_Roll = PARTY_LOOT_MODE.GROUP_LOOT}
	local tLootColor = {Image_LootColor_Green = 2, Image_LootColor_Blue = 3, Image_LootColor_Purple = 4, Image_LootColor_Orange = 5}
	if szName:match("Image_LootMode") and RaidGridEx.IsLooter(GetClientPlayer().dwID) then
		team.SetTeamLootMode(tLootMode[szName]) --设置物品分配模式
	elseif szName:match("Image_LootColor") and RaidGridEx.IsLooter(GetClientPlayer().dwID) then
		team.SetTeamRollQuality(tLootColor[szName]) --设置需要ROLL点的物品品质
	elseif szName:match("Handle_Role_") and this:GetAlpha() == 255 then
		local tMenu = {}
		local player = GetClientPlayer()
		local dwMemberID = RaidGridEx.tGroupList[this.nGroupIndex][this.nSortIndex]
		
		if RaidGridEx.IsLeader(player.dwID) then
			RaidGridEx.InsertChangeGroupMenu(tMenu, dwMemberID)
		end
		
		if dwMemberID ~= player.dwID then
			InsertTeammateMenu(tMenu, dwMemberID) --插入到Teammate菜单里
		else
			InsertPlayerMenu(tMenu) --插入到Player菜单里
		end

		if tMenu and #tMenu > 0 then
			PopupMenu(tMenu)
		end
	end
end

-- ---------------------------------------------------------------
-- 队伍分队, 拖动成员相关
-- ---------------------------------------------------------------
local nDragGroupID = nil			-- 拖动的源小队序号
local dwDragMemberID = nil			-- 拖动的角色ID
function RaidGridEx.OnItemLButtonDrag()
	local szName = this:GetName()
	if not RaidGridEx.IsLeader(GetClientPlayer().dwID) or not szName:match("Handle_Role_") then
		return
	end	
	if not RaidGridEx.bLockGroup or IsShiftKeyDown() then
		RaidGridEx.bDrag = true
		RaidGridEx.AutoScalePanel()
		
		nDragGroupID = this.nGroupIndex
		dwDragMemberID = RaidGridEx.tGroupList[this.nGroupIndex][this.nSortIndex]
		RaidGridEx.OpenRaidDragPanel(dwDragMemberID)
	else
		RaidGridEx.Message("错误：小队分组已锁定，你需要 解锁 或 按住Shift 才能进行分组！")
	end
end

function RaidGridEx.OnItemLButtonDragEnd()
	local szName = this:GetName()
	local team = GetClientTeam()
	if not RaidGridEx.IsLeader(GetClientPlayer().dwID) or not szName:match("Handle_Role_") or not team then
		return
	end
	
	RaidGridEx.bDrag = false
	RaidGridEx.AutoScalePanel()
	local nTargetGroup = this.nGroupIndex
	local dwTargetMemberID = RaidGridEx.tGroupList[this.nGroupIndex][this.nSortIndex] or 0

	if nTargetGroup and nTargetGroup >= 0 and nTargetGroup < 5 then
		if nDragGroupID and dwDragMemberID and dwTargetMemberID and (nTargetGroup ~= nDragGroupID) then
			team.ChangeMemberGroup(dwDragMemberID, nTargetGroup, dwTargetMemberID)
		end
	end

	RaidGridEx.handleBG:Lookup("Image_DragBox"):Hide()
	RaidGridEx.handleBG:Lookup("Image_DragBox_Disable"):Hide()
	
	nDragGroupID = nil
	dwDragMemberID = nil
	RaidGridEx.CloseRaidDragPanel()
end
RegisterEvent("UPDATE_SELECT_TARGET",function()
	if RaidGridEx.handleLastSelect then
		local ani = RaidGridEx.handleLastSelect:Lookup("Animate_SelectRole")
		if ani then
			ani:Hide()
			RaidGridEx.handleLastSelect = nil
		end
	end
end)
function RaidGridEx.OnFrameBreathe()
	RaidGridEx.nSteper = RaidGridEx.nSteper + 1

	-- 目标显示
	local player = GetClientPlayer()
	if player then
		local _, dwTargetID = player.GetTarget()
		if dwTargetID and dwTargetID > 0 then
			local target = nil		
			if IsPlayer(dwTargetID) and player.IsPlayerInMyParty(dwTargetID) then
				target = GetPlayer(dwTargetID)
			else
				if IsPlayer(dwTargetID) then
					target = GetPlayer(dwTargetID)
				else
					target = GetNpc(dwTargetID)
				end
				if target then
					local _, dwTargetTargetID = target.GetTarget()
					if IsPlayer(dwTargetTargetID) and player.IsPlayerInMyParty(dwTargetTargetID) then
						target = GetPlayer(dwTargetTargetID)
					else
						target = nil
					end
				end
			end
			if target then
				RaidGridEx.handleLastSelect = RaidGridEx.GetRoleHandleByID(target.dwID)
				if RaidGridEx.handleLastSelect then
					RaidGridEx.handleLastSelect:Lookup("Animate_SelectRole"):Show()
				end
			end
		end
	end

	-- 关闭拖弋模式
	if RaidGridEx.bDrag and not IsKeyDown("LButton") then
		RaidGridEx.bDrag = false
		RaidGridEx.AutoScalePanel()
		RaidGridEx.handleBG:Lookup("Image_DragBox"):Hide()
		RaidGridEx.handleBG:Lookup("Image_DragBox_Disable"):Hide()
		nDragGroupID = nil
		dwDragMemberID = nil
		RaidGridEx.CloseRaidDragPanel()	--
	end
	
	-- 更新距离提示
	if RaidGridEx.nSteper % (RaidGridEx.nDistColorInterval or 12) == 0 then
		for dwMemberID, _ in pairs(RaidGridEx.tRoleIDList) do
			RaidGridEx.UpdateMemberSpecialState(dwMemberID)
		end
	end
	
	-- 自动精简模式下屏蔽TITLE信息
	if RaidGridEx.bAutoScalePanel then
		RaidGridEx.frameSelf:Lookup("", "Text_Title"):Hide()
	else
		RaidGridEx.frameSelf:Lookup("", "Text_Title"):Show()
	end
	
	-- DEBUFF 监视
	if RaidGridEx.bAutoBUFFColor then
		for dwMemberID, _ in pairs(RaidGridEx.tRoleIDList) do
			RaidGridEx.UpdateMemberBuff(dwMemberID)
		end
	end
	RaidGridEx.EnableRaidPanel(RaidGridEx.bShowSystemRaidPanel)
	RaidGridEx.TeammatePanel_Switch()
	RaidGridEx.tLastLoc.nX, RaidGridEx.tLastLoc.nY = RaidGridEx.frameSelf:GetRelPos()
end

-- ---------------------------------------------------------------
-- 队伍成员TIPS 等鼠标进去离开事件
-- ---------------------------------------------------------------
function RaidGridEx.OnItemMouseEnter()
	local szName = this:GetName()

	if szName:match("Image_Loot") then
		local szLEADER = ""
		if RaidGridEx.IsLooter(GetClientPlayer().dwID) then
			this:SetAlpha(210)
			szLEADER = tLootTip.LEADER
		end
		RaidGridEx.frameSelf:Lookup("", "Text_Title"):SetText(tLootTip[szName] .. szLEADER)
		RaidGridEx.frameSelf:Lookup("", "Text_Title"):SetAlpha(200)
	elseif szName:match("Handle_Role_") then
		RaidGridEx.EnterRoleHandle(nil, nil, this)
		
		if RaidGridEx.bDrag then
			local nGroupIndex = this.nGroupIndex
			local imageDragBox = nil
			if nGroupIndex == nDragGroupID then
				imageDragBox = RaidGridEx.handleBG:Lookup("Image_DragBox_Disable")
				RaidGridEx.handleBG:Lookup("Image_DragBox"):Hide()
			else
				imageDragBox = RaidGridEx.handleBG:Lookup("Image_DragBox")
				RaidGridEx.handleBG:Lookup("Image_DragBox_Disable"):Hide()
			end
			if imageDragBox then
				imageDragBox:Show()
				imageDragBox:SetRelPos((nGroupIndex * RaidGridEx.nColLength + 5) * RaidGridEx.fScale, RaidGridEx.nTopBound)
				RaidGridEx.handleBG:FormatAllItemPos()
			end
		end
	end
end

function RaidGridEx.OnItemMouseLeave()
	local szName = this:GetName()
	local nLootMode, nRollQuality = RaidGridEx.GetLootModenQuality()
	if szName:match("Image_LootColor") then
		if RaidGridEx.tRollQualityImage[nRollQuality] and RaidGridEx.tRollQualityImage[nRollQuality]:GetName() == szName then
			this:SetAlpha(255)
		else
			this:SetAlpha(64)
		end
		RaidGridEx.frameSelf:Lookup("", "Text_Title"):SetText(RaidGridEx.szTitleText)
		RaidGridEx.frameSelf:Lookup("", "Text_Title"):SetAlpha(64)
	elseif szName:match("Image_LootMode") then
		if RaidGridEx.tLootModeImage[nLootMode] and RaidGridEx.tLootModeImage[nLootMode]:GetName() == szName then
			this:SetAlpha(255)
		else
			this:SetAlpha(64)
		end
		RaidGridEx.frameSelf:Lookup("", "Text_Title"):SetText(RaidGridEx.szTitleText)
		RaidGridEx.frameSelf:Lookup("", "Text_Title"):SetAlpha(64)
	elseif szName:match("Handle_Role_") then
		RaidGridEx.LeaveRoleHandle(nil, nil, this)
	end
end

-- ---------------------------------------------------------------
-- 团队数据更新
-- ---------------------------------------------------------------
function RaidGridEx.SetTarget(dwTargetID)	--设置目标
	local nType = TARGET.NPC
	if not dwTargetID or (dwTargetID <= 0) then
		nType = TARGET.NO_TARGET
		dwTargetID = 0
	elseif IsPlayer(dwTargetID) then
		nType = TARGET.PLAYER
	end
	if SetTarget then
		local as0, as1 = arg0, arg1
		SetTarget(nType, dwTargetID)
		arg0, arg1 = as0, as1
	elseif SelectTarget then
		SelectTarget(nType, dwTargetID)
	end
end


function RaidGridEx.OpenPanel(bForceShow)
	local player = GetClientPlayer()
	if not player then
		return
	end
	local frame = Station.Lookup("Normal/RaidGridEx")
	if not frame then
		frame = Wnd.OpenWindow("Interface\\JH\\RaidGridEx\\RaidGridEx.ini", "RaidGridEx")
	end

	RaidGridEx.frameSelf = frame
	RaidGridEx.handleMain = frame:Lookup("", "")
	RaidGridEx.handleBG = frame:Lookup("", "Handle_BG")
	RaidGridEx.handleDummy = frame:Lookup("", "Handle_Dummy")
	RaidGridEx.handleRoles = frame:Lookup("", "Handle_Roles")
	
	RaidGridEx.tLootModeImage = {RaidGridEx.handleBG:Lookup("Image_LootMode_Free"), RaidGridEx.handleBG:Lookup("Image_LootMode_Looter"), RaidGridEx.handleBG:Lookup("Image_LootMode_Roll"),	}
	RaidGridEx.tRollQualityImage = {{}, RaidGridEx.handleBG:Lookup("Image_LootColor_Green"), RaidGridEx.handleBG:Lookup("Image_LootColor_Blue"), RaidGridEx.handleBG:Lookup("Image_LootColor_Purple"), RaidGridEx.handleBG:Lookup("Image_LootColor_Orange"), }
	
	RaidGridEx.frameSelf:Lookup("", "Handle_Dummy"):Hide()
	RaidGridEx.CreateAllRoleHandle()
	RaidGridEx.ReloadEntireTeamInfo(true)
	RaidGridEx.AutoScalePanel()
	RaidGridEx.SetPanelPos(RaidGridEx.tLastLoc.nX, RaidGridEx.tLastLoc.nY)

	RaidGridEx.handleBG:Lookup("Image_DragBox"):Scale(RaidGridEx.fScale, RaidGridEx.fScale)
	RaidGridEx.handleBG:Lookup("Image_DragBox_Disable"):Scale(RaidGridEx.fScale, RaidGridEx.fScale)
	RaidGridEx.handleMain:FormatAllItemPos()
	
	frame:Show()
	
	if not RaidGridEx.IsInRaid() then
		if RaidGridEx.bShowInRaid and not bForceShow then -- 开启只在团队后，如果不是团队模式就不显示, 否则在任何时候都显示
			RaidGridEx.ClosePanel()
		end
	end
	if not player.IsInParty() then
		RaidGridEx.ClosePanel()
	end
end

function RaidGridEx.NoticeChangeLootMode()
	local player = GetClientPlayer()
	local hTeam = GetClientTeam()
	local dwLooterID = hTeam.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE)
	
	if player.IsInParty() then
		if player.dwID == dwLooterID then
			local msg=
			{
				szMessage = "是否要转换分配模式为【分配者分配】？",
				szName = "LootModeChangeTip",
				{szOption = g_tStrings.STR_HOTKEY_SURE, fnAction = function() hTeam.SetTeamLootMode(PARTY_LOOT_MODE.DISTRIBUTE) end},
				{szOption = g_tStrings.STR_HOTKEY_CANCEL}
			}
		else
			RaidGridEx.Message("你没有分配权，无法自动更改分配模式，请提醒当前分配者注意更改分配模式！")
		end
	end
end

function RaidGridEx.ClosePanel()
	local frame = Station.Lookup("Normal/RaidGridEx")
	if frame then
		frame:Hide()
	end
end

function RaidGridEx.IsOpened()
	local frame = Station.Lookup("Normal/RaidGridEx")
	if frame then
		return frame:IsVisible()
	end
end

function RaidGridEx.IsInRaid()
	return GetClientPlayer().IsInRaid()
end

function RaidGridEx.OpenDebuffSettingPanel()
	if DebuffSettingPanel then
		DebuffSettingPanel.OpenPanel()
	end
end

-- 隐藏默认团队界面
function RaidGridEx.EnableRaidPanel(bEnable)
	local frame = Station.Lookup("Normal/RaidPanel_Main")
	if frame then
		if bEnable then
			frame:Show()
		else
			frame:Hide()
		end
	end
end

function RaidGridEx.TeammatePanel_Switch(arg)
	local hFrame = Station.Lookup("Normal/Teammate")
	if not hFrame then return end
	if not RaidGridEx.IsInRaid() and RaidGridEx.bShowInRaid then
		hFrame:Show()
	else
		hFrame:Hide()
	end
end

RegisterEvent("PARTY_LEVEL_UP_RAID", function() 
	RaidGridEx.OpenPanel(); 
	RaidGridEx.AutoScalePanel();
	RaidGridEx.NoticeChangeLootMode();
end)
RegisterEvent("CUSTOM_DATA_LOADED", RaidGridEx.OnCustomDataLoaded)
RegisterEvent("SYNC_ROLE_DATA_END", function() RaidGridEx.OpenPanel(); RaidGridEx.AutoScalePanel(); end)
RegisterEvent("PARTY_UPDATE_BASE_INFO", function() RaidGridEx.OpenPanel(); RaidGridEx.AutoScalePanel();end)
RegisterEvent("TEAM_CHANGE_MEMBER_GROUP", function() RaidGridEx.OnMemberChangeGroup(arg0, arg1, arg3, arg2) end)

JH.AddHotKey("JH_RaidGridEx_Toggle","开启/关闭RaidGrid",function()
	if RaidGridEx.IsOpened() then
		RaidGridEx.ClosePanel()
	else
		RaidGridEx.OpenPanel(true)
	end
end)

JH.AddHotKey("RaidGridEx_Reload","重新加载RaidGrid",RaidGridEx.OnMemberChangeGroup)
