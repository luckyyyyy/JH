local _L = JH.LoadLangPack
local HEXIE_ALPHA = 5
BossFaceAlert =  {	
	Setting = {
	-- 头顶那个方块
		dwTopFontSchemeID = 40, -- 头顶字体ID
		fTopScale = 1.5, -- 头顶文字的缩放
		tTopDelta = {0,0,0,0,-25},
	-- TEXT
		dwFontSchemeID = 40, -- 文字字体ID
		fScale = 1, -- 文字的缩放
		fTopDelta = 50, --场景坐标高度的调整值，
	-- col
		sTarSelf = {255,0,128}, -- 监视目标自己 给粉色的
		sTarOther = {255,250,50}, --监视目标 不是自己 给黄色的
		cOther = {255, 255, 0}, -- 其他东西
	}
}

local BossfaceAlertUpdateAlertName = {}

BFA = {}
local _BFA = {
	szItemIni = JH.GetAddonInfo().szShadowIni,
	tLastTargetTime = {},
	tLastTargetName = {},
	tNpcFace = {},
	tPlayerFace = {},
	tDoodadFace = {},
	tScrutinyNpc = {},
	tScrutinyPlayer = {},
	tScrutinyDoodad = {},
	tHandle = {},
	tCache = {
		Line = {},
		Circle = {},
		Border = {},
		DrawingBoard = {},
		DrawingBoardCache = {},
	},
	
}
--------------------------------------------
-- 
--------------------------------------------
BossFaceAlert.nSteper = 0
BossFaceAlert.bEnable = true;				RegisterCustomData("BossFaceAlert.bEnable")
BossFaceAlert.bSendRaidMsg = false;			RegisterCustomData("BossFaceAlert.bSendRaidMsg")
BossFaceAlert.bSendWhisperMsg = false;		RegisterCustomData("BossFaceAlert.bSendWhisperMsg")

--------------------------------------------
-- 
--------------------------------------------
BossFaceAlert.StepAngleBase = 10;			RegisterCustomData("BossFaceAlert.StepAngleBase")
BossFaceAlert.BorderThickBase = 5;  	  	--RegisterCustomData("BossFaceAlert.BorderThickBase")
BossFaceAlert.BorderAlphaBase = 130;    	--RegisterCustomData("BossFaceAlert.BorderAlphaBase")
BossFaceAlert.bBorder = false; 				RegisterCustomData("BossFaceAlert.bBorder")

BossFaceAlert.tFlashColor =
{
	["b"] = 0,
	["g"] = 0,
	["r"] = 255,
}
RegisterCustomData("BossFaceAlert.tFlashColor")
	

BossFaceAlert.nLineWidth = 2

BossFaceAlert.DrawFaceLineNames = {}
BossFaceAlert.FaceClassNameInfo = {}
BossFaceAlert.tDefaultSetForAdd = {
	szName = "默认设置",--Npc名字或者ID
	bAllDisable = false,--关闭此项监控，默认false为开启，修改为true则关闭
	--nFaceClass = nil,--分类设置
	--szDescription = nil,----------注释说明
	bShowDescriptionName = true,----◆以注释代替该项监控的名字
	bAutoAddOn = true,--出现时自动添加，已作废，默认即可（现在总是自动添加了）
	
	--面向圈
	bOn = true,--------开启面向圈
	nAngle = 120,------◆角度设置
	nLength = 5,------◆半径设置
	tColor = {
		r = 240,
		g = 55,
		b = 25,
		a = 100
	},-----------------◆颜色设置
	nAngleToAdd = 0,---◆偏移角度
	nTopToAdd = 0,
	--额外距离圈
	bDistanceCircleOn = false,--开启距离圈
	nAngle2 = 360,--------------◆角度设置
	nLength2 = 3,---------------◆半径设置
	tColor2 = {
		r = 255,
		g = 0,
		b = 0,
		a = 200
	},--------------------------◆颜色设置
	nAngleToAdd2 = 0,-----------◆偏移角度
	
	bNotShowTargetName = false,---不进行注视目标提示
	bNotTargetLine = true,------◆注视非自己时不画追踪线
	bNotSendWhisperMsg = true,--◆注视不密聊报警
	bNotSendRaidMsg = true,-----◆注视不团队报警
	bNotFlashRedAlarm = true,---◆注视不全屏泛光提示
	bNotOtherFlash = true,------◆注视不中央文字提示
	bTimerHeadEnable = false,----◆注视队友头顶特效报警
	
	bShowNPCSelfName = false,--显示目标自身的名字
	bShowNPCDistance = false,--◆显示距离自己的尺数	
}
RegisterCustomData("BossFaceAlert.tDefaultSetForAdd")

BossFaceAlert.bFlashRedAlarm = true
RegisterCustomData("BossFaceAlert.bFlashRedAlarm")
BossFaceAlert.bOtherFlash = true
RegisterCustomData("BossFaceAlert.bOtherFlash")

function BossFaceAlert.AddListByCopy(handleRecord, szNewName)
	if not handleRecord then
		return
	end
	if not szNewName or szNewName == "" then
		return
	end
	for i = 1, #BossFaceAlert.DrawFaceLineNames, 1 do
		if tostring(BossFaceAlert.DrawFaceLineNames[i].szName) == tostring(szNewName) then
			OutputMessage("MSG_SYS", "面向监控设置["..szNewName.."]已存在！".."\n")
			return
		end
	end
	local tNewRecord = clone(handleRecord)
	tNewRecord.szName = tonumber(szNewName) or tostring(szNewName)
	table.insert(BossFaceAlert.DrawFaceLineNames, tNewRecord)
end

local PS = {}
PS.OnPanelActive = function(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX,nY = ui:Append("Text", { x = 0, y = 0, txt = "面向目标监控", font = 27 }):Pos_()
	nX = ui:Append("WndButton3", { x = 350, y = 0 })
	:Text("数据设置面板"):Click(FA.OpenPanel):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = 28, checked = BossFaceAlert.bBorder })
	:Text("边框模式（强烈建议开启,但略微影响性能）"):Click(function(bChecked)
		BossFaceAlert.bBorder = bChecked
		BossFaceAlert.ClearAllItem()
	end):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = "全局设置（总开关）", font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox", { x = 10, y = nY + 12, checked = BossFaceAlert.bSendRaidMsg })
	:Text("被注视团队报警"):Click(function(bChecked)
		BossFaceAlert.bSendRaidMsg = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 15, y = nY + 12, checked = BossFaceAlert.bSendWhisperMsg })
	:Text("被注视密聊报警"):Click(function(bChecked)
		BossFaceAlert.bSendWhisperMsg = bChecked
	end):Pos_()
	nX = ui:Append("WndCheckBox", { x = nX + 15, y = nY + 12, checked = BossFaceAlert.bFlashRedAlarm })
	:Text("全屏泛光报警"):Click(function(bChecked)
		BossFaceAlert.bFlashRedAlarm = bChecked
	end):Pos_()
	nX,nY = ui:Append("Shadow","Shadow_Color", { x = nX + 5, y = nY + 15,w = 20, h = 20 , color = {BossFaceAlert.tFlashColor.r,BossFaceAlert.tFlashColor.g,BossFaceAlert.tFlashColor.b}})
	:Click(function()
		OpenColorTablePanel(function(r,g,b)
			BossFaceAlert.tFlashColor.r = r
			BossFaceAlert.tFlashColor.g = g
			BossFaceAlert.tFlashColor.b = b
			ui:Fetch("Shadow_Color"):Color(r, g, b)
		end)
	end):Pos_()
	nX,nY = ui:Append("WndCheckBox", { x = 10, y = nY + 2, checked = BossFaceAlert.bOtherFlash })
	:Text("中央提示报警"):Click(function(bChecked)
		BossFaceAlert.bOtherFlash = bChecked
	end):Pos_()
	nX = ui:Append("WndButton2", { x = 10, y = nY + 5 })
	:Text("默认面向"):Click(function() FA.LoadAndSaveData(nil,false) end):Pos_()
