-- @Author: Webster
-- @Date:   2015-05-14 13:59:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2017-05-29 02:26:11

local _L = JH.LoadLangPack
local ipairs, pairs, select = ipairs, pairs, select
local unpack, tonumber, type, tostring = unpack, tonumber, type, tostring
local JsonEncode = JH.JsonEncode
local DBMUI_INIFILE     = JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/DBM_UI.ini"
local DBMUI_ITEM_L      = JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/DBM_ITEM_L.ini"
local DBMUI_TALK_L      = JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/DBM_TALK_L.ini"
local DBMUI_ITEM_R      = JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/DBM_ITEM_R.ini"
local DBMUI_TALK_R      = JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/DBM_TALK_R.ini"
local DBMUI_TYPE        = { "BUFF", "DEBUFF", "CASTING", "NPC", "DOODAD", "CIRCLE", "TALK", "CHAT" }
local DBMUI_SELECT_TYPE = DBMUI_TYPE[1]
local DBMUI_SELECT_MAP  = _L["All Data"]
local DBMUI_TREE_EXPAND = { true } -- 默认第一项展开
local DBMUI_SEARCH
local DBMUI_DRAG          = false
local DBMUI_GLOBAL_SEARCH = false
local DBMUI_SEARCH_CACHE  = {}
local DBMUI_PANEL_ANCHOR  = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
local DBMUI_ANCHOR        = {}
local DBMUI = {}

local DBMUI_DOODAD_ICON = {
	[DOODAD_KIND.INVALID]      = 1434, -- 无效
	[DOODAD_KIND.NORMAL]       = 4956, --
	[DOODAD_KIND.CORPSE]       = 179,  -- 尸体
	[DOODAD_KIND.QUEST]        = 1676, -- 任务
	[DOODAD_KIND.READ]         = 243,  -- 阅读
	[DOODAD_KIND.DIALOG]       = 3267, -- 对话
	[DOODAD_KIND.ACCEPT_QUEST] = 1678, -- 接受任务
	[DOODAD_KIND.TREASURE]     = 3557, -- 宝箱
	[DOODAD_KIND.ORNAMENT]     = 1395, -- 装饰物
	[DOODAD_KIND.CRAFT_TARGET] = 351,
	[DOODAD_KIND.CHAIR]        = 3912, -- 椅子
	[DOODAD_KIND.CLIENT_ONLY]  = 240,  --
	[DOODAD_KIND.GUIDE]        = 885,  -- 路牌
	[DOODAD_KIND.DOOR]         = 1890, -- 门
	[DOODAD_KIND.NPCDROP]      = 381,
}
setmetatable(DBMUI_DOODAD_ICON, { __index = function(me, key)
	JH.Debug("unknown Kind" .. key)
	return 369
end })

local function OpenDragPanel(ui)
	local frame = Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/DBM_DRAG.ini", "DBM_DRAG")
	local x, y = Cursor.GetPos()
	local w, h = ui:GetSize()
	-- local x, y = ui:GetAbsPos()
	frame.szName = this:GetName()
	frame:SetAbsPos(x, y)
	frame:StartMoving()
	frame.data = ui.dat
	local szName = DBMUI.GetDataName(DBMUI_SELECT_TYPE, ui.dat)
	frame:Lookup("", "Text"):SetText(szName or ui.dat.key)
	frame:SetSize(w, h)
	frame:Lookup("", "Image"):SetSize(w, h)
	frame:Lookup("", "Text"):SetSize(w, h)
	frame:Lookup("", ""):FormatAllItemPos()
	frame:BringToTop()
	DBMUI_DRAG = true
end

local function CloseDragPanel()
	local frame = Station.Lookup("Normal1/DBM_DRAG")
	if frame then
		frame:EndMoving()
		Wnd.CloseWindow(frame)
		return frame.data, frame.szName
	end
end

local function DragPanelIsOpened()
	return Station.Lookup("Normal1/DBM_DRAG") and Station.Lookup("Normal1/DBM_DRAG"):IsVisible()
end

DBM_UI = {}

function DBM_UI.OnFrameCreate()
	this:RegisterEvent("DBMUI_TEMP_UPDATE")
	this:RegisterEvent("DBMUI_TEMP_RELOAD")
	this:RegisterEvent("DBMUI_DATA_RELOAD")
	if type(Circle) ~= "nil" then
		this:RegisterEvent("CIRCLE_RELOAD")
	end
	this:RegisterEvent("UI_SCALED")
	-- Esc
	JH.RegisterGlobalEsc("DBM", DBMUI.IsOpened, DBMUI.ClosePanel)
	-- CreateItemData
	this.hItemL = this:CreateItemData(DBMUI_ITEM_L, "Handle_L")
	this.hTalkL = this:CreateItemData(DBMUI_TALK_L, "Handle_TALK_L")
	this.hItemR = this:CreateItemData(DBMUI_ITEM_R, "Handle_R")
	this.hTalkR = this:CreateItemData(DBMUI_TALK_R, "Handle_TALK_R")
	-- tree
	this.hTreeT = this:CreateItemData(DBMUI_INIFILE, "TreeLeaf_Node")
	this.hTreeC = this:CreateItemData(DBMUI_INIFILE, "TreeLeaf_Content")
	this.hTreeH = this:Lookup("PageSet_Main/WndScroll_Tree", "Handle_Tree_List")

	DBMUI_SEARCH = nil -- 重置搜索
	DBMUI_GLOBAL_SEARCH = false
	DBMUI_DRAG = false

	this.hPageSet = this:Lookup("PageSet_Main")
	local ui = GUI(this)
	ui:Title(_L["JX3 DBM Plug-in"])
	for k, v in ipairs(DBMUI_TYPE) do
		local txt = this.hPageSet:Lookup("CheckBox_" .. v, "Text_Page_" .. v)
		txt:SetText(_L[v])
		if v == "CIRCLE" and type(Circle) == "nil" then
			this.hPageSet:Lookup("CheckBox_" .. v):Enable(false)
			txt:SetFontColor(192, 192, 192)
		end
	end
	ui:Append("WndButton4", { x = 895, y = 52, txt = g_tStrings.SYS_MENU }):Click(function()
		local menu = {}
		table.insert(menu, { szOption = _L["Import Data (local)"], fnAction = function() DBMUI.OpenImportPanel() end }) -- 有传惨 不要改
		local szLang = select(3, GetVersion())
		if szLang == "zhcn" or szLang == "zhtw" then
			table.insert(menu, { szOption = _L["Import Data (web)"], fnAction = DBM_RemoteRequest.TogglePanel })
		end
		table.insert(menu, { szOption = _L["Export Data"], fnAction = DBMUI.OpenExportPanel })
		PopupMenu(menu)
	end)
	-- debug
	if JH.bDebugClient then
		ui:Append("WndButton", { txt = "debug", x = 10, y = 10 }):Click(ReloadUIAddon)
		ui:Append("WndButton", "On", { txt = "Enable", x = 110, y = 10, enable = not DBM.bEnable }):Click(function()
			DBM_API.Enable(true, true)
			this:Enable(false)
			ui:Fetch("Off"):Enable(true)
			DBM.bEnable = true
		end)
		ui:Append("WndButton", "Off", { txt = "Disable", x = 210, y = 10, enable = DBM.bEnable }):Click(function()
			DBM_API.Enable(false)
			this:Enable(false)
			ui:Fetch("On"):Enable(true)
			DBM.bEnable = false
		end)
	end
	local hSearch = ui:Fetch("PageSet_Main"):Append("WndEdit", "WndEdit_Search", { x = 50, y = 38, txt = g_tStrings.SEARCH, w = 500, h = 25 })
	hSearch:Change(function(szText)
		if JH.Trim(szText) == "" then
			DBMUI_SEARCH = nil
		else
			DBMUI_SEARCH = JH.Trim(szText)
		end
		FireUIEvent("DBMUI_TEMP_RELOAD")
		FireUIEvent("DBMUI_DATA_RELOAD")
	end):Focus(function(bFocus)
		if bFocus then
			if this:GetText() == g_tStrings.SEARCH then
				hSearch:Text("", true)
			end
		else
			FireUIEvent("DBMUI_FREECACHE")
		end
	end)
	ui:Fetch("PageSet_Main"):Append("WndCheckBox", { x = 560, y = 38, checked = DBMUI_GLOBAL_SEARCH, txt = _L["Global Search"] }):Click(function(bCheck)
		DBMUI_GLOBAL_SEARCH = bCheck
		FireUIEvent("DBMUI_TEMP_RELOAD")
		FireUIEvent("DBMUI_DATA_RELOAD")
	end)
	ui:Fetch("PageSet_Main"):Append("WndButton2", "NewFace", { x = 720, y = 40, txt = _L["New Face"] }):Click(function()
		Circle.OpenAddPanel(nil, nil, DBMUI_SELECT_MAP ~= _L["All Data"] and JH.IsMapExist(DBMUI_SELECT_MAP))
	end)
	ui:Fetch("PageSet_Main"):Append("WndButton2", { x = 860, y = 40, txt = _L["Clear Record"] }):Click(function()
		JH.Confirm(_L["Confirm?"], function()
			DBM_API.ClearTemp(DBMUI_SELECT_TYPE)
		end)
	end)
	DBMUI.UpdateAnchor(this)
	-- 首次加载
	for k, v in ipairs(DBMUI_TYPE) do
		if DBMUI_SELECT_TYPE == v then
			this.hPageSet:ActivePage(k - 1)
			break
		end
	end
end

function DBM_UI.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		DBMUI.UpdateAnchor(this)
	elseif szEvent == "DBMUI_TEMP_UPDATE" then
		local szType = (DBMUI_SELECT_TYPE == "CIRCLE" and arg0 == "NPC") and "CIRCLE" or arg0
		if szType ~= DBMUI_SELECT_TYPE then
			return
		end
		DBMUI.UpdateRList(arg1)
	elseif szEvent == "DBMUI_TEMP_RELOAD" or szEvent == "DBMUI_DATA_RELOAD" or szEvent == "CIRCLE_RELOAD" then
		if szEvent == "CIRCLE_RELOAD" and arg0 and DBMUI_SELECT_TYPE == "CIRCLE" then
			DBMUI_SELECT_MAP = arg0
		end
		if szEvent == "DBMUI_DATA_RELOAD" or szEvent == "CIRCLE_RELOAD" then
			DBMUI.RefreshTable("L")
		elseif szEvent == "DBMUI_TEMP_RELOAD" then
			DBMUI.RefreshTable("R")
		end
	end
end

function DBM_UI.OnFrameDragEnd()
	DBMUI_ANCHOR = GetFrameAnchor(this)
end

function DBMUI.RefreshTable(szRefresh)
	if szRefresh == "L" then
		DBMUI.UpdateLList()
		DBMUI.UpdateTree()
	elseif szRefresh == "R" then
		DBMUI.UpdateRList()
	end
end
-- 用于刷新滚动条 来刷新内容
function DBMUI.RefreshScroll(szRefresh)
	local frame = DBMUI.GetFrame()
	local hWndScroll = frame.hPageSet:GetActivePage():Lookup(string.format("WndScroll_%s_%s/Btn_%s_%s_ALL", DBMUI_SELECT_TYPE, szRefresh, DBMUI_SELECT_TYPE, szRefresh))
	-- 修改指针
	local _this = this
	this = hWndScroll
	DBM_UI.OnScrollBarPosChanged()
	this = _this
