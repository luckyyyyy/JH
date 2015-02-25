-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-02-26 00:37:24
local _L = JH.LoadLangPack
-----------------------------------------------
-- 重构 @ 2015 赶时间 很多东西写的很粗略
-----------------------------------------------
-- global cache

local pairs, ipairs = pairs, ipairs
local type, unpack = type, unpack
local setmetatable = setmetatable
local GetDistance = JH.GetDistance
local GetClientPlayer, GetClientTeam, GetPlayer = GetClientPlayer, GetClientTeam, GetPlayer
local Station, SetTarget, Target_GetTargetData = Station, SetTarget, Target_GetTargetData
local RaidGrid_CTM_Edition = RaidGrid_CTM_Edition
-- global STR cache
local COINSHOP_SOURCE_NULL   = g_tStrings.COINSHOP_SOURCE_NULL
local STR_FRIEND_NOT_ON_LINE = g_tStrings.STR_FRIEND_NOT_ON_LINE
local FIGHT_DEATH            = g_tStrings.FIGHT_DEATH
-- STATE cache
local MOVE_STATE_ON_STAND    = MOVE_STATE.ON_STAND
local MOVE_STATE_ON_DEATH    = MOVE_STATE.ON_DEATH
-- local value
local CTM_ALPHA_STEP         = 15    -- 240 / CTM_ALPHA_STEP
local CTM_BOX_HEIGHT         = 42    -- 注意::受限ini 这里只是作用于动态修改
local CTM_GROUP_COUNT        = 5 - 1 -- 防止以后开个什么40人本 估计不太可能 就和剑三这还得好几年
local CTM_MEMBER_COUNT       = 5
local CTM_DRAG               = false
local CTM_INIFILE            = JH.GetAddonInfo().szRootPath .. "Cataclysm_Panel/ui/Cataclysm_Party.ini"
local CTM_ITEM               = JH.GetAddonInfo().szRootPath .. "Cataclysm_Panel/ui/item.ini"
local CTM_BUFF_ITEM          = JH.GetAddonInfo().szRootPath .. "Cataclysm_Panel/ui/Item_Buff.ini"
local CTM_IMAGES             = JH.GetAddonInfo().szRootPath .. "Cataclysm_Panel/images/ForceColorBox.UITex"
local CTM_TAR_TEMP
local CTM_DRAG_ID
local CTM_TARGET
local CTM_TTARGET
local CTM_CACHE              = setmetatable({}, { __mode = "v" })
local CTM_LIFE_CACHE         = {}
-- Package func
local HIDE_FORCE = {
	[7]  = true,
	[8]  = true,
	[10] = true,
	[21] = true,
}
local function IsPlayerManaHide(dwForceID)
	return HIDE_FORCE[dwForceID]
end

local function EditBox_AppendLinkPlayer(szName)
	local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
	edit:InsertObj("[" .. szName .. "]", { type = "name", text = "[" .. szName .. "]", name = szName })
	Station.SetFocusWindow(edit)
end

local function OpenRaidDragPanel(dwMemberID)
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

local function CloseRaidDragPanel()
	local hFrame = Station.Lookup("Normal/RaidDragPanel")
	if hFrame then
		hFrame:EndMoving()
		Wnd.CloseWindow(hFrame)
	end
end
-- OutputTeamMemberTip 系统的API不好用所以这是改善版
local function OutputTeamMemberTip(dwID, rc)	
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
		local p = GetPlayer(dwID)
		if p and p.dwTongID > 0 then
			if GetTongClient().ApplyGetTongName(p.dwTongID) then
				szTip = szTip .. GetFormatText("[" .. GetTongClient().ApplyGetTongName(p.dwTongID) .. "]\n", 41)
			end
		end
    	szTip = szTip .. GetFormatText(FormatString(g_tStrings.STR_PLAYER_H_WHAT_LEVEL, tMemberInfo.nLevel), 82)
		szTip = szTip .. GetFormatText(JH.GetSkillName(tMemberInfo.dwMountKungfuID, 1) .. "\n", 82)
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

