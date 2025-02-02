@echo off
set start_date=%date% %time%
@echo =========== BUILDING SUPER METROID HACK =========== & echo(

del "Hack.smc"
copy "BaseRom.smc" "Hack.smc"

@echo on
asar.exe --fix-checksum=off --no-title-check "..\Nodever2\Unique_Door_Cap_Graphics\UniqueDoorCapGraphics_by_Nodever2.asm" ".\Hack.smc"
@echo off

@echo ================= BUILD COMPLETED ================= & echo(
set end_date=%date% %time%
powershell -command "&{$start_date1 = [datetime]::parse('%start_date%'); $end_date1 = [datetime]::parse('%date% %time%'); echo (-join('Time elapsed in seconds: ', ($end_date1 - $start_date1).TotalSeconds)); }"
@echo(

