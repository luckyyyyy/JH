-- @Author: Webster
-- @Date:   2015-04-27 06:11:32
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-04-27 09:20:49

local ST_INIFILE = JH.GetAddonInfo().szRootPath .. "RaidGrid_EventScrutiny/ui/ST_UI.ini"
-- 倒计时类型
local ST_TYPE = {
	OTHER       = 0,
	BUFF_ENTER  = 1,
	BUFF_LEAVE  = 2,
	NPC_ENTER   = 3,
	NPC_LEAVE   = 4,
	NPC_TALK    = 5,
	NPC_LIFE    = 6,
	SKILL_BEGIN = 7,
	SKILL_END   = 8,
}

local ST_CACHE = {}
do
	for k, v in pairs(ST_TYPE) do
		ST_CACHE[v] = setmetatable({}, { __mode = "v" })
	end
end

-- 解析分段倒计时
local function GetCountdown(tTime)
	local tab = {}
	local t = JH.Split(tTime, ";")
	for k, v in ipairs(t) do
		local _ = JH.Split(v, ",")
		if _[1] and _[2] and tonumber(JH.Trim(_[1])) and _[2] ~= "" then
			table.insert(tab, { nTime = tonumber(_[1]), szName = _[2] })
		end
	end
	if IsEmpty(tab) then
		return nil
	else
		return tab
	end
end

-- 倒计时模块
-- nType 倒计时类型
-- szKey 同一类型内唯一标识符
-- tArgs {
--      szName -- 倒计时名称 如果是分段就不需要传
-- 		nTime  -- 时间,名称; 或 时间
--      nRefresh -- 多少时间内禁止重复刷新
--      nIcon -- 倒计时图标ID
-- }
--
local function CreateCountdown(nType, szKey, tArgs)
	local t = {}
	if type(tArgs.nTime) == "number" then
		t = tArgs
	else
		local tCountdown = GetCountdown(tArgs.nTime)
		if tCountdown then
			tArgs.nTime = tCountdown
			t = tCountdown[1]
		else
			return JH.Sysmsg2("tCountdown ERROR nType: " .. nType .. " szKey:" .. szKey .. " tCountdown:" .. tArgs.nTime)
		end
	end
	ST.new(nType, szKey, tArgs):SetInfo(t, tArgs.nIcon)
end

ST_UI = {
	bEnable = true,
	nImportant = 5,
	tAnchor = {},
}

local _ST_UI = {}

function ST_UI.OnFrameCreate()
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("JH_CREATE_ST")
	_ST_UI.UpdateAnchor(this)
	_ST_UI.handle = this:Lookup("", "Handle_List")
	_ST_UI.handle:Clear()
end

function ST_UI.OnEvent(szEvent)
	if szEvent == "JH_CREATE_ST" then
		CreateCountdown(arg0, arg1, arg2)
	elseif szEvent=="UI_SCALED" then
		_ST_UI.UpdateAnchor(this)
	elseif szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, "ST")
	end
end

function ST_UI.OnFrameDragEnd()
	this:CorrectPos()
	ST_UI.tAnchor = GetFrameAnchor(this, "TOPLEFT")
end

function ST_UI.OnFrameBreathe()
	local me = GetClientPlayer()
	if not me then return end
	local nNow = GetTime()
	for k, v in pairs(ST_CACHE) do
		for kk, vv in pairs(v) do
			if vv:IsValid() then
				local obj = ST.new(k, kk)
				if type(obj.ui.countdown) == "number" then
					local nLeft  = obj.ui.countdown - ((nNow - obj.ui.nLeft) / 1000)
					if nLeft >= 0 then
						obj:SetInfo({ nTime = nLeft }):SetPercentage(nLeft / obj.ui.countdown)
					else
						obj:RemoveItem()
					end
				else
					local time = obj.ui.countdown[1]
					local nLeft = time.nTime - (nNow - obj.ui.nLeft) / 1000
					if nLeft >= 0 then
						obj:SetInfo({ nTime = nLeft }):SetPercentage(nLeft / time.nTime)
					else
						if #obj.ui.countdown == 1 then
							obj:RemoveItem()
						else
							local nATime = (nNow - obj.ui.nLeft) / 1000
							obj.ui.nLeft = nNow
							table.remove(obj.ui.countdown, 1)
							local time = obj.ui.countdown[1]
							time.nTime = time.nTime - nATime
							obj:SetInfo(time)
						end
					end
				end
			end
		end
	end
end

function _ST_UI.UpdateAnchor(frame)
	local a = ST_UI.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, -300)
	end
end

function _ST_UI.Init()
	local frame = Wnd.OpenWindow(ST_INIFILE, "ST_UI")
end

JH.RegisterEvent("LOGIN_GAME", _ST_UI.Init)
JH.RegisterEvent("LOADING_END", function()
	FireEvent("JH_CREATE_ST", 1, "test", { nTime = "5,aaa;15,bbb;", szName = "test", nIcon = 37 })
	FireEvent("JH_CREATE_ST", 1, "test1", { nTime = "5,aaa;15,bbb;", szName = "test", nIcon = 37 })
	FireEvent("JH_CREATE_ST", 1, "test2", { nTime = "5,aaa;15,bbb;", szName = "test", nIcon = 37 })
	FireEvent("JH_CREATE_ST", 1, "test3", { nTime = "5,aaa;15,bbb;", szName = "test", nIcon = 37 })
end)

ST = class()
function ST:ctor(nType, szKey, tArgs)
	local ui = ST_CACHE[nType][szKey]
	if ui and ui:IsValid() then
		self.ui = ui
		return self
	elseif tArgs then
		self.ui = _ST_UI.handle:AppendItemFromIni(ST_INIFILE, "Handle_Item", nType .. szKey)
		self.ui.nCreate = GetTime()
		self.ui.nLeft = GetTime()
		self.ui.countdown = tArgs.nTime
		self.ui.szKey = szKey
		self.ui.nRefresh = tArgs.nRefresh
		_ST_UI.handle:FormatAllItemPos()
		ST_CACHE[nType][szKey] = self.ui
		return self
	else
		return nil
	end
end

-- 设置倒计时的名称和时间 用于动态改变分段倒计时
function ST:SetInfo(tArgs, nIcon)
	if tArgs.szName then
		self.ui:Lookup("SkillName"):SetText(tArgs.szName)
	end
	if tArgs.nTime then
		self.ui:Lookup("TimeLeft"):SetText(JH.GetBuffTimeString(tArgs.nTime))
	end
	if nIcon then
		local box = self.ui:Lookup("Box")
		box:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
		box:SetObjectIcon(nIcon)
	end
	return self
end

function ST:SetPercentage(fPercentage)
	self.ui:Lookup("Image"):SetPercentage(fPercentage)
end

function ST:RemoveItem()
	_ST_UI.handle:RemoveItem(self.ui)
	_ST_UI.handle:FormatAllItemPos()
end
