echo off
color 0A
set szVersion=0x0000000
for /f "tokens=2,4 delims= " %%i in (0Base/Base.lua) do (
	if "%%i"=="_VERSION_" (
		set szVersion=%%j
	)
)

set szTime=%date:~0,10%%time:~0,8%
set szTime=%szTime:/=%
set szTime=%szTime::=%
set szTime=%szTime: =%

set szFile=releases\JH_%szTime%_%szVersion:~0,8%.7z
echo zippping...
7z a -t7z %szFile% -xr!manifest.dat -xr!manifest.key -xr!publisher.key -x@7zipignore.txt -xr!About.ini -xr!RGES-* -xr!sync_*
echo File(s) compressing acomplete!
echo Url: %szFile%
set /p _=press enter to exit...