local _L = JH.LoadLangPack
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
local reverse, type, unpack, pcall = string.reverse, type, unpack, pcall
local setmetatable = setmetatable
local tostring, tonumber = tostring, tonumber
local ceil, cos, sin, pi = math.ceil, math.cos, math.sin, math.pi
local tinsert = table.insert
local JsonEncode, JsonDecode = JH.JsonEncode, JH.JsonDecode
local IsRemotePlayer, UI_GetClientPlayerID = IsRemotePlayer, UI_GetClientPlayerID

-- 常量 副本外大部分不受此限制
local SHADOW = JH.GetAddonInfo().szShadowIni
local CIRCLE_MAX_COUNT = 15 -- 默认副本最大数据量
local CIRCLE_CHANGE_TIME = 0 --7200 -- 暂不限制 加载数据后 再次加载数据的时间 2小时 避免一个BOSS一套数据
local CIRCLE_CIRCLE_ALPHA = 55 -- 最大的透明度 根据半径逐步降低 
local CIRCLE_MAX_RADIUS = 30 -- 最大的半径
local CIRCLE_LINE_ALPHA = 150 -- 线和边框最大透明度
local CIRCLE_RESERT_DRAW = false -- 全局重绘
local CIRCLE_PLAYER_NAME = "NONE"
local CIRCLE_DEFAULT_DATA = { bEnable = true, nAngle = 80, nRadius = 4, col = { 0, 255, 0 }, bBorder = true }
local CIRCLE_MAP_COUNT = { -- 部分副本地图数量补偿
	[-1] = 100, -- 全地图生效的东西
	[165] = 30, -- 英雄大明宫
	[164] = 30, -- 大明宫
	[160] = 20, -- 军械库
	[171] = 20, -- 英雄军械库
	[175] = 35, -- 血战天策
	[176] = 35, -- 英雄血战天策
}
-- 除上述外 其他一律 = 15
setmetatable(CIRCLE_MAP_COUNT, { __index = function() return CIRCLE_MAX_COUNT end, __metatable = true, __newindex = function() end })

local _GetMapName = Table_GetMapName
local function C_Table_GetMapName(mapid)
	if mapid == -1 then
		return _L["All Map"]
	end
	local szMap = _GetMapName(mapid)
	if szMap == "" then
		return tostring(mapid)
	else
		return szMap
	end
end

local function Confuse(tCode)
	if type(tCode) == "table" then
		return JsonEncode(tCode)
	else
		return JsonDecode(tCode)
	end
end

local function GetPlayerID()
	return JH.MD5(UI_GetClientPlayerID() .. "Circle")
end

-- 获取数据路径
local function GetDataPath()
	return JH.GetAddonInfo().szDataPath .. "Circle/" .. CIRCLE_PLAYER_NAME .. "/Circle.jx3dat"
end

Circle = {
	bEnable = true,
	nLimit = 0,
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
	tMapList  = {
		[_L["All Map"]] = { id = -1, bDungeon = true },
	},
}

do
	for k, v in ipairs(GetMapList()) do
		local szName = C_Table_GetMapName(v)
		local a = g_tTable.DungeonInfo:Search(v)
		C.tMapList[szName] = { id = v }
		if a and a.dwClassID == 3 then
			C.tMapList[szName].bDungeon = true
		end
	end
end

C.GetData = function()
	return C.tData
end

C.SaveFile = function(szFullPath, bMsg)
	szFullPath = szFullPath or GetDataPath()
	local data = {
		Circle = {},
	}
	for k, v in pairs(C.tData) do -- fix encode
		data.Circle[tostring(k)] = v
	end
	if not bMsg then
		if IsRemotePlayer(UI_GetClientPlayerID()) then
			return
		else
			data.code = GetPlayerID()
		end
	end
	local code = Confuse(data)
	SaveLUAData(szFullPath, code)
	if bMsg then
		JH.Alert(_L("Save success.\n Path:%s", szFullPath))
	end
end

-- 加载本地文件使用 bMsg相当于不需要效验
C.LoadFile = function(szFullPath, bMsg)
	szFullPath = szFullPath or GetDataPath()
	local code = LoadLUAData(szFullPath)
	if code then
		local data = Confuse(code)
		if type(data) == "table" then
			C.LoadCircleData(data, bMsg)
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

