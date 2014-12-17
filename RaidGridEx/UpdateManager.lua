-- ----------------------------------------------------------------------------------------------------------
-- Title:	团队增强
-- Date:	2010.06.22
-- Author:	Danexx
-- Comment:	我看过很多遍的花开花谢，
--			采过很多甜美或者苦涩的果实，
--			尝过很多种类的好酒，
--			却只遇见过一个能举樽共饮的人…… 
-- ----------------------------------------------------------------------------------------------------------
RaidGridEx = RaidGridEx or {}
RaidGridEx.tGroupList = {}			-- 按照实际小队排序法则保存当前团队位置
RaidGridEx.tForceList = {}			-- 按照门派分类保存虚拟团队位置
RaidGridEx.tCustomList = {}			-- 自定义团队位置
RaidGridEx.tRoleIDList = {}			-- 在团队中的角色ID总表

RaidGridEx.nMaxCol = 5
RaidGridEx.nMaxRow = 5

local szIniFile = "Interface/JH/RaidGridEx/RaidGridEx.ini"
-- ----------------------------------------------------------------------------------------------------------
-- 界面相关的控制和处理
-- ----------------------------------------------------------------------------------------------------------
-- 创建所有可能的格子, 一般在初始化的时候调用
function RaidGridEx.CreateAllRoleHandle()
	RaidGridEx.handleRoles:Clear()
	for nCol = 0, RaidGridEx.nMaxCol -1 do
		for nRow = 1, RaidGridEx.nMaxRow  do
			local handleRole = RaidGridEx.handleRoles:AppendItemFromIni(szIniFile, "Handle_RoleDummy", "Handle_Role_" .. nCol .. "_" .. nRow)
			handleRole:SetRelPos((nCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound)* RaidGridEx.fScale, ((nRow - 1) * RaidGridEx.nRowLength + RaidGridEx.nBottomBound)* RaidGridEx.fScale)
			handleRole:Show()
			handleRole.nGroupIndex = nCol
			handleRole.nSortIndex = nRow
			handleRole.dwMemberID = nil
			RaidGridEx.HideRoleHandle(nCol, nRow)
			handleRole:Scale(RaidGridEx.fScale, RaidGridEx.fScale)
		end
	end
	RaidGridEx.handleRoles:FormatAllItemPos()
end

-- 显示一个格子
function RaidGridEx.ShowRoleHandle(nCol, nRow, handleRole)
	local handleRole = handleRole or RaidGridEx.handleRoles:Lookup("Handle_Role_" .. tostring(nCol) .. "_" .. tostring(nRow))
	if not handleRole then
		return
	end
	handleRole:Show()
	handleRole:SetAlpha(255)	
	--handleRole:Lookup("Animate_SelectRole"):Hide()
	handleRole:Lookup("Text_Name"):SetText("")
	handleRole:Lookup("Image_LifeBG"):Show()
	handleRole:Lookup("Image_LifeBG"):SetAlpha(48)
	handleRole:Lookup("Image_BGBox_White"):Show()
	handleRole:Lookup("Image_BGBox_White"):SetAlpha(16)
	RaidGridEx.HideAllLifeBar(handleRole)
	handleRole:Lookup("Text_LifeValue"):SetText("")
	handleRole:Lookup("Image_ManaBG"):Show()
	handleRole:Lookup("Image_ManaBG"):SetAlpha(64)
	handleRole:Lookup("Image_Mana"):Show()
	RaidGridEx.HideAllManaBar(handleRole)
	handleRole:Lookup("Image_Leader"):Hide()
	handleRole:Lookup("Image_Looter"):Hide()
	handleRole:Lookup("Image_Mark"):Hide()
	handleRole:Lookup("Image_MarkImage"):Hide()
	handleRole:Lookup("Image_Matrix"):Hide()
end

-- 隐藏一个格子
function RaidGridEx.HideRoleHandle(nCol, nRow, handleRole)
	local handleRole = handleRole or RaidGridEx.handleRoles:Lookup("Handle_Role_" .. nCol .. "_" .. nRow)
	if not handleRole then
		return
	end
	handleRole:Show()
	handleRole:SetAlpha(32)	
	--handleRole:Lookup("Animate_SelectRole"):Hide()
	handleRole:Lookup("Text_Name"):SetText("")
	handleRole:Lookup("Image_LifeBG"):Hide()
	handleRole:Lookup("Image_BGBox_White"):Show()
	handleRole:Lookup("Image_BGBox_White"):SetAlpha(8)
	RaidGridEx.HideAllLifeBar(handleRole)
	handleRole:Lookup("Text_LifeValue"):SetText("")
	handleRole:Lookup("Image_ManaBG"):Hide()
	handleRole:Lookup("Image_Mana"):Hide()
	RaidGridEx.HideAllManaBar(handleRole)
	handleRole:Lookup("Image_Leader"):Hide()
	handleRole:Lookup("Image_Looter"):Hide()
	handleRole:Lookup("Image_Mark"):Hide()
	handleRole:Lookup("Image_MarkImage"):Hide()
	handleRole:Lookup("Image_Matrix"):Hide()
end

-- 鼠标移动到格子
function RaidGridEx.EnterRoleHandle(nCol, nRow, handleRole)
	handleRole = handleRole or RaidGridEx.handleRoles:Lookup("Handle_Role_" .. nCol .. "_" .. nRow)
	if not handleRole then
		return
	end
	nCol = nCol or handleRole.nGroupIndex
	nRow = nRow or handleRole.nSortIndex
	
	if handleRole:GetAlpha() == 32 then
		handleRole:SetAlpha(128)
	elseif handleRole:GetAlpha() == 255 then
		handleRole:Lookup("Animate_SelectRole"):Show()
		local dwMemberID = RaidGridEx.tGroupList[nCol]
		if dwMemberID then
			dwMemberID = RaidGridEx.tGroupList[nCol][nRow]
		end
		if not dwMemberID then
			return
		end
		local tMemberInfo = RaidGridEx.GetTeamMemberInfo(dwMemberID)
		if not tMemberInfo then
			return
		end		
		local nLifeValue = tMemberInfo.nCurrentLife
		local nLifePercentage = tMemberInfo.nCurrentLife / tMemberInfo.nMaxLife
		
		if IsCtrlKeyDown() then
			nLifeValue = math.floor((nLifeValue / tMemberInfo.nMaxLife) * 100) .. "%"
		end
		local textLifeValue = handleRole:Lookup("Text_LifeValue")
		--在非血量常显模式下,要显示数值必须确认目标存活且在线
		if textLifeValue and not RaidGridEx.bShowLifeValue and tMemberInfo.bIsOnLine and not tMemberInfo.bDeathFlag then
			textLifeValue:SetText(nLifeValue)
			textLifeValue:SetFontScale(RaidGridEx.fontScale)
			if nLifePercentage < 0.3 then
				textLifeValue:SetFontColor(255,96,96)
			elseif nLifePercentage <0.7 then
				textLifeValue:SetFontColor(255,192,64)
			else
				textLifeValue:SetFontColor(255,128,128)
			end
			textLifeValue:Show()
		end		
		local nX, nY = RaidGridEx.frameSelf:GetAbsPos()
		local nW, nH = RaidGridEx.frameSelf:GetSize()
		OutputTeamMemberTip(dwMemberID, {nX, nY, nW, nH})
	end
