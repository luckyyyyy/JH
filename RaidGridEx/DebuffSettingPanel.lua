DebuffSettingPanel = {}
DebuffSettingPanel.frameSelf = nil
DebuffSettingPanel.handleList = nil
DebuffSettingPanel.handleListSelected = nil

-- 存档的BUFF/DEBUFF列表内容, 主表是个 Array
-- 子表格式为 {szName = "组名", szDesc = "我是描述，我是TIP。", szContent = "普渡八音(红),火里栽莲,王手截脉(蓝)", bEnable = true}
DebuffSettingPanel.tDebuffListContent = {};				RegisterCustomData("DebuffSettingPanel.tDebuffListContent")

local nEnableIcon = 1520
local nDisableIcon = 646
local szIniFile = "Interface/JH/RaidGridEx/DebuffSettingPanel.ini"

DebuffSettingPanel.tColorCover = {
	["红"] = {255, 0, 0},
	["绿"] = {0, 255, 0},
	["蓝"] = {0, 0, 255},
	["黄"] = {255, 255, 0},
	["紫"] = {255, 0, 255},
	["青"] = {0, 255, 255},
	["橙"] = {255, 128, 0},
	["黑"] = {0, 0, 0},
	["白"] = {255, 255, 255},
}

-- 格式化Debuff表的数据, 成为直接可用的内容
function DebuffSettingPanel.FormatDebuffNameList()
	local tSplitTextTable = {}
	for nIndex, tInfo in pairs(DebuffSettingPanel.tDebuffListContent) do
		local szContent = tInfo.szContent
		if tInfo.bEnable and szContent and type(szContent) == "string" and szContent ~= "" then
			szContent = szContent:gsub("%s", "")
			szContent = szContent:gsub("，", ",")
			szContent = szContent:gsub("（", "(")
			szContent = szContent:gsub("）", ")")
			szContent = szContent .. ","
			local nRate = 0
			for i = 1, 20 do
				local nStartIndex, nEndInex, szNewContent = szContent:find(",(.*)")
				if not nStartIndex then
					break
				end
				local szSplitText = szContent:sub(1, nStartIndex - 1)
				if szSplitText and szSplitText ~= "" then
					local szColor = szSplitText:match("%b()")
					if szColor and szColor ~= "" then
						 szColor = szColor:sub(2, -2)
						 szSplitText = szSplitText:gsub("%b()", "")
					end
					if not tSplitTextTable[szSplitText] then
						nRate = nRate + 1
						tSplitTextTable[szSplitText] = {nRate, (szColor or "")}
					end
				end
				szContent = szNewContent
			end
		end
	end
	return tSplitTextTable
end

function DebuffSettingPanel.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	DebuffSettingPanel.OnEvent("UI_SCALED")
	DebuffSettingPanel.frameSelf = this
	DebuffSettingPanel.handleList = this:Lookup("", "Handle_List")	
	DebuffSettingPanel.UpdateList()
end

function DebuffSettingPanel.OnFrameBreathe()
	local player = GetClientPlayer()
	if not player then
		return
	end
end

function DebuffSettingPanel.OnEvent(event)
	if event == "UI_SCALED" then
		this:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
	end
end

function DebuffSettingPanel.UpdateList()
	local handleList = DebuffSettingPanel.handleList
	handleList:Clear()
	for nIndex, tContent in pairs(DebuffSettingPanel.tDebuffListContent) do
		DebuffSettingPanel.NewListDebuffGroup(nIndex)
	end
end

function DebuffSettingPanel.NewListDebuffGroup(nIndex, bSelectNewHandle)
	local tInfo = DebuffSettingPanel.tDebuffListContent[(nIndex or -1)]
	if not tInfo then
		nIndex = #DebuffSettingPanel.tDebuffListContent + 1
		tInfo = {szName = "新建组[" .. nIndex .. "]", szDesc = "", szContent = "", bEnable = true}
		table.insert(DebuffSettingPanel.tDebuffListContent, tInfo)
	end
	
	local handleList = DebuffSettingPanel.handleList
	local handleDebuffGroup = handleList:AppendItemFromIni(szIniFile, "HI")
	handleDebuffGroup:Lookup("Name"):SetText(tInfo.szName)
	handleDebuffGroup.nIndex = nIndex
	
	local box = handleDebuffGroup:Lookup("Box_Skill")
	local nIconID = nDisableIcon
	if tInfo.bEnable then
		nIconID = nEnableIcon
	end
	
	box:Show()
	box:SetObject(1,0)
	box:ClearObjectIcon()
	box:SetObjectIcon(nIconID)
	box.nIndex = nIndex
	
	if bSelectNewHandle then
		DebuffSettingPanel.SelectListHandle(handleDebuffGroup)
	end
	DebuffSettingPanel.UpdateScrollInfo()
	return handleDebuffGroup
end