-- 导入数据基本使用同一个函数
-- 严格判断数量 传table
C.LoadCircleData = function(tData, bMsg)
	local data = {}
	if not bMsg then
		if IsRemotePlayer(UI_GetClientPlayerID()) or tData.code ~= GetPlayerID() then
			return JH.RegisterEvent("LOADING_END.LoadCircleData", C.LoadFile)
		end
		JH.UnRegisterEvent("LOADING_END.LoadCircleData")
	else
		if GetCurrentTime() - Circle.nLimit < CIRCLE_CHANGE_TIME then
			return JH.Sysmsg2(_L["Too frequent load file"])
		else
			Circle.nLimit = GetCurrentTime()
		end
	end
	for k, v in pairs(tData.Circle) do
		local map = C.tMapList[tonumber(k)]
		if map and map.bDungeon then
			if #v < CIRCLE_MAP_COUNT[tonumber(k)] then
				data[tonumber(k)] = v
			else
				JH.Debug2(_L["Length limit. # "] .. k)
			end
		else
			data[tonumber(k)] = v
		end
	end
	C.tData = data
	FireEvent("CIRCLE_CLEAR")
	FireEvent("CIRCLE_DRAW_UI")
	if bMsg then
		JH.Sysmsg2(_L["Circle loaded."])
	end
end

C.GetMapID = function()
	return GetClientPlayer().GetMapID()
end

C.Release = function()
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
end
-- 构建data table
C.CreateData = function()
	pcall(C.Release)
	local mapid = C.GetMapID()
	for k, v in ipairs(C.tData[mapid] or {}) do
		C.tList[v.dwType][v.key] = { id = mapid, index = k }
		setmetatable(C.tList[v.dwType][v.key], { __call = function() return C.tData[mapid][k] end })
	end
	-- 全地图数据
	if C.tData[-1] and C.tMapList[C_Table_GetMapName(mapid)] and not C.tMapList[C_Table_GetMapName(mapid)].bDungeon then
		for k, v in ipairs(C.tData[-1]) do
			C.tList[v.dwType][v.key] = { id = -1, index = k }
			setmetatable(C.tList[v.dwType][v.key], { __call = function() return C.tData[-1][k] end })
		end
	end
	for k, v in pairs(JH.GetAllNpc()) do
		local t = C.tList[TARGET.NPC][v.dwTemplateID] or C.tList[TARGET.NPC][JH.GetTemplateName(v)]
		if t then
			C.tScrutiny[TARGET.NPC][v.dwID] = t
		end
	end
	for k, v in pairs(JH.GetAllDoodad()) do
		local t = C.tList[TARGET.DOODAD][v.dwTemplateID] or C.tList[TARGET.DOODAD][JH.GetTemplateName(v)]
		if t then
			C.tScrutiny[TARGET.DOODAD][v.dwID] = t
		end
	end
end

C.RemoveData = function(mapid, index, bConfirm)
	if C.tData[mapid] and C.tData[mapid][index] then
		local fnAction = function() 
			table.remove(C.tData[mapid], index)
			FireEvent("CIRCLE_CLEAR")
			FireEvent("CIRCLE_DRAW_UI")
		end
		if bConfirm then
			JH.Confirm(FormatString(g_tStrings.MSG_DELETE_NAME, C.tData[mapid][index].szNote or C.tData[mapid][index].key), fnAction)
		else
			fnAction()
		end
	end
end

C.DrawText = function()
	local sha = C.shName
	sha:ClearTriangleFanPoint()
	for _ ,v in ipairs(C.tDrawText) do
		if not TargetFace or (TargetFace and (not TargetFace.bTTName or TargetFace.bTTName and TargetFace.GetTargetID() ~= v[1])) then
			local r, g, b = unpack(v[3])
			if v[4] ~= TARGET.DOODAD then
				sha:AppendCharacterID(v[1], v[5] or false, r, g, b, 255, 50, 40,v[2], 1, 1)
			else
				sha:AppendDoodadID(v[1], r, g, b, 255, 50, 40,v[2], 1, 1)
			end
		end
	end
	C.tDrawText = {}
end

C.DrawLine = function(tar, ttar, sha, col, dwType)
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

C.DrawShape = function(tar, sha, nAngle, nRadius, col, dwType)
	nRadius = nRadius * 64
	local nFace = ceil(128 * nAngle / 360)
	local dwRad1 = pi * (tar.nFaceDirection - nFace) / 128
	if tar.nFaceDirection > (256 - nFace) then
		dwRad1 = dwRad1 - pi - pi
	end
	local dwRad2 = dwRad1 + (nAngle / 180 * pi)
	local nStep = 18
	if nAngle == 360 then
		dwRad2 = dwRad2 + pi / 20
	end
	if nAngle <= 45 then nStep = 180 end
	local nAlpha = CIRCLE_CIRCLE_ALPHA
	if 2.5 * (nRadius / 64) > 40 then
		nAlpha = 10
	else
		nAlpha = nAlpha - 2.5 * (nRadius / 64)
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