end
GUI.RegisterPanel("面向目标监控", 194, _L["RGES"],PS)

function BossFaceAlert.GetMenuList()
	if JH.IsPanelOpened() then
		JH.ClosePanel()
	else
		JH.OpenPanel("面向目标监控")
	end
end

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------

-- 更新监控
_BFA.UpdateScrutiny = function(me,class,cTab,aTab)
	for k,v in pairs(cTab) do
		local i = aTab[v]
		local dwID,data,szTargetName = k,BossFaceAlert.DrawFaceLineNames[i],nil
		if not data.bAllDisable then

			local KObject = JH.GetTarget(class,dwID)
			if KObject then
				local szName = KObject.szName
				if class == TARGET.NPC then
					szName = JH.GetTemplateName(KObject)
				end
				
				if data.bShowDescriptionName then
					if data.szDescription and data.szDescription ~= "" then
						szName = data.szDescription
					end
				end
				
				
				local target,dwType
				if class ~= TARGET.DOODAD then
					target,dwType = JH.GetTarget(KObject.GetTarget())
				end
				if target then
					szTargetName = target.szName
					if dwType == TARGET.NPC then
						szTargetName = JH.GetTemplateName(target)
					end
				end
				
				
				-- 1、更新目标线和头顶
				if target and dwType ~= TARGET.NPC and (not data.bNotShowTargetName) then				
					table.insert(BossfaceAlertUpdateAlertName,{dwID,target.dwID,target.szName})
					if target.dwID == me.dwID then -- 目标是自己就给一根粉红色的线
						BossFaceAlert.UpdateAlertLine(dwID,1,target.dwID,KObject,BossFaceAlert.Setting.sTarSelf)
					elseif (not data.bNotTargetLine) then
						BossFaceAlert.UpdateAlertLine(dwID,1,target.dwID,KObject,BossFaceAlert.Setting.sTarOther)
					end
				end
				
				if class == TARGET.DOODAD and (not data.bNotShowTargetName) then
					BossFaceAlert.UpdateAlertLine(dwID,1,me.dwID,KObject,BossFaceAlert.Setting.sTarOther,TARGET.DOODAD)
				end
				
				-- 2、更新目标名称和泛光喊话等
				if target and dwType ~= TARGET.NPC and class ~= TARGET.DOODAD then
					if _BFA.tLastTargetName[dwID] and _BFA.tLastTargetName[dwID] == szTargetName then
						_BFA.tLastTargetTime[dwID] = _BFA.tLastTargetTime[dwID] or 0
						if BossFaceAlert.nSteper % 16 == 0 then
							_BFA.tLastTargetTime[dwID] = _BFA.tLastTargetTime[dwID] + 1
						end
					else
						_BFA.tLastTargetTime[dwID] = 0
						if data.bShowDescriptionName then
							if data.szDescription and data.szDescription ~= "" then
								szName = data.szDescription
							end
						end
						
						if (not data.bNotShowTargetName)  then
							if BossFaceAlert.bSendRaidMsg and (not data.bNotSendRaidMsg) then		---团队频道提示开关
								JH.Talk("警告:【" .. szTargetName .. "】正在被【"..szName.."】注视。")
							end
							if BossFaceAlert.bSendWhisperMsg and (not data.bNotSendWhisperMsg) then		---密语频道提示开关
								JH.Talk(szTargetName,"警告:★你★正在被【"..szName.."】注视。")
							end
							if me.szName == szTargetName then
								local bFExist,szSoundFileCommon = RaidGrid_EventScrutiny.SoundFileCommon(data)
								if bFExist and RaidGrid_EventScrutiny.bSoundAlertEnable then
									PlaySound(RaidGrid_EventScrutiny.nSoundChannel, szSoundFileCommon)
								end
							
								if BossFaceAlert.bFlashRedAlarm and (not data.bNotFlashRedAlarm) then
									RaidGrid_RedAlarm.FlashOrg(2, "★你★正在被【"..szName.."】注视。", true, true, BossFaceAlert.tFlashColor.r, BossFaceAlert.tFlashColor.g, BossFaceAlert.tFlashColor.b)
								end
							elseif BossFaceAlert.bOtherFlash and (not data.bNotOtherFlash) then
								RaidGrid_RedAlarm.FlashOrg(2, "【" .. szTargetName .. "】正在被【"..szTargetName.."】注视。", false, true, 255, 0, 0)
							end
							

							
							if data.bTimerHeadEnable then
								if type(ScreenHead) ~= "nil" then
									ScreenHead(target.dwID, { txt = _L("Staring %s",szName)})
								end
							end
							
						end
					end
					_BFA.tLastTargetName[dwID] = szTargetName or nil			
				end
				-- 3、更新自身名称
				if data.bShowNPCSelfName then

					local nDistance = GetCharacterDistance(GetClientPlayer().dwID, dwID)
					if szName ~= "" and nDistance and nDistance >= 0 and data.bShowNPCDistance then
						szName = szName .. "·" .. (string.format("%.1f", nDistance / 64)) .. "尺"
					end
					local ct = -1
					if class == TARGET.DOODAD then
						ct = -2
					end
					
					table.insert(BossfaceAlertUpdateAlertName,{dwID,ct,szName,BossFaceAlert.Setting.cOther,true,nil,nil,135}) --这个是目标自身名称 备注下 你们可能有些人要
				end
				
				-- 删除不需要的线
				if class ~= TARGET.DOODAD then
					if (target and target.dwID == dwID) or dwType == TARGET.NPC or not target or data.bNotShowTargetName or (data.bNotTargetLine and target.dwID ~= me.dwID) then
						if _BFA.tHandle.handleShadowLine:Lookup(dwID.. 1) then
							_BFA.tHandle.handleShadowLine:RemoveItem(dwID.. 1)
						end
					end
				end
				-- 4、更新圈圈
				if data.bOn then -- 更新第一个圈
					local t = {
						nAngle = data.nAngle, --角度
						nLength = 64 * data.nLength,
						tColor = data.tColor,
						nAngleToAdd =  data.nAngleToAdd,
						nTopToAdd =  data.nTopToAdd,
						bDistanceCircleOn = data.bDistanceCircleOn,
						tColor2 = data.tColor2,
						nStyle = data.nStyle or 0,
						bGradient = data.bGradient
					}
					local doodad
					if data.bDoodad then 
						doodad = TARGET.DOODAD
					end
				
					BossFaceAlert.UpdateAlertCircle(dwID,1,KObject,t,doodad)
				end
				if data.bDistanceCircleOn then -- 更新第二个圈
					data.tColor2 = data.tColor2 or {r = 255,g = 0,b = 0,a = 200,}
					local t = {
						nAngle = data.nAngle2, --角度
						nLength = 64 * data.nLength2,
						tColor = data.tColor2,
						nAngleToAdd =  data.nAngleToAdd2,
						nTopToAdd =  data.nTopToAdd,
						nStyle = data.nStyle,
						bGradient = data.bGradient
					}
					local doodad
					if data.bDoodad then 
						doodad = TARGET.DOODAD
					end
					BossFaceAlert.UpdateAlertCircle(dwID,2,KObject, t,doodad)
				end
			end
		end
	end
