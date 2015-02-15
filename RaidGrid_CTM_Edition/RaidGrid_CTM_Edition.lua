local _L = JH.LoadLangPack

local CTM_CONFIG = {
	bRaidEnable = true,
	bShowInRaid = false,
	bEditMode = false,
	tAnchor = {},
	nAutoLinkMode = 5,
	nHPShownMode2 = 2,
	nHPShownNumMode = 1,
	nShowMP = false,
	bHPHitAlert = true,
	bColoredName = true,
	bColoredGrid = false,
	bShowIcon = 2,
	bShowDistance = false,
	bColorHPBarWithDistance = true,
	bShowTargetTargetAni = false,
	nFont = 40,
	bLifeGradient = true,
	bManaGradient = true,
	nAlpha = 255,
	bTempTargetFightTip = true,
	bTempTargetEnable = true,
	--
	fScaleX = 1,
	fScaleY = 1,
	tDistanceLevel = { 8, 20, 22, 24, 999 },
	tDistanceCol = {
		{ 0,   180, 52  }, -- 绿
		{ 0,   180, 52  }, -- 绿
		{ 230, 170, 40  }, -- 黄
		{ 230, 80,  80  }, -- 红
		{ 230, 80,  80  }, -- 红
	},
	tOtherCol = {
		{ 255, 255, 255 },
		{ 128, 128, 128 },
		{ 192, 192, 192 }
	},
	bFasterHP = false,
}
local CTM_CONFIG_PLAYER = JH.LoadLUAData("CTM/Config_V1.jx3dat") or CTM_CONFIG

RaidGrid_CTM_Edition = {}

local CTM_FRAME
local CTM_LOOT_MODE = {
	Image_LootMode_Free    = PARTY_LOOT_MODE.FREE_FOR_ALL, 
	Image_LootMode_Looter  = PARTY_LOOT_MODE.DISTRIBUTE, 
	Image_LootMode_Roll    = PARTY_LOOT_MODE.GROUP_LOOT,
	Image_LootMode_Bidding = PARTY_LOOT_MODE.BIDDING,
}

local function GetLootModenQuality()
	local team = GetClientTeam()
	local player = GetClientPlayer()
	if not team or not player or not player.IsInParty() then
		return
	end
	return team.nLootMode, team.nRollQuality
end

local function UpdateLootImages()
	local nLootMode, nRollQuality = GetLootModenQuality()
	local frame = CTM_FRAME
	for k, v in pairs(CTM_LOOT_MODE) do
		if nLootMode == v then
			frame:Lookup("", "Handle_BG"):Lookup(k):SetAlpha(255)
		else
			frame:Lookup("", "Handle_BG"):Lookup(k):SetAlpha(64)
		end
	end
	-- 世界标记
	if JH.IsLeader() then
		frame:Lookup("Btn_WorldMark"):Show()
	else
		frame:Lookup("Btn_WorldMark"):Hide()
	end
end

local function InsertForceCountMenu(tMenu)
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
------------------------------------------------------------------------------------------------------------
local function RaidOpenPanel()
	local frame = CTM_FRAME or Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "RaidGrid_CTM_Edition/ui/RaidGrid_CTM_Edition.ini", "RaidGrid_CTM_Edition")
	return frame
end
local function RaidClosePanel()
	if CTM_FRAME then
		Wnd.CloseWindow(CTM_FRAME)
		Raid_CTM:CloseParty()
		CTM_FRAME = nil
	end
end

local function RaidCheckEnable()
	local me = GetClientPlayer()
	if not RaidGrid_CTM_Edition.bRaidEnable then
		return RaidClosePanel()
	end
	if RaidGrid_CTM_Edition.bShowInRaid and not me.IsInRaid() then
		return RaidClosePanel()
	end
	if not me.IsInParty() then
		return RaidClosePanel()
	end
	RaidOpenPanel()
	UpdateLootImages()
	Raid_CTM:ReloadParty()
end

local function UpdateAnchor(frame)
	local a = RaidGrid_CTM_Edition.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

