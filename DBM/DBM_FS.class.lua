-- @Author: Webster
-- @Date:   2015-05-02 06:59:32
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-06-28 18:17:31
local FS = class()

local type, ipairs, pairs, assert, unpack = type, ipairs, pairs, assert, unpack
local floor = math.floor
local GetBuff = JH.GetBuff

local FS_HANDLE, FS_FRAME
local FS_CACHE    = setmetatable({}, { __mode = "v" })
local FS_UI_CACHE = setmetatable({}, { __mode = "v" })
local FS_INIFILE  = JH.GetAddonInfo().szRootPath .. "DBM/ui/FS_UI.ini"
local SHADOW      = JH.GetAddonInfo().szShadowIni

-- FireUIEvent("JH_FS_CREATE", "test", { nTime = 3, col = { 255, 255, 0 }, bFlash = true})
local function CreateFullScreen(szKey, tArgs)
	assert(type(arg1) == "table", "CreateFullScreen failed!")
	tArgs.nTime = tArgs.nTime or 3
	if tArgs.tBindBuff then
		FS.new(szKey, tArgs):DrawEdge()
	else
		FS.new(szKey, tArgs)
	end
end

local function Init()
	Wnd.OpenWindow(FS_INIFILE, "FS_UI"):Hide()
end

FS_UI = {}

function FS_UI.OnFrameCreate()
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("JH_FS_CREATE")
	this:RegisterEvent("UI_SCALED")
	FS_FRAME = this
	FS_HANDLE = this:Lookup("", "")
	FS_HANDLE:Clear()
end

function FS_UI.OnEvent(szEvent)
	if szEvent == "JH_FS_CREATE" then
		CreateFullScreen(arg0, arg1)
	elseif szEvent == "UI_SCALED" then
		for k, v in pairs(FS_UI_CACHE) do
			local obj = FS.new(k)
			if obj then
				obj:DrawEdge()
			end
		end
	elseif szEvent == "LOADING_END" then
		FS_HANDLE:Clear()
	end
end
-- OnFrameBreathe 比较慢
function FS_UI.OnFrameRender()
	local nNow = GetTime()
	for k, v in pairs(FS_CACHE) do
		if v:IsValid() then
			local obj = FS.new(k)
			local nTime = ((nNow - obj.ui.nCreate) / 1000)
			local nLeft  = obj.ui.nTime - nTime
			if nLeft > 0 then
				if v.bFlash then
					local nTimeLeft = nTime * 1000 % 750
					local nAlpha = 150 * nTimeLeft / 750
					if floor(nTime / 0.75) % 2 == 1 then
						nAlpha = 150 - nAlpha
					end
					obj:DrawFullScreen(floor(nAlpha))
				else
					local nAlpha = 150 - 150 * nTime / v.nTime
					obj:DrawFullScreen(nAlpha)
				end
			else
				if v.sha1:IsValid() then
					if v.tBindBuff then
						obj:RemoveFullScreen()
					else
						obj:RemoveItem()
					end
				end
			end
			if v.tBindBuff then
				local dwID, nLevel = unpack(v.tBindBuff)
				local KBuff = GetBuff(dwID)
				if not KBuff then
					obj:RemoveItem()
				end
			end
		end
	end
end

function FS:ctor(szKey, tArgs)
	local ui = FS_CACHE[szKey]
	local nTime = GetTime()
	self.key = szKey
	if tArgs then
		local h
		if ui and ui:IsValid() then
			-- ui:Clear()
		else
			ui = FS_HANDLE:AppendItemFromIni(FS_INIFILE, "Handle_Item")
		end
		ui.sha1 = ui.sha1 or ui:AppendItemFromIni(SHADOW, "shadow")
		ui.bFlash = tArgs.bFlash
		ui.nTime = tArgs.nTime
		ui.nCreate = nTime
		ui.col = tArgs.col or { 255, 128, 0 }
		if tArgs.tBindBuff then
			ui.sha2 = ui.sha2 or ui:AppendItemFromIni(SHADOW, "shadow")
			ui.tBindBuff = tArgs.tBindBuff
		end
		self.ui = ui
		FS_CACHE[szKey] = self.ui
		FS_FRAME:Show()
		return self
	else
		if ui and ui:IsValid() then
			self.ui = ui
			return self
		else
			return nil
		end
	end
end

function FS:DrawFullScreen( ... )
	self:DrawShadow(self.ui.sha1, ...)
	return self
end

function FS:DrawEdge()
	self:DrawShadow(self.ui.sha2, 220, 15, 15)
	FS_UI_CACHE[self.key] = self.ui
	return self
end

function FS:DrawShadow(sha, nAlpha, fScreenX, fScreenY)
	local r, g, b = unpack(self.ui.col)
	local w, h = Station.GetClientSize()
	local bW, bH = fScreenX or w * 0.15, fScreenY or h * 0.15
	if sha:IsValid() then
		sha:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
		sha:SetD3DPT(D3DPT.TRIANGLESTRIP)
		sha:ClearTriangleFanPoint()
		sha:AppendTriangleFanPoint(0, 0, r, g, b, nAlpha)
		sha:AppendTriangleFanPoint(bW, bH, r, g, b, 0)
		sha:AppendTriangleFanPoint(0, h, r, g, b, nAlpha)
		sha:AppendTriangleFanPoint(bW, h - bH, r, g, b, 0)
		sha:AppendTriangleFanPoint(bW, h, r, g, b, nAlpha)
		sha:AppendTriangleFanPoint(w - bW, h - bH, r, g, b, 0)
		sha:AppendTriangleFanPoint(w, h, r, g, b, nAlpha)
		sha:AppendTriangleFanPoint(w - bW, bH, r, g, b, 0)
		sha:AppendTriangleFanPoint(w, 0, r, g, b, nAlpha)
		sha:AppendTriangleFanPoint(bW, bH, r, g, b, 0)
		sha:AppendTriangleFanPoint(0, 0, r, g, b, nAlpha)
	end
	return self
end

function FS:RemoveFullScreen()
	self.ui:RemoveItem(self.ui.sha1)
	return self
end

function FS:RemoveItem()
	FS_HANDLE:RemoveItem(self.ui)
	if FS_HANDLE:GetItemCount() == 0 then
		FS_FRAME:Hide()
	end
end

JH.RegisterEvent("LOGIN_GAME", Init)
