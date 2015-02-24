local _L = JH.LoadLangPack
local Station = Station
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
	nShowIcon = 2,
	bShowDistance = false,
	bEnableDistance = true,
	nBGClolrMode = 1, -- 0 不着色 1 根据距离 2 根据门派
	bShowTargetTargetAni = false,
	nFont = 40,
	nMaxShowBuff = 4,
	bLifeGradient = true,
	bManaGradient = true,
	nAlpha = 255,
	bTempTargetFightTip = false,
	bTempTargetEnable = true,
	fScaleX = 1,
	fScaleY = 1,
	tDistanceLevel = { 20, 22, 200 },
	tManaColor = { 0, 96, 255 },
	tDistanceCol = {
		{ 0,   180, 52  }, -- 绿
		{ 230, 170, 40  }, -- 黄
		{ 230, 80,  80  }, -- 红
	},
	tOtherCol = {
		{ 255, 255, 255 },
		{ 128, 128, 128 },
		{ 192, 192, 192 }
	},
	bFasterHP = false,
}
local DEBUG = false
local CONFIG_KEY = "config/Cataclysmg_V1.jx3dat"
local CTM_CONFIG_PLAYER = JH.LoadLUAData(CONFIG_KEY) or CTM_CONFIG
-- options fixed
do
	for k, v in pairs(CTM_CONFIG) do
		if not CTM_CONFIG_PLAYER[k] then
			CTM_CONFIG_PLAYER[k] = v
		end
	end
end

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

local function RaidOpenPanel()
	local frame = CTM_FRAME or Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "Cataclysm_Panel/ui/Cataclysm_Main.ini", "RaidGrid_CTM_Edition")
	return frame
end
local function RaidClosePanel()
	if CTM_FRAME then
		Wnd.CloseWindow(CTM_FRAME)
		Grid_CTM:CloseParty()
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
	Grid_CTM:ReloadParty()
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
RaidGrid_CTM_Edition = {}
local RaidGrid_CTM_Edition = RaidGrid_CTM_Edition
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
	Grid_CTM:AutoLinkAllPanel()
