RaidGrid_Party = {}
RaidGrid_Party.bDrag = false
RaidGrid_Party.tHPBarColor = {0, 200, 72}; 					RegisterCustomData("RaidGrid_Party.tHPBarColor")
RaidGrid_Party.tDistanceLevel = {8, 20, 24, 28, 999};		RegisterCustomData("RaidGrid_Party.tDistanceLevel")
RaidGrid_Party.tDistanceColorLevel = {1, 2, 3, 4, 5};		RegisterCustomData("RaidGrid_Party.tDistanceColorLevel")
RaidGrid_Party.tDistanceColor = {
 	{0, 170, 140},
 	{0, 180, 52},
 	{230, 170, 40},
 	{230, 110, 230},
 	{230, 80, 80},
 	{128, 128, 128},
 	{192, 192, 192},
 	{255, 255, 255},
};
RaidGrid_Party.tLifeColor = {}
RaidGrid_Party.tOrgW = {}
RaidGrid_Party.fScaleX = 1;									RegisterCustomData("RaidGrid_Party.fScaleX")
RaidGrid_Party.fScaleY = 1;									RegisterCustomData("RaidGrid_Party.fScaleY")
RaidGrid_Party.fScaleFont = 1;								RegisterCustomData("RaidGrid_Party.fScaleFont")
RaidGrid_Party.fScaleIcon = 1;								RegisterCustomData("RaidGrid_Party.fScaleIcon")
RaidGrid_Party.fScaleShadowX = 1;							RegisterCustomData("RaidGrid_Party.fScaleShadowX")
RaidGrid_Party.fScaleShadowY = 1;							RegisterCustomData("RaidGrid_Party.fScaleShadowY")
 
RaidGrid_Party.dwLastTempTargetId = 0
RaidGrid_Party.bTempTargetEnable = true;					RegisterCustomData("RaidGrid_Party.bTempTargetEnable")
RaidGrid_Party.bTempTargetFightTip = true;					RegisterCustomData("RaidGrid_Party.bTempTargetFightTip")

RaidGrid_Party.Shadow = {
 	bLife = false,
 	bMana = false,
 	a = 240,
 	d = 1,
 }
RegisterCustomData("RaidGrid_Party.Shadow")

local szIniFile = JH.GetAddonInfo().szRootPath .. "RaidGrid_CTM_Edition/RaidGrid_Party.ini"

function RaidGrid_Party.IsInRaid() --检查是否在队伍中
	local me = GetClientPlayer()
	if me then
		return me.IsInRaid()
	end
end

function RaidGrid_Party.OnAddOrDeleteMember(dwMemberID, nGroupIndex) --添加或删除团员
	local tMemberInfo, team = RaidGrid_Party.GetTeamMemberInfo(dwMemberID)
	if not tMemberInfo then
		return
	end

	if nGroupIndex > 0 and not RaidGrid_Party.IsInRaid() then
		return
	end

	local frame = RaidGrid_Party.GetPartyPanel(nGroupIndex)
	if not frame then
		frame = RaidGrid_Party.CreateNewPartyPanel(nGroupIndex)
	end
	if RaidGrid_CTM_Edition.bShowRaid then
		frame:Show()
	else
		frame:Hide()
	end

	local tGroupInfo = team.GetGroupInfo(nGroupIndex)
	local nMemberCount = 0
	for i = 0, 4 do
		if tGroupInfo.MemberList[i + 1] then
			local dwMemberID = tGroupInfo.MemberList[i + 1]
			RaidGrid_Party.ShowHandleRoleInGroup(i, nGroupIndex, dwMemberID)
			nMemberCount = nMemberCount + 1
		else
			RaidGrid_Party.ClearHandleRoleInGroup(i, nGroupIndex)
		end
	end

	if RaidGrid_CTM_Edition.bShowAllMemberGrid then
		frame:SetSize(128 * RaidGrid_Party.fScaleX, 235 * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Shadow_BG"):SetSize(120 * RaidGrid_Party.fScaleX, 228 * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Image_BG_L"):SetSize(15 * RaidGrid_Party.fScaleX, 205 * RaidGrid_Party.fScaleY)	
		frame:Lookup("", "Handle_BG/Image_BG_R"):SetSize(15 * RaidGrid_Party.fScaleX, 205 * RaidGrid_Party.fScaleY)	
		frame:Lookup("", "Handle_BG/Image_BG_BL"):SetRelPos(0, 220 * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Image_BG_B"):SetRelPos(15 * RaidGrid_Party.fScaleX, 220 * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Image_BG_BR"):SetRelPos(113 * RaidGrid_Party.fScaleX, 220 * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Text_GroupIndex"):SetRelPos(0, 216 * RaidGrid_Party.fScaleY)	
	else
		frame:SetSize(128 * RaidGrid_Party.fScaleX, (235 - (5 - nMemberCount) * 42) * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Shadow_BG"):SetSize(120 * RaidGrid_Party.fScaleX, (228 - (5 - nMemberCount) * 42) * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Image_BG_L"):SetSize(15 * RaidGrid_Party.fScaleX, (205 - (5 - nMemberCount) * 42) * RaidGrid_Party.fScaleY)	
		frame:Lookup("", "Handle_BG/Image_BG_R"):SetSize(15 * RaidGrid_Party.fScaleX, (205 - (5 - nMemberCount) * 42) * RaidGrid_Party.fScaleY)	
		frame:Lookup("", "Handle_BG/Image_BG_BL"):SetRelPos(0, (220 - (5 - nMemberCount) * 42) * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Image_BG_B"):SetRelPos(15 * RaidGrid_Party.fScaleX, (220 - (5 - nMemberCount) * 42) * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Image_BG_BR"):SetRelPos(113 * RaidGrid_Party.fScaleX, (220 - (5 - nMemberCount) * 42) * RaidGrid_Party.fScaleY)
		frame:Lookup("", "Handle_BG/Text_GroupIndex"):SetRelPos(0, (216 - (5 - nMemberCount) * 42) * RaidGrid_Party.fScaleY)	
	end
	frame:Lookup("", "Handle_BG"):FormatAllItemPos()
end

------------------------------------------------------------------------------------------------------------
--成员血量距离
------------------------------------------------------------------------------------------------------------
function RaidGrid_Party.UpdateMemberDistance() --团员距离更新
	local player = GetClientPlayer()
	
	for i = 0, 4 do
		for nMemberIndex = 0, 4 do
			local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, i)
			if handleRole and handleRole.dwMemberID then
				local textDistance = handleRole:Lookup("Handle_Common/Text_Distance")
				local playerMember = GetPlayer(handleRole.dwMemberID)
				
				if not playerMember then
					if RaidGrid_CTM_Edition.bShowDistance then
						textDistance:SetText("∞")
						textDistance:SetFontColor(128, 128, 128)
					else
						textDistance:SetText("")
					end
					if RaidGrid_CTM_Edition.bColorHPBarWithDistance then
						local tMemberInfo, team = RaidGrid_Party.GetTeamMemberInfo(handleRole.dwMemberID)
						if tMemberInfo and tMemberInfo.bIsOnLine then
							RaidGrid_Party.tLifeColor[handleRole.dwMemberID] = {192, 192, 192}
						else
							RaidGrid_Party.tLifeColor[handleRole.dwMemberID] = {128, 128, 128}
						end
						RaidGrid_Party.RedrawHandleRoleHPnMP(handleRole.dwMemberID)
					end
				elseif player.dwID == handleRole.dwMemberID then
					if RaidGrid_CTM_Edition.bColorHPBarWithDistance then
						RaidGrid_Party.tLifeColor[handleRole.dwMemberID] = {RaidGrid_Party.tHPBarColor[1], RaidGrid_Party.tHPBarColor[2], RaidGrid_Party.tHPBarColor[3]}
						RaidGrid_Party.RedrawHandleRoleHPnMP(handleRole.dwMemberID)
					end
					textDistance:SetText("")
				else
					local tArrowDelay = {2, 3, 5, 8, 12}
					local nArrowDelay = tArrowDelay[3]
					if RaidGrid_CTM_Edition.bShowDistance or RaidGrid_CTM_Edition.bColorHPBarWithDistance then
						local nDist2d = math.floor(((playerMember.nX - player.nX) ^ 2 + (playerMember.nY - player.nY) ^ 2) ^ 0.5) / 64
						for nDistLevel = 1, 5 do
							if nDist2d <= RaidGrid_Party.tDistanceLevel[nDistLevel] then
								nArrowDelay = tArrowDelay[nDistLevel]
								if RaidGrid_CTM_Edition.bShowDistance then
									if RaidGrid_CTM_Edition.bFloatNumber then
										textDistance:SetText(string.format("%.1f", nDist2d))
									else
										textDistance:SetText(math.floor(nDist2d))
									end
									textDistance:SetFontColor(255, 210, 255)
								else
									textDistance:SetText("")
								end
								if RaidGrid_CTM_Edition.bColorHPBarWithDistance then
									RaidGrid_Party.tLifeColor[handleRole.dwMemberID] = {
									RaidGrid_Party.tDistanceColor[RaidGrid_Party.tDistanceColorLevel[nDistLevel]][1],
									RaidGrid_Party.tDistanceColor[RaidGrid_Party.tDistanceColorLevel[nDistLevel]][2],
									RaidGrid_Party.tDistanceColor[RaidGrid_Party.tDistanceColorLevel[nDistLevel]][3]}
									RaidGrid_Party.RedrawHandleRoleHPnMP(handleRole.dwMemberID)
								end
								break
							end
						end
					end					
				end
			end
		end
	end
