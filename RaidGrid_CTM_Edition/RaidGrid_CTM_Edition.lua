local _L = JH.LoadLangPack

RaidGrid_CTM_Edition = {
	bAltNeededForDrag = true,
	bRaidEnable = true,
	bShowInRaid = false,
	bShowSystemTeamPanel = false,
	tAnchor = {},
	nAutoLinkMode = 5,
	bShowAllPanel = false,
	bShowAllMemberGrid = false,
	nHPShownMode2 = 2,
	nHPShownNumMode = 1,
	nShowMP = false,
	bHPHitAlert = true,
	bColoredName = true,
	bColoredGrid = false,
	bShowIcon = 2,
	bShowDistance = false,
	bColorHPBarWithDistance = true,
	bShowTargetTargetAni = true,
	nFont = 40,
}
JH.RegisterCustomData("RaidGrid_CTM_Edition")

local CTM_COLOR = {
	[0] =  { 255, 255, 255 },
	[1] =  { 255, 255, 170 },
	[2] =  { 175, 25 , 255 },
	[3] =  { 250, 75 , 100 },
	[4] =  { 148, 178, 255 },
	[5] =  { 255, 125, 255 },
	[6] =  { 140, 80 , 255 },
	[7] =  { 0  , 128, 192 },
	[8] =  { 255, 200, 0   },
	[9] =  { 185, 125, 60  },
	[10] = { 240, 50 , 200 },
	[21] = { 180, 60 , 0   }
}
setmetatable(CTM_COLOR, { __index = function() return 168, 168, 168 end, __metatable = true })
function RaidGrid_CTM_Edition.GetForceColor(dwForceID) --获得成员颜色
	return unpack(CTM_COLOR[dwForceID])
end


local CTM_LOOT_MODE = {
	Image_LootMode_Free = PARTY_LOOT_MODE.FREE_FOR_ALL, 
	Image_LootMode_Looter = PARTY_LOOT_MODE.DISTRIBUTE, 
	Image_LootMode_Roll = PARTY_LOOT_MODE.GROUP_LOOT,
	Image_LootMode_Bidding = PARTY_LOOT_MODE.BIDDING,
}
local CTM_FRAME

local function RaidPanel_Switch(bOpen)
	local frame = Station.Lookup("Normal/RaidPanel_Main")
	if frame then
		if bOpen then
			frame:Show()
		else
			frame:Hide()
		end
	end
end

local function TeammatePanel_Switch(bOpen)
	local hFrame = Station.Lookup("Normal/Teammate")
	if hFrame then
		if bOpen then
			hFrame:Show()
		else
			hFrame:Hide()
		end
	end	
end

-------------------------------------------------
-- 界面创建 事件注册
-------------------------------------------------
function RaidGrid_CTM_Edition.OnFrameCreate()
	CTM_FRAME = this
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
		RaidGrid_CTM_Edition.UpdateLootImages()
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
		RaidGrid_Party.AutoLinkAllPanel()
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

function RaidGrid_CTM_Edition.OnLButtonDown()
	RaidGrid_Party.BringToTop()
end

function RaidGrid_CTM_Edition.OnItemLButtonClick()
	local szName = this:GetName()
	local team = GetClientTeam()
	local player = GetClientPlayer()
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) ~= player.dwID then
		return
	end
	if szName:match("Image_LootMode") then
		if not IsCtrlKeyDown() then
			return _L["Please hold down Ctrl, change it"]
		end
		team.SetTeamLootMode(CTM_LOOT_MODE[szName])
	end
end

function RaidGrid_CTM_Edition.OnFrameBreathe()
	local me = GetClientPlayer()
	if not me then return end
	
	RaidGrid_Party.RedrawAllFadeHP()
	RaidGrid_Party.UpdateMemberDistance()
	RaidGrid_Party.UpdateReadyCheckFade()
	-- kill System Panel
	RaidPanel_Switch(false)	
	TeammatePanel_Switch(false)
end

