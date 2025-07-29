@echo off

:choose
choice /c awsdeclxq /m "[A]dd | [W]akey | [S]how | [D]elete | [E]dit | Re-[C]ode | C[l]ear | E[x]cel | [Q]uit"
if ERRORLEVEL 9 goto quit
if ERRORLEVEL 8 goto excel
if ERRORLEVEL 7 goto clear_screen
if ERRORLEVEL 6 goto recode
if ERRORLEVEL 5 goto edit
if ERRORLEVEL 4 goto delete
if ERRORLEVEL 3 goto show
if ERRORLEVEL 2 goto wakey
if ERRORLEVEL 1 goto add
goto :choose

:excel
type %USERPROFILE%\events.log | clip
start "unused-window-title" "https://dbotsoftware-my.sharepoint.com/:x:/r/personal/nir_dbotsoftware_com/_layouts/15/Doc.aspx?sourcedoc=%%7B3F8F51F0-B88E-4BEE-B62A-C9B0B1726BAD%%7D&file=Timesheet-Calculator.xlsx&action=default&mobileredirect=true&DefaultItemOpen=1&wdOrigin=WAC.EXCEL.HOME-BUTTON%%2CAPPHOME-WEB.JUMPBACKIN&wdPreviousSession=d15560ea-f8bc-4704-9c15-0e022d08b50c&wdPreviousSessionSrc=AppHomeWeb&ct=1753271318068"
goto choose

:add
set /p desc="Event short description: "
echo %DATE% %TIME%	%desc%>> %USERPROFILE%\events.log
set desc=
goto choose

:wakey
choice /c sw /m "[S]leep | [W]ake"
if ERRORLEVEL 2 goto wakey_wake
if ERRORLEVEL 1 goto wakey_sleep
goto wakey

:wakey_sleep
for /f "usebackq delims=" %%i in (`powershell -Command "(Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Power' -MaxEvents 30 | where -Property Id -Eq 506 | select -First 1 -Property TimeCreated).TimeCreated.ToString('yyyy-MM-dd HH:mm:ss.ff')"`) do set LAST_SLEEP_TIME=%%i
echo %LAST_SLEEP_TIME%	break>> %USERPROFILE%\events.log
set desc=
goto choose

:wakey_wake
for /f "usebackq delims=" %%i in (`powershell -Command "(Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Power' -MaxEvents 30 | where -Property Id -Eq 507 | select -First 1 -Property TimeCreated).TimeCreated.ToString('yyyy-MM-dd HH:mm:ss.ff')"`) do set LAST_WAKE_TIME=%%i
set /p desc="Event short description: "
echo %LAST_WAKE_TIME%	%desc%>> %USERPROFILE%\events.log
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
