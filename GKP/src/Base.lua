local PATH_ROOT = JH.GetAddonInfo().szRootPath .. "GKP/"
local _L = JH.LoadLangPack

GKP = {
	Config = {
		bDebug2 = false,
		bOn = true, -- 是分配者就开启
		bOn2 = false, -- 不是分配者关闭
		bMoneyTalk = false, -- 金钱变动喊话
		bAlertMessage = true, -- 进入副本提醒清空数据
		bCheckScore = true, -- 查看装备分
		bMoneySystem = false, -- 记录系统金钱变动
		bDeathWarn = false, -- 重伤提示
		bAutoSetMoney = false, --自动设置发布时的金钱
		bAutoBX = true, -- 自动设置碧玺碎片的价格
		bDisplayEmptyRecords = true, -- show 0 record
		bAutoSync = true, -- 自动接收分配者的同步信息
		bLootStyle = true,
		szLootListTitle = "Loot List, By GKP Plugin",
	}
}
JH.RegisterCustomData("GKP.Config")
---------------------------------------------------------------------->
-- 本地函数与变量
----------------------------------------------------------------------<
local _GKP = {
	szIniFile = PATH_ROOT .. "ui/GKP.ini",
	aDoodadCache = {}, -- 拾取列表cache
	aDistributeList = {}, -- 当前拾取列表
	tLootListMoney = {}, -- 发布的金钱cache
	tDistribute = {}, -- 待记账列表
	tDistributeRecords = {},
	tDungeonList = {},
	tViewInvite = {},
	DeathWarn = {},
	aPartyMember = {
		{szName = "test user 1", dwForceID = 1, dwForce = 1, bOnlineFlag = true, dwID = 0},
		{szName = "test user 2", dwForceID = 2, dwForce = 2, bOnlineFlag = true, dwID = 1},
		{szName = "test user 3", dwForceID = 5, dwForce = 5, bOnlineFlag = true, dwID = 2},
		{szName = "test user 4", dwForceID = 7, dwForce = 7, bOnlineFlag = true, dwID = 3},
		{szName = "test user 5", dwForceID = 9, dwForce = 9, bOnlineFlag = true, dwID = 4},
		{szName = "test user 6", dwForceID = 0, dwForce = 0, bOnlineFlag = true, dwID = 5},
		{szName = "test user 7", dwForceID = 6, dwForce = 6, bOnlineFlag = true, dwID = 6},
		{szName = "test user 8", dwForceID = 21, dwForce = 21, bOnlineFlag = true, dwID = 8},
		{szName = "test user 9", dwForceID = 6, dwForce = 6, bOnlineFlag = true, dwID = 9},
		{szName = "test user 10 ban", dwForceID = 5, dwForce = 5, bOnlineFlag = false, dwID = 10},
	},
	tQualityImage = { nil, 13, 12, 14, 11 }, -- Frame
	tSyncQueue = {},
	bSync = {},
	GKP_Record = {},
	GKP_Account = {},
	Config = {
		Subsidies = {
			{_L["Treasure Chests"],"",true},
			{_L["BiXi Fragment"],"",true},
			{_L["Boss"],"",true},
			{_L["Banquet Allowance"],-1000,true},
			{_L["Fines"],"",true},
			{_L["Others"],"",true},
		},
		Scheme = {
			{100,true},
			{1000,true},
			{2000,true},
			{3000,true},
			{4000,true},
			{5000,true},
			{6000,true},
			{7000,true},
			{8000,true},
			{9000,true},
			{10000,true},
			{20000,true},
			{50000,true},
			{100000,true},
		},
		Special = {
			[_L["FuTu Meteoric Iron"]] = true,
			[_L["WuJin Meteoric Iron"]] = true,
			[_L["TianWai Meteoric Iron"]] = true,
			[_L["ShuYu Stone"]] = true,
			[_L["BiXi Fragment"]] = true,
			[_L["BingYong CanZhi"]] = true,
		},
	}
}
_GKP.Config = JH.LoadLUAData("config/gkp.cfg") or _GKP.Config

---------------------------------------------------------------------->
-- 数据处理
----------------------------------------------------------------------<
setmetatable(GKP,{ __call = function(me,key,value,sort)
	if _GKP[key] then
		if value and type(value) == "table" then
			table.insert(_GKP[key],value)
			pcall(_GKP.GKP_Save)
		elseif value and type(value) == "string" then
			if sort == "asc" or sort == "desc" then
				table.sort(_GKP[key],function(a,b)
					if a[value] and b[value] then
						if a[value] == b[value] then
							if sort == "asc" then
								return a.nTime < b.nTime
							else
								return a.nTime > b.nTime
							end
						else
							if sort == "asc" then
								return a[value] < b[value]
							else
								return a[value] > b[value]
							end
						end
					else
						return false
					end
				end)
			elseif value == "del" then
				if _GKP[key][sort] then
					_GKP[key][sort].bDelete = not _GKP[key][sort].bDelete
					pcall(_GKP.GKP_Save)
					return _GKP[key][sort]
				end
			end
			return _GKP[key]
		elseif value and type(value) == "number" then
			if _GKP[key][value] then
				_GKP[key][value] = sort
				pcall(_GKP.GKP_Save)
				return _GKP[key][value]
			end
		else
			return _GKP[key]
		end
	end
end})

---------------------------------------------------------------------->
-- 本地函数
----------------------------------------------------------------------<
_GKP.SaveConfig = function()
	JH.SaveLUAData("config/gkp.cfg",_GKP.Config)
end

_GKP.GKP_Save = function()
	local me = GetClientPlayer()
	local szPath = "GKP/" .. me.szName .. "/" .. FormatTime("%Y-%m-%d",GetCurrentTime()) .. ".gkp"	
	JH.SaveLUAData(szPath,{ GKP_Record = GKP("GKP_Record") , GKP_Account = GKP("GKP_Account") })
end
_GKP.GKP_LoadData = function(szFile)
	local me = GetClientPlayer()
	local szPath = szFile .. ".gkp"
	local t = JH.LoadLUAData(szPath)
	if t then
		_GKP.GKP_Record = t.GKP_Record or {}
		_GKP.GKP_Account = t.GKP_Account or {}
	end
	pcall(_GKP.Draw_GKP_Record)
	pcall(_GKP.Draw_GKP_Account)
end
_GKP.OpenLootPanel = function()
	if not Station.Lookup("Normal/GKP_Loot") then
		local loot = Wnd.OpenWindow(PATH_ROOT .. "ui/GKP_Loot.ini","GKP_Loot")
		loot:Hide()
		GUI(loot):Title(GKP.Config.szLootListTitle or "Loot List, By GKP Plugin"):Point():Close(_GKP.CloseLootWindow)
		loot:Lookup("Btn_Style").OnLButtonClick = function()
			if IsCtrlKeyDown() then
				if #_GKP.aDistributeList > 0 then
					local t = {}
					for k,v in ipairs(_GKP.aDistributeList) do
						table.insert(t,GKP.GetFormatLink(v))
					end
					table.insert(t,{type = "text", text = _L["Expression"]})
					JH.Talk(t)
				end
				return 
			end
			GKP.Config.bLootStyle = not GKP.Config.bLootStyle
			if _GKP.dwOpenID then
				_GKP.OnOpenDoodad(_GKP.dwOpenID)
			end
		end
	end
	return Station.Lookup("Normal/GKP_Loot")
end
_GKP.OpenPanel = function(bDisableSound)
	local frame = Station.Lookup("Normal/GKP") or Wnd.OpenWindow(_GKP.szIniFile, "GKP")
	frame:Show()
	frame:BringToTop()
	Station.SetActiveFrame(frame)
	pcall(_GKP.Draw_GKP_Buff)
	if not bDisableSound then
		PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
	end
	return frame
end
-- close
_GKP.ClosePanel = function(bRealClose)
	if _GKP.frame then
		if not bRealClose then
			_GKP.frame:Hide()
		else
			Wnd.CloseWindow(_GKP.frame)
			_GKP.frame = nil
		end
		PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
	end
end
-- toggle
_GKP.TogglePanel = function()
	if _GKP.frame and _GKP.frame:IsVisible() then
		_GKP.ClosePanel()
	else
		_GKP.OpenPanel()
	end
end
-- initlization
_GKP.Init = function()
	if not _GKP.bInit then
		local me = GetClientPlayer()
		Wnd.OpenWindow(PATH_ROOT .. "ui/GKP_Record.ini","GKP_Record"):Hide()
		_GKP.OpenPanel(true):Hide()
		_GKP.nNowMoney = me.GetMoney().nGold
		_GKP.bInit = true
		JH.DelayCall(50,function() -- Init延后 避免和进入副本冲突
			_GKP.GKP_LoadData("GKP/" .. me.szName .. "/" .. FormatTime("%Y-%m-%d",GetCurrentTime()))				
		end)
	end
end
RegisterEvent("LOADING_END",_GKP.Init) -- LOADING_END 主要是为了获取名字 所以压到最后加载
-- OnMsgArrive
_GKP.OnMsgArrive = function(szMsg)
	if not Station.Lookup("Normal/GKP_Chat") then return end
	local me = Station.Lookup("Normal/GKP_Chat/WndScroll_Chat")
	local h = me:Lookup("","")
	szMsg = string.gsub(szMsg,_L["[Team]"],"")
	
	local AppendText = function()
		local t = TimeToDate(GetCurrentTime())
		return GetFormatText(string.format(" %02d:%02d:%02d ", t.hour, t.minute, t.second),10,255,255,255)
	end
	szMsg = AppendText() .. szMsg
	if MY and MY.Chat and MY.Chat.RenderLink then
		szMsg =  MY.Chat.RenderLink(szMsg)
	end
	if MY_Farbnamen and MY_Farbnamen.Render then
		szMsg = MY_Farbnamen.Render(szMsg)
	end
	local xml = "<image>path=" .. EncodeComponentsString("UI/Image/Button/ShopButton.uitex") .. " frame=1 eventid=786 w=20 h=20 script=\"this.OnItemLButtonClick=GKP.DistributionItem\nthis.OnItemMouseEnter=function() this:SetFrame(2) end\nthis.OnItemMouseLeave=function() this:SetFrame(1) end\"</<image>>"	
	h:AppendItemFromString(xml)
	h:AppendItemFromString(szMsg)
	h:FormatAllItemPos()
	me:Lookup("Scroll_All"):ScrollEnd()
end
-- 点击锤子图标预览 严格判断
GKP.DistributionItem = function()
	local h,i = this:GetParent(),this:GetIndex()
	if not h or not i then
		error("GKP_ERROR -> UI_ERROR")
	end
	local szName = string.match(h:Lookup(i+3):GetText(),"%[(.*)%]")
	local me = Station.Lookup("Normal/GKP_Chat")
	local box = me:Lookup("","Box") or me:Lookup("","iteminfolink") or me:Lookup("","booklink") -- fix setname
	if not _GKP.dwOpenID then
		return JH.Alert(_L["No open doodad"])
	end
	local _,nUiId,dwID,nVersion,dwTabType,dwIndex = box:GetObject()
	local doodad = GetDoodad(_GKP.dwOpenID)
	if type(doodad) ~= "userdata" then return JH.Alert(_L["No open doodad"]) end
	pcall(_GKP.OnOpenDoodad,_GKP.dwOpenID)
	local item
	for k,v in ipairs(_GKP.aDistributeList) do
		if v.nUiId == nUiId and v.dwID == dwID and v.nVersion == nVersion and v.dwTabType == dwTabType and v.dwIndex == dwIndex then
			item = v
			break
		end
	end
	if not item then return JH.Alert(_L["The item was not found"]) end
	if not item.dwID then
		_GKP.OnOpenDoodad(_GKP.dwOpenID)
		return GKP.Sysmsg(_L["Userdata is overdue, distribut failed, please try again."])
	end

	local team = GetClientTeam()
	local aPartyMember = doodad.GetLooterList()
	if JH.bDebug then
		aPartyMember = _GKP.aPartyMember
	end

	if not aPartyMember then
		_GKP.OnOpenDoodad(_GKP.dwOpenID)
		return GKP.Sysmsg(_L["Pick up time limit exceeded, please try again."])
	end
	if not JH.bDebug then
		for k,v in ipairs(aPartyMember) do
			local player = team.GetMemberInfo(v.dwID)
			aPartyMember[k].dwForceID = player.dwForceID
		end
	end
	local p
	for k,v in ipairs(aPartyMember) do
		if v.szName == szName then
			p = v
			break
		end
	end
	if JH.bDebug then p = aPartyMember[1] end
	if not p or (p and not p.bOnlineFlag) then -- bOnlineFlag 刷新其实有延迟
		return JH.Alert(_L["No Pick up Object, may due to Network off - line"]) 
	end
	local r,g,b = JH.GetForceColor(p.dwForceID)
	-- 不管如何品质都弹出MessageBox 防止点错手滑误操作什么的
	local msg = {
		szMessage = FormatLinkString(
			g_tStrings.PARTY_DISTRIBUTE_ITEM_SURE,
			"font=162",
			GetFormatText("[".. GetItemNameByItem(item) .."]", "166"..GetItemFontColorByQuality(item.nQuality, true)),
			GetFormatText("[".. p.szName .."]", 162,r,g,b)
		), 
		szName = "Distribute_Item_Sure",
		bRichText = true,
		{
			szOption = g_tStrings.STR_HOTKEY_SURE, 
			fnAutoClose = function()
				return false
			end,
			fnAction = function()
				_GKP.DistributeItem(item,p,doodad)
			end
		},
		{szOption = g_tStrings.STR_HOTKEY_CANCEL},
	}
	MessageBox(msg)
end

_GKP.SetChatWindow = function(item, ui)
	local me = Station.Lookup("Normal/GKP_Chat")
	if not me then
		me = Wnd.OpenWindow(PATH_ROOT .. "ui/GKP_Chat.ini","GKP_Chat")
		GUI(me):Point():Close(_GKP.CloseChatWindow):Append("WndButton2",{x = 380, y = 38,txt = _L["Stop Bidding"]}):Click(function()
			JH.Talk(_L["--- Stop Bidding ---"])
			JH.DelayCall(1000,function() UnRegisterMsgMonitor(_GKP.OnMsgArrive) end)
		end)
	end
	local box = me:Lookup("","Box") or me:Lookup("","iteminfolink") or me:Lookup("","booklink") -- fix setname
	local txt = me:Lookup("","Text")
	txt:SetText(GetItemNameByItem(item))
	txt:SetFontColor(GetItemFontColorByQuality(item.nQuality))	
	local h = Station.Lookup("Normal/GKP_Chat/WndScroll_Chat"):Lookup("","")
	h:Clear()
	box:SetObject(UI_OBJECT_ITEM_ONLY_ID, item.nUiId, item.dwID, item.nVersion, item.dwTabType, item.dwIndex)
	box:SetObjectIcon(Table_GetItemIconID(item.nUiId))
	box.OnItemLButtonClick = ui.OnItemLButtonClick
	box.OnItemMouseLeave = ui.OnItemMouseLeave
	box.OnItemMouseEnter = ui.OnItemMouseEnter
	RegisterMsgMonitor(_GKP.OnMsgArrive,{"MSG_TEAM"})
	me:Show()
	Station.SetFocusWindow(me)
end

_GKP.CloseChatWindow = function(bCheck)
	local me = Station.Lookup("Normal/GKP_Chat")
	if not me then return end
	if type(bCheck) == "userdata" then
		local box = me:Lookup("","Box") or me:Lookup("","iteminfolink") or me:Lookup("","booklink") -- fix setname
		local _,nUiId,dwID,nVersion,dwTabType,dwIndex = box:GetObject()
		if bCheck.nUiId ~= nUiId or bCheck.dwID ~= dwID or bCheck.nVersion ~= nVersion or bCheck.dwTabType ~= dwTabType or bCheck.dwIndex ~= dwIndex then
			return
		end
	end
	UnRegisterMsgMonitor(_GKP.OnMsgArrive)
	Wnd.CloseWindow(Station.Lookup("Normal/GKP_Chat"))
