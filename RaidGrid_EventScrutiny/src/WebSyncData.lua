local _L = JH.LoadLangPack
WebSyncData = {
	tData = {}, --以后实现自动更新用
}
RegisterCustomData("WebSyncData.tData")

local _WebSyncData = {
	tResult = {},
	key = {},
	tList = {},
	tData = {},
	tUnused = nil,
	bSyncWebPage = false,
	tUrl = { -- 暂时先这样配置 请不要修改
		szConfigList = "http://www.j3ui.com/list/game/",
		szConfigList2 = "http://www.j3ui.com/list/game2/",
		szDownload = "http://www.j3ui.com/down/json/",		
		szKeyUrl = "http://www.j3ui.com/analysis/md5/",
	},
}
	
_WebSyncData.Search = function()
	GetUserInput(g_tStrings.SEARCH,function(txt)
		local t = {}
		local x, y = _WebSyncData.Container:GetAllContentSize()
		for k,v in ipairs(_WebSyncData.tList) do
			if tonumber(txt) and v.aid == txt then
				table.insert(t,v)
				break
			elseif v.title:match(txt) then
				table.insert(t,v)
			elseif v.author:match(txt) then
				table.insert(t,v)
			end
		end
		if #t > 0 then
			_WebSyncData.Container:Clear()
			for i = 1 , #t do 
				_WebSyncData.AppendItem(t[i],t[i].aid,i)
			end
			_WebSyncData.Container:FormatAllContentPos()
		else
			JH.Alert(_L["No content"])
		end
	end)	
end

_WebSyncData.GetData = function()
	local fnAction = function(szText)
		if szText ~= "" then
			_WebSyncData.SyncTip(_L["Loading..."],{255,255,0})
			local szUrl = _WebSyncData.tUrl.szKeyUrl.. szText .. "?&_".. GetCurrentTime()
			JH.RemoteRequest(szUrl,function(szTitle,szDoc)
				local result,err = JH.JsonDecode(JH.UrlDecode(szDoc))
				if not result then
					_WebSyncData.SyncTip(true)
					return JH.Sysmsg2(err)
				else
					_WebSyncData.SyncTip(true)
					table.insert(_WebSyncData.key,result)
					_WebSyncData.RefreshList()
				end
			end)
		end
	end
	GetUserInput(_L["Please enter md5"], fnAction)
end

_WebSyncData.SyncTeam = function()
	if _WebSyncData.bSyncWebPage then
		return
	end
	if not _WebSyncData.tUnused then
		return JH.Alert(g_tStrings.MSG_CHOOSE_FILE_EMPTY)
	end
	local me = GetClientPlayer()
	if not me.IsInParty() then
		return JH.Alert(g_tStrings.STR_TALK_ERROR_NOT_IN_PARTY)
	end
	local team = GetClientTeam()
	local szLeader = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER))
	if szLeader ~= me.szName then
		return JH.Alert(_L["You are not team leader."])
	end
	JH.Confirm(_L["Confirm?"],function()
		local t = _WebSyncData.tUnused.tData
		JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "WebSyncTean", "WebSyncTean", t.aid, JH.AscIIEncode(t.title), JH.AscIIEncode(t.author), t.dateline, JH.AscIIEncode(t.md5))
	end)
end

JH.RegisterEvent("ON_BG_CHANNEL_MSG",function()
	local data = JH.BgHear("WebSyncTean", true)
	if data then
		if data[1] == "WebSyncTean" and WebSyncData then
			WebSyncData.OpenPanel(data[2], data[3], data[4], data[5], data[6])
		end
		if data[1] == "Load" then
			JH.Sysmsg(_L("%s use %s data", arg3, data[2]))
		end
	end
end)

