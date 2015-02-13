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
 }
RegisterCustomData("RaidGrid_Party.Shadow")

local CTM_INIFILE = JH.GetAddonInfo().szRootPath .. "RaidGrid_CTM_Edition/ui/RaidGrid_Party.ini"
local CTM_ITEM    = JH.GetAddonInfo().szRootPath .. "RaidGrid_CTM_Edition/ui/item.ini"
local CTM_IMAGES  = JH.GetAddonInfo().szRootPath .. "RaidGrid_CTM_Edition/images/ForceColorBox.UITex"
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
	frame:Show()


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
									textDistance:SetText(string.format("%.1f", nDist2d))
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
				if nMarkImageIndex and PARTY_MARK_ICON_FRAME_LIST[nMarkImageIndex] then
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

function RaidGrid_Party.RedrawTargetSelectImage()  --重绘目标选择图像
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
				if target and target.dwID == handleRole.dwMemberID then
					imageSelected:Show()
				else
					imageSelected:Hide()
				end
				local aniTargetTarget = handleRole:Lookup("Animate_TargetTarget")
				if RaidGrid_CTM_Edition.bShowTargetTargetAni then
					if target and targetTarget and targetTarget.dwID == handleRole.dwMemberID then
						aniTargetTarget:Show()
					else
						aniTargetTarget:Hide()
					end
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
	local r, g, b = RaidGrid_CTM_Edition.GetForceColor(tMemberInfo.dwForceID)
	if not tMemberInfo.bIsOnLine then
		RaidGrid_Party.tLifeColor[dwMemberID] = { 128, 128, 128 }
		textLife:SetFontColor(128, 128, 128)
		textLife:SetText(g_tStrings.STR_FRIEND_NOT_ON_LINE)
	elseif tMemberInfo.bDeathFlag then
		RaidGrid_Party.tLifeColor[dwMemberID] = { 255, 0, 0 }
		textLife:SetFontColor(255, 0, 0)
		textLife:SetText(g_tStrings.FIGHT_DEATH)
	else
		local nRedOnline, nGreenOnline, nBlueOnline = unpack(RaidGrid_Party.tHPBarColor)
		if not RaidGrid_CTM_Edition.bColorHPBarWithDistance then
			RaidGrid_Party.tLifeColor[dwMemberID] = { nRedOnline, nGreenOnline, nBlueOnline }
		end
		textLife:SetFontColor(255, 255, 255)
	end

	local textName = handleRole:Lookup("Text_Name_2")
	textName:SetText(tMemberInfo.szName)
	if RaidGrid_CTM_Edition.bColoredName then
		textName:SetFontColor(r, g, b)
	else
		textName:SetFontColor(255, 255, 255)
	end
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
	
	local img = handleRole:Lookup("Handle_Icons/Image_Icon")
	if RaidGrid_CTM_Edition.bShowIcon == 2 then
		local _, nIconID = JH.GetSkillName(tMemberInfo.dwMountKungfuID, 0)
		img:FromIconID(nIconID)
	elseif RaidGrid_CTM_Edition.bShowIcon == 1 then
		img:FromUITex(GetForceImage(tMemberInfo.dwForceID))
	elseif RaidGrid_CTM_Edition.bShowIcon == 3 then
		local camp = { [0] = -1, [1] = 43, [2] = 40 }
		img:FromUITex("UI/Image/Button/ShopButton.uitex", camp[tMemberInfo.nCamp])
	end
	
	if RaidGrid_Party.fScaleX ~= RaidGrid_Party.fScaleY then
		local szImageSize = 28
		if RaidGrid_Party.fScaleX > RaidGrid_Party.fScaleY then
			szImageSize = szImageSize * RaidGrid_Party.fScaleY
			img:SetSize(szImageSize, szImageSize)
		else
			szImageSize = szImageSize * RaidGrid_Party.fScaleX
			img:SetSize(szImageSize, szImageSize)
		end
	end
	img:Show()

	local imageForceBG = handleRole:Lookup("Handle_Common/Image_BG_Force")
	if RaidGrid_CTM_Edition.bColoredGrid then
		imageForceBG:FromUITex(CTM_IMAGES, 3)
	else
		imageForceBG:FromUITex(CTM_IMAGES, 3)
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

