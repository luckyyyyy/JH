RaidGrid_CTM_Edition = RaidGrid_CTM_Edition or {}

local CTM_LOOT_MODE = {
	Image_LootMode_Free = PARTY_LOOT_MODE.FREE_FOR_ALL, 
	Image_LootMode_Looter = PARTY_LOOT_MODE.DISTRIBUTE, 
	Image_LootMode_Roll = PARTY_LOOT_MODE.GROUP_LOOT,
	Image_LootMode_Bidding = PARTY_LOOT_MODE.BIDDING,
}

-------------------------------------------------
-- 界面创建 事件注册
-------------------------------------------------
function RaidGrid_CTM_Edition.OnFrameCreate()
	this:RegisterEvent("PARTY_UPDATE_BASE_INFO")
	this:RegisterEvent("PARTY_SYNC_MEMBER_DATA")
	this:RegisterEvent("PARTY_ADD_MEMBER")
	this:RegisterEvent("PARTY_DISBAND")
	this:RegisterEvent("PARTY_DELETE_MEMBER")
	this:RegisterEvent("PARTY_UPDATE_MEMBER_INFO")
	this:RegisterEvent("PARTY_UPDATE_MEMBER_LMR")
	this:RegisterEvent("PARTY_LEVEL_UP_RAID")
	this:RegisterEvent("PARTY_SET_MEMBER_ONLINE_FLAG")
	this:RegisterEvent("PLAYER_STATE_UPDATE")
	this:RegisterEvent("UPDATE_PLAYER_SCHOOL_ID")
	this:RegisterEvent("RIAD_READY_CONFIRM_RECEIVE_ANSWER")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("PARTY_SET_MARK")
	this:RegisterEvent("TEAM_AUTHORITY_CHANGED")
	this:RegisterEvent("TEAM_CHANGE_MEMBER_GROUP")
	this:RegisterEvent("PARTY_SET_FORMATION_LEADER")
	this:RegisterEvent("PARTY_LOOT_MODE_CHANGED")
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("CTM_LOADING_END")
	this:RegisterEvent("TARGET_CHANGE")
	if GetClientPlayer() then
		FireEvent("CTM_LOADING_END")
	end
end
-------------------------------------------------
-- 拖动窗体
-------------------------------------------------
function RaidGrid_CTM_Edition.OnFrameDrag() -- 救命小天使
	RaidGrid_Party.AutoLinkAllPanel()
