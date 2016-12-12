-- @Author: Webster
-- @Date:   2016-01-04 14:32:39
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-01-04 14:33:35
local _L = JH.LoadLangPack
-- 工资结算
local TEAM_VOTE_REQUEST = {}
JH.RegisterEvent("TEAM_VOTE_REQUEST", function()
	if arg0 == 1 then
		TEAM_VOTE_REQUEST = {}
		local team = GetClientTeam()
		for k, v in ipairs(team.GetTeamMemberList()) do
			TEAM_VOTE_REQUEST[v] = false
		end
	end
end)

JH.RegisterEvent("TEAM_VOTE_RESPOND", function()
	if arg0 == 1 and not IsEmpty(TEAM_VOTE_REQUEST) then
		if arg2 == 1 then
			TEAM_VOTE_REQUEST[arg1] = true
		end
		local team  = GetClientTeam()
		local num   = team.GetTeamSize()
		local agree = 0
		for k, v in pairs(TEAM_VOTE_REQUEST) do
			if v then
				agree = agree + 1
			end
		end
		JH.Topmsg(_L("Team Members: %d, %d agree %d%%", num, agree, agree / num * 100))
	end
end)

JH.RegisterEvent("TEAM_INCOMEMONEY_CHANGE_NOTIFY", function()
	local nTotalRaidMoney = GetClientTeam().nInComeMoney
	if nTotalRaidMoney and nTotalRaidMoney == 0 then
		TEAM_VOTE_REQUEST = {}
	end
end)