end


-- 进入和离开事件 检查缓存是否存在
-- bEvent false = 离开 true = 进入
_BFA.Event = function(arg0,dwType,bEvent)
	local KObject
	if dwType == TARGET.NPC then
		if bEvent then
			KObject = GetNpc(arg0)
		end
	end
	if dwType == TARGET.PLAYER then
		if bEvent then
			KObject = GetPlayer(arg0)
		end
	end
	
	if dwType == TARGET.DOODAD then
		if bEvent then
			KObject = GetDoodad(arg0)
		end
	end
	
	if KObject then
		if dwType == TARGET.NPC then
			local szName = JH.GetTemplateName(KObject)
			-- Output(KObject.CanSeeName() , szName)
			if _BFA.tNpcFace[KObject.dwTemplateID] then -- 如果有ID的话 给ID优先绘制
				_BFA.tScrutinyNpc[arg0] = KObject.dwTemplateID
			elseif _BFA.tNpcFace[szName] then
				_BFA.tScrutinyNpc[arg0] = szName
			end
		end
		if dwType == TARGET.PLAYER and _BFA.tPlayerFace[arg0] then -- 玩家只允许是ID
			_BFA.tScrutinyPlayer[arg0] = arg0
		end
		if dwType == TARGET.DOODAD and _BFA.tDoodadFace[KObject.szName] then -- DOODAD只支持名字
			_BFA.tScrutinyDoodad[arg0] = KObject.szName
		end
	else
		if dwType == TARGET.NPC then
			_BFA.tScrutinyNpc[arg0] = nil
		elseif dwType == TARGET.PLAYER then
			_BFA.tScrutinyPlayer[arg0] = nil
		elseif dwType == TARGET.DOODAD then
			_BFA.tScrutinyDoodad[arg0] = nil
		end
		BossFaceAlert.RemoveAllItem(arg0)
	end
end


JH.RegisterEvent("PLAYER_ENTER_SCENE", function()
	_BFA.Event(arg0,TARGET.PLAYER,true)
end)

JH.RegisterEvent("PLAYER_LEAVE_SCENE", function() 
	_BFA.Event(arg0,TARGET.PLAYER,false)
end)
JH.RegisterEvent("NPC_ENTER_SCENE", function() 
	_BFA.Event(arg0,TARGET.NPC,true)
end)
JH.RegisterEvent("NPC_LEAVE_SCENE", function() 
	_BFA.Event(arg0,TARGET.NPC,false)
end)
JH.RegisterEvent("DOODAD_ENTER_SCENE", function() 
	_BFA.Event(arg0,TARGET.DOODAD,true)
end)
JH.RegisterEvent("DOODAD_LEAVE_SCENE", function() 
	_BFA.Event(arg0,TARGET.DOODAD,false)
end)


-- 刷新和创建数据缓存 
-- 只有在首次登陆和 删除/添加/修改/导入 等结构变更时才更新
BFA.Init = function(bMsg)
	_BFA.tNpcFace = {}
	_BFA.tPlayerFace = {}
	_BFA.tDoodadFace = {}
	_BFA.tScrutinyNpc = {}
	_BFA.tScrutinyPlayer = {}
	_BFA.tScrutinyDoodad = {}
	
	for k,v in pairs(BossFaceAlert.DrawFaceLineNames) do
		local szName = tonumber(v.szName) or v.szName
		if v.bPlayer then
			_BFA.tPlayerFace[szName] = k
		elseif v.bDoodad then
			_BFA.tDoodadFace[szName] = k
		else
			_BFA.tNpcFace[szName] = k
		end
	end
	for k,v in pairs(JH.GetAllNpcID()) do
		_BFA.Event(k,TARGET.NPC,true)
	end
	for k,v in pairs(JH.GetAllPlayerID()) do
		_BFA.Event(k,TARGET.PLAYER,true)
	end
	for k,v in pairs(JH.GetAllDoodadID()) do
		_BFA.Event(k,TARGET.DOODAD,true)
	end
	BossFaceAlert.ClearAllItem()
	if bMsg then
		-- JH.Sysmsg("初始化缓存数据成功")
	end
end

BFA.AddScrutiny = function(szName,dwType,szPlayerName)
	if not szName or szName == "" then
		return
	end
	for i = 1, #BossFaceAlert.DrawFaceLineNames, 1 do
		if tostring(BossFaceAlert.DrawFaceLineNames[i].szName) == tostring(szName) then
			JH.Sysmsg("面向监控设置["..szName.."]已存在！")
			return
		end
	end
	local tNewRecord = clone(BossFaceAlert.tDefaultSetForAdd)
	tNewRecord.szName = tonumber(szName) or tostring(szName)
	if dwType == TARGET.PLAYER then
		tNewRecord.bPlayer = true
		tNewRecord.szDescription = "（玩家）" .. tostring(szPlayerName or "")
	elseif dwType == TARGET.DOODAD then
		tNewRecord.bDoodad = true
		tNewRecord.szDescription = "Doodad - " .. tostring(szName)
	end
	table.insert(BossFaceAlert.DrawFaceLineNames, tNewRecord)
	BFA.Init()
	FA.LoadLastData(BossFaceAlert.DrawFaceLineNames)
end

JH.BreatheCall("BossFaceAlert",function()
	BossFaceAlert.nSteper = BossFaceAlert.nSteper + 1
	if not BossFaceAlert.bEnable then
		return
	end
	local me = GetClientPlayer()
	if not me then
		return
	end
	-- pcall UpdateScrutiny 
	_BFA.UpdateScrutiny(me, TARGET.NPC, _BFA.tScrutinyNpc, _BFA.tNpcFace)
	_BFA.UpdateScrutiny(me, TARGET.PLAYER, _BFA.tScrutinyPlayer, _BFA.tPlayerFace)
	_BFA.UpdateScrutiny(me, TARGET.DOODAD, _BFA.tScrutinyDoodad, _BFA.tDoodadFace)
	BossFaceAlert.UpdateAlertName()
end)

JH.RegisterEvent("LOADING_END", function()
	BossFaceAlert.ClearAllItem()
end)

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------



-- 第一个绘制的目标ID或者坐标 第二个注视的ID 3 text 4 col 5 bCharacterTop 6 字号 7 缩放 8 fTopDelta
function BossFaceAlert.UpdateAlertName()
	local me = GetClientPlayer()
	if not me then
		return
	end
	local _, dwTargetID = me.GetTarget()
	local shadow = _BFA.tHandle.handleShadowName
	shadow:ClearTriangleFanPoint()
	local team = GetClientTeam()
	for _ ,v in pairs(BossfaceAlertUpdateAlertName) do
		if not TargetFace or (TargetFace and (not TargetFace.bTTName or TargetFace.bTTName and TargetFace.GetTargetID() ~= v[1])) then
			if not v[4] then
				if me.dwID == v[2] then
					v[4] = BossFaceAlert.Setting.sTarSelf
				else
					v[4] = BossFaceAlert.Setting.sTarOther 
				end
			end
			if type(v[1]) == "table" then
				shadow:AppendTriangleFan3DPoint(v[1].nX,v[1].nY,v[1].nZ+15*64,v[4][1],v[4][2],v[4][3],255,0,v[6] or BossFaceAlert.Setting.dwFontSchemeID,v[3],1,v[7] or BossFaceAlert.Setting.fScale)
			else
				if v[2] > -1 then
					local GetKungfuName = function(dwKungfuID)
						return string.sub(Table_GetSkillName(dwKungfuID,0),0,4)
					end
					local p,kf = team.GetMemberInfo(v[2]),""
					if p then
						kf = "[" .. GetKungfuName(p.dwMountKungfuID) .. "]"
					end
					if _BFA.tLastTargetName[v[1]] and _BFA.tLastTargetName[v[1]] == v[3] then
						v[3] = v[3] .. " " .. tostring(_BFA.tLastTargetTime[v[1]] or 0) .. "″" .. kf
					end
				end
				if v[2] >= -1 then
					shadow:AppendCharacterID(v[1],v[5] or false,v[4][1],v[4][2],v[4][3],255,v[8] or BossFaceAlert.Setting.fTopDelta,v[6] or BossFaceAlert.Setting.dwFontSchemeID,v[3],1,v[7] or BossFaceAlert.Setting.fScale)
				elseif v[2] == -2 then
					shadow:AppendDoodadID(v[1],v[4][1],v[4][2],v[4][3],255,v[8] or BossFaceAlert.Setting.fTopDelta,v[6] or BossFaceAlert.Setting.dwFontSchemeID,v[3],1,v[7] or BossFaceAlert.Setting.fScale)
				end
			end
		end
	end
	BossfaceAlertUpdateAlertName = {}
