echo off
color 0A
REM set szTime=JH
set szTime=%date:~0,10%%time:~0,8%
set szTime=%szTime:/=%
set szTime=%szTime::=%
set szTime=%szTime: =%

:: 拼接字符串开始压缩文件
set szFile=releases\JH_%szTime%.7z
echo zippping...
7z a -t7z %szFile% -xr!manifest.dat -xr!manifest.key -xr!publisher.key -x@7zipignore.txt -xr!About.ini -xr!RGES-* -xr!sync_*
echo File(s) compressing acomplete!
echo Url: %szFile%
set /p _=press enter to exit...