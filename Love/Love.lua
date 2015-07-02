-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-06-30 07:17:07
local _L = JH.LoadLangPack
JH_Love = {
	bQuiet = false,				-- 免打扰（拒绝其它人的查看请求）
	szNone = _L["Singleton"],		-- 没情缘时显示的字
	szJabber = _L["Hi, I seem to meet you somewhere ago"],	-- 搭讪用语
	bAutoFocus = true,	-- 自动焦点
}
JH.RegisterCustomData("JH_Love")
JH_Love.szTitle = _L["Lover of JX3"]

--[[
海鳗情缘局
========
1. 每个角色只允许有一个情缘，情缘必须是好友
2. 爱要坦荡荡，情缘信息无法隐藏（队友可直接查看，其它人则等您确认）
3. 建立双向情缘，要求六重好友组队并在5尺内，背包中要有真橙之心，并选其为目标，再点插件确认
4. 单向情缘，可以选择一个 3重好感以上的在线好友，对方会收到匿名通知
5. 情缘可以随时单向解除，但会密聊通知对方（单向情缘若不在线则不通知）
6. 若删除情缘好友则自动解除情缘关系


心动情缘：
    XXXXXXXXX (198大号字 ...) [斩情丝]
	类型：单恋/双向  时长：X天X小时X分钟X秒

	与六重队友结连理：[___________] （距离4尺内，带一个真橙之心）
	单恋某个三重好友：[___________] （要求在线，匿名通知对方）
	没情缘时显示什么：[___________]  [**] 开启免打扰模式

    情缘宣言： [________________________________________________________]
	搭讪用语： [________________________________________________________]

小提示：
    1. 仅安装本插件的玩家才能相互看见设置
	2. 情缘可以单方面删除，双向情缘会通过密聊告知对方
	3. 非队友查看情缘时目会弹出确认框（可开启免打扰屏蔽）
--]]

---------------------------------------------------------------------
-- 本地函数和变量
---------------------------------------------------------------------
local _i = Table_GetItemName
local _JH_Love = {
	dwID = 0,				-- 情缘 ID
	szName = "",		-- 情缘名字
	dwAvatar = 0,		-- 情缘头像
	nRoleType = 0,	-- 情缘体型（0：无情缘）
	nLoveType = 0,	-- 情缘类型（单向：0，双向：1）
	nStartTime = 0,	-- 情缘开始时间（单位：秒）
	szSign = "",			-- 情缘宣言（个性签名）
	tOther = {},			-- 查看的情缘数据（[0] = szName, [1] = dwAvatar,  [2] = szSign, [3] = nRoletype, [4] = nLoveType）
	tViewer = {},			-- 等候查看您的玩家列表
	dwRoot = 2669320,		-- root user id
}

-- 神秘表白语（单数：表白，双数：取消单恋通知）
_JH_Love.tAutoSay = {
	_L["Some people fancy you"],
	_L["Other side terminate love you"],
	_L["Some people fall in love with you"],
	_L["Other side gave up love you"],
}

-- 获取背包指定名称物品
_JH_Love.GetBagItemPos = function(szName)
	local me = GetClientPlayer()
	for dwBox = 1, BigBagPanel_nCount do
		for dwX = 0, me.GetBoxSize(dwBox) - 1 do
			local it = me.GetItem(dwBox, dwX)
			if it and GetItemNameByItem(it) == szName then
				return dwBox, dwX
			end
		end
	end
end

-- 根据背包坐标获取物品及数量
_JH_Love.GetBagItemNum = function(dwBox, dwX)
	local item = GetPlayerItem(GetClientPlayer(), dwBox, dwX)
	if not item then
		return 0
	elseif not item.bCanStack then
		return 1
	else
		return item.nStackNum
	end
end

-- 是否可结双向好友，并返回真橙之心的位置
_JH_Love.GetDoubleLoveItem = function(aInfo)
	if aInfo then
		local tar = GetPlayer(aInfo.id)
		if aInfo.attraction >= 800 and tar and JH.IsParty(tar.dwID) and JH.GetDistance(tar) <= 4 then
			return _JH_Love.GetBagItemPos(_i(67291))
		end
	end
end

-- 获取头像文件路径，帧序，是否动画
_JH_Love.GetAvatarFile = function(dwAvatar, nRoleType)
	-- mini avatar
	if dwAvatar > 0 then
		local tInfo = g_tTable.RoleAvatar:Search(dwAvatar)
		if tInfo then
			if nRoleType == ROLE_TYPE.STANDARD_MALE then
				return tInfo.szM2Image, tInfo.nM2ImgFrame, tInfo.bAnimate
			elseif nRoleType == ROLE_TYPE.STANDARD_FEMALE then
				return tInfo.szF2Image, tInfo.nF2ImgFrame, tInfo.bAnimate
			elseif nRoleType == ROLE_TYPE.STRONG_MALE then
				return tInfo.szM3Image, tInfo.nM3ImgFrame, tInfo.bAnimate
			elseif nRoleType == ROLE_TYPE.SEXY_FEMALE then
				return tInfo.szF3Image, tInfo.nF3ImgFrame, tInfo.bAnimate
			elseif nRoleType == ROLE_TYPE.LITTLE_BOY then
				return tInfo.szM1Image, tInfo.nM1ImgFrame, tInfo.bAnimate
			elseif nRoleType == ROLE_TYPE.LITTLE_GIRL then
				return tInfo.szF1Image, tInfo.nF1ImgFrame, tInfo.bAnimate
			end
		end
	end
	-- force avatar
	local tForce = { "shaolin", "wanhua", "tiance", "chunyang", "qixiu", "wudu", "tangmen", "cangjian", "gaibang", "mingjiao" }
	local szForce = tForce[0 - dwAvatar] or "jianghu"
	return "ui\\Image\\PlayerAvatar\\" .. szForce .. ".tga", -2, false
