-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2016-12-13 01:08:42

-- 早期代码 需要重写

local PATH_ROOT = JH.GetAddonInfo().szRootPath .. "JH_GKP/"
local _L = JH.LoadLangPack

GKP = {
	bDebug2              = false,
	bOn                  = true,  -- enable
	bMoneyTalk           = false, -- 金钱变动喊话
	bAlertMessage        = true,  -- 进入副本提醒清空数据
	bMoneySystem         = false, -- 记录系统金钱变动
	bDisplayEmptyRecords = true,  -- show 0 record
	bAutoSync            = true,  -- 自动接收分配者的同步信息
	bShowGoldBrick       = true,
}
JH.RegisterCustomData("GKP")
---------------------------------------------------------------------->
-- 本地函数与变量
----------------------------------------------------------------------<
local _GKP = {
	szIniFile   = PATH_ROOT .. "ui/GKP.ini",
	tSyncQueue  = {},
	bSync       = {},
	GKP_Record  = {},
	GKP_Account = {},
	Config = {
		Subsidies = {
			{ _L["Treasure Chests"], "", true},
			-- { JH.GetItemName(73214), "", true},
			{ _L["Boss"], "", true},
			{ _L["Banquet Allowance"], -1000, true},
			{ _L["Fines"], "", true},
			{ _L["Other"], "", true},
		},
		Scheme = {
			{ 100, true },
			{ 1000, true },
			{ 2000, true },
			{ 3000, true },
			{ 4000, true },
			{ 5000, true },
			{ 6000, true },
			{ 7000, true },
			{ 8000, true },
			{ 9000, true },
			{ 10000, true },
			{ 20000, true },
			{ 50000, true },
			{ 100000, true },
		},
	},
}
_GKP.Config = JH.LoadLUAData("config/gkp.cfg") or _GKP.Config
---------------------------------------------------------------------->
-- 数据处理
----------------------------------------------------------------------<
setmetatable(GKP,{ __call = function(me, key, value, sort)
	if _GKP[key] then
		if value and type(value) == "table" then
			table.insert(_GKP[key], value)
			_GKP.SaveData()
			if key == "GKP_Record" then
				_GKP.DrawRecord()
			elseif key == "GKP_Account" then
				_GKP.DrawAccount()
			end
		elseif value and type(value) == "string" then
			if sort == "asc" or sort == "desc" then
				table.sort(_GKP[key], function(a, b)
					if a[value] and b[value] then
						if sort == "asc" then
							if a[value] ~= b[value] then
								return a[value] < b[value]
							elseif a.key and b.key then
								return a.key < b.key
							else
								return a.nTime < b.nTime
							end
						else
							if a[value] ~= b[value] then
								return a[value] > b[value]
							elseif a.key and b.key then
								return a.key > b.key
							else
								return a.nTime > b.nTime
							end
						end

					else
						return false
					end
				end)
			elseif value == "del" then
				if _GKP[key][sort] then
					_GKP[key][sort].bDelete = not _GKP[key][sort].bDelete
					_GKP.SaveData()
					if key == "GKP_Record" then
						_GKP.DrawRecord()
					elseif key == "GKP_Account" then
						_GKP.DrawAccount()
					end
					return _GKP[key][sort]
				end
			end
			return _GKP[key]
		elseif value and type(value) == "number" then
			if _GKP[key][value] then
				_GKP[key][value] = sort
				_GKP.SaveData()
				if key == "GKP_Record" then
					_GKP.DrawRecord()
				elseif key == "GKP_Account" then
					_GKP.DrawAccount()
				end
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
function _GKP.SaveConfig()
	JH.SaveLUAData("config/gkp.cfg", _GKP.Config)
end

function _GKP.SaveData()
	local me = GetClientPlayer()
	local szPath = "GKP/" .. me.szName .. "/" .. FormatTime("%Y-%m-%d",GetCurrentTime()) .. ".gkp"
	JH.SaveLUAData(szPath,{ GKP_Record = GKP("GKP_Record") , GKP_Account = GKP("GKP_Account") })
	_GKP.UpdateStat()
end

function _GKP.LoadData(szFile)
	local me = GetClientPlayer()
	local szPath = szFile .. ".gkp"
	local t = JH.LoadLUAData(szPath)
	if t then
		_GKP.GKP_Record = t.GKP_Record or {}
		_GKP.GKP_Account = t.GKP_Account or {}
	end
	_GKP.DrawRecord()
	_GKP.DrawAccount()
	_GKP.UpdateStat()
end

function _GKP.UpdateStat()
	local a, b = _GKP.GetRecordSum()
	local c, d = _GKP.GetAccountSum()
	local hStat = Station.Lookup("Normal/GKP", "Handle_Record_Stat")
	local szXml = GetFormatText(_L["Reall Salary:"], 41) .. _GKP.GetMoneyTipText(a + b)
	if JH.IsDistributer() or not JH.IsInParty() then
		if c + d < 0 then
			szXml = szXml .. GetFormatText(" || " .. _L["Spending:"], 41) .. _GKP.GetMoneyTipText(d)
		elseif c ~= 0 then
			szXml = szXml .. GetFormatText(" || " .. _L["Reall income:"], 41) .. _GKP.GetMoneyTipText(c + d)
		end
		local e = (a + b) - (c + d)
		if a > 0 then
			szXml = szXml .. GetFormatText(" || " .. _L["Money on Debt:"], 41) .. _GKP.GetMoneyTipText(e)
		end
	end
	hStat:Clear()
	hStat:AppendItemFromString(szXml)
	hStat:FormatAllItemPos()
	hStat:SetSizeByAllItemSize()
	hStat.OnItemMouseEnter = function()
		local br = GetFormatText("\n", 41)
		local szXml = ""
		if a > 0 then
			szXml = szXml .. GetFormatText(_L["Total Auction:"], 41) .. _GKP.GetMoneyTipText(a) .. br
			if b ~= 0 then
				szXml = szXml .. GetFormatText(_L["Salary Allowance:"], 41) .. _GKP.GetMoneyTipText(b) .. br
				szXml = szXml .. GetFormatText(_L["Reall Salary:"], 41) .. _GKP.GetMoneyTipText(a + b) .. br
			end
		end
		if (JH.IsDistributer() or not JH.IsInParty()) and c > 0 then
			szXml = szXml .. GetFormatText(_L["Total income:"], 41) .. _GKP.GetMoneyTipText(c) .. br
			if d ~= 0 then
				szXml = szXml .. GetFormatText(_L["Spending:"], 41) .. _GKP.GetMoneyTipText(d) .. br
				szXml = szXml .. GetFormatText(_L["Reall income:"], 41) .. _GKP.GetMoneyTipText(c + d) .. br
			end
		end
		if szXml ~= "" then
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			OutputTip(szXml, 400, { x - w, y, w, h })
		end
	end
	FireUIEvent("GKP_RECORD_TOTAL", a, b)
end

function _GKP.OpenPanel(bDisableSound)
	local frame = Station.Lookup("Normal/GKP") or Wnd.OpenWindow(_GKP.szIniFile, "GKP")
	frame:Show()
	frame:BringToTop()
	if not bDisableSound then
		PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
	end
	return frame
end
-- close
function _GKP.ClosePanel()
	if _GKP.frame then
		_GKP.frame:Hide()
		PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
	end
end
-- toggle
function _GKP.TogglePanel()
	if _GKP.IsOpened() then
		_GKP.ClosePanel()
	else
		_GKP.OpenPanel()
	end
end

function _GKP.IsOpened()
	return _GKP.frame and _GKP.frame:IsVisible()
end

-- initlization
function _GKP.Init()
	local me = GetClientPlayer()
	_GKP.OpenPanel(true):Hide()
	JH.DelayCall(function() -- Init延后 避免和进入副本冲突
		_GKP.LoadData("GKP/" .. me.szName .. "/" .. FormatTime("%Y-%m-%d", GetCurrentTime()))
	end, 125)
end
JH.RegisterEvent("FIRST_LOADING_END", _GKP.Init)

function _GKP.GetRecordWindow()
	return Station.Lookup("Normal/GKP_Record")
end

function _GKP.Random() -- 生成一个随机字符串 这还能重复我吃翔
	local a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,_+;*-"
	local t = {}
	for i = 1, 64 do
		local n = math.random(1, string.len(a))
		table.insert(t, string.sub(a, n, n))
	end
	return table.concat(t)
end

function _GKP.Sysmsg(szMsg)
	JH.Sysmsg(szMsg, "[GKP]")
end

function _GKP.GetTimeString(nTime, year)
	if year then
		return FormatTime("%H:%M:%S", nTime)
	else
		return FormatTime("%Y-%m-%d %H:%M:%S", nTime)
	end
end

function _GKP.GetMoneyCol(Money)
	local Money = tonumber(Money)
	if Money then
		if Money < 0 then
			return 0, 128, 255
		elseif Money < 1000 then
			return 255, 255, 255
		elseif Money < 10000 then
			return 255, 255, 164
		elseif Money < 100000 then
			return 255, 255, 0
		elseif Money < 1000000 then
			return 255, 192, 0
		elseif Money < 10000000 then
			return 255, 92, 0
		else
			return 255, 0, 0
		end
	else
		return 255, 255, 255
	end
end

function _GKP.GetFormatLink(item, bName)
	if type(item) == "string" then
		if bName then
			return { type = "name", name = item, text = "[" .. item .."]" }
		else
			return { type = "text", text = item }
		end
	else
		if item.nGenre == ITEM_GENRE.BOOK then
			return { type = "book", tabtype = item.dwTabType, index = item.dwIndex, bookinfo = item.nBookID, version = item.nVersion, text = "" }
		else
			return { type = "iteminfo", version = item.nVersion, tabtype = item.dwTabType, index = item.dwIndex, text = "" }
		end
	end
end

---------------------------------------------------------------------->
-- 窗体创建时会被调用
----------------------------------------------------------------------<
function GKP.OnFrameCreate()
	_GKP.frame = this
	_GKP.hRecordContainer = this:Lookup("PageSet_Menu/Page_GKP_Record/WndScroll_GKP_Record/WndContainer_Record_List")
	_GKP.hAccountContainer = this:Lookup("PageSet_Menu/Page_GKP_Account/WndScroll_GKP_Account/WndContainer_Account_List")
	local ui = GUI(this)
	local hPageSet = ui:Fetch("PageSet_Menu")
	ui:Title(_L["GKP Golden Team Record"]):Point():RegisterClose(_GKP.ClosePanel)
	ui:Append("WndComboBox", { x = 805, y = 52, txt = g_tStrings.STR_LOG_SET }):Click(function()
		JH.OpenPanel(_L["GKP Golden Team Record"])
	end)
	ui:Append("WndButton3", { x = 15, y = 660, txt = _L["Add Manually"] }):Click(function()
		if _GKP.GetRecordWindow() then
			return JH.Alert(_L["No Record For Current Object."])
		end
		if not JH.IsDistributer() and not JH.bDebugClient then -- debug
			return JH.Alert(_L["You are not the distrubutor."])
		end
		_GKP.Record()
	end)
	ui:Append("WndButton3", { x = 840, y = 620, txt = g_tStrings.GOLD_TEAM_SYLARY_LIST }):Click(_GKP.Calculation)
	ui:Append("WndButton3", "GOLD_TEAM_BID_LIST", {x = 840, y = 660, txt = g_tStrings.GOLD_TEAM_BID_LIST }):Click(_GKP.SpendingList)
	ui:Append("WndButton3", "Debt", { x = 690, y = 660, txt = _L["Debt Issued"] }):Click(_GKP.OweList)
	ui:Append("WndButton3", { x = 540, y = 660, txt = _L["Clear Record"] }):Click(_GKP.ClearData)
	ui:Append("WndButton3", { x = 390, y = 660, txt = _L["Loading Record"] }):Click(_GKP.Recovery)
	ui:Append("WndButton3", { x = 240, y = 660, txt = _L["Manual SYNC"] }):Click(_GKP.OnSync)

	hPageSet:Fetch("WndCheck_GKP_Record"):Fetch("Text_GKP_Record"):Text(g_tStrings.GOLD_BID_RECORD_STATIC_TITLE)
	hPageSet:Fetch("WndCheck_GKP_Account"):Fetch("Text_GKP_Account"):Text(g_tStrings.GOLD_BID_RPAY_STATIC_TITLE)
	JH.RegisterGlobalEsc("GKP", _GKP.IsOpened, _GKP.ClosePanel)
	-- 排序
	local page = this:Lookup("PageSet_Menu/Page_GKP_Record")
	local t = {
		{"#",         false},
		{"szPlayer",  _L["Gainer"]},
		{"szName",    _L["Name of the Items"]},
		{"nMoney",    _L["Auction Price"]},
		{"szNpcName", _L["Source of the Object"]},
		{"nTime",     _L["Distribution Time"]},
	}
	for k, v in ipairs(t) do
		if v[2] then
			local txt = page:Lookup("", "Text_Record_Break" ..k)
			txt:RegisterEvent(786)
			txt:SetText(v[2])
			txt.OnItemLButtonClick = function()
				local sort = txt.sort or "asc"
				_GKP.DrawRecord(v[1], sort)
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
		{"#",        false},
		{"szPlayer", _L["Transation Target"]},
		{"nGold",    _L["Changes in Money"]},
		{"szPlayer", _L["Ways of Money Change"]},
		{"dwMapID",  _L["The Map of Current Location when Money Changes"]},
		{"nTime",    _L["The Change of Time"]},
	}

	for k, v in ipairs(t) do
		if v[2] then
			local txt = page:Lookup("", "Text_Account_Break" .. k)
			txt:RegisterEvent(786)
			txt:SetText(v[2])
			txt.OnItemLButtonClick = function()
				local sort = txt.sort or "asc"
				_GKP.DrawAccount(v[1], sort)
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
end

function GKP.OnItemLButtonDown()
	local szName = this:GetName()
	if szName == "Text_Name" then
		if IsCtrlKeyDown() then
			return EditBox_AppendLinkPlayer(this:GetText())
		end
	end
end

function GKP.OnItemMouseEnter()
	if this:GetName() == "Text_Name" then
		local data = this.data
		local szIcon, nFrame = GetForceImage(data.dwForceID)
		local r, g, b = JH.GetForceColor(data.dwForceID)
		local szXml = GetFormatImage(szIcon,nFrame,20,20) .. GetFormatText("  " .. data.szPlayer .. g_tStrings.STR_COLON .. "\n", 136, r, g, b)
		if IsCtrlKeyDown() then
			szXml = szXml .. GetFormatText(g_tStrings.DEBUG_INFO_ITEM_TIP .. "\n", 136, 255, 0, 0)
			szXml = szXml .. GetFormatText(var2str(data, " "), 136, 255, 255, 255)
		else
			szXml = szXml .. GetFormatText(_L["System Information as Shown Below\n\n"],136,255,255,255)
			local nNum,nNum1,nNum2 = 0,0,0
			for kk,vv in ipairs(GKP("GKP_Record")) do
				if vv.szPlayer == data.szPlayer and not vv.bDelete then
					if  vv.nMoney > 0 then
						nNum = nNum + vv.nMoney
					else
						nNum1 = nNum1 + vv.nMoney
					end
				end
			end
			local r, g, b = _GKP.GetMoneyCol(nNum)
			szXml = szXml .. GetFormatText(_L["Total Cosumption:"],136,255,128,0) .. GetFormatText(nNum ..g_tStrings.STR_GOLD .. g_tStrings.STR_FULL_STOP .. "\n",136,r,g,b)
			local r, g, b = _GKP.GetMoneyCol(nNum1)
			szXml = szXml .. GetFormatText(_L["Total Allowance:"],136,255,128,0) .. GetFormatText(nNum1 ..g_tStrings.STR_GOLD .. g_tStrings.STR_FULL_STOP .. "\n",136,r,g,b)
			for kk,vv in ipairs(GKP("GKP_Account")) do
				if vv.szPlayer == data.szPlayer and not vv.bDelete and vv.nGold > 0 then
					nNum2 = nNum2 + vv.nGold
				end
			end
			local r, g, b = _GKP.GetMoneyCol(nNum2)
			szXml = szXml .. GetFormatText(_L["Total Payment:"],136,255,128,0) .. GetFormatText(nNum2 ..g_tStrings.STR_GOLD .. g_tStrings.STR_FULL_STOP .. "\n",136,r,g,b)
			local nNum3 = nNum+nNum1-nNum2
			if nNum3 < 0 then
				nNum3 = 0
			end
			local r, g, b = _GKP.GetMoneyCol(nNum3)
			szXml = szXml .. GetFormatText(_L["Money on Debt:"],136,255,128,0) .. GetFormatText(nNum3 ..g_tStrings.STR_GOLD .. g_tStrings.STR_FULL_STOP .. "\n",136,r,g,b)
		end
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		OutputTip(szXml, 400, { x, y, w, h })
	end
end

function GKP.OnItemMouseLeave()
	HideTip()
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	ui:Append("Text", { x = 0, y = 0, txt = _L["Preference Setting"], font = 27 })
	ui:Append("WndButton3", { x = 350, y = 0, txt = _L["Open Panel"] }):Click(_GKP.OpenPanel)

	nX, nY = ui:Append("WndCheckBox", { x = 10, y = 28, txt = _L["Popup Record for Distributor"], checked = GKP.bOn })
	:Click(function(bChecked)
		GKP.bOn = bChecked
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Clause with 0 Gold as Record"], checked = GKP.bDisplayEmptyRecords })
	:Click(function(bChecked)
		GKP.bDisplayEmptyRecords = bChecked
		_GKP.DrawRecord()
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, color = { 255, 128, 0 } , txt = _L["Show Gold Brick"], checked = GKP.bShowGoldBrick })
	:Click(function(bChecked)
		GKP.bShowGoldBrick = bChecked
		_GKP.DrawRecord()
		_GKP.DrawAccount()
		_GKP.UpdateStat()
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Remind Wipe Data When Enter Dungeon"], checked = GKP.bAlertMessage })
	:Click(function(bChecked)
		GKP.bAlertMessage = bChecked
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Automatic Reception with Record From Distributor"], checked = GKP.bAutoSync })
	:Click(function(bChecked)
		GKP.bAutoSync = bChecked
	end):Pos_()
	nX = ui:Append("WndComboBox", { x = 10, y = nY + 5, txt = _L["Edit Allowance Protocols"] }):Menu(_GKP.GetSubsidiesMenu):Pos_()
	nX, nY = ui:Append("WndComboBox", { x = nX + 10, y = nY + 5, txt = _L["Edit Auction Protocols"] }):Menu(_GKP.GetSchemeMenu):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Money Record"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 12, checked = GKP.bMoneySystem, txt = _L["Track Money Trend in the System"] })
	:Click(function(bChecked)
		GKP.bMoneySystem = bChecked
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY, txt = _L["Enable Money Trend"], checked = GKP.bMoneyTalk })
	:Click(function(bChecked)
		GKP.bMoneyTalk = bChecked
	end):Pos_()
	if JH.bDebugClient then
		ui:Append("WndCheckBox", { x = 10, y = nY, txt = "Enable Debug", checked = GKP.bDebug2 })
		:Click(function(bChecked)
			GKP.bDebug2 = bChecked
		end)
	end
end
GUI.RegisterPanel(_L["GKP Golden Team Record"], { "ui/Image/Common/Money.uitex", 15 }, g_tStrings.CHANNEL_CHANNEL, PS)

---------------------------------------------------------------------->
-- 获取补贴方案菜单
----------------------------------------------------------------------<
function _GKP.GetSubsidiesMenu()
	local menu = { szOption = _L["Edit Allowance Protocols"], rgb = { 255, 0, 0 } }
	table.insert(menu, {
		szOption = _L["Add New Protocols"],
		rgb = { 255, 255, 0 },
		fnAction = function()
			GetUserInput(_L["New Protocol  Format: Protocol's Name, Money"], function(txt)
				local t = JH.Split(txt, ",")
				table.insert(_GKP.Config.Subsidies, { t[1], tonumber(t[2]) or "", true })
				_GKP.SaveConfig()
			end)
		end
	})
	table.insert(menu, { bDevide = true})
	for k, v in ipairs(_GKP.Config.Subsidies) do
		table.insert(menu, {
			szOption = v[1],
			bCheck = true,
			bChecked = v[3],
			fnAction = function()
				v[3] = not v[3]
				_GKP.SaveConfig()
			end,
		})
	end
	return menu
end
---------------------------------------------------------------------->
-- 获取拍卖方案菜单
----------------------------------------------------------------------<
function _GKP.GetSchemeMenu()
	local menu = { szOption = _L["Edit Auction Protocols"], rgb = { 255, 0, 0 } }
	table.insert(menu,{
		szOption = _L["Edit All Protocols"],
		rgb = { 255, 255, 0 },
		fnAction = function()
			GetUserInput(_L["New Protocol Format: Money, Money, Money"], function(txt)
				local t = JH.Split(txt, ",")
				_GKP.Config.Scheme = {}
				for k, v in ipairs(t) do
					table.insert(_GKP.Config.Scheme, { tonumber(v) or 0, true })
				end
				_GKP.SaveConfig()
			end)
		end
	})
	table.insert(menu, { bDevide = true })
	for k, v in ipairs(_GKP.Config.Scheme) do
		table.insert(menu,{
			szOption = v[1],
			bCheck = true,
			bChecked = v[2],
			fnAction = function()
				v[2] = not v[2]
				_GKP.SaveConfig()
			end,
		})
	end

	return menu
end

function _GKP.GetMoneyTipText(nGold)
	local szUitex = "ui/image/common/money.UITex"
	local r, g, b = _GKP.GetMoneyCol(nGold)
	if GKP.bShowGoldBrick then
		if nGold >= 0 then
			return GetFormatText(math.floor(nGold / 10000), 41, r, g, b) .. GetFormatImage(szUitex, 27) .. GetFormatText(math.floor(nGold % 10000), 41, r, g, b) .. GetFormatImage(szUitex, 0)
		else
			nGold = nGold * -1
			return GetFormatText("-" .. math.floor(nGold / 10000), 41, r, g, b) .. GetFormatImage(szUitex, 27) .. GetFormatText(math.floor(nGold % 10000), 41, r, g, b) .. GetFormatImage(szUitex, 0)
		end
	else
		return GetFormatText(nGold, 41, r, g, b) .. GetFormatImage(szUitex, 0)
	end
end

---------------------------------------------------------------------->
-- 绘制物品记录
----------------------------------------------------------------------<
function _GKP.DrawRecord(key, sort)
	local key = key or _GKP.hRecordContainer.key or "nTime"
	local sort = sort or _GKP.hRecordContainer.sort or "desc"
	local tab = GKP("GKP_Record",key,sort)
	_GKP.hRecordContainer.key = key
	_GKP.hRecordContainer.sort = sort
	_GKP.hRecordContainer:Clear()
	for k, v in ipairs(tab) do
		if GKP.bDisplayEmptyRecords or v.nMoney ~= 0 then
			local wnd = _GKP.hRecordContainer:AppendContentFromIni(PATH_ROOT .. "ui/GKP_Record_Item.ini", "WndWindow", k)
			local item = wnd:Lookup("", "")
			if k % 2 == 0 then
				item:Lookup("Image_Line"):Hide()
			end
			item:RegisterEvent(32)
			item.OnItemRButtonClick = function()
				if not JH.IsDistributer() and not JH.bDebugClient then
					return JH.Alert(_L["You are not the distrubutor."])
				end
				_GKP.Record(v, k)
			end
			item:Lookup("Text_No"):SetText(k)
			item:Lookup("Image_NameIcon"):FromUITex(GetForceImage(v.dwForceID))
			item:Lookup("Text_Name"):SetText(v.szPlayer)
			item:Lookup("Text_Name"):SetFontColor(JH.GetForceColor(v.dwForceID))
			local szName = v.szName or JH.GetItemName(v.nUiId)
			item:Lookup("Text_ItemName"):SetText(szName)
			if v.nQuality then
				item:Lookup("Text_ItemName"):SetFontColor(GetItemFontColorByQuality(v.nQuality))
			else
				item:Lookup("Text_ItemName"):SetFontColor(255, 255, 0)
			end
			item:Lookup("Handle_Money"):AppendItemFromString(_GKP.GetMoneyTipText(v.nMoney))
			item:Lookup("Handle_Money"):FormatAllItemPos()
			item:Lookup("Text_Source"):SetText(v.szNpcName)
			if v.bSync then
				item:Lookup("Text_Source"):SetFontColor(0,255,0)
			end
			item:Lookup("Text_Time"):SetText(_GKP.GetTimeString(v.nTime))
			if v.bEdit then
				item:Lookup("Text_Time"):SetFontColor(255,255,0)
			end
			local box = item:Lookup("Box_Item")
			if v.dwTabType == 0 and v.dwIndex == 0 then
				box:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
				box:SetObjectIcon(582)
			else
				UpdataItemInfoBoxObject(box, v.nVersion, v.dwTabType, v.dwIndex, v.nBookID or v.nStackNum)
			end
			local hItemName = item:Lookup("Text_ItemName")
			for kk, vv in ipairs({"OnItemMouseEnter", "OnItemMouseLeave", "OnItemLButtonDown", "OnItemLButtonUp"}) do
				hItemName[vv] = function()
					if box[vv] then
						this = box
						box[vv]()
					end
				end
			end
			wnd:Lookup("WndButton_Delete").OnLButtonClick = function()
				if not JH.IsDistributer() and not JH.bDebugClient then
					return JH.Alert(_L["You are not the distrubutor."])
				end
				local tab = GKP("GKP_Record", "del", k)
				if JH.IsDistributer() then
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "del", tab)
				end
			end
			-- tip
			item:Lookup("Text_Name").data = v
			if v.bDelete then
				wnd:SetAlpha(80)
			end
		end
	end
	_GKP.hRecordContainer:FormatAllContentPos()
end

function _GKP.Bidding()
	local team = GetClientTeam()
	if not JH.IsDistributer() then
		return JH.Alert(_L["You are not the distrubutor."])
	end
	local nGold = _GKP.GetRecordSum(true)
	if nGold <= 0 then
		return JH.Alert(_L["Auction Money <=0."])
	end
	local t, fnAction = {}, nil
	InsertDistributeMenu(t, false)
	for k, v in ipairs(t[1]) do
		if v.szOption == g_tStrings.STR_LOOTMODE_GOLD_BID_RAID then
			fnAction = v.fnAction
			break
		end
	end
	team.SetTeamLootMode(PARTY_LOOT_MODE.BIDDING)
	local LeaderAddMoney = Wnd.OpenWindow("LeaderAddMoney")
	local fx, fy = Station.GetClientSize()
	local w2, h2 = LeaderAddMoney:GetSize()
	LeaderAddMoney:SetAbsPos((fx - w2) / 2, (fy - h2) / 2)
	LeaderAddMoney:Lookup("Edit_PriceB"):SetText(math.floor(nGold / 10000))
	LeaderAddMoney:Lookup("Edit_Price"):SetText(nGold % 10000)
	LeaderAddMoney:Lookup("Edit_Reason"):SetText("auto append")
	LeaderAddMoney:Lookup("Btn_Ok").OnLButtonUp = function()
		fnAction()
		Station.SetActiveFrame("GoldTeam")
		Station.Lookup("Normal/GoldTeam"):Lookup("PageSet_Total"):ActivePage(1)
	end
end

function GKP.GetTeamMemberMenu(fnAction, bDisable, bSelf)
	local tTeam, menu = {}, {}
	for _, v in ipairs(GetClientTeam().GetTeamMemberList()) do
		local info = GetClientTeam().GetMemberInfo(v)
		table.insert(tTeam, { szName = info.szName, dwID = v, dwForce = info.dwForceID, bIsOnLine = info.bIsOnLine})
	end
	local dwID = UI_GetClientPlayerID()
	table.sort(tTeam, function(a, b) return a.dwForce < b.dwForce end)
	for _, v in ipairs(tTeam) do
		if v.dwID ~= dwID or bSelf then
			local szIcon, nFrame = GetForceImage(v.dwForce)
			table.insert(menu, {
				szOption = v.szName,
				szLayer  = "ICON_RIGHTMOST",
				bDisable = bDisable and not v.bIsOnLine,
				szIcon   = szIcon,
				nFrame   = nFrame,
				rgb      = { JH.GetForceColor(v.dwForce) },
				fnAction = function()
					fnAction(v)
				end
			})
		end
	end
	return menu
end

---------------------------------------------------------------------->
-- 同步数据
----------------------------------------------------------------------<
function _GKP.OnSync()
	local me = GetClientPlayer()
	if me.IsInParty() then
		local menu = GKP.GetTeamMemberMenu(function(v)
			JH.Confirm(_L["Wheater replace the current record with the synchronization target's record?\n Please notice, this means you are going to lose the information of current record."], function()
				JH.Alert(_L["Asking for the sychoronization information...\n If no response in longtime, it may because the opposite side are not using GKP plugin or not responding."])
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_Sync", v.szName) -- 请求同步信息
			end)
		end, true)
		table.insert(menu, 1, { bDevide = true })
		table.insert(menu, 1, { szOption = _L["Please select which will be the one you are going to ask record for."], bDisable = true })
		PopupMenu(menu)
	else
		JH.Alert(_L["You are not in the team."])
	end
end

local SYNC_LENG = 0

JH.RegisterBgMsg("GKP", function(nChannel, dwID, szName, data, bIsSelf)
	local me = GetClientPlayer()
	local team = GetClientTeam()
	if team then
		if not bIsSelf then
			if data[1] == "GKP_Sync" and data[2] == me.szName then
				local tab = {
					GKP_Record  = GKP("GKP_Record"),
					GKP_Account = GKP("GKP_Account"),
				}
				local str = JH.JsonEncode(tab)
				local nMax = 500
				local nTotle = math.ceil(#str / nMax)
				-- 密聊频道限制了字数 发起来太慢了
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_Sync_Start", dwID, nTotle)
				for i = 1, nTotle do
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_Sync_Content", dwID, string.sub(str ,(i-1) * nMax + 1, i * nMax))
				end
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_Sync_Stop", dwID)
			end

			if data[2] == me.dwID then
				if data[1] == "GKP_Sync_Start" then
					_GKP.bSync, SYNC_LENG = true, data[3]
					JH.Alert(_L["Start Sychoronizing..."])
				end

				if data[1] == "GKP_Sync_Content" and _GKP.bSync then
					table.insert(_GKP.tSyncQueue, data[3])
					if SYNC_LENG ~= 0 then
						local percent = #_GKP.tSyncQueue / SYNC_LENG
						JH.Topmsg(_L("Sychoronizing data please wait %d%% loaded.", percent * 100))
					end
				end
				if data[1] == "GKP_Sync_Stop" then
					local str = table.concat(_GKP.tSyncQueue)
					_GKP.tSyncQueue = {}
					_GKP.bSync, SYNC_LENG = false, 0
					JH.Alert(_L["Sychoronization Complete"])
					JH.Topmsg(_L["Sychoronization Complete"])
					local tData, err = JH.JsonDecode(str)
					if err then
						JH.Debug(err)
						return _GKP.Sysmsg(_L["Abnormal with Data Sharing, Please contact and make feed back with the writer."])
					end
					JH.Confirm(_L("Data Sharing Finished, you have one last chance to confirm wheather cover the current data or not? \n data of team bidding: %s\n transation data: %s", #tData.GKP_Record, #tData.GKP_Account), function()
						_GKP.GKP_Record  = tData.GKP_Record
						_GKP.GKP_Account = tData.GKP_Account
						_GKP.DrawRecord()
						_GKP.DrawAccount()
						_GKP.SaveData()
					end)
				end
			end
			if (data[1] == "del" or data[1] == "edit" or data[1] == "add") and GKP.bAutoSync then
				local tab = data[2]
				tab.bSync = true
				if data[1] == "add" then
					GKP("GKP_Record", tab)
				else
					for k, v in ipairs(GKP("GKP_Record")) do
						if v.key == tab.key then
							GKP("GKP_Record", k, tab)
							break
						end
					end
				end
				JH.Debug("#GKP# Sync Success")
			end
		end
		if data[1] == "GKP_INFO" then
			if data[2] == "Start" then
				local szFrameName = data[3] == "Information on Debt" and "GKP_Debt" or "GKP_info"
				if data[3] == "Information on Debt" and szName ~= me.szName then -- 欠债记录只自己看
					return
				end
				local ui = GUI.CreateFrame(szFrameName, { w = 760, h = 350, title = _L["GKP Golden Team Record"], close = true }):Point()
				ui:Append("Text", { x = 0, y = 50, w = 760, h = 30, txt = _L[data[3]], align = 1, font = 236, color = { 255, 255, 0 } })
				ui:Append("WndButton3", "ScreenShot", { x = 590, y = 50, txt = _L["Print Ticket"] }):Toggle(false):Click(function()
					local scale         = Station.GetUIScale()
					local left, top     = ui:Pos()
					local right, bottom = ui:Pos_()
					local btn           = this
					local path          = GetRootPath() .. string.format("\\ScreenShot\\GKP_Ticket_%s.png", FormatTime("%Y-%m-%d_%H.%M.%S", GetCurrentTime()))
					btn:Hide()
					JH.DelayCall(function()
						ScreenShot(path, 100, scale * left, scale * top, scale * right, scale * bottom)
						JH.DelayCall(function()
							JH.Alert(_L("Shot screen succeed, file saved as %s .", path))
							btn:Show()
						end)
					end, 50)
				end)
				ui:Append("Text", { w = 120, h = 30, x = 40, y = 85, txt = _L("Operator:%s", szName), font = 41 })
				ui:Append("Text", { w = 720, h = 30, x = 0, align = 2, y = 85, txt = _L("Print Time:%s", _GKP.GetTimeString(GetCurrentTime())), font = 41 })
				ui.self.self = ui
			end
			if data[2] == "Info" then
				if data[3] == me.szName and tonumber(data[4]) and tonumber(data[4]) <= -100 then
					JH.OutputWhisper(data[3] .. g_tStrings.STR_COLON .. data[4] .. g_tStrings.STR_GOLD, "GKP")
				end
				local frm = Station.Lookup("Normal/GKP_info")
				if frm and frm.done then
					frm = Station.Lookup("Normal/GKP_Debt")
				end
				if not frm and Station.Lookup("Normal/GKP_Debt") then
					frm = Station.Lookup("Normal/GKP_Debt")
				end
				if frm then
					if not frm.n then frm.n = 0 end
					local n = frm.n
					local ui = frm.self
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
					local handle = ui:Append("Handle", { w = 130, h = 20, x = 200, y = 120 + 30 * n }):Type(3):Raw()
					handle:AppendItemFromString(_GKP.GetMoneyTipText(tonumber(data[4])))
					handle:FormatAllItemPos()
					for k, v in ipairs(tBox) do
						if k > 12 then
							ui:Append("Text", { x = 290 + k * 32 + 5, y = 121 + 30 * n, w = 28, h = 28, txt = ".....", font = 23 })
							break
						end
						local hBox = ui:Append("Box", { x = 290 + k * 32, y = 121 + 30 * n, w = 28, h = 28, alpha = v.bDelete and 60 })
						if v.nUiId ~= 0 then
							hBox:ItemInfo(v.nVersion, v.dwTabType, v.dwIndex, v.nStackNum or v.nBookID)
						else
							hBox:Icon(582):Hover(function(bHover)
								if bHover then
									local x, y = this:GetAbsPos()
									local w, h = this:GetSize()
									OutputTip(GetFormatText(v.szName .. g_tStrings.STR_TALK_HEAD_SAY1, 136) .. _GKP.GetMoneyTipText(v.nMoney), 250, { x, y, w, h })
								else
									HideTip()
								end
							end)
						end
					end
					if frm.n > 5 then
						frm.self:Size(760, 30 * frm.n + 200)
					end
					frm.n = frm.n + 1
				end
			end
			if data[2] == "End" then
				local szFrameName = data[4] and "GKP_info" or "GKP_Debt"
				local frm = Station.Lookup("Normal/" .. szFrameName)
				if frm then
					if data[4] then
						local ui = frm.self
						local n = frm.n or 0
						local handle = ui:Append("Handle", { w = 230, h = 20, x = 30, y = 120 + 30 * n + 5 }):Type(3):Raw()
						handle:AppendItemFromString(GetFormatText(_L["Total Auction:"], 41) .. _GKP.GetMoneyTipText(tonumber(data[4])))
						handle:FormatAllItemPos()
						if JH.IsDistributer() then
							ui:Append("WndButton4", { w = 91, h = 26, x = 620, y = 120 + 30 * n + 5, txt = _L["salary"] }):Click(function()
								JH.Confirm(_L["Confirm?"], _GKP.Bidding)
							end)
						end
						if data[5] and tonumber(data[5]) then
							local nTime = tonumber(data[5])
							ui:Append("Text", { w = 725, h = 30, x = 0, y = 120 + 30 * n + 5, txt = _L("Spend time approx %d:%d", nTime / 3600, nTime % 3600 / 60), align = 1 })
						end
						frm.self:Fetch("ScreenShot"):Toggle(true)
						if n >= 4 then
							local nMoney = tonumber(data[4]) or 0
							local t = {
								{ 50000,   1 }, -- 黑出翔
								{ 100000,  0 }, -- 背锅
								{ 250000,  2 }, -- 脸帅
								{ 500000,  6 }, -- 自称小红手
								{ 5000000, 3 }, -- 特别红
								{ 5000000, 5 }, -- 玄晶专用r
							}
							local nFrame = 4
							for k, v in ipairs(t) do
								if v[1] >= nMoney then
									nFrame = v[2]
									break
								end
							end
							local img = ui:Append("Image", { x = 590, y = n * 30 - 30, w = 150, h = 150, alpha = 180 }):File(JH.GetAddonInfo().szRootPath .. "JH_GKP/img/GKPSeal.uitex", nFrame):Hover(function(bHover)
								if bHover then
									this:SetAlpha(30)
								else
									this:SetAlpha(180)
								end
							end):Raw()
							JH.Animate(img, 200):Scale(4)
						end
						frm.done = true
					elseif szFrameName == "GKP_Debt" and not frm:IsVisible() then
						Wnd.CloseWindow(frm)
					end
				end
				_GKP.SetButton(true)
			end
		end
	end
end)

function _GKP.SetButton(bEnable)
	GUI(Station.Lookup("Normal/GKP")):Fetch("GOLD_TEAM_BID_LIST"):Enable(bEnable)
	GUI(Station.Lookup("Normal/GKP")):Fetch("Debt"):Enable(bEnable)
end

---------------------------------------------------------------------->
-- 恢复记录按钮
----------------------------------------------------------------------<
function _GKP.Recovery()
	local me = GetClientPlayer()
	_GKP.szName = _GKP.szName or me.szName
	local menu = {}
	table.insert(menu,{
		szOption = _L("Loading Data of the Character's name: %s (edit by clicking)",_GKP.szName),
		rgb = { 255, 255, 0 },
		fnAction = function()
			GetUserInput(_L["Modify to Lead the Character's name"],function(szText)
				_GKP.szName = szText
			end)
		end
	})
	for i = 0, 21 do
		local nTime = GetCurrentTime() - i * 86400
		local szPath = JH.GetAddonInfo().szDataPath .. "GKP/" .. _GKP.szName .. "/" .. FormatTime("%Y-%m-%d",nTime) .. ".gkp"
		table.insert(menu,{
			szOption = FormatTime("%Y-%m-%d",nTime) .. ".gkp",
			bDisable = not IsFileExist(szPath .. ".jx3dat"),
			fnAction = function()
				JH.Confirm(_L["Are you sure to cover the current information with the last record data?"],function()
					_GKP.LoadData("GKP/" .. _GKP.szName .. "/" .. FormatTime("%Y-%m-%d",nTime))
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
function _GKP.ClearData(bConfirm)
	local fnAction = function()
		_GKP.GKP_Record = {}
		_GKP.GKP_Account = {}
		_GKP.DrawRecord()
		_GKP.DrawAccount()
		_GKP.UpdateStat()
		FireUIEvent("GKP_LOOT_BOSS")
		JH.Alert(_L["Recods are wiped"])
	end
	if bConfirm then
		fnAction()
	else
		JH.Confirm(_L["Are you sure to wipe all of the records?"], fnAction)
	end
end
---------------------------------------------------------------------->
-- 欠费情况
----------------------------------------------------------------------<
function _GKP.OweList()
	local me = GetClientPlayer()
	if not me.IsInParty() and not JH.bDebugClient then return JH.Alert(_L["You are not in the team."]) end
	local tMember = {}
	if IsEmpty(GKP("GKP_Record")) then
		return JH.Alert(_L["No Record"])
	end
	if not JH.IsDistributer() and not JH.bDebugClient then
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
	local _Account = {}
	for k,v in ipairs(GKP("GKP_Account")) do
		if not v.bDelete and v.szPlayer and v.szPlayer ~= "System" then
			if tMember[v.szPlayer] then
				tMember[v.szPlayer] = tMember[v.szPlayer] - v.nGold
			else
				if not _Account[v.szPlayer] then
					_Account[v.szPlayer] = 0
				end
				_Account[v.szPlayer] = _Account[v.szPlayer] + v.nGold
			end
		end
	end
	-- 欠账
	local tMember2 = {}
	for k,v in pairs(tMember) do
		if v ~= 0 then
			table.insert(tMember2, { szName = k, nGold = v * -1 })
		end
	end
	-- 正账
	for k,v in pairs(_Account) do
		if v > 0 then
			table.insert(tMember2, { szName = k, nGold = v })
		end
	end

	table.sort(tMember2, function(a,b) return a.nGold < b.nGold end)
	JH.Talk(_L["Information on Debt"])
	JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Start", "Information on Debt")
	for k,v in pairs(tMember2) do
		if v.nGold < 0 then
			JH.Talk({ _GKP.GetFormatLink(v.szName, true), _GKP.GetFormatLink(g_tStrings.STR_TALK_HEAD_SAY1 .. v.nGold .. g_tStrings.STR_GOLD .. g_tStrings.STR_FULL_STOP) })
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Info", v.szName, v.nGold, "-")
		else
			JH.Talk({ _GKP.GetFormatLink(v.szName, true), _GKP.GetFormatLink(g_tStrings.STR_TALK_HEAD_SAY1 .. "+" .. v.nGold .. g_tStrings.STR_GOLD .. g_tStrings.STR_FULL_STOP) })
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Info", v.szName, v.nGold, "+")
		end
	end
	local nGold, nGold2 = 0, 0
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
		JH.Talk(_L("Received: %d Gold.", nGold))
	end
	if nGold2 ~= 0 then
		JH.Talk(_L("Spending: %d Gold.", nGold2 * -1))
	end
	JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "End", _L("Received: %d Gold.", nGold))
end
---------------------------------------------------------------------->
-- 获取工资总额
----------------------------------------------------------------------<
function _GKP.GetRecordSum(bAccurate)
	local a, b = 0, 0
	for k, v in ipairs(GKP("GKP_Record")) do
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
		return a, b
	end
end

function _GKP.GetAccountSum(bAccurate)
	local a, b = 0, 0
	for k, v in ipairs(GKP("GKP_Account")) do
		if not v.bDelete then
			if tonumber(v.nGold) > 0 then
				a = a + v.nGold
			else
				b = b + v.nGold
			end
		end
	end
	if bAccurate then
		return a + b
	else
		return a, b
	end
end

---------------------------------------------------------------------->
-- 消费情况按钮
----------------------------------------------------------------------<
function _GKP.SpendingList()
	local me = GetClientPlayer()
	if not me.IsInParty() and not JH.bDebugClient then return JH.Alert(_L["You are not in the team."]) end
	local tMember = {}
	if IsEmpty(GKP("GKP_Record")) then
		return JH.Alert(_L["No Record"])
	end
	if not JH.IsDistributer() and not JH.bDebugClient then
		return JH.Alert(_L["You are not the distrubutor."])
	end
	_GKP.SetButton(false)
	local tTime = {}
	for k, v in ipairs(GKP("GKP_Record")) do
		if not v.bDelete then
			if not tMember[v.szPlayer] then
				tMember[v.szPlayer] = 0
			end
			if tonumber(v.nMoney) > 0 then
				tMember[v.szPlayer] = tMember[v.szPlayer] + v.nMoney
			end
			table.insert(tTime, { nTime = v.nTime })
		end
	end
	table.sort(tTime, function(a, b)
		return a.nTime < b.nTime
	end)
	local nTime = tTime[#tTime].nTime - tTime[1].nTime -- 所花费的时间

	JH.Talk(_L["--- Consumption ---"])
	JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Start", "--- Consumption ---")
	local sort = {}
	for k,v in pairs(tMember) do
		table.insert(sort,{ szName = k, nGold = v })
	end

	table.sort(sort,function(a,b) return a.nGold < b.nGold end)
	for k, v in ipairs(sort) do
		if v.nGold > 0 then
			JH.Talk({ _GKP.GetFormatLink(v.szName, true), _GKP.GetFormatLink(g_tStrings.STR_TALK_HEAD_SAY1 .. v.nGold .. g_tStrings.STR_GOLD .. g_tStrings.STR_FULL_STOP) })
		end
		JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "Info", v.szName, v.nGold)
	end
	JH.Talk(_L("Total Auction: %d Gold.", _GKP.GetRecordSum()))
	JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "GKP_INFO", "End", _L("Total Auction: %d Gold.", _GKP.GetRecordSum()), _GKP.GetRecordSum(), nTime)
end
---------------------------------------------------------------------->
-- 结算工资按钮
----------------------------------------------------------------------<
function _GKP.Calculation()
	local me = GetClientPlayer()
	if not me.IsInParty() and not JH.bDebugClient then return JH.Alert(_L["You are not in the team."]) end
	local team = GetClientTeam()
	if IsEmpty(GKP("GKP_Record")) then
		return JH.Alert(_L["No Record"])
	end
	if not JH.IsDistributer() and not JH.bDebugClient then
		return JH.Alert(_L["You are not the distrubutor."])
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
	end, nil, nil, nil, team.GetTeamSize())
end

---------------------------------------------------------------------->
-- 记账页面
----------------------------------------------------------------------<
function _GKP.Record(tab, item, bEnter)
	-- CreateFrame
	if _GKP.GetRecordWindow() then
		local wnd = GUI(_GKP.GetRecordWindow())
		wnd:Fetch("Btn_Close"):Click()
	end
	local ui = GUI.CreateFrame("GKP_Record", { h = 380, w = 400, title = _L["GKP Golden Team Record"], close = true, focus = true })
	local nAuto = 0
	local dwForceID
	local hBox = ui:Append("Box", "Box", { x = 175, y = 80, h = 48, w = 48 })
	local hCheckBox = ui:Append("WndCheckBox", "WndCheckBox", { x = 20, y = 300, font = 65, txt = _L["Equiptment Boss"] })
	local hButton = ui:Append("WndButton3", "Success", { x = 130, y = 300, txt = g_tStrings.STR_HOTKEY_SURE })
	ui:RegisterClose(function()
		if ui:Raw().userdata then
			ui:Fetch("Money"):Text(0)
			return hButton:Click()
		end
		ui:Remove()
	end)

	ui:Append("Text", { x = 65, y = 50, font = 65, txt = _L["Keep Account to:"] })
	ui:Append("Text", { x = 65, y = 130, font = 65, txt = _L["Name of the Item:"] })
	ui:Append("Text", { x = 65, y = 160, font = 65, txt = _L["Route of Acquiring:"] })
	ui:Append("Text", { x = 65, y = 190, font = 65, txt = _L["Auction Price:"] })

	local hPlayer = ui:Append("WndComboBox", "PlayerList", { x = 140, y = 53, txt = g_tStrings.PLAYER_NOT_EMPTY }):Menu(function()
		return GKP.GetTeamMemberMenu(function(v)
			local hTeamList = ui:Fetch("PlayerList")
			hTeamList:Text(v.szName):Color(JH.GetForceColor(v.dwForce))
			dwForceID = v.dwForce
		end, false, true)
	end)
	local hSource = ui:Append("WndEdit", "Source", { x = 140, y = 161, w = 185, h = 25 })
	local hName = ui:Append("WndEdit", "Name", { x = 140, y = 131, w = 185, h = 25 }):Autocomplete(function(szText)
		local tList = {}
		for k, v in ipairs(_GKP.Config.Subsidies) do
			if v[3] then
				table.insert(tList, { szOption = v[1], data = v })
			end
		end
		return tList
	end, function(szText, data)
		if data then
			ui:Fetch("Money"):Focus()
		end
	end)
	local hMoney = ui:Append("WndEdit", "Money", { x = 140, y = 191, w = 185, h = 25, limit = 8 }):Type(1):Autocomplete(function(szText)
		if tonumber(szText) and tonumber(szText) < 100 and tonumber(szText) > -100 and tonumber(szText) ~= 0 then
			local menu = {}
			for k, v in ipairs({2, 3, 4}) do
				local nMoney = string.format("%0.".. v .."f", szText):gsub("%.", "")
				table.insert(menu, {
					bRichText = true,
					szOption  = _GKP.GetMoneyTipText(tonumber(nMoney)),
					option    = nMoney,
				})
			end
			table.insert(menu, { bDevide = true })
			table.insert(menu, { bRichText = true, szOption = _GKP.GetMoneyTipText(tonumber(szText)), option = szText, self = true })
			return menu
		else
			if tonumber(szText) then
				return {{ bRichText = true, szOption = _GKP.GetMoneyTipText(tonumber(szText)), option = szText, self = true }}
			else
				return {}
			end
		end
	end):Change(function(szText)
		if tonumber(szText) or szText == "" or szText == "-" then
			this.txt = szText
			this:SetFontColor(_GKP.GetMoneyCol(szText))
		else
			JH.Sysmsg(_L["Please enter numbers"])
			this:SetText(this.txt or "")
		end
	end)
	-- set frame
	if tab and type(item) == "userdata" then
		hPlayer:Text(tab.szPlayer):Color(JH.GetForceColor(tab.dwForceID))
		hName:Text(tab.szName):Enable(false)
		hSource:Text(tab.szNpcName):Enable(false)
		ui:Raw().userdata = true
	else
		hPlayer:Text(g_tStrings.PLAYER_NOT_EMPTY):Color(255, 255, 255)
		hSource:Text(_L["Add Manually"]):Enable(false)
	end
	if tab and type(item) == "number" then -- 编辑
		hPlayer:Text(tab.szPlayer):Color(JH.GetForceColor(tab.dwForceID))
		dwForceID = tab.dwForceID
		local iName = JH.GetItemName(tab.nUiId)
		hName:Text(tab.szName or iName)
		hMoney:Text(tab.nMoney)
		hSource:Text(tab.szNpcName)
	end

	if tab and tab.nVersion and tab.nUiId and tab.dwTabType and tab.dwIndex and tab.nUiId ~= 0 then
		hBox:ItemInfo(tab.nVersion, tab.dwTabType, tab.dwIndex, tab.nBookID or tab.nStackNum)
	else
		hBox:ItemInfo()
		hBox:Icon(582)
	end
	if nAuto == 0 and type(item) ~= "number" and tab then -- edit/add killfocus
		hMoney:Focus()
	elseif nAuto > 0 and tab then
		hMoney:Text(auto) -- OnEditChanged kill
		ui:Focus()
	elseif not tab then
		hName:Focus()
	end
	hButton:Click(function()
		local tab = tab or {
			nUiId      = 0,
			dwTabType  = 0,
			dwDoodadID = 0,
			nQuality   = 1,
			nVersion   = 0,
			dwIndex    = 0,
			nTime      = GetCurrentTime(),
			dwForceID  = dwForceID,
			szName     = hName:Text(),
		}
		local nMoney = tonumber(hMoney:Text()) or 0
		local szPlayer = hPlayer:Text()
		if hName:Text() == "" then
			return JH.Alert(_L["Please entry the name of the item"])
		end
		if szPlayer == g_tStrings.PLAYER_NOT_EMPTY then
			return JH.Alert(_L["Select a member who is in charge of account and put money in his account."])
		end
		tab.szNpcName = hSource:Text()
		tab.nMoney    = nMoney
		tab.szPlayer  = szPlayer
		tab.key       = tab.key or tab.nUiId .. _GKP.Random()
		tab.dwForceID = dwForceID or tab.dwForceID or 0
		if tab and type(item) == "userdata" then
			if JH.IsDistributer() then
				JH.Talk({
					_GKP.GetFormatLink(tab),
					_GKP.GetFormatLink(" ".. nMoney ..g_tStrings.STR_GOLD),
					_GKP.GetFormatLink(_L[" Distribute to "]),
					_GKP.GetFormatLink(tab.szPlayer, true)
				})
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "GKP", "add", tab)
			end
		elseif tab and type(item) == "number" then
			tab.szName = hName:Text()
			tab.dwForceID = dwForceID or tab.dwForceID or 0
			tab.bEdit = true
			if JH.IsDistributer() then
				JH.Talk({
					_GKP.GetFormatLink(tab.szPlayer, true),
					_GKP.GetFormatLink(" ".. tab.szName),
					_GKP.GetFormatLink(" ".. nMoney ..g_tStrings.STR_GOLD),
					_GKP.GetFormatLink(_L["Make changes to the record."]),
				})
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP", "edit", tab)
			end
		else
			if JH.IsDistributer() then
				JH.Talk({
					_GKP.GetFormatLink(tab.szName),
					_GKP.GetFormatLink(" ".. nMoney ..g_tStrings.STR_GOLD),
					_GKP.GetFormatLink(_L["Manually make record to"]),
					_GKP.GetFormatLink(tab.szPlayer, true)
				})
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID,"GKP", "add", tab)
			end
		end
		if ui:Fetch("WndCheckBox"):Check() then
			FireUIEvent("GKP_LOOT_BOSS", tab.szPlayer)
		end
		if tab and type(item) == "number" then
			GKP("GKP_Record", item, tab)
		else
			GKP("GKP_Record", tab)
		end
		ui:Remove()
	end)
	if bEnter then
		hButton:Click()
	end
end


---------------------------------------------------------------------->
-- 金钱记录
----------------------------------------------------------------------<
_GKP.TradingTarget = {}

function _GKP.MoneyUpdate(nGold, nSilver, nCopper)
	if nGold > -20 and nGold < 20 then
		return
	end
	if not _GKP.TradingTarget then
		return
	end
	if not _GKP.TradingTarget.szName and not GKP.bMoneySystem then
		return
	end
	GKP("GKP_Account", {
		nGold     = nGold, -- API给的有问题 …… 只算金
		szPlayer  = _GKP.TradingTarget.szName or "System",
		dwForceID = _GKP.TradingTarget.dwForceID,
		nTime     = GetCurrentTime(),
		dwMapID   = GetClientPlayer().GetMapID()
	})
	if _GKP.TradingTarget.szName and GKP.bMoneyTalk then
		if nGold > 0 then
			JH.Talk({
				_GKP.GetFormatLink(_L["Received"]),
				_GKP.GetFormatLink(_GKP.TradingTarget.szName, true),
				_GKP.GetFormatLink(_L["The"] .. nGold ..g_tStrings.STR_GOLD .. g_tStrings.STR_FULL_STOP),
			})
		else
			JH.Talk({
				_GKP.GetFormatLink(_L["Pay to"]),
				_GKP.GetFormatLink(_GKP.TradingTarget.szName, true),
				_GKP.GetFormatLink(" " .. nGold * -1 ..g_tStrings.STR_GOLD .. g_tStrings.STR_FULL_STOP),
			})
		end
	end
end

function _GKP.DrawAccount(key,sort)
	local key = key or _GKP.hAccountContainer.key or "szPlayer"
	local sort = sort or _GKP.hAccountContainer.sort or "desc"
	local tab = GKP("GKP_Account",key,sort)
	_GKP.hAccountContainer.key = key
	_GKP.hAccountContainer.sort = sort
	_GKP.hAccountContainer:Clear()
	local tMoney = GetClientPlayer().GetMoney()
	for k, v in ipairs(tab) do
		local c = _GKP.hAccountContainer:AppendContentFromIni(PATH_ROOT .. "ui/GKP_Account_Item.ini", "WndWindow", k)
		local item = c:Lookup("", "")
		if k % 2 == 0 then
			item:Lookup("Image_Line"):Hide()
		end
		c:Lookup("", "Handle_Money"):AppendItemFromString(_GKP.GetMoneyTipText(v.nGold))
		c:Lookup("", "Handle_Money"):FormatAllItemPos()
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
		item:Lookup("Text_Time"):SetText(_GKP.GetTimeString(v.nTime))
		c:Lookup("WndButton_Delete").OnLButtonClick = function()
			GKP("GKP_Account", "del", k)
		end
		-- tip
		item:Lookup("Text_Name").data = v
		if v.bDelete then
			c:SetAlpha(80)
		end
	end
	_GKP.hAccountContainer:FormatAllContentPos()
end

RegisterEvent("TRADING_OPEN_NOTIFY",function() -- 交易开始
	_GKP.TradingTarget = GetPlayer(arg0)
end)
RegisterEvent("TRADING_CLOSE",function() -- 交易结束
	_GKP.TradingTarget = {}
end)
RegisterEvent("MONEY_UPDATE",function() --金钱变动
	_GKP.MoneyUpdate(arg0, arg1, arg2)
end)

JH.PlayerAddonMenu({ szOption = _L["Open Golden Team Record"], fnAction = _GKP.OpenPanel })
JH.AddHotKey("JH_GKP", _L["Open Golden Team Record"], _GKP.TogglePanel)

RegisterEvent("LOADING_END",function()
	if JH.IsInDungeon() and GKP.bAlertMessage then
		if not IsEmpty(GKP("GKP_Record")) or not IsEmpty(GKP("GKP_Account")) then
			JH.Confirm(_L["Do you want to wipe the previous data when you enter the dungeon's map?"],function() _GKP.ClearData(true) end)
		end
	end
end)
GKP.Record          = _GKP.Record
GKP.GetMoneyCol     = _GKP.GetMoneyCol
GKP.OpenPanel       = _GKP.OpenPanel
GKP.ClosePanel      = _GKP.ClosePanel
GKP.TogglePanel     = _GKP.TogglePanel
GKP.GetFormatLink   = _GKP.GetFormatLink
function GKP.GetConfig()
	return _GKP.Config
end
