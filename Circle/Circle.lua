-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-08-04 13:01:09
local _L = JH.LoadLangPack
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
local reverse, type, unpack, pcall = string.reverse, type, unpack, pcall
local setmetatable = setmetatable
local tostring, tonumber = tostring, tonumber
local ceil, cos, sin, pi = math.ceil, math.cos, math.sin, math.pi
local tinsert, tconcat = table.insert, table.concat
local JsonEncode, JsonDecode = JH.JsonEncode, JH.JsonDecode
local IsRemotePlayer, UI_GetClientPlayerID = IsRemotePlayer, UI_GetClientPlayerID
local GetClientPlayer = GetClientPlayer
local TARGET = TARGET
-- 常量 副本外大部分不受此限制
local SHADOW              = JH.GetAddonInfo().szShadowIni
local CIRCLE_ALPHA_STEP   = 2.5
local CIRCLE_MAX_RADIUS   = 30    -- 最大的半径
local CIRCLE_LINE_ALPHA   = 165   -- 线和边框最大透明度
local CIRCLE_MAX_CIRCLE   = 2
local CIRCLE_RESERT_DRAW  = false -- 全局重绘
local CIRCLE_PLAYER_NAME  = "NONE"
local CIRCLE_DEFAULT_DATA = { bEnable = true, nAngle = 80, nRadius = 4, col = { 0, 255, 0 }, bBorder = true }

local CIRCLE_COLOR = {
	{ r = 0,   g = 255, b = 0   },
	{ r = 0,   g = 255, b = 255 },
	{ r = 255, g = 0,   b = 0   },
	{ r = 40,  g = 140, b = 218 },
	{ r = 211, g = 229, b = 37  },
	{ r = 65,  g = 50,  b = 160 },
	{ r = 170, g = 65,  b = 180 },
	{ r = 255, g = 255, b = 255 },
	{ r = 255, g = 128, b = 0   },
}

local function Confuse(tCode)
	return tCode
end

-- 获取数据路径
local function GetDataPath()
	if DBM and DBM.bCommon then
		return JH.GetAddonInfo().szDataPath .. "Circle/Common/Circle.jx3dat"
	else
		return JH.GetAddonInfo().szDataPath .. "Circle/" .. CIRCLE_PLAYER_NAME .. "/Circle.jx3dat"
	end
end

Circle = {
	nMaxAlpha = 50,
	bEnable = true,
	bTeamChat = false, -- 控制全局的团队频道
	bWhisperChat = false, -- 控制全局的密聊频道
	bBorder = true, -- 全局的边框模式 边框会造成卡
}
JH.RegisterCustomData("Circle")

local Circle = Circle
local C = {
	szIniFile = JH.GetAddonInfo().szRootPath .. "Circle/Circle.ini",
	tData = {},
	tDrawText = {},
	tTarget = {},
	tCache = {
		[TARGET.NPC] = {},
		[TARGET.DOODAD] = {},
	},
	tList = {
		[TARGET.NPC] = {},
		[TARGET.DOODAD] = {},
	},
	tScrutiny = {
		[TARGET.NPC] = {},
		[TARGET.DOODAD] = {},
	},
}

function C.GetData()
	return C.tData
end

function C.SaveFile()
	SaveLUAData(GetDataPath(), { Circle = C.tData })
end

-- 加载本地文件使用
function C.LoadFile(szFullPath, bMsg)
	szFullPath = szFullPath or GetDataPath()
	local code = LoadLUAData(szFullPath)
	if code then
		if type(code) == "table" then
			C.LoadCircleData(code, bMsg)
		else
			if bMsg then
				JH.Sysmsg2(_L["content errors."])
			end
		end
	else
		if bMsg then
			JH.Sysmsg2(_L["File does not exist, or content errors."])
		end
	end
end

function C.LoadCircleData(tData, bMsg)
	tData.Circle = tData.Circle or {}
	tData.Circle["mt"] = nil
	tData.Circle[-2]   = nil
	C.tData = tData.Circle
	FireUIEvent("CIRCLE_CLEAR")
	FireUIEvent("CIRCLE_DRAW_UI")
	if bMsg then
		JH.Sysmsg(_L["Circle loaded."])
	end
end

function C.LoadCircleMergeData(tData)
	local data = {}
	for k, v in pairs(tData.Circle) do
		if JH.IsMapExist(k) then
			data[tonumber(k)] = v
		end
	end
	for k, v in pairs(data) do
		if C.tData[k] then
			if JH.IsMapExist(k) then
				for kk, vv in ipairs(v) do
					if not C.CheckRepeatData(k, vv.key, vv.dwType) then
						table.insert(C.tData[k], vv)
					end
				end
			end
		else
			C.tData[k] = v
		end
	end
	FireUIEvent("CIRCLE_CLEAR")
	FireUIEvent("CIRCLE_DRAW_UI")
	JH.Sysmsg(_L["Circle loaded."])
end

function C.GetMapID()
	local mapid = GetClientPlayer().GetMapID()
	if JH_MAP_NAME_FIX[mapid] then
		mapid = JH_MAP_NAME_FIX[mapid]
	end
	return mapid
end

function C.Release()
	C.tScrutiny = {
		[TARGET.NPC] = {},
		[TARGET.DOODAD] = {},
	}
	C.tList = {
		[TARGET.NPC] = {},
		[TARGET.DOODAD] = {},
	}
	C.tCache = {
		[TARGET.NPC] = {},
		[TARGET.DOODAD] = {},
	}

	C.tTarget = {} -- clear
	-- 取得容器
	C.shCircle = JH.GetShadowHandle("Handle_Shadow_Circle")
	C.shLine = JH.GetShadowHandle("Handle_Shadow_Line")
	C.shName = JH.GetShadowHandle("Handle_Shadow_Name")
	C.shCircle:Clear()
	C.shLine:Clear()
	C.shName:Clear()
	C.shName = C.shName:AppendItemFromIni(SHADOW, "shadow", "Circle_NAME")
	C.shName:SetTriangleFan(GEOMETRY_TYPE.TEXT)
	-- 重建所有数据的metatable
	for k, v in pairs(C.tData) do
		for kk, vv in ipairs(v) do
			setmetatable(vv, { __index = function(_, val)
				if val == "dwMapID" then
					return k
				elseif val == "nIndex" then
					return kk
				end
			end })
		end
	end
	local mt = {
		__index = function(me, mapid)
			if mapid == _L["All Data"] then
				local dat = {}
				for k, v in pairs(me) do
					for kk, vv in ipairs(v) do
						tinsert(dat, vv)
					end
				end
				return dat
			end
		end
	}
	setmetatable(C.tData, mt)
