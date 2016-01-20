-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-01-20 09:34:06

-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
local ipairs, pairs, next, pcall = ipairs, pairs, next, pcall
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local ssub, slen, schar, srep, sbyte, sformat, sgsub =
      string.sub, string.len, string.char, string.rep, string.byte, string.format, string.gsub
local type, tonumber, tostring = type, tonumber, tostring
local GetTime, GetLogicFrameCount = GetTime, GetLogicFrameCount
local floor, mmin, mmax, mceil = math.floor, math.min, math.max, math.ceil
local GetClientPlayer, GetPlayer, GetNpc, GetClientTeam, UI_GetClientPlayerID = GetClientPlayer, GetPlayer, GetNpc, GetClientTeam, UI_GetClientPlayerID
local setmetatable = setmetatable

local ROOT_PATH   = "interface/JH/0Base/"
local DATA_PATH   = "interface/JH/@DATA/"
local SHADOW_PATH = "interface/JH/0Base/item/shadow.ini"
local ADDON_PATH  = "interface/JH/"
local _VERSION_   = 0x1020400

---------------------------------------------------------------------
-- 多语言处理
---------------------------------------------------------------------
local function GetLang()
	local _, _, szLang = GetVersion()
	local t0 = LoadLUAData(ROOT_PATH .. "lang/default.jx3dat") or {}
	local t1 = LoadLUAData(ROOT_PATH .. "lang/" .. szLang .. ".jx3dat") or {}
	for k, v in pairs(t0) do
		if not t1[k] then
			t1[k] = v
		end
	end
	t1.__import = function(szPath)
		local t2 = LoadLUAData(szPath .. "/" .. szLang .. ".jx3dat") or {}
		for k, v in pairs(t2) do
			t1[k] = v
		end
	end
	local mt = {
		__index = function(t, k) return k end,
		__call = function(t, k, ...) return sformat(t[k] or k, ...) end,
	}
	setmetatable(t1, mt)
	return t1
end
local _L = GetLang()

---------------------------------------------------------------------
-- 插件开始
---------------------------------------------------------------------
JH = {
	bDebug       = false, -- debug
	bDebugClient = false, -- 测试客户端版本
	nChannel     = PLAYER_TALK_CHANNEL.RAID, -- JH.Talk默认频道
	LoadLangPack = _L,
}
RegisterCustomData("JH.bDebug")
RegisterCustomData("JH.nChannel") -- 方便debug切到TONG

do
	local exp = { GetVersion() }
	if exp then
		if exp[4] == "exp" or exp[4] == "bvt" then -- 体服和内网 默认开启了DEBUG
			JH.bDebug = true
			OutputMessage("MSG_SYS", " [-- JH --] test client, enable debug mode!\n")
			OutputMessage("MSG_SYS", " [-- JH --] client version " .. exp[2] .. "\n")
			OutputMessage("MSG_SYS", " [-- JH --] client tag " .. exp[4] .. "\n")
		end
	end
end

local _JH = {
	szBuildDate  = "20160114",
	szTitle      = _L["JH, JX3 Plug-in Collection"],
	tHotkey      = {},
	tAnchor      = {},
	tDelayCall   = {},
	tRequest     = {},
	tGlobalValue = {},
	tConflict    = {},
	tEvent       = {},
	tBgMsgHandle = {},
	tModule      = {},
	szShort      = _L["JH"],
	nDebug       = 2,
	tBuffCache   = {},
	tSkillCache  = {},
	tMapCache    = {},
	tItemCache   = {},
	tDungeonList = {},
	tMapList     = {},
	aPlayer      = {},
	aNpc         = {},
	aDoodad      = {},
	tBreatheCall = {},
	tItem        = { {}, {}, {} },
	tOption      = { szOption = _L["JH Plugin"] },
	tOption2     = { szOption = _L["JH Plugin"] },
	tClass       = { _L["General"], _L["Other"] },
	szIniFile    = ROOT_PATH .. "JH.ini",
}

local JH = JH
-- parse emotion in talking message
function _JH.ParseFaceIcon(t)
	if not _JH.tFaceIcon then
		_JH.tFaceIcon = {}
		for i = 1, g_tTable.FaceIcon:GetRowCount() do
			local tLine = g_tTable.FaceIcon:GetRow(i)
			_JH.tFaceIcon[tLine.szCommand] = tLine.dwID
		end
	end
	local t2 = {}
	for _, v in ipairs(t) do
		if v.type ~= "text" then
			if v.type == "emotion" then
				v.type = "text"
			end
			tinsert(t2, v)
		else
			local nOff, nLen = 1, slen(v.text)
			while nOff <= nLen do
				local szFace, dwFaceID = nil, nil
				local nPos = StringFindW(v.text, "#", nOff)
				if not nPos then
					nPos = nLen
				else
					for i = nPos + 7, nPos + 2, -1 do
						if i <= nLen then
							local szTest = ssub(v.text, nPos, i)
							if _JH.tFaceIcon[szTest] then
								szFace, dwFaceID = szTest, _JH.tFaceIcon[szTest]
								nPos = nPos - 1
								break
							end
						end
					end
				end
				if nPos >= nOff then
					tinsert(t2, { type = "text", text = ssub(v.text, nOff, nPos) })
					nOff = nPos + 1
				end
				if szFace and dwFaceID then
					tinsert(t2, { type = "emotion", text = szFace, id = dwFaceID })
					nOff = nOff + slen(szFace)
				end
			end
		end
	end
	return t2
end

-------------------------------------
-- 设置面板开关、初始化
-------------------------------------
function JH.OpenPanel(szTitle)
	_JH.OpenPanel()
	if szTitle then
		local nClass, nItem = 0, 0
		for k, v in ipairs(_JH.tItem) do
			if _JH.tClass[k] == szTitle then
				nClass = k
				break
			end
			for kk, vv in ipairs(v) do
				if vv.szTitle == szTitle then
					nClass, nItem = k, kk
				end
			end
		end
		if nClass ~= 0 then
			GUI.Fetch(_JH.frame, "TabBox_" .. nClass):Check(true)
			if nItem ~= 0 then
				GUI.Fetch(_JH.hList, "Button_" .. nItem):Click()
			end
		end
	end
end

-- open
function _JH.OpenPanel()
	local frame = Station.Lookup("Normal/JH")
	if frame then
		PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
		frame:Show()
		frame:BringToTop()
		local win = GUI(_JH.frame:Lookup("Wnd_Detail"))
		if win.___data then
			local i, data = unpack(win.___data)
			_JH.UpdateDetail(i, data)
		end
	else
		frame = Wnd.OpenWindow(_JH.szIniFile, "JH")
	end
	return frame
end

-- close
function _JH.ClosePanel(bDisable)
	local frame = Station.Lookup("Normal/JH")
	if frame then
		frame:Hide()
		local win = GUI(frame:Lookup("Wnd_Detail"))
		if win.fnDestroy then
			win.fnDestroy(win)
		end
		if not bDisable then
			PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
		end
	end
end

-- toggle
function _JH.TogglePanel()
	if _JH.frame and _JH.frame:IsVisible() then
		_JH.ClosePanel()
	else
		_JH.OpenPanel()
	end
end

function _JH.IsPanelOpened()
	return _JH.frame and _JH.frame:IsVisible()
end

JH.ClosePanel  = _JH.ClosePanel
JH.TogglePanel = _JH.TogglePanel

-- register conflict checker
function _JH.RegisterConflictCheck(fnAction)
	_JH.tConflict = _JH.tConflict or {}
	tinsert(_JH.tConflict, fnAction)
end

-------------------------------------
-- 更新设置面板界面
-------------------------------------

-- updae detail content
function _JH.UpdateDetail(i, data)
	local win = GUI.Fetch(_JH.frame, "Wnd_Detail")
	if win then win:Remove() end
	if not data then
		data = {}
		if JH_About then
			if not i then	-- default
				data.fn = {
					OnPanelActive = JH_About.OnPanelActive,
					GetAuthorInfo = JH_About.GetAuthorInfo,
				}
			elseif JH_About.OnTaboxCheck then	-- switch
				data.fn = {
					OnPanelActive = function(frame)
						JH_About.OnTaboxCheck(frame, i, _JH.tClass[i])
						-- PlaySound(SOUND.UI_SOUND, g_sound.Mail)
					end,
					GetAuthorInfo = JH_About.GetAuthorInfo
				}
			end
		end
	end
	win = GUI.Append(_JH.frame, "WndActionWindow", "Wnd_Detail")
	win:Size(_JH.hContent:GetSize()):Pos(_JH.hContent:GetRelPos())
	if type(data.fn) == "table" then
		local szInfo = ""
		if data.fn.GetAuthorInfo then
			szInfo = "-- by " .. data.fn.GetAuthorInfo() .. " --"
		end
		_JH.hTotal:Lookup("Text_Author"):SetText(szInfo)
		if data.fn.OnPanelActive then
			data.fn.OnPanelActive(win:Raw())
			win.___data = { i, data }
			win.handle:FormatAllItemPos()
		end
		win.fnDestroy = data.fn.OnPanelDeactive
	end
end

-- create menu item
function _JH.NewListItem(i, data, dwClass)
	local handle = _JH.hList
	local item = GUI.Append(handle, "BoxButton", "Button_" .. i)
	item:Icon(data.dwIcon):Text(data.szTitle):Click(function()
		_JH.UpdateDetail(dwClass, data)
	end, true, true)
	return item
end

-- update menu list
function _JH.UpdateListInfo(nIndex)
	local nX, nY = 0, 2 -- 预留2
	_JH.hList:Clear()
	_JH.UpdateDetail(nIndex)
	for k, v in ipairs(_JH.tItem[nIndex]) do
		local item = _JH.NewListItem(k, v, nIndex)
		item:Pos(nX, nY)
		nY = nY + 55
	end
end

-- update tab list
function _JH.UpdateTabBox(frame)
	local nX, nY, first = 25, 52, nil
	for k, v in ipairs(_JH.tClass) do
		if table.getn(_JH.tItem[k]) > 0 then
			local tab = frame:Lookup("TabBox_" .. k)
			if not tab then
				tab = GUI.Append(frame, "WndTabBox", "TabBox_" .. k, { group = "Nav" })
			else
				tab = GUI.Fetch(tab)
			end
			tab:Text(v):Pos(nX, nY):Click(function(bChecked)
				if bChecked then
					_JH.UpdateListInfo(k)
				end
			end):Check(false)
			if not first then
				first = tab
			end
			local nW, _ = tab:Size()
			nX = nX + mceil(nW) + 10
		end
	end
	if first then
		first:Check(true)
	end
end

function _JH.EventHandler(szEvent)
	local tEvent = _JH.tEvent[szEvent]
	if tEvent then
		for k, v in pairs(tEvent) do
			local res, err = pcall(v, szEvent)
			if not res then
				JH.Debug("EVENT#" .. szEvent .. "." .. k .." ERROR: " .. err)
			end
		end
	end
end

function _JH.UpdateAnchor(frame)
	local a = _JH.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

function JH.OnFrameCreate()
	-- var
	_JH.frame    = this
	_JH.hTotal   = this:Lookup("Wnd_Content", "")
	_JH.hList    = this:Lookup("Wnd_Content/WndScroll_List", "")
	_JH.hContent = _JH.hTotal:Lookup("Handle_Content")
	_JH.hBox     = _JH.hTotal:Lookup("Box_1")
	-- title
	local szTitle = _JH.szTitle .. " v" ..  JH.GetVersion() .. " (" .. _JH.szBuildDate .. ")"
	local ui = GUI(this)
	-- Text_Title
	ui:Title(szTitle):Point()
	ui:Append("WndButton4", { x = 670, y = 52, txt = g_tStrings.BUG_SUBMIT }):Click(function()
		OpenInternetExplorer("http://www.diaochapai.com/survey1592748")
	end)
	this:RegisterEvent("UI_SCALED")
	-- update list/detail
	_JH.UpdateTabBox(this)
end

function JH.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		_JH.UpdateAnchor(this)
	end
end

function JH.OnFrameDragEnd()
	_JH.tAnchor = GetFrameAnchor(this)
end

function JH.OnFrameBreathe()
	-- run breathe calls
	local nFrame = GetLogicFrameCount()
	for k, v in pairs(_JH.tBreatheCall) do
		if nFrame >= v.nNext then
			v.nNext = nFrame + v.nFrame
			local res, err = pcall(v.fnAction)
			if not res then
				JH.Debug("BreatheCall#" .. k .." ERROR: " .. err)
			end
		end
	end
	local nTime = GetTime()
	for k = #_JH.tDelayCall, 1, -1 do
		local v = _JH.tDelayCall[k]
		if v.nTime <= nTime then
			local res, err = pcall(v.fnAction)
			if not res then
				JH.Debug("DelayCall#" .. k .." ERROR: " .. err)
			end
			tremove(_JH.tDelayCall, k)
		end
	end
	-- run remote request (10s)
	if not _JH.nRequestExpire or _JH.nRequestExpire < nTime then
		if _JH.nRequestExpire then
			local r = tremove(_JH.tRequest, 1)
			if r then
				pcall(r.fnAction)
			end
			_JH.nRequestExpire = nil
		end
		if #_JH.tRequest > 0 then
			local page = Station.Lookup("Normal/JH/Page_1")
			if page then
				page:Navigate(_JH.tRequest[1].szUrl)
			end
			_JH.nRequestExpire = GetTime() + 15000
		end
	end
end

function JH.OnDocumentComplete()
	local r = tremove(_JH.tRequest, 1)
	if r then
		_JH.nRequestExpire = nil
		pcall(r.fnAction, this:GetLocationName(), this:GetDocument())
	end
end
-- button click
function JH.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Close" then
		_JH.ClosePanel()
	end
end
--------------------------------------- * 常用函数 * ---------------------------------------

-- (void) JH.SetHotKey()               -- 打开快捷键设置面板
-- (void) JH.SetHotKey(string szGroup) -- 打开快捷键设置面板并定位到 szGroup 分组（不可用）
function JH.SetHotKey(szGroup)
	HotkeyPanel_Open(szGroup or _JH.szTitle)
end
-- (string, number) JH.GetVersion() -- 获取插件版本号
function JH.GetVersion()
	local v = _VERSION_
	local szVersion = sformat("%d.%d.%d", v/0x1000000,
		floor(v/0x10000)%0x100, floor(v/0x100)%0x100)
	if  v%0x100 ~= 0 then
		szVersion = szVersion .. "b" .. tostring(v%0x100)
	end
	return szVersion, v
end
-- (table) JH.GetAddonInfo() -- 获取插件基础信息
function JH.GetAddonInfo()
	return {
		szName      = _JH.szTitle,
		szVersion   = JH.GetVersion(),
		szRootPath  = ADDON_PATH,
		szAuthor    = _L['JH @ Double Dream Town'],
		szShadowIni = SHADOW_PATH,
		szDataPath  = DATA_PATH,
		szBuildDate = _JH.szBuildDate,
	}
end

local function JH_GetNpcName(dwTemplateID)
	local szName = Table_GetNpcTemplateName(dwTemplateID)
	if JH.Trim(szName) == "" then
		szName = tostring(dwTemplateID)
	end
	return szName
end
-- (string) JH.GetTemplateName(KObject KObject[, boolean bEmployer])  -- 获取或格式化NPC对象真实名称
-- (string) JH.GetTemplateName(number KObject[, boolean bEmployer])
function JH.GetTemplateName(KObject, bEmployer)
	if type(KObject) == "userdata" then
		local szName
		if IsPlayer(KObject.dwID) then
			return KObject.szName
		else
			szName = JH_GetNpcName(KObject.dwTemplateID)
		end
		if bEmployer and KObject.dwEmployer ~= 0 then
			local emp = GetPlayer(KObject.dwEmployer)
			if not emp then
				szName =  g_tStrings.STR_SOME_BODY .. g_tStrings.STR_PET_SKILL_LOG .. szName
			else
				if KObject.szName == "" then
					szName = emp.szName
				else
					szName = emp.szName .. g_tStrings.STR_PET_SKILL_LOG .. szName
				end
			end
		end
		return szName
	else
		return JH_GetNpcName(KObject)
	end
