-- @Author: Webster
-- @Date:   2016-01-04 14:09:04
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-01-04 14:17:36

local WM = {}
local WM_LIST = {
	[20107] = { id = 1,  col = { 255, 255, 255 } },
	[20108] = { id = 2,  col = { 255, 128, 0   } },
	[20109] = { id = 3,  col = { 0  , 0  , 255 } },
	[20110] = { id = 4,  col = { 0  , 255, 0   } },
	[20111] = { id = 5,  col = { 255, 0  , 0   } },
	[36781] = { id = 6,  col = { 50 , 220, 255 } },
	[36782] = { id = 7,  col = { 255, 100, 220 } },
	[36783] = { id = 8,  col = { 255, 255, 0   } },
	[36784] = { id = 9,  col = { 200, 40,  255 } },
	[36785] = { id = 10, col = { 30,  255, 180 } },
}
local WM_POINT  = {}
local WM_SHADOW = JH.GetAddonInfo().szShadowIni

JH_WorldMark = {
	bEnable = true
}
JH.RegisterCustomData("JH_WorldMark")

function WM.OnNpcEvent()
	local npc = GetNpc(arg0)
	if npc then
		local mark = WM_LIST[npc.dwTemplateID]
		if mark then
			local tPoint = { npc.nX, npc.nY, npc.nZ }
			local handle = JH.GetShadowHandle("Handle_World_Mark")
			local szName = "w_" .. mark.id
			if handle:Lookup(szName) then
				handle:RemoveItem(szName)
			end
			WM_POINT[mark.id] = tPoint
		end
	end
end

function WM.OnNpcLeave()
	local npc = GetNpc(arg0)
	if npc then
		local mark = WM_LIST[npc.dwTemplateID]
		if mark then
			local tPoint = WM_POINT[mark.id]
			if tPoint then
				local handle = JH.GetShadowHandle("Handle_World_Mark")
				local szName = "w_" .. mark.id
				local sha = handle:Lookup(szName) or handle:AppendItemFromIni(WM_SHADOW, "shadow", szName)
				WM.Draw(tPoint, sha, mark.col)
			end
		end
	end
end

function WM.OnCast(dwSkillID)
	if dwSkillID == 4906 then
		WM_POINT = {}
		JH.GetShadowHandle("Handle_World_Mark"):Clear()
	end
end

function WM.Draw(Point, sha, col)
	local nRadius    = 64
	local nFace      = 128
	local dwRad1     = math.pi
	local dwRad2     = 3 * math.pi + math.pi / 20
	local r, g, b    = unpack(col)
	local nX, nY, nZ = unpack(Point)
	sha:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	sha:SetD3DPT(D3DPT.TRIANGLEFAN)
	sha:ClearTriangleFanPoint()
	sha:AppendTriangleFan3DPoint(nX ,nY, nZ, r, g, b, 80)
	sha:Show()
	local sX, sZ = Scene_PlaneGameWorldPosToScene(nX, nY)
	repeat
		local sX_, sZ_ = Scene_PlaneGameWorldPosToScene(nX + math.cos(dwRad1) * nRadius, nY + math.sin(dwRad1) * nRadius)
		sha:AppendTriangleFan3DPoint(nX ,nY, nZ, r, g, b, 80, { sX_ - sX, 0, sZ_ - sZ })
		dwRad1 = dwRad1 + math.pi / 16
	until dwRad1 > dwRad2
end

function JH_WorldMark.GetEvent()
	if JH_WorldMark.bEnable then
		return
			{ "DO_SKILL_CAST", function()
				WM.OnCast(arg1)
			end },
			{ "NPC_LEAVE_SCENE", WM.OnNpcLeave },
			{ "NPC_ENTER_SCENE", WM.OnNpcEvent },
			{ "LOADING_END", function()
				WM_POINT = {}
				JH.GetShadowHandle("Handle_World_Mark"):Clear()
			end }
	else
		WM.OnCast(4906)
	end
end