end


function BossFaceAlert.GetExtensionPos(character,nFanAngle,nLineLength)
	nFanAngle = nFanAngle or 0
	nLineLength = nLineLength or (64 * 5)

	-- 这里计算目标朝向的延长线目标点
	local tEndPos = {}
	local nFace = (character.nFaceDirection + 512 + ((nFanAngle / 360) * 256)) % 256

	local nFaceD = (nFace / 256) * 360
	local nFaceR = math.rad(nFaceD)
	local nSrcX, nSrcY = character.nX, character.nY
	local nHa = math.abs(math.sin(nFaceR) * nLineLength)
	local nWa = math.abs(math.cos(nFaceR) * nLineLength)
	local nDesX, nDesY = nil, nil
	if nFace < 64 then			-- 第一象限
		nDesX, nDesY = nSrcX + nWa, nSrcY + nHa
	elseif nFace < 128 then		-- 第二象限
		nDesX, nDesY = nSrcX - nWa, nSrcY + nHa
	elseif nFace < 192 then		-- 第三象限
		nDesX, nDesY = nSrcX - nWa, nSrcY - nHa
	else						-- 第四象限
		nDesX, nDesY = nSrcX + nWa, nSrcY - nHa
	end
	tEndPos.nX, tEndPos.nY, tEndPos.nZ = nDesX, nDesY, character.nZ
	return tEndPos
end

function BossFaceAlert.GetExtensionPosLine(nX,nY,nX1,nY1)
	local tStartPos,tEndPos = {},{}
	tStartPos.nX, tStartPos.nY = nX,nY
	tEndPos.nX, tEndPos.nY = nX1,nY1
	local nW = BossFaceAlert.nLineWidth or 1
	local nWt = nW
	local nDifX, nDifY = tEndPos.nX - tStartPos.nX, tEndPos.nY - tStartPos.nY
	local nAX, nAY, nBX, nBY = 0, 0, 0, 0
	local nCX, nCY, nDX, nDY = 0, 0, 0, 0
	if (nDifX >= 0 and nDifY >= 0) or (nDifX < 0 and nDifY < 0) then		-- 二四象限
		nAX, nAY = tStartPos.nX + nW, tStartPos.nY - nW
		nBX, nBY = tStartPos.nX - nW, tStartPos.nY + nW
		nCX, nCY = tEndPos.nX + nWt, tEndPos.nY - nWt
		nDX, nDY = tEndPos.nX - nWt, tEndPos.nY + nWt
	else																	-- 一三象限
		nAX, nAY = tStartPos.nX - nW, tStartPos.nY - nW
		nBX, nBY = tStartPos.nX + nW, tStartPos.nY + nW
		nCX, nCY = tEndPos.nX - nWt, tEndPos.nY - nWt
		nDX, nDY = tEndPos.nX + nWt, tEndPos.nY + nWt
	end
	return nAX,nAY,nBX,nBY,nCX,nCY,nDX,nDY
end

-- RemoveAllItem
function BossFaceAlert.ClearAllItem()
	if _BFA.tHandle.handleShadowName then
		_BFA.tHandle.handleShadowName:ClearTriangleFanPoint()
	end
	if _BFA.tHandle.handleShadowLine then
		_BFA.tHandle.handleShadowLine:Clear()
	end
	if _BFA.tHandle.handleShadowCircle then
		_BFA.tHandle.handleShadowCircle:Clear()
	end
	if _BFA.tHandle.handleShadowBorder then
		_BFA.tHandle.handleShadowBorder:Clear()
	end
end

function BossFaceAlert.RemoveAllItem(ID,index)
	if index then
		if _BFA.tCache.Line[ID] and _BFA.tCache.Line[ID][index] then
			_BFA.tHandle.handleShadowLine:RemoveItem(ID..index)
			_BFA.tCache.Line[ID][index] = nil
		end
		if _BFA.tCache.Circle[ID] and _BFA.tCache.Circle[ID][index] then
			_BFA.tHandle.handleShadowCircle:RemoveItem(ID..index)
			_BFA.tCache.Circle[ID][index] = nil
		end
		if _BFA.tCache.Border[ID] and _BFA.tCache.Circle[ID][index] then
			_BFA.tHandle.handleShadowBorder:RemoveItem(ID..index)
			_BFA.tCache.Border[ID][index] = nil
		end
	else
		if _BFA.tCache.Line[ID] then
			for k,v in pairs(_BFA.tCache.Line[ID]) do
				_BFA.tHandle.handleShadowLine:RemoveItem(ID..k)
			end
		end
		if _BFA.tCache.Circle[ID] then
			for k,v in pairs(_BFA.tCache.Circle[ID]) do
				_BFA.tHandle.handleShadowCircle:RemoveItem(ID..k)
			end
		end
		if _BFA.tCache.Border[ID] then
			for k,v in pairs(_BFA.tCache.Border[ID]) do
				_BFA.tHandle.handleShadowBorder:RemoveItem(ID..k)
			end
		end
		_BFA.tCache.Line[ID] = nil
		_BFA.tCache.Circle[ID] = nil
		_BFA.tCache.Border[ID] = nil
	end
end

-- 如果是用GEOMETRY_TYPE.LINE不需要刷新重绘

function BossFaceAlert.UpdateAlertLine(CachedwID,CacheClass,tEndPos,tStartPos,col,dwType)
	local dwID,nX,nY,nZ = 0,0,0,0
	if type(tEndPos) == "number" then
		dwID = tEndPos
	elseif type(tEndPos) == "table" then
		nX,nY,nZ = unpack(tEndPos)
	end
	local r,g,b = unpack(col)
	local shadow = _BFA.tHandle.handleShadowLine:Lookup(CachedwID..CacheClass)
	local t = {dwID,nX,nY,nZ,tStartPos.dwID,r,g,b,220,BossFaceAlert.nLineWidth}
	if not shadow then
		shadow = _BFA.tHandle.handleShadowLine:AppendItemFromIni(_BFA.szItemIni, "shadow",CachedwID..CacheClass)
		return BossFaceAlert.UpdateAlertLineCall(CachedwID,CacheClass,t,shadow,tEndPos,tStartPos,col,dwType)
	else
		if _BFA.tCache.Line[CachedwID] and _BFA.tCache.Line[CachedwID][CacheClass] then
			for i = 1, #t do
				if t[i] ~= _BFA.tCache.Line[CachedwID][CacheClass][i] then
					BossFaceAlert.UpdateAlertLineCall(CachedwID,CacheClass,t,shadow,tEndPos,tStartPos,col,dwType)
					break
				end
			end
		else
			return BossFaceAlert.UpdateAlertLineCall(CachedwID,CacheClass,t,shadow,tEndPos,tStartPos,col,dwType)
		end
	end	
