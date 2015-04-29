-- @Author: Webster
-- @Date:   2015-04-28 16:41:08
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-04-30 06:17:01
local _L = JH.LoadLangPack
-- ST class
local ST = class()
-- ini path
local ST_INIFILE = JH.GetAddonInfo().szRootPath .. "RaidGrid_EventScrutiny/ui/ST_UI.ini"
-- cache
local type, tonumber, ipairs, pairs = type, tonumber, ipairs, pairs
local tinsert, tsort = table.insert, table.sort
local JH_Split, JH_Trim = JH.Split, JH.Trim
local abs, mod, floor = math.abs, math.mod, math.floor
local GetClientPlayer, GetTime, IsEmpty = GetClientPlayer, GetTime, IsEmpty

local ST_CACHE = {}
do
	for k, v in pairs(JH_ST_TYPE) do
		ST_CACHE[v] = setmetatable({}, { __mode = "v" })
	end
end

-- 解析分段倒计时
local function GetCountdown(tTime)
	local tab = {}
	local t = JH_Split(tTime, ";")
	for k, v in ipairs(t) do
		local time = JH_Split(v, ",")
		if time[1] and time[2] and tonumber(JH_Trim(time[1])) and time[2] ~= "" then
			tinsert(tab, { nTime = tonumber(time[1]), szName = time[2] })
		end
	end
	if IsEmpty(tab) then
		return nil
	else
		tsort(tab, function(a, b) return a.nTime < b.nTime end)
		return tab
	end
end
-- 倒计时模块 事件名称 JH_ST_CREATE
-- nType 倒计时类型 Compatible.lua 中的 JH_ST_TYPE
-- szKey 同一类型内唯一标识符
-- tArgs {
--      szName   -- 倒计时名称 如果是分段就不需要传名称
--      nTime    -- 时间  例 10,测试;25,测试2; 或 30
--      nRefresh -- 多少时间内禁止重复刷新
--      nIcon    -- 倒计时图标ID
--      bTalk    -- 是否发布倒计时 5秒内聊天框提示 【szName】 剩余 n 秒。
-- }
-- 例子：FireEvent("JH_ST_CREATE", 0, "test", { nTime = 20 })
-- 性能测试：for i = 10, 100 do FireEvent("JH_ST_CREATE", 0, i, { nTime = 0.1*i, nIcon = i }) end
local function CreateCountdown(nType, szKey, tArgs)
	local arg = {}
	local nTime = GetTime()
	if type(tArgs.nTime) == "number" then
		arg = tArgs
	else
		local tCountdown = GetCountdown(tArgs.nTime)
		if tCountdown then
			arg = tCountdown[1]
			tArgs.nTime = tCountdown
			tArgs.nRefresh = tArgs.nRefresh or tCountdown[#tCountdown].nTime -- 最大时间内防止重复刷新 但是脱离战斗的NPC需要手动删除
		else
			return JH.Sysmsg2("tCountdown ERROR nType: " .. nType .. " szKey:" .. szKey .. " tCountdown:" .. tArgs.nTime)
		end
	end
	local ui = ST_CACHE[nType][szKey]
	if ui and ui:IsValid() and ui.nRefresh then
		if (nTime - ui.nCreate) / 1000 > ui.nRefresh then
			ST.new(nType, szKey, tArgs):SetInfo(arg, tArgs.nIcon or 13):Switch(false)
		end
	else
		ST.new(nType, szKey, tArgs):SetInfo(arg, tArgs.nIcon or 13):Switch(false)
	end
end

ST_UI = {
	bEnable = true,
	tAnchor = {},
}
JH.RegisterCustomData("ST_UI")

local _ST_UI = {}

function ST_UI.OnFrameCreate()
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("JH_ST_CREATE")
	this:RegisterEvent("JH_ST_DEL")
	this:RegisterEvent("JH_ST_CLEAR")
	_ST_UI.UpdateAnchor(this)
	_ST_UI.handle = this:Lookup("", "Handle_List")
end

function ST_UI.OnEvent(szEvent)
	if szEvent == "JH_ST_CREATE" then
		CreateCountdown(arg0, arg1, arg2)
	elseif szEvent == "JH_ST_DEL" then
		local obj = ST.new(arg0, arg1)
		if obj then
			if arg2 then -- 强制无条件删除
				obj:RemoveItem()
			else -- 只是把重复刷新时间去掉
				obj.ui.nRefresh = nil
			end
		end
	elseif szEvent == "JH_ST_CLEAR" then
		_ST_UI.handle:Clear()
	elseif szEvent =="UI_SCALED" then
		_ST_UI.UpdateAnchor(this)
	elseif szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, _L["Countdown"])
	elseif szEvent == "LOADING_END" then
		_ST_UI.handle:Clear()
	end
end

function ST_UI.OnFrameDragEnd()
	this:CorrectPos()
	ST_UI.tAnchor = GetFrameAnchor(this)
end