end

function DBMUI.ConflictCheck()
	if DBMUI_SELECT_TYPE == "BUFF" or DBMUI_SELECT_TYPE == "DEBUFF"	or DBMUI_SELECT_TYPE == "CASTING" then
		local data = DBM_API.GetTable(DBMUI_SELECT_TYPE)
		local bMsg = false
		for k, v in pairs(data) do
			if k ~= -9 then
				local tTemp = {}
				for kk, vv in ipairs(v) do
					tTemp[vv.dwID] = tTemp[vv.dwID] or {}
					table.insert(tTemp[vv.dwID], vv)
				end
				for kk, vv in pairs(tTemp) do
					if #vv > 1 then
						for kkk, vvv in ipairs(vv) do
							if not vvv.bCheckLevel then
								bMsg = true
								JH.Sysmsg2(_L["Data Conflict"] .. " " .. _L[DBMUI_SELECT_TYPE] .. " " .. DBMUI.GetMapName(k) .. " :: " .. vvv.dwID .. " :: " .. (vvv.szName or DBMUI.GetDataName(DBMUI_SELECT_TYPE, vvv)), "DBM")
								break
							end
						end
					end
				end
			end
		end
		if bMsg then
			JH.Sysmsg2(_L["Data Conflict Please check."])
		end
	end
end

function DBM_UI.OnActivePage()
	local nPage = this:GetActivePageIndex()
	DBMUI_SELECT_TYPE = DBMUI_TYPE[nPage + 1]
	if DBMUI_SELECT_TYPE ~= "CIRCLE" then
		this:Lookup("NewFace"):Hide()
	else
		this:Lookup("NewFace"):Show()
	end
	DBMUI.RefreshTable("L")
	DBMUI.RefreshTable("R")
	FireUIEvent("DBMUI_SWITCH_PAGE")
	DBMUI.ConflictCheck()
	DBMUI.UpdateBG()
end

function DBMUI.UpdateBG()
	-- background
	local frame = DBMUI.GetFrame()
	local info = g_tTable.DungeonInfo:Search(DBMUI_SELECT_MAP)
	if DBMUI_SELECT_TYPE ~= "TALK" and DBMUI_SELECT_TYPE ~= "CHAT" and info and info.szDungeonImage2 then
		frame:Lookup("", "Handle_BG"):Show()
		frame:Lookup("", "Handle_BG/Image_BG"):FromUITex(info.szDungeonImage2, 0)
		frame:Lookup("", "Handle_BG/Text_BgTitle"):SetText(info.szLayer3Name .. g_tStrings.STR_CONNECT .. info.szOtherName)
	else
		frame:Lookup("", "Handle_BG"):Hide()
	end
end

function DBMUI.UpdateTree()
	local frame     = DBMUI.GetFrame()
	local nSelectID = DBMUI_SELECT_MAP
	local tDungeon  = DBM_API.GetDungeon()
	local data      = DBM_API.GetTable(DBMUI_SELECT_TYPE)
	local dwMapID   = JH.GetMapID()
	local tCount    = {}
	local hSelect
	local function GetCount(data)
		local nCount = data and #data or 0
		if DBMUI_SEARCH and data then
			nCount = 0
			for k, v in ipairs(data) do
				if DBMUI.CheckSearch(DBMUI_SELECT_TYPE, v) then
					nCount = nCount + 1
				end
			end
		end
		return nCount
	end
	local function Format(hTreeT, hTreeC, key, ...)
		local nCount = GetCount(data[key])
		local szName = DBMUI.GetMapName(key) or key
		local tFilter = { ... }
		for i = 1, select("#", ...) do
			szName = szName:gsub(tFilter[i], "") or szName
		end
		if key ~= _L["All Data"] then
			local szClassName = hTreeT.szName or hTreeT:Lookup(1):GetText()
			hTreeT.szName = szClassName
			tCount[hTreeT] = tCount[hTreeT] or 0
			tCount[hTreeT] = tCount[hTreeT] + nCount
			hTreeT:Lookup(1):SetText(szClassName .. " (".. tCount[hTreeT] .. ")")
		end
		hTreeC:Lookup(1):SetText(szName .. " (".. nCount .. ")")
		hTreeC.dwMapID = key
		hTreeC.nCount = nCount
		if nCount == 0 then
			hTreeC.col = { 168, 168, 168 }
			hTreeC:Lookup(1):SetFontColor(168, 168, 168)
		end
		if nSelectID == key then
			hTreeC:Lookup(0):Show()
			hTreeC:Lookup(1):SetFontColor(255, 255, 0)
			frame.hTreeH.hSelect = hTreeC
		end
		if dwMapID == key then
			hSelect = hTreeT
			hTreeC.col = { 168, 168, 255 }
			hTreeC:Lookup(1):SetFontColor(168, 168, 255)
		end
	end
	frame.hTreeH:Clear()
	local hTreeT = frame.hTreeH:AppendItemFromData(frame.hTreeT)
	hTreeT:Lookup(1):SetText(g_tStrings.STR_GUILD_ALL .. "/" .. g_tStrings.OTHER)
	-- 全部 / 通用
	local hTreeC = frame.hTreeH:AppendItemFromData(frame.hTreeC)
	Format(hTreeT, hTreeC, _L["All Data"])
	local hTreeC = frame.hTreeH:AppendItemFromData(frame.hTreeC)
	Format(hTreeT, hTreeC, -1)
	-- 其他
	for k, v in pairs(data) do
		if (k > 0 and not JH.IsDungeon(k, true)) and (tonumber(k) and k > 0) then
			local hTreeC = frame.hTreeH:AppendItemFromData(frame.hTreeC)
			Format(hTreeT, hTreeC, k)
		end
	end
	for _, v in ipairs(tDungeon) do
		local hTreeT = frame.hTreeH:AppendItemFromData(frame.hTreeT)
		hTreeT:Lookup(1):SetText(v.szLayer3Name)
		for _, vv in ipairs(v.aList) do
			local hTreeC = frame.hTreeH:AppendItemFromData(frame.hTreeC)
			Format(hTreeT, hTreeC, vv, _L["Battle of Taiyuan"], _L["YongWangXingGong"], v.szLayer3Name)
		end
	end
	local hTreeT = frame.hTreeH:AppendItemFromData(frame.hTreeT)
	hTreeT:Lookup(1):SetText(_L["recycle bin"])
	local hTreeC = frame.hTreeH:AppendItemFromData(frame.hTreeC)
	Format(hTreeT, hTreeC, -9)
	if hSelect then
		local hLocation = hSelect:Lookup("Image_Location")
		local w, h = hSelect:Lookup(1):GetTextExtent()
		hLocation:SetRelX(w)
		hLocation:Show()
		hSelect:FormatAllItemPos()
	end
	-- 还原列表展开
	local n = 1
	for i = 0, frame.hTreeH:GetItemCount() - 1 do
		local item = frame.hTreeH:Lookup(i)
		if item and item:GetIndent() == 0 then
			if DBMUI_TREE_EXPAND[n] then
				item:Expand()
			else
				item:Collapse()
			end
			if tCount[item] == 0 then
				item:Lookup(1):SetFontColor(222, 222, 222)
			end
			n = n + 1
		end
	end
	frame.hTreeH:FormatAllItemPos()
end

function DBM_UI.OnItemLButtonDown()
	local szName = this:GetName()
	if IsCtrlKeyDown() then
		if szName == "Handle_R" or szName == "Handle_L" then
			local data = {}
			local szName
			if this:Lookup("Text") then
				if DBMUI_SELECT_TYPE == "CASTING" then
					szName = "[" .. Table_GetSkillName(this.dat.dwID, this.dat.nLevel) .. "]"
					data = {
						type = "skill",
						skill_id = this.dat.dwID,
						skill_level = this.dat.nLevel,
						text = szName
					}
				else
					szName = this:Lookup("Text"):GetText()
					data   = { type = "text", text = szName }
				end
			elseif this:Lookup("Text_Name") and this:Lookup("Text_Content") then
				szName = this:Lookup("Text_Name"):GetText() .. g_tStrings.STR_COLON .. this:Lookup("Text_Content"):GetText()
				data   = { type = "text", text = szName }
			end
			if szName then
				local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
				edit:InsertObj(szName, data)
				Station.SetFocusWindow(edit)
			end
		end
	end
end

function DBM_UI.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Close" then
		DBMUI.ClosePanel()
	end
end

function DBM_UI.OnItemLButtonClick()
	local szName = this:GetName()
	if szName == "TreeLeaf_Node" then
		if this:IsExpand() then
			this:Collapse()
		else
			this:Expand()
		end
		local handle = this:GetParent()
		DBMUI_TREE_EXPAND = {}
		for i = 0, handle:GetItemCount() - 1 do
			local item = handle:Lookup(i)
			if item and item:GetIndent() == 0 then
				table.insert(DBMUI_TREE_EXPAND, item:IsExpand())
			end
		end
		handle:FormatAllItemPos()
	elseif szName == "TreeLeaf_Content" then
		-- 重新着色
		local handle = this:GetParent()
		if handle.hSelect and handle.hSelect:IsValid() then
			handle.hSelect:Lookup(0):Hide()
			local col = handle.hSelect.col and handle.hSelect.col or { 255, 255, 255 }
			handle.hSelect:Lookup(1):SetFontColor(unpack(col))
		end
		this:Lookup(0):Show()
		this:Lookup(1):SetFontColor(255, 255, 0)
		handle.hSelect = this
		-- 刷新数据
		DBMUI_SELECT_MAP = this.dwMapID
		DBMUI.UpdateLList()
		DBMUI.UpdateBG()
	elseif szName == "Handle_L" then
		if DBMUI_DRAG or IsCtrlKeyDown() then
			return
		end
		if DBMUI_SELECT_TYPE == "CIRCLE" then
			Circle.OpenDataPanel(this.dat)
		else
			DBMUI.OpenSettingPanel(this.dat, DBMUI_SELECT_TYPE)
		end
	end
end