end

-- 保存好友数据
_JH_Love.SaveFellowRemark = function(id, remark)
	if not remark or remark == "" then
		remark = " "
	end
	GetClientPlayer().SetFellowshipRemark(id, remark)
	--[[
	Wnd.CloseWindow("PartyPanel")
	local frame = Wnd.OpenWindow("PartyPanel")
	local page = frame:Lookup("Wnd_FriendInfo")
	if not page then return end
	local edit = page:Lookup("Edit_Name")
	if not edit then return end
	page.dwID = id
	edit:SetLimit(128)
	Station.SetFocusWindow(edit)
	edit:SetText(remark)
	Station.SetFocusWindow(frame)
	Wnd.CloseWindow("PartyPanel")
	--]]
end

-- 根据 ID 获取数据好友信息
_JH_Love.GetFellowDataByID = function(id)
	local me = GetClientPlayer()
	local aGroup = me.GetFellowshipGroupInfo() or {}
	table.insert(aGroup, 1, {id = 0, name = g_tStrings.STR_FRIEND_GOOF_FRIEND})
	for _, v in ipairs(aGroup) do
		local aFriend = me.GetFellowshipInfo(v.id) or {}
		for _, vv in ipairs(aFriend) do
			if vv.id == id then
				return vv
			end
		end
	end
	return nil
end

-- 加入校验和确保数据不被篡改（0-255）
_JH_Love.EncodeString = function(szData)
	local nCrc = 0
	for i = 1, string.len(szData) do
		nCrc = (nCrc + string.byte(szData, i)) % 255
	end
	return string.format("%02x", nCrc) .. szData
end

-- 剔除校验和提取原始数据
_JH_Love.DecodeString = function(szData)
	if string.len(szData) > 2 then
		local nCrc = 0
		for i = 3, string.len(szData) do
			nCrc = (nCrc + string.byte(szData, i)) % 255
		end
		if nCrc == tonumber(string.sub(szData, 1, 2), 16) then
			return string.sub(szData, 3)
		end
	end
end

-- 按键值保存数据到好友备注（成功 true，失败 false）
-- FIXME：通过 ID 保存数据时可能会覆盖已有其它含义的数据！！！
_JH_Love.SetFellowDataByKey = function(szKey, szData, dwID, bEnc)
	local szKey, me, slot = "#HM#" .. szKey .. "#", GetClientPlayer(), nil
	if not me then return Output("not me") end
	local aGroup = me.GetFellowshipGroupInfo() or {}
	table.insert(aGroup, 1, { id = 0, name = g_tStrings.STR_FRIEND_GOOF_FRIEND })
	if bEnc and szData then
		szData = _JH_Love.EncodeString(szData)
	end
	for _, v in ipairs(aGroup) do
		local aFriend = me.GetFellowshipInfo(v.id) or {}
		for i = #aFriend, 1, -1 do
			local info = aFriend[i]
			local bMatch = string.sub(info.remark, 1, string.len(szKey)) == szKey
			if not szData then
				-- fetch data
				if bMatch then
					local szData = string.sub(info.remark, string.len(szKey) + 1)
					if bEnc then
						szData = _JH_Love.DecodeString(szData)
					end
					return szData, info
				end
			elseif not dwID then
				-- set by Key
				if bMatch then
					_JH_Love.SaveFellowRemark(info.id, szKey .. szData)
					return true, info
				end
				-- find slot
				if string.sub(info.remark, 1, 4) ~= "#HM#" and (not slot or info.attraction < slot.attraction) then
					slot = info
				end
			else
				-- set by ID (unique key)
				if dwID == info.id then
					slot = info
				elseif bMatch then
					_JH_Love.SaveFellowRemark(info.id, "")
				end
			end
		end
	end
	-- last result
	if szData then
		if slot then
			_JH_Love.SaveFellowRemark(slot.id, szKey .. szData)
			return true, slot
		else
			return false, nil
		end
	end
end

-- 按键值从好友备注中提取数据（成功返回数据 + rawInfo，失败 nil）
_JH_Love.GetFellowDataByKey = function(szKey, bEnc)
	return _JH_Love.SetFellowDataByKey(szKey, nil, nil, bEnc)
end