WebSyncData.OnFrameCreate = function()
	local ui = GUI(this)
	ui:Append("WndButton3", { x = 30, y = 630, txt = _L["sync team"] })
	:Click(_WebSyncData.SyncTeam)
	ui:Append("WndButton3","btn1", { x = 180, y = 630, txt = g_tStrings.SEARCH }):Enable(false)
	:Click(function()
		ui:Fetch("btn1"):Enable(false)
		ui:Fetch("btn2"):Enable(true)
		_WebSyncData.RefreshList()
	end)
	ui:Append("WndButton3","btn2", { x = 330, y = 630, txt = _L["Other data"] })
	:Click(function()
		ui:Fetch("btn1"):Enable(true)
		ui:Fetch("btn2"):Enable(false)
		_WebSyncData.RefreshList(true)
	end)
	ui:Append("WndButton3", { x = 480, y = 630, txt = _L["Close update notice"] })
	:Click(function()
		WebSyncData.tData = {}
		JH.Alert(g_tStrings.STR_MAIL_SUCCEED)
		_WebSyncData.RefreshList()
	end)
	ui:Append("WndButton3", { x = 630, y = 630, txt = g_tStrings.SEARCH })
	:Click(_WebSyncData.Search)
	ui:Append("WndButton3", { x = 780, y = 630, txt = _L["Access to personal data"] })
	:Click(_WebSyncData.GetData)
	ui:Point():RegisterClose(_WebSyncData.ClosePanel)
	_WebSyncData.Container = this:Lookup("PageSet_Menu/Page_FileDownload/WndScroll_FileDownload/WndContainer_FileDownload_List")
end

_WebSyncData.OpenPanel = function( ... )
	local f = Station.Lookup("Normal/WebSyncData") or Wnd.OpenWindow("Interface/JH/RaidGrid_EventScrutiny/ui/WebSyncData.ini", "WebSyncData")
	f:BringToTop()
	Station.SetActiveFrame(f)
	_WebSyncData.RefreshList( ... )
end

_WebSyncData.RefreshList = function(aid, title, author, dateline, md5)
	local nTime = GetCurrentTime()
	local t = TimeToDate(nTime)
	local szDate = t.year .. t.month .. t.day .. t.hour .. t.minute
	_WebSyncData.Container:Clear()
	_WebSyncData.tList = {}
	if aid and title and author and dateline and md5 then
		_WebSyncData.tResult = { aid = aid,title = JH.AscIIDecode(title),author = JH.AscIIDecode(author),dateline = dateline ,md5 = JH.AscIIDecode(md5)}
	else
		_WebSyncData.tResult = {}
	end
	_WebSyncData.SyncTip(_L["Loading..."], { 255, 255, 0 })
	local url = _WebSyncData.tUrl.szConfigList
	if type(aid) == "boolean" then
		url = _WebSyncData.tUrl.szConfigList2
	end
	local _, _, szLang = GetVersion()
	JH.RemoteRequest(url .. "?_" .. szDate .. "&lang=" .. szLang,function(szTitle,szDoc)
		local result,err = JH.JsonDecode(JH.UrlDecode(szDoc))
		if err then
			JH.Sysmsg2(err)
		else
			_WebSyncData.tData = result
			_WebSyncData.LoadData(_WebSyncData.tData)
			if not IsEmpty(_WebSyncData.tResult) then
				_WebSyncData.ItemRButtonClick(_WebSyncData.tResult, true)
			end
		end
	end)
end
_WebSyncData.ClosePanel = function()
	Wnd.CloseWindow(Station.Lookup("Normal/WebSyncData"))
	PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
	_WebSyncData.tData = {}
	_WebSyncData.tList = {}
end

-- format time
_WebSyncData.TimeToDate = function(nTime)
	local nNow = GetCurrentTime()
	local nTime = tonumber(nTime) or nNow
	local ndifference = nNow - nTime
	local fn = function(n)
		return string.format("%02d", n)
	end
	if ndifference < 60 then
		return _L["now"]
	elseif ndifference < 3600 then
		return _L("%d mins ago", ndifference / 60)
	elseif ndifference < 86400 then
		return _L("%d hours ago", ndifference / 3600)
	else
		return _L("%d days ago", ndifference / 86400)
	end