function DBM_UI.OnItemRButtonClick()
	local szName = this:GetName()
	if szName == "TreeLeaf_Content" then
		local menu = {}
		local dwMapID = this.dwMapID
		if dwMapID ~= _L["All Data"] then
			local szName =
			table.insert(menu, { szOption = this:Lookup(1):GetText(), bDisable = true })
			table.insert(menu, { bDevide = true })
			table.insert(menu, { szOption = _L["Clear this map data"], rgb = { 255, 0, 0 }, fnAction = function()
				if DBMUI_SELECT_TYPE == "CIRCLE" then
					Circle.RemoveData(dwMapID, nil, true)
				else
					DBMUI.RemoveData(dwMapID, nil, JH.IsMapExist(dwMapID))
				end
			end })
			PopupMenu(menu)
		end
	elseif szName == "Handle_L" then
		local t = this.dat
		local menu = {}
		local name = this:Lookup("Text") and this:Lookup("Text"):GetText() or t.szContent
		if DBMUI_SELECT_TYPE ~= "TALK" and DBMUI_SELECT_TYPE ~= "CHAT" then -- 太长
			table.insert(menu, { szOption = g_tStrings.CHAT_NAME .. g_tStrings.STR_COLON .. name, bDisable = true })
		end
		table.insert(menu, { szOption = _L["Class"] .. g_tStrings.STR_COLON .. (DBMUI.GetMapName(t.dwMapID) or t.dwMapID), bDisable = true })
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = g_tStrings.STR_FRIEND_MOVE_TO })
		table.insert(menu[#menu], { szOption = _L["Manual input"], fnAction = function()
			GetUserInput(g_tStrings.MSG_INPUT_MAP_NAME, function(szText)
				local map = JH.IsMapExist(szText)
				if map then
					if DBMUI_SELECT_TYPE == "CIRCLE" then
						return Circle.MoveData(t.dwMapID, t.nIndex, map, IsCtrlKeyDown())
					else
						return DBMUI.MoveData(t.dwMapID, t.nIndex, map, IsCtrlKeyDown())
					end
				end
				return JH.Alert(_L["The map does not exist"])
			end)
		end })
		table.insert(menu[#menu], { bDevide = true })
		DBMUI.InsertDungeonMenu(menu[#menu], function(dwMapID)
			if DBMUI_SELECT_TYPE == "CIRCLE" then
				Circle.MoveData(t.dwMapID, t.nIndex, dwMapID, IsCtrlKeyDown())
			else
				DBMUI.MoveData(t.dwMapID, t.nIndex, dwMapID, IsCtrlKeyDown())
			end
		end)
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = _L["Share Data"], bDisable = not JH.IsInParty(), fnAction = function()
			if JH.IsLeader() or JH.bDebugClient then
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "DBM_SHARE", DBMUI_SELECT_TYPE, t.dwMapID, t)
				JH.Topmsg(g_tStrings.STR_MAIL_SUCCEED)
			else
				return JH.Alert(_L["You are not team leader."])
			end
		end })
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = g_tStrings.STR_FRIEND_DEL, rgb = { 255, 0, 0 }, fnAction = function()
			if DBMUI_SELECT_TYPE == "CIRCLE" then
				Circle.RemoveData(t.dwMapID, t.nIndex, true)
			else
				DBMUI.RemoveData(t.dwMapID, t.nIndex, name)
			end
		end })
		PopupMenu(menu)
	elseif szName == "Handle_R" then
		local menu = {}
		local t = this.dat
		local szName = DBMUI.GetDataName(DBMUI_SELECT_TYPE, t)
		-- table.insert(menu, { szOption = _L["Add to monitor list"], fnAction = function() DBMUI.OpenAddPanel(DBMUI_SELECT_TYPE, t) end })
		-- table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = g_tStrings.STR_DATE .. g_tStrings.STR_COLON .. FormatTime("%Y%m%d %H:%M:%S",t.nCurrentTime) , bDisable = true })
		if DBMUI_SELECT_TYPE ~= "TALK" and DBMUI_SELECT_TYPE ~= "CHAT" then
			table.insert(menu, { szOption = g_tStrings.CHAT_NAME .. g_tStrings.STR_COLON .. szName, bDisable = true })
		end
		table.insert(menu, { szOption = g_tStrings.MAP_TALK .. g_tStrings.STR_COLON .. Table_GetMapName(t.dwMapID), bDisable = true })
		if DBMUI_SELECT_TYPE ~= "NPC" and DBMUI_SELECT_TYPE ~= "CIRCLE" and DBMUI_SELECT_TYPE ~= "TALK" and DBMUI_SELECT_TYPE ~= "DOODAD" then
			table.insert(menu, { szOption = g_tStrings.STR_SKILL_H_CAST_TIME .. (t.szSrcName or g_tStrings.STR_CRAFT_NONE) .. (t.bIsPlayer and _L["(player)"] or ""), bDisable = true })
		end
		if DBMUI_SELECT_TYPE ~= "TALK" and DBMUI_SELECT_TYPE ~= "CHAT" then
			local cmenu = { szOption = _L["Interval Time"] }
			local tInterval
			if t.nLevel then
				tInterval = DBM_API.GetIntervalData(DBMUI_SELECT_TYPE, t.dwID .. "_" .. t.nLevel)
			else
				tInterval = DBM_API.GetIntervalData(DBMUI_SELECT_TYPE, t.dwID)
			end

			if tInterval and #tInterval > 1 then
				local nTime = tInterval[#tInterval]
				for k, v in JH.bpairs(tInterval) do
					if #cmenu == 16 then break end
					table.insert(cmenu, { szOption = string.format("%.1f", (nTime - v) / 1000) .. g_tStrings.STR_TIME_SECOND })
					nTime = v
				end
				table.remove(cmenu, 1)
			else
				table.insert(cmenu, { szOption = g_tStrings.STR_FIGHT_NORECORD, bDisable = true })
			end
			table.insert(menu, cmenu)
		end
		PopupMenu(menu)
	end
end

function DBM_UI.OnItemMouseLeave()
	local szName = this:GetName()
	if szName == "TreeLeaf_Node" or szName == "TreeLeaf_Content" then
		local handle = this:GetParent()
		if handle.hSelect ~= this and this:IsValid() and this:Lookup(0) and this:Lookup(0):IsValid() then
			this:Lookup(0):Hide()
		end
	elseif szName == "Handle_L" or szName == "Handle_R" then
		if DBMUI_SELECT_TYPE == "TALK" or DBMUI_SELECT_TYPE == "CHAT" then
			if this:Lookup("Image_Light") and this:Lookup("Image_Light"):IsValid() then
				this:Lookup("Image_Light"):Hide()
			end
		else
			if this:Lookup("Image") and this:Lookup("Image"):IsValid() then
				this:Lookup("Image"):SetFrame(7)
				local box = this:Lookup("Box")
				if box and box:IsValid() then
					box:SetObjectMouseOver(false)
				end
			end
		end
	end
	HideTip()
end

function DBM_UI.OnItemMouseEnter()
	local szName = this:GetName()
	local x, y = this:GetAbsPos()
	local w, h = this:GetSize()
	if szName == "TreeLeaf_Node" or szName == "TreeLeaf_Content" then
		this:Lookup(0):Show()
		if szName == "TreeLeaf_Content" then
			local info = g_tTable.DungeonInfo:Search(this.dwMapID)
			local szXml = GetFormatText((DBMUI.GetMapName(this.dwMapID) or this.dwMapID) .." (" .. this.nCount ..  ")\n", 47, 255, 255, 0)
			if info and JH.Trim(info.szBossInfo) ~= "" then
				local tBoss = JH.Split(info.szBossInfo, " ")
				for k, v in ipairs(tBoss or {}) do
					if JH.Trim(v) ~= "" then
						szXml = szXml .. GetFormatText(k .. ") " .. v .. "\n", 47, 255, 255, 255)
					end
				end
				szXml = szXml .. GetFormatImage(info.szDungeonImage3, 0, 200, 200)
			end
			if IsCtrlKeyDown() then
				szXml = szXml .. GetFormatText("\n\n" .. g_tStrings.DEBUG_INFO_ITEM_TIP .. "\nMapID:" .. this.dwMapID, 47, 255, 0, 0)
			end
			OutputTip(szXml, 300, { x, y, w, h })
		end
	elseif szName == "Handle_L" or szName == "Handle_R" then
		if DBMUI_SELECT_TYPE == "TALK" or DBMUI_SELECT_TYPE == "CHAT" then
			this:Lookup("Image_Light"):Show()
		else
			this:Lookup("Image"):SetFrame(8)
			local box = this:Lookup("Box")
			box:SetObjectMouseOver(true)
		end
		if szName == "Handle_R" and DBMUI_SELECT_TYPE == "CIRCLE" then -- circle fix
			DBMUI.OutputTip("NPC", this.dat, { x, y, w, h })
		else
			DBMUI.OutputTip(DBMUI_SELECT_TYPE, this.dat, { x, y, w, h })
		end

	end
end

function DBM_UI.OnItemLButtonDrag()
	local szName = this:GetName()
	if szName == "Handle_L" or szName == "Handle_R" then
		OpenDragPanel(this)
	end
end

function DBM_UI.OnItemLButtonDragEnd()
	local szName = this:GetName()
	if not DragPanelIsOpened() then
		return
	end
	local data, szAction = CloseDragPanel()
	if szName == "TreeLeaf_Content" then
		if szAction:find("Handle.+L") then
			if data and data.dwMapID ~= this.dwMapID then
				if DBMUI_SELECT_TYPE == "CIRCLE" then
					Circle.MoveData(data.dwMapID, data.nIndex, this.dwMapID, IsCtrlKeyDown())
				else
					DBMUI.MoveData(data.dwMapID, data.nIndex, this.dwMapID, IsCtrlKeyDown())
				end
			end
		elseif szAction:find("Handle.+R") then
			DBMUI.OpenAddPanel(DBMUI_SELECT_TYPE, data)
		end
	elseif szName:find("Handle.+L") then
		if szAction:find("Handle.+L") and not szName:find("Handle.+List_L") then
			if DBMUI_SELECT_MAP ~= _L["All Data"] then
				if DBMUI_SELECT_TYPE == "CIRCLE" then
					Circle.Exchange(DBMUI_SELECT_MAP, data.nIndex, this.dat.nIndex)
				else
					DBMUI.Exchange(DBMUI_SELECT_MAP, data.nIndex, this.dat.nIndex)
				end
			else
				DBMUI.UpdateTree(this:GetRoot())
			end
		elseif szAction:find("Handle.+R") then
			DBMUI.OpenAddPanel(DBMUI_SELECT_TYPE, data)
		end
	end
	JH.DelayCall(function() -- 由于 click在 dragend 之后
		 DBMUI_DRAG = false
	end, 50)
end

-- 优化核心函数 根据滚动条加载内容
function DBM_UI.OnScrollBarPosChanged()
	-- print(this:GetName())
	local hWndScroll = this:GetParent()
	local szName = hWndScroll:GetName()
	local dir = szName:match("WndScroll_" .. DBMUI_SELECT_TYPE .. "_(.*)")
	if dir then
		local handle = hWndScroll:Lookup("", string.format("Handle_%s_List_%s", DBMUI_SELECT_TYPE, dir))
		local nPer = this:GetScrollPos() / math.max(1, this:GetStepCount())
		local nCount = math.ceil(handle:GetItemCount() * nPer)
		for i = math.max(0, nCount - 21), nCount + 21, 1 do -- 每次渲染两页
			local h = handle:Lookup(i)
			if h then
				if not h.bDraw then
					if DBMUI_SELECT_TYPE == "BUFF" or DBMUI_SELECT_TYPE == "DEBUFF" then
						DBMUI.SetBuffItemAction(h)
					elseif DBMUI_SELECT_TYPE == "CASTING" then
						DBMUI.SetCastingItemAction(h)
					elseif DBMUI_SELECT_TYPE == "NPC" then
						DBMUI.SetNpcItemAction(h)
					elseif DBMUI_SELECT_TYPE == "DOODAD" then
						DBMUI.SetDoodadItemAction(h)
					elseif DBMUI_SELECT_TYPE == "CIRCLE" and dir == "L" then
						DBMUI.SetCircleItemAction(h)
					elseif DBMUI_SELECT_TYPE == "CIRCLE" and dir == "R"  then
						DBMUI.SetNpcItemAction(h)
					elseif DBMUI_SELECT_TYPE == "TALK" then
						DBMUI.SetTalkItemAction(h)
					elseif DBMUI_SELECT_TYPE == "CHAT" then
						DBMUI.SetChatItemAction(h)
					end
				end
			else
				break
			end
		end
	end
end

function DBMUI.OutputTip(szType, data, rect)
	if szType == "BUFF" or szType == "DEBUFF" then
		JH.OutputBuffTip(data.dwID, data.nLevel, rect)
	elseif szType == "CASTING" then
		OutputSkillTip(data.dwID, data.nLevel, rect)
	elseif szType == "NPC" then
		JH.OutputNpcTip(data.dwID, rect)
	elseif szType == "DOODAD" then
		JH.OutputDoodadTip(data.dwID, rect)
	elseif szType == "TALK" then
		OutputTip(GetFormatText((data.szTarget or _L["Warning Box"]) .. "\t", 41, 255, 255, 0) .. GetFormatText((DBMUI.GetMapName(data.dwMapID) or data.dwMapID) .. "\n", 41, 255, 255, 255) .. GetFormatText(data.szContent, 41, 255, 255, 255), 300, rect)
	elseif szType == "CHAT" then
		OutputTip(GetFormatText(_L["CHAT"] .. "\t", 41, 255, 255, 0) .. GetFormatText((DBMUI.GetMapName(data.dwMapID) or data.dwMapID) .. "\n", 41, 255, 255, 255) .. GetFormatText(data.szContent, 41, 255, 255, 255), 300, rect)
	elseif szType == "CIRCLE" then
		Circle.OutputTip(data, rect)
	end
end

function DBMUI.InsertDungeonMenu(menu, fnAction)
	local me = GetClientPlayer()
	local dwMapID = me.GetMapID()
	local tDungeon =  DBM_API.GetDungeon()
	local data = DBM_API.GetTable(DBMUI_SELECT_TYPE)
	table.insert(menu, { szOption = g_tStrings.CHANNEL_COMMON .. " (" .. (data[-1] and #data[-1] or 0) .. ")", fnAction = function()
		if fnAction then
			fnAction(-1)
		end
	end })
	table.insert(menu, { bDevide = true })
	for k, v in ipairs(tDungeon) do
		local tMenu = { szOption = v.szLayer3Name }
		for _, vv in ipairs(v.aList) do
			table.insert(tMenu, {
				szOption = Table_GetMapName(vv) .. " (" .. (data[vv] and #data[vv] or 0) .. ")",
				rgb      = { 255, 128, 0 },
				szIcon   = dwMapID == vv and "ui/Image/Minimap/Minimap.uitex",
				szLayer  = dwMapID == vv and "ICON_RIGHT",
				nFrame   = dwMapID == vv and 10,
				fnAction = function()
					if fnAction then
						fnAction(vv)
					end
				end
			})
		end
		table.insert(menu, tMenu)
	end
end

function DBMUI.OpenImportPanel(szDefault, szTitle, fnAction)
	local ui = GUI.CreateFrame("DBM_DatatPanel", { w = 720, h = 300, title = _L["Import Data"], close = true })
	local nX, nY = ui:Append("Text", { x = 20, y = 50, txt = _L["includes"], font = 27 }):Pos_()
	nX = 25
	for k, v in ipairs(DBMUI_TYPE) do
		nX = ui:Append("WndCheckBox", v, { x = nX + 5, y = nY + 5, checked = true, txt = _L[v] }):Pos_()
	end
	nY = 100
	nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["File Name"], font = 27 }):Pos_()
	nX = ui:Append("WndEdit", "FilePtah", { x = 30, y = nY + 10, w = 450, h = 25, txt = szTitle, enable = not szDefault }):Pos_()
	nX, nY = ui:Append("WndButton2", { x = nX + 5, y = nY + 10, txt = _L["browse"], enable = not szDefault }):Click(function()
		local szFile = GetOpenFileName(_L['please select data file.'], "DBM data File(*.jx3dat)\0*.jx3dat\0All Files(*.*)\0*.*\0")
		if szFile ~= "" and not szFile:lower():find("interface") then
			JH.Alert(_L["please select interface path."])
			ui:Fetch("FilePtah"):Text("")
		else
			ui:Fetch("FilePtah"):Text(szFile)
		end
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["Import mode"], font = 27 }):Pos_()
	local nType = 1
	nX = ui:Append("WndRadioBox", { x = 30, y = nY + 10, txt = _L["Cover"], group = "type", checked = true }):Click(function()
		nType = 1
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = _L["Merge Priority new file"], group = "type" }):Click(function()
		nType = 3
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = _L["Merge Priority old file"], group = "type" }):Click(function()
		nType = 2
	end):Pos_()
	ui:Append("WndButton3", { x = 285, y = nY + 30, txt = g_tStrings.STR_HOTKEY_SURE }):Click(function()
		local config = {
			bFullPath  = not szDefault,
			szFileName = szDefault or ui:Fetch("FilePtah"):Text(),
			nMode      = nType,
			tList      = {}
		}
		for k, v in ipairs(DBMUI_TYPE) do
			if ui:Fetch(v):Check() then
				config.tList[v] = true
			end
		end
		local bStatus, szMsg = DBM_API.LoadConfigureFile(config)
		JH.Debug("#DBM# load config: " .. tostring(szMsg))
		if bStatus then
			JH.Alert(_L("Import success %s", szTitle or szMsg))
			ui:Remove()
			if fnAction then
				fnAction()
			end
		else
			JH.Alert(_L("Import failed %s", szTitle or _L[szMsg]))
		end
	end)
