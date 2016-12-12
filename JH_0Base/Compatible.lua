-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2016-11-13 15:53:46

local _L = JH.LoadLangPack

DBM_TYPE = {
	OTHER           = 0,
	BUFF_GET        = 1,
	BUFF_LOSE       = 2,
	NPC_ENTER       = 3,
	NPC_LEAVE       = 4,
	NPC_TALK        = 5,
	NPC_LIFE        = 6,
	NPC_FIGHT       = 7,
	SKILL_BEGIN     = 8,
	SKILL_END       = 9,
	SYS_TALK        = 10,
	NPC_ALLLEAVE    = 11,
	NPC_DEATH       = 12,
	NPC_ALLDEATH    = 13,
	TALK_MONITOR    = 14,
	COMMON          = 15,
	NPC_MANA        = 16,
	DOODAD_ENTER    = 17,
	DOODAD_LEAVE    = 18,
	DOODAD_ALLLEAVE = 19,
	CHAT_MONITOR    = 20,
}
DBM_SCRUTINY_TYPE = { SELF = 1, TEAM = 2, ENEMY = 3, TARGET = 4 }

-- skillid, uitex, frame
JH_KUNGFU_LIST = {
	-- MT
	{ 10062, "ui/Image/icon/skill_tiance01.UITex",     0 }, -- 铁牢
	{ 10243, "ui/Image/icon/mingjiao_taolu_7.UITex",   0 }, -- 明尊
	{ 10389, "ui/Image/icon/Skill_CangY_33.UITex",     0 }, -- 铁骨
	{ 10002, "ui/Image/icon/skill_shaolin14.UITex",    0 }, -- 少林
	-- 治疗
	{ 10080, "ui/Image/icon/skill_qixiu02.UITex",      0 }, -- 云裳
	{ 10176, "ui/Image/icon/wudu_neigong_2.UITex",     0 }, -- 补天
	{ 10028, "ui/Image/icon/skill_wanhua23.UITex",     0 }, -- 离经
	{ 10448, "ui/Image/icon/skill_0514_23.UITex",      0 }, -- 相知
	-- 内功
	{ 10225, "ui/Image/icon/skill_tangm_20.UITex",     0 }, -- 天罗
	{ 10081, "ui/Image/icon/skill_qixiu03.UITex",      0 }, -- 冰心
	{ 10175, "ui/Image/icon/wudu_neigong_1.UITex",     0 }, -- 毒经
	{ 10242, "ui/Image/icon/mingjiao_taolu_8.UITex",   0 }, -- 焚影
	{ 10014, "ui/Image/icon/skill_chunyang21.UITex",   0 }, -- 紫霞
	{ 10021, "ui/Image/icon/skill_wanhua17.UITex",     0 }, -- 花间
	{ 10003, "ui/Image/icon/skill_shaolin10.UITex",    0 }, -- 易经
	{ 10447, "ui/Image/icon/skill_0514_27.UITex",      0 }, -- 莫问
	-- 外功
	{ 10390, "ui/Image/icon/Skill_CangY_32.UITex",     0 }, -- 分山
	{ 10224, "ui/Image/icon/skill_tangm_01.UITex",     0 }, -- 鲸鱼
	{ 10144, "ui/Image/icon/cangjian_neigong_1.UITex", 0 }, -- 问水
	{ 10145, "ui/Image/icon/cangjian_neigong_2.UITex", 0 }, -- 山居
	{ 10015, "ui/Image/icon/skill_chunyang13.UITex",   0 }, -- 备胎剑意
	{ 10026, "ui/Image/icon/skill_tiance02.UITex",     0 }, -- 傲雪
	{ 10268, "ui/Image/icon/skill_GB_30.UITex",        0 }, -- 笑尘
	{ 10464, "ui/Image/icon/daoj_16_8_25_16.UITex",    0 }, -- 霸刀
}

setmetatable(JH_KUNGFU_LIST, { __index = function(me, key)
	for k, v in pairs(me) do
		if v[1] == key then
			return v
		end
	end
end })

