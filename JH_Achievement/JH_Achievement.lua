-- @Author: Webster
-- @Date:   2016-02-26 23:33:04
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-03-16 10:06:25
local _L = JH.LoadLangPack
local Achievement = {}
local ACHI_ANCHOR  = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
local ACHI_ROOT_URL = "http://game.j3ui.com/wiki/"
-- local ACHI_ROOT_URL = "http://10.37.210.22:8088/wiki/"
-- local ACHI_ROOT_URL = "http://10.0.20.20/wiki/"
local AHCI_CLIENT_LANG = select(3, GetVersion())

JH_Achievement = {}

function JH_Achievement.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	JH.RegisterGlobalEsc("Achievement", Achievement.IsOpened, Achievement.ClosePanel)
	local handle = this:Lookup("", "")
	this.pedia   = this:Lookup("WndScroll_Pedia", "")
	this.link    = this:Lookup("Edit_Link")
	this.title   = handle:Lookup("Text_Title")
	this.box     = handle:Lookup("Box_Icon")
	this:Lookup("Btn_Edit"):Lookup("", "Text_Edit"):SetText(_L["perfection"])
	handle:Lookup("Text_AchievementPedia"):SetText(_L["achievement encyclopedia"])
	handle:Lookup("Text_Link"):SetText(_L["Reference Link"])
	this:Lookup("Btn_Open"):Lookup("", "Text_Open"):SetText(_L["Open URL"])
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
		table.insert(xml, GetFormatText(frame.desc, 41))
		OutputTip(table.concat(xml), 300, { x, y, w, h })
	end
end

function JH_Achievement.OnItemMouseLeave()
	local szName = this:GetName()
	if szName == "Box_Icon" then
		this:SetObjectMouseOver(false)
		HideTip()
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
	elseif szName == "Btn_Open" then
		OpenInternetExplorer(ACHI_ROOT_URL .. "detail/" .. this:GetRoot().dwAchievement)
		Achievement.ClosePanel()
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
		frame.desc = szDesc
		frame:Lookup("Btn_Edit"):Enable(false)
		frame.pedia:Clear()
		frame.link:SetText(ACHI_ROOT_URL .. "detail/" .. dwID)
		frame.pedia:AppendItemFromString(GetFormatText(_L["Loading..."], 6))
		frame.pedia:FormatAllItemPos()
		PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
		JH.RemoteRequest(ACHI_ROOT_URL .. "game/" .. dwID .. "?_" .. GetCurrentTime() .. "&lang=" .. AHCI_CLIENT_LANG, function(szTitle, szDoc)
			if Achievement.IsOpened() then
				local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
				if err then
					JH.Sysmsg2(_L["request failed"])
				else
					frame:Lookup("Btn_Edit"):Enable(true)
					if tonumber(result['id']) == frame.dwAchievement then
						Achievement.SelectVersiont(result)
					end
				end
			end
		end)
	end
end

function Achievement.SelectVersiont(result)
	local frame = Achievement.GetFrame()
	frame.result = result -- 菜单用
	frame.pedia:Clear()
	if result.data then
		local dat = result.data
		frame.pedia:AppendItemFromString(GetFormatText(dat.desc, 6))
		frame.szText = dat.desc
		frame.pedia:AppendItemFromString(GetFormatText("\n\n", 6))
		frame.pedia:AppendItemFromString(GetFormatText(_L["Version"], 172))
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
						table.insert(xml, GetFormatText(_L["Click for achievement Encyclopedia"], 41))
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