local HIDE_FORCE = {
	[7] = true,
	[8] = true,
	[10] = true,
	[21] = true,
}
local IsPlayerManaHide = function(dwForceID)
	return HIDE_FORCE[dwForceID]
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

	local nHPHeight = 29
	local nMPHeight = 9

	local shadowMana = handleRole:Lookup("Handle_Common/Shadow_Mana")
	local nManaShow = 0
	local nPercentage = nil
	local r, g, b = 0, 96, 255
	if IsPlayerManaHide(tMemberInfo.dwForceID) then
		nPercentage = 0
		nManaShow = 0
	else
		nPercentage = tMemberInfo.nCurrentMana / tMemberInfo.nMaxMana
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
		RaidGrid_Party.tLifeColor[dwMemberID] = { 255, 255, 255 }
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
	if not tMemberInfo.bDeathFlag and tMemberInfo.bIsOnLine then
		local life = handleRole:Lookup("Handle_Common/Text_Life")
		if RaidGrid_CTM_Edition.nHPShownMode2 == 0 then
			life:SetText("")
		else
			local fnAction = function(val, max)
				if RaidGrid_CTM_Edition.nHPShownNumMode == 1 then
					if val > 9999 then
						return string.format("%.1fw", val / 10000)
					else
						return val
					end
				elseif RaidGrid_CTM_Edition.nHPShownNumMode == 2 then
					return string.format("%.1f", val / max * 100) .. "%"
				elseif RaidGrid_CTM_Edition.nHPShownNumMode == 3 then
					return val
				end
			end
			if RaidGrid_CTM_Edition.nHPShownMode2 == 2 then
				life:SetText(fnAction(tMemberInfo.nCurrentLife, tMemberInfo.nMaxLife))
			elseif RaidGrid_CTM_Edition.nHPShownMode2 == 1 then
				local nShownLife = tMemberInfo.nMaxLife - tMemberInfo.nCurrentLife
				if nShownLife > 0 then
					life:SetText("-" .. fnAction(nShownLife, tMemberInfo.nMaxLife))
				else
					life:SetText("")
				end
			end
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

function RaidGrid_Party.GetTeamMemberInfo(dwMemberID) -- 获得成员信息
	local me = GetClientPlayer()
	if not me or not me.IsInParty() or not me.IsPlayerInMyParty(dwMemberID) then
		return
	end
	local team = GetClientTeam()
	if not team then
		return
	end	
	return team.GetMemberInfo(dwMemberID), team
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
JH.AddHotKey("JH_CTM_Ready", g_tStrings.STR_RAID_READY_CONFIRM_START, RaidGrid_Party.InitReadyCheckCover)

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
			RaidGrid_Party.SetTarget(dwMemberID)
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
	if not bPureColour then
		shadow:AppendTriangleFanPoint(	0,	0,	64,	64,	64,	a) --x,y,r,g,b,alpha
		shadow:AppendTriangleFanPoint(	x,	0,	64,	64,	64,	a)
		shadow:AppendTriangleFanPoint(	x,	y,	r,	g,	b,	a)
		shadow:AppendTriangleFanPoint(	0,	y,	r,	g,	b,	a)
	else
		shadow:AppendTriangleFanPoint(	0,	0,	r,	g,	b,	a) --x,y,r,g,b,alpha
		shadow:AppendTriangleFanPoint(	x,	0,	r,	g,	b,	a)
		shadow:AppendTriangleFanPoint(	x,	y,	r,	g,	b,	a)
		shadow:AppendTriangleFanPoint(	0,	y,	r,	g,	b,	a)	
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