end
-- 构建data table
function C.CreateData()
	pcall(C.Release)
	local mapid = C.GetMapID()
	-- 全地图数据
	if C.tData[-1] then
		for k, v in ipairs(C.tData[-1]) do
			C.tList[v.dwType][v.key] = C.tData[-1][k]
		end
	end
	if C.tData[mapid] then
		for k, v in ipairs(C.tData[mapid]) do
			C.tList[v.dwType][v.key] = C.tData[mapid][k]
		end
	end
	for k, v in pairs(JH.GetAllNpc()) do
		local t = C.tList[TARGET.NPC][v.dwTemplateID] or C.tList[TARGET.NPC][JH.GetObjName(v)]
		if t then
			C.tScrutiny[TARGET.NPC][v.dwID] = t
		end
	end
	for k, v in pairs(JH.GetAllDoodad()) do
		local t = C.tList[TARGET.DOODAD][v.dwTemplateID] or C.tList[TARGET.DOODAD][JH.GetObjName(v)]
		if t then
			C.tScrutiny[TARGET.DOODAD][v.dwID] = t
		end
	end
end

function C.AddData(dwMapID, data)
	C.tData[dwMapID] = C.tData[dwMapID] or {}
	tinsert(C.tData[dwMapID], data)
	FireUIEvent("CIRCLE_CLEAR")
	FireUIEvent("CIRCLE_DRAW_UI", dwMapID)
	return C.tData[dwMapID][#C.tData[dwMapID]]
end

function C.MoveOrder(dwMapID, nIndex, bUp)
	if C.tData[dwMapID] then
		if bUp then
			if nIndex ~= 1 then
				C.tData[dwMapID][nIndex], C.tData[dwMapID][nIndex - 1] = C.tData[dwMapID][nIndex - 1], C.tData[dwMapID][nIndex]
			end
		else
			if nIndex ~= #C.tData[dwMapID] then
				C.tData[dwMapID][nIndex], C.tData[dwMapID][nIndex + 1] = C.tData[dwMapID][nIndex + 1], C.tData[dwMapID][nIndex]
			end
		end
		FireUIEvent("CIRCLE_CLEAR")
		FireUIEvent("CIRCLE_DRAW_UI")
	end
end

function C.CheckRepeatData(dwMapID, key, dwType)
	if C.tData[dwMapID] then
		for k, v in ipairs(C.tData[dwMapID]) do
			if key == v.key and dwType == v.dwType then
				return k, v
			end
		end
	end
end

function C.MoveData(dwMapID, nIndex, dwTargetMapID, bCopy)
	if dwMapID == dwTargetMapID then
		return
	end
	if C.tData[dwMapID] and C.tData[dwMapID][nIndex] then
		local data = C.tData[dwMapID][nIndex]
		if C.CheckRepeatData(dwTargetMapID, data.key, data.dwType) then
			return JH.Alert(_L["same data Exist"])
		end
		C.tData[dwTargetMapID] = C.tData[dwTargetMapID] or {}
		tinsert(C.tData[dwTargetMapID], clone(C.tData[dwMapID][nIndex]))
		if not bCopy then
			C.RemoveData(dwMapID, nIndex)
		end
		FireUIEvent("CIRCLE_CLEAR")
		FireUIEvent("CIRCLE_DRAW_UI")
	end
end

function C.RemoveData(mapid, index, bConfirm)
	if C.tData[mapid] and C.tData[mapid][index] then
		local fnAction = function()
			table.remove(C.tData[mapid], index)
			if #C.tData[mapid] == 0 then
				C.tData[mapid] = nil
			end
			FireUIEvent("CIRCLE_CLEAR")
			FireUIEvent("CIRCLE_DRAW_UI")
		end
		if bConfirm then
			JH.Confirm(FormatString(g_tStrings.MSG_DELETE_NAME, C.tData[mapid][index].szNote or C.tData[mapid][index].key), fnAction)
		else
			fnAction()
		end
	end
end

function C.DrawLine(tar, ttar, sha, col, dwType)
	sha:SetTriangleFan(GEOMETRY_TYPE.LINE, 3)
	sha:ClearTriangleFanPoint()
	local r, g, b = unpack(col)
	if dwType == TARGET.DOODAD then
		sha:AppendDoodadID(tar.dwID, r, g, b, CIRCLE_LINE_ALPHA)
	elseif dwType == TARGET.NPC then
		sha:AppendCharacterID(tar.dwID, true, r, g, b, CIRCLE_LINE_ALPHA)
	elseif dwType == "Point" then -- 可能需要用到
		sha:AppendTriangleFan3DPoint(tar.nX, tar.nY, tar.nZ, r, g, b, CIRCLE_LINE_ALPHA)
	end
	sha:AppendCharacterID(ttar.dwID, true, r, g, b, CIRCLE_LINE_ALPHA)
	sha:Show()
end

function C.DrawShape(tar, sha, nAngle, nRadius, col, dwType, __Alpha)
	local nRadius = nRadius * 64
	local nFace = ceil(128 * nAngle / 360)
	local dwRad1 = pi * (tar.nFaceDirection - nFace) / 128
	if tar.nFaceDirection > (256 - nFace) then
		dwRad1 = dwRad1 - pi - pi
	end
	local dwRad2 = dwRad1 + (nAngle / 180 * pi)
	local nStep = 16
	if nAngle <= 45 then nStep = 180 end
	if nAngle == 360 then
		dwRad2 = dwRad2 + pi / 20
	end
	-- nAlpha 补偿
	local nAlpha = Circle.nMaxAlpha
	local ap = CIRCLE_ALPHA_STEP * (nRadius / 64)
	if ap > 35 then
		nAlpha = 15
	else
		nAlpha = nAlpha - ap
	end
	nAlpha = nAlpha + (360 - nAngle) / 6
	if nAlpha > Circle.nMaxAlpha then nAlpha = Circle.nMaxAlpha end
	if __Alpha then -- circle 2
		nAlpha = nAlpha - (__Alpha / 360 * nAlpha / 2)
	end
	local r, g, b = unpack(col)
	-- orgina point
	sha:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	sha:SetD3DPT(D3DPT.TRIANGLEFAN)
	sha:ClearTriangleFanPoint()
	if dwType == TARGET.DOODAD then
		sha:AppendDoodadID(tar.dwID, r, g, b, nAlpha)
	else
		sha:AppendCharacterID(tar.dwID, false, r, g, b, nAlpha)
	end
	sha:Show()
	-- relative points
	local sX, sZ = Scene_PlaneGameWorldPosToScene(tar.nX, tar.nY)
	repeat
		local sX_, sZ_ = Scene_PlaneGameWorldPosToScene(tar.nX + cos(dwRad1) * nRadius, tar.nY + sin(dwRad1) * nRadius)
		if dwType == TARGET.DOODAD then
			sha:AppendDoodadID(tar.dwID, r, g, b, nAlpha, { sX_ - sX, 0, sZ_ - sZ })
		else
			sha:AppendCharacterID(tar.dwID, false, r, g, b, nAlpha, { sX_ - sX, 0, sZ_ - sZ })
		end
		dwRad1 = dwRad1 + pi / nStep
	until dwRad1 > dwRad2
end

function C.DrawBorder(tar, sha, nAngle, nRadius, col, dwType)
	local nRadius = nRadius * 64
	local nThick = 1 + (5 * nRadius / 64 / 20)
	local nFace = ceil(128 * nAngle / 360)
	local dwRad1 = pi * (tar.nFaceDirection - nFace) / 128
	if tar.nFaceDirection > (256 - nFace) then
		dwRad1 = dwRad1 - pi - pi
	end
	local dwRad2 = dwRad1 + (nAngle / 180 * pi)
	local nStep = 16
	if nAngle <= 45 then nStep = 180 end
	if nAngle == 360 then
		dwRad2 = dwRad2 + pi / 20
	end
	local sX, sZ = Scene_PlaneGameWorldPosToScene(tar.nX, tar.nY)
	local r, g, b = unpack(col)
	sha:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	sha:SetD3DPT(D3DPT.TRIANGLESTRIP)
	sha:ClearTriangleFanPoint()
	repeat
		local tRad = { nRadius, nRadius - nThick }
		for _, v in ipairs(tRad) do
			local sX_, sZ_ = Scene_PlaneGameWorldPosToScene(tar.nX + cos(dwRad1) * v , tar.nY + sin(dwRad1) * v)
			if dwType == TARGET.DOODAD then
				sha:AppendDoodadID(tar.dwID, r, g, b, CIRCLE_LINE_ALPHA, { sX_ - sX, 0, sZ_ - sZ })
			else
				sha:AppendCharacterID(tar.dwID, false, r, g, b, CIRCLE_LINE_ALPHA, { sX_ - sX, 0, sZ_ - sZ })
			end
		end
		dwRad1 = dwRad1 + pi / nStep
	until dwRad1 > dwRad2
end

-- 绘制设置UI表格
function C.DrawTable()
	if not C.hSelect or not C.hSelect.self:IsValid() then
		return
	end
	if type(arg0) == "string" then
		C.hSelect:Text(arg0)
	elseif type(arg0) == "number" then
		C.hSelect:Text(JH.IsMapExist(arg0))
	end
	if C.hTable and C.hTable:IsValid() then
		local h, tab = C.hTable:Lookup("", "Handle_List"), {}
		local mapid = C.dwSelMapID or C.GetMapID()
		if mapid == _L["All Data"] then
			tab = C.tData[_L["All Data"]]
		else
			tab = C.tData[mapid] or tab
		end
		h:Clear()
		for k, v in ipairs(tab) do
			local szName = v.szNote or v.key
			if not C.szSearch or C.szSearch and tostring(szName):match(C.szSearch) or tostring(v.key):match(C.szSearch) then
				local item = h:AppendItemFromIni(C.szIniFile, "Handle_Item", k)
				if k % 2 == 0 then
					item:Lookup("Image_Line"):Hide()
				end
				local text = item:Lookup("Text_I_Name")
				text:SetText(v.szNote and string.format("%s (%s)", v.key, v.szNote) or v.key)
				local r, g, b = 255, 255, 255
				local vv = C.tData[v.dwMapID][v.nIndex]
				if vv.tCircles then
					r, g, b = unpack(vv.tCircles[1].col)
				end
				text:SetFontColor(r, g, b)
				local szMapName = JH.IsMapExist(v.dwMapID)
				item:Lookup("Text_I_Map"):SetText(szMapName)
				item.OnItemMouseEnter = function()
					this:Lookup("Image_Light"):Show()
				end
				item.OnItemMouseLeave = function()
					if this:Lookup("Image_Light") then
						this:Lookup("Image_Light"):Hide()
					end
				end
				if not v.bEnable then
					item:Lookup("Image_Btn"):SetFrame(5)
				end
				item:Lookup("Image_Btn").OnItemMouseEnter = function()
					local nFrame = this:GetFrame()
					this:SetFrame(nFrame == 6 and 7 or 3)
				end
				item:Lookup("Image_Btn").OnItemMouseLeave = function()
					local nFrame = this:GetFrame()
					this:SetFrame(nFrame == 7 and 6 or 5)
				end
				item:Lookup("Image_Btn").OnItemLButtonClick = function()
					local nFrame = this:GetFrame()
					C.tData[v.dwMapID][v.nIndex].bEnable = nFrame ~= 7
					FireUIEvent("CIRCLE_CLEAR")
					FireUIEvent("CIRCLE_DRAW_UI")
				end
				item.OnItemLButtonClick = function()
					C.OpenDataPanel(v)
				end
				item.OnItemRButtonClick = function()
					local szNote = v.szNote or g_tStrings.STR_NONE
					local menu = {
						{ szOption = g_tStrings.CHAT_NAME .. g_tStrings.STR_COLON .. v.key, bDisable = true },
						{ szOption = g_tStrings.CYCLOPAEDIA_NOTE_TEXT .. szNote, bDisable = true },
						{ bDevide = true },
						{ szOption = g_tStrings.STR_FRIEND_DEL, rgb = { 255, 0, 0 }, fnAction = function()
							C.RemoveData(v.dwMapID, v.nIndex, not IsAltKeyDown())
						end }
					}
					if mapid ~= _L["All Data"] then
						tinsert(menu, 4, { szOption = _L["Move up"], bDisable = k == 1, fnAction = function()
							C.MoveOrder(mapid, k, true)
						end })
						tinsert(menu, 5, { szOption = _L["Move down"], bDisable = k == #tab, fnAction = function()
							C.MoveOrder(mapid, k, false)
						end })
						tinsert(menu, 6, { bDevide = true })
					end
					PopupMenu(menu)
				end
				item:Show()
			end
		end
		h:FormatAllItemPos()
	end
end

function C.OnNpcEnter(szEvent)
	local npc = GetNpc(arg0)
	local t = C.tList[TARGET.NPC][npc.dwTemplateID] or C.tList[TARGET.NPC][JH.GetObjName(npc)]
	if t then
		C.tScrutiny[TARGET.NPC][arg0] = t
	end
end

function C.OnNpcLeave()
	if C.tScrutiny[TARGET.NPC][arg0] then
		if C.tCache[TARGET.NPC][arg0] then
			for k, v in pairs(C.tCache[TARGET.NPC][arg0].Circle) do
				C.shCircle:RemoveItem(v)
			end
			if C.tCache[TARGET.NPC][arg0].Line and C.tCache[TARGET.NPC][arg0].Line.item then
				C.shLine:RemoveItem(C.tCache[TARGET.NPC][arg0].Line.item)
			end
			C.tCache[TARGET.NPC][arg0] = nil
		end
		C.tScrutiny[TARGET.NPC][arg0] = nil
	end
end

function C.OnDoodadEnter()
	local v = GetDoodad(arg0)
	local t = C.tList[TARGET.DOODAD][v.dwTemplateID] or C.tList[TARGET.DOODAD][v.szName]
	if t then
		C.tScrutiny[TARGET.DOODAD][arg0] = t
	end
end

function C.OnDoodadLeave()
	if C.tScrutiny[TARGET.DOODAD][arg0] then
		if C.tCache[TARGET.DOODAD][arg0] then
			for k, v in pairs(C.tCache[TARGET.DOODAD][arg0].Circle) do
				C.shCircle:RemoveItem(v)
			end
			if C.tCache[TARGET.DOODAD][arg0].Line and C.tCache[TARGET.DOODAD][arg0].Line.item then
				C.shLine:RemoveItem(C.tCache[TARGET.DOODAD][arg0].Line.item)
			end
			C.tCache[TARGET.DOODAD][arg0] = nil
		end
		C.tScrutiny[TARGET.DOODAD][arg0] = nil
	end
end

function C.OnBreathe()
	-- NPC面向绘制
	local me = GetClientPlayer()
	if not me then return end
	for k, v in pairs(C.tScrutiny[TARGET.NPC]) do
		local data = v
		if data.bEnable then
			local KGNpc = GetNpc(k)
			if not C.tCache[TARGET.NPC][k] then
				C.tCache[TARGET.NPC][k] = {
					Circle = {},
					Line = {},
				}
			end
			if data.tCircles then
				if #data.tCircles > CIRCLE_MAX_CIRCLE then return end
				for i = #data.tCircles, 1, -1 do
					local kk, vv = i, data.tCircles[i]
					if vv.bEnable then
						local sha = C.tCache[TARGET.NPC][k].Circle
						if not sha[kk] then
							sha[kk] = C.shCircle:AppendItemFromIni(SHADOW, "shadow", k .. kk)
						end
						if sha[kk].nFaceDirection ~= KGNpc.nFaceDirection or CIRCLE_RESERT_DRAW then -- 面向不对 重绘
							sha[kk].nFaceDirection = KGNpc.nFaceDirection
							local __Alpha
							if #data.tCircles == 2 then
								__Alpha = data.tCircles[1].nAngle
							end
							C.DrawShape(KGNpc, sha[kk], vv.nAngle, vv.nRadius, vv.col, data.dwType, __Alpha)
						end
						if Circle.bBorder and vv.bBorder then
							local key = "B" .. kk
							if not sha[key] then
								sha[key] = C.shCircle:AppendItemFromIni(SHADOW, "shadow", k .. key)
							end
							if sha[key].nFaceDirection ~= KGNpc.nFaceDirection or CIRCLE_RESERT_DRAW then -- 面向不对 重绘
								sha[key].nFaceDirection = KGNpc.nFaceDirection
								C.DrawBorder(KGNpc, sha[key], vv.nAngle, vv.nRadius, vv.col, data.dwType)
							end
						end
					end
				end
			end
			if data.bDrawName then
				local tSelectObject = Scene_SelectObject("nearest")
				if (KGNpc.CanSeeName() and tSelectObject[1]["ID"] == KGNpc.dwID) or not KGNpc.CanSeeName() then
					tinsert(C.tDrawText, { KGNpc.dwID, data.szNote or data.key, { 255, 255, 0 }, TARGET.NPC, true })
				end
			end
			if data.bTarget then
				local sha = C.tCache[TARGET.NPC][k].Line
				local dwType, dwID = KGNpc.GetTarget()
				local tar = JH.GetTarget(dwType, dwID)
				if data.bDrawLine and dwID ~= 0 and dwType == TARGET.PLAYER and (not sha.item or sha.item and sha.item.dwID ~= dwID) and tar then
					if not data.bDrawLineSelf or data.bDrawLineSelf and dwID == me.dwID then
						sha.item = sha.item or C.shLine:AppendItemFromIni(SHADOW, "shadow", k)
						sha.item.dwID = dwID
						local col = dwID == me.dwID and { 255, 0, 128 } or { 255, 255, 0 }
						C.DrawLine(KGNpc, tar, sha.item, col, data.dwType)
					elseif sha.item then
						C.shLine:RemoveItem(sha.item)
						C.tCache[TARGET.NPC][k].Line = {}
					end
				elseif (not data.bDrawLine or dwID == 0 or dwType ~= TARGET.PLAYER or not tar) and sha.item then
					C.shLine:RemoveItem(sha.item)
					C.tCache[TARGET.NPC][k].Line = {}
				end
				if dwID ~= 0 and dwType == TARGET.PLAYER then
					local col = dwID == me.dwID and { 255, 0, 128 } or { 255, 255, 0 }
					tinsert(C.tDrawText, { KGNpc.dwID, JH.GetObjName(tar), col })
				end
				if dwID ~= 0 and dwType == TARGET.PLAYER and tar and (not C.tTarget[KGNpc.dwID] or C.tTarget[KGNpc.dwID] and C.tTarget[KGNpc.dwID] ~= dwID) then
					local szName = JH.GetObjName(tar)
					C.tTarget[KGNpc.dwID] = dwID
					if data.bScreenHead then
						FireUIEvent("JH_SCREENHEAD", tar.dwID, { txt = _L("Staring %s", data.szNote or data.key)})
					end
					if me.IsInRaid() then
						if Circle.bWhisperChat and data.bWhisperChat then
							JH.Talk(szName, _L("Warning: %s staring at %s", data.szNote or data.key, g_tStrings.STR_YOU))
						end
						if Circle.bTeamChat and data.bTeamChat then
							JH.Talk(_L("Warning: %s staring at %s", data.szNote or data.key, szName))
						end
					end
					if data.bFlash then
						if me.dwID == dwID then
							local xml = {}
							tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
							tinsert(xml, GetFormatText(data.szNote or data.key, 44, 255, 255, 0))
							tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
							tinsert(xml, GetFormatText(_L["staring at"], 44, 255, 255, 255))
							tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
							tinsert(xml, GetFormatText(g_tStrings.STR_YOU, 44, 255, 255, 0))
							tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
							FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
							FireUIEvent("JH_FS_CREATE", "Circle", { nTime  = 3, col = { 255, 0, 0 }, bFlash = true })
						else
							local xml = {}
							tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
							tinsert(xml, GetFormatText(data.szNote or data.key, 44, 255, 255, 0))
							tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
							tinsert(xml, GetFormatText(_L["staring at"], 44, 255, 255, 255))
							tinsert(xml, GetFormatText(_L["["], 44, 255, 255, 255))
							tinsert(xml, GetFormatText(szName, 44, 255, 255, 0))
							tinsert(xml, GetFormatText(_L["]"], 44, 255, 255, 255))
							FireUIEvent("JH_CA_CREATE", tconcat(xml), 3, true)
						end
					end
				end
			end
		end
	end
	-- DOODAD面向绘制
	for k, v in pairs(C.tScrutiny[TARGET.DOODAD]) do
		local data = v
		if data.bEnable then
			local KGDoodad = GetDoodad(k)
			if not C.tCache[TARGET.DOODAD][k] then
				C.tCache[TARGET.DOODAD][k] = {
					Circle = {},
					Line = {},
				}
			end
			if data.tCircles then
				if #data.tCircles > CIRCLE_MAX_CIRCLE then return end
				for i = #data.tCircles, 1, -1 do
					local kk, vv = i, data.tCircles[i]
					if vv.bEnable then
						local sha = C.tCache[TARGET.DOODAD][k].Circle
						if not sha[kk] then
							sha[kk] = C.shCircle:AppendItemFromIni(SHADOW, "shadow", k .. kk)
						end
						if sha[kk].nFaceDirection ~= KGDoodad.nFaceDirection or CIRCLE_RESERT_DRAW then -- 面向不对 重绘
							sha[kk].nFaceDirection = KGDoodad.nFaceDirection
							local __Alpha = #data.tCircles == 2 and data.tCircles[1].nAngle or nil
							C.DrawShape(KGDoodad, sha[kk], vv.nAngle, vv.nRadius, vv.col, data.dwType, __Alpha)
						end
						if Circle.bBorder and vv.bBorder then
							local key = "B" .. kk
							if not sha[key] then
								sha[key] = C.shCircle:AppendItemFromIni(SHADOW, "shadow", k .. key)
							end
							if sha[key].nFaceDirection ~= KGDoodad.nFaceDirection or CIRCLE_RESERT_DRAW then -- 面向不对 重绘
								sha[key].nFaceDirection = KGDoodad.nFaceDirection
								C.DrawBorder(KGDoodad, sha[key], vv.nAngle, vv.nRadius, vv.col, data.dwType)
							end
						end
					end
				end
			end
			local sha = C.tCache[TARGET.DOODAD][k].Line
			if data.bDoodadLine and not sha.item then
				sha.item = sha.item or C.shLine:AppendItemFromIni(SHADOW, "shadow", k)
				C.DrawLine(KGDoodad, me, sha.item, { 255, 128, 0 }, data.dwType)
			elseif not data.bDoodadLine and sha.item then
				C.shLine:RemoveItem(sha.item)
				C.tCache[TARGET.DOODAD][k].Line = {}
			end
			if data.bDrawName then
				tinsert(C.tDrawText, { KGDoodad.dwID, data.szNote or data.key, { 255, 128, 0 }, TARGET.DOODAD })
			end
		end
	end
	if C.shName then
		C.shName:ClearTriangleFanPoint()
		for _, v in ipairs(C.tDrawText) do
			local r, g, b = unpack(v[3])
			if v[4] ~= TARGET.DOODAD then
				C.shName:AppendCharacterID(v[1], v[5] or false, r, g, b, 255, 50, 40, v[2], 1, 1)
			else
				C.shName:AppendDoodadID(v[1], r, g, b, 255, 50, 40, v[2], 1, 1)
			end
		end
		C.tDrawText = {}
	end
	CIRCLE_RESERT_DRAW = false
end

-- 注册头像右键菜单
Target_AppendAddonMenu({ function(dwID, dwType)
	if dwType == TARGET.NPC then
		local p = GetNpc(dwID)
		local data = C.tList[TARGET.NPC][p.dwTemplateID] or C.tList[TARGET.NPC][JH.GetObjName(p)]
		if data then
			return {{
				szOption = _L["Edit Face"],
				rgb = { 255, 128, 0 },
				szLayer = "ICON_RIGHT",
				szIcon = "ui/Image/UICommon/Feedanimials.uitex",
				nFrame = 86,
				nMouseOverFrame = 87,
				fnClickIcon = function()
					C.RemoveData(data.dwMapID, data.nIndex, not IsCtrlKeyDown())
				end,
				fnAction = function()
					C.OpenDataPanel(data)
				end
			}}
		else
			return {{ szOption = _L["Add Face"], rgb = { 255, 255, 0 }, fnAction = function()
				C.OpenAddPanel(not IsAltKeyDown() and JH.GetObjName(p) or p.dwTemplateID, dwType, JH.IsMapExist(C.GetMapID()))
			end }}
		end
	else
		return {}
	end
end })

function C.OpenAddPanel(szName, dwType, szMap)
	dwType = dwType or TARGET.NPC
	GUI.CreateFrame("DBM_NewData", { w = 380, h = 250, title = _L["Add Face"], close = true, focus = true })
	-- update ui = wnd
	local ui = GUI(Station.Lookup("Normal/DBM_NewData"))
	ui:Append("Text", "Name", { txt = szName or _L["Please enter key"], font = 48, w = 380, h = 30, x = 0, y = 45, align = 1 })
	ui:Append("Text", { txt = _L["Key:"], font = 27, w = 105, h = 30, x = 0, y = 80, align = 2 })
	ui:Append("WndEdit", "Key", { txt = szName, x = 115, y = 83, enable = szName == nil })
	:Change(function(szText)
		ui:Fetch("Name"):Text(szText)
	end)
	ui:Append("Text", { txt = _L["Map:"], font = 27, w = 105, h = 30, x = 0, y = 110, align = 2 })
	if not szMap then
		szMap = tonumber(C.dwSelMapID) and JH.IsMapExist(C.dwSelMapID) or JH.IsMapExist(C.GetMapID())
	end
	ui:Append("WndEdit", "Map", { txt = szMap, x = 115, y = 113 })
	ui:Append("WndRadioBox", { x = 100, y = 150, txt = _L["NPC"], group = "type", checked = dwType == TARGET.NPC })
	:Enable(szName == nil):Click(function()
		dwType = TARGET.NPC
	end)
	ui:Append("WndRadioBox", { x = 180, y = 150, txt = _L["DOODAD"], group = "type", checked = dwType == TARGET.DOODAD })
	:Enable(szName == nil):Click(function()
		dwType = TARGET.DOODAD
	end)

	ui:Append("WndButton3", { txt = g_tStrings.STR_HOTKEY_SURE, x = 115, y = 185 })
	:Click(function()
		local map = JH.IsMapExist(ui:Fetch("Map"):Text())
		local key = tonumber(ui:Fetch("Key"):Text()) or ui:Fetch("Key"):Text()
		if JH.Trim(key) == "" then
			return  JH.Alert(_L["Please enter NPC name or Template ID."])
		end
		if map then
			local fnAction = function()
				local data = {
					key = key,
					dwType = dwType,
					bEnable = true,
					tCircles = { clone(CIRCLE_DEFAULT_DATA) }
				}
				C.OpenDataPanel(C.AddData(map, data))
				ui:Remove()
			end
			if C.tData[map] then
				local tab = select(2, C.CheckRepeatData(map, key, dwType))
				if tab then
					return JH.Confirm(_L["Data exists, editor?"], function()
						C.OpenDataPanel(tab)
						ui:Fetch("Btn_Close"):Click()
					end)
				end
			end
			pcall(fnAction)
		else
			JH.Alert(_L["The map does not exist"])
		end
	end)
end

function C.OpenDataPanel(data)
	local a = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
	if Station.Lookup("Normal/C_Data") then
		a = GetFrameAnchor(Station.Lookup("Normal/C_Data"))
	end
	GUI.CreateFrame("C_Data", { w = 380, h = 380, title = _L["Setting"], close = true, focus = true }):Point(a.s, 0, 0, a.r, a.x, a.y)
	-- update ui = wnd
	local frame = Station.Lookup("Normal/C_Data")
	local ui = GUI(frame)
	frame:RegisterEvent("CIRCLE_DRAW_UI")
	frame.OnEvent = function(szEvent)
		if szEvent == "CIRCLE_DRAW_UI" then
			ui:Remove()
		end
	end
	local file = "ui/Image/UICommon/Feedanimials.uitex"
	--58
	local title = data.szNote and string.format("%s(%s)", data.key, data.szNote) or data.key
	ui:Append("Image", { x = 59.5, y = 45, w = 261, h = 25, alpha = 180}):File(file, 58)
	local nX, nY = ui:Append("Text", "Name", { txt = title, font = 48, w = 380, h = 30, x = 0, y = 40, align = 1 }):Pos_()
	ui:Append("WndRadioBox", { x = 100, y = nY + 5, txt = _L["NPC"], group = "type", checked = data.dwType == TARGET.NPC })
	:Click(function()
		data.dwType = TARGET.NPC
		C.OpenDataPanel(data)
		FireUIEvent("CIRCLE_CLEAR")
	end)
	local nX, nY = ui:Append("WndRadioBox", { x = 180, y = nY + 5, txt = _L["DOODAD"], group = "type", checked = data.dwType == TARGET.DOODAD })
	:Click(function()
		data.dwType = TARGET.DOODAD
		C.OpenDataPanel(data)
		FireUIEvent("CIRCLE_CLEAR")
	end):Pos_()
	for k, v in ipairs(data.tCircles or {}) do
		nX = ui:Append("WndCheckBox", { x = 15, y = nY, txt = _L["Face Circle"], font = 27, checked = v.bEnable })
		:Click(function(bChecked)
			v.bEnable = bChecked
			FireUIEvent("CIRCLE_CLEAR")
		end):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 2, y = nY + 2, w = 35, h = 25, limit = 4 })
		:Enable(k ~= 2):Text(v.nAngle):Change(function(nVal)
			local n = tonumber(nVal) or 30
			if n < 1 or n > 360 then
				n = 30
				JH.Sysmsg2(_L["Limit 1, "] .. 360)
			end
			v.nAngle = n
			FireUIEvent("CIRCLE_RESERT_DRAW")
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 2, y = nY - 21 + 20, txt = _L[" degree"] }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 8, y = nY + 2, w = 35, h = 25, limit = 4 })
		:Text(v.nRadius):Change(function(nVal)
			local n = tonumber(nVal) or 1
			if n <= 0 or n > CIRCLE_MAX_RADIUS then
				n = 1
				JH.Sysmsg2(_L["Limit 0, "] .. CIRCLE_MAX_RADIUS)
			end
			v.nRadius = n
			FireUIEvent("CIRCLE_RESERT_DRAW")
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 2, y = nY - 21 + 20, txt = _L[" feet"] }):Pos_()
		nX = ui:Append("Shadow", "Color_" .. k, { x = nX + 5, y = nY + 2, color = v.col, w = 23, h = 23 })
		:Click(function()
			OpenColorTablePanel(function(r, g, b)
				ui:Fetch("Color_" .. k):Color(r, g, b)
				v.col = { r, g, b }
				FireUIEvent("CIRCLE_RESERT_DRAW")
			end, nil, nil, CIRCLE_COLOR)
			end):Pos_()
		nX = ui:Append("WndCheckBox", { x = nX + 2, y = nY + 1, txt = _L["Draw Border"], checked = v.bBorder })
		:Click(function(bChecked)
			v.bBorder = bChecked
			FireUIEvent("CIRCLE_CLEAR")
		end):Pos_()
		nX, nY = ui:Append("Image", { x = nX + 5, y = nY + 1, w = 26, h = 26 }):File(file, 86):Event(525311)
		:Hover(function() this:SetFrame(87) end, function() this:SetFrame(86) end):Click(function()
			if #data.tCircles == 1 then
				data.tCircles = nil
			else
				table.remove(data.tCircles, k)
			end
			C.OpenDataPanel(data)
			FireUIEvent("CIRCLE_CLEAR")
		end):Pos_()
	end
	nX, nY = ui:Append("WndCheckBox", { x = 15, y = nY, txt = _L["Mon Target"], font = 27, checked = data.bTarget })
	:Enable(data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bTarget = bChecked
		ui:Fetch("bTeamChat"):Enable(bChecked)
		ui:Fetch("bWhisperChat"):Enable(bChecked)
		ui:Fetch("bScreenHead"):Enable(bChecked)
		ui:Fetch("bFlash"):Enable(bChecked)
		ui:Fetch("bDrawLine"):Enable(bChecked)
		ui:Fetch("bDrawLineSelf"):Enable(bChecked and data.bDrawLine)
		FireUIEvent("CIRCLE_CLEAR")
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bTeamChat", { x = 25, y = nY, checked = data.bTeamChat, txt = _L["Team Channel"], color = GetMsgFontColor("MSG_TEAM", true) })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bTeamChat = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bWhisperChat", { x = nX + 5, y = nY, checked = data.bWhisperChat, txt = _L["Whisper Channel"], color = GetMsgFontColor("MSG_WHISPER", true) })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bWhisperChat = bChecked
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bScreenHead", { x = nX + 5, y = nY, checked = data.bScreenHead, txt = _L["Screen Head Alarm"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bScreenHead = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bFlash", { x = 25, y = nY, checked = data.bFlash, txt = _L["Center Alarm"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bFlash = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bDrawLine", { x = nX + 5, y = nY, checked = data.bDrawLine, txt = _L["Draw Line"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bDrawLine = bChecked
		FireUIEvent("CIRCLE_CLEAR")
		ui:Fetch("bDrawLineSelf"):Enable(bChecked)
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bDrawLineSelf", { x = nX + 5, y = nY, checked = data.bDrawLineSelf, txt = _L["Draw Line Only Self"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC and data.bDrawLine == true):Click(function(bChecked)
		data.bDrawLineSelf = bChecked
		FireUIEvent("CIRCLE_CLEAR")
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 15, y = nY, txt = _L["Other"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 25, y = nY + 10, checked = data.bDrawName, txt = _L["Draw Self Name"] })
	:Click(function(bChecked)
		data.bDrawName = bChecked
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bDoodadLine, txt = _L["Draw Doodad Line"] })
	:Enable(data.dwType == TARGET.DOODAD):Click(function(bChecked)
		data.bDoodadLine = bChecked
	end):Pos_()
	ui:Append("WndEdit", { x = 25, y = nY + 10, w = 310, h = 26 ,txt = data.szNote or g_tStrings.STR_FRIEND_REMARK, limit = 30, })
	:Focus(function()
		if this:GetText() == g_tStrings.STR_FRIEND_REMARK then
			this:SetText("")
		end
	end):Change(function(szText)
		if JH.Trim(szText) ~= "" then
			data.szNote = szText
			ui:Fetch("Name"):Text(string.format("%s(%s)", data.key, data.szNote))
		else
			ui:Fetch("Name"):Text(data.key)
			data.szNote = nil
		end
	end)
	local n = 0
	if data.tCircles then n = #data.tCircles end
	ui:Append("WndButton2", { x = 260, y = 330, txt = _L["Add Circle"] }):Enable(n < CIRCLE_MAX_CIRCLE)
	:Click(function()
		data.tCircles = data.tCircles or {}
		tinsert(data.tCircles, clone(CIRCLE_DEFAULT_DATA) )
		if #data.tCircles == 2 then	data.tCircles[2].nAngle = 360 end
		C.OpenDataPanel(data)
		FireUIEvent("CIRCLE_CLEAR")
	end)
	ui:Append("WndButton2", { x = 20, y = 330, txt = g_tStrings.STR_FRIEND_DEL, color = { 255, 0, 0 } })
	:Click(function()
		C.RemoveData(data.dwMapID, data.nIndex, not IsAltKeyDown())
	end)