end

_GKP.CloseLootWindow = function()
	Wnd.CloseWindow(Station.Lookup("Normal/GKP_Loot"))
	_GKP.dwOpenID = nil
	_GKP.CloseChatWindow(true)
end
_GKP.SetLootTitle = function()
	if Station.Lookup("Normal/GKP_Loot") then
		Station.Lookup("Normal/GKP_Loot"):Lookup("","Text_Title"):SetText(GKP.Config.szLootListTitle)
	end
end
---------------------------------------------------------------------->
-- 常用函数
----------------------------------------------------------------------<
GKP.Random = function() -- 生成一个随机字符串 这还能重复我吃翔
	local a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,_+;*-"
	local t = {}
	for i = 1, 64 do
		local n = math.random(1,string.len(a))
		table.insert(t, string.sub(a, n ,n))
	end
	return table.concat(t, "")
end

GKP.Sysmsg = function(szMsg)
	JH.Sysmsg(szMsg,"[GKP]")
end

GKP.GetTimeString = function(nTime, year)
	if year then
		return FormatTime("%H:%M:%S", nTime)
	else
		return FormatTime("%Y-%m-%d %H:%M:%S", nTime)
	end
end

GKP.GetMoneyCol = function(Money)
	local Money = tonumber(Money)
	if Money then
		if Money < 0 then
			return 0,128,255
		elseif Money < 1000 then
			return 255,255,255
		elseif Money < 10000 then
			return 255,255,164
		elseif Money < 100000 then
			return 255,255,0
		elseif Money < 1000000 then
			return 255,128,0
		else
			return 255,0,0
		end
	else
		return 255,255,255
	end
end
---------------------------------------------------------------------->
-- 判断分配者
----------------------------------------------------------------------<
GKP.IsDistributer = function()
	return GetClientTeam().GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) == GetClientPlayer().dwID
end

---------------------------------------------------------------------->
-- 格式化链接
----------------------------------------------------------------------<
GKP.GetFormatLink = function(item)
	if item.nGenre == ITEM_GENRE.BOOK then
		return { type = "book",tabtype = item.dwTabType, index = item.dwIndex, bookinfo = item.nBookID, version = item.nVersion,text = "" }
	else 
		return { type = "iteminfo",version = item.nVersion,tabtype = item.dwTabType,index = item.dwIndex,text = "" }
	end
end
GKP.InsertEditByName = function(szName)
	local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
	edit:InsertObj("[" .. szName .. "]",{ type = "name" , name = szName , text = szName})
	Station.SetFocusWindow(edit)
end
GKP.OnItemLinkDown = function(item,ui)
	ui.nVersion = item.nVersion
	ui.dwTabType = item.dwTabType
	ui.dwIndex = item.dwIndex
	if item.nGenre == ITEM_GENRE.BOOK then
		ui.nBookRecipeID = BookID2GlobelRecipeID(GlobelRecipeID2BookID(item.nBookID))
		ui:SetName("booklink")
	else
		ui:SetName("iteminfolink")
	end
	return OnItemLinkDown(ui)
end
---------------------------------------------------------------------->
-- 获取团队成员 menu
----------------------------------------------------------------------<
GKP.GetTeamList = function()
	local TeamMemberList = GetClientTeam().GetTeamMemberList()
	local tTeam,menu = {},{}
	if JH.bDebug then 
		tTeam = _GKP.aPartyMember 
	else
		for _,v in ipairs(TeamMemberList) do
			local player = GetClientTeam().GetMemberInfo(v)
			table.insert(tTeam,{ szName = player.szName ,dwForce = player.dwForceID})
		end
	end
	table.sort(tTeam,function(a,b) return a.dwForce < b.dwForce end)
	for _,v in ipairs(tTeam) do
		local szIcon,nFrame = GetForceImage(v.dwForce)
		table.insert(menu,{
			szOption = v.szName,
			szLayer = "ICON_RIGHT",
			szIcon = szIcon,
			nFrame = nFrame ,
			rgb = {JH.GetForceColor(v.dwForce)},
			fnAction = function()
				local list = GUI(Station.Lookup("Normal1/GKP_Record/TeamList"))
				local teamlist = list:Text(v.szName):Color(JH.GetForceColor(v.dwForce)).self
				teamlist.dwForceID = v.dwForce
			end
		})
	end
	return menu
end

---------------------------------------------------------------------->
-- 窗体创建时会被调用
----------------------------------------------------------------------<
function GKP.OnFrameCreate()
	_GKP.frame = this
	_GKP.GKP_Record_Container = this:Lookup("PageSet_Menu/Page_GKP_Record/WndScroll_GKP_Record/WndContainer_Record_List")
	_GKP.GKP_Account_Container = this:Lookup("PageSet_Menu/Page_GKP_Account/WndScroll_GKP_Account/WndContainer_Account_List")
	_GKP.GKP_Buff_Container = this:Lookup("PageSet_Menu/Page_GKP_Buff/WndScroll_GKP_Buff/WndContainer_Buff_List")
	local frm = Station.Lookup("Normal1/GKP_Record")
	local ui = GUI(this)
	local PageSet = ui:Fetch("PageSet_Menu")
	local record = GUI(frm)
	ui:Title(_L["GKP Golden Team Record"]):Point():Close(_GKP.ClosePanel)
	:Append("WndComboBox",{x = 805,y = 52,txt = _L["Setting"]}):Click(_GKP.GetSettingMenu)
	PageSet:Append("WndButton3",{x = 15,y = 610,txt = _L["Add Manually"]}):Click(function()
		if IsCtrlKeyDown() and JH_About.CheckNameEx() then -- 和谐自用
			return _GKP.GKP_Bidding()
		end
		if record:IsVisible() then
			return JH.Alert(_L["No Record For Current Object."])
		end
		if not GKP.IsDistributer() then
			return JH.Alert(_L["You are not the distrubutor."])
		end	
		pcall(_GKP.Record)
	end)
	PageSet:Append("WndButton3", {x = 840,y = 570,txt = g_tStrings.GOLD_TEAM_SYLARY_LIST}):Click(_GKP.GKP_Calculation)
	PageSet:Append("WndButton3", "GOLD_TEAM_BID_LIST", {x = 840,y = 610,txt = g_tStrings.GOLD_TEAM_BID_LIST}):Click(_GKP.GKP_SpendingList)
	PageSet:Append("WndButton3", "Debt", {x = 690,y = 610,txt = _L["Debt Issued"]}):Click(_GKP.GKP_OweList)
	PageSet:Append("WndButton3",{x = 540,y = 610,txt = _L["Wipe Record"]}):Click(_GKP.GKP_Clear)
	PageSet:Append("WndButton3",{x = 390,y = 610,txt = _L["Loading Record"]}):Click(_GKP.GKP_Recovery)
	PageSet:Append("WndButton3",{x = 240,y = 610,txt = _L["Manual SYNC"]}):Click(_GKP.GKP_Sync)

	PageSet:Fetch("WndCheck_GKP_Record"):Fetch("Text_GKP_Record"):Text(g_tStrings.GOLD_BID_RECORD_STATIC_TITLE)
	PageSet:Fetch("WndCheck_GKP_Account"):Fetch("Text_GKP_Account"):Text(g_tStrings.GOLD_BID_RPAY_STATIC_TITLE)
	PageSet:Fetch("WndCheck_GKP_Buff"):Fetch("Text_GKP_Buff"):Text(_L["Team Profile"])
	
	record:Title(_L["GKP Golden Team Record"]):Point():Close(function()
		if this.userdata then
			record:Fetch("Money"):Text(0)
			return record:Fetch("btn_ok"):Click()
		end
		record:Toggle(false)
		FireEvent("GKP_DEL_DISTRIBUTE_ITEM")
	end)

	-- append text
	record:Append("Text",{x = 60,y = 50,font = 65,txt = _L["Keep Account to:"]})
	record:Append("Text",{x = 60,y = 124,font = 65,txt = _L["Name of the Item:"]})
	record:Append("Text",{x = 60,y = 154,font = 65,txt = _L["Route of Acquiring:"]})
	record:Append("Text",{x = 60,y = 184,font = 65,txt = _L["Auction Price:"]})
	record:Append("WndCheckBox",{x = 20,y = 300,font = 65,txt = _L["Equiptment Boss"]}):Name("WndCheckBox")
	record:Append("WndButton3",{x = 115,y = 300,txt = g_tStrings.STR_HOTKEY_SURE}):Name("btn_ok")
	record:Append("WndComboBox",{x = 135,y = 53,txt = g_tStrings.PLAYER_NOT_EMPTY}):Name("TeamList"):Menu(GKP.GetTeamList)
	record:Append("WndEdit",{x = 135,y = 155,w = 185,h = 25}):Name("Source")
	
	
	local fnAction_Name = function()
		local me = this
		local txt = me:GetText()
		if txt ~= "" then
			if IsPopupMenuOpened() then 
				Wnd.CloseWindow("PopupMenuPanel")
				me.txt = nil
			end
			return 
		end
		if IsPopupMenuOpened() then
			return
		end
		local menu = {}
		for k,v in ipairs(_GKP.Config.Subsidies) do
			if v[3] then
				table.insert(menu,{
					szOption = v[1],
					fnAction = function()
						me:SetText(v[1])
						record:Fetch("Money"):Text(v[2]):Focus()
					end
				})
			end
		end
		local nX, nY = this:GetAbsPos()
		local nW, nH = this:GetSize()
		menu.nMiniWidth = nW
		menu.x = nX
		menu.y = nY + nH
		menu.bShowKillFocus = true
		menu.bDisableSound = true		
		PopupMenu(menu)
		Station.SetFocusWindow(me)
	end
	record:Append("WndEdit",{x = 135,y = 125,w = 185,h = 25}):Name("Name"):Focus(fnAction_Name,function()
		if not Station.GetFocusWindow() then return end
		local szFocusWindow = Station.GetFocusWindow():GetName()
		if szFocusWindow ~= "Edit_Default" and szFocusWindow ~= "PopupMenuPanel" then
			Wnd.CloseWindow("PopupMenuPanel")
		end
	end):Change(fnAction_Name)
	
	local fnAction =  function()
		local me = this
		local txt = me:GetText()
		if IsPopupMenuOpened() and me.txt and me.txt == txt then
			return
		end
		if tonumber(me:GetText()) then
			me.txt = me:GetText()
			me:SetFontColor(GKP.GetMoneyCol(me:GetText()))
			if tonumber(me:GetText()) >= 1000 or tonumber(me:GetText()) <= -1000 or tonumber(me:GetText()) == 0 then
				if IsPopupMenuOpened() then
					Wnd.CloseWindow("PopupMenuPanel")
				end
				return
			end
			local menu = {}
			for k,v in ipairs({2,3,4}) do
				local nMoney = string.format("%0.".. v .."f", me:GetText()):gsub("%.","")
				table.insert(menu,{
					szOption = nMoney,
					rgb = {GKP.GetMoneyCol(nMoney)},
					szLayer = "ICON_RIGHT",
					nFrame = 11,
					szIcon = "ui/image/LootPanel/LootPanel.UITex",
					fnAction = function()
						me:SetText(nMoney)
					end
				})
			end
			local nX, nY = me:GetAbsPos()
			local nW, nH = me:GetSize()
			menu.nMiniWidth = nW
			menu.x = nX
			menu.y = nY + nH
			menu.bShowKillFocus = true
			menu.bDisableSound = true
			PopupMenu(menu)
			Station.SetFocusWindow(me)
		elseif txt == "" then
			me.txt = nil
			if IsPopupMenuOpened() then 
				Wnd.CloseWindow("PopupMenuPanel")
			end
		else
			if me.txt then
				me:SetText(me.txt)
			else
				me:SetText(0)
			end
		end
	end
	record:Append("WndEdit",{x = 135,y = 185,w = 185,h = 25}):Name("Money"):Focus(fnAction,function()
		if not Station.GetFocusWindow() then return end
		local szFocusWindow = Station.GetFocusWindow():GetName()
		if szFocusWindow ~= "Edit_Default" and szFocusWindow ~= "PopupMenuPanel" then
			Wnd.CloseWindow("PopupMenuPanel")
		end
	end):Change(fnAction)

	
	-- 排序
	local page = this:Lookup("PageSet_Menu/Page_GKP_Record")
	local t = {
		{"#",false},
		{"szPlayer",_L["Gainer"]},
		{"szName",_L["Name of the Items"]},
		{"nMoney",_L["Auction Price"]},
		{"szNpcName",_L["Source of the Object"]},
		{"nTime",_L["Distribution Time"]},
	}
	for k ,v in ipairs(t) do
		if v[2] then
			local txt = page:Lookup("", "Text_Record_Break" ..k)
			txt:RegisterEvent(786)
			txt:SetText(v[2])
			txt.OnItemLButtonClick = function()
				local sort = txt.sort or "asc"
				pcall(_GKP.Draw_GKP_Record, v[1], sort)
				if sort == "asc" then
					txt.sort = "desc"
				else
					txt.sort = "asc"
				end
			end
			txt.OnItemMouseEnter = function()
				this:SetFontColor(255, 128, 0)
			end
			txt.OnItemMouseLeave = function()
				this:SetFontColor(255, 255, 255)
			end
		end
	end
	
	-- 排序2
	local page = this:Lookup("PageSet_Menu/Page_GKP_Account")
	local t = {
		{"#",false},
		{"szPlayer",_L["Transation Target"]},
		{"nGold",_L["Changes in Money"]},
		{"szPlayer",_L["Ways of Money Change"]},
		{"dwMapID",_L["The Map of Current Location when Money Changes"]},
		{"nTime",_L["The Change of Time"]},
	}
	
	for k ,v in ipairs(t) do
		if v[2] then
			local txt = page:Lookup("","Text_Account_Break"..k)
			txt:RegisterEvent(786)
			txt:SetText(v[2])
			txt.OnItemLButtonClick = function()
				local sort = txt.sort or "asc"
				pcall(_GKP.Draw_GKP_Account,v[1],sort)
				if sort == "asc" then
					txt.sort = "desc"
				else
					txt.sort = "asc"
				end
			end
			txt.OnItemMouseEnter = function()
				this:SetFontColor(255,128,0)
			end
			txt.OnItemMouseLeave = function()
				this:SetFontColor(255,255,255)
			end
		end
	end
	-- 排序3
	local page = this:Lookup("PageSet_Menu/Page_GKP_Buff")
	local t = {
		{"#",false},
		{"dwForceID",_L["Team Members"]},
		{"nScore1",_L["Item Buff"]},
		{"nScore2",_L["Team Buff"]},
		{"nEquipScore",_L["Score of the Equiptment"]},
		{"bFightState",_L["Information on Combat Situation"]},
		{false,_L["Update time"]}
	}
	for k ,v in ipairs(t) do
		if v[2] then
			local txt = page:Lookup("","Text_Buff_Break"..k)
			txt:RegisterEvent(786)
			txt:SetText(v[2])
			if v[1] then
				txt.OnItemLButtonClick = function()
					local sort = txt.sort or "asc"
					pcall(_GKP.Draw_GKP_Buff,v[1],sort)
					if sort == "asc" then
						txt.sort = "desc"
					else
						txt.sort = "asc"
					end
				end
				txt.OnItemMouseEnter = function()
					this:SetFontColor(255,128,0)
				end
				txt.OnItemMouseLeave = function()
					this:SetFontColor(255,255,255)
				end
			end
		end
	end