end


_WebSyncData.AppendItem = function(tData,aid,k)
	local wnd = _WebSyncData.Container:AppendContentFromIni("Interface/JH/RaidGrid_EventScrutiny/ui/Data_ListItem.ini", "WndWindow")
	local item = wnd:Lookup("","")
	if k % 2 == 0 then
		item:Lookup("Image_Line"):Hide()
	end
	
	if item then
		item.tData = tData
		item:Lookup("Text_Author"):SetText(tData.author)
		item:Lookup("Text_Title"):SetText(tData.title)
	
		local nTime = GetCurrentTime()
		local szDate = _WebSyncData.TimeToDate(tData.dateline)
		item:Lookup("Text_Download"):SetText(szDate)
		if (nTime - tData.dateline) < 86400 then
			item:Lookup("Text_Download"):SetFontColor(255,255,0)
		end
		
		item.OnItemMouseEnter = function()
			if not _WebSyncData.bSyncWebPage then
				item:Lookup("Image_CoverBg"):Show()
				local txt = this.tData.title .. " - " .. this.tData.downloads
				_WebSyncData.MenuTip(this, txt)
			end
		end
		item.OnItemMouseLeave = function()
			if not _WebSyncData.bSyncWebPage then
				item:Lookup("Image_CoverBg"):Hide()
			end
		end
		item.OnItemLButtonClick = function()
			if not _WebSyncData.bSyncWebPage then
				if _WebSyncData.tUnused then
					_WebSyncData.tUnused:Lookup("Image_Unused"):Hide()
				end
			end
			this:Lookup("Image_Unused"):Show()
			_WebSyncData.tUnused = this
		end

		if tData.color then
			item:Lookup("Text_Title"):SetFontColor("0x" .. string.sub(tData.color,0,2),"0x" .. string.sub(tData.color,2,4),"0x" .. string.sub(tData.color,4,6))
		end
		local btn = wnd:Lookup("WndButton")
		local btn2 = wnd:Lookup("WndButton2")
		btn.OnLButtonClick = function()
			_WebSyncData.ItemRButtonClick(tData, true)
		end
		btn2.OnLButtonClick = function()
			local url = "http://www.j3ui.com/#file/".. tData.tid
			if tData.url then
				url = "http://" .. tData.url
			end
			OpenInternetExplorer(url)
		end
		if tData.url then
			btn2:Lookup("","Text_Default2"):SetText(_L["details"])
			btn:Hide()
		end
		if WebSyncData.tData.aid and WebSyncData.tData.aid == tData.aid then
			item:Lookup("Text_Title"):SetFontColor(255,255,0)
			if WebSyncData.tData.md5 == tData.md5 then
				-- btn:Enable(false)
				btn:Lookup("","Text_Default"):SetText(_L["select"])
			else
				btn:Lookup("","Text_Default"):SetText(_L["update"])
				btn:Lookup("","Text_Default"):SetFontColor(255,255,0)
			end
		end
		
	end
end

_WebSyncData.LoadData = function(result)
	if not Station.Lookup("Normal/WebSyncData") then return end
	_WebSyncData.Container:Clear()
	_WebSyncData.tUnused = nil
	local k = 1
	if #_WebSyncData.key > 0 then
		for i = 1 , #_WebSyncData.key do
			_WebSyncData.AppendItem(_WebSyncData.key[i],_WebSyncData.key[i].aid,k)
			k = k + 1
			table.insert(_WebSyncData.tList,_WebSyncData.key[i])
		end
	end
	for i = 1 , #result["top"] do
		_WebSyncData.AppendItem(result["top"][i],result["top"][i].aid,k)
		k = k + 1
		table.insert(_WebSyncData.tList,result["top"][i])
	end
	for i = 1 , #result["usually"] do
		_WebSyncData.AppendItem(result["usually"][i],result["usually"][i].aid,k)
		k = k + 1
		table.insert(_WebSyncData.tList,result["usually"][i])
	end	
	_WebSyncData.Container:FormatAllContentPos()
	_WebSyncData.SyncTip(true)