end

function C.GetMemu()
	local menu = {
		{ szOption = _L["All Data"], fnAction = function()
			C.dwSelMapID = _L["All Data"]
			FireUIEvent("CIRCLE_DRAW_UI", _L["All Data"])
		end },
		{ bDevide = true },
		{ szOption = _L["Dungeon"] },
		{ szOption = _L["Other"] },
	}
	for i = -1, -2, -1 do
		if C.tData[i] then
			tinsert(menu, { szOption = JH.IsMapExist(i) .. string.format(" (%d)", #C.tData[i]),
				rgb = { 255, 180, 0 },
				szLayer = "ICON_RIGHT",
				szIcon = "ui/Image/UICommon/Feedanimials.uitex",
				nFrame = 86,
				nMouseOverFrame = 87,
				fnClickIcon = function()
					JH.Confirm(FormatString(g_tStrings.MSG_DELETE_NAME, JH.IsMapExist(i) .. string.format(" (%d)", #C.tData[i])), function()
						C.tData[i] = nil
						FireUIEvent("CIRCLE_DRAW_UI")
						FireUIEvent("CIRCLE_CLEAR")
					end)
				end,
				fnAction = function()
					C.dwSelMapID = i
					FireUIEvent("CIRCLE_DRAW_UI", i)
				end
			})
		end
	end
	for k, v in pairs(C.tData) do
		if k ~= -1 and k ~= -2 and JH.IsMapExist(k) then
			local tm, txt = menu[4], string.format(" (%d)", #v)
			if JH.IsInDungeon(k) then
				tm = menu[3]
			end
			tinsert(tm, { szOption = JH.IsMapExist(k) .. txt,
				rgb = { 255, 180, 0 },
				szLayer = "ICON_RIGHT",
				szIcon = "ui/Image/UICommon/Feedanimials.uitex",
				nFrame = 86,
				nMouseOverFrame = 87,
				fnClickIcon = function()
					JH.Confirm(FormatString(g_tStrings.MSG_DELETE_NAME, JH.IsMapExist(k) .. txt), function()
						C.tData[k] = nil
						FireUIEvent("CIRCLE_DRAW_UI")
						FireUIEvent("CIRCLE_CLEAR")
					end)
				end,
				fnAction = function()
					C.dwSelMapID = k
					FireUIEvent("CIRCLE_DRAW_UI", k)
				end
			})
			if k == C.GetMapID() then
				tm[#tm].szIcon = "ui/Image/Minimap/Minimap.uitex"
				tm[#tm].szLayer = "ICON_RIGHT"
				tm[#tm].nFrame = 10
				tm[#tm].nMouseOverFrame = nil
			end
		end
	end
	return menu
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX,nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Circle"], font = 27 }):Pos_()
	ui:Append("WndButton2", { x = 420, y = 0, txt = _L["New Face"] }):Click(C.OpenAddPanel)
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = Circle.bEnable, txt = _L["Circle Enable"] }):Click(function(bChecked)
		Circle.bEnable = bChecked
		if bChecked then
			C.Init()
			C.CreateData()
		else
			C.UnInit()
			C.Release()
		end
		ui:Fetch("bTeamChat"):Enable(bChecked)
		ui:Fetch("bWhisperChat"):Enable(bChecked)
		ui:Fetch("bBorder"):Enable(bChecked)
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bTeamChat", { x = nX + 5, y = nY + 10, checked = Circle.bTeamChat, txt = _L["Team Channel"], color = GetMsgFontColor("MSG_TEAM", true) })
	:Enable(Circle.bEnable):Click(function(bChecked)
		Circle.bTeamChat = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bWhisperChat", { x = nX + 5, y = nY + 10, checked = Circle.bWhisperChat, txt = _L["Whisper Channel"], color = GetMsgFontColor("MSG_WHISPER", true) })
	:Enable(Circle.bEnable):Click(function(bChecked)
		Circle.bWhisperChat = bChecked
	end):Pos_()

	nX,nY = ui:Append("WndCheckBox", "bBorder", { x = nX + 5, y = nY + 10, checked = Circle.bBorder, txt = _L["Circle Border"] }):Enable(Circle.bEnable):Click(function(bChecked)
		Circle.bBorder = bChecked
		FireUIEvent("CIRCLE_CLEAR")
	end):Pos_()
	if not C.dwSelMapID then C.dwSelMapID = _L["All Data"] end
	nX = ui:Append("WndComboBox", "Select", { x = 0, y = nY + 2, txt = JH.IsMapExist(C.dwSelMapID) or _L["All Data"] }):Menu(C.GetMemu):Pos_()

	ui:Append("WndEdit", "Search", { x = 330, y = nY + 2, txt = g_tStrings.SEARCH }):Focus(function()
		if ui:Fetch("Search"):Text() == g_tStrings.SEARCH then
			ui:Fetch("Search"):Text("")
		end
	end):Change(function(szText)
		if JH.Trim(szText) == "" then szText = nil end
		C.szSearch = szText
		FireUIEvent("CIRCLE_DRAW_UI")
	end):Pos_()

	local fx = Wnd.OpenWindow(C.szIniFile, "Circle")
	local win = fx:Lookup("WndScroll")
	win:ChangeRelation(frame, true, true)
	Wnd.CloseWindow(fx)
	win:SetRelPos(0, 80)
	C.hTable = win
	C.hSelect = ui:Fetch("Select")
	C.szSearch = nil
	FireUIEvent("CIRCLE_DRAW_UI")
end

GUI.RegisterPanel(_L["Circle"], { "ui/Image/UICommon/RaidTotal.uitex", 50 }, _L["Dungeon"], PS)

function C.Init()
	JH.RegisterInit("Circle",
		{ "Breathe", C.OnBreathe },
		{ "NPC_ENTER_SCENE", C.OnNpcEnter },
		{ "NPC_LEAVE_SCENE", C.OnNpcLeave },
		{ "DOODAD_ENTER_SCENE", C.OnDoodadEnter },
		{ "DOODAD_LEAVE_SCENE", C.OnDoodadLeave },
		{ "LOADING_END", C.CreateData },
		{ "CIRCLE_CLEAR", C.CreateData },
		{ "CIRCLE_RESERT_DRAW", function()
			CIRCLE_RESERT_DRAW = true
		end }
	)
end

function C.UnInit()
	JH.UnRegisterInit("Circle")
end
JH.RegisterExit(C.SaveFile)
JH.RegisterEvent("CIRCLE_DRAW_UI", C.DrawTable)
JH.RegisterEvent("LOADING_END", function()
	if CIRCLE_PLAYER_NAME == "NONE" then
		local me = GetClientPlayer()
		CIRCLE_PLAYER_NAME = me.szName -- 防止测试reload毁了所有数据
		C.LoadFile()
	end
end)
JH.RegisterEvent("CIRCLE_DEBUG", function()
	if JH_About.CheckNameEx() then
		Circle.nMaxAlpha, CIRCLE_ALPHA_STEP = arg0, arg1
		FireUIEvent("CIRCLE_CLEAR")
	end
end)
JH.RegisterEvent("LOGIN_GAME", function()
	if Circle.bEnable then
		C.Init()
	end
end)

JH.PlayerAddonMenu({ szOption = _L["Open Circle Panel"], fnAction = function()
	JH.OpenPanel(_L["Circle"])
end })

-- public
local ui = {
	OpenAddPanel        = C.OpenAddPanel,
	LoadCircleData      = C.LoadCircleData,
	LoadCircleMergeData = C.LoadCircleMergeData,
	GetData             = C.GetData,
	OpenDataPanel       = C.OpenDataPanel,
	MoveOrder           = C.MoveOrder,
	RemoveData          = C.RemoveData,
	MoveData            = C.MoveData,
	CheckRepeatData     = C.CheckRepeatData,
	AddData             = C.AddData
}
setmetatable(Circle, { __index = ui, __metatable = true, __newindex = function() end } )
