-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   William Chan
-- @Last Modified time: 2017-06-02 14:03:23

-- 方案已废弃 需要合并到 DBM 但由于目前数据结构问题 和DBM部分不兼容
-- 避免玩家重做数据 暂时不做修改
local _L = JH.LoadLangPack
local pairs, ipairs = pairs, ipairs
local type, unpack, pcall = type, unpack, pcall
local setmetatable = setmetatable
local tostring, tonumber = tostring, tonumber
local ceil, cos, sin, pi = math.ceil, math.cos, math.sin, math.pi
local tinsert, tconcat = table.insert, table.concat
local GetClientPlayer = GetClientPlayer
local TARGET = TARGET

local SHADOW              = JH.GetAddonInfo().szShadowIni
local CIRCLE_ALPHA_STEP   = 2.5
local CIRCLE_MAX_RADIUS   = 30   -- 最大的半径
local CIRCLE_LINE_ALPHA   = 45   -- 线和边框最大透明度
local CIRCLE_ALPHA        = 30   -- 圈圈透明度
local CIRCLE_MAX_CIRCLE   = 1
local CIRCLE_RESERT_DRAW  = false -- 全局重绘
local CIRCLE_DEFAULT_DATA = { bEnable = true, nAngle = 80, nRadius = 4, col = { 0, 255, 0 }, bBorder = true }
local CIRCLE_PANEL_ANCHOR = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
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

-- 获取数据路径
local function GetDataPath()
	if DBM.bCommon then
		return JH.GetAddonInfo().szDataPath .. "Circle/Common/Circle.jx3dat"
	else
		return JH.GetAddonInfo().szDataPath .. "Circle/" .. GetUserRoleName() .. "/Circle.jx3dat"
	end
end

Circle = {
	bEnable = true,
	bBorder = true, -- 全局的边框模式 边框会造成卡
}
JH.RegisterCustomData("Circle")

