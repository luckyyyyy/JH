-- @Author: Webster
-- @Date:   2015-05-02 06:59:32
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-04 23:24:49
local FS = class()

local type, ipairs, pairs, assert, unpack = type, ipairs, pairs, assert, unpack
local min, max = math.min, math.max
local HasBuff = JH.HasBuff

local FS_CACHE    = setmetatable({}, { __mode = "v" })
local FS_UI_CACHE = setmetatable({}, { __mode = "v" })
local FS_INIFILE  = JH.GetAddonInfo().szRootPath .. "RaidGrid_EventScrutiny/ui/FS_UI.ini"
local SHADOW      = JH.GetAddonInfo().szShadowIni

-- FireEvent("JH_FS_CREATE", "test", { nTime = 5, col = { 255, 255, 0 }, bFlash = true, tBindBuff = { 103, 1 }})
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
	local frame = Wnd.OpenWindow(FS_INIFILE, "FS_UI")
end

FS_UI    = {}

function FS_UI.OnFrameCreate()
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("JH_FS_CREATE")
	this:RegisterEvent("UI_SCALED")
	FS_UI.handle = this:Lookup("", "")
	FS_UI.handle:Clear()
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
		FS_UI.handle:Clear()
	end
end

function FS_UI.OnFrameBreathe()
	local nNow = GetTime()
	for k, v in pairs(FS_CACHE) do
		if v:IsValid() then
			local obj = FS.new(k)
			local nTime = ((nNow - obj.ui.nCreate) / 1000)
			local nLeft  = obj.ui.nTime - nTime
			if nLeft > 0 then
				if v.bFlash then
					if v.bUp then
						v.nAlpha = min(150, v.nAlpha + 15)
						if v.nAlpha == 150 then
							v.bUp = false
						end
					else
						v.nAlpha = max(0, v.nAlpha - 15)
						if v.nAlpha == 0 then
							v.bUp = true
						end
					end
					obj:DrawFullScreen(v.nAlpha)
				else
					local nAlpha = 150 - (150 / v.nTime) * nTime
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
				local bExist = HasBuff(dwID)
				if not bExist then
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
			ui:Clear()
		else
			ui = FS_UI.handle:AppendItemFromIni(FS_INIFILE, "Handle_Item")
		end
		ui.sha1 = ui:AppendItemFromIni(SHADOW, "shadow")
		ui.bFlash = tArgs.bFlash
		ui.nUp = false
		ui.nAlpha = 150
		ui.nTime = tArgs.nTime
		ui.nCreate = nTime
		ui.col = tArgs.col or { 255, 128, 0 }
		if tArgs.tBindBuff then
			ui.sha2 = ui:AppendItemFromIni(SHADOW, "shadow")
			ui.tBindBuff = tArgs.tBindBuff
		end
		self.ui = ui
		FS_CACHE[szKey] = self.ui
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
	return self
end

function FS:RemoveFullScreen()
	self.ui:RemoveItem(self.ui.sha1)
	return self
end

function FS:RemoveItem()
	FS_UI.handle:RemoveItem(self.ui)
end

JH.RegisterEvent("LOGIN_GAME", Init)
