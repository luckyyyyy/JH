RaidGrid_CTM_Edition = RaidGrid_CTM_Edition or {}
RaidGrid_CTM_Edition.nSteper = -1
RaidGrid_CTM_Edition.frameSelf = nil

RaidGrid_CTM_Edition.bIsSynKungfu = false
RaidGrid_CTM_Edition.tLastLoc = {nX = 0, nY = 0};		RegisterCustomData("RaidGrid_CTM_Edition.tLastLoc")
RaidGrid_CTM_Edition.tLastPartyPanelLoc = {
	{nX = 0, nY = 0}, {nX = 0, nY = 0}, {nX = 0, nY = 0}, {nX = 0, nY = 0}, {nX = 0, nY = 0}
};														RegisterCustomData("RaidGrid_CTM_Edition.tLastPartyPanelLoc")

function RaidGrid_CTM_Edition.OnFrameCreate()
	this:RegisterEvent("RENDER_FRAME_UPDATE")

	this:RegisterEvent("PARTY_UPDATE_BASE_INFO")
	this:RegisterEvent("PARTY_SYNC_MEMBER_DATA")
	this:RegisterEvent("PARTY_ADD_MEMBER")
	this:RegisterEvent("PARTY_DISBAND")
	this:RegisterEvent("PARTY_DELETE_MEMBER")
	this:RegisterEvent("PARTY_UPDATE_MEMBER_INFO")
	this:RegisterEvent("PARTY_UPDATE_MEMBER_LMR")
	this:RegisterEvent("PARTY_SET_MEMBER_ONLINE_FLAG")
	this:RegisterEvent("PLAYER_STATE_UPDATE")
	this:RegisterEvent("UPDATE_PLAYER_SCHOOL_ID")
	this:RegisterEvent("RIAD_READY_CONFIRM_RECEIVE_ANSWER")
	this:RegisterEvent("UI_SCALED")
	
	this:RegisterEvent("PARTY_SET_MARK")
	
	this:RegisterEvent("TEAM_AUTHORITY_CHANGED")
	this:RegisterEvent("PARTY_SET_FORMATION_LEADER")
	
	this:RegisterEvent("PARTY_LOOT_MODE_CHANGED")
	this:RegisterEvent("LOADING_END")
end

function RaidGrid_CTM_Edition.OnCustomDataLoaded()
	if arg0 ~= "Role" then
		return
	end	
	if RaidGrid_CTM_Edition.tLastLoc.nX == 0 and RaidGrid_CTM_Edition.tLastLoc.nY == 0 then
		RaidGrid_CTM_Edition.SetPanelPos()
	elseif RaidGrid_CTM_Edition.frameSelf then
		RaidGrid_CTM_Edition.SetPanelPos(RaidGrid_CTM_Edition.tLastLoc.nX, RaidGrid_CTM_Edition.tLastLoc.nY)
	end
end

function RaidGrid_CTM_Edition.OnEvent(szEvent)
	local player = GetClientPlayer()
	if not player then
		return
	end
	if szEvent == "RENDER_FRAME_UPDATE" then
		if RaidGrid_CTM_Edition.bAutoLinkAllPanel then
			local nX, nY = RaidGrid_CTM_Edition.frameSelf:GetRelPos()
			if RaidGrid_CTM_Edition.tLastLoc.nX ~= nX or RaidGrid_CTM_Edition.tLastLoc.nY ~= nY then
				RaidGrid_Party.AutoLinkAllPanel()
			end
		end
	elseif szEvent == "PARTY_SYNC_MEMBER_DATA" then		-- dwTeamID:arg0, dwMemberID:arg1, nGroupIndex:arg2
		RaidGrid_Party.OnAddOrDeleteMember(arg1, arg2)
		RaidGrid_Party.RedrawHandleRoleHPnMP(arg1)
		RaidGrid_Party.RedrawHandleRoleInfo(arg1)
		RaidGrid_Party.RedrawHandleRoleInfoEx(arg1)
		if RaidGrid_CTM_Edition.bAutoLinkAllPanel then
			RaidGrid_Party.AutoLinkAllPanel()
		end
	elseif szEvent == "PARTY_ADD_MEMBER" then			-- dwTeamID:arg0, dwMemberID:arg1, nGroupIndex:arg2
		RaidGrid_Party.OnAddOrDeleteMember(arg1, arg2)
		RaidGrid_Party.RedrawHandleRoleHPnMP(arg1)
		RaidGrid_Party.RedrawHandleRoleInfo(arg1)
		RaidGrid_Party.RedrawHandleRoleInfoEx(arg1)
		if RaidGrid_CTM_Edition.bAutoLinkAllPanel then
			RaidGrid_Party.AutoLinkAllPanel()
		end
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
		if player.IsPlayerInMyParty(arg0) then
			RaidGrid_Party.RedrawHandleRoleInfo(arg0)
			RaidGrid_Party.RedrawHandleRoleInfoEx(arg0)
		end
	elseif szEvent == "PLAYER_STATE_UPDATE" then
		if player.IsPlayerInMyParty(arg0) then
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
	elseif szEvent == "LOADING_END" or szEvent == "PARTY_UPDATE_BASE_INFO" or szEvent == "PARTY_LOOT_MODE_CHANGED" then
		RaidGrid_CTM_Edition.UpdateLootImages()
	end