end
-------------------------------------------------
-- 事件处理
-------------------------------------------------
function RaidGrid_CTM_Edition.OnEvent(szEvent)
	if szEvent == "PARTY_SYNC_MEMBER_DATA" then		-- dwTeamID:arg0, dwMemberID:arg1, nGroupIndex:arg2
		RaidGrid_Party.OnAddOrDeleteMember(arg1, arg2)
		RaidGrid_Party.RedrawHandleRoleHPnMP(arg1)
		RaidGrid_Party.RedrawHandleRoleInfo(arg1)
		RaidGrid_Party.RedrawHandleRoleInfoEx(arg1)
		RaidGrid_Party.AutoLinkAllPanel()
	elseif szEvent == "PARTY_ADD_MEMBER" then			-- dwTeamID:arg0, dwMemberID:arg1, nGroupIndex:arg2
		RaidGrid_Party.OnAddOrDeleteMember(arg1, arg2)
		RaidGrid_Party.RedrawHandleRoleHPnMP(arg1)
		RaidGrid_Party.RedrawHandleRoleInfo(arg1)
		RaidGrid_Party.RedrawHandleRoleInfoEx(arg1)
		RaidGrid_Party.AutoLinkAllPanel()
	elseif szEvent == "PARTY_DELETE_MEMBER" then		-- dwTeamID:arg0, dwMemberID:arg1, szMemberName:arg2
		RaidGrid_Party.tLifeColor[arg1] = nil
		RaidGrid_Party.tOrgW[arg1] = nil
		RaidGrid_Party.ReloadRaidPanel()
		RaidGrid_CTM_Edition.UpdateLootImages()
	elseif szEvent == "PARTY_DISBAND" then				-- dwTeamID:arg0
		RaidGrid_Party.tLifeColor = {}
		RaidGrid_Party.tOrgW = {}
		RaidGrid_Party.ReloadRaidPanel()
		RaidGrid_CTM_Edition.UpdateLootImages()
	elseif szEvent == "PARTY_UPDATE_MEMBER_LMR" then	-- dwTeamID:arg0, dwMemberID:arg1
		RaidGrid_Party.RedrawHandleRoleHPnMP(arg1)
	elseif szEvent == "PARTY_UPDATE_MEMBER_INFO" then	-- dwTeamID:arg0, dwMemberID:arg1
		RaidGrid_Party.RedrawHandleRoleInfo(arg1)
		RaidGrid_Party.RedrawHandleRoleInfoEx(arg1)
	elseif szEvent == "UPDATE_PLAYER_SCHOOL_ID" then
		if JH.IsParty(arg0) then
			RaidGrid_Party.RedrawHandleRoleInfo(arg0)
			RaidGrid_Party.RedrawHandleRoleInfoEx(arg0)
		end
	elseif szEvent == "PLAYER_STATE_UPDATE" then
		if JH.IsParty(arg0) then
			RaidGrid_Party.RedrawHandleRoleInfo(arg0)
		end
	elseif szEvent == "PARTY_SET_MEMBER_ONLINE_FLAG" then
		RaidGrid_Party.RedrawHandleRoleHPnMP(arg1)
		RaidGrid_Party.RedrawHandleRoleInfo(arg1)
		RaidGrid_Party.RedrawHandleRoleInfoEx(arg1)
	elseif szEvent == "TEAM_AUTHORITY_CHANGED" then
		RaidGrid_Party.RedrawHandleRoleInfo(arg2)
		RaidGrid_Party.RedrawHandleRoleInfo(arg3)
	elseif szEvent == "PARTY_SET_FORMATION_LEADER" then
		RaidGrid_Party.ReloadRaidPanel()
	elseif szEvent == "PARTY_SET_MARK" then
		RaidGrid_Party.UpdateMarkImage()
	elseif szEvent == "RIAD_READY_CONFIRM_RECEIVE_ANSWER" then
		RaidGrid_Party.UpdateReadyCheckCover(arg0, arg1)
	elseif szEvent == "PARTY_UPDATE_BASE_INFO" or szEvent == "PARTY_LEVEL_UP_RAID" or szEvent == "TEAM_CHANGE_MEMBER_GROUP" then
		RaidGrid_Party.ReloadRaidPanel()
	elseif szEvent == "PARTY_LOOT_MODE_CHANGED" then
		RaidGrid_CTM_Edition.UpdateLootImages()
	elseif szEvent == "LOADING_END" or szEvent == "PARTY_UPDATE_BASE_INFO" then
		RaidGrid_Party.ReloadRaidPanel()
		RaidGrid_CTM_Edition.UpdateAnchor(this)
		RaidGrid_CTM_Edition.UpdateLootImages()
	elseif szEvent == "CTM_LOADING_END" then
		RaidGrid_Party.ReloadRaidPanel()
		RaidGrid_CTM_Edition.UpdateAnchor(this)
		RaidGrid_CTM_Edition.UpdateLootImages()
	elseif szEvent == "TARGET_CHANGE" then
		RaidGrid_Party.RedrawTargetSelectImage()
	elseif szEvent == "UI_SCALED" then
		RaidGrid_CTM_Edition.UpdateAnchor(this)
		RaidGrid_Party.AutoLinkAllPanel()
	end
end
-------------------------------------------------
-- 菜单和世界标记
-------------------------------------------------
function RaidGrid_CTM_Edition.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Option" then
		RaidGrid_CTM_Edition.PopOptions()
	elseif szName == "Btn_WorldMark" then
		Wnd.ToggleWindow("WorldMark")
	end
end

function RaidGrid_CTM_Edition.OnItemLButtonClick()
	local szName = this:GetName()
	local team = GetClientTeam()
	local player = GetClientPlayer()
	if IsCtrlKeyDown() or not szName:match("Image_Loot") or not team or not player.IsInParty() or team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) ~= player.dwID then
		return
	end
	if szName:match("Image_LootMode") then
		team.SetTeamLootMode(CTM_LOOT_MODE[szName])
	end
