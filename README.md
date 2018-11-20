《剑网3》菊花插件集
==================
本插件适用于国产网游```《剑侠情缘网络版叁》```，由于游戏版本较多，本插件基于```zhcn```版本编译，所有的功能以及API针对于```zhcn```版本，其他版本需要做一些兼容性的修改，可以参考下文的兼容性修改部分。

* 建议反馈：欢迎各位直接pull request，或者打开新的issues，除此之外不接受任何反馈。
* LICENSE：MIT
* 分支说明：`master`分支为主开发测试版本，`stable`分支为稳定版本。
* 其他说明：本人已很少维护本插件，本插件接受所有合理的pull request，如果您有建议可直接开issues讨论。

使用方法
-----------------------
在```./bin/{ version }/interface/```目录下载仓库所有文件，但是请注意，目前```zhcn```版本需要key验证，否则会被判为非法插件。
```
git clone git@github.com:luckyyyyy/JH.git
或者也可以直接下载所有文件，文件夹名称为JH。
https://github.com/luckyyyyy/JH/archive/dev.zip
```

兼容性修改
-----------------------
对于非```zhcn```版本的客户端，可能需要做一些改动请参考如下方案。

### 路径修改
对于较老的游戏版本，可能不支持目前的路径方案，请修改```JH/0Base/Base.lua```，请将以下路径修改正确。
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
对于info.ini，请做单独的翻译，需要针对不同服对文件编码进行修改。
对于较老的游戏版本，可能需要修改路径，请补全```interface/{ sid }```。

### 图片文件
对于较老的游戏版本，可能出现图片丢失的情况，请根据源码中的路径修改相应的图片资源。

### 无法加载
您可能需要在控制面板，把非Unicode使用的语言更改为United States (English)，并且推荐开启日志记录```./bin/{ version }/logs/```查看报错信息做对应的修改。
