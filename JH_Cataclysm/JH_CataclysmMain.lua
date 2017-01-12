-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   William Chan
-- @Last Modified time: 2017-01-10 14:53:49
local _L = JH.LoadLangPack
local Station, UI_GetClientPlayerID, Table_BuffIsVisible = Station, UI_GetClientPlayerID, Table_BuffIsVisible
local GetBuffName = JH.GetBuffName
local tostring = tostring

local CTM_CONFIG = {
	bDrag                = true,
	bRaidEnable          = false,
	bShowInRaid          = false,
	bEditMode            = false,
	bShowAllGrid         = false,
	tAnchor              = {},
	nAutoLinkMode        = 5,
	nHPShownMode2        = 2,
	nHPShownNumMode      = 3,
	nShowMP              = false,
	bHPHitAlert          = true,
	nColoredName         = 1,
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
	nAlpha               = 220,
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
	bShowEffect          = false, -- 五毒醉舞提示 万花距离提示 晚点做
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
	setmetatable(Cataclysm_Main, {
		__index = CTM_CONFIG_PLAYER,
		__newindex = CTM_CONFIG_PLAYER,
	})
	CTM_CONFIG_PLAYER.bFasterHP = false
end

local function GetFrame()
	return Station.Lookup("Normal/Cataclysm_Main")
end

local CTM_LOOT_MODE = {
	[PARTY_LOOT_MODE.FREE_FOR_ALL] = {"ui/Image/TargetPanel/Target.UITex", 60},
	[PARTY_LOOT_MODE.DISTRIBUTE]   = {"ui/Image/UICommon/CommonPanel2.UITex", 92},
	[PARTY_LOOT_MODE.GROUP_LOOT]   = {"ui/Image/UICommon/LoginCommon.UITex", 29},
	[PARTY_LOOT_MODE.BIDDING]      = {"ui/Image/UICommon/GoldTeam.UITex", 6},
}
local CTM_LOOT_QUALITY = {
	[2] = 2401,
	[3] = 2397,
	[4] = 2402,
	[5] = 2400,
}

local function CreateControlBar()
	local team         = GetClientTeam()
	local nLootMode    = team.nLootMode
	local nRollQuality = team.nRollQuality
	local frame        = GetFrame()
	local hContainer   = frame:Lookup("Container_Main")
	local szIniFile    = JH.GetAddonInfo().szRootPath .. "JH_Cataclysm/ui/Cataclysm_Button.ini"
	hContainer:Clear()
	-- 分配模式
	local line = 22
	local hLootMode = hContainer:AppendContentFromIni(szIniFile, "Wnd_LootMode")
	hLootMode:Lookup("", "Image_LootMode"):FromUITex(unpack(CTM_LOOT_MODE[nLootMode]))
	hLootMode:SetRelX((hContainer:GetAllContentCount() - 1) * line)
	if nLootMode == PARTY_LOOT_MODE.DISTRIBUTE then
		local hLootQuality = hContainer:AppendContentFromIni(szIniFile, "Wnd_LootQuality")
		hLootQuality:Lookup("", "Image_LootQuality"):FromIconID(CTM_LOOT_QUALITY[nRollQuality])
		hLootQuality:SetRelX((hContainer:GetAllContentCount() - 1) * line)
		local hGKP = hContainer:AppendContentFromIni(szIniFile, "Wnd_GKP")
		hGKP:SetRelX((hContainer:GetAllContentCount() - 1) * line)
	end
	-- 世界标记
	if JH.IsLeader() then
		local hWorldMark = hContainer:AppendContentFromIni(szIniFile, "Btn_WorldMark")
		hWorldMark:SetRelX((hContainer:GetAllContentCount() - 1) * line)
	end
	hContainer:FormatAllContentPos()
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

local function GetTeammateFrame()
	return Station.Lookup("Normal/Teammate")
end

local function RaidPanel_Switch(bOpen)
	local frame = Station.Lookup("Normal/RaidPanel_Main")
	if bOpen then
		if not frame then
			OpenRaidPanel()
		end
	else
		if frame then
			-- 有一点问题 会被加呼吸 根据判断
			if not GetTeammateFrame() then
				Wnd.OpenWindow("Teammate")
			end
			CloseRaidPanel()
			Wnd.CloseWindow("Teammate")
		end
	end
end

local function TeammatePanel_Switch(bOpen)
	local hFrame = GetTeammateFrame()
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

local function SetFrameSize(bEnter)
	local frame = GetFrame()
	if GetFrame() then
		local nGroup = GetGroupTotal()
		local nGroupEx = nGroup
		if Cataclysm_Main.nAutoLinkMode ~= 5 then
			nGroupEx = 1
		end
		local fScaleX = math.max(nGroupEx == 1 and 1 or 0, Cataclysm_Main.fScaleX)
		local w = 128 * nGroupEx * fScaleX
		local h = select(2, frame:GetSize())
		frame:SetW(w)
		if not bEnter then
			w = 128 * fScaleX
		end
		frame:SetDragArea(0, 0, w, h)
		frame:Lookup("", "Handle_BG/Image_Title_BG"):SetW(w)
	end
end

local function OpenCataclysmPanel()
	if not GetFrame() then
		Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "JH_Cataclysm/ui/Cataclysm_Main.ini", "Cataclysm_Main")
	end