end
-------------------------------------------------
-- 事件处理
-------------------------------------------------
function RaidGrid_CTM_Edition.OnEvent(szEvent)
	if szEvent == "RENDER_FRAME_UPDATE" then
		Grid_CTM:CallDrawHPMP(true)
	elseif szEvent == "PARTY_SYNC_MEMBER_DATA" then -- ??
		Grid_CTM:CallRefreshImages(arg1, true, true, nil, true, true)
	elseif szEvent == "PARTY_ADD_MEMBER" then
		Grid_CTM:CreatePanel(arg2)
		Grid_CTM:DrawParty(arg2, true)
	elseif szEvent == "PARTY_DELETE_MEMBER" then
		local me = GetClientPlayer()
		if me.dwID == arg1 then
			RaidClosePanel()
		else
			local team = GetClientTeam()
			local tGropu = team.GetGroupInfo(arg3)
			if #tGropu.MemberList == 0 then
				Grid_CTM:CloseParty(arg3)
				Grid_CTM:AutoLinkAllPanel()
			else
				Grid_CTM:DrawParty(arg3, true)
			end
		end
		JH.DelayCall(1000, function()
			collectgarbage("collect")
		end)
	elseif szEvent == "PARTY_DISBAND" then
		RaidClosePanel()
		JH.DelayCall(1000, function()
			collectgarbage("collect")
		end)
	elseif szEvent == "PARTY_UPDATE_MEMBER_LMR" then
		Grid_CTM:CallDrawHPMP(arg1, true)
	elseif szEvent == "PARTY_UPDATE_MEMBER_INFO" then
		Grid_CTM:CallRefreshImages(arg1, false, true, nil, true, true)
		Grid_CTM:CallDrawHPMP(arg1, true)
	elseif szEvent == "UPDATE_PLAYER_SCHOOL_ID" then
		if JH.IsParty(arg0) then
			Grid_CTM:CallRefreshImages(arg0, false, true)
		end
	elseif szEvent == "PLAYER_STATE_UPDATE" then
		if JH.IsParty(arg0) then
			Grid_CTM:CallDrawHPMP(arg0, true)
		end
	elseif szEvent == "PARTY_SET_MEMBER_ONLINE_FLAG" then
		Grid_CTM:CallDrawHPMP(arg1, true)
	elseif szEvent == "TEAM_AUTHORITY_CHANGED" then
		Grid_CTM:CallRefreshImages(arg2, true)
		Grid_CTM:CallRefreshImages(arg3, true)
		UpdateLootImages()
	elseif szEvent == "PARTY_SET_FORMATION_LEADER" then
		Grid_CTM:RefresFormation()
	elseif szEvent == "PARTY_SET_MARK" then
		Grid_CTM:RefreshMark()
	-- elseif szEvent == "RIAD_READY_CONFIRM_RECEIVE_QUESTION" then
	elseif szEvent == "RIAD_READY_CONFIRM_RECEIVE_ANSWER" then
		Grid_CTM:ChangeReadyConfirm(arg0, arg1)
	elseif szEvent == "TEAM_CHANGE_MEMBER_GROUP" then
		local me = GetClientPlayer()
		local team = GetClientTeam()
		local tSrcGropu = team.GetGroupInfo(arg1)
		-- SrcGroup
		if #tSrcGropu.MemberList == 0 then
			Grid_CTM:CloseParty(arg1)
			Grid_CTM:AutoLinkAllPanel()
		else
			Grid_CTM:DrawParty(arg1, true)
		end
		-- DstGroup
		if Grid_CTM:GetPartyFrame(arg2) then
			Grid_CTM:DrawParty(arg2)
		else
			Grid_CTM:CreatePanel(arg2)
			Grid_CTM:DrawParty(arg2)
		end
	elseif szEvent == "PARTY_LEVEL_UP_RAID" then
		Grid_CTM:ReloadParty()
	elseif szEvent == "PARTY_LOOT_MODE_CHANGED" then
		UpdateLootImages()
	elseif szEvent == "TARGET_CHANGE" then
		Grid_CTM:RefreshTarget()
	elseif szEvent == "JH_RAID_REC_BUFF" then
		Grid_CTM:RecBuff(arg0, arg1, arg2, arg3)
	elseif szEvent == "UI_SCALED" or "CTM_LOADING_END" then
		UpdateAnchor(this)
		Grid_CTM:AutoLinkAllPanel()
	end
	
end
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
		if me.IsInRaid() then
			-- 团队就位
			table.insert(menu, { szOption = g_tStrings.STR_RAID_MENU_READY_CONFIRM, 
				{ szOption = g_tStrings.STR_RAID_READY_CONFIRM_START, bDisable = not JH.IsLeader() or not me.IsInRaid(), fnAction = function() Grid_CTM:Send_RaidReadyConfirm() end },
				{ szOption = g_tStrings.STR_RAID_READY_CONFIRM_RESET, bDisable = not JH.IsLeader() or not me.IsInRaid(), fnAction = function() Grid_CTM:Clear_RaidReadyConfirm() end }
			})
			table.insert(menu, { bDevide = true })
		end
		-- 分配
		InsertDistributeMenu(menu, me.dwID ~= dwDistribute)
		table.insert(menu, { bDevide = true })
		if me.IsInRaid() then
			-- 编辑模式
			table.insert(menu, { szOption = string.gsub(g_tStrings.STR_RAID_MENU_RAID_EDIT, "Ctrl", "Alt"), bDisable = not JH.IsLeader() or not me.IsInRaid(), bCheck = true, bChecked = RaidGrid_CTM_Edition.bEditMode, fnAction = function() 
				RaidGrid_CTM_Edition.bEditMode = not RaidGrid_CTM_Edition.bEditMode
				GetPopupMenu():Hide()
			end })
		-- 人数统计
			table.insert(menu, { bDevide = true })
			InsertForceCountMenu(menu)
			table.insert(menu, { bDevide = true })
		end
		table.insert(menu, { szOption = _L["Interface settings"], rgb = { 255, 255, 0 }, fnAction = function()
			JH.OpenPanel(_L["Cataclysm"])
		end })
		if JH.bDebug then
			table.insert(menu, { bDevide = true })
			table.insert(menu, { szOption = "DEBUG Mode", bCheck = true, bChecked = DEBUG, fnAction = function()
				DEBUG = not DEBUG
			end	})
		end
		local nX, nY = Cursor.GetPos(true)
		menu.x, menu.y = nX, nY
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
	Grid_CTM:BringToTop()
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
	Grid_CTM:RefreshDistance()
	Grid_CTM:RefresBuff()
	if RaidGrid_CTM_Edition.bShowTargetTargetAni then
		Grid_CTM:RefreshTarget()
	end
	-- kill System Panel
	RaidPanel_Switch(DEBUG)
	TeammatePanel_Switch(false)