end

function RaidGrid_Party.UpdateMarkImage() --标记图像更新
	local team = GetClientTeam()
	local tPartyMark = team.GetTeamMark()
	if not tPartyMark then
		return
	end
	
	for i = 0, 4 do
		for nMemberIndex = 0, 4 do
			local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, i)
			if handleRole then
				local nMarkImageIndex = nil
				if handleRole.dwMemberID then
					nMarkImageIndex = tPartyMark[handleRole.dwMemberID]
				end
				if nMarkImageIndex and PARTY_MARK_ICON_FRAME_LIST[nMarkImageIndex] and RaidGrid_CTM_Edition.bShowMark then
					local imageMark = handleRole:Lookup("Handle_Icons/Image_MarkImage")
					imageMark:SetFrame(PARTY_MARK_ICON_FRAME_LIST[nMarkImageIndex])
					imageMark:Show()
					imageMark:SetAlpha(250)
					imageMark.nFlashDegSpeed = -1
				else
					local imageMark = handleRole:Lookup("Handle_Icons/Image_MarkImage")
					imageMark:Hide()
				end
			end
		end
	end
end

function RaidGrid_Party.RedrawTargetSelectImage(bForceHide)  --重绘目标选择图像
	if not RaidGrid_CTM_Edition.bShowSelectImage and not RaidGrid_CTM_Edition.bShowTargetTargetAni and not bForceHide then
		return
	end
	local player = GetClientPlayer()
	if not player then
		return
	end
	local _, dwTargetID = player.GetTarget()
	local target = GetNpc(dwTargetID)
	if IsPlayer(dwTargetID) then
		target = GetPlayer(dwTargetID)
	end

	local targetTarget = nil
	if target then
		local _, dwTargetTargetID = target.GetTarget()
		targetTarget = GetNpc(dwTargetTargetID)
		if IsPlayer(dwTargetTargetID) then
			targetTarget = GetPlayer(dwTargetTargetID)
		end
	end

	for nGroupIndex = 0, 4 do
		for nMemberIndex = 0, 4 do
			local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, nGroupIndex)
			if handleRole and handleRole.dwMemberID then
				local imageSelected = handleRole:Lookup("Image_Selected")
				if not bForceHide and RaidGrid_CTM_Edition.bShowSelectImage and target and target.dwID == handleRole.dwMemberID then
					imageSelected:Show()
				else
					imageSelected:Hide()
				end
				
				local aniTargetTarget = handleRole:Lookup("Animate_TargetTarget")
				if not bForceHide and RaidGrid_CTM_Edition.bShowTargetTargetAni and target and targetTarget and targetTarget.dwID == handleRole.dwMemberID then
					aniTargetTarget:Show()
				else
					aniTargetTarget:Hide()
				end				
			end
		end
	end
end

function RaidGrid_Party.RedrawHandleRoleInfoEx(dwMemberID)  --重绘处理角色信息EX
	local nMemberIndex, nGroupIndex = RaidGrid_Party.GetMemberIndexInGroup(dwMemberID)
	if not nMemberIndex then
		return
	end
	
	local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, nGroupIndex)
	if not handleRole then
		return
	end
	
	local tMemberInfo, team = RaidGrid_Party.GetTeamMemberInfo(dwMemberID)
	if not tMemberInfo then
		return
	end

	local textLife = handleRole:Lookup("Handle_Common/Text_Life")	
	local nRed, nGreen, nBlue, dwForceID = RaidGrid_Party.GetCharacterColor(dwMemberID, tMemberInfo.dwForceID)
	if not tMemberInfo.bIsOnLine then
		RaidGrid_Party.tLifeColor[dwMemberID] = {128, 128, 128}
		textLife:SetFontColor(128, 128, 128)
		textLife:SetText(g_tStrings.STR_FRIEND_NOT_ON_LINE)
	elseif tMemberInfo.bDeathFlag then
		RaidGrid_Party.tLifeColor[dwMemberID] = {255, 0, 0}
		textLife:SetFontColor(255, 0, 0)
		textLife:SetText(g_tStrings.FIGHT_DEATH)
	else
		local nRedOnline, nGreenOnline, nBlueOnline = RaidGrid_Party.tHPBarColor[1], RaidGrid_Party.tHPBarColor[2], RaidGrid_Party.tHPBarColor[3]
		if not RaidGrid_CTM_Edition.bColorHPBarWithDistance then
			RaidGrid_Party.tLifeColor[dwMemberID] = {nRedOnline, nGreenOnline, nBlueOnline}
		end
		textLife:SetFontColor(255, 255, 255)
	end

	local textName = handleRole:Lookup("Text_Name_2")
	textName:SetText(tMemberInfo.szName)
	if RaidGrid_CTM_Edition.bColoredName then
		textName:SetFontColor(nRed, nGreen, nBlue)
	else
		textName:SetFontColor(255, 255, 255)
	end
	
	RaidGrid_Party.RedrawMemberCampImage(handleRole, tMemberInfo.nCamp)
