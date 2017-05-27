-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Administrator
-- @Last Modified time: 2017-05-27 16:27:45
local _L = JH.LoadLangPack

DBM_RemoteRequest = {
	tData = {},
	bLogin = false,
}

JH.RegisterCustomData("DBM_RemoteRequest")
local ROOT_URL = "https://haimanchajian.com/" -- http://game.j3ui.com/"
-- local ROOT_URL = "http://10.0.20.20/"
local CLIENT_LANG = select(3, GetVersion())
local W = {
	szIniFile   = JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/DBM_RemoteRequest.ini",
	szFileList  = ROOT_URL .. "api/jx3/plugin-data/dbm?state=2",
	szFileList2 = ROOT_URL .. "api/jx3/plugin-data/dbm?state=1",
	szSearch    = ROOT_URL .. "api/jx3/plugin-data/dbm?kw=",
	szUser      = ROOT_URL .. "DBM/user/",
	szDownload  = ROOT_URL .. "down/json2/",
	szLoginUrl  = ROOT_URL .. "user/login/",
}

function W.GetFrame()
	return Station.Lookup("Normal/DBM_RemoteRequest")
end

W.IsOpened = W.GetFrame

-- 打开界面
function W.OpenPanel()
	local frame = W.GetFrame() or Wnd.OpenWindow(W.szIniFile, "DBM_RemoteRequest")
	frame:BringToTop()
	Station.SetActiveFrame(frame)
	W.RequestList()
	PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
	JH.RegisterGlobalEsc("DBM_RemoteRequest", W.IsOpened, W.ClosePanel)
end

function W.ClosePanel()
	Wnd.CloseWindow(W.GetFrame())
	PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
	W.Container = nil
	JH.RegisterGlobalEsc("DBM_RemoteRequest")
end

function W.TogglePanel()
	if W.IsOpened() then
		W.ClosePanel()
	else
		W.OpenPanel()
	end
end

function DBM_RemoteRequest.OnFrameCreate()
	local ui = GUI(this)
	if DBM_RemoteRequest.bLogin then
		JH.RemoteRequest(W.szLoginUrl .. "?_" .. GetCurrentTime() .. "&lang=" .. CLIENT_LANG, function(szTitle, szDoc)
			local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
			if result and result["status"] == 401 then
				return W.Logout()
			end
			if err then
				JH.Sysmsg2(_L["request failed"])
			else
				if result['username'] then
					ui:Append("Text", { x = 0, y = 50, w = 980, h = 30, align = 2, txt = result['username'], color = { 255, 255, 0 } })
				end
			end
		end)
	end
	ui:Append("WndButton3", { x = 30, y = 630, txt = _L["sync team"] })
	:Click(W.SyncTeam)
	ui:Append("WndButton3", { x = 180, y = 630, txt = _L["standard data"] })
	:Click(function()
		W.RequestList(W.szFileList)
	end)
	ui:Append("WndButton3", { x = 330, y = 630, txt = _L["Other data"] })
	:Click(function()
		W.RequestList(W.szFileList2)
	end)
	ui:Append("WndButton3", { x = 480, y = 630, txt = g_tStrings.SEARCH }):Click(W.Search)
	ui:Append("WndButton3", { x = 665, y = 630, txt = _L["My Data"] }):Enable(DBM_RemoteRequest.bLogin):Click(W.MyData)
	ui:Append("WndButton3", { x = 815, y = 630, txt = DBM_RemoteRequest.bLogin and _L["Logout"] or _L["Login Web Account"] }):Click(function()
		if not DBM_RemoteRequest.bLogin then
			W.Login()
		else
			W.Logout()
		end
	end)
	ui:Point():RegisterClose(W.ClosePanel)
	W.Container = this:Lookup("PageSet_Menu/Page_FileDownload/WndScroll_FileDownload/WndContainer_FileDownload_List")
end