end

function DBMUI.OpenExportPanel()
	local ui = GUI.CreateFrame("DBM_DatatPanel", { w = 720, h = 300, title = _L["Export Data"], close = true })
	local nX, nY = ui:Append("Text", { x = 20, y = 50, txt = _L["includes"], font = 27 }):Pos_()
	nX = 25
	for k, v in ipairs(DBMUI_TYPE) do
		nX = ui:Append("WndCheckBox", v, { x = nX + 5, y = nY + 5, checked = true, txt = _L[v] }):Pos_()
	end
	nY = 100
	local szFileName = "DBM-" .. select(3, GetVersion()) .. FormatTime("-%Y%m%d_%H.%M", GetCurrentTime()) .. ".jx3dat"
	nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["File Name"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndEdit", { x = 30, y = nY + 10, w = 500, h = 25, txt = szFileName }):Change(function(szText)
		szFileName = szText
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["File Format"], font = 27 }):Pos_()
	local nType = 1
	nX = ui:Append("WndRadioBox", { x = 30, y = nY + 10, txt = _L["LUA TABLE"], group = "type", checked = true }):Click(function()
		nType = 1
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = _L["JSON"], group = "type", enable = false }):Click(function()
		nType = 2
	end):Pos_()
	ui:Append("WndCheckBox", "Format", { x = 20, y = nY + 50, txt = _L["Format content"] })
	ui:Append("WndButton3", { x = 285, y = nY + 30, txt = g_tStrings.STR_HOTKEY_SURE }):Click(function()
		local config = {
			bFormat = ui:Fetch("Format"):Check(),
			szFileName = szFileName,
			bJson = nType == 2,
			tList = {}
		}
		for k, v in ipairs(DBMUI_TYPE) do
			if ui:Fetch(v):Check() then
				config.tList[v] = true
			end
		end
		local path = DBM_API.SaveConfigureFile(config)
		JH.Alert(_L("Export success %s", path))
		ui:Remove()
	end)
end

function DBMUI.MoveData( ... )
	DBM_API.MoveData(DBMUI_SELECT_TYPE, ... )
end

function DBMUI.Exchange( ... )
	DBM_API.Exchange(DBMUI_SELECT_TYPE, ...)
end

function DBMUI.RemoveData(dwMapID, nIndex, szMsg)
	local function fnAction()
		DBM_API.RemoveData(DBMUI_SELECT_TYPE, dwMapID, nIndex)
	end
	if not nIndex then
		JH.Confirm(FormatString(g_tStrings.MSG_DELETE_NAME, szMsg), fnAction)
	else
		fnAction()
	end
end

function DBMUI.GetSearchCache(data)
	if not DBMUI_SEARCH_CACHE[DBMUI_SELECT_TYPE] then
		DBMUI_SEARCH_CACHE[DBMUI_SELECT_TYPE] = {}
	end
	local tab = DBMUI_SEARCH_CACHE[DBMUI_SELECT_TYPE]
	local szString
	if data.dwMapID and data.nIndex then
		if tab[data.dwMapID] and tab[data.dwMapID][data.nIndex] then
			szString = tab[data.dwMapID][data.nIndex]
		else
			tab[data.dwMapID] = tab[data.dwMapID] or {}
			tab[data.dwMapID][data.nIndex] = JsonEncode(data)
			szString = tab[data.dwMapID][data.nIndex]
		end
	else -- 临时记录 暂时还不做缓存处理
		szString = JsonEncode(data)
	end
	return szString
end

function DBMUI.CheckSearch(szType, data)
	if DBMUI_GLOBAL_SEARCH then
		if DBMUI.GetSearchCache(data):find(DBMUI_SEARCH, nil, true) then
			return true
		end
	else
		local szName = DBMUI.GetDataName(szType, data)
		if tostring(szName):find(DBMUI_SEARCH, nil, true)
			or (data.szNote   and tostring(data.szNote):find(DBMUI_SEARCH, nil, true))
			or (data.key      and tostring(data.key):find(DBMUI_SEARCH, nil, true)) -- 画圈圈
			or (data.dwID     and tostring(data.dwID):find(DBMUI_SEARCH, nil, true))
			or (data.dwMapID  and DBMUI.GetMapName(data.dwMapID):find(DBMUI_SEARCH, nil, true))
			or (data.szTarget and tostring(data.szTarget):find(DBMUI_SEARCH, nil, true))
		then
			return true
		end
	end
	return false
end

function DBMUI.GetDataName(szType, data)
	local szName, nIcon
	if szType == "CASTING" then
		szName, nIcon = JH.GetSkillName(data.dwID, data.nLevel)
	elseif szType == "NPC" or szType == "CIRCLE" then
		if data.dwID then
			szName = JH.GetTemplateName(data.dwID)
			nIcon = data.nFrame
		end
	elseif szType == "DOODAD" then
		local doodad = GetDoodadTemplate(data.dwID)
		szName = doodad.szName ~= "" and doodad.szName or data.dwID
		nIcon  = DBMUI_DOODAD_ICON[doodad.nKind]
	elseif szType == "TALK" or szType == "CHAT" then
		szName = data.szContent
	else
		szName, nIcon = JH.GetBuffName(data.dwID, data.nLevel)
	end
	nIcon  = data.nIcon  or nIcon
	szName = data.szName or szName
	return szName, nIcon
end

function DBMUI.SetBuffItemAction(h)
	local dat = h.dat
	local szName, nIcon = DBMUI.GetDataName("BUFF", dat)
	h:Lookup("Text"):SetText(szName)
	if dat.col then
		h:Lookup("Text"):SetFontColor(unpack(dat.col))
	end
	local nSec = select(3, GetBuffTime(dat.dwID, dat.nLevel))
	if not nSec then
		h:Lookup("Text_R"):SetText("N/A")
	elseif nSec > 24 * 60 * 60 / GLOBAL.GAME_FPS then
		h:Lookup("Text_R"):SetText(_L["infinite"])
	else
		nSec = nSec / GLOBAL.GAME_FPS
		h:Lookup("Text_R"):SetText(JH.FormatTimeString(nSec, 1))
	end
	h:Lookup("Image_RBg"):Show()
	local box = h:Lookup("Box")
	box:SetObjectIcon(nIcon)
	if dat.nCount then
		box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
		box:SetOverTextFontScheme(0, 15)
		box:SetOverText(0, dat.nCount)
	end
	h.bDraw = true
