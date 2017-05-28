-- @Author: Webster
-- @Date:   2015-10-08 12:47:40
-- @Last Modified by:   Administrator
-- @Last Modified time: 2017-05-29 02:29:47

local _L = JH.LoadLangPack
local CRAFT_RESULT_CODE_SUCCESS = 1
local pairs, ipairs = pairs, ipairs
local GetClientPlayer, BigBagPanel_nCount = GetClientPlayer, BigBagPanel_nCount
local BookID2GlobelRecipeID = BookID2GlobelRecipeID
JH_CopyBook = {
	szBookName = _L["BOOK_143"],
	nCopyNum   = 1,
	tIgnore    = {},
}
JH.RegisterCustomData("JH_CopyBook")

local Book = {
	tCache  = {
		BOOK = {},
		ITEM = {},
	},
	bEnable = false,
	nBook   = 1,
}

-- 返回值 书本ID，书本数量，需要体力, 获得监本
function Book.GetBook(szName)
	if not Book.tCache.BOOK[szName] then
		local me = GetClientPlayer()
		local nCount = g_tTable.BookSegment:GetRowCount() --获取表格总行
		local nThew, nExamPrint, nMaxLevel, nMaxLevelEx, nMaxPlayerLevel, dwProfessionIDExt = 0, 0, 0, 0, 0, 0
		local tItems, tBooks, tTool = {}, {}, {}
		local dwBookID, dwBookNumber
		for i = 1, nCount do
			local item = g_tTable.BookSegment:GetRow(i)
			if item.szBookName == szName then
				dwBookID, dwBookNumber = item.dwBookID, item.dwBookNumber
				break
			end
		end
		if dwBookID then
			for i = 1, dwBookNumber do
				local tRecipe = GetRecipe(12, dwBookID, i)
				if not JH_CopyBook.tIgnore[i] then
					nThew           = nThew + tRecipe.nThew
					nMaxLevel       = math.max(nMaxLevel, tRecipe.dwRequireProfessionLevel) -- 阅读等级
					nMaxPlayerLevel = math.max(nMaxPlayerLevel, tRecipe.nRequirePlayerLevel) -- 角色等级
					if nMaxLevelEx < tRecipe.dwRequireProfessionLevelExt then
						nMaxLevelEx = tRecipe.dwRequireProfessionLevelExt
						if dwProfessionIDExt == 0 then -- 不知道为毛会放在里面。。。
							dwProfessionIDExt = tRecipe.dwProfessionIDExt
						end
					end
					for nIndex = 1, 4, 1 do
						local dwTabType = tRecipe["dwRequireItemType"  .. nIndex]
						local dwIndex   = tRecipe["dwRequireItemIndex" .. nIndex]
						local nCount    = tRecipe["dwRequireItemCount" .. nIndex]
						if nCount > 0 then
							local item = GetItemInfo(dwTabType, dwIndex)
							tItems[item.szName] = tItems[item.szName] or { dwTabType = dwTabType, dwIndex = dwIndex, nCount = 0 }
							tItems[item.szName].nCount = tItems[item.szName].nCount + nCount
						end
					end
					if tRecipe.dwToolItemType ~= 0 and tRecipe.dwToolItemIndex ~= 0 then
						local item   = GetItemInfo(tRecipe.dwToolItemType, tRecipe.dwToolItemIndex)
						local nCount = me.GetItemAmount(tRecipe.dwToolItemType, tRecipe.dwToolItemIndex)
						tTool[item.szName] = nCount
					end
				end
				table.insert(tBooks, {
					dwTabType = tRecipe.dwCreateItemType,
					dwIndex   = tRecipe.dwCreateItemIndex
				})
			end
			local tTable = g_tTable.BookEx:Search(dwBookID)
			if tTable then
				nExamPrint = tTable.dwPresentExamPrint
			end
		end
		Book.tCache.BOOK[szName] = { dwBookID, dwBookNumber, nThew, nExamPrint, nMaxLevel, nMaxLevelEx, nMaxPlayerLevel, dwProfessionIDExt, tItems, tBooks, tTool }
	end
	return unpack(Book.tCache.BOOK[szName] or {})
end

