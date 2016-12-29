-- @Author: Webster
-- @Date:   2016-01-04 12:57:33
-- @Last Modified by:   Administrator
-- @Last Modified time: 2016-12-29 11:13:26

local _L = JH.LoadLangPack
local PR = {}
local PR_MAX_LEVEL = 95
local PR_INI_PATH      = JH.GetAddonInfo().szRootPath .. "JH_ToolBox/ui/JH_PartyRequest.ini"
local PR_EQUIP_REQUEST = {}
local PR_MT = { __call = function(me, szName)
	for k, v in ipairs(me) do
		if v.szName == szName then
			return true
		end
	end
end }
local PR_PARTY_REQUEST  = setmetatable({}, PR_MT)

JH_PartyRequest = {
	bEnable     = true,
	bAutoCancel = false,
}
JH.RegisterCustomData("JH_PartyRequest")

function JH_PartyRequest.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Setting" then
		local menu = {}
		table.insert(menu, { szOption = _L["Auto Refuse No full level Player"], bCheck = true, bChecked = JH_PartyRequest.bAutoCancel, fnAction = function()
			JH_PartyRequest.bAutoCancel = not JH_PartyRequest.bAutoCancel
		end })
		PopupMenu(menu)
	end
end

function PR.GetFrame()
	return Station.Lookup("Normal2/JH_PartyRequest")
end

function PR.OpenPanel()
	if not PR.GetFrame() then
		local frame = Wnd.OpenWindow(PR_INI_PATH, "JH_PartyRequest")
		frame.bg = frame:Lookup("", "Image_Bg")
		GUI(frame):Point():Title(g_tStrings.STR_ARENA_INVITE):RegisterClose(PR.ClosePanel, false, true)
	end
end

function PR.ClosePanel(bCompulsory)
	local fnAction = function()
		Wnd.CloseWindow(PR.GetFrame())
		PR_PARTY_REQUEST  = setmetatable({}, PR_MT)
	end
	if bCompulsory then
		fnAction()
	else
		JH.Confirm(_L["Clear list and close?"], fnAction)
	end
end

function PR.OnPeekPlayer()
	if PR_EQUIP_REQUEST[arg1] then
		if arg0 == PEEK_OTHER_PLAYER_RESPOND.SUCCESS then
			local me = GetClientPlayer()
			local dwType, dwID = me.GetTarget()
			JH.SetTarget(arg1)
			JH.SetTarget(dwType, dwID)
			local p = GetPlayer(arg1)
			if p then
				local mnt = p.GetKungfuMount()
				local data = { nil, arg1, mnt and mnt.dwSkillID or nil, false }
				PR.Feedback(p.szName, data)
			end
		end
		PR_EQUIP_REQUEST[arg1] = nil
	end
end

function PR.OnApplyRequest()
	if not JH_PartyRequest.bEnable then
		return
	end
	local hMsgBox = Station.Lookup("Topmost/MB_ATMP_" .. arg0) or Station.Lookup("Topmost/MB_IMTP_" .. arg0)
	if hMsgBox then
		local btn  = hMsgBox:Lookup("Wnd_All/Btn_Option1")
		local btn2 = hMsgBox:Lookup("Wnd_All/Btn_Option2")
		if btn and btn:IsEnabled() then
			if not PR_PARTY_REQUEST(arg0) then
				local tab = {
					szName  = arg0,
					nCamp   = arg1,
					dwForce = arg2,
					nLevel  = arg3,
					fnAction = function()
						pcall(btn.fnAction)
					end,
					fnCancelAction = function()
						pcall(btn2.fnAction)
					end
				}
				if not JH_PartyRequest.bAutoCancel or JH_PartyRequest.bAutoCancel and arg3 == PR_MAX_LEVEL then
					table.insert(PR_PARTY_REQUEST, tab)
				else
					JH.Sysmsg(_L("Auto Refuse %s(%s %d%s) Party request", arg0, g_tStrings.tForceTitle[arg2], arg3, g_tStrings.STR_LEVEL))
					pcall(btn2.fnAction)
				end
			end
			local data
			local fnGetEqueip = function(dwID)
				PR_EQUIP_REQUEST[dwID] = true
				ViewInviteToPlayer(dwID, true)
			end
			if MY_Farbnamen and MY_Farbnamen.Get then
				data = MY_Farbnamen.Get(arg0)
				if data then
					fnGetEqueip(data.dwID)
				end
			end
			if not data then
				for k, v in pairs(JH.GetAllPlayer()) do
					if v.szName == arg0 then
						fnGetEqueip(v.dwID)
						break
					end
				end
			end
			hMsgBox.fnAutoClose = nil
			hMsgBox.fnCancelAction = nil
			hMsgBox.szCloseSound = nil
			Wnd.CloseWindow(hMsgBox)
			PR.UpdateFrame()
		end
	end
end