end

function BossFaceAlert.UpdateAlertLineCall(CachedwID,CacheClass,t,shadow,tEndPos,tStartPos,col,dwType)
	local r,g,b = unpack(col)
	if _BFA.tCache.Line[CachedwID] then
		_BFA.tCache.Line[CachedwID][CacheClass] = t
	else
		_BFA.tCache.Line[CachedwID] = {}
		_BFA.tCache.Line[CachedwID][CacheClass] = t
	end
	shadow:SetTriangleFan(GEOMETRY_TYPE.LINE,BossFaceAlert.nLineWidth)
	shadow:ClearTriangleFanPoint()
	
	if type(tEndPos) == "number" then
		if dwType and dwType == TARGET.DOODAD then
			shadow:AppendDoodadID(tStartPos.dwID,r,g,b,220)
			shadow:AppendCharacterID(tEndPos,true,r,g,b,220)
		else
			shadow:AppendCharacterID(tStartPos.dwID,true,r,g,b,220)
			shadow:AppendCharacterID(tEndPos,true,r,g,b,220)
		end
	elseif type(tEndPos) == "table" then
		nX,nY,nZ = unpack(tEndPos)
		shadow:AppendCharacterID(tStartPos.dwID,true,r,g,b,220)
		shadow:AppendTriangleFan3DPoint(nX,nY,nZ,r,g,b,220)
	end
end

-- 缓存的ID 类别三种 圈1 圈2 自定义圈3 所以名字冲突也无所谓
function BossFaceAlert.UpdateAlertCircle(CachedwID,CacheClass,target,table,dwType)

	local shadow = _BFA.tHandle.handleShadowCircle:Lookup(CachedwID..CacheClass)
	local nAngle = table.nAngle or 360
	local nLength = table.nLength or 64 * 3
	local tColor = table.tColor or {r=0,g=255,b=120}
	local nAngleToAdd = table.nAngleToAdd or 0
	local nTopToAdd = table.nTopToAdd or 0
	local bDistanceCircleOn = table.bDistanceCircleOn or false
	local tColor2 = table.tColor2 or nil
	local nStyle = table.nStyle or 0
	local bGradient = table.bGradient or false
	
	local t = {target.nFaceDirection,nAngle,nLength,tColor.r,tColor.g,tColor.b,tColor.a,nAngleToAdd,nTopToAdd,nStyle,bGradient}
	if not shadow then
		shadow = _BFA.tHandle.handleShadowCircle:AppendItemFromIni(_BFA.szItemIni, "shadow",CachedwID..CacheClass)
		return BossFaceAlert.UpdateAlertCircleCall(CachedwID,CacheClass,t,shadow,target,table,dwType)
	else
		if _BFA.tCache.Circle[CachedwID] and _BFA.tCache.Circle[CachedwID][CacheClass] then
			for i = 1, #t do
				if t[i] ~= _BFA.tCache.Circle[CachedwID][CacheClass][i] then
					BossFaceAlert.UpdateAlertCircleCall(CachedwID,CacheClass,t,shadow,target,table,dwType)
					break
				end
			end
		else
			return BossFaceAlert.UpdateAlertCircleCall(CachedwID,CacheClass,t,shadow,target,table,dwType)
		end
	end	
end

function BossFaceAlert.UpdateAlertCircleCall(CachedwID,CacheClass,t,shadow,KGobj,table,dwType)

	local shadow = _BFA.tHandle.handleShadowCircle:Lookup(CachedwID..CacheClass)
	local nAngle = table.nAngle or 360
	local nLength = table.nLength or 64 * 3
	local tColor = table.tColor or {r=0,g=255,b=120}
	local nAngleToAdd = table.nAngleToAdd or 0
	local nTopToAdd = table.nTopToAdd or 0
	local bDistanceCircleOn = table.bDistanceCircleOn or false
	local tColor2 = table.tColor2 or nil
	local nStyle = table.nStyle or 0
	local bGradient = table.bGradient or false
	
	if nLength <= 0 or nAngle <= 0 or nAngle > 360 or nLength > 64 * 500 then
		return
	end
	
	if _BFA.tCache.Circle[CachedwID] then
		_BFA.tCache.Circle[CachedwID][CacheClass] = t
	else
		_BFA.tCache.Circle[CachedwID] = {}
		_BFA.tCache.Circle[CachedwID][CacheClass] = t
	end
	if nTopToAdd > 0 then 
		nTopToAdd = nTopToAdd * 512
	end
	-- target K object
	local target = {
		dwID = KGobj.dwID,
		nZ = KGobj.nZ,
		nX = KGobj.nX,
		nY = KGobj.nY,
		nFaceDirection = KGobj.nFaceDirection
	}
	target.nZ = target.nZ + nTopToAdd
	if not tColor2 or not bGradient then
		tColor2 = tColor
	end
	local nAngleToAdd = nAngleToAdd or 0
	shadow:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	shadow:SetD3DPT(D3DPT.TRIANGLEFAN)   --默认是D3DPT.TRIANGLEFAN -- 6
	shadow:ClearTriangleFanPoint()
	-- 角度小于2 当线处理
	if nAngle < 2 then
		shadow:SetTriangleFan(GEOMETRY_TYPE.LINE,4)
		local tEndPos = BossFaceAlert.GetExtensionPos(target, nAngleToAdd, nLength)
		local nAX,nAY,nBX,nBY,nCX,nCY,nDX,nDY = BossFaceAlert.GetExtensionPosLine(target.nX, target.nY , tEndPos.nX, tEndPos.nY)
		if target.dwID then
			if dwType and dwType == TARGET.DOODAD then
				shadow:AppendDoodadID(target.dwID,tColor.r, tColor.g, tColor.b, tColor.a or 220)
			else
				shadow:AppendCharacterID(target.dwID,false,tColor.r, tColor.g, tColor.b, tColor.a or 220)
			end
		else
			shadow:AppendTriangleFan3DPoint(target.nX,target.nY,target.nZ,tColor.r, tColor.g, tColor.b, tColor.a or 220)
		end
		shadow:AppendTriangleFan3DPoint(nDX,nDY,target.nZ,tColor.r, tColor.g, tColor.b, tColor.a or 220)
		return
	else
		local colI = {tColor2.r, tColor2.g, tColor2.b}
		local colO = {tColor.r, tColor.g, tColor.b}
		if bGradient then
			colI = {tColor.r, tColor.g, tColor.b}
			colO = {tColor2.r, tColor2.g, tColor2.b}
		end
		local rI,gI,bI = unpack(colI)
		local rO,gO,bO = unpack(colO)
		local nAlphaI,nAlphaO = tColor2.a,tColor.a
		if (nStyle == 0 or not nStyle) and not BossFaceAlert.bBorder then -- 默认情况
			nAlphaI = math.floor(nAlphaI / 2) --全部是中心透明度减半
		elseif nStyle == 1 then -- 距离圈中心透明，面向圈中心透明
			nAlphaI = 0
		elseif nStyle == 2 then
			nAlphaO = 0
		elseif nStyle == 3 then
			if CacheClass == 1 then
				nAlphaI = 0
			elseif CacheClass == 2 then
				nAlphaO = 0
			end
		end
		
		nAlphaI = nAlphaI / HEXIE_ALPHA
		nAlphaO = nAlphaO / HEXIE_ALPHA
		
		local nFace = math.ceil(128 * nAngle / 360)
		local dwRad1 = math.pi * (target.nFaceDirection - nFace + (128 * nAngleToAdd / 180)) / 128
		if target.nFaceDirection > (256 - nFace) then
			dwRad1 = dwRad1 - math.pi - math.pi
		end
		local dwRad2 = dwRad1 + (nAngle / 180 * math.pi)
		if target.dwID then
			if dwType and dwType == TARGET.DOODAD then
				shadow:AppendDoodadID(target.dwID,rI,gI,bI,nAlphaI)
			else
				shadow:AppendCharacterID(target.dwID,false,rI,gI,bI,nAlphaI)
			end
		else
			shadow:AppendTriangleFan3DPoint(target.nX,target.nY,target.nZ,rI,gI,bI,nAlphaI)
		end
		
		local sX, sZ = Scene_PlaneGameWorldPosToScene(target.nX, target.nY)
		local StepAngle = 18
		if nAngle == 360 then
			dwRad2 = dwRad2 + math.pi / 20
		end
		if nAngle <= 45 then StepAngle = 180 end
		repeat
			local sX_, sZ_ = Scene_PlaneGameWorldPosToScene(target.nX + math.cos(dwRad1) * nLength, target.nY + math.sin(dwRad1) * nLength)
			local sX_2, sZ_2 = Scene_PlaneGameWorldPosToScene(target.nX + math.cos(dwRad1) * (nLength+1), target.nY + math.sin(dwRad1) * (nLength+1))
			if target.dwID then
				if dwType and dwType == TARGET.DOODAD then
					shadow:AppendDoodadID(target.dwID,rO,gO,bO,nAlphaO,{ sX_ - sX, 0, sZ_ - sZ })
				else
					shadow:AppendCharacterID(target.dwID,false,rO,gO,bO,nAlphaO,{ sX_ - sX, 0, sZ_ - sZ })
				end
			else
				shadow:AppendTriangleFan3DPoint(target.nX,target.nY,target.nZ,rO,gO,bO,nAlphaO,{ sX_ - sX, 0, sZ_ - sZ })
			end
			dwRad1 = dwRad1 + math.pi / StepAngle
		until dwRad1 > dwRad2
	end
	if BossFaceAlert.bBorder then
		BossFaceAlert.UpdateAlertBorder(CachedwID,CacheClass,target,table,dwType)
	end
