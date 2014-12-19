local _L = JH.LoadLangPack
WebSyncData = {
	tData = {}, --以后实现自动更新用
}
RegisterCustomData("WebSyncData.tData")

local _WebSyncData = {
	tResult = {},
	key = {},
	tList = {},
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
	GetUserInput("输入aid或者作者名字或者部分标题",function(txt)
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
			JH.Alert("没有搜索结果。")
		end
	end)	
end

_WebSyncData.GetData = function()
	local fnAction = function(szText)
		if szText ~= "" then
			_WebSyncData.SyncTip(_L["Loading..."],{255,255,0})
			local szUrl = _WebSyncData.tUrl.szKeyUrl.. szText .. "&_".. GetCurrentTime()
			JH.RemoteRequest(szUrl,function(szTitle,szDoc)
				local result,err = JH.JsonDecode(JH.UrlDecode(szDoc))
				if not result then
					_WebSyncData.SyncTip(true)
					return JH.Sysmsg2(err)
				else
				-- c 418524171f9f757d9dde6a40aef60e85
					_WebSyncData.SyncTip(true)
					table.insert(_WebSyncData.key,result)
					_WebSyncData.RefreshList()
				end
			end)
		end
	end
	GetUserInput("请输入文件MD5（网站能看）",fnAction)
end

_WebSyncData.SyncTeam = function()
	if _WebSyncData.bSyncWebPage then
		return
	end
	if not _WebSyncData.tUnused then
		return JH.Alert("请选择一个数据在执行操作")
	end
	local me = GetClientPlayer()
	if not me.IsInParty() then
		return JH.Alert("你没有组队。")
	end
	local team = GetClientTeam()
	local szLeader = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER))
	if szLeader ~= me.szName then
		return JH.Alert("你不是团长。")
	end
	JH.Confirm("确定同步吗？（请先提前通知队友）！",function()
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
			JH.Sysmsg(arg3 .." 使用了：" .. data[2], "团队数据")
		end
	end
end)

WebSyncData.OnFrameCreate = function()
	local ui = GUI(this)
	ui:Append("WndButton3", { x = 30, y = 630, txt = "同步给全团" })
	:Click(_WebSyncData.SyncTeam)
	ui:Append("WndButton3", { x = 180, y = 630, txt = "推荐数据" })
	:Click(_WebSyncData.RefreshList)
	ui:Append("WndButton3", { x = 330, y = 630, txt = "其他数据" })
	:Click(function()
		_WebSyncData.RefreshList(true)
	end)
	ui:Append("WndButton3", { x = 480, y = 630, txt = "关闭更新通知" })
	:Click(function()
		WebSyncData.tData = {}
		JH.Sysmsg("在下次选择数据之前，不会再提示了。")
		_WebSyncData.RefreshList()
	end)
	ui:Append("WndButton3", { x = 630, y = 630, txt = "搜索" })
	:Click(_WebSyncData.Search)
	ui:Append("WndButton3", { x = 780, y = 630, txt = "获取私密数据" })
	:Click(_WebSyncData.GetData)
	ui:Point():Close(_WebSyncData.ClosePanel)
	_WebSyncData.Container = this:Lookup("PageSet_Menu/Page_FileDownload/WndScroll_FileDownload/WndContainer_FileDownload_List")
end

_WebSyncData.OpenPanel = function( ... )
	local f = Station.Lookup("Normal/WebSyncData") or Wnd.OpenWindow("Interface/JH/RaidGrid_EventScrutiny/ui/WebSyncData.ini", "WebSyncData")
	f:BringToTop()
	Station.SetActiveFrame(f)
	_WebSyncData.RefreshList( ... )
end

_WebSyncData.RefreshList = function(aid, title, author, dateline, md5)
	-- if not _WebSyncData.bSyncWebPage then
		_WebSyncData.tUnused = nil
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
		JH.RemoteRequest(url .. "?_" .. szDate,function(szTitle,szDoc)
			local result,err = JH.JsonDecode(JH.UrlDecode(szDoc))
			if err then
				JH.Sysmsg2(err)
			else
				_WebSyncData.LoadData(result)
				if not IsEmpty(_WebSyncData.tResult) then
					_WebSyncData.ItemRButtonClick(_WebSyncData.tResult, true)
				end
			end
		end)
	-- end
end

_WebSyncData.ClosePanel = function()
	Wnd.CloseWindow(Station.Lookup("Normal/WebSyncData"))
	PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
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
		return "刚刚"
	elseif ndifference < 3600 then
		return string.format("%d分钟前", ndifference / 60)
	elseif ndifference < 86400 then
		return string.format("%d小时前", ndifference / 3600)
	else
		return string.format("%d天前", ndifference / 86400)
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
				local txt = "标题：" .. this.tData.title .. "\n"
				txt = txt .. "作者：" .. this.tData.author .. "\n"
				txt = txt .. "更新时间：" .. _WebSyncData.TimeToDate(this.tData.dateline) .. "\n"
				txt = txt .. "下载次数：" .. this.tData.downloads
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
			btn2:Lookup("","Text_Default2"):SetText("查看详情")
			btn:Hide()
		end
		if WebSyncData.tData.aid and WebSyncData.tData.aid == tData.aid then
			item:Lookup("Text_Title"):SetFontColor(255,255,0)
			if WebSyncData.tData.md5 == tData.md5 then
				btn:Enable(false)
				btn:Lookup("","Text_Default"):SetText("使用中")
			else
				btn:Lookup("","Text_Default"):SetText("有更新")
				btn:Lookup("","Text_Default"):SetFontColor(255,255,0)
				JH.Confirm("《剑网3》团队事件监控 数据更新提示\n检查到当前使用的数据有更新 是否更新？\n新数据："..tData.title .. "\n这是数据作者（" .. tData.author .."）推送的更新,如果不想接收请点击关闭更新。",function()
					_WebSyncData.ItemRButtonClick(tData, true)
				end)
			end
		end
		
	end
end


_WebSyncData.LoadData = function(result)
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
			local szText = GetFormatText("      《剑网3》团队事件监控 数据更新提示\n",167,255,255,255)
			szText = szText..GetFormatText("      数据：".. tData.title .."\n",16)
			local msg = {
				szMessage = szText,
				bRichText = true,
				szName = "RaidGrid_Base_tRecordsClearNew",
				{szOption = "覆盖导入", fnAction = function()
					WebSyncData.tData = tData
					RaidGrid_Base.LoadSettingsFileNew("sync_data_" .. tData.aid, true)
					if me.IsInParty() then JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "WebSyncTean","Load",tData.title) end
					_WebSyncData.RefreshList()
				end},
				{szOption = "合并导入", fnAction = function()
					WebSyncData.tData = tData
					RaidGrid_Base.LoadSettingsFileNew("sync_data_"..tData.aid, false)
					if me.IsInParty() then JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "WebSyncTean","Load",tData.title) end
					_WebSyncData.RefreshList()
				end},
				{szOption = "取消"},
			}
			MessageBox(msg)
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
	JH.RemoteRequest(szUrl..tData.aid.. "?" .. tData.dateline,function(szTitle,szDoc)
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
		local t = f:Lookup("","Text_Tips_Msg")
		t:SetText(szText)
		t:SetFontColor(unpack(col))
		f:Show()
	end
end


local UIProtect = {
	OpenPanel = _WebSyncData.OpenPanel,
}
setmetatable(WebSyncData, { __index = UIProtect, __metatable = true, __newindex = function() --[[ print("Protect") ]] end } )