C.DrawBorder = function(tar, sha, nAngle, nRadius, col, dwType)
	nRadius = nRadius * 64
	local nThick = 1 + (5 * nRadius / 64 / 20)
	local dwMaxRad = nAngle / 180 * pi
	local nFace = ceil(128 * nAngle / 360)
	local dwRad1 = pi * (tar.nFaceDirection - nFace) / 128
	if tar.nFaceDirection > (256 - nFace) then
		dwRad1 = dwRad1 - pi - pi
	end	
	local dwStepRadBase = nRadius / 128
	if dwStepRadBase < 2 then
		dwStepRadBase = 2
	end
	local dwStepRad = dwMaxRad / (nRadius / dwStepRadBase)
	local dwCurRad = 0 - dwStepRad
	local sX, sZ = Scene_PlaneGameWorldPosToScene(tar.nX, tar.nY)
	local r, g, b = unpack(col)
	sha:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	sha:SetD3DPT(D3DPT.TRIANGLESTRIP)
	sha:ClearTriangleFanPoint()
	repeat
		local tRad = {
			{ nRadius, dwCurRad },
			{ nRadius - nThick, dwCurRad }
		}
		for _, v in ipairs(tRad) do
			local nX = tar.nX + cos((v[2] + dwRad1)) * v[1]
			local nY = tar.nY + sin((v[2] + dwRad1)) * v[1]
			local sX_,sZ_ = Scene_PlaneGameWorldPosToScene(nX ,nY)
			if dwType == TARGET.DOODAD then
				sha:AppendDoodadID(tar.dwID, r, g, b, CIRCLE_LINE_ALPHA, { sX_ - sX, 0, sZ_ - sZ })
			else
				sha:AppendCharacterID(tar.dwID, false, r, g, b, CIRCLE_LINE_ALPHA, { sX_ - sX, 0, sZ_ - sZ })
			end
		end
		dwCurRad = dwCurRad + dwStepRad
	until dwMaxRad <= dwCurRad
end

-- 绘制设置UI表格
C.DrawTable = function()
	if Station.Lookup("Normal/C_Data") then
		Wnd.CloseWindow(Station.Lookup("Normal/C_Data"))
	end
	if C.hTable and C.hTable:IsValid() then
		local h, tab = C.hTable:Lookup("", "Handle_List"), {}
		local mapid = C.dwSelMapID or C.GetMapID()
		if mapid == _L["All Circle"] then
			for k, v in pairs(C.tData) do
				for kk, vv in ipairs(v) do
					table.insert(tab, { key = vv.szNote or vv.key, id = k, index = kk, bEnable = vv.bEnable })
				end
			end
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
				item:Lookup("Text_I_Name"):SetText(v.szNote or v.key)
				local szMapName = C_Table_GetMapName(mapid)
				if v.id then
					szMapName = C_Table_GetMapName(v.id)
				end
				item:Lookup("Text_I_Map"):SetText(szMapName)
				item.OnItemMouseEnter = function()
					this:Lookup("Image_Light"):Show()
				end
				item.OnItemMouseLeave = function()
					this:Lookup("Image_Light"):Hide()
				end
				if not v.bEnable then
					item:Lookup("Image_Btn"):SetFrame(5)
				end
				item:Lookup("Image_Btn").OnItemMouseEnter = function()
					local nFrame = this:GetFrame()
					if nFrame == 6 then
						this:SetFrame(7)
					else
						this:SetFrame(3)
					end
				end
				item:Lookup("Image_Btn").OnItemMouseLeave = function()
					local nFrame = this:GetFrame()
					if nFrame == 7 then
						this:SetFrame(6)
					else
						this:SetFrame(5)
					end
				end
				item:Lookup("Image_Btn").OnItemLButtonClick = function()
					local nFrame = this:GetFrame()
					if nFrame == 7 then
						C.tData[v.id or mapid][v.index or k].bEnable = false
					else
						C.tData[v.id or mapid][v.index or k].bEnable = true
					end
					FireEvent("CIRCLE_CLEAR")
					FireEvent("CIRCLE_DRAW_UI")
				end
				item.OnItemLButtonClick = function()
					C.OpenDataPanel(C.tData[v.id or mapid][v.index or k], v.id or mapid, v.index or k)
				end
				item.OnItemRButtonClick = function()
					local szNote = v.szNote or g_tStrings.STR_NONE
					local menu = {
						{ szOption = g_tStrings.CHAT_NAME .. g_tStrings.STR_COLON .. v.key, bDisable = true },
						{ szOption = g_tStrings.CYCLOPAEDIA_NOTE_TEXT .. szNote, bDisable = true },
						{ bDevide = true },
						{ szOption = g_tStrings.STR_FRIEND_DEL, rgb = { 255, 0, 0 }, fnAction = function()
							C.RemoveData(v.id or mapid, v.index or k, not IsAltKeyDown())
						end }
					}
					PopupMenu(menu)
				end
				item:Show()
			end
		end
		h:FormatAllItemPos()
	end