end

function DBMUI.SetCastingItemAction(h)
	local dat = h.dat
	local szName, nIcon = DBMUI.GetDataName("CASTING", dat)
	h:Lookup("Text"):SetText(szName)
	if dat.col then
		h:Lookup("Text"):SetFontColor(unpack(dat.col))
	end
	local hSkill = GetSkillInfo({ skill_id = dat.dwID, skill_level = dat.nLevel })
	if not hSkill or hSkill.AreaRadius == 0 then
		h:Lookup("Text_R"):SetText("N/A")
	else
		h:Lookup("Text_R"):SetText(hSkill.AreaRadius / 64 .. g_tStrings.STR_METER)
	end
	h:Lookup("Image_RBg"):Show()
	local box = h:Lookup("Box")
	box:SetObjectIcon(nIcon)
	h.bDraw = true
end

function DBMUI.SetNpcItemAction(h)
	local dat = h.dat
	local szName = DBMUI.GetDataName("NPC", dat)
	h:Lookup("Text"):SetText(szName)
	if dat.col then
		h:Lookup("Text"):SetFontColor(unpack(dat.col))
	end
	local box = h:Lookup("Box")
	box:ClearObjectIcon()
	box:SetExtentImage("ui/Image/TargetPanel/Target.UITex", dat.nFrame)
	h.bDraw = true
end

function DBMUI.SetDoodadItemAction(h)
	local dat = h.dat
	local szName, nIcon = DBMUI.GetDataName("DOODAD", dat)
	h:Lookup("Text"):SetText(szName)
	if dat.col then
		h:Lookup("Text"):SetFontColor(unpack(dat.col))
	end
	local box = h:Lookup("Box")
	box:SetObjectIcon(nIcon)
	h.bDraw = true
end

function DBMUI.SetCircleItemAction(h)
	local dat = h.dat
	h:Lookup("Text"):SetText(dat.szNote and string.format("%s (%s)", dat.key, dat.szNote) or dat.key)
	local box = h:Lookup("Box")
	if dat.tCircles then
		h:Lookup("Text"):SetFontColor(unpack(dat.tCircles[1].col))
	end
	if dat.dwType == TARGET.NPC then
		box:SetObjectIcon(2397)
	else
		box:SetObjectIcon(2396)
	end
	h.bDraw = true
end

function DBMUI.SetTalkItemAction(h)
	local dat = h.dat
	h:Lookup("Text_Name"):SetText(dat.szTarget or _L["Warning Box"])
	if not dat.szTarget or dat.szTarget == "%" then -- system and %%
		h:Lookup("Text_Name"):SetFontColor(255, 255, 0)
	end
	h:Lookup("Text_Content"):SetText(dat.szContent)
	if dat.col then
		h:Lookup("Text_Content"):SetFontColor(unpack(dat.col))
	end
	h.bDraw = true
end

function DBMUI.SetChatItemAction(h)
	local dat = h.dat
	h:Lookup("Text_Name"):SetText(_L["CHAT"])
	h:Lookup("Text_Name"):SetFontColor(255, 255, 0)
	h:Lookup("Text_Content"):SetText(dat.szContent)
	if dat.col then
		h:Lookup("Text_Content"):SetFontColor(unpack(dat.col))
	end
	h.bDraw = true
end

function DBMUI.GetMapName(dwMapID)
	if dwMapID == _L["All Data"] then
		return dwMapID
	end
	return JH.IsMapExist(dwMapID)
end

-- 更新监控数据
function DBMUI.UpdateLList()
	local tab = DBM_API.GetTable(DBMUI_SELECT_TYPE)
	if tab then
		local dat, dat2 = tab[DBMUI_SELECT_MAP] or {}, {}
		if DBMUI_SEARCH then
			for k, v in ipairs(dat) do
				if DBMUI.CheckSearch(DBMUI_SELECT_TYPE, v) then
					table.insert(dat2, v)
				end
			end
		else
			dat2 = dat
		end
		DBMUI.DrawTableL(dat2)
	end
end

function DBMUI.DrawTableL(data)
	local frame = DBMUI.GetFrame()
	local page = frame.hPageSet:GetActivePage()
	local handle = page:Lookup("WndScroll_" .. DBMUI_SELECT_TYPE .. "_L", "Handle_" .. DBMUI_SELECT_TYPE .. "_List_L")
	local hItemData = (DBMUI_SELECT_TYPE == "TALK" or DBMUI_SELECT_TYPE == "CHAT") and frame.hTalkL or frame.hItemL
	handle:Clear()
	if #data > 0 then
		for k, v in JH.bpairs(data) do
			local h = handle:AppendItemFromData(hItemData, "Handle_L")
			h.dat = v
		end
	end
	handle:FormatAllItemPos()
	DBMUI.RefreshScroll("L")
end

-- 更新临时数据
function DBMUI.UpdateRList(data)
	if data then
		DBMUI.DrawTableR(data, true)
	else
		local tab, tab2 = DBM_API.GetTable(DBMUI_SELECT_TYPE, true), {}
		if tab then
			if DBMUI_SEARCH then
				for k, v in ipairs(tab) do
					if DBMUI.CheckSearch(DBMUI_SELECT_TYPE, v) then
						table.insert(tab2, v)
					end
				end
			else
				tab2 = tab
			end
			DBMUI.DrawTableR(tab2)
		end
	end
end

function DBMUI.DrawTableR(data, bInsert)
	local frame = DBMUI.GetFrame()
	local page = frame.hPageSet:GetActivePage()
	local handle = page:Lookup("WndScroll_" .. DBMUI_SELECT_TYPE .. "_R", "Handle_" .. DBMUI_SELECT_TYPE .. "_List_R")
	if not bInsert then
		handle:Clear()
		local hItemData = (DBMUI_SELECT_TYPE == "TALK" or DBMUI_SELECT_TYPE == "CHAT") and frame.hTalkR or frame.hItemR
		if #data > 0 then
			for k, v in JH.bpairs(data) do
				local h = handle:AppendItemFromData(hItemData, "Handle_R")
				h.dat = v
			end
		end
	else
		-- 少一个 InsertItemFromData
		local szIniFile = (DBMUI_SELECT_TYPE == "TALK" or DBMUI_SELECT_TYPE == "CHAT") and DBMUI_TALK_R or DBMUI_ITEM_R
		local szSectionName = (DBMUI_SELECT_TYPE == "TALK" or DBMUI_SELECT_TYPE == "CHAT") and "Handle_TALK_R" or "Handle_R"
		if not DBMUI_SEARCH or DBMUI.CheckSearch(DBMUI_SELECT_TYPE, data) then
			handle:InsertItemFromIni(0, false, szIniFile, szSectionName, "Handle_R")
			local h = handle:Lookup(0)
			h.dat = data
		end
	end
	handle:FormatAllItemPos()
	DBMUI.RefreshScroll("R")
end

-- 添加面板
function DBMUI.OpenAddPanel(szType, data)
	if szType == "CIRCLE" then
		Circle.OpenAddPanel(IsCtrlKeyDown() and data.dwID or DBMUI.GetDataName("NPC", data), TARGET.NPC, Table_GetMapName(data.dwMapID), DBMUI_SELECT_MAP)
	else
		local szName, nIcon = _L[szType], 340
		if szType ~= "TALK" and szType ~= "CHAT" then
			szName, nIcon = DBMUI.GetDataName(szType, data)
		end
		local ui = GUI.CreateFrame("DBM_NewData", { w = 380, h = 250, title = szName, focus = true, close = true })
		local nX, nY = 0, 0
		ui:Event("DBMUI_SWITCH_PAGE", "DBMUI_TEMP_RELOAD"):OnEvent(function(szEvent)
			ui:Remove()
		end)
		if szType ~= "NPC" then
			nX, nY = ui:Append("Box", "Box_Icon", { w = 48, h = 48, x = 166, y = 40, icon = nIcon }):Pos_()
		else
			nX, nY = ui:Append("Box", "Box_Icon", { w = 48, h = 48, x = 166, y = 40, icon = nIcon }):File("ui/Image/TargetPanel/Target.uitex", data.nFrame):Pos_()
		end
		ui:Fetch("Box_Icon"):Hover(function(bHover)
			this:SetObjectMouseOver(bHover)
			if bHover then
				local x, y = this:GetAbsPos()
				local w, h = this:GetSize()
				DBMUI.OutputTip(szType, data, { x, y, w, h })
			else
				HideTip()
			end
		end)
		nX, nY = ui:Append("WndEdit", "map", { x = 100, y = nY + 15 })
		:Autocomplete(JH.GetAllMap()):Change(function()
			local me = this
			if me:GetText() == "" then
				local menu = {}
				DBMUI.InsertDungeonMenu(menu, function(dwMapID)
					me:SetText(DBMUI.GetMapName(dwMapID))
				end)
				local nX, nY = this:GetAbsPos()
				local nW, nH = this:GetSize()
				menu.nMiniWidth = nW
				menu.x = nX
				menu.y = nY + nH
				menu.fnAutoClose = function() return not me or not me:IsValid() end
				menu.bShowKillFocus = true
				menu.bDisableSound = true
				PopupMenu(menu)
			end
		end)
		:Text(DBMUI_SELECT_MAP ~= _L["All Data"] and DBMUI.GetMapName(DBMUI_SELECT_MAP) or DBMUI.GetMapName(data.dwMapID)):Pos_()
		ui:Append("WndButton3", { x = 120, y = nY + 40, txt = _L["Add"] }):Click(function()
			local txt = ui:Fetch("map"):Text()
			local dwMapID = JH.IsMapExist(txt)
			if not dwMapID then
				return JH.Alert(_L["The map does not exist"])
			end
			local tab = select(2, DBM_API.CheckSameData(szType, dwMapID, data.dwID or data.szContent, data.nLevel or data.szTarget))
			if tab then
				return JH.Confirm(_L["Data exists, editor?"], function()
					DBMUI.OpenSettingPanel(tab, szType)
					ui:Remove()
				end)
			end
			local dat = {
				dwID      = data.dwID,
				nLevel    = data.nLevel,
				nFrame    = data.nFrame,
				szContent = data.szContent,
				szTarget  = data.szTarget
			}
			DBMUI_SELECT_MAP = dwMapID
			DBMUI.OpenSettingPanel(DBM_API.AddData(szType, dwMapID, dat), szType)
			ui:Remove()
		end)
	end