end

function RaidGrid_CTM_Edition.OnFrameBreathe()
	local me = GetClientPlayer()
	if not me then return end
	
	RaidGrid_Party.RedrawAllFadeHP()
	RaidGrid_Party.UpdateMemberDistance()
	RaidGrid_Party.UpdateReadyCheckFade()
	
	if not RaidGrid_CTM_Edition.bShowSystemRaidPanel then
		RaidGrid_CTM_Edition.RaidPanel_Switch(false)
	end
	
	if RaidGrid_CTM_Edition.bShowSystemTeamPanel then
		RaidGrid_CTM_Edition.TeammatePanel_Switch(true)
	elseif RaidGrid_CTM_Edition.bShowRaid then
		RaidGrid_CTM_Edition.TeammatePanel_Switch(false)
	end
end

function RaidGrid_CTM_Edition.OnFrameDragEnd()
	this:CorrectPos()
	RaidGrid_CTM_Edition.tAnchor = GetFrameAnchor(this)
end

function RaidGrid_CTM_Edition.UpdateAnchor(frame)
	local a = RaidGrid_CTM_Edition.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

function RaidGrid_CTM_Edition.SetPartyPanelPos(nIndex, nX, nY)
	local frameParty = RaidGrid_Party.GetPartyPanel(nIndex)
	if not frameParty then
		return
	end

	if not nX or not nY then
		frameParty:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	else
		frameParty:SetRelPos(nX, nY)
	end
end

function RaidGrid_CTM_Edition.GetLootModenQuality()
	local team = GetClientTeam()
	local player = GetClientPlayer()
	if not team or not player or not player.IsInParty() then
		return
	end
	return team.nLootMode, team.nRollQuality
end

function RaidGrid_CTM_Edition.UpdateLootImages()
	local nLootMode, nRollQuality = RaidGrid_CTM_Edition.GetLootModenQuality()
	local frame = RaidGrid_CTM_Edition.frameSelf
	for k, v in pairs(CTM_LOOT_MODE) do
		if nLootMode == v then
			frame:Lookup("", "Handle_BG"):Lookup(k):SetAlpha(255)
		else
			frame:Lookup("", "Handle_BG"):Lookup(k):SetAlpha(64)
		end
	end
	-- 世界标记
	if RaidGrid_CTM_Edition.IsLeader() then
		frame:Lookup("Btn_WorldMark"):Show()
	else
		frame:Lookup("Btn_WorldMark"):Hide()
	end
end
------------------------------------------------------------------------------------------------------------
function RaidGrid_CTM_Edition.OpenPanel()
	local frame = RaidGrid_CTM_Edition.frameSelf or Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "RaidGrid_CTM_Edition/ui/RaidGrid_CTM_Edition.ini", "RaidGrid_CTM_Edition")
	RaidGrid_CTM_Edition.frameSelf = frame
	JH.BreatheCall("CTM_BINDRGES", function()
		if RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.RedrawAllBuffBox then
			RaidGrid_EventScrutiny.RedrawAllBuffBox()
		end
	end, 256)
	return frame
end

function RaidGrid_CTM_Edition.ClosePanel()
	Wnd.CloseWindow(RaidGrid_CTM_Edition.frameSelf)
	JH.UnBreatheCall("CTM_BINDRGES")
	RaidGrid_CTM_Edition.frameSelf = nil
end

function RaidGrid_CTM_Edition.CloseAndOpenPanel()
	local frame = RaidGrid_CTM_Edition.frameSelf
	if frame then
		RaidGrid_CTM_Edition.ClosePanel()
		RaidGrid_CTM_Edition.bRaidEnable = false
	else
		RaidGrid_CTM_Edition.OpenPanel()
		RaidGrid_CTM_Edition.bRaidEnable = true
	end
end

RegisterEvent("LOGIN_GAME", RaidGrid_CTM_Edition.OpenPanel)
JH.AddHotKey("JH_CTM_Switch", "开启/关闭CTM团队面板", RaidGrid_CTM_Edition.CloseAndOpenPanel)
JH.AddHotKey("JH_CTM_Ready", g_tStrings.STR_RAID_READY_CONFIRM_START, RaidGrid_Party.InitReadyCheckCover)
