-- @Author: Webster
-- @Date:   2016-02-26 23:33:04
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-04-16 22:11:18
local _L = JH.LoadLangPack
local Achievement = {}
local ACHI_ANCHOR  = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
local ACHI_ROOT_URL = "http://game.j3ui.com/wiki/"
-- local ACHI_ROOT_URL = "http://10.37.210.22:8088/wiki/"
-- local ACHI_ROOT_URL = "http://10.0.20.20:8090/wiki/"
local AHCI_CLIENT_LANG = select(3, GetVersion())

-- 获取玩家成就完成信息 2byte存8个 无法获取带进度的
local sformat = string.format
local tinsert = table.insert

local function Bitmap2Number(t)
	local n = 0
	for i, v in ipairs(t) do
		if v and v ~= 0 then
			n = n + 2 ^ (i - 1)
		end
	end
	return sformat("%02x", n)
end

local function GetAchievementList()
	local me    = GetClientPlayer()
	local data  = {}
	local count = g_tTable.Achievement:GetRowCount()
	local max   = g_tTable.Achievement:GetRow(count).dwID
	for i = 1, max do
		data[i] = me.IsAchievementAcquired(i)
	end
	local bitmap = {}
	local i = 1
	repeat
		local tt = {}
		for a = i, i + 8 do
			tinsert(tt, data[a])
		end
		tinsert(bitmap, Bitmap2Number(tt))
		i = i + 8
	until i > max
	return bitmap, data
end

JH_Achievement = {}

function JH_Achievement.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	JH.RegisterGlobalEsc("Achievement", Achievement.IsOpened, Achievement.ClosePanel)
	local handle = this:Lookup("", "")
	this.pedia   = this:Lookup("WndScroll_Pedia", "")
	this.link    = handle:Lookup("Text_Link")
	this.title   = handle:Lookup("Text_Title")
	this.desc    = handle:Lookup("Text_Desc")
	this.box     = handle:Lookup("Box_Icon")
	this:Lookup("Btn_Edit"):Lookup("", "Text_Edit"):SetText(_L["perfection"])
	Achievement.UpdateAnchor(this)
end

function JH_Achievement.OnItemMouseEnter()
	local szName = this:GetName()
	if szName == "Box_Icon" then
		this:SetObjectMouseOver(true)
		local frame = this:GetRoot()
		local x, y  = this:GetAbsPos()
		local w, h  = this:GetSize()
		local xml   = {}
		table.insert(xml, GetFormatText(frame.title:GetText() .. "\n", 27))
		table.insert(xml, GetFormatText(frame.desc:GetText(), 41))
		OutputTip(table.concat(xml), 300, { x, y, w, h })
	elseif szName == "Text_Link" then
		this:SetFontScheme(35)
	end
end

function JH_Achievement.OnItemMouseLeave()
	local szName = this:GetName()
	if szName == "Box_Icon" then
		this:SetObjectMouseOver(false)
		HideTip()
	elseif szName == "Text_Link" then
		this:SetFontScheme(172)
	end
end

function JH_Achievement.OnFrameDragEnd()
	ACHI_ANCHOR = GetFrameAnchor(this)
end

function JH_Achievement.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		Achievement.UpdateAnchor(this)
	end
end

function JH_Achievement.OnEditChanged()
	local szName = this:GetName()
	if szName == "Edit_EditMode" then
		this:GetRoot().szText = this:GetText()
		this:GetRoot():Lookup("Btn_Send"):Enable(true)
	end
end

function JH_Achievement.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Close" then
		Achievement.ClosePanel()
	elseif szName == "Btn_Edit" then
		if AHCI_CLIENT_LANG ~= "zhcn" and AHCI_CLIENT_LANG ~= "zhtw" then
			return JH.Alert(_L["Sorry, Does not support this function"])
		end
		if this:GetRoot().szText == "" or this:GetRoot().szText == _L["Achi Default Templates"] then
			Achievement.EditMode(true)
		else
			JH.Confirm(_L["ACHI_TIPS"], function()
				Achievement.EditMode(true)
			end)
		end
	elseif szName == "Btn_Cancel" then
		Achievement.EditMode(false)
	elseif szName == "Btn_Send" then
		JH.Confirm(_L["Confirm?"], Achievement.Send)
	end