end

------------------------------------------------------------------------------------------------------------
function RaidGrid_CTM_Edition.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Option" then
		RaidGrid_CTM_Edition.PopOptions()
	elseif szName == "Btn_WorldMark" then
		Wnd.ToggleWindow("WorldMark")
	end
end

local tLootMode = {
	Image_LootMode_Free = PARTY_LOOT_MODE.FREE_FOR_ALL, 
	Image_LootMode_Looter = PARTY_LOOT_MODE.DISTRIBUTE, 
	Image_LootMode_Roll = PARTY_LOOT_MODE.GROUP_LOOT,
	Image_LootMode_Bidding = PARTY_LOOT_MODE.BIDDING,
}
function RaidGrid_CTM_Edition.OnItemLButtonClick()
	local szName = this:GetName()
	local team = GetClientTeam()
	local player = GetClientPlayer()
	if IsCtrlKeyDown() or not szName:match("Image_Loot") or not team or not player.IsInParty() or team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) ~= player.dwID then
		return
	end
	
	if szName:match("Image_LootMode") then
		team.SetTeamLootMode(tLootMode[szName])
	end

end

function RaidGrid_CTM_Edition.OnItemMouseEnter()
end

function RaidGrid_CTM_Edition.OnItemMouseLeave()
end

function RaidGrid_CTM_Edition.OnFrameBreathe()
	RaidGrid_CTM_Edition.nSteper = RaidGrid_CTM_Edition.nSteper + 1
	local player = GetClientPlayer()
	if not player then
		return
	end
	
	RaidGrid_Party.RedrawAllFadeHP()
	RaidGrid_Party.UpdateMemberDistance()
	RaidGrid_Party.UpdateReadyCheckFade()
	RaidGrid_Party.RedrawTargetSelectImage()
	if RaidGrid_CTM_Edition.nSteper % 4 == 0 then		
		if RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.RedrawAllBuffBox then
			RaidGrid_EventScrutiny.RedrawAllBuffBox()
		end
	end
	
	if IsShiftKeyDown() and not RaidGrid_CTM_Edition.bAutoLinkAllPanel then
		for i = 0, 4 do
			local framePartyPanel = RaidGrid_Party.GetPartyPanel(i)
			if framePartyPanel then
				framePartyPanel:SetDragArea(0, 0, 85, 315)
				RaidGrid_CTM_Edition.tLastPartyPanelLoc[i+1].nX, RaidGrid_CTM_Edition.tLastPartyPanelLoc[i+1].nY = framePartyPanel:GetRelPos()
			end
		end
	else
		for i = 0, 4 do
			local framePartyPanel = RaidGrid_Party.GetPartyPanel(i)
			if framePartyPanel then
				framePartyPanel:SetDragArea(0, 0, 0, 0)
				RaidGrid_CTM_Edition.tLastPartyPanelLoc[i+1].nX, RaidGrid_CTM_Edition.tLastPartyPanelLoc[i+1].nY = framePartyPanel:GetRelPos()
			end
		end
	end
	
	if RaidGrid_Party.bDrag and not IsKeyDown("LButton") then
		RaidGrid_CTM_Edition.bShowAllMemberGrid = bLastShowAllMemberGrid
		RaidGrid_Party.bDrag = false
		nDragGroupID = nil
		dwDragMemberID = nil
		RaidGrid_CTM_Edition.CloseRaidDragPanel()
		RaidGrid_Party.ReloadRaidPanel()
	end
	
	if not RaidGrid_CTM_Edition.bShowSystemRaidPanel then
		RaidGrid_CTM_Edition.RaidPanel_Switch(false)
	end
	
	if RaidGrid_CTM_Edition.bShowSystemTeamPanel then
		RaidGrid_CTM_Edition.TeammatePanel_Switch(true)
	elseif RaidGrid_CTM_Edition.bShowRaid then
		RaidGrid_CTM_Edition.TeammatePanel_Switch(false)
	end
	
	RaidGrid_CTM_Edition.tLastLoc.nX, RaidGrid_CTM_Edition.tLastLoc.nY = RaidGrid_CTM_Edition.frameSelf:GetRelPos()
end

