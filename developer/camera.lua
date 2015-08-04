-- @Author: Webster
-- @Date:   2015-05-11 18:51:46
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-08-04 00:17:47

-- 因为相机的原点是在玩家的位置 所以这个不是很科学

local function Camera(X, Y, Z)
	rlcmd("set camera offset " .. X .. " " .. Y .. " " .. Z)
end

local function Open()
	local X, Y, Z = 0, 0, 0
	local step = 50
	_G["JH_camera"] = {}
	local ui = GUI.CreateFrame("JH_camera", { w = 200, h = 100, close = true, title = "camera offset", nStyle = 2 })
	ui:Append("WndTrackBar", { x = 30, y = 20 }):Range(1, 100, 99):Value(step):Change(function(nVal)
		step = nVal
	end)
	local frame = _G["JH_camera"]
	frame.OnFrameKeyDown = function()
		local dwKey = Station.GetMessageKey()
		local szKey = GetKeyName(dwKey)
		if szKey == "A" then
			Y = Y + step
		elseif szKey == "D" then
			Y = Y - step
		elseif szKey == "Q" then
			Z = Z + step
		elseif szKey == "E" then
			Z = Z - step
		elseif szKey == "W" then
			X = X + step
		elseif szKey == "S" then
			X = X - step
		end
		Camera(X, Y, Z)
		return 1
	end
	frame.OnFrameDestroy = function()
		Camera(0, 0, 0)
		_G["JH_camera"] = nil
	end
end

JH.AddonMenu(function()
	return { szOption = "camera", fnAction = Open }
end)