end

function RaidGrid_Party.RedrawHandleRoleInfo(dwMemberID)  --重绘处理角色信息
	local nMemberIndex, nGroupIndex = RaidGrid_Party.GetMemberIndexInGroup(dwMemberID)
	if not nMemberIndex then
		return
	end
	
	local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, nGroupIndex)
	if not handleRole then
		return
	end
	
	local tMemberInfo, team = RaidGrid_Party.GetTeamMemberInfo(dwMemberID)
	if not tMemberInfo then
		return
	end
	
	local imageLeader = handleRole:Lookup("Handle_Icons/Image_Leader")
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) == dwMemberID then
		imageLeader:Show()
	else
		imageLeader:Hide()
	end
	
	local imageLooter = handleRole:Lookup("Handle_Icons/Image_Looter")
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) == dwMemberID then
		imageLooter:Show()
	else
		imageLooter:Hide()
	end
	
	local imageMarker = handleRole:Lookup("Handle_Icons/Image_Marker")
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK) == dwMemberID then
		imageMarker:Show()
	else
		imageMarker:Hide()
	end
	
	local imageMatrixcore = handleRole:Lookup("Handle_Icons/Image_Matrix")
	imageMatrixcore:Hide()
	for i = 0, math.min(4, team.nGroupNum - 1) do
		local tGroupInfo = team.GetGroupInfo(i)
		if tGroupInfo and tGroupInfo.MemberList and #tGroupInfo.MemberList > 0 and tGroupInfo.dwFormationLeader == dwMemberID then
			imageMatrixcore:Show()
			break;
		end
	end
	
	RaidGrid_Party.RedrawMemberCampImage(handleRole, tMemberInfo.nCamp)
	
	local imageForce = handleRole:Lookup("Handle_Icons/Image_Force")
	local imageKungfu = handleRole:Lookup("Handle_Icons/Image_Kungfu")
	local dwMountKungfuID = tMemberInfo.dwMountKungfuID
	local dwForceID = tMemberInfo.dwForceID
	if dwMountKungfuID then
		RaidGrid_CTM_Edition.bIsSynKungfu = true
	end
	if RaidGrid_CTM_Edition.bShowForceIcon or RaidGrid_CTM_Edition.bShowKungfuIcon then
		if dwMountKungfuID and RaidGrid_CTM_Edition.bShowKungfuIcon then
			local nIconID = Table_GetSkillIconID(dwMountKungfuID, 0)
			if nIconID then
				imageKungfu:FromIconID(nIconID)
				if RaidGrid_Party.fScaleX ~= RaidGrid_Party.fScaleY then
					local szImageSize = 28
					if RaidGrid_Party.fScaleX > RaidGrid_Party.fScaleY then
						szImageSize = szImageSize * RaidGrid_Party.fScaleY
						imageKungfu:SetSize(szImageSize, szImageSize)
					else
						szImageSize = szImageSize * RaidGrid_Party.fScaleX
						imageKungfu:SetSize(szImageSize, szImageSize)
					end
				end
				imageKungfu:Show()
			else
				imageKungfu:Hide()
			end
			imageForce:Hide()
		else
			local tForceID2Frame = {
				[0] = 64,
				[1] = 59,
				[2] = 63,
				[3] = 62,
				[4] = 49,
				[5] = 56,
				[6] = 107,
				[7] = 108,
				[8] = 88,
				[9] = 110,
				[10] = 109,
				[21] = 0,
			}
			if tForceID2Frame[dwForceID] then
				imageForce:SetFrame(tForceID2Frame[dwForceID])				
				if RaidGrid_Party.fScaleX ~= RaidGrid_Party.fScaleY then
					local szImageSize = 28
					if RaidGrid_Party.fScaleX > RaidGrid_Party.fScaleY then
						szImageSize = szImageSize * RaidGrid_Party.fScaleY
						imageForce:SetSize(szImageSize, szImageSize)
					else
						szImageSize = szImageSize * RaidGrid_Party.fScaleX
						imageForce:SetSize(szImageSize, szImageSize)
					end
				end
				imageForce:Show()
			else
				imageForce:Hide()
			end
			imageKungfu:Hide()
		end
	else
		imageForce:Hide()
		imageKungfu:Hide()
	end
	
	for i = 0, 8 do
		local imageForceBG = handleRole:Lookup("Handle_Common/Image_BG_Force" .. i)
		local dwForceID_Clone = dwForceID
		if not RaidGrid_CTM_Edition.bColoredGrid then
			dwForceID_Clone = -1
		end
		if imageForceBG then
			if i == dwForceID_Clone then
				imageForceBG:Show()
			else
				imageForceBG:Hide()
			end
		end
		imageForceBG = handleRole:Lookup("Handle_Common/Image_BG_Force")
		if dwForceID_Clone == -1 then
			imageForceBG:Show()
		end
	end
end

function RaidGrid_Party.RedrawMemberCampImage(handleRole, nCamp)  --重绘成员阵营图标
	if not handleRole then
		return
	end
	local tcamp = {
		["ALL"] = -1;
		["NEUTRAL"] = 0;
		["GOOD"] = 1;--CAMP.GOOD
		["EVIL"] = 2;
	}
	local imageCamp = handleRole:Lookup("Handle_Icons/Image_Camp")
	local nFrame = 7
	if not nCamp or not RaidGrid_CTM_Edition.bShowCampIcon then
		imageCamp:Hide()
		imageCamp.nFrame = -1
	elseif nCamp == tcamp.GOOD then
		imageCamp:Show()
		if nFrame ~= (imageCamp.nFrame or -1) then
			imageCamp.nFrame = 7
			imageCamp:SetFrame(imageCamp.nFrame)
		end
	elseif nCamp == tcamp.EVIL then
		imageCamp:Show()
		if nFrame ~= (imageCamp.nFrame or -1) then
			imageCamp.nFrame = 5
			imageCamp:SetFrame(imageCamp.nFrame)
		end
	else
		imageCamp:Hide()
		imageCamp.nFrame = -1
	end
end

function RaidGrid_Party.RedrawAllFadeHP(bForceHide)  --重绘当前血量
	if not RaidGrid_CTM_Edition.bHPHitAlert and not bForceHide then
		return
	end
	
	for nGroupIndex = 0, 4 do
		for nMemberIndex = 0, 4 do
			local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, nGroupIndex)
			if handleRole and handleRole.dwMemberID then
				local shadowLifeFade = handleRole:Lookup("Handle_Common/Shadow_Life_Fade")
				local nFadeAlpha = math.max(shadowLifeFade:GetAlpha() - 10, 0)
				if bForceHide then
					nFadeAlpha = 0
				end
				shadowLifeFade:SetAlpha(nFadeAlpha)
			end
		end
	end
end

