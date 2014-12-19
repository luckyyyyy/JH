FA = {}

local _FA = {
	szTitle = "面向配置",
	tLastIten = {
		["Handle"] = {},
		["Item"] = {},		
	},
	Append = {},
	tDrag = {},
	tScroll = {},
	nClass = -1,
	nIndex = -1,
	tData = {},
	tSearchTemp = {},
}
----------------------------------------------
-- 打开关闭面板
----------------------------------------------
_FA.GetFrame = function()
	return Station.Lookup("Normal/FA")
end
_FA.OpenPanel = function()
	_FA.GetFrame():BringToTop()
	_FA.GetFrame():Show()
	Station.SetActiveFrame(_FA.GetFrame())
end
_FA.ClosePanel = function()
	_FA.GetFrame():Hide()
	PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
end
_FA.TogglePanel = function()
	if _FA.GetFrame() and _FA.GetFrame():IsVisible() then
		_FA.ClosePanel()
	else
		_FA.OpenPanel()
	end
end

----------------------------------------------
-- 常用控件获取和输出
----------------------------------------------
_FA.ReadWndEdit = function(szName,nVal)
	local item = _FA.GetFrame():Lookup(szName):Lookup("Edit_Default")
	if nVal then
		item:SetText(nVal)
	else
		return tonumber(item:GetText())
	end
end

_FA.ReadCheckBox = function(szName,bVal)
	local item = _FA.GetFrame():Lookup(szName)
	if bVal == nil then
		return item:IsCheckBoxChecked()
	else
		item:Check(bVal)
	end
end

_FA.ReadColor = function(szName,col)
	local item = _FA.GetFrame():Lookup("",szName)
	if col then
		local r,g,b = unpack(col)
		item:SetColorRGB(r,g,b)
	else
		local r,g,b = item:GetColorRGB()
		return {r,g,b}
	end
end

_FA.ReadTitle = function(szText,szDescription)
	local item = _FA.GetFrame():Lookup("","Handle_Left"):Lookup("Text_LeftTitle")
	local title = _FA.GetFrame():Lookup("","Text_Title")
	if szText then
		item:SetText(szText)
		if szDescription then
			local txt = _FA.szTitle .. " - " .. szDescription
			title:SetText(txt)
		else
			title:SetText(_FA.szTitle)
		end
		
	else
		return item:GetText()
	end
end

_FA.ReadIndex = function()
	_FA.GetFrame():Lookup("","Text_Index"):SetText(_FA.nIndex)
end

----------------------------------------------
-- 各类事件
-- 窗体创建事件 OnFrameCreate
----------------------------------------------
function FA.OnFrameCreate()
	local ui = GUI(this)
	ui:Append("WndCheckBox", "Chk_ShowAngle", { x = 46, y = 64, txt = "面向圈" })
	ui:Append("WndCheckBox", "Chk_ShowCircle", { x = 130, y = 64, txt = "距离圈" })
	ui:Append("WndEdit", "Edt_aRadius", { x = 68, y = 117, w = 40, h = 21 })
	ui:Append("WndEdit", "Edt_aAngle", { x = 68, y = 142, w = 40, h = 21 })
	ui:Append("WndEdit", "Edt_aAlpha", { x = 68, y = 167, w = 40, h = 21 })
	ui:Append("WndEdit", "Edt_cRadius", { x = 150, y = 117, w = 40, h = 21 })
	
	ui:Append("WndEdit", "Edt_cAngle", { x = 150, y = 142, w = 40, h = 21 })
	ui:Append("WndEdit", "Edt_cAlpha", { x = 150, y = 167, w = 40, h = 21 })
	ui:Append("WndEdit", "Edt_Search", { x = 515, y = 5, w = 150, h = 21, txt = "Search..." })
	:Change(_FA.Search):Focus(function()
		this:SetText("")
	end,function()
		this:SetText("Search...")
		_FA.tSearchTemp = {}
	end)
	ui:Append("WndCheckBox", "Chk_Enable", { x = 216, y = 64, txt = "启用", font = 65 })
	ui:Append("WndCheckBox", "Chk_ShowName", { x = 216, y = 90, txt = "显示名字" })
	ui:Append("WndCheckBox", "Chk_ShowTarget", { x = 216, y = 115, txt = "监控目标" })
	ui:Point():Title(_FA.szTitle)
	_FA.LoadDataPanel(false)
end

----------------------------------------------
-- 各类事件 OnLButtonClick 鼠标点击 回调函数
----------------------------------------------
function FA.OnItemLButtonClick()
	local szName = this:GetName()
	local fnAction = {
		Shadow_AngleColor = _FA.Button_ChangeAngleColor,
		Shadow_CircleColor = _FA.Button_ChangeCircleColor,
		Image_Checked = _FA.Click_Image_Checked,
		Image_Check = _FA.Click_Image_Check,
	}
	if fnAction[szName] then
		fnAction[szName]()
	end
	
	if szName:match("^Handle_Item_") then
		_FA.Click_Handle_Item()
	end
end

function FA.OnLButtonClick()
	local szName = this:GetName()
	local fnAction = {
		Button_Close = _FA.ClosePanel,
		Button_ReName = _FA.Button_ReName,
		Button_Setting = _FA.Button_Setting,
		Button_More = _FA.Button_More,
		Button_Option = _FA.Button_Option,
		Button_Sync = _FA.Button_Sync,
		Button_Delete = _FA.Button_Delete,
		Button_Pre = _FA.Button_Pre,
		Button_Next = _FA.Button_Next,
		Button_Up = _FA.Button_Up,
		Button_Down = _FA.Button_Down,
		Button_AddClass = _FA.Button_AddClass,
	}
	if fnAction[szName] then
		fnAction[szName]()
	end
end

