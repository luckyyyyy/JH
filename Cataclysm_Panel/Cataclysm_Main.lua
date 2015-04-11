-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-04-12 01:53:18
local _L = JH.LoadLangPack
local Station, UI_GetClientPlayerID, Table_BuffIsVisible = Station, UI_GetClientPlayerID, Table_BuffIsVisible
local GetBuffName = JH.GetBuffName
local tostring = tostring
local CTM_CONFIG = {
	bRaidEnable          = true,
	bShowInRaid          = false,
	bEditMode            = false,
	bShowAllGrid         = false,
	tAnchor              = {},
	nAutoLinkMode        = 5,
	nHPShownMode2        = 2,
	nHPShownNumMode      = 1,
	nShowMP              = false,
	bHPHitAlert          = true,
	bColoredName         = true,
	nShowIcon            = 2,
	bShowDistance        = false,
	bEnableDistance      = true,
	nBGClolrMode         = 1, -- 0 不着色 1 根据距离 2 根据门派
	bShowTargetTargetAni = false,
	nFont                = 40,
	nLifeFont            = 15,
	nMaxShowBuff         = 4,
	bLifeGradient        = true,
	bManaGradient        = true,
	nAlpha               = 255,
	fBuffScale           = 1,
	bAutoBuffSize        = true,
	bTempTargetFightTip  = false,
	bTempTargetEnable    = true,
	fScaleX              = 1,
	fScaleY              = 1,
	tDistanceLevel       = { 20, 22, 200 },
	tManaColor           = { 0, 96, 255 },
	bFasterHP            = false,
	bStaring             = false,
	bShowBuffTime        = false,
	bShowBuffNum         = false,
	bShowGropuNumber     = true,
	tBuffList = { -- 结构的话 就这样吧不过颜色不让设置
		-- ["调息"] = { bSelf = true, col = 255, 255, 255}
	},
	tDistanceCol = {
		{ 0,   180, 52  }, -- 绿
		{ 0,   180, 52  }, -- 绿
		-- 免得被说乱
		-- { 230, 170, 40  }, -- 黄
		{ 230, 80,  80  }, -- 红
	},
	tOtherCol = {
		{ 255, 255, 255 },
		{ 128, 128, 128 },
		{ 192, 192, 192 }
	},
}
local TEAM_VOTE_REQUEST = {}
local GKP_RECORD_TOTAL = 0
local CTM_CONFIG_PLAYER
local DEBUG = false

Cataclysm_KEY = "common"
RegisterCustomData("Cataclysm_KEY")

local function GetConfigurePath()
	return "config/Cataclysm_" .. Cataclysm_KEY .. ".jx3dat"
end

local function SetConfigure()
	CTM_CONFIG_PLAYER = JH.LoadLUAData(GetConfigurePath()) or CTM_CONFIG
	-- options fixed
	for k, v in pairs(CTM_CONFIG) do
		if type(CTM_CONFIG_PLAYER[k]) == "nil" then
			CTM_CONFIG_PLAYER[k] = v
		end
	end
	setmetatable(RaidGrid_CTM_Edition, {
		__index = CTM_CONFIG_PLAYER,
		__newindex = CTM_CONFIG_PLAYER,
	})
end

local CTM_FRAME
local CTM_LOOT_MODE = {
	Image_LootMode_Free    = PARTY_LOOT_MODE.FREE_FOR_ALL,
	Image_LootMode_Looter  = PARTY_LOOT_MODE.DISTRIBUTE,
	Image_LootMode_Roll    = PARTY_LOOT_MODE.GROUP_LOOT,
	Image_LootMode_Bidding = PARTY_LOOT_MODE.BIDDING,
}

local function UpdateLootImages()
	local team = GetClientTeam()
	local nLootMode = team.nLootMode
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

local function GetGroupTotal()
	local me, team = GetClientPlayer(), GetClientTeam()
	local nGroup = 0
	if me.IsInRaid() then
		for i = 0, team.nGroupNum - 1 do
			local tGropu = team.GetGroupInfo(i)
			if #tGropu.MemberList > 0 then
				nGroup = nGroup + 1
			end
		end
	else
		nGroup = 1
	end
	return nGroup
end