function RaidGrid_Party.BringToTop()
	for i = 0, 4 do
		if Station.Lookup("Normal/RaidGrid_Party_" .. i) then
			Station.Lookup("Normal/RaidGrid_Party_" .. i):BringToTop()
		end
	end
	Station.Lookup("Normal/RaidGrid_CTM_Edition"):BringToTop()
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
function RaidGrid_Party.CreateNewPartyPanel(nIndex) --创建新的小队面板
	local frame = RaidGrid_Party.GetPartyPanel(nIndex)
	if frame then
		Wnd.CloseWindow(frame:GetName())
	end
	frame = Wnd.OpenWindow(CTM_INIFILE, "RaidGrid_Party_" .. nIndex)

	local textGroup = frame:Lookup("", "Handle_BG/Text_GroupIndex")
	textGroup:SetFontScale(RaidGrid_Party.fScaleFont)
	if textGroup then
		textGroup:SetText(g_tStrings.STR_NUMBER[nIndex + 1])
	end
	
	-- 初始化格子
	frame.tHandleRoles = {}
	local handleRoles = frame:Lookup("", "Handle_Roles")
	for i = 0, 4 do
		-- 性能杀手。。。
		local handleRole = handleRoles:AppendItemFromIni(CTM_ITEM, "Handle_RoleDummy", "Handle_Role_" .. i)
		frame.tHandleRoles[i] = handleRole
		handleRole:SetRelPos(5, i * 42 + 10)
		handleRole:Show()
		
		local handleBoxes = handleRole:Lookup("Handle_Buff_Boxes")
		if handleBoxes then
			for j = 1, 4 do
				local box = handleBoxes:Lookup("Box_" .. j)
				local text = handleBoxes:Lookup("Text_Time_" .. j)
				box:SetObject(UI_OBJECT_ITEM)
				text:SetFontScale(RaidGrid_Party.fScaleFont * 0.8)
			end
		end
		
		local shadowMana = handleRole:Lookup("Handle_Common/Shadow_Mana")
		local shadowLife = handleRole:Lookup("Handle_Common/Shadow_Life")
		local shadowLifeFade = handleRole:Lookup("Handle_Common/Shadow_Life_Fade")
		shadowMana:SetRelPos(-2, 29)
		shadowLifeFade:SetSize(121, 29)
		handleRole:FormatAllItemPos()
		------------------------------------------------------------------------------
		
		local textLife = handleRole:Lookup("Handle_Common/Text_Life")
		textLife:SetFontScale(RaidGrid_Party.fScaleFont)
		local textMana = handleRole:Lookup("Handle_Common/Text_Mana")
		textMana:SetFontScale(RaidGrid_Party.fScaleFont)
		local textDistance = handleRole:Lookup("Handle_Common/Text_Distance")
		textDistance:SetFontScale(RaidGrid_Party.fScaleFont)
		local textName2 = handleRole:Lookup("Text_Name_2")
		textName2:SetFontScale(RaidGrid_Party.fScaleFont)
		RaidGrid_Party.ClearHandleRoleInGroup(i, nIndex)
		
		handleRole.nGroupIndex = nIndex

		handleRole.OnItemLButtonDrag = function()
			local team = GetClientTeam()
			local player = GetClientPlayer()
			if (not IsAltKeyDown() and RaidGrid_CTM_Edition.bAltNeededForDrag) or not player.IsInRaid() or not RaidGrid_CTM_Edition.IsLeader() then
				return
			end
			RaidGrid_CTM_Edition.bShowAllMemberGrid = true
			RaidGrid_CTM_Edition.bShowAllPanel = true
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
			RaidGrid_Party.AutoLinkAllPanel()
			RaidGrid_Party.BringToTop()
			RaidGrid_CTM_Edition.OpenRaidDragPanel(dwDragMemberID)
		end
		
		handleRole.OnItemLButtonUp = function()
			JH.DelayCall(50, function()
				if RaidGrid_Party.bDrag then
					RaidGrid_CTM_Edition.bShowAllMemberGrid = false
					RaidGrid_CTM_Edition.bShowAllPanel = false
					RaidGrid_Party.bDrag = false
					nDragGroupID = nil
					dwDragMemberID = nil
					RaidGrid_CTM_Edition.CloseRaidDragPanel()
					RaidGrid_Party.ReloadRaidPanel()
				end
			end)
		end
		
		handleRole.OnItemLButtonDragEnd = function()
			local team = GetClientTeam()
			local player = GetClientPlayer()
			local dwTargetMemberID = this.dwMemberID or 0
			if dwTargetMemberID ~= dwDragMemberID then
				RaidGrid_Party.bDrag = false	
				RaidGrid_CTM_Edition.bShowAllMemberGrid = false
				RaidGrid_CTM_Edition.bShowAllPanel = false
				local nTargetGroup = this.nGroupIndex
				if nDragGroupID and dwDragMemberID then
					team.ChangeMemberGroup(dwDragMemberID, nTargetGroup, dwTargetMemberID)
				end
				nDragGroupID = nil
				dwDragMemberID = nil
				RaidGrid_CTM_Edition.CloseRaidDragPanel()
			end
		end

		handleRole.OnItemMouseEnter = function()
			local nX, nY = this:GetRoot():GetAbsPos()
			local nW, nH = this:GetRoot():GetSize()
			if RaidGrid_Party.bDrag then
				this:Lookup("Image_Selected"):Show()
			end
			local me = GetClientPlayer()
			if RaidGrid_Party.bTempTargetFightTip and not me.bFightState or not RaidGrid_Party.bTempTargetFightTip then
				RaidGrid_CTM_Edition.OutputTeamMemberTip(this.dwMemberID, { nX, nY + 5, nW, nH })
			end
			RaidGrid_Party.SetTempTarget(this.dwMemberID, true)
		end
		
		handleRole.OnItemMouseLeave = function()
			if RaidGrid_Party.bDrag then
				this:Lookup("Image_Selected"):Hide()
			end
			HideTip()
			RaidGrid_Party.SetTempTarget(this.dwMemberID, false)
		end

		handleRole.OnItemLButtonDown = function()
			RaidGrid_Party.BringToTop()
			local dwMemberID = this.dwMemberID
			if not dwMemberID or dwMemberID <= 0 or not IsPlayer(dwMemberID) then
				return
			end
			local player = RaidGrid_Party.GetTeamMemberInfo(dwMemberID)
			if IsCtrlKeyDown() then
				RaidGrid_CTM_Edition.EditBox_AppendLinkPlayer(player.szName)
			else
				RaidGrid_Party.SetTarget(dwMemberID)
				RaidGrid_Party.dwLastTempTargetId = dwMemberID
			end
		end
		
		handleRole.OnItemRButtonClick = function()
			RaidGrid_Party.BringToTop()
			local menu = {}
			local me = GetClientPlayer()
			local dwMemberID = this.dwMemberID
			if dwMemberID and me.IsInParty() then
				if RaidGrid_CTM_Edition.IsLeader() then
					RaidGrid_CTM_Edition.InsertChangeGroupMenu(menu, dwMemberID)
				end
				local player = RaidGrid_Party.GetTeamMemberInfo(dwMemberID)
				if dwMemberID ~= me.dwID then
					InsertTeammateMenu(menu, dwMemberID)
					table.insert(menu, { szOption = g_tStrings.STR_LOOKUP, bDisable = not player.bIsOnLine, fnAction = function() 
						ViewInviteToPlayer(dwMemberID) end 
					})
				end
				if #menu > 0 then
					PopupMenu(menu)
				end
			end
		end
	end
	handleRoles:FormatAllItemPos()
	frame:Scale(RaidGrid_Party.fScaleX, RaidGrid_Party.fScaleY)
	
	return frame
end

function RaidGrid_Party.CreateAllNewPartyPanel() --创建所有新的小队面板
	for i = 0, 4 do
		RaidGrid_Party.CreateNewPartyPanel(i)
	end
end

function RaidGrid_Party.ReloadRaidPanel()	--重载团队面板
	if not RaidGrid_Party.bDrag then
		RaidGrid_Party.CreateAllNewPartyPanel()
	end
	local team = GetClientTeam()
	local me = GetClientPlayer()
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
		
		-- if not RaidGrid_CTM_Edition.bShowRaid then
			-- local frameParty = RaidGrid_Party.GetPartyPanel(i)
			-- frameParty:Hide()
		-- end
	end
	RaidGrid_CTM_Edition.Switch()
	RaidGrid_Party.UpdateMarkImage()
	RaidGrid_Party.AutoLinkAllPanel()
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