-------------------------------------------------
-- 界面创建 事件注册
-------------------------------------------------
function RaidGrid_CTM_Edition.OnFrameCreate()
	CTM_FRAME = this
	
	if RaidGrid_CTM_Edition.bFasterHP then
		this:RegisterEvent("RENDER_FRAME_UPDATE")
	end
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
	-- this:RegisterEvent("RIAD_READY_CONFIRM_RECEIVE_QUESTION")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("PARTY_SET_MARK")
	this:RegisterEvent("TEAM_AUTHORITY_CHANGED")
	this:RegisterEvent("TEAM_CHANGE_MEMBER_GROUP")
	this:RegisterEvent("PARTY_SET_FORMATION_LEADER")
	this:RegisterEvent("PARTY_LOOT_MODE_CHANGED")
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("CTM_LOADING_END")
	this:RegisterEvent("JH_RAID_REC_BUFF")
	this:RegisterEvent("TARGET_CHANGE")
	if GetClientPlayer() then
		FireEvent("CTM_LOADING_END")
	end
end
-------------------------------------------------
-- 拖动窗体
-------------------------------------------------
function RaidGrid_CTM_Edition.OnFrameDrag() -- 救命小天使
	Raid_CTM:AutoLinkAllPanel()
end
-------------------------------------------------
-- 事件处理
-------------------------------------------------
function RaidGrid_CTM_Edition.OnEvent(szEvent)
	if szEvent == "RENDER_FRAME_UPDATE" then
		Raid_CTM:CallDrawHPMP(true)
	elseif szEvent == "PARTY_SYNC_MEMBER_DATA" then -- ??
		Raid_CTM:CallRefreshImages(arg1, true, true, nil, true, true)
	elseif szEvent == "PARTY_ADD_MEMBER" then
		Raid_CTM:CreatePanel(arg2)
		Raid_CTM:DrawParty(arg2)
	elseif szEvent == "PARTY_DELETE_MEMBER" then
		local me = GetClientPlayer()
		if me.dwID == arg1 then
			return RaidClosePanel()
		end
		local team = GetClientTeam()
		local tGropu = team.GetGroupInfo(arg3)
		if #tGropu.MemberList == 0 then
			Raid_CTM:CloseParty(arg3)
			Raid_CTM:AutoLinkAllPanel()
		else
			Raid_CTM:DrawParty(arg3)
		end
	elseif szEvent == "PARTY_DISBAND" then
		RaidClosePanel()
	elseif szEvent == "PARTY_UPDATE_MEMBER_LMR" then
		Raid_CTM:CallDrawHPMP(arg1, true)
	elseif szEvent == "PARTY_UPDATE_MEMBER_INFO" then
		Raid_CTM:CallRefreshImages(arg1, false, true, nil, true, true)
		Raid_CTM:CallDrawHPMP(arg1, true)
	elseif szEvent == "UPDATE_PLAYER_SCHOOL_ID" then
		if JH.IsParty(arg0) then
			Raid_CTM:CallRefreshImages(arg0, false, true)
		end
	elseif szEvent == "PLAYER_STATE_UPDATE" then
		if JH.IsParty(arg0) then
			Raid_CTM:CallDrawHPMP(arg1, true)
		end
	elseif szEvent == "PARTY_SET_MEMBER_ONLINE_FLAG" then
		Raid_CTM:CallDrawHPMP(arg1, true)
	elseif szEvent == "TEAM_AUTHORITY_CHANGED" then
		Raid_CTM:CallRefreshImages(arg2, true)
		Raid_CTM:CallRefreshImages(arg3, true)
		UpdateLootImages()
	elseif szEvent == "PARTY_SET_FORMATION_LEADER" then
		Raid_CTM:RefresFormation()
	elseif szEvent == "PARTY_SET_MARK" then
		Raid_CTM:RefreshMark()
	-- elseif szEvent == "RIAD_READY_CONFIRM_RECEIVE_QUESTION" then
	elseif szEvent == "RIAD_READY_CONFIRM_RECEIVE_ANSWER" then
		Raid_CTM:ChangeReadyConfirm(arg0, arg1)
	elseif szEvent == "TEAM_CHANGE_MEMBER_GROUP" then
		Raid_CTM:ReloadParty()	
	elseif szEvent == "PARTY_LEVEL_UP_RAID" then
		Raid_CTM:ReloadParty()
	elseif szEvent == "PARTY_LOOT_MODE_CHANGED" then
		UpdateLootImages()
	elseif szEvent == "TARGET_CHANGE" then
		Raid_CTM:RefreshTarget()
	elseif szEvent == "JH_RAID_REC_BUFF" then
		Raid_CTM:RecBuff(arg0, arg1, arg2, arg3)
	elseif szEvent == "UI_SCALED" or "CTM_LOADING_END" then
		UpdateAnchor(this)
		Raid_CTM:AutoLinkAllPanel()
	end
	