end

function JH_Achievement.OnItemLButtonClick()
	local szName = this:GetName()
	if szName == "Text_Link" then
		local frame = this:GetRoot()
		OpenInternetExplorer(ACHI_ROOT_URL .. "detail/" .. frame.dwAchievement)
		if not frame.bEdit then
			Achievement.ClosePanel()
		end
	end
end

function Achievement.Send()
	if Achievement.IsOpened() then
		local frame = Achievement.GetFrame()
		local edit = frame:Lookup("Edit_EditMode")
		local desc = edit:GetText()
		if string.len(JH.UrlEncode(desc)) > 1200 or string.len(desc) < 5 then
			return JH.Alert(_L["game limit"])
		end
		local tParam = {
			aid    = frame.dwAchievement,
			desc   = desc,
			author = GetUserRoleName() .. "@" .. select(2, GetUserServer()), -- 每天跌停@长白山
			_      = GetCurrentTime(),
			lang   = AHCI_CLIENT_LANG
		}
		local t = {}
		for k, v in pairs(tParam) do
			table.insert(t, k .. "=" .. JH.UrlEncode(tostring(v)))
		end
		frame:Lookup("Btn_Send"):Enable(false)
		JH.RemoteRequest(ACHI_ROOT_URL .. "send/?" .. table.concat(t, "&"), function(szTitle, szDoc)
			frame:Lookup("Btn_Send"):Enable(true)
			local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
			if err then
				JH.Sysmsg2(_L["request failed"])
			else
				Achievement.EditMode(false)
				JH.Alert(result.msg)
			end
		end)
	end
end

function Achievement.EditMode(bEnter)
	if Achievement.IsOpened() then
		local frame = Achievement.GetFrame()
		if bEnter then
			frame:Lookup("WndScroll_Pedia"):Hide()
			frame:Lookup("Btn_Edit"):Hide()
			frame:Lookup("Btn_Cancel"):Show()
			frame:Lookup("Btn_Send"):Show()
			frame:Lookup("Edit_EditMode"):Show()
			if frame.szText == "" then
				frame.szText = _L["Achi Default Templates"]
			end
			frame:Lookup("Edit_EditMode"):SetText(frame.szText)
			frame:Lookup("Btn_Send"):Enable(false)
		else
			frame:Lookup("WndScroll_Pedia"):Show()
			frame:Lookup("Btn_Edit"):Show()
			frame:Lookup("Btn_Cancel"):Hide()
			frame:Lookup("Btn_Send"):Hide()
			frame:Lookup("Edit_EditMode"):Hide()
		end
		frame.bEdit = bEnter
	end
end

function Achievement.UpdateAnchor(frame)
	frame:SetPoint(ACHI_ANCHOR.s, 0, 0, ACHI_ANCHOR.r, ACHI_ANCHOR.x, ACHI_ANCHOR.y)
end

function Achievement.ClosePanel()
	if Achievement.IsOpened() then
		Wnd.CloseWindow(Achievement.IsOpened())
		PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
	end
end

function Achievement.IsOpened()
	return Station.Lookup("Normal/JH_Achievement")
end

function Achievement.GetFrame()
	if not Achievement.IsOpened() then
		Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "JH_Achievement/ui/JH_Achievement.ini", "JH_Achievement")
	end
	return Achievement.IsOpened()
end

function Achievement.GetLinkScript(szLink)
	return [[
		this.OnItemLButtonClick = function()
			OpenInternetExplorer(]] .. EncodeComponentsString(szLink) .. [[)
		end
		this.OnItemMouseEnter = function()
			this:SetFontColor(255, 0, 0)
		end
		this.OnItemMouseLeave = function()
			this:SetFontColor(20, 150, 220)
		end
	]]
