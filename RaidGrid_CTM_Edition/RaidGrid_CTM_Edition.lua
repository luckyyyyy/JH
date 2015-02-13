RaidGrid_CTM_Edition = RaidGrid_CTM_Edition or {}
RaidGrid_CTM_Edition.frameSelf = nil

local CTM_X, CTM_Y = 0, 0

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
	this:RegisterEvent("TARGET_CHANGE")
end

function RaidGrid_CTM_Edition.OnEvent(szEvent)
	if szEvent == "RENDER_FRAME_UPDATE" then
		local me = GetClientPlayer()
		if not me then return end
		local nX, nY = RaidGrid_CTM_Edition.frameSelf:GetRelPos()
		if CTM_X ~= nX or CTM_Y ~= nY then
			RaidGrid_Party.AutoLinkAllPanel()
		end
	elseif szEvent == "PARTY_SYNC_MEMBER_DATA" then		-- dwTeamID:arg0, dwMemberID:arg1, nGroupIndex:arg2
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
	elseif szEvent == "LOADING_END" or szEvent == "PARTY_UPDATE_BASE_INFO" or szEvent == "PARTY_LOOT_MODE_CHANGED" then
		RaidGrid_CTM_Edition.UpdateLootImages()
	elseif szEvent == "TARGET_CHANGE" then
		RaidGrid_Party.RedrawTargetSelectImage()
	elseif szEvent == "UI_SCALED" then
		RaidGrid_CTM_Edition.UpdateAnchor(this)
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
	CTM_X, CTM_Y = RaidGrid_CTM_Edition.frameSelf:GetRelPos()
end

function RaidGrid_CTM_Edition.OnFrameDragEnd()
	this:CorrectPos()
	RaidGrid_CTM_Edition.tAnchor = GetFrameAnchor(this)
	RaidGrid_Party.AutoLinkAllPanel()
end

function RaidGrid_CTM_Edition.UpdateAnchor(frame)
	local a = RaidGrid_CTM_Edition.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

JH.BreatheCall("CTM_RGES", function()
	if RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.RedrawAllBuffBox then
		RaidGrid_EventScrutiny.RedrawAllBuffBox()
	end
end, 256)

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
	local frame = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	if RaidGrid_CTM_Edition.IsLeader() then
		frame:Lookup("Btn_WorldMark"):Show()
	else
		frame:Lookup("Btn_WorldMark"):Hide()
	end
end
------------------------------------------------------------------------------------------------------------
function RaidGrid_CTM_Edition.OpenPanel()
	local frame = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	if not frame then
		frame = Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "RaidGrid_CTM_Edition/ui/RaidGrid_CTM_Edition.ini", "RaidGrid_CTM_Edition")
	end

	RaidGrid_CTM_Edition.frameSelf = frame
	local handleBG = frame:Lookup("", "Handle_BG")
	RaidGrid_CTM_Edition.tLootModeImage = {
		handleBG:Lookup("Image_LootMode_Free"),
		handleBG:Lookup("Image_LootMode_Looter"),
		handleBG:Lookup("Image_LootMode_Roll"),
		handleBG:Lookup("Image_LootMode_Bidding"),
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

RegisterEvent("LOGIN_GAME", RaidGrid_CTM_Edition.OpenPanel)
RegisterEvent("PARTY_LEVEL_UP_RAID", RaidGrid_Party.ReloadRaidPanel)
RegisterEvent("SYNC_ROLE_DATA_END", RaidGrid_Party.ReloadRaidPanel)
RegisterEvent("PARTY_UPDATE_BASE_INFO", RaidGrid_Party.ReloadRaidPanel)
RegisterEvent("TEAM_CHANGE_MEMBER_GROUP", RaidGrid_Party.ReloadRaidPanel)


JH.AddHotKey("JH_CTM_Switch","开启/关闭CTM团队面板",function()
	RaidGrid_CTM_Edition.CloseAndOpenPanel()
	if RaidGrid_CTM_Edition.bShowInRaid and RaidGrid_Party.IsInRaid() then
		RaidGrid_Party.ReloadRaidPanel()
	end
	if not RaidGrid_CTM_Edition.bShowInRaid and GetClientPlayer().IsInParty() then
		RaidGrid_Party.ReloadRaidPanel()
	end
end)
JH.AddHotKey("JH_CTM_Ready", g_tStrings.STR_RAID_READY_CONFIRM_START, RaidGrid_Party.InitReadyCheckCover)