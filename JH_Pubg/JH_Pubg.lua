local function UpdateTarget(dwID)
	local frame = Station.Lookup("Normal/Target")
	local text = frame:Lookup("", "Text_Target")
	if frame and frame:IsVisible() and text then
		local tar, type = JH.GetTarget()
		if type == TARGET.PLAYER and dwID == tar.dwID then
			local szName = JH.GetTemplateName(tar)
			local mnt = tar.GetKungfuMount()
			szName = szName .. ' - ' .. tar.GetTotalEquipScore()
			if mnt then
				szName = szName .. ' - ' .. string.sub(JH.GetSkillName(mnt.dwSkillID, mnt.dwLevel), 1, 4)
			end
			text:SetText(szName)
		end
	end
end

local function UpdateState()
	local tar, type = JH.GetTarget()
	if type == TARGET.PLAYER then
		ViewInviteToPlayer(tar.dwID, true)
	end
end
JH.RegisterEvent('PLAYER_STATE_UPDATE', function()
	local frame = Station.Lookup("Normal/Target")
	if frame and arg0 == frame.dwID then
		UpdateState()
	end
end)

JH.RegisterEvent("TARGET_CHANGE", UpdateState)

JH.RegisterEvent("PEEK_OTHER_PLAYER", function()
	if arg0 == PEEK_OTHER_PLAYER_RESPOND.SUCCESS then
		UpdateTarget(arg1)
	end
end)


