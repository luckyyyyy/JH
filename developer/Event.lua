-- @Author: Webster
-- @Date:   2015-02-27 14:44:16
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-02-27 15:57:30
local _L = JH.LoadLangPack
local tEventIndex = {
	{ "¼üÅÌ°´ÏÂ", 13 },
	{ "¼üÅÌµ¯Æð", 14 },

	{ "×ó¼ü°´ÏÂ", 1 },
	{ "×ó¼üµ¯Æð", 3 },
	{ "×ó¼üµã»÷", 5 },
	{ "×ó¼üË«»÷", 7 },
	{ "×ó¼üÍÏ×§", 20 },

	{ "ÓÒ¼ü°´ÏÂ", 2 },
	{ "ÓÒ¼üµ¯Æð", 4 },
	{ "ÓÒ¼üµã»÷", 6 },
	{ "ÓÒ¼üË«»÷", 8 },
	{ "ÓÒ¼üÍÏ×§", 19 },

	{ "ÖÐ¼ü°´ÏÂ", 15 },
	{ "ÖÐ¼üµ¯Æð", 16 },
	{ "ÖÐ¼üµã»÷", 17 },
	{ "ÖÐ¼üË«»÷", 18 },
	{ "ÖÐ¼üÍÏ×§", 21 },

	{ "Êó±ê½ø³ö", 9 },
	{ "Êó±êÇøÓò", 10 },
	{ "Êó±êÒÆ¶¯", 11 },
	{ "Êó±êÐüÍ£", 22 },
	{ "¹öÂÖÊÂ¼þ", 12 },
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
		ui:Fetch("WndEdit"):Text(nUInt, true)
	end

	local function UInt2BitTable(nUInt)
		local tBitTab = {}
		local nUInt4C = nUInt
		if nUInt4C > (2 ^ 24) then
			return
		end

		for i = 1, 32 do
			local nValue = math.fmod(nUInt4C, 2)
			nUInt4C = math.floor(nUInt4C / 2)
			table.insert(tBitTab, nValue)
			if nUInt4C == 0 then
				break
			end
		end
		for k, v in ipairs(tEventIndex) do
			if tBitTab[v[2]] == 1 then
				ui:Fetch(v[1]):Check(true)
			else
				ui:Fetch(v[1]):Check(false)
			end
		end
	end

	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Events"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndEdit", "WndEdit", { txt = 0, x = 10, y = nY + 10, font = 201, color = { 255, 255, 255 }})
	:Change(function(txt)
		if tonumber(txt) then UInt2BitTable(tonumber(txt)) end
	end):Pos_()
	nX, nY = 5, nY + 10
	for k, v in ipairs(tEventIndex) do
		nX = ui:Append("WndCheckBox", v[1], { txt = v[1], x = nX + 5, y = nY }):Click(function(bCheck)
			if bCheck then
				ui:Fetch(v[1]):Color(255, 128, 0)
			else
				ui:Fetch(v[1]):Color(255, 255, 255)
			end
			BitTable2UInt()
		end):Pos_()
		if(k - 1) % 5 == 1 or k == 2 then
			nX, nY = 5, nY + 25
		end
	end
end

GUI.RegisterPanel(_L["Events"], 6060, _L["Dev"], PS)