local function InsertChangeGroupMenu(tMenu, dwMemberID)
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
					bDisable = (#tGroupInfo.MemberList >= CTM_MEMBER_COUNT),
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

local CTM_FORCE_COLOR = {
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
	[21] = { 180, 60 , 0   },
}
setmetatable(CTM_FORCE_COLOR, { __index = function() return 168, 168, 168 end, __metatable = true })
local function GetForceColor(dwForceID) --获得成员颜色
	return unpack(CTM_FORCE_COLOR[dwForceID])
end

-- 有各个版本之间的文本差异，所以做到翻译中
local CTM_KUNGFU_TEXT = {
	[10080] = _L["KUNGFU_10080"], -- "云",
	[10081] = _L["KUNGFU_10081"], -- "冰",
	[10021] = _L["KUNGFU_10021"], -- "花",
	[10028] = _L["KUNGFU_10028"], -- "离",
	[10026] = _L["KUNGFU_10026"], -- "傲",
	[10062] = _L["KUNGFU_10062"], -- "铁",
	[10002] = _L["KUNGFU_10002"], -- "洗",
	[10003] = _L["KUNGFU_10003"], -- "易",
	[10014] = _L["KUNGFU_10014"], -- "气",
	[10015] = _L["KUNGFU_10015"], -- "剑",
	[10144] = _L["KUNGFU_10144"], -- "问",
	[10145] = _L["KUNGFU_10145"], -- "山",
	[10175] = _L["KUNGFU_10175"], -- "毒",
	[10176] = _L["KUNGFU_10176"], -- "补",
	[10224] = _L["KUNGFU_10224"], -- "羽",
	[10225] = _L["KUNGFU_10225"], -- "诡",
	[10242] = _L["KUNGFU_10242"], -- "焚",
	[10243] = _L["KUNGFU_10243"], -- "尊",
	[10268] = _L["KUNGFU_10268"], -- "丐",
	[10390] = _L["KUNGFU_10390"], -- "分",
	[10389] = _L["KUNGFU_10389"], -- "衣",
}
setmetatable(CTM_KUNGFU_TEXT, { __index = function() return _L["KUNGFU_0"] end, __metatable = true })

-- CODE --
local CTM = {}

function CTM:GetPartyFrame(nIndex) --获得组队面板
	return Station.Lookup("Normal/RaidGrid_Party_" .. nIndex)
end

function CTM:BringToTop()
	for i = 0, CTM_GROUP_COUNT do
		if self:GetPartyFrame(i) then
			self:GetPartyFrame(i):BringToTop()
		end
	end
	Station.Lookup("Normal/RaidGrid_CTM_Edition"):BringToTop()
end

function CTM:GetMemberHandle(nGroup, nIndex)
	local frame = self:GetPartyFrame(nGroup)
	if frame then
		return frame:Lookup("", "Handle_Roles"):Lookup(nIndex)
	end
end

-- 创建面板
function CTM:CreatePanel(nIndex)
	local me = GetClientPlayer()
	local frame = self:GetPartyFrame(nIndex)
	if not frame then
		frame = Wnd.OpenWindow(CTM_INIFILE, "RaidGrid_Party_" .. nIndex)
	end
	self:AutoLinkAllPanel()
	self:RefreshGroupText()
end
-- 刷新团队组编号
function CTM:RefreshGroupText()
	for i = 0, CTM_GROUP_COUNT do
		local me = GetClientPlayer()
		local frame = self:GetPartyFrame(i)
		if frame then
			local TextGroup = frame:Lookup("", "Handle_BG/Text_GroupIndex")
			if me.IsInRaid() then
				TextGroup:SetText(g_tStrings.STR_NUMBER[i + 1])
				TextGroup:SetFontScheme(7)
				local team = GetClientTeam()
				local tGroup = team.GetGroupInfo(i)
				if tGroup and tGroup.MemberList then
					for k, v in ipairs(tGroup.MemberList) do
						if v == UI_GetClientPlayerID() then
							TextGroup:SetFontScheme(2)
							TextGroup:SetFontColor(255, 255, 0) -- 自己所在的小队 黄色
							break
						end
					end
				end
			else
				TextGroup:SetText(g_tStrings.STR_TEAM)
			end
		end
	end
end

function CTM:AutoLinkAllPanel() --自动连接所有面板
	local frameMain = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	local nX, nY = frameMain:GetRelPos()
	nY = nY + 24
	local nShownCount = 0
	local tPosnSize = {}
	-- { nX = nX, nY = nY, nW = 0, nH = 0 }
	for i = 0, CTM_GROUP_COUNT do
		local hPartyPanel = self:GetPartyFrame(i)
		if hPartyPanel then
			local nW, nH = hPartyPanel:GetSize()
			
			if nShownCount < RaidGrid_CTM_Edition.nAutoLinkMode then
				tPosnSize[nShownCount] = { nX = nX + (128 * RaidGrid_CTM_Edition.fScaleX * nShownCount), nY = nY, nW = nW, nH = nH }
			else
				local nUpperIndex = math.min(nShownCount - RaidGrid_CTM_Edition.nAutoLinkMode, RaidGrid_CTM_Edition.nAutoLinkMode - 1)
				local tPS = tPosnSize[nUpperIndex] or {nH = 235 * RaidGrid_CTM_Edition.fScaleY}
				tPosnSize[nShownCount] = {
					nX = nX + (128 * RaidGrid_CTM_Edition.fScaleX * (nShownCount - RaidGrid_CTM_Edition.nAutoLinkMode)),
					nY = nY + tPosnSize[nUpperIndex].nH,
					nW = nW,
					nH = nH
				}
			end
			local _nX, _nY = hPartyPanel:GetRelPos()
			if _nX ~= tPosnSize[nShownCount].nX or _nY ~= tPosnSize[nShownCount].nY then
				hPartyPanel:SetRelPos(tPosnSize[nShownCount].nX, tPosnSize[nShownCount].nY)
			end
			nShownCount = nShownCount + 1
		end
	end
end

function CTM:GetMemberInfo(dwID)
	local team = GetClientTeam()
	return team.GetMemberInfo(dwID)
end

function CTM:GetTeamInfo()
	local team = GetClientTeam()
	return {
		[TEAM_AUTHORITY_TYPE.LEADER]     = team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER),
		[TEAM_AUTHORITY_TYPE.MARK]       = team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK),
		[TEAM_AUTHORITY_TYPE.DISTRIBUTE] = team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE),
	}
end

function CTM:RefreshTarget()
	if CTM_TARGET then
		if CTM_CACHE[CTM_TARGET] and CTM_CACHE[CTM_TARGET]:IsValid() then
			CTM_CACHE[CTM_TARGET]:Lookup("Image_Selected"):Hide()
		end
	end
	if CTM_TTARGET then
		if CTM_CACHE[CTM_TTARGET] and CTM_CACHE[CTM_TTARGET]:IsValid() then
			CTM_CACHE[CTM_TTARGET]:Lookup("Animate_TargetTarget"):Hide()
		end
	end
	
	local dwID, dwType = Target_GetTargetData()
	if dwType == TARGET.PLAYER and JH.IsParty(dwID) then
		CTM_TARGET = dwID
		if CTM_CACHE[CTM_TARGET] and CTM_CACHE[CTM_TARGET]:IsValid() then
			CTM_CACHE[CTM_TARGET]:Lookup("Image_Selected"):Show()
		end
	end
	
	if RaidGrid_CTM_Edition.bShowTargetTargetAni and dwID then
		local KObject = JH.GetTarget(dwID)
		if KObject then
			local tdwType, tdwID = KObject.GetTarget()
			if tdwID and tdwType == TARGET.PLAYER and JH.IsParty(tdwID) then
				CTM_TTARGET = tdwID
				if CTM_CACHE[CTM_TTARGET] and CTM_CACHE[CTM_TTARGET]:IsValid() then
					CTM_CACHE[CTM_TTARGET]:Lookup("Animate_TargetTarget"):Show()
				end
			end
		end
	end