end

local function CloseCataclysmPanel()
	if GetFrame() then
		Wnd.CloseWindow(GetFrame())
		Grid_CTM:CloseParty()
	end
end

local function CheckCataclysmEnable(szEvent)
	local me = GetClientPlayer()
	if not Cataclysm_Main.bRaidEnable then
		CloseCataclysmPanel()
		return false
	end
	if Cataclysm_Main.bShowInRaid and not me.IsInRaid() then
		CloseCataclysmPanel()
		return false
	end
	if not me.IsInParty() then
		CloseCataclysmPanel()
		return false
	end
	OpenCataclysmPanel()
	return true
end

local function ReloadCataclysmPanel()
	if GetFrame() then
		CreateControlBar()
		Grid_CTM:CloseParty()
		Grid_CTM:ReloadParty()
	end
end

local function UpdateAnchor(frame)
	local a = Cataclysm_Main.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("LEFTCENTER", 0, 0, "LEFTCENTER", 100, -200)
	end
end

-------------------------------------------------
-- 界面创建 事件注册
-------------------------------------------------
Cataclysm_Main = {
	GetFrame            = GetFrame,
	CloseCataclysmPanel = CloseCataclysmPanel,
	OpenCataclysmPanel  = OpenCataclysmPanel,
}
local Cataclysm_Main = Cataclysm_Main
function Cataclysm_Main.OnFrameCreate()
	if Cataclysm_Main.bFasterHP then
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
	this:RegisterEvent("PARTY_ROLL_QUALITY_CHANGED")
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("TARGET_CHANGE")
	this:RegisterEvent("BUFF_UPDATE")
	-- 拍团部分 arg0 0=T人 1=分工资
	this:RegisterEvent("TEAM_VOTE_REQUEST")
	-- arg0 回应状态 arg1 dwID arg2 同意=1 反对=0
	this:RegisterEvent("TEAM_VOTE_RESPOND")
	-- this:RegisterEvent("TEAM_INCOMEMONEY_CHANGE_NOTIFY")
	this:RegisterEvent("SYS_MSG")
	this:RegisterEvent("JH_KUNGFU_SWITCH")
	this:RegisterEvent("JH_RAID_REC_BUFF")
	this:RegisterEvent("GKP_RECORD_TOTAL")
	if GetClientPlayer() then
		UpdateAnchor(this)
		Grid_CTM:AutoLinkAllPanel()
	end
	SetFrameSize()
	CreateControlBar()
	this:EnableDrag(Cataclysm_Main.bDrag)
	-- 中间层数据 常用的
	this.hMember = this:CreateItemData(JH.GetAddonInfo().szRootPath .. "JH_Cataclysm/ui/item.ini", "Handle_RoleDummy")
	this.hBuff   = this:CreateItemData(JH.GetAddonInfo().szRootPath .. "JH_Cataclysm/ui/Item_Buff.ini", "Handle_Buff")

end
-------------------------------------------------
-- 拖动窗体 OnFrameDrag
-------------------------------------------------

function Cataclysm_Main.OnFrameDragSetPosEnd()
	Grid_CTM:AutoLinkAllPanel()
end

function Cataclysm_Main.OnFrameDragEnd()
	this:CorrectPos()
	Cataclysm_Main.tAnchor = GetFrameAnchor(this, "TOPLEFT")
	Grid_CTM:AutoLinkAllPanel() -- fix screen pos
end