function RaidGrid_CTM_Edition.OnFrameDragEnd()
	this:CorrectPos()
	RaidGrid_CTM_Edition.tAnchor = GetFrameAnchor(this)
	RaidGrid_Party.AutoLinkAllPanel() -- fix screen pos
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
	local frame = CTM_FRAME
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
function RaidGrid_CTM_Edition.IsLeader()
	local hTeam = GetClientTeam()
	local hPlayer = GetClientPlayer()
	return hTeam.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) == hPlayer.dwID
end
local IsLeader = RaidGrid_CTM_Edition.IsLeader

function RaidGrid_CTM_Edition.PopOptions()
	local me = GetClientPlayer()
	local team = GetClientTeam()
	local dwDistribute = team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE)
	local menu = {}
	-- 团队就位
	table.insert(menu, { szOption = g_tStrings.STR_RAID_MENU_READY_CONFIRM, 
		{ szOption = g_tStrings.STR_RAID_READY_CONFIRM_START, bDisable = not IsLeader(), fnAction = RaidGrid_Party.InitReadyCheckCover },
		{ szOption = g_tStrings.STR_RAID_READY_CONFIRM_RESET, bDisable = not IsLeader(), fnAction = RaidGrid_Party.ClearReadyCheckCover }
	})
	table.insert(menu, { bDevide = true })
	-- 分配
	InsertDistributeMenu(menu, me.dwID ~= dwDistribute)
	table.insert(menu, { bDevide = true })
	-- 编辑模式
	table.insert(menu, { szOption = string.gsub(g_tStrings.STR_RAID_MENU_RAID_EDIT, "Ctrl", "Alt"), bDisable = not IsLeader() or not me.IsInRaid(), bCheck = true, bChecked = not RaidGrid_CTM_Edition.bAltNeededForDrag, fnAction = function() 
		RaidGrid_CTM_Edition.bAltNeededForDrag = not RaidGrid_CTM_Edition.bAltNeededForDrag
		GetPopupMenu():Hide()
	end })
	-- 治疗模式
	table.insert(menu, { szOption = g_tStrings.STR_RAID_TARGET_ASSIST, bCheck = true, bChecked = RaidGrid_Party.bTempTargetEnable, fnAction = function() RaidGrid_Party.bTempTargetEnable = not RaidGrid_Party.bTempTargetEnable end,
		{ szOption = _L["Don't show Tip in fight"], bCheck = true, bChecked = RaidGrid_Party.bTempTargetFightTip, fnDisable = function() return not RaidGrid_Party.bTempTargetEnable end, fnAction = function()
			RaidGrid_Party.bTempTargetFightTip = not RaidGrid_Party.bTempTargetFightTip
		end	}
	})
	table.insert(menu, { bDevide = true })
	-- 提醒窗体
	table.insert(menu, { szOption = g_tStrings.STR_RAID_TIP_IMAGE,
		{ szOption = g_tStrings.STR_RAID_TIP_TARGET, bCheck = true, bChecked = RaidGrid_CTM_Edition.bShowTargetTargetAni, fnAction = function()
			RaidGrid_CTM_Edition.bShowTargetTargetAni = not RaidGrid_CTM_Edition.bShowTargetTargetAni
			RaidGrid_Party.RedrawTargetSelectImage()
		end },
		{ szOption = _L["Show distance"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bShowDistance, fnAction = function()
			RaidGrid_CTM_Edition.bShowDistance = not RaidGrid_CTM_Edition.bShowDistance
			RaidGrid_Party.ReloadRaidPanel()
		end },
		{ szOption = _L["Attack Warning"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bHPHitAlert, fnAction = function()
			RaidGrid_CTM_Edition.bHPHitAlert = not RaidGrid_CTM_Edition.bHPHitAlert
			RaidGrid_Party.RedrawAllFadeHP(true)
		end }
	})
	table.insert(menu, { bDevide = true })
	table.insert(menu, { szOption = g_tStrings.STR_RAID_LIFE_SHOW,
		{ szOption = _L["LifeBar Gradient"], bCheck = true, bChecked = not RaidGrid_Party.Shadow.bLife, fnAction = function()
			RaidGrid_Party.Shadow.bLife = not RaidGrid_Party.Shadow.bLife
		end	},
		{ szOption = _L["ManaBar Gradient"], bCheck = true, bChecked = not RaidGrid_Party.Shadow.bMana, fnAction = function()
			RaidGrid_Party.Shadow.bMana = not RaidGrid_Party.Shadow.bMana
		end	},
		{ szOption = g_tStrings.STR_ALPHA, fnAction = function()
			local x, y = Cursor.GetPos()
			GetUserPercentage(function(val)
				RaidGrid_Party.Shadow.a = tonumber(val) * 255
				Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
			end, nil, RaidGrid_Party.Shadow.a / 255, g_tStrings.STR_ALPHA .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 })
		end	},
		{ bDevide = true },
		{ szOption = _L["Show ManaCount"], bCheck = true, bChecked = RaidGrid_CTM_Edition.nShowMP, fnAction = function()
			RaidGrid_CTM_Edition.nShowMP = not RaidGrid_CTM_Edition.nShowMP
			RaidGrid_Party.ReloadRaidPanel()
		end	},
		{ bDevide = true },
		{ szOption = g_tStrings.STR_RAID_LIFE_LEFT, bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownMode2 == 2, fnAction = function()
			RaidGrid_CTM_Edition.nHPShownMode2 = 2
			RaidGrid_Party.ReloadRaidPanel()
		end	},
		{ szOption = g_tStrings.STR_RAID_LIFE_LOSE, bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownMode2 == 1, fnAction = function()
			RaidGrid_CTM_Edition.nHPShownMode2 = 1
			RaidGrid_Party.ReloadRaidPanel()
		end	},
		{ szOption = g_tStrings.STR_RAID_LIFE_HIDE, bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownMode2 == 0, fnAction = function()
			RaidGrid_CTM_Edition.nHPShownMode2 = 0
			RaidGrid_Party.ReloadRaidPanel()
		end	},
		{ bDevide = true },
		{ szOption = _L["Show Format value"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownNumMode == 1, fnAction = function()
			RaidGrid_CTM_Edition.nHPShownNumMode = 1
			RaidGrid_Party.ReloadRaidPanel()
		end	},
		{ szOption = _L["Show Percentage value"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownNumMode == 2, fnAction = function()
			RaidGrid_CTM_Edition.nHPShownNumMode = 2
			RaidGrid_Party.ReloadRaidPanel()
		end	},
		{ szOption = _L["Show full value"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownNumMode == 3, fnAction = function()
			RaidGrid_CTM_Edition.nHPShownNumMode = 3
			RaidGrid_Party.ReloadRaidPanel()
		end	},
	})
	table.insert(menu, { szOption = _L["Icon & Color"],
		{ szOption = g_tStrings.STR_RAID_COLOR_NAME_SCHOOL, bCheck = true, bChecked = RaidGrid_CTM_Edition.bColoredName, fnAction = function()
			RaidGrid_CTM_Edition.bColoredName = not RaidGrid_CTM_Edition.bColoredName
			RaidGrid_Party.ReloadRaidPanel()
		end	},		
		{ szOption = _L["Border Color"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bColoredGrid, fnAction = function()
			RaidGrid_CTM_Edition.bColoredGrid = not RaidGrid_CTM_Edition.bColoredGrid
			RaidGrid_Party.ReloadRaidPanel()
		end	},
		{ bDevide = true },
		{ szOption = _L["Show Force Icon"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.bShowIcon == 1, fnAction = function()
			RaidGrid_CTM_Edition.bShowIcon = 1
			RaidGrid_Party.ReloadRaidPanel()
		end	},
		{ szOption = g_tStrings.STR_SHOW_KUNGFU, bMCheck = true, bChecked = RaidGrid_CTM_Edition.bShowIcon == 2, fnAction = function()
			RaidGrid_CTM_Edition.bShowIcon = 2
			RaidGrid_Party.ReloadRaidPanel()
		end	},
		{ szOption = _L["Show Camp Icon"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.bShowIcon == 3, fnAction = function()
			RaidGrid_CTM_Edition.bShowIcon = 3
			RaidGrid_Party.ReloadRaidPanel()
		end	},
	})
	
	local function GetDistTable(nIndex)
		local tabAllDist = {szOption = g_tStrings.STR_SKILL_H_CAST_MAX_DIS1 .. RaidGrid_Party.tDistanceLevel[nIndex],}
		if nIndex == 5 then
			tabAllDist.bDisable = true
		else
			for k = 4, 32 do
				local tabDist = {
					szOption = k .. g_tStrings.STR_METER, bMCheck = true, bChecked = RaidGrid_Party.tDistanceLevel[nIndex] == k, fnAction = function(UserData, bCheck)
						RaidGrid_Party.tDistanceLevel[nIndex] = k
					end,
				}
				table.insert(tabAllDist, tabDist)
			end
		end
		return tabAllDist, RaidGrid_Party.tDistanceLevel[nIndex]
	end
	local function GetColorTable(nIndex)
		local tColor = {
			{ szName = _L["Blue"], nLevel = 1, rgb = RaidGrid_Party.tDistanceColor[1] },
			{ szName = _L["Green"], nLevel = 2, rgb = RaidGrid_Party.tDistanceColor[2] },
			{ szName = _L["Yellow"], nLevel = 3, rgb = RaidGrid_Party.tDistanceColor[3] },
			{ szName = _L["Purple"], nLevel = 4, rgb = RaidGrid_Party.tDistanceColor[4] },
			{ szName = _L["Red"], nLevel = 5, rgb = RaidGrid_Party.tDistanceColor[5] },
			{ szName = _L["Gray"], nLevel = 6, rgb = RaidGrid_Party.tDistanceColor[6] },
			{ szName = _L["Gray"], nLevel = 7, rgb = RaidGrid_Party.tDistanceColor[7] },
			{ szName = _L["White"], nLevel = 8, rgb = RaidGrid_Party.tDistanceColor[8] },
		}
		local szNameC = tColor[RaidGrid_Party.tDistanceColorLevel[nIndex]].szName
		local nR, nG, nB = unpack(RaidGrid_Party.tDistanceColor[RaidGrid_Party.tDistanceColorLevel[nIndex]])
		local tabAllColor = { szOption = g_tStrings.BACK_COLOR .. g_tStrings.STR_COLON .. szNameC, rgb = { nR, nG, nB } }
		for k = 1, #tColor do
			local tabColor = {
				szOption = tColor[k].szName, bMCheck = true, bChecked = RaidGrid_Party.tDistanceColorLevel[nIndex] == tColor[k].nLevel, fnAction = function(UserData, bCheck)
					RaidGrid_Party.tDistanceColorLevel[nIndex] = k
				end,
				rgb = tColor[k].rgb
			}
			table.insert(tabAllColor, tabColor)
		end
		return tabAllColor, szNameC, nR, nG, nB 
	end
	local tDistanceMenu = { szOption = g_tStrings.STR_RAID_DISTANCE, bCheck = true, bChecked = RaidGrid_CTM_Edition.bColorHPBarWithDistance, fnAction = function() 
		RaidGrid_CTM_Edition.bColorHPBarWithDistance = not RaidGrid_CTM_Edition.bColorHPBarWithDistance
		RaidGrid_Party.ReloadRaidPanel() 
	end	}
	for j = 1, 5 do
		local tD, nDist = GetDistTable(j)
		local tC, szNameC, nR, nG, nB = GetColorTable(j)
		local szDist = tostring(nDist)
		szDist = ("_"):rep(3 - #szDist) .. szDist
		table.insert(tDistanceMenu, { szOption = szDist .. g_tStrings.STR_METER .. g_tStrings.STR_COLON .. szNameC, fnDisable = function() return not RaidGrid_CTM_Edition.bColorHPBarWithDistance end,tD, tC, rgb = { nR, nG, nB }} )
	end

	table.insert(menu, tDistanceMenu)
	table.insert(menu, { bDevide = true })
	table.insert(menu, { szOption = _L["Arrangement"],
		{ szOption = _L["One lines: 5/0"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 5, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 5
			RaidGrid_Party.ReloadRaidPanel()
		end },
		{ szOption = _L["Two lines: 1/4"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 1, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 1
			RaidGrid_Party.ReloadRaidPanel()
		end },
		{ szOption = _L["Two lines: 2/3"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 2, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 2
			RaidGrid_Party.ReloadRaidPanel()
		end },
		{ szOption = _L["Two lines: 3/2"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 3, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 3
			RaidGrid_Party.ReloadRaidPanel()
		end },
		{ szOption = _L["Two lines: 4/1"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 4, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 4
			RaidGrid_Party.ReloadRaidPanel()
		end },	
	})
	table.insert(menu, { szOption = g_tStrings.WINDOW_ADJUST_SCALE,
		{ szOption = _L["Restore Default"], bCheck = false, bChecked = false, fnAction = function()
			RaidGrid_Party.fScaleX = 1
			RaidGrid_Party.fScaleY = 1
			RaidGrid_CTM_Edition.nFont = 40
			RaidGrid_Party.fScaleIcon = 1
			RaidGrid_Party.fScaleShadowX = 1
			RaidGrid_Party.fScaleShadowY = 1
			RaidGrid_Party.ReloadRaidPanel()
		end },
		{ bDevide = true },
		{ szOption = _L["Interface Width"], fnAction = function()
			local x, y = Cursor.GetPos()
			local fScaleX = RaidGrid_Party.fScaleX
			GetUserPercentage(function(val)
				RaidGrid_Party.fScaleX = tonumber(val)
				RaidGrid_Party.ReloadRaidPanel()
				Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
			end, nil, (fScaleX - 0.5) / 1.00, _L["Interface Width"] .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 }, nil, { StartValue = 50, nStepCount = 100 })
		end	},
		{ szOption = _L["Interface Height"], fnAction = function()
			local x, y = Cursor.GetPos()
			local fScaleY = RaidGrid_Party.fScaleY
			GetUserPercentage(function(val)
				RaidGrid_Party.fScaleY = tonumber(val)
				RaidGrid_Party.ReloadRaidPanel()
				Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
			end, nil, (fScaleY - 0.5) / 1.00, _L["Interface Height"] .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 }, nil, { StartValue = 50, nStepCount = 100 })
		end },
		{ szOption = _L["Font Style"], fnAction = function()
			GUI.OpenFontTablePanel(function(nFont)
				RaidGrid_CTM_Edition.nFont = nFont
				RaidGrid_Party.ReloadRaidPanel()
			end)
		end },
		{ szOption = _L["Icon Size"], fnAction = function()
			local x, y = Cursor.GetPos()
			local fScaleIcon = RaidGrid_Party.fScaleIcon
			GetUserPercentage(function(val)
				RaidGrid_Party.fScaleIcon = tonumber(val)
				RaidGrid_Party.ReloadRaidPanel()
				Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
			end, nil, (fScaleIcon - 0.5) / 1.00, _L["Icon Size"] .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 }, nil, { StartValue = 50, nStepCount = 100 })
		end	},
		{ szOption = _L["Buff BG Width"], fnAction = function()
			local x, y = Cursor.GetPos()
			local fScaleShadowX = RaidGrid_Party.fScaleShadowX
			GetUserPercentage(function(val)
				RaidGrid_Party.fScaleShadowX = tonumber(val)
				RaidGrid_Party.ReloadRaidPanel()
				Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
			end, nil, (fScaleShadowX - 0.5) / 1.00, _L["Buff BG Width"] .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 }, nil, { StartValue = 50, nStepCount = 100 })
		end },
		{ szOption = _L["Buff BG Height"], fnAction = function()
			local x, y = Cursor.GetPos()
			local fScaleShadowY = RaidGrid_Party.fScaleShadowY
			GetUserPercentage(function(val)
				RaidGrid_Party.fScaleShadowY = tonumber(val)
				RaidGrid_Party.ReloadRaidPanel()
				Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
			end, nil, (fScaleShadowY - 0.5) / 1.00, _L["Buff BG Height"] .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 }, nil, { StartValue = 50, nStepCount = 100 })
		end },
	})
	table.insert(menu, { bDevide = true })
	table.insert(menu, { szOption = g_tStrings.OTHER,
		{ szOption = _L["Only in team"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bShowInRaid, fnAction = function(UserData, bCheck)
			RaidGrid_CTM_Edition.bShowInRaid = bCheck
			RaidGrid_CTM_Edition.CheckEnable()
			local me = GetClientPlayer()
			if me.IsInParty() and not me.IsInRaid() then
				FireEvent("CTM_PANEL_TEAMATE", RaidGrid_CTM_Edition.bShowInRaid)
			end
		end },	
	})
	-- 人数统计
	if me.IsInRaid() then
		table.insert(menu, { bDevide = true })
		RaidGrid_CTM_Edition.InsertForceCountMenu(menu)
	end
	local nX, nY = Cursor.GetPos(true)
	menu.x, menu.y = nX + 15, nY + 15
	PopupMenu(menu)
end
-- RaidGrid_CTM_Edition.bShowAllMemberGrid 
-- RaidGrid_CTM_Edition.bShowAllPanel
function RaidGrid_CTM_Edition.InsertForceCountMenu(tMenu)
	local tForceList = {}
	local hTeam = GetClientTeam()
	local nCount = 0
	for nGroupID = 0, hTeam.nGroupNum - 1 do
		local tGroupInfo = hTeam.GetGroupInfo(nGroupID)
		for _, dwMemberID in ipairs(tGroupInfo.MemberList) do
			local tMemberInfo = hTeam.GetMemberInfo(dwMemberID)
			if not tForceList[tMemberInfo.dwForceID] then
				tForceList[tMemberInfo.dwForceID] = 0
			end
			tForceList[tMemberInfo.dwForceID] = tForceList[tMemberInfo.dwForceID] + 1
		end
		nCount = nCount + #tGroupInfo.MemberList
	end
	local tSubMenu = { szOption = g_tStrings.STR_RAID_MENU_FORCE_COUNT ..
		FormatString(g_tStrings.STR_ALL_PARENTHESES, nCount)
	}
	for dwForceID, nCount in pairs(tForceList) do
		local szPath, nFrame = GetForceImage(dwForceID)
		table.insert(tSubMenu, { 
			szOption = g_tStrings.tForceTitle[dwForceID] .. "   " .. nCount,
			rgb = { JH.GetForceColor(dwForceID) },
			szIcon = szPath,
			nFrame = nFrame,
			szLayer = "ICON_LEFT"
		})
	end
	table.insert(tMenu, tSubMenu)
end

function RaidGrid_CTM_Edition.InsertChangeGroupMenu(tMenu, dwMemberID)
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

function RaidGrid_CTM_Edition.OutputTeamMemberTip(dwID, rc)	
	local hTeam = GetClientTeam()
	local tMemberInfo = hTeam.GetMemberInfo(dwID)
	if not tMemberInfo then
		return
	end
	local r, g, b = JH.GetForceColor(tMemberInfo.dwForceID)
	local szPath, nFrame = GetForceImage(tMemberInfo.dwForceID)
	local szTip = GetFormatImage(szPath, nFrame, 22, 22)
    szTip = szTip .. GetFormatText(FormatString(g_tStrings.STR_NAME_PLAYER, tMemberInfo.szName), 80, r, g, b)
    if tMemberInfo.bIsOnLine then
    	szTip = szTip .. GetFormatText(FormatString(g_tStrings.STR_PLAYER_H_WHAT_LEVEL, tMemberInfo.nLevel), 82)
		local szMapName = Table_GetMapName(tMemberInfo.dwMapID)
		if szMapName then
			szTip = szTip .. GetFormatText(szMapName .. "\n", 82)
		end
        
        local nCamp = tMemberInfo.nCamp
        szTip = szTip .. GetFormatText(g_tStrings.STR_GUILD_CAMP_NAME[nCamp] .. "\n", 82)
    else
    	szTip = szTip .. GetFormatText(g_tStrings.STR_FRIEND_NOT_ON_LINE .. "\n", 82, 128, 128, 128)
    end
    if IsCtrlKeyDown() then
    	szTip = szTip .. GetFormatText(FormatString(g_tStrings.TIP_PLAYER_ID, dwID), 102)
    end	
    OutputTip(szTip, 345, rc)
end

function RaidGrid_CTM_Edition.OpenRaidDragPanel(dwMemberID)
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
	hFrame:BringToTop()
end

function RaidGrid_CTM_Edition.CloseRaidDragPanel()
	local hFrame = Station.Lookup("Normal/RaidDragPanel")
	if hFrame then
		hFrame:EndMoving()
		Wnd.CloseWindow(hFrame)
	end
end

function RaidGrid_CTM_Edition.EditBox_AppendLinkPlayer(szName)
	local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
	edit:InsertObj("[" .. szName .. "]", { type = "name", text = "[" .. szName .. "]", name = szName})
	Station.SetFocusWindow(edit)
end
------------------------------------------------------------------------------------------------------------
function RaidGrid_CTM_Edition.OpenPanel()
	local frame = CTM_FRAME or Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "RaidGrid_CTM_Edition/ui/RaidGrid_CTM_Edition.ini", "RaidGrid_CTM_Edition")
	JH.BreatheCall("CTM_BINDRGES", function()
		if RaidGrid_EventScrutiny and RaidGrid_EventScrutiny.RedrawAllBuffBox then
			RaidGrid_EventScrutiny.RedrawAllBuffBox()
		end
	end, 256)
	return frame
end

function RaidGrid_CTM_Edition.CheckEnable()
	if not RaidGrid_CTM_Edition.bRaidEnable then
		return RaidGrid_CTM_Edition.ClosePanel()
	end
	if RaidGrid_CTM_Edition.bShowInRaid and not RaidGrid_Party.IsInRaid() then
		return RaidGrid_CTM_Edition.ClosePanel()
	end
	return RaidGrid_CTM_Edition.OpenPanel()
end

function RaidGrid_CTM_Edition.ClosePanel()
	if CTM_FRAME then Wnd.CloseWindow(CTM_FRAME) end
	JH.UnBreatheCall("CTM_BINDRGES")
	for i = 0, 4 do
		if Station.Lookup("Normal/RaidGrid_Party_" .. i) then
			Wnd.CloseWindow(Station.Lookup("Normal/RaidGrid_Party_" .. i))
		end
	end
	CTM_FRAME = nil
end

function RaidGrid_CTM_Edition.Switch()
	local me = GetClientPlayer()
	if CTM_FRAME then
		if me.IsInParty() then
			CTM_FRAME:Show()
		else
			CTM_FRAME:Hide()
		end
	end
end

RegisterEvent("LOGIN_GAME", RaidGrid_CTM_Edition.OpenPanel)
RegisterEvent("FIRST_LOADING_END", RaidGrid_CTM_Edition.CheckEnable)
RegisterEvent("CTM_PANEL_RAID", function()
	RaidPanel_Switch(arg0)
end)
RegisterEvent("CTM_PANEL_TEAMATE", function()
	TeammatePanel_Switch(arg0)
end)

JH.AddonMenu(function()
	return {
		szOption = _L["CTM Team Panel"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bRaidEnable and not RaidGrid_CTM_Edition.bShowInRaid, fnAction = function()
			RaidGrid_CTM_Edition.bRaidEnable = not RaidGrid_CTM_Edition.bRaidEnable
			RaidGrid_CTM_Edition.bShowInRaid = false
			RaidGrid_CTM_Edition.CheckEnable()
			RaidGrid_CTM_Edition.Switch()
			FireEvent("CTM_PANEL_RAID", not RaidGrid_CTM_Edition.bRaidEnable)
		end
	}
end)