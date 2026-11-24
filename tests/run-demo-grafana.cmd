@echo off
setlocal
pushd "%~dp0..\source" || exit /b 1
msbuild OTel4D.dproj /t:Build /p:Config=Release /p:Platform=Win32 /v:minimal /nologo
if errorlevel 1 goto failed
pushd "Win32\Release" || goto failed
dcc32 -B -Q -LUrtl;OTel4D -U".;%~dp0..\examples\TelemetryDemo" -N0. -E. "%~dp0TelemetryDemoSmoke.dpr"
if errorlevel 1 goto consumerfailed
TelemetryDemoSmoke.exe %*
if errorlevel 1 goto consumerfailed
popd
popd
exit /b 0

:consumerfailed
popd
:failed
popd
exit /b 1