function PR.UpdateFrame()
	if not PR.GetFrame() then
		PR.OpenPanel()
	end
	local frame = PR.GetFrame()
	-- update
	if #PR_PARTY_REQUEST == 0 then
		return PR.ClosePanel(true)
	end
	local hContainer = frame:Lookup("WndContainer_Request")
	hContainer:Clear()
	local cover = "ui/Image/Common/CoverShadow.UITex"
	for k, v in ipairs(PR_PARTY_REQUEST) do
		local item = hContainer:AppendContentFromIni(PR_INI_PATH, "WndWindow_Item", k)
		local ui = GUI(item)
		if v.dwKungfuID then
			ui:Append("Image", { x = 5, y = 5, w = 40, h = 40 }):File(Table_GetSkillIconID(v.dwKungfuID, 1))
		else
			ui:Append("Image", { x = 5, y = 5, w = 40, h = 40 }):File(GetForceImage(v.dwForce))
		end
		if v.nGongZhan == 1 then
			ui:Append("Image", { x = 25, y = 30, w = 15, h = 15 }):File(Table_GetBuffIconID(3219, 1))
		end
		ui:Append("Image", { x = 215, y = 15, w = 20, h = 20 }):File("ui/Image/UICommon/CommonPanel2.UITex", GetCampImageFrame(v.nCamp) or -1)
		ui:Append("Image", { x = 0, y = 42, w = 420, h = 8 }):File("ui/Image/UICommon/CommonPanel.UITex", 45)
		ui:Append("Image", "Cover", { x = 0, y = 0, w = 420, h = 50 }):File(cover, 2):Toggle(false)
		ui:Hover(function(bHover)
			if bHover then
				ui:Fetch("Cover"):File(cover, 2):Toggle(true)
			else
				ui:Fetch("Cover"):Toggle(false)
			end
		end):Raw().OnRButtonDown = function()
			local menu = {}
			InsertPlayerCommonMenu(menu, 0, v.szName)
			menu[4] = nil
			if v.dwID then
				table.insert(menu, { szOption = g_tStrings.STR_LOOKUP, fnAction = function()
					ViewInviteToPlayer(v.dwID)
				end })
			end
			PopupMenu(menu)
		end
		if v.bDetail and v.bEx == "Author" then
			ui:Append("Text",{ x = 47, y = 8, txt = v.szName, font = 15, color = { 255, 255, 0 } })
		else
			ui:Append("Text",{ x = 47, y = 8, txt = v.szName, font = 15  })
		end
		ui:Append("Text",{ x = 5, y = 25, txt = v.nLevel, font = 215 })
		item.OnLButtonDown = function()
			if IsCtrlKeyDown() then
				EditBox_AppendLinkPlayer(v.szName)
			end
		end
		ui:Append("WndButton2", { x = 240, y = 10, w = 60, h = 34, txt = g_tStrings.STR_ACCEPT }):Click(function()
			v.fnAction()
			table.remove(PR_PARTY_REQUEST, k)
			PR.UpdateFrame()
		end):Hover(function(bHover)
			if bHover then
				ui:Fetch("Cover"):File(cover, 3):Toggle(true)
			else
				ui:Fetch("Cover"):Toggle(false)
			end
		end)
		ui:Append("WndButton2", { x = 305, y = 10, w = 60, h = 34, txt = g_tStrings.STR_REFUSE }):Click(function()
			v.fnCancelAction()
			table.remove(PR_PARTY_REQUEST, k)
			PR.UpdateFrame()
		end):Hover(function(bHover)
			if bHover then
				ui:Fetch("Cover"):File(cover, 4):Toggle(true)
			else
				ui:Fetch("Cover"):Toggle(false)
			end
		end)
		if v.bDetail then
			ui:Append("WndButton2", "Details",{ x = 370, y = 10, w = 90, h = 34, txt = g_tStrings.STR_LOOKUP, color = { 255, 255, 0 } }):Click(function()
				ViewInviteToPlayer(v.dwID)
			end):Hover(function(bHover)
				if bHover then
					ui:Fetch("Cover"):File(cover, 1):Toggle(true)
				else
					ui:Fetch("Cover"):Toggle(false)
				end
			end)
		else
			ui:Append("WndButton2", "Details",{ x = 370, y = 10,w = 90, h = 34, txt = _L["Details"] }):Click(function()
				JH.BgTalk(v.szName, "RL", "ASK")
				ui:Fetch("Details"):Enable(false):Text(_L["loading..."])
				JH.Sysmsg(_L["If it is always loading, the target may not install plugin or refuse."])
			end):Hover(function(bHover)
				if bHover then
					ui:Fetch("Cover"):File(cover,1):Toggle(true)
				else
					ui:Fetch("Cover"):Toggle(false)
				end
			end)
		end
	end
	local w, h = 470, 50
	local n = hContainer:GetAllContentCount()
	hContainer:SetH(h * n)
	frame:SetH(h * n + 30)
	frame:SetDragArea(0, 0, w, h * n + 30)
	frame.bg:SetH(h * n + 30)
	hContainer:FormatAllContentPos()
end

function PR.Feedback(szName, data)
	for k, v in ipairs(PR_PARTY_REQUEST) do
		if v.szName == szName then
			v.bDetail    = true
			v.dwID       = data[2]
			v.dwKungfuID = data[3]
			v.nGongZhan  = data[4]
			v.bEx        = data[5]
			break
		end
	end
	PR.UpdateFrame()
end

function JH_PartyRequest.GetEvent()
	if JH_PartyRequest.bEnable then
		return
			{ "PEEK_OTHER_PLAYER"   , PR.OnPeekPlayer   },
			{ "PARTY_INVITE_REQUEST", PR.OnApplyRequest },
			{ "PARTY_APPLY_REQUEST" , PR.OnApplyRequest }
	end
end

JH.RegisterBgMsg("RL", function(nChannel, dwID, szName, data, bIsSelf)
	if not bIsSelf then
		if data[1] == "ASK" then
			JH.Confirm(_L("[%s] want to see your info, OK?", szName), function()
				local me = GetClientPlayer()
				local nGongZhan = JH.GetBuff(3219) and 1 or 0
				JH.BgTalk(szName, "RL", "Feedback", me.dwID, UI_GetPlayerMountKungfuID(), nGongZhan, JH.bDebugClient and "Author" or "Player")
			end)
		elseif data[1] == "Feedback" then
			PR.Feedback(szName, data)
		end
	end
end)