-------------------------------------------------
-- 事件处理
-------------------------------------------------
function Cataclysm_Main.OnEvent(szEvent)
	if szEvent == "RENDER_FRAME_UPDATE" then
		Grid_CTM:CallDrawHPMP(true)
	elseif szEvent == "SYS_MSG" then
		if Cataclysm_Main.bShowEffect then
			if arg0 == "UI_OME_SKILL_EFFECT_LOG" and arg5 == 6252 and arg1 == UI_GetClientPlayerID() and arg9[SKILL_RESULT_TYPE.THERAPY] then
				Grid_CTM:CallEffect(arg2, 500)
			end
		end
	elseif szEvent == "PARTY_SYNC_MEMBER_DATA" then
		Grid_CTM:CallRefreshImages(arg1, true, true, nil, true)
		Grid_CTM:CallDrawHPMP(arg1, true)
	elseif szEvent == "PARTY_ADD_MEMBER" then
		if Grid_CTM:GetPartyFrame(arg2) then
			Grid_CTM:DrawParty(arg2)
		else
			Grid_CTM:CreatePanel(arg2)
			Grid_CTM:DrawParty(arg2)
			SetFrameSize()
		end
		if Cataclysm_Main.nAutoLinkMode ~= 5 then
			Grid_CTM:AutoLinkAllPanel()
		end
	elseif szEvent == "PARTY_DELETE_MEMBER" then
		local me = GetClientPlayer()
		if me.dwID == arg1 then
			CloseCataclysmPanel()
		else
			local team = GetClientTeam()
			local tGropu = team.GetGroupInfo(arg3)
			if #tGropu.MemberList == 0 then
				Grid_CTM:CloseParty(arg3)
				Grid_CTM:AutoLinkAllPanel()
			else
				Grid_CTM:DrawParty(arg3)
			end
			if Cataclysm_Main.nAutoLinkMode ~= 5 then
				Grid_CTM:AutoLinkAllPanel()
			end
		end
		SetFrameSize()
	elseif szEvent == "PARTY_DISBAND" then
		CloseCataclysmPanel()
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
		CreateControlBar()
	elseif szEvent == "PARTY_SET_FORMATION_LEADER" then
		Grid_CTM:RefresFormation()
	elseif szEvent == "PARTY_SET_MARK" then
		Grid_CTM:RefreshMark()
	-- elseif szEvent == "RIAD_READY_CONFIRM_RECEIVE_QUESTION" then
	elseif szEvent == "TEAM_VOTE_REQUEST" then
		if arg0 == 1 then
			if JH.IsLeader() then
				Grid_CTM:Send_RaidReadyConfirm(true)
			end
		end
	elseif szEvent == "TEAM_VOTE_RESPOND" then
		if arg0 == 1 then
			if JH.IsLeader() then
				Grid_CTM:ChangeReadyConfirm(arg1, arg2 == 1)
			end
		end
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
		if not Grid_CTM:GetPartyFrame(arg2) then
			Grid_CTM:CreatePanel(arg2)
		end
		Grid_CTM:DrawParty(arg2)
		Grid_CTM:RefreshGroupText()
		Grid_CTM:RefreshMark()
		if Cataclysm_Main.nAutoLinkMode ~= 5 then
			Grid_CTM:AutoLinkAllPanel()
		end
		SetFrameSize()
	elseif szEvent == "PARTY_LEVEL_UP_RAID" then
		Grid_CTM:RefreshGroupText()
	elseif szEvent == "PARTY_LOOT_MODE_CHANGED" then
		CreateControlBar()
	elseif szEvent == "PARTY_ROLL_QUALITY_CHANGED" then
		CreateControlBar()
	elseif szEvent == "JH_KUNGFU_SWITCH" then
		Grid_CTM:KungFuSwitch(arg0)
	elseif szEvent == "TARGET_CHANGE" then
		-- oldid， oldtype, newid, newtype
		Grid_CTM:RefreshTarget(arg0, arg1, arg2, arg3)
	elseif szEvent == "JH_RAID_REC_BUFF" then
		Grid_CTM:RecBuff(arg0, arg1)
	elseif szEvent == "BUFF_UPDATE" then
		if arg1 then return end
		local szName = GetBuffName(arg4, arg8)
		local tab = Cataclysm_Main.tBuffList[szName] or Cataclysm_Main.tBuffList[tostring(arg4)]
		if tab and Table_BuffIsVisible(arg4, arg8) then
			if tab.bSelf and arg9 == UI_GetClientPlayerID() or not tab.bSelf then
				Grid_CTM:RecBuff(arg0, {
					dwID      = arg4,
					nLevel    = 0,
					col       = tab.col,
					bOnlySelf = tab.bSelf
				})
			end
		end
	elseif szEvent == "GKP_RECORD_TOTAL" then
		GKP_RECORD_TOTAL = arg0
	elseif szEvent == "UI_SCALED" then
		UpdateAnchor(this)
		Grid_CTM:AutoLinkAllPanel()
	elseif szEvent == "LOADING_END" then -- 勿删
		ReloadCataclysmPanel()
		RaidPanel_Switch(DEBUG)
		TeammatePanel_Switch(false)
		SetFrameSize()
	end
end

function Cataclysm_Main.OnFrameBreathe()
	local me = GetClientPlayer()
	if not me then return end
	Grid_CTM:RefreshDistance()
	Grid_CTM:RefresBuff()
	if Cataclysm_Main.bShowTargetTargetAni then
		Grid_CTM:RefreshTTarget()
	end
	-- kill System Panel
	RaidPanel_Switch(DEBUG)
	TeammatePanel_Switch(false)
end

