@echo off
cd bin
if %1 == debug (
	Main-debug.exe -i
) else (
	Main.exe -i
)
pause