function W.Login()
	return OpenInternetExplorer(ROOT_URL .. "jx3/plugin-data")
	--[[
	GetUserInput(_L["Enter User ID"], function(szNum)
		if not tonumber(szNum) then
			JH.Alert(_L["Please enter numbers"])
		else
			uid = tonumber(szNum)
			JH.DelayCall(function()
				GetUserInput(_L["Enter password"], function(szText)
					W.CallLogin(uid, szText)
				end)
			end)
		end
	end)
	--]]
end

function W.Logout()
	DBM_RemoteRequest.bLogin = false
	W.ClosePanel()
	W.OpenPanel()
end

function W.CallLogin(uid, pw, fnAction)
	-- web传参不安全 但是只能这样
	if string.len(pw) ~= 32 then
		pw = JH.MD5(pw)
	end

	JH.RemoteRequest(W.szLoginUrl .. "?_" .. GetCurrentTime() .. "&lang=" .. CLIENT_LANG .. "&username=" .. uid .. "&password=" .. pw, function(szTitle, szDoc)
		local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
		if err then
			JH.Sysmsg2(_L["request failed"])
		else
			JH.Debug("#DBM# LOGIN " .. result['uid'])
			if tonumber(result['uid']) > 0 then
				DBM_RemoteRequest.bLogin = true
				W.ClosePanel()
				W.OpenPanel()
				if fnAction then pcall(fnAction) end
			else
				W.Logout()
				JH.Alert(result["info"])
			end
		end
	end)
end

function W.MyData()
	JH.RemoteRequest(W.szLoginUrl .. "?_" .. GetCurrentTime() .. "&lang=" .. CLIENT_LANG, function(szTitle, szDoc)
		local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
		if err then
			JH.Sysmsg2(_L["request failed"])
		else
			if tonumber(result['uid']) > 0 then
				W.CallMyData()
			else
				DBM_RemoteRequest.bLogin = false
				W.ClosePanel()
				W.OpenPanel()
			end
		end
	end)
end

function W.CallMyData()
	W.Loading()
	local szCacheTime = FormatTime("%Y.%m.%d.%H.%M", GetCurrentTime()) -- 得益于IE缓存 1分钟一次
	JH.RemoteRequest(W.szUser .. "?_" .. szCacheTime .. "&lang=" .. CLIENT_LANG, function(szTitle, szDoc)
		local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
		if err then
			JH.Debug(err)
			JH.Sysmsg2(_L["request failed"])
		else
			W.ListCallBack(result)
		end
	end)
end

function W.Search()
	GetUserInput(_L["Enter thread ID"], function(szNum)
		if not tonumber(szNum) then
			JH.Alert(_L["Please enter numbers"])
		else
			W.RequestList(W.szSearch ..szNum)
		end
	end)
end

function W.Loading(szTitle)
	W.Container:Clear()
	W.AppendItem({ title = szTitle or "", author = "loading..." }, 1)
end

-- 列表请求
function W.RequestList(szUrl)
	szUrl = szUrl or W.szFileList
	W.Loading()
	JH.Curl({
		url = szUrl,
	})
	:done(function(szContent, dwBufferSize)
		local data = JH.JsonToTable(szContent)
		W.ListCallBack(data)
	end)
	:fail(function(errMsg, dwBufferSize)
		JH.Sysmsg2(_L["request failed"] .. errMsg)
	end)
end

function W.ListCallBack(result)
	if not W.IsOpened() then return end
	W.Container:Clear()
	W.UseData = nil

	if result.errcode and result.errcode ~= 0 then
		return JH.Alert(result.errmsg)
	end
	for k, v in ipairs(result) do
		v.tid = v.tid or v.id
		v.id = nil
		W.AppendItem(v, k)
	end
	if IsEmpty(result) then
		W.Loading("no result.")
	end
	--[[if result["msg"] then
		return JH.Alert(result["msg"])
	end
	for k, v in ipairs(result["data"]) do
		W.AppendItem(v, k)
	end
	--]]
	W.Container:FormatAllContentPos()
