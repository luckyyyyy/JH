-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-04-19 05:07:47
local _L = JH.LoadLangPack
local TeamAD = {
	szDataFile = "TeamAD.jx3dat",
	szAD = _L["Edit AD"],
	tItem = {
		{
			{ dwTabType = 5, dwIndex = 6386, nUiId = 65944 },
			{ dwTabType = 5, dwIndex = 6376, nUiId = 65934 },
			{ dwTabType = 5, dwIndex = 6366, nUiId = 65924 },
			{ dwTabType = 5, dwIndex = 6356, nUiId = 65914 },
			{ dwTabType = 5, dwIndex = 6345, nUiId = 65903 },
			{ dwTabType = 5, dwIndex = 22084, nUiId = 150827 },
			{ dwTabType = 5, dwIndex = 22085, nUiId = 150828 },
			{ dwTabType = 5, dwIndex = 22086, nUiId = 150829 },
			{ dwTabType = 5, dwIndex = 22087, nUiId = 150830 },
			{ dwTabType = 5, dwIndex = 20522, nUiId = 72592 },
		},
		{
			{ dwTabType = 5, dwIndex = 3822, nUiId = 13909 },
			{ dwTabType = 5, dwIndex = 20522, nUiId = 72592 },
			{ dwTabType = 5, dwIndex = 6387, nUiId = 65945 },
			{ dwTabType = 5, dwIndex = 6377, nUiId = 65935 },
			{ dwTabType = 5, dwIndex = 6367, nUiId = 65925 },
			{ dwTabType = 5, dwIndex = 6357, nUiId = 65915 },
			{ dwTabType = 5, dwIndex = 6347, nUiId = 65905 },
			{ dwTabType = 5, dwIndex = 18575, nUiId = 71865 },
			{ dwTabType = 6, dwIndex = 8819, nUiId = 63192 },
			{ dwTabType = 5, dwIndex = 11916, nUiId = 69938 },
		}
	}
}
TeamAD.tADList = JH.LoadLUAData(TeamAD.szDataFile) or {}

TeamAD.SetEdit = function(edit,tab) -- 略奇葩 看不懂。。。 神经病一样的设置
	edit:ClearText()
	for kk,vv in ipairs(tab) do
		for kkk,vvv in ipairs(vv) do
			local text = "[link]"
			if vvv.text then text = vvv.text end
			edit:InsertObj(text,vvv)
		end
		if vv.text then
			edit:InsertObj(vv.text,vv)
		end
	end
end
TeamAD.PS = {}
TeamAD.PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["TeamAD"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndEdit","WndEditAD", { x = 10, y = 28,w = 500, h = 80,multi = true,limit = 164 }):Pos_()
	TeamAD.edit = ui:Fetch("WndEditAD").edit
	nX = ui:Append("WndButton2", { x = 10, y = nY + 10 })
	:Text(_L["Save AD"]):Click(function(bChecked)
		local ad = ui:Fetch("WndEditAD"):Text()
		local data = TeamAD.edit:GetTextStruct()
		GetUserInput(_L["Save Name"],function(txt)
			if #TeamAD.tADList == 18 then return end
			table.insert(TeamAD.tADList,{key = txt,txt = ad,ad = data})
			TeamAD.SetEdit(TeamAD.edit,data)
			JH.SaveLUAData(TeamAD.szDataFile,TeamAD.tADList)
			JH.OpenPanel(_L["TeamAD"])
		end,nil,nil,nil,nil,5)
	end):Pos_()
	nX = ui:Append("WndButton2", { x = nX + 10, y = nY + 10 })
	:Text(_L["push Edit"]):Click(function(bChecked)
		local ad = ui:Fetch("WndEditAD"):Text()
		local data = TeamAD.edit:GetTextStruct()
		local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
		TeamAD.SetEdit(edit,data)
		Station.SetFocusWindow(edit)
	end):Pos_()
	nX,nY = ui:Append("WndButton2", { x = nX + 10, y = nY + 10 })
	:Text(_L["Import"]):Click(function()
		local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
		TeamAD.SetEdit(TeamAD.edit,edit:GetTextStruct())
	end):Pos_()
	local t = TeamAD.tItem[1]
	if JH_About and JH_About.CheckNameEx() then
		t = TeamAD.tItem[2]
	end
	for k, v in ipairs(t) do
		if k % #t == 1 then nX = 10 end
		nX = ui:Append("Box", "iteminfolink", { x = nX + 12, y = nY + 5, w = 38, h = 38, icon = Table_GetItemIconID(v.nUiId)})
		:Click(function()
			this.nVersion = GLOBAL.CURRENT_ITEM_VERSION
			this.dwTabType = v.dwTabType
			this.dwIndex = v.dwIndex
			return OnItemLinkDown(this)
		end):Hover(function(bHover)
			if bHover then
				this:SetObjectMouseOver(true)
				local x, y = this:GetAbsPos()
				local w, h = this:GetSize()
				OutputItemTip(UI_OBJECT_ITEM_INFO,GLOBAL.CURRENT_ITEM_VERSION, v.dwTabType, v.dwIndex, {x, y, w, h})
			else
				this:SetObjectMouseOver(false)
				HideTip()
			end
		end):Pos_()
	end
	nY = nY + 48
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["AD List"], font = 27 }):Pos_()
	nY = nY - 10
	for k,v in ipairs(TeamAD.tADList) do
		if k % 4 == 1 then nX = 10 end
		nX = ui:Append("WndButton2", { x = nX + 15, y = nY + math.ceil(k/4) * 32 })
		:Text(v.key):Click(function()
			local txt = GUI(this):Text()
			if IsCtrlKeyDown() then
				table.remove(TeamAD.tADList,k)
				JH.SaveLUAData(TeamAD.szDataFile,TeamAD.tADList)
				JH.OpenPanel(_L["TeamAD"])
			else
				local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
				TeamAD.SetEdit(edit,v.ad)
				TeamAD.SetEdit(TeamAD.edit,v.ad)
				Station.SetFocusWindow(edit)
			end
		end):Pos_()
	end
end

GUI.RegisterPanel(_L["TeamAD"], 5958, g_tStrings.CHANNEL_CHANNEL, TeamAD.PS)
-- public
JH.TeamAD = {}
JH.TeamAD.SetEdit = TeamAD.SetEdit