function FA.OnItemRButtonClick()
	local nID = this.nID
	local tab,data,szType
	data = BossFaceAlert.DrawFaceLineNames
	tab = BossFaceAlert.FaceClassNameInfo
	szType = "DrawFaceLineNames"

	if this.szType == "Class" and this.nID > 0 then
		local r,g,b = 255,255,255
		if tab[nID].tMenuColor then
			r, g, b = tab[nID].tMenuColor.r, tab[nID].tMenuColor.g, tab[nID].tMenuColor.b
		end
		local t = {
			{szOption = tostring(nID) .. " - " .. tab[nID].szName,bDisable = true},
			{szOption = "☆修改名字☆",rgb = {r,g,b},bColorTable = true,fnAction = function()
					local fcAction = function(szText)
						if not szText or szText == "" then
							return
						end
						tab[nID].szName = szText
						_FA.LoadDataPanel(false, nil, true)
					end
					GetUserInput("输入新名字：", fcAction, nil,nil, nil, tab[nID].szName)
				end,
				fnChangeColor = function(UserData, r, g, b)
					tab[nID].tMenuColor = {}
					tab[nID].tMenuColor.r = r
					tab[nID].tMenuColor.g = g
					tab[nID].tMenuColor.b = b
					_FA.LoadDataPanel(false, nil, true)
				end,
			},
			{bDevide = true},
			{szOption = "上移此分类", bDisable = not tab[nID - 1], fnAction = function()
					for iUp = #data, 1, -1 do
						if data[iUp].nFaceClass then
							if data[iUp].nFaceClass == nID then
								data[iUp].nFaceClass = data[iUp].nFaceClass - 1
							elseif data[iUp].nFaceClass == nID - 1 then
								data[iUp].nFaceClass = data[iUp].nFaceClass + 1
							end
						end
					end
					tab[nID], tab[nID - 1] = tab[nID - 1], tab[nID]
					_FA.LoadDataPanel(false, nil, true)
				end,
			},
			{szOption = "下移此分类", bDisable = not tab[nID + 1], fnAction = function()
					for iDown = #data, 1, -1 do
						if data[iDown].nFaceClass then
							if data[iDown].nFaceClass == nID then
								data[iDown].nFaceClass = data[iDown].nFaceClass + 1
							elseif data[iDown].nFaceClass == nID + 1 then
								data[iDown].nFaceClass = data[iDown].nFaceClass - 1
							end
						end
					end
					tab[nID], tab[nID + 1] = tab[nID + 1], tab[nID]
					_FA.LoadDataPanel(false, nil, true)
				end,
			},
			
			{bDevide = true},
			{szOption = "删除分类和数据",
				rgb = {255,0,0,},
				fnAction = function()	
					JH.Confirm("你确定要删除 ".. tab[nID].szName .." 以及该分类下面的数据么？", function() 
						for i = #data, 1, -1 do
							if data[i].nFaceClass then
								if data[i].nFaceClass == nID then
									table.remove(data, i)
								elseif data[i].nFaceClass > nID and data[i].nFaceClass <= #tab then
									data[i].nFaceClass = data[i].nFaceClass - 1
								end
							end
						end
						table.remove(tab, nID)
						if _FA.tData.nFaceClass == nID then
							_FA.ClearPanel()
						elseif _FA.nClass == nID then
							_FA.LoadDataPanel(false, -2, true)
						else
							_FA.LoadDataPanel(false , nil, true)
						end
						BFA.Init()
					end)
				end
			}
		}
		PopupMenu(t)
	elseif this.szType == "Data" then
		local fnAction = function()
			table.remove(data, nID)
			_FA.ClearPanel(true)
			BFA.Init()
			_FA.LoadDataPanel(nil,_FA.nClass,true)
		end
		local t = {
			{szOption = tostring(nID) .. " - " .. data[nID].szName,bDisable = true},
			{bDevide = true},
			{szOption = "☆修改名字☆",fnAction = function()
					local fcAction = function(szText)
						if not szText or szText == "" then
							return
						end
						for i = 1, #data do
							if tostring(data[i].szName) == tostring(szText) then
								return JH.Sysmsg("修改失败，["..szText.."]已存在！")
							end
						end
						data[nID].szName = szText
						if _FA.nIndex == nID then
							_FA.LoadAndSaveData(_FA.tData)
						end
						BFA.Init()
						_FA.LoadDataPanel(nil,_FA.nClass,true)
					end
					GetUserInput("输入新名字：", fcAction,nil,nil,nil,data[nID].szName)
				end
			},
			{bDevide = true},
			RaidGrid_EventScrutiny.SyncOptions(data[nID],szType),
			{bDevide = true},
			{szOption = "删除",rgb = {255,0,0},fnAction = fnAction}
		}
		PopupMenu(t)
	end
end


function FA.OnItemLButtonUp()
	if this.szType == "Data" and _FA.tDrag.bOn then -- 拖动结束
		_FA.tDrag.kItem:Hide()
		if _FA.tDrag.nNewClass then
			if _FA.tDrag.nNewClass == 0 then
				_FA.tDrag.nNewClass = nil
			end
			BossFaceAlert.DrawFaceLineNames[_FA.tDrag.nIndex].nFaceClass = _FA.tDrag.nNewClass
			_FA.LoadDataPanel(false , _FA.nClass, true)
		end
		_FA.tDrag = {}
	end
end

----------------------------------------------
-- 各类事件 拖动开始 原理是鼠标弹起后结束，获取最后一次 MouseEnter  
----------------------------------------------
function FA.OnItemLButtonDrag()
	if this.szType == "Data" then
		_FA.tDrag.bOn = true
		_FA.tDrag.nIndex = this.nID
		_FA.tDrag.kItem = this:Lookup("Handle_CMNormal")
		_FA.tDrag.kItem:Show()
		_FA.tDrag.kItem:Lookup("Text_CMNormal"):SetText("可以拖动到分类")
	end
end