JH_FORCE_COLOR = {
	[FORCE_TYPE.JIANG_HU ] = { 255, 255, 255 }, -- 江湖
	[FORCE_TYPE.SHAO_LIN ] = { 255, 178, 95  }, -- 少林
	[FORCE_TYPE.WAN_HUA  ] = { 196, 152, 255 }, -- 万花
	[FORCE_TYPE.TIAN_CE  ] = { 255, 111, 83  }, -- 天策
	[FORCE_TYPE.CHUN_YANG] = { 89 , 224, 232 }, -- 纯阳
	[FORCE_TYPE.QI_XIU   ] = { 255, 129, 176 }, -- 七秀
	[FORCE_TYPE.WU_DU    ] = { 55 , 147, 255 }, -- 五毒
	[FORCE_TYPE.TANG_MEN ] = { 121, 183, 54  }, -- 唐门
	[FORCE_TYPE.CANG_JIAN] = { 214, 249, 93  }, -- 藏剑
	[FORCE_TYPE.GAI_BANG ] = { 205, 133, 63  }, -- 丐帮
	[FORCE_TYPE.MING_JIAO] = { 240, 70 , 96  }, -- 明教
	[FORCE_TYPE.CANG_YUN ] = { 180, 60 , 0   }, -- 苍云
	[FORCE_TYPE.CHANG_GE ] = { 100, 250, 180 }, -- 长歌
	[FORCE_TYPE.BA_DAO   ] = { 106 ,108, 189 }, -- 霸刀
}

setmetatable(JH_FORCE_COLOR, {
	__index = function()
		return { 225, 225, 225 }
	end,
	__metatable = true,
})

JH_TALK_CHANNEL_HEADER = {
	[PLAYER_TALK_CHANNEL.NEARBY]        = "/s ",
	[PLAYER_TALK_CHANNEL.FRIENDS]       = "/o ",
	[PLAYER_TALK_CHANNEL.TONG_ALLIANCE] = "/a ",
	[PLAYER_TALK_CHANNEL.RAID]          = "/t ",
	[PLAYER_TALK_CHANNEL.BATTLE_FIELD]  = "/b ",
	[PLAYER_TALK_CHANNEL.TONG]          = "/g ",
	[PLAYER_TALK_CHANNEL.SENCE]         = "/y ",
	[PLAYER_TALK_CHANNEL.FORCE]         = "/f ",
	[PLAYER_TALK_CHANNEL.CAMP]          = "/c ",
	[PLAYER_TALK_CHANNEL.WORLD]         = "/h ",
}
-- 相同名字的地图 全部指向同一个ID
JH_MAP_NAME_FIX = {
	[143] = 147,
	[144] = 147,
	[145] = 147,
	[146] = 147,
	[195] = 196,
}

JH_MARK_NAME = { _L["Cloud"], _L["Sword"], _L["Ax"], _L["Hook"], _L["Drum"], _L["Shear"], _L["Stick"], _L["Jade"], _L["Dart"], _L["Fan"] }

BigBagPanel_nCount = 6

--帮会仓库界面虚拟一个背包位置
INVENTORY_GUILD_BANK = INVENTORY_GUILD_BANK or INVENTORY_INDEX.TOTAL + 1
INVENTORY_GUILD_PAGE_SIZE = INVENTORY_GUILD_PAGE_SIZE or 100

-- middle map
if not CloseWorldMap then
function CloseWorldMap(bDisableSound)
	local frame = Station.Lookup("Topmost1/WorldMap")
	if frame then
		frame:Hide()
	end
	if not bDisableSound then
		PlaySound(SOUND.UI_SOUND,g_sound.CloseFrame)
	end
	-- FIXME：FireDataAnalysisEvent
end
end
if not IsMiddleMapOpened then
function IsMiddleMapOpened()
	local frame = Station.Lookup("Topmost1/MiddleMap")
	if frame and frame:IsVisible() then
		return true
	end
	return false
end
end
if not OpenMiddleMap then
function OpenMiddleMap(dwMapID, nIndex, bTraffic, bDisableSound)
	CloseWorldMap(true)
	local frame = Station.Lookup("Topmost1/MiddleMap")
	if frame then
		frame:Show()
	else
		frame = Wnd.OpenWindow("MiddleMap")
	end
	MiddleMap.bTraffic = bTraffic
	MiddleMap.ShowMap(frame, dwMapID, nIndex)
	MiddleMap.UpdateTraffic(frame, bTraffic)
	if not bDisableSound then
		PlaySound(SOUND.UI_SOUND,g_sound.OpenFrame)
	end
	-- FIXME：OnClientAddAchievement
	MiddleMap.nLastAlpha = MiddleMap.nAlpha