local function SetSTAction(obj, nLeft, nPer)
	local me = GetClientPlayer()
	if nLeft < 5 then
		local alpha = 255 * (abs(mod(nLeft * 15, 32) - 7) + 4) / 12
		obj:SetInfo({ nTime = nLeft }):SetPercentage(nPer):Switch(true):SetAlpha(alpha)
		if obj.ui.bTalk and me.IsInParty() then
			if not obj.ui.szTalk or obj.ui.szTalk ~= floor(nLeft) then
				obj.ui.szTalk = floor(nLeft)
				JH.Talk(_L("[%s] left over %d.", obj:GetName(), floor(nLeft)))
			end
		end
	else
		obj:SetInfo({ nTime = nLeft }):SetPercentage(nPer)
	end
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
						SetSTAction(obj, nLeft, nLeft / obj.ui.countdown)
					else
						obj:RemoveItem()
					end
				else
					local time = obj.ui.countdown[1]
					local nLeft = time.nTime - (nNow - obj.ui.nLeft) / 1000
					if nLeft >= 0 then
						SetSTAction(obj, nLeft, nLeft / time.nTime)
					else
						if #obj.ui.countdown == 1 then
							obj:RemoveItem()
						else
							local nATime = (nNow - obj.ui.nCreate) / 1000
							-- Output(nATime)
							obj.ui.nLeft = nNow
							table.remove(obj.ui.countdown, 1)
							local time = obj.ui.countdown[1]
							time.nTime = time.nTime - nATime
							obj:SetInfo(time):Switch(false)
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

function _ST_UI.FormatTimeString(nTime)
	nTime = tonumber(nTime) or 0
	if nTime > 60 then
		return floor(nTime / 60) .. "m" .. floor(nTime % 60) .. "s"
	else
		return floor(nTime) .. "s"
	end
end
-- 构造函数
function ST:ctor(nType, szKey, tArgs)
	local ui = ST_CACHE[nType][szKey]
	local nTime = GetTime()
	local key = nType .. "_" .. szKey
	if tArgs then
		tArgs.szName = tArgs.szName or key
		if ui and ui:IsValid() then
			self.ui           = ui
			self.ui.nCreate   = nTime
			self.ui.nLeft     = nTime
			self.ui.countdown = tArgs.nTime
			self.ui.nRefresh  = tArgs.nRefresh or 1
			self.ui.bTalk     = tArgs.bTalk
		else -- 没有ui的情况下 创建
			self.ui                = _ST_UI.handle:AppendItemFromIni(ST_INIFILE, "Handle_Item", key)
			self.ui.nCreate        = nTime
			self.ui.nLeft          = nTime
			self.ui.countdown      = tArgs.nTime
			self.ui.szKey          = key
			self.ui.nRefresh       = tArgs.nRefresh or 1
			self.ui.bTalk          = tArgs.bTalk
			-- ui
			self.ui.time           = self.ui:Lookup("TimeLeft")
			self.ui.txt            = self.ui:Lookup("SkillName")
			self.ui.img            = self.ui:Lookup("Image")
			ST_CACHE[nType][szKey] = self.ui
			self.ui:Show()
			_ST_UI.handle:FormatAllItemPos()
		end
		return self
	else
		if ui and ui:IsValid() then
			self.ui = ui
			return self
		else
			-- Log("[JH_DEBUG] ST == nil! nType: " .. nType .. " szKey:" .. szKey)
			return nil
		end
	end
end
-- 设置倒计时的名称和时间 用于动态改变分段倒计时
function ST:SetInfo(tArgs, nIcon)
	if tArgs.szName then
		self.ui.txt:SetText(tArgs.szName)
	end
	if tArgs.nTime then
		self.ui.time:SetText(_ST_UI.FormatTimeString(tArgs.nTime))
	end
	if nIcon then
		local box = self.ui:Lookup("Box")
		box:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
		box:SetObjectIcon(nIcon)
	end
	return self
end
-- 设置进度条
function ST:SetPercentage(fPercentage)
	self.ui.img:SetPercentage(fPercentage)
	return self
end
-- 改变样式 如果true则更改为第二样式 用于时间小于5秒的时候
function ST:Switch(bSwitch)
	if bSwitch then
		self.ui.txt:SetFontColor(255, 255, 255)
		self.ui.time:SetFontColor(255, 255, 255)
		self.ui.img:SetFrame(26)
	else
		self.ui.txt:SetFontColor(255, 255, 0)
		self.ui.time:SetFontColor(255, 255, 0)
		self.ui.img:SetFrame(208)
		self.ui.img:SetAlpha(160)
	end
	return self
end

function ST:SetAlpha(nAlpha)
	self.ui.img:SetAlpha(nAlpha)
	return self
end

function ST:GetName()
	return self.ui.txt:GetText()
end
-- 删除倒计时
function ST:RemoveItem()
	_ST_UI.handle:RemoveItem(self.ui)
	_ST_UI.handle:FormatAllItemPos()
end

JH.RegisterEvent("LOGIN_GAME", _ST_UI.Init)