end

-- 缓存的ID 类别三种 圈1 圈2 自定义圈3 所以名字冲突也无所谓
function BossFaceAlert.UpdateAlertBorder(CachedwID,CacheClass,target,table,dwType)

	local nAngle = table.nAngle or 360
	local nLength = table.nLength or 64 * 3
	local tColor = table.tColor or {r=0,g=255,b=120}
	local nAngleToAdd = table.nAngleToAdd or 0
	local nTopToAdd = table.nTopToAdd or 0
	

	local shadow = _BFA.tHandle.handleShadowBorder:Lookup(CachedwID..CacheClass)
	local t = {target.nFaceDirection,nAngle,nLength,tColor.r,tColor.g,tColor.b,nAngleToAdd}
	if not shadow then
		shadow = _BFA.tHandle.handleShadowBorder:AppendItemFromIni(_BFA.szItemIni, "shadow",CachedwID..CacheClass)
		return BossFaceAlert.UpdateAlertBorderCall(CachedwID,CacheClass,t,shadow,target,table,dwType)
	else
		if _BFA.tCache.Border[CachedwID] and _BFA.tCache.Border[CachedwID][CacheClass] then
			for i = 1, #t do
				if t[i] ~= _BFA.tCache.Border[CachedwID][CacheClass][i] then
					BossFaceAlert.UpdateAlertBorderCall(CachedwID,CacheClass,t,shadow,target,table,dwType)
					break
				end
			end
		else
			return BossFaceAlert.UpdateAlertBorderCall(CachedwID,CacheClass,t,shadow,target,table,dwType)
		end
	end
end

function BossFaceAlert.UpdateAlertBorderCall(CachedwID,CacheClass,t,shadow,target,table,dwType)

	local nAngle = table.nAngle or 360
	local nLength = table.nLength or 64 * 3
	local tColor = table.tColor or {r=0,g=255,b=120}
	local nAngleToAdd = table.nAngleToAdd or 0
	local nTopToAdd = table.nTopToAdd or 0

	if _BFA.tCache.Border[CachedwID] then
		_BFA.tCache.Border[CachedwID][CacheClass] = t
	else
		_BFA.tCache.Border[CachedwID] = {}
		_BFA.tCache.Border[CachedwID][CacheClass] = t
	end

	shadow:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	shadow:SetD3DPT(D3DPT.TRIANGLESTRIP)
	shadow:ClearTriangleFanPoint()
	
	local nThick = BossFaceAlert.BorderThickBase
	local dwMaxRad = nAngle * math.pi / 180
	local nFace = math.ceil(128 * nAngle / 360)
	local nFace2 = 128 * nAngleToAdd / 180
	local dwStepRadBase = nLength / (4 * 64)
	if dwStepRadBase < 2 then
		dwStepRadBase = 2
	end
	local dwStepRad = dwMaxRad / (nLength / dwStepRadBase)
	local dwCurRad = 0 - dwStepRad
	local sX, sZ = Scene_PlaneGameWorldPosToScene(target.nX, target.nY)
	repeat
		local tRad = {}
		tRad[1] = { nLength, dwCurRad }
		tRad[2] = { nLength - nThick, dwCurRad }
		for _, v in ipairs(tRad) do
			local nX = target.nX + math.ceil(math.cos((v[2] + math.pi * (target.nFaceDirection - nFace + nFace2) / 128)) * v[1])
			local nY = target.nY + math.ceil(math.sin((v[2] + math.pi * (target.nFaceDirection - nFace + nFace2) / 128)) * v[1])
			local sX_,sZ_ = Scene_PlaneGameWorldPosToScene(nX,nY)
			if dwType and dwType == TARGET.DOODAD then
				shadow:AppendDoodadID(target.dwID,tColor.r,tColor.g,tColor.b,BossFaceAlert.BorderAlphaBase,{ sX_ - sX, 0, sZ_ - sZ })
			elseif target.dwID then
				shadow:AppendCharacterID(target.dwID,false,tColor.r,tColor.g,tColor.b,BossFaceAlert.BorderAlphaBase,{ sX_ - sX, 0, sZ_ - sZ })
			else
				shadow:AppendTriangleFan3DPoint(target.nX,target.nY,target.nZ,tColor.r,tColor.g,tColor.b,BossFaceAlert.BorderAlphaBase,{ sX_ - sX, 0, sZ_ - sZ })
			end
		end
		dwCurRad = dwCurRad + dwStepRad
	until dwMaxRad <= dwCurRad
end


JH.RegisterEvent("LOGIN_GAME", function()
	_BFA.tHandle.handleShadowCircle = JH.GetShadowHandle("Handle_Shadow_Circle")
	_BFA.tHandle.handleShadowLine = JH.GetShadowHandle("Handle_Shadow_Line")
	_BFA.tHandle.handleShadowBorder = JH.GetShadowHandle("Handle_Shadow_Border")
	_BFA.tHandle.handleShadowName = JH.GetShadowHandle("Handle_Shadow_Name"):AppendItemFromIni(_BFA.szItemIni, "shadow", "BFA_NAME")
	_BFA.tHandle.handleShadowName:SetTriangleFan(GEOMETRY_TYPE.TEXT)
end)