end
end

-- target level
if not GetTargetLevelFont then
function GetTargetLevelFont(nLevelDiff)
	local nFont = 16
	if nLevelDiff > 4 then	-- 红
		nFont = 159
	elseif nLevelDiff > 2 then	-- 桔
		nFont = 168
	elseif nLevelDiff > -3 then	-- 黄
		nFont = 16
	elseif nLevelDiff > -6 then	-- 绿
		nFont = 167
	else	-- 灰
		nFont = 169
	end
	return nFont
end
end

-- arena mapt
if not IsInArena then
function IsInArena()
	local me = GetClientPlayer()
	return me ~= nil and me.GetScene().bIsArenaMap
end
end

-- battle map
if not IsInBattleField then
function IsInBattleField()
	local me = GetClientPlayer()
	return me ~= nil and g_tTable.BattleField:Search(me.GetScene().dwMapID) ~= nil
end
end

-- internet exploere
if not OpenInternetExplorer then
function IsInternetExplorerOpened(nIndex)
	local frame = Station.Lookup("Topmost/IE"..nIndex)
	if frame and frame:IsVisible() then
		return true
	end
	return false
end

function IE_GetNewIEFramePos()
	local nLastTime = 0
	local nLastIndex = nil
	for i = 1, 10, 1 do
		local frame = Station.Lookup("Topmost/IE"..i)
		if frame and frame:IsVisible() then
			if frame.nOpenTime > nLastTime then
				nLastTime = frame.nOpenTime
				nLastIndex = i
			end
		end
	end
	if nLastIndex then
		local frame = Station.Lookup("Topmost/IE"..nLastIndex)
		x, y = frame:GetAbsPos()
		local wC, hC = Station.GetClientSize()
		if x + 890 <= wC and y + 630 <= hC then
			return x + 30, y + 30
		end
	end
	return 40, 40
end

function OpenInternetExplorer(szAddr, bDisableSound)
	local nIndex, nLast = nil, nil
	for i = 1, 10, 1 do
		if not IsInternetExplorerOpened(i) then
			nIndex = i
			break
		elseif not nLast then
			nLast = i
		end
	end
	if not nIndex then
		OutputMessage("MSG_ANNOUNCE_RED", g_tStrings.MSG_OPEN_TOO_MANY)
		return nil
	end
	local x, y = IE_GetNewIEFramePos()
	local frame = Wnd.OpenWindow("InternetExplorer", "IE"..nIndex)
	frame.bIE = true
	frame.nIndex = nIndex

	frame:BringToTop()
	if nLast then
		frame:SetAbsPos(x, y)
		frame:CorrectPos()
		frame.x = x
		frame.y = y
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
		frame.x, frame.y = frame:GetAbsPos()
	end
	local webPage = frame:Lookup("WebPage_Page")
	if szAddr then
		webPage:Navigate(szAddr)
	end
	Station.SetFocusWindow(webPage)
	if not bDisableSound then
		PlaySound(SOUND.UI_SOUND,g_sound.OpenFrame)
	end
	return webPage
end
end

-- dialogue panel
if not IsDialoguePanelOpened then
function IsDialoguePanelOpened()
	local frame = Station.Lookup("Normal/DialoguePanel")
	if frame and frame:IsVisible() then
		return true
	end
	return false
end
end

-- doodad loot
if not IsCorpseAndCanLoot then
function IsCorpseAndCanLoot(dwDoodadID)
	local doodad = GetDoodad(dwDoodadID)
	if not doodad then
		return false
	end
	return (doodad.nKind == DOODAD_KIND.CORPSE and doodad.CanLoot(GetClientPlayer().dwID))
end
end

-- get segment name
if not Table_GetSegmentName then
function Table_GetSegmentName(dwBookID, dwSegmentID)
	local szSegmentName = ""
	local tBookSegment = g_tTable.BookSegment:Search(dwBookID, dwSegmentID)
	if tBookSegment then
		szSegmentName = tBookSegment.szSegmentName
	end
	return szSegmentName