end
-- 注册事件，和系统的区别在于可以指定一个 KEY 防止多次加载
-- (void) JH.RegisterEvent(string szEvent, func fnAction[, string szKey])
-- szEvent		-- 事件，可在后面加一个点并紧跟一个标识字符串用于防止重复或取消绑定，如 LOADING_END.xxx
-- fnAction		-- 事件处理函数，arg0 ~ arg9，传入 nil 相当于取消该事件
--特别注意：当 fnAction 为 nil 并且 szKey 也为 nil 时会取消所有通过本函数注册的事件处理器
function JH.RegisterEvent(szEvent, fnAction)
	local szKey = nil
	local nPos = StringFindW(szEvent, ".")
	if nPos then
		szKey = ssub(szEvent, nPos + 1)
		szEvent = ssub(szEvent, 1, nPos - 1)
	end
	if not _JH.tEvent[szEvent] then
		_JH.tEvent[szEvent] = {}
		RegisterEvent(szEvent, function() _JH.EventHandler(szEvent) end)
	end
	local tEvent = _JH.tEvent[szEvent]
	if fnAction then
		if not szKey then
			tinsert(tEvent, fnAction)
		else
			tEvent[szKey] = fnAction
		end
	else
		if not szKey then
			_JH.tEvent[szEvent] = {}
		else
			tEvent[szKey] = nil
		end
	end
end
-- 取消事件处理函数
-- (void) JH.UnRegisterEvent(string szEvent)
function JH.UnRegisterEvent(szEvent)
	JH.RegisterEvent(szEvent, nil)
end
-- 注册用户定义数据，支持全局变量数组遍历
-- (void) JH.RegisterCustomData(string szVarPath[, number nVersion])
function JH.RegisterCustomData(szVarPath, nVersion, szDomain)
	szDomain = szDomain or "Role"
	if _G and type(_G[szVarPath]) == "table" then
		for k, _ in pairs(_G[szVarPath]) do
			RegisterCustomData(szDomain .. "/" .. szVarPath .. "." .. k, nVersion)
		end
	else
		RegisterCustomData(szDomain .. "/" .. szVarPath, nVersion)
	end
end
-- 开发函数 修改全局变量
function JH.SetGlobalValue(szVarPath, Val)
	local t = JH.Split(szVarPath, ".")
	local tab = _G
	for k, v in ipairs(t) do
		if type(tab[v]) == "nil" then
			tab[v] = {}
		end
		if k == #t then
			tab[v] = Val
		end
		tab = tab[v]
	end
end
-- 开发函数 CallGlobalFun
function JH.CallGlobalFun(funname, ...)
	if not string.find(funname, ".") then
		return _G[funname](...)
	end
	local t = JH.Split(funname, ".")
	local len = #t
	if len == 2 then
		return _G[t[1]][t[2]](...)
	end
	local fun = _G
	for k, v in ipairs(t) do
		if fun[v] then
			fun = fun[v]
		else
			return
		end
	end
	if fun then
		return fun(...)
	end
end
-- 初始化一个模块
function JH.RegisterInit(key, ...)
	local events = { ... }
	if _JH.tModule[key] and IsEmpty(events) then
		for k, v in ipairs(_JH.tModule[key]) do
			if v[1] == "Breathe" then
				JH.UnBreatheCall(key)
			else
				JH.UnRegisterEvent(sformat("%s.%s", v[1], key))
			end
		end
		_JH.tModule[key] = nil
		JH.Debug2("UnInit # "  .. key)
	elseif #events > 0 then
		_JH.tModule[key] = events
		for k, v in ipairs(_JH.tModule[key]) do
			if v[1] == "Breathe" then
				JH.BreatheCall(key, v[2], v[3] or nil)
			else
				JH.RegisterEvent(sformat("%s.%s", v[1], key), v[2])
			end
		end
		JH.Debug2("Init # "  .. key .. " # Events # " .. #_JH.tModule[key])
	end
end

function JH.UnRegisterInit(key)
	JH.RegisterInit(key)
end

function JH.RegisterExit(fnAction)
	JH.RegisterEvent("PLAYER_EXIT_GAME", fnAction)
	JH.RegisterEvent("GAME_EXIT", fnAction)
	JH.RegisterEvent("RELOAD_UI_ADDON_BEGIN", fnAction)
end

function JH.RegisterBgMsg(szKey, fnAction)
	_JH.tBgMsgHandle[szKey] = fnAction
end

function JH.GetForceColor(dwForce)
	return unpack(JH_FORCE_COLOR[dwForce])
end

function JH.CanTalk(nChannel)
	for _, v in ipairs({"WHISPER", "TEAM", "RAID", "BATTLE_FIELD", "NEARBY", "TONG", "TONG_ALLIANCE" }) do
		if nChannel == PLAYER_TALK_CHANNEL[v] then
			return true
		end
	end
	return false
end

function JH.SwitchChat(nChannel)
	local szHeader = JH_TALK_CHANNEL_HEADER[nChannel]
	if szHeader then
		SwitchChatChannel(szHeader)
	elseif type(nChannel) == "string" then
		SwitchChatChannel("/w " .. nChannel .. " ")
	end
end

function JH.Talk(nChannel, szText, szUUID, bNoEmotion, bSaveDeny, bNotLimit)
	local szTarget, me = "", GetClientPlayer()
	-- channel
	if not nChannel then
		nChannel = JH.nChannel
	elseif type(nChannel) == "string" then
		if not szText then
			szText = nChannel
			nChannel = JH.nChannel
		elseif type(szText) == "number" then
			szText, nChannel = nChannel, szText
		else
			szTarget = nChannel
			nChannel = PLAYER_TALK_CHANNEL.WHISPER
		end
	elseif nChannel == PLAYER_TALK_CHANNEL.RAID and me.GetScene().nType == MAP_TYPE.BATTLE_FIELD then
		nChannel = PLAYER_TALK_CHANNEL.BATTLE_FIELD
	elseif type(nChannel) == "table" then
		szText = nChannel
		nChannel = JH.nChannel
	end
	if nChannel == PLAYER_TALK_CHANNEL.RAID and not me.IsInParty() then
		return
	end
	-- say body
	local tSay = nil
	if type(szText) == "table" then
		tSay = szText
	else
		local tar = JH.GetTarget(me.GetTarget())
		szText = sgsub(szText, "%$zj", me.szName)
		if tar then
			szText = sgsub(szText, "%$mb", tar.szName)
		end
		if wstring.len(szText) > 150 and not bNotLimit then
			szText = wstring.sub(szText, 1, 150)
		end
		tSay = {{ type = "text", text = szText .. "\n"}}
	end
	if not bNoEmotion then
		tSay = _JH.ParseFaceIcon(tSay)
	end
	-- add addon msg header
	if not tSay[1] or (
		not (tSay[1].type == "eventlink" and tSay[1].name == "BG_CHANNEL_MSG") -- bgmsg
 		and not (tSay[1].name == "" and tSay[1].type == "eventlink") -- header already added
 	) then
		tinsert(tSay, 1, {
			type = "eventlink",
			name = "",
			linkinfo = JH.JsonEncode({
				via = "JH",
				uuid = szUUID and tostring(szUUID),
			}),
		})
	end
	if bSaveDeny and not JH.CanTalk(nChannel) then
		local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
		edit:ClearText()
		for _, v in ipairs(tSay) do
			if v.type == "text" then
				edit:InsertText(v.text)
			else
				edit:InsertObj(v.text, v)
			end
		end
		-- change to this channel
		JH.SwitchChat(nChannel)
	else
		me.Talk(nChannel, szTarget, tSay)
	end
end

function JH.Talk2(nChannel, szText, szUUID, bNoEmotion)
	JH.Talk(nChannel, szText, szUUID, bNoEmotion, true)
end

function JH.BgTalk(nChannel, szKey, ...)
	local tSay = { { type = "eventlink", name = "BG_CHANNEL_MSG", linkinfo = szKey } }
	local tArg = { ... }
	for _, v in ipairs(tArg) do
		tinsert(tSay, { type = "eventlink", name = "", linkinfo = var2str(v) })
	end
	JH.Talk(nChannel, tSay, nil, true)
end

function JH.BgHear(szKey, bIgnore)
	local me = GetClientPlayer()
	local tSay = me.GetTalkData()
	if tSay and (arg0 ~= me.dwID or bIgnore) and #tSay > 1 and (tSay[1].text == _L["Addon comm."] or tSay[1].text == "BG_CHANNEL_MSG") and tSay[2].type == "eventlink" then
		local tData, nOff = {}, 2
		if szKey then
			if tSay[nOff].linkinfo ~= szKey then
				return nil
			end
			nOff = nOff + 1
		end
		for i = nOff, #tSay do
			tinsert(tData, tSay[i].linkinfo)
		end
		return tData
	end
end

function JH.CanUseSkill(dwSkillID, dwLevel)
	local me, box = GetClientPlayer(), _JH.hBox
	if me and box then
		if not dwLevel then
			if dwSkillID ~= 9007 then
				dwLevel = me.GetSkillLevel(dwSkillID)
			else
				dwLevel = 1
			end
		end
		if dwLevel > 0 then
			box:EnableObject(false)
			box:SetObjectCoolDown(1)
			box:SetObject(UI_OBJECT_SKILL, dwSkillID, dwLevel)
			UpdataSkillCDProgress(me, box)
			return box:IsObjectEnable() and not box:IsObjectCoolDown()
		end
	end
	return false
end

function JH.IsParty(dwID)
	return GetClientPlayer().IsPlayerInMyParty(dwID)
end

function JH.GetAllPlayer(nLimit)
	local aPlayer = {}
	for k, _ in pairs(_JH.aPlayer) do
		local p = GetPlayer(k)
		if not p then
			_JH.aPlayer[k] = nil
		elseif p.szName ~= "" then
			tinsert(aPlayer, p)
			if nLimit and #aPlayer == nLimit then
				break
			end
		end
	end
	return aPlayer
end

function JH.GetAllPlayerID()
	return _JH.aPlayer
end

function JH.GetAllNpc(nLimit)
	local aNpc = {}
	for k, _ in pairs(_JH.aNpc) do
		local p = GetNpc(k)
		if not p then
			_JH.aNpc[k] = nil
		else
			tinsert(aNpc, p)
			if nLimit and #aNpc == nLimit then
				break
			end
		end
	end
	return aNpc
end

function JH.GetAllNpcID()
	return _JH.aNpc
end

function JH.GetAllDoodad(nLimit)
	local aDoodad = {}
	for k, _ in pairs(_JH.aDoodad) do
		local p = GetDoodad(k)
		if not p then
			_JH.aDoodad[k] = nil
		else
			tinsert(aDoodad, p)
			if nLimit and #aDoodad == nLimit then
				break
			end
		end
	end
	return aDoodad
end

function JH.GetAllDoodadID()
	return _JH.aDoodad
end

function JH.GetDistance(nX, nY, nZ)
	local me = GetClientPlayer()
	if not nY and not nZ then
		local tar = nX
		nX, nY, nZ = tar.nX, tar.nY, tar.nZ
	elseif not nZ then
		return floor(((me.nX - nX) ^ 2 + (me.nY - nY) ^ 2) ^ 0.5)/64
	end
	return floor(((me.nX - nX) ^ 2 + (me.nY - nY) ^ 2 + (me.nZ/8 - nZ/8) ^ 2) ^ 0.5)/64
end

function JH.GetAllMap()
	local tList, tMap = {}, {}
	for k, v in ipairs(GetMapList()) do
		local szName = Table_GetMapName(v)
		if not tMap[szName] then
			tMap[szName] = true
			tinsert(tList, 1, szName)
		end
	end
	return tList
end

-- 判断一个地图是不是副本
-- (bool) JH.IsDungeonMap(dwMapID, bType)
function JH.IsDungeon(dwMapID, bType)
	if bType then
		return select(2, GetMapParams(dwMapID)) == MAP_TYPE.DUNGEON
	else
		if IsEmpty(_JH.tDungeonList) then
			for k, v in ipairs(GetMapList()) do
				local a = g_tTable.DungeonInfo:Search(v)
				if a and a.dwClassID == 3 then
					_JH.tDungeonList[a.dwMapID] = true
				end
			end
		end
		return _JH.tDungeonList[dwMapID] or false
	end
end

-- 获取主角当前所在地图
-- JH.GetMapID(bool bFix) 是否做修正
function JH.GetMapID(bFix)
	local dwMapID = GetClientPlayer().GetMapID()
	if not bFix then
		return dwMapID
	else
		return JH_MAP_NAME_FIX[dwMapID] or dwMapID
	end
end

-- 判断是不是副本地图
function JH.IsInDungeon(bType)
	local me = GetClientPlayer()
	local dwMapID = me.GetMapID()
	return JH.IsDungeon(dwMapID, bType)
end

-- JJC地图
function JH.IsInArena()
	local me = GetClientPlayer()
	local dwMapID = me.GetMapID()
	local nMapType = select(2, GetMapParams(dwMapID))
	return nMapType and nMapType == MAP_TYPE.BATTLE_FIELD
end

function JH.IsMapExist(param)
	if not _JH.tMapList[-1] then
		local tMapListByID   = {
			[-1] = g_tStrings.CHANNEL_COMMON,
			[-9] = _L["recycle bin"],
		}
		local tMapListByName = {
			[g_tStrings.CHANNEL_COMMON] = -1,
			[_L["recycle bin"]]         = -9,
		}
		for k, v in ipairs(GetMapList()) do
			if not JH_MAP_NAME_FIX[v] then
				local szName           = Table_GetMapName(v)
				tMapListByID[v]        = szName
				tMapListByName[szName] = v
			end
		end
		setmetatable(_JH.tMapList, { __index = function(me, k)
			if tonumber(k) then
				if JH_MAP_NAME_FIX[k] then
					k = JH_MAP_NAME_FIX[k]
				end
				return tMapListByID[k]
			else
				return tMapListByName[k]
			end
		end })
	end
	return _JH.tMapList[param]
end

function JH.IsInParty()
	local me = GetClientPlayer()
	return me and me.IsInParty()
end



function JH.JsonToTable(szJson)
	local result, err = JH.JsonDecode(JH.UrlDecode(szJson))
	if err then
		JH.Debug(err)
		return false, err
	end
	if type(result) ~= "table" then
		return false, "data is invalid"
	end
	local data = {}
	local function Key2Num(data, tab)
		for k, v in pairs(tab) do
			local key = tonumber(k) or k
			data[key] = {}
			if type(v) == "table" then
				Key2Num(data[key], v)
			else
				data[key] = v
			end
		end
	end
	Key2Num(data, result)
	return data, nil
end

-- 输出一条密聊信息
function JH.OutputWhisper(szMsg, szHead)
	szHead = szHead or _JH.szShort
	OutputMessage("MSG_WHISPER", "[" .. szHead .. "]" .. g_tStrings.STR_TALK_HEAD_WHISPER .. szMsg .. "\n")
	PlaySound(SOUND.UI_SOUND, g_sound.Whisper)
end
-- 没有头的中央信息 也可以用于系统信息
function JH.Topmsg(szText, szType)
	OutputMessage(szType or "MSG_ANNOUNCE_YELLOW", szText .. "\n")
end

function JH.Sysmsg(szMsg, szHead, szType)
	szHead = szHead or _JH.szShort
	szType = szType or "MSG_SYS"
	OutputMessage(szType, "[" .. szHead .. "] " .. szMsg .. "\n")
end
-- err message
function JH.Sysmsg2(szMsg, szHead, col)
	szHead = szHead or _JH.szShort
	local r, g, b = 255, 0, 0
	if col then r, g, b = unpack(col) end
	OutputMessage("MSG_SYS", "[" .. szHead .. "] " .. szMsg .. "\n", false, 10, { r, g, b })
end

function JH.Debug(szMsg, szHead, nLevel)
	nLevel = nLevel or 1
	if JH.bDebug and _JH.nDebug >= nLevel then
		if nLevel == 3 then szMsg = "### " .. szMsg
		elseif nLevel == 2 then szMsg = "=== " .. szMsg
		else szMsg = "-- " .. szMsg end
		JH.Sysmsg(szMsg, szHead)
	end
end
function JH.Debug2(szMsg, szHead) JH.Debug(szMsg, szHead, 2) end
function JH.Debug3(szMsg, szHead) JH.Debug(szMsg, szHead, 3) end

function JH.Alert(szMsg, fnAction, szSure)
	local nW, nH = Station.GetClientSize()
	local tMsg = {
		x = nW / 2, y = nH / 3, szMessage = szMsg, szName = "JH_Alert", szAlignment = "CENTER",
		{
			szOption = szSure or g_tStrings.STR_HOTKEY_SURE,
			fnAction = fnAction,
		},
	}
	MessageBox(tMsg)
end

function JH.Confirm(szMsg, fnAction, fnCancel, szSure, szCancel)
	local nW, nH = Station.GetClientSize()
	local tMsg = {
		x = nW / 2, y = nH / 3, szMessage = szMsg, szName = "JH_Confirm", szAlignment = "CENTER",
		{
			szOption = szSure or g_tStrings.STR_HOTKEY_SURE,
			fnAction = fnAction,
		}, {
			szOption = szCancel or g_tStrings.STR_HOTKEY_CANCEL,
			fnAction = fnCancel,
		},
	}
	MessageBox(tMsg)
end

function JH.RegisterGlobalEsc(szID, fnCondition, fnAction, bTopmost)
	if fnCondition and fnAction then
		RegisterGlobalEsc("JH_" .. szID, fnCondition, fnAction, bTopmost)
	else
		UnRegisterGlobalEsc("JH_" .. szID, bTopmost)
	end
end

-- 选代器 倒序
local function fnBpairs(tab, nIndex)
	nIndex = nIndex - 1
	if nIndex > 0 then
		return nIndex, tab[nIndex]
	end
end

function JH.bpairs(tab)
	return fnBpairs, tab, #tab + 1
end

function JH.UpdateItemBoxExtend(box, nQuality)
	local szImage = "ui/Image/Common/Box.UITex"
	local nFrame
	if nQuality == 2 then
		nFrame = 13
	elseif nQuality == 3 then
		nFrame = 12
	elseif nQuality == 4 then
		nFrame = 14
	elseif nQuality == 5 then
		nFrame = 17
	end
	box:ClearExtentImage()
	box:ClearExtentAnimate()
	if nFrame and nQuality < 5 then
		box:SetExtentImage(szImage, nFrame)
	elseif nQuality == 5 then
		box:SetExtentAnimate(szImage, nFrame, -1)
	end
end

function JH.GetEndTime(nEndFrame)
	return (nEndFrame - GetLogicFrameCount()) / GLOBAL.GAME_FPS
end

function JH.GetBuffName(dwBuffID, dwLevel)
	local xKey = dwBuffID
	if dwLevel then
		xKey = dwBuffID .. "_" .. dwLevel
	end
	if not _JH.tBuffCache[xKey] then
		local tLine = Table_GetBuff(dwBuffID, dwLevel or 1)
		if tLine then
			_JH.tBuffCache[xKey] = { tLine.szName, tLine.dwIconID }
		else
			local szName = "BUFF#" .. dwBuffID
			if dwLevel then
				szName = szName .. ":" .. dwLevel
			end
			_JH.tBuffCache[xKey] = { szName, 1436 }
		end
	end
	return unpack(_JH.tBuffCache[xKey])
end

function JH.GetSkillName(dwSkillID, dwLevel)
	if not _JH.tSkillCache[dwSkillID] then
		local tLine = Table_GetSkill(dwSkillID, dwLevel)
		if tLine and tLine.dwSkillID > 0 and tLine.bShow
			and (StringFindW(tLine.szDesc, "_") == nil  or StringFindW(tLine.szDesc, "<") ~= nil)
		then
			_JH.tSkillCache[dwSkillID] = { tLine.szName, tLine.dwIconID }
		else
			local szName = "SKILL#" .. dwSkillID
			if dwLevel then
				szName = szName .. ":" .. dwLevel
			end
			_JH.tSkillCache[dwSkillID] = { szName, 1435 }
		end
	end
	return unpack(_JH.tSkillCache[dwSkillID])
end

function JH.GetItemName(nUiId)
	if not _JH.tItemCache[nUiId] then
		local szName = Table_GetItemName(nUiId)
		local nIcon = Table_GetItemIconID(nUiId)
		if szName ~= "" and nIocn ~= -1 then
			_JH.tItemCache[nUiId] = { szName, nIcon }
		else
			_JH.tItemCache[nUiId] = { "ITEM#" .. nUiId, 1435 }
		end
	end
	return unpack(_JH.tItemCache[nUiId])
end

function JH.GetMapName(dwMapID)
	if not _JH.tMapCache[dwMapID] then
		local szName = Table_GetMapName(dwMapID)
		if szName ~= "" then
			_JH.tMapCache[dwMapID] = tostring(dwMapID)
		else
			_JH.tMapCache[dwMapID] = szName
		end
	end
	return _JH.tMapCache[dwMapID]
end

-- 根据 dwType 类型和 dwID 设置目标
-- (void) JH.SetTarget([number dwType, ]number dwID)
-- dwType	-- *可选* 目标类型
-- dwID		-- 目标 ID
function JH.SetTarget(dwType, dwID)
	if not dwType or dwType <= 0 then
		dwType, dwID = TARGET.NO_TARGET, 0
	elseif not dwID then
		dwID, dwType = dwType, TARGET.NPC
		if IsPlayer(dwID) then
			dwType = TARGET.PLAYER
		end
	end
	SetTarget(dwType, dwID)
end

-- 根据BUFF ID 或者 KBUFF 对象 如不传 nLevel 或 nLevel 等于0 代表忽略 nLevel
-- (KBUFF) HM.GetBuff(dwBuffID, [nLevel[, KObject me]])
-- (KBUFF) HM.GetBuff(tBuff, [nLevel[, KObject me]])
-- KBUFF_LIST_NODE
-- DECLARE_LUA_CLASS(KBUFF_LIST_NODE);
-- DECLARE_LUA_STRUCT_INTEGER(Index, nIndex);
-- DECLARE_LUA_STRUCT_INTEGER(StackNum, nStackNum);
-- DECLARE_LUA_STRUCT_INTEGER(NextActiveFrame, nNextActiveFrame);
-- DECLARE_LUA_STRUCT_INTEGER(LeftActiveCount, nLeftActiveCount);
-- DECLARE_LUA_STRUCT_DWORD(SkillSrcID, dwSkillSrcID);
-- DECLARE_LUA_STRUCT_BOOL(Validity, bValidity);
-- int LuaGetIntervalFrame(Lua_State* L);
-- int LuaGetEndTime(Lua_State* L);
function JH.GetBuff(dwID, nLevel, KObject)
	local tBuff = {}
	if type(dwID) == "table" then
		tBuff = dwID
	elseif type(dwID) == "number" then
		if type(nLevel) == "number" then
			tBuff[dwID] = nLevel
		else
			tBuff[dwID] = 0
		end
	end
	if type(nLevel) == "userdata" then
		KObject = nLevel
	else
		KObject = KObject or GetClientPlayer()
	end
	for k, v in pairs(tBuff) do
		local KBuff = KObject.GetBuff(k, v)
		if KBuff then
			return KBuff
		end
	end
end
function JH.CancelBuff( ... )
	local tBuff = JH.GetBuff( ... )
	if tBuff then
		return GetClientPlayer().CancelBuff(tBuff.nIndex)
	end
end
-- 格式化时间字符串
function JH.FormatTimeString(nSec, nStyle, bDefault)
	nSec = nSec > 0 and nSec or 0
	if nStyle == 1 then
		if bDefault then
			nSec = nSec < 5999 and nSec or 5999
		end
		if nSec > 60 then
			return floor(nSec / 60) .. "'" .. floor(nSec % 60) .. "\""
		else
			return floor(nSec) .. "\""
		end
	else
		local h, m, s = "h", "m", "s"
		if nStyle == 2 then
			h, m, s = g_tStrings.STR_TIME_HOUR, g_tStrings.STR_TIME_MINUTE, g_tStrings.STR_TIME_SECOND
		end
		if nSec > 3600 then
			return floor(nSec / 3600) .. h .. floor(nSec / 60) % 60  .. m .. floor(nSec % 60) .. s
		elseif nSec > 60 then
			return floor(nSec / 60) .. m .. floor(nSec % 60) .. s
		else
			return floor(nSec) .. s
		end
	end
end

function JH.GetBuffList(tar)
	tar = tar or GetClientPlayer()
	local aBuff = {}
	local nCount = tar.GetBuffCount()
	for i = 1, nCount, 1 do
		local dwID, nLevel, bCanCancel, nEndFrame, nIndex, nStackNum, dwSkillSrcID, bValid = tar.GetBuff(i - 1)
		if dwID then
			tinsert(aBuff, {
				dwID = dwID, nLevel = nLevel, bCanCancel = bCanCancel, nEndFrame = nEndFrame,
				nIndex = nIndex, nStackNum = nStackNum, dwSkillSrcID = dwSkillSrcID, bValid = bValid,
				nCount = i
			})
		end
	end
	return aBuff
end

function JH.WalkAllBuff(tar, fnAction)
	if type(tar) == "function" then
		fnAction = tar
		tar = GetClientPlayer()
	end
	local nCount = tar.GetBuffCount()
	for i = 1, nCount, 1 do
		local dwID, nLevel, bCanCancel, nEndFrame, nIndex, nStackNum, dwSkillSrcID, bValid = tar.GetBuff(i - 1)
		if dwID then
			local res, ret = pcall(fnAction, dwID, nLevel, bCanCancel, nEndFrame, nIndex, nStackNum, dwSkillSrcID, bValid)
			if res == true and ret == false then
				break
			end
		end
	end
end

function JH.SaveLUAData(szPath, ...)
	local nTime = GetTime()
	SaveLUAData(DATA_PATH .. szPath, ...)
	JH.Debug3(_L["SaveLUAData # "] ..  DATA_PATH .. szPath .. " " .. GetTime() - nTime .. "ms")
end

function JH.LoadLUAData(szPath)
	local nTime = GetTime()
	local data = LoadLUAData(DATA_PATH .. szPath)
	JH.Debug3(_L["LoadLUAData # "] ..  DATA_PATH .. szPath .. " " .. GetTime() - nTime .. "ms")
	return data
end

function JH.IsMark()
	return GetClientTeam().GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK) == UI_GetClientPlayerID()