end

-- 鼠标离开格子
function RaidGridEx.LeaveRoleHandle(nCol, nRow, handleRole)
	local handleRole = handleRole or RaidGridEx.handleRoles:Lookup("Handle_Role_" .. nCol .. "_" .. nRow)
	if not handleRole then
		return
	end
	nCol = nCol or handleRole.nGroupIndex
	nRow = nCol or handleRole.nSortIndex
	
	if handleRole:GetAlpha() == 128 then
		RaidGridEx.HideRoleHandle(nCol, nRow, handleRole)
	elseif handleRole:GetAlpha() == 255 then
		if RaidGridEx.handleLastSelect ~= handleRole then
			handleRole:Lookup("Animate_SelectRole"):Hide()
			RaidGridEx.handleLastSelect = nil
		end
		local textLifeValue = handleRole:Lookup("Text_LifeValue")
		--必须在非血量常显模式下,确定标记文字既不是离线也不是重伤才清除文字并隐藏文本控件,否则从不隐藏
		if textLifeValue and not RaidGridEx.bShowLifeValue and textLifeValue:GetText() ~= "重伤" and textLifeValue:GetText() ~= "离线" then
			textLifeValue:SetText("")
			textLifeValue:SetFontScale(RaidGridEx.fontScale)
			textLifeValue:SetFontColor(255,255,255)
			textLifeValue:Hide()
		end
		HideTip()
	end
end

-- 通过角色 ID 获得这个 ID 的角色在团队中的位置
function RaidGridEx.GetHandlePosByID(dwMemberID)
	for nCol = 0, RaidGridEx.nMaxCol -1 do
		for nRow = 1, RaidGridEx.nMaxRow  do
			if RaidGridEx.tGroupList and RaidGridEx.tGroupList[nCol] and RaidGridEx.tGroupList[nCol][nRow] == dwMemberID then
				return nCol, nRow
			end
		end
	end
end

-- 通过角色 ID 获得面板中对应控件的名字
function RaidGridEx.GetHandleNameByID(dwMemberID)
	local nCol, nRow = RaidGridEx.GetHandlePosByID(dwMemberID)
	if nCol and nRow then
		return "Handle_Role_" .. nCol .. "_" .. nRow
	end
end

-- 通过角色 ID 获得面板中对应控件
function RaidGridEx.GetRoleHandleByID(dwMemberID)
	local szName = RaidGridEx.GetHandleNameByID(dwMemberID)
	if szName then
		local handleRole = RaidGridEx.handleRoles:Lookup(szName)
		return handleRole
	end
end

-- 重新绘制特定角色的血量和蓝条
function RaidGridEx.RedrawMemberHandleHPnMP(dwMemberID)
	local handleRole = RaidGridEx.GetRoleHandleByID(dwMemberID)
	local tMemberInfo = RaidGridEx.GetTeamMemberInfo(dwMemberID)

	if not handleRole or not tMemberInfo then
		return
	end
	handleRole:Show()
	
	-- 血量显示和离线标记
	RaidGridEx.HideAllLifeBar(handleRole)
	local textLifeValue = handleRole:Lookup("Text_LifeValue")
	if tMemberInfo.bIsOnLine then
		local nMaxLife = tMemberInfo.nMaxLife
		if nMaxLife == 0 then nMaxLife = 1 end
		local nLifePercentage = tMemberInfo.nCurrentLife / nMaxLife
		if RaidGridEx.bAutoDistColor then
			handleRole.imageLifeF = handleRole.imageLifeF or handleRole:Lookup("Image_Life_Green")
		else
			if nLifePercentage <= 0.3 then
				handleRole.imageLifeF = handleRole:Lookup("Image_Life_Red")
			elseif nLifePercentage <= 0.6 then
				handleRole.imageLifeF = handleRole:Lookup("Image_Life_Orange")
			else
				handleRole.imageLifeF = handleRole:Lookup("Image_Life_Green")
			end
		end
		if nLifePercentage < 0 or nLifePercentage > 1 then
			nLifePercentage = 1
		end
		handleRole.imageLifeF:Show()
		handleRole.imageLifeF:SetPercentage(nLifePercentage)
		handleRole.imageLifeF:SetAlpha(230)
		-- 若重伤,则添加标记
		if tMemberInfo.bDeathFlag then
			textLifeValue:SetText("重伤")
			textLifeValue:SetFontScale(RaidGridEx.fontScale)
			textLifeValue:SetFontColor(255,0,0)
			textLifeValue:Show()
		else
			--在非血量常显模式下,若目标存活而重伤文字却存在则立刻清除文字并隐藏文本控件
			if not RaidGridEx.bShowLifeValue and textLifeValue:GetText() == "重伤" then
				textLifeValue:SetText("")
				textLifeValue:SetFontScale(RaidGridEx.fontScale)
				textLifeValue:SetFontColor(255,255,255)
				textLifeValue:Hide()
			end
			--在血量常显模式下,只有当处于损血显示状态且损血为0时,才清除血量文字
			if tMemberInfo.nCurrentLife and RaidGridEx.bShowLifeValue then
				local nLifeValue = tMemberInfo.nCurrentLife
				local nCostLife = tMemberInfo.nMaxLife - tMemberInfo.nCurrentLife
				local nCostLife2 = nCostLife
				if RaidGridEx.bLifePercent then
					nLifeValue = math.ceil((tMemberInfo.nCurrentLife / tMemberInfo.nMaxLife) * 100) .. "%"
					nCostLife2 = math.ceil((nCostLife / tMemberInfo.nMaxLife) * 100) .. "%"
				elseif RaidGridEx.bLifeSimplify then
					if nLifeValue > 9999 then
						nLifeValue = string.format("%.1f",nLifeValue / 10000) .. "w"
					end
					if nCostLife > 9999 then
						nCostLife2 = string.format("%.1f",nCostLife / 10000) .. "w"
					end
				end
				
				if RaidGridEx.bShowLastLife then
					textLifeValue:SetText(nLifeValue)
					textLifeValue:SetFontScale(RaidGridEx.fontScale)
					textLifeValue:SetFontColor(255,255,255)
					textLifeValue:Show()
				else			
					if nCostLife > 0 then
						textLifeValue:SetText("-"..nCostLife2)
						textLifeValue:SetFontScale(RaidGridEx.fontScale)
						if nLifePercentage < 0.3 then
							textLifeValue:SetFontColor(255,96,96)
						elseif nLifePercentage <0.7 then
							textLifeValue:SetFontColor(255,192,64)
						else
							textLifeValue:SetFontColor(255,128,128)
						end
						textLifeValue:Show()
					else
						textLifeValue:SetText("")
						textLifeValue:SetFontScale(RaidGridEx.fontScale)
						textLifeValue:SetFontColor(255,255,255)
						textLifeValue:Hide()
					end
				end
			end
		end
	else
		textLifeValue:SetText("离线")
		textLifeValue:SetFontScale(RaidGridEx.fontScale)
		textLifeValue:SetFontColor(96,96,96)
		textLifeValue:Show()
	end
	
	-- 内力显示
	RaidGridEx.HideAllManaBar(handleRole)
	local playerMember = GetPlayer(dwMemberID)
	local imageMana = handleRole:Lookup("Image_Mana")
	if playerMember and (tMemberInfo.dwMountKungfuID == 10144 or tMemberInfo.dwMountKungfuID == 10145)  and playerMember.nCurrentRage > 0 then
		local nCurrentRage = playerMember.nCurrentRage
		local nMaxRage = playerMember.nMaxRage
		if nMaxRage == 0 then nMaxRage = 1 end
		local nRagePercentage = nCurrentRage / nMaxRage
		if nRagePercentage < 0 or nRagePercentage > 1 then
			nRagePercentage = 1
		end
		imageMana = handleRole:Lookup("Image_CJRage")
		imageMana:SetPercentage(nRagePercentage)
	elseif playerMember and (tMemberInfo.dwMountKungfuID == 10224 or tMemberInfo.dwMountKungfuID == 10225) and playerMember.nCurrentEnergy > 0 then
		local nCurrentEnergy = playerMember.nCurrentEnergy
		local nMaxEnergy = playerMember.nMaxEnergy
		if nMaxEnergy == 0 then nMaxEnergy = 1 end
		local nEnergyPercentage = nCurrentEnergy / nMaxEnergy
		if nEnergyPercentage < 0 or nEnergyPercentage > 1 then
			nEnergyPercentage = 1
		end
		
		imageMana = handleRole:Lookup("Image_TMRage")
		imageMana:SetPercentage(nEnergyPercentage)
	else
		local nMaxMana = tMemberInfo.nMaxMana
		if nMaxMana == 0 then nMaxMana = 1 end
		local nPercentage = tMemberInfo.nCurrentMana / nMaxMana
		if nPercentage < 0 or nPercentage > 1 then
			nPercentage = 1
		end
		imageMana:SetPercentage(nPercentage)
	end
	if tMemberInfo.bIsOnLine then
		imageMana:Show()
	else
		imageMana:Hide()
	end
