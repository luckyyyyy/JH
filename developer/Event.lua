-- @Author: Webster
-- @Date:   2015-02-27 14:44:16
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-02-27 15:33:09
local _L = JH.LoadLangPack
local tEventIndex = {
	{ "键盘按下", 13 },
	{ "键盘弹起", 14 },

	{ "左键按下", 1 },
	{ "左键弹起", 3 },
	{ "左键点击", 5 },
	{ "左键双击", 7 },
	{ "左键拖拽", 20 },

	{ "右键按下", 2 },
	{ "右键弹起", 4 },
	{ "右键点击", 6 },
	{ "右键双击", 8 },
	{ "右键拖拽", 19 },

	{ "中键按下", 15 },
	{ "中键弹起", 16 },
	{ "中键点击", 17 },
	{ "中键双击", 18 },
	{ "中键拖拽", 21 },

	{ "鼠标进出", 9 },
	{ "鼠标区域", 10 },
	{ "鼠标移动", 11 },
	{ "鼠标悬停", 22 },
	{ "滚轮事件", 12 },
}

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	local function BitTable2UInt()
		local tBitTab = {}
		for k, v in ipairs(tEventIndex) do
			if ui:Fetch(v[1]) then
				if ui:Fetch(v[1]):Check() then
					tBitTab[v[2]] = 1
				else
					tBitTab[v[2]] = 0
				end
			end
		end
		local nUInt = 0
		for i = 1, 24 do
			nUInt = nUInt + (tBitTab[i] or 0) * (2 ^ (i - 1))
		end
		ui:Fetch("WndEdit"):Text(nUInt)
	end

	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Events"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndEdit", "WndEdit", { txt = 0, x = 10, y = nY + 10, font = 201, color = { 255, 255, 255 }}):Pos_()
	nX, nY = 5, nY + 10
	for i = 1, 2 do
		local v = tEventIndex[i]
		nX = ui:Append("WndCheckBox", v[1], { txt = v[1], x = nX + 5, y = nY }):Click(function(bCheck)
			if bCheck then
				ui:Fetch(v[1]):Color(255, 128, 0)
			else
				ui:Fetch(v[1]):Color(255, 255, 255)
			end
			BitTable2UInt()
		end):Pos_()
	end
	nX, nY = 5, nY + 25
	for i = 3, 22 do
		local v = tEventIndex[i]
		nX = ui:Append("WndCheckBox", v[1], { txt = v[1], x = nX + 5, y = nY }):Click(function(bCheck)
			if bCheck then
				ui:Fetch(v[1]):Color(255, 128, 0)
			else
				ui:Fetch(v[1]):Color(255, 255, 255)
			end
			BitTable2UInt()
		end):Pos_()
		if(i - 1) % 5 == 1 then
			nX, nY = 5, nY + 25
		end
	end
end

GUI.RegisterPanel(_L["Events"], 6060, _L["Dev"], PS)