local Circle = Circle
local C = {
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
	FireUIEvent("CIRCLE_RELOAD")
end

function C.LoadCircleMergeData(tData, bPriority)
	local data = {}
	for k, v in pairs(tData.Circle or {}) do
		if JH.IsMapExist(k) then
			data[tonumber(k)] = v
		end
	end
	local fnMergeData = function(tab_data)
		for k, v in pairs(tab_data) do
			if C.tData[k] then
				if JH.IsMapExist(k) then
					for kk, vv in ipairs(v) do
						if not C.CheckSameData(k, vv.key, vv.dwType) then
							table.insert(C.tData[k], vv)
						end
					end
				end
			else
				C.tData[k] = v
			end
		end
	end
	if bPriority then
		local tab_data = clone(C.tData)
		C.tData = data
		fnMergeData(tab_data)
	else
		fnMergeData(data)
	end
	FireUIEvent("CIRCLE_RELOAD")
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
					if k ~= -9 then
						for kk, vv in ipairs(v) do
							tinsert(dat, vv)
						end
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
	local mapid = JH.GetMapID(true)
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

function C.AddData(dwMapID, data)
	C.tData[dwMapID] = C.tData[dwMapID] or {}
	tinsert(C.tData[dwMapID], data)
	FireUIEvent("CIRCLE_RELOAD", dwMapID)
	return C.tData[dwMapID][#C.tData[dwMapID]]
end

function C.Exchange(dwMapID, nIndex1, nIndex2)
	if nIndex1 == nIndex2 then
		return
	end
	if C.tData[dwMapID] then
		local data1 = C.tData[dwMapID][nIndex1]
		local data2 = C.tData[dwMapID][nIndex2]
		if data1 and data2 then
			C.tData[dwMapID][nIndex1] = data2
			C.tData[dwMapID][nIndex2] = data1
			FireUIEvent("CIRCLE_RELOAD")
		end
	end
end

function C.CheckSameData(dwMapID, key, dwType)
	if C.tData[dwMapID] then
		if dwMapID ~= -9 then
			for k, v in ipairs(C.tData[dwMapID]) do
				if key == v.key and dwType == v.dwType then
					return k, v
				end
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
		if C.CheckSameData(dwTargetMapID, data.key, data.dwType) then
			return JH.Alert(_L["same data Exist"])
		end
		C.tData[dwTargetMapID] = C.tData[dwTargetMapID] or {}
		tinsert(C.tData[dwTargetMapID], clone(C.tData[dwMapID][nIndex]))
		if not bCopy then
			table.remove(C.tData[dwMapID], nIndex)
			if #C.tData[dwMapID] == 0 then
				C.tData[dwMapID] = nil
			end
		end
		FireUIEvent("CIRCLE_RELOAD")
	end
end

function C.RemoveData(dwMapID, nIndex, bConfirm)
	local fnAction
	if nIndex then
		if C.tData[dwMapID] and C.tData[dwMapID][nIndex] then
			fnAction = function()
				if dwMapID == -9 then
					table.remove(C.tData[dwMapID], nIndex)
					if #C.tData[dwMapID] == 0 then
						C.tData[dwMapID] = nil
					end
					FireUIEvent("CIRCLE_RELOAD")
				else
					C.MoveData(dwMapID, nIndex, -9)
				end
			end
		end
	else
		if C.tData[dwMapID] then
			fnAction = function()
				C.tData[dwMapID] = nil
				FireUIEvent("CIRCLE_RELOAD")
			end
		end
	end
	if fnAction then
		if not nIndex then
			JH.Confirm(FormatString(g_tStrings.MSG_DELETE_NAME, JH.IsMapExist(dwMapID)), fnAction)
		else
			fnAction()
		end
	end
end

function C.OutputTip(data, rect)
	local xml = {}
	if tonumber(data.key) then
		if data.dwType == TARGET.NPC then
			tinsert(xml, GetFormatText(JH.GetTemplateName(data.key), 80, 255, 255, 0))
		else
			local szName = data.key
			local doodad = GetDoodadTemplate(data.key)
			if doodad then
				szName = doodad.szName
				if doodad.nKind == DOODAD_KIND.CORPSE then
					szName = szName .. g_tStrings.STR_DOODAD_CORPSE
				end
			end
			tinsert(xml, GetFormatText(szName, 80, 255, 255, 0))
		end
	else
		tinsert(xml, GetFormatText(data.key, 80, 255, 255, 0))
	end
	tinsert(xml, GetFormatText(" (" .. (data.dwType == TARGET.NPC and _L["NPC"] or _L["DOODAD"]) .. ")", 80, 255, 255, 0))
	tinsert(xml, GetFormatText("\t" .. (JH.IsMapExist(data.dwMapID) or data.dwMapID), 41, 255, 255, 255))
	if data.szNote then
		tinsert(xml, GetFormatText(data.szNote .. "\n", 41, 255, 255, 255))
	end
	if data.tCircles then
		for k, v in ipairs(data.tCircles) do
			local txt = _L("Circle %d", k)
			txt = txt .. g_tStrings.STR_COLON
			txt = txt .. v.nAngle .. _L[" degree"] .. "  "
			txt = txt .. v.nRadius .. _L[" feet"] .. "\n"
			local r, g, b = unpack(v.col)
			tinsert(xml, GetFormatText(txt, 41, r, g, b))
		end
	end
	OutputTip(tconcat(xml), 400, rect)
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
	local nAlpha = CIRCLE_ALPHA
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

function C.OnNpcEnter(szEvent)
	local npc = GetNpc(arg0)
	local t = C.tList[TARGET.NPC][npc.dwTemplateID] or C.tList[TARGET.NPC][JH.GetTemplateName(npc)]
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
		local KGNpc = GetNpc(k)
		if not data.bEmployer or data.bEmployer and KGNpc.dwEmployer == me.dwID then
			if not C.tCache[TARGET.NPC][k] then
				C.tCache[TARGET.NPC][k] = {
					Circle = {},
					Line = {},
				}
			end
			if data.tCircles then
				local n = 1
				for i = #data.tCircles, 1, -1 do
					if n > CIRCLE_MAX_CIRCLE then
						break
					end
					n = n + 1
					local kk, vv = i, data.tCircles[i]
					if vv.bEnable then
						local sha = C.tCache[TARGET.NPC][k].Circle
						if not sha[kk] then
							sha[kk] = C.shCircle:AppendItemFromIni(SHADOW, "shadow")
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
								sha[key] = C.shCircle:AppendItemFromIni(SHADOW, "shadow")
							end
							if sha[key].nFaceDirection ~= KGNpc.nFaceDirection or CIRCLE_RESERT_DRAW then -- 面向不对 重绘
								sha[key].nFaceDirection = KGNpc.nFaceDirection
								C.DrawBorder(KGNpc, sha[key], vv.nAngle, vv.nRadius, vv.col, data.dwType)
							end
						end
					end
				end
			end
			-- if data.bDrawName then
			-- 	local tSelectObject = Scene_SelectObject("nearest")
			-- 	if (KGNpc.CanSeeName() and tSelectObject[1]["ID"] == KGNpc.dwID) or not KGNpc.CanSeeName() then
			-- 		tinsert(C.tDrawText, { KGNpc.dwID, data.szNote or data.key, { 255, 255, 0 }, TARGET.NPC, true })
			-- 	end
			-- end
			if data.bTarget then
				local sha = C.tCache[TARGET.NPC][k].Line
				local dwType, dwID = KGNpc.GetTarget()
				local tar = JH.GetTarget(dwType, dwID)
				-- if data.bDrawLine and dwID ~= 0 and dwType == TARGET.PLAYER and (not sha.item or sha.item and sha.item.dwID ~= dwID) and tar then
				-- 	if not data.bDrawLineSelf or data.bDrawLineSelf and dwID == me.dwID then
				-- 		sha.item = sha.item or C.shLine:AppendItemFromIni(SHADOW, "shadow", k)
				-- 		sha.item.dwID = dwID
				-- 		local col = dwID == me.dwID and { 255, 0, 128 } or { 255, 255, 0 }
				-- 		C.DrawLine(KGNpc, tar, sha.item, col, data.dwType)
				-- 	elseif sha.item then
				-- 		C.shLine:RemoveItem(sha.item)
				-- 		C.tCache[TARGET.NPC][k].Line = {}
				-- 	end
				-- elseif (not data.bDrawLine or dwID == 0 or dwType ~= TARGET.PLAYER or not tar) and sha.item then
				-- 	C.shLine:RemoveItem(sha.item)
				-- 	C.tCache[TARGET.NPC][k].Line = {}
				-- end
				if dwID ~= 0 and dwType == TARGET.PLAYER then
					local col = dwID == me.dwID and { 255, 0, 128 } or { 255, 255, 0 }
					tinsert(C.tDrawText, { KGNpc.dwID, JH.GetTemplateName(tar), col })
				end
				if dwID ~= 0 and dwType == TARGET.PLAYER and tar and (not C.tTarget[KGNpc.dwID] or C.tTarget[KGNpc.dwID] and C.tTarget[KGNpc.dwID] ~= dwID) then
					local szName = JH.GetTemplateName(tar)
					C.tTarget[KGNpc.dwID] = dwID
					if data.bScreenHead then
						FireUIEvent("JH_SA_CREATE", "TIME", tar.dwID, { txt = _L("Staring %s", data.szNote or data.key)})
					end
					if me.IsInRaid() then
						if DBM.bPushWhisperChannel and data.bWhisperChat then
							JH.Talk(szName, _L("Warning: %s staring at %s", data.szNote or data.key, g_tStrings.STR_YOU))
						end
						if DBM.bPushTeamChannel and data.bTeamChat then
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
		local KGDoodad = GetDoodad(k)
		if not C.tCache[TARGET.DOODAD][k] then
			C.tCache[TARGET.DOODAD][k] = {
				Circle = {},
				Line = {},
			}
		end
		if data.tCircles then
			local n = 1
			for i = #data.tCircles, 1, -1 do
				if n > CIRCLE_MAX_CIRCLE then
					return
				end
				n = n + 1
				local kk, vv = i, data.tCircles[i]
				if vv.bEnable then
					local sha = C.tCache[TARGET.DOODAD][k].Circle
					if not sha[kk] then
						sha[kk] = C.shCircle:AppendItemFromIni(SHADOW, "shadow")
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
		-- if data.bDoodadLine and not sha.item then
		-- 	sha.item = sha.item or C.shLine:AppendItemFromIni(SHADOW, "shadow", k)
		-- 	C.DrawLine(KGDoodad, me, sha.item, { 255, 128, 0 }, data.dwType)
		-- elseif not data.bDoodadLine and sha.item then
		-- 	C.shLine:RemoveItem(sha.item)
		-- 	C.tCache[TARGET.DOODAD][k].Line = {}
		-- end
		-- if data.bDrawName then
		-- 	tinsert(C.tDrawText, { KGDoodad.dwID, data.szNote or data.key, { 255, 128, 0 }, TARGET.DOODAD })
		-- end
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

function C.OpenAddPanel(szName, dwType, szMap, dwSelMapID)
	dwType = dwType or TARGET.NPC
	local ui = GUI.CreateFrame("DBM_NewData", { w = 380, h = 250, title = _L["Add Face"], close = true, focus = true })
	ui:Append("Text", "Name", { txt = szName or _L["Please enter key"], font = 48, w = 380, h = 30, x = 0, y = 45, align = 1 })
	ui:Append("Text", { txt = _L["Key:"], font = 27, w = 105, h = 30, x = 0, y = 80, align = 2 })
	ui:Append("WndEdit", "Key", { txt = szName, x = 115, y = 83, enable = szName == nil })
	:Change(function(szText)
		ui:Fetch("Name"):Text(szText)
	end)
	ui:Append("Text", { txt = _L["Map:"], font = 27, w = 105, h = 30, x = 0, y = 110, align = 2 })
	if dwSelMapID then
		if dwSelMapID ~= _L["All Data"] then
			szMap = JH.IsMapExist(dwSelMapID)
		else
			szMap = JH.IsMapExist(JH.GetMapID(true))
		end
	end
	ui:Append("WndEdit", "Map", { txt = szMap, x = 115, y = 113 }):Autocomplete(JH.GetAllMap())
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
					tCircles = { clone(CIRCLE_DEFAULT_DATA) }
				}
				C.OpenDataPanel(C.AddData(map, data))
				ui:Remove()
			end
			if C.tData[map] then
				local tab = select(2, C.CheckSameData(map, key, dwType))
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
	local title = data.szNote and string.format("%s(%s)", data.key, data.szNote) or data.key
	local a = CIRCLE_PANEL_ANCHOR
	local ui = GUI.CreateFrame("DBM_SettingPanel", { w = 770, h = 390, title = title, close = true, focus = true }):Point(a.s, 0, 0, a.r, a.x, a.y)
	ui:Event("CIRCLE_RELOAD", "DBMUI_SWITCH_PAGE"):OnEvent(function(szEvent)
		ui:Remove()
	end)
	local frame = Station.Lookup("Normal/DBM_SettingPanel")
	frame.OnFrameDragEnd = function()
		CIRCLE_PANEL_ANCHOR = GetFrameAnchor(frame, "LEFTTOP")
	end
	local file = "ui/Image/UICommon/Feedanimials.uitex"
	--58
	local nX, nY = ui:Append("Box", { w = 48, h = 48, x = 361, y = 40, icon = 2673 }):Hover(function(bHover)
		this:SetObjectMouseOver(bHover)
		if bHover then
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			Circle.OutputTip(data, { x, y, w, h })
		else
			HideTip()
		end
	end):Pos_()

	nX = ui:Append("WndRadioBox", { x = 300, y = nY + 5, txt = _L["NPC"], group = "type", checked = data.dwType == TARGET.NPC }):Click(function()
		data.dwType = TARGET.NPC
		FireUIEvent("CIRCLE_RELOAD")
		C.OpenDataPanel(data)
	end):Pos_()
	nX, nY = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 5, txt = _L["DOODAD"], group = "type", checked = data.dwType == TARGET.DOODAD }):Click(function()
		data.dwType = TARGET.DOODAD
		FireUIEvent("CIRCLE_RELOAD")
		C.OpenDataPanel(data)
	end):Pos_()
	for k, v in ipairs(data.tCircles or {}) do
		nX = ui:Append("WndCheckBox", { x = 15, y = nY, txt = _L["Face Circle"], font = 27, checked = v.bEnable })
		:Click(function(bChecked)
			v.bEnable = bChecked
			FireUIEvent("CIRCLE_RELOAD")
			C.OpenDataPanel(data)
		end):Pos_()
		nX = ui:Append("WndEdit", { x = nX + 2, y = nY + 2, w = 35, h = 25, limit = 4 })
		:Enable(k ~= 2):Text(v.nAngle):Change(function(nVal)
			local n = tonumber(nVal) or 30
			if n < 1 or n > 360 then
				n = 30
				JH.Alert("Limit (1, 360)")
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
				JH.Alert("Limit (0.1, " .. CIRCLE_MAX_RADIUS ..")")
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
			FireUIEvent("CIRCLE_RELOAD")
			C.OpenDataPanel(data)
		end):Pos_()
		nX, nY = ui:Append("Image", { x = nX + 5, y = nY + 1, w = 26, h = 26 }):File(file, 86):Event(525311)
		:Hover(function() this:SetFrame(87) end, function() this:SetFrame(86) end):Click(function()
			if #data.tCircles == 1 then
				data.tCircles = nil
			else
				table.remove(data.tCircles, k)
			end
			FireUIEvent("CIRCLE_RELOAD")
			C.OpenDataPanel(data)
		end):Pos_()
	end
	nX, nY = ui:Append("WndCheckBox", { x = 15, y = nY, txt = _L["Mon Target"], font = 27, checked = data.bTarget })
	:Enable(data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bTarget = bChecked
		ui:Fetch("bTeamChat"):Enable(bChecked)
		ui:Fetch("bWhisperChat"):Enable(bChecked)
		ui:Fetch("bScreenHead"):Enable(bChecked)
		ui:Fetch("bFlash"):Enable(bChecked)
		-- ui:Fetch("bDrawLine"):Enable(bChecked)
		-- ui:Fetch("bDrawLineSelf"):Enable(bChecked and data.bDrawLine)
		FireUIEvent("CIRCLE_RELOAD")
		C.OpenDataPanel(data)
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bTeamChat", { x = 25, y = nY, checked = data.bTeamChat, txt = _L["Team Channel"], color = GetMsgFontColor("MSG_TEAM", true) })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bTeamChat = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bWhisperChat", { x = nX + 5, y = nY, checked = data.bWhisperChat, txt = _L["Whisper Channel"], color = GetMsgFontColor("MSG_WHISPER", true) })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bWhisperChat = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", "bScreenHead", { x = nX + 5, y = nY, checked = data.bScreenHead, txt = _L["Screen Head Alarm"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bScreenHead = bChecked
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bFlash", { x = nX + 5, y = nY, checked = data.bFlash, txt = _L["Center Alarm"] })
	:Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bFlash = bChecked
	end):Pos_()
	-- nX = ui:Append("WndCheckBox", "bDrawLine", { x = nX + 5, y = nY, checked = data.bDrawLine, txt = _L["Draw Line"] })
	-- :Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC):Click(function(bChecked)
	-- 	data.bDrawLine = bChecked
	-- 	ui:Fetch("bDrawLineSelf"):Enable(bChecked)
	-- 	FireUIEvent("CIRCLE_RELOAD")
	-- 	C.OpenDataPanel(data)
	-- end):Pos_()
	-- nX, nY = ui:Append("WndCheckBox", "bDrawLineSelf", { x = nX + 5, y = nY, checked = data.bDrawLineSelf, txt = _L["Draw Line Only Self"] })
	-- :Enable(type(data.bTarget) ~= "nil" and data.bTarget and data.dwType == TARGET.NPC and data.bDrawLine == true):Click(function(bChecked)
	-- 	data.bDrawLineSelf = bChecked
	-- 	FireUIEvent("CIRCLE_RELOAD")
	-- 	C.OpenDataPanel(data)
	-- end):Pos_()
	-- nX, nY = ui:Append("Text", { x = 15, y = nY, txt = _L["Other"], font = 27 }):Pos_()
	-- nX = ui:Append("WndCheckBox", { x = 25, y = nY + 10, checked = data.bDrawName, txt = _L["Draw Self Name"] })
	-- :Click(function(bChecked)
	-- 	data.bDrawName = bChecked
	-- end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 15 + 10, y = nY, checked = data.bEmployer, txt = _L["Check Employer"] })
	:Enable(data.dwType == TARGET.NPC):Click(function(bChecked)
		data.bEmployer = bChecked
		FireUIEvent("CIRCLE_RELOAD")
		C.OpenDataPanel(data)
	end):Pos_()
	-- nX, nY = ui:Append("WndCheckBox", { x = nX + 5, y = nY + 10, checked = data.bDoodadLine, txt = _L["Draw Doodad Line"] })
	-- :Enable(data.dwType == TARGET.DOODAD):Click(function(bChecked)
	-- 	data.bDoodadLine = bChecked
	-- end):Pos_()
	nX, nY = ui:Append("Text", { x = 15, y = nY, txt = g_tStrings.STR_GUILD_REMARK, font = 27 }):Pos_()
	ui:Append("WndEdit", { x = 25, y = nY + 10, w = 720, h = 24 ,txt = data.szNote or g_tStrings.STR_FRIEND_REMARK, limit = 30, })
	:Focus(function(bFocus)
		if bFocus then
			if this:GetText() == g_tStrings.STR_FRIEND_REMARK then
				this:SetText("")
			end
		end
	end):Change(function(szText)
		if JH.Trim(szText) ~= "" then
			data.szNote = szText
			ui:Title(string.format("%s(%s)", data.key, data.szNote))
		else
			ui:Title(data.key)
			data.szNote = nil
		end
	end)
	local nCount = data.tCircles and #data.tCircles or 0
	ui:Append("WndButton2", { x = 20, y = 340, txt = _L["Add Circle"] }):Enable(nCount < CIRCLE_MAX_CIRCLE):Click(function()
		data.tCircles = data.tCircles or {}
		tinsert(data.tCircles, clone(CIRCLE_DEFAULT_DATA) )
		if #data.tCircles == 2 then	data.tCircles[2].nAngle = 360 end
		FireUIEvent("CIRCLE_RELOAD")
		C.OpenDataPanel(data)
	end)
	ui:Append("WndButton2", { x = 335, y = 340, txt = g_tStrings.STR_FRIEND_DEL, color = { 255, 0, 0 } }):Click(function()
		C.RemoveData(data.dwMapID, data.nIndex, not IsAltKeyDown())
	end)
	ui:Append("WndButton2", { x = 640, y = 340, txt = g_tStrings.HELP_PANEL }):Click(function()
		OpenInternetExplorer("https://github.com/luckyyyyy/JH/blob/dev/JH_DBM/README.md")
	end)
