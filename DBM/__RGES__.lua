-- @Author: Webster
-- @Date:   2015-05-23 06:20:42
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-23 20:34:01


function RGESToDBM(szPath)
	local __data__ = LoadLUAData(szPath)
	local me = GetClientPlayer()
	local nTime = GetTime()
	if not __data__ then
		return JH.Alert("文件不存在或数据文件错误，请仔细检查路径格式，是否以interface开头。")
	end
	local data = {
		CIRCLE = {},
		BUFF = {},
		DEBUFF = {},
		CASTING = {},
		NPC = {},
		TALK = {}
	}
	-- 画圈圈数据 不需要转换
	if __data__.Circle then
		data["CIRCLE"] = __data__.Circle
		JH.Sysmsg("成功转换画圈圈数据(其实这个不用转) sort:" .. GetTime() - nTime .. "ms")
	end
	nTime = GetTime()
	if __data__.EventScrutinyRecords then
		for k = #__data__.EventScrutinyRecords.Buff, 1, -1 do
			local v = __data__.EventScrutinyRecords.Buff[k]
			local dat = {
				dwID = v.dwID,
				nLevel = v.nLevel,
			}
			local dwType = DBM_TYPE.BUFF_GET
			if not v.bNotAddToCTM then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bTeamPanel = true
			end
			if v.bPartyBuffList then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bPartyBuffList = true
			end
			if not v.bNotAddSelfBuffAlert then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bBuffList = true
			end
			if v.bChatAlertW then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bWhisperChannel = true
			end
			if v.bChatAlertT then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bTeamChannel = true
			end
			if v.bBigFontAlarm then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bBigFontAlarm = true
			end
			if v.bScreenHead then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bScreenHead = true
			end
			if v.bFullScreenAlert then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bFullScreen = true
			end
			if v.tRGCenterAlarm then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bCenterAlarm = true
			end
			if v.bOnlySelfSrcAddCTM then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bOnlySelfSrc = true
			end
			if v.bAlwaysCheckLevel then
				dat.bCheckLevel = true
			end
			if v.nEventAlertStackNum and v.nEventAlertStackNum ~= 1 then
				dat.nCount = v.nEventAlertStackNum
			end
			if v.tAutoTeamMark then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].tMark = { false, false, false, false, false, false, false, false, false, false }
				dat[dwType].tMark[v.tAutoTeamMark] = true
			end
			if v.nRelScrutinyType == 1 then
				dat.nScrutinyType = DBM_SCRUTINY_TYPE.SELF
			elseif v.nRelScrutinyType == 2 then
				dat.nScrutinyType = DBM_SCRUTINY_TYPE.TEAM
			elseif v.nRelScrutinyType == -1 then
				dat.nRelScrutinyType = DBM_SCRUTINY_TYPE.ENEMY
			end
			local szName, nIcon = JH.GetBuffName(v.dwID, v.nLevel)
			if v.nIconID ~= nIcon then
				dat.nIcon = v.nIconID
			end
			if v.szName ~= szName then
				dat.szName = v.szName
			end
			if v.tRGBuffColor then
				dat.col = { v.tRGBuffColor[1], v.tRGBuffColor[2], v.tRGBuffColor[3] }
			end
			if v.tAlarmAddInfo and JH.Trim(v.tAlarmAddInfo) ~= "" then
				dat.szNote = v.tAlarmAddInfo
			end
			if v.bSkillTimer2Enable and v.nSkillTimer2 and v.nSkillTimer2 ~= 0 then
				dat.tCountdown = {}
				table.insert(dat.tCountdown, {
					nIcon = nIcon,
					nClass = DBM_TYPE.BUFF_GET,
					nTime = v.nSkillTimer2,
					szName = v.szSkillName2 or szName,
					nRefresh = 7
				})
			end
			data["BUFF"][-1] = data["BUFF"][-1] or {}
			table.insert(data["BUFF"][-1], dat)
		end
		JH.Sysmsg("BUFF 数据转换成功 sort:" .. GetTime() - nTime .. "ms")
		nTime = GetTime()
		for k = #__data__.EventScrutinyRecords.Debuff, 1, -1 do
			local v = __data__.EventScrutinyRecords.Debuff[k]
			local dat = {
				dwID = v.dwID,
				nLevel = v.nLevel,
			}
			local dwType = DBM_TYPE.BUFF_GET
			if not v.bNotAddToCTM then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bTeamPanel = true
			end
			if v.bPartyBuffList then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bPartyBuffList = true
			end
			if not v.bNotAddSelfBuffAlert then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bBuffList = true
			end
			if v.bChatAlertW then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bWhisperChannel = true
			end
			if v.bChatAlertT then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bTeamChannel = true
			end
			if v.bBigFontAlarm then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bBigFontAlarm = true
			end
			if v.bScreenHead then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bScreenHead = true
			end
			if v.bFullScreenAlert then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bFullScreen = true
			end
			if v.tRGCenterAlarm then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bCenterAlarm = true
			end
			if v.bOnlySelfSrcAddCTM then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bOnlySelfSrc = true
			end
			if v.bAlwaysCheckLevel then
				dat.bCheckLevel = true
			end
			if v.nEventAlertStackNum and v.nEventAlertStackNum ~= 1 then
				dat.nCount = v.nEventAlertStackNum
			end
			if v.tAutoTeamMark then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].tMark = { false, false, false, false, false, false, false, false, false, false }
				dat[dwType].tMark[v.tAutoTeamMark] = true
			end
			if v.nRelScrutinyType == 1 then
				dat.nScrutinyType = DBM_SCRUTINY_TYPE.SELF
			elseif v.nRelScrutinyType == 2 then
				dat.nScrutinyType = DBM_SCRUTINY_TYPE.TEAM
			elseif v.nRelScrutinyType == -1 then
				dat.nRelScrutinyType = DBM_SCRUTINY_TYPE.ENEMY
			end
			local szName, nIcon = JH.GetBuffName(v.dwID, v.nLevel)
			if v.nIconID ~= nIcon then
				dat.nIcon = v.nIconID
			end
			if v.szName ~= szName then
				dat.szName = v.szName
			end
			if v.tRGBuffColor then
				dat.col = { v.tRGBuffColor[1], v.tRGBuffColor[2], v.tRGBuffColor[3] }
			end
			if v.tAlarmAddInfo and JH.Trim(v.tAlarmAddInfo) ~= "" then
				dat.szNote = v.tAlarmAddInfo
			end
			if v.bSkillTimer2Enable and v.nSkillTimer2 and v.nSkillTimer2 ~= 0 then
				dat.tCountdown = {}
				table.insert(dat.tCountdown, {
					nIcon = nIcon,
					nClass = DBM_TYPE.BUFF_GET,
					nTime = v.nSkillTimer2,
					szName = v.szSkillName2 or szName,
					nRefresh = 7
				})
			end
			data["DEBUFF"][-1] = data["DEBUFF"][-1] or {}
			table.insert(data["DEBUFF"][-1], dat)
		end
		JH.Sysmsg("DEBUFF 数据转换成功 sort:" .. GetTime() - nTime .. "ms")
		nTime = GetTime()
		for k = #__data__.EventScrutinyRecords.Casting, 1, -1 do
			local v = __data__.EventScrutinyRecords.Casting[k]
			local dat = {
				dwID = v.dwID,
				nLevel = v.nLevel,
			}
			local tRecipeKey = me.GetSkillRecipeKey(v.dwID, v.nLevel)
			tSkillInfo = GetSkillInfo(tRecipeKey)
			local dwType = DBM_TYPE.SKILL_END
			if tSkillInfo and tSkillInfo.CastTime ~= 0 then
				dwType = DBM_TYPE.SKILL_BEGIN
			end
			if v.bChatAlertW then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bWhisperChannel = true
			end
			if v.bChatAlertT then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bTeamChannel = true
			end
			if v.bBigFontAlarm then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bBigFontAlarm = true
			end
			if v.bScreenHead then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bScreenHead = true
			end
			if v.bFullScreenAlert then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bFullScreen = true
			end
			if v.tRGCenterAlarm then
				dat[dwType] = dat[dwType] or {}
				dat[dwType].bCenterAlarm = true
			end
			if v.bAlwaysCheckLevel then
				dat.bCheckLevel = true
			end
			if v.nRelScrutinyType == 1 then
				dat.nScrutinyType = DBM_SCRUTINY_TYPE.SELF
			elseif v.nRelScrutinyType == 2 then
				dat.nScrutinyType = DBM_SCRUTINY_TYPE.TEAM
			elseif v.nRelScrutinyType == -1 then
				dat.nRelScrutinyType = DBM_SCRUTINY_TYPE.ENEMY
			end
			local szName, nIcon = JH.GetSkillName(v.dwID, v.nLevel)
			if v.nIconID ~= nIcon then
				dat.nIcon = v.nIconID
			end
			if v.szName ~= szName then
				dat.szName = v.szName
			end
			if v.tRGBuffColor then
				dat.col = { v.tRGBuffColor[1], v.tRGBuffColor[2], v.tRGBuffColor[3] }
			end
			if v.tAlarmAddInfo and JH.Trim(v.tAlarmAddInfo) ~= "" then
				dat.szNote = v.tAlarmAddInfo
			end

			if v.bSkillTimer2Enable and v.nSkillTimer2 and v.nSkillTimer2 ~= 0 then
				dat.tCountdown = dat.tCountdown or {}
				table.insert(dat.tCountdown, {
					nIcon = nIcon,
					nClass = dwType,
					nTime = v.nSkillTimer2,
					szName = v.szSkillName2 or szName,
					nRefresh = 7
				})
			end
			if v.bAddToSkillTimer and v.nEventAlertTime then
				dat.tCountdown = dat.tCountdown or {}
				table.insert(dat.tCountdown, {
					nIcon = nIcon,
					nClass = dwType,
					nTime = v.nEventAlertTime,
					szName = szName,
					nRefresh = 7
				})
			end
			if v.szTimerSet then
				dat.tCountdown = dat.tCountdown or {}
				table.insert(dat.tCountdown, {
					nIcon = nIcon,
					nClass = dwType,
					nTime = v.szTimerSet,
				})
			end
			data["CASTING"][-1] = data["CASTING"][-1] or {}
			table.insert(data["CASTING"][-1], dat)
		end
		JH.Sysmsg("技能数据转换成功 sort:" .. GetTime() - nTime .. "ms")
		nTime = GetTime()
		for k = #__data__.EventScrutinyRecords.Npc, 1, -1 do
			local v = __data__.EventScrutinyRecords.Npc[k]
			local dat = {
				dwID = v.dwID,
				nLevel = v.nLevel,
			}

			if v.nEventAlertCount and v.nEventAlertCount ~= 1 then
				dat.nCount = v.nEventAlertCount
			end
			local dwType = DBM_TYPE.NPC_ENTER
			if not v.bNotAppearScrutiny then
				if v.bChatAlertW then
					dat[dwType] = dat[dwType] or {}
					dat[dwType].bWhisperChannel = true
				end
				if v.bChatAlertT then
					dat[dwType] = dat[dwType] or {}
					dat[dwType].bTeamChannel = true
				end
				if v.bBigFontAlarm then
					dat[dwType] = dat[dwType] or {}
					dat[dwType].bBigFontAlarm = true
				end
				if v.bScreenHead then
					dat[dwType] = dat[dwType] or {}
					dat[dwType].bScreenHead = true
				end
				if v.bFullScreenAlert then
					dat[dwType] = dat[dwType] or {}
					dat[dwType].bFullScreen = true
				end
				if v.tRGCenterAlarm then
					dat[dwType] = dat[dwType] or {}
					dat[dwType].bCenterAlarm = true
				end
				if v.tAutoTeamMark then
					dat[dwType] = dat[dwType] or {}
					dat[dwType].tMark = { false, false, false, false, false, false, false, false, false, false }
					dat[dwType].tMark[v.tAutoTeamMark] = true
				end
				if v.bAutoTeamMarkAll then
					dat[dwType] = dat[dwType] or {}
					dat[dwType].tMark = { true, true, true, true, true, true, true, true, true, true }
				end
			else
				dwType = DBM_TYPE.NPC_FIGHT
			end
			if v.bNpcLeaveScrutiny then
				local a = DBM_TYPE.NPC_LEAVE
				if v.bNpcAllLeave then
					a = DBM_TYPE.NPC_ALLLEAVE
				end
				if v.bChatAlertW then
					dat[a] = dat[a] or {}
					dat[a].bWhisperChannel = true
				end
				if v.bChatAlertT then
					dat[a] = dat[a] or {}
					dat[a].bTeamChannel = true
				end
				if v.bBigFontAlarm then
					dat[a] = dat[a] or {}
					dat[a].bBigFontAlarm = true
				end
				if v.tRGCenterAlarm then
					dat[a] = dat[a] or {}
					dat[a].bCenterAlarm = true
				end
			end
			local szName = Table_GetNpcTemplateName(v.dwID)
			if JH.Trim(szName) == "" then
				szName = tostring(v.dwID)
			end
			dat.nFrame = v.nIconFrame
			if v.szName ~= szName then
				if not tonumber(szName) then
					dat.szName = v.szName
				end
			end
			if v.tRGBuffColor then
				dat.col = { v.tRGBuffColor[1], v.tRGBuffColor[2], v.tRGBuffColor[3] }
			end
			if v.tAlarmAddInfo and JH.Trim(v.tAlarmAddInfo) ~= "" then
				dat.szNote = v.tAlarmAddInfo
			end

			if v.bSkillTimer2Enable and v.nSkillTimer2 and v.nSkillTimer2 ~= 0 then
				dat.tCountdown = dat.tCountdown or {}
				table.insert(dat.tCountdown, {
					nIcon = nIcon,
					nClass = dwType,
					nTime = v.nSkillTimer2,
					szName = v.szSkillName2 or szName,
					nRefresh = 7
				})
			end
			if v.bAddToSkillTimer and v.nEventAlertTime then
				dat.tCountdown = dat.tCountdown or {}
				table.insert(dat.tCountdown, {
					nIcon = nIcon,
					nClass = dwType,
					nTime = v.nEventAlertTime,
					szName = szName,
					nRefresh = 7
				})
			end
			if v.szTimerSet then
				dat.tCountdown = dat.tCountdown or {}
				table.insert(dat.tCountdown, {
					nIcon = 346,
					nClass = dwType,
					nTime = v.szTimerSet,
				})
			end
			if v.szNpcLife then
				dat.tCountdown = dat.tCountdown or {}
				table.insert(dat.tCountdown, {
					nIcon = 346,
					nClass = DBM_TYPE.NPC_LIFE,
					nTime = v.szNpcLife,
				})
			end
			data["NPC"][-1] = data["NPC"][-1] or {}
			table.insert(data["NPC"][-1], dat)
		end
		JH.Sysmsg("NPC数据转换成功 sort:" .. GetTime() - nTime .. "ms")
		nTime = GetTime()

		if __data__.BossCallAlertRecords then
			for k, v in ipairs(__data__.BossCallAlertRecords.tWarningMessages) do
				if v.bOn then
					local dat = {
						szContent = v.szText,
						szNote = v.szName
					}
					local dwType = DBM_TYPE.TALK_MONITOR
					if v.bCenterAlarm then
						dat[dwType] = dat[dwType] or {}
						dat[dwType].bCenterAlarm = true
					end
					if v.bFlash then
						dat[dwType] = dat[dwType] or {}
						dat[dwType].bFullScreen = true
					end
					if v.bWHISPER then
						dat[dwType] = dat[dwType] or {}
						dat[dwType].bWhisperChannel = true
					end
					if v.bRAID then
						dat[dwType] = dat[dwType] or {}
						dat[dwType].bTeamChannel = true
					end
					if v.nTime1 and v.nTime1 ~= 0 then
						dat.tCountdown = dat.tCountdown or {}
						table.insert(dat.tCountdown, {
							nIcon = 340,
							nClass = dwType,
							nTime = v.nTime1,
							szName = v.szName,
						})
					end
					if v.szName2 and v.nTime2 and v.nTime2 ~= 0 then
						dat.tCountdown = dat.tCountdown or {}
						table.insert(dat.tCountdown, {
							nIcon = 340,
							nClass = dwType,
							nTime = v.nTime2,
							szName = v.szName2 or v.szName,
						})
					end
					data["TALK"][-1] = data["TALK"][-1] or {}
					table.insert(data["TALK"][-1], dat)
				end
			end
			for k, v in ipairs(__data__.BossCallAlertRecords.tBossCall) do
				if v.bOn then
					local dat = {
						szContent = v.szText,
						szNote = v.szName,
						szTarget = v.szBossName
					}
					local dwType = DBM_TYPE.TALK_MONITOR
					if v.bCenterAlarm then
						dat[dwType] = dat[dwType] or {}
						dat[dwType].bCenterAlarm = true
					end
					if v.bFlash then
						dat[dwType] = dat[dwType] or {}
						dat[dwType].bFullScreen = true
					end
					if v.bWHISPER then
						dat[dwType] = dat[dwType] or {}
						dat[dwType].bWhisperChannel = true
					end
					if v.bRAID then
						dat[dwType] = dat[dwType] or {}
						dat[dwType].bTeamChannel = true
					end
					if v.nTime1 and v.nTime1 ~= 0 then
						dat.tCountdown = dat.tCountdown or {}
						table.insert(dat.tCountdown, {
							nIcon = 340,
							nClass = dwType,
							nTime = v.nTime1,
							szName = v.szName,
						})
					end
					if v.szName2 and v.nTime2 and v.nTime2 ~= 0 then
						dat.tCountdown = dat.tCountdown or {}
						table.insert(dat.tCountdown, {
							nIcon = 340,
							nClass = dwType,
							nTime = v.nTime2,
							szName = v.szName2 or v.szName,
						})
					end
					data["TALK"][-1] = data["TALK"][-1] or {}
					table.insert(data["TALK"][-1], dat)
				end
			end
			JH.Sysmsg("喊话数据转换成功 sort:" .. GetTime() - nTime .. "ms")
		end
	end
	JH.Sysmsg("所有数据转换成功，文件已经导出到interface/data.jx3dat，请自取。")
	SaveLUAData("interface/data.jx3dat", data, "\t")
end