end

-- 重新绘制队友标记图标
local tMarkerImageList = {66, 67, 73, 74, 75, 76, 77, 78, 81, 82}
function RaidGridEx.UpdateMarkImage(dwMemberID)
	local team = GetClientTeam()
	local tPartyMark = team.GetTeamMark()
	if not tPartyMark then
		return
	end	
	local handleRole = RaidGridEx.GetRoleHandleByID(dwMemberID)
	if handleRole then
		local nMarkImageIndex = tPartyMark[dwMemberID]
		if nMarkImageIndex and tMarkerImageList[nMarkImageIndex] and RaidGridEx.bShowMark then
			local imageMark = handleRole:Lookup("Image_MarkImage")
			imageMark:SetFrame(tMarkerImageList[nMarkImageIndex])
			imageMark:Show()
			imageMark:SetAlpha(255)
			imageMark.nFlashDegSpeed = -1
		else
			local imageMark = handleRole:Lookup("Image_MarkImage")
			imageMark:Hide()
		end
	end
end

-- 重新绘制特定角色的状态图标, 如阵眼, 队长等
function RaidGridEx.RedrawMemberHandleState(dwMemberID)
	local handleRole = RaidGridEx.GetRoleHandleByID(dwMemberID)
	local tMemberInfo = RaidGridEx.GetTeamMemberInfo(dwMemberID)
	if not handleRole or not tMemberInfo then
		return
	end
	handleRole:Show()
	
	-- 队长
	local imageLeader = handleRole:Lookup("Image_Leader")
	if RaidGridEx.IsLeader(dwMemberID) then
		imageLeader:Show()
	else
		imageLeader:Hide()
	end
	
	-- 分配者
	local imageLooter = handleRole:Lookup("Image_Looter")
	if RaidGridEx.IsLooter(dwMemberID) then
		imageLooter:Show()
	else
		imageLooter:Hide()
	end
	
	-- 标记者
	local imageMark = handleRole:Lookup("Image_Mark")
	if RaidGridEx.IsMarker(dwMemberID) then
		imageMark:Show()
	else
		imageMark:Hide()
	end
	
	-- 阵眼 
	local imageMatrix = handleRole:Lookup("Image_Matrix")
	if RaidGridEx.IsMatrixcore(dwMemberID) then
		imageMatrix:Show()
	else
		imageMatrix:Hide()
	end
	
	-- 队友标记
	RaidGridEx.UpdateMarkImage(dwMemberID)
end