end

function C.Init()
	JH.RegisterInit("Circle",
		{ "Breathe", C.OnBreathe },
		{ "NPC_ENTER_SCENE", C.OnNpcEnter },
		{ "NPC_LEAVE_SCENE", C.OnNpcLeave },
		{ "DOODAD_ENTER_SCENE", C.OnDoodadEnter },
		{ "DOODAD_LEAVE_SCENE", C.OnDoodadLeave },
		{ "LOADING_END", C.CreateData },
		{ "CIRCLE_RESERT_DRAW", function()
			CIRCLE_RESERT_DRAW = true
		end }
	)
end

function C.UnInit()
	JH.UnRegisterInit("Circle")
	C.Release()
end

function C.Enable(bEnable)
	if type(bEnable) == "boolean" then
		Circle.bEnable = bEnable
	else
		bEnable = Circle.bEnable
	end
	if bEnable then
		C.Init()
	else
		C.UnInit()
	end
end

JH.RegisterExit(C.SaveFile)

JH.RegisterEvent("CIRCLE_DEBUG", function()
	if JH.bDebugClient then
		Circle.nMaxAlpha, CIRCLE_ALPHA_STEP = arg0, arg1
		FireUIEvent("CIRCLE_RELOAD")
	end
end)

JH.RegisterEvent("LOGIN_GAME", function()
	C.LoadFile()
	C.Enable()
	JH.RegisterEvent("CIRCLE_RELOAD", C.CreateData)
end)

