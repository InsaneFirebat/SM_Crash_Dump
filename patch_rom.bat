@echo off

echo Patching SM Crash Handler

cp build\sm.sfc build\sm_debug.sfc && tools\asar\asar.exe --no-title-check CrashHandler.asm build\sm_debug.sfc

PAUSE