end
---------------------------------------------------------------------->
-- 获取设置菜单
----------------------------------------------------------------------<
local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	ui:Append("Text", { x = 0, y = 0, txt = _L["Preference Setting"], font = 27 })
	ui:Append("WndButton3", { x = 350, y = 0 }):Text(_L["Open Panel"]):Click(_GKP.OpenPanel)
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = 28, checked = GKP.Config.bDisplayEmptyRecords })
	:Text(_L["Clause with 0 Gold as Record"]):Click(function(bChecked)
		GKP.Config.bDisplayEmptyRecords = bChecked
		pcall(_GKP.Draw_GKP_Record)
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = GKP.Config.bAutoSetMoney })
	:Text(_L["Auto Fill Money by Clicking Right Button"]):Click(function(bChecked)
		GKP.Config.bAutoSetMoney = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = GKP.Config.bAutoBX })
	:Text(_L["Auto Fill the amount of BiXi Fragment as Price"]):Click(function(bChecked)
		GKP.Config.bAutoBX = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = GKP.Config.bAlertMessage })
	:Text(_L["Remind Wipe Data When Enter Dungeon"]):Click(function(bChecked)
		GKP.Config.bAlertMessage = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = GKP.Config.bAutoSync })
	:Text(_L["Automatic Reception with Record From Distributor"]):Click(function(bChecked)
		GKP.Config.bAutoSync = bChecked
	end):Pos_()
	nX = ui:Append("WndComboBox", { x = 10, y = nY,w = 130,h = 30 })
	:Text(_L["Popup with Record Options"]):Menu(function()
		return {
			{ szOption = _L["Popup Record for Distributor"],bCheck = true,bChecked = GKP.Config.bOn,fnAction = function()
				GKP.Config.bOn = not GKP.Config.bOn
			end},
			{ szOption = _L["Popup Record for Nondistributor"],bCheck = true,bChecked = GKP.Config.bOn2,fnAction = function()
				GKP.Config.bOn2 = not GKP.Config.bOn2
				if GKP.Config.bOn2 then
					GKP.Config.bAutoSync = false
				else
					GKP.Config.bAutoSync = true
				end
			end},
		}
	end):Pos_()
	nX = ui:Append("WndComboBox", { x = nX + 10, y = nY,w = 130,h = 30 })
	:Text(_L["Edit Allowance Protocols"]):Menu(_GKP.GetSubsidiesMenu):Pos_()
	nX,nY = ui:Append("WndComboBox", { x = nX + 10, y = nY,w = 130,h = 30 })
	:Text(_L["Edit Auction Protocols"]):Menu(_GKP.GetSchemeMenu):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY, txt = _L["Set Loot Title"]}):Pos_()
	nX,nY = ui:Append("WndEdit", { x = nX + 5, y = nY,txt = GKP.Config.szLootListTitle}):Change(function(txt)
		GKP.Config.szLootListTitle = txt
		_GKP.SetLootTitle()
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Money Record"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY + 12, checked = GKP.Config.bMoneySystem })
	:Text(_L["Track Money Trend in the System"]):Click(function(bChecked)
		GKP.Config.bMoneySystem = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = GKP.Config.bMoneyTalk })
	:Text(_L["Enable Money Trend"]):Click(function(bChecked)
		GKP.Config.bMoneyTalk = bChecked
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Team Profile"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY + 12, checked = GKP.Config.bCheckScore })
	:Text(_L["Team Profile on Equipment Score"]):Click(function(bChecked)
		GKP.Config.bCheckScore = bChecked
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY, checked = GKP.Config.bDeathWarn })
	:Text(_L["Injuries tips"]):Click(function(bChecked)
		GKP.Config.bDeathWarn = bChecked
	end):Pos_()
	if JH_About.CheckNameEx() then
		ui:Append("WndCheckBox", { x = 320, y = nY, checked = GKP.Config.bDebug2 })
		:Text(_L["Show LootList(HEXIE)"]):Click(function(bChecked)
			GKP.Config.bDebug2 = not GKP.Config.bDebug2
		end)
	end
end
GUI.RegisterPanel(_L["GKP Golden Team Record"], 95, _L["General"], PS)


_GKP.GetSettingMenu = function()
	if JH.IsPanelOpened() then
		JH.ClosePanel()
	else
		JH.OpenPanel(_L["GKP Golden Team Record"])
	end
	return
end
---------------------------------------------------------------------->
-- 获取补贴方案菜单
----------------------------------------------------------------------<
_GKP.GetSubsidiesMenu = function()
	local menu = { szOption = _L["Edit Allowance Protocols"] , rgb = {255,0,0} }
	table.insert(menu,{
		szOption = _L["Add New Protocols"],
		rgb = {255,255,0},
		fnAction = function()
			GetUserInput(_L["New Protocol  Format: Protocol's Name, Money"],function(txt)
				local t = JH.Split(txt,",")
				table.insert(_GKP.Config.Subsidies,{t[1],tonumber(t[2]) or "",true})
				pcall(_GKP.SaveConfig)
			end)
		end
	})
	table.insert(menu,{bDevide = true})
	for k,v in ipairs(_GKP.Config.Subsidies) do
		table.insert(menu,{
			szOption = v[1],
			bCheck = true,
			bChecked = v[3],
			fnAction = function()
				v[3] = not v[3]
				pcall(_GKP.SaveConfig)
			end,
		})
	end
	return menu
end
---------------------------------------------------------------------->
-- 获取拍卖方案菜单
----------------------------------------------------------------------<
_GKP.GetSchemeMenu = function()
	local menu = { szOption = _L["Edit Auction Protocols"] , rgb = {255,0,0} }
	table.insert(menu,{
		szOption = _L["Edit All Protocols"],
		rgb = {255,255,0},
		fnAction = function()
			GetUserInput(_L["New Protocol Format: Money, Money, Money"],function(txt)
				local t = JH.Split(txt,",")
				_GKP.Config.Scheme = {}
				for k,v in ipairs(t) do
					table.insert(_GKP.Config.Scheme,{tonumber(v) or 0,true})
				end
				pcall(_GKP.SaveConfig)
			end)
		end
	})
	table.insert(menu,{bDevide = true})
	for k,v in ipairs(_GKP.Config.Scheme) do
		table.insert(menu,{
			szOption = v[1],
			bCheck = true,
			bChecked = v[2],
			fnAction = function()
				v[2] = not v[2]
				pcall(_GKP.SaveConfig)
			end,
		})
	end
	
	return menu
end