end

function W.TimeToDate(nTime)
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

function W.MenuTip(hItem, szXml)
	local x, y = hItem:GetAbsPos()
	local w, h = hItem:GetSize()
	OutputTip(szXml, 435, {x, y, w, h})
end

function W.AppendItem(data, k)
	local wnd = W.Container:AppendContentFromIni(JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/DBM_ITEM_RR.ini", "WndWindow")
	local item = wnd:Lookup("", "")
	if item then
		item.data = data
		item:Lookup("Text_Author"):SetText(data.author)
		item:Lookup("Text_Title"):SetText(data.title)
		if data.tid then
			local nTime = GetCurrentTime()
			local szDate = W.TimeToDate(data.dateline)
			item:Lookup("Text_Download"):SetText(szDate)
			if (nTime - data.dateline) < 3600 then
				item:Lookup("Text_Download"):SetFontColor(0, 255, 0)
			elseif (nTime - data.dateline) < 86400 then
				item:Lookup("Text_Download"):SetFontColor(255, 255, 0)
			end
			item.OnItemMouseEnter = function()
				item:Lookup("Image_Line"):SetFrame(8)
				local szXml = GetFormatText(data.author .. "\n", 47, 255, 255, 0)
				szXml = szXml ..GetFormatText(data.title, 47, 255, 255, 255)
				W.MenuTip(item:Lookup("Text_Author"), szXml)
			end
			item.OnItemMouseLeave = function()
				item:Lookup("Image_Line"):SetFrame(7)
				HideTip()
			end
			item.OnItemLButtonClick = function()
				if W.UseData then
					W.UseData:Lookup("Image_Unused"):Hide()
				end
				W.UseData = this
				this:Lookup("Image_Unused"):Show()
			end

			if data.color then
				item:Lookup("Text_Title"):SetFontColor(tonumber(string.sub(data.color, 0, 2), 16), tonumber(string.sub(data.color, 2, 4), 16), tonumber(string.sub(data.color, 4, 6), 16))
			end
			local btn = wnd:Lookup("WndButton")
			local btn2 = wnd:Lookup("WndButton2")
			btn:Enable(data.md5 ~= "")
			btn.OnLButtonClick = function()
				W.DoanloadData(data)
			end
			btn2.OnLButtonClick = function()
				local url = data.url or ROOT_URL .. "jx3/plugin-data/".. data.tid
				--[[
				local url = ROOT_URL .. "config/detail/".. data.tid
				if data.url then
					url = "http://" .. data.url
				end
				--]]
				OpenInternetExplorer(url)
			end
			if data.url then
				btn2:Lookup("", "Text_Default2"):SetText(_L["details"])
				btn:Hide()
			end
			if DBM_RemoteRequest.tData.tid and DBM_RemoteRequest.tData.tid == data.tid then
				item:Lookup("Text_Title"):SetFontColor(255, 255, 0)
				if DBM_RemoteRequest.tData.md5 == data.md5 then
					btn:Lookup("", "Text_Default"):SetText(_L["select"])
				else
					btn:Lookup("", "Text_Default"):SetText(_L["update"])
					btn:Lookup("", "Text_Default"):SetFontColor(255, 255, 0)
				end
			else
				btn:Lookup("", "Text_Default"):SetText(_L["Download"])
			end
		else
			wnd:Lookup("WndButton"):Hide()
			wnd:Lookup("WndButton2"):Hide()
		end
	end
end

function W.DoanloadData(data)
	if data.tid then
		-- 简单本地缓存一下
		local szPath = JH.GetAddonInfo().szRootPath .. "JH_DBM/data/"
		local szFileName = "DBM_Remote-" .. CLIENT_LANG .. "-" .. data.tid .. FormatTime("-%Y%m%d_%H.%M", data.dateline) .. ".jx3dat"
		W.CallDoanloadData(data, szPath, szFileName)
	end
end

function W.CallDoanloadData(data, szPath, szFileName)
	local function fnAction(szFile)
		DBM_UI.OpenImportPanel(szFile, data.title .. " - " .. data.author, function()
			DBM_RemoteRequest.tData = data
			local me = GetClientPlayer()
			-- if me.IsInParty() then JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "DBM_RemoteRequest", "Load", data.title) end
		end)
	end

	if IsFileExist(szPath .. szFileName) then -- 本地文件存在则优先
		fnAction(szFileName)
	else -- 否则 remote request
		JH.Topmsg(_L["Loading..., please wait."])
		JH.Curl({
			type = "get",
			url = ROOT_URL .. "jx3/plugin-data/" .. data.tid .. "/get?lang=" .. CLIENT_LANG .. "&cdn=url",
		}):done(function(szContent)
			JH.Debug("#DBM# download url: " .. szContent)
			JH.Curl({
				type = "get",
				charset = "",
				url = szContent,
			}):done(function(szContent)
				JH.Debug("#DBM# download size: " .. string.len(szContent))
				Log(szPath .. szFileName .. ".log", szContent, "close")
				CPath.Move(szPath .. szFileName .. ".log", szPath .. szFileName)
				fnAction(szFileName)
			end):fail(function(errMsg, dwBufferSize, set)
				JH.Sysmsg2(_L["request failed"] .. errMsg)
			end)
		end)	:fail(function(errMsg, dwBufferSize, set)
			JH.Sysmsg2(_L["request failed"] .. errMsg)
		end)
		--[[
		JH.Curl({
			url = W.szDownload .. data.tid .. "/" .. data.md5,
			data = {
				lang = CLIENT_LANG
			},
		})
		:done(function(szContent, dwBufferSize, set)
			local tab = JH.JsonToTable(szContent)
			if not tab then
				JH.SaveLUAData("log/error/err_" .. data.tid, err)
				return JH.Alert(_L["update failed! Please try again."])
			end
			if CLIENT_LANG == "zhcn" then
				tab = JH.ConvertToAnsi(tab)
			end
			SaveLUAData(szPath .. szFileName, tab, nil, false) -- 缓存文件
			fnAction(szFileName)
		end)
		:fail(function(errMsg, dwBufferSize, set)
			JH.Sysmsg2(_L["request failed"] .. errMsg)
		end)
		--]]
	end