-- 转换好友信息为情缘信息
_JH_Love.ToLocalLover = function(aInfo)
	if not aInfo then
		_JH_Love.dwID = 0
		_JH_Love.szName = ""
		_JH_Love.dwAvatar = 0
		_JH_Love.nRoleType = 0
		_JH_Love.nLoveType = 0
		_JH_Love.nStartTime = 0
	else
		_JH_Love.dwID = aInfo.id
		_JH_Love.szName = aInfo.name
		_JH_Love.dwAvatar = aInfo.miniavatar
		_JH_Love.nRoleType = aInfo.roletype
		if aInfo.miniavatar == 0 then
			_JH_Love.dwAvatar = 0 - aInfo.forceid
		end
	end
end

-- 获取情缘类型
_JH_Love.GetLoverType = function(nType)
	nType = nType or _JH_Love.nLoveType
	if nType == 1 then
		return _L["Mutual love"]
	else
		return _L["Blind love"]
	end
end

-- 获取情缘时长
_JH_Love.GetLoverTime = function(nTime)
	nTime = nTime or _JH_Love.nStartTime
	local nSec = GetCurrentTime() - nTime
	local szTime = ""
	if nSec <= 60 then
		return nSec .. _L["sec"]
	elseif nSec < 3600 then	-- X分钟X秒
		return _L("%d min %d sec", nSec / 60, nSec % 60)
	elseif nSec < 86400 then	-- X小时X分钟
		return _L("%d hour %d min", nSec / 3600, (nSec % 3600) / 60)
	elseif nSec < 31536000 then	-- X天X小时
		return _L("%d day %d hour", nSec / 86400, (nSec % 86400) / 3600)
	else	-- X年X天
		return _L("%d year %d day", nSec / 31536000, (nSec % 31536000) / 86400)
	end
end

-- 保存情缘
_JH_Love.SaveLover = function(aInfo, nType, nTime)
	nTime = nTime or GetCurrentTime()
	_JH_Love.SetFellowDataByKey("LOVER", nType .. "#" .. nTime, aInfo.id, true)
	_JH_Love.ToLocalLover(aInfo)
	_JH_Love.nLoveType = nType
	_JH_Love.nStartTime = nTime
	_JH_Love.PS.Refresh()
	JH.Talk(PLAYER_TALK_CHANNEL.TONG, _L("From now on, my heart lover is [%s]", aInfo.name))
end

-- 设置情缘
_JH_Love.SetLover = function(dwID, nType)
	if not dwID then
		-- 取消情缘
		if _JH_Love.nLoveType == 1 then			-- 双向则密聊提醒
			JH.Talk(_JH_Love.szName, _L["Sorry, I decided to just a swordman, bye my plugin lover"])
		elseif _JH_Love.nLoveType == 0 then	-- 单向只通知在线的
			local aInfo = _JH_Love.GetFellowDataByID(_JH_Love.dwID)
			if aInfo and aInfo.isonline then
				JH.BgTalk(_JH_Love.szName, "HM_LOVE", "REMOVE0")
			end
		end
		-- 清空数据
		JH.Talk(PLAYER_TALK_CHANNEL.TONG, _L("A blade and cut, no longer meet with [%s]", _JH_Love.szName))
		_JH_Love.SaveFellowRemark(_JH_Love.dwID, "")
		_JH_Love.ToLocalLover(nil)
		_JH_Love.PS.Refresh()
		JH.Sysmsg(_L["Congratulations, do not repeat the same mistakes ah"])
	else
		-- 设置成为情缘（在线好友）
		local aInfo = _JH_Love.GetFellowDataByID(dwID)
		if not aInfo or not aInfo.isonline then
			return JH.Alert(_L["Lover must be a online friend"])
		end
		if nType == 0 then
			-- 单向情缘（简单）
			_JH_Love.SaveLover(aInfo, nType)
			JH.BgTalk(aInfo.name, "HM_LOVE", "LOVE0")
		else
			-- 双向情缘（在线，组队一起，并且在4尺内，发起方带有一个真橙之心）
			if not _JH_Love.GetDoubleLoveItem(aInfo) then
				return JH.Alert(_L("Inadequate conditions, requiring Lv6 friend/party/4-feet distance/%s", _i(67291)))
			end
			JH.BgTalk(aInfo.name, "HM_LOVE", "LOVE_ASK")
			JH.Sysmsg(_L("Love request has been sent to [%s], wait please", aInfo.name))
		end
	end
end

-- 删除情缘
_JH_Love.RemoveLover = function()
	if _JH_Love.dwID ~= 0 then
		local nTime = GetCurrentTime() - _JH_Love.nStartTime
		if nTime < 3600 then
			return JH.Alert(_L("Love can not run a red-light, [%d] seconds left", 3600 - nTime))
		end
		JH.Confirm(_L("Are you sure to cut love with [%s]?", _JH_Love.szName), function()
			JH.DelayCall(50, function() JH.Confirm(_L["Past five hundred times looking back only in exchange for a chance encounter this life, you really decided?"], function()
				JH.DelayCall(50, function() JH.Confirm(_L["You do not really want to cut off love it, really sure?"], function()
					_JH_Love.SetLover(nil)
				end) end)
			end) end)
		end)
	end
end