function RaidGrid_Party.RedrawHandleRoleHPnMP(dwMemberID)  --HP&MP相关
	local nMemberIndex, nGroupIndex = RaidGrid_Party.GetMemberIndexInGroup(dwMemberID)
	if not nMemberIndex then
		return
	end

	local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, nGroupIndex)
	if not handleRole then
		return
	end

	local tMemberInfo, team = RaidGrid_Party.GetTeamMemberInfo(dwMemberID)
	if not tMemberInfo then
		return
	end

	local nHPHeight = 24
	local nMPHeight = 14
	if RaidGrid_CTM_Edition.bLowMPBar then
		nHPHeight = 29
		nMPHeight = 9
	end

	local playerMember = GetPlayer(dwMemberID)
	local shadowMana = handleRole:Lookup("Handle_Common/Shadow_Mana")
	local nManaShow = 0
	local nPercentage = nil
	local r, g, b = 255, 255, 255
	if playerMember and (playerMember.dwForceID == 8 or playerMember.dwForceID == 21) and playerMember.nCurrentRage and playerMember.nMaxRage then --剑气绘图
		local nCurrentRage = playerMember.nCurrentRage
		local nMaxRage = playerMember.nMaxRage
		local nRagePercentage = nCurrentRage / nMaxRage
		if nMaxRage <= 100 then
			r, g, b = 255, 110, 0
		else
			r, g, b = 255, 170, 0
		end
		nPercentage = nRagePercentage
		nManaShow = nCurrentRage
	elseif playerMember and playerMember.dwForceID == 7 and playerMember.nCurrentEnergy and playerMember.nMaxEnergy and playerMember.nCurrentEnergy > 0 then --神机值绘图
		local nCurrentEnergy = playerMember.nCurrentEnergy
		local nMaxEnergy = playerMember.nMaxEnergy
		local nEnergyPercentage = nCurrentEnergy / nMaxEnergy
		r, g, b = (192 + nEnergyPercentage * (255 - 192)), (192 + nEnergyPercentage * (255 - 192)), 250
		nPercentage = nEnergyPercentage
		nManaShow = nCurrentEnergy
	else
		local nManaPercentage = tMemberInfo.nCurrentMana / tMemberInfo.nMaxMana
		r, g, b = 0, 96, 255
		nPercentage = nManaPercentage
		nManaShow = tMemberInfo.nCurrentMana
	end
	if not nPercentage or nPercentage < 0 or nPercentage > 1 then nPercentage = 1 end
	RaidGrid_Party.RedrawTriangleFan(shadowMana, 121 * RaidGrid_Party.fScaleX * nPercentage, nMPHeight * RaidGrid_Party.fScaleY, r, g, b,RaidGrid_Party.Shadow.bMana)

	local nLifePercentage = tMemberInfo.nCurrentLife / tMemberInfo.nMaxLife
	local shadowLife = handleRole:Lookup("Handle_Common/Shadow_Life")
	local shadowLifeFade = handleRole:Lookup("Handle_Common/Shadow_Life_Fade")
	if not RaidGrid_Party.tOrgW[dwMemberID] then
		RaidGrid_Party.tOrgW[dwMemberID] = 121 * RaidGrid_Party.fScaleX
	end
	local nNewW = 121 * nLifePercentage * RaidGrid_Party.fScaleX
	if not RaidGrid_Party.tLifeColor[dwMemberID] then
		RaidGrid_Party.tLifeColor[dwMemberID] = {255,255,255}
	end

	RaidGrid_Party.RedrawTriangleFan(shadowLife, nNewW, nHPHeight * RaidGrid_Party.fScaleY, RaidGrid_Party.tLifeColor[dwMemberID][1], RaidGrid_Party.tLifeColor[dwMemberID][2], RaidGrid_Party.tLifeColor[dwMemberID][3],RaidGrid_Party.Shadow.bLife)
	
	-- 被击效果显示
	if RaidGrid_CTM_Edition.bHPHitAlert then
		local nOrgFadeW = shadowLifeFade:GetSize()
		local nFadeAlpha = shadowLifeFade:GetAlpha()
		local nDiff = nOrgFadeW - RaidGrid_Party.tOrgW[dwMemberID]
		local nNewFadeW = RaidGrid_Party.tOrgW[dwMemberID]
		
		if nNewW < RaidGrid_Party.tOrgW[dwMemberID] then
			if nFadeAlpha <= 0 then
				nNewFadeW = RaidGrid_Party.tOrgW[dwMemberID]
			else
				nNewFadeW = nOrgFadeW
			end
			shadowLifeFade:SetAlpha(240)
		else
			if nFadeAlpha <= 0 then
				nNewFadeW = nNewW
			else
				nNewFadeW = nNewW + nDiff
			end
		end
		if nNewFadeW >= 121 * RaidGrid_Party.fScaleX then
			nNewFadeW = 121 * RaidGrid_Party.fScaleX
		end
		shadowLifeFade:SetSize(nNewFadeW, nHPHeight * RaidGrid_Party.fScaleY)
	else
		shadowLifeFade:SetSize(0, nHPHeight * RaidGrid_Party.fScaleY)
	end

	RaidGrid_Party.tOrgW[dwMemberID] = nNewW

	
	-- 血量显示
	local textLife = handleRole:Lookup("Handle_Common/Text_Life")
	if tMemberInfo.bDeathFlag or not tMemberInfo.bIsOnLine then
	elseif not RaidGrid_CTM_Edition.nHPShownMode or RaidGrid_CTM_Edition.nHPShownMode == 0 then
		textLife:SetText("")
	elseif RaidGrid_CTM_Edition.nHPShownMode == 1 then
		local nShownLife = tMemberInfo.nMaxLife - tMemberInfo.nCurrentLife
		if nShownLife > 0 then
			textLife:SetText("-" .. nShownLife)
		else
			textLife:SetText("")
		end
	elseif RaidGrid_CTM_Edition.nHPShownMode == 2 then
		textLife:SetText(tMemberInfo.nCurrentLife)
	elseif RaidGrid_CTM_Edition.nHPShownMode == 3 then
		if RaidGrid_CTM_Edition.bFloatNumber then
			textLife:SetText(string.format("%.1f", nLifePercentage * 100) .. "%")
		else
			textLife:SetText(math.floor(nLifePercentage * 100) .. "%")
		end
	elseif RaidGrid_CTM_Edition.nHPShownMode == 4 then
		if tMemberInfo.nCurrentLife > 9999 then
			textLife:SetText(string.format("%.1fw", tMemberInfo.nCurrentLife / 10000))
		else
			textLife:SetText(tMemberInfo.nCurrentLife)
		end
	end
	-- 蓝显示
	local textMana = handleRole:Lookup("Handle_Common/Text_Mana")
	if not RaidGrid_CTM_Edition.nShowMP then
		textMana:SetText("")
	else
		textMana:SetText(nManaShow)
	end
end

function RaidGrid_Party.GetTeamMemberInfo(dwMemberID)	--获得成员信息
	local player = GetClientPlayer()
	if not player or not player.IsInParty() or not player.IsPlayerInMyParty(dwMemberID) then
		return
	end

	local team = GetClientTeam()
	if not team then
		return
	end	

	local tMemberInfo = nil
	local tMemberInfo = team.GetMemberInfo(dwMemberID)
	if not tMemberInfo then
		return
	end
	return tMemberInfo, team
end