end
end

-- get item name by item
if not GetItemNameByItem then
function GetItemNameByItem(item)
	if item.nGenre == ITEM_GENRE.BOOK then
		local nBookID, nSegID = GlobelRecipeID2BookID(item.nBookID)
		return Table_GetSegmentName(nBookID, nSegID) or g_tStrings.BOOK
	else
		return Table_GetItemName(item.nUiId)
	end
end
end

-- hotkey panel
function HotkeyPanel_Open(szGroup)
	local frame = Station.Lookup("Topmost/HotkeyPanel")
	if not frame then
		frame = Wnd.OpenWindow("HotkeyPanel")
	elseif not frame:IsVisible() then
		frame:Show()
	end
	if not szGroup then return end
	-- load aKey
	local aKey, nI, bindings = nil, 0, Hotkey.GetBinding(false)
	for k, v in pairs(bindings) do
		if v.szHeader ~= "" then
			if aKey then
				break
			elseif v.szHeader == szGroup then
				aKey = {}
			else
				nI = nI + 1
			end
		end
		if aKey then
			if not v.Hotkey1 then
				v.Hotkey1 = {nKey = 0, bShift = false, bCtrl = false, bAlt = false}
			end
			if not v.Hotkey2 then
				v.Hotkey2 = {nKey = 0, bShift = false, bCtrl = false, bAlt = false}
			end
			table.insert(aKey, v)
		end
	end
	if not aKey then return end
	local hP = frame:Lookup("", "Handle_List")
	local hI = hP:Lookup(nI)
	if hI.bSel then return end
	-- update list effect
	for i = 0, hP:GetItemCount() - 1 do
		local hB = hP:Lookup(i)
		if hB.bSel then
			hB.bSel = false
			if hB.IsOver then
				hB:Lookup("Image_Sel"):SetAlpha(128)
				hB:Lookup("Image_Sel"):Show()
			else
				hB:Lookup("Image_Sel"):Hide()
			end
		end
	end
	hI.bSel = true
	hI:Lookup("Image_Sel"):SetAlpha(255)
	hI:Lookup("Image_Sel"):Show()
	-- update content keys [hI.nGroupIndex]
	local hK = frame:Lookup("", "Handle_Hotkey")
	local szIniFile = "UI/Config/default/HotkeyPanel.ini"
	Hotkey.SetCapture(false)
	hK:Clear()
	hK.nGroupIndex = hI.nGroupIndex
	hK:AppendItemFromIni(szIniFile, "Text_GroupName")
	hK:Lookup(0):SetText(szGroup)
	hK:Lookup(0).bGroup = true
	for k, v in ipairs(aKey) do
		hK:AppendItemFromIni(szIniFile, "Handle_Binding")
		local hI = hK:Lookup(k)
		hI.bBinding = true
		hI.nIndex = k
		hI.szTip = v.szTip
		hI:Lookup("Text_Name"):SetText(v.szDesc)
		for i = 1, 2, 1 do
			local hK = hI:Lookup("Handle_Key"..i)
			hK.bKey = true
			hK.nIndex = i
			local hotkey = v["Hotkey"..i]
			hotkey.bUnchangeable = v.bUnchangeable
			hK.bUnchangeable = v.bUnchangeable
			local text = hK:Lookup("Text_Key"..i)
			text:SetText(GetKeyShow(hotkey.nKey, hotkey.bShift, hotkey.bCtrl, hotkey.bAlt))
			-- update btn
			if hK.bUnchangeable then
				hK:Lookup("Image_Key"..hK.nIndex):SetFrame(56)
			elseif hK.bDown then
				hK:Lookup("Image_Key"..hK.nIndex):SetFrame(55)
			elseif hK.bRDown then
				hK:Lookup("Image_Key"..hK.nIndex):SetFrame(55)
			elseif hK.bSel then
				hK:Lookup("Image_Key"..hK.nIndex):SetFrame(55)
			elseif hK.bOver then
				hK:Lookup("Image_Key"..hK.nIndex):SetFrame(54)
			elseif hotkey.bChange then
				hK:Lookup("Image_Key"..hK.nIndex):SetFrame(56)
			elseif hotkey.bConflict then
				hK:Lookup("Image_Key"..hK.nIndex):SetFrame(54)
			else
				hK:Lookup("Image_Key"..hK.nIndex):SetFrame(53)
			end
		end
	end
	-- update content scroll
	hK:FormatAllItemPos()
	local wAll, hAll = hK:GetAllItemSize()
    local w, h = hK:GetSize()
    local scroll = frame:Lookup("Scroll_Key")
    local nCountStep = math.ceil((hAll - h) / 10)
    scroll:SetStepCount(nCountStep)
	scroll:SetScrollPos(0)
	if nCountStep > 0 then
		scroll:Show()
    	scroll:GetParent():Lookup("Btn_Up"):Show()
    	scroll:GetParent():Lookup("Btn_Down"):Show()
    else
    	scroll:Hide()
    	scroll:GetParent():Lookup("Btn_Up"):Hide()
    	scroll:GetParent():Lookup("Btn_Down"):Hide()
    end
	-- update list scroll
	local scroll = frame:Lookup("Scroll_List")
	if scroll:GetStepCount() > 0 then
		local _, nH = hI:GetSize()
		local nStep = math.ceil((nI * nH) / 10)
		if nStep > scroll:GetStepCount() then
			nStep = scroll:GetStepCount()
		end
		scroll:SetScrollPos(nStep)
	end
