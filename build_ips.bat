@echo off

echo Building SM Crash Handler Patch
cd tools
python create_dummies.py 00.sfc ff.sfc

echo Building single-page version
copy *.sfc ..\build
asar\asar.exe --no-title-check -DEXTRA_PAGES=0 ..\CrashHandler.asm ..\build\00.sfc
asar\asar.exe --no-title-check -DEXTRA_PAGES=0 ..\CrashHandler.asm ..\build\ff.sfc
python create_ips.py ..\build\00.sfc ..\build\ff.sfc ..\build\debug.ips

echo Building multi-page version
copy *.sfc ..\build
..\tools\asar\asar.exe --no-title-check -DEXTRA_PAGES=1 ..\CrashHandler.asm ..\build\00.sfc
..\tools\asar\asar.exe --no-title-check -DEXTRA_PAGES=1 ..\CrashHandler.asm ..\build\ff.sfc
python create_ips.py ..\build\00.sfc ..\build\ff.sfc ..\build\debug_extra.ips

del 00.sfc ff.sfc ..\build\00.sfc ..\build\ff.sfc
cd ..
PAUSE