------------------------------------------------------------------------------------------------------------
--成员就绪相关
------------------------------------------------------------------------------------------------------------
function RaidGrid_Party.InitReadyCheckCover()	--成员就绪显示
	if not GetClientPlayer().IsInParty() then
		return
	end
	
	local team = GetClientTeam()
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) ~= GetClientPlayer().dwID then
		return
	end
	Send_RaidReadyConfirm()
	for nGroupIndex = 0, 4 do
		for nMemberIndex = 0, 4 do
			local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, nGroupIndex)
			if handleRole then
				local imageReadyCover = handleRole:Lookup("Image_ReadyCover")
				local imageNotReady = handleRole:Lookup("Image_NotReady")
				local aniReady = handleRole:Lookup("Animate_Ready")
				
				if handleRole.dwMemberID and handleRole.dwMemberID ~= GetClientPlayer().dwID then
					local tMemberInfo, team = RaidGrid_Party.GetTeamMemberInfo(handleRole.dwMemberID)
					if tMemberInfo and tMemberInfo.bIsOnLine then
						imageReadyCover:Show()
						imageReadyCover:SetAlpha(255)
						imageNotReady:Hide()
						aniReady:Hide()
					else
						imageReadyCover:Hide()
						imageNotReady:Hide()
						aniReady:Hide()
					end
				else
					imageReadyCover:Hide()
					imageNotReady:Hide()
					aniReady:Hide()
				end
			end
		end
	end
end

function RaidGrid_Party.ClearReadyCheckCover()	--清除就绪显示
	for nGroupIndex = 0, 4 do
		for nMemberIndex = 0, 4 do
			local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, nGroupIndex)
			if handleRole then
				local imageReadyCover = handleRole:Lookup("Image_ReadyCover")
				local imageNotReady = handleRole:Lookup("Image_NotReady")
				local aniReady = handleRole:Lookup("Animate_Ready")
				imageReadyCover:Hide()
				imageNotReady:Hide()
				aniReady:Hide()
			end
		end
	end
end

function RaidGrid_Party.UpdateReadyCheckCover(dwMemberID, nReadyState)	--更新就绪显示
	local nMemberIndex, nGroupIndex = RaidGrid_Party.GetMemberIndexInGroup(dwMemberID)
	if not nMemberIndex then
		return
	end
	
	local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, nGroupIndex)
	if not handleRole then
		return
	end
	
	local imageNotReady = handleRole:Lookup("Image_NotReady")
	local aniReady = handleRole:Lookup("Animate_Ready")
	if nReadyState == 1 then
		imageNotReady:Hide()
		aniReady:Show()
		aniReady:SetAlpha(255)
	else
		aniReady:Hide()
		imageNotReady:Show()
	end
end

function RaidGrid_Party.UpdateReadyCheckFade()	--更新就绪检查消退
	if not GetClientPlayer().IsInParty() then
		return
	end
	local team = GetClientTeam()
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) ~= GetClientPlayer().dwID then
		return
	end

	for nGroupIndex = 0, 4 do
		for nMemberIndex = 0, 4 do
			local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nMemberIndex, nGroupIndex)
			if handleRole then
				local imageReadyCover = handleRole:Lookup("Image_ReadyCover")
				local imageNotReady = handleRole:Lookup("Image_NotReady")
				local aniReady = handleRole:Lookup("Animate_Ready")
				if aniReady:IsVisible() then
					aniReady:SetAlpha(math.max(aniReady:GetAlpha() - 15, 0))
					imageReadyCover:SetAlpha(math.max(imageReadyCover:GetAlpha() - 30, 0))
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------------------------
--[[选中相关&成员类型]]
------------------------------------------------------------------------------------------------------------
function RaidGrid_Party.ShowHandleRoleInGroup(nIndex, nGroupIndex, dwMemberID) --显示处理环
	local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nIndex, nGroupIndex)
	if not handleRole then
		return
	end

	handleRole.dwMemberID = dwMemberID
	handleRole:Lookup("Handle_Common"):Show()
	handleRole:Lookup("Handle_Buff_Boxes"):Show()
	handleRole:Lookup("Handle_Icons"):Show()
	
	handleRole:Lookup("Image_Selected"):Hide()
	handleRole:Lookup("Animate_TargetTarget"):Hide()
	
	handleRole:Lookup("Image_BG_Slot"):Hide()
end

function RaidGrid_Party.ClearHandleRoleInGroup(nIndex, nGroupIndex) --清除处理环
	local handleRole = RaidGrid_Party.GetHandleRoleInGroup(nIndex, nGroupIndex)
	if not handleRole then
		return
	end

	handleRole.dwMemberID = nil
	handleRole:Lookup("Handle_Common"):Hide()
	handleRole:Lookup("Handle_Icons"):Hide()
	
	handleRole:Lookup("Image_Selected"):Hide()
	handleRole:Lookup("Animate_TargetTarget"):Hide()
	handleRole:Lookup("Animate_TargetTarget"):SetAlpha(170)
	
	if RaidGrid_CTM_Edition.bShowAllMemberGrid then
		handleRole:Lookup("Image_BG_Slot"):Show()
	else
		handleRole:Lookup("Image_BG_Slot"):Hide()
	end
		
	handleRole:Lookup("Image_ReadyCover"):Hide()
	handleRole:Lookup("Image_NotReady"):Hide()
	handleRole:Lookup("Animate_Ready"):Hide()
	
	handleRole:Lookup("Handle_CastingBar"):Hide()
	
	local handleBoxes = handleRole:Lookup("Handle_Buff_Boxes")
	for i = 1, 4 do
		local box = handleBoxes:Lookup("Box_" .. i)
		local shadow = handleBoxes:Lookup("Shadow_BuffColor_" .. i)
		local text = handleBoxes:Lookup("Text_Time_" .. i)
		text:Hide()
		shadow:Hide()
		box:Hide()
		box.tInfo = nil
	end
	handleBoxes:Hide()
end

function RaidGrid_Party.GetMemberIndexInGroup(dwMemberID)	--获得组队索引
	for nGroupIndex = 0, 4 do
		for i = 0, 4 do
			local handleRole = RaidGrid_Party.GetHandleRoleInGroup(i, nGroupIndex)
			if handleRole and handleRole.dwMemberID == dwMemberID then
				return i, nGroupIndex
			end
		end
	end
end

function RaidGrid_Party.GetHandleRoleInGroup(nIndex, nGroupIndex)	--获得选中的队伍成员
	local frame = RaidGrid_Party.GetPartyPanel(nGroupIndex)
	if not frame then
		return
	end

	if not nIndex or nIndex < 0 or nIndex > 4 then
		return
	end
	return frame.tHandleRoles[nIndex]
end

