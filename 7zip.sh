#!/bin/sh
# @Author: Webster
# @Date:   2015-07-18 14:20:46
# @Last Modified by:   Administrator
# @Last Modified time: 2016-12-21 21:41:13
# 方便在OSX下打包

VERSION=$(grep "local _VERSION_" JH_0Base/Base.lua | awk '{print $4}')
DATE=$(date +%Y%m%d%H%M)

FILE=releases/JH_${DATE}_${VERSION}.7z
echo zippping...
7z a -t7z $FILE -x@7zipignore.txt
echo 'File(s) compressing acomplete!'
echo Path：$FILE