function DebuffSettingPanel.DelListDebuffGroup(handle)
	local nIndex = handle.nIndex
	local tInfo = DebuffSettingPanel.tDebuffListContent[nIndex]
	if tInfo then
		table.remove(DebuffSettingPanel.tDebuffListContent, nIndex)
		DebuffSettingPanel.UpdateList()
		DebuffSettingPanel.UpdateScrollInfo()
		DebuffSettingPanel.handleListSelected = nil
	end
end

function DebuffSettingPanel.UpdateScrollInfo()
	local handleList = DebuffSettingPanel.handleList
	handleList:FormatAllItemPos()
	local w, h = handleList:GetSize()
	local wAll, hAll = handleList:GetAllItemSize()

	local nStep = math.ceil((hAll - h) / 10)
	local scroll = handleList:GetRoot():Lookup("Scroll_List")
	if nStep > 0 then
		scroll:Show()
		scroll:GetParent():Lookup("Btn_Up"):Show()
		scroll:GetParent():Lookup("Btn_Down"):Show()
	else
		scroll:Hide()
		scroll:GetParent():Lookup("Btn_Up"):Hide()
		scroll:GetParent():Lookup("Btn_Down"):Hide()			
	end	
	scroll:SetStepCount(nStep)
end

-------------------------------------------------------------------------------------------------------------

function DebuffSettingPanel.OnItemMouseEnter()
	local szName = this:GetName()
	if szName:match("HI") then
		local imageCover = this:Lookup("Sel")
		if imageCover then
			imageCover:Show()
		end
	elseif szName:match("Box_Skill") then
		this:SetObjectMouseOver(true)
		local tInfo = DebuffSettingPanel.tDebuffListContent[this.nIndex]
		if tInfo then
			local szTip = tInfo.szDesc or ""
			local nMouseX, nMouseY = Cursor.GetPos()
			local szEnableTip = "<Text>text="..EncodeComponentsString("当前监视模块已经关闭（红色图标）\n").." font=102 </text>"
			if tInfo.bEnable then
				szEnableTip = "<Text>text="..EncodeComponentsString("当前监视模块已经开启（绿色图标）\n").." font=105 </text>"
			end
			OutputTip(szEnableTip .. "<Text>text="..EncodeComponentsString(szTip).." font=100 </text>", 1000, {nMouseX, nMouseY, 0, 0})
		end
	end
end

function DebuffSettingPanel.OnItemMouseLeave()
	local szName = this:GetName()
	if szName:match("HI") then
		local imageCover = this:Lookup("Sel")
		local nSelectedIndex = -1
		if DebuffSettingPanel.handleListSelected and DebuffSettingPanel.handleListSelected.nIndex then
			nSelectedIndex = DebuffSettingPanel.handleListSelected.nIndex
		end
		if imageCover and this.nIndex ~= nSelectedIndex then
			imageCover:Hide()
		end
	elseif szName:match("Box_Skill") then
		this:SetObjectMouseOver(false)
		HideTip()
	end
end

-------------------------------------------------------------------------------------------------------------

function DebuffSettingPanel.OnItemLButtonClick()
	local szName = this:GetName()
	if szName:match("Box_Skill") then
		local nIndex = this.nIndex
		local tInfo = DebuffSettingPanel.tDebuffListContent[nIndex]
		if tInfo then
			local box = this
			local nIconID = nDisableIcon
			if tInfo.bEnable then
				tInfo.bEnable = false
			else
				tInfo.bEnable = true
				nIconID = nEnableIcon
			end
			box:SetObjectIcon(nIconID)
			RaidGridEx.ReloadEntireTeamInfo(true)
			DebuffSettingPanel.OnItemMouseEnter()
		end
	elseif szName:match("HI") then
		DebuffSettingPanel.SelectListHandle(this)
	end
end

function DebuffSettingPanel.SelectListHandle(handle)
	if DebuffSettingPanel.handleListSelected then
		local imageLastSelectedImage = DebuffSettingPanel.handleListSelected:Lookup("Sel")
		if imageLastSelectedImage then
			imageLastSelectedImage:Hide()
		end
	end
	DebuffSettingPanel.handleListSelected = handle
	
	local imageCover = handle:Lookup("Sel")
	if imageCover then
		imageCover:Show()
	end

	local tInfo = DebuffSettingPanel.tDebuffListContent[handle.nIndex]
	if tInfo then
		DebuffSettingPanel.frameSelf:Lookup("Edit_Name"):SetText(tInfo.szName or "")
		DebuffSettingPanel.frameSelf:Lookup("Edit_Desc"):SetText(tInfo.szDesc or "")
		DebuffSettingPanel.frameSelf:Lookup("Edit_Content"):SetText(tInfo.szContent or "")
	else
		DebuffSettingPanel.frameSelf:Lookup("Edit_Name"):SetText("")
		DebuffSettingPanel.frameSelf:Lookup("Edit_Desc"):SetText("")
		DebuffSettingPanel.frameSelf:Lookup("Edit_Content"):SetText("")
	end