-- 修复双向情缘
_JH_Love.FixLover = function()
	if _JH_Love.nLoveType ~= 1 then
		return JH.Alert(_L["Repair feature only supports mutual love!"])
	end
	if not JH.IsParty(_JH_Love.dwID) then
		return JH.Alert(_L["Both sides must in a team to be repaired!"])
	end
	JH.BgTalk(_JH_Love.szName, "HM_LOVE", "FIX1", _JH_Love.nStartTime)
	JH.Sysmsg(_L["Repair request has been sent, wait please"])
end

-- 获取可情缘好友列表
_JH_Love.GetLoverMenu = function(nType)
	local me, m0 = GetClientPlayer(), {}
	local aGroup = me.GetFellowshipGroupInfo() or {}
	table.insert(aGroup, 1, {id = 0, name = g_tStrings.STR_FRIEND_GOOF_FRIEND})
	for _, v in ipairs(aGroup) do
		local aFriend = me.GetFellowshipInfo(v.id) or {}
		for _, vv in ipairs(aFriend) do
			if vv.attraction >= 200 and (nType ~= 1 or vv.attraction >= 800) then
				table.insert(m0, {
					szOption = vv.name,
					fnDisable = function() return not vv.isonline end,
					fnAction = function()
						JH.Confirm(_L("Do you want to love with [%s]?", vv.name), function()
							_JH_Love.SetLover(vv.id, nType)
						end)
					end
				})
			end
		end
	end
	if #m0 == 0 then
		table.insert(m0, { szOption = _L["<Non-avaiable>"] })
	end
	return m0
end

-- 保存签名
_JH_Love.SetSign = function(szSign)
	szSign = JH.Trim(szSign)
	_JH_Love.szSign = szSign
	JH.DelayCall(3000, function()
		if szSign == _JH_Love.szSign then
			local szPart1, szPart2 = "", ""
			if string.len(szSign) > 22 then
				-- 分割确保不乱码
				local i = 1
				while i < 21 do
					if string.byte(szSign, i) < 128 then
						i = i + 1
					else
						i = i + 2
					end
				end
				szPart1 = string.sub(szSign, 1, i - 1)
				szPart2 = string.sub(szSign, i)
			else
				szPart1, szPart2 = szSign, " "
			end
			if not _JH_Love.SetFellowDataByKey("S1", szPart1) then
				return JH.Alert(_L["Save signature failed, please add some friends."])
			end
			_JH_Love.SetFellowDataByKey("S2", szPart2)
		end
	end)
end

-- 更新情缘面板信息
_JH_Love.UpdatePage = function()
	local p = Station.Lookup("Normal/PlayerView/Page_Main/Page_Love")
	if not p then return end
	local tar = GetPlayer(p:GetParent().dwPlayer)
	if not tar then
		return p:GetRoot():Hide()
	end
	local h, t = p:Lookup("", ""), _JH_Love.tOther
	-- t = {  szName, dwAvatar, szSign, nRoleType, nLoveType, nStartTime }
	h:Lookup("Text_LTitle"):SetText(tar.szName .. _L["'s Lover"])
	-- lover
	local txt = h:Lookup("Text_Lover")
	txt:SetText(t[1] or _L["...Loading..."])
	txt.szPlayer = t[1]
	-- avatar
	local dwAvatar = tonumber(t[2]) or 0
	local img, ani = h:Lookup("Image_Lover"), h:Lookup("Animate_Lover")
	if dwAvatar == 0 then
		img:Hide()
		ani:Hide()
		txt:SetRelPos(42, 92)
		txt:SetSize(300, 25)
		txt:SetHAlign(1)
	else
		local szFile, nFrame, bAnimate = _JH_Love.GetAvatarFile(dwAvatar, tonumber(t[4]) or 1)
		if bAnimate then
			ani:SetAnimate(szFile, nFrame)
			--ani:SetAnimateType(ANIMATE.FLIP_HORIZONTAL)
			ani:Show()
			img:Hide()
			ani.szPlayer = t[1]
		else
			if nFrame < 0 then
				img:FromTextureFile(szFile)
			else
				img:FromUITex(szFile, nFrame)
			end
			if nFrame == -2 then
				img:SetImageType(IMAGE.NORMAL)
			else
				img:SetImageType(IMAGE.FLIP_HORIZONTAL)
			end
			ani:Hide()
			img:Show()
			img.szPlayer = t[1]
		end
		txt:SetRelPos(130, 92)
		txt:SetSize(200, 25)
		txt:SetHAlign(0)
	end
	-- lover info
	local inf = h:Lookup("Text_LoverInfo")
	if t[5] and t[6] and dwAvatar ~= 0 then
		local szText = _JH_Love.GetLoverType(tonumber(t[5]) or 0) .. "   " .. _JH_Love.GetLoverTime(tonumber(t[6]) or 0)
		inf:SetText(szText)
	else
		inf:SetText("")
	end
	-- sign title
	h:Lookup("Text_SignTTL"):SetText(tar.szName .. _L["'s Love signature:"])
	-- sign
	local szSign = t[3]
	if not szSign then
		szSign = _L["If it is always loading, the target may not install plugin or turn on quiet mode, strongly recommend to query after team up."]
	elseif szSign == "" then
		szSign = _L["This guy is very lazy, nothing left!"]
	end
	h:Lookup("Text_Sign"):SetText(szSign)
	-- btn
	local txt = p:Lookup("Btn_LoveYou"):Lookup("", "Text_LoveYou")
	if tar.nGender == 2 then
		txt:SetText(_L["Strike up her"])
	else
		txt:SetText(_L["Strike up him"])
	end
	h:FormatAllItemPos()