end

if not DoAcceptJoinBattleField then
function DoAcceptJoinBattleField(nCenterIndex, dwMapID, nCopyIndex, nGroupID, dwJoinValue)
	JH.DoMessageBox("BattleField_Enter_" .. dwMapID, 1)
end
end

if not DoAcceptJoinArena then
function DoAcceptJoinArena(nArenaType, nCenterID, dwMapID, nCopyIndex, nGroupID, dwJoinValue, dwCorpsID)
	JH.DoMessageBox("Arena_Enter_" .. nArenaType, 1)
end
end

if not MakeNameLink then
function MakeNameLink(szName, szFont)
	local szLink = "<text>text=" .. EncodeComponentsString(szName) ..
	szFont .. " name=\"namelink\" eventid=515</text>"
	return szLink
end
end

if not GetCampImageFrame then
function GetCampImageFrame(eCamp, bFight)	-- ui\Image\UICommon\CommonPanel2.UITex
	local nFrame
	if eCamp == CAMP.GOOD then
		if bFight then
			nFrame = 117
		else
			nFrame = 7
		end
	elseif eCamp == CAMP.EVIL then
		if bFight then
			nFrame = 116
		else
			nFrame = 5
		end
	end
	return nFrame
end
end

if not EditBox_AppendLinkPlayer then
function EditBox_AppendLinkPlayer(szName)
	local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
	edit:InsertObj("[".. szName .."]", { type = "name", text = "[".. szName .."]", name = szName })
	Station.SetFocusWindow(edit)
	return true
end
end
if not EditBox_AppendLinkItem then
function EditBox_AppendLinkItem(dwID)
	local item = GetItem(dwID)
	if not item then
		return false
	end
	local szName = "[" .. GetItemNameByItem(item) .."]"
	local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
	edit:InsertObj(szName, { type = "item", text = szName, item = item.dwID })
	Station.SetFocusWindow(edit)
	return true
end
end

if not IsInUICustomMode then
local bCustomMode = false
function IsInUICustomMode()
	return bCustomMode
end
JH.RegisterEvent("ON_ENTER_CUSTOM_UI_MODE", function()
	bCustomMode = true
end)
JH.RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE", function()
	bCustomMode = false
end)
end

if not Table_GetCommonEnchantDesc then
function Table_GetCommonEnchantDesc(enchant_id)
	local res = g_tTable.CommonEnchant:Search(enchant_id)
	if res then
		return res.desc
	end
end
end
if not Table_GetProfessionName then
function Table_GetProfessionName(dwProfessionID)
	local szName = ""
	local tProfession = g_tTable.ProfessionName:Search(dwProfessionID)
	if tProfession then
		szName = tProfession.szName
	end
	return szName
end
end