function Cataclysm_Main.OnLButtonClick()
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
			table.insert(menu, { szOption = string.gsub(g_tStrings.STR_RAID_MENU_RAID_EDIT, "Ctrl", "Alt"), bDisable = not JH.IsLeader() or not me.IsInRaid(), bCheck = true, bChecked = Cataclysm_Main.bEditMode, fnAction = function()
				Cataclysm_Main.bEditMode = not Cataclysm_Main.bEditMode
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
		if JH.bDebugClient then
			table.insert(menu, { bDevide = true })
			table.insert(menu, { szOption = "DEBUG", bCheck = true, bChecked = DEBUG, fnAction = function()
				DEBUG = not DEBUG
			end	})
		end
		local nX, nY = Cursor.GetPos(true)
		menu.x, menu.y = nX, nY
		PopupMenu(menu)
	elseif szName == "Btn_WorldMark" then
		local me  = GetClientPlayer()
		local dwMapID = me.GetMapID()
		local nMapType = select(2, GetMapParams(dwMapID))
	    if not nMapType or nMapType ~= MAP_TYPE.DUNGEON then
			OutputMessage("MSG_ANNOUNCE_RED", g_tStrings.STR_WORLD_MARK)
			return
		end
		Wnd.ToggleWindow("WorldMark")
	elseif szName == "Wnd_GKP" and GKP then
		return GKP.TogglePanel()
	elseif szName == "Wnd_LootMode" or szName == "Wnd_LootQuality" then
		if JH.IsDistributer() then
			local menu = {}
			if szName == "Wnd_LootMode" then
				InsertDistributeMenu(menu, not JH.IsDistributer())
				PopupMenu(menu[1])
			elseif szName == "Wnd_LootQuality" then
				InsertDistributeMenu(menu, not JH.IsDistributer())
				PopupMenu(menu[2])
			end
		else
			return JH.Sysmsg(_L["You are not the distrubutor."])
		end
	end
end

function Cataclysm_Main.OnLButtonDown()
	Grid_CTM:BringToTop()
end

function Cataclysm_Main.OnRButtonDown()
	Grid_CTM:BringToTop()
end


function Cataclysm_Main.OnMouseLeave()
	local szName = this:GetName()
	if szName == "Wnd_GKP" or szName == "Wnd_LootMode" or szName == "Wnd_LootQuality" then
		this:SetAlpha(220)
	end
	if not IsKeyDown("LButton") then
		SetFrameSize()
	end
end

function Cataclysm_Main.OnMouseEnter()
	local szName = this:GetName()
	if szName == "Wnd_GKP" or szName == "Wnd_LootMode" or szName == "Wnd_LootQuality" then
		this:SetAlpha(255)
	end
	SetFrameSize(true)
end

local function EnableTeamPanel()
	Cataclysm_Main.bRaidEnable = not Cataclysm_Main.bRaidEnable
	if CheckCataclysmEnable() then
		ReloadCataclysmPanel()
	end
	if not Cataclysm_Main.bRaidEnable then
		local me = GetClientPlayer()
		if me.IsInRaid() then
			FireUIEvent("CTM_PANEL_RAID", true)
		elseif me.IsInParty() then
			FireUIEvent("CTM_PANEL_TEAMATE", true)
		end
	end
end
local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Cataclysm Team Panel"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Enable Cataclysm Team Panel"], checked = Cataclysm_Main.bRaidEnable }):Click(EnableTeamPanel):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Only in team"], checked = Cataclysm_Main.bShowInRaid })
	:Click(function(bCheck)
		Cataclysm_Main.bShowInRaid = bCheck
		if CheckCataclysmEnable() then
			ReloadCataclysmPanel()
		end
		local me = GetClientPlayer()
		if me.IsInParty() and not me.IsInRaid() then
			FireUIEvent("CTM_PANEL_TEAMATE", Cataclysm_Main.bShowInRaid)
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x= nX + 5, y = nY + 10, txt = g_tStrings.WINDOW_LOCK, checked = not Cataclysm_Main.bDrag })
	:Click(function(bCheck)
		Cataclysm_Main.bDrag = not bCheck
		if GetFrame() then
			GetFrame():EnableDrag(not bCheck)
		end
	end):Pos_()
	-- 提醒框
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.STR_RAID_TIP_IMAGE, font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_RAID_TIP_TARGET, checked = Cataclysm_Main.bShowTargetTargetAni })
	:Click(function(bCheck)
		Cataclysm_Main.bShowTargetTargetAni = bCheck
		if GetFrame() then
			Grid_CTM:RefreshTTarget()
		end
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Show distance"], checked = Cataclysm_Main.bShowDistance })
	:Click(function(bCheck)
		Cataclysm_Main.bShowDistance = bCheck
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Show ManaCount"], checked = Cataclysm_Main.nShowMP })
	:Click(function(bCheck)
		Cataclysm_Main.nShowMP = bCheck
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Attack Warning"], checked = Cataclysm_Main.bHPHitAlert })
	:Click(function(bCheck)
		Cataclysm_Main.bHPHitAlert = bCheck
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	local me = GetClientPlayer()
	if me.dwForceID == 6 then
		nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["ZuiWu Effect"], color = { JH.GetForceColor(6) }, checked = Cataclysm_Main.bShowEffect })
		:Click(function(bCheck)
			Cataclysm_Main.bShowEffect = bCheck
		end):Pos_()
	end
	-- 血量显示
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.STR_RAID_LIFE_SHOW .. _L["& Icon"], font = 27 }):Pos_()
	nX = ui:Append("WndRadioBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_RAID_LIFE_LEFT, group = "lifemode", checked = Cataclysm_Main.nHPShownMode2 == 2 })
	:Click(function()
		Cataclysm_Main.nHPShownMode2 = 2
		ui:Fetch("lifval1"):Enable(true)
		ui:Fetch("lifval2"):Enable(true)
		ui:Fetch("lifval3"):Enable(true)
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX+ 5, y = nY + 10, txt = g_tStrings.STR_RAID_LIFE_LOSE, group = "lifemode", checked = Cataclysm_Main.nHPShownMode2 == 1 })
	:Click(function()
		Cataclysm_Main.nHPShownMode2 = 1
		ui:Fetch("lifval1"):Enable(true)
		ui:Fetch("lifval2"):Enable(true)
		ui:Fetch("lifval3"):Enable(true)
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX+ 5, y = nY + 10, txt = g_tStrings.STR_RAID_LIFE_HIDE, group = "lifemode", checked = Cataclysm_Main.nHPShownMode2 == 0 })
	:Click(function()
		Cataclysm_Main.nHPShownMode2 = 0
		ui:Fetch("lifval1"):Enable(false)
		ui:Fetch("lifval2"):Enable(false)
		ui:Fetch("lifval3"):Enable(false)
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	-- 数值
	nX = ui:Append("WndRadioBox", "lifval1", { x = 10, y = nY, txt = _L["Show Format value"], group = "lifval", checked = Cataclysm_Main.nHPShownNumMode == 1 })
	:Enable(Cataclysm_Main.nHPShownMode2 ~= 0):Click(function()
		Cataclysm_Main.nHPShownNumMode = 1
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", "lifval2", { x = nX+ 5, y = nY, txt = _L["Show Percentage value"], group = "lifval", checked = Cataclysm_Main.nHPShownNumMode == 2 })
	:Enable(Cataclysm_Main.nHPShownMode2 ~= 0):Click(function()
		Cataclysm_Main.nHPShownNumMode = 2
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", "lifval3", { x = nX+ 5, y = nY, txt = _L["Show full value"], group = "lifval", checked = Cataclysm_Main.nHPShownNumMode == 3 })
	:Enable(Cataclysm_Main.nHPShownMode2 ~= 0):Click(function()
		Cataclysm_Main.nHPShownNumMode = 3
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	-- Icon
	nX = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Show Force Icon"], group = "icon", checked = Cataclysm_Main.nShowIcon == 1 })
	:Click(function()
		Cataclysm_Main.nShowIcon = 1
		if GetFrame() then
			Grid_CTM:CallRefreshImages(true, false, true, nil, true)
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX+ 5, y = nY, txt = g_tStrings.STR_SHOW_KUNGFU, group = "icon", checked = Cataclysm_Main.nShowIcon == 2 })
	:Click(function()
		Cataclysm_Main.nShowIcon = 2
		if GetFrame() then
			Grid_CTM:CallRefreshImages(true, false, true, nil, true)
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX + 5, y = nY, txt = _L["Show Camp Icon"], group = "icon", checked = Cataclysm_Main.nShowIcon == 3 })
	:Click(function()
		Cataclysm_Main.nShowIcon = 3
		if GetFrame() then
			Grid_CTM:CallRefreshImages(true, false, true, nil, true)
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY, txt = _L["Show Text Force"], group = "icon", checked = Cataclysm_Main.nShowIcon == 4 })
	:Click(function()
		Cataclysm_Main.nShowIcon = 4
		if GetFrame() then
			Grid_CTM:CallRefreshImages(true, false, true, nil, true)
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()

	-- 其他
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.OTHER, font = 27 }):Pos_()
	nX  = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_RAID_TARGET_ASSIST, checked = Cataclysm_Main.bTempTargetEnable })
	:Click(function(bCheck)
		Cataclysm_Main.bTempTargetEnable = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, txt = _L["Don't show Tip in fight"], checked = Cataclysm_Main.bTempTargetFightTip })
	:Click(function(bCheck)
		Cataclysm_Main.bTempTargetFightTip = bCheck
	end):Pos_()
	-- nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Faster Refresh HP(Greater performance loss)"], checked = Cataclysm_Main.bFasterHP, enable = false })
	-- :Click(function(bCheck)
	-- 	Cataclysm_Main.bFasterHP = bCheck
	-- 	if GetFrame() then
	-- 		if bCheck then
	-- 			GetFrame():RegisterEvent("RENDER_FRAME_UPDATE")
	-- 		else
	-- 			GetFrame():UnRegisterEvent("RENDER_FRAME_UPDATE")
	-- 		end
	-- 	end
	-- end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["configure"], font = 27 }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 8, txt = _L["Configuration name"] }):Pos_()
	ui:Append("WndEdit", { x = nX + 5, y = nY + 10, txt = Cataclysm_KEY }):Change(function(txt)
		Cataclysm_KEY = txt
		SetConfigure()
		if GetFrame() then
			CloseCataclysmPanel()
			if CheckCataclysmEnable() then
				ReloadCataclysmPanel()
			end
		end
	end)
