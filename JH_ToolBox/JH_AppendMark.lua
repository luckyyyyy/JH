-- @Author: Webster
-- @Date:   2016-01-04 14:35:16
-- @Last Modified by:   Administrator
-- @Last Modified time: 2016-11-13 15:55:37

local _L = JH.LoadLangPack
local MARK = {}

JH_AppendMark = {
	bEnable = true,
}
-- JH.RegisterCustomData("JH_AppendMark")

function MARK.SetMark()
	local tTeamMark,tMark = GetClientTeam().GetTeamMark() or {}, {}
	for k, v in pairs(tTeamMark) do
		tMark[v] = true
	end
	local frame = Station.Lookup("Normal1/WorldMark")
	if frame and frame.tMark then
		for k, v in ipairs(frame.tMark) do
			if v and v:IsValid() then
				if tMark[k] then
					v:SetAlpha(50)
					v.alpha = 50
				else
					v:SetAlpha(180)
					v.alpha = 180
				end
			end
		end
	end
end

function MARK.AppendMark()
	if arg0 and arg0:GetName() == "WorldMark" then
		local WorldMark = arg0
		local Wnd_WorldMark = WorldMark:Lookup("Wnd_WorldMark")
		local w, h = Wnd_WorldMark:Lookup("", "Image_Bg"):GetSize()
		WorldMark:SetH(h * 2 + 22)
		Wnd_WorldMark:SetH(h * 2 + 22)
		local handle = Wnd_WorldMark:Lookup("", "")
		handle:SetH(h * 2)
		Wnd_WorldMark:Lookup("","Image_Bg"):SetH(h * 2)
		handle:AppendItemFromString("<handle>w=195 h=82 name=\"Mark\"</handle>")
		local Mark = Wnd_WorldMark:Lookup("", "Mark")
		Mark:SetHandleStyle(3)
		Mark:SetRelPos(5, 82 + 22)
		handle:FormatAllItemPos()
		local tTeamMark,tMark = GetClientTeam().GetTeamMark() or {}, {}
		for k,v in pairs(tTeamMark) do
			tMark[v] = true
		end
		arg0.tMark = {}
		for k, v in ipairs_c(PARTY_MARK_ICON_FRAME_LIST) do
			Mark:AppendItemFromString(GetFormatImage(PARTY_MARK_ICON_PATH, v, 33, 33, 816, "Mark" ..k))
			local img = Mark:Lookup("Mark" ..k)
			if tMark[k] and tMark[k] ~= 0 then
				img:SetAlpha(50)
				img.alpha = 50
			else
				img:SetAlpha(180)
				img.alpha = 180
			end
			img.OnItemLButtonClick = function()
				local dwID = select(2, Target_GetTargetData())
				GetClientTeam().SetTeamMark(k, dwID)
			end
			img.OnItemRButtonClick = function()
				GetClientTeam().SetTeamMark(k, 0)
			end
			img.OnItemMouseEnter = function()
				this:SetAlpha(255)
			end
			img.OnItemMouseLeave = function()
				this:SetAlpha(this.alpha)
			end
			arg0.tMark[k] = img
		end
		Mark:FormatAllItemPos()
	end
end


function JH_AppendMark.GetEvent()
	if JH_AppendMark.bEnable then
		return
			{ "PARTY_SET_MARK",  MARK.SetMark },
			{ "ON_FRAME_CREATE", MARK.AppendMark }
	end
end