end

C.OnNpcEnter = function(szEvent)
	local v = GetNpc(arg0)
	local t = C.tList[TARGET.NPC][v.dwTemplateID] or C.tList[TARGET.NPC][JH.GetTemplateName(v)]
	if t then
		C.tScrutiny[TARGET.NPC][arg0] = t
	end
end

C.OnNpcLeave = function()
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

C.OnDoodadEnter = function()
	local v = GetDoodad(arg0)
	local t = C.tList[TARGET.DOODAD][v.dwTemplateID] or C.tList[TARGET.DOODAD][v.szName]
	if t then
		C.tScrutiny[TARGET.DOODAD][arg0] = t
	end
end

C.OnDoodadLeave = function()
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

C.OnBreathe = function()
	-- NPC面向绘制
	local me = GetClientPlayer()
	if not me then return end
	for k, v in pairs(C.tScrutiny[TARGET.NPC]) do
		local data = v()
		if data.bEnable then
			local KGNpc = GetNpc(k)
			if not C.tCache[TARGET.NPC][k] then
				C.tCache[TARGET.NPC][k] = {
					Circle = {},
					Line = {},
				}
			end
			for i = #data.tCircles, 1, -1 do
				local kk, vv = i, data.tCircles[i]
				if vv.bEnable then
					local sha = C.tCache[TARGET.NPC][k].Circle
					if not sha[kk] then
						sha[kk] = C.shCircle:AppendItemFromIni(SHADOW, "shadow", k .. kk)
					end
					if sha[kk].nFaceDirection ~= KGNpc.nFaceDirection or CIRCLE_RESERT_DRAW then -- 面向不对 重绘
						sha[kk].nFaceDirection = KGNpc.nFaceDirection
						C.DrawShape(KGNpc, sha[kk], vv.nAngle, vv.nRadius, vv.col, data.dwType)
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
			if data.bDrawName then
				table.insert(C.tDrawText, { KGNpc.dwID, data.szNote or data.key, { 0, 255, 0 }, TARGET.NPC, true })
			end
			if data.bTarget then
				local sha = C.tCache[TARGET.NPC][k].Line
				local dwType, dwID = KGNpc.GetTarget()
				local tar = JH.GetTarget(dwType, dwID)
				if data.bDrawLine and dwID ~= 0 and dwType == TARGET.PLAYER and not sha.item and sha.dwID ~= dwID and tar then
					if not data.bDrawLineSelf or data.bDrawLineSelf and dwID == me.dwID then
						sha.item = sha.item or C.shLine:AppendItemFromIni(SHADOW, "shadow", k)
						sha.dwID = dwID
						local col = { 255, 255, 0 }
						if dwID == me.dwID then
							col = { 255, 0, 128 }
						end
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
					local col = { 255, 255, 0 }
					if dwID == me.dwID then
						col = { 255, 0, 128 }
					end
					table.insert(C.tDrawText, { KGNpc.dwID, JH.GetTemplateName(tar), col })
				end
				if dwID ~= 0 and dwType == TARGET.PLAYER and tar and (not C.tTarget[KGNpc.dwID] or C.tTarget[KGNpc.dwID] and C.tTarget[KGNpc.dwID] ~= dwID) then
					local szName = JH.GetTemplateName(tar)
					C.tTarget[KGNpc.dwID] = dwID
					if data.bScreenHead then
						FireEvent("JH_SCREENHEAD", tar.dwID, { txt = _L("Staring %s", szName)})
					end
					if me.IsInRaid() then
						if Circle.bWhisperChat and data.bWhisperChat then
							JH.Talk(szName, _L("Warning: %s staring at you", data.szNote or data.key))
						end
						if Circle.bTeamChat and data.bTeamChat then
							JH.Talk(szName, _L("Warning: %s staring at %s", data.szNote or data.key, szName))
						end
					end
					-- RaidGrid_RedAlarm这个还没重构 先这样 
					if data.bFlash and RaidGrid_RedAlarm then
						if me.dwID == dwID then
							RaidGrid_RedAlarm.FlashOrg(2, _L("%s staring at you", data.szNote or data.key), true, true, 255, 0, 0)
						else
							RaidGrid_RedAlarm.FlashOrg(2, _L("%s staring at %s", data.szNote or data.key, szName), false, true, 255, 0, 0)
						end
					end
				end
			end
		end
	end
	-- DOODAD面向绘制
	for k, v in pairs(C.tScrutiny[TARGET.DOODAD]) do
		local data = v()
		if data.bEnable then
			local KGDoodad = GetDoodad(k)
			if not C.tCache[TARGET.DOODAD][k] then
				C.tCache[TARGET.DOODAD][k] = {
					Circle = {},
					Line = {},
				}
			end
			for i = #data.tCircles, 1, -1 do
				local kk, vv = i, data.tCircles[i]
				if vv.bEnable then
					local sha = C.tCache[TARGET.DOODAD][k].Circle
					if not sha[kk] then
						sha[kk] = C.shCircle:AppendItemFromIni(SHADOW, "shadow", k .. kk)
					end
					if sha[kk].nFaceDirection ~= KGDoodad.nFaceDirection or CIRCLE_RESERT_DRAW then -- 面向不对 重绘
						sha[kk].nFaceDirection = KGDoodad.nFaceDirection
						C.DrawShape(KGDoodad, sha[kk], vv.nAngle, vv.nRadius, vv.col, data.dwType)
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
			local sha = C.tCache[TARGET.DOODAD][k].Line
			if data.bDoodadLine and not sha.item then
				sha.item = sha.item or C.shCircle:AppendItemFromIni(SHADOW, "shadow", k)
				C.DrawLine(KGDoodad, me, sha.item, { 255, 128, 0 }, data.dwType)
			elseif not data.bDoodadLine and sha.item then
				C.shLine:RemoveItem(sha.item)
				C.tCache[TARGET.DOODAD][k].Line = {}
			end
			if data.bDrawName then
				table.insert(C.tDrawText, { KGDoodad.dwID, data.szNote or data.key, { 255, 128, 0 }, TARGET.DOODAD })
			end
		end
	end
	pcall(C.DrawText)
	CIRCLE_RESERT_DRAW = false