local function SetFrameSize(bLeave)
	if CTM_FRAME then
		if RaidGrid_CTM_Edition.nAutoLinkMode == 5 then
			local nGroup = GetGroupTotal()
			local w = 128 * nGroup
			local _, h = CTM_FRAME:GetSize()
			w = w * RaidGrid_CTM_Edition.fScaleX
			CTM_FRAME:SetSize(w, h)
			CTM_FRAME:SetDragArea(0, 0, w, h)
			CTM_FRAME:Lookup("", "Handle_BG/Image_Title_BG"):SetSize(w, h)
			if bLeave then
				local w = 128
				if RaidGrid_CTM_Edition.fScaleX > 1 then
					w = w * RaidGrid_CTM_Edition.fScaleX
				end
				CTM_FRAME:Lookup("", "Handle_BG/Image_Title_BG"):SetSize(w, h)
			end
		else
			local w = 128
			local _, h = CTM_FRAME:GetSize()
			CTM_FRAME:SetSize(w, h)
			CTM_FRAME:SetDragArea(0, 0, w, h)
			CTM_FRAME:Lookup("", "Handle_BG/Image_Title_BG"):SetSize(w, h)
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
	Grid_CTM:CloseParty()
	Grid_CTM:ReloadParty()
end

local function UpdateAnchor(frame)
	local a = RaidGrid_CTM_Edition.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("LEFTCENTER", 0, 0, "LEFTCENTER", 100, -200)
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
	this:RegisterEvent("TARGET_CHANGE")
	this:RegisterEvent("BUFF_UPDATE")
	-- 拍团部分 arg0 0=T人 1=分工资
	this:RegisterEvent("TEAM_VOTE_REQUEST")
	-- arg0 回应状态 arg1 dwID arg2 同意=1 反对=0
	this:RegisterEvent("TEAM_VOTE_RESPOND")
	-- this:RegisterEvent("TEAM_INCOMEMONEY_CHANGE_NOTIFY")
	--
	this:RegisterEvent("JH_RAID_REC_BUFF")
	this:RegisterEvent("GKP_RECORD_TOTAL")
	if GetClientPlayer() then
		UpdateAnchor(this)
		Grid_CTM:AutoLinkAllPanel()
	end
	SetFrameSize(true)