---------------------------------------------------------------------------------------------------------
TimeToFight = {
	bShow = true,
	Postion = { x = 200, y = 200},
}

local _TimeToFight = {
	-- szDictionary = false,
	bFight = false,
	bShowCharInfo = false,
	bShowHelp = true,
	nStart = 0,
	lastTime = "你先去打一架再说。",
	col = {255,255,255},
	tTalkChannelHeader = {
		[PLAYER_TALK_CHANNEL.NEARBY] = "/s ",
		[PLAYER_TALK_CHANNEL.FRIENDS] = "/o ",
		[PLAYER_TALK_CHANNEL.TONG_ALLIANCE] = "/a ",
		[PLAYER_TALK_CHANNEL.RAID] = "/t ",
		[PLAYER_TALK_CHANNEL.BATTLE_FIELD] = "/b ",
		[PLAYER_TALK_CHANNEL.TONG] = "/g ",
		[PLAYER_TALK_CHANNEL.SENCE] = "/y ",
		[PLAYER_TALK_CHANNEL.FORCE] = "/f ",
		[PLAYER_TALK_CHANNEL.CAMP] = "/c ",
		[PLAYER_TALK_CHANNEL.WORLD] = "/h ",
	}
}

TimeToFight.CanTalk = function(nChannel)
	for _, v in ipairs({"WHISPER", "TEAM", "RAID", "BATTLE_FIELD", "NEARBY", "TONG", "TONG_ALLIANCE" }) do
		if nChannel == PLAYER_TALK_CHANNEL[v] then
			return true
		end
	end
	return false
end

TimeToFight.SwitchChat = function(nChannel)
	local szHeader = _TimeToFight.tTalkChannelHeader[nChannel]
	if szHeader then
		SwitchChatChannel(szHeader)
	end
end

TimeToFight.Talk = function(nChannel, szText,szTarget)
	local me = GetClientPlayer()
	if nChannel ~= PLAYER_TALK_CHANNEL.WHISPER then
		szTarget = ""
	end
	local tSay = {{type="text",text=szText}}
	me.Talk(nChannel, szTarget, tSay)
	if not TimeToFight.CanTalk(nChannel) then
		local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
		edit:ClearText()
		for _, v in ipairs(tSay) do
			if v.type == "text" then
				edit:InsertText(v.text)
			else
				edit:InsertObj(v.text, v)
			end
		end
		TimeToFight.SwitchChat(nChannel)
	end
end

for k, _ in pairs(TimeToFight.Postion) do
	RegisterCustomData("TimeToFight.Postion." .. k)
end
RegisterCustomData("TimeToFight.bShow")
-- open
TimeToFight.OpenPanel = function()
	local frame = Station.Lookup("Normal/TimeToFight")
	if not frame then
		Wnd.OpenWindow("Interface\\JH\\RaidGrid_EventScrutiny\\ui\\TimeToFight.ini","TimeToFight")
		TimeToFight.ChangeImage(true)
		TimeToFight.SetAni(true)
		TimeToFight.CheckFight()
	end
	frame:Show()
	frame:BringToTop()
	return frame
end

-- close
TimeToFight.ClosePanel = function(bRealClose)
	local frame = Station.Lookup("Normal/TimeToFight")
	if frame then
		frame:Hide()
	end
end

-- toggle
TimeToFight.TogglePanel = function()
	if _TimeToFight.frame and _TimeToFight.frame:IsVisible() then
		TimeToFight.ClosePanel()
	else
		TimeToFight.OpenPanel()
	end
end

function TimeToFight.OnFrameCreate()
	this:RegisterEvent("FIGHT_HINT")
	this:Lookup("Check_Minimize"):Check(false)
	TimeToFight.UpdateSize(false)
	_TimeToFight.frame = this
	if TimeToFight.bShow then this:Show() end
end

function TimeToFight.OnCheckBoxCheck()
	local szName = this:GetName()
	if szName == "Check_Minimize" then
		-- this:SetRelPos(200,5)
		TimeToFight.UpdateSize(true)
		_TimeToFight.bShowCharInfo = true
	end
end

function TimeToFight.OnCheckBoxUncheck()
	local szName = this:GetName()
	if szName == "Check_Minimize" then
		-- this:SetRelPos(150,5)
		TimeToFight.UpdateSize(false)
		_TimeToFight.bShowCharInfo = false
	end	
end

function TimeToFight.UpdateSize(bCheck)
	local Frame = Station.Lookup("Normal/TimeToFight")
	if bCheck then
		-- Frame:SetSize(220,30)
		-- Frame:SetDragArea(0,0,220,30)
		Frame:Lookup("","Image_Title"):SetSize(200,180)
		Frame:Lookup("","Handle_CharInfo"):Show()
	else
		-- Frame:SetSize(181,30)
		-- Frame:SetDragArea(0,0,181,30)
		Frame:Lookup("","Image_Title"):SetSize(200,30)
		Frame:Lookup("","Handle_CharInfo"):Hide()
	end
end
function TimeToFight.GetTimeStr(n)
	local d = n / 1000
	if d / 60 >= 1 then
		_TimeToFight.lastTime = string.format("%.0f 分",math.floor(d / 60)) .. string.format(" %.0f 秒",d % 60 )
	else
		_TimeToFight.lastTime = string.format("%.0f 秒",d)
	end
	return _TimeToFight.lastTime
end

function TimeToFight.SetText(text,col)
	local Frame = Station.Lookup("Normal/TimeToFight")
	local r,g,b = unpack(col)
	local c = Frame:Lookup("","Text_Title")
	if c then
		c:SetFontColor(r,g,b)
		c:SetText(text)
	end
end

function TimeToFight.OnFrameBreathe()
	if _TimeToFight.LastKungFu then
		if _TimeToFight.LastKungFu ~= UI_GetPlayerMountKungfuID() then
			local aFrame = TimeToFight.GetFrame()
			local c = aFrame:Lookup("","Button_bg")
			_TimeToFight.LastKungFu = UI_GetPlayerMountKungfuID()
			local nIconID = Table_GetSkillIconID(_TimeToFight.LastKungFu, 0)
			if nIconID then
				c:FromIconID(nIconID)
			end
		end
	end
	if _TimeToFight.bShowCharInfo then
		TimeToFight.GetCharInfo()
	end
	if _TimeToFight.nStart > 0 then
		local d = (GetTime() - _TimeToFight.nStart)
		TimeToFight.SetText(TimeToFight.GetTimeStr(d),_TimeToFight.col)

		_TimeToFight.bFight = true
	elseif _TimeToFight.bFight then
		_TimeToFight.bFight = false
		TimeToFight.SetText("不在战斗中",{255,255,255})
	end
end
function TimeToFight.CheckFight()
	if GetClientPlayer().bFightState then
		_TimeToFight.nStart = GetTime()
	else
		_TimeToFight.nStart = 0
	end
end
function TimeToFight.OnEvent(event)
	if event=="FIGHT_HINT" then
		TimeToFight.CheckFight()
	end
end