end

function RaidGrid_CTM_Edition.OnFrameDragEnd()
	this:CorrectPos()
	RaidGrid_CTM_Edition.tAnchor = GetFrameAnchor(this)
	Grid_CTM:AutoLinkAllPanel() -- fix screen pos
end

local EnableTeamPanel = function()
	RaidGrid_CTM_Edition.bRaidEnable = not RaidGrid_CTM_Edition.bRaidEnable
	RaidCheckEnable()
	if not RaidGrid_CTM_Edition.bRaidEnable then
		local me = GetClientPlayer()
		if me.IsInRaid() then
			FireEvent("CTM_PANEL_RAID", true)
		elseif me.IsInParty() then
			FireEvent("CTM_PANEL_TEAMATE", true)
		end
	end
end

local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Cataclysm Team Panel"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Enable Cataclysm Team Panel"], checked = RaidGrid_CTM_Edition.bRaidEnable }):Click(EnableTeamPanel):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Only in team"], checked = RaidGrid_CTM_Edition.bShowInRaid })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bShowInRaid = bCheck
		RaidCheckEnable()
		local me = GetClientPlayer()
		if me.IsInParty() and not me.IsInRaid() then
			FireEvent("CTM_PANEL_TEAMATE", RaidGrid_CTM_Edition.bShowInRaid)
		end
	end):Pos_()
	-- 提醒框
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.STR_RAID_TIP_IMAGE, font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_RAID_TIP_TARGET, checked = RaidGrid_CTM_Edition.bShowTargetTargetAni })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bShowTargetTargetAni = bCheck
		if CTM_FRAME then
			Grid_CTM:RefreshTarget()
		end
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Show distance"], checked = RaidGrid_CTM_Edition.bShowDistance })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bShowDistance = bCheck
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Show ManaCount"], checked = RaidGrid_CTM_Edition.nShowMP })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.nShowMP = bCheck
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Attack Warning"], checked = RaidGrid_CTM_Edition.bHPHitAlert })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bHPHitAlert = bCheck
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	-- 血量显示
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.STR_RAID_LIFE_SHOW .. _L["& Icon"], font = 27 }):Pos_()
	nX = ui:Append("WndRadioBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_RAID_LIFE_LEFT, group = "lifemode", checked = RaidGrid_CTM_Edition.nHPShownMode2 == 2 })
	:Click(function()
		RaidGrid_CTM_Edition.nHPShownMode2 = 2
		ui:Fetch("lifval1"):Enable(true)
		ui:Fetch("lifval2"):Enable(true)
		ui:Fetch("lifval3"):Enable(true)
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX+ 5, y = nY + 10, txt = g_tStrings.STR_RAID_LIFE_LOSE, group = "lifemode", checked = RaidGrid_CTM_Edition.nHPShownMode2 == 1 })
	:Click(function()
		RaidGrid_CTM_Edition.nHPShownMode2 = 1
		ui:Fetch("lifval1"):Enable(true)
		ui:Fetch("lifval2"):Enable(true)
		ui:Fetch("lifval3"):Enable(true)
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX+ 5, y = nY + 10, txt = g_tStrings.STR_RAID_LIFE_HIDE, group = "lifemode", checked = RaidGrid_CTM_Edition.nHPShownMode2 == 0 })
	:Click(function()
		RaidGrid_CTM_Edition.nHPShownMode2 = 0
		ui:Fetch("lifval1"):Enable(false)
		ui:Fetch("lifval2"):Enable(false)
		ui:Fetch("lifval3"):Enable(false)
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	-- 数值
	nX = ui:Append("WndRadioBox", "lifval1", { x = 10, y = nY, txt = _L["Show Format value"], group = "lifval", checked = RaidGrid_CTM_Edition.nHPShownNumMode == 1 })
	:Enable(RaidGrid_CTM_Edition.nHPShownMode2 ~= 0):Click(function()
		RaidGrid_CTM_Edition.nHPShownNumMode = 1
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", "lifval2", { x = nX+ 5, y = nY, txt = _L["Show Percentage value"], group = "lifval", checked = RaidGrid_CTM_Edition.nHPShownNumMode == 2 })
	:Enable(RaidGrid_CTM_Edition.nHPShownMode2 ~= 0):Click(function()
		RaidGrid_CTM_Edition.nHPShownNumMode = 2
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", "lifval3", { x = nX+ 5, y = nY, txt = _L["Show full value"], group = "lifval", checked = RaidGrid_CTM_Edition.nHPShownNumMode == 3 })
	:Enable(RaidGrid_CTM_Edition.nHPShownMode2 ~= 0):Click(function()
		RaidGrid_CTM_Edition.nHPShownNumMode = 3
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	-- Icon
	nX = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Show Force Icon"], group = "icon", checked = RaidGrid_CTM_Edition.nShowIcon == 1 })
	:Click(function()
		RaidGrid_CTM_Edition.nShowIcon = 1
		if CTM_FRAME then
			Grid_CTM:CallRefreshImages(true, false, true, nil, nil, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX+ 5, y = nY, txt = g_tStrings.STR_SHOW_KUNGFU, group = "icon", checked = RaidGrid_CTM_Edition.nShowIcon == 2 })
	:Click(function()
		RaidGrid_CTM_Edition.nShowIcon = 2
		if CTM_FRAME then
			Grid_CTM:CallRefreshImages(true, false, true, nil, nil, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX + 5, y = nY, txt = _L["Show Camp Icon"], group = "icon", checked = RaidGrid_CTM_Edition.nShowIcon == 3 })
	:Click(function()
		RaidGrid_CTM_Edition.nShowIcon = 3
		if CTM_FRAME then
			Grid_CTM:CallRefreshImages(true, false, true, nil, nil, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY, txt = _L["Show Text Force"], group = "icon", checked = RaidGrid_CTM_Edition.nShowIcon == 4 })
	:Click(function()
		RaidGrid_CTM_Edition.nShowIcon = 4
		if CTM_FRAME then
			Grid_CTM:CallRefreshImages(true, false, true, nil, nil, true)
		end
	end):Pos_()
	-- Interface settings
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Interface settings"], font = 27 }):Pos_()
	nX = ui:Append("WndComboBox", { x = 10, y = nY + 10, txt = _L["Color settings"] })
	:Menu(function()
		local tIconColor = {}
		table.insert(tIconColor, { szOption = _L["LifeBar Gradient"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bLifeGradient, fnAction = function()
			RaidGrid_CTM_Edition.bLifeGradient = not RaidGrid_CTM_Edition.bLifeGradient
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end	})
		table.insert(tIconColor, { szOption = _L["ManaBar Gradient"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bManaGradient, fnAction = function()
			RaidGrid_CTM_Edition.bManaGradient = not RaidGrid_CTM_Edition.bManaGradient
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end	})
		table.insert(tIconColor, { szOption = g_tStrings.STR_ALPHA, fnAction = function()
			local x, y = Cursor.GetPos()
			GetUserPercentage(function(val)
				RaidGrid_CTM_Edition.nAlpha = tonumber(val) * 255
				Grid_CTM:CallDrawHPMP(true, true)
				Station.Lookup("Normal/GetPercentagePanel"):BringToTop()
			end, nil, RaidGrid_CTM_Edition.nAlpha / 255, g_tStrings.STR_ALPHA .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 })
		end	})
		table.insert(tIconColor, { bDevide = true })
		table.insert(tIconColor, { szOption = g_tStrings.STR_GUILD_NAME .. g_tStrings.STR_RAID_COLOR_NAME_SCHOOL, bCheck = true, bChecked = RaidGrid_CTM_Edition.bColoredName, fnAction = function()
			RaidGrid_CTM_Edition.bColoredName = not RaidGrid_CTM_Edition.bColoredName
			if CTM_FRAME then
				Grid_CTM:CallRefreshImages(true, false, false, nil, false, true)
			end
		end	})
		table.insert(tIconColor, { bDevide = true })
		table.insert(tIconColor, { szOption = g_tStrings.STR_RAID_DISTANCE, bCheck = true, bChecked = RaidGrid_CTM_Edition.bEnableDistance, fnAction = function() 
			RaidGrid_CTM_Edition.bEnableDistance = not RaidGrid_CTM_Edition.bEnableDistance
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end })
		table.insert(tIconColor, { bDevide = true })
		table.insert(tIconColor, { szOption = g_tStrings.BACK_COLOR .. g_tStrings.STR_RAID_COLOR_NAME_NONE, bMCheck = true, bChecked = RaidGrid_CTM_Edition.nBGClolrMode == 0, fnAction = function() 
			RaidGrid_CTM_Edition.nBGClolrMode = 0
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end })
		table.insert(tIconColor, { szOption = g_tStrings.BACK_COLOR .. _L["Colored according to the distance"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nBGClolrMode == 1, fnAction = function() 
			RaidGrid_CTM_Edition.nBGClolrMode = 1
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end })
		table.insert(tIconColor, { szOption = g_tStrings.BACK_COLOR .. g_tStrings.STR_RAID_COLOR_NAME_SCHOOL, bMCheck = true, bChecked = RaidGrid_CTM_Edition.nBGClolrMode == 2, fnAction = function() 
			RaidGrid_CTM_Edition.nBGClolrMode = 2
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end })
		table.insert(tIconColor, { bDevide = true })
		table.insert(tIconColor, { szOption = _L["Edit Distance Level"], fnDisable = function() return RaidGrid_CTM_Edition.nBGClolrMode ~= 1 end, fnAction = function()
			GetUserInput(_L["distance, distance, ..."], function(szText)
				local t = JH.Split(JH.Trim(szText), ",")
				local tt = {}
				for k, v in ipairs(t) do
					if not tonumber(v) then
						table.remove(t, k)
					else
						table.insert(tt, tonumber(v))
					end
				end
				if #t > 0 then
					RaidGrid_CTM_Edition.tDistanceLevel = tt
					RaidGrid_CTM_Edition.tDistanceCol = {}
					for k, v in ipairs(t) do
						table.insert(RaidGrid_CTM_Edition.tDistanceCol, { 255, 255, 255 })
					end
				end
			end)
		end	})
		for i = 1, #RaidGrid_CTM_Edition.tDistanceLevel do
			local n = RaidGrid_CTM_Edition.tDistanceLevel[i - 1] or 0
			local szOption = n .. " - " .. RaidGrid_CTM_Edition.tDistanceLevel[i] .. g_tStrings.STR_METER .. g_tStrings.BACK_COLOR
			table.insert(tIconColor, { 
				szOption = szOption, 
				fnDisable = function() return RaidGrid_CTM_Edition.nBGClolrMode ~= 1 end, 
				rgb = RaidGrid_CTM_Edition.tDistanceCol[i], 
				fnAction = function()
					GetUserInputNumber(RaidGrid_CTM_Edition.tDistanceLevel[i], RaidGrid_CTM_Edition.tDistanceLevel[i + 1] or 999, nil, function(val)
						RaidGrid_CTM_Edition.tDistanceLevel[i] = val
						if CTM_FRAME then
							Grid_CTM:CallDrawHPMP(true, true)
						end
					end)
				end,
				szIcon = "ui/Image/button/CommonButton_1.UItex",
				nFrame = 69,
				nMouseOverFrame = 70,
				szLayer = "ICON_RIGHT",
				fnClickIcon = function() 
					GUI.OpenColorTablePanel(function(r, g, b)
						RaidGrid_CTM_Edition.tDistanceCol[i] = { r, g, b }
						if CTM_FRAME then
							Grid_CTM:CallDrawHPMP(true, true)
						end
					end)
				end
			})
		end
		table.insert(tIconColor, { bDevide = true })
		table.insert(tIconColor, { szOption = g_tStrings.STR_RAID_DISTANCE_M4 .. g_tStrings.BACK_COLOR,
			rgb =  RaidGrid_CTM_Edition.tOtherCol[3], 
			szIcon = "ui/Image/button/CommonButton_1.UItex",
			nFrame = 69,
			nMouseOverFrame = 70,
			szLayer = "ICON_RIGHT",
			fnClickIcon = function() 
				GUI.OpenColorTablePanel(function(r, g, b)
					RaidGrid_CTM_Edition.tOtherCol[3] = { r, g, b }
					if CTM_FRAME then
						Grid_CTM:CallDrawHPMP(true, true)
					end
				end)
			end
		})
		table.insert(tIconColor, { szOption = g_tStrings.STR_GUILD_OFFLINE .. g_tStrings.BACK_COLOR,
			rgb =  RaidGrid_CTM_Edition.tOtherCol[2], 
			szIcon = "ui/Image/button/CommonButton_1.UItex",
			nFrame = 69,
			nMouseOverFrame = 70,
			szLayer = "ICON_RIGHT",
			fnClickIcon = function() 
				GUI.OpenColorTablePanel(function(r, g, b)
					RaidGrid_CTM_Edition.tOtherCol[2] = { r, g, b }
					if CTM_FRAME then
						Grid_CTM:CallDrawHPMP(true, true)
					end
				end)
			end
		})
		table.insert(tIconColor, { szOption = g_tStrings.STR_SKILL_MANA .. g_tStrings.BACK_COLOR,
			rgb =  RaidGrid_CTM_Edition.tManaColor, 
			szIcon = "ui/Image/button/CommonButton_1.UItex",
			nFrame = 69,
			nMouseOverFrame = 70,
			szLayer = "ICON_RIGHT",
			fnClickIcon = function() 
				GUI.OpenColorTablePanel(function(r, g, b)
					RaidGrid_CTM_Edition.tManaColor = { r, g, b }
					if CTM_FRAME then
						Grid_CTM:CallDrawHPMP(true, true)
					end
				end)
			end
		})
		table.insert(tIconColor, { bDevide = true })
		table.insert(tIconColor, { szOption = _L["Max buff count"], fnAction = function()
			GetUserInputNumber(RaidGrid_CTM_Edition.nMaxShowBuff, 4, nil, function(val)
				RaidGrid_CTM_Edition.nMaxShowBuff = val
			end)
		end	})
		table.insert(tIconColor, { bDevide = true })
		table.insert(tIconColor, { szOption = _L["Font Style"], fnAction = function()
			GUI.OpenFontTablePanel(function(nFont)
				RaidGrid_CTM_Edition.nFont = nFont
				if CTM_FRAME then
					Grid_CTM:CallRefreshImages(true, false, false, nil, false, true)
				end
			end)
		end })
		
		return tIconColor
	end):Pos_()
	nX = ui:Append("WndComboBox", { x = nX + 5, y = nY + 10, w = 150, h = 25, txt = g_tStrings.WINDOW_ADJUST_SCALE })
	:Menu(function()
		local x, y = this:GetAbsPos()
		local menu = {}
		table.insert(menu, { szOption = _L["Restore Default"], bCheck = false, bChecked = false, fnAction = function()
			RaidGrid_CTM_Edition.fScaleX = 1
			RaidGrid_CTM_Edition.fScaleY = 1
			RaidGrid_CTM_Edition.nFont = 40
			if CTM_FRAME then
				Grid_CTM:CloseParty()
				Grid_CTM:ReloadParty()
			end
		end })
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = _L["Interface Width"], fnAction = function()
			local fScaleX = RaidGrid_CTM_Edition.fScaleX
			GetUserPercentage(function(val)
				val = tonumber(val)
				local nNewX, nNewY = val / RaidGrid_CTM_Edition.fScaleX, RaidGrid_CTM_Edition.fScaleY / RaidGrid_CTM_Edition.fScaleY
				if CTM_FRAME then
					Grid_CTM:Scale(nNewX, nNewY)
				end
				RaidGrid_CTM_Edition.fScaleX = val
			end, nil, (fScaleX - 0.5) / 1.00, _L["Interface Width"] .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 }, nil, { StartValue = 50, nStepCount = 100 })
		end	})
		table.insert(menu, { szOption = _L["Interface Height"], fnAction = function()
			local fScaleY = RaidGrid_CTM_Edition.fScaleY
			GetUserPercentage(function(val)
				val = tonumber(val)
				local nNewX, nNewY = RaidGrid_CTM_Edition.fScaleX / RaidGrid_CTM_Edition.fScaleX, val / RaidGrid_CTM_Edition.fScaleY
				if CTM_FRAME then
					Grid_CTM:Scale(nNewX, nNewY)
				end
				RaidGrid_CTM_Edition.fScaleY = val
			end, nil, (fScaleY - 0.5) / 1.00, _L["Interface Height"] .. g_tStrings.STR_COLON, { x, y, x + 1, y + 1 }, nil, { StartValue = 50, nStepCount = 100 })
		end })
		return menu
	end):Pos_()
	nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 10, w = 150, h = 25, txt = _L["Arrangement"] })
	:Menu(function()
		local menu = {}
		table.insert(menu, { szOption = _L["One lines: 5/0"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 5, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 5
			if CTM_FRAME then
				Grid_CTM:AutoLinkAllPanel()
			end
		end })
		table.insert(menu, { szOption = _L["Two lines: 1/4"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 1, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 1
			if CTM_FRAME then
				Grid_CTM:AutoLinkAllPanel()
			end
		end })
		table.insert(menu, { szOption = _L["Two lines: 2/3"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 2, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 2
			if CTM_FRAME then
				Grid_CTM:AutoLinkAllPanel()
			end
		end })
		table.insert(menu, { szOption = _L["Two lines: 3/2"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 3, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 3
			if CTM_FRAME then
				Grid_CTM:AutoLinkAllPanel()
			end
		end })
		table.insert(menu, { szOption = _L["Two lines: 4/1"], bMCheck = true, bChecked = RaidGrid_CTM_Edition.nAutoLinkMode == 4, fnAction = function()
			RaidGrid_CTM_Edition.nAutoLinkMode = 4
			if CTM_FRAME then
				Grid_CTM:AutoLinkAllPanel()
			end
		end })
		return menu
	end):Pos_()
	-- 其他
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.OTHER, font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_RAID_TARGET_ASSIST, checked = RaidGrid_CTM_Edition.bTempTargetEnable })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bTempTargetEnable = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 250, y = nY + 10, txt = _L["Don't show Tip in fight"], checked = RaidGrid_CTM_Edition.bTempTargetFightTip })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bTempTargetFightTip = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Faster Refresh HP(Greater performance loss)"], checked = RaidGrid_CTM_Edition.bFasterHP })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bFasterHP = bCheck
		if CTM_FRAME then
			if bCheck then
				CTM_FRAME:RegisterEvent("RENDER_FRAME_UPDATE")
			else
				RaidClosePanel()
				RaidCheckEnable()
			end
		end
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["CataclysmTIP"], font = 27 }):Pos_()
end

GUI.RegisterPanel(_L["Cataclysm"], 5389, _L["General"], PS)
JH.RegisterEvent("LOADING_END", RaidCheckEnable)
JH.RegisterEvent("PARTY_UPDATE_BASE_INFO", RaidCheckEnable)
JH.RegisterEvent("CTM_PANEL_TEAMATE", function()
	TeammatePanel_Switch(arg0)
end)
JH.RegisterEvent("CTM_PANEL_RAID", function()
	RaidPanel_Switch(arg0)
end)
local SaveConfig = function()
	JH.SaveLUAData(CONFIG_KEY, CTM_CONFIG_PLAYER)
end
JH.RegisterEvent("GAME_EXIT", SaveConfig)
JH.RegisterEvent("PLAYER_EXIT_GAME", SaveConfig)

JH.AddonMenu(function()
	return { szOption = _L["Cataclysm Team Panel"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bRaidEnable and not RaidGrid_CTM_Edition.bShowInRaid, fnAction = EnableTeamPanel }
end)
-- 所有角色共享配置
setmetatable(RaidGrid_CTM_Edition, {
	__index = CTM_CONFIG_PLAYER,
	__newindex = CTM_CONFIG_PLAYER,
})