end
-------------------------------------------------
-- 拖动窗体 OnFrameDrag对于较大的窗口 掉帧严重
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
		Grid_CTM:CallRefreshImages(arg1, true, true, nil, true)
		Grid_CTM:CallDrawHPMP(arg1, true)
	elseif szEvent == "PARTY_ADD_MEMBER" then
		if Grid_CTM:GetPartyFrame(arg2) then
			Grid_CTM:DrawParty(arg2)
		else
			Grid_CTM:CreatePanel(arg2)
			Grid_CTM:DrawParty(arg2)
			SetFrameSize(true)
		end
		if RaidGrid_CTM_Edition.nAutoLinkMode ~= 5 then
			Grid_CTM:AutoLinkAllPanel()
		end
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
				Grid_CTM:DrawParty(arg3)
			end
			if RaidGrid_CTM_Edition.nAutoLinkMode ~= 5 then
				Grid_CTM:AutoLinkAllPanel()
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
		Grid_CTM:CallRefreshImages(arg1, false, true, nil, true)
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
	elseif szEvent == "TEAM_VOTE_REQUEST" then
		if arg0 == 1 then
			TEAM_VOTE_REQUEST = {}
			local team = GetClientTeam()
			for k, v in ipairs(team.GetTeamMemberList()) do
				TEAM_VOTE_REQUEST[v] = false
			end
			if JH.IsLeader() then
				Grid_CTM:Send_RaidReadyConfirm()
			end
		end
	elseif szEvent == "TEAM_VOTE_RESPOND" then
		if arg0 == 1 and not IsEmpty(TEAM_VOTE_REQUEST) then
			Grid_CTM:ChangeReadyConfirm(arg1, arg2 == 1)
			if arg2 == 1 then
				TEAM_VOTE_REQUEST[arg1] = true
			end
			local team = GetClientTeam()
			local num = #team.GetTeamMemberList()
			local agree = 0
			for k, v in pairs(TEAM_VOTE_REQUEST) do
				if v then
					agree = agree + 1
				end
			end
			OutputMessage("MSG_ANNOUNCE_YELLOW", _L("Team Members: %d, %d agree %d%%", num, agree, agree / num * 100))
		end
	elseif szEvent == "TEAM_INCOMEMONEY_CHANGE_NOTIFY" then
		-- 缺少API
		-- local nTotalRaidMoney = GetClientTeam().nInComeMoney
		-- if nTotalRaidMoney == 0 then
			-- TEAM_VOTE_REQUEST = {}
		-- end
	elseif szEvent == "RIAD_READY_CONFIRM_RECEIVE_ANSWER" then
		Grid_CTM:ChangeReadyConfirm(arg0, arg1 == 1)
	elseif szEvent == "TEAM_CHANGE_MEMBER_GROUP" then
		local me = GetClientPlayer()
		local team = GetClientTeam()
		local tSrcGropu = team.GetGroupInfo(arg1)
		-- SrcGroup
		if #tSrcGropu.MemberList == 0 then
			Grid_CTM:CloseParty(arg1)
			Grid_CTM:AutoLinkAllPanel()
		else
			Grid_CTM:DrawParty(arg1)
		end
		-- DstGroup
		if Grid_CTM:GetPartyFrame(arg2) then
			Grid_CTM:DrawParty(arg2)
		else
			Grid_CTM:CreatePanel(arg2)
			Grid_CTM:DrawParty(arg2)
		end
		Grid_CTM:RefreshGroupText()
		Grid_CTM:RefreshMark()
		if RaidGrid_CTM_Edition.nAutoLinkMode ~= 5 then
			Grid_CTM:AutoLinkAllPanel()
		end
	elseif szEvent == "PARTY_LEVEL_UP_RAID" then
		Grid_CTM:RefreshGroupText()
	elseif szEvent == "PARTY_LOOT_MODE_CHANGED" then
		UpdateLootImages()
	elseif szEvent == "TARGET_CHANGE" then
		Grid_CTM:RefreshTarget()
	elseif szEvent == "JH_RAID_REC_BUFF" then
		Grid_CTM:RecBuff(arg0, arg1, arg2, arg3)
	elseif szEvent == "BUFF_UPDATE" then
		if arg1 then return end
		local szName = GetBuffName(arg4 , arg8)
		local tab = RaidGrid_CTM_Edition.tBuffList[szName] or RaidGrid_CTM_Edition.tBuffList[tostring(arg4)]
		if tab and Table_BuffIsVisible(arg4, arg8) then
			if tab.bSelf and arg9 == UI_GetClientPlayerID() or not tab.bSelf then
				Grid_CTM:RecBuff(arg0, arg4, arg8, tab.col)
			end
		end
	elseif szEvent == "GKP_RECORD_TOTAL" then
		GKP_RECORD_TOTAL = arg0
	elseif szEvent == "UI_SCALED" then
		UpdateAnchor(this)
		Grid_CTM:AutoLinkAllPanel()
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

function RaidGrid_CTM_Edition.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Option" then
		local me = GetClientPlayer()
		local menu = {}
		if me.IsInRaid() then
			-- 团队就位
			table.insert(menu, { szOption = g_tStrings.STR_RAID_MENU_READY_CONFIRM,
				{ szOption = g_tStrings.STR_RAID_READY_CONFIRM_START, bDisable = not JH.IsLeader(), fnAction = function() Grid_CTM:Send_RaidReadyConfirm() end },
				{ szOption = g_tStrings.STR_RAID_READY_CONFIRM_RESET, bDisable = not JH.IsLeader(), fnAction = function() Grid_CTM:Clear_RaidReadyConfirm() end }
			})
			table.insert(menu, { bDevide = true })
		end
		-- 分配
		InsertDistributeMenu(menu, not JH.IsDistributer())
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
		if JH.IsInDungeon(true) then
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

function RaidGrid_CTM_Edition.OnMouseEnter()
	local me = GetClientPlayer()
	local nGroup = GetGroupTotal()
	if me.IsInRaid() and nGroup > 1 and RaidGrid_CTM_Edition.nAutoLinkMode == 5 then
		SetFrameSize()
		if GKP_RECORD_TOTAL > 0 and GKP then -- 第一个GKP
			local text = CTM_FRAME:Lookup("", "Text_GKP")
			text:SetText("GKP:" .. GKP_RECORD_TOTAL)
			text:SetFontColor(GKP.GetMoneyCol(GKP_RECORD_TOTAL))
			text:Show()
			text.OnItemRButtonClick = GKP.OpenPanel
			text:SetRelPos(128 * (nGroup - 1) * RaidGrid_CTM_Edition.fScaleX, 0)
			text:SetSize(125 * RaidGrid_CTM_Edition.fScaleX, 28)
			CTM_FRAME:Lookup("", ""):FormatAllItemPos()
		else
			CTM_FRAME:Lookup("", "Text_GKP"):Hide()
		end
	else
		CTM_FRAME:Lookup("", "Text_GKP"):Hide()
	end