end

-- 后台请求别人的情缘数据
_JH_Love.AskOtherData = function(dwID)
	local tar = GetPlayer(dwID)
	if not tar then
		return
	end

	_JH_Love.tOther = {}
	_JH_Love.UpdatePage()
	if tar.bFightState and not JH.IsParty(tar.dwID) then
		_JH_Love.bActiveLove = false
		return JH.Sysmsg("[" .. tar.szName .. "] " .. _L[" in fighting, no time for you"])
	end
	JH.BgTalk(tar.szName, "HM_LOVE", "VIEW")

end

-------------------------------------
-- 事件处理
-------------------------------------
-- 好友数据更新，随时检查情缘变化（删除好友改备注等）
_JH_Love.OnFellowUpdate = function()
	-- 载入情缘
	local szData, aInfo = _JH_Love.GetFellowDataByKey("LOVER", true)
	if not szData and _JH_Love.dwID ~= 0 then
		_JH_Love.ToLocalLover(nil)
		_JH_Love.PS.Refresh()
	end
	if aInfo and _JH_Love.dwID ~= aInfo.id then
		local data = SplitString(szData, "#")
		_JH_Love.ToLocalLover(aInfo)
		_JH_Love.nLoveType = tonumber(data[1]) or 0
		_JH_Love.nStartTime = tonumber(data[2]) or GetCurrentTime()
		_JH_Love.PS.Refresh()
		-- 上线提示
		if not _JH_Love.bLoaded and aInfo.isonline then
			local szMsg = _L["Warm tip: Your "] .. _JH_Love.GetLoverType() .. _L("Lover <link0> is happy in [%s].\n", Table_GetMapName(aInfo.mapid))
			_JH_Love.OnLoverMsg(szMsg)
		end
	end
	-- 第一次加载：签名
	if not _JH_Love.bLoaded then
		local szData, _ = _JH_Love.GetFellowDataByKey("S1")
		if szData then
			_JH_Love.szSign =szData
			local szData, _ = _JH_Love.GetFellowDataByKey("S2")
			if szData then
				_JH_Love.szSign = _JH_Love.szSign .. szData
			end
			_JH_Love.szSign = JH.Trim(_JH_Love.szSign)
		end
		_JH_Love.bLoaded = true
	end
end

-- 查看别人装备、情缘
_JH_Love.OnPeekOtherPlayer = function()
	if arg0 ~= 1 then return end
	local mPage = Station.Lookup("Normal/PlayerView/Page_Main")
	if not mPage then
		return
	end
	-- attach page
	if not mPage.bLoved then
		local frame = Wnd.OpenWindow("interface/JH/Love/Love.ini", "HM_Love")
		local pageset = frame:Lookup("Page_Main")
		local checkbox = pageset:Lookup("CheckBox_Love")
		local page = pageset:Lookup("Page_Love")
		checkbox:ChangeRelation(mPage, true, true)
		page:ChangeRelation(mPage, true, true)
		Wnd.CloseWindow(frame)
		checkbox:SetRelPos(270, 510)
		page:SetRelPos(0, 0)
		mPage:AddPage(page, checkbox)
		checkbox:Show()
		mPage.bLoved = true
		-- events
		mPage.OnActivePage = function()
			PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
			if this:GetActivePage():GetName() == "Page_Love" then
				_JH_Love.AskOtherData(this.dwPlayer)
			end
		end
		page:Lookup("Btn_LoveYou").OnLButtonClick = function()
			local mp = this:GetParent():GetParent()
			local tar = GetPlayer(mp.dwPlayer)
			if tar then
				JH.Talk(tar.szName, JH_Love.szJabber)
			end
		end
		page:Lookup("Btn_LoveYou").OnRButtonClick = function()
			local mp = this:GetParent():GetParent()
			local tar = GetPlayer(mp.dwPlayer)
			if tar then
				local m0, me = {}, GetClientPlayer()
				InsertInviteTeamMenu(m0, tar.szName)
				if me.IsInParty() and me.dwID == GetClientTeam().GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK) then
					InsertMarkMenu(m0, tar.dwID)
				end
				if me.IsInParty() and me.IsPlayerInMyParty(tar.dwID) then
					InsertTeammateLeaderMenu(m0, tar.dwID)
				end
				if #m0 > 0 then
					table.insert(m0, { bDevide = true })
				end
				InsertPlayerCommonMenu(m0, tar.dwID, tar.szName)
				PopupMenu(m0)
			end
		end
		page:Lookup("", "Image_Lover").OnItemRButtonDown = function()
			if this.szPlayer then
				local m0 = {}
				InsertPlayerCommonMenu(m0, 0, this.szPlayer)
				PopupMenu(m0)
			end
		end
		page:Lookup("", "Text_Lover").OnItemRButtonDown = page:Lookup("", "Image_Lover").OnItemRButtonDown
		page:Lookup("", "Animate_Lover").OnItemRButtonDown = page:Lookup("", "Image_Lover").OnItemRButtonDown
		page:Lookup("", "Text_LTitle"):SetText(_L["Lover"])
		page:Lookup("", "Text_SignTTL"):SetText(_L["Love signature:"])
		page:Lookup("", "Text_Lover"):SetFontColor(255, 128, 255)
		checkbox:Lookup("", "Text_LoveCaptical"):SetText(_L["Lover"])
	end
	-- update page
	mPage.dwPlayer = arg1
	-- active page
	if _JH_Love.bActiveLove then
		_JH_Love.bActiveLove = false
		mPage:ActivePage("Page_Love")
	end
