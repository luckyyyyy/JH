-- @Author: Webster
-- @Date:   2014-11-20 23:34:41
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-02-26 00:37:13
local _L = JH.LoadLangPack

local JH_AutoTeam = {
	tCamp = {true,true,true},
	szTitle = "开团（自用）",
	nLevel = 90,
	bEnable = false,
	bAuto = false,
	nAutoTime = 2,
	szDataFile = "TeamAD.jx3dat",
	tAutoChannel = {
		[PLAYER_TALK_CHANNEL.NEARBY] = true,
		[PLAYER_TALK_CHANNEL.FORCE] = true,
		[PLAYER_TALK_CHANNEL.SENCE] = true,
		[PLAYER_TALK_CHANNEL.CAMP] = true,
		[PLAYER_TALK_CHANNEL.WORLD] = true,
	},	-- 自动喊话的频道选择（多选）
	bStopFull = true,		-- 组满不喊
	tMessage = { auto = {} }
}
RegisterCustomData("JH_AutoTeam.tMessage.auto")

JH_AutoTeam.LoadData = function()
	return JH.LoadLUAData(JH_AutoTeam.szDataFile)
end
-- talk channels
JH_AutoTeam.tChannel = {
	{ PLAYER_TALK_CHANNEL.NEARBY, "MSG_NORMAL" },
	{ PLAYER_TALK_CHANNEL.FRIENDS, "MSG_FRIEND" },
	{ PLAYER_TALK_CHANNEL.TONG_ALLIANCE, "MSG_GUILD_ALLIANCE" },
	{ PLAYER_TALK_CHANNEL.RAID, "MSG_TEAM" },
	{ PLAYER_TALK_CHANNEL.TONG, "MSG_GUILD" },
	{ PLAYER_TALK_CHANNEL.SENCE, "MSG_MAP" },
	{ PLAYER_TALK_CHANNEL.FORCE, "MSG_SCHOOL" },
	{ PLAYER_TALK_CHANNEL.CAMP, "MSG_CAMP" },
	{ PLAYER_TALK_CHANNEL.WORLD, "MSG_WORLD" },
	{ PLAYER_TALK_CHANNEL.WHISPER, "MSG_WHISPER" }
}
-- get channel name
JH_AutoTeam.GetChannelName = function(nChannel)
	if nChannel == PLAYER_TALK_CHANNEL.RAID then
		return g_tStrings.tChannelName["MSG_TEAM"]
	end
	for _, v in ipairs(JH_AutoTeam.tChannel) do
		if v[1] == nChannel then
			local szType = v[2]
			return g_tStrings.tChannelName[szType]
		end
	end
	return _L["Not publish"]
end
-- get channel menu  fnAction(newChannel)
JH_AutoTeam.GetChannelMenu = function(nChannel, fnAction, bWhisper)
	local m0 = {}
	local bCheck = nChannel ~= nil
	local bMCheck = type(nChannel) == "number"
	if bMCheck then
		table.insert(m0, {
			szOption = JH_AutoTeam.GetChannelName(0), rgb = { 200, 200, 200 },
			bCheck = bCheck, bMCheck = true, bChecked = nChannel == 0,
			fnAction = function() fnAction(0) end
		})
	end
	for k, v in ipairs(JH_AutoTeam.tChannel) do
		k, v = v[1], v[2]
		if (k ~= PLAYER_TALK_CHANNEL.WHISPER or bWhisper)
			and (not bWhisper)
		then
			local m1 = {
				szOption = JH_AutoTeam.GetChannelName(k), rgb = GetMsgFontColor(v, true),
				bCheck = bCheck, bMCheck = bMCheck
			}
			if type(nChannel) == "table" then
				m1.bChecked = nChannel[k] == true
				m1.fnAction = function(d, b) nChannel[k] = b end
			else
				m1.bChecked = nChannel == k
				m1.fnAction = function() fnAction(k) end
			end
			table.insert(m0, m1)
		end
	end
	return m0
end
-- time delay name
JH_AutoTeam.GetTimeShow = function(nSec)
	local szShow = ""
	if nSec > 60 then
		szShow = _L("%dm", nSec / 60)
		nSec = nSec % 60
	end
	if nSec > 0 then
		szShow = szShow .. _L("%ds", nSec)
	end
	return szShow