function TimeToFight.GetCharInfo()
	local a = Station.Lookup("Normal/CharInfo")
	if a then
		if not a:IsVisible() then
			a:Show()
			a:SetAbsPos(-4096,-4096)
		end
		_TimeToFight.szGetCharInfo = "【我的属性】 - "
		local frame = TimeToFight.GetFrame()
		local f = frame:Lookup("","Handle_CharInfo")
		for i = 1, 5 do
			local aa = a:Lookup("","Text_ClassInfoLabel0"..i)
			local b = a:Lookup("","Text_ClassInfoValue0"..i)
			local item = f:Lookup("Text_CharInfo"..i)
			item:SetText(aa:GetText().."："..b:GetText())
			_TimeToFight.szGetCharInfo = _TimeToFight.szGetCharInfo  .. aa:GetText().."："..b:GetText() .. "，"
		end
		local c = 0
		if GetClientPlayer().GetBuffCount then
			c = GetClientPlayer().GetBuffCount()
		end
		local item = f:Lookup("Text_CharInfo6")
		item:SetText("BUFF："..c .. "  (含隐藏)")
		_TimeToFight.szGetCharInfo = _TimeToFight.szGetCharInfo  .. "当前BUFF数量："..c .. "个。"

	end
end

function TimeToFight.OnMouseEnter()--鼠标进入
	local szName = this:GetName()
	if _TimeToFight.bShowHelp then
		if szName == "TimeToFight"  then
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			local str = "右键弹出面向菜单。\n【一般情况下】双击图标发布当前目标和战斗时间。\n【属性模式下】属性可以自己到人物面板切换，时双击发布属性。\n\n上次战斗时间：".. _TimeToFight.lastTime
			local szTip = "<text>text=" ..EncodeComponentsString(str).." font=101 </text>" 
			OutputTip(szTip, 600, {x, y, w, h})
			if not this:IsDragable() then
				this:EnableDrag(true)
			end
		elseif szName == "Btn_Setting" then
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			local szTip= "<text>text=" ..EncodeComponentsString("右键隐藏Tip 左键画板").." font=101 </text>" 
			OutputTip(szTip, 200, {x, y, w, h})
		end
	end
end

function TimeToFight.OnMouseLeave()
	HideTip()
end

function TimeToFight.OnLButtonUp()  											--左键弹起
	local szName = this:GetName()
	if szName == "TimeToFight" then
		TimeToFight.SavePostion()
	end
end
function TimeToFight.OnLButtonDown()  											--左路键按下
	local szName = this:GetName()
	if szName == "TimeToFight" then
		if not this:IsDragable() then
			this:EnableDrag(true)
		end
	end
end
function TimeToFight.OnItemLButtonDBClick()

	local nChannel, szTarName = EditBox_GetChannel()
	local me = GetClientPlayer()
	local szName,nCurrentLife,tar,str = nil
	
	if _TimeToFight.bShowCharInfo then
		str = _TimeToFight.szGetCharInfo
	else
		local id,type = Target_GetTargetData()
		
		if id and type then
			if type == TARGET.PLAYER then
				tar = GetPlayer(id)
			elseif type == TARGET.NPC then
				tar = GetNpc(id)
			end
			if tar then
				szName,nCurrentLife = tar.szName,tar.nCurrentLife
			end
		end
		local HP = function(hp)
			if hp > 99999999 then
				return string.format("%.2f 亿",hp / 100000000)
			elseif hp > 9999 then
				return string.format("%.2f 万",hp / 10000)
			else
				return hp
			end
		end
		if me.bFightState then
			if tar then
				str = "我正在和 [" .. szName .."] 斗殴，TA目前还有 [" .. HP(nCurrentLife) .."] ，斗殴已经持续了 " .._TimeToFight.lastTime
			else
				str = "我正在斗殴，已经持续了 " .._TimeToFight.lastTime
			end
		else
			if tar then
				str = "我正在注视 [" .. szName .."] 一共有 [" .. HP(nCurrentLife) .."] ，我没有跟他斗殴。"
			else
				OutputMessage("MSG_SYS","没有进入战斗，也没有目标。\n")
			end
		end
	end
	if _TimeToFight.szDictionary and IsCtrlKeyDown() then
		str = _TimeToFight.szDictionary
	end
	if str then
		TimeToFight.Talk(nChannel,str,szTarName)
	end
end

function TimeToFight.OnLButtonClick()
	PopupMenu(BossFaceAlert.GetDrawingBoardOption())
end


function TimeToFight.OnRButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Setting" then
		_TimeToFight.bShowHelp = not _TimeToFight.bShowHelp
	end
end
function TimeToFight.OnRButtonDown()--右键按下
	if IsCtrlKeyDown() then
		local name,type,id = ""
		if Target_GetTargetData() then
			id,type = Target_GetTargetData()
			if type == TARGET.NPC then
				name = GetNpc(id).szName
			elseif type == TARGET.PLAYER then
				name = GetPlayer(id).szName
			end
			name = JH.UrlEncode(name)
		end
		OpenInternetExplorer("http://www.baidu.com/s?wd="..name)
	else
		FA.OpenPanel()
	end
end

function TimeToFight.GetFrame()  											--取得FRAME
	return Station.Lookup("Normal/TimeToFight")
end
function TimeToFight.SavePostion()  											--保存MINI位置
	local nx,ny=TimeToFight.GetFrame():GetAbsPos()
	TimeToFight.Postion.x=nx
	TimeToFight.Postion.y=ny
end

function TimeToFight.loadedSetMini() 									--载入完成后设置MINI的位置
	local f=TimeToFight.GetFrame()
	if f then
		local x,y=TimeToFight.Postion.x,TimeToFight.Postion.y
		if x<2 and y<2 then
			local fp = Station.Lookup("Normal/Player")
			local w,h=fp:GetSize()
			local cx,cy=fp:GetAbsPos()
			x=cx+w-20
			y=cy+h/2
		end
		f:SetAbsPos(x,y)
	end
end
function TimeToFight.SetAni(bMMove)  											--设置MINI动画
		local f = TimeToFight.GetFrame()
		if f then
			local c=f:Lookup("","Animate_Hot")
			if c then
				local szini="UI/Image/ChannelsPanel/b.UITex"
				local idx=0
				if bMMove then
					szini="UI/Image/Common/Animate.UITex"
					idx=4
				end
				c:SetImagePath(szini)
				c:SetGroup(idx)
			end
		end
end

function TimeToFight.ChangeImage()
	local me = GetClientPlayer()
	local aFrame = TimeToFight.GetFrame()
	local szini,id = GetForceImage(me.dwForceID)
	if aFrame then
		local c = aFrame:Lookup("","Button_bg")
		-- c:FromUITex(szini, id)
		_TimeToFight.LastKungFu = UI_GetPlayerMountKungfuID()
		local nIconID = Table_GetSkillIconID(_TimeToFight.LastKungFu, 0)
		if nIconID then
			c:FromIconID(nIconID)
		end
	end
	TimeToFight.loadedSetMini()
	local t = {
		[0] = {255, 255, 255},
		[3] = {255, 111, 83},
		[2] = {196, 152, 255},
		[4] = {89, 224, 232},
		[5] = {255, 129, 176},
		[1] = {255, 178, 95},
		[8] = {214, 249, 93},
		[6] = {55, 147, 255},
		[7] = {121, 183, 54},
		[10] = {240, 70, 96},
		[9] = {205,133,63},
	}
	if t[me.dwForceID] then
		_TimeToFight.col = t[me.dwForceID] or {255,255,255}
	end
end

RegisterEvent("LOADING_END", function()
	if TimeToFight.bShow then
		Wnd.OpenWindow("Interface\\JH\\RaidGrid_EventScrutiny\\ui\\TimeToFight.ini","TimeToFight")
		TimeToFight.ChangeImage(true)
		TimeToFight.SetAni(true)
		TimeToFight.CheckFight()
	end
end)