function Book.GetBookCount(dwRecipeID)
	local nCount = 0
	for k, v in pairs(Book.tCache.ITEM) do
		for kk, vv in pairs(v) do
			if vv == dwRecipeID then
				nCount = nCount + 1
			end
		end
	end
	return nCount
end

function Book.UpdateRange(szName)
	local ui = Book.ui
	if not ui then return end
	local me = GetClientPlayer()
	local dwBookID, dwBookNumber, nThew, nExamPrint, nMaxLevel, nMaxLevelEx, nMaxPlayerLevel, dwProfessionIDExt, tItems, tBooks, tTool = Book.GetBook(szName and szName or JH_CopyBook.szBookName)
	local nMax = math.max(math.floor(me.nCurrentThew / math.max(nThew, 1)), 1)
	ui:Fetch("Count"):Change(nil):Enable(nThew ~= 0):Range(0, nMax, math.max(nMax, 0)):Value(JH_CopyBook.nCopyNum):Change(function(nNum)
		JH_CopyBook.nCopyNum = nNum
		JH.DelayCall(Book.UpdateInfo)
	end)
end

function Book.UpdateInfo(szName)
	local ui = Book.ui
	if not ui then return end
	local me = GetClientPlayer()
	local dwBookID, dwBookNumber, nThew, nExamPrint, nMaxLevel, nMaxLevelEx, nMaxPlayerLevel, dwProfessionIDExt, tItems, tBooks, tTool = Book.GetBook(szName and szName or JH_CopyBook.szBookName)
	if dwBookID then
		local bCanCopy = nThew > 0 and true or false
		local szUitex = "ui/Image/Minimap/MapMark.UITex"
		local green, red = { 255, 255, 255 }, { 255, 0, 0 }
		ui:Fetch("Copy"):Enable(true)
		local nMax = math.max(math.floor(me.nCurrentThew / math.max(nThew, 1)), 1)
		if JH_CopyBook.nCopyNum > nMax and not Book.bEnable then
			JH_CopyBook.nCopyNum = nMax
		end
		ui:Fetch("Count"):Enable(true)
		local handle = ui:Fetch("Require"):Clear()
		local nX, nY = 10, 0
		nX, nY = handle:Append("Text", { x = nX, y = nY, txt = FormatString(g_tStrings.CRAFT_COPY_REWARD_EXAMPRINT, " " .. JH_CopyBook.nCopyNum * nExamPrint), color = { 255, 128, 0 } }):Pos_()
		-- 计算体力
		local nNumThew = JH_CopyBook.nCopyNum * nThew
		local bStatus  = nNumThew <= me.nCurrentThew and true or false
		bCanCopy = bCanCopy and bStatus
		nX = handle:Append("Text", { x = 10, y = nY + 5, txt = _L["Need Thew:"]}):Pos_()
		handle:Append("Image", { x = nX + 5, y = nY + 15, w = 200, h = 11 }):File(szUitex, 123)
		handle:Append("Image", { x = nX + 7, y = nY + 18, w = 194, h = 5 }):File(szUitex, bStatus and 127 or 125):Percentage(nNumThew / math.max(1, me.nCurrentThew))
		nX, nY = handle:Append("Text", { x = nX + 5, y = nY + 5, w = 200, h = 30, align = 1, font = 15, txt = me.nCurrentThew .. "/" .. nNumThew, color = bStatus and green or red }):Pos_()
		-- 阅读等级需求
		local nPlayerLevel = me.GetProfessionLevel(8)
		local bStatus      = nPlayerLevel >= nMaxLevel
		bCanCopy = bCanCopy and bStatus
		nX = handle:Append("Text", { x = 10, y = nY + 5, txt = FormatString(_L["Need<D0>Level:"], g_tStrings.CRAFT_READING)}):Pos_()
		handle:Append("Image", { x = nX + 5, y = nY + 15, w = 200, h = 11 }):File(szUitex, 123)
		handle:Append("Image", { x = nX + 7, y = nY + 18, w = 194, h = 5 }):File(szUitex, bStatus and 127 or 125):Percentage(math.max(1, nPlayerLevel) / nMaxLevel)
		nX, nY = handle:Append("Text", { x = nX + 5, y = nY + 5, w = 200, h = 30, align = 1, font = 15, txt = nPlayerLevel .. "/" .. nMaxLevel, color = bStatus and green or red }):Pos_()
		-- XX等级需求
		if dwProfessionIDExt ~= 0 then
			local ProfessionExt = GetProfession(dwProfessionIDExt)
			if ProfessionExt then
				local nExtLevel = me.GetProfessionLevel(dwProfessionIDExt)
				local bStatus   = nExtLevel >= nMaxLevelEx
				bCanCopy = bCanCopy and bStatus
				nX = handle:Append("Text", { x = 10, y = nY + 5, txt = FormatString(_L["Need<D0>Level:"], Table_GetProfessionName(dwProfessionIDExt))}):Pos_()
				handle:Append("Image", { x = nX + 5, y = nY + 15, w = 200, h = 11 }):File(szUitex, 123)
				handle:Append("Image", { x = nX + 7, y = nY + 18, w = 194, h = 5 }):File(szUitex, bStatus and 127 or 125):Percentage(math.max(1, nExtLevel) / nMaxLevelEx)
				nX, nY = handle:Append("Text", { x = nX + 5, y = nY + 5, w = 200, h = 30, align = 1, font = 15, txt = nExtLevel .. "/" .. nMaxLevelEx, color = bStatus and green or red }):Pos_()
			end
		end
		-- 需要角色等级
		if nMaxPlayerLevel ~= 0 then
			local bStatus = me.nLevel >= nMaxPlayerLevel
			bCanCopy = bCanCopy and bStatus
			nX = handle:Append("Text", { x = 10, y = nY + 5, txt = FormatString(_L["Need<D0>Level:"], _L["Role"])}):Pos_()
			handle:Append("Image", { x = nX + 5, y = nY + 15, w = 200, h = 11 }):File(szUitex, 123)
			handle:Append("Image", { x = nX + 7, y = nY + 18, w = 194, h = 5 }):File(szUitex, bStatus and 127 or 125):Percentage(math.max(1, me.nLevel) / nMaxPlayerLevel)
			nX, nY = handle:Append("Text", { x = nX + 5, y = nY + 5, w = 200, h = 30, align = 1, font = 15, txt = me.nLevel .. "/" .. nMaxPlayerLevel, color = bStatus and green or red }):Pos_()
		end
		-- 需求道具
		if not IsEmpty(tTool) then
			nX = handle:Append("Text", { x = 10, y = nY + 5, txt = g_tStrings.CRAFT_NEED_TOOL, color = green }):Pos_()
			for k, v in pairs(tTool) do
				bCanCopy = bCanCopy and v ~= 0
				nX = handle:Append("Text", { x = nX + 5, y = nY + 5, txt = k, color = v ~= 0 and green or red }):Pos_()
			end
			nY = nY + 15
		end
		-- 需求的道具
		local i = 0
		for k, v in pairs(tItems) do
			local nCount  = me.GetItemAmount(v.dwTabType, v.dwIndex)
			local bStatus = nCount >= v.nCount * JH_CopyBook.nCopyNum and true or false
			bCanCopy = bCanCopy and bStatus
			nX = handle:Append("Box", { x = (i % 9) * 58, y = nY + math.floor(i / 9 ) * 55 + 15, w = 48, h = 48})
			:ItemInfo(GLOBAL.CURRENT_ITEM_VERSION, v.dwTabType, v.dwIndex)
			:OverText(ITEM_POSITION.RIGHT_BOTTOM, nCount .. "/" .. v.nCount * JH_CopyBook.nCopyNum, 0, bStatus and 15 or 159)
			:Pos_()
			i = i + 1
		end
		-- 书本
		local hBooks = ui:Fetch("Books"):Clear()
		nX = 5
		local tBS, tCheck = me.GetBookSegmentList(dwBookID), {}
		for k, v in ipairs(tBS) do
			tCheck[v] = true
		end
		for k, v in ipairs(tBooks) do
			if not JH_CopyBook.tIgnore[k] then
				bCanCopy = bCanCopy and tCheck[k] or false
			end
			local dwRecipeID = BookID2GlobelRecipeID(dwBookID, k)
			local nCount  = Book.GetBookCount(dwRecipeID)
			nX = hBooks:Append("Box", { x = nX + 10, y = 5, w = 32, h = 32 }):ToGray(not tCheck[k])
			:Enable(not JH_CopyBook.tIgnore[k] and true or false)
			:ItemInfo(GLOBAL.CURRENT_ITEM_VERSION, v.dwTabType, v.dwIndex, dwRecipeID)
			:OverText(ITEM_POSITION.RIGHT_BOTTOM, nCount)
			:Staring(Book.nBook == k and Book.bEnable)
			:Click(function()
				if not IsCtrlKeyDown() then
					this:EnableObject(this:IsObjectEnable())
					JH_CopyBook.tIgnore[k] = this:IsObjectEnable() or nil
					Book.tCache.BOOK[JH_CopyBook.szBookName] = nil
					Book.UpdateInfo()
					Book.UpdateRange()
				end
			end):Pos_()
		end
		ui:Fetch("Copy"):Enable(bCanCopy and JH_CopyBook.nCopyNum > 0 and not Book.bEnable)
		if szName then
			JH_CopyBook.szBookName = szName
		end
		if not Book.bEnable and Book.nBook ~= 1 and Book.szBookName and Book.szBookName == JH_CopyBook.szBookName then
			ui:Fetch("go_on"):Toggle(true)
		else
			ui:Fetch("go_on"):Toggle(false)
		end
	else
		ui:Fetch("Count"):Enable(false)
		ui:Fetch("Copy"):Enable(false)
		ui:Fetch("Require"):Clear()
		local handle = ui:Fetch("Books"):Clear()
		if szName ~= "" then
			handle:Append("Text", { x = 10, y = 0, txt = _L["No Books"], color = { 255, 0, 0 } })
		end
	end