end
GUI.RegisterPanel(_L["Cataclysm"], { "ui/Image/UICommon/RaidTotal.uitex", 62 }, _L["Panel"], PS)

local PS2 = {}
function PS2.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Grid Style"], font = 27 }):Pos_()

	nX = ui:Append("WndRadioBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_GUILD_NAME .. g_tStrings.STR_RAID_COLOR_NAME_SCHOOL, group = "namecolor", checked = Cataclysm_Main.nColoredName == 1 })
	:Click(function()
		Cataclysm_Main.nColoredName = 1
		if GetFrame() then
			Grid_CTM:CallRefreshImages(true, false, false, nil, true)
			Grid_CTM:CallDrawHPMP(true ,true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = g_tStrings.STR_GUILD_NAME .. g_tStrings.STR_RAID_COLOR_NAME_CAMP, group = "namecolor", checked = Cataclysm_Main.nColoredName == 2 })
	:Click(function()
		Cataclysm_Main.nColoredName = 2
		if GetFrame() then
			Grid_CTM:CallRefreshImages(true, false, false, nil, true)
			Grid_CTM:CallDrawHPMP(true ,true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = g_tStrings.STR_GUILD_NAME .. g_tStrings.STR_RAID_COLOR_NAME_NONE, group = "namecolor", checked = Cataclysm_Main.nColoredName == 0 })
	:Click(function()
		Cataclysm_Main.nColoredName = 0
		if GetFrame() then
			Grid_CTM:CallRefreshImages(true, false, false, nil, true)
			Grid_CTM:CallDrawHPMP(true ,true)
		end
	end):Pos_()

	-- 字体修改
	nX, nY = ui:Append("WndButton2", { x = 400, y = nY + 10, txt = g_tStrings.STR_GUILD_NAME .. g_tStrings.FONT })
	:Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			Cataclysm_Main.nFont = nFont
			if GetFrame() then
				Grid_CTM:CallRefreshImages(true, false, false, nil, true)
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Show AllGrid"], checked = Cataclysm_Main.bShowAllGrid })
	:Click(function(bCheck)
		Cataclysm_Main.bShowAllGrid = bCheck
		if GetFrame() then
			Grid_CTM:CloseParty()
			Grid_CTM:ReloadParty()
		end
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, txt = _L["LifeBar Gradient"], checked = Cataclysm_Main.bLifeGradient })
	:Click(function(bCheck)
		Cataclysm_Main.bLifeGradient = bCheck
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, txt = _L["ManaBar Gradient"], checked = Cataclysm_Main.bManaGradient })
	:Click(function(bCheck)
		Cataclysm_Main.bManaGradient = bCheck
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndButton2", { x = 400, y = nY, txt = g_tStrings.STR_RAID_LIFE_SHOW .. g_tStrings.FONT })
	:Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			Cataclysm_Main.nLifeFont = nFont
			if GetFrame() then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()

	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = g_tStrings.STR_RAID_DISTANCE, checked = Cataclysm_Main.bEnableDistance })
	:Click(function(bCheck)
		Cataclysm_Main.bEnableDistance = bCheck
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()

	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.BACK_COLOR, font = 27 }):Pos_()
	nX = ui:Append("WndRadioBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_RAID_COLOR_NAME_NONE, group = "BACK_COLOR", checked = Cataclysm_Main.nBGClolrMode == 0 })
	:Click(function()
		Cataclysm_Main.nBGClolrMode = 0
		JH.OpenPanel(_L["Grid Style"])
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX+ 5, y = nY + 10, txt = _L["Colored according to the distance"], group = "BACK_COLOR", checked = Cataclysm_Main.nBGClolrMode == 1 })
	:Click(function()
		Cataclysm_Main.nBGClolrMode = 1
		JH.OpenPanel(_L["Grid Style"])
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = g_tStrings.STR_RAID_COLOR_NAME_SCHOOL, group = "BACK_COLOR", checked = Cataclysm_Main.nBGClolrMode == 2 })
	:Click(function()
		Cataclysm_Main.nBGClolrMode = 2
		JH.OpenPanel(_L["Grid Style"])
		if GetFrame() then
			Grid_CTM:CallDrawHPMP(true, true)
		end
	end):Pos_()

	if Cataclysm_Main.nBGClolrMode ~= 2 then
		if Cataclysm_Main.nBGClolrMode == 1 then
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
						Cataclysm_Main.tDistanceLevel = tt
						Cataclysm_Main.tDistanceCol = {}
						for k, v in ipairs(t) do
							table.insert(Cataclysm_Main.tDistanceCol, { 255, 255, 255 })
						end
						JH.OpenPanel(_L["Grid Style"])
					end
				end)
			end):Pos_()
		end
		for i = 1, #Cataclysm_Main.tDistanceLevel do
			local n = Cataclysm_Main.tDistanceLevel[i - 1] or 0
			local txt = n .. g_tStrings.STR_METER .. " - " .. Cataclysm_Main.tDistanceLevel[i] .. g_tStrings.STR_METER .. g_tStrings.BACK_COLOR
			if Cataclysm_Main.nBGClolrMode == 0 then
				txt = g_tStrings.BACK_COLOR
			end
			if Cataclysm_Main.nBGClolrMode ~= 1 and i > 1 then
				break
			end
			nX = ui:Append("Text", { x = 10, y = nY, txt = txt }):Pos_()
			nX, nY = ui:Append("Shadow", "BG_" .. i, { w = 22, h = 22, x = 280, y = nY + 3, color = Cataclysm_Main.tDistanceCol[i] }):Click(function()
				GUI.OpenColorTablePanel(function(r, g, b)
					Cataclysm_Main.tDistanceCol[i] = { r, g, b }
					ui:Fetch("BG_" .. i):Color(r, g, b)
					if GetFrame() then
						Grid_CTM:CallDrawHPMP(true, true)
					end
				end)
			end):Pos_()
		end
	end

	nX = ui:Append("Text", { x = 10, y = nY, txt = g_tStrings.STR_RAID_DISTANCE_M4 }):Pos_()
	nX, nY = ui:Append("Shadow", "STR_RAID_DISTANCE_M4", { w = 22, h = 22, x = 280, y = nY + 3, color = Cataclysm_Main.tOtherCol[3] }):Click(function()
		GUI.OpenColorTablePanel(function(r, g, b)
			Cataclysm_Main.tOtherCol[3] = { r, g, b }
			ui:Fetch("STR_RAID_DISTANCE_M4"):Color(r, g, b)
			if GetFrame() then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY, txt = g_tStrings.STR_GUILD_OFFLINE .. g_tStrings.BACK_COLOR }):Pos_()
	nX, nY = ui:Append("Shadow", "STR_GUILD_OFFLINE", { w = 22, h = 22, x = 280, y = nY + 3, color = Cataclysm_Main.tOtherCol[2] }):Click(function()
		GUI.OpenColorTablePanel(function(r, g, b)
			Cataclysm_Main.tOtherCol[2] = { r, g, b }
			ui:Fetch("STR_GUILD_OFFLINE"):Color(r, g, b)
			if GetFrame() then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY, txt = g_tStrings.STR_SKILL_MANA .. g_tStrings.BACK_COLOR }):Pos_()
	nX, nY = ui:Append("Shadow", "STR_SKILL_MANA", { w = 22, h = 22, x = 280, y = nY + 3, color = Cataclysm_Main.tManaColor }):Click(function()
		GUI.OpenColorTablePanel(function(r, g, b)
			Cataclysm_Main.tManaColor = { r, g, b }
			ui:Fetch("STR_SKILL_MANA"):Color(r, g, b)
			if GetFrame() then
				Grid_CTM:CallDrawHPMP(true, true)
			end
		end)
	end):Pos_()