function RaidGrid_CTM_Edition.SetPanelPos(nX, nY)
	if not nX or not nY then
		RaidGrid_CTM_Edition.frameSelf:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	else
		local nW, nH = Station.GetClientSize(true)
		if nX < 0 then nX = 0 end
		if nX > nW - 50 then nX = nW - 50 end
		if nY < 0 then nY = 0 end
		if nY > nH - 50 then nY = nH - 50 end
		RaidGrid_CTM_Edition.frameSelf:SetRelPos(nX, nY)
	end
	RaidGrid_CTM_Edition.tLastLoc.nX, RaidGrid_CTM_Edition.tLastLoc.nY = RaidGrid_CTM_Edition.frameSelf:GetRelPos()
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
	RaidGrid_CTM_Edition.tLastPartyPanelLoc[nIndex+1].nX, RaidGrid_CTM_Edition.tLastPartyPanelLoc[nIndex+1].nY = frameParty:GetRelPos()
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
	local team = GetClientTeam()
	local player = GetClientPlayer()
	local nLootMode, nRollQuality = RaidGrid_CTM_Edition.GetLootModenQuality()
	if not nLootMode or not team or not player.IsInParty() then
		nLootMode, nRollQuality = -1, -1
	end

	for i = 1, #RaidGrid_CTM_Edition.tLootModeImage do
		if nLootMode == i then
			RaidGrid_CTM_Edition.tLootModeImage[i]:SetAlpha(255)
		else
			RaidGrid_CTM_Edition.tLootModeImage[i]:SetAlpha(64)
		end
	end
end
------------------------------------------------------------------------------------------------------------
function RaidGrid_CTM_Edition.OpenPanel()
	local frame = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	if not frame then
		frame = Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "RaidGrid_CTM_Edition/RaidGrid_CTM_Edition.ini", "RaidGrid_CTM_Edition")
	end

	RaidGrid_CTM_Edition.frameSelf = frame
	RaidGrid_CTM_Edition.handleMain = frame:Lookup("", "")
	RaidGrid_CTM_Edition.handleBG = frame:Lookup("", "Handle_BG")
	RaidGrid_CTM_Edition.tLootModeImage = {
		RaidGrid_CTM_Edition.handleBG:Lookup("Image_LootMode_Free"),
		RaidGrid_CTM_Edition.handleBG:Lookup("Image_LootMode_Looter"),
		RaidGrid_CTM_Edition.handleBG:Lookup("Image_LootMode_Roll"),
		RaidGrid_CTM_Edition.handleBG:Lookup("Image_LootMode_Bidding"),
	}
end

function RaidGrid_CTM_Edition.ShowPanel()
	local frame = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	if frame then
		frame:Show()
	end
end

function RaidGrid_CTM_Edition.ClosePanel()
	local frame = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	if frame then
		frame:Hide()
	end
end

function RaidGrid_CTM_Edition.CloseAndOpenPanel()
	local frame = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	if frame then
		if frame:IsVisible() then
			frame:Hide()
			RaidGrid_CTM_Edition.bRaidEnable = false
		else
			frame:Show()
			RaidGrid_CTM_Edition.bRaidEnable = true
		end
	else
		RaidGrid_CTM_Edition.OpenPanel()
		RaidGrid_CTM_Edition.bRaidEnable = true
	end
end

function RaidGrid_CTM_Edition.IsOpened()
	local frame = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	if frame then
		return frame:IsVisible()
	end
end

RaidGrid_CTM_Edition.OpenPanel()
RegisterEvent("PARTY_LEVEL_UP_RAID", RaidGrid_Party.ReloadRaidPanel)
RegisterEvent("CUSTOM_DATA_LOADED", RaidGrid_CTM_Edition.OnCustomDataLoaded)
RegisterEvent("SYNC_ROLE_DATA_END", RaidGrid_Party.ReloadRaidPanel)
RegisterEvent("PARTY_UPDATE_BASE_INFO", RaidGrid_Party.ReloadRaidPanel)
RegisterEvent("TEAM_CHANGE_MEMBER_GROUP", RaidGrid_Party.ReloadRaidPanel)


JH.AddHotKey("JH_CTM_Switch","开启/关闭CTM团队面板",function()
	RaidGrid_CTM_Edition.CloseAndOpenPanel()
	if RaidGrid_CTM_Edition.bAutoHideCTM then
		if RaidGrid_CTM_Edition.bShowInRaid and RaidGrid_Party.IsInRaid() then
			RaidGrid_Party.ReloadRaidPanel()
		end
		if not RaidGrid_CTM_Edition.bShowInRaid and GetClientPlayer().IsInParty() then
			RaidGrid_Party.ReloadRaidPanel()
		end
	else
		RaidGrid_Party.ReloadRaidPanel()
	end
end)
JH.AddHotKey("JH_CTM_Ready", "发布团队你就位确认", RaidGrid_Party.InitReadyCheckCover)
JH.AddHotKey("JH_CTM_ResetPos","重置CTM面板位置",function()
	RaidGrid_CTM_Edition.SetPanelPos()
	if RaidGrid_CTM_Edition.bAutoLinkAllPanel then
		RaidGrid_Party.AutoLinkAllPanel()
	end
end)