@ECHO OFF

REM Path to fpc binaries
SET "FPCBIN=D:\Lazarus\fpc\3.2.0\bin\x86_64-win64"

IF NOT EXIST %FPCBIN% GOTO FAILENVIRONMENT

REM Extend PATH
SET "PATH=%PATH%;%FPCBIN%;%FPCBIN%\..\..\..\.."

REM Build exe
cd ..\SocketMod
lazbuild --build-all --cpu=i386 --os=Win32 --build-mode=Release SocketMod.lpi
IF ERRORLEVEL 1 GOTO FAIL

REM Build dll
cd ..\SocketMod_Lib
lazbuild --build-all --cpu=i386 --os=Win32 --build-mode=Release SocketMod_Lib.lpi
IF ERRORLEVEL 1 GOTO FAIL

ECHO.
ECHO Build finished
ECHO.
GOTO END

:FAILENVIRONMENT
  ECHO.
  ECHO FPCBIN does not exist, please adjust variable
  ECHO.
  PAUSE
  GOTO END

:FAIL
  ECHO.
  ECHO Build failed
  ECHO.
  PAUSE

:END