end

C.Init = function()
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
	Circle.bEnable = true
end

C.UnInit = function()
	C.Release()
	JH.UnRegisterInit("Circle")
	Circle.bEnable = false
end

-- 注册头像右键菜单
Target_AppendAddonMenu({function(dwID, dwType)
	if dwType == TARGET.NPC then
		local p = GetNpc(dwID)
		local data = C.tList[TARGET.NPC][p.dwTemplateID] or C.tList[TARGET.NPC][JH.GetTemplateName(p)]
		if data then
			return {{ 
				szOption = _L["Edit Face"],
				rgb = { 255, 128, 0 }, 
				szLayer = "ICON_RIGHT",
				szIcon = "ui/Image/UICommon/CommonPanel4.uitex",
				nFrame = 72,
				fnClickIcon = function()
					C.RemoveData(data.id, data.index, not IsCtrlKeyDown())
				end,
				fnAction = function()
					C.OpenDataPanel(C.tData[data.id][data.index], data.id, data.index)
				end 
			}}
		else
			return {{ szOption = _L["Add Face"], rgb = { 255, 255, 0 }, fnAction = function()
				if IsAltKeyDown() then
					C.OpenAddPanel(p.dwTemplateID, dwType)
				else
					C.OpenAddPanel(JH.GetTemplateName(p), dwType)
				end
			end }}
		end
	else
		return {}
	end
end })