end
GUI.RegisterPanel(_L["Grid Style"], { "ui/Image/UICommon/RaidTotal.uitex", 68 }, _L["Panel"], PS2)

local PS3 = {}
function PS3.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Interface settings"], font = 27 }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 10, txt = _L["Interface Width"]}):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 12, h = 25, w = 250 })
	:Range(50, 250, 200):Value(Cataclysm_Main.fScaleX * 100):Change(function(nVal)
		nVal = nVal / 100
		local nNewX, nNewY = nVal / Cataclysm_Main.fScaleX, Cataclysm_Main.fScaleY / Cataclysm_Main.fScaleY
		Cataclysm_Main.fScaleX = nVal
		if GetFrame() then
			Grid_CTM:Scale(nNewX, nNewY)
		end
	end):Pos_()

	nX = ui:Append("Text", { x = 10, y = nY, txt = _L["Interface Height"]}):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 2, h = 25, w = 250 })
	:Range(50, 250, 200):Value(Cataclysm_Main.fScaleY * 100):Change(function(nVal)
		nVal = nVal / 100
		local nNewX, nNewY = Cataclysm_Main.fScaleX / Cataclysm_Main.fScaleX, nVal / Cataclysm_Main.fScaleY
		Cataclysm_Main.fScaleY = nVal
		if GetFrame() then
			Grid_CTM:Scale(nNewX, nNewY)
		end
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = g_tStrings.OTHER, font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Show Group Number"], checked = Cataclysm_Main.bShowGropuNumber })
	:Click(function(bCheck)
		Cataclysm_Main.bShowGropuNumber = bCheck
		if GetFrame() then
			Grid_CTM:CloseParty()
			Grid_CTM:ReloadParty()
		end
	end):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY, txt = g_tStrings.STR_ALPHA }):Pos_()
	nX, nY = ui:Append("WndTrackBar", { x = nX + 5, y = nY + 2 })
	:Range(1, 100, 99):Value(Cataclysm_Main.nAlpha / 255 * 100):Change(function(nVal)
		Cataclysm_Main.nAlpha = nVal / 100 * 255
		if GetFrame() then
			FireUIEvent("CTM_SET_ALPHA")
		end
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Arrangement"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY + 10, txt = _L["One lines: 5/0"], group = "Arrangement", checked = Cataclysm_Main.nAutoLinkMode == 5 })
	:Click(function()
		Cataclysm_Main.nAutoLinkMode = 5
		if GetFrame() then
			Grid_CTM:AutoLinkAllPanel()
			SetFrameSize()
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Two lines: 1/4"], group = "Arrangement", checked = Cataclysm_Main.nAutoLinkMode == 1 })
	:Click(function()
		Cataclysm_Main.nAutoLinkMode = 1
		if GetFrame() then
			Grid_CTM:AutoLinkAllPanel()
			SetFrameSize()
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Two lines: 2/3"], group = "Arrangement", checked = Cataclysm_Main.nAutoLinkMode == 2 })
	:Click(function()
		Cataclysm_Main.nAutoLinkMode = 2
		if GetFrame() then
			Grid_CTM:AutoLinkAllPanel()
			SetFrameSize()
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Two lines: 3/2"], group = "Arrangement", checked = Cataclysm_Main.nAutoLinkMode == 3 })
	:Click(function()
		Cataclysm_Main.nAutoLinkMode = 3
		if GetFrame() then
			Grid_CTM:AutoLinkAllPanel()
			SetFrameSize()
		end
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = 10, y = nY, txt = _L["Two lines: 4/1"], group = "Arrangement", checked = Cataclysm_Main.nAutoLinkMode == 4 })
	:Click(function()
		Cataclysm_Main.nAutoLinkMode = 4
		if GetFrame() then
			Grid_CTM:AutoLinkAllPanel()
			SetFrameSize()
		end
	end):Pos_()
end
GUI.RegisterPanel(_L["Interface settings"], { "ui/Image/UICommon/RaidTotal.uitex", 71 }, _L["Panel"], PS3)

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
	:Range(0, 10, 10):Value(Cataclysm_Main.nMaxShowBuff):Change(function(nVal)
		Cataclysm_Main.nMaxShowBuff = nVal
	end):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY, txt = _L["buff Size"]}):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = Cataclysm_Main.bAutoBuffSize, txt = g_tStrings.STR_OPTIMIZE_AUTO }):Click(function(bCheck)
		Cataclysm_Main.bAutoBuffSize = bCheck
		ui:Fetch("BuffSize"):Enable(not bCheck)
	end):Pos_()
	nX, nY = ui:Append("WndTrackBar", "BuffSize", { x = nX + 5, y = nY + 2, h = 25, w = 200 })
	:Enable(not Cataclysm_Main.bAutoBuffSize):Range(50, 200, 150):Value(Cataclysm_Main.fBuffScale * 100):Change(function(nVal)
		Cataclysm_Main.fBuffScale = nVal / 100
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Buff Staring"], checked = Cataclysm_Main.bStaring }):Click(function(bCheck)
		Cataclysm_Main.bStaring = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Show Buff Time"], checked = Cataclysm_Main.bShowBuffTime }):Click(function(bCheck)
		Cataclysm_Main.bShowBuffTime = bCheck
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Show Buff Num"], checked = Cataclysm_Main.bShowBuffNum }):Click(function(bCheck)
		Cataclysm_Main.bShowBuffNum = bCheck
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Manually add (One per line)"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndEdit",{ x = 10, y = nY + 10, w = 450, h = 150, limit = 4096, multi = true})
	:Text(GetListText(Cataclysm_Main.tBuffList)):Change(function(szText)
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
		Cataclysm_Main.tBuffList = t
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Tips"], font = 27 }):Pos_()
	ui:Append("Text", { x = 10, y = nY + 5, txt = _L["Cataclysm_TIPS"], w = 500, h = 60 , multi = true }):Pos_()
end
GUI.RegisterPanel(_L["Buff settings"], { "ui/Image/UICommon/RaidTotal.uitex", 74 }, _L["Panel"], PS4)

JH.RegisterEvent("CTM_PANEL_TEAMATE", function()
	TeammatePanel_Switch(arg0)
end)
JH.RegisterEvent("CTM_PANEL_RAID", function()
	RaidPanel_Switch(arg0)
end)

-- 关于界面打开和刷新面板的时机
-- 1) 普通情况下 组队会触发[PARTY_UPDATE_BASE_INFO]打开+刷新
-- 2) 进入竞技场/战场的情况下 不会触发[PARTY_UPDATE_BASE_INFO]事件
--    需要利用外面注册的[LOADING_END]来打开+刷新
-- 3) 如果在竞技场/战场掉线重上的情况下 需要使用外面注册的[LOADING_END]来打开面板
--    然后在UI上注册的[LOADING_END]的来刷新界面，否则获取不到团队成员，只能获取到有几个队
--    UI的[LOADING_END]晚大约30m，然后就能获取到团队成员了??????
-- 4) 从竞技场/战场回到原服使用外面注册的[LOADING_END]来打开+刷新
-- 5) 普通掉线/过地图使用外面注册的[LOADING_END]打开+刷新，避免过地图时候团队变动没有收到事件的情况。
-- 6) 综上所述的各式各样的奇葩情况 可以做如下的调整
--    利用外面的注册的[LOADING_END]来打开
--    利用UI注册的[LOADING_END]来刷新
--    避免多次重复刷新面板浪费开销

JH.RegisterEvent("PARTY_UPDATE_BASE_INFO", function()
	CheckCataclysmEnable()
	ReloadCataclysmPanel()
	PlaySound(SOUND.UI_SOUND, g_sound.Gift)
end)

JH.RegisterEvent("PARTY_LEVEL_UP_RAID", function()
	CheckCataclysmEnable()
	ReloadCataclysmPanel()
end)
JH.RegisterEvent("LOADING_END", CheckCataclysmEnable)

-- 保存和读取配置
JH.RegisterExit(function()
	JH.SaveLUAData(GetConfigurePath(), CTM_CONFIG_PLAYER)
end)

JH.RegisterEvent("LOGIN_GAME", SetConfigure)


JH.AddonMenu(function()
	return { szOption = _L["Cataclysm Team Panel"], bCheck = true, bChecked = Cataclysm_Main.bRaidEnable, fnAction = EnableTeamPanel }
end)