end

function RaidGrid_CTM_Edition.OnMouseLeave()
	if not IsKeyDown("LButton") then
		SetFrameSize(true)
		CTM_FRAME:Lookup("", "Text_GKP"):Hide()
	end
end

function RaidGrid_CTM_Edition.OnFrameDragEnd()
	local w, h = this:GetSize()
	this:SetSize(128, h) -- 什么原因你懂的我就不说了
	this:CorrectPos()
	RaidGrid_CTM_Edition.tAnchor = GetFrameAnchor(this)
	Grid_CTM:AutoLinkAllPanel() -- fix screen pos
	this:SetSize(w, h)
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
function PS.OnPanelActive(frame)
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
			Grid_CTM:CallRefreshImages(true, false, true, nil, true)
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX+ 5, y = nY, txt = g_tStrings.STR_SHOW_KUNGFU, group = "icon", checked = RaidGrid_CTM_Edition.nShowIcon == 2 })
	:Click(function()
		RaidGrid_CTM_Edition.nShowIcon = 2
		if CTM_FRAME then
			Grid_CTM:CallRefreshImages(true, false, true, nil, true)
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX + 5, y = nY, txt = _L["Show Camp Icon"], group = "icon", checked = RaidGrid_CTM_Edition.nShowIcon == 3 })
	:Click(function()
		RaidGrid_CTM_Edition.nShowIcon = 3
		if CTM_FRAME then
			Grid_CTM:CallRefreshImages(true, false, true, nil, true)
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY, txt = _L["Show Text Force"], group = "icon", checked = RaidGrid_CTM_Edition.nShowIcon == 4 })
	:Click(function()
		RaidGrid_CTM_Edition.nShowIcon = 4
		if CTM_FRAME then
			Grid_CTM:CallRefreshImages(true, false, true, nil, true)
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()

	-- 其他
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.OTHER, font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_RAID_TARGET_ASSIST, checked = RaidGrid_CTM_Edition.bTempTargetEnable })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bTempTargetEnable = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Don't show Tip in fight"], checked = RaidGrid_CTM_Edition.bTempTargetFightTip })
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
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["configure"], font = 27 }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 8, txt = _L["Configuration name"] }):Pos_()
	ui:Append("WndEdit", { x = nX + 5, y = nY + 10, txt = Cataclysm_KEY }):Change(function(txt)
		Cataclysm_KEY = txt
		SetConfigure()
		if CTM_FRAME then
			RaidClosePanel()
			RaidCheckEnable()
		end
	end)
end
GUI.RegisterPanel(_L["Cataclysm"], 5389, _L["Panel"], PS)