end

function Achievement.OpenEncyclopedia(dwID, dwIcon, szTitle, szDesc)
	local frame = Achievement.GetFrame()
	if frame.bEdit then
		JH.Alert(_L["Please exit edit mode"])
	else
		local handle = frame.handle
		frame.dwAchievement = dwID
		frame:BringToTop()
		frame.title:SetText(szTitle)
		frame.box:SetObjectIcon(dwIcon)
		frame.desc:SetText(szDesc)
		frame:Lookup("Btn_Edit"):Enable(false)
		frame.pedia:Clear()
		frame.link:SetText(_L("Link(Open URL):%s", ACHI_ROOT_URL .. "detail/" .. dwID))
		frame.link:AutoSize()
		frame.pedia:AppendItemFromString(GetFormatText(_L["Loading..."], 6))
		frame.pedia:FormatAllItemPos()
		PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
		JH.RemoteRequest(ACHI_ROOT_URL .. "api?op=game&aid=" .. dwID .. "&_" .. GetCurrentTime() .. "&lang=" .. AHCI_CLIENT_LANG, function(szTitle, szDoc)
			if Achievement.IsOpened() then
				local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
				if err then
					JH.Sysmsg2(_L["request failed"])
				else
					frame:Lookup("Btn_Edit"):Enable(true)
					if tonumber(result['id']) == frame.dwAchievement then
						Achievement.RemoteCallBack(result)
					end
				end
			end
		end)
	end
end

function Achievement.RemoteCallBack(result)
	local frame = Achievement.GetFrame()
	frame.result = result -- 菜单用
	frame.pedia:Clear()
	if result.data then
		local dat = result.data
		local xml = {}
		for k, v in ipairs(dat.desc) do
			if v.type == "text" then
				tinsert(xml, GetFormatText(v.text, 6))
			elseif v.type == "span" then
				local r, g, b = unpack(v.text[1])
				tinsert(xml, GetFormatText(v.text[2], 6, r, g, b))
			elseif v.type == "image" then
				tinsert(xml, "<image>script=".. EncodeComponentsString("this.src=" .. EncodeComponentsString(v.text[1]))  .." </image>")
			elseif v.type == "a" then
				tinsert(xml, GetFormatText(v.text[2], 6, 20, 150, 220, 272, Achievement.GetLinkScript(v.text[1])))
			end
		end
		frame.pedia:AppendItemFromString(table.concat(xml))
		for i = frame.pedia:GetItemCount() - 1, 0, -1 do
			local item = frame.pedia:Lookup(i)
			if item and item:GetType() == 'Image' and item.FromRemoteFile then
				item:FromRemoteFile(item.src, true, function(e, a, b, c)
					e:AutoSize()
					JH.DelayCall(function()
						if item and item:IsValid() then
							local w, h = item:GetSize()
							if w > 670 then
								local f = 670 / w
								item:SetSize(w * f, h * f)
							end
						end
						if frame and frame.pedia and frame.pedia:IsValid() then
							frame.pedia:FormatAllItemPos()
						end
					end, 100)
				end)
			end
		end
		frame.szText = GetPureText(table.concat(xml))
		frame.pedia:AppendItemFromString(GetFormatText("\n\n", 6))
		frame.pedia:AppendItemFromString(GetFormatText(_L["revise"], 172))
		frame.pedia:AppendItemFromString(GetFormatText(" " .. dat.ver .. "\n", 6))
		frame.pedia:AppendItemFromString(GetFormatText(_L["Author"], 172))
		frame.pedia:AppendItemFromString(GetFormatText(" " .. dat.author .. "\n", 6))
		frame.pedia:AppendItemFromString(GetFormatText(_L["Change time"], 172))
		local date = FormatTime("%Y/%m/%d %H:%M", tonumber(dat.dateline))
		frame.pedia:AppendItemFromString(GetFormatText(" " .. date, 6))
	else
		frame.pedia:AppendItemFromString(GetFormatText(result.desc, 6))
		frame.szText = ""
	end
	frame.pedia:FormatAllItemPos()
