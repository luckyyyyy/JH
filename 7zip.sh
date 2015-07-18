#!/bin/sh
# @Author: Webster
# @Date:   2015-07-18 14:20:46
# @Last Modified by:   Webster
# @Last Modified time: 2015-07-18 14:26:49
# 方便在OSX下打包

VERSION=$(grep "local _VERSION_" 0Base/Base.lua | awk '{print $4}')
DATE=$(date +%Y%m%d%H%I)

FILE=releases/${DATE}_${VERSION}.7z
echo zippping...
7z a -t7z $FILE -x@7zipignore.txt
echo 'File(s) compressing acomplete!'
echo Path：$FILE
