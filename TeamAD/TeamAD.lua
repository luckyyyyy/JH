-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-10-29 23:42:32
local _L = JH.LoadLangPack
local Advertising = {
	szDataFile = "TeamAD.jx3dat",
	tItem = {
		{ dwTabType = 5, dwIndex = 24430, nUiId = 153192 },
		{ dwTabType = 5, dwIndex = 23988, nUiId = 152748 },
		{ dwTabType = 5, dwIndex = 23841, nUiId = 152596 },
		{ dwTabType = 5, dwIndex = 22939, nUiId = 151677 },
		{ dwTabType = 5, dwIndex = 23759, nUiId = 152512 },
		{ dwTabType = 5, dwIndex = 22084, nUiId = 150827 },
		{ dwTabType = 5, dwIndex = 22085, nUiId = 150828 },
		{ dwTabType = 5, dwIndex = 22086, nUiId = 150829 },
		{ dwTabType = 5, dwIndex = 22087, nUiId = 150830 },
		{ dwTabType = 5, dwIndex = 25831, nUiId = 153898 },
	}
}


function Advertising.SetEdit(edit, tab)
	edit:ClearText()
	for k, v in ipairs(tab) do
		if v.text then
			if v.type == "text" then
				edit:InsertText(v.text)
			else
				edit:InsertObj(v.text, v)
			end
		end
	end
end

local PS = {}
function PS.OnPanelActive(frame)
	Advertising.tADList = JH.LoadLUAData(Advertising.szDataFile) or {}
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Save Talk"], font = 27 }):Pos_()
	nX = ui:Append("WndButton2", { x = 10, y = nY + 10, txt = _L["Save Advertising"] }):Click(function(bChecked)
		local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
		local txt, data = edit:GetText(), edit:GetTextStruct()
		if JH.Trim(txt) == "" then
			JH.Alert(_L["Chat box is empty"])
		else
			GetUserInput(_L["Save Advertising Name"],function(text)
				table.insert(Advertising.tADList, { key = text, txt = txt, ad = data })
				JH.SaveLUAData(Advertising.szDataFile, Advertising.tADList, "\t")
				JH.OpenPanel(_L["Save Talk"])
			end, nil, nil, nil, nil, 5)
		end
	end):Pos_()
	nX, nY = ui:Append("Text", { x = nX + 5, y = nY + 10, txt = _L["Advertising Tips"] }):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY + 5, txt = _L["Gadgets"], font = 27 }):Pos_()
	for k, v in ipairs(Advertising.tItem) do
		nX = ui:Append("Box", { x = (k - 1) * 48 + 10, y = nY + 10, w = 38, h = 38 }):ItemInfo(GLOBAL.CURRENT_ITEM_VERSION, v.dwTabType, v.dwIndex):Pos_()
	end
	nX, nY = ui:Append("Text", { x = 0, y = nY + 53, txt = _L["Advertising List"], font = 27 }):Pos_()
	nY = nY - 10
	for k,v in ipairs(Advertising.tADList) do
		if k % 4 == 1 then nX = 10 end
		nX = ui:Append("WndButton2", { x = nX + 15, y = nY + math.ceil(k/4) * 32, txt = v.key })
		:Click(function()
			local txt = GUI(this):Text()
			if IsCtrlKeyDown() then
				table.remove(Advertising.tADList, k)
				JH.SaveLUAData(Advertising.szDataFile, Advertising.tADList, "\t")
				JH.OpenPanel(_L["Save Talk"])
			else
				local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
				Advertising.SetEdit(edit, v.ad)
				Station.SetFocusWindow(edit)
			end
		end):Pos_()
	end
end

GUI.RegisterPanel(_L["Save Talk"], 5958, g_tStrings.CHANNEL_CHANNEL, PS)
-- public
JH.TeamAD = {}
JH.TeamAD.SetEdit = Advertising.SetEdit
