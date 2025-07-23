@echo off

:choose
choice /c asdeclq /m "[A]dd | [S]how | [D]elete | [E]dit | Re-[C]ode | C[l]ear | [Q]uit"
if %ERRORLEVEL% EQU 7 goto quit
if %ERRORLEVEL% EQU 6 goto clear_screen
if %ERRORLEVEL% EQU 5 goto recode
if %ERRORLEVEL% EQU 4 goto edit
if %ERRORLEVEL% EQU 3 goto delete
if %ERRORLEVEL% EQU 2 goto show
if %ERRORLEVEL% EQU 1 goto add
goto :choose

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