function RaidGrid_Party.GetCharacterColor(dwCharacterID, dwForceID) --获得成员颜色
	local player = GetClientPlayer()
	if not player then
		return 128, 128, 128, 0
	end
	if not IsPlayer(dwCharacterID) then
		return 168, 168, 168, 0
	end
	
	if not dwForceID then
		local target = GetPlayer(dwCharacterID)
		if not target then
			return 128, 128, 128, 0
		end
		
		dwForceID = target.dwForceID
		if not dwForceID then
			return 168, 168, 168, 0
		end
	end
	if dwForceID == 0 then		-- 侠
		return 255, 255, 255, dwForceID
	elseif dwForceID == 1 then	-- 少林
		return 255, 255, 170, dwForceID
	elseif dwForceID == 2 then	-- 万花
		return 175, 25, 255, dwForceID
	elseif dwForceID == 3 then	-- 天策
		return 250, 75, 100, dwForceID
	elseif dwForceID == 4 then	-- 纯阳
		return 148, 178, 255, dwForceID  
	elseif dwForceID == 5 then	-- 七秀
		return 255, 125, 255, dwForceID
	elseif dwForceID == 6 then	-- 五毒
		return 140, 80, 255, dwForceID
	elseif dwForceID == 7 then  -- 唐门
		return 0, 128, 192, dwForceID
	elseif dwForceID == 8 then	-- 藏剑
		return 255, 200, 0, dwForceID
	elseif dwForceID == 9 then	-- 丐帮
		return 185, 125, 60, dwForceID	
	elseif dwForceID == 10 then	-- 明教
		return 240, 50, 200, dwForceID
	elseif dwForceID == 21 then
		return 180, 60, 0, dwForceID
	end
	return 168, 168, 168, 0
end

function RaidGrid_Party.SetTarget(dwTargetID)	--设置目标
	local nType = TARGET.NPC
	if not dwTargetID or (dwTargetID <= 0) then
		nType = TARGET.NO_TARGET
		dwTargetID = 0
	elseif IsPlayer(dwTargetID) then
		nType = TARGET.PLAYER
	end
	SetTarget(nType, dwTargetID)
end

function RaidGrid_Party.SetTempTarget(dwMemberID, bEnter)
	if not RaidGrid_Party.bTempTargetEnable then
		return
	end
	local player = GetClientPlayer()
	if not player then
		return
	end
	if not dwMemberID or dwMemberID <= 0 then
		return
	end
	local tarType, tardwID = player.GetTarget()
	if bEnter then
		RaidGrid_Party.dwLastTempTargetId = tardwID
		if dwMemberID ~= tardwID then
			if player.dwID == dwMemberID then
				if IsCtrlKeyDown() then
					RaidGrid_Party.SetTarget(dwMemberID)
				end
			else
				RaidGrid_Party.SetTarget(dwMemberID)
			end
		end
	else
		if RaidGrid_Party.dwLastTempTargetId then
			if (dwMemberID == tardwID or tardwID <= 0) and RaidGrid_Party.dwLastTempTargetId ~= tardwID then
				if player.dwID == RaidGrid_Party.dwLastTempTargetId then
					RaidGrid_Party.SetTarget(RaidGrid_Party.dwLastTempTargetId)
				elseif RaidGrid_Party.dwLastTempTargetId > 0 then
					RaidGrid_Party.SetTarget(RaidGrid_Party.dwLastTempTargetId)
				else
					RaidGrid_Party.SetTarget(-1)
				end
			end
		end
	end
end


function RaidGrid_Party.RedrawTriangleFan(shadow, x, y, r, g, b,bPureColour) --重绘三角扇
	shadow:SetTriangleFan(true)
	shadow:ClearTriangleFanPoint()
	local a = RaidGrid_Party.Shadow.a
	local d = RaidGrid_Party.Shadow.d
	if not bPureColour then
		shadow:AppendTriangleFanPoint(	0,	0,	64,	64,	64,	a) --x,y,r,g,b,alpha
		shadow:AppendTriangleFanPoint(	x,	0,	64,	64,	64,	a)
		shadow:AppendTriangleFanPoint(	x,	y,	r,	g,	b,	a)
		shadow:AppendTriangleFanPoint(	0,	y,	r,	g,	b,	a)
	else
		local r2 = math.ceil(r*d)
		local g2 = math.ceil(g*d)
		local b2 = math.ceil(b*d)
		shadow:AppendTriangleFanPoint(	0,	0,	r2,	g2,	b2,	a) --x,y,r,g,b,alpha
		shadow:AppendTriangleFanPoint(	x,	0,	r2,	g2,	b2,	a)
		shadow:AppendTriangleFanPoint(	x,	y,	r2,	g2,	b2,	a)
		shadow:AppendTriangleFanPoint(	0,	y,	r2,	g2,	b2,	a)	
	end
end



------------------------------------------------------------------------------------------------------------
--面板相关
------------------------------------------------------------------------------------------------------------
function RaidGrid_Party.GetPartyPanel(nIndex) --获得组队面板
	if not nIndex or nIndex < 0 or nIndex > 4 then
		return
	end
	return Station.Lookup("Normal/RaidGrid_Party_" .. nIndex)
end

function RaidGrid_Party.AutoLinkAllPanel2()	--自动连接所有面板2
	local player = GetClientPlayer()
	if not player or not player.IsInParty() then
		return
	end
	
	local team = GetClientTeam()
	if not team then
		return
	end	

	local frameMain = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	if not frameMain then
		return
	end
	local nX, nY = frameMain:GetRelPos()
	nY = nY + 24
	
	local nShownCount = 0
	local tPosnSize = {[-1] = {nX = nX, nY = nY, nW = 0, nH = 0}}
	local nGroupNum = team.nGroupNum
	for i = 0, nGroupNum - 1 do
		local framePartyPanel = RaidGrid_Party.GetPartyPanel(i)
		if framePartyPanel and (RaidGrid_CTM_Edition.bShowAllPanel or RaidGrid_Party.IsPartyOpened(i)) then
			local tGroupInfo = team.GetGroupInfo(i)
			local nMemberCount = #tGroupInfo.MemberList
			local nW, nH = 128 * RaidGrid_Party.fScaleX, (235 - (5 - nMemberCount) * 42) * RaidGrid_Party.fScaleY + 1
			framePartyPanel:SetSize(nW, nH)
			
			if nShownCount < RaidGrid_CTM_Edition.nAutoLinkMode then
				tPosnSize[nShownCount] = {nX = nX + (128 * RaidGrid_Party.fScaleX * nShownCount), nY = nY, nW = nW, nH = nH}
			else
				local nUpperIndex = math.min(nShownCount - RaidGrid_CTM_Edition.nAutoLinkMode, RaidGrid_CTM_Edition.nAutoLinkMode - 1)
				local tPS = tPosnSize[nUpperIndex] or {nH = 235 * RaidGrid_Party.fScaleY}
				tPosnSize[nShownCount] = {
					nX = nX + (128 * RaidGrid_Party.fScaleX * (nShownCount - RaidGrid_CTM_Edition.nAutoLinkMode)),
					nY = nY + tPosnSize[nUpperIndex].nH,
					nW = nW,
					nH = nH}
			end
			RaidGrid_CTM_Edition.SetPartyPanelPos(i, tPosnSize[nShownCount].nX, tPosnSize[nShownCount].nY)
			nShownCount = nShownCount + 1
		end
	end
end

