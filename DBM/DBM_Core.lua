-- @Author: Webster
-- @Date:   2015-05-13 16:06:53
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-05-13 16:38:06
--[[
DBM_TYPE = {
	OTHER       = 0,
	BUFF_GET    = 1,
	BUFF_LOSE   = 2,
	NPC_ENTER   = 3,
	NPC_LEAVE   = 4,
	NPC_TALK    = 5,
	NPC_LIFE    = 6,
	NPC_FIGHT   = 7,
	SKILL_BEGIN = 8,
	SKILL_END   = 9,
	SYS_TALK    = 10,
}
数据结构设计
data = {
	【TYPE】 = {
		{
			nScrutinyType = DBM_SCR_TYPE
		}
	}
}

]]
local DBM_SCRUTINY_TYPE = {
	ALL   = 0,
	SELF  = 1,
	TEAM  = 2,
	ENEMY = 3
}
local DBM_INIFILE  = JH.GetAddonInfo().szRootPath .. "DBM/ui/DBM.ini"
local D = {}

DBM = {
	bEnable = true,
}

function DBM.OnFrameCreate()
	this:RegisterEvent("NPC_ENTER_SCENE")
	this:RegisterEvent("NPC_LEAVE_SCENE")
	this:RegisterEvent("BUFF_UPDATE")
	this:RegisterEvent("SYS_MSG")
	this:RegisterEvent("DO_SKILL_CAST")
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("PLAYER_SAY")
	this:RegisterEvent("ON_WARNING_MESSAGE")
end

function DBM.OnEvent(szEvent)
end

function D.GetFrame()
	return Station.Lookup("Normal/DBM")
end

function D.Open()
	if not D.GetFrame() then
		Wnd.OpenWindow(DBM_INIFILE, "DBM")
	end
end

function D.Close()
	if D.GetFrame() then
		Wnd.CloseWindow(Station.Lookup("Normal/DBM")) -- kill all event
	end
end

function D.Enable(bEnable)
	if bEnable then
		local res, err = pcall(D.Open)
		if not res then
			JH.Sysmsg2(err)
		end
	else
		D.Close()
	end
end

function D.Init()
	D.Enable(DBM.bEnable)
end

JH.RegisterEvent("LOADING_END", D.Init)