end
-- 数据调试面板
function DBMUI.OpenJosnPanel(data, fnAction)
	local ui = GUI.CreateFrame("DBM_JsonPanel", { w = 720,h = 500, title = "DBM DEBUG Panel", close = true }):Event("DBMUI_DATA_RELOAD", "DBMUI_SWITCH_PAGE"):OnEvent(function(szEvent)
		ui:Remove()
	end)
	ui:Append("WndEdit", "CODE", { w = 660, h = 350, x = 30, y = 60, color = { 255, 255, 0 }, multi = true, limit = 999999, txt = JsonEncode(data, true), color = { 255, 255, 0 } }):Change(function()
		local code = ui:Fetch("CODE")
		local dat  = JH.JsonDecode(code:Text())
		if dat then
			code:Color(255, 255, 0)
			else
			code:Color(255, 0, 0)
		end
	end)
	ui:Append("WndButton3",{ x = 30, y = 440,txt = g_tStrings.STR_HOTKEY_SURE }):Click(function()
		JH.Confirm(_L["Confirm?"], function()
			local dat = JH.JsonToTable(ui:Fetch("CODE"):Text())
			if fnAction and dat then
				ui:Remove()
				return fnAction(dat)
			end
		end)
	end)
end

-- 设置面板
function DBMUI.OpenSettingPanel(data, szType)
	local function GetScrutinyTypeMenu()
		local menu = {
			{ szOption = g_tStrings.STR_GUILD_ALL, bMCheck = true, bChecked = type(data.nScrutinyType) == "nil", fnAction = function() data.nScrutinyType = nil end },
			-- { bDevide = true },
			{ szOption = g_tStrings.MENTOR_SELF, bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.SELF, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.SELF end },
			{ szOption = _L["Team"], bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.TEAM, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.TEAM end },
			{ szOption = _L["Enemy"], bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.ENEMY, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.ENEMY end },
			{ szOption = g_tStrings.STR_RAID_TIP_TARGET, bMCheck = true, bChecked = data.nScrutinyType == DBM_SCRUTINY_TYPE.TARGET, fnAction = function() data.nScrutinyType = DBM_SCRUTINY_TYPE.TARGET end },
		}
		return menu
	end
	local function GetKungFuMenu()
		local menu = {}
		if data.tKungFu then
			table.insert(menu, { szOption = _L["no request"], bCheck = true, bChecked = type(data.tKungFu) == "nil", fnAction = function()
				data.tKungFu = nil
				GetPopupMenu():Hide()
			end })
		end
		for k, v in ipairs(JH_KUNGFU_LIST) do
			table.insert(menu, {
				szOption = JH.GetSkillName(v[1], 1),
				bCheck   = true,
				bChecked = data.tKungFu and data.tKungFu["SKILL#" .. v[1]],
				szIcon   = v[2],
				nFrame   = v[3],
				szLayer  = "ICON_RIGHTMOST",
				fnAction = function()
					data.tKungFu = data.tKungFu or {}
					if not data.tKungFu["SKILL#" .. v[1]] then
						data.tKungFu["SKILL#" .. v[1]] = true
					else
						data.tKungFu["SKILL#" .. v[1]] = nil
						if IsEmpty(data.tKungFu) then
							data.tKungFu = nil
						end
					end
				end
			})
		end
		return menu
	end
	local function GetMarkMenu(nClass)
		local menu = {}
		for k, v in ipairs_c(PARTY_MARK_ICON_FRAME_LIST) do
			table.insert(menu, { szOption = JH_MARK_NAME[k], szIcon = PARTY_MARK_ICON_PATH, nFrame = v, szLayer = "ICON_RIGHT", bCheck = true, bChecked = data[nClass] and data[nClass].tMark and data[nClass].tMark[k], fnAction = function(_, bCheck)
				if bCheck then
					data[nClass] = data[nClass] or {}
					if not data[nClass].tMark then
						data[nClass].tMark = {}
						for kk, vv in ipairs_c(PARTY_MARK_ICON_FRAME_LIST) do
							data[nClass].tMark[kk] = false
						end
					end
					data[nClass].tMark[k] = true
				else
					data[nClass].tMark[k] = false
					local bDelete = true
					for k, v in ipairs(data[nClass].tMark) do
						if v then
							bDelete = false
							break
						end
					end
					if bDelete then
						data[nClass].tMark = nil
					end
					if IsEmpty(data[nClass]) then data[nClass] = nil end
				end
			end })
		end
		return menu
	end
	local function SetDataClass(nClass, key, value)
		if value then
			data[nClass] = data[nClass] or {}
			data[nClass][key] = value
		else
			data[nClass][key] = nil
			if IsEmpty(data[nClass]) then
				data[nClass] = nil
			end
		end
	end

	local function UI_tonumber(szNum, nDefault)
		if tonumber(szNum) then
			return tonumber(szNum)
		else
			return nDefault
		end
	end

	local function SetCountdownType(dat, val, ui)
		dat.nClass = val
		ui:Text(_L["Countdown TYPE " ..  dat.nClass])
		GetPopupMenu():Hide()
	end

	local function CheckCountdown(tTime)
		if tonumber(tTime) then
			return true
		else
			local tab = {}
			local t = JH.Split(tTime, ";")
			for k, v in ipairs(t) do
				local time = JH.Split(v, ",")
				if time[1] and time[2] and tonumber(JH.Trim(time[1])) and time[2] ~= "" then
					table.insert(tab, { nTime = tonumber(time[1]), szName = time[2] })
				elseif JH.Trim(time[1]) ~= "" and not tonumber(time[1]) then
					return false
				elseif tonumber(time[1]) and (not time[2] or JH.Trim(time[2]) == "") then
					return false
				end
			end
			if IsEmpty(tab) then
				return false
			else
				table.sort(tab, function(a, b)
					return a.nTime < b.nTime
				end)
				return tab
			end
		end
	end
	local tSkillInfo
	local me = GetClientPlayer()
	local file = "ui/Image/UICommon/Feedanimials.uitex"
	local szName, nIcon = _L[szType], 340
	if szType ~= "TALK" and szType ~= "CHAT" then
		szName, nIcon = DBMUI.GetDataName(szType, data)
	elseif szType == "CHAT" then
		nIcon = 439
	end
	local ui = GUI.CreateFrame("DBM_SettingPanel", { w = 770, h = 450, title = szName, close = true, focus = true })
	local frame = Station.Lookup("Normal/DBM_SettingPanel")
	ui:Event("DBMUI_DATA_RELOAD", "DBMUI_SWITCH_PAGE"):OnEvent(function(szEvent)
		ui:Remove()
	end)
	frame.OnFrameDragEnd = function()
		DBMUI_PANEL_ANCHOR = GetFrameAnchor(frame, "LEFTTOP")
	end
	local nX, nY, _ = 0, 0, 0
	local function fnClickBox()
		local menu, box = {}, this
		if szType ~= "TALK" and szType ~= "CHAT" then
			table.insert(menu, { szOption = _L["Edit Name"], fnAction = function()
				GetUserInput(_L["Edit Name"], function(szText)
					if JH.Trim(szText) == "" then
						data.szName = nil
						ui:Title(szName)
					else
						data.szName = szText
						ui:Title(szText)
					end
				end, nil, nil, nil, data.szName or szName)
			end})
			table.insert(menu, { bDevide = true })
		end
		if szType ~= "NPC" and szType ~= "TALK" and szType ~= "CHAT" then
			table.insert(menu, { szOption = _L["Edit Iocn"], fnAction = function()
				GUI.OpenIconPanel(function(nIcon)
					data.nIcon = nIcon
					box:SetObjectIcon(nIcon)
				end)
			end})
			table.insert(menu, { bDevide = true })
		end
		table.insert(menu, {
			szOption = _L["Edit Color"],
			szLayer = "ICON_RIGHT",
			szIcon = "ui/Image/UICommon/Feedanimials.uitex",
			nFrame = 86,
			nMouseOverFrame = 87,
			fnClickIcon = function()
				data.col = nil
				ui:Fetch("Shadow_Color"):Alpha(0)
			end,
			fnAction = function()
				GUI.OpenColorTablePanel(function(r, g, b)
					data.col = { r, g, b }
					ui:Fetch("Shadow_Color"):Color(r, g, b):Alpha(255)
				end)
			end
		})
		table.insert(menu, { bDevide = true })
		table.insert(menu, { szOption = _L["raw data, Please be careful"], color = { 255, 255, 0 }, fnAction = function()
			DBMUI.OpenJosnPanel(data, function(dat)
				local file = DBM_API.GetTable(DBMUI_SELECT_TYPE)
				if file and file[DBMUI_SELECT_MAP] and file[data.dwMapID][data.nIndex] then
					file[data.dwMapID][data.nIndex] = dat
				end
				FireUIEvent("DBM_CREATE_CACHE")
				FireUIEvent("DBMUI_DATA_RELOAD")
				DBMUI.OpenSettingPanel(file[data.dwMapID][data.nIndex], szType)
			end)
		end })
		PopupMenu(menu)
	end

	ui:Append("Shadow", "Shadow_Color", { w = 52, h = 52, x = 359, y = 38, color = data.col, alpha = data.col and 255 or 0 })
	if szType ~= "NPC" then
		nX, nY = ui:Append("Box", "Box_Icon", { w = 48, h = 48, x = 361, y = 40, icon = nIcon }):Pos_()
	else
		nX, nY = ui:Append("Box", "Box_Icon", { w = 48, h = 48, x = 361, y = 40, icon = nIcon }):File("ui/Image/TargetPanel/Target.uitex", data.nFrame):Pos_()
	end
	ui:Fetch("Box_Icon"):Hover(function(bHover)
		this:SetObjectMouseOver(bHover)
		if bHover then
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			DBMUI.OutputTip(szType, data, { x, y, w, h })
		else
			HideTip()
		end
	end):Click(fnClickBox)
	if szType == "BUFF" or szType == "DEBUFF" then
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = g_tStrings.CHANNEL_COMMON, font = 27 }):Pos_()
		nX = ui:Append("WndComboBox", { x = 30, y = nY + 12, txt = _L["Scrutiny Type"] }):Menu(function()
			return GetScrutinyTypeMenu(data)
		end):Pos_()
		nX = ui:Append("WndComboBox", { x = nX + 5, y = nY + 12, txt = _L["Self KungFu require"] }):Menu(function()
			return GetKungFuMenu(data)
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 5, y = nY + 10, txt = _L["Count Achieve"] }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 2, y = nY + 12, w = 30, h = 26, txt = data.nCount or 1 }):Type(0):Change(function(nNum)
			data.nCount = UI_tonumber(nNum)
			if data.nCount == 1 then
				data.nCount = nil
			end
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bCheckLevel, txt = _L["Check Level"] }):Click(function(bCheck)
			data.bCheckLevel = bCheck and true or nil
		end):Pos_()
		-- get buff
		local cfg = data[DBM_TYPE.BUFF_GET] or {}
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Get Buff"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 8, w = 60, h = 25, txt = _L["Mark"] }):Menu(function()
			return GetMarkMenu(DBM_TYPE.BUFF_GET)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bScreenHead, txt = _L["Screen Head Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bScreenHead", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bFullScreen", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bPartyBuffList, txt = _L["Party Buff List"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bPartyBuffList", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBuffList, txt = _L["Buff List"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bBuffList", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bTeamPanel, txt = _L["Team Panel"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bTeamPanel", bCheck)
			ui:Fetch("bOnlySelfSrc"):Enable(bCheck)
			FireUIEvent("DBM_CREATE_CACHE")
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", "bOnlySelfSrc", { x = nX + 5, y = nY, checked = cfg.bOnlySelfSrc, txt = _L["Only Source Self"] }):Enable(cfg.bTeamPanel == true):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_GET, "bOnlySelfSrc", bCheck)
		end):Pos_()
		-- 失去buff
		local cfg = data[DBM_TYPE.BUFF_LOSE] or {}
		nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Lose Buff"], font = 27 }):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_LOSE, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_LOSE, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_LOSE, "bCenterAlarm", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.BUFF_LOSE, "bBigFontAlarm", bCheck)
		end):Pos_()
	elseif szType == "CASTING" then
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = g_tStrings.CHANNEL_COMMON, font = 27 }):Pos_()
		nX = ui:Append("WndComboBox", { x = 30, y = nY + 12, txt = _L["Scrutiny Type"] }):Menu(function()
			return GetScrutinyTypeMenu(data)
		end):Pos_()
		nX = ui:Append("WndComboBox", { x = nX + 5, y = nY + 12, txt = _L["Self KungFu require"] }):Menu(function()
			return GetKungFuMenu(data)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bCheckLevel, txt = _L["Check Level"] }):Click(function(bCheck)
			data.bCheckLevel = bCheck and true or nil
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bMonTarget, txt = _L["Show Target Name"] }):Click(function(bCheck)
			data.bMonTarget = bCheck and true or nil
		end):Pos_()

		local cfg = data[DBM_TYPE.SKILL_END] or {}
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Skills using a success"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 8, w = 60, h = 25, txt = _L["Mark"] }):Menu(function()
			return GetMarkMenu(DBM_TYPE.SKILL_END)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.SKILL_END, "bFullScreen", bCheck)
		end):Pos_()
		local tRecipeKey = me.GetSkillRecipeKey(data.dwID, data.nLevel)
		tSkillInfo = GetSkillInfo(tRecipeKey)
		if tSkillInfo and tSkillInfo.CastTime ~= 0 then
			local cfg = data[DBM_TYPE.SKILL_BEGIN] or {}
			nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Skills began to release"], font = 27 }):Pos_()
			nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 8, w = 60, h = 25, txt = _L["Mark"] }):Menu(function()
				return GetMarkMenu(DBM_TYPE.SKILL_BEGIN)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bTeamChannel", bCheck)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bWhisperChannel", bCheck)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bCenterAlarm", bCheck)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bBigFontAlarm", bCheck)
			end):Pos_()
			nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bScreenHead, txt = _L["Screen Head Alarm"] }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bScreenHead", bCheck)
			end):Pos_()
			nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
				SetDataClass(DBM_TYPE.SKILL_BEGIN, "bFullScreen", bCheck)
			end):Pos_()
		end
	elseif szType == "NPC" then
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = g_tStrings.CHANNEL_COMMON, font = 27 }):Pos_()
		nX = ui:Append("WndComboBox", { x = 30, y = nY + 12, txt = _L["Self KungFu require"] }):Menu(function()
			return GetKungFuMenu(data)
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 5, y = nY + 10, txt = _L["Count Achieve"] }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 2, y = nY + 12, w = 30, h = 26, txt = data.nCount or 1 }):Type(0):Change(function(nNum)
			data.nCount = UI_tonumber(nNum)
			if data.nCount == 1 then
				data.nCount = nil
			end
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bAllLeave, txt = _L["Must All leave scene"] }):Click(function(bCheck)
			data.bAllLeave = bCheck and true or nil
			if bCheck then
				ui:Fetch("NPC_LEAVE_TEXT"):Text(_L["All Leave scene"])
			else
				ui:Fetch("NPC_LEAVE_TEXT"):Text(_L["Leave scene"])
			end
		end):Pos_()
		local cfg = data[DBM_TYPE.NPC_ENTER] or {}
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Enter scene"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndComboBox", { x = nX + 5, y = nY + 8, w = 60, h = 25, txt = _L["Mark"] }):Menu(function()
			return GetMarkMenu(DBM_TYPE.NPC_ENTER)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bScreenHead, txt = _L["Screen Head Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bScreenHead", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_ENTER, "bFullScreen", bCheck)
		end):Pos_()
		nX, nY = ui:Append("Text", "NPC_LEAVE_TEXT", { x = 20, y = nY + 5, txt = data.bAllLeave and _L["All Leave scene"] or _L["Leave scene"], font = 27 }):Pos_()
		local cfg = data[DBM_TYPE.NPC_LEAVE] or {}
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_LEAVE, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_LEAVE, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_LEAVE, "bCenterAlarm", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.NPC_LEAVE, "bBigFontAlarm", bCheck)
		end):Pos_()
	elseif szType == "DOODAD" then
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = g_tStrings.CHANNEL_COMMON, font = 27 }):Pos_()
		nX = ui:Append("WndComboBox", { x = 30, y = nY + 12, txt = _L["Self KungFu require"] }):Menu(function()
			return GetKungFuMenu(data)
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 5, y = nY + 10, txt = _L["Count Achieve"] }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 2, y = nY + 12, w = 30, h = 26, txt = data.nCount or 1 }):Type(0):Change(function(nNum)
			data.nCount = UI_tonumber(nNum)
			if data.nCount == 1 then
				data.nCount = nil
			end
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bAllLeave, txt = _L["Must All leave scene"] }):Click(function(bCheck)
			data.bAllLeave = bCheck and true or nil
			if bCheck then
				ui:Fetch("DOODAD_LEAVE_TEXT"):Text(_L["All Leave scene"])
			else
				ui:Fetch("DOODAD_LEAVE_TEXT"):Text(_L["Leave scene"])
			end
		end):Pos_()
		local cfg = data[DBM_TYPE.DOODAD_ENTER] or {}
		nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Enter scene"], font = 27 }):Pos_()
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_ENTER, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_ENTER, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_ENTER, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_ENTER, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bScreenHead, txt = _L["Screen Head Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_ENTER, "bScreenHead", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_ENTER, "bFullScreen", bCheck)
		end):Pos_()
		nX, nY = ui:Append("Text", "DOODAD_LEAVE_TEXT", { x = 20, y = nY + 5, txt = data.bAllLeave and _L["All Leave scene"] or _L["Leave scene"], font = 27 }):Pos_()
		local cfg = data[DBM_TYPE.DOODAD_LEAVE] or {}
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_LEAVE, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_LEAVE, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_LEAVE, "bCenterAlarm", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.DOODAD_LEAVE, "bBigFontAlarm", bCheck)
		end):Pos_()
	elseif szType == "TALK" then
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Alert Content"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndEdit", { x = nX + 5, y = nY + 8, txt = data.szNote, w = 650, h = 25 }):Change(function(txt)
			local szText = JH.Trim(txt)
			if szText == "" then
				data.szNote = nil
			else
				data.szNote = szText
			end
		end):Pos_()
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Speaker"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndEdit", { x = nX + 5, y = nY + 8, txt = data.szTarget or _L["Warning Box"], w = 650, h = 25 }):Change(function(txt)
			local szText = JH.Trim(txt)
			if szText == "" or szText == _L["Warning Box"] then
				data.szTarget = nil
			else
				data.szTarget = szText
			end
			FireUIEvent("DBM_CREATE_CACHE")
		end):Pos_()
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Content"], font = 27 }):Pos_()
		_, nY = ui:Append("WndEdit", { x = nX + 5, y = nY + 8, txt = data.szContent, w = 650, h = 55, multi = true }):Change(function(txt)
			data.szContent = JH.Trim(txt)
			FireUIEvent("DBM_CREATE_CACHE")
		end):Pos_()
		nX, nY = ui:Append("Text", { x = nX, y = nY, txt = _L["Tips:$me behalf of self, $team behalf of team, Only allow a time"], alpha = 200 }):Pos_()
		nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Trigger Talk"], font = 27 }):Pos_()
		local cfg = data[DBM_TYPE.TALK_MONITOR] or {}
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bScreenHead, txt = _L["Screen Head Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bScreenHead", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.TALK_MONITOR, "bFullScreen", bCheck)
		end):Pos_()
	elseif szType == "CHAT" then
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Alert Content"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndEdit", { x = nX + 5, y = nY + 8, txt = data.szNote, w = 650, h = 25 }):Change(function(txt)
			local szText = JH.Trim(txt)
			if szText == "" then
				data.szNote = nil
			else
				data.szNote = szText
			end
		end):Pos_()
		nX = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Chat Content"], font = 27 }):Pos_()
		_, nY = ui:Append("WndEdit", { x = nX + 5, y = nY + 8, txt = data.szContent, w = 650, h = 85, multi = true }):Change(function(txt)
			data.szContent = txt:gsub("\r", "")
			FireUIEvent("DBM_CREATE_CACHE")
		end):Pos_()
		nX, nY = ui:Append("Text", { x = nX, y = nY, txt = _L["Tips:$me behalf of self, $team behalf of team, Only allow a time"], alpha = 200 }):Pos_()
		nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Trigger Chat"], font = 27 }):Pos_()
		local cfg = data[DBM_TYPE.CHAT_MONITOR] or {}
		nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = cfg.bTeamChannel, txt = _L["Team Channel Alarm"], color = GetMsgFontColor("MSG_TEAM", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.CHAT_MONITOR, "bTeamChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bWhisperChannel, txt = _L["Whisper Channel Alarm"], color = GetMsgFontColor("MSG_WHISPER", true) }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.CHAT_MONITOR, "bWhisperChannel", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bCenterAlarm, txt = _L["Center Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.CHAT_MONITOR, "bCenterAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bBigFontAlarm, txt = _L["Big Font Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.CHAT_MONITOR, "bBigFontAlarm", bCheck)
		end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bScreenHead, txt = _L["Screen Head Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.CHAT_MONITOR, "bScreenHead", bCheck)
		end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = cfg.bFullScreen, txt = _L["Full Screen Alarm"] }):Click(function(bCheck)
			SetDataClass(DBM_TYPE.CHAT_MONITOR, "bFullScreen", bCheck)
		end):Pos_()
	end
	if szType ~= "TALK" and szType ~= "CHAT" then
		nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["Add Content"], font = 27 }):Pos_()
		nX, nY = ui:Append("WndEdit", { x = 30, y = nY + 10, txt = data.szNote, w = 650, h = 25, limit = 10 }):Change(function(txt)
			local szText = JH.Trim(txt)
			if szText == "" then
				data.szNote = nil
			else
				data.szNote = szText
			end
		end):Pos_()
	end
	-- 倒计时
	nX, nY = ui:Append("Text", { x = 20, y = nY + 5, txt = _L["Countdown"], font = 27 }):Pos_()
	nY = nY + 10
	for k, v in ipairs(data.tCountdown or {}) do
		nX = ui:Append("WndComboBox", "Countdown" .. k, { x = 30, w = 155, h = 25, y = nY, color = v.key and { 255, 255, 0 }, txt = v.nClass == -1 and _L["Please Select Type"] or _L["Countdown TYPE " ..  v.nClass] }):Menu(function()
			local menu = {}
			if IsCtrlKeyDown() then
				table.insert(menu, { szOption = _L["Set Countdown Key"], rgb = { 255, 255, 0 } , fnAction = function()
					GetUserInput(_L["Countdown Key"], function(szKey)
						if JH.Trim(szKey) == "" then
							v.key = nil
						else
							v.key = JH.Trim(szKey)
						end
						DBMUI.OpenSettingPanel(data, szType)
					end, nil, nil, nil, v.key)
				end })
				table.insert(menu, { bDevide = true })
				table.insert(menu, { szOption = _L["Hold Countdown"], bCheck = true, bChecked = v.bHold, fnAction = function()
					v.bHold = not v.bHold
				end })
				if v.nClass == DBM_TYPE.NPC_FIGHT then
					table.insert(menu, { szOption = _L["Hold Fight Countdown"], bCheck = true, bChecked = v.bFightHold, fnAction = function()
						v.bFightHold = not v.bFightHold
					end })
				end

				table.insert(menu, { bDevide = true })
				table.insert(menu, { szOption = _L["Color Picker"], bDisable = true })
				-- Color Picker
				for i = 0, 8 do
					table.insert(menu, {
						bMCheck = true,
						bChecked = v.nFrame == i,
						fnAction = function()
							v.nFrame = i
						end,
						szIcon = JH.GetAddonInfo().szRootPath .. "JH_DBM/image/ST_UI.uitex",
						nFrame = i,
						szLayer = "ICON_FILL",
					})
				end
			else
				table.insert(menu, { szOption = _L["Please Select Type"], bDisable = true, bChecked = v.nClass == -1 })
				table.insert(menu, { bDevide = true })
				if szType == "BUFF" or szType == "DEBUFF" then
					for kk, vv in ipairs({ DBM_TYPE.BUFF_GET, DBM_TYPE.BUFF_LOSE }) do
						table.insert(menu, { szOption = _L["Countdown TYPE " .. vv], bMCheck = true, bChecked = v.nClass == vv, fnAction = function()
							SetCountdownType(v, vv, ui:Fetch("Countdown" .. k))
						end })
					end
				elseif szType == "CASTING" then
					table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.SKILL_END], bMCheck = true, bChecked = v.nClass == DBM_TYPE.SKILL_END, fnAction = function()
						SetCountdownType(v, DBM_TYPE.SKILL_END, ui:Fetch("Countdown" .. k))
					end })
					if tSkillInfo and tSkillInfo.CastTime ~= 0 then
						table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.SKILL_BEGIN], bMCheck = true, bChecked = v.nClass == DBM_TYPE.SKILL_BEGIN, fnAction = function()
							SetCountdownType(v, DBM_TYPE.SKILL_BEGIN, ui:Fetch("Countdown" .. k))
						end })
					end
				elseif szType == "NPC" then
					for kk, vv in ipairs({ DBM_TYPE.NPC_ENTER, DBM_TYPE.NPC_LEAVE, DBM_TYPE.NPC_ALLLEAVE, DBM_TYPE.NPC_FIGHT, DBM_TYPE.NPC_DEATH, DBM_TYPE.NPC_ALLDEATH, DBM_TYPE.NPC_LIFE, --[[DBM_TYPE.NPC_MANA]] }) do
						table.insert(menu, { szOption = _L["Countdown TYPE " .. vv], bMCheck = true, bChecked = v.nClass == vv, fnAction = function()
							SetCountdownType(v, vv, ui:Fetch("Countdown" .. k))
							if vv == DBM_TYPE.NPC_LIFE or vv == DBM_TYPE.NPC_MANA then
								JH.Alert(_L["Npc Life/Mana Alarm, different format, Recommended reading Help!"])
							end
						end })
					end
				elseif szType == "DOODAD" then
					for kk, vv in ipairs({ DBM_TYPE.DOODAD_ENTER, DBM_TYPE.DOODAD_LEAVE, DBM_TYPE.DOODAD_ALLLEAVE }) do
						table.insert(menu, { szOption = _L["Countdown TYPE " .. vv], bMCheck = true, bChecked = v.nClass == vv, fnAction = function()
							SetCountdownType(v, vv, ui:Fetch("Countdown" .. k))
						end })
					end
				elseif szType == "TALK" then
					table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.TALK_MONITOR], bMCheck = true, bChecked = v.nClass == DBM_TYPE.TALK_MONITOR, fnAction = function()
						SetCountdownType(v, DBM_TYPE.TALK_MONITOR, ui:Fetch("Countdown" .. k))
					end })
				elseif szType == "CHAT" then
					table.insert(menu, { szOption = _L["Countdown TYPE " .. DBM_TYPE.CHAT_MONITOR], bMCheck = true, bChecked = v.nClass == DBM_TYPE.CHAT_MONITOR, fnAction = function()
						SetCountdownType(v, DBM_TYPE.CHAT_MONITOR, ui:Fetch("Countdown" .. k))
					end })
				end
			end
			return menu
		end):Pos_()
		nX = ui:Append("Box", { x = nX + 5, y = nY, w = 24, h = 24, icon = v.nIcon or nIcon }):Hover(function(bHover) this:SetObjectMouseOver(bHover) end):Click(function()
			local box = this
			GUI.OpenIconPanel(function(nIcon)
				v.nIcon = nIcon
				box:SetObjectIcon(nIcon)
			end)
		end):Pos_()
		local bLife = v.nClass ~= DBM_TYPE.NPC_LIFE and v.nClass ~= DBM_TYPE.NPC_MANA and tonumber(v.nTime)
		nX = ui:Append("WndCheckBox", { x = nX + 5, y = nY - 2, txt = _L["TC"], color = GetMsgFontColor("MSG_TEAM", true), checked = v.bTeamChannel }):Click(function(bCheck)
			v.bTeamChannel = bCheck and true or nil
		end):Pos_()
		ui:Append("WndEdit", "CountdownName" .. k, { x = nX + 5, y = nY, w = 295, h = 25, txt = v.szName }):Toggle(bLife and true or false):Change(function(szName)
			v.szName = szName
		end):Pos_()
		nX = ui:Append("WndEdit", "CountdownTime" .. k, { x = nX + 5 + (bLife and 300 or 0), y = nY, w = bLife and 100 or 400, h = 25, txt = v.nTime, color = (v.nClass ~= DBM_TYPE.NPC_LIFE and not CheckCountdown(v.nTime)) and { 255, 0, 0 } }):Change(function(szNum)
			v.nTime = UI_tonumber(szNum, szNum)
			local edit = ui:Fetch("CountdownTime" .. k)
			if szNum == "" then
				return
			end
			if v.nClass == DBM_TYPE.NPC_LIFE or v.nClass == DBM_TYPE.NPC_MANA then
				return
			else
				if tonumber(szNum) then
					if this:GetW() > 200 then
						local x, y = edit:Pos()
						edit:Pos(x + 300, y):Size(100, 25):Color(255, 255, 255)
						ui:Fetch("CountdownName" .. k):Toggle(true):Text(v.szName or g_tStrings.CHAT_NAME)
					end
				else
					if CheckCountdown(szNum) then
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						local xml = { GetFormatText("[DBM] " .. _L["Countdown Preview"] .. "\n", 0, 255, 255, 0) }
						for k, v in ipairs(CheckCountdown(szNum)) do
							table.insert(xml, GetFormatText(v.nTime .. " - " .. v.szName .. "\n"))
						end
						OutputTip(table.concat(xml), 300, { x, y, w, h }, 1, true, "DBM")
						edit:Color(255, 255, 255)
					else
						HideTip()
						edit:Color(255, 0, 0)
					end
					if this:GetW() < 200 then
						local x, y = edit:Pos()
						edit:Pos(x - 300, y):Size(400, 25)
						ui:Fetch("CountdownName" .. k):Toggle(false)
					end
				end
			end
		end):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 5, y = nY, w = 30, h = 25, txt = v.nRefresh }):Type(0):Change(function(szNum)
			v.nRefresh = UI_tonumber(szNum)
		end):Pos_()
		nX, nY = ui:Append("Image", { x = nX + 5, y = nY, w = 26, h = 26}):File(file, 86):Event(257)
		:Hover(function() this:SetFrame(87) end, function() this:SetFrame(86) end):Click(function()
			if v.nClass ~= -1 then
				local class = v.key and DBM_TYPE.COMMON or v.nClass
				if data.dwID then
					FireUIEvent("JH_ST_DEL", class, v.key or (k .. "."  .. data.dwID .. "." .. (data.nLevel or 0)), true) -- try kill
				else
					FireUIEvent("JH_ST_DEL", class, v.key or (data.nIndex .. "." .. k), true) -- try kill
				end
			end
			if #data.tCountdown == 1 then
				data.tCountdown = nil
			else
				table.remove(data.tCountdown, k)
			end
			DBMUI.OpenSettingPanel(data, szType)
		end):Pos_()
	end
	nX = ui:Append("WndButton2", { x = 30, y = nY + 10, txt = _L["Add Countdown"] }):Enable(not (data.tCountdown and #data.tCountdown > 10)):Click(function()
		data.tCountdown = data.tCountdown or {}
		local icon = nIocn or 13
		if szType == "NPC" then	icon = 13 end
		table.insert(data.tCountdown, { nTime = _L["10,Countdown Name;25,Countdown Name"], nClass = -1, nIcon = icon })
		DBMUI.OpenSettingPanel(data, szType)
	end):Pos_()
	ui:Append("WndButton2", { x = 335, y = nY + 10, txt = g_tStrings.STR_FRIEND_DEL, color = { 255, 0, 0 } }):Click(function()
		DBMUI.RemoveData(data.dwMapID, data.nIndex, szName or _L["This data"])
	end)
	nX, nY = ui:Append("WndButton2", { x = 640, y = nY + 10, txt = g_tStrings.HELP_PANEL }):Click(function()
		OpenInternetExplorer("https://github.com/luckyyyyy/JH/blob/dev/JH_DBM/README.md")
	end):Pos_()
	local w, h = ui:Size()
	local a = DBMUI_PANEL_ANCHOR
	ui:Size(w, nY + 25):Point(a.s, 0, 0, a.r, a.x, a.y)
end

function DBMUI.UpdateAnchor(frame)
	local a = DBMUI_ANCHOR
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

function DBMUI.GetFrame()
	return Station.Lookup("Normal/DBM_UI")
end

DBMUI.IsOpened = DBMUI.GetFrame

function DBMUI.TogglePanel()
	if DBMUI.IsOpened() then
		DBMUI.ClosePanel()
	else
		DBMUI.OpenPanel()
	end
end
function DBMUI.OpenPanel(szType)
	if not DBMUI.IsOpened() then
		if szType then
			DBMUI_SELECT_TYPE = szType
		end
		Wnd.OpenWindow(DBMUI_INIFILE, "DBM_UI")
		PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
	end
end

function DBMUI.ClosePanel()
	if DBMUI.IsOpened() then
		FireUIEvent("DBMUI_FREECACHE")
		Wnd.CloseWindow(DBMUI.GetFrame())
		PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
		JH.RegisterGlobalEsc("DBM")
	end
end

JH.RegisterEvent("DBMUI_FREECACHE", function()
	 DBMUI_SEARCH_CACHE = {}
end)
JH.PlayerAddonMenu({ szOption = _L["Open DBM Panel"], fnAction = DBMUI.TogglePanel })
JH.AddHotKey("JH_DBMUI", _L["Open DBM Panel"], DBMUI.TogglePanel)

-- 公开UI API DBM_UI.xxx
local ui = {
	OpenPanel       = DBMUI.OpenPanel,
	ClosePanel      = DBMUI.ClosePanel,
	IsOpened        = DBMUI.GetFrame,
	TogglePanel     = DBMUI.TogglePanel,
	OpenImportPanel = DBMUI.OpenImportPanel,
	OpenExportPanel = DBMUI.OpenExportPanel
}
setmetatable(DBM_UI, { __index = ui, __newindex = function() end, __metatable = true })