_FA.Search = function()
	if this:GetText() ~= "" then
		local data = BossFaceAlert.DrawFaceLineNames
		_FA.tSearchTemp = { nIndex = 1,tTemp = {},data = data }
		-- 首先返回名字
		for i = 1, #data, 1 do
			if tostring(data[i].szName) == tostring(this:GetText()) then
				table.insert(_FA.tSearchTemp.tTemp,i)
			end
		end
		-- 没有的话返回备注
		for i = 1, #data, 1 do
			if data[i].szDescription and tostring(data[i].szDescription):match(tostring(this:GetText())) then
				table.insert(_FA.tSearchTemp.tTemp,i)
			end
		end
		-- 没有名字返回包含的
		for i = 1, #data, 1 do
			if tostring(data[i].szName):match(tostring(this:GetText())) then
				table.insert(_FA.tSearchTemp.tTemp,i)
			end
		end
		if not IsEmpty(_FA.tSearchTemp.tTemp) then
			_FA.nIndex = _FA.tSearchTemp.tTemp[1]
			_FA.tData = data[_FA.nIndex]
			-- local txt = FormatString("Among all the searching results, there are <D0> records in total containing the <D1>. You can switch the serching results with the Up Arrow and Down Arrow keys on the keyboard. ...",#_FA.tSearchTemp.tTemp,this:GetText())
			-- _FA.GetFrame():Lookup("","Handle_Text"):Lookup("Text_AD2"):SetText(txt)
			return _FA.LoadAndSaveData(_FA.tData)
		else
			_FA.tSearchTemp ={}
		end
	end
end
----------------------------------------------
-- 各类事件 键盘事件 自动保存和关闭
----------------------------------------------
function FA.OnEditChanged()
	if _FA.nIndex >= 0 then
		local frame = _FA.GetFrame()
		if frame:IsVisible() and not _FA.LoadData then
			_FA.LoadAndSaveData(_FA.tData,true)
		end
	end
end

function FA.OnFrameKeyDown()
	if GetKeyName(Station.GetMessageKey()) == "Esc" then
		_FA.ClosePanel()
		return 1
	elseif GetKeyName(Station.GetMessageKey()) == "Up" or GetKeyName(Station.GetMessageKey()) == "Down" then
		if GetKeyName(Station.GetMessageKey()) == "Up" and not IsEmpty(_FA.tSearchTemp.tTemp) then
			_FA.tSearchTemp.nIndex = _FA.tSearchTemp.nIndex + 1
			if _FA.tSearchTemp.nIndex > #_FA.tSearchTemp.tTemp then
				_FA.tSearchTemp.nIndex = 1
			end
			_FA.nIndex = _FA.tSearchTemp.tTemp[_FA.tSearchTemp.nIndex]
			_FA.tData = _FA.tSearchTemp.data[_FA.nIndex]
			return _FA.LoadAndSaveData(_FA.tData)
		elseif GetKeyName(Station.GetMessageKey()) == "Down" and not IsEmpty(_FA.tSearchTemp.tTemp) then
			_FA.tSearchTemp.nIndex = _FA.tSearchTemp.nIndex - 1
			if _FA.tSearchTemp.nIndex < 1 then
				_FA.tSearchTemp.nIndex = #_FA.tSearchTemp.tTemp
			end
			_FA.nIndex = _FA.tSearchTemp.tTemp[_FA.tSearchTemp.nIndex]
			_FA.tData = _FA.tSearchTemp.data[_FA.nIndex]
			return _FA.LoadAndSaveData(_FA.tData)
		end
	end
end

----------------------------------------------
-- 各类事件 OnMouse 拖拽逻辑
----------------------------------------------

function FA.OnMouseEnter()
	local szName = this:GetName()
	if szName then
		_FA.MenuTip(this,szName)
	end
end

function FA.OnMouseLeave()
	HideTip()
end

function FA.OnItemMouseEnter()
	HideTip()
	local szName = this:GetName()
	if szName:match("^Handle_List_") or szName:match("^Handle_Item_") then
		local szType = szName:match("Handle_List_(.*)") or szName:match("Handle_Item_(.*)_.*")
		local handle = _FA.GetFrame():Lookup("","Handle_Main"):Lookup("Handle_List_"..szType)
		local scroll = handle:GetRoot():Lookup("Scroll_List_"..szType)
		scroll:Lookup("Btn_Scroll_"..szType):SetAlpha(140)
	end
	if szName:match("^Handle_Item_") then
		if this:Lookup("Image_CoverBg") then
			this:Lookup("Image_CoverBg"):Show()
		end
	end
	if this.szType == "Data" then
		local data =  BossFaceAlert.DrawFaceLineNames
		local txt = "Key："..data[this.nID].szName
		if data[this.nID].szDescription then
			txt = txt .. "\n描述："..data[this.nID].szDescription
		end
		_FA.MenuTip(this,true,txt)
	---------------------拖拽部分---------------------------
		if _FA.tDrag.bOn then
			if _FA.tDrag.tLastItem then
				_FA.tDrag.tLastItem:Hide()
			end
			_FA.tDrag.nNewClass = nil
		end
	end
	if this.szType == "Class" then
		if this.nID > 0 then
			local data =  BossFaceAlert.DrawFaceLineNames
			local _ = 0
			for i = 1 , #data do
				if data[i].nFaceClass == this.nID then
					_ = _ + 1
				end
			end
			local txt = "分类："..this:Lookup("Title_Text"):GetText().."\n包含：".. _ .." 个数据"
			_FA.MenuTip(this,true,txt)
		end

	---------------------拖拽部分---------------------------
		if _FA.tDrag.bOn and this.nID >= 0 then
			if _FA.tDrag.tLastItem then
				_FA.tDrag.tLastItem:Hide()
			end
			_FA.tDrag.tLastItem = this:Lookup("Handle_CMNormal")
			_FA.tDrag.tLastItem:Show()
			_FA.tDrag.nNewClass = this.nID
		end
	end
end

function FA.OnItemMouseLeave()
	local szName = this:GetName()
	if szName:match("^Handle_List_") or szName:match("^Handle_Item_") then
		local szType = szName:match("Handle_List_(.*)") or szName:match("Handle_Item_(.*)_.*")
		local handle = _FA.GetFrame():Lookup("","Handle_Main"):Lookup("Handle_List_"..szType)
		local scroll = handle:GetRoot():Lookup("Scroll_List_"..szType)
		scroll:Lookup("Btn_Scroll_"..szType):SetAlpha(60)
	end
	if szName:match("^Handle_Item_") then
		if this:Lookup("Image_CoverBg") then
			this:Lookup("Image_CoverBg"):Hide()
		end
	end
end

_FA.MenuTip = function(hItem,index,text)
	if not hItem then return end
	local x, y = hItem:GetAbsPos()
	local w, h = hItem:GetSize()
	if index then
		local val
		if text then val = text end
		if val then
			local szTip = "<text>text=" ..EncodeComponentsString(val).." font=47 r=255 g=200 b=255 </text>"
			OutputTip(szTip, 435, {x, y, w, h})
		end
	end
end

----------------------------------------------
-- 各类事件 OnCheckBox
----------------------------------------------

function FA.OnCheckBoxCheck()
	if _FA.nIndex >= 0 then
		local frame = _FA.GetFrame()
		if frame:IsVisible() and not _FA.LoadData then
			_FA.LoadAndSaveData(_FA.tData,true)
			BossFaceAlert.ClearAllItem()
		end
	end
end

function FA.OnCheckBoxUncheck()
	if _FA.nIndex >= 0 then
		local frame = _FA.GetFrame()
		if frame:IsVisible() and not _FA.LoadData then
			_FA.LoadAndSaveData(_FA.tData,true)
			BossFaceAlert.ClearAllItem()
		end
	end
end

----------------------------------------------
-- 鼠标滚轮和拖动事件
----------------------------------------------
function FA.OnItemMouseWheel()
	if this:GetName():match("^Handle_List_") then
		local szType = this:GetName():match("Handle_List_(.*)")
		local scroll = _FA.GetFrame():Lookup("Scroll_List_"..szType)
		if scroll:IsVisible() then
			local nStep = Station.GetMessageWheelDelta()
			nStep = nStep * 3
			scroll:ScrollNext(nStep)
			return true
		end
	end
end

function FA.OnScrollBarPosChanged()
	if this:GetName():match("^Scroll_List_") then
		local szType = this:GetName():match("Scroll_List_(.*)")
		local nCurrentValue = this:GetScrollPos()
		local frame = this:GetParent()
		local handle = frame:Lookup("","Handle_Main"):Lookup("Handle_List_"..szType)
		handle:SetItemStartRelPos(0, - nCurrentValue * 10)
	end
end

----------------------------------------------
-- 重置面板
----------------------------------------------
_FA.ClearPanel = function(bNotClear)
	local aFrame = _FA.GetFrame()
	_FA.nIndex = -1
	_FA.tData = {}
	_FA.ReadColor("Shadow_AngleColor",{0,0,0})
	_FA.ReadColor("Shadow_CircleColor",{0,0,0})
	
	_FA.ReadWndEdit("Edt_aRadius","")
	_FA.ReadWndEdit("Edt_aAngle","")
	_FA.ReadWndEdit("Edt_aAlpha","")
	
	
	_FA.ReadWndEdit("Edt_cRadius","")
	_FA.ReadWndEdit("Edt_cAngle","")
	_FA.ReadWndEdit("Edt_cAlpha","")
	
	_FA.ReadCheckBox("Chk_ShowAngle",false)
	_FA.ReadCheckBox("Chk_ShowCircle",false)
	_FA.ReadCheckBox("Chk_Enable",false)
	_FA.ReadCheckBox("Chk_ShowName",false)
	_FA.ReadCheckBox("Chk_ShowTarget",false)
	aFrame:Lookup("","Text_Index"):SetText("0")
	_FA.ReadTitle("名称")
	if not bNotClear then
		_FA.LoadDataPanel(false, -2)
	end
end
----------------------------------------------
-- 按钮点击 添加新分类
----------------------------------------------
_FA.Button_AddClass = function()
	local tab = BossFaceAlert.FaceClassNameInfo

	GetUserInput("输入分类名称：", function(szText)
		if not szText or szText == "" then
			return
		end
		table.insert(tab,{szName = szText, bOn = true})
		_FA.LoadDataPanel(false, nil, true)
	end)
end

----------------------------------------------
-- 按钮点击 设置按钮
----------------------------------------------
_FA.Button_Setting = function()
	local tOptions = BossFaceAlert.GetMenuList()
	PopupMenu(tOptions)
end
----------------------------------------------
-- 按钮点击 共享数据
----------------------------------------------
_FA.Button_Sync = function()
	if _FA.nIndex > 0 then
		if GetClientPlayer().IsInParty() then
			local szType = "DrawFaceLineNames"
			PopupMenu(RaidGrid_EventScrutiny.SyncOptions(_FA.tData,szType))
		else
			JH.Sysmsg("不在队伍中")
		end
	end
end
----------------------------------------------
-- 按钮点击 添加按钮
----------------------------------------------
_FA.Button_More = function()
	local t = {szOption = "PopupMenu",
		{szOption = "新建NPC监控数据", fnAction = function()
			GetUserInput("输入NPC名称或模板ID", function(szText) 
				BFA.AddScrutiny(szText)
			end)
		end},
		{szOption = "新建Doodad监控数据", fnAction = function()
			GetUserInput("输入Doodad名称", function(szText) 
				BFA.AddScrutiny(szText,TARGET.DOODAD)
			end)
		end},
		-- {bDevide = true},
		-- {szOption = "当前位置添加自定义圈", fnAction = function()
			-- GetUserInput("自定义圈名字：", function(szText) BossFaceAlert.AddPoint(szText) end, nil, nil,nil,GetCurrentTime())
		-- end},
	}
	PopupMenu(t)
end
----------------------------------------------
-- 按钮点击 点击名称
----------------------------------------------
_FA.Button_ReName = function()
	if _FA.nIndex > 0 then
		local tab = BossFaceAlert.DrawFaceLineNames
		local t = {szOption = "PopupMenu",
			{szOption = "修改名称或ID", fnAction = function()
				GetUserInput("请输入新的监控名称或模板ID", function(szText)
					for i = 1, #tab, 1 do
						if tostring(tab[i].szName) == tostring(szText) then
							return JH.Sysmsg("修改失败，["..szText.."]已存在！")
						end
					end
					_FA.tData.szName = szText
					_FA.ReadTitle(_FA.tData.szName,_FA.tData.szDescription)
					BFA.Init()
					_FA.LoadDataPanel(nil,_FA.nClass,true)
				end,nil,nil,nil,_FA.tData.szName)
			end},
			{bDevide = true},
			{szOption = "修改描述信息", fnAction = function()
				GetUserInput("请输入新的描述信息", function(szText)
					_FA.tData.szDescription = szText
					if szText == "" then
						_FA.tData.szDescription = nil
					end
					_FA.ReadTitle(_FA.tData.szName,_FA.tData.szDescription)
				end, nil, nil,nil,_FA.tData.szDescription)
			end},
		}
		PopupMenu(t)
	end
end
----------------------------------------------
-- 按钮点击 删除按钮
----------------------------------------------
_FA.Button_Delete = function()
	if _FA.nIndex > 0 then
		local tab = BossFaceAlert.DrawFaceLineNames
		local fnAction = function()
			table.remove(tab, _FA.nIndex)
			if #tab == 0 then
				_FA.ClearPanel()
			elseif _FA.nIndex == 1 then
				_FA.Button_Pre(true)
			else
				_FA.Button_Pre()
			end
			BFA.Init()
			_FA.LoadDataPanel(nil,_FA.nClass,true)
		end
		if IsAltKeyDown() then
			fnAction()
		else
			local t = {{szOption = "删除此数据",rgb = {255,0,0},fnAction = fnAction}}
			PopupMenu(t)
		end
	end
end

----------------------------------------------
-- 按钮点击 前进后退数据
----------------------------------------------
_FA.Button_Pre = function(bReload)
	if _FA.nIndex > 0 then
		local tab = BossFaceAlert.DrawFaceLineNames
		if bReload then
			_FA.tData = tab[_FA.nIndex]
			_FA.LoadAndSaveData(_FA.tData)
		else
			if _FA.nIndex - 1 < 1 then
				JH.Sysmsg("已经到最前一项了。")
			else
				_FA.nIndex = _FA.nIndex - 1
				_FA.tData = tab[_FA.nIndex]
				_FA.LoadAndSaveData(_FA.tData)
			end
		end
	end
end

_FA.Button_Next = function()
	if _FA.nIndex > 0 then
		local tab = BossFaceAlert.DrawFaceLineNames
		if _FA.nIndex + 1 > #tab then
			JH.Sysmsg("已经到最后一项了。")
		else
			_FA.nIndex = _FA.nIndex + 1
			_FA.tData = tab[_FA.nIndex]
			_FA.LoadAndSaveData(_FA.tData)
		end
	end
end

_FA.Button_Up = function()
	if _FA.nIndex > 0 then
		local tab = BossFaceAlert.DrawFaceLineNames
		local nCount = 1
		if IsAltKeyDown() then
			nCount = 10
		end
		if _FA.nIndex - nCount < 1 then
			JH.Sysmsg("不能再往前移了")
		else
			for i = _FA.nIndex, math.max(2, _FA.nIndex - nCount + 1), -1 do
				tab[i], tab[i - 1] = tab[i - 1], tab[i]
			end
			_FA.nIndex = _FA.nIndex - nCount
			_FA.LoadAndSaveData(_FA.tData)
			BFA.Init()
			_FA.LoadDataPanel(nil,_FA.nClass,true)
		end
	end
end
_FA.Button_Down = function()
	if _FA.nIndex > 0 then
		local tab = BossFaceAlert.DrawFaceLineNames
		local nCount = 1
		if IsAltKeyDown() then
			nCount = 10
		end
		if _FA.nIndex + nCount > #tab then
			JH.Sysmsg("不能再往后移了。")
		else
			for i = _FA.nIndex, math.min(#tab - 1, _FA.nIndex + nCount - 1) do
				tab[i], tab[i + 1] = tab[i + 1], tab[i]
			end
			_FA.nIndex = _FA.nIndex + nCount
			_FA.LoadAndSaveData(_FA.tData)
			BFA.Init()
			_FA.LoadDataPanel(nil,_FA.nClass,true)
		end
	end
end

----------------------------------------------
-- 按钮点击 更多设置
----------------------------------------------
_FA.Button_Option = function()
	if _FA.nIndex >= 0 then
		local tOptions = _FA.GetRecordMenuList()
		local nX, nY = Cursor.GetPos(true)
		tOptions.x, tOptions.y = nX + 15, nY + 15
		PopupMenu(tOptions)
	end
end

_FA.GetRecordMenuList = function()
	local tMenu = {
		{szOption = "◆显示距离自己的尺数",bDisable = not _FA.tData.bShowNPCSelfName,bCheck = true,bChecked = _FA.tData.bShowNPCDistance or false,fnAction = function()
				_FA.tData.bShowNPCDistance = not _FA.tData.bShowNPCDistance
		end},
		{szOption = "◆以注释代替该项监控的名字",bDisable = not _FA.tData.bShowNPCSelfName,bCheck = true,bChecked = _FA.tData.bShowDescriptionName or false,fnAction = function()
				_FA.tData.bShowDescriptionName = not _FA.tData.bShowDescriptionName
		end},
		{bDevide = true},
		{szOption = "◆此项目标监控不密聊报警",bDisable = _FA.tData.bNotShowTargetName,bCheck = true,bChecked = _FA.tData.bNotSendWhisperMsg or false,fnAction = function()
				_FA.tData.bNotSendWhisperMsg = not _FA.tData.bNotSendWhisperMsg
		end},
		{szOption = "◆此项目标监控不团队报警",bDisable = _FA.tData.bNotShowTargetName,bCheck = true,bChecked = _FA.tData.bNotSendRaidMsg or false,fnAction = function()
				_FA.tData.bNotSendRaidMsg = not _FA.tData.bNotSendRaidMsg
		end},
		{szOption = "◆此项注视不全屏泛光提示",bDisable = _FA.tData.bNotShowTargetName,bCheck = true,bChecked = _FA.tData.bNotFlashRedAlarm or false,fnAction = function()
				_FA.tData.bNotFlashRedAlarm = not _FA.tData.bNotFlashRedAlarm
		end},
		{szOption = "◆此项注视不中央文字提示",bDisable = _FA.tData.bNotShowTargetName,bCheck = true,bChecked = _FA.tData.bNotOtherFlash or false,fnAction = function()
				_FA.tData.bNotOtherFlash = not _FA.tData.bNotOtherFlash
		end},
		{szOption = "◆目标非自己时不画追踪线",bDisable = _FA.tData.bNotShowTargetName,bCheck = true,bChecked = _FA.tData.bNotTargetLine or false,fnAction = function()
				_FA.tData.bNotTargetLine = not _FA.tData.bNotTargetLine
		end},
		{szOption = "◆被注视队友头顶特效报警",bDisable = _FA.tData.bNotShowTargetName,bCheck = true,bChecked = _FA.tData.bTimerHeadEnable or false,fnAction = function()
				_FA.tData.bTimerHeadEnable = not _FA.tData.bTimerHeadEnable
		end},		{bDevide = true},
		{szOption = "样式选择",
			{szOption='面向圈渐变（颜色取决于距离圈）',bCheck = true,bChecked = _FA.tData.bGradient,fnAction = function() _FA.tData.bGradient = not _FA.tData.bGradient end},
			{bDevide = true},
			{szOption='默认（中心透明减半）',bMCheck = true,bChecked =_FA.tData.nStyle == 0 or nil,fnAction = function() _FA.tData.nStyle = 0 end},
			{szOption='距离圈中心透明，面向圈中心透明',bMCheck = true,bChecked = _FA.tData.nStyle == 1,fnAction = function() _FA.tData.nStyle = 1 end},
			{szOption='距离圈边缘透明，面向圈边缘透明',bMCheck = true,bChecked = _FA.tData.nStyle == 2,fnAction = function() _FA.tData.nStyle = 2 end},
			{szOption='距离圈边缘透明，面向圈中心透明',bMCheck = true,bChecked = _FA.tData.nStyle == 3,fnAction = function() _FA.tData.nStyle = 3 end},
		},
		{bDevide = true},
		{szOption = "导出信息（按住Alt可导出）", fnAction = function()
			RaidGrid_Base.OutputRecord(_FA.tData,"DrawFaceLineNames")
		end},
	}
	if _FA.tData.szName == "Target" then
		table.insert(tMenu,{szOption = "仅显示敌对目标的面向",bCheck = true,bChecked = _FA.tData.bShowEnemyCircleOnly or false,fnAction = function()
			_FA.tData.bShowEnemyCircleOnly = not _FA.tData.bShowEnemyCircleOnly
		end,})
	end
	
	return tMenu
end

----------------------------------------------
-- 按钮点击 面向圈颜色
----------------------------------------------

_FA.Button_ChangeAngleColor = function()
	if _FA.nIndex >= 0 then
		OpenColorTablePanel(function(r, g, b)
			_FA.ReadColor("Shadow_AngleColor",{r,g,b})
			_FA.tData.tColor.r, _FA.tData.tColor.g, _FA.tData.tColor.b = r, g, b
		end,nil,nil,{
			{ r = 0, g = 255, b = 0},
			{ r = 0, g = 255, b = 255},
			{ r = 255, g = 0, b = 0},
			{ r = 40, g = 140, b = 218},
			{ r = 211, g = 229, b = 37},
			{ r = 65, g = 50, b = 160},
			{ r = 170, g = 65, b = 180},
			{ r = 255, g = 255, b = 255},
		})
	end
end
_FA.Button_ChangeCircleColor = function()
	if _FA.nIndex >= 0 then
		OpenColorTablePanel(function(r, g, b)
			_FA.ReadColor("Shadow_CircleColor",{r,g,b})
			_FA.tData.tColor2.r, _FA.tData.tColor2.g, _FA.tData.tColor2.b = r, g, b
		end,nil,nil,{
			{ r = 0, g = 255, b = 0},
			{ r = 0, g = 255, b = 255},
			{ r = 255, g = 0, b = 0},
			{ r = 40, g = 140, b = 218},
			{ r = 211, g = 229, b = 37},
			{ r = 65, g = 50, b = 160},
			{ r = 170, g = 65, b = 180},
			{ r = 255, g = 255, b = 255},
		})
	end
end

----------------------------------
-- 设置 获取和保存读取面板操作方法
----------------------------------

_FA.LoadLastData = function(tab)
	_FA.nIndex = #tab
	if _FA.nIndex < 1 then
		_FA.tData = {}
		_FA.ClearPanel()
	else
		_FA.tData = tab[_FA.nIndex]
		_FA.LoadAndSaveData(_FA.tData)
	end
end

_FA.LoadAndSaveData = function(tData,bSave,nIndex)
	if not tData then
		_FA.nIndex = 0
		_FA.tData = BossFaceAlert.tDefaultSetForAdd
		tData = _FA.tData 
	end
	if nIndex then
		_FA.nIndex = nIndex
	end
	_FA.tData = tData
	_FA.OpenPanel()
	_FA.ReadTitle(tData.szName,tData.szDescription)
	_FA.ReadIndex()
	if not bSave then
		_FA.LoadData = true
		
		_FA.ReadWndEdit("Edt_aAngle",tData.nAngle or 120)
		_FA.ReadWndEdit("Edt_aRadius",tData.nLength or 5)
		_FA.ReadWndEdit("Edt_aAlpha",tData.tColor.a or 255)
		_FA.ReadColor("Shadow_AngleColor",{tData.tColor.r,tData.tColor.g,tData.tColor.b} or {255,255,0})

		_FA.ReadWndEdit("Edt_cAngle",tData.nAngle2 or 120)
		_FA.ReadWndEdit("Edt_cRadius",tData.nLength2 or 5)
		_FA.ReadWndEdit("Edt_cAlpha",tData.tColor2.a or 255)
		_FA.ReadColor("Shadow_CircleColor",{tData.tColor2.r,tData.tColor2.g,tData.tColor2.b} or {255,255,0})
		_FA.ReadCheckBox("Chk_Enable",not tData.bAllDisable or false)
		_FA.ReadCheckBox("Chk_ShowAngle",tData.bOn or false)
		_FA.ReadCheckBox("Chk_ShowCircle",tData.bDistanceCircleOn or false)
		_FA.ReadCheckBox("Chk_ShowTarget",not tData.bNotShowTargetName or false)
		_FA.ReadCheckBox("Chk_ShowName",tData.bShowNPCSelfName or false)	
		_FA.LoadData = false
	else -- Save
		local ToNumber = function(num)
			return tonumber(num) or 0
		end

		local GetAngle = function(angle)
			angle = ToNumber(angle)
			if angle > 360 or angle < 0 then
				JH.Sysmsg("角度不能大于360或者小于0，请重新设置。")
				return 0
			else
				return angle
			end
		end
		
		local GetRadius = function(Radius)
			Radius = ToNumber(Radius)
			if Radius > 500 or Radius < 0 then
				JH.Sysmsg("半径设置有问题亲。")
				return 0
			else
				return Radius
			end
		end
		
		local GetAlpha = function(Alpha)
			Alpha = ToNumber(Alpha)
			if Alpha > 255 or Alpha < 0 then
				JH.Sysmsg("Alpha值应该在0-255之间。")
				return 0
			else
				return Alpha
			end
		end
		
		_FA.tData.nAngle = GetAngle(_FA.ReadWndEdit("Edt_aAngle"))
		_FA.tData.nLength = GetRadius(_FA.ReadWndEdit("Edt_aRadius"))
		_FA.tData.tColor.a = GetAlpha(_FA.ReadWndEdit("Edt_aAlpha"))
		local r,g,b = unpack(_FA.ReadColor("Shadow_AngleColor"))
		_FA.tData.tColor.r,_FA.tData.tColor.g,_FA.tData.tColor.b = tonumber(r),tonumber(g),tonumber(b)
		
		_FA.tData.nAngle2 = GetAngle(_FA.ReadWndEdit("Edt_cAngle"))
		_FA.tData.nLength2 = GetRadius(_FA.ReadWndEdit("Edt_cRadius"))
		_FA.tData.tColor2.a = GetAlpha(_FA.ReadWndEdit("Edt_cAlpha"))
		local r,g,b = unpack(_FA.ReadColor("Shadow_CircleColor"))
		_FA.tData.tColor2.r,_FA.tData.tColor2.g,_FA.tData.tColor2.b = tonumber(r),tonumber(g),tonumber(b)
		_FA.tData.bAllDisable = not _FA.ReadCheckBox("Chk_Enable")
		_FA.tData.bOn = _FA.ReadCheckBox("Chk_ShowAngle")
		_FA.tData.bDistanceCircleOn = _FA.ReadCheckBox("Chk_ShowCircle")
		_FA.tData.bNotShowTargetName = not _FA.ReadCheckBox("Chk_ShowTarget")
		_FA.tData.bShowNPCSelfName = _FA.ReadCheckBox("Chk_ShowName")

	end
	
	
	-- 重载高亮右边的数据面板
	local nClass,nIndex = tData.nFaceClass or 0,0

	if _FA.tLastIten["Item"]["Data"] then
		nIndex = tonumber(_FA.tLastIten["Item"]["Data"]:match("Handle_Item_Data_(%d+)"))
	end

	if _FA.nClass ~= nClass or nIndex ~= _FA.nIndex then
		_FA.LoadDataPanel(false, nClass)
		-- 高亮当前数据
		local t = {
			["Class"] = nClass,
			["Data"] = _FA.nIndex,
		}
		
		for k,v in pairs(t) do
			local handle = _FA.tLastIten["Handle"][k]
			local a = handle:Lookup("Handle_Item_" .. k .. "_" .. v)
			if a then
				a:Lookup("Image_Unused"):Show()
				_FA.tLastIten["Item"][k] = a:GetName()
				
				-- 设置滚动条位置
				local scroll,index = handle:GetRoot():Lookup("Scroll_List_"..k),false
				if scroll:IsVisible() then
					for i = handle:GetItemCount() - 1, 0, -1 do
						if handle:Lookup(i):GetName() == a:GetName() then
							index = i + 1
						end
					end
					if index then
						local nSP1 = ( index - 13 ) * 2.5
						local nSP2 = ( index - 1 ) * 2.5
						local nSP = scroll:GetScrollPos()
						if nSP < nSP1 or nSP > nSP2 then
							scroll:SetScrollPos(( index - 6 ) * 2.5)
						end
					end
				end
				
			end
		end
	end
end

----------------------------------------------------
-- 数据窗口部分
----------------------------------------------------

-- 构建Item 
_FA.AppendItem = function(szName,x,y,szText,bCheck,szType,col)
	local handle = _FA.GetFrame():Lookup("","Handle_Main"):Lookup("Handle_List_"..szType)
	-- AppendItemFromIni
	local item = handle:AppendItemFromIni("Interface\\JH\\RaidGrid_EventScrutiny\\ui\\Data_CheckItem.ini","Handle_Item","Handle_Item_"..szType.."_"..szName)
	if item then
		item:SetRelPos(x,y)
		item:Lookup("Title_Text"):SetText(szText)
		if col then
			local r,g,b = unpack(col)
			item:Lookup("Title_Text"):SetFontColor(r,g,b)
		end
		item.nID = tonumber(szName)
		item.szType = szType
		if type(bCheck) == "boolean" then
			if bCheck then
				item:Lookup("Image_Checked"):Show()
			end
		else
			item:Lookup("Image_Check"):Hide()
		end
	end
end

_FA.UpdateScrollInfo = function(handle)
	handle:FormatAllItemPos()
	local szType = handle:GetName():match("Handle_List_(.*)")
	local scroll = handle:GetRoot():Lookup("Scroll_List_"..szType)

	local w, h = handle:GetSize()
	local wA, hA = handle:GetAllItemSize()
	local nStep = math.ceil((hA - h) / 10)
	if nStep > 0 then
		scroll:Show()
		local h = 200 - nStep * 2
		if h < 25 then h = 25 end
		scroll:Lookup("Btn_Scroll_"..szType):SetSize(5,h)
	else
		scroll:Hide()
	end
	scroll:SetStepCount(nStep)
	if scroll:GetScrollPos() > nStep then
		scroll:SetScrollPos(nStep)
	end
end

_FA.LoadDataPanel = function(bPosition,nClass,bLastSelect)
	if type(bPosition) == "boolean" then
		local handle = _FA.GetFrame():Lookup("","Handle_Main"):Lookup("Handle_List_Class")
		handle:Clear()
		_FA.AppendItem(0,5,0,"未分类数据",nil,"Class")
		for i = 1,#BossFaceAlert.FaceClassNameInfo do
			local v = BossFaceAlert.FaceClassNameInfo[i]
			local r,g,b = 255,255,255
			if v.tMenuColor then
				r,g,b = v.tMenuColor.r,v.tMenuColor.g,v.tMenuColor.b
			end
			_FA.AppendItem(i,5,(i + 0 --[[ 1 ]]) * 25,v.szName,v.bOn,"Class",{r,g,b})
		end
		_FA.tLastIten["Handle"]["Class"] = handle
		if bLastSelect and _FA.tLastIten["Item"]["Class"] then
			local i = _FA.tLastIten["Item"]["Class"]
			local a = handle:Lookup(i)
			if a then
				a:Lookup("Image_Unused"):Show()
			else
				_FA.tLastIten["Item"]["Class"] = nil
			end
		else
			_FA.tLastIten["Item"]["Class"] = nil
		end
		_FA.UpdateScrollInfo(handle)
	end
	if type(nClass) == "number" then
		local nClassFix = nClass
		local handle = _FA.GetFrame():Lookup("","Handle_Main"):Lookup("Handle_List_Data")
		if nClass == 0 then
			nClassFix = nil
		end
		if nClass == -2 then
			handle:Clear()
			_FA.tLastIten["Data"] = nil
			_FA.nClass = nil
			return
		end
		handle:Clear()
		local _ = 0
		for i = 1,#BossFaceAlert.DrawFaceLineNames do
			local v = BossFaceAlert.DrawFaceLineNames[i]
			if v.nFaceClass == nClassFix then
				_FA.AppendItem(i,5,_* 25,v.szDescription or v.szName,not v.bAllDisable,"Data")
				_ = _ +1
			end
		end
		_FA.tLastIten["Handle"]["Data"] = handle
		if bLastSelect and _FA.tLastIten["Item"]["Data"] then
			local i = _FA.tLastIten["Item"]["Data"]
			local a = handle:Lookup(i)
			if a then
				a:Lookup("Image_Unused"):Show()
			else
				_FA.tLastIten["Item"]["Data"] = nil
			end
		else
			_FA.tLastIten["Item"]["Data"] = nil
		end
		_FA.nClass = nClass
		_FA.UpdateScrollInfo(handle)
	end
end

----------------------------------------------
-- 鼠标点击 Item
----------------------------------------------
_FA.Click_Handle_Item = function()	
	if this.szType == "Data" then
		local tab = BossFaceAlert.DrawFaceLineNames
		_FA.nIndex = this.nID
		_FA.tData = tab[_FA.nIndex]
		_FA.LoadAndSaveData(_FA.tData)
	elseif this.szType == "Class" then
		if _FA.tLastIten["Item"][this.szType] then
			local i = _FA.tLastIten["Item"][this.szType]
			local a = _FA.tLastIten["Handle"][this.szType]:Lookup(i)
			if a then
				a:Lookup("Image_Unused"):Hide()
			end
		end
		_FA.tLastIten["Item"][this.szType] = this:GetName()
		this:Lookup("Image_Unused"):Show()
		_FA.LoadDataPanel(nil,this.nID,true)
	end
end

----------------------------------------------
-- 鼠标点击 Image_Check
----------------------------------------------
_FA.Click_Image_Checked = function(self)
	_FA.Apply_Click_Check(self or this,false)
end

_FA.Click_Image_Check = function(self)
	_FA.Apply_Click_Check(self or this,true)
end

_FA.Apply_Click_Check = function(self,bCheck)
	local this = self
	local fnAction,szItem
	local nID = this:GetParent().nID
	if bCheck then
		this:GetParent():Lookup("Image_Checked"):Show()
		szItem = "Image_Check"
		fnAction = _FA.Click_Image_Check
	else
		this:GetParent():Lookup("Image_Checked"):Hide()
		szItem = "Image_Checked"
		fnAction = _FA.Click_Image_Checked
	end

	
	if this:GetParent().szType == "Data" then
		if _FA.nIndex == nID then -- 如果在面板上
			_FA.ReadCheckBox("Chk_Enable",bCheck)
			_FA.LoadAndSaveData(_FA.tData,true)
		else -- 其他情况直接改
			BossFaceAlert.DrawFaceLineNames[nID].bAllDisable = not bCheck
		end
	end

	if this:GetParent().szType == "Class" then
		BossFaceAlert.FaceClassNameInfo[nID].bOn = bCheck
		if _FA.nClass == nID then -- 在面板上模拟直接全部点一下
			local handle = _FA.GetFrame():Lookup("","Handle_Main"):Lookup("Handle_List_Data")
			for i = handle:GetItemCount() - 1, 0, -1 do
				fnAction(handle:Lookup(i):Lookup(szItem))
			end
		else -- 否则就获取下分类数据挨个干掉 
			for i = 1,#BossFaceAlert.DrawFaceLineNames do
			local v = BossFaceAlert.DrawFaceLineNames[i]
				if v.nFaceClass == nID then
					v.bAllDisable = not bCheck
				end
			end
		end
	end
	BossFaceAlert.ClearAllItem()
end

RegisterEvent("LOGIN_GAME",function() 
	Wnd.OpenWindow("Interface/JH/RaidGrid_EventScrutiny/ui/xCirclesOption.ini", "FA"):Hide()
end)
----------------------------------------------------
-- 直接添加或者给出 Exist
----------------------------------------------------
_FA.InsertTarget = function(bConfirm,bDelete)
	if not  Target_GetTargetData() then return end
	local dwID,dwType = Target_GetTargetData()
	local Target = JH.GetTarget(dwType,dwID)
	local key,dwTemplateID = Target.szName,0
	if dwType == TARGET.PLAYER then
		key = Target.dwID
	elseif dwType == TARGET.NPC then
		key = JH.GetTemplateName(Target)
		dwTemplateID = Target.dwTemplateID
	end
	for i = 1, #BossFaceAlert.DrawFaceLineNames, 1 do
		if tostring(BossFaceAlert.DrawFaceLineNames[i].szName) == tostring(key) or tostring(BossFaceAlert.DrawFaceLineNames[i].szName) == tostring(dwTemplateID) then
			if bDelete then
				table.remove(BossFaceAlert.DrawFaceLineNames,i)
				if #BossFaceAlert.DrawFaceLineNames == 0 then
					_FA.ClearPanel()
				elseif i == 1 then
					_FA.Button_Pre(true)
				else
					_FA.Button_Pre()
				end
				BFA.Init()
				_FA.LoadDataPanel(nil,_FA.nClass,true)
				JH.Sysmsg("目标已经删除")
				return true,Target.szName or key,0
			end
			return true,key or key,i
		end
	end
	if not bConfirm then
		if dwType == TARGET.NPC then
			BFA.AddScrutiny(key,dwType)
		else
			BFA.AddScrutiny(key,dwType,Target.szName)
		end
	end
	return false,key or key,#BossFaceAlert.DrawFaceLineNames
end

----------------------------------------------------
-- 快捷键和头像右键菜单添加
----------------------------------------------------

JH.AddHotKey("JH_BFA","开启/关闭面向面板",_FA.TogglePanel)
JH.AddHotKey("JH_BFA2","添加/删除当前目标的面向",function() _FA.InsertTarget(false,true) end)


Target_AppendAddonMenu({function()
	local bExist,szKey,nIndex = _FA.InsertTarget(true)
	if bExist then
		return 	{{szOption = "修改面向 - " .. szKey,rgb = {255,0,255},fnAction = function()
			_FA.nIndex = nIndex
			_FA.tData = BossFaceAlert.DrawFaceLineNames[nIndex]
			_FA.LoadAndSaveData(_FA.tData) 
		end,}}
	else
		return 	{{szOption = "添加面向 - " .. szKey,rgb = {255,255,0},fnAction = _FA.InsertTarget,}}
	end
end })
JH.PlayerAddonMenu({szOption = "面向目标监控",fnAction = _FA.OpenPanel,rgb = {255,255,0}})

----------------------------------------------------
-- public
----------------------------------------------------
local UIProtect = {
	LoadDataPanel = _FA.LoadDataPanel,
	LoadAndSaveData = _FA.LoadAndSaveData,
	LoadLastData = _FA.LoadLastData,
	OpenPanel = _FA.OpenPanel,
	ClearPanel = _FA.ClearPanel,
	ClosePanel = _FA.ClosePanel,
	-- InsertTarget = _FA.InsertTarget,
}
setmetatable(FA, { __index = UIProtect, __metatable = true, __newindex = function() --[[ print("Protect") ]] end } )
