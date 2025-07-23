@echo off

:choose
choice /c asdeclxq /m "[A]dd | [S]how | [D]elete | [E]dit | Re-[C]ode | C[l]ear | E[x]cel | [Q]uit"
if %ERRORLEVEL% EQU 8 goto quit
if %ERRORLEVEL% EQU 7 goto excel
if %ERRORLEVEL% EQU 6 goto clear_screen
if %ERRORLEVEL% EQU 5 goto recode
if %ERRORLEVEL% EQU 4 goto edit
if %ERRORLEVEL% EQU 3 goto delete
if %ERRORLEVEL% EQU 2 goto show
if %ERRORLEVEL% EQU 1 goto add
goto :choose

:excel
type %USERPROFILE%\events.log | clip
start "unused-window-title" "https://dbotsoftware-my.sharepoint.com/:x:/r/personal/nir_dbotsoftware_com/_layouts/15/Doc.aspx?sourcedoc=%%7B3F8F51F0-B88E-4BEE-B62A-C9B0B1726BAD%%7D&file=Timesheet-Calculator.xlsx&action=default&mobileredirect=true&DefaultItemOpen=1&wdOrigin=WAC.EXCEL.HOME-BUTTON%%2CAPPHOME-WEB.JUMPBACKIN&wdPreviousSession=d15560ea-f8bc-4704-9c15-0e022d08b50c&wdPreviousSessionSrc=AppHomeWeb&ct=1753271318068"
goto choose

:add
set /p desc="Event short description: "
echo %DATE% %TIME%	%desc% >> %USERPROFILE%\events.log
set desc=
goto choose

:show
less %USERPROFILE%\events.log
echo.
goto choose

:delete
del /p %USERPROFILE%\events.log
goto choose

:edit
vim %USERPROFILE%\events.log
goto choose

:recode
vim %USERPROFILE%\record-event.cmd
goto choose

:clear_screen
cls
goto choose

:quit