end

function W.SyncTeam()
	if not W.UseData then
		return JH.Alert(g_tStrings.MSG_CHOOSE_FILE_EMPTY)
	end
	local me = GetClientPlayer()
	if not me.IsInParty() then
		return JH.Alert(_L["You are not in the team."])
	end
	if me.GetScene().nType == MAP_TYPE.BATTLE_FIELD then
		return JH.Alert(g_tStrings.STR_REMOTE_NOT_TIP)
	end
	if not JH.IsLeader() and not JH.bDebugClient then
		return JH.Alert(_L["You are not team leader."])
	end
	JH.Confirm(_L["Confirm?"], function()
		local t = W.UseData.data
		JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "DBM_RemoteRequest", "WebSyncTean", t)
	end)
end

JH.RegisterBgMsg("DBM_RemoteRequest", function(nChannel, dwID, szName, data, bIsSelf)
	if data[1] == "WebSyncTean" then
		local t = data[2]
		JH.Confirm(_L("Team leader request download: %s", t.title .. " - " .. t.author), function()
			W.DoanloadData(t)
		end)
	elseif data[1] == "Load" then
		JH.Sysmsg(_L("%s use %s data", szName, data[2]))
	end
end)

local UIProtect = {
	TogglePanel = W.TogglePanel,
}
setmetatable(DBM_RemoteRequest, { __index = UIProtect, __metatable = true, __newindex = function() --[[ print("Protect") ]] end } )
