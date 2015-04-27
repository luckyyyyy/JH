-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-02-26 13:12:58
local _L = JH.LoadLangPack
local _JH_FontList = {
	nCur = 0,
	nMax = 236,
}
_JH_FontList.OnPanelActive = function(frame)
	local ui = GUI(frame)
	local txts = {}
	ui:Append("Text", { txt = _L["Font"], x = 0, y = 0, font = 27 })
	for i = 1, 40 do
		local x = ((i - 1) % 8) * 62
		local y = math.floor((i - 1) / 8) * 55 + 30
		txts[i] = ui:Append("Text", { w = 62, h = 30, x = x, y = y, align = 1 })
	end
	local btn1 = ui:Append("WndButton2", { txt = _L["Up"], x = 0, y = 320 })
	local nX, _ = btn1:Pos_()
	local btn2 = ui:Append("WndButton2", { txt = _L["Next"], x = nX, y = 320 })
	btn1:Click(function()
		_JH_FontList.nCur = _JH_FontList.nCur - #txts
		if _JH_FontList.nCur <= 0 then
			_JH_FontList.nCur = 0
			btn1:Enable(false)
		end
		btn2:Enable(true)
		for k, v in ipairs(txts) do
			local i = _JH_FontList.nCur + k - 1
			if i > _JH_FontList.nMax then
				txts[k]:Text("")
			else
				txts[k]:Text(_L["Jh"] .. i)
				txts[k]:Font(i)
			end
		end
	end):Click()
	btn2:Click(function()
		_JH_FontList.nCur = _JH_FontList.nCur + #txts
		if (_JH_FontList.nCur + #txts) >= _JH_FontList.nMax then
			btn2:Enable(false)
		end
		btn1:Enable(true)
		for k, v in ipairs(txts) do
			local i = _JH_FontList.nCur + k - 1
			if i > _JH_FontList.nMax then
				txts[k]:Text("")
			else
				txts[k]:Text(_L["Jh"] .. i)
				txts[k]:Font(i)
			end
		end
	end)
end

GUI.RegisterPanel(_L["Font"], 581, _L["Dev"], _JH_FontList)
