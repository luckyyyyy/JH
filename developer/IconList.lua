-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-02-26 03:47:27
local _L = JH.LoadLangPack
local _JH_IconList = {
	nCur = 0,
	nMax = 6500,
}

_JH_IconList.OnPanelActive = function(frame)
	local ui = GUI(frame)
	local imgs, txts = {}, {}
	ui:Append("Text", { txt = _L["Icon"], x = 0, y = 0, font = 27 })
	for i = 1, 40 do
		local x = ((i - 1) % 10) * 50
		local y = math.floor((i - 1) / 10) * 70 + 40
		imgs[i] = ui:Append("Image", { w = 48, h = 48, x = x, y = y})
		txts[i] = ui:Append("Text", { w = 48, h = 20, x = x, y = y + 48, align = 1 })
	end
	local btn1 = ui:Append("WndButton2", { txt = _L["Up"], x = 0, y = 320 })
	local nX, _ = btn1:Pos_()
	local btn2 = ui:Append("WndButton2", { txt = _L["Next"], x = nX, y = 320 })
	btn1:Click(function()
		_JH_IconList.nCur = _JH_IconList.nCur - #imgs
		if _JH_IconList.nCur <= 0 then
			_JH_IconList.nCur = 0
			btn1:Enable(false)
		end
		btn2:Enable(true)
		for k, v in ipairs(imgs) do
			local i = _JH_IconList.nCur + k - 1
			if i > _JH_IconList.nMax then
				break
			end
			imgs[k]:Icon(i)
			txts[k]:Text(tostring(i))
		end
	end):Click()
	btn2:Click(function()
		_JH_IconList.nCur = _JH_IconList.nCur + #imgs
		if (_JH_IconList.nCur + #imgs) >= _JH_IconList.nMax then
			btn2:Enable(false)
		end
		btn1:Enable(true)
		for k, v in ipairs(imgs) do
			local i = _JH_IconList.nCur + k - 1
			if i > _JH_IconList.nMax then
				break
			end
			imgs[k]:Icon(i)
			txts[k]:Text(tostring(i))
		end
	end)
end

GUI.RegisterPanel(_L["Icon"], 591, _L["Dev"], _JH_IconList)