-- 注册头像右键菜单
Target_AppendAddonMenu({ function(dwID, dwType)
	if dwType == TARGET.NPC then
		local p = GetNpc(dwID)
		local data = C.tList[TARGET.NPC][p.dwTemplateID] or C.tList[TARGET.NPC][JH.GetTemplateName(p)]
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
					GetPopupMenu():Hide()
				end,
				fnAction = function()
					C.OpenDataPanel(data)
				end
			}}
		else
			return {{ szOption = _L["Add Face"], rgb = { 255, 255, 0 }, fnAction = function()
				C.OpenAddPanel(not IsCtrlKeyDown() and JH.GetTemplateName(p) or p.dwTemplateID, dwType, JH.IsMapExist(JH.GetMapID(true)))
			end }}
		end
	else
		return {}
	end
end })
-- public
local ui = {
	OpenAddPanel        = C.OpenAddPanel,
	LoadCircleData      = C.LoadCircleData,
	LoadCircleMergeData = C.LoadCircleMergeData,
	GetData             = C.GetData,
	OpenDataPanel       = C.OpenDataPanel,
	Exchange            = C.Exchange,
	RemoveData          = C.RemoveData,
	MoveData            = C.MoveData,
	CheckSameData       = C.CheckSameData,
	AddData             = C.AddData,
	OutputTip           = C.OutputTip,
	Enable              = C.Enable
}
setmetatable(Circle, { __index = ui, __metatable = true, __newindex = function() end } )