local PS2 = {}
function PS2.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Grid Style"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Show AllGrid"], checked = RaidGrid_CTM_Edition.bShowAllGrid })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bShowAllGrid = bCheck
		if CTM_FRAME then
			Grid_CTM:CloseParty()
			Grid_CTM:ReloadParty()
		end
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["LifeBar Gradient"], checked = RaidGrid_CTM_Edition.bLifeGradient })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bLifeGradient = bCheck
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["ManaBar Gradient"], checked = RaidGrid_CTM_Edition.bManaGradient })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bManaGradient = bCheck
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = g_tStrings.STR_GUILD_NAME .. g_tStrings.STR_RAID_COLOR_NAME_SCHOOL, checked = RaidGrid_CTM_Edition.bColoredName })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bColoredName = bCheck
		if CTM_FRAME then
			Grid_CTM:CallRefreshImages(true, false, false, nil, true)
			Grid_CTM:CallDrawHPMP(true ,true)
		end
	end):Pos_()

	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = g_tStrings.STR_RAID_DISTANCE, checked = RaidGrid_CTM_Edition.bEnableDistance })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bEnableDistance = bCheck
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY, txt = g_tStrings.STR_ALPHA }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 2 })
	:Range(1, 100, 99):Value(RaidGrid_CTM_Edition.nAlpha / 255 * 100):Change(function(nVal)
		RaidGrid_CTM_Edition.nAlpha = nVal / 100 * 255
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()


	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.BACK_COLOR, font = 27 }):Pos_()
	nX = ui:Append("WndRadioBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_RAID_COLOR_NAME_NONE, group = "BACK_COLOR", checked = RaidGrid_CTM_Edition.nBGClolrMode == 0 })
	:Click(function()
		RaidGrid_CTM_Edition.nBGClolrMode = 0
		JH.OpenPanel(_L["Grid Style"])
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX+ 5, y = nY + 10, txt = _L["Colored according to the distance"], group = "BACK_COLOR", checked = RaidGrid_CTM_Edition.nBGClolrMode == 1 })
	:Click(function()
		RaidGrid_CTM_Edition.nBGClolrMode = 1
		JH.OpenPanel(_L["Grid Style"])
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = g_tStrings.STR_RAID_COLOR_NAME_SCHOOL, group = "BACK_COLOR", checked = RaidGrid_CTM_Edition.nBGClolrMode == 2 })
	:Click(function()
		RaidGrid_CTM_Edition.nBGClolrMode = 2
		JH.OpenPanel(_L["Grid Style"])
		if CTM_FRAME then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()

	if RaidGrid_CTM_Edition.nBGClolrMode ~= 2 then
		if RaidGrid_CTM_Edition.nBGClolrMode == 1 then
			nX, nY = ui:Append("WndButton3", { x = 10, y = nY, txt = _L["Edit Distance Level"] })
			:Click(function()
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
						JH.OpenPanel(_L["Grid Style"])
					end
				end)
			end):Pos_()
		end
		for i = 1, #RaidGrid_CTM_Edition.tDistanceLevel do
			local n = RaidGrid_CTM_Edition.tDistanceLevel[i - 1] or 0
			local txt = n .. g_tStrings.STR_METER .. " - " .. RaidGrid_CTM_Edition.tDistanceLevel[i] .. g_tStrings.STR_METER .. g_tStrings.BACK_COLOR
			if RaidGrid_CTM_Edition.nBGClolrMode == 0 then
				txt = g_tStrings.BACK_COLOR
			end
			if RaidGrid_CTM_Edition.nBGClolrMode ~= 1 and i > 1 then
				break
			end
			nX = ui:Append("Text", { x = 10, y = nY, txt = txt }):Pos_()
			nX, nY = ui:Append("Shadow", "BG_" .. i, { w = 22, h = 22, x = 280, y = nY + 3, color = RaidGrid_CTM_Edition.tDistanceCol[i] }):Click(function()
				GUI.OpenColorTablePanel(function(r, g, b)
					RaidGrid_CTM_Edition.tDistanceCol[i] = { r, g, b }
					ui:Fetch("BG_" .. i):Color(r, g, b)
					if CTM_FRAME then
						Grid_CTM:CallDrawHPMP(true, true)
					end
				end)
			end):Pos_()
		end
	end

	nX = ui:Append("Text", { x = 10, y = nY, txt = g_tStrings.STR_RAID_DISTANCE_M4 }):Pos_()
	nX, nY = ui:Append("Shadow", "STR_RAID_DISTANCE_M4", { w = 22, h = 22, x = 280, y = nY + 3, color = RaidGrid_CTM_Edition.tOtherCol[3] }):Click(function()
		GUI.OpenColorTablePanel(function(r, g, b)
			RaidGrid_CTM_Edition.tOtherCol[3] = { r, g, b }
			ui:Fetch("STR_RAID_DISTANCE_M4"):Color(r, g, b)
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY, txt = g_tStrings.STR_GUILD_OFFLINE .. g_tStrings.BACK_COLOR }):Pos_()
	nX, nY = ui:Append("Shadow", "STR_GUILD_OFFLINE", { w = 22, h = 22, x = 280, y = nY + 3, color = RaidGrid_CTM_Edition.tOtherCol[2] }):Click(function()
		GUI.OpenColorTablePanel(function(r, g, b)
			RaidGrid_CTM_Edition.tOtherCol[2] = { r, g, b }
			ui:Fetch("STR_GUILD_OFFLINE"):Color(r, g, b)
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY, txt = g_tStrings.STR_SKILL_MANA .. g_tStrings.BACK_COLOR }):Pos_()
	nX, nY = ui:Append("Shadow", "STR_SKILL_MANA", { w = 22, h = 22, x = 280, y = nY + 3, color = RaidGrid_CTM_Edition.tManaColor }):Click(function()
		GUI.OpenColorTablePanel(function(r, g, b)
			RaidGrid_CTM_Edition.tManaColor = { r, g, b }
			ui:Fetch("STR_SKILL_MANA"):Color(r, g, b)
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()

end
GUI.RegisterPanel(_L["Grid Style"], 6233, _L["Panel"], PS2)

local PS3 = {}
function PS3.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Interface settings"], font = 27 }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 10, txt = _L["Interface Width"]}):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 12, h = 25, w = 250 })
	:Range(50, 250, 200):Value(RaidGrid_CTM_Edition.fScaleX * 100):Change(function(nVal)
		nVal = nVal / 100
		local nNewX, nNewY = nVal / RaidGrid_CTM_Edition.fScaleX, RaidGrid_CTM_Edition.fScaleY / RaidGrid_CTM_Edition.fScaleY
		RaidGrid_CTM_Edition.fScaleX = nVal
		if CTM_FRAME then
			Grid_CTM:Scale(nNewX, nNewY)
		end
	end):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY, txt = _L["Interface Height"]}):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 2, h = 25, w = 250 })
	:Range(50, 250, 200):Value(RaidGrid_CTM_Edition.fScaleY * 100):Change(function(nVal)
		nVal = nVal / 100
		local nNewX, nNewY = RaidGrid_CTM_Edition.fScaleX / RaidGrid_CTM_Edition.fScaleX, nVal / RaidGrid_CTM_Edition.fScaleY
		RaidGrid_CTM_Edition.fScaleY = nVal
		if CTM_FRAME then
			Grid_CTM:Scale(nNewX, nNewY)
		end
	end):Pos_()
	-- 字体修改
	nX = ui:Append("WndButton2", { x = 10, y = nY, txt = g_tStrings.STR_GUILD_NAME .. g_tStrings.FONT })
	:Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			RaidGrid_CTM_Edition.nFont = nFont
			if CTM_FRAME then
				Grid_CTM:CallRefreshImages(true, false, false, nil, true)
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()
	nX, nY = ui:Append("WndButton2", { x = nX + 5, y = nY, txt = g_tStrings.STR_RAID_LIFE_SHOW .. g_tStrings.FONT })
	:Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			RaidGrid_CTM_Edition.nLifeFont = nFont
			if CTM_FRAME then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.OTHER, font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Show Group Number"], checked = RaidGrid_CTM_Edition.bShowGropuNumber })
	:Click(function(bCheck)
		RaidGrid_CTM_Edition.bShowGropuNumber = bCheck
		if CTM_FRAME then
			Grid_CTM:CloseParty()
			Grid_CTM:ReloadParty()
		end
	end):Pos_()

	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Arrangement"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY + 10, txt = _L["One lines: 5/0"], group = "Arrangement", checked = RaidGrid_CTM_Edition.nAutoLinkMode == 5 })
	:Click(function()
		RaidGrid_CTM_Edition.nAutoLinkMode = 5
		if CTM_FRAME then
			Grid_CTM:AutoLinkAllPanel()
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Two lines: 1/4"], group = "Arrangement", checked = RaidGrid_CTM_Edition.nAutoLinkMode == 1 })
	:Click(function()
		RaidGrid_CTM_Edition.nAutoLinkMode = 1
		if CTM_FRAME then
			Grid_CTM:AutoLinkAllPanel()
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Two lines: 2/3"], group = "Arrangement", checked = RaidGrid_CTM_Edition.nAutoLinkMode == 2 })
	:Click(function()
		RaidGrid_CTM_Edition.nAutoLinkMode = 2
		if CTM_FRAME then
			Grid_CTM:AutoLinkAllPanel()
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Two lines: 3/2"], group = "Arrangement", checked = RaidGrid_CTM_Edition.nAutoLinkMode == 3 })
	:Click(function()
		RaidGrid_CTM_Edition.nAutoLinkMode = 3
		if CTM_FRAME then
			Grid_CTM:AutoLinkAllPanel()
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Two lines: 4/1"], group = "Arrangement", checked = RaidGrid_CTM_Edition.nAutoLinkMode == 4 })
	:Click(function()
		RaidGrid_CTM_Edition.nAutoLinkMode = 4
		if CTM_FRAME then
			Grid_CTM:AutoLinkAllPanel()
		end
	end):Pos_()
end
GUI.RegisterPanel(_L["Interface settings"], 6060, _L["Panel"], PS3)

-- 解析
local function GetListText(tab)
	local tName = {}
	for k, v in pairs(tab) do
		if type(k) == "string" then
			if v.bSelf then
				k = k .. "|self"
			end
			table.insert(tName, k)
		end
	end
	return table.concat(tName, "\n")
end

local PS4 = {}
function PS4.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Buff settings"], font = 27 }):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY + 10, txt = _L["Max buff count"]}):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 12, txt = "" })
	:Range(0, 10):Value(RaidGrid_CTM_Edition.nMaxShowBuff):Change(function(nVal)
		RaidGrid_CTM_Edition.nMaxShowBuff = nVal
	end):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY, txt = _L["buff Size"]}):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = RaidGrid_CTM_Edition.bAutoBuffSize, txt = g_tStrings.STR_OPTIMIZE_AUTO }):Click(function(bCheck)
		RaidGrid_CTM_Edition.bAutoBuffSize = bCheck
		ui:Fetch("BuffSize"):Enable(not bCheck)
	end):Pos_()
	nX, nY = ui:Append("WndTrackBar", "BuffSize", { x = nX + 5, y = nY + 2, h = 25, w = 200 })
	:Enable(not RaidGrid_CTM_Edition.bAutoBuffSize):Range(50, 200, 150):Value(RaidGrid_CTM_Edition.fBuffScale * 100):Change(function(nVal)
		RaidGrid_CTM_Edition.fBuffScale = nVal / 100
		if CTM_FRAME then
			Grid_CTM:RecBuff(UI_GetClientPlayerID(), 684, 1, nil, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Buff Staring"], checked = RaidGrid_CTM_Edition.bStaring }):Click(function(bCheck)
		RaidGrid_CTM_Edition.bStaring = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Show Buff Time"], checked = RaidGrid_CTM_Edition.bShowBuffTime }):Click(function(bCheck)
		RaidGrid_CTM_Edition.bShowBuffTime = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Show Buff Num"], checked = RaidGrid_CTM_Edition.bShowBuffNum }):Click(function(bCheck)
		RaidGrid_CTM_Edition.bShowBuffNum = bCheck
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Manually add (One per line)"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndEdit",{ x = 10, y = nY + 10, w = 450, h = 150, limit = 4096, multi = true})
	:Text(GetListText(RaidGrid_CTM_Edition.tBuffList)):Change(function(szText)
		local t = {}
		for _, v in ipairs(JH.Split(szText, "\n")) do
			v = JH.Trim(v)
			if v ~= "" then
				local a = JH.Split(v, "|")
				t[JH.Trim(a[1])] = {
					bSelf = a[2] and true or false
				}
			end
		end
		RaidGrid_CTM_Edition.tBuffList = t
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Tips"], font = 27 }):Pos_()
	ui:Append("Text", { x = 10, y = nY + 5, txt = _L["Cataclysm_TIPS"], w = 500, h = 60 , multi = true }):Pos_()
end
GUI.RegisterPanel(_L["Buff settings"], 1498, _L["Panel"], PS4)

JH.RegisterEvent("LOADING_END", RaidCheckEnable)
JH.RegisterEvent("PARTY_UPDATE_BASE_INFO", function()
	RaidCheckEnable()
	PlaySound(SOUND.UI_SOUND, g_sound.Gift)
end)
JH.RegisterEvent("CTM_PANEL_TEAMATE", function()
	TeammatePanel_Switch(arg0)
end)
JH.RegisterEvent("CTM_PANEL_RAID", function()
	RaidPanel_Switch(arg0)
end)
local SaveConfig = function()
	JH.SaveLUAData(GetConfigurePath(), CTM_CONFIG_PLAYER)
end
JH.RegisterEvent("GAME_EXIT", SaveConfig)
JH.RegisterEvent("PLAYER_EXIT_GAME", SaveConfig)
JH.RegisterEvent("LOGIN_GAME", SetConfigure)

JH.AddonMenu(function()
	return { szOption = _L["Cataclysm Team Panel"], bCheck = true, bChecked = RaidGrid_CTM_Edition.bRaidEnable and not RaidGrid_CTM_Edition.bShowInRaid, fnAction = EnableTeamPanel }
end)
