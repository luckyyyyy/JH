local _L = JH.LoadLangPack
local HasteView = {
	tBuff = {
		[Table_GetBuffName(6251, 1)] = 50,
		[Table_GetBuffName(5788, 1)] = 50,
		[Table_GetBuffName(6229, 1)] = 102,
		[_L["JujingNingShen"]] = 205,
		[_L["YuePo"]] = 52,
		[_L["TaiJiWuJi"]] = 60,
	},
	extra = 0
}
-- 配装器算法 懒得自己写了 拿来用
HasteView.calc = function(time, x)
	if not tonumber(time) or not tonumber(x) then
		return JH.Alert("please enter number")
	end
	local extra = HasteView.extra
	local oriTime = tonumber(time)
	if oriTime > 100 then
		return JH.Alert("value is too big")
	end
	local skillx = tonumber(x)
	if skillx > 100 then
		return JH.Alert("value is too big")
	end
	local oriFrame = math.ceil(oriTime / 0.0625)
	local hastePercent, hastePercentLimit, level, i = 0, 0, 0, 0
	local lastTime = oriTime + 0.1
	HasteView.handle.self:Clear()
	repeat
		local baseHaste = i / 54.782 * 10.24
		local totalHaste = math.floor(baseHaste) + math.floor(extra)
		local a = totalHaste / 1024 + 1024
		local nowFrame = math.floor(oriFrame * 1024 / (totalHaste + 1024))
		hastePercent = i / 54.782
		hastePercentLimit = i / 54.782 + extra / 10.24
		if nowFrame <= oriFrame - level then
			local nowTime = nowFrame * 0.0625 * skillx
			if nowTime ~= lastTime then
				lastTime = nowTime
				HasteView.handle:Append("Text", { w = 80, h = 30, x = 50, y = 30 + 30 * level, align = 2, txt = "Lv" .. level })
				HasteView.handle:Append("Text", { w = 80, h = 30, x = 130, y = 30 + 30 * level, align = 2, txt = string.format("%0.2f", nowTime) })
				HasteView.handle:Append("Text", { w = 80, h = 30, x = 210, y = 30 + 30 * level, align = 2, txt = string.format("%0.2f%%", hastePercent) })
				HasteView.handle:Append("Text", { w = 80, h = 30, x = 290, y = 30 + 30 * level, align = 2, txt = i })
				level = level + 1
			end
		end
		i = i + 1
	until hastePercentLimit > 25
	HasteView.handle.self:FormatAllItemPos()
end
local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["HasteView"], font = 27 }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 5, txt = _L["skill time"] }):Pos_()
	nX = ui:Append("WndEdit", "time", { x = nX + 5, y = nY + 8, txt = 1.5, w = 30, h = 26 })
	:Change(function(szText)
		if szText == "" then return end
		HasteView.calc(ui:Fetch("time"):Text(), ui:Fetch("count"):Text())
	end):Pos_()
	nX = ui:Append("Text", { x = nX + 15, y = nY + 5, txt = _L["skill count"] }):Pos_()
	nX, nY = ui:Append("WndEdit", "count", { x = nX + 5, y = nY + 8, txt = 1, w = 30, h = 26 })
	:Change(function(szText)
		if szText == "" then return end
		HasteView.calc(ui:Fetch("time"):Text(), ui:Fetch("count"):Text())
	end):Pos_()
	nX = ui:Append("WndRadioBox", { x = 10, y = nY + 10, txt = g_tStrings.STR_NONE, group = "type", checked = true })
	:Click(function()
		HasteView.extra = 0
		HasteView.calc(ui:Fetch("time"):Text(), ui:Fetch("count"):Text())
	end):Pos_()
	for k ,v in pairs(HasteView.tBuff) do
		nX = ui:Append("WndRadioBox", { x = nX + 5, y = nY + 10, txt = k, group = "type", checked = false })
		:Click(function()
			HasteView.extra = v
			HasteView.calc(ui:Fetch("time"):Text(), ui:Fetch("count"):Text())
		end):Pos_()
	end
	ui:Append("Handle", "table", { w = 500, h = 300, x = 10, y = 80 })
	HasteView.handle = ui:Fetch("table")
	HasteView.extra = 0
	HasteView.calc(ui:Fetch("time"):Text(), ui:Fetch("count"):Text())
	ui:Append("Text", { y = 360, x = 300, w = 210, h = 30, txt = "thanks for http://www.j3pz.com" }):Click(function()
		OpenInternetExplorer("http://www.j3pz.com/")
	end)
end
GUI.RegisterPanel(_L["HasteView"], 394, _L["Tools"], PS)