C.OpenAddPanel = function(szName, dwType)
	if Station.Lookup("Normal/C_NewFace") then
		Wnd.CloseWindow(Station.Lookup("Normal/C_NewFace"))
	end
	dwType = dwType or TARGET.NPC
	GUI.CreateFrame("C_NewFace", { w = 380, h = 250, title = _L["Add Face"], close = true }):RegisterClose()
	-- update ui = wnd
	local ui = GUI(Station.Lookup("Normal/C_NewFace"))
	ui:Append("Text", "Name", { txt = szName or _L["Please enter key"], font = 200, w = 380, h = 30, x = 0, y = 50, align = 1 })
	ui:Append("Text", { txt = _L["Key:"], font = 27, w = 105, h = 30, x = 0, y = 80, align = 2 })
	ui:Append("WndEdit", "Key", { txt = szName, x = 115, y = 83, enable = szName == nil, limit = 20 })
	:Change(function(szText)
		ui:Fetch("Name"):Text(szText)
	end)
	ui:Append("Text", { txt = _L["Map:"], font = 27, w = 105, h = 30, x = 0, y = 110, align = 2 })
	ui:Append("WndEdit", "Map", { txt = C_Table_GetMapName(C.GetMapID()), x = 115, y = 113, limit = 20 })
	
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
		local map = C.tMapList[ui:Fetch("Map"):Text()]
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
				if not C.tData[map.id] then
					C.tData[map.id] = {}
				end
				table.insert(C.tData[map.id], data)
				FireEvent("CIRCLE_CLEAR")
				FireEvent("CIRCLE_DRAW_UI")
				C.OpenDataPanel(C.tData[map.id][#C.tData[map.id]], map.id, #C.tData[map.id])
				ui:Fetch("Btn_Close"):Click()
			end
			if C.tData[map.id] then
				for k, v in ipairs(C.tData[map.id]) do
					if v.key == key and v.dwType == dwType then
						JH.Confirm(_L["Data already exists, whether editor?"], function()
						end)
						return
					end
				end
			end
			if map.bDungeon then
				local n = 0
				if C.tData[map.id] then
					n = #C.tData[map.id]
				end
				if n < CIRCLE_MAP_COUNT[map.id] then
					pcall(fnAction)
				else
					JH.Alert(_L("%s Unable to add more data", ui:Fetch("Map"):Text()))
				end
			else
				pcall(fnAction)
			end
		else
			JH.Alert(_L["The map does not exist"])
		end
	end)
end

C.OpenDataPanel = function(data, id, index)
	if Station.Lookup("Normal/C_Data") then
		Wnd.CloseWindow(Station.Lookup("Normal/C_Data"))
	end
	GUI.CreateFrame("C_Data", { w = 380, h = 380, title = _L["Setting"], close = true }):RegisterClose()
	-- update ui = wnd
	local ui = GUI(Station.Lookup("Normal/C_Data"))
	local nX, nY = ui:Append("Text", "Name", { txt = data.szNote or data.key, font = 200, w = 380, h = 30, x = 0, y = 40, align = 1 }):Pos_()
	ui:Append("WndRadioBox", { x = 100, y = nY + 5, txt = _L["NPC"], group = "type", checked = data.dwType == TARGET.NPC })
	:Click(function()
		data.dwType = TARGET.NPC
		C.OpenDataPanel(data, id, index)
		FireEvent("CIRCLE_CLEAR")
	end)
	local nX, nY = ui:Append("WndRadioBox", { x = 180, y = nY + 5, txt = _L["DOODAD"], group = "type", checked = data.dwType == TARGET.DOODAD })
	:Click(function()
		data.dwType = TARGET.DOODAD
		C.OpenDataPanel(data, id, index)
		FireEvent("CIRCLE_CLEAR")
	end):Pos_()
	for k, v in ipairs(data.tCircles) do
		nX = ui:Append("WndCheckBox", { x = 20, y = nY, txt = _L["Face Circle"], font = 27, checked = v.bEnable })
		:Click(function(bChecked)
			v.bEnable = bChecked
			FireEvent("CIRCLE_CLEAR")
		end):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 2, y = nY - 18 + 20, w = 35, h = 25 })
		:Enable(k ~= 2):Text(v.nAngle):Change(function(nVal)
			nVal = tonumber(nVal) or 30
			if nVal < 2 or nVal > 360 then
				nVal = 30
			end
			v.nAngle = nVal
			FireEvent("CIRCLE_RESERT_DRAW")
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 2, y = nY - 21 + 20, txt = _L[" degree"] }):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 8, y = nY - 18 + 20, w = 35, h = 25 })
		:Text(v.nRadius):Change(function(nVal)
			nVal = tonumber(nVal) or 1
			if nVal < 0 or nVal > CIRCLE_MAX_RADIUS then
				nVal = 1
			end
			v.nRadius = nVal
			FireEvent("CIRCLE_RESERT_DRAW")
		end):Pos_()
		nX = ui:Append("Text", { x = nX + 2, y = nY - 21 + 20, txt = _L[" feet"] }):Pos_()
		nX = ui:Append("Shadow", "Color_" .. k, { x = nX + 5, y = nY - 18 + 20, color = v.col, w = 23, h = 23 })
		:Click(function()
			OpenColorTablePanel(function(r, g, b)
				ui:Fetch("Color_" .. k):Color(r, g, b)
				v.col = { r, g, b }
				FireEvent("CIRCLE_RESERT_DRAW")
			end,nil,nil,{
				{ r = 0, g = 255, b = 0},
				{ r = 0, g = 255, b = 255},
				{ r = 255, g = 0, b = 0},
				{ r = 40, g = 140, b = 218},
				{ r = 211, g = 229, b = 37},
				{ r = 65, g = 50, b = 160},
				{ r = 170, g = 65, b = 180},
				{ r = 255, g = 255, b = 255},
			})
			end):Pos_()
		nX, nY = ui:Append("WndCheckBox", { x = nX + 2, y = nY - 19 + 20, txt = _L["Draw Border"], checked = v.bBorder })
		:Click(function(bChecked)
			v.bBorder = bChecked
			FireEvent("CIRCLE_CLEAR")
		end):Pos_()
	end
	nX, nY = ui:Append("WndCheckBox", { x = 20, y = nY + 10, txt = _L["Mon Target"], font = 27, checked = data.bTarget })
	:Enable(data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bTarget = bChecked
		ui:Fetch("bTeamChat"):Enable(bChecked)
		ui:Fetch("bWhisperChat"):Enable(bChecked)
		ui:Fetch("bScreenHead"):Enable(bChecked)
		ui:Fetch("bFlash"):Enable(bChecked)
		ui:Fetch("bDrawLine"):Enable(bChecked)
		ui:Fetch("bDrawLineSelf"):Enable(bChecked)
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bTeamChat", { x = 30, y = nY, checked = data.bTeamChat, txt = _L["RaidAlert"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bTeamChat = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bWhisperChat", { x = nX + 5, y = nY, checked = data.bWhisperChat, txt = _L["WhisperAlert"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bWhisperChat = bChecked
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bScreenHead", { x = nX + 5, y = nY, checked = data.bScreenHead, txt = _L["HeadAlert"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bScreenHead = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bFlash", { x = 30, y = nY, checked = data.bFlash, txt = _L["CenterAlarm"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bFlash = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bDrawLine", { x = nX + 5, y = nY, checked = data.bDrawLine, txt = _L["Draw Line"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bDrawLine = bChecked
		FireEvent("CIRCLE_CLEAR")
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bDrawLineSelf", { x = nX + 5, y = nY, checked = data.bDrawLineSelf, txt = _L["Draw Line Only Self"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bDrawLineSelf = bChecked
		FireEvent("CIRCLE_CLEAR")
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 20, y = nY, txt = _L["Other"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 30, y = nY + 10, checked = data.bDrawName, txt = _L["Draw Self Name"] })
	:Click(function(bChecked)
		data.bDrawName = bChecked
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bDoodadLine, txt = _L["Draw Doodad Line"] })
	:Enable(data.dwType == TARGET.DOODAD):Click(function(bChecked)
		data.bDoodadLine = bChecked
	end):Pos_()
	ui:Append("WndEdit", { x = 30, y = nY + 10, w = 310, h = 26 ,txt = data.szNote or g_tStrings.STR_FRIEND_REMARK })
	:Focus(function()
		if this:GetText() == g_tStrings.STR_FRIEND_REMARK then
			this:SetText("")
		end
	end):Change(function(szText)
		if JH.Trim(szText) ~= "" then
			data.szNote = szText
			ui:Fetch("Name"):Text(szText)
		else
			ui:Fetch("Name"):Text(data.key)
			data.szNote = nil
		end
	end)
	ui:Append("WndButton2", { x = 250, y = 330, txt = _L["Add Circle"] }):Enable(#data.tCircles < 2)
	:Click(function()
		table.insert(data.tCircles, clone(CIRCLE_DEFAULT_DATA) )
		data.tCircles[2].nAngle = 360
		C.OpenDataPanel(data, id, index)
	end)
	ui:Append("WndButton2", { x = 20, y = 330, txt = g_tStrings.STR_FRIEND_DEL, color = { 255, 0, 0 } })
	:Click(function()
		C.RemoveData(id, index, not IsAltKeyDown())
	end)
	
end

-- bTargetName

local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX,nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Circle"], font = 27 }):Pos_()
	ui:Append("WndButton2", { x = 420, y = 0, txt = _L["New Face"] }):Click(C.OpenAddPanel)
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = Circle.bEnable, txt = _L["Circle Enable"] }):Click(function(bChecked)
		Circle.bEnable = bChecked
		if bChecked then
			C.Init()
		else
			C.UnInit()
		end
		ui:Fetch("bTeamChat"):Enable(bChecked)
		ui:Fetch("bWhisperChat"):Enable(bChecked)
		ui:Fetch("bBorder"):Enable(bChecked)
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bTeamChat", { x = nX + 5, y = nY + 10, checked = Circle.bTeamChat, txt = _L["RaidAlert"] }):Enable(Circle.bEnable):Click(function(bChecked)
		Circle.bTeamChat = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bWhisperChat", { x = nX + 5, y = nY + 10, checked = Circle.bWhisperChat, txt = _L["WhisperAlert"] }):Enable(Circle.bEnable):Click(function(bChecked)
		Circle.bWhisperChat = bChecked
	end):Pos_()
	
	nX,nY = ui:Append("WndCheckBox", "bBorder", { x = nX + 5, y = nY + 10, checked = Circle.bEnable, txt = _L["Circle Border"] }):Enable(Circle.bEnable):Click(function(bChecked)
		Circle.bBorder = bChecked
		FireEvent("CIRCLE_CLEAR")
	end):Pos_()
	local mapid = C.dwSelMapID or C.GetMapID()
	nX = ui:Append("WndComboBox", "Select", { x = 0, y = nY + 2, txt = C_Table_GetMapName(mapid) }):Menu(function()
		local menu = {
			{ szOption =  _L["All Circle"], fnAction = function()
				C.dwSelMapID = _L["All Circle"]
				FireEvent("CIRCLE_DRAW_UI")
				ui:Fetch("Select"):Text(_L["All Circle"])
			end },
			{ bDevide = true }
		}
		for k, v in pairs(C.tData) do
			table.insert(menu, { szOption = C_Table_GetMapName(k), fnAction = function() 
				C.dwSelMapID = k
				FireEvent("CIRCLE_DRAW_UI")
				ui:Fetch("Select"):Text(C_Table_GetMapName(k))
			end })
			if k == C.GetMapID() then
				menu[#menu].szIcon = "ui/Image/Minimap/Minimap.uitex"
				menu[#menu].szLayer = "ICON_RIGHT"
				menu[#menu].nFrame = 10
			end
		end
		if #menu == 0 then
			table.insert(menu, { szOption = _L["None Data"], bDisable = true })
		end
		return menu
	end):Pos_()
	
	ui:Append("WndEdit", "Search", { x = 330, y = nY + 2, txt = g_tStrings.SEARCH }):Focus(function()
		if ui:Fetch("Search"):Text() == g_tStrings.SEARCH then
			ui:Fetch("Search"):Text("")
		end
	end):Change(function(szText)
		if JH.Trim(szText) == "" then szText = nil end
		C.szSearch = szText
		FireEvent("CIRCLE_DRAW_UI")
	end):Pos_()
	
	local fx = Wnd.OpenWindow(C.szIniFile, "Circle")
	local win = fx:Lookup("WndScroll")
	win:ChangeRelation(frame, true, true)
	Wnd.CloseWindow(fx)
	win:SetRelPos(0, 80)
	C.hTable = win
	C.szSearch = nil
	FireEvent("CIRCLE_DRAW_UI")
end

GUI.RegisterPanel(_L["Circle"], 2402, _L["RGES"], PS)

JH.RegisterEvent("LOGIN_GAME", function()
	if not Circle.bEnable then return end
	C.Init()
end)

JH.RegisterEvent("GAME_EXIT", C.SaveFile)
JH.RegisterEvent("PLAYER_EXIT_GAME", C.SaveFile)
JH.RegisterEvent("FIRST_LOADING_END", function()
	local me = GetClientPlayer()
	CIRCLE_PLAYER_NAME = me.szName -- 防止测试reload毁了所有数据
	C.LoadFile()
end)
JH.RegisterEvent("CIRCLE_DRAW_UI", C.DrawTable)
JH.PlayerAddonMenu({ szOption = _L["Open Circle Panel"], fnAction = function()
	JH.OpenPanel(_L["Circle"])
end })
-- public
local ui = {
	OpenAddPanel = C.OpenAddPanel,
	LoadFile = C.LoadFile,
	SaveFile = C.SaveFile,
	GetData = C.GetData,
}
setmetatable(Circle, { __index = ui, __metatable = true, __newindex = function() end } )