-- 这里用来更新角色的BUFF状态, 如 BUFF监视 等
function RaidGridEx.UpdateMemberBuff(dwMemberID)
	local handleRole = RaidGridEx.GetRoleHandleByID(dwMemberID)
	local hPlayer = GetPlayer(dwMemberID)
	if not hPlayer or handleRole:GetAlpha() == 32 then
		return
	end
	
	if not handleRole.tBoxes then	
		local handleDebuffs = handleRole:Lookup("Handle_Debuffs")
		if not handleDebuffs then
			return
		end
		local tBoxes = {}
		for i = 1, 4, 1 do
			local box = handleDebuffs:Lookup("Box_" .. i)
			if box then
				box:Hide()
				box:SetAlpha(RaidGridEx.nBuffFlashAlpha)
				box:SetObject(1,0)
				box:ClearObjectIcon()
			
				box.szName = nil
				box.nIconID = -1
				box.bShow = false
				box.nEndFrame = 0
				box.nRate = 9999
				box.szColor = nil
				box.nAlpha = RaidGridEx.nBuffFlashAlpha
				box.nTrend = 1
				tBoxes[i] = box
			end
		end
		handleRole.tBoxes = tBoxes
	end
	
	local nBoxAlpha = RaidGridEx.nBuffFlashAlpha
	local bFlash = false
	if not RaidGridEx.bAutoBUFFColor then
		nBoxAlpha = 0
	elseif RaidGridEx.nBuffFlashTime == 0 then
		nBoxAlpha = RaidGridEx.nBuffFlashAlpha
	else
		bFlash = true
	end
	
	for i = 1, 4 do
		if handleRole.tBoxes[i].bShow then
			if bFlash then
				nBoxAlpha = handleRole.tBoxes[i].nAlpha
				local nTrend = handleRole.tBoxes[i].nTrend
				if nBoxAlpha <= 70 then
					nBoxAlpha = nBoxAlpha + (RaidGridEx.nBuffFlashTime * nTrend) / 15
				elseif nBoxAlpha <= (70 + (RaidGridEx.nBuffFlashAlpha - 70) / 2) then
					nBoxAlpha = nBoxAlpha + (RaidGridEx.nBuffFlashTime * nTrend) / 2
				elseif nBoxAlpha >= (RaidGridEx.nBuffFlashAlpha - 10) then
					nBoxAlpha = nBoxAlpha + (RaidGridEx.nBuffFlashTime * nTrend) / 10
				else
					nBoxAlpha = nBoxAlpha + (RaidGridEx.nBuffFlashTime * nTrend)
				end
				if nBoxAlpha >= RaidGridEx.nBuffFlashAlpha then
					nBoxAlpha = RaidGridEx.nBuffFlashAlpha
					nTrend = nTrend * -1
				elseif nBoxAlpha <= 50 then
					nBoxAlpha = 50
					nTrend = nTrend * -1
				end
				handleRole.tBoxes[i].nAlpha = nBoxAlpha
				handleRole.tBoxes[i].nTrend = nTrend
			end
		
			handleRole.tBoxes[i]:Show()
			handleRole.tBoxes[i]:SetAlpha(nBoxAlpha)
			if nBoxAlpha == RaidGridEx.nBuffFlashAlpha then
				handleRole.tBoxes[i]:SetObjectStaring(true)
			end
			
			-- 检查存在时间
			if handleRole.tBoxes[i].nEndFrame then
				local nLogic = GetLogicFrameCount()
				if nLogic > ((handleRole.tBoxes[i].nEndFrame) or 0) then
					handleRole.tBoxes[i].szName = nil
					handleRole.tBoxes[i].nIconID = -1
					handleRole.tBoxes[i].bShow = false
					handleRole.tBoxes[i].nEndFrame = 0
					handleRole.tBoxes[i].nRate = 9999
					handleRole.tBoxes[i].szColor = nil
					handleRole.tBoxes[i].nAlpha = RaidGridEx.nBuffFlashAlpha
					handleRole.tBoxes[i].nTrend = 1
					handleRole.tBoxes[i]:ClearObjectIcon()
					handleRole.tBoxes[i]:Hide()
				end
			end
		else
			handleRole.tBoxes[i]:Hide()
		end
	end
	
	local shadow = handleRole:Lookup("Shadow_Color")
	if shadow then
		shadow:SetAlpha(RaidGridEx.nBuffCoverAlpha)
		local nEndFrame = shadow.nEndFrame or 0
		local nLogic = GetLogicFrameCount()
		if nLogic > nEndFrame then
			shadow.nEndFrame = 0
			shadow.nRate = 9999
			shadow:Hide()
		end
	end
end

-- 这里用来更新角色的一些特殊显示, 如 距离监视等, 玩家名字等
function RaidGridEx.UpdateMemberSpecialState(dwMemberID)
	local handleRole = RaidGridEx.GetRoleHandleByID(dwMemberID)
	local tMemberInfo = RaidGridEx.GetTeamMemberInfo(dwMemberID)
	if not handleRole or not tMemberInfo then
		return
	end
	handleRole:Show()
	
	-- 名字显示, 颜色显示
	local KungfuInfo = RaidGridEx.GetKungfuByID(dwMemberID)
	local textName = handleRole:Lookup("Text_Name")
	local textKungfu = handleRole:Lookup("Text_Kungfu")
	local imageKungfu = handleRole:Lookup("Image_Kungfu")
	local szName = tMemberInfo.szName
	local NameLimit = ((RaidGridEx.fScale/0.2)-4)*2 +4
	
		local tcamp = {
		["ALL"] = -1;
		["NEUTRAL"] = 0;
		["GOOD"] = 1;--CAMP.GOOD
		["EVIL"] = 2;
	}

	textName:SetFontScheme(RaidGridEx.szFontScheme)
	
	--处理角色名字自动缩进，缩进限制必须使用偶数！奇数会出错的！
	if NameLimit > 12 then
		NameLimit = 12
	end	
	if RaidGridEx.szFontScheme == 23 then
		NameLimit = NameLimit - 2
	end
	
	--处理名字颜色
	local nRed, nGreen, nBlue = RaidGridEx.GetCharacterColor(dwMemberID, tMemberInfo.dwForceID)
	if tMemberInfo.bDeathFlag then
		nRed, nGreen, nBlue = 255, 0, 0
	elseif not tMemberInfo.bIsOnLine then
		nRed, nGreen, nBlue = 128, 128, 128
	else
		if RaidGridEx.bShowNameColorByCondition == 2 and KungfuInfo then
			nRed, nGreen, nBlue = KungfuInfo[2],KungfuInfo[3],KungfuInfo[4]
		elseif RaidGridEx.bShowNameColorByCondition == 3 then
			if not tMemberInfo.nCamp or tMemberInfo.nCamp == 0 then
				nRed, nGreen, nBlue = 128,255,128
			elseif tMemberInfo.nCamp == tcamp.GOOD or tMemberInfo.nCamp == 1 then
				nRed, nGreen, nBlue = 64,64,255
			elseif tMemberInfo.nCamp == tcamp.EVIL or tMemberInfo.nCamp == 2 then
				nRed, nGreen, nBlue = 255,64,64
			end
		end
	end	
	
	-- if #szName <= NameLimit then
		-- textName:SetFontSpacing(-1)
		textName:SetText(tMemberInfo.szName)
	-- else
		-- textName:SetFontSpacing(-3)
		-- textName:SetText(tMemberInfo.szName:sub(1, NameLimit) .. "…")
	-- end
	
	textName:SetFontColor(nRed, nGreen, nBlue)
	
	if KungfuInfo and RaidGridEx.bShowKungfu then
		if RaidGridEx.bShowKungfuIcon then
			local nIconID = Table_GetSkillIconID(KungfuInfo[5], 0)
			if nIconID and KungfuInfo[5] ~= 10000 then
				textKungfu:Hide()
				imageKungfu:FromIconID(nIconID)
				imageKungfu:Show()
			else
				imageKungfu:Hide()
			end
		else
			imageKungfu:Hide()
			textKungfu:SetText(KungfuInfo[1])
			textKungfu:SetFontColor(KungfuInfo[2],KungfuInfo[3],KungfuInfo[4])
			textKungfu:Show()
		end
	else
		imageKungfu:Hide()
		textKungfu:Hide()
	end
	
	if RaidGridEx.bFightNameAlpha and GetClientPlayer().bFightState then
		imageKungfu:SetAlpha(192)
		textName:SetAlpha(192)
		textKungfu:SetAlpha(192)
	else
		imageKungfu:SetAlpha(240)
		textName:SetAlpha(240)
		textKungfu:SetAlpha(240)
	end
	
	-- 距离处理和颜色
	local objPlayer = GetPlayer(dwMemberID)
	if RaidGridEx.bAutoDistColor then			-- 距离模式
		if not tMemberInfo.bIsOnLine then		-- 不在线
			handleRole.imageLifeF = handleRole:Lookup("Image_Life_White")
		elseif objPlayer then					-- 同步范围内
			local player = GetClientPlayer()
			if player then
				local nDist2d = math.floor(((objPlayer.nX - player.nX) ^ 2 + (objPlayer.nY - player.nY) ^ 2) ^ 0.5)
				local nDistM = nDist2d / 64
				if nDistM <= RaidGridEx.nDis1 then			-- 8米以内
					handleRole.imageLifeF = handleRole:Lookup("Image_Life_" .. RaidGridEx.szDistColor_8)
				elseif nDistM <= RaidGridEx.nDis2 then		-- 20米以内
					handleRole.imageLifeF = handleRole:Lookup("Image_Life_" .. RaidGridEx.szDistColor_20)
				elseif nDistM <= RaidGridEx.nDis3 then		-- 24米以内
					handleRole.imageLifeF = handleRole:Lookup("Image_Life_" .. RaidGridEx.szDistColor_24)
				else							-- 24米之外
					handleRole.imageLifeF = handleRole:Lookup("Image_Life_" .. RaidGridEx.szDistColor_999)
				end				
			end
			RaidGridEx.RedrawMemberHandleHPnMP(dwMemberID)
		else									-- 同步范围外
			handleRole.imageLifeF = handleRole:Lookup("Image_Life_" .. RaidGridEx.szDistColor_0)
			RaidGridEx.RedrawMemberHandleHPnMP(dwMemberID)
		end
	end