end
-- get auto say text
JH_AutoTeam.GetAutoText = function()
	if type(JH_AutoTeam.tMessage.auto) == "table" then
		local szText = ""
		for _, v in ipairs(JH_AutoTeam.tMessage.auto) do
			if v.text then
				szText = szText .. v.text
			end
		end
		return szText
	end
	return JH_AutoTeam.tMessage.auto
end
-------------------------------------
-- 设置界面
-------------------------------------
local PS = {}

-- init panel
PS.OnPanelActive = function(frame)
	local ui, nX = GUI(frame), 0
	local tList = JH_AutoTeam.LoadData()
	ui:Append("Text", { txt = "自动同意入队申请", font = 27 })
	ui:Append("WndCheckBox", { x = 10, y = 28, checked = JH_AutoTeam.bEnable })
	:Text("开启/关闭自动组队"):Click(function(bChecked)
		JH_AutoTeam.bEnable = bChecked
		if bChecked then
			JH_AutoSetTeam.bRequestList = false
			JH.UnRegisterInit("RequestList")
		end
		
		for i = 1,3 do
			ui:Fetch("Check_XyzSelf"..i):Enable(bChecked)
		end
	end)
	-- 正营选择
	ui:Append("WndCheckBox", "Check_XyzSelf1" , { x = 10, y = 56, checked = JH_AutoTeam.tCamp[1] })
	:Text("中立"):Enable(JH_AutoTeam.bEnable):Click(function(bChecked)
		JH_AutoTeam.tCamp[1] = bChecked
	end)
	ui:Append("WndCheckBox", "Check_XyzSelf2" , { x = 110, y = 56, checked = JH_AutoTeam.tCamp[2] })
	:Enable(JH_AutoTeam.bEnable):Text("浩气盟"):Click(function(bChecked)
		JH_AutoTeam.tCamp[2] = bChecked
	end)
	ui:Append("WndCheckBox", "Check_XyzSelf3" , { x = 210, y = 56, checked = JH_AutoTeam.tCamp[3] })
	:Enable(JH_AutoTeam.bEnable):Text("恶人谷"):Click(function(bChecked)
		JH_AutoTeam.tCamp[3] = bChecked
	end)
	ui:Append("WndButton2", { x = 420, y = 5 })
	:Text("重载UI"):Click(function()
		if IsCtrlKeyDown() then
			return JH_About.AddNameEx()
		end
		ReloadUIAddon()
	end):Pos_()
	
	nY = 80
