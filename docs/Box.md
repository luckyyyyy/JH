```lua
UI_OBJECT_ITEM = 0  --身上有的物品。nUiId, dwBox, dwX, nItemVersion, nTabType, nIndex
UI_OBJECT_SHOP_ITEM = 1 --商店里面出售的物品 nUiId, dwID, dwShopID, dwIndex
UI_OBJECT_OTER_PLAYER_ITEM = 2 --其他玩家身上的物品 nUiId, dwBox, dwX, dwPlayerID
UI_OBJECT_ITEM_ONLY_ID = 3  --只有一个ID的物品。比如装备链接之类的。nUiId, dwID, nItemVersion, nTabType, nIndex
UI_OBJECT_ITEM_INFO = 4 --类型物品 nUiId, nItemVersion, nTabType, nIndex
UI_OBJECT_SKILL = 5	--技能。dwSkillID, dwSkillLevel
UI_OBJECT_CRAFT = 6	--技艺。dwProfessionID, dwBranchID, dwCraftID
UI_OBJECT_SKILL_RECIPE = 7	--配方dwID, dwLevel
UI_OBJECT_SYS_BTN = 8 --系统栏快捷方式dwID
UI_OBJECT_MACRO = 9 --宏
UI_OBJECT_MOUNT = 10 --镶嵌
UI_OBJECT_ENCHANT = 11 --附魔
UI_OBJECT_NOT_NEED_KNOWN = 15 --不需要知道类型```