end

-- 隐藏所有的血条颜色
function RaidGridEx.HideAllLifeBar(handleRole)
	handleRole:Lookup("Image_Life_White"):Hide()
	handleRole:Lookup("Image_Life_Red"):Hide()
	handleRole:Lookup("Image_Life_Orange"):Hide()
	handleRole:Lookup("Image_Life_Blue"):Hide()
	handleRole:Lookup("Image_Life_Green"):Hide()
end

function RaidGridEx.HideAllManaBar(handleRole)
	handleRole:Lookup("Image_Mana"):Hide()
	handleRole:Lookup("Image_CJRage"):Hide()
	handleRole:Lookup("Image_TMRage"):Hide()
end



-- 自动缩小团队界面, bFullMode 表示模式
function RaidGridEx.AutoScalePanel()
	if not RaidGridEx.bAutoScalePanel or RaidGridEx.bDrag then
		for nCol = 0, RaidGridEx.nMaxCol -1 do
			for nRow = 1, RaidGridEx.nMaxRow do
				local handleRole = RaidGridEx.handleRoles:Lookup("Handle_Role_" .. nCol .. "_" .. nRow)
				handleRole:SetRelPos((nCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, ((nRow - 1) * RaidGridEx.nRowLength + RaidGridEx.nBottomBound)*RaidGridEx.fScale)
				handleRole:Show()
			end
		end
		-- 处理背景和尺寸
		RaidGridEx.handleBG:Lookup("Image_Title_BG"):SetSize((RaidGridEx.nMaxCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, RaidGridEx.nTitleHeight)
		RaidGridEx.handleBG:Lookup("Image_BG"):SetSize((RaidGridEx.nMaxCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, (RaidGridEx.nMaxRow * RaidGridEx.nRowLength + RaidGridEx.nBottomBound) * RaidGridEx.fScale)
		RaidGridEx.frameSelf:SetSize((RaidGridEx.nMaxCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, (RaidGridEx.nMaxRow * RaidGridEx.nRowLength + RaidGridEx.nTopBound + RaidGridEx.nBottomBound) * RaidGridEx.fScale)	
		RaidGridEx.frameSelf:SetDragArea(0, 0, (RaidGridEx.nMaxCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, 25)
	else
		local nMaxRow = 0
		local nMaxCol = 0
		local nOffsetDepth = 0
		for nCol = 0, RaidGridEx.nMaxCol -1 do
			local bEmptyGroup = true
			for nRow = 1, RaidGridEx.nMaxRow do
				local handleRole = RaidGridEx.handleRoles:Lookup("Handle_Role_" .. nCol .. "_" .. nRow)
				handleRole:SetRelPos(((nCol + nOffsetDepth) * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, ((nRow - 1) * RaidGridEx.nRowLength + RaidGridEx.nBottomBound) * RaidGridEx.fScale)
				
				if handleRole:GetAlpha() == 32 then				-- 空格子
					handleRole:Hide()
				else
					nMaxRow = math.max(nMaxRow, nRow)
					bEmptyGroup = false
				end
			end
			if bEmptyGroup then
				nOffsetDepth = nOffsetDepth - 1
			else
				nMaxCol = nMaxCol + 1
			end
		end
		-- 处理背景和尺寸
		nMaxRow = math.max(nMaxRow, 1)
		nMaxCol = math.max(nMaxCol, 2)
		RaidGridEx.handleBG:Lookup("Image_Title_BG"):SetSize((nMaxCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, RaidGridEx.nTitleHeight)
		RaidGridEx.handleBG:Lookup("Image_BG"):SetSize((nMaxCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, (nMaxRow * RaidGridEx.nRowLength + RaidGridEx.nBottomBound) * RaidGridEx.fScale)
		RaidGridEx.frameSelf:SetSize((nMaxCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, (nMaxRow * RaidGridEx.nRowLength + RaidGridEx.nTopBound + RaidGridEx.nBottomBound) * RaidGridEx.fScale)
		RaidGridEx.frameSelf:SetDragArea(0, 0, (nMaxCol * RaidGridEx.nColLength + RaidGridEx.nLeftBound) * RaidGridEx.fScale, 25)
	end
	
	RaidGridEx.handleRoles:FormatAllItemPos()
end

-- ----------------------------------------------------------------------------------------------------------
-- 本地缓存数据初始化以及更新: 由于依赖团队更新事件来更新本地缓存, 所以这里的所有数据全都以缓存做处理
-- ----------------------------------------------------------------------------------------------------------
-- 重新加载所有团队数据
-- 主要定义了数据的结构, 这里采用四种排序方式来进行储存: 小队模式(默认模式)/门派模式/自定义模式/角色模式(ID模式), 前三种方式可以在面板的TITLE条中进行快捷切换, 第四种是系统内部使用的
function RaidGridEx.ReloadEntireTeamInfo(bRedraw)
	local team = GetClientTeam()
	if not team then
		return
	end
	if bRedraw then
		RaidGridEx.frameSelf:Lookup("", "Text_Title"):SetText(RaidGridEx.szTitleText)
		if RaidGridEx.tRollQualityImage and RaidGridEx.tRollQualityImage[team.nRollQuality] then
			RaidGridEx.tRollQualityImage[team.nRollQuality]:SetAlpha(255)
		end
		if RaidGridEx.tLootModeImage and RaidGridEx.tLootModeImage[team.nLootMode] then
			RaidGridEx.tLootModeImage[team.nLootMode]:SetAlpha(255)
		end
	end

	RaidGridEx.tGroupList = {}
	RaidGridEx.tForceList = {}
	--RaidGridEx.tCustomList = {}
	RaidGridEx.tRoleIDList = {}
	
	if GetClientPlayer().IsInParty() then
		for nGroupIndex = 0, math.min(4, team.nGroupNum - 1) do
			local tGroupInfo = team.GetGroupInfo(nGroupIndex)
			if tGroupInfo then
				RaidGridEx.tGroupList[nGroupIndex] = RaidGridEx.tGroupList[nGroupIndex] or {}		
				for nSortIndex = 1, #tGroupInfo.MemberList do
					local dwMemberID = tGroupInfo.MemberList[nSortIndex]
					RaidGridEx.OnMemberJoinTeam(dwMemberID, nGroupIndex)
					
					if bRedraw then
						RaidGridEx.ShowRoleHandle(nGroupIndex, nSortIndex)
						RaidGridEx.RedrawMemberHandleHPnMP(dwMemberID)
						RaidGridEx.RedrawMemberHandleState(dwMemberID)
						RaidGridEx.UpdateMemberSpecialState(dwMemberID)
					end
				end
			end
		end
	end
end

-- On PARTY_SYNC_MEMBER_DATA / PARTY_ADD_MEMBER [dwMemberID:arg1, nGroupIndex:arg2]
-- 当队伍有新队员进入的时候触发事件
function RaidGridEx.OnMemberJoinTeam(dwMemberID, nGroupIndex)
	local team = GetClientTeam()
	if not team then
		return
	end
	
	local tMemberInfo = team.GetMemberInfo(dwMemberID)
	if tMemberInfo then
		RaidGridEx.tForceList[tMemberInfo.dwForceID] = RaidGridEx.tForceList[tMemberInfo.dwForceID] or {}
		table.insert(RaidGridEx.tGroupList[nGroupIndex], dwMemberID)				-- 保存到小队列表数据
		table.insert(RaidGridEx.tForceList[tMemberInfo.dwForceID], dwMemberID)		-- 保存到门派列表数据
		RaidGridEx.tRoleIDList[dwMemberID] = dwMemberID								-- 保存到角色模式
	end
end

function RaidGridEx.GetBuffList(obj)
	local aBuffTable = {}

	local nCount = obj.GetBuffCount()
	for i=1,nCount,1 do
		local dwID, nLevel, bCanCancel, nEndFrame, nIndex, nStackNum, dwSkillSrcID, bValid = obj.GetBuff(i - 1)
		if dwID then
			table.insert(aBuffTable,{dwID = dwID, nLevel = nLevel, bCanCancel = bCanCancel, nEndFrame = nEndFrame, nIndex = nIndex, nStackNum = nStackNum, dwSkillSrcID = dwSkillSrcID, bValid = bValid})
		end
	end

	return aBuffTable
end


-- On BUFF_UPDATE [dwMemberID:arg0, bIsRemoved:arg1, nIndex:arg2, dwBuffID:arg4, nStackNum:arg5, nEndFrame:arg6, nLevel:arg8, dwSrcID:arg9]
-- 这里接收和更改BUFF监视的数据
function RaidGridEx.OnUpdateBuffData(dwMemberID, bIsRemoved, nIndex, dwBuffID, nStackNum, nEndFrame, nLevel)
	if nLevel <= 0 then
		return
	end
	
	local member = GetPlayer(dwMemberID)
	if not member then
		return
	end
	
	local tBuffList = RaidGridEx.GetBuffList(member)	
	if not tBuffList then
		return
	end
	
	local szBuffName = Table_GetBuffName(dwBuffID, nLevel)
	if not szBuffName or szBuffName == "" then
		return
	end

	local handleRole = RaidGridEx.GetRoleHandleByID(dwMemberID)
	if not handleRole.tBoxes then
		RaidGridEx.UpdateMemberBuff(dwMemberID)
	end
	
	local tBoxes = handleRole.tBoxes
	
	-- 如果是删除, 则无条件删除
	if bIsRemoved then
		for i = 1, 4, 1 do
			local box = tBoxes[i]
			if box.szName == szBuffName then
				box.szName = nil
				box.nIconID = -1
				box.bShow = false
				box.nEndFrame = 0
				box.nRate = 9999
				box.szColor = nil
				box.nAlpha = RaidGridEx.nBuffFlashAlpha
				box.nTrend = 1
				box:ClearObjectIcon()
				local shadow = handleRole:Lookup("Shadow_Color")
				shadow:Hide()
			end
		end
		return
	end
	
	-- 如果是添加, 则看是否在关注列表中
	local tSplitTextTable = DebuffSettingPanel.FormatDebuffNameList()
	if RaidGridEx.SearchBuffNameInTable(szBuffName,tSplitTextTable) ~= "" then
		szBuffName = RaidGridEx.SearchBuffNameInTable(szBuffName,tSplitTextTable)
	else
		return
	end
	
	local nRate = tSplitTextTable[szBuffName][1]
	local szColor = tSplitTextTable[szBuffName][2] or ""
	local tCurrentDebuff = {}
	local bInserted = false
	for i = 1, 4, 1 do
		local box = tBoxes[i]
		if box:IsVisible() then
			box.nRate = box.nRate or 9999
			if nRate < box.nRate and not bInserted then
				local nIconID = Table_GetBuffIconID(dwBuffID, nLevel)
				if nIconID then
					bInserted = true
					table.insert(tCurrentDebuff, {szName = szBuffName, nIconID = nIconID, bShow = true, nEndFrame = nEndFrame, nRate = nRate, szColor = szColor, nAlpha = RaidGridEx.nBuffFlashAlpha, nTrend = 1})
				end
			end
			if szBuffName ~= box.szName then
				table.insert(tCurrentDebuff, {szName = box.szName, nIconID = box.nIconID, bShow = box.bShow, nEndFrame = box.nEndFrame, nRate = box.nRate, szColor = box.szColor, nAlpha = box.nAlpha, nTrend = box.nTrend})
			end
		end
		--bInserted = false
	end
	
	if #tCurrentDebuff == 0 then
		local nIconID = Table_GetBuffIconID(dwBuffID, nLevel)
		if nIconID then
			table.insert(tCurrentDebuff, {szName = szBuffName, nIconID = nIconID, bShow = true, nEndFrame = nEndFrame, nRate = nRate, szColor = szColor, nAlpha = RaidGridEx.nBuffFlashAlpha, nTrend = 1})
		end
	end
	
	for i = 1, 4, 1 do
		if tCurrentDebuff[i] then
			tBoxes[i].szName = tCurrentDebuff[i].szName
			tBoxes[i].nIconID = tCurrentDebuff[i].nIconID
			tBoxes[i].bShow = tCurrentDebuff[i].bShow
			tBoxes[i].nEndFrame = tCurrentDebuff[i].nEndFrame
			tBoxes[i].nRate = tCurrentDebuff[i].nRate
			tBoxes[i].szColor = tCurrentDebuff[i].szColor
			tBoxes[i].nAlpha = tCurrentDebuff[i].nAlpha
			tBoxes[i].nTrend = tCurrentDebuff[i].nTrend
			tBoxes[i]:ClearObjectIcon()
			tBoxes[i]:SetObjectIcon(tBoxes[i].nIconID)
			
			local shadow = handleRole:Lookup("Shadow_Color")
			if shadow and (shadow.nEndFrame == 0 or tBoxes[i].nRate < shadow.nRate) then
				local tColor = DebuffSettingPanel.tColorCover[tBoxes[i].szColor]
				local r, g, b, a = 255, 255, 255, 0
				if tColor then
					r, g, b, a = tColor[1], tColor[2], tColor[3], RaidGridEx.nBuffCoverAlpha
				end
				shadow:SetTriangleFan(true)
				shadow:ClearTriangleFanPoint()
				shadow:AppendTriangleFanPoint(0, 0, r, g, b, a)
				shadow:AppendTriangleFanPoint(0, 34, r, g, b, a)
				shadow:AppendTriangleFanPoint(56, 34, r, g, b, a)
				shadow:AppendTriangleFanPoint(56, 0, r, g, b, a)
				shadow:Scale(RaidGridEx.fScale,RaidGridEx.fScale)
				shadow:Show()
				shadow.nEndFrame = tBoxes[i].nEndFrame or 0
				shadow.nRate = tBoxes[i].nRate
			end
		else
			tBoxes[i].szName = nil
			tBoxes[i].nIconID = -1
			tBoxes[i].bShow = false
			tBoxes[i].nEndFrame = 0
			tBoxes[i].nRate = 9999
			tBoxes[i].szColor = nil
			tBoxes[i].nAlpha = RaidGridEx.nBuffFlashAlpha
			tBoxes[i].nTrend = 1
			tBoxes[i]:ClearObjectIcon()
		end
	end
end

-- On TEAM_CHANGE_MEMBER_GROUP [dwSrcMember:arg0, nSrcGroup:arg1, dwDesMember:arg3, nDesGroup:arg2]
-- 参数表示了改变前的源与目标的情况, dwDesMember 为 0 表示将源移动而不是交换
-- 当队长把玩家换队伍后触发事件, 这里的参数表示的位置是改动前的
function RaidGridEx.OnMemberChangeGroup(dwSrcMember, nSrcGroup, dwDesMember, nDesGroup)
	RaidGridEx.CreateAllRoleHandle()
	RaidGridEx.ReloadEntireTeamInfo(true)
	RaidGridEx.AutoScalePanel()
	RaidGridEx.EnableRaidPanel()
end

-- ----------------------------------------------------------------------------------------------------------
-- 本地缓存数据访问: 
-- ----------------------------------------------------------------------------------------------------------
-- 获取团长 ID
function RaidGridEx.GetLeader()
	local team = GetClientTeam()
	if not team then
		return
	end
	return team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER)
end

-- 判断玩家是否是团队队长
function RaidGridEx.IsLeader(dwMemberID)
	return dwMemberID == RaidGridEx.GetLeader()
end

-- 获取阵眼 ID
function RaidGridEx.GetMatrixcore(nGroupIndex)
	local team = GetClientTeam()
	if not team then
		return
	end
	if GetClientPlayer().IsInParty() then
		local tGroupInfo = team.GetGroupInfo(nGroupIndex)
		if tGroupInfo and tGroupInfo.MemberList and #tGroupInfo.MemberList > 0 then
			return tGroupInfo.dwFormationLeader
		end
	end
end

-- 判断玩家是否是阵眼
function RaidGridEx.IsMatrixcore(dwMemberID)
	local team = GetClientTeam()
	if not team then
		return
	end
	if GetClientPlayer().IsInParty() then
		for i = 0, math.min(4, team.nGroupNum - 1) do
			local tGroupInfo = team.GetGroupInfo(i)
			if tGroupInfo and tGroupInfo.MemberList and #tGroupInfo.MemberList > 0 and tGroupInfo.dwFormationLeader == dwMemberID then
				return true
			end
		end
	end
	return false
end

-- 获取拾取者 ID
function RaidGridEx.GetLooter()
	local team = GetClientTeam()
	if not team then
		return
	end
	return team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE)
end

-- 判断玩家是否拾取者
function RaidGridEx.IsLooter(dwMemberID)
	return dwMemberID == RaidGridEx.GetLooter()
end

-- 获取标记者 ID
function RaidGridEx.GetMarker()
	local team = GetClientTeam()
	if not team then
		return
	end
	return team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK)
end

-- 判断玩家是否标记者
function RaidGridEx.IsMarker(dwMemberID)
	return dwMemberID == RaidGridEx.GetMarker()
end

-- 获取拾取模式和品质
function RaidGridEx.GetLootModenQuality()
	local team = GetClientTeam()
	if not team then
		return
	end
	return team.nLootMode, team.nRollQuality
end

-- 通过 ID 获取一个队友, 这不是一个对象, 而是特征数据的集合表
function RaidGridEx.GetTeamMemberInfo(dwMemberID)
	local player = GetClientPlayer()
	if not player then return end
	local team = GetClientTeam()
	if not team then return end
	local member = team.GetMemberInfo(dwMemberID)
	if not member then
		return
	end
	member.nX = member.nPosX
	member.nY = member.nPosY
	return member
end

-- 获取角色在表中的排列序号: nSortIndex
-- nTypeIndex: 在 tGroupMode 中表示小队ID, 在 tForceMode 中表示势力(门派)ID
function RaidGridEx.GetSortIndex(tTeamInfoSubTable, nTypeIndex, dwMemberID)
	local tInfo = tTeamInfoSubTable[nTypeIndex]
	if not tInfo then
		return
	end
	for i = 1, #tInfo do
		if tInfo[i] and tInfo[i] == dwMemberID then
			return i
		end
	end
end

-- 取得角色所在的小队的序号
function RaidGridEx.GetGroupIndex(dwMemberID)
	local team = GetClientTeam()
	return team.GetMemberGroupIndex(dwMemberID)
end

-- 获取鼠标位置在哪个小队范围内
function RaidGridEx.GetMouseGroupIndex()
	local nX = RaidGridEx.frameSelf:GetAbsPos()
	local nMouseX = Cursor.GetPos()
	for i = 0, 4, 1 do
		if nMouseX <= nX + (i + 1) * RaidGridEx.nColLength then
			return i
		end
	end
	return 4
end

-- 模糊匹配Buff名称
function RaidGridEx.SearchBuffNameInTable(szBuffName,tSplitTextTable)
	for k,v in pairs(tSplitTextTable) do
		if string.find(tostring(szBuffName),tostring(k)) then
			return tostring(k)
		end
	end
	return ""
end

-- ----------------------------------------------------------------------------------------------------------
-- 其他: 
-- ----------------------------------------------------------------------------------------------------------
function RaidGridEx.Message(szMessage)
	OutputMessage("MSG_SYS", "[RaidGridEx] " .. tostring(szMessage) .. "\n")
end

function RaidGridEx.GetCharacterColor(dwCharacterID, dwForceID)
	local player = GetClientPlayer()
	if not player then
		return 128, 128, 128
	end
	if not IsPlayer(dwCharacterID) then
		return 168, 168, 168
	end
	
	if not dwForceID then
		local target = GetPlayer(dwCharacterID)
		if not target then
			return 128, 128, 128
		end
		
		dwForceID = target.dwForceID
		if not dwForceID then
			return 168, 168, 168
		end
	end
	return JH.GetForceColor(dwForceID)
end

function RaidGridEx.GetKungfuByID(dwMemberID)
	local tMemberInfo = RaidGridEx.GetTeamMemberInfo(dwMemberID)
	local dwKungfuID = tMemberInfo.dwMountKungfuID
	if not dwKungfuID then return {"侠",255,255,255,10000}
	elseif dwKungfuID == 10080 then return {"云",255,129,176,dwKungfuID}
	elseif dwKungfuID == 10081 then return {"冰",255,129,176,dwKungfuID}
	elseif dwKungfuID == 10021 then return {"花",196,152,255,dwKungfuID}
	elseif dwKungfuID == 10028 then return {"离",196,152,255,dwKungfuID}
	elseif dwKungfuID == 10026 then return {"傲",255,111,83,dwKungfuID}
	elseif dwKungfuID == 10062 then return {"铁",255,111,83,dwKungfuID}
	elseif dwKungfuID == 10002 then return {"洗",255,178,95,dwKungfuID}
	elseif dwKungfuID == 10003 then return {"易",255,178,95,dwKungfuID}
	elseif dwKungfuID == 10014 then return {"气",89,224,232,dwKungfuID}
	elseif dwKungfuID == 10015 then return {"剑",89,224,232,dwKungfuID}
	elseif dwKungfuID == 10144 then return {"问",214,249,93,dwKungfuID}
	elseif dwKungfuID == 10145 then return {"山",214,249,93,dwKungfuID}
	elseif dwKungfuID == 10175 then return {"毒",55,147,255,dwKungfuID}
	elseif dwKungfuID == 10176 then return {"补",55,147,255,dwKungfuID}
	elseif dwKungfuID == 10224 then return {"羽",121,183,54,dwKungfuID}
	elseif dwKungfuID == 10225 then return {"诡",121,183,54,dwKungfuID}
	elseif dwKungfuID == 10242 then return {"焚",240,70,96,dwKungfuID}
	elseif dwKungfuID == 10243 then return {"尊",240,70,96,dwKungfuID}
	elseif dwKungfuID == 10268 then return {"丐",205,133,63,dwKungfuID}
	elseif dwKungfuID == 10390 then return {"分",180,60,0,dwKungfuID}
	elseif dwKungfuID == 10389 then return {"衣",180,60,0,dwKungfuID}
	else return {"unknown",255,255,255,dwKungfuID}
	end
end


function RaidGridEx.SetPanelPos(nX, nY)
	local frame = Station.Lookup("Normal/RaidGridEx")
	if not frame then
		frame = Wnd.OpenWindow("Interface\\JH\\RaidGridEx\\RaidGridEx.ini", "RaidGridEx")
	end
	if not nX or not nY then
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	else
		local nW, nH = Station.GetClientSize(true)
		if nX < 0 then nX = 0 end
		if nX > nW - 100 then nX = nW - 100 end
		if nY < 0 then nY = 0 end
		if nY > nH - 100 then nY = nH - 100 end
		frame:SetRelPos(nX, nY)
	end
	RaidGridEx.tLastLoc.nX, RaidGridEx.tLastLoc.nY = frame:GetRelPos()
end

function RaidGridEx.ChangeReadyConfirm(dwMemberID, nReadyState)
	local handleRole = RaidGridEx.GetRoleHandleByID(dwMemberID)
	local imgReadyCheck = handleRole:Lookup("Image_ReadyCheck")
	local imgReadyCheckNo = handleRole:Lookup("Image_ReadyCheck_No")
	if nReadyState == 1 then
		imgReadyCheck:Hide()
	elseif nReadyState == 2 then
		imgReadyCheckNo:Show()
	end	
end