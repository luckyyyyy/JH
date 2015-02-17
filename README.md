《剑网3》菊花插件集
==================
本插件适用于国产网游```《剑侠情缘网络版叁》```，由于游戏版本较多，本插件基于```zhcn```版本编译，所有的功能以及API针对于```zhcn```版本，其他版本需要做一些兼容性的修改，可以参考下文的兼容性修改部分。

* 插件官网：http://www.j3ui.com
* 作者微博：http://weibo.com/techvicky
* 建议反馈：可以通过微博私信反馈您的建议，当然欢迎各位直接pull request

使用方法
-----------------------
1. 在./bin/{ version }/interface/目录下载仓库所有文件，但是请注意，目前```zhcn```版本需要key验证，否则会被判为非法插件。
```
git clone git@github.com:Webster-jx3/JH.git
或者也可以直接下载所有文件，文件夹名称为JH。
https://github.com/Webster-jx3/JH/archive/master.zip
```
2. 上线后进入插件管理勾选即可。

兼容性修改
-----------------------
对于非```zhcn```版本的客户端，可能需要做一些改动请参考如下方案。

### 路径修改
对于较老的游戏版本，可能不支持目前的路径方案，请修改```JH/0Base/Base.lua```，请以下路径修改正确。
```lua
-- 请将 interface/JH/ 修改为 interface/ ，并且将文件夹从JH中移出到interface。
local ROOT_PATH   = "interface/JH/0Base/"
local DATA_PATH   = "interface/JH/@DATA/"
local SHADOW_PATH = "interface/JH/0Base/item/shadow.ini"
local ADDON_PATH  = "interface/JH/"
```
### 翻译
请新增相应版本的语言文件到 ```JH/0Base/lang/```路径，根据内容翻译即可。

### info.ini
对于inifo.ini，请做单独的翻译，需要针对不同服对文件编码进行修改。

### 图片文件
对于较老的游戏版本，可能出现图片丢失的情况，请根据源码中的路径修改相应的图片资源。