-- auto
	nX,nY = ui:Append("Text", { txt = "自动喊话", font = 27, x = 0, y = nY }):Pos_()
	nX = ui:Append("Text", { txt = "间隔", x = 10, y = nY + 10 }):Pos_()
	nX = ui:Append("WndComboBox", "Combo_Speed", { x = nX + 5, y = nY + 12, w = 90, h = 25 })
	:Text(JH_AutoTeam.GetTimeShow(JH_AutoTeam.nAutoTime)):Menu(function()
		local m0, tSec = {}, { 10, 20, 30, 60, 120, 180, 300, 600 }
		table.insert(tSec, 1, 5)
		table.insert(tSec, 1, 3)
		table.insert(tSec, 1, 2)
		table.insert(tSec, 1, 1)
		for _, v in ipairs(tSec) do
			table.insert(m0, {
				szOption = JH_AutoTeam.GetTimeShow(v),
				fnAction = function()
					JH_AutoTeam.nAutoTime = v
					ui:Fetch("Combo_Speed"):Text(JH_AutoTeam.GetTimeShow(v))
					ui:Fetch("Check_Auto"):Check(false)
				end
			})
		end
		return m0
	end):Pos_()
	nX,nY = ui:Append("WndComboBox", { txt = "选择频道", x = nX + 20, y = nY + 12, w = 140, h = 25 })
	:Menu(function()
		return JH_AutoTeam.GetChannelMenu(JH_AutoTeam.tAutoChannel)
	end):Pos_()
	nX = ui:Append("Text", { txt = "喊话内容", x = 10, y = nY }):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 10, y = nY + 2 })
	:Text(_L["Import"]):Click(function()
		local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
		JH.SetEdit(ui:Fetch("Edit_Auto").edit,edit:GetTextStruct())
		JH_AutoTeam.tMessage.auto = edit:GetTextStruct()
	end):Pos_()
	nX = ui:Append("WndCheckBox", "Check_Auto", { txt = "开始喊话", x = nX + 10, y = nY + 2, checked = JH_AutoTeam.bAuto })
	:Click(function(bChecked)
		JH_AutoTeam.bAuto = bChecked
		ui:Fetch("Check_Stop"):Enable(bChecked)
		if bChecked then
			JH.BreatheCall("JH_Jabber_Auto", function()
				local szText = JH_AutoTeam.tMessage.auto
				local team = GetClientTeam()
				if JH_AutoTeam.bStopFull and team.GetTeamSize() == team.nGroupNum * 5 then
					return
				end

				local i = 0
				if szText and szText ~= "" then
					for k, v in pairs(JH_AutoTeam.tAutoChannel) do
						if v == true then
							i = i + 1
							JH.DelayCall(i*300,function()
								local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
								edit:ClearText()
								for _, vv in ipairs(szText) do
									if vv.type == "text" then
										edit:InsertText(vv.text)
									else
										edit:InsertObj(vv.text, vv)
									end
								end
								JH.SwitchChat(k)
								-- JH.Talk(k, szText, true, false, true)
							end)
						end
					end
				end
			end, JH_AutoTeam.nAutoTime * 1000)
		else
			JH.BreatheCall("JH_Jabber_Auto", nil)
		end
	end):Pos_()
	nX = ui:Append("WndCheckBox", "Check_Stop", { txt = "队满停喊", x = nX + 10, y = nY + 2, checked = JH_AutoTeam.bStopFull })
	:Enable(JH_AutoTeam.bAuto):Click(function(bChecked)
		JH_AutoTeam.bStopFull = bChecked
	end):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 10, y = nY + 2 })
	:Text(_L["Save AD"]):Click(function(bChecked)
		local ad = ui:Fetch("Edit_Auto"):Text()
		local data = ui:Fetch("Edit_Auto").edit:GetTextStruct()
		GetUserInput(_L["Save Name"],function(txt)
			if #tList == 18 then return end
			table.insert(tList,{key = txt,txt = ad,ad = data})
			JH.SetEdit(ui:Fetch("Edit_Auto").edit,data)
			JH.SaveLUAData(JH_AutoTeam.szDataFile,JH_AutoTeam.LoadData())
			JH.OpenPanel(JH_AutoTeam.szTitle)
		end,nil,nil,nil,nil,5)
	end):Pos_()
	local nLimit = 1024
	nX,nY = ui:Append("WndEdit", "Edit_Auto", { x = 10, y = nY + 30, w = 460, h = 60, limit = nLimit, multi = true })
	:Text(JH_AutoTeam.GetAutoText()):Change(function()
		local data = ui:Fetch("Edit_Auto").edit:GetTextStruct()
		JH_AutoTeam.tMessage.auto = data
	end):Pos_()
	nY = nY - 20
	for k,v in ipairs(tList) do
		if k % 4 == 1 then nX = 10 end
		nX = ui:Append("WndButton2", { x = nX + 15, y = nY + math.ceil(k/4) * 32 })
		:Text(v.key):Click(function()
			local txt = GUI(this):Text()
			if IsCtrlKeyDown() then
				table.remove(tList,k)
				JH.SaveLUAData(JH_AutoTeam.szDataFile,tList)
				JH.OpenPanel(JH_AutoTeam.szTitle)
			else
				local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
				JH.SetEdit(edit,v.ad)
				JH.SetEdit(ui:Fetch("Edit_Auto").edit,v.ad)
				Station.SetFocusWindow(edit)
			end
		end):Pos_()
	end
	
end


GUI.RegisterPanel(JH_AutoTeam.szTitle, 1344, _L["Dev"], PS)

-- arg0 名字 arg1 阵营 arg2 门派 arg3 等级
JH.RegisterEvent("PARTY_APPLY_REQUEST", function()
	if JH_AutoTeam.bEnable then
		if JH_AutoTeam.tCamp[arg1+1] then
			JH.DoMessageBox("ATMP_" .. arg0)
		else
			JH.DoMessageBox("ATMP_" .. arg0,2)
		end
	end
end)