end

function Achievement.AppendBoxEvent(handle)
	for i = 0, handle:GetItemCount() -1 do
		local item = handle:Lookup(i)
		if item and item:IsValid() then
			local dwID = item.dwAchievement
			if dwID ~= item.__JH_Append then
				local hiDescribe = item:Lookup("Text_AchiDescribe")
				local hName = item:Lookup("Text_AchiName")
				local box = item:Lookup("Box_AchiBox")
				if dwID and box and hiDescribe and hName then
					box:RegisterEvent(272)
					box.OnItemMouseEnter = function()
						this:SetObjectMouseOver(true)
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						local xml   = {}
						table.insert(xml, GetFormatText(_L["Click for Achievepedia"], 41))
						if IsCtrlKeyDown() then
							table.insert(xml, GetFormatText("\n\n" .. g_tStrings.DEBUG_INFO_ITEM_TIP .. "\n", 102))
							table.insert(xml, GetFormatText("dwAchievement: " .. dwID, 102))
						end
						OutputTip(table.concat(xml), 300, { x, y, w, h })
					end
					box.OnItemMouseLeave = function()
						this:SetObjectMouseOver(false)
						HideTip()
					end
					box.OnItemLButtonClick = function()
						Achievement.OpenEncyclopedia(dwID, box:GetObjectIcon(), hName:GetText(), hiDescribe:GetText())
						return
					end
				end
				item.__JH_Append = dwID
			end
		end
	end
end

function Achievement.OnFrameBreathe()
	local handle = Station.Lookup("Normal/AchievementPanel/PageSet_Achievement/Page_Achievement/WndScroll_AShow", "")
	if handle then
		Achievement.AppendBoxEvent(handle)
	end
	local handle2 = Station.Lookup("Normal/AchievementPanel/PageSet_Achievement/Page_Summary/WndScroll_Summary/WndContainer_AchiPanel/PageSet_Achi/Page_Chi/PageSet_RecentAchi/Page_AlmostFinish", "")
	if handle2 then
		Achievement.AppendBoxEvent(handle2)
	end
	local handle3 = Station.Lookup("Normal/AchievementPanel/PageSet_Achievement/Page_Summary/WndScroll_Summary/WndContainer_AchiPanel/PageSet_Achi/Page_Chi/PageSet_RecentAchi/Page_Scene", "")
	if handle3 then
		Achievement.AppendBoxEvent(handle3)
	end
end

-- local PS = {}
-- function PS.OnPanelActive(frame)
-- 	local ui, nX, nY = GUI(frame), 10, 0
-- 	local bitmap, data = GetAchievementList()
-- 	ui:Append("Text", { x = 0, y = 0, txt = _L["Achievepedia"], font = 27 })

-- end
-- GUI.RegisterPanel(_L["Achievepedia"], { "ui/Image/UICommon/Achievement8.uitex", 16 }, g_tStrings.CHANNEL_CHANNEL, PS)

-- kill AchievementPanel
if Station and Station.Lookup("Normal/AchievementPanel") then
	Wnd.CloseWindow("AchievementPanel")
end

-- init
JH.RegisterEvent("ON_FRAME_CREATE.ACHIVEEMENT", function()
	if arg0 and arg0:GetName() == "AchievementPanel" then
		arg0.OnFrameShow = function()
			JH.BreatheCall("ACHIVEEMENT", Achievement.OnFrameBreathe)
			JH.Debug("Init ACHIVEEMENT")
		end
		arg0.OnFrameHide = function()
			JH.BreatheCall("ACHIVEEMENT")
			JH.Debug("UnInit ACHIVEEMENT")
		end
		JH.BreatheCall("ACHIVEEMENT", Achievement.OnFrameBreathe)
		JH.UnRegisterEvent("ON_FRAME_CREATE.ACHIVEEMENT")
	end
end)
