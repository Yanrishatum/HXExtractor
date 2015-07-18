@echo off
cd bin
if %1 == debug (
	Main-debug.exe test.hx test.tex
) else (
	Main.exe
)
pause