---------------------------------------------------------------------->
-- 绘制团队概况
----------------------------------------------------------------------<
_GKP.Draw_GKP_Buff = function(key,sort)
	if _GKP.frame:IsVisible() then
		JH.DelayCall(3000,_GKP.Draw_GKP_Buff)
	end
	local key = key or _GKP.GKP_Buff_Container.key or "nEquipScore"
	local sort = sort or _GKP.GKP_Buff_Container.sort or "desc"
	_GKP.GKP_Buff_Container.key = key
	_GKP.GKP_Buff_Container.sort = sort
	_GKP.GKP_Buff_Container:Clear()
	local me = GetClientPlayer()
	if not me.IsInParty() then
		return
	end
	local team = GetClientTeam()
	local TeamMemberList = team.GetTeamMemberList()
	local tType = { [24] = true,[17] = true,[18] = true,[19] = true,[20] = true }
	local tType2 = { [362] = true, [673] = true,[112] = true,[382] = true, [3219] = true, [2837] = true }
	local tNameEx = { -- utf8 not supported
		-- ["隐居"] = 3694590,
		-- ["樱墨"] = 1301156,
	}
	local tab = {}
	for k,v in ipairs(TeamMemberList) do
		local player = GetPlayer(v)
		local tPlayer = team.GetMemberInfo(v)
		local t = {
			dwID = v,
			Box1 = {},
			Box2 = {},
			szName = tPlayer.szName,
			dwForceID = tPlayer.dwForceID,
			dwMountKungfuID = tPlayer.dwMountKungfuID,
			nScore1 = 0,
			nScore2 = 0,
			nEquipScore = 0,
			bFightState = 2,
		}
		if player then
			for _, tBuff in ipairs(JH.GetBuffList(player)) do
				local nType = GetBuffInfo(tBuff.dwID,tBuff.nLevel,{}).nDetachType or 0
				if tType[nType] then
					table.insert(t.Box1,tBuff)
					t.nScore1 = t.nScore1 + 1
				end
				if tType2[tBuff.dwID] then
					table.insert(t.Box2,tBuff)
					t.nScore2 = t.nScore2 + 1
				end
			end
			local nEquipScore = player.GetTotalEquipScore()
			if GKP.Config.bCheckScore then
				if nEquipScore == 0 then
					_GKP.tViewInvite[v] = true
					local PlayerView = Station.Lookup("Normal/PlayerView")
					if not PlayerView or not PlayerView:IsVisible() then
						ViewInviteToPlayer(v)
					end
				end
			end
			t.nEquipScore = nEquipScore
			if player.bFightState then
				t.bFightState = 1
			else
				t.bFightState = 0
			end
		end
		table.insert(tab,t)
	end

	table.sort(tab,function(a,b)
		if a[key] and b[key] then
			if sort == "asc" then
				return a[key] < b[key]
			else
				return a[key] > b[key]
			end
		else
			return false
		end
	end)
	
	for k,v in ipairs(tab) do
		local wnd = _GKP.GKP_Buff_Container:AppendContentFromIni(PATH_ROOT .. "ui/GKP_Buff_Item.ini","WndWindow",k)
		local item = wnd:Lookup("","")
		if k % 2 == 0 then
			item:Lookup("Image_Line"):Hide()
		end
		local player = GetPlayer(v.dwID)
		item:Lookup("Text_No"):SetText(k)
		-- item:Lookup("Image_NameIcon"):FromUITex(GetForceImage(v.dwForceID))
		item:Lookup("Image_NameIcon"):FromIconID(Table_GetSkillIconID(v.dwMountKungfuID))
		item:Lookup("Text_Name"):SetText(v.szName)
		item:Lookup("Text_Name"):SetFontColor(JH.GetForceColor(v.dwForceID))
		local ex,r,g,b = _L["Not in the Scope"],255,255,255
		if tNameEx[v.szName] and tNameEx[v.szName] == v.dwID then
			player = nil
			ex,r,g,b = "Access denied",255,128,0
		end
		if player then
			for kk, vv in pairs(v.Box1) do
				wnd:Lookup("","Handle_Box1"):AppendItemFromString("<box>w=28 h=28 name=\"".. vv.nIndex  .."\"</box>")
				local box = wnd:Lookup("","Handle_Box1"):Lookup(tostring(vv.nIndex))
				wnd:Lookup("","Handle_Box1"):FormatAllItemPos()
				box:SetObject(UI_OBJECT_ITEM)
				box:SetObjectIcon(Table_GetBuffIconID(vv.dwID,vv.nLevel))
				box:RegisterEvent(786)
				local nTime = (vv.nEndFrame - GetLogicFrameCount()) / 16
				if nTime < 480 then
					box:SetAlpha(80)
				end
				box.OnItemMouseLeave = function()
					this:SetObjectMouseOver(false)
					HideTip()
				end
				box.OnItemMouseEnter = function()
					this:SetObjectMouseOver(true)
					local x, y = this:GetAbsPos()
					local w, h = this:GetSize()
					OutputBuffTip(player,vv.dwID,vv.nLevel,0,true,nTime,{x,y,w,h})
				end
			end
			
			-- wnd:Lookup("","Handle_Box1"):SetRelPos(200+ (150 - #v.Box1 * 28) / 2 ,0)

			for kk, vv in pairs(v.Box2) do
				wnd:Lookup("","Handle_Box2"):AppendItemFromString("<box>w=28 h=28 name=\"".. vv.nIndex  .."\"</box>")
				local box = wnd:Lookup("","Handle_Box2"):Lookup(tostring(vv.nIndex))
				wnd:Lookup("","Handle_Box2"):FormatAllItemPos()
				box:SetObject(UI_OBJECT_ITEM)
				box:SetObjectIcon(Table_GetBuffIconID(vv.dwID,vv.nLevel))
				box:RegisterEvent(786)
				local nTime = (vv.nEndFrame - GetLogicFrameCount()) / 16
				if nTime < 480 then
					box:SetAlpha(80)
				end
				box.OnItemMouseLeave = function()
					this:SetObjectMouseOver(false)
					HideTip()
				end
				box.OnItemMouseEnter = function()
					this:SetObjectMouseOver(true)
					local x, y = this:GetAbsPos()
					local w, h = this:GetSize()
					OutputBuffTip(player,vv.dwID,vv.nLevel,0,true,nTime,{x,y,w,h})
				end
			end

			-- wnd:Lookup("","Handle_Box2"):SetRelPos(350 + (150 - #v.Box2 * 28) / 2 ,0)
			-- wnd:Lookup("",""):FormatAllItemPos()
			if v.bFightState == 1 then
				item:Lookup("Text_Fight"):SetText(_L["Combat"])
				item:Lookup("Text_Fight"):SetFontColor(255,0,0)
			else
				item:Lookup("Text_Fight"):SetText(_L["Nocombat"])
				item:Lookup("Text_Fight"):SetFontColor(0,255,0)
			end
			if GKP.Config.bCheckScore then
				item:Lookup("Text_Score"):SetText(v.nEquipScore)
			else
				item:Lookup("Text_Score"):SetText(_L["Unopened"])
			end			
		else
			for kk,vv in ipairs({"Text_Box1","Text_Box2","Text_Score","Text_Fight"}) do
				item:Lookup(vv):SetText(ex)
				item:Lookup(vv):SetFontColor(r,g,b)
			end
		end
		item:Lookup("Text_Time"):SetText(GKP.GetTimeString(GetCurrentTime()))
		item:Lookup("Text_Name"):RegisterEvent(786)
		item:Lookup("Text_Name").OnItemLButtonClick = function()
			if IsCtrlKeyDown() then
				return GKP.InsertEditByName(v.szName)
			end
			SetTarget(TARGET.PLAYER,v.dwID)
			ViewInviteToPlayer(v.dwID)
		end
		
		item:Lookup("Text_Name").OnItemMouseEnter = function()
			local szIcon,nFrame = GetForceImage(v.dwForceID)
			local r,g,b = JH.GetForceColor(v.dwForceID)
			local szXml = GetFormatImage(szIcon,nFrame,20,20) .. GetFormatText("  " .. v.szName .. _L[":\n"],136,r,g,b)
			szXml = szXml .. GetFormatText(_L["Serious Injured Record as Shown Below\n\n"],136,255,255,255)
			if not _GKP.DeathWarn.tDeath[v.dwID] or #_GKP.DeathWarn.tDeath[v.dwID] == 0 then
				szXml = szXml ..GetFormatText(_L["No Record"],136,255,255,0)
			else
				for i = #_GKP.DeathWarn.tDeath[v.dwID] , 1 , -1 do
					local a = _GKP.DeathWarn.tDeath[v.dwID][i]
					szXml = szXml ..GetFormatText(GKP.GetTimeString(a.time,true) .. " ",136,255,255,0)
					szXml = szXml ..GetFormatText(a.szCaster,136,255,128,0)
					szXml = szXml ..GetFormatText(" <",136,255,255,0)
					szXml = szXml ..GetFormatText(a.szSkillName,136,255,128,0)
					szXml = szXml ..GetFormatText("> ",136,255,255,0)
					szXml = szXml ..GetFormatText(_L["Cause"],136,255,255,0)
					szXml = szXml ..GetFormatText(a.szValue .. "\n",136,255,128,0)
				end
			end
			local x, y = item:Lookup("Text_No"):GetAbsPos()
			local w, h = item:Lookup("Text_No"):GetSize()
			OutputTip(szXml,600,{x,y,w,h})
		end
		
		item:Lookup("Text_Name").OnItemMouseLeave = function()
			HideTip()
		end
	end
	_GKP.GKP_Buff_Container:FormatAllContentPos()	
end

---------------------------------------------------------------------->
-- 查看装备回调事件
----------------------------------------------------------------------<
RegisterEvent("PEEK_OTHER_PLAYER", function()
	if arg0 ~= 1 then return end
	if _GKP.tViewInvite[arg1] then
		_GKP.tViewInvite[arg1] = nil
		for k,v in pairs(_GKP.tViewInvite) do
			return ViewInviteToPlayer(k)
		end
		JH.DelayCall(200,function()
			Station.Lookup("Normal/PlayerView"):Hide()
		end)
	end
end)
---------------------------------------------------------------------->
-- 绘制物品记录
----------------------------------------------------------------------<
_GKP.Draw_GKP_Record = function(key,sort)
	local key = key or _GKP.GKP_Record_Container.key or "nTime"
	local sort = sort or _GKP.GKP_Record_Container.sort or "desc"
	local tab = GKP("GKP_Record",key,sort)
	_GKP.GKP_Record_Container.key = key
	_GKP.GKP_Record_Container.sort = sort
	_GKP.GKP_Record_Container:Clear()
	local a,b = _GKP.GetRecordSum()
	local c = 0
	for k,v in ipairs(tab) do
		if GKP.Config.bDisplayEmptyRecords or v.nMoney ~= 0 then
			local wnd = _GKP.GKP_Record_Container:AppendContentFromIni(PATH_ROOT .. "ui/GKP_Record_Item.ini","WndWindow",i)
			local item = wnd:Lookup("","")
			if k % 2 == 0 then
				item:Lookup("Image_Line"):Hide()
			end
			if v.bDelete then
				wnd:SetAlpha(80)
			end
			item:RegisterEvent(32)
			item.OnItemRButtonClick = function()
				if not GKP.IsDistributer() then
					return JH.Alert(_L["You are not the distrubutor."])
				end	
				_GKP.Record(v,k)
			end
			item:Lookup("Text_No"):SetText(k)
			item:Lookup("Image_NameIcon"):FromUITex(GetForceImage(v.dwForceID))
			item:Lookup("Text_Name"):SetText(v.szPlayer)
			item:Lookup("Text_Name"):SetFontColor(JH.GetForceColor(v.dwForceID))
			local szName = v.szName or Table_GetItemName(v.nUiId)
			item:Lookup("Text_ItemName"):SetText(szName)
			if v.nQuality then
				item:Lookup("Text_ItemName"):SetFontColor(GetItemFontColorByQuality(v.nQuality))
			else
				item:Lookup("Text_ItemName"):SetFontColor(255,255,0)
			end
			item:Lookup("Text_Money"):SetText(v.nMoney)
			item:Lookup("Text_Money"):SetFontColor(GKP.GetMoneyCol(v.nMoney))
			
			item:Lookup("Text_Source"):SetText(v.szNpcName)
			if v.bSync then
				item:Lookup("Text_Source"):SetFontColor(0,255,0)
			end
			item:Lookup("Text_Time"):SetText(GKP.GetTimeString(v.nTime))
			if v.bEdit then
				item:Lookup("Text_Time"):SetFontColor(255,255,0)
			end
			local box = item:Lookup("Box_Item")
			box:SetObject(UI_OBJECT_ITEM_INFO, v.nVersion, v.dwTabType, v.dwIndex)
			box:SetObjectIcon(Table_GetItemIconID(v.nUiId))
			
			if v.nStackNum then
				box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
				box:SetOverTextFontScheme(0,15)
				box:SetOverText(0, v.nStackNum .. " ")
			end
			if v.dwTabType == 0 and v.dwIndex == 0 then box:SetObjectIcon(2490) end
			item:Lookup("Text_ItemName"):RegisterEvent(786)
			box:RegisterEvent(786)
			local OnItemMouseEnter = function()
				box:SetObjectMouseOver(true)
				local x, y = box:GetAbsPos()
				local w, h = box:GetSize()
				if v.nBookID then
					local dwBookID, dwSubID = GlobelRecipeID2BookID(v.nBookID)
					OutputBookTipByID(dwBookID, dwSubID,{x, y, w, h})
				else
					local _,dwTabType,dwIndex = box:GetObjectData()
					if dwTabType == 0 and dwIndex == 0 then return end
					OutputItemTip(UI_OBJECT_ITEM_INFO,GLOBAL.CURRENT_ITEM_VERSION,dwTabType,dwIndex,{x, y, w, h})
				end
			end
			
			item:Lookup("Text_ItemName").OnItemMouseEnter = OnItemMouseEnter
			box.OnItemMouseEnter = OnItemMouseEnter
			
			local OnItemMouseLeave = function()
				box:SetObjectMouseOver(false)
				HideTip()
			end
			
			item:Lookup("Text_ItemName").OnItemMouseLeave = OnItemMouseLeave
			box.OnItemMouseLeave = OnItemMouseLeave
			local OnItemLButtonClick = function()
				if IsCtrlKeyDown() or IsAltKeyDown() then
					return GKP.OnItemLinkDown(v,this)
				end
			end
			item:Lookup("Text_ItemName").OnItemLButtonClick = OnItemLButtonClick
			box.OnItemLButtonClick = OnItemLButtonClick
			
			wnd:Lookup("WndButton_Delete").OnLButtonClick = function()
				if not GKP.IsDistributer() then
					return JH.Alert(_L["You are not the distrubutor."])
				end	
				local tab = GKP("GKP_Record","del",k)
				if GKP.IsDistributer() then
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP","del",JH.AscIIEncode(JH.JsonEncode(tab)))
				end
				pcall(_GKP.Draw_GKP_Record)
			end
			
			wnd:Lookup("WndButton_Edit").OnLButtonClick = function()
				if not GKP.IsDistributer() then
					return JH.Alert(_L["You are not the distrubutor."])
				end	
				_GKP.Record(v,k)
			end
			
			-- tip
			item:Lookup("Text_Name"):RegisterEvent(786)
			item:Lookup("Text_Name").OnItemLButtonClick = function()
				if IsCtrlKeyDown() then
					return GKP.InsertEditByName(v.szPlayer)
				end
			end
			
			item:Lookup("Text_Name").OnItemMouseEnter = function()
				local szIcon,nFrame = GetForceImage(v.dwForceID)
				local r,g,b = JH.GetForceColor(v.dwForceID)
				local szXml = GetFormatImage(szIcon,nFrame,20,20) .. GetFormatText("  " .. v.szPlayer .. _L[":\n"],136,r,g,b)
				szXml = szXml .. GetFormatText(_L["System Information as Shown Below\n\n"],136,255,255,255)
				local nNum,nNum1,nNum2 = 0,0,0
				for kk,vv in ipairs(GKP("GKP_Record")) do
					if vv.szPlayer == v.szPlayer and not vv.bDelete then
						if  vv.nMoney > 0 then
							nNum = nNum + vv.nMoney
						else
							nNum1 = nNum1 + vv.nMoney
						end
					end
				end
				local r,g,b = GKP.GetMoneyCol(nNum)
				szXml = szXml .. GetFormatText(_L["Total Cosumption:"],136,255,128,0) .. GetFormatText(nNum .._L["Gold.\n"],136,r,g,b)
				local r,g,b = GKP.GetMoneyCol(nNum1)
				szXml = szXml .. GetFormatText(_L["Total Allowance:"],136,255,128,0) .. GetFormatText(nNum1 .._L["Gold.\n"],136,r,g,b)
				
				for kk,vv in ipairs(GKP("GKP_Account")) do
					if vv.szPlayer == v.szPlayer and not vv.bDelete and vv.nGold > 0 then
						nNum2 = nNum2 + vv.nGold
					end
				end
				local r,g,b = GKP.GetMoneyCol(nNum2)
				szXml = szXml .. GetFormatText(_L["Total Payment:"],136,255,128,0) .. GetFormatText(nNum2 .._L["Gold.\n"],136,r,g,b)
				local nNum3 = nNum+nNum1-nNum2
				if nNum3 < 0 then
					nNum3 = 0
				end
				local r,g,b = GKP.GetMoneyCol(nNum3)			
				szXml = szXml .. GetFormatText(_L["Money on Debt:"],136,255,128,0) .. GetFormatText(nNum3 .._L["Gold.\n"],136,r,g,b)
				
				local x, y = item:Lookup("Text_No"):GetAbsPos()
				local w, h = item:Lookup("Text_No"):GetSize()
				OutputTip(szXml,400,{x,y,w,h})
			end
			
			item:Lookup("Text_Name").OnItemMouseLeave = function()
				HideTip()
			end
			
			if v.bDelete then
				c = c + 1
			end
		end
	end
	
	_GKP.GKP_Record_Container:FormatAllContentPos()
	local txt = Station.Lookup("Normal/GKP/PageSet_Menu/Page_GKP_Record"):Lookup("","Text_GKP_RecordSettlement")
	txt:SetText(_L("Statistic: real salary = %d Gold(By Auction: %d Gold + Extra Allowance: %d Gold) %d record has been deleted.",a+b,a,b,c))
	txt:SetFontColor(255,255,0)
end
---------------------------------------------------------------------->
-- 和谐
----------------------------------------------------------------------<
_GKP.GKP_Bidding = function()
	local team = GetClientTeam()
	if not GKP.IsDistributer() then
		return JH.Alert(_L["You are not the distrubutor."])
	end	
	local nGold = _GKP.GetRecordSum(true)
	if nGold <= 0 then
		return JH.Alert(_L["Auction Money <=0."])
	end
	team.SetTeamLootMode(PARTY_LOOT_MODE.BIDDING)
	local GoldTeam = Wnd.OpenWindow("GoldTeam")
	local LeaderAddMoney = Wnd.OpenWindow("LeaderAddMoney")
	local fx, fy = Station.GetClientSize()
	local w,h = GoldTeam:GetSize()
	local w2,h2 = LeaderAddMoney:GetSize()
	GoldTeam:Hide()
	GoldTeam:SetAbsPos((fx-w)/2,(fy-h)/2)
	LeaderAddMoney:SetAbsPos((fx-w2)/2,(fy-h2)/2)
	LeaderAddMoney:Lookup("Edit_Price"):SetText(nGold)
	LeaderAddMoney:Lookup("Edit_Reason"):SetText("Auto Append Money")
	LeaderAddMoney:Lookup("Btn_Ok").OnLButtonUp = function()
		GoldTeam:Show()
		Station.SetActiveFrame("GoldTeam")
		GoldTeam:Lookup("PageSet_Total"):ActivePage(1)
	end	
end
---------------------------------------------------------------------->
-- 同步数据
----------------------------------------------------------------------<
_GKP.GKP_Sync = function()
	local me = GetClientPlayer()
	if not me.IsInParty() then return JH.Alert(_L["You are not in the team."]) end
	local TeamMemberList = GetClientTeam().GetTeamMemberList()
	local tTeam,menu = {},{}
	for _,v in ipairs(TeamMemberList) do
		local player = GetClientTeam().GetMemberInfo(v)
		table.insert(tTeam,{ szName = player.szName ,dwForce = player.dwForceID ,bIsOnLine = player.bIsOnLine})
	end
	table.sort(tTeam,function(a,b) return a.dwForce < b.dwForce end)
	table.insert(menu,{szOption = _L["Please select which will be the one you are going to ask record for."],bDisable = true	})
	table.insert(menu,{bDevide = true})
	for _,v in ipairs(tTeam) do
		local szIcon,nFrame = GetForceImage(v.dwForce)
		table.insert(menu,{
			szOption = v.szName,
			szLayer = "ICON_RIGHT",
			bDisable = not v.bIsOnLine,
			szIcon = szIcon,
			nFrame = nFrame ,
			rgb = {JH.GetForceColor(v.dwForce)},
			fnAction = function()
				JH.Confirm(_L["Wheater replace the current record with the synchronization target's record?\n Please notice, this means you are going to lose the information of current record."],function()
					JH.Alert(_L["Asking for the sychoronization information...\n If no response in longtime, it may because the opposite side are not using GKP plugin or not responding."])
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP","GKP_Sync",v.szName) -- 请求同步信息
				end)
			end
		})
	end
	PopupMenu(menu)
end
_GKP.OnMsg = function()
	local data = JH.BgHear("GKP", true)
	local me = GetClientPlayer()
	local team = GetClientTeam()
	if team and data then
		if arg3 ~= me.szName then
			if data[1] == "GKP_Sync" and data[2] == me.szName then
				local tab = {
					GKP_Record = GKP("GKP_Record"),
					GKP_Account = GKP("GKP_Account"),
				}
				local str = JH.AscIIEncode(JH.JsonEncode(tab))
				local nMax = 150
				local nTotle = math.ceil(#str / nMax)
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP","GKP_Sync_Start",arg3)
				for i = 1 , nTotle do
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP","GKP_Sync_Content",arg3,string.sub(str ,(i-1) * nMax + 1 , i * nMax))
				end
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP","GKP_Sync_Stop",arg3)
			end
			
			if data[1] == "GKP_Sync_Start" and data[2] == me.szName then
				_GKP.bSync = true
				JH.Alert(_L["Start Sychoronizing..."])
			end
			if data[1] == "GKP_Sync_Content" and data[2] == me.szName and _GKP.bSync then
				table.insert(_GKP.tSyncQueue,data[3])
				if #_GKP.tSyncQueue % 10 == 0 then
					JH.Alert(_L("Sychoronizing data please wait %d loaded.",#_GKP.tSyncQueue))
				end
			end
			
			if data[1] == "GKP_Sync_Stop" and data[2] == me.szName then
				local str = ""
				for i = 1, #_GKP.tSyncQueue do
					str = str .. _GKP.tSyncQueue[i]
				end
				_GKP.tSyncQueue = {}
				_GKP.bSync = false
				JH.Alert(_L["Sychoronization Complete"])
				local tData,err = JH.JsonDecode(JH.AscIIDecode(str))
				if err then
					return GKP.Sysmsg(_L["Abnormal with Data Sharing, Please contact and make feed back with the writer."])
				end
				JH.Confirm(_L("Data Sharing Finished, you have one last chance to confirm wheather cover the current data or not? \n data of team bidding: %s\n transation data: %s",#tData.GKP_Record,#tData.GKP_Account) ,function()
					_GKP.GKP_Record = tData.GKP_Record
					_GKP.GKP_Account = tData.GKP_Account
					pcall(_GKP.Draw_GKP_Record)
					pcall(_GKP.Draw_GKP_Account)
					pcall(_GKP.GKP_Save)
				end)
			end
			
			if (data[1] == "del" or data[1] == "edit" or data[1] == "add") and GKP.Config.bAutoSync and arg3 ~= me.szName then
				local tData,err = JH.JsonDecode(JH.AscIIDecode(data[2]))
				if err then
					return GKP.Sysmsg(_L["Abnormal with Data Sharing, Please contact and make feed back with the writer."])
				end
				tData.bSync = true
				if data[1] == "add" then
					pcall(GKP,"GKP_Record",tData)
				else
					for k,v in ipairs(GKP("GKP_Record")) do
						if v.key == tData.key then
							pcall(GKP,"GKP_Record",k,tData)
							break
						end
					end
				end
				pcall(_GKP.Draw_GKP_Record)
				JH.Debug("#GKP# Sync Success")
			end
		end
		if data[1] == "GKP_INFO" then -- 这他妈做成收据了。。。。。。。hhhhhhhhhhhhhhhhh
			if data[2] == "Start" then
				if Station.Lookup("Normal/GKP_info") then
					Wnd.CloseWindow(Station.Lookup("Normal/GKP_info"))
					_GKP.info = nil
				end
				_GKP.info = GUI.CreateFrame("GKP_info", { w = 760, h = 350, title = _L["GKP Golden Team Record"] }):Point():Close()
				_GKP.info:Append("Text", { w = 683, h = 30, txt = _L[data[3]], align = 1, font = 236 })
				_GKP.info:Append("WndButton2", "ScreenShot", { x = 580, y = -10, txt = _L["Print Ticket"], font = 41 })
				:Enable(false):Click(function()
					local scale = Station.GetUIScale()
					local left, top = _GKP.info:Pos()
					local right, bottom = _GKP.info:Pos_()
					local path = GetRootPath() .. string.format("\\ScreenShot\\GKP_Ticket_%s.png", FormatTime("%Y-%m-%d_%H.%M.%S", GetCurrentTime()))
					ScreenShot(path, 100, scale * left, scale * top, scale * right, scale * bottom)
					JH.Sysmsg(_L("Shot screen succeed, file saved as %s .", path))
				end)
				_GKP.info:Append("Text", { w = 120, h = 30, x = 0, y = 30, txt = _L("Operator:%s", arg3), font = 41 })
				_GKP.info:Append("Text", { w = 120, h = 30, x = 560, y = 30, txt = _L("Print Time:%s", GKP.GetTimeString(GetCurrentTime())), font = 41, align = 2 })
			end
			if data[2] == "Info" then
				local frm = Station.Lookup("Normal/GKP_info")
				if frm then
					if not frm.n then frm.n = 0 end
					local n = frm.n
					local ui = GUI(frm)
					if n % 2 == 0 then
						ui:Append("Image", { w = 760, h = 30, x = 0, y = 120 + 30 * n }):File("ui/Image/button/ShopButton.UITex", 75)
					end
					local dwForceID, tBox = -1, {}
					if me.IsInParty() then
						for k, v in ipairs(team.GetTeamMemberList()) do
							if team.GetClientTeamMemberName(v) == data[3] then
								dwForceID = team.GetMemberInfo(v).dwForceID
							end
						end
					end
					for k, v in ipairs(GKP("GKP_Record")) do -- 依赖于本地记录 反正也不可能差异到哪去
						if v.szPlayer == data[3] then
							if dwForceID == -1 then
								dwForceID = v.dwForceID
							end
							table.insert(tBox, v)
						end
					end
					if dwForceID ~= -1 then
						ui:Append("Image", { w = 28, h = 28, x = 30, y = 121 + 30 * n }):File(GetForceImage(dwForceID))
					end
					ui:Append("Text", { w = 140, h = 30, x = 60, y = 120 + 30 * n, txt = data[3], color = { JH.GetForceColor(dwForceID) } })
					local r, g, b = GKP.GetMoneyCol(data[4])
					if tonumber(data[4]) < 0 then
						r, g, b = GKP.GetMoneyCol(tonumber(data[4]) * - 1) -- 就算是欠债 也要抓颜色
					end
					ui:Append("Text", { w = 80, h = 30, x = 200, y = 120 + 30 * n, txt = data[4], align = 2, color = { r, g, b } })
					ui:Append("Image", { w = 28, h = 28, x = 283, y = 121 + 30 * n }):File("ui/image/LootPanel/LootPanel.UITex", 11)
					for k, v in ipairs(tBox) do
						if k > 12 then
							ui:Append("Text", { x = 290 + k * 32 + 5, y = 121 + 30 * n, w = 28, h = 28, txt = ".....", font = 23 })
							break
						end
						local alpha = 255
						if v.bDelete then
							alpha = 60
						end
						local box = ui:Append("Box", { x = 290 + k * 32, y = 121 + 30 * n, w = 28, h = 28, alpha = alpha }).self
						if _GKP.tQualityImage[v.nQuality] then
							if v.nQuality < 5 then
								ui:Append("Image", { x = 290 + k * 32, y = 121 + 30 * n, w = 28, h = 28, alpha = alpha })
								:File("ui/Image/Common/Box.UITex", _GKP.tQualityImage[v.nQuality])
							else
								ui:Append("Animate", { x = 290 + k * 32, y = 121 + 30 * n, w = 28, h = 28 })
								:Animate("ui/Image/Common/Box.UITex", 17, -1)
							end
						end
						
						box:SetObject(UI_OBJECT_ITEM_INFO, v.nVersion, v.dwTabType, v.dwIndex)
						local icon = 2490
						if v.nUiId ~= 0 then
							icon = Table_GetItemIconID(v.nUiId)
						end
						box:SetObjectIcon(icon)
						box:RegisterEvent(786)
						if v.nStackNum then
							box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
							box:SetOverTextFontScheme(0,15)
							box:SetOverText(0, v.nStackNum .. " ")
						end
						box.OnItemMouseEnter = function()
							this:SetObjectMouseOver(true)
							local x, y = this:GetAbsPos()
							local w, h = this:GetSize()
							if v.nBookID then
								local dwBookID, dwSubID = GlobelRecipeID2BookID(v.nBookID)
								OutputBookTipByID(dwBookID, dwSubID,{x, y, w, h})
							else
								local _,dwTabType,dwIndex = this:GetObjectData()
								if dwTabType == 0 and dwIndex == 0 then
									OutputTip(GetFormatText(v.szName .. g_tStrings.STR_TALK_HEAD_SAY1 .. v.nMoney .. _L["Gold."],136,255,255,0), 250, { x, y, w, h })
								else
									OutputItemTip(UI_OBJECT_ITEM_INFO,GLOBAL.CURRENT_ITEM_VERSION,dwTabType,dwIndex,{x, y, w, h})
								end
							end
						end
						box.OnItemMouseLeave = function()
							this:SetObjectMouseOver(false)
							HideTip()
						end
						box.OnItemLButtonClick = function()
							if IsCtrlKeyDown() or IsAltKeyDown() then
								return GKP.OnItemLinkDown(v,this)
							end
						end
					end
					if frm.n > 5 then
						_GKP.info:Size(760, 30 * frm.n + 200)
					end
					frm.n = frm.n + 1
				end
			end
			if data[2] == "End" then
				local frm = Station.Lookup("Normal/GKP_info")
				if frm then
					local ui = GUI(frm)
					local n = frm.n or 0
					ui:Append("Text", { w = 121, h = 30, x = 30, y = 120 + 30 * n + 1, txt = data[3], color = { 255, 255, 0 } })
					if data[4] then
						ui:Append("Text", { w = 121, h = 30, x = 620, y = 120 + 30 * n + 1, txt = string.format("%d/%d = %d", tonumber(data[4]), team.GetTeamSize(), math.floor(tonumber(data[4]) / team.GetTeamSize())), color = { GKP.GetMoneyCol(data[4]) }, align = 2 })
						_GKP.info:Fetch("ScreenShot"):Enable(true)
						if n >= 4 then
							ui:Append("Image", { x = 640, y = n * 30 + 10, w = 100, h = 107.5 }):File(JH.GetAddonInfo().szRootPath .. "GKP/img/zhcn_img.uitex", 0)
						end
					end
				end
				_GKP.SetButton(true)
			end
		end
	end
end

RegisterEvent("ON_BG_CHANNEL_MSG",_GKP.OnMsg)

_GKP.SetButton = function(bEnable)
	GUI(Station.Lookup("Normal/GKP/PageSet_Menu")):Fetch("GOLD_TEAM_BID_LIST"):Enable(bEnable)
	GUI(Station.Lookup("Normal/GKP/PageSet_Menu")):Fetch("Debt"):Enable(bEnable)
end

---------------------------------------------------------------------->
-- 恢复记录按钮
----------------------------------------------------------------------<
_GKP.GKP_Recovery = function()
	local me = GetClientPlayer()
	_GKP.szName = _GKP.szName or me.szName
	local menu = {}	
	table.insert(menu,{
		szOption = _L("Loading Data of the Character's name: %s (edit by clicking)",_GKP.szName),
		rgb = {255,255,0},
		fnAction = function()
			GetUserInput(_L["Modify to Lead the Character's name"],function(szText)
				_GKP.szName = szText
			end)
		end
	})
	for i = 0 , 19 do
		local nTime = GetCurrentTime() - i * 86400		
		local szPath = JH.GetAddonInfo().szDataPath .. "GKP/" .. _GKP.szName .. "/" .. FormatTime("%Y-%m-%d",nTime) .. ".gkp"
		table.insert(menu,{
			szOption = FormatTime("%Y-%m-%d",nTime) .. ".gkp",
			bDisable = not IsFileExist(szPath .. ".jx3dat"),
			fnAction = function()
				JH.Confirm(_L["Are you sure to cover the current information with the last record data?"],function()
					_GKP.GKP_LoadData("GKP/" .. _GKP.szName .. "/" .. FormatTime("%Y-%m-%d",nTime))
					JH.Alert(_L["Reocrd Recovered."])
				end)
			end,
		})
	end	
	PopupMenu(menu)
end
---------------------------------------------------------------------->
-- 清空数据
----------------------------------------------------------------------<
_GKP.GKP_Clear = function(bConfirm)
	local fnAction = function()
		_GKP.GKP_Record = {}
		_GKP.GKP_Account = {}
		pcall(_GKP.Draw_GKP_Record)
		pcall(_GKP.Draw_GKP_Account)
		_GKP.nNowMoney = GetClientPlayer().GetMoney().nGold
		_GKP.tDistributeRecords = {}
		JH.Alert(_L["Recods are wiped"])
	end
	if bConfirm then
		fnAction()
	else
		JH.Confirm(_L["Are you sure to wipe all of the records?"],fnAction)
	end
end
---------------------------------------------------------------------->
-- 欠费情况
----------------------------------------------------------------------<
_GKP.GKP_OweList = function()
	local me = GetClientPlayer()
	if not me.IsInParty() and not JH.bDebug then return JH.Alert(_L["You are not in the team."]) end
	local tMember = {}
	if IsEmpty(GKP("GKP_Record")) then
		return JH.Alert(_L["No Record"])
	end
	if not GKP.IsDistributer() and not JH.bDebug then
		return JH.Alert(_L["You are not the distrubutor."])
	end	
	_GKP.SetButton(false)	
	for k,v in ipairs(GKP("GKP_Record")) do
		if not v.bDelete then
			if tonumber(v.nMoney) > 0 then
				if not tMember[v.szPlayer] then
					tMember[v.szPlayer] = 0
				end
				tMember[v.szPlayer] = tMember[v.szPlayer] + v.nMoney
			end
		end
	end
	for k,v in ipairs(GKP("GKP_Account")) do
		if not v.bDelete and v.szPlayer and v.szPlayer ~= "System" then
			if tMember[v.szPlayer] then
				tMember[v.szPlayer] = tMember[v.szPlayer] - v.nGold
			else
				tMember[v.szPlayer] = v.nGold * -1
			end
		end
	end
	-- 欠账
	local tMember2 = {}
	for k,v in pairs(tMember) do
		if v ~= 0 then
			table.insert(tMember2,{szName = k, nGold = v * -1 })
		end
	end
	table.sort(tMember2,function(a,b) return a.nGold < b.nGold end)
	JH.Talk(_L["Information on Debt"])
	JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Start", "Information on Debt")
	for k,v in pairs(tMember2) do
		if v.nGold < 0 then
			JH.Talk({{type = "name" , name = v.szName , text =""},{type = "text" , text = g_tStrings.STR_TALK_HEAD_SAY1 .. v.nGold .. _L["Gold."]}})
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Info", v.szName, v.nGold, "-")
		else
			JH.Talk({{type = "name" , name = v.szName , text =""},{type = "text" , text = g_tStrings.STR_TALK_HEAD_SAY1 .. "+" .. v.nGold .. _L["Gold."]}})
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Info", v.szName, v.nGold, "+")
		end
	end
	local nGold,nGold2 = 0,0
	for _,v in ipairs(GKP("GKP_Account")) do
		if not v.bDelete then
			if v.szPlayer and v.szPlayer ~= "System" then -- 必须要有交易对象
				if tonumber(v.nGold) > 0 then
					nGold = nGold + v.nGold
				else
					nGold2 = nGold2 + v.nGold
				end
			end
		end
	end
	if nGold ~= 0 then
		JH.Talk(_L("Received: %d Gold.",nGold))
	end
	if nGold2 ~= 0 then
		JH.Talk(_L("Spending: %d Gold.",nGold))
	end
	JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "End", _L("Received: %d Gold.",nGold))
end
---------------------------------------------------------------------->
-- 获取工资总额
----------------------------------------------------------------------<
_GKP.GetRecordSum = function(bAccurate)
	if IsEmpty(GKP("GKP_Record")) then
		return 0,0
	end
	local a,b = 0,0
	for k,v in ipairs(GKP("GKP_Record")) do
		if not v.bDelete then
			if tonumber(v.nMoney) > 0 then
				a = a + v.nMoney
			else
				b = b + v.nMoney
			end
		end
	end
	if bAccurate then
		return a + b
	else
		return a,b
	end
end
---------------------------------------------------------------------->
-- 消费情况按钮
----------------------------------------------------------------------<
_GKP.GKP_SpendingList = function()
	local me = GetClientPlayer()
	if not me.IsInParty() and not JH.bDebug then return JH.Alert(_L["You are not in the team."]) end
	local tMember = {}
	if IsEmpty(GKP("GKP_Record")) then
		return JH.Alert(_L["No Record"])
	end
	if not GKP.IsDistributer() and not JH.bDebug then
		return JH.Alert(_L["You are not the distrubutor."])
	end
	_GKP.SetButton(false)
	for k,v in ipairs(GKP("GKP_Record")) do
		if not v.bDelete then
			if not tMember[v.szPlayer] then
				tMember[v.szPlayer] = 0
			end
			if tonumber(v.nMoney) > 0 then
				tMember[v.szPlayer] = tMember[v.szPlayer] + v.nMoney
			end
		end
	end
	JH.Talk(_L["--- Consumption ---"])
	JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Start", "--- Consumption ---")
	local sort = {}
	for k,v in pairs(tMember) do
		table.insert(sort,{ szName = k, nGold = v })
	end

	table.sort(sort,function(a,b) return a.nGold < b.nGold end)
	for k,v in ipairs(sort) do
		if v.nGold > 0 then
			JH.Talk({{type = "name" , name = v.szName , text = "" },{type = "text" , text = g_tStrings.STR_TALK_HEAD_SAY1 .. v.nGold .. _L["Gold."]}})
		end
		JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Info", v.szName, v.nGold)
	end
	JH.Talk(_L("Toal Auction: %d Gold.",_GKP.GetRecordSum()))
	JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "End", _L("Toal Auction: %d Gold.",_GKP.GetRecordSum()), _GKP.GetRecordSum())
end
---------------------------------------------------------------------->
-- 结算工资按钮
----------------------------------------------------------------------<
_GKP.GKP_Calculation = function()
	local me = GetClientPlayer()
	if not me.IsInParty() and not JH.bDebug then return JH.Alert(_L["You are not in the team."]) end
	local team = GetClientTeam()
	if IsEmpty(GKP("GKP_Record")) then
		return JH.Alert(_L["No Record"])
	end
	
	GetUserInput(_L["Total Amount of People with Output Settle Account"],function(num)
		if not tonumber(num) then return end
		local a,b = _GKP.GetRecordSum()
		JH.Talk(_L["Salary Settle Account"])
		JH.Talk(_L("Salary Statistic: income  %d Gold.",a))
		JH.Talk(_L("Salary Allowance: %d Gold.",b))
		JH.Talk(_L("Reall Salary: %d Gold.",a+b,a,b))
		if a+b >= 0 then
			JH.Talk(_L("Amount of People with Settle Account: %d",num))
			JH.Talk(_L("Actual per person: %d Gold.",math.floor((a+b)/num)))
		else
			JH.Talk(_L["The Account is Negative, no money is coming out!"])
		end
	end,nil,nil,nil,team.GetTeamSize())
end
---------------------------------------------------------------------->
-- open doodad (loot)
----------------------------------------------------------------------<
_GKP.OnOpenDoodad = function(dwID)
	local me = GetClientPlayer()
	local d = GetDoodad(dwID)
	local refresh = false
	if d then
		-- money 拾取金钱
		local nM = d.GetLootMoney() or 0
		if nM > 0 then
			LootMoney(d.dwID)
			PlaySound(SOUND.UI_SOUND, g_sound.PickupMoney)
		end
		local nLootItemCount = d.GetItemListCount()
		-- items
		for i = 0, nLootItemCount - 1 do
			-- item Roll Distribute  Bidding
			local item, _ , bDist = d.GetLootItem(i,me)
			if item and item.dwID then
				if bDist or JH.bDebug then
					if not refresh then
						refresh = true
						_GKP.aDistributeList = {}
					end
					table.insert(_GKP.aDistributeList,item)
				else
					if item.nQuality > 0 then
						LootItem(d.dwID,item.dwID)
						JH.Debug("LootItem")
					end
				end
			end
		end
	end
	if refresh then
		pcall(_GKP.DrawDistributeList,d)
		JH.Debug("distribute items " .. #_GKP.aDistributeList)
	else
		return _GKP.CloseLootWindow()
	end
end
-- JH.bDebug = true
---------------------------------------------------------------------->
-- UpdateDistributeList
----------------------------------------------------------------------<
_GKP.CheckDialog = function()
	if Station.Lookup("Normal/GKP_Loot") and Station.Lookup("Normal/GKP_Loot"):IsVisible() then
		if type(GetDoodad(_GKP.dwOpenID)) == "userdata" then
			JH.DelayCall(200,_GKP.CheckDialog)
		else
			_GKP.CloseLootWindow()
		end
	end
end

_GKP.DrawDistributeList = function(doodad)
	local frame = _GKP.OpenLootPanel()
	local me = GetClientPlayer()
	if #_GKP.aDistributeList == 0 or (not me.IsInParty() and not JH.bDebug) then
		return _GKP.CloseLootWindow()
	end
	frame:Show()
	Wnd.CloseWindow("LootList")
	pcall(_GKP.CheckDialog)
	-- append tip
	if not IsFileExist(JH.GetAddonInfo().szDataPath .. "config/lock.jx3dat") then
		JH.Alert(_L["GKP_TIPS"])
		JH.SaveLUAData("config/lock.jx3dat",{["Tips"] = true})
	end
	local handle = frame:Lookup("","Handle_Box")
	handle:Clear()
	if GKP.Config.bLootStyle then
		if #_GKP.aDistributeList <= 6 then
			frame:Lookup("","Image_Bg"):SetSize(6 * 72,110)
			frame:Lookup("","Image_Title"):SetSize(6 * 72,30)
			frame:SetSize(6 * 72,110)
		else
			frame:Lookup("","Image_Bg"):SetSize(6 * 72,30 + math.ceil(#_GKP.aDistributeList / 6) * 75)
			frame:Lookup("","Image_Title"):SetSize(6 * 72,30)
			frame:SetSize(6 * 72,8 + 30 + math.ceil(#_GKP.aDistributeList / 6) * 75)
		end
		
		local fx, fy = Station.GetClientSize()
		local w,h = frame:GetSize()
		-- frame:SetAbsPos((fx-w)/2,(fy-h)/2) -- 固定位置在中间 他们说不好就去掉了
		frame:Lookup("Btn_Close"):SetRelPos(w - 30,5)
		frame:Lookup("Btn_Boss"):SetRelPos(365,3)
		handle:SetHandleStyle(0)
		
	else
		frame:Lookup("","Image_Bg"):SetSize(280,#_GKP.aDistributeList*56+35)
		frame:Lookup("","Image_Title"):SetSize(280,30)
		frame:Lookup("Btn_Close"):SetRelPos(250,5)
		frame:SetSize(280,#_GKP.aDistributeList*56+35)
		handle:SetHandleStyle(3)
		frame:Lookup("Btn_Boss"):SetRelPos(210,3)
	end
	
	
	local team = GetClientTeam()
	local aPartyMember = doodad.GetLooterList()
	if JH.bDebug then
		aPartyMember = _GKP.aPartyMember
	end

	if not aPartyMember then
		_GKP.OnOpenDoodad(_GKP.dwOpenID)
		return GKP.Sysmsg(_L["Pick up time limit exceeded, please try again."])
	end
	if not JH.bDebug then
		for k,v in ipairs(aPartyMember) do
			local player = team.GetMemberInfo(v.dwID)
			aPartyMember[k].dwForceID = player.dwForceID
		end
	end
	
	
	for item_k,item in ipairs(_GKP.aDistributeList) do
		local szItemName = GetItemNameByItem(item)
		local fnSetBox = function(box)
			box:SetObject(UI_OBJECT_ITEM_ONLY_ID, item.nUiId, item.dwID, item.nVersion, item.dwTabType, item.dwIndex)
			box:SetObjectIcon(Table_GetItemIconID(item.nUiId))
			
			if item.bCanStack and item.nStackNum > 1 then
				box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
				box:SetOverTextFontScheme(0,15)
				box:SetOverText(0, item.nStackNum .. " ")
			end
			return box
		end
		local box	
		
		if GKP.Config.bLootStyle then
			handle:AppendItemFromString(string.format("<Box>name=\"box_%s\" EventID=816 w=64 h=64 </Box>",item_k))
			box = handle:Lookup("box_" .. item_k)
			box = fnSetBox(box)
			-- append box			
			local x,y = (item_k - 1) % 6 , math.ceil(item_k / 6) - 1
			box:SetRelPos(x * 70 + 5, y * 70 + 5)
			-- append img
			if _GKP.tQualityImage[item.nQuality] then
				if item.nQuality < 5 then
					handle:AppendItemFromString(GetFormatImage("ui/Image/Common/Box.UITex",_GKP.tQualityImage[item.nQuality],62,62,nil,"img_"..item_k))
				else
					handle:AppendItemFromString("<animate> path=\"ui/Image/Common/Box.UITex\" group=17 w=62 h=62 name=\"img_" ..item_k.."\" </animate>")
				end
				local img = handle:Lookup("img_" .. item_k)
				img:SetRelPos(x * 70 + 6 , y * 70 + 6)
			end
		else
			local h = handle:AppendItemFromIni(PATH_ROOT .. "ui/GKP_Loot.ini","Handle_Item",item_k)
			box = fnSetBox(h:Lookup("Box_Item"))
			local txt = h:Lookup("Text_Item")
			txt:SetText(szItemName)
			txt:SetFontColor(GetItemFontColorByQuality(item.nQuality))
			handle:FormatAllItemPos()
			box = h -- list
		end
		-- MouseEnter
		box.OnItemMouseEnter = function()
			local me = this
			if not GKP.Config.bLootStyle and me:GetType() == "Handle" then
				me:Lookup("Image_Copper"):Show()
				me = me:Lookup("Box_Item")
			end
			me:SetObjectMouseOver(true)
			local x, y = me:GetAbsPos()
			local w, h = me:GetSize()
			local _,dwID = me:GetObjectData()
			OutputItemTip(UI_OBJECT_ITEM_ONLY_ID, dwID, nil, nil, {x, y, w, h}, nil, "loot")
		end
		
		box.OnItemMouseLeave = function()
			local me = this
			if not GKP.Config.bLootStyle and me:GetType() == "Handle" then
				if me:Lookup("Image_Copper") then
					me:Lookup("Image_Copper"):Hide()
				end
				me = me:Lookup("Box_Item")
			end
			if me then
				me:SetObjectMouseOver(false)
			end
			HideTip()
		end
		if _GKP.tDistributeRecords[szItemName] then
			if GKP.Config.bLootStyle then
				box:SetObjectStaring(true)
			else
				box:Lookup("Box_Item"):SetObjectStaring(true)
			end
		end
		local _item = { -- 分配后 userdata缓存
			nVersion = item.nVersion,
			dwTabType = item.dwTabType,
			dwIndex = item.dwIndex,
			nBookID = item.nBookID,
			nGenre = item.nGenre,
		}
		-- Click
		box.OnItemRButtonClick = function()
			local me = GetClientPlayer()
			local nLootMode = team.nLootMode
			if nLootMode ~= PARTY_LOOT_MODE.DISTRIBUTE and not JH.bDebug then -- 需要分配者模式
				return OutputMessage("MSG_ANNOUNCE_RED", g_tStrings.GOLD_CHANGE_DISTRIBUTE_LOOT)
			end
			if not GKP.IsDistributer() and not JH.bDebug then -- 需要自己是分配者
				return OutputMessage("MSG_ANNOUNCE_RED",g_tStrings.ERROR_LOOT_DISTRIBUTE)
			end
			local tMenu = {}
			table.insert(tMenu,{ szOption = GetItemNameByItem(item) , bDisable = true})
			table.insert(tMenu,{bDevide = true})
			table.insert(tMenu,{ 
				szOption = "Roll",
				fnAction = function()
					if MY_RollMonitor then
						if MY_RollMonitor.OpenPanel and MY_RollMonitor.Clear then
							MY_RollMonitor.OpenPanel()
							MY_RollMonitor.Clear({echo=false})
						end
					end
					JH.Talk({GKP.GetFormatLink(_item),{type = "text" ,text =_L["Roll the dice if you wang"]}})
				end
			})
			table.insert(tMenu,{bDevide = true})
			for k,v in ipairs(_GKP.Config.Scheme) do
				if v[2] then
					table.insert(tMenu,{
						szOption = v[1],
						fnAction = function()
							_GKP.SetChatWindow(item,box)
							_GKP.tLootListMoney[item.dwID] = v[1]
							JH.Talk({GKP.GetFormatLink(_item),{type = "text" ,text = _L(" %d Gold Start Bidding, off a price if you want.",v[1] )}})
						end
					})
				end
				PopupMenu(tMenu)
			end
		end
		
		box.OnItemLButtonClick = function()
			if IsCtrlKeyDown() or IsAltKeyDown() then
				return GKP.OnItemLinkDown(item,this)
			end
			local me = GetClientPlayer()
			local nLootMode = team.nLootMode
			if nLootMode ~= PARTY_LOOT_MODE.DISTRIBUTE and not JH.bDebug then -- 需要分配者模式
				return OutputMessage("MSG_ANNOUNCE_RED", g_tStrings.GOLD_CHANGE_DISTRIBUTE_LOOT)
			end
			if not GKP.IsDistributer() and not JH.bDebug then -- 需要自己是分配者
				return OutputMessage("MSG_ANNOUNCE_RED",g_tStrings.ERROR_LOOT_DISTRIBUTE)
			end
			table.sort(aPartyMember,function(a,b)
				return a.dwForceID < b.dwForceID
			end)
			local tMenu = {}
			table.insert(tMenu,{ szOption = szItemName , bDisable = true})
			table.insert(tMenu,{bDevide = true})
			local fnAction = function(v,fnMouseEnter,fix,bEnter)
				local szIcon,nFrame = GetForceImage(v.dwForceID)
				return {
					szOption = fix or v.szName,
					bDisable = not v.bOnlineFlag,
					rgb = {JH.GetForceColor(v.dwForceID)},
					szIcon = szIcon,
					szLayer = "ICON_RIGHT",
					nFrame = nFrame,
					fnMouseEnter = fnMouseEnter,
					fnAction = function()
						if not item.dwID then
							_GKP.OnOpenDoodad(_GKP.dwOpenID)
							return GKP.Sysmsg(_L["Userdata is overdue, distribut failed, please try again."])
						end
						if item.nQuality >= 3 then
							local r,g,b = JH.GetForceColor(v.dwForceID)
							local msg = {
								szMessage = FormatLinkString(
									g_tStrings.PARTY_DISTRIBUTE_ITEM_SURE,
									"font=162",
									GetFormatText("[".. GetItemNameByItem(item) .."]", "166"..GetItemFontColorByQuality(item.nQuality, true)),
									GetFormatText("[".. v.szName .."]", 162,r,g,b)
								), 
								szName = "Distribute_Item_Sure", 
								bRichText = true,
								{
									szOption = g_tStrings.STR_HOTKEY_SURE, 
									fnAutoClose = function()
										return false
									end,
									fnAction = function()
										if IsShiftKeyDown() then
											_GKP.DistributeItem(item,v,doodad,true)
										else
											_GKP.DistributeItem(item,v,doodad,bEnter)
										end
									end
								},
								{szOption = g_tStrings.STR_HOTKEY_CANCEL},
							}
							MessageBox(msg)	
						else
							if IsShiftKeyDown() then
								_GKP.DistributeItem(item,v,doodad,true)
							else
								_GKP.DistributeItem(item,v,doodad,bEnter)
							end
						end
					end
				}
			end
			-- 有记忆的情况下 append meun
			if _GKP.tDistributeRecords[szItemName] then
				local p
				for k,v in ipairs(aPartyMember) do
					if v.dwID == _GKP.tDistributeRecords[szItemName] then
						p = v
						break
					end
				end
				if p then  -- 这个人存在团队的情况下
					if IsShiftKeyDown() then
						if p.bOnlineFlag then
							_GKP.DistributeItem(item,p,doodad,true)
						else
							GKP.Sysmsg(_L["No Pick up Object, may due to Network off - line"])
						end
						return
					end
					table.insert(tMenu,fnAction(p,function(this)
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						local szXml = GetFormatText(_L("You already distrubute [%s] with [%s], you can press Shift and select the object to make a fast distrubution, you can also make distribution to he or her by clicking this menu. \n",szItemName,p.szName,p.szName),136,255,255,255)
						OutputTip(szXml,400,{x,y,w,h})
					end,p.szName .. " - " .. szItemName,true))
					table.insert(tMenu,{bDevide = true})
				end
			end
			-- Create list
			for k,v in ipairs(aPartyMember) do
				table.insert(tMenu,fnAction(v))
			end
			PopupMenu(tMenu)
		end
	end
	handle:FormatAllItemPos()
	
	if _GKP.tDistributeRecords["EquipmentBoss"] then
		frame:Lookup("Btn_Boss"):Show()
		frame:Lookup("Btn_Boss").OnLButtonClick = function()
			local tEquipment = {}
			for k,v in ipairs(_GKP.aDistributeList) do
				if v.nGenre == ITEM_GENRE.EQUIPMENT or IsCtrlKeyDown() then -- 按住Ctrl的情况下 无视分类 否则只给装备	
					table.insert(tEquipment,v)
				end
			end
			if #tEquipment == 0 then
				return JH.Alert(_L["No Equiptment left for Equiptment Boss"])
			end
			local p
			for k,v in ipairs(aPartyMember) do
				if v.szName == _GKP.tDistributeRecords["EquipmentBoss"] then
					p = v
					break
				end
			end
			if p and p.bOnlineFlag then  -- 这个人存在团队的情况下
				local szXml = GetFormatText(_L["Are you sure you want the following item\n"], 162,255,255,255)
				local r,g,b = JH.GetForceColor(p.dwForceID)
				for k,v in ipairs(tEquipment) do
					szXml = szXml .. GetFormatText("[".. GetItemNameByItem(v) .."]\n", "166"..GetItemFontColorByQuality(v.nQuality, true))
				end
				szXml = szXml .. GetFormatText(_L["All distrubute to"], 162,255,255,255)
				szXml = szXml .. GetFormatText("[".. p.szName .."]", 162,r,g,b)
				local msg = {
					szMessage = szXml, 
					szName = "Distribute_Item_Sure", 
					bRichText = true,
					{szOption = g_tStrings.STR_HOTKEY_SURE, 
					fnAutoClose = function()
						return false
					end,
					fnAction = function()
						for k,v in ipairs(tEquipment) do
							_GKP.DistributeItem(v,p,doodad,true)
						end
					end},
					{szOption = g_tStrings.STR_HOTKEY_CANCEL},
				}
				MessageBox(msg)	
			else
				return JH.Alert(_L["No Pick up Object, may due to Network off - line"])
			end
		end
	else
		frame:Lookup("Btn_Boss"):Hide()
	end
end
---------------------------------------------------------------------->
-- 弹出记账页面后分配
----------------------------------------------------------------------<
_GKP.DistributeItem = function(item,player,doodad,bEnter)
	if not item.dwID then
		_GKP.OnOpenDoodad(_GKP.dwOpenID)
		return GKP.Sysmsg(_L["Userdata is overdue, distribut failed, please try again."])
	end
	_GKP.CloseChatWindow(item)
	local szName = GetItemNameByItem(item)
	if _GKP.Config.Special[szName] or JH.bDebug then -- 记住上次分给谁
		_GKP.tDistributeRecords[szName] = player.dwID
		JH.Debug("memory " .. szName .. " -> " .. player.dwID)
	end
	doodad.DistributeItem(item.dwID,player.dwID)
	_GKP.OnOpenDoodad(_GKP.dwOpenID)
	local tab = {
		szPlayer = player.szName,
		nUiId = item.nUiId,		
		szNpcName = doodad.szName,
		dwDoodadID = doodad.dwID,
		dwTabType = item.dwTabType,
		dwIndex = item.dwIndex,
		nVersion = item.nVersion,
		nTime = GetCurrentTime(),
		nQuality = item.nQuality,
		dwForceID = player.dwForceID,
		szName = szName,
		nGenre = item.nGenre,
	}
	if item.bCanStack and item.nStackNum > 1 then
		tab.nStackNum = item.nStackNum
	end
	if item.nGenre == ITEM_GENRE.BOOK then
		tab["szName"] = GetItemNameByItem(item)
		tab["nBookID"] = item.nBookID
	end
	
	if GKP.Config.bOn then
		_GKP.Record(tab,item,bEnter)
	else -- 关闭的情况所有东西全部绕过
		tab.nMoney = 0
		pcall(GKP,"GKP_Record",tab)
		pcall(_GKP.Draw_GKP_Record)
	end
end
---------------------------------------------------------------------->
-- 记账页面
----------------------------------------------------------------------<
_GKP.Record = function(tab,item,bEnter)
	local record = GUI(Station.Lookup("Normal1/GKP_Record"))
	local box = record:Fetch("Box"):Pos(170,80).self
	local text = record:Fetch("TeamList")
	local Money = record:Fetch("Money")
	local Name = record:Fetch("Name")
	local Source = record:Fetch("Source")
	local auto = 0
	record:Fetch("WndCheckBox"):Check(false)
	if record:IsVisible() and record:Fetch("btn_Close").self.userdata then -- 上次是userdata并且没关闭
		if text:Text() ~= g_tStrings.PLAYER_NOT_EMPTY and Name:Text() ~= "" then 
			Money:Text(0)
			record:Fetch("btn_ok"):Click()
		end
	end
	
	if record:Fetch("btn_Close").self.userdata then
		record:Fetch("btn_Close").self.userdata = nil
	end
	if tab and type(item) == "userdata" then
		text:Text(tab.szPlayer):Color(JH.GetForceColor(tab.dwForceID))
		Name:Text(tab.szName):Enable(false)
		Source:Text(tab.szNpcName):Enable(false)
		if _GKP.tLootListMoney[item.dwID] and GKP.Config.bAutoSetMoney then
			auto = _GKP.tLootListMoney[item.dwID] -- 自动设置发布时的金钱
		elseif GKP.Config.bAutoBX and tab.szName == _L["BiXi Fragment"] and tab.nStackNum and tab.nStackNum >= 1 then
			auto = tab.nStackNum
		else
			Money:Text("")
		end
		record:Fetch("btn_Close").self.userdata = true
	else
		text:Text(g_tStrings.PLAYER_NOT_EMPTY):Color(255,255,255)
		text.self.dwForceID = nil
		Source:Text(_L["Add Manually"]):Enable(false)
		Name:Text(""):Enable(true)
		Money:Text("")
	end	
	if tab and type(item) == "number" then -- 编辑
		text:Text(tab.szPlayer):Color(JH.GetForceColor(tab.dwForceID))
		text.self.dwForceID = tab.dwForceID
		Name:Text(tab.szName or Table_GetItemName(tab.nUiId)):Enable(true)
		Source:Text(tab.szNpcName):Enable(true)
		Money:Text(tab.nMoney)
	end
	
	if tab and tab.nVersion and tab.nUiId and tab.dwTabType and tab.dwIndex then
		-- Box
		box:SetObject(UI_OBJECT_ITEM_INFO, tab.nVersion, tab.dwTabType, tab.dwIndex)
		box:SetObjectIcon(Table_GetItemIconID(tab.nUiId))
		box:SetOverTextPosition(0,ITEM_POSITION.RIGHT_BOTTOM)
		box:SetOverTextFontScheme(0,15)
		if tab.nStackNum and tab.nStackNum > 1 then
			box:SetOverText(0,tab.nStackNum .. " ")
		else
			box:SetOverText(0,"")
		end
		box.OnItemLButtonClick = function()
			if IsCtrlKeyDown() or IsAltKeyDown() then
				return GKP.OnItemLinkDown(tab,this)
			end
		end
		-- MouseEnter
		box.OnItemMouseEnter = function()
			this:SetObjectMouseOver(true)
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			local _,dwID = this:GetObjectData()
			if tab.nBookID then
				local dwBookID, dwSubID = GlobelRecipeID2BookID(tab.nBookID)
				OutputBookTipByID(dwBookID, dwSubID,{x, y, w, h})
			else
				local _,dwTabType,dwIndex = this:GetObjectData()
				if dwTabType == 0 and dwIndex == 0 then return end
				OutputItemTip(UI_OBJECT_ITEM_INFO,GLOBAL.CURRENT_ITEM_VERSION,dwTabType,dwIndex,{x, y, w, h})
			end
		end
		
		box.OnItemMouseLeave = function()
			this:SetObjectMouseOver(false)
			HideTip()
		end
		box:Show()
	else
		box:SetObject(UI_OBJECT_ITEM_ONLY_ID)
		box:SetObjectIcon(95)
	end	
	record:Toggle(true)
	if auto == 0 and type(item) ~= "number" and tab then -- edit/add killfocus
		Money:Focus()
	elseif auto > 0 and tab then
		Money:Text(auto) -- OnEditChanged kill
		record:Focus()
	elseif not tab then
		Name:Focus()
	end

	record:Fetch("btn_ok"):Click(function()
		local tab = tab or {
			nUiId = 0,
			dwTabType = 0,
			dwDoodadID = 0,
			nQuality = 1,
			nVersion = 0,
			dwIndex = 0,
			nTime = GetCurrentTime(),
			dwForceID = text.self.dwForceID or 0,
			szName = Name:Text(),
		}	
		local nMoney = tonumber(Money:Text()) or 0
		local szPlayer = text:Text()
		if Name:Text() == "" then
			return JH.Alert(_L["Please entry the name of the item"])
		end
		if szPlayer == g_tStrings.PLAYER_NOT_EMPTY then
			return JH.Alert(_L["Select a member who is in charge of account and put money in his account."])
		end

		tab.szNpcName = Source:Text()
		tab.nMoney = nMoney
		tab.szPlayer = szPlayer
		tab.key = tab.key or GKP.Random()
		if tab and type(item) == "userdata" then
			if GKP.IsDistributer() then
				JH.Talk({
					GKP.GetFormatLink(tab),
					{type = "text" ,text = " ".. nMoney .._L["Gold"]},
					{type = "text" ,text = _L[" Distribute to "]},
					{type = "name" ,name = tab.szPlayer,text = "[" .. tab.szPlayer .. "]"},
				})
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP","add",JH.AscIIEncode(JH.JsonEncode(tab)))
			end
			if _GKP.tLootListMoney[item.dwID] then
				_GKP.tLootListMoney[item.dwID] = nil
			end
		elseif tab and type(item) == "number" then
			tab.szName = Name:Text()
			tab.dwForceID = text.self.dwForceID or tab.dwForceID or 0
			tab.bEdit = true
			if GKP.IsDistributer() then
				JH.Talk({
					{type = "name" ,name = tab.szPlayer,text = "[" .. tab.szPlayer .. "]"},
					{type = "text" ,text = " " .. tab.szName},
					{type = "text" ,text = " " .. nMoney .._L["Gold"]},
					{type = "text" ,text = _L["Make changes to the record."]},
				})
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP","edit",JH.AscIIEncode(JH.JsonEncode(tab)))
			end
		else
			if GKP.IsDistributer() then
				JH.Talk({
					{type = "text" ,text = tab.szName},
					{type = "text" ,text = " ".. nMoney .._L["Gold"]},
					{type = "text" ,text = _L["Manually make record to"]},
					{type = "name" ,name = tab.szPlayer,text = "[" .. tab.szPlayer .. "]"},
				})
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP","add",JH.AscIIEncode(JH.JsonEncode(tab)))
			end
		end
		if record:Fetch("WndCheckBox"):Check() then
			_GKP.tDistributeRecords["EquipmentBoss"] = tab.szPlayer -- 233333 不管了 这个挺好玩的
			_GKP.OnOpenDoodad(_GKP.dwOpenID)
		end
		if tab and type(item) == "number" then
			pcall(GKP,"GKP_Record",item,tab)
		else
			pcall(GKP,"GKP_Record",tab)
		end
		
		pcall(_GKP.Draw_GKP_Record)
		record:Toggle(false)
		FireEvent("GKP_DEL_DISTRIBUTE_ITEM")
	end)
	if bEnter then
		record:Fetch("btn_ok"):Click()
	end
	
end
---------------------------------------------------------------------->
-- OpenDoodad
----------------------------------------------------------------------<
_GKP.OpenDoodad = function(arg0)
	local team = GetClientTeam()
	local me = GetClientPlayer()
	if me and team then
		local nLootMode = team.nLootMode	
		if nLootMode == PARTY_LOOT_MODE.DISTRIBUTE or JH.bDebug then -- 需要分配者模式
			_GKP.dwOpenID = arg0
			_GKP.OnOpenDoodad(arg0)
		end
	end
end
---------------------------------------------------------------------->
-- OpenDoodad cache
----------------------------------------------------------------------<
_GKP._OpenDoodad = function(arg0)
	local team = GetClientTeam()
	local me = GetClientPlayer()
	local refresh = false
	if me and team then
		local d = GetDoodad(arg0)
		if d then
			local nLootItemCount = d.GetItemListCount()
			-- items
			_GKP.aDoodadCache[arg0] = {}
			_GKP.aDoodadCache[arg0].szName = d.szName
			for i = 0, nLootItemCount - 1 do
				-- item Roll Distribute  Bidding
				local item, _ , bDist = d.GetLootItem(i,me)
				if item and bDist then -- 只操作需要分配的物品
					refresh = true					
					if item.dwID then
						local tab = {
							item = item,
							nUiId = item.nUiId,
							dwTabType = item.dwTabType,
							dwIndex = item.dwIndex,
							nVersion = item.nVersion,
							nQuality = item.nQuality,
							nGenre = item.nGenre,
							szName = GetItemNameByItem(item),
						}
						if item.bCanStack and item.nStackNum > 1 then
							tab.nStackNum = item.nStackNum
						end
						if item.nGenre == ITEM_GENRE.BOOK then
							tab.nBookID = item.nBookID
						end
						_GKP.aDoodadCache[arg0][item.dwID] = tab
					else
						JH.Debug("not item dwID")
					end
				end
			end
		end
	end
	if not refresh then
		_GKP.aDoodadCache[arg0] = nil
	end
end
---------------------------------------------------------------------->
-- DISTRIBUTE_ITEM
----------------------------------------------------------------------<
RegisterEvent("DISTRIBUTE_ITEM",function() -- DISTRIBUTE_ITEM
	if GKP.IsDistributer() then
		return
	end
	local team = GetClientTeam()
	local me = GetClientPlayer()
	local player = team.GetMemberInfo(arg0)
	for k,v in pairs(_GKP.aDoodadCache) do
		if v[arg1] then
			local item = v[arg1]
			item.szPlayer = player.szName
			item.szNpcName = v.szName
			item.dwDoodadID = k
			item.nTime = GetCurrentTime()
			item.dwForceID = player.dwForceID
			if GKP.Config.bOn2 then
				local tab = clone(item)
				tab.item = nil
				table.insert(_GKP.tDistribute,{tab = tab , item = item.item})
				if me.bFightState then
					GKP.Sysmsg(_L["A distribute record has produced, it has been ignored in the combat, it will automatically popup after breaking away from the combat."])
				else
					FireEvent("GKP_DISTRIBUTE_ITEM")
				end
			end
			break
		end
	end
	JH.Debug("DISTRIBUTE_ITEM")
end)

RegisterEvent("FIGHT_HINT", function()
	local me = GetClientPlayer()
	if GKP.Config.bOn and #_GKP.tDistribute > 0 and not me.bFightState then
		FireEvent("GKP_DISTRIBUTE_ITEM")
	end
end)

RegisterEvent("GKP_DEL_DISTRIBUTE_ITEM", function()
	if #_GKP.tDistribute > 0 then
		table.remove(_GKP.tDistribute,1)
		if #_GKP.tDistribute > 0 then
			FireEvent("GKP_DISTRIBUTE_ITEM")
		end
	end
	if IsPopupMenuOpened() then
		Wnd.CloseWindow("PopupMenuPanel")
	end
	JH.Debug("GKP_DEL_DISTRIBUTE_ITEM")
end)

RegisterEvent("GKP_DISTRIBUTE_ITEM", function()
	if _GKP.tDistribute[1] and not Station.Lookup("Normal1/GKP_Record"):IsVisible() then
		local tab = _GKP.tDistribute[1]
		_GKP.Record(tab.tab,tab.item)
	end
	JH.Debug("GKP_DISTRIBUTE_ITEM")
end)

RegisterEvent("SYNC_LOOT_LIST", function()
	if _GKP.dwOpenID == arg0 and Station.Lookup("Normal/GKP_Loot") and Station.Lookup("Normal/GKP_Loot"):IsVisible() then
		_GKP.OpenDoodad(arg0)
	end	
	if JH.IsInDungeon() and JH_About.CheckNameEx() and GKP.Config.bDebug2 and not _GKP.aDoodadCache[arg0] and not Station.Lookup("Normal/GKP_Loot") then
		_GKP.OpenDoodad(arg0)
	end
	_GKP._OpenDoodad(arg0)
	JH.Debug("SYNC_LOOT_LIST " .. arg0)
end)

RegisterEvent("OPEN_DOODAD", function()
	local team = GetClientTeam()
	local me = GetClientPlayer()
	local nLootMode = team.nLootMode	
	if nLootMode == PARTY_LOOT_MODE.DISTRIBUTE or JH.bDebug then
		_GKP.OpenDoodad(arg0)
		JH.Debug("OPEN_DOODAD " .. arg0)
	end	
end)

---------------------------------------------------------------------->
-- 金钱记录
----------------------------------------------------------------------<
_GKP.TradingTarget = {}

_GKP.MoneyUpdate = function(nGold, nSilver, nCopper)
	if nGold > -20 and nGold < 20  then
		return
	end
	if not _GKP.TradingTarget.szName and not GKP.Config.bMoneySystem then
		return
	end
	pcall(GKP,"GKP_Account",{
		nGold = nGold, -- API给的有问题 …… 只算金
		szPlayer = _GKP.TradingTarget.szName or "System",
		dwForceID = _GKP.TradingTarget.dwForceID,
		nTime = GetCurrentTime(),
		dwMapID = GetClientPlayer().GetMapID()
	})
	pcall(_GKP.Draw_GKP_Account)
	if _GKP.TradingTarget.szName and GKP.Config.bMoneyTalk then
		if nGold > 0 then
			JH.Talk({
				{type = "text" ,text = _L["Received"]},
				{type = "name" ,name = _GKP.TradingTarget.szName,text = "[" .. _GKP.TradingTarget.szName .. "]"},
				{type = "text" ,text = _L["The"] .. nGold .._L["Gold."]},
			})
		else
			JH.Talk({
				{type = "text" ,text = _L["Pay to"]},
				{type = "name" ,name = _GKP.TradingTarget.szName,text = "[" .. _GKP.TradingTarget.szName .. "]"},
				{type = "text" ,text = " " .. nGold * -1 .._L["Gold."]},
			})
		end
	end
end

_GKP.Draw_GKP_Account = function(key,sort)
	local key = key or _GKP.GKP_Account_Container.key or "szPlayer"
	local sort = sort or _GKP.GKP_Account_Container.sort or "desc"
	local tab = GKP("GKP_Account",key,sort)
	_GKP.GKP_Account_Container.key = key
	_GKP.GKP_Account_Container.sort = sort
	_GKP.GKP_Account_Container:Clear()
	local a,b = 0,0
	local tMoney = GetClientPlayer().GetMoney()
	for k,v in ipairs(tab) do
		local c = _GKP.GKP_Account_Container:AppendContentFromIni(PATH_ROOT .. "ui/GKP_Account_Item.ini","WndWindow",i)
		local item = c:Lookup("","")
		if k % 2 == 0 then
			item:Lookup("Image_Line"):Hide()			
		end
		if v.bDelete then
			c:SetAlpha(80)
		end
		c:Lookup("","Handle_Money"):AppendItemFromString(GetGoldText(v.nGold,3))
		if v.nGold  < 0 then
			c:Lookup("","Handle_Money"):Lookup(0):SetFontColor(255,0,0)
		else
			c:Lookup("","Handle_Money"):Lookup(0):SetFontColor(0,255,0)
		end		
		c:Lookup("","Handle_Money"):FormatAllItemPos()		
		item:Lookup("Text_No"):SetText(k)
		if v.szPlayer and v.szPlayer ~= "System" then
			item:Lookup("Image_NameIcon"):FromUITex(GetForceImage(v.dwForceID))
			item:Lookup("Text_Name"):SetText(v.szPlayer)
			item:Lookup("Text_Change"):SetText(_L["Player's transation"])
			item:Lookup("Text_Name"):SetFontColor(JH.GetForceColor(v.dwForceID))
		else
			item:Lookup("Image_NameIcon"):FromUITex("ui/Image/uicommon/commonpanel4.UITex",3)
			item:Lookup("Text_Name"):SetText(_L["System"])
			item:Lookup("Text_Change"):SetText(_L["Reward & other ways"])
		end
		item:Lookup("Text_Map"):SetText(Table_GetMapName(v.dwMapID))
		item:Lookup("Text_Time"):SetText(GKP.GetTimeString(v.nTime))		
		c:Lookup("WndButton_Delete").OnLButtonClick = function()
			GKP("GKP_Account","del",k)
			pcall(_GKP.Draw_GKP_Account)
		end
		
		-- tip
		item:Lookup("Text_Name"):RegisterEvent(786)
		item:Lookup("Text_Name").OnItemLButtonClick = function()
			if IsCtrlKeyDown() then
				return GKP.InsertEditByName(v.szPlayer)
			end
		end
		
		item:Lookup("Text_Name").OnItemMouseEnter = function()
			local szIcon,nFrame = GetForceImage(v.dwForceID)
			local r,g,b = JH.GetForceColor(v.dwForceID)
			local szXml = GetFormatImage(szIcon,nFrame,20,20) .. GetFormatText("  " .. v.szPlayer .. _L[":\n"],136,r,g,b)
			szXml = szXml .. GetFormatText(_L["System Information as Shown Below\n\n"],136,255,255,255)
			local nNum,nNum1,nNum2 = 0,0,0
			for kk,vv in ipairs(GKP("GKP_Record")) do
				if vv.szPlayer == v.szPlayer and not vv.bDelete then
					if  vv.nMoney > 0 then
						nNum = nNum + vv.nMoney
					else
						nNum1 = nNum1 + vv.nMoney
					end
				end
			end
			local r,g,b = GKP.GetMoneyCol(nNum)
			szXml = szXml .. GetFormatText(_L["Total Cosumption:"],136,255,128,0) .. GetFormatText(nNum .._L["Gold.\n"],136,r,g,b)
			local r,g,b = GKP.GetMoneyCol(nNum1)
			szXml = szXml .. GetFormatText(_L["Total Allowance:"],136,255,128,0) .. GetFormatText(nNum1 .._L["Gold.\n"],136,r,g,b)
			
			for kk,vv in ipairs(GKP("GKP_Account")) do
				if vv.szPlayer == v.szPlayer and not vv.bDelete and vv.nGold > 0 then
					nNum2 = nNum2 + vv.nGold
				end
			end
			local r,g,b = GKP.GetMoneyCol(nNum2)
			szXml = szXml .. GetFormatText(_L["Total Payment:"],136,255,128,0) .. GetFormatText(nNum2 .._L["Gold.\n"],136,r,g,b)
			local nNum3 = nNum+nNum1-nNum2
			if nNum3 < 0 then
				nNum3 = 0
			end
			local r,g,b = GKP.GetMoneyCol(nNum3)
			szXml = szXml .. GetFormatText(_L["Money on Debt:"],136,255,128,0) .. GetFormatText(nNum3 .._L["Gold.\n"],136,r,g,b)
			
			local x, y = item:Lookup("Text_No"):GetAbsPos()
			local w, h = item:Lookup("Text_No"):GetSize()
			OutputTip(szXml,400,{x,y,w,h})
		end
		item:Lookup("Text_Name").OnItemMouseLeave = function()
			HideTip()
		end
		if not v.bDelete then
			if tonumber(v.nGold) > 0 then
				a = a + v.nGold
			else
				b = b + v.nGold
			end
		end
	end
	_GKP.GKP_Account_Container:FormatAllContentPos()
	local txt = Station.Lookup("Normal/GKP/PageSet_Menu/Page_GKP_Account"):Lookup("","Text_GKP_AccountSettlement")
	local text = _L("Statistic: Overall Income = %d Gold (Income: %d Gold + Output: %d Gold)",a+b,a,b)
	if _GKP.nNowMoney then
		text = _L("%s log in with %d Gold in possession",text,_GKP.nNowMoney)
	end
	txt:SetText(text)
	txt:SetFontColor(255,255,0)
end

RegisterEvent("TRADING_OPEN_NOTIFY",function() -- 交易开始
	_GKP.TradingTarget = GetPlayer(arg0)
end)
RegisterEvent("TRADING_CLOSE",function() -- 交易结束
	_GKP.TradingTarget = {}
end)
RegisterEvent("MONEY_UPDATE",function() --金钱变动
	_GKP.MoneyUpdate(arg0,arg1,arg2)
end)

JH.PlayerAddonMenu({szOption = _L["GKP Golden Team Record"],rgb = {255,255,128} , fnAction = _GKP.OpenPanel})
JH.AddHotKey("JH_GKP",_L["Open/Close Golden Team Record"],_GKP.TogglePanel)


RegisterEvent("LOADING_END",function()
	if JH.IsInDungeon() and GKP.Config.bAlertMessage then
		if not IsEmpty(GKP("GKP_Record")) or not IsEmpty(GKP("GKP_Account")) then
			JH.Confirm(_L["Do you want to wipe the previous data when you enter the dungeon's map?"],function() _GKP.GKP_Clear(true) end)
		end
	end
end)

----------------------------------------------------------
-- 重伤提示
----------------------------------------------------------

local DeathWarn = {
	tDamage = {},
	tDeath = {}
}

DeathWarn.GetName = function(tar)
	local szName = tar.szName
	if not IsPlayer(tar.dwID) then
		if szName == "" then
			szName = Table_GetNpcTemplateName(tar.dwTemplateID)
		end
		if tar.dwEmployer and tar.dwEmployer ~= 0 and szName == Table_GetNpcTemplateName(tar.dwTemplateID) then
			local emp = GetPlayer(tar.dwEmployer)
			if not emp then
				szName =  g_tStrings.STR_SOME_BODY .. g_tStrings.STR_PET_SKILL_LOG .. tar.szName
			else
				szName = emp.szName .. g_tStrings.STR_PET_SKILL_LOG .. tar.szName
			end
		end
	end
	return szName
end

DeathWarn.OnSkillEffectLog = function(dwCaster, dwTarget, bReact, nEffectType, dwID, dwLevel, bCriticalStrike, nCount, tResult)
	local Caster,target,szSkillName
	if nCount <= 2 then
		return
	end
	if IsPlayer(dwCaster) then
		Caster = GetPlayer(dwCaster)
	else
		Caster = GetNpc(dwCaster)
	end
	if not Caster then
		return
	end
	if IsPlayer(dwTarget) then
		target = GetPlayer(dwTarget)
	else
		target = GetNpc(dwTarget)
	end
	if not target then
		return
	end
	if nEffectType == SKILL_EFFECT_TYPE.SKILL then
		szSkillName = Table_GetSkillName(dwID, dwLevel);
	elseif nEffectType == SKILL_EFFECT_TYPE.BUFF then
		szSkillName = Table_GetBuffName(dwID, dwLevel);
	end
	if not szSkillName then
		return
	end
	local me = GetClientPlayer()
	local team = GetClientTeam()
	if IsPlayer(dwTarget) then
		if team.IsPlayerInTeam(dwTarget) or dwTarget == me.dwID then
			if not DeathWarn.tDamage[dwTarget] then
				DeathWarn.tDamage[dwTarget] = {}
			end
			local szDamage = ""
			local nValue = tResult[SKILL_RESULT_TYPE.PHYSICS_DAMAGE]
			if nValue and nValue > 0 then
				if szDamage ~= "" then
					szDamage = szDamage..g_tStrings.STR_COMMA
				end	
				szDamage = szDamage..FormatString(g_tStrings.SKILL_DAMAGE, nValue, g_tStrings.STR_SKILL_PHYSICS_DAMAGE)
			end
			local nValue = tResult[SKILL_RESULT_TYPE.SOLAR_MAGIC_DAMAGE]
			if nValue and nValue > 0 then
				if szDamage ~= "" then
					szDamage = szDamage..g_tStrings.STR_COMMA
				end
				szDamage = szDamage..FormatString(g_tStrings.SKILL_DAMAGE, nValue, g_tStrings.STR_SKILL_SOLAR_MAGIC_DAMAGE)
			end
			local nValue = tResult[SKILL_RESULT_TYPE.NEUTRAL_MAGIC_DAMAGE]
			if nValue and nValue > 0 then
				if szDamage ~= "" then
					szDamage = szDamage..g_tStrings.STR_COMMA
				end
				szDamage = szDamage..FormatString(g_tStrings.SKILL_DAMAGE, nValue, g_tStrings.STR_SKILL_NEUTRAL_MAGIC_DAMAGE)
			end
			local nValue = tResult[SKILL_RESULT_TYPE.LUNAR_MAGIC_DAMAGE]
			if nValue and nValue > 0 then
				if szDamage ~= "" then
					szDamage = szDamage..g_tStrings.STR_COMMA
				end
				szDamage = szDamage..FormatString(g_tStrings.SKILL_DAMAGE, nValue, g_tStrings.STR_SKILL_LUNAR_MAGIC_DAMAGE)
			end
			local nValue = tResult[SKILL_RESULT_TYPE.POISON_DAMAGE]
			if nValue and nValue > 0 then
				if szDamage ~= "" then
					szDamage = szDamage..g_tStrings.STR_COMMA
				end
				szDamage = szDamage..FormatString(g_tStrings.SKILL_DAMAGE, nValue, g_tStrings.STR_SKILL_POISON_DAMAGE)
			end
			if szDamage ~= "" then
				table.insert(DeathWarn.tDamage[dwTarget],{
					szCaster = DeathWarn.GetName(Caster),
					szTarget = DeathWarn.GetName(target),
					szSkillName = szSkillName,
					szValue = szDamage,
				})
			end
		end
	end
	if IsPlayer(dwCaster) and (team.IsPlayerInTeam(dwCaster) or dwCaster == me.dwID) then
		if not DeathWarn.tDamage[dwCaster] then
			DeathWarn.tDamage[dwCaster] = {}
		end
		local szDamage = ""
		local nValue = tResult[SKILL_RESULT_TYPE.REFLECTIED_DAMAGE]
		if nValue and nValue > 0 then
			if szDamage ~= "" then
				szDamage = szDamage..g_tStrings.STR_COMMA
			end
			szDamage = szDamage..nValue.._L["Points harm"]
		end
		if szDamage ~= "" then
			table.insert(DeathWarn.tDamage[dwCaster],{
				szCaster = DeathWarn.GetName(target),
				szTarget = DeathWarn.GetName(Caster),
				szSkillName = _L["Bounce"] .. "("..szSkillName..")",
				szValue = szDamage,
			})
		end
	end
end

DeathWarn.OnCommonHealthLog = function(dwTarget, nDeltaLife)
	local target
	if IsPlayer(dwTarget) then
		target = GetPlayer(dwTarget)
	else
		target = GetNpc(dwTarget)
	end
	if not target then return end
	if nDeltaLife < 0 then
		nDeltaLife = -nDeltaLife
	end
	local me = GetClientPlayer()
	local team = GetClientTeam() 
	if IsPlayer(dwTarget) then
		if team.IsPlayerInTeam(dwTarget) or dwTarget == me.dwID then
			if not DeathWarn.tDamage[dwTarget] then
				DeathWarn.tDamage[dwTarget] = {}
			end
			table.insert(DeathWarn.tDamage[dwTarget],{
				szCaster = _L["Unknown"],
				szTarget = DeathWarn.GetName(target),
				szSkillName = _L["Unknown Skill"],
				szValue = nDeltaLife .. _L["Points harm"],
			})
		end
	end
end

--[[
	arg0:"UI_OME_DEATH_NOTIFY" arg1:dwCharacterID arg2: 为INT_MAX，2147483647 arg3:szKiller  
	arg0:"UI_OME_SKILL_EFFECT_LOG" arg1:dwCaster arg2:dwTarget arg3:bReact arg4:nType  arg5:dwID  arg6:dwLevel  arg7:bCriticalStrike arg8:nResultCount 
	arg0:"UI_OME_COMMON_HEALTH_LOG" arg1:dwCharacterID arg2:nDeltaLife  
]]
DeathWarn.OnDeath = function(dwTarget, szKiller)
	local me = GetClientPlayer()
	local team = GetClientTeam()
	local tRecordList = DeathWarn.tDamage[dwTarget]
	if IsPlayer(dwTarget) and tRecordList then
		if team.IsPlayerInTeam(dwTarget) or dwTarget == me.dwID then
			local tInfo = tRecordList[#tRecordList]
			if tInfo then
				tInfo.time = GetCurrentTime()
			end
			if not DeathWarn.tDeath[dwTarget] then
				DeathWarn.tDeath[dwTarget] = {}
			end
			table.insert(DeathWarn.tDeath[dwTarget],tInfo)
			if #DeathWarn.tDeath[dwTarget] > 15 then
				table.remove(DeathWarn.tDeath[dwTarget],1)
			end
			DeathWarn.tDamage[dwTarget] = nil
			if GKP.Config.bDeathWarn then
				OutputMessage("MSG_SYS",_L["Boardcast of Serious Injure:"] .. "["..tInfo.szTarget.."]" .. _L["By"] .. "["..tInfo.szCaster.."]" .. _L["The"] .."<"..tInfo.szSkillName..">" .. _L["Lead to"] .. ""..tInfo.szValue.."," .. _L["Serious injured!"] .. "\n")
			end
		end
	end
end

RegisterEvent("SYS_MSG",function()
	if arg0 == "UI_OME_DEATH_NOTIFY" then -- 死亡记录
		DeathWarn.OnDeath(arg1, arg3)
	elseif arg0 == "UI_OME_SKILL_EFFECT_LOG" then -- 技能记录
		DeathWarn.OnSkillEffectLog(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9)
	elseif arg0 == "UI_OME_COMMON_HEALTH_LOG" then
		DeathWarn.OnCommonHealthLog(arg1,arg2)
	end
end)

local UIProtect = {
	tDamage = DeathWarn.tDamage,
	tDeath = DeathWarn.tDeath,
}
setmetatable(_GKP.DeathWarn, { __index = UIProtect, __metatable = true, __newindex = function() --[[ print("Protect") ]] end } )