function RaidGrid_Party.AutoLinkAllPanel() --自动连接所有面板
	local frameMain = Station.Lookup("Normal/RaidGrid_CTM_Edition")
	if not frameMain then
		return
	end
	local nX, nY = frameMain:GetRelPos()
	nY = nY + 24
	local nShownCount = 0
	local tPosnSize = {[-1] = {nX = nX, nY = nY, nW = 0, nH = 0}}
	
	for i = 0, 4 do
		local framePartyPanel = RaidGrid_Party.GetPartyPanel(i)
		if framePartyPanel and (RaidGrid_CTM_Edition.bShowAllPanel or RaidGrid_Party.IsPartyOpened(i)) then
			local nW, nH = framePartyPanel:GetSize()
			--_, nH = framePartyPanel:Lookup("", "Handle_BG/Image_BG_B"):GetRelPos()
			--nH = nH + 16
			--framePartyPanel:SetSize(nW, nH)
			
			if nShownCount < RaidGrid_CTM_Edition.nAutoLinkMode then
				tPosnSize[nShownCount] = {nX = nX + (128 * RaidGrid_Party.fScaleX * nShownCount), nY = nY, nW = nW, nH = nH}
			else
				local nUpperIndex = math.min(nShownCount - RaidGrid_CTM_Edition.nAutoLinkMode, RaidGrid_CTM_Edition.nAutoLinkMode - 1)
				local tPS = tPosnSize[nUpperIndex] or {nH = 235 * RaidGrid_Party.fScaleY}
				tPosnSize[nShownCount] = {
					nX = nX + (128 * RaidGrid_Party.fScaleX * (nShownCount - RaidGrid_CTM_Edition.nAutoLinkMode)),
					nY = nY + tPosnSize[nUpperIndex].nH,
					nW = nW,
					nH = nH}
			end
			RaidGrid_CTM_Edition.SetPartyPanelPos(i, tPosnSize[nShownCount].nX, tPosnSize[nShownCount].nY)
			nShownCount = nShownCount + 1
		end
	end
end

local nDragGroupID = nil			-- 拖动的源小队序号
local dwDragMemberID = nil			-- 拖动的角色ID
local bLastShowAllMemberGrid = nil
function RaidGrid_Party.CreateNewPartyPanel(nIndex) --创建新的小队面板
	local frame = RaidGrid_Party.GetPartyPanel(nIndex)
	if frame then
		Wnd.CloseWindow(frame:GetName())
	end
	frame = Wnd.OpenWindow(szIniFile, "RaidGrid_Party_" .. nIndex)

	local textGroup = frame:Lookup("", "Handle_BG/Text_GroupIndex")
	textGroup:SetFontScale(RaidGrid_Party.fScaleFont)
	if textGroup then
		textGroup:SetText(g_tStrings.STR_NUMBER[nIndex + 1])
	end
	
	-- 初始化格子
	frame.tHandleRoles = {}
	local handleRoles = frame:Lookup("", "Handle_Roles")
	for i = 0, 4 do
		local handleRole = handleRoles:AppendItemFromIni(szIniFile, "Handle_RoleDummy", "Handle_Role_" .. i)
		frame.tHandleRoles[i] = handleRole
		handleRole:SetRelPos(5, i * 42 + 10)
		handleRole:Show()
		
		local handleBoxes = handleRole:Lookup("Handle_Buff_Boxes")
		if handleBoxes then
			for j = 1, 4 do
				local box = handleBoxes:Lookup("Box_" .. j)
				local shadow = handleBoxes:Lookup("Shadow_BuffColor_" .. j)
				local text = handleBoxes:Lookup("Text_Time_" .. j)
				box:SetObject(1,0)
				box:ClearObjectIcon()
				box:SetObjectIcon(1435)
				box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
				box:SetOverTextFontScheme(0, 15)
				box:SetOverText(0, "")
				box:Hide()
				shadow:Hide()
				text:Hide()
				text:SetFontScale(RaidGrid_Party.fScaleFont * 0.8)
			end
		end
		
		local boxCasting = handleRole:Lookup("Handle_CastingBar/Box_CastingIcon")
		boxCasting:Show()
		boxCasting:SetObject(1,0)
		boxCasting:ClearObjectIcon()
		boxCasting:SetAlpha(180)
		
		if RaidGrid_CTM_Edition.bLowMPBar then
			local shadowMana = handleRole:Lookup("Handle_Common/Shadow_Mana")
			local shadowLife = handleRole:Lookup("Handle_Common/Shadow_Life")
			local shadowLifeFade = handleRole:Lookup("Handle_Common/Shadow_Life_Fade")
			local imageCasting = handleRole:Lookup("Handle_CastingBar/Image_CastP")
			shadowMana:SetRelPos(-2, 29)
			shadowLifeFade:SetSize(121, 29)
			imageCasting:SetRelPos(16, 29)
			imageCasting:SetSize(102, 8)
			handleRole:FormatAllItemPos()
		end
		--------------------------------------------------------------------------------------
		
		local textLife = handleRole:Lookup("Handle_Common/Text_Life")
		textLife:SetFontScale(RaidGrid_Party.fScaleFont)
		local textMana = handleRole:Lookup("Handle_Common/Text_Mana")
		textMana:SetFontScale(RaidGrid_Party.fScaleFont)
		local textDistance = handleRole:Lookup("Handle_Common/Text_Distance")
		textDistance:SetFontScale(RaidGrid_Party.fScaleFont)
		local textName = handleRole:Lookup("Handle_Common/Text_Name")
		textName:SetFontScale(RaidGrid_Party.fScaleFont)
		local textName2 = handleRole:Lookup("Text_Name_2")
		textName2:SetFontScale(RaidGrid_Party.fScaleFont)
		RaidGrid_Party.ClearHandleRoleInGroup(i, nIndex)
		
		handleRole.nGroupIndex = nIndex

		handleRole.OnItemLButtonDrag = function()
			local szName = this:GetName()
			local team = GetClientTeam()
			local player = GetClientPlayer()
			if RaidGrid_Party.IsInRaid() and (not IsAltKeyDown() and RaidGrid_CTM_Edition.bAltNeededForDrag) or not szName:match("Handle_Role_") or not team or not player.IsInParty() or team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) ~= player.dwID then
				return
			end
			bLastShowAllMemberGrid = RaidGrid_CTM_Edition.bShowAllMemberGrid
			RaidGrid_CTM_Edition.bShowAllMemberGrid = true
			
			nDragGroupID = this.nGroupIndex
			dwDragMemberID = this.dwMemberID
			if not dwDragMemberID then
				return
			end
			
			RaidGrid_Party.bDrag = true
			RaidGrid_Party.ReloadRaidPanel()
			for i = 0, 4 do
				local frameParty = RaidGrid_Party.GetPartyPanel(i)
				if frameParty then
					frameParty:Show()
				end
			end
			RaidGrid_CTM_Edition.OpenRaidDragPanel(dwDragMemberID)
			RaidGrid_Party.AutoLinkAllPanel()
		end

		handleRole.OnItemLButtonDragEnd = function()
			local szName = this:GetName()
			local team = GetClientTeam()
			local player = GetClientPlayer()
			if RaidGrid_Party.IsInRaid() and not RaidGrid_Party.bDrag or not szName:match("Handle_Role_") or not team or not player.IsInParty() or team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) ~= player.dwID then
				RaidGrid_CTM_Edition.bShowAllMemberGrid = bLastShowAllMemberGrid
				nDragGroupID = nil
				dwDragMemberID = nil
				RaidGrid_CTM_Edition.CloseRaidDragPanel()
				if RaidGrid_Party.bDrag then
					RaidGrid_Party.ReloadRaidPanel()
				end
				return
			end
			RaidGrid_Party.bDrag = false	
			RaidGrid_CTM_Edition.bShowAllMemberGrid = bLastShowAllMemberGrid		
			local nTargetGroup = this.nGroupIndex
			local dwTargetMemberID = this.dwMemberID or 0
			
			if nDragGroupID and dwDragMemberID then
				team.ChangeMemberGroup(dwDragMemberID, nTargetGroup, dwTargetMemberID)
			end
			
			if dwTargetMemberID == dwDragMemberID then
				RaidGrid_Party.ReloadRaidPanel()
			end
			nDragGroupID = nil
			dwDragMemberID = nil
			RaidGrid_CTM_Edition.CloseRaidDragPanel()
		end

		handleRole.OnItemMouseEnter = function()
			local nX, nY = this:GetRoot():GetAbsPos()
			local nW, nH = this:GetRoot():GetSize()
			local me = GetClientPlayer()
			if RaidGrid_Party.bTempTargetFightTip and not me.bFightState or not RaidGrid_Party.bTempTargetFightTip then
				RaidGrid_CTM_Edition.OutputTeamMemberTip(this.dwMemberID, {nX, nY + 5, nW, nH})
			end
			RaidGrid_Party.SetTempTarget(this.dwMemberID, true)
		end
		handleRole.OnItemMouseLeave = function()
			HideTip()
			RaidGrid_Party.SetTempTarget(this.dwMemberID, false)
		end
		
		handleRole.OnItemLButtonClick = function()
			local szName = this:GetName()
			local player = GetClientPlayer()
			if not player then
				return
			end
			
			if szName:match("Handle_Role_") then
				local dwMemberID = this.dwMemberID
				if not dwMemberID or dwMemberID <= 0 or not IsPlayer(dwMemberID) then
					return
				end
				
				local player = GetPlayer(dwMemberID)
				if not player then
					player = RaidGrid_Party.GetTeamMemberInfo(dwMemberID)
				end
	
				if IsCtrlKeyDown() then
					RaidGrid_CTM_Edition.EditBox_AppendLinkPlayer(player.szName)
				else
					RaidGrid_Party.SetTarget(dwMemberID)
					RaidGrid_Party.dwLastTempTargetId = dwMemberID
				end
			end
		end
		
		handleRole.OnItemRButtonClick = function()
			local szName = this:GetName()
			local team = GetClientTeam()
			if not team then
				return
			end
			
			if szName:match("Handle_Role_") then
				local tMenu = {}
				local player = GetClientPlayer()
				local dwMemberID = handleRole.dwMemberID
				
				if dwMemberID and player.IsInParty() then
					if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) == player.dwID then
						RaidGrid_CTM_Edition.InsertChangeGroupMenu(tMenu, dwMemberID)
					end
					
					if dwMemberID ~= player.dwID then
						InsertTeammateMenu(tMenu, dwMemberID)
					end
			
					if tMenu and #tMenu > 0 then
						PopupMenu(tMenu)
					end
				end
			end
		end
	end
	handleRoles:FormatAllItemPos()
	
	local handleDummy = frame:Lookup("", "Handle_Dummy/Handle_RoleDummy")
	if handleDummy then
		handleDummy:Hide()
	end
	
	frame:Scale(RaidGrid_Party.fScaleX, RaidGrid_Party.fScaleY)
	
	return frame
