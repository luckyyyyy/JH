-------------------------------------------------------------------------------------------
-- 下面是追加的自定义显示规则模块，一些以前的辅助。
-----------------------------------------------------------------------------------------
local tMapList = {
	[60] = "70CG",
	[65] = "70CG",
	[66] = "70CG",
	-- [108] = "HG",
	[148] = "80CG",
	[131] = "80CG",
	[140] = "HG",
	[155] = "HG",
}
local FunctionModule = false

local tDebuffInfoList = {
	["70CG"] = {
		["天绝华散曲·白露"] = {8417, 30336, 1342400},
		["天绝华散曲·碧海"] = {8425, 22376, 1342400},
		["天绝华散曲·朱云"] = {4335, 22372, 1342400},
		["天绝华散曲·黑洞"] = {4315, 30323, 1342400},
		-- ["调息"] = {4315, 30323, 1342400},
		["天国镇魂曲·破静天门"] = {3044, 26448, 1354176},--szRunTargetName = "鼓"},
		["天国镇魂曲·普渡八音"] = {6375, 22407, 1354176},--szRunTargetName = "古琴"},
		["天国镇魂曲·欲吐地葬"] = {6359, 30312, 1354176},--szRunTargetName = "大钟"},
		["天国镇魂曲·镇魂长曲"] = {9734, 26469, 1354176},--szRunTargetName = "铜铃"},
	},
	["80CG"] = {
		["天绝华散曲·白露"] = {8417,30336,1342400,},
		["天绝华散曲·碧海"] = {8425,22376,1342400,},
		["天绝华散曲·朱云"] = {4335,22372,1342400,},
		["天绝华散曲·黑洞"] = {4315,30323,1342400,},
		["天国镇魂曲·破静天门"] = {3044,26448,1354176},-- szRunTargetName = "雷音天鼓"},
		["天国镇魂曲·普渡八音"] = {9734,26469,1354176},-- szRunTargetName = "枯木禅琴"},
		["天国镇魂曲·欲吐地葬"] = {6375,22407,1354176},-- szRunTargetName = "菩提梵钟"},
		["天国镇魂曲·镇魂长曲"] = {6359,30312,1354176},-- szRunTargetName = "金刚佛铃"},
	},
	["HG"] = {
		[1] = {37949,38359,1118016},--钟1坐标
		[2] = {35356,38362,1118016},--钟2坐标
		[3] = {35375,35805,1118016},--钟3坐标
		[4] = {37923,35742,1118016},--钟4坐标
	}
}
local GetTwoTargetDistance = function(player, tPosition)
	local nX,nY,nZ = unpack(tPosition)
	local nDistX = nX - player.nX
	local nDistY = nY - player.nY
	local nDistZ = nZ - player.nZ
	local nDistance = math.sqrt(nDistX^2 + nDistY^2 + nDistZ^2/64)
	return nDistance
	
end
local tFanYinPlayerList = {}
local tFanYinResult = {}

local CheckBuff = function()
	if FunctionModule then
		local me = GetClientPlayer()
		if FunctionModule == "70CG" or FunctionModule == "80CG" then
			if me.dwID == arg0 then
				local szIndex = FunctionModule
				local szBuffName = Table_GetBuffName(arg4,arg8)
				if tDebuffInfoList[szIndex][szBuffName] then					
					if not arg1 then
						BossFaceAlert.UpdateAlertLine(me.dwID,szIndex,tDebuffInfoList[szIndex][szBuffName],me,{255,255,255})
					else
						BossFaceAlert.RemoveAllItem(me.dwID,szIndex)
					end
				end
			end
		elseif FunctionModule == "HG" then
			if arg4 == 4387 then
				local szIndex = FunctionModule
				if not arg1 then -- 获得4387
					table.insert(tFanYinPlayerList, arg0)
					if #tFanYinPlayerList < 4 then
						return
					end
					local tFanYinResultTemp = {
						[1] = {},
						[2] = {},
						[3] = {},
						[4] = {},
					}
					for i = 1,4 do
						tFanYinResultTemp[i].KGobj = GetPlayer(tFanYinPlayerList[i])
						if not tFanYinResultTemp[i].KGobj then
						
							return
						end
					end
					local nFanYinResultDistance = 9999999
					local nCurrentTotalDistance = 9999999
					for i = 1,4 do
						for j = 1,4 do
							for k = 1,4 do
								for l = 1,4 do
									if (i ~= j) and  (i ~= k) and  (i ~= l) and  (j ~= k) and  (j ~= l) and  (k ~= l) then
										tFanYinResultTemp[1].TargetNumber = i
										tFanYinResultTemp[2].TargetNumber = j
										tFanYinResultTemp[3].TargetNumber = k
										tFanYinResultTemp[4].TargetNumber = l
										local nMaxDistance = 0
										local nTotalDistance = 0
										for ijkl = 1,4 do
											tFanYinResultTemp[ijkl].nDistance = GetTwoTargetDistance(tFanYinResultTemp[ijkl].KGobj, tDebuffInfoList[szIndex][tFanYinResultTemp[ijkl].TargetNumber])
											if tFanYinResultTemp[ijkl].nDistance > nMaxDistance then
												nMaxDistance = tFanYinResultTemp[ijkl].nDistance
											end
											nTotalDistance = nTotalDistance + tFanYinResultTemp[ijkl].nDistance
										end
										if nMaxDistance < nFanYinResultDistance then
											nFanYinResultDistance = nMaxDistance
											nCurrentTotalDistance = nTotalDistance
											tFanYinResult = clone(tFanYinResultTemp)
										elseif nMaxDistance == nFanYinResultDistance then
											if nCurrentTotalDistance > nTotalDistance then
												nFanYinResultDistance = nMaxDistance
												nCurrentTotalDistance = nTotalDistance
												tFanYinResult = clone(tFanYinResultTemp)
											end
										end
									end
								end
							end
						end
					end
					if	#tFanYinResult > 3 then
						for i = 1,4 do
							local character = GetPlayer(tFanYinPlayerList[i])
							if character then
								local tEndPos = tDebuffInfoList[szIndex][tFanYinResult[i].TargetNumber]
								if character.dwID == me.dwID then
									BossFaceAlert.UpdateAlertLine(szIndex,me.dwID,tEndPos,me,{255,255,255})
								else
									BossFaceAlert.UpdateAlertLine(szIndex,character.dwID,tEndPos,character,{0,255,0})
								end
							end
						end
					end
				else
					tFanYinPlayerList = {}
					tFanYinResult = {}
					nFanYinResultDistance = 9999999
					BossFaceAlert.RemoveAllItem(szIndex)
				end
			end
		end
	end
end

JH.RegisterEvent("LOADING_END", function()
	local me = GetClientPlayer()
	local scene = me.GetScene()
	if tMapList[scene.dwMapID] then
		FunctionModule = tMapList[scene.dwMapID]
		JH.RegisterEvent("BUFF_UPDATE.BossfaceAlertEx", CheckBuff)
	else
		FunctionModule = false
		JH.UnRegisterEvent("BUFF_UPDATE.BossfaceAlertEx")
	end
end)