end

function CTM:RefreshMark()
	local team = GetClientTeam()
	local tPartyMark = team.GetTeamMark()
	if not tPartyMark then return end
	for k, v in pairs(CTM_CACHE) do
		if v:IsValid() then
			if tPartyMark[k] then
				local nMarkID = tPartyMark[k]
				if nMarkID then
					assert(nMarkID > 0 and nMarkID <= #PARTY_MARK_ICON_FRAME_LIST)
					nIconFrame = PARTY_MARK_ICON_FRAME_LIST[nMarkID]
				end
				v:Lookup("Handle_Icons/Image_MarkImage"):FromUITex(PARTY_MARK_ICON_PATH, nIconFrame)
				v:Lookup("Handle_Icons/Image_MarkImage"):Show()
			else
				v:Lookup("Handle_Icons/Image_MarkImage"):Hide()
			end
		end
	end
end

function CTM:CallRefreshImages(dwID, ...)
	if type(dwID) == "number" then
		local info = self:GetMemberInfo(dwID)
		if info and CTM_CACHE[dwID] and CTM_CACHE[dwID]:IsValid() then
			self:RefreshImages(CTM_CACHE[dwID], dwID, info, ...)
		end
	else
		for k, v in pairs(CTM_CACHE) do
			if v:IsValid() then
				local info = self:GetMemberInfo(k)
				self:RefreshImages(v, k, info, ...)
			end
		end
	end
end

-- 刷新图标和名字之类的信息
function CTM:RefreshImages(h, dwID, info, tSetting, bIcon, bFormationLeader, bMark, bName)
	-- assert(info)
	if not info then return end
	local fnAction = function(t)
		if t[TEAM_AUTHORITY_TYPE.LEADER] == dwID then
			h:Lookup("Handle_Icons/Image_Leader"):Show()
		else
			h:Lookup("Handle_Icons/Image_Leader"):Hide()
		end
		
		if t[TEAM_AUTHORITY_TYPE.MARK] == dwID then
			h:Lookup("Handle_Icons/Image_Marker"):Show()
		else
			h:Lookup("Handle_Icons/Image_Marker"):Hide()
		end

		if t[TEAM_AUTHORITY_TYPE.DISTRIBUTE] == dwID then
			h:Lookup("Handle_Icons/Image_Looter"):Show()
		else
			h:Lookup("Handle_Icons/Image_Looter"):Hide()
		end
	end
	
	if type(tSetting) == "table" then -- 根据表的内容刷新标记队长等信息
		fnAction(tSetting)	
	elseif type(tSetting) == "boolean" and tSetting then
		fnAction(self:GetTeamInfo())
	end
	-- 刷新阵眼
	if type(bFormationLeader) == "boolean" then
		if bFormationLeader then
			h:Lookup("Handle_Icons/Image_Matrix"):Show()
		else
			h:Lookup("Handle_Icons/Image_Matrix"):Hide()
		end
	end
	-- 刷新内功
	if bIcon then -- 刷新icon
		local img = h:Lookup("Image_Icon")
		if RaidGrid_CTM_Edition.nShowIcon ~= 4 then
			if RaidGrid_CTM_Edition.nShowIcon == 2 then
				local _, nIconID = JH.GetSkillName(info.dwMountKungfuID, 0)
				if nIconID == 13 then nIconID = 2003 end -- _(:з」∠)_
				img:FromIconID(nIconID)
			elseif RaidGrid_CTM_Edition.nShowIcon == 1 then
				img:FromUITex(GetForceImage(info.dwForceID))
			elseif RaidGrid_CTM_Edition.nShowIcon == 3 then
				local camp = { [0] = -1, [1] = 43, [2] = 40 }
				img:FromUITex("UI/Image/Button/ShopButton.uitex", camp[info.nCamp])
			end
			img:SetSize(28, 28)
			img:Show()
		else -- 不再由icon控制 转交给textname
			img:Hide()
			bName = true
		end
	end
	-- 刷新名字
	if bName then
		local TextName = h:Lookup("Text_Name")
		TextName:SetText(info.szName)
		TextName:SetFontScheme(RaidGrid_CTM_Edition.nFont)
		if RaidGrid_CTM_Edition.bColoredName then
			TextName:SetFontColor(GetForceColor(info.dwForceID))
		else
			TextName:SetFontColor(255, 255, 255)
		end
		if RaidGrid_CTM_Edition.nShowIcon == 4 then
			TextName:SetRelPos(-6, 0)
			TextName:SetSize(105, 10)
			TextName:SetText(string.format("%s %s", CTM_KUNGFU_TEXT[info.dwMountKungfuID], info.szName))
		else
			TextName:SetRelPos(15, 0)
			TextName:SetSize(90, 10)
		end
		h:FormatAllItemPos()
	end
	if bMark then
		self:RefreshMark()
	end
end

function CTM:DrawAllParty()
	for i = 0, CTM_GROUP_COUNT do
		if not self:GetPartyFrame(i) then
			self:CreatePanel(i)
			self:DrawParty(i)
		else
			self:FormatFrame(self:GetPartyFrame(i), 5)
		end
	end
end

function CTM:CloseParty(nIndex)
	if nIndex then
		Wnd.CloseWindow(self:GetPartyFrame(nIndex))
	else
		for i = 0, CTM_GROUP_COUNT do
			Wnd.CloseWindow(self:GetPartyFrame(i))
		end
	end
end

function CTM:ReloadParty()
	local team = GetClientTeam()
	for i = 0, CTM_GROUP_COUNT do
		local tGroup = team.GetGroupInfo(i)
		if tGroup then
			if #tGroup.MemberList == 0 then
				self:CloseParty(i)
			else
				self:CreatePanel(i)
				self:DrawParty(i)
			end
		end
	end
	local dwID, dwType = Target_GetTargetData()
	if dwType == TARGET.PLAYER and JH.IsParty(dwID) then
		CTM_TARGET = dwID
		if RaidGrid_CTM_Edition.bShowTargetTargetAni then
			local tdwType, tdwID = JH.GetTarget(dwID).GetTarget()
			CTM_TTARGET = tdwID
		end
	else
		CTM_TTARGET = nil
		CTM_TARGET = nil
	end
	self:RefreshMark()
	self:RefreshTarget()
	self:AutoLinkAllPanel()
	self:RefreshDistance()
	self:RefresFormation()
	CTM_LIFE_CACHE = {}
end

-- 哎 事件太蛋疼 就这样吧
function CTM:RefresFormation()
	local team = GetClientTeam()
	for i = 0, CTM_GROUP_COUNT do
		local tGroup = team.GetGroupInfo(i)
		if tGroup and tGroup.dwFormationLeader and #tGroup.MemberList > 0 then
			local dwFormationLeader = tGroup.dwFormationLeader
			for k, v in ipairs(tGroup.MemberList) do
				local info = self:GetMemberInfo(v)
				self:RefreshImages(CTM_CACHE[v], v, info, false, false, dwFormationLeader == v)
			end
		end
	end
end
-- 绘制面板 bHandle单独刷新handle的缩放
function CTM:DrawParty(nIndex, bHandle)
	local team = GetClientTeam()
	local tGroup = team.GetGroupInfo(nIndex)
	local frame = self:GetPartyFrame(nIndex)
	local handle = frame:Lookup("", "Handle_Roles")
	local tSetting = self:GetTeamInfo()
	handle:Clear()
	for i = 1, CTM_MEMBER_COUNT do
		local dwID = tGroup.MemberList[i]
		local h = handle:AppendItemFromIni(CTM_ITEM, "Handle_RoleDummy", i)
		if dwID then
			h.dwID = dwID
			h.nGroup = nIndex
			CTM_CACHE[dwID] = h
			local info = self:GetMemberInfo(dwID)
			-- name
			local TextName = h:Lookup("Text_Name")
			TextName:SetText(info.szName)
			TextName:SetFontScheme(RaidGrid_CTM_Edition.nFont)
			if RaidGrid_CTM_Edition.bColoredName then
				TextName:SetFontColor(GetForceColor(info.dwForceID))
			else
				TextName:SetFontColor(255, 255, 255)
			end
			h:Lookup("Handle_Common/Image_BG_Force"):FromUITex(CTM_IMAGES, 3)
			self:RefreshImages(h, dwID, info, tSetting, true, dwID == tGroup.dwFormationLeader)
		end
		h.OnItemLButtonDrag = function()
			if not dwID then return	end
			local team = GetClientTeam()
			local player = GetClientPlayer()
			if (IsAltKeyDown() or RaidGrid_CTM_Edition.bEditMode) and player.IsInRaid() and JH.IsLeader() then
				CTM_DRAG = true
				CTM_DRAG_ID = dwID
				self:DrawAllParty()
				self:BringToTop()
				OpenRaidDragPanel(dwID)
			end
		end
		
		h.OnItemLButtonUp = function() -- fix range bug
			JH.DelayCall(50, function()
				if CTM_DRAG then
					CTM_DRAG, CTM_DRAG_ID = false, nil
					self:CloseParty()
					self:ReloadParty()
					CloseRaidDragPanel()
				end
			end)
		end
		
		h.OnItemLButtonDragEnd = function()
			if CTM_DRAG and dwID ~= CTM_DRAG_ID then
				local team = GetClientTeam()
				local player = GetClientPlayer()				
				team.ChangeMemberGroup(CTM_DRAG_ID, nIndex, dwID or 0)
				CTM_DRAG, CTM_DRAG_ID = false, nil
				CloseRaidDragPanel()
				self:CloseParty()
				self:ReloadParty()
			end
		end
		-- 按下 为了效率不用click
		h.OnItemLButtonDown = function()
			self:BringToTop()
			if not dwID then return	end
			local info = self:GetMemberInfo(dwID)
			if IsCtrlKeyDown() then
				EditBox_AppendLinkPlayer(info.szName)
			elseif info.bIsOnLine and GetPlayer(dwID) then -- 有待考证
				SetTarget(TARGET.PLAYER, dwID)
				CTM_TAR_TEMP = dwID
			end
		end
		-- 鼠标进入
		h.OnItemMouseEnter = function()
			if CTM_DRAG then
				this:Lookup("Image_Selected"):Show()
			end
			if not dwID then return	end
			local nX, nY = this:GetRoot():GetAbsPos()
			local nW, nH = this:GetRoot():GetSize()
			local me = GetClientPlayer()
			if RaidGrid_CTM_Edition.bTempTargetFightTip and not me.bFightState or not RaidGrid_CTM_Edition.bTempTargetFightTip then
				OutputTeamMemberTip(dwID, { nX, nY + 5, nW, nH })
			end
			local info = self:GetMemberInfo(dwID)
			if info.bIsOnLine and GetPlayer(dwID) then
				CTM.SetTempTarget(dwID, true)
			end
		end
		-- 鼠标离开
		h.OnItemMouseLeave = function()
			if CTM_DRAG then
				this:Lookup("Image_Selected"):Hide()
			end
			HideTip()
			if not dwID then return	end
			local info = self:GetMemberInfo(dwID)
			if not info then return end -- 退租的问题
			if info.bIsOnLine and GetPlayer(dwID) then
				CTM.SetTempTarget(dwID, false)
			end
		end
		-- 右键
		h.OnItemRButtonClick = function()
			self:BringToTop()
			if not dwID then return	end
			local menu = {}
			local me = GetClientPlayer()
			local info = self:GetMemberInfo(dwID)
			local szPath, nFrame = GetForceImage(info.dwForceID)
			table.insert(menu, {
				szOption = info.szName,
				szLayer = "ICON_RIGHT",
				rgb = { JH.GetForceColor(info.dwForceID) },
				szIcon = szPath,
				nFrame = nFrame
			})
			if JH.IsLeader() and me.IsInRaid() then
				table.insert(menu, { bDevide = true })
				InsertChangeGroupMenu(menu, dwMemberID)
			end
			local info = self:GetMemberInfo(dwID)
			if dwID ~= me.dwID then
				InsertTeammateMenu(menu, dwID)
				table.insert(menu, { szOption = g_tStrings.STR_LOOKUP, bDisable = not info.bIsOnLine, fnAction = function() 
					ViewInviteToPlayer(dwID) 
				end })
			else
				InsertPlayerMenu(menu ,dwID)
			end
			if #menu > 0 then
				PopupMenu(menu)
			end
		end
	end
	handle:FormatAllItemPos()
	frame.nMemberCount = #tGroup.MemberList
	if bHandle then
		self:Scale(RaidGrid_CTM_Edition.fScaleX, RaidGrid_CTM_Edition.fScaleY, handle)
	else
		self:Scale(RaidGrid_CTM_Edition.fScaleX, RaidGrid_CTM_Edition.fScaleY, frame)
	end
	-- 先缩放后画
	self:FormatFrame(frame, #tGroup.MemberList)
	self:RefreshDistance() -- 立即刷新一次
	for k, v in pairs(CTM_CACHE) do
		if v:IsValid() and v.nGroup == nIndex then
			self:DrawHPMP(v, k, self:GetMemberInfo(k))
		end
	end
	CTM_LIFE_CACHE = {}
end

function CTM:Scale(fX, fY, frame)
	if frame then
		frame:Scale(fX, fY)
	else
		for i = 0, CTM_GROUP_COUNT do
			if self:GetPartyFrame(i) then
				self:GetPartyFrame(i):Scale(fX, fY)
				self:FormatFrame(self:GetPartyFrame(i))
			end
		end
	end
	self:AutoLinkAllPanel()
	self:CallRefreshImages(true, false, true)
end

function CTM:FormatFrame(frame, nMemberCount)
	local fX, fY = RaidGrid_CTM_Edition.fScaleX, RaidGrid_CTM_Edition.fScaleY
	if CTM_DRAG then
		nMemberCount = CTM_MEMBER_COUNT
		frame:SetSize(128 * fX, (25 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Shadow_BG"):SetSize(120 * fX, (20 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Image_BG_L"):SetSize(15 * fX, nMemberCount * CTM_BOX_HEIGHT * fY)
		frame:Lookup("", "Handle_BG/Image_BG_R"):SetSize(15 * fX, nMemberCount * CTM_BOX_HEIGHT * fY)
		frame:Lookup("", "Handle_BG/Image_BG_BL"):SetRelPos(0, (12 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Image_BG_B"):SetRelPos(15 * fX, (12 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Image_BG_BR"):SetRelPos(113 * fX, (12 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Text_GroupIndex"):SetRelPos(0, 3 + nMemberCount * CTM_BOX_HEIGHT * fY)
		local handle = frame:Lookup("", "Handle_Roles")
		for i = 0, handle:GetItemCount() - 1 do
			handle:Lookup(i):Lookup("Image_BG_Slot"):Show()
		end
	else
		nMemberCount = frame.nMemberCount or CTM_MEMBER_COUNT
		frame:SetSize(128 * fX, (25 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Shadow_BG"):SetSize(120 * fX, (20 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Image_BG_L"):SetSize(15 * fX, nMemberCount * CTM_BOX_HEIGHT * fY)
		frame:Lookup("", "Handle_BG/Image_BG_R"):SetSize(15 * fX, nMemberCount * CTM_BOX_HEIGHT * fY)
		frame:Lookup("", "Handle_BG/Image_BG_BL"):SetRelPos(0, (12 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Image_BG_B"):SetRelPos(15 * fX, (12 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Image_BG_BR"):SetRelPos(113 * fX, (12 + nMemberCount * CTM_BOX_HEIGHT) * fY)
		frame:Lookup("", "Handle_BG/Text_GroupIndex"):SetRelPos(0, 3 + nMemberCount * CTM_BOX_HEIGHT * fY)
		local handle = frame:Lookup("", "Handle_Roles")
		for i = 0, handle:GetItemCount() - 1 do
			handle:Lookup(i):Lookup("Image_BG_Slot"):Hide()
		end
	end
	frame:Lookup("", "Handle_BG"):FormatAllItemPos()
end

-- 注册buff 
-- arg0:dwMemberID, arg1:dwID, arg2:nLevel, arg3:tColor
function CTM:RecBuff(arg0, arg1, arg2, arg3)
	if CTM_CACHE[arg0] and CTM_CACHE[arg0]:IsValid() then
		local h = CTM_CACHE[arg0]:Lookup("Handle_Buff_Boxes")
		if h:GetItemCount() >= RaidGrid_CTM_Edition.nMaxShowBuff then
			return
		end
		for i = 0, h:GetItemCount() - 1 do
			local _h = h:Lookup(i)
			if _h and _h:IsValid() then -- 防止溢出
				local _, dwID, nLevel = _h:Lookup("Box"):GetObject()
				if dwID == arg1 and nLevel == arg2 then
					return
				end
			end
		end
		local p = GetPlayer(arg0)
		if p then
			local bExist, tBuff = JH.HasBuff(arg1, p)
			if bExist then
				local hBuff = h:AppendItemFromIni(CTM_BUFF_ITEM, "Handle_Buff", arg1 .. arg2)
				if not arg3 then
					hBuff:Lookup("Shadow"):Hide()
				else
					hBuff:Lookup("Shadow"):SetColorRGB(unpack(arg3))
				end
				local szName, nIcon = JH.GetBuffName(arg1, arg2)
				if nIcon == -1 then nIcon = 1434 end
				local hBox = hBuff:Lookup("Box")
				hBox:SetObject(UI_OBJECT_ITEM, arg1, arg2)
				hBox:SetObjectIcon(nIcon)
				
				local nTime = JH.GetEndTime(tBuff.nEndFrame)				
				if nTime < 5 then
					hBox:SetOverTextFontScheme(0, 219)
					hBox:SetOverText(0, math.floor(nTime))
				elseif nTime < 10 then
					hBox:SetOverTextFontScheme(0, 27)
					hBox:SetOverText(0, math.floor(nTime))
				end
				if RaidGrid_CTM_Edition.fScaleY > 1 then
					self:Scale(RaidGrid_CTM_Edition.fScaleY, RaidGrid_CTM_Edition.fScaleY, hBuff)
				end
				h:FormatAllItemPos()
			end
		end
	end
end

function CTM:RefresBuff()
	for k, v in pairs(CTM_CACHE) do
		if v:IsValid() then
			local handle = v:Lookup("Handle_Buff_Boxes")
			if handle:GetItemCount() > 0 then
				local p = GetPlayer(k)
				for i = 0, handle:GetItemCount() - 1 do
					if p then
						local h = handle:Lookup(i)
						if h then -- 因为是呼吸
							local hBox = h:Lookup("Box")
							local _, dwID, nLevel = hBox:GetObject()
							local bExist, tBuff = JH.HasBuff(dwID, p)
							if bExist then
								local nTime = JH.GetEndTime(tBuff.nEndFrame)
								if nTime < 5 then
									hBox:SetOverTextFontScheme(0, 219)
									hBox:SetOverText(0, math.floor(nTime) .. " ")
								elseif nTime < 10 then
									hBox:SetOverTextFontScheme(0, 27)
									hBox:SetOverText(0, math.floor(nTime) .. " ")
								end
							else
								handle:RemoveItem(handle:Lookup(i))
							end
						end
					else
						handle:RemoveItem(handle:Lookup(i))
					end
				end
			end
		end
	end
end

function CTM:RefreshDistance()
	if RaidGrid_CTM_Edition.bEnableDistance then
		for k, v in pairs(CTM_CACHE) do
			if v:IsValid() then
				local p = GetPlayer(k) -- info.nPoX 刷新太慢了 对于治疗来说 这个太重要了
				local Lsha = v:Lookup("Handle_Common/Shadow_Life")
				if p then
					local nDistance = GetDistance(p.nX, p.nY) -- 只计算平面
					if RaidGrid_CTM_Edition.nBGClolrMode == 1 then
						for kk, vv in ipairs(RaidGrid_CTM_Edition.tDistanceLevel) do
							if nDistance <= vv then
								if Lsha.nLevel ~= kk then
									Lsha.nLevel = kk
									CTM:DrawHPMP(v, k, self:GetMemberInfo(k), true) -- 立即重绘颜色 好像没API设置
								end
								break
							end
						end
					else
						local _nDistance = Lsha.nDistance or 0
						Lsha.nDistance = nDistance
						if (nDistance > 20 and _nDistance <= 20) or (nDistance <= 20 and _nDistance > 20) then
							CTM:DrawHPMP(v, k, self:GetMemberInfo(k), true)
						end
					end
					if RaidGrid_CTM_Edition.bShowDistance then
						v:Lookup("Handle_Common/Text_Distance"):SetText(string.format("%.1f", nDistance))
					else
						v:Lookup("Handle_Common/Text_Distance"):SetText("")
					end
				else
					if RaidGrid_CTM_Edition.bShowDistance then
						v:Lookup("Handle_Common/Text_Distance"):SetText("")
					end
					if Lsha.nLevel or Lsha.nDistance then
						Lsha.nLevel = nil
						Lsha.nDistance = nil
						CTM:DrawHPMP(v, k, self:GetMemberInfo(k), true)
					end
				end
			end
		end
	else
		for k, v in pairs(CTM_CACHE) do
			if v:IsValid() then
				local Lsha = v:Lookup("Handle_Common/Shadow_Life")
				if Lsha.nLevel or Lsha.nDistance ~= 0 then
					Lsha.nLevel = 1
					Lsha.nDistance = 0
					CTM:DrawHPMP(v, k, self:GetMemberInfo(k), true)
				end				
			end
		end
	end
end

-- 血量 / 内力
function CTM:CallDrawHPMP(dwID, ...)
	if type(dwID) == "number" then
		local info = self:GetMemberInfo(dwID)
		if info and CTM_CACHE[dwID] and CTM_CACHE[dwID]:IsValid() then
			self:DrawHPMP(CTM_CACHE[dwID], dwID, info, ...)
		end
	else
		for k, v in pairs(CTM_CACHE) do
			if v:IsValid() then
				local info = self:GetMemberInfo(k)
				if info then
					self:DrawHPMP(v, k, info, ...)
				end
			end
		end
	end
end

-- 缩放对动态构建的UI不会缩放 所以需要后处理
function CTM:DrawHPMP(h, dwID, info, bRefresh)
	local Lsha = h:Lookup("Handle_Common/Shadow_Life")
	local Msha = h:Lookup("Handle_Common/Shadow_Mana")
	local p
	if RaidGrid_CTM_Edition.bFasterHP then
		p = GetPlayer(dwID)
	end
	-- 气血计算 因为sync 必须拿出来单独算
	local nLifePercentage, nCurrentLife, nMaxLife
	if p and p.nMaxLife ~= 1 and p.nCurrentLife ~= 255 and p.nMaxLife ~= 255 and p.nCurrentLife < 10000000 and p.nCurrentLife > - 1000 then -- p sync err fix
		nCurrentLife = p.nCurrentLife
		nMaxLife = p.nMaxLife
	else
		nCurrentLife = info.nCurrentLife
		nMaxLife = info.nMaxLife
	end
	nLifePercentage = nCurrentLife / nMaxLife
	if not nLifePercentage or nLifePercentage < 0 or nLifePercentage > 1 then nLifePercentage = 1 end
	
	local bDeathFlag = info.bDeathFlag
	-- 有待验证
	if p then
		if p.nMoveState == MOVE_STATE_ON_STAND then
			if info.bDeathFlag then
				bDeathFlag = true
			end
		else
			bDeathFlag = p.nMoveState == MOVE_STATE_ON_DEATH
		end
	end
	local nAlpha = RaidGrid_CTM_Edition.nAlpha
	if RaidGrid_CTM_Edition.nBGClolrMode ~= 1 then
		if (Lsha.nDistance and Lsha.nDistance > 20) or not Lsha.nDistance then
			nAlpha = nAlpha * 0.6
		end
	end
	-- 内力
	if not bDeathFlag then
		local nPercentage, nManaShow = 1, 1
		local mana = h:Lookup("Handle_Common/Text_Mana")
		if not IsPlayerManaHide(info.dwForceID) then -- 内力不需要那么准
			nPercentage = info.nCurrentMana / info.nMaxMana
			nManaShow = info.nCurrentMana
			if not RaidGrid_CTM_Edition.nShowMP then
				mana:SetText("")
			else
				mana:SetText(nManaShow)
			end
		end
		if not nPercentage or nPercentage < 0 or nPercentage > 1 then nPercentage = 1 end
		local r, g, b = unpack(RaidGrid_CTM_Edition.tManaColor)
		self:DrawShadow(Msha, 121 * nPercentage, 8, r, g, b, nAlpha, RaidGrid_CTM_Edition.bManaGradient)
		Msha:Show()
	else
		Msha:Hide()
	end
	
	-- 缓存
	if not RaidGrid_CTM_Edition.bFasterHP or bRefresh or (RaidGrid_CTM_Edition.bFasterHP and CTM_LIFE_CACHE[dwID] ~= nLifePercentage) then
		-- 颜色计算
		local nNewW = 121 * nLifePercentage
		local r, g, b = unpack(RaidGrid_CTM_Edition.tOtherCol[2]) -- 不在线就灰色了
		if info.bIsOnLine then
			if RaidGrid_CTM_Edition.nBGClolrMode == 1 then
				if p or GetPlayer(dwID) then
					if Lsha.nLevel then
						r, g, b = unpack(RaidGrid_CTM_Edition.tDistanceCol[Lsha.nLevel])
					else
						r, g, b = unpack(RaidGrid_CTM_Edition.tOtherCol[3])
					end
				else
					r, g, b = unpack(RaidGrid_CTM_Edition.tOtherCol[3]) -- 在线使用白色
				end
			elseif RaidGrid_CTM_Edition.nBGClolrMode == 0 then
				r, g, b = unpack(RaidGrid_CTM_Edition.tDistanceCol[1]) -- 使用用户配色1
			elseif RaidGrid_CTM_Edition.nBGClolrMode == 2 then
				r, g, b = JH.GetForceColor(info.dwForceID)
			end
		else
			nAlpha = RaidGrid_CTM_Edition.nAlpha
		end
		self:DrawShadow(Lsha, nNewW, 31, r, g, b, nAlpha, RaidGrid_CTM_Edition.bLifeGradient)
		Lsha:Show()
		if RaidGrid_CTM_Edition.bHPHitAlert then
			local lifeFade = h:Lookup("Handle_Common/Shadow_Life_Fade")
			if CTM_LIFE_CACHE[dwID] and CTM_LIFE_CACHE[dwID] > nLifePercentage then
				local alpha = lifeFade:GetAlpha()
				if alpha == 0 then
					lifeFade:SetSize(CTM_LIFE_CACHE[dwID] * 121 * RaidGrid_CTM_Edition.fScaleX, 31 * RaidGrid_CTM_Edition.fScaleY)
				end
				if RaidGrid_CTM_Edition.nBGClolrMode ~= 1 then
					if (Lsha.nDistance and Lsha.nDistance > 20) or not Lsha.nDistance then
						lifeFade:SetAlpha(0)
						lifeFade:Hide()
					else
						lifeFade:SetAlpha(240)
						lifeFade:Show()
					end
				else
					lifeFade:SetAlpha(240)
					lifeFade:Show()
				end
				local key = "CTM_HIT_" .. dwID
				JH.UnBreatheCall(key)
				JH.BreatheCall(key, function()
					if lifeFade:IsValid() then
						local nFadeAlpha = math.max(lifeFade:GetAlpha() - CTM_ALPHA_STEP, 0)
						lifeFade:SetAlpha(nFadeAlpha)
						if nFadeAlpha == 0 then
							JH.UnBreatheCall(key)
						end
					else
						JH.UnBreatheCall(key)
					end
				end)
			end
		else
			h:Lookup("Handle_Common/Shadow_Life_Fade"):Hide()
		end
		
		if not CTM_LIFE_CACHE[dwID] then
			CTM_LIFE_CACHE[dwID] = 0
		else
			CTM_LIFE_CACHE[dwID] = nLifePercentage
		end
		-- 数值绘制
		local life = h:Lookup("Handle_Common/Text_Life")
		if RaidGrid_CTM_Edition.nBGClolrMode ~= 1 then
			if (Lsha.nDistance and Lsha.nDistance > 20) or not Lsha.nDistance then
				life:SetAlpha(150)
			else
				life:SetAlpha(255)
			end
		else
			life:SetAlpha(255)
		end
		if not bDeathFlag and info.bIsOnLine then
			life:SetFontColor(255, 255, 255)
			if RaidGrid_CTM_Edition.nHPShownMode2 == 0 then
				life:SetText("")
			else
				local fnAction = function(val, max)
					if RaidGrid_CTM_Edition.nHPShownNumMode == 1 then
						if val > 9999 then
							return string.format("%.1fw", val / 10000)
						else
							return val
						end
					elseif RaidGrid_CTM_Edition.nHPShownNumMode == 2 then
						return string.format("%.1f", val / max * 100) .. "%"
					elseif RaidGrid_CTM_Edition.nHPShownNumMode == 3 then
						return val
					end
				end
				if RaidGrid_CTM_Edition.nHPShownMode2 == 2 then
					life:SetText(fnAction(nCurrentLife, nMaxLife))
				elseif RaidGrid_CTM_Edition.nHPShownMode2 == 1 then
					local nShownLife = nMaxLife - nCurrentLife
					if nShownLife > 0 then
						life:SetText("-" .. fnAction(nShownLife, nMaxLife))
					else
						life:SetText("")
					end
				end
			end
		elseif not info.bIsOnLine then
			life:SetFontColor(128, 128, 128)
			life:SetText(STR_FRIEND_NOT_ON_LINE)
		elseif bDeathFlag then
			life:SetFontColor(255, 0, 0)
			life:SetText(FIGHT_DEATH)
		else
			life:SetFontColor(128, 128, 128)
			life:SetText(COINSHOP_SOURCE_NULL)
		end
	end
end

function CTM:DrawShadow(sha, x, y, r, g, b, a, bGradient) --重绘三角扇
	sha:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	sha:ClearTriangleFanPoint()
	x = x * RaidGrid_CTM_Edition.fScaleX
	y = y * RaidGrid_CTM_Edition.fScaleY
	if bGradient then
		sha:AppendTriangleFanPoint(0, 0, 64, 64, 64, a)
		sha:AppendTriangleFanPoint(x, 0, 64, 64, 64, a)
		sha:AppendTriangleFanPoint(x, y, r,	 g,	 b,	 a)
		sha:AppendTriangleFanPoint(0, y, r,	 g,	 b,	 a)
	else
		sha:AppendTriangleFanPoint(0, 0, r,	g, b, a)
		sha:AppendTriangleFanPoint(x, 0, r,	g, b, a)
		sha:AppendTriangleFanPoint(x, y, r,	g, b, a)
		sha:AppendTriangleFanPoint(0, y, r,	g, b, a)
	end
end

function CTM:Send_RaidReadyConfirm()
	if JH.IsLeader() then
		self:Clear_RaidReadyConfirm()
		for k, v in pairs(CTM_CACHE) do
			if v:IsValid() then
				local info = self:GetMemberInfo(k)
				if info.bIsOnLine and k ~= UI_GetClientPlayerID() then
					v:Lookup("Image_ReadyCover"):Show()
				end
			end
		end
		Send_RaidReadyConfirm()
	end
end

function CTM:Clear_RaidReadyConfirm()
	for k, v in pairs(CTM_CACHE) do
		if v:IsValid() then
			v:Lookup("Image_ReadyCover"):Hide()
			v:Lookup("Image_NotReady"):Hide()
			v:Lookup("Animate_Ready"):Hide()
		end
	end
end

function CTM:ChangeReadyConfirm(dwID, status)
	if CTM_CACHE[dwID] and CTM_CACHE[dwID]:IsValid() then
		local h = CTM_CACHE[dwID]
		h:Lookup("Image_ReadyCover"):Hide()
		if status == 1 then
			local key = "CTM_READY_" .. dwID
			h:Lookup("Animate_Ready"):Show()
			h:Lookup("Animate_Ready"):SetAlpha(240)
			JH.BreatheCall(key, function()
				if h:Lookup("Animate_Ready"):IsValid() then
					local nAlpha = math.max(h:Lookup("Animate_Ready"):GetAlpha() - 15, 0)
					h:Lookup("Animate_Ready"):SetAlpha(nAlpha)
					if nAlpha == 0 then
						JH.UnBreatheCall(key)
					end
				end
			end)
		elseif status == 2 then
			h:Lookup("Image_NotReady"):Show()
		end 
	end
end

local function CTM_SetTarget(dwTargetID)
	if dwTargetID and dwTargetID > 0 then
		local nType = IsPlayer(dwTargetID) and TARGET.PLAYER or TARGET.NPC
		SetTarget(nType, dwTargetID)
	else
		SetTarget(TARGET.NO_TARGET, 0)
	end
end


CTM.SetTempTarget = function(dwMemberID, bEnter)
	if not RaidGrid_CTM_Edition.bTempTargetEnable then
		return
	end
	local dwID, dwType = Target_GetTargetData() -- 如果没有目标输出的是 nil, TARGET.NO_TARGET
	if bEnter then
		CTM_TAR_TEMP = dwID
		if dwMemberID ~= dwID then
			CTM_SetTarget(dwMemberID)
		end
	else
		CTM_SetTarget(CTM_TAR_TEMP)
	end
end


Grid_CTM = setmetatable({}, { __index = CTM, __newindex = function() end, __metatable = true })