end
--[[
/ FireEvent("JH_RAID_REC_BUFF", UI_GetClientPlayerID(), 103, 1, { 255, 255, 255 })
]]
-------------------------------------------------
-- 菜单和世界标记
-------------------------------------------------
function RaidGrid_CTM_Edition.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Option" then
		local me = GetClientPlayer()
		local team = GetClientTeam()
		local dwDistribute = team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE)
		local menu = {}
		-- 团队就位
		table.insert(menu, { szOption = g_tStrings.STR_RAID_MENU_READY_CONFIRM, 
			{ szOption = g_tStrings.STR_RAID_READY_CONFIRM_START, bDisable = not JH.IsLeader() or not me.IsInRaid(), fnAction = function() Raid_CTM:Send_RaidReadyConfirm() end },
			{ szOption = g_tStrings.STR_RAID_READY_CONFIRM_RESET, bDisable = not JH.IsLeader() or not me.IsInRaid(), fnAction = function() Raid_CTM:Clear_RaidReadyConfirm() end }
		})
		table.insert(menu, { bDevide = true })
		-- 分配
		InsertDistributeMenu(menu, me.dwID ~= dwDistribute)
		table.insert(menu, { bDevide = true })
		-- 编辑模式
		table.insert(menu, { szOption = string.gsub(g_tStrings.STR_RAID_MENU_RAID_EDIT, "Ctrl", "Alt"), bDisable = not JH.IsLeader() or not me.IsInRaid(), bCheck = true, bChecked = RaidGrid_CTM_Edition.bEditMode, fnAction = function() 
			RaidGrid_CTM_Edition.bEditMode = not RaidGrid_CTM_Edition.bEditMode
			GetPopupMenu():Hide()
		end })
		-- 治疗模式
		table.insert(menu, { szOption = g_tStrings.STR_RAID_TARGET_ASSIST, bCheck = true, bChecked = RaidGrid_CTM_Edition.bTempTargetEnable, fnAction = function() RaidGrid_CTM_Edition.bTempTargetEnable = not RaidGrid_CTM_Edition.bTempTargetEnable end,
			{ szOption = _L["Don't show Tip in fight"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bTempTargetFightTip, fnDisable = function() return not RaidGrid_CTM_Edition.bTempTargetEnable end, fnAction = function()
				RaidGrid_CTM_Edition.bTempTargetFightTip = not RaidGrid_CTM_Edition.bTempTargetFightTip
			end	}
		})
		table.insert(menu, { bDevide = true })
		-- 提醒窗体
		table.insert(menu, { szOption = g_tStrings.STR_RAID_TIP_IMAGE,
			{ szOption = g_tStrings.STR_RAID_TIP_TARGET, bCheck = true, bChecked = RaidGrid_CTM_Edition.bShowTargetTargetAni, fnAction = function()
				RaidGrid_CTM_Edition.bShowTargetTargetAni = not RaidGrid_CTM_Edition.bShowTargetTargetAni
				Raid_CTM:RefreshTarget()
			end },
			{ szOption = _L["Show distance"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bShowDistance, fnAction = function()
				RaidGrid_CTM_Edition.bShowDistance = not RaidGrid_CTM_Edition.bShowDistance
			end },
			{ szOption = _L["Attack Warning"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bHPHitAlert, fnAction = function()
				RaidGrid_CTM_Edition.bHPHitAlert = not RaidGrid_CTM_Edition.bHPHitAlert
				Raid_CTM:CallDrawHPMP(true, true)
			end }
		})
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = g_tStrings.STR_RAID_LIFE_SHOW,
			{ szOption = _L["LifeBar Gradient"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bLifeGradient, fnAction = function()
				RaidGrid_CTM_Edition.bLifeGradient = not RaidGrid_CTM_Edition.bLifeGradient
				Raid_CTM:CallDrawHPMP(true, true)
			end	},
			{ szOption = _L["ManaBar Gradient"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bManaGradient, fnAction = function()
				RaidGrid_CTM_Edition.bManaGradient = not RaidGrid_CTM_Edition.bManaGradient
				Raid_CTM:CallDrawHPMP(true, true)
			end	},
			{ szOption = g_tStrings.STR_ALPHA, fnAction = function()
				local x, y = Cursor.GetPos()
				GetUserPercentage(function(val)
					RaidGrid_CTM_Edition.nAlpha = tonumber(val) * 255
					Raid_CTM:CallDrawHPMP(true, true)
					Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
				end, nil, RaidGrid_CTM_Edition.nAlpha / 255, g_tStrings.STR_ALPHA .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 })
			end	},
			{ bDevide = true },
			{ szOption = _L["Show ManaCount"], bCheck = true, bChecked = RaidGrid_CTM_Edition.nShowMP, fnAction = function()
				RaidGrid_CTM_Edition.nShowMP = not RaidGrid_CTM_Edition.nShowMP
				Raid_CTM:ReloadParty()
			end	},
			{ bDevide = true },
			{ szOption = g_tStrings.STR_RAID_LIFE_LEFT, bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownMode2 == 2, fnAction = function()
				RaidGrid_CTM_Edition.nHPShownMode2 = 2
				Raid_CTM:CallDrawHPMP(true, true)
			end	},
			{ szOption = g_tStrings.STR_RAID_LIFE_LOSE, bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownMode2 == 1, fnAction = function()
				RaidGrid_CTM_Edition.nHPShownMode2 = 1
				Raid_CTM:CallDrawHPMP(true, true)
			end	},
			{ szOption = g_tStrings.STR_RAID_LIFE_HIDE, bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownMode2 == 0, fnAction = function()
				RaidGrid_CTM_Edition.nHPShownMode2 = 0
				Raid_CTM:CallDrawHPMP(true, true)
			end	},
			{ bDevide = true },
			{ szOption = _L["Show Format value"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownNumMode == 1, fnAction = function()
				RaidGrid_CTM_Edition.nHPShownNumMode = 1
				Raid_CTM:CallDrawHPMP(true, true)
			end	},
			{ szOption = _L["Show Percentage value"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownNumMode == 2, fnAction = function()
				RaidGrid_CTM_Edition.nHPShownNumMode = 2
				Raid_CTM:CallDrawHPMP(true, true)
			end	},
			{ szOption = _L["Show full value"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nHPShownNumMode == 3, fnAction = function()
				RaidGrid_CTM_Edition.nHPShownNumMode = 3
				Raid_CTM:CallDrawHPMP(true, true)
			end	},
		})
		table.insert(menu, { szOption = _L["Icon & Color"],
			{ szOption = g_tStrings.STR_RAID_COLOR_NAME_SCHOOL, bCheck = true, bChecked = RaidGrid_CTM_Edition.bColoredName, fnAction = function()
				RaidGrid_CTM_Edition.bColoredName = not RaidGrid_CTM_Edition.bColoredName
				Raid_CTM:CallRefreshImages(true, false, false, nil, false, true)
			end	},		
			-- { szOption = _L["Border Color"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bColoredGrid, fnAction = function()
				-- RaidGrid_CTM_Edition.bColoredGrid = not RaidGrid_CTM_Edition.bColoredGrid
				-- Raid_CTM:ReloadParty()
			-- end	},
			{ bDevide = true },
			{ szOption = _L["Show Force Icon"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.bShowIcon == 1, fnAction = function()
				RaidGrid_CTM_Edition.bShowIcon = 1
				Raid_CTM:CallRefreshImages(true, false, true)
			end	},
			{ szOption = g_tStrings.STR_SHOW_KUNGFU, bMCheck = true, bChecked = RaidGrid_CTM_Edition.bShowIcon == 2, fnAction = function()
				RaidGrid_CTM_Edition.bShowIcon = 2
				Raid_CTM:CallRefreshImages(true, false, true)
			end	},
			{ szOption = _L["Show Camp Icon"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.bShowIcon == 3, fnAction = function()
				RaidGrid_CTM_Edition.bShowIcon = 3
				Raid_CTM:CallRefreshImages(true, false, true)
			end	},
		})

		local tDistanceMenu = { 
			szOption = g_tStrings.STR_RAID_DISTANCE, bCheck = true, bChecked = RaidGrid_CTM_Edition.bColorHPBarWithDistance, fnAction = function() 
				RaidGrid_CTM_Edition.bColorHPBarWithDistance = not RaidGrid_CTM_Edition.bColorHPBarWithDistance
				Raid_CTM:CallDrawHPMP(true, true)
			end	
		}
		for i = 1, #RaidGrid_CTM_Edition.tDistanceLevel do
			local n = RaidGrid_CTM_Edition.tDistanceLevel[i - 1] or 0
			local szOption = n .. " - " .. RaidGrid_CTM_Edition.tDistanceLevel[i] .. g_tStrings.STR_METER .. g_tStrings.BACK_COLOR
			table.insert(tDistanceMenu, { 
				szOption = szOption, 
				fnDisable = function() return not RaidGrid_CTM_Edition.bColorHPBarWithDistance end, 
				rgb = RaidGrid_CTM_Edition.tDistanceCol[i], 
				fnAction = function()
					GetUserInputNumber(RaidGrid_CTM_Edition.tDistanceLevel[i], RaidGrid_CTM_Edition.tDistanceLevel[i + 1] or 999, nil, function(val)
						RaidGrid_CTM_Edition.tDistanceLevel[i] = val
						Raid_CTM:CallDrawHPMP(true, true)
					end)
				end,
				szIcon = "ui/Image/button/CommonButton_1.UItex",
				nFrame = 69,
				nMouseOverFrame = 70,
				szLayer = "ICON_RIGHT",
				fnClickIcon = function() 
					GUI.OpenColorTablePanel(function(r, g, b)
						RaidGrid_CTM_Edition.tDistanceCol[i] = { r, g, b }
						Raid_CTM:CallDrawHPMP(true, true)
					end)
				end
			})
		end

		table.insert(menu, tDistanceMenu)
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = _L["Arrangement"],
			{ szOption = _L["One lines: 5/0"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 5, fnAction = function()
				RaidGrid_CTM_Edition.nAutoLinkMode = 5
				Raid_CTM:ReloadParty()
			end },
			{ szOption = _L["Two lines: 1/4"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 1, fnAction = function()
				RaidGrid_CTM_Edition.nAutoLinkMode = 1
				Raid_CTM:ReloadParty()
			end },
			{ szOption = _L["Two lines: 2/3"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 2, fnAction = function()
				RaidGrid_CTM_Edition.nAutoLinkMode = 2
				Raid_CTM:ReloadParty()
			end },
			{ szOption = _L["Two lines: 3/2"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 3, fnAction = function()
				RaidGrid_CTM_Edition.nAutoLinkMode = 3
				Raid_CTM:ReloadParty()
			end },
			{ szOption = _L["Two lines: 4/1"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 4, fnAction = function()
				RaidGrid_CTM_Edition.nAutoLinkMode = 4
				Raid_CTM:ReloadParty()
			end },	
		})
		table.insert(menu, { szOption = g_tStrings.WINDOW_ADJUST_SCALE,
			{ szOption = _L["Restore Default"], bCheck = false, bChecked = false, fnAction = function()
				RaidGrid_CTM_Edition.fScaleX = 1
				RaidGrid_CTM_Edition.fScaleY = 1
				RaidGrid_CTM_Edition.nFont = 40
				Raid_CTM:ReloadParty()
			end },
			{ bDevide = true },
			{ szOption = _L["Interface Width"], fnAction = function()
				local x, y = Cursor.GetPos()
				local fScaleX = RaidGrid_CTM_Edition.fScaleX
				GetUserPercentage(function(val)
					val = tonumber(val)
					local nNewX, nNewY = val / RaidGrid_CTM_Edition.fScaleX, RaidGrid_CTM_Edition.fScaleY / RaidGrid_CTM_Edition.fScaleY
					Raid_CTM:Scale(nNewX, nNewY)
					RaidGrid_CTM_Edition.fScaleX = val
					Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
				end, nil, (fScaleX - 0.5) / 1.00, _L["Interface Width"] .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 }, nil, { StartValue = 50, nStepCount = 100 })
			end	},
			{ szOption = _L["Interface Height"], fnAction = function()
				local x, y = Cursor.GetPos()
				local fScaleY = RaidGrid_CTM_Edition.fScaleY
				GetUserPercentage(function(val)
					val = tonumber(val)
					local nNewX, nNewY = RaidGrid_CTM_Edition.fScaleX / RaidGrid_CTM_Edition.fScaleX, val / RaidGrid_CTM_Edition.fScaleY
					Raid_CTM:Scale(nNewX, nNewY)
					RaidGrid_CTM_Edition.fScaleY = val
					Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
				end, nil, (fScaleY - 0.5) / 1.00, _L["Interface Height"] .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 }, nil, { StartValue = 50, nStepCount = 100 })
			end },
			{ szOption = _L["Font Style"], fnAction = function()
				GUI.OpenFontTablePanel(function(nFont)
					RaidGrid_CTM_Edition.nFont = nFont
					Raid_CTM:CallRefreshImages(true, false, false, nil, false, true)
				end)
			end },
		})
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = g_tStrings.OTHER,
			{ szOption = _L["Only in team"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bShowInRaid, fnAction = function(UserData, bCheck)
				RaidGrid_CTM_Edition.bShowInRaid = bCheck
				RaidCheckEnable()
				local me = GetClientPlayer()
				if me.IsInParty() and not me.IsInRaid() then
					FireEvent("CTM_PANEL_TEAMATE", RaidGrid_CTM_Edition.bShowInRaid)
				end
			end },
			{ szOption = _L["Faster Refresh HP(Greater performance loss)"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bFasterHP, fnAction = function()
				RaidGrid_CTM_Edition.bFasterHP = not RaidGrid_CTM_Edition.bFasterHP
				if RaidGrid_CTM_Edition.bFasterHP then
					CTM_FRAME:RegisterEvent("RENDER_FRAME_UPDATE")
				else
					RaidClosePanel()
					RaidCheckEnable()
				end
			end },	
		})		
		-- 人数统计
		if me.IsInRaid() then
			table.insert(menu, { bDevide = true })
			InsertForceCountMenu(menu)
		end
		local nX, nY = Cursor.GetPos(true)
		menu.x, menu.y = nX + 15, nY + 15
		PopupMenu(menu)
	
	elseif szName == "Btn_WorldMark" then
		if JH.IsInDungeon2() then
			Wnd.ToggleWindow("WorldMark")
		else
			OutputMessage("MSG_ANNOUNCE_RED", g_tStrings.STR_WORLD_MARK)
		end
	end
end

function RaidGrid_CTM_Edition.OnLButtonDown()
	Raid_CTM:BringToTop()
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
			return JH.Sysmsg(_L["Please hold down Ctrl, change it"])
		end
		team.SetTeamLootMode(CTM_LOOT_MODE[szName])
	end
end

function RaidGrid_CTM_Edition.OnFrameBreathe()
	local me = GetClientPlayer()
	if not me then return end
	Raid_CTM:RefreshDistance()
	Raid_CTM:RefresBuff()
	if RaidGrid_CTM_Edition.bShowTargetTargetAni then
		Raid_CTM:RefreshTarget()
	end
	-- kill System Panel
	RaidPanel_Switch(false)
	TeammatePanel_Switch(false)
end

function RaidGrid_CTM_Edition.OnFrameDragEnd()
	this:CorrectPos()
	RaidGrid_CTM_Edition.tAnchor = GetFrameAnchor(this)
	Raid_CTM:AutoLinkAllPanel() -- fix screen pos
end

JH.RegisterEvent("LOADING_END", RaidCheckEnable)
JH.RegisterEvent("PARTY_UPDATE_BASE_INFO", RaidCheckEnable)
JH.RegisterEvent("CTM_PANEL_TEAMATE", function()
	TeammatePanel_Switch(arg0)
end)

JH.RegisterEvent("CTM_PANEL_RAID", function()
	RaidPanel_Switch(arg0)
end)

local SaveConfig = function()
	JH.SaveLUAData("CTM/Config_V1.jx3dat", CTM_CONFIG_PLAYER)
end
JH.RegisterEvent("GAME_EXIT", SaveConfig)
JH.RegisterEvent("PLAYER_EXIT_GAME", SaveConfig)

JH.AddonMenu(function()
	return {
		szOption = _L["CTM Team Panel"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bRaidEnable and not RaidGrid_CTM_Edition.bShowInRaid, fnAction = function()
			RaidGrid_CTM_Edition.bRaidEnable = not RaidGrid_CTM_Edition.bRaidEnable
			RaidGrid_CTM_Edition.bShowInRaid = false
			RaidCheckEnable()
			FireEvent("CTM_PANEL_RAID", not RaidGrid_CTM_Edition.bRaidEnable)
		end
	}
end)
-- 所有角色共享配置
setmetatable(RaidGrid_CTM_Edition, {
	__index = CTM_CONFIG_PLAYER,
	__newindex = CTM_CONFIG_PLAYER,
})