end

function JH.IsLeader()
	return GetClientTeam().GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) == UI_GetClientPlayerID()
end

function JH.IsDistributer()
	return GetClientTeam().GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) == UI_GetClientPlayerID()
end

function JH.RemoteRequest(szUrl, fnAction)
	tinsert(_JH.tRequest, { szUrl = szUrl, fnAction = fnAction })
end

function JH.DelayCall(fnAction, nDelay)
	if not nDelay then
		if #_JH.tDelayCall > 0 then
			if _JH.tDelayCall[#_JH.tDelayCall].fnAction == fnAction then
				return JH.Debug("Ignore DelayCall " .. tostring(fnAction))
			end
		end
		nDelay = 0
	end
	tinsert(_JH.tDelayCall, { nTime = nDelay + GetTime(), fnAction = fnAction })
end

function JH.Split(szFull, szSep)
	local nOff, tResult = 1, {}
	while true do
		local nEnd = StringFindW(szFull, szSep, nOff)
		if not nEnd then
			tinsert(tResult, ssub(szFull, nOff, slen(szFull)))
			break
		else
			tinsert(tResult, ssub(szFull, nOff, nEnd - 1))
			nOff = nEnd + slen(szSep)
		end
	end
	return tResult
end

function JH.DoMessageBox(szName, i)
	local frame = Station.Lookup("Topmost2/MB_" .. szName) or Station.Lookup("Topmost/MB_" .. szName)
	if frame then
		i = i or 1
		local btn = frame:Lookup("Wnd_All/Btn_Option" .. i)
		if btn and btn:IsEnabled() then
			if btn.fnAction then
				if frame.args then
					btn.fnAction(unpack(frame.args))
				else
					btn.fnAction()
				end
			elseif frame.fnAction then
				if frame.args then
					frame.fnAction(i, unpack(frame.args))
				else
					frame.fnAction(i)
				end
			end
			frame.OnFrameDestroy = nil
			CloseMessageBox(szName)
		end
	end
end

function JH.BreatheCall(szKey, fnAction, nTime)
	local key = StringLowerW(szKey)
	if type(fnAction) == "function" then
		local nFrame = 1
		if nTime and nTime > 0 then
			nFrame = mceil(nTime / 62.5)
		end
		_JH.tBreatheCall[key] = { fnAction = fnAction, nNext = GetLogicFrameCount() + 1, nFrame = nFrame }
		JH.Debug3("BreatheCall # " .. szKey .. " # " .. nFrame)
	else
		_JH.tBreatheCall[key] = nil
		JH.Debug3("UnBreatheCall # " .. szKey)
	end
end

function JH.UnBreatheCall(szKey)
	JH.BreatheCall(szKey)
end

function JH.AddHotKey(szName, szTitle, fnAction)
	if ssub(szName, 1, 3) ~= "JH_" then
		szName = "JH_" .. szName
	end
	tinsert(_JH.tHotkey, { szName = szName, szTitle = szTitle, fnAction = fnAction })
end
-- (KObject) JH.GetTarget() -- 取得当前目标操作对象
-- (KObject) JH.GetTarget([number dwType, ]number dwID)	-- 根据 dwType 类型和 dwID 取得操作对象
function JH.GetTarget(dwType, dwID)
	if not dwType then
		local me = GetClientPlayer()
		if me then
			dwType, dwID = me.GetTarget()
		else
			dwType, dwID = TARGET.NO_TARGET, 0
		end
	elseif not dwID then
		dwID, dwType = dwType, TARGET.NPC
		if IsPlayer(dwID) then
			dwType = TARGET.PLAYER
		end
	end
	if dwID <= 0 or dwType == TARGET.NO_TARGET then
		return nil, TARGET.NO_TARGET
	elseif dwType == TARGET.PLAYER then
		return GetPlayer(dwID), TARGET.PLAYER
	elseif dwType == TARGET.DOODAD then
		return GetDoodad(dwID), TARGET.DOODAD
	else
		return GetNpc(dwID), TARGET.NPC
	end
end

function _JH.GetMainMenu()
	return {
		szOption = _L["JH Plugin"],
		fnAction = _JH.TogglePanel,
		bCheck = true,
		bChecked = _JH.frame:IsVisible(),
		szIcon = 'ui/Image/UICommon/CommonPanel2.UITex',
		nFrame = 105, nMouseOverFrame = 106,
		szLayer = "ICON_RIGHT",
		fnClickIcon = _JH.TogglePanel
	}
end

function _JH.GetPlayerAddonMenu()
	local menu = _JH.GetMainMenu()
	tinsert(menu, { szOption = _L["JH Plugin"] .. " v" .. JH.GetVersion(), bDisable = true })
	tinsert(menu, { bDevide = true })
	tinsert(menu, { szOption = _L["Open JH Panel"], fnAction = _JH.TogglePanel })
	tinsert(menu, { bDevide = true })
	for k, v in ipairs(_JH.tOption) do
		if type(v) == "function" then
			tinsert(menu, v())
		else
			tinsert(menu, v)
		end
	end
	if JH.bDebugClient then
		tinsert(menu, { bDevide = true })
		tinsert(menu, { szOption = "ReloadUIAddon", fnAction = function()
			ReloadUIAddon()
		end })
		tinsert(menu, { bDevide = true })
		tinsert(menu, { szOption = "Enable Debug mode", bCheck = true, bChecked = JH.bDebug, fnAction = function()
			JH.bDebug = not JH.bDebug
		end })
	end
	if JH.bDebug then
		tinsert(menu, { bDevide = true })
		tinsert(menu, { szOption = "Debug Level 1", bMCheck = true, bChecked = _JH.nDebug == 1, fnAction = function()
			_JH.nDebug = 1
		end })
		tinsert(menu, { szOption = "Debug Level 2", bMCheck = true, bChecked = _JH.nDebug == 2, fnAction = function()
			_JH.nDebug = 2
		end })
		tinsert(menu, { szOption = "Debug Level 3", bMCheck = true, bChecked = _JH.nDebug == 3, fnAction = function()
			_JH.nDebug = 3
		end })
		tinsert(menu, { bDevide = true })
		tinsert(menu, { szOption = "Talk Debug Channel",
			{ szOption = g_tStrings.tChannelName["MSG_TEAM"], rgb = GetMsgFontColor("MSG_TEAM", true), bMCheck = true ,bChecked = JH.nChannel == PLAYER_TALK_CHANNEL.RAID, fnAction = function()
				JH.nChannel = PLAYER_TALK_CHANNEL.RAID
			end },
			{ szOption = g_tStrings.tChannelName["MSG_GUILD"], rgb = GetMsgFontColor("MSG_GUILD", true), bMCheck = true ,bChecked = JH.nChannel == PLAYER_TALK_CHANNEL.TONG, fnAction = function()
				JH.nChannel = PLAYER_TALK_CHANNEL.TONG
			end },
		})
	end
	return { menu }
end

function _JH.GetAddonMenu()
	local menu = _JH.GetMainMenu()
	tinsert(menu,{ szOption = _L["JH Plugin"] .. " v" .. JH.GetVersion(), bDisable = true })
	tinsert(menu,{ bDevide = true })
	for _, v in ipairs(_JH.tOption2) do
		if type(v) == "function" then
			tinsert(menu, v())
		else
			tinsert(menu, v)
		end
	end
	return { menu }
end
-- 注册玩家头像的插件菜单
function JH.PlayerAddonMenu(tMenu)
	tinsert(_JH.tOption, tMenu)
end
-- 注册右上角的扳手菜单
function JH.AddonMenu(tMenu)
	tinsert(_JH.tOption2, tMenu)
end
-- 管理全部shadow的容器 这样可以防止前后顺序覆盖
function JH.GetShadowHandle(szName)
	local sh = Station.Lookup("Lowest/JH_Shadows") or Wnd.OpenWindow(ROOT_PATH .. "item/JH_Shadows.ini", "JH_Shadows")
	if not sh:Lookup("", szName) then
		sh:Lookup("", ""):AppendItemFromString(sformat("<handle> name=\"%s\" </handle>", szName))
	end
	JH.Debug3("Create sh # " .. szName)
	return sh:Lookup("", szName)
end
JH.GetPlayerAddonMenu = _JH.GetPlayerAddonMenu
JH.RegisterEvent("PLAYER_ENTER_GAME", function()
	_JH.OpenPanel():Hide()
	-- _JH.tGlobalValue = JH.LoadLUAData("config/userdata.jx3dat") or {}
	-- 注册快捷键
	Hotkey.AddBinding("JH_Total", _L["JH Plugin"], _JH.szTitle, _JH.TogglePanel , nil)
	for _, v in ipairs(_JH.tHotkey) do
		Hotkey.AddBinding(v.szName, v.szTitle, "", v.fnAction, nil)
	end
	-- 注册玩家头像菜单
	Player_AppendAddonMenu({ _JH.GetPlayerAddonMenu })
	-- 注册右上角菜单
	TraceButton_AppendAddonMenu({ _JH.GetAddonMenu })
	JH.RegisterGlobalEsc("JH", _JH.IsPanelOpened, _JH.ClosePanel)
end)

JH.RegisterEvent("LOADING_END", function()
	-- reseting frame count (FIXED BUG FOR Cross Server)
	for k, v in pairs(_JH.tBreatheCall) do
		v.nNext = GetLogicFrameCount()
	end
	for k, v in pairs(_JH.tGlobalValue) do
		JH.SetGlobalValue(k, v)
		_JH.tGlobalValue[k] = nil
	end
end)
JH.RegisterEvent("FIRST_LOADING_END", function()
	JH.Sysmsg(_L("%s are welcome to use JH plug-in", GetClientPlayer().szName) .. "! v" .. JH.GetVersion() )
end)
-- szKey, nChannel, dwID, szName, aTable
JH.RegisterEvent("ON_BG_CHANNEL_MSG", function()
	if _JH.tBgMsgHandle[arg0] then
		local res, err = pcall(_JH.tBgMsgHandle[arg0], arg1, arg2, arg3, arg4, arg2 == UI_GetClientPlayerID())
		if not res then
			JH.Debug("BG_MSG#" .. arg0 .. "# ERROR:" .. err)
		end
	end
end)

JH.RegisterEvent("PLAYER_ENTER_SCENE", function() _JH.aPlayer[arg0] = true end)
JH.RegisterEvent("PLAYER_LEAVE_SCENE", function() _JH.aPlayer[arg0] = nil  end)
JH.RegisterEvent("NPC_ENTER_SCENE",    function() _JH.aNpc[arg0]    = true end)
JH.RegisterEvent("NPC_LEAVE_SCENE",    function() _JH.aNpc[arg0]    = nil  end)
JH.RegisterEvent("DOODAD_ENTER_SCENE", function() _JH.aDoodad[arg0] = true end)
JH.RegisterEvent("DOODAD_LEAVE_SCENE", function() _JH.aDoodad[arg0] = nil  end)
-- 字符串类
function JH.Trim(szText)
	if not szText or szText == "" then
		return ""
	end
	return (sgsub(szText, "^%s*(.-)%s*$", "%1"))
end

local function get_urlencode(c)
	return sformat("%%%02X", sbyte(c))
end
function JH.UrlEncode(szText)
	local str = szText:gsub("([^0-9a-zA-Z ])", get_urlencode)
	str = str:gsub(" ", "+")
	return str
end

local function get_urldecode(h)
	return schar(tonumber(h, 16))
end
function JH.UrlDecode(szText)
	return szText:gsub("+", " "):gsub("%%(%x%x)", get_urldecode)
end

local function get_asciiencode(s)
	return sformat("%02x", s:byte())
end
function JH.AscIIEncode(szText)
	return szText:gsub('(.)', get_asciiencode)
end

local function get_asciidecode(s)
	return schar(tonumber(s, 16))
end
function JH.AscIIDecode(szText)
	return szText:gsub('(%x%x)', get_asciidecode)
end

-- 临时选择集中处理
local JH_TAR_TEMP
local JH_TAR_TEMP_STATUS = false

JH.RegisterEvent("JH_TAR_TEMP_UPDATE", function()
	JH_TAR_TEMP = arg0
end)

function JH.SetTempTarget(dwMemberID, bEnter)
	if JH_TAR_TEMP_STATUS == bEnter then -- 防止偶尔UIBUG
		return
	end
	JH_TAR_TEMP_STATUS = bEnter
	local dwType, dwID = Target_GetTargetData()
	if bEnter then
		JH_TAR_TEMP = dwID
		if dwMemberID ~= dwID then
			JH.SetTarget(dwMemberID)
		end
	else
		JH.SetTarget(JH_TAR_TEMP)
	end
end

-- Output
function JH.OutputNpcTip(dwNpcTemplateID, Rect)
	local npc = GetNpcTemplate(dwNpcTemplateID)
	if not npc then
		return
	end
	local szName = JH.GetTemplateName(dwNpcTemplateID)
	local t = {}
	tinsert(t, GetFormatText(szName .. "\n", 80, 255, 255, 0))
		-------------等级----------------------------
	if npc.nLevel - GetClientPlayer().nLevel > 10 then
		tinsert(t, GetFormatText(g_tStrings.STR_PLAYER_H_UNKNOWN_LEVEL, 82))
	else
		tinsert(t, GetFormatText(FormatString(g_tStrings.STR_NPC_H_WHAT_LEVEL, npc.nLevel), 0))
	end
	------------模版ID-----------------------
	tinsert(t, GetFormatText(FormatString(g_tStrings.TIP_TEMPLATE_ID_NPC_INTENSITY, npc.dwTemplateID, npc.nIntensity or 1), 101))

	OutputTip(tconcat(t), 345, Rect)
end

function JH.OutputDoodadTip(dwTemplateID, Rect)
	local doodad = GetDoodadTemplate(dwTemplateID)
	if not doodad then
		return
	end
	local t = {}
	--------------名字-------------------------
	local szName = doodad.szName ~= "" and doodad.szName or dwTemplateID
	if doodad.nKind == DOODAD_KIND.CORPSE then
		szName = szName .. g_tStrings.STR_DOODAD_CORPSE
	end
	tinsert(t, GetFormatText(szName .. "\n", 65))
	tinsert(t, GetDoodadQuestTip(dwTemplateID))
	------------模版ID-----------------------
	tinsert(t, GetFormatText(FormatString(g_tStrings.TIP_TEMPLATE_ID, doodad.dwTemplateID), 101))
	if IsCtrlKeyDown() then
		tinsert(t, GetFormatText(FormatString(g_tStrings.TIP_REPRESENTID_ID, doodad.dwRepresentID), 102))
	end
	if doodad.nKind == DOODAD_KIND.GUIDE then
		local x, y = Cursor.GetPos()
		w, h = 40, 40
		Rect = {x, y, w, h}
	end
	OutputTip(tconcat(t), 300, Rect)
end

local XML_LINE_BREAKER = GetFormatText("\n")
function JH.OutputBuffTip(dwID, nLevel, Rect, nTime)
	local t, tab = {}, {}
	local szName = Table_GetBuffName(dwID, nLevel)
	if szName == "" then
		szName = g_tStrings.STR_HOTKEY_HIDE
	end
	tinsert(t, GetFormatText(szName .. "\t", 65))
	local buffInfo = GetBuffInfo(dwID, nLevel, {})
	if buffInfo and buffInfo.nDetachType and g_tStrings.tBuffDetachType[buffInfo.nDetachType] then
		tinsert(t, GetFormatText(g_tStrings.tBuffDetachType[buffInfo.nDetachType] .. "\n", 106))
	else
		tinsert(t, XML_LINE_BREAKER)
	end
	local szDesc = GetBuffDesc(dwID, nLevel, "desc")
	if szDesc and szDesc ~= "" then
		tinsert(t, GetFormatText(szDesc .. g_tStrings.STR_FULL_STOP, 106))
	else
		tinsert(t, GetFormatText("BUFF#" .. dwID .. "#" .. nLevel, 106))
	end

	if nTime then
		if nTime == 0 then
			tinsert(t, XML_LINE_BREAKER)
			tinsert(t, GetFormatText(g_tStrings.STR_BUFF_H_TIME_ZERO, 102))
		else
			local H, M, S = "", "", ""
			local h = math.floor(nTime / 3600)
			local m = math.floor(nTime / 60) % 60
			local s = math.floor(nTime % 60)
			if h > 0 then
				H = h .. g_tStrings.STR_BUFF_H_TIME_H .. " "
			end
			if h > 0 or m > 0 then
				M = m .. g_tStrings.STR_BUFF_H_TIME_M_SHORT .. " "
			end
			S = s..g_tStrings.STR_BUFF_H_TIME_S
			if h < 720 then
				tinsert(t, XML_LINE_BREAKER)
				tinsert(t, GetFormatText(FormatString(g_tStrings.STR_BUFF_H_LEFT_TIME_MSG, H, M, S), 102))
			end
		end
	end

	-- For test
	if IsCtrlKeyDown() then
		tinsert(t, XML_LINE_BREAKER)
		tinsert(t, GetFormatText(g_tStrings.DEBUG_INFO_ITEM_TIP, 102))
		tinsert(t, XML_LINE_BREAKER)
		tinsert(t, GetFormatText("ID:     " .. dwID, 102))
		tinsert(t, XML_LINE_BREAKER)
		tinsert(t, GetFormatText("Level:  " .. nLevel, 102))
		tinsert(t, XML_LINE_BREAKER)
		tinsert(t, GetFormatText("IconID: " .. tostring(Table_GetBuffIconID(dwID, nLevel)), 102))
	end
	OutputTip(table.concat(t), 300, Rect)
end

---------------------------------------------------------------------
-- 可重复利用的简易 Handle 元件缓存池
---------------------------------------------------------------------
_JH.HandlePool = class()

-- construct
function _JH.HandlePool:ctor(handle, xml)
	self.handle, self.xml = handle, xml
	handle.nFreeCount = 0
	handle:Clear()
end

-- clear
function _JH.HandlePool:Clear()
	self.handle:Clear()
	self.handle.nFreeCount = 0
end

-- new item
function _JH.HandlePool:New()
	local handle = self.handle
	local nCount = handle:GetItemCount()
	if handle.nFreeCount > 0 then
		for i = nCount - 1, 0, -1 do
			local item = handle:Lookup(i)
			if item.bFree then
				item.bFree = false
				handle.nFreeCount = handle.nFreeCount - 1
				return item
			end
		end
		handle.nFreeCount = 0
	else
		handle:AppendItemFromString(self.xml)
		local item = handle:Lookup(nCount)
		item.bFree = false
		return item
	end
end

-- remove item
function _JH.HandlePool:Remove(item)
	if item:IsValid() then
		self.handle:RemoveItem(item)
	end
end

-- free item
function _JH.HandlePool:Free(item)
	if item:IsValid() then
		self.handle.nFreeCount = self.handle.nFreeCount + 1
		item.bFree = true
		item:SetName("")
		item:Hide()
	end
end

function _JH.HandlePool:GetAllItem(bShow)
	local t = {}
	for i = self.handle:GetItemCount() - 1, 0, -1 do
		local item = self.handle:Lookup(i)
		if bShow and item:IsVisible() or not bShow then
			table.insert(t, item)
		end
	end
	return t
end
-- public api, create pool
-- (class) JH.HandlePool(userdata handle, string szXml)
JH.HandlePool = _JH.HandlePool.new

---------------------------------------------------------------------
-- 本地的 UI 组件对象
---------------------------------------------------------------------
local _GUI = {}
-------------------------------------
-- Base object class
-------------------------------------
_GUI.Base = class()

-- (userdata) Instance:Raw()		-- 获取原始窗体/组件对象
function _GUI.Base:Raw()
	if self.type == "Label" then
		return self.txt
	end
	return self.wnd or self.edit or self.self
end

-- (void) Instance:Remove()		-- 删除组件
function _GUI.Base:Remove()
	if self.fnDestroy then
		local wnd = self.wnd or self.self
		self.fnDestroy(wnd)
	end
	local hP = self.self:GetParent()
	if hP.___uis then
		local szName = self.self:GetName()
		hP.___uis[szName] = nil
	end
	if self.type == "WndFrame" then
		Wnd.CloseWindow(self.self)
	elseif ssub(self.type, 1, 3) == "Wnd" then
		self.self:Destroy()
	else
		hP:RemoveItem(self.self:GetIndex())
	end
end

-- (string) Instance:Name()					-- 取得名称
-- (self) Instance:Name(szName)			-- 设置名称为 szName 并返回自身以支持串接调用
function _GUI.Base:Name(szName)
	if not szName then
		return self.self:GetName()
	end
	self.self:SetName(szName)
	return self
end

-- (self) Instance:Toggle([boolean bShow])			-- 显示/隐藏
function _GUI.Base:Toggle(bShow)
	if bShow == false or (not bShow and self.self:IsVisible()) then
		self.self:Hide()
	else
		self.self:Show()
		if self.type == "WndFrame" then
			self.self:BringToTop()
		end
	end
	return self
end

function _GUI.Base:IsVisible()
	return self.self:IsVisible()
end

function _GUI.Base:Point( ... )
	if self.type == "WndFrame" or self.type == "WndWindow" then
		local t = { ... }
		if IsEmpty(t) then
			self.self:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
		else
			self.self:SetPoint( ... )
		end
	end
	return self
end

function _GUI.Base:RegisterClose(fnAction, bNotButton, bNotKeyDown)
	if self.type == "WndFrame" or self.type == "WndWindow" then
		if not bNotKeyDown then
			self.self.OnFrameKeyDown = function()
				if GetKeyName(Station.GetMessageKey()) == "Esc" then
					fnAction()
					return 1
				end
			end
		end
		if not bNotButton then
			self.self:Lookup("Btn_Close").OnLButtonClick = fnAction
		end
	end
	return self
end



-- (number, number) Instance:Pos()					-- 取得位置坐标
-- (self) Instance:Pos(number nX, number nY)	-- 设置位置坐标
function _GUI.Base:Pos(nX, nY)
	if not nX then
		return self.self:GetRelPos()
	end
	self.self:SetRelPos(nX, nY)
	if self.type == "WndFrame" then
		self.self:CorrectPos()
	elseif ssub(self.type, 1, 3) ~= "Wnd" then
		self.self:GetParent():FormatAllItemPos()
	end
	return self
end

-- (number, number) Instance:Pos_()			-- 取得右下角的坐标
function _GUI.Base:Pos_()
	local nX, nY = self:Pos()
	local nW, nH = self:Size()
	return nX + nW, nY + nH
end

-- (number, number) Instance:CPos_()			-- 取得最后一个子元素右下角坐标
-- 特别注意：仅对通过 :Append() 追加的元素有效，以便用于动态定位
function _GUI.Base:CPos_()
	local hP = self.wnd or self.self
	if not hP.___last and ssub(hP:GetType(), 1, 3) == "Wnd" then
		hP = hP:Lookup("", "")
	end
	if hP.___last then
		local ui = GUI.Fetch(hP, hP.___last)
		if ui then
			return ui:Pos_()
		end
	end
	return 0, 0
end

-- (class) Instance:Append(string szType, ...)	-- 添加 UI 子组件
-- NOTICE：only for Handle，WndXXX
function _GUI.Base:Append(szType, ...)
	local hP = self.wnd or self.self
	if ssub(hP:GetType(), 1, 3) == "Wnd" and ssub(szType, 1, 3) ~= "Wnd" then
		hP.___last = nil
		hP = hP:Lookup("", "")
	end
	return GUI.Append(hP, szType, ...)
end

-- (class) Instance:Fetch(string szName)	-- 根据名称获取 UI 子组件
function _GUI.Base:Fetch(szName)
	local hP = self.wnd or self.self
	local ui = GUI.Fetch(hP, szName)
	if not ui and self.handle then
		ui = GUI.Fetch(self.handle, szName)
	end
	return ui
end

-- (number, number) Instance:Align()
-- (self) Instance:Align(number nHAlign, number nVAlign)
function _GUI.Base:Align(nHAlign, nVAlign)
	local txt = self.edit or self.txt
	if txt then
		if not nHAlign and not nVAlign then
			return txt:GetHAlign(), txt:GetVAlign()
		else
			if nHAlign then
				txt:SetHAlign(nHAlign)
			end
			if nVAlign then
				txt:SetVAlign(nVAlign)
			end
		end
	end
	return self
end

-- (number) Instance:Font()
-- (self) Instance:Font(number nFont)
function _GUI.Base:Font(nFont)
	local txt = self.edit or self.txt
	if txt then
		if not nFont then
			return txt:GetFontScheme()
		end
		txt:SetFontScheme(nFont)
		if self.type == "WndEdit" then
			txt:SetSelectFontScheme(nFont)
		end
	end
	return self
end

-- (number, number, number) Instance:Color()
-- (self) Instance:Color(number nRed, number nGreen, number nBlue)
function _GUI.Base:Color(nRed, nGreen, nBlue)
	if self.type == "Shadow" then
		if not nRed then
			return self.self:GetColorRGB()
		end
		self.self:SetColorRGB(nRed, nGreen, nBlue)
	else
		local txt = self.edit or self.txt
		if txt then
			if not nRed then
				return txt:GetFontColor()
			end
			txt:SetFontColor(nRed, nGreen, nBlue)
			txt.col = { nRed, nGreen, nBlue }
		end
	end
	return self
end

-- (number) Instance:Alpha()
-- (self) Instance:Alpha(number nAlpha)
function _GUI.Base:Alpha(nAlpha)
	local txt = self.edit or self.txt or self.self
	if txt then
		if not nAlpha then
			return txt:GetAlpha()
		end
		txt:SetAlpha(nAlpha)
	end
	return self
end

function _GUI.Base:Event( ... )
	local t = { ... }
	for i = 1, select("#", ...) do
		if self.type == "WndFrame" then
			self.self:UnRegisterEvent(t[i])
		end
		self.self:RegisterEvent(t[i])
	end
	return self
end

------------------------------------------------

_GUI.Frame = class(_GUI.Base)

function _GUI.Frame:OnEvent(fnAction)
	if not self.event then
		self.event = { fnAction }
		self.self.OnEvent = function(szEvent)
			for k, v in ipairs(self.event) do
				v(szEvent)
			end
		end
	end
	for k, v in ipairs(self.event) do
		if v ~= fnAction then
			tinsert(self.event, fnAction)
			break
		end
	end
	return self
end

-- (string) Instance:Title()					-- 取得窗体标题
-- (self) Instance:Title(string szTitle)	-- 设置窗体标题
function _GUI.Frame:Title(szTitle)
	local ttl = self.self:Lookup("", "Text_Title")
	if not szTitle then
		return ttl:GetText()
	end
	ttl:SetText(szTitle)
	return self
end

-- (boolean) Instance:Drag()						-- 判断窗体是否可拖移
-- (self) Instance:Drag(boolean bEnable)	-- 设置窗体是否可拖移
function _GUI.Frame:Drag(bEnable)
	local frm = self.self
	if bEnable == nil then
		return frm:IsDragable()
	end
	frm:EnableDrag(bEnable == true)
	return self
end

-- (string) Instance:Relation()
-- (self) Instance:Relation(string szName)	-- Normal/Lowest ...
function _GUI.Frame:Relation(szName)
	local frm = self.self
	if not szName then
		return frm:GetParent():GetName()
	end
	frm:ChangeRelation(szName)
	return self
end

-- (userdata) Instance:Lookup(...)
function _GUI.Frame:Lookup(...)
	local wnd = self.wnd or self.self
	return self.wnd:Lookup(...)
end

-------------------------------------
-- Dialog frame
-------------------------------------
_GUI.Frm = class(_GUI.Frame)

-- constructor
function _GUI.Frm:ctor(szName, bEmpty)
	local frm, szIniFile = nil, ROOT_PATH .. "ui/WndFrame.ini"
	if bEmpty then
		szIniFile = ROOT_PATH .. "ui/WndFrameEmpty.ini"
	end
	if type(szName) == "string" then
		frm = Station.Lookup("Normal/" .. szName)
		if frm then
			Wnd.CloseWindow(frm)
		else
			PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
		end
		frm = Wnd.OpenWindow(szIniFile, szName)
	else
		frm = Wnd.OpenWindow(szIniFile)
	end
	frm:Show()
	if not bEmpty then
		frm:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
		frm:Lookup("Btn_Close").OnLButtonClick = function()
			PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
			Wnd.CloseWindow(frm)
		end
		frm.OnFrameKeyDown = function()
			if GetKeyName(Station.GetMessageKey()) == "Esc" then
				PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
				self:Remove()
				return 1
			end
		end
		self.wnd = frm:Lookup("Window_Main")
		self.handle = self.wnd:Lookup("", "")
	else
		self.handle = frm:Lookup("", "")
	end
	self.self, self.type = frm, "WndFrame"
end

-- (number, number) Instance:Size()						-- 取得窗体宽和高
-- (self) Instance:Size(number nW, number nH)	-- 设置窗体的宽和高
function _GUI.Frm:Size(nW, nH)
	local frm = self.self
	if not nW then
		return frm:GetSize()
	end
	local hnd = frm:Lookup("", "")
	-- empty frame
	if not self.wnd then
		frm:SetSize(nW, nH)
		hnd:SetSize(nW, nH)
		return self
	end
	-- set size
	frm:SetSize(nW, nH)
	frm:SetDragArea(0, 0, nW, 70)
	hnd:SetSize(nW, nH)
	hnd:Lookup("Image_BgT"):SetW(nW)
	hnd:Lookup("Image_BgCT"):SetW(nW - 32)
	hnd:Lookup("Image_BgLC"):SetH(nH - 149)
	hnd:Lookup("Image_BgCC"):SetSize(nW - 16, nH - 149)
	hnd:Lookup("Image_BgRC"):SetH(nH - 149)
	hnd:Lookup("Image_BgCB"):SetW(nW - 132)
	hnd:Lookup("Text_Title"):SetW(nW - 90)

	hnd:FormatAllItemPos()
	frm:Lookup("Btn_Close"):SetRelPos(nW - 35, 15)
	self.wnd:SetSize(nW, nH)
	self.wnd:Lookup("", ""):SetSize(nW, nH)
	-- reset position
	local an = GetFrameAnchor(frm)
	frm:SetPoint(an.s, 0, 0, an.r, an.x, an.y)
	return self
end

_GUI.Frm2 = class(_GUI.Frame)
-- constructor
function _GUI.Frm2:ctor(szName, bEmpty)
	local frm, szIniFile = nil, ROOT_PATH .. "ui/WndFrame2.ini"
	if bEmpty then
		szIniFile = ROOT_PATH .. "ui/WndFrameEmpty.ini"
	end
	if type(szName) == "string" then
		frm = Station.Lookup("Normal/" .. szName)
		if frm then
			Wnd.CloseWindow(frm)
		else
			PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
		end
		frm = Wnd.OpenWindow(szIniFile, szName)
	else
		frm = Wnd.OpenWindow(szIniFile)
	end
	frm:Show()
	if not bEmpty then
		frm:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
		frm:Lookup("Btn_Close").OnLButtonClick = function()
			PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
			self:Remove()
		end
		frm.OnFrameKeyDown = function()
			if GetKeyName(Station.GetMessageKey()) == "Esc" then
				PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
				self:Remove()
				return 1
			end
		end
		self.wnd = frm:Lookup("Window_Main")
		self.handle = self.wnd:Lookup("", "")
	else
		self.handle = frm:Lookup("", "")
	end
	self.self, self.type = frm, "WndFrame"
end

function _GUI.Frm2:Size(nW, nH)
	local frm = self.self
	if not nW then
		return frm:GetSize()
	end
	local hnd = frm:Lookup("", "")
	-- empty frame
	if not self.wnd then
		frm:SetSize(nW, nH)
		hnd:SetSize(nW, nH)
		return self
	end
	-- set size
	frm:SetSize(nW, nH)
	frm:SetDragArea(0, 0, nW, 30)
	hnd:SetSize(nW, nH)
	hnd:Lookup("Shadow_Bg"):SetSize(nW, nH)
	hnd:Lookup("Shadow_Title"):SetW(nW)
	hnd:Lookup("Text_Title"):SetW(nW - 90)
	hnd:FormatAllItemPos()
	frm:Lookup("Btn_Close"):SetRelPos(nW - 28, 5)
	self.wnd:SetSize(nW, nH)
	self.wnd:Lookup("", ""):SetSize(nW, nH)
	-- reset position
	local an = GetFrameAnchor(frm)
	frm:SetPoint(an.s, 0, 0, an.r, an.x, an.y)
	return self
end

function _GUI.Frm2:Setting(fnAction)
	local wnd = self.self
	wnd:Lookup("Btn_Setting").OnLButtonClick = fnAction
	return self
end

function _GUI.Frm2:BackGround( ... )
	local shadow = self.self:Lookup("", "Shadow_Bg")
	if ... then
		shadow:SetColorRGB( ... )
		return self
	else
		return shadow:GetColorRGB()
	end

end

-------------------------------------
-- Window Component
-------------------------------------
_GUI.Wnd = class(_GUI.Base)

-- constructor
function _GUI.Wnd:ctor(pFrame, szType, szName)
	local wnd = nil
	if not szType and not szName then
		-- convert from raw object
		wnd, szType = pFrame, pFrame:GetType()
	else
		-- append from ini file
		local szFile = ROOT_PATH .. "ui/" .. szType .. ".ini"
		local frame = Wnd.OpenWindow(szFile, "GUI_Virtual")
		assert(frame, _L("Unable to open ini file [%s]", szFile))
		wnd = frame:Lookup(szType)
		assert(wnd, _L("Can not find wnd component [%s]", szType))
		wnd:SetName(szName)
		wnd:ChangeRelation(pFrame, true, true)
		Wnd.CloseWindow(frame)
	end
	if wnd then
		if string.find(szType, "WndButton") then
			szType = "WndButton"
		end
		self.type = szType
		self.edit = wnd:Lookup("Edit_Default")
		self.handle = wnd:Lookup("", "")
		self.self = wnd
		if self.handle then
			self.txt = self.handle:Lookup("Text_Default")
		end
		if szType == "WndTrackBar" then
			local scroll = wnd:Lookup("Scroll_Track")
			scroll.nMin, scroll.nMax, scroll.szText = 0, scroll:GetStepCount(), self.txt:GetText()
			scroll.nVal = scroll.nMin
			self.txt:SetText(scroll.nVal .. scroll.szText)
			scroll.OnScrollBarPosChanged = function()
				-- if (this.nMax - this.nMin) < this:GetStepCount() then
					this.nVal = this.nMin + (this:GetScrollPos() / this:GetStepCount()) * (this.nMax - this.nMin)
				-- else
				-- 	this.nVal = this.nMin + mceil((this:GetScrollPos() / this:GetStepCount()) * (this.nMax - this.nMin))
				-- end
				if this.OnScrollBarPosChanged_ then
					this.OnScrollBarPosChanged_(this.nVal)
				end
				self.txt:SetText(this.nVal .. this.szText)
			end
		end
	end
end

-- (number, number) Instance:Size()
-- (self) Instance:Size(number nW, number nH)
function _GUI.Wnd:Size(nW, nH)
	local wnd = self.self
	if not nW then
		local nW, nH = wnd:GetSize()
		if self.type == "WndRadioBox" or self.type == "WndCheckBox" or self.type == "WndTrackBar" then
			local xW, _ = self.txt:GetTextExtent()
			nW = nW + xW + 5
		end
		return nW, nH
	end
	if self.edit then
		wnd:SetSize(nW + 2, nH)
		self.handle:SetSize(nW + 2, nH)
		self.handle:Lookup("Image_Default"):SetSize(nW + 2, nH)
		self.edit:SetSize(nW - 3, nH)
	else
		wnd:SetSize(nW, nH)
		if self.handle then
			self.handle:SetSize(nW, nH)
			if self.type == "WndButton" or self.type == "WndTabBox" then
				self.txt:SetSize(nW, nH)
			elseif self.type == "WndComboBox" then
				self.handle:Lookup("Image_ComboBoxBg"):SetSize(nW, nH)
				local btn = wnd:Lookup("Btn_ComboBox")
				local hnd = btn:Lookup("", "")
				local bW, bH = btn:GetSize()
				btn:SetRelPos(nW - bW - 5, mceil((nH - bH)/2))
				hnd:SetAbsPos(self.handle:GetAbsPos())
				hnd:SetSize(nW, nH)
				self.txt:SetSize(nW - mceil(bW/2), nH)
			elseif self.type == "WndCheckBox" then
				local _, xH = self.txt:GetTextExtent()
				self.txt:SetRelPos(nW - 20, floor((nH - xH)/2))
			elseif self.type == "WndRadioBox" then
				local _, xH = self.txt:GetTextExtent()
				self.txt:SetRelPos(nW + 5, floor((nH - xH)/2))
				self.handle:FormatAllItemPos()
			elseif self.type == "WndTrackBar" then
				wnd:Lookup("Scroll_Track"):SetSize(nW, nH - 13)
				wnd:Lookup("Scroll_Track/Btn_Track"):SetH(nH - 13)
				self.handle:Lookup("Image_BG"):SetSize(nW, nH - 15)
				self.handle:Lookup("Text_Default"):SetRelPos(nW + 5, mceil((nH - 25)/2))
				self.handle:FormatAllItemPos()
			end
		end
	end
	return self
end

function _GUI.Wnd:Title(szTitle)
	local ttl = self.self:Lookup("", "Text_Title")
	if not szTitle then
		return ttl:GetText()
	end
	ttl:SetText(szTitle)
	return self
end

-- (boolean) Instance:Enable()
-- (self) Instance:Enable(boolean bEnable)
function _GUI.Wnd:Enable(bEnable)
	local wnd = self.edit or self.self
	local txt = self.edit or self.txt
	if bEnable == nil then
		if self.type == "WndButton" then
			return wnd:IsEnabled()
		end
		return self.enable ~= false
	end
	if bEnable then
		if self.type == "WndTrackBar" then
			wnd:Lookup("Scroll_Track/Btn_Track"):Enable(1)
		elseif self.type == "WndComboBox" then
			wnd:Lookup("Btn_ComboBox"):Enable(1)
		end
		wnd:Enable(1)
		if txt then
			if self.font then
				txt:SetFontScheme(self.font)
			end
			if txt.col then
				txt:SetFontColor(unpack(txt.col))
			end
		end
		self.enable = true
	else
		if self.type == "WndTrackBar" then
			wnd:Lookup("Scroll_Track/Btn_Track"):Enable(0)
		elseif self.type == "WndComboBox" then
			wnd:Lookup("Btn_ComboBox"):Enable(0)
		end
		wnd:Enable(0)
		if txt and self.enable ~= false then
			self.font = txt:GetFontScheme()
			txt:SetFontScheme(161)
		end
		self.enable = false
	end
	return self
end

-- (self) Instance:AutoSize([number hPad[, number vPad]])
function _GUI.Wnd:AutoSize(hPad, vPad)
	local wnd = self.self
	if self.type == "WndTabBox" or self.type == "WndButton" then
		local _, nH = wnd:GetSize()
		local nW, _ = self.txt:GetTextExtent()
		local nEx = self.txt:GetTextPosExtent()
		if hPad then
			nW = nW + hPad + hPad
		end
		if vPad then
			nH = nH + vPad + vPad
		end
		self:Size(nW + nEx + 16, nH)
	elseif self.type == "WndComboBox" then
		local bW, _ = wnd:Lookup("Btn_ComboBox"):GetSize()
		local nW, nH = self.txt:GetTextExtent()
		local nEx = self.txt:GetTextPosExtent()
		if hPad then
			nW = nW + hPad + hPad
		end
		if vPad then
			nH = nH + vPad + vPad
		end
		self:Size(nW + bW + 20, nH + 6)
	end
	return self
end

-- (boolean) Instance:Check()
-- (self) Instance:Check(boolean bCheck)
-- NOTICE：only for WndCheckBox
function _GUI.Wnd:Check(bCheck)
	local wnd = self.self
	if wnd:GetType() == "WndCheckBox" then
		if bCheck == nil then
			return wnd:IsCheckBoxChecked()
		end
		wnd:Check(bCheck == true)
	end
	return self
end

-- (string) Instance:Group()
-- (self) Instance:Group(string szGroup)
-- NOTICE：only for WndCheckBox
function _GUI.Wnd:Group(szGroup)
	local wnd = self.self
	if wnd:GetType() == "WndCheckBox" then
		if not szGroup then
			return wnd.group
		end
		wnd.group = szGroup
	end
	return self
end

-- (string) Instance:Url()
-- (self) Instance:Url(string szUrl)
-- NOTICE：only for WndWebPage
function _GUI.Wnd:Url(szUrl)
	local wnd = self.self
	if self.type == "WndWebPage" then
		if not szUrl then
			return wnd:GetLocationURL()
		end
		wnd:Navigate(szUrl)
	end
	return self
end

-- (number, number, number) Instance:Range()
-- (self) Instance:Range(number nMin, number nMax[, number nStep])
-- NOTICE：only for WndTrackBar
function _GUI.Wnd:Range(nMin, nMax, nStep)
	if self.type == "WndTrackBar" then
		local scroll = self.self:Lookup("Scroll_Track")
		if not nMin and not nMax then
			return scroll.nMin, scroll.nMax, scroll:GetStepCount()
		end
		if nMin then scroll.nMin = nMin end
		if nMax then scroll.nMax = nMax end
		if nStep then scroll:SetStepCount(nStep) end
		self:Value(scroll.nVal)
	end
	return self
end

-- (number) Instance:Value()
-- (self) Instance:Value(number nVal)
-- NOTICE：only for WndTrackBar
function _GUI.Wnd:Value(nVal)
	if self.type == "WndTrackBar" then
		local scroll = self.self:Lookup("Scroll_Track")
		if not nVal then
			return scroll.nVal
		end
		scroll.nVal = mmin(mmax(nVal, scroll.nMin), scroll.nMax)
		scroll:SetScrollPos(mceil((scroll.nVal - scroll.nMin) / (scroll.nMax - scroll.nMin) * scroll:GetStepCount()))
		self.txt:SetText(scroll.nVal .. scroll.szText)
	end
	return self
end

-- (string) Instance:Text()
-- (self) Instance:Text(string szText[, boolean bDummy])
-- bDummy		-- 设为 true 不触发输入框的 onChange 事件
function _GUI.Wnd:Text(szText, bDummy)
	local txt = self.edit or self.txt
	if txt then
		if not szText then
			return txt:GetText()
		end
		if self.type == "WndTrackBar" then
			local scroll = self.self:Lookup("Scroll_Track")
			scroll.szText = szText
			txt:SetText(scroll.nVal .. scroll.szText)
		elseif self.type == "WndEdit" and bDummy then
			local fnChanged = txt.OnEditChanged
			txt.OnEditChanged = nil
			txt:SetText(szText)
			txt.OnEditChanged = fnChanged
		else
			txt:SetText(szText)
		end
		if self.type == "WndTabBox" then
			self:AutoSize()
		end
		if self.type == "WndCheckBox" or self.type == "WndRadioBox" then
			local nWidth, nHeight = txt:GetTextExtent()
			txt:SetSize(nWidth + 26, nHeight)
			self.handle:SetSize(nWidth + 26, nHeight)
			self.handle:FormatAllItemPos()
		end
	end
	return self
end

-- (boolean) Instance:Multi()
-- (self) Instance:Multi(boolean bEnable)
-- NOTICE: only for WndEdit
function _GUI.Wnd:Multi(bEnable)
	local edit = self.edit
	if edit then
		if bEnable == nil then
			return edit:IsMultiLine()
		end
		edit:SetMultiLine(bEnable == true)
	end
	return self
end

-- (number) Instance:Limit()
-- (self) Instance:Limit(number nLimit)
-- NOTICE: only for WndEdit
function _GUI.Wnd:Limit(nLimit)
	local edit = self.edit
	if edit then
		if not nLimit then
			return edit:GetLimit()
		end
		edit:SetLimit(nLimit)
	end
	return self
end
-- Autocomplete
function _GUI.Wnd:Autocomplete(fnTable, fnCallBack, fnRecovery, nMaxOption)
	if self.type == "WndEdit" then
		local wnd = self.edit
		local tab = {}
		local Autocomplete = function()
			local tList, tTab  = {}, {}
			local szText = this:GetText()
			if type(fnTable) == "function" then
				tTab = fnTable(szText)
			else
				tTab = fnTable
			end
			for k, v in ipairs(tTab) do
				local txt = type(v) ~= "table" and tostring(v) or v.bRichText and v.option or v.szOption
				if txt and txt:find(szText) and (txt ~= szText or type(v) == "table" and v.self) then
					table.insert(tList, v)
				elseif type(v) == "table" and v.bDevide then
					table.insert(tList, v)
				end
				if #tList > (nMaxOption or 15) then break end
			end

			if #tList == 0 or (#tList == 1 and ((type(tList[1]) == "table" and tList[1].szOption == szText) or tostring(tList[1]) == szText)) then
				if IsPopupMenuOpened() then
					Wnd.CloseWindow(GetPopupMenu())
				end
			else
				local menu = {}
				for k, v in ipairs(tList) do
					local t = {}
					if type(v) == "table" then
						t = v
					else
						t.szOption = v
					end
					t.fnAction = function()
						local txt = t.szOption
						if type(v) == "table" and v.bRichText then
							txt = v.option
						end
						wnd:SetText(txt)
						Wnd.CloseWindow(GetPopupMenu())
						if fnCallBack then
							local _this = this
							this = wnd
							fnCallBack(txt, type(v) == "table" and v.data) -- callback
							this = _this
						end
					end
					if fnRecovery then
						t.szLayer         = "ICON_RIGHTMOST"
						t.nFrame          = 86
						t.nMouseOverFrame = 87
						t.szIcon          = "ui/Image/UICommon/Feedanimials.uitex"
						t.fnClickIcon     = function()
							JH.Confirm(FormatString(g_tStrings.MSG_DELETE_NAME, t.szOption), function()
								local _this = this
								this = wnd
								fnRecovery(t.szOption) -- callback
								this = _this
								Wnd.CloseWindow(GetPopupMenu())
								Station.SetFocusWindow(wnd)
								return
							end)
						end
					end
					table.insert(menu, t)
				end
				local nX, nY = this:GetAbsPos()
				local nW, nH = this:GetSize()
				menu.nMiniWidth = nW
				menu.x = nX
				menu.y = nY + nH
				menu.bShowKillFocus = true
				menu.bDisableSound = true
				menu.fnAutoClose = function()
					local frame = Station.GetFocusWindow()
					if not frame or frame and frame:GetName() ~= "PopupMenuPanel" and frame:GetName() ~= wnd:GetName() then
						return true
					end
				end
				PopupMenu(menu)
				-- PopupMenu_ProcessHotkey("Down") -- 还是不加的好
			end
			if fnCallBack then
				fnCallBack(szText)
			end
		end
		if not wnd.__Autocomplete then
			wnd.__Autocomplete = Autocomplete
			if wnd.OnEditChanged then
				local OnEditChanged = wnd.OnEditChanged
				wnd.OnEditChanged = function()
					this.__Autocomplete()
					OnEditChanged()
				end
			else
				wnd.OnEditChanged = wnd.__Autocomplete
			end
		else
			wnd.__Autocomplete = Autocomplete
		end
		wnd.OnSetFocus = function()
			this.OnEditChanged()
		end
		wnd.OnEditSpecialKeyDown = function()
			local szKey = GetKeyName(Station.GetMessageKey())
			if IsPopupMenuOpened() and PopupMenu_ProcessHotkey then
				if szKey == "Enter"
				or szKey == "Up"
				or szKey == "Down"
				or szKey == "Left"
				or szKey == "Right"
			then
					return PopupMenu_ProcessHotkey(szKey)
				end
			end
		end
		wnd.OnKillFocus = function() -- 这里是切换edit
			if IsPopupMenuOpened() then
				local frame = Station.GetFocusWindow()
				if frame and frame:GetName() ~= "PopupMenuPanel" then
					Wnd.CloseWindow(GetPopupMenu())
				end
			end
		end
	end
	return self
end

-- (self) Instance:Change()			-- 触发编辑框修改处理函数
-- (self) Instance:Change(func fnAction)
-- NOTICE：only for WndEdit，WndTrackBar
function _GUI.Wnd:Change(fnAction)
	if self.type == "WndTrackBar" then
		self.self:Lookup("Scroll_Track").OnScrollBarPosChanged_ = fnAction
	elseif self.edit then
		local edit = self.edit
		if not fnAction then
			if edit.OnEditChanged then
				local _this = this
				this = edit
				edit.OnEditChanged()
				this = _this
			end
		else
			edit.OnEditChanged = function()
				if not this.bChanging then
					this.bChanging = true
					if this.__Autocomplete then
						this.__Autocomplete()
					end
					fnAction(this:GetText())
					this.bChanging = false
				end
			end
		end
	end
	return self
end

-- (self) Instance:Focus()
-- (self) Instance:Focus(func fnFocus[, func fnKillFocus])
-- NOTICE：only for WndWindow, WndEdit
function _GUI.Wnd:Focus(fnFocus, fnKillFocus)
	local wnd = self.self
	if self.type == "WndEdit" then
		wnd = self.edit
	end
	if type(fnFocus) == "function" then
		fnKillFocus = fnKillFocus or fnFocus
		wnd.OnSetFocus  = function() fnFocus(true) end
		wnd.OnKillFocus = function() fnKillFocus(false) end
	else
		Station.SetFocusWindow(wnd)
	end
	return self
end

-- (self) Instance:Menu(table menu)		-- 设置下拉菜单
-- NOTICE：only for WndComboBox
function _GUI.Wnd:Menu(menu)
	if self.type == "WndComboBox" then
		local wnd = self.self
		self:Click(function()
			local _menu = nil
			local nX, nY = wnd:GetAbsPos()
			local nW, nH = wnd:GetSize()
			if type(menu) == "function" then
				_menu = menu()
			else
				_menu = menu
			end
			_menu.nMiniWidth = nW
			_menu.x = nX
			_menu.y = nY + nH
			PopupMenu(_menu)
		end)
	end
	return self
end

-- (self) Instance:Click()
-- (self) Instance:Click(func fnAction)	-- 设置组件点击后触发执行的函数
-- fnAction = function([bCheck])			-- 对于 WndCheckBox 会传入 bCheck 代表是否勾选
function _GUI.Wnd:Click(fnAction)
	local wnd = self.self
	if self.type == "WndComboBox" then
		wnd = wnd:Lookup("Btn_ComboBox")
	end
	if wnd:GetType() == "WndCheckBox" then
		if not fnAction then
			self:Check(not self:Check())
		else
			wnd.OnCheckBoxCheck = function()
				if wnd.group then
					local uis = this:GetParent().___uis or {}
					for _, ui in pairs(uis) do
						if ui:Group() == this.group and ui:Name() ~= this:GetName() then
							ui.bCanUnCheck = true
							ui:Check(false)
							ui.bCanUnCheck = nil
						end
					end
				end
				fnAction(true)
			end
			wnd.OnCheckBoxUncheck = function()
				if wnd.group and not self.bCanUnCheck then
					self:Check(true)
				else
					fnAction(false)
				end
			end
		end
	else
		if not fnAction then
			if wnd.OnLButtonClick then
				local _this = this
				this = wnd
				wnd.OnLButtonClick()
				this = _this
			end
		else
			wnd.OnLButtonClick = fnAction
		end
	end
	return self
end

-- (self) Instance:Hover(func fnEnter[, func fnLeave])	-- 设置鼠标进出处理函数
-- fnEnter = function(true)		-- 鼠标进入时调用
-- fnLeave = function(false)		-- 鼠标移出时调用，若省略则和进入函数一样
function _GUI.Wnd:Hover(fnEnter, fnLeave)
	local wnd = self.self
	if self.type == "WndComboBox" then
		wnd = wnd:Lookup("Btn_ComboBox")
	end
	if wnd then
		fnLeave = fnLeave or fnEnter
		if fnEnter then
			wnd.OnMouseEnter = function() fnEnter(true) end
		end
		if fnLeave then
			wnd.OnMouseLeave = function() fnLeave(false) end
		end
	end
	return self
end

function _GUI.Wnd:Type(nType)
	if self.type == "WndEdit" then
		self.edit:SetType(nType)
	end
	return self
end

-------------------------------------
-- Handle Item
-------------------------------------
_GUI.Item = class(_GUI.Base)

-- xml string
_GUI.tItemXML = {
	["Text"]    = "<text>w=150 h=30 valign=1 font=162 </text>",
	["Image"]   = "<image>w=100 h=100 </image>",
	["Animate"] = "<Animate>w=100 h=100 </Animate>",
	["Box"]     = "<box>w=48 h=48 </box>",
	["Shadow"]  = "<shadow>w=15 h=15 </shadow>",
	["Handle"]  = "<handle>firstpostype=0 w=10 h=10</handle>",
	["Label"]   = "<handle>w=150 h=30 <text>name=\"Text_Label\" w=150 h=30 font=162 valign=1 </text></handle>",
}

-- construct
function _GUI.Item:ctor(pHandle, szType, szName)
	local hnd = nil
	if not szType and not szName then
		-- convert from raw object
		hnd, szType = pHandle, pHandle:GetType()
	else
		local szXml = _GUI.tItemXML[szType]
		if szXml then
			-- append from xml
			local nCount = pHandle:GetItemCount()
			pHandle:AppendItemFromString(szXml)
			hnd = pHandle:Lookup(nCount)
			if hnd then hnd:SetName(szName) end
		else
			-- append from ini
			hnd = pHandle:AppendItemFromIni(ROOT_PATH .. "ui/HandleItems.ini","Handle_" .. szType, szName)
		end
		assert(hnd, _L("Unable to append handle item [%s]", szType))
	end
	if szType == "BoxButton" then
		self.txt = hnd:Lookup("Text_BoxButton")
		self.img = hnd:Lookup("Image_BoxIco")
		hnd.OnItemMouseEnter = function()
			if not this.bSelected then
				this:Lookup("Image_BoxBg"):Hide()
				this:Lookup("Image_BoxBgOver"):Show()
			end
		end
		hnd.OnItemMouseLeave = function()
			if not this.bSelected then
				this:Lookup("Image_BoxBg"):Show()
				this:Lookup("Image_BoxBgOver"):Hide()
			end
		end
	elseif szType == "TxtButton" then
		self.txt = hnd:Lookup("Text_TxtButton")
		self.img = hnd:Lookup("Image_TxtBg")
		hnd.OnItemMouseEnter = function()
			self.img:Show()
		end
		hnd.OnItemMouseLeave = function()
			if not this.bSelected then
				self.img:Hide()
			end
		end
	elseif szType == "Label" then
		self.txt = hnd:Lookup("Text_Label")
	elseif szType == "Text" then
		self.txt = hnd
	elseif szType == "Image" then
		self.img = hnd
	end
	self.self, self.type = hnd, szType
	hnd:SetRelPos(0, 0)
	hnd:GetParent():FormatAllItemPos()
end

-- (number, number) Instance:Size()
-- (self) Instance:Size(number nW, number nH)
function _GUI.Item:Size(nW, nH)
	local hnd = self.self
	if not nW then
		local nW, nH = hnd:GetSize()
		if self.type == "Text" or self.type == "Label" then
			nW, nH = self.txt:GetTextExtent()
		end
		return nW, nH
	end
	hnd:SetSize(nW, nH)
	if self.type == "BoxButton" then
		local nPad = mceil(nH * 0.2)
		hnd:Lookup("Image_BoxBg"):SetSize(nW - 12, nH + 8)
		hnd:Lookup("Image_BoxBgOver"):SetSize(nW - 12, nH + 8)
		hnd:Lookup("Image_BoxBgSel"):SetSize(nW - 1, nH + 11)
		self.img:SetSize(nH - nPad, nH - nPad)
		self.img:SetRelPos(10, mceil(nPad / 2))
		self.txt:SetSize(nW - nH - nPad, nH)
		self.txt:SetRelPos(nH + 10, 0)
		hnd:FormatAllItemPos()
	elseif self.type == "TxtButton" then
		self.img:SetSize(nW, nH - 5)
		self.txt:SetSize(nW - 10, nH - 5)
	elseif self.type == "Label" then
		self.txt:SetSize(nW, nH)
	end
	return self
end

function _GUI.Item:AutoSize()
	self.self:AutoSize()
	return self
end

-- (self) Instance:Zoom(boolean bEnable)	-- 是否启用点击后放大
-- NOTICE：only for BoxButton
function _GUI.Item:Zoom(bEnable)
	local hnd = self.self
	if self.type == "BoxButton" then
		local bg = hnd:Lookup("Image_BoxBg")
		local sel = hnd:Lookup("Image_BoxBgSel")
		if bEnable == true then
			local nW, nH = bg:GetSize()
			sel:SetSize(nW + 11, nH + 3)
			sel:SetRelPos(1, -5)
		else
			sel:SetSize(bg:GetSize())
			sel:SetRelPos(5, -2)
		end
		hnd:FormatAllItemPos()
	end
	return self
end

-- (self) Instance:Select()		-- 激活选中当前按纽，进行特效处理
-- NOTICE：only for BoxButton，TxtButton
function _GUI.Item:Select()
	local hnd = self.self
	if self.type == "BoxButton" or self.type == "TxtButton" then
		local hParent, nIndex = hnd:GetParent(), hnd:GetIndex()
		local nCount = hParent:GetItemCount() - 1
		for i = 0, nCount do
			local item = GUI.Fetch(hParent:Lookup(i))
			if item and item.type == self.type then
				if i == nIndex then
					if not item.self.bSelected then
						hnd.bSelected = true
						hnd.nIndex = i
						if self.type == "BoxButton" then
							hnd:Lookup("Image_BoxBg"):Hide()
							hnd:Lookup("Image_BoxBgOver"):Hide()
							hnd:Lookup("Image_BoxBgSel"):Show()
							self.txt:SetFontScheme(168)
							local icon = hnd:Lookup("Image_BoxIco")
							local nW, nH = icon:GetSize()
							local nX, nY = icon:GetRelPos()
							icon:SetSize(nW + 6, nH + 6)
							icon:SetRelPos(nX - 3, nY - 3)
							hnd:FormatAllItemPos()
						else
							self.img:Show()
						end
					end
				elseif item.self.bSelected then
					item.self.bSelected = false
					if item.type == "BoxButton" then
						item.self:SetIndex(item.self.nIndex)
						if hnd.nIndex >= item.self.nIndex then
							hnd.nIndex = hnd.nIndex + 1
						end
						item.self:Lookup("Image_BoxBg"):Show()
						item.self:Lookup("Image_BoxBgOver"):Hide()
						item.self:Lookup("Image_BoxBgSel"):Hide()
						item.txt:SetFontScheme(163)
						local icon = item.self:Lookup("Image_BoxIco")
						local nW, nH = icon:GetSize()
						local nX, nY = icon:GetRelPos()
						icon:SetSize(nW - 6, nH - 6)
						icon:SetRelPos(nX + 3, nY + 3)
						item.self:FormatAllItemPos()
					else
						item.img:Hide()
					end
				end
			end
		end
		if hnd.nIndex then
			hnd:SetIndex(nCount)
		end
	end
	return self
end

-- (string) Instance:Text()
-- (self) Instance:Text(string szText)
function _GUI.Item:Text(szText)
	local txt = self.txt
	if txt then
		if not szText then
			return txt:GetText()
		end
		txt:SetText(szText)
	end
	return self
end
function _GUI.Item:Scale(fScale)
	local txt = self.txt
	if txt then
		if not fScale then
			return txt:GetFontScale()
		end
		txt:SetFontScale(fScale)
	end
	return self
end

-- (boolean) Instance:Multi()
-- (self) Instance:Multi(boolean bEnable)
-- NOTICE: only for Text，Label
function _GUI.Item:Multi(bEnable)
	local txt = self.txt
	if txt then
		if bEnable == nil then
			return txt:IsMultiLine()
		end
		txt:SetMultiLine(bEnable == true)
	end
	return self
end

-- (self) Instance:File(string szUitexFile, number nFrame)
-- (self) Instance:File(string szTextureFile)
-- (self) Instance:File(number dwIcon)
-- NOTICE：only for Image，BoxButton
function _GUI.Item:File(szFile, nFrame)
	local img = nil
	if self.type == "Image" then
		img = self.self
	elseif self.type == "BoxButton" then
		img = self.img
	end
	if self.type == "Box" then
		self.self:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
		if type(szFile) == "number" then
			self.self:ClearExtentImage()
			self.self:SetObjectIcon(szFile)
		else
			self.self:ClearObjectIcon()
			self.self:SetExtentImage(szFile, nFrame)
		end
	else
		if img then
			if type(szFile) == "number" then
				img:FromIconID(szFile)
			elseif not nFrame then
				img:FromTextureFile(szFile)
			else
				img:FromUITex(szFile, nFrame)
			end
		end
	end
	return self
end
function _GUI.Item:Animate(szImage, nGroup, nLoopCount)
	if self.type == "Animate" then
		self.self:SetAnimate(szImage, nGroup, nLoopCount)
	end
	return self
end

-- (self) Instance:Type()
-- (self) Instance:Type(number nType)		-- 修改图片类型或 BoxButton 的背景类型
-- NOTICE：only for Image，BoxButton
function _GUI.Item:Type(nType)
	local hnd = self.self
	if self.type == "Image" then
		if not nType then
			return hnd:GetImageType()
		end
		hnd:SetImageType(nType)
	elseif self.type == "BoxButton" then
		if nType == nil then
			local nFrame = hnd:Lookup("Image_BoxBg"):GetFrame()
			if nFrame == 16 then
				return 2
			elseif nFrame == 18 then
				return 1
			end
			return 0
		elseif nType == 0 then
			hnd:Lookup("Image_BoxBg"):SetFrame(1)
			hnd:Lookup("Image_BoxBgOver"):SetFrame(2)
			hnd:Lookup("Image_BoxBgSel"):SetFrame(3)
		elseif nType == 1 then
			hnd:Lookup("Image_BoxBg"):SetFrame(18)
			hnd:Lookup("Image_BoxBgOver"):SetFrame(19)
			hnd:Lookup("Image_BoxBgSel"):SetFrame(22)
		elseif nType == 2 then
			hnd:Lookup("Image_BoxBg"):SetFrame(16)
			hnd:Lookup("Image_BoxBgOver"):SetFrame(17)
			hnd:Lookup("Image_BoxBgSel"):SetFrame(15)
		end
	end
	return self
end

-- (self) Instance:ToGray(bGray)
-- NOTICE：only for Box
function _GUI.Item:ToGray(bGray)
	if self.type == "Box" then
		if bGray then
			self.self:IconToGray()
		else
			self.self:IconToNormal()
		end
	end
	return self
end
-- (self) Instance:ItemInfo( ... )
-- NOTICE：only for Box
function _GUI.Item:ItemInfo( ... )
	if self.type == "Box" then
		if IsEmpty({ ... }) then
			UpdataItemBoxObject(self.self)
		else
			local res, err = pcall(UpdataItemInfoBoxObject, self.self, ...) -- 防止itemtab不一样
			if not res then
				JH.Debug(err)
			end
		end
	end
	return self
end
function _GUI.Item:BoxInfo(nType, ...)
	if self.type == "Box" then
		if IsEmpty({ ... }) then
			UpdataItemBoxObject(self.self)
		else
			local res, err = pcall(UpdateBoxObject, self.self, nType, ...) -- 防止itemtab不一样
			if not res then
				JH.Debug(err)
			end
		end
	end
	return self
end
-- (self) Instance:Icon(number dwIcon)
-- NOTICE：only for Box，Image，BoxButton
function _GUI.Item:Icon(dwIcon)
	if self.type == "BoxButton" or self.type == "Image" then
		if type(dwIcon) == "number" then
			self.img:FromIconID(dwIcon)
		elseif type(dwIcon) == "table" then
			self.img:FromUITex(unpack(dwIcon))
		end
	elseif self.type == "Box" then
		self.self:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
		self.self:SetObjectIcon(dwIcon)
	end
	return self
end

function _GUI.Item:OverText(nPos, szText, nOverTextIndex, nFontScheme)
	if self.type == "Box" then
		if nPos and szText then
			nOverTextIndex = nOverTextIndex or 0
			nFontScheme = nFontScheme or 15
			self.self:SetOverTextPosition(nOverTextIndex, nPos)
			self.self:SetOverTextFontScheme(nOverTextIndex, nFontScheme)
			self.self:SetOverText(nOverTextIndex, szText)
		else
			nPos = nPos or 0
			return self.self:GetOverText(nPos)
		end
	end
	return self
end

function _GUI.Item:Sparking(bSparking)
	if self.type == "Box" then
		self.self:SetObjectSparking(bSparking)
	end
	return self
end
function _GUI.Item:Staring(bStaring)
	if self.type == "Box" then
		self.self:SetObjectStaring(bStaring)
	end
	return self
end

function _GUI.Item:Percentage(fPercentage)
	if self.type == "Image" then
		if fPercentage then
			self.self:SetImageType(1)
			self.self:SetPercentage(fPercentage)
		else
			return self.self:GetPercentage()
		end
	end
	return self
end

function _GUI.Item:Type(nType)
	if self.type == "Image" then
		self.self:SetImageType(nType)
	elseif self.type == "Handle" then
		self.self:SetHandleStyle(nType)
	end
	return self
end

function _GUI.Item:Event(dwEventID)
	if dwEventID then
		self.self:RegisterEvent(dwEventID)
	else
		self.self:ClearEvent()
	end
	return self
end

function _GUI.Item:Clear()
	if self.type == "Handle" then
		self.self:Clear()
	end
	return self
end

function _GUI.Item:Enable(bEnable)
	if self.type == "Box" then
		if type(bEnable) ~= "nil" then
			self.self:EnableObject(bEnable)
		else
			return self.self:IsObjectEnable()
		end
	end
	return self
end

-- (self) Instance:Click()
-- (self) Instance:Click(func fnAction[, boolean bSound[, boolean bSelect]])	-- 登记鼠标点击处理函数
-- (self) Instance:Click(func fnAction[, table tLinkColor[, tHoverColor]])		-- 同上，只对文本
function _GUI.Item:Click(fnAction, bSound, bSelect)
	local hnd = self.self
	hnd:RegisterEvent(0x10)
	if not fnAction then
		if hnd.OnItemLButtonClick then
			local _this = this
			this = hnd
			hnd.OnItemLButtonClick()
			this = _this
		end
	elseif self.type == "BoxButton" or self.type == "TxtButton" then
		hnd.OnItemLButtonClick = function()
			if bSound then PlaySound(SOUND.UI_SOUND, g_sound.Button) end
			if bSelect then self:Select() end
			fnAction()
		end
	else
		hnd.OnItemLButtonClick = fnAction
		-- text link：tLinkColor，tHoverColor
		local txt = self.txt
		if txt then
			local tLinkColor = bSound or { 255, 255, 0 }
			local tHoverColor = bSelect or { 255, 200, 100 }
			if bSound then
				txt:SetFontColor(unpack(tLinkColor))
			end
			if tHoverColor then
				self:Hover(function(bIn)
					if bSound then
						if bIn then
							txt:SetFontColor(unpack(tHoverColor))
						else
							txt:SetFontColor(unpack(tLinkColor))
						end
					end
				end)
			end
		end
	end
	return self
end

-- (self) Instance:Hover(func fnEnter[, func fnLeave])	-- 设置鼠标进出处理函数
-- fnEnter = function(true)		-- 鼠标进入时调用
-- fnLeave = function(false)		-- 鼠标移出时调用，若省略则和进入函数一样
function _GUI.Item:Hover(fnEnter, fnLeave)
	local hnd = self.self
	hnd:RegisterEvent(0x100)
	fnLeave = fnLeave or fnEnter
	if fnEnter then
		hnd.OnItemMouseEnter = function() fnEnter(true) end
	end
	if fnLeave then
		hnd.OnItemMouseLeave = function() fnLeave(false) end
	end
	return self
end

---------------------------------------------------------------------
-- 公开的 API：GUI.xxx
---------------------------------------------------------------------
GUI = {}
setmetatable(GUI, { __call = function(me, ...) return me.Fetch(...) end, __metatable = true })

-- 开启一个空的对话窗体界面，并返回 GUI 封装对象
-- (class) GUI.CreateFrame([string szName, ]table tArg)
-- szName		-- *可选* 名称，若省略则自动编序号
-- tArg {			-- *可选* 初始化配置参数，自动调用相应的封装方法，所有属性均可选
--		w, h,			-- 宽和高，成对出现用于指定大小，注意宽度会自动被就近调节为：770/380/234，高度最小 200
--		x, y,			-- 位置坐标，默认在屏幕正中间
--		title			-- 窗体标题
--		drag			-- 设置窗体是否可拖动
--		close		-- 点击关闭按纽是是否真正关闭窗体（若为 false 则是隐藏）
--		empty		-- 创建空窗体，不带背景，全透明，只是界面需求
--		fnCreate = function(frame)		-- 打开窗体后的初始化函数，frame 为内容窗体，在此设计 UI
--		fnDestroy = function(frame)	-- 关闭销毁窗体时调用，frame 为内容窗体，可在此清理变量
-- }
-- 返回值：通用的  GUI 对象，可直接调用封装方法
function GUI.CreateFrame(szName, tArg)
	if type(szName) == "table" then
		szName, tArg = nil, szName
	end
	tArg = tArg or {}
	local ui = tArg.nStyle == 2 and _GUI.Frm2.new(szName, tArg.empty == true) or _GUI.Frm.new(szName, tArg.empty == true)
	if tArg.focus then
		Station.SetFocusWindow(ui.self)
	end
	-- apply init setting
	if tArg.w and tArg.h then ui:Size(tArg.w, tArg.h) end
	if tArg.x and tArg.y then ui:Pos(tArg.x, tArg.y) end
	if tArg.title then ui:Title(tArg.title) end
	if tArg.drag ~= nil then ui:Drag(tArg.drag) end
	if tArg.close ~= nil then ui.self.bClose = tArg.close end
	if tArg.fnCreate then tArg.fnCreate(ui:Raw()) end
	if tArg.fnDestroy then ui.fnDestroy = tArg.fnDestroy end
	if tArg.parent then ui:Relation(tArg.parent) end
	ui:Point() -- fix Size
	return ui
end

-- 创建空窗体
function GUI.CreateFrameEmpty(szName, szParent)
	return GUI.CreateFrame(szName, { empty  = true, parent = szParent })
end

-- 往某一父窗体或容器添加  INI 配置文件中的部分，并返回 GUI 封装对象
-- (class) GUI.Append(userdata hParent, string szIniFile, string szTag, string szName)
-- hParent		-- 父窗体或容器原始对象（GUI 对象请直接用  :Append 方法）
-- szIniFile		-- INI 文件路径
-- szTag			-- 要添加的对象源，即中括号内的部分 [XXXX]，请与 hParent 匹配采用 Wnd 或容器组件
-- szName		-- *可选* 对象名称，若不指定则沿用原名称
-- 返回值：通用的  GUI 对象，可直接调用封装方法，失败或出错返回 nil
-- 特别注意：这个函数也支持添加窗体对象
function GUI.AppendIni(hParent, szFile, szTag, szName)
	local raw = nil
	if hParent:GetType() == "Handle" then
		if not szName then
			szName = "Child_" .. hParent:GetItemCount()
		end
		raw = hParent:AppendItemFromIni(szFile, szTag, szName)
	elseif ssub(hParent:GetType(), 1, 3) == "Wnd" then
		local frame = Wnd.OpenWindow(szFile, "GUI_Virtual")
		if frame then
			raw = frame:Lookup(szTag)
			if raw and ssub(raw:GetType(), 1, 3) == "Wnd" then
				raw:ChangeRelation(hParent, true, true)
				if szName then
					raw:SetName(szName)
				end
			else
				raw = nil
			end
			Wnd.CloseWindow(frame)
		end
	end
	assert(raw, _L("Fail to add component [%s@%s]", szTag, szFile))
	return GUI.Fetch(raw)
end

-- 往某一父窗体或容器添加 GUI 组件并返回封装对象
-- (class) GUI.Append(userdata hParent, string szType[, string szName], table tArg)
-- hParent		-- 父窗体或容器原始对象（GUI 对象请直接用  :Append 方法）
-- szType			-- 要添加的组件类型（如：WndWindow，WndEdit，Handle，Text ……）
-- szName		-- *可选* 名称，若省略则自动编序号
-- tArg {			-- *可选* 初始化配置参数，自动调用相应的封装方法，所有属性均可选，如果没用则忽略
--		w, h,			-- 宽和高，成对出现用于指定大小
--		x, y,			-- 位置坐标
--		txt, font, multi, limit, align		-- 文本内容，字体，是否多行，长度限制，对齐方式（0：左，1：中，2：右）
--		color, alpha			-- 颜色，不透明度
--		checked				-- 是否勾选，CheckBox 专用
--		enable					-- 是否启用
--		file, icon, type		-- 图片文件地址，图标编号，类型
--		group					-- 单选框分组设置
-- }
-- 返回值：通用的  GUI 对象，可直接调用封装方法，失败或出错返回 nil
-- 特别注意：为统一接口此函数也可用于 AppendIni 文件，参数与 GUI.AppendIni 一致
-- (class) GUI.Append(userdata hParent, string szIniFile, string szTag, string szName)
function GUI.Append(hParent, szType, szName, tArg)
	-- compatiable with AppendIni
	if StringFindW(szType, ".ini") ~= nil then
		return GUI.AppendIni(hParent, szType, szName, tArg)
	end
	-- reset parameters
	if not tArg and type(szName) == "table" then
		szName, tArg = nil, szName
	end
	if not szName then
		if not hParent.nAutoIndex then
			hParent.nAutoIndex = 1
		end
		szName = szType .. "_" .. hParent.nAutoIndex
		hParent.nAutoIndex = hParent.nAutoIndex + 1
	else
		szName = tostring(szName)
	end
	-- create ui
	local ui = nil
	if ssub(szType, 1, 3) == "Wnd" then
		assert(ssub(hParent:GetType(), 1, 3) == "Wnd", _L["The 1st arg for adding component must be a [WndXxx]"])
		ui = _GUI.Wnd.new(hParent, szType, szName)
	else
		assert(hParent:GetType() == "Handle", _L["The 1st arg for adding item must be a [Handle]"])
		ui = _GUI.Item.new(hParent, szType, szName)
	end
	local raw = ui:Raw()
	if raw then
		-- for reverse fetching
		hParent.___uis = hParent.___uis or {}
		for k, v in pairs(hParent.___uis) do
			if not v.self.___id then
				hParent.___uis[k] = nil
			end
		end
		hParent.___uis[szName] = ui
		hParent.___last = szName
		-- apply init setting
		tArg = tArg or {}
		if tArg.w and tArg.h then ui:Size(tArg.w, tArg.h) end
		if tArg.x and tArg.y then ui:Pos(tArg.x, tArg.y) end
		if tArg.font then ui:Font(tArg.font) end
		if tArg.multi ~= nil then ui:Multi(tArg.multi) end
		if tArg.limit then ui:Limit(tArg.limit) end
		if tArg.color then ui:Color(unpack(tArg.color)) end
		if tArg.align ~= nil then ui:Align(tArg.align) end
		if tArg.alpha then ui:Alpha(tArg.alpha) end
		if tArg.txt then ui:Text(tArg.txt) end
		if tArg.checked ~= nil then ui:Check(tArg.checked) end
		-- wnd only
		if tArg.enable ~= nil then ui:Enable(tArg.enable) end
		if tArg.group then ui:Group(tArg.group) end
		if ui.type == "WndComboBox" and (not tArg.w or not tArg.h) then
			ui:Size(185, 25)
		end
		-- item only
		if tArg.file then ui:File(tArg.file, tArg.num) end
		if tArg.icon ~= nil then ui:Icon(tArg.icon) end
		if tArg.type then ui:Type(tArg.type) end
		return ui
	end
end

-- (class) GUI(...)
-- (class) GUI.Fetch(hRaw)						-- 将 hRaw 原始对象转换为 GUI 封装对象
-- (class) GUI.Fetch(hParent, szName)	-- 从 hParent 中提取名为 szName 的子元件并转换为 GUI 对象
-- 返回值：通用的  GUI 对象，可直接调用封装方法，失败或出错返回 nil
function GUI.Fetch(hParent, szName)
	if type(hParent) == "string" then
		hParent = Station.Lookup(hParent)
	end
	if not szName then
		szName = hParent:GetName()
		hParent = hParent:GetParent()
	end
	-- exists
	if hParent.___uis and hParent.___uis[szName] then
		local ui = hParent.___uis[szName]
		if ui and ui.self.___id then
			return ui
		end
	end
	-- convert
	local hRaw = hParent:Lookup(szName)
	if hRaw then
		local ui
		if ssub(hRaw:GetType(), 1, 3) == "Wnd" then
			ui = _GUI.Wnd.new(hRaw)
		else
			ui = _GUI.Item.new(hRaw)
		end
		hParent.___uis = hParent.___uis or {}
		hParent.___uis[szName] = ui
		return ui
	end
end

function GUI.RegisterPanel(szTitle, dwIcon, szClass, fn)
	-- find class
	local dwClass = nil
	if not szClass then
		dwClass = 1
	else
		for k, v in ipairs(_JH.tClass) do
			if v == szClass then
				dwClass = k
			end
		end
		if not dwClass then
			tinsert(_JH.tClass, szClass)
			dwClass = table.getn(_JH.tClass)
			_JH.tItem[dwClass] = {}
		end
	end
	-- check to update
	for _, v in ipairs(_JH.tItem[dwClass]) do
		if v.szTitle == szTitle then
			v.dwIcon, v.fn, dwClass = dwIcon, fn, nil
			break
		end
	end
	-- create new one
	if dwClass then
		tinsert(_JH.tItem[dwClass], { szTitle = szTitle, dwIcon = dwIcon, fn = fn })
	end
	if _JH.frame then
		_JH.UpdateTabBox(_JH.frame)
	end
	if fn and fn.OnConflictCheck then
		_JH.RegisterConflictCheck(fn.OnConflictCheck)
	end
end

-- 字体选择器
function GUI.OpenFontTablePanel(fnAction)
	local ui = GUI.CreateFrame("JH_FontTable", { w = 470, h = 370, title = g_tStrings.FONT, nStyle = 2 , close = true, focus = true }):BackGround(64, 64, 64)
	ui:Setting(function()
		GetUserInput(_L["Input Font ID"], function(szText)
			if tonumber(szText) and tonumber(szText) >= 0 and tonumber(szText) <= 236 then
				if fnAction then fnAction(tonumber(szText)) end
				ui:Remove()
			end
		end)
	end)
	local tFontList = LoadLUAData(JH.GetAddonInfo().szRootPath .. "0Base/font/FontList.jx3dat")
	local tFont = {
		["0"] = g_tStrings.FONT_HEITI,
		["7"] = g_tStrings.FONT_JIANZHI,
		["8"] = g_tStrings.FONT_XINGKAI,
	}
	local handle = ui:Append("Handle", { x = 0, y = 40, w = 100, h = 300 })
	local function LoadFontList(szFont)
		local i = 0
		local txt = tFont[szFont]
		handle:Clear()
		table.sort(tFontList[szFont], function(a, b)
			if a.Size ~= b.Size then
				return a.Size < b.Size
			else
				return a.FontID < b.FontID
			end
		end)
		for k , v in ipairs(tFontList[szFont]) do
			handle:Append("Text", { x = (i % 7) * 68 + 10, y = floor(i / 7) * 35 + 15, color = { 255, 128, 0 } , txt = txt, font = v.FontID } ):AutoSize()
			:Click(function()
				if fnAction then fnAction(v.FontID) end
				ui:Remove()
			end):Hover(function(bHover)
				if bHover then
					this:SetFontColor(255, 255, 0)
					if IsCtrlKeyDown() then
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						OutputTip(GetFormatText(var2str(v, "    "), 41, 255, 255, 255), 300, { x, y, w, h })
					end
				else
					HideTip()
					this:SetFontColor(255, 128, 0)
				end
			end)
			i = i + 1
		end
	end
	local i = 0
	for k, v in pairs(tFont) do
		ui:Append("WndRadioBox", { x = i * 80 + 125, y = 10, txt = v , group = "font", checked = k == "0" }):Click(function()
			LoadFontList(k)
		end)
		i = i + 1
	end
	LoadFontList("0")
end

-- 调色板 https://en.wikipedia.org/wiki/HSL_and_HSV
local COLOR_HUE = 0
function GUI.OpenColorTablePanel(fnAction)
	local fX, fY = Cursor.GetPos(true)
	local tUI = {}
	local function hsv2rgb(h, s, v)
		s = s / 100
		v = v / 100
		local r, g, b = 0, 0, 0
		local h = h / 60
		local i = floor(h)
		local f = h - i
		local p = v * (1 - s)
		local q = v * (1 - s * f)
		local t = v * (1 - s * (1 - f))
		if i == 0 or i == 6 then
			r, g, b = v, t, p
		elseif i == 1 then
			r, g, b = q, v, p
		elseif i == 2 then
			r, g, b = p, v, t
		elseif i == 3 then
			r, g, b = p, q, v
		elseif i == 4 then
			r, g, b = t, p, v
		elseif i == 5 then
			r, g, b = v, p, q
		end
		return floor(r * 255), floor(g * 255), floor(b * 255)
	end

	local ui = GUI.CreateFrame("JH_ColorTable", { w = 346, h = 430, title = _L["Color Picker"], nStyle = 2 , close = true, focus = true }):Pos(fX + 15, fY + 15)
	local GetRGBValue = function()
		for k, v in pairs({ "R", "G", "B" }) do
			local val = tonumber(ui:Fetch(v):Text())
			if val and val > 255 then
				ui:Fetch(v):Text(0, true)
			end
		end
		local r, g, b = tonumber(ui:Fetch("R"):Text()), tonumber(ui:Fetch("G"):Text(g)), tonumber(ui:Fetch("B"):Text(b))
		return r or 0, g or 0, b or 0
	end
	local fnChang = function()
		local r, g, b = GetRGBValue()
		ui:Fetch("Select"):Color(r, g, b)
		ui:Fetch("SURE"):Toggle(true)
	end

	local fnHover = function(bHover, r, g, b)
		if bHover then
			ui:Fetch("Select"):Color(r, g, b)
			for k, v in pairs({ R = r, G = g, B = b }) do
				ui:Fetch(k):Text(v, true)
			end
		else
			ui:Fetch("Select"):Color(255, 255, 255)
			for k, v in pairs({ "R", "G", "B" }) do
				if ui:Fetch(v) then ui:Fetch(v):Text("", true) end
			end
		end
	end
	local fnClick = function()
		if fnAction then fnAction(GetRGBValue()) end
		if not IsCtrlKeyDown() then ui:Remove() end
	end
	ui.self.OnItemMouseEnter = function()
		local r, g, b = this:GetColorRGB()
		fnHover(true, r, g, b)
		ui:Fetch("Select_Image"):Pos(this:GetRelPos()):Toggle(true)
		ui:Fetch("SURE"):Toggle(false)
	end
	ui.self.OnItemMouseLeave = function()
		local r, g, b = this:GetColorRGB()
		fnHover(false, r, g, b)
		ui:Fetch("Select_Image"):Pos(this:GetRelPos()):Toggle(false)
	end
	ui.self.OnItemLButtonClick = fnClick
	local handle = ui:Append("Handle", { w = 300, h = 300, x = 0, y = 0 }):Type(0):Raw()
	local function SetColor(bInit)
		for v = 100, 0, -2 do
			tUI[v] = tUI[v] or {}
			for s = 0, 100, 2 do
				local x = 20 + s * 3
				local y = 80 + (100 - v) * 3
				local r, g, b = hsv2rgb(COLOR_HUE, s, v)
				if not bInit then
					tUI[v][s]:SetColorRGB(r, g, b)
				else
					handle:AppendItemFromString("<shadow> w=6 h=6 EventID=272 </shadow>")
					local sha = handle:Lookup(handle:GetItemCount() - 1)
					sha:SetRelPos(x, y)
					sha:SetColorRGB(r, g, b)
					tUI[v][s] = sha
				end
			end
		end
		if bInit then
			handle:FormatAllItemPos()
		end
	end
	SetColor(true)
	local x, y = ui:Append("Text", { x = 50, y = 8, txt = "R" }):Pos_()
	x, y = ui:Append("WndEdit", "R", { x = x + 5, y = 10, w = 30, h = 25, limit = 3 }):Change(fnChang):Type(0):Pos_()

	x, y = ui:Append("Text", { x = x + 5, y = 8, txt = "G" }):Pos_()
	x, y = ui:Append("WndEdit", "G", { x = x + 5, y = 10, w = 30, h = 25, limit = 3 }):Change(fnChang):Type(0):Pos_()

	x, y = ui:Append("Text", { x = x + 5, y = 8, txt = "B" }):Pos_()
	x, y = ui:Append("WndEdit", "B", { x = x + 5, y = 10, w = 30, h = 25, limit = 3 }):Change(fnChang):Type(0):Pos_()
	ui:Append("WndButton2", "SURE", { x = x + 5, y = 10, txt = g_tStrings.STR_PLAYER_SURE }):Click(fnClick):Toggle(false)
	ui:Append("Image", "Select_Image", { w = 6, h = 6, x = 0, y = 0 }):File("ui/Image/Common/Box.Uitex", 9):Toggle(false)
	ui:Append("Shadow", "Select", { w = 25, h = 25, x = 20, y = 10, color = { 255, 255, 255 } })
	ui:Append("WndTrackBar", { x = 20, y = 35, h = 25, w = 270, txt = " H" }):Range(0, 360, 360):Value(COLOR_HUE):Change(function(nVal)
		COLOR_HUE = nVal
		SetColor()
	end)
	for i = 0, 360, 2 do
		ui:Append("Shadow", { x = 20 + (0.74 * i), y = 60, h = 10, w = 2, color = { hsv2rgb(i, 100, 100) } })
	end
end

local ICON_PAGE
-- icon选择器
function GUI.OpenIconPanel(fnAction)
	local nMaxIocn, boxs, txts = 8074, {}, {}
	local ui = GUI.CreateFrame("JH_IconPanel", { w = 920, h = 650, title = _L["Icon Picker"], nStyle = 2 , close = true, focus = true })
	local function GetPage(nPage, bInit)
		if nPage == ICON_PAGE and not bInit then
			return
		end
		ICON_PAGE = nPage
		local nStart = (nPage - 1) * 144
		for i = 1, 144 do
			local x = ((i - 1) % 18) * 50 + 10
			local y = floor((i - 1) / 18) * 70 + 10
			if boxs[i] then
				local nIocn = nStart + i
				if nIocn > nMaxIocn then
					boxs[i]:Toggle(false)
					txts[i]:Toggle(false)
				else
					boxs[i]:Icon(-1)
					txts[i]:Text(nIocn):Toggle(true)
					JH.DelayCall(function()
						if mceil(nIocn / 144) == ICON_PAGE and boxs[i] then
							boxs[i]:Icon(nIocn):Toggle(true)
						end
					end)
				end
			else
				boxs[i] = ui:Append("Box", { w = 48, h = 48, x = x, y = y, icon = nStart + i}):Hover(function(bHover)
					this:SetObjectMouseOver(bHover)
				end):Click(function()
					if fnAction then
						fnAction(this:GetObjectIcon())
					end
					ui:Remove()
				end)
				txts[i] = ui:Append("Text", { w = 48, h = 20, x = x, y = y + 48, txt = nStart + i, align = 1 })
			end
		end
	end
	ui:Append("WndEdit", "Icon", { x = 730, y = 580, w = 50, h = 25 }):Type(0)
	ui:Append("WndButton2", { txt = g_tStrings.STR_HOTKEY_SURE, x = 800, y = 580 }):Click(function()
		local nIocn = tonumber(ui:Fetch("Icon"):Text())
		if nIocn then
			if fnAction then
				fnAction(nIocn)
			end
			ui:Remove()
		end
	end)
	ui:Append("WndTrackBar", { x = 10, y = 580, h = 25, w = 500, txt = " Page" }):Range(1, math.ceil(nMaxIocn / 144), math.ceil(nMaxIocn / 144) - 1):Value(ICON_PAGE or 21):Change(function(nVal)
		GetPage(nVal)
	end)
	GetPage(ICON_PAGE or 21, true)
end