end

WebSyncData.OnMouseLeave = function()
	HideTip()
end

_WebSyncData.MenuTip = function(hItem, text)
	if not hItem then return end
	local x, y = hItem:GetAbsPos()
	local w, h = hItem:GetSize()
	if text then
		local szXml = GetFormatText(text, 47, 255, 255, 255)
		OutputTip(szXml, 435, {x, y, w - 600, h})
	end
end
_WebSyncData.ItemRButtonClick = function(tData, bSync)
	HideTip()
	local self = tData
	local me = GetClientPlayer()
	if self.aid then
		local fnAction = function(tData)
			local wnd = GUI.CreateFrame("RGES_Data",{ w = 760,h = 300,title = _L["JH"] ,drag = true,close = true }):RegisterClose()
			tData.color = tData.color or "ffffff"
			wnd:Append("Text", { w = 685, h = 60, x = 0, y = 0, txt = tData.title, font = 40, multi = true, align = 1, color = { "0x" .. string.sub(tData.color,0,2),"0x" .. string.sub(tData.color,2,4),"0x" .. string.sub(tData.color,4,6) } })
			wnd:Append("Text", { w = 685, h = 30, x = 0, y = 65, txt = "By:" .. tData.author, font = 40, align = 1 })
			wnd:Append("WndButton3", { x = 145, y = 120, txt = _L["Cover data"] }):Click(function()
				WebSyncData.tData = tData
				RaidGrid_Base.LoadSettingsFileNew("sync_data_" .. tData.aid, true)
				if me.IsInParty() then JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "WebSyncTean","Load",tData.title) end
				_WebSyncData.LoadData(_WebSyncData.tData)
				wnd:CloseFrame()
			end)
			wnd:Append("WndButton3", { x = 400, y = 120, txt = _L["Merge data"] }):Click(function()
				WebSyncData.tData = {}
				RaidGrid_Base.LoadSettingsFileNew("sync_data_" .. tData.aid, false)
				if me.IsInParty() then JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "WebSyncTean","Load",tData.title) end
				_WebSyncData.LoadData(_WebSyncData.tData)
				wnd:CloseFrame()
			end)			
			_WebSyncData.SyncTip(true)
		end
		local fnSync = function()
			_WebSyncData.RemoteRequest(_WebSyncData.tUrl.szDownload, self, fnAction)
			_WebSyncData.SyncTip(_L["Loading..."], { 255, 255, 0 })
		end
		if bSync then
			fnSync()
		end
	end
end

_WebSyncData.RemoteRequest = function(szUrl, tData, fnAction)
	local _, _, szLang = GetVersion()
	JH.RemoteRequest(szUrl..tData.aid.. "?" .. tData.dateline .. "&lang=" .. szLang, function(szTitle, szDoc)
		local data = JH.JsonToTable(szDoc)
		local szFile = "Interface/JH/RaidGrid_EventScrutiny/alldat/sync_data_".. tData.aid .. ".jx3dat"
		pcall(SaveLUAData, szFile, data)
		pcall(fnAction, tData)
	end)
end

_WebSyncData.SyncTip = function(szText, col)
	local f = Station.Lookup("Normal/WebSyncData/WndWindow")
	if type(szText) == "boolean" and szText then
		_WebSyncData.bSyncWebPage = false
		f:Hide()
	else
		_WebSyncData.bSyncWebPage = true
		local t = f:Lookup("", "Text_Tips_Msg")
		t:SetText(szText)
		t:SetFontColor(unpack(col))
		f:Show()
	end
end


local UIProtect = {
	OpenPanel = _WebSyncData.OpenPanel,
}
setmetatable(WebSyncData, { __index = UIProtect, __metatable = true, __newindex = function() --[[ print("Protect") ]] end } )