end

function RaidGrid_Party.CreateAllNewPartyPanel() --创建所有新的小队面板
	for i = 0, 4 do
		RaidGrid_Party.CreateNewPartyPanel(i)
	end
end

function RaidGrid_Party.ReloadRaidPanel()	--重载团队面板

	if RaidGrid_CTM_Edition.bShowRaid then
		if not RaidGrid_CTM_Edition.bRaidEnable or (RaidGrid_CTM_Edition.bShowInRaid and not RaidGrid_Party.IsInRaid()) then
			RaidGrid_CTM_Edition.bShowRaid = false
		end
	elseif RaidGrid_CTM_Edition.bRaidEnable then
		if not RaidGrid_CTM_Edition.bShowInRaid or RaidGrid_Party.IsInRaid() then
			RaidGrid_CTM_Edition.bShowRaid = true
		end
	end
	
	if not RaidGrid_CTM_Edition.bShowRaid then
		RaidGrid_CTM_Edition.TeammatePanel_Switch(true)
	end

	if RaidGrid_CTM_Edition.bAutoHideCTM then
		if not RaidGrid_CTM_Edition.bShowRaid or not GetClientPlayer().IsInParty() then
			RaidGrid_CTM_Edition.ClosePanel()
		else
			RaidGrid_CTM_Edition.ShowPanel()
		end
	end

	if not RaidGrid_Party.bDrag then
		RaidGrid_Party.CreateAllNewPartyPanel()
	end

	local team = GetClientTeam()
	for i = 0, 4 do
		local tGroupInfo = nil
		if math.min(4, team.nGroupNum - 1) >= i then
			tGroupInfo = team.GetGroupInfo(i)
		end
		if tGroupInfo and tGroupInfo.MemberList and #tGroupInfo.MemberList > 0 and math.min(4, team.nGroupNum - 1) >= i then
			local tMemberList = tGroupInfo.MemberList
			for nMemberIndex = 1, 5 do
				local dwMemberID = tMemberList[nMemberIndex]
				RaidGrid_Party.OnAddOrDeleteMember(dwMemberID, i)
				RaidGrid_Party.RedrawHandleRoleHPnMP(dwMemberID)
				RaidGrid_Party.RedrawHandleRoleInfo(dwMemberID)
				RaidGrid_Party.RedrawHandleRoleInfoEx(dwMemberID)
			end
		elseif not RaidGrid_CTM_Edition.bShowAllPanel then
			local frameParty = RaidGrid_Party.GetPartyPanel(i)
			frameParty:Hide()
		end
		
		if not RaidGrid_CTM_Edition.bShowRaid then
			local frameParty = RaidGrid_Party.GetPartyPanel(i)
			frameParty:Hide()
		end
	end

	for i = 0, 4 do
		RaidGrid_CTM_Edition.SetPartyPanelPos(i, RaidGrid_CTM_Edition.tLastPartyPanelLoc[i+1].nX, RaidGrid_CTM_Edition.tLastPartyPanelLoc[i+1].nY)
	end
	RaidGrid_Party.UpdateMarkImage()
	
	if RaidGrid_CTM_Edition.bAutoLinkAllPanel then
		RaidGrid_Party.AutoLinkAllPanel()
	end
end

function RaidGrid_Party.ClosePartyPanel(nIndex, bClose) --关闭组队面板
	local frame = RaidGrid_Party.GetPartyPanel(nIndex)
	if frame then
		if bClose then
			Wnd.CloseWindow(frame:GetName())
		else
			frame:Hide()
		end
	end
end

function RaidGrid_Party.IsPartyOpened(nIndex)	--组队面板是否打开
	local frame = RaidGrid_Party.GetPartyPanel(nIndex)
	if frame then
		return frame:IsVisible()
	end
end