end

function Book.CheckCopy()
	if Book.bEnable then
		return JH.Sysmsg(g_tStrings.STR_ERROR_IN_OTACTION)
	end
	local dwBookID, dwBookNumber = Book.GetBook(JH_CopyBook.szBookName)
	if Book.nBook and Book.nBook > 1
		and Book.szBookName and JH_CopyBook.szBookName == Book.szBookName
	then
		JH.Confirm(_L("%s, go on?", Book.szBookName .. " " .. Book.nBook .. "/" .. dwBookNumber), function()
			Book.Copy()
		end, function()
			Book.nBook = 1
			Book.Copy()
		end, _L["go on"], _L["restart"])
	else
		Book.Copy()
	end
end

function Book.Copy()
	if Book.bEnable then
		return JH.Sysmsg(g_tStrings.STR_ERROR_IN_OTACTION)
	end
	Book.bEnable    = true
	Book.szBookName = JH_CopyBook.szBookName
	local dwBookID, dwBookNumber = Book.GetBook(Book.szBookName)
	assert(dwBookID)
	JH.Sysmsg(_L("Start Copy Book %s", Book.szBookName))
	local function StopProfessionSkill()
		Book.bEnable = false
		JH.UnRegisterInit("COPYBOOK_START")
		JH.Sysmsg(_L("Stop Copy Book %s", Book.szBookName))
		Book.UpdateInfo()
		Book.UpdateRange()
	end
	local function GetNextBook(bNext)
		if not bNext then
			if JH_CopyBook.tIgnore[Book.nBook] then
				bNext = true
			end
		end
		if bNext then
			repeat
				Book.nBook = Book.nBook + 1
				if Book.nBook > dwBookNumber then -- 一套书抄完了
					Book.nBook = 1
					JH_CopyBook.nCopyNum = JH_CopyBook.nCopyNum - 1
					JH.Debug("COPYBOOK # Count " .. JH_CopyBook.nCopyNum)
					if JH_CopyBook.nCopyNum == 0 then
						return StopProfessionSkill()
					end
					Book.UpdateRange()
				end
			until not JH_CopyBook.tIgnore[Book.nBook]
		end
		return Book.nBook
	end
	local function CastProfessionSkill(bNext)
		local me = GetClientPlayer()
		if not me then
			return StopProfessionSkill()
		end
		local nBook = GetNextBook(bNext)
		if nBook then
			JH.Debug("COPYBOOK # Book:" .. dwBookID .. " Index:" .. nBook)
			local nState = me.CastProfessionSkill(12, dwBookID, nBook)
			if nState ~= 1 then
				JH.Debug("COPYBOOK # CAST_ERROR #" .. nState)
				return StopProfessionSkill()
			end
		end
	end
	JH.RegisterInit("COPYBOOK_START",
		{ "OT_ACTION_PROGRESS_BREAK", function() -- 打断读条时
			if arg0 == UI_GetClientPlayerID() then
				StopProfessionSkill()
			end
		end },
		{ "DO_RECIPE_PREPARE_PROGRESS", function() -- 更新读条时 更新
			JH.DelayCall(Book.UpdateInfo)
		end },
		{ "SYS_MSG", function() -- 抄录完成 继续抄录
			if arg0 == "UI_OME_CRAFT_RESPOND" and arg2 == 12 then
				if arg1 == CRAFT_RESULT_CODE_SUCCESS then
					CastProfessionSkill(true)
				else
					StopProfessionSkill()
				end
			end
		end }
	)
	CastProfessionSkill()
	Book.UpdateInfo()
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	Book.ui = ui
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Copy Book"], font = 27 }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 10, txt = _L["Books Name"] }):Pos_()
	nX = ui:Append("WndEdit", "Name", { x = nX + 5, y = nY + 12, txt = JH_CopyBook.szBookName }):Autocomplete(function(szText)
		if not Book.tBookList then
			local tName = {}
			Book.tBookList = {}
			for i = 2, g_tTable.BookSegment:GetRowCount() do
				local item = g_tTable.BookSegment:GetRow(i)
				if not tName[item.szBookName] then
					table.insert(Book.tBookList, { szOption = item.szBookName })
					tName[item.szBookName] = true
				end
			end
			setmetatable(Book.tBookList, { __index = tName })
		end
		return Book.tBookList
	end, function(szText)
		Book.UpdateInfo(szText)
		Book.UpdateRange(szText)
	end):Pos_()
	nX = ui:Append("WndButton2", "Copy", { x = nX + 5, y = nY + 12, txt = _L["Start Copy"] }):Click(Book.CheckCopy):Pos_()
	nX, nY = ui:Append("WndButton2", "go_on", { x = nX + 5, y = nY + 12, txt = _L["go on"] }):Toggle(false):Click(Book.Copy):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY, txt = _L["Copy Count"] }):Pos_()
	nX, nY = ui:Append("WndTrackBar", "Count", { x = nX + 5, y = nY + 5, txt = "" }):Pos_()
	nX, nY = ui:Append("Handle", "Books", { x = 0, y = nY, h = 40, w = 500 }):Pos_()
	nX, nY = ui:Append("Handle", "Require", { x = 0, y = nY + 5, h = 200, w = 500 })
	-- item cache
	Book.tCache.ITEM = {}
	local me = GetClientPlayer()
	for dwBox = 1, BigBagPanel_nCount do
		Book.tCache.ITEM[dwBox] = Book.tCache.ITEM[dwBox] or {}
		for dwX = 0, me.GetBoxSize(dwBox) - 1 do
			local item = me.GetItem(dwBox, dwX)
			if item and item.nGenre == ITEM_GENRE.BOOK then
				Book.tCache.ITEM[dwBox][dwX] = item.nStackNum
			end
		end
	end
	Book.UpdateInfo()
	Book.UpdateRange()
	JH.RegisterInit("COPYBOOK",
		{ "BAG_ITEM_UPDATE", function()
			local me = GetClientPlayer()
			local item = me.GetItem(arg0, arg1)
			Book.tCache.ITEM[arg0] = Book.tCache.ITEM[arg0] or {}
			if item and item.nGenre == ITEM_GENRE.BOOK then
				Book.tCache.ITEM[arg0][arg1] = item.nStackNum
			else
				Book.tCache.ITEM[arg0][arg1] = nil
			end
			JH.DelayCall(Book.UpdateInfo)
		end },
		{ "PROFESSION_LEVEL_UP", function() JH.DelayCall(Book.UpdateInfo) end },
		{ "SYS_MSG", function()
			if arg0 == "UI_OME_CRAFT_RESPOND" then
				JH.DelayCall(Book.UpdateInfo)
			end
		end }
	)
end

function PS.OnPanelDeactive()
	JH.UnRegisterInit("COPYBOOK")
	Book.tCache.ITEM = {}
	Book.ui          = nil
	Book.tBookList   = nil
end

GUI.RegisterPanel(_L["Copy Book"], 415, g_tStrings.CHANNEL_CHANNEL, PS)
