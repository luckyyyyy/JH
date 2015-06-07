-- @Author: Webster
-- @Date:   2015-06-06 13:17:37
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-06-06 13:59:54


local UI = 	{
	["Lowest"] = {
		["ActionBar1"]         = "主快捷键栏",
		["ActionBar2"]         = "副快捷键栏",
		["ActionBar3"]         = "自定义快捷键栏一",
		["ActionBar4"]         = "自定义快捷键栏二",
		["CombatTextWnd"]      = "浮动战斗信息",
		["FullScreenSFX"]      = "全屏特效",
		["GlobalEventHandler"] = "GlobalEventHandler",
		["Hand"]               = "鼠标移动道具",
		["Scene"]              = "系统游戏场景",
	},
	["Lowest1"] = {
		["ChatTitleBG"]  = "聊天频道分类背景",
		["MainBarPanel"] = "主副快捷键栏背景",
	},
	["Lowest2"] = {
		["ChatPanel1"] = "聊天分类频道1",
		["ChatPanel2"] = "聊天分类频道2",
		["ChatPanel3"] = "聊天分类频道3",
		["ChatPanel4"] = "聊天分类频道4",
		["ChatPanel5"] = "聊天分类频道5",
		["ChatPanel6"] = "聊天分类频道6",
		["EditBox"]    = "聊天信息输入框",
	},
	["Normal"] = {
		["AnimationMgr"]        = "AnimationMgr",
		["BuffList"]            = "自身增益状态列表",
		["CampActiveTime"]      = "阵营活动时间",
		["CampPanel"]           = "阵营士气条",
		["CharacterPanel"]      = "人物装备面板",
		["CraftPanel"]          = "生活技能面板",
		["DebuffList"]          = "自身减益状态列表",
		["DialoguePanel"]       = "NPC对话窗口",
		["DurabilityPanel"]     = "装备持久提示",
		["ExpLine"]             = "人物经验条",
		["GuildMainPanel"]      = "帮会信息面板",
		["LootListExSingle"]    = "盒子插件_拾取助手",
		["MainMessageLine"]     = "屏幕顶部信息条",
		["Matrix"]              = "Matrix",
		["Player"]              = "自身头像面板",
		["QuestAcceptPanel"]    = "任务接取对话窗",
		["QuestPanel"]          = "任务查看面板",
		["ReputationIntroduce"] = "声望详细介绍面板",
		["SprintPower"]         = "轻功气力值图标",
		["Teammate"]            = "官方团队面板",
		["TopMenu"]             = "屏幕右上图标菜单",
		["Minimap"]             = "小地图面板",
		["SystemMenu_Left"]     = "屏幕左下图标菜单",
		["SystemMenu_Right"]    = "屏幕右下图标菜单",
		["DBM"]                 = "DBM_Core",
		["DBM_UI"]              = "DBM设置面板",
		["GKP"]                 = "金团记录",
		["TargetTarget"]        = "目标的目标面板",
	},
	["Normal1"] = {
		["GKP_Record"] = "GKP记录面板",
		["BL_UI"]      = "DBM_普通BUFF列表",
		["CA_UI"]      = "DBM_中央报警",
	},
	["Normal2"] = {
		["ST_UI"] = "DBM_倒计时",
	},
	["Topmost"] = {
		["BreatheBar"]       = "BreatheBar",
		["LoginMotp"]        = "LoginMotp",

		["OTActionBar"]      = "读条显示面板",
		["TargetMark"]       = "官方目标头顶标记",
	},
	["Topmost1"] = {
		["BattleTipPanel"]       = "战场提示信息",
		["PopupMenuPanel"]       = "游戏所有弹出菜单",
		["SceneCampTip"]         = "阵营场景提示信息",
		["TipPanel_Normal"]      = "屏幕右边提示信息",
		["TraceButton"]          = "屏幕右侧菜单图标",
	},
	["Topmost2"] = {
		["Announce"]        = "系统错误等提示区域",
		["EnterAreaTip"]    = "EnterAreaTip",
		["GMAnnouncePanel"] = "系统公告跑马灯区域",
		["LoadingPanel"]    = "游戏加载界面",
	}
}

local function GetMeun(ui)
	local menu, frames = { szOption = ui }, {}
	local frame = Station.Lookup(ui):GetFirstChild()
	while frame do
		table.insert(frames, { szName = frame:GetName() })
		frame = frame:GetNext()
	end
	table.sort(frames, function(a, b) return a.szName < b.szName end)
	for k, v in ipairs(frames) do
		local frame = Station.Lookup(ui .. "/" .. v.szName)
		table.insert(menu, {
			szOption = UI[ui][v.szName] and v.szName .. "（" .. UI[ui][v.szName]  .. "）" or  v.szName,
			bCheck = true,
			bChecked = frame:IsVisible(),
			rgb = frame:IsAddOn() and { 255, 255, 255 } or { 255, 255, 0 },
			fnAction = function()
				if frame:IsVisible() then
					frame:Hide()
				else
					frame:Show()
				end
			end
		})
	end
	return { menu }
end

for k, v in ipairs({ "Lowest", "Lowest1", "Lowest2", "Normal", "Normal1", "Normal2", "Topmost", "Topmost1", "Topmost2" })do
	TraceButton_AppendAddonMenu({function() return GetMeun(v) end})
end