end

-------------------------------------------------------------------------------------------------------------

function DebuffSettingPanel.OnEditChanged()
	local szName = this:GetName()
	local handleSelected = DebuffSettingPanel.handleListSelected
	if handleSelected then
		local nIndex = DebuffSettingPanel.handleListSelected.nIndex
		local tInfo = DebuffSettingPanel.tDebuffListContent[nIndex]
		if tInfo then
			if szName:match("Edit_Name") then
				tInfo.szName = this:GetText()
				handleSelected:Lookup("Name"):SetText(tInfo.szName)
			elseif szName:match("Edit_Desc") then
				tInfo.szDesc = this:GetText()
			elseif szName:match("Edit_Content") then
				tInfo.szContent = this:GetText()
			end
		end
	end
end

function DebuffSettingPanel.OnScrollBarPosChanged()
	local nCurrentValue = this:GetScrollPos()
	local szName = this:GetName()
	if szName == "Scroll_List" then
		local nCurrentValue = this:GetScrollPos()
		local frame = this:GetParent()
		if nCurrentValue == 0 then
			frame:Lookup("Btn_Up"):Enable(false)
		else
			frame:Lookup("Btn_Up"):Enable(true)
		end
		if nCurrentValue == this:GetStepCount() then
			frame:Lookup("Btn_Down"):Enable(false)
		else
			frame:Lookup("Btn_Down"):Enable(true)
		end
		
	    local handle = frame:Lookup("", "Handle_List")
	    handle:SetItemStartRelPos(0, - nCurrentValue * 10)
    end
end

function DebuffSettingPanel.OnLButtonHold()
    local szName = this:GetName()
	if szName == "Btn_Up" then
		this:GetParent():Lookup("Scroll_List"):ScrollPrev(1)
	elseif szName == "Btn_Down" then
		this:GetParent():Lookup("Scroll_List"):ScrollNext(1)
    end
end

function DebuffSettingPanel.OnItemMouseWheel()
	local nDistance = Station.GetMessageWheelDelta()
	this:GetParent():Lookup("Scroll_List"):ScrollNext(nDistance)
	return 1
end

function DebuffSettingPanel.OnLButtonDown()
	DebuffSettingPanel.OnLButtonHold()
end

-------------------------------------------------------------------------------------------------------------

function DebuffSettingPanel.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Cancel" then
		DebuffSettingPanel.ClosePanel()
	elseif szName == "Btn_New" then
		DebuffSettingPanel.NewListDebuffGroup(nil, true)
		PlaySound(SOUND.UI_SOUND,g_sound.Button)
	elseif szName == "Btn_Close" then
		DebuffSettingPanel.ClosePanel()
	elseif szName == "Btn_Delete" then
		if not DebuffSettingPanel.handleListSelected then
			return
		end
		local DelHandle = function()
			local handleSelected = DebuffSettingPanel.handleListSelected
			if not handleSelected then
				return
			end
			local nIndex = DebuffSettingPanel.handleListSelected.nIndex
			local tInfo = DebuffSettingPanel.tDebuffListContent[nIndex]
			if not tInfo then
				return
			end
			DebuffSettingPanel.DelListDebuffGroup(handleSelected)
		end				
		if IsShiftKeyDown() then
			DelHandle()
		else
			local msg = {
				szMessage = "你确定要删除么？（按住SHIFT可以跳过此确认框）",
				szName = "del_debufflist_sure",
				fnAutoClose = function() return not DebuffSettingPanel.IsPanelOpened() end,
				{szOption = g_tStrings.STR_HOTKEY_SURE, fnAction = function() DelHandle() end, },
				{szOption = g_tStrings.STR_HOTKEY_CANCEL, },
			}
			MessageBox(msg)
		end
	end
end

function DebuffSettingPanel.OpenPanel()
	if DebuffSettingPanel.IsPanelOpened() then
		return
	end
	local frame = Station.Lookup("Topmost/DebuffSettingPanel")
	if not frame then
		frame = Wnd.OpenWindow("Interface\\JH\\RaidGridEx\\DebuffSettingPanel.ini", "DebuffSettingPanel")
	end
	frame:Show()
end

function DebuffSettingPanel.ClosePanel()
	if not DebuffSettingPanel.IsPanelOpened() then
		return
	end
	local frame = DebuffSettingPanel.frameSelf or Station.Lookup("Topmost/DebuffSettingPanel")
	frame:Hide()
end

function DebuffSettingPanel.IsPanelOpened()
	local frame = DebuffSettingPanel.frameSelf or Station.Lookup("Topmost/DebuffSettingPanel")
	if frame and frame:IsVisible() then
		return true
	end
	return false
end