end

-- 回复情缘信息
_JH_Love.ReplyLove = function(bCancel)
	local szName, bRoot = _JH_Love.szName, false
	local root = nil
	if _JH_Love.dwID == 0 then
		szName = "<" .. JH_Love.szNone .. ">"
		bRoot = GetClientPlayer().szName == _L["HMM5"]
		if not bRoot then
			root = GetPlayer(_JH_Love.dwRoot)
		end
	elseif bCancel then
		szName = _L["<Not tell you>"]
	end
	for k, v in pairs(_JH_Love.tViewer) do
		if bRoot or root then
			local p = root or GetPlayer(k)
			if p then
				szName = p.szName
				_JH_Love.dwAvatar = p.dwMiniAvatarID
				_JH_Love.nRoleType = p.nRoleType
				_JH_Love.nLoveType = 1
				_JH_Love.nStartTime =  GetCurrentTime() - 1173600
				if p.dwMiniAvatarID == 0 then
					_JH_Love.dwAvatar = 0 - p.dwForceID
				end
			end
		end
		JH.BgTalk(v, "HM_LOVE", szName,
			_JH_Love.dwAvatar, _JH_Love.szSign, _JH_Love.nRoleType,
			_JH_Love.nLoveType, _JH_Love.nStartTime)
	end
	_JH_Love.tViewer = {}
end

-- 后台同步
_JH_Love.OnBgTalk = function(nChannel, dwID, szName, data, bIsSelf)
	if HM_Love then return end
	if not bIsSelf then
		if data[1] == "VIEW" then
			if JH.IsParty(dwID) then
				_JH_Love.tViewer[dwID] = szName
				_JH_Love.ReplyLove()
			elseif not GetClientPlayer().bFightState and not JH_Love.bQuiet then
				_JH_Love.tViewer[dwID] = szName
				JH.Confirm(
					"[" .. szName .. "] " .. _L["want to see your lover info, OK?"],
					function() _JH_Love.ReplyLove() end,
					function() _JH_Love.ReplyLove(true) end
				)
			end
		elseif data[1] == "LOVE0" or data[1] == "REMOVE0" then
			local i = math.random(1, math.floor(table.getn(_JH_Love.tAutoSay)/2)) * 2
			if data[1] == "LOVE0" then
				i = i - 1
			end
			OutputMessage("MSG_WHISPER", _L["[Mystery] quietly said:"] .. _JH_Love.tAutoSay[i] .. "\n")
			PlaySound(SOUND.UI_SOUND,g_sound.Whisper)
		elseif data[1] == "LOVE_ASK" then
			-- 已有情缘直接拒绝
			if _JH_Love.dwID ~= 0 and (_JH_Love.dwID ~= dwID or _JH_Love.nLoveType == 1) then
				return JH.BgTalk(szName, "HM_LOVE", "LOVE_ANS", "EXISTS")
			end
			-- 询问意见
			JH.Confirm("[" .. szName .. "] " .. _L["want to mutual love with you, OK?"], function()
				JH.BgTalk(szName, "HM_LOVE", "LOVE_ANS", "YES")
			end, function()
				JH.BgTalk(szName, "HM_LOVE", "LOVE_ANS", "NO")
			end)
		elseif data[1] == "FIX1" then
			if _JH_Love.dwID == 0 or (_JH_Love.dwID == dwID and _JH_Love.nLoveType ~= 1) then
				local aInfo = _JH_Love.GetFellowDataByID(dwID)
				if aInfo then
					JH.Confirm("[" .. aInfo.name .. "] " .. _L["want to repair love relation with you, OK?"], function()
						_JH_Love.SaveLover(aInfo, 1, tonumber(data[2]))
						JH.Sysmsg(_L("Congratulations, love relation with [%s] has been fixed!", aInfo.name))
					end)
				end
			else
				JH.BgTalk(szName, "HM_LOVE", "LOVE_ANS", "EXISTS")
			end
		elseif data[1] == "LOVE_ANS" then
			if data[2] == "EXISTS" then
				local szMsg = _L["Unfortunately the other has lover, but you can still blind love him!"]
				JH.Sysmsg(szMsg)
				JH.Alert(szMsg)
			elseif data[2] == "NO" then
				local szMsg = _L["The other refused you without reason, but you can still blind love him!"]
				JH.Sysmsg(szMsg)
				JH.Alert(szMsg)
			elseif data[2] == "YES" then
				local aInfo = _JH_Love.GetFellowDataByID(dwID)
				local dwBox, dwX = _JH_Love.GetDoubleLoveItem(aInfo)
				if dwBox then
					local nNum = _JH_Love.GetBagItemNum(dwBox, dwX)
					SetTarget(TARGET.PLAYER, aInfo.id)
					OnUseItem(dwBox, dwX)
					JH.DelayCall(500, function()
						if _JH_Love.GetBagItemNum(dwBox, dwX) ~= nNum then
							_JH_Love.SaveLover(aInfo, 1)
							JH.BgTalk(aInfo.name, "HM_LOVE", "LOVE_ANS", "CONF")
							JH.Sysmsg(_L("Congratulations, success to attach love with [%s]!", aInfo.name))
						end
					end)
				end
			elseif data[2] == "CONF" then
				local aInfo = _JH_Love.GetFellowDataByID(dwID)
				if aInfo then
					_JH_Love.SaveLover(aInfo, 1)
					JH.Sysmsg(_L("Congratulations, success to attach love with [%s]!", aInfo.name))
				end
			end
		else
			_JH_Love.tOther = data
			_JH_Love.UpdatePage()
		end
	end
end

-- 情缘名字链接通知
_JH_Love.OnLoverMsg = function(szMsg)
	local szChannel = "MSG_SYS"
	local szFont = GetMsgFontString(szChannel)
	szMsg = FormatLinkString(szMsg, szFont, MakeNameLink("[" .. _JH_Love.szName .. "]", szFont))
	OutputMessage(szChannel, szMsg, true)
end

-- 上线，下线通知：bOnLine, szName, bFoe
_JH_Love.OnFriendLogin = function()
	if not  arg2 and arg1 == _JH_Love.szName then
		local szMsg = _L["Warm tip: Your "] .. _JH_Love.GetLoverType() .. _L["Lover <link0>"]
		if arg0 then
			szMsg = szMsg .. _L["online, hurry doing needy doing.\n"]
			OnBowledCharacterHeadLog(GetClientPlayer().dwID, _L["Love Tip: "] .. arg1 .. _L["onlines now"], 199, { 255, 0, 255 })
			PlaySound(SOUND.UI_SOUND, g_sound.LevelUp)
		else
			szMsg = szMsg .. _L["offline, hurry doing like doing.\n"]
		end
		_JH_Love.OnLoverMsg(szMsg)
	end
end

-- 禁止修改情缘好友备注、禁止显示备注
_JH_Love.OnBreathe = function()
	-- social list
	local hL = Station.Lookup("Normal/SocialPanel/PageSet_Company/Page_Friend/WndScroll_Friend", "")
	if hL and hL:IsVisible() then
		for i = 0, hL:GetItemCount() - 1, 1 do
			local hI = hL:Lookup(i)
			if hI.bPlayer and hI.info and hI.info.remark
				and (hI.info.remark == " " or string.sub(hI.info.remark, 1, 4) == "#HM#")
			then
				hI:Lookup("Text_N"):SetText(hI.info.name)
			end
		end
		local input = Station.Lookup("Topmost/GetNamePanel")
		if input and not input.bChecked
			and input:Lookup("", "Text_Msg"):GetText() == g_tStrings.STR_FRIEND_INPUT_MARK
		then
			local edit = input:Lookup("Edit_Input")
			if string.sub(edit:GetText(), 1, 10) == "#HM#LOVER#" then
				edit:Enable(0)
				input:Lookup("Btn_Sure"):Enable(false)
			end
			input.bChecked = true
		end
	end
	-- friendrank
	local hL = Station.Lookup("Normal/FriendRank/Wnd_PRanking", "Handle_RankingMes")

end

-- player enter
_JH_Love.OnPlayerEnter = function()
	if JH_Love.bAutoFocus and arg0 == _JH_Love.dwID then
		if HM_TargetList and HM_TargetList.AddFocus and not IsInArena() then
			HM_TargetList.AddFocus(arg0)
		end
	end
end

-------------------------------------
-- 设置界面
-------------------------------------
_JH_Love.PS = {}

-- refresh
_JH_Love.PS.Refresh = function()
	if _JH_Love.ui then
		JH.OpenPanel(JH_Love.szTitle)
	end
end

-- init
_JH_Love.PS.OnPanelActive = function(frame)
	local ui, nX = GUI(frame), 0
	ui:Append("Text", { txt = _L["Heart lover"], x = 0, y = 0, font = 27 })
	-- lover info
	if _JH_Love.dwID == 0 then
		ui:Append("Text", { txt = _L["No lover :-("], font = 19, x = 10, y = 36 })
		-- create lover
		nX = ui:Append("Text", { txt = _L["Mutual love friend Lv.6: "], x = 10, y = 72 }):Pos_()
		nX = ui:Append("WndComboBox", { txt = _L["- Select plz -"], x = nX + 5, y = 72, w = 200, h = 25 })
		:Menu(function() return _JH_Love.GetLoverMenu(1) end):Pos_()
		ui:Append("Text", { txt = _L("(4-feets, +%s)", _i(67291)), x = nX + 5, y = 72 })
		nX = ui:Append("Text", { txt = _L["Blind love friend Lv.2: "], x = 10, y = 100 }):Pos_()
		nX = ui:Append("WndComboBox", { txt = _L["- Select plz -"], x = nX + 5, y = 100, w = 200, h = 25 })
		:Menu(function() return _JH_Love.GetLoverMenu(0) end):Pos_()
		ui:Append("Text", { txt = _L["(Online required, notify anonymous)"], x = nX + 5, y = 100 })
	else
		-- show lover
		ui:Append("Text", { txt = _JH_Love.szName, font = 19, x = 10, y = 36 })
		:Color(255, 128, 255)
		nX = ui:Append("Text", { txt = _JH_Love.GetLoverType(), font = 2, x = 10, y = 72 }):Pos_()
		nX = ui:Append("Text", { txt = _JH_Love.GetLoverTime(), font = 2, x = nX + 10, y = 72 }):Pos_()
		nX = ui:Append("Text", { txt = _L["[Break love]"], x = nX + 10, y = 72 })
		:Click(_JH_Love.RemoveLover, { 128, 255, 255 }, { 0, 255, 255 }):Pos_()
		if _JH_Love.nLoveType == 1 then
			nX = ui:Append("Text", { txt = _L["[Recovery]"], x = nX + 10, y = 72 }):Click(_JH_Love.FixLover, { 128, 255, 255 }, { 0, 255, 255 }):Pos_()
		end
		ui:Append("WndCheckBox", { txt = _L["Auto focus lover"], x = nX + 10, y = 72, checked = JH_Love.bAutoFocus })
		:Click(function(bChecked)
			JH_Love.bAutoFocus = bChecked
			if not bChecked and _JH_Love.dwID ~=0 and HM_TargetList and HM_TargetList.DelFocus then
				HM_TargetList.DelFocus(_JH_Love.dwID)
			end
		end)
	end
	-- local setting
	nX = ui:Append("Text", { txt = _L["Non-love display: "], x = 10, y = 128 }):Pos_()
	nX = ui:Append("WndEdit", { x = nX + 5, y = 128, limit = 20, w = 198, h = 25, txt = JH_Love.szNone })
	:Change(function(szText) JH_Love.szNone = szText end):Pos_()
	ui:Append("WndCheckBox", { txt = _L["Enable quiet mode"], x = nX + 5, y = 128, checked = JH_Love.bQuiet  })
	:Click(function(bChecked) JH_Love.bQuiet = bChecked end)
	-- jabber
	nX = ui:Append("Text", { txt = _L["Quick to accost text: "], x = 10, y = 156 }):Pos_()
	ui:Append("WndEdit", { x = nX + 5, y = 156, limit = 128, w = 340, h = 25, txt = JH_Love.szJabber })
	:Change(function(szText) JH_Love.szJabber = szText end)
	-- signature
	nX = ui:Append("Text", { txt = _L["Love signature: "], x = 10, y = 192, font = 27 }):Pos_()
	ui:Append("WndEdit", { x = nX + 5, y = 192, limit = 42, w = 340, h = 48, multi = true, txt = _JH_Love.szSign }):Change(_JH_Love.SetSign)
	-- tips
	ui:Append("Text", { txt = _L["Tips"], x = 0, y = 228, font = 27 })
	ui:Append("Text", { txt = _L["1. Amuse only, both sides need to install this plug-in"], x = 10, y = 253 })
	ui:Append("Text", { txt = _L["2. You can break love one-sided"], x = 10, y = 278 })
	ui:Append("Text", { txt = _L["3. Non-party views need to confirm (enable quiet to avoid)"], x = 10, y = 303 })
	_JH_Love.ui = ui
end

-- deinit
_JH_Love.PS.OnPanelDeactive = function()
	_JH_Love.ui = nil
end

---------------------------------------------------------------------
-- 注册事件、初始化
---------------------------------------------------------------------
if not HM_Love then
	JH.RegisterBgMsg("HM_LOVE", _JH_Love.OnBgTalk)
	JH.RegisterEvent("PEEK_OTHER_PLAYER", _JH_Love.OnPeekOtherPlayer)
	JH.RegisterEvent("PLAYER_FELLOWSHIP_LOGIN", _JH_Love.OnFriendLogin)

	JH.RegisterEvent("PLAYER_ENTER_SCENE", _JH_Love.OnPlayerEnter)
	JH.BreatheCall("JH_Love", _JH_Love.OnBreathe)
end
JH.RegisterEvent("PLAYER_FELLOWSHIP_UPDATE", _JH_Love.OnFellowUpdate)
GUI.RegisterPanel(JH_Love.szTitle, 329, _L["Recreation"], _JH_Love.PS)

-- view other lover by dwID
function JH_Love.PeekOther(dwID)
	ViewInviteToPlayer(dwID)
	_JH_Love.bActiveLove = true
	if not JH.IsParty(dwID) then
		_JH_Love.AskOtherData(dwID)
	end
end

if not HM_Love then
Target_AppendAddonMenu({ function(dwID)
	return {{
		szOption = _L["View love info"],
		fnDisable = function() return dwID == GetClientPlayer().dwID or not IsPlayer(dwID) end,
		fnAction = function() JH_Love.PeekOther(dwID) end
	}}
end })
end
