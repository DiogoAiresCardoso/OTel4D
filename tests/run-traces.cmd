@echo off
setlocal
if not defined OTEL4D_TEST_PYTHON set "OTEL4D_TEST_PYTHON=python"
pushd "%~dp0..\source" || exit /b 1
msbuild OTel4D.dproj /t:Build /p:Config=Debug /p:Platform=Win32 /v:minimal /nologo
if errorlevel 1 goto failed
pushd "Win32\Debug" || goto failed
dcc32 -B -Q -LUrtl;OTel4D -U. -N0. -E. "%~dp0TraceSmoke.dpr"
if errorlevel 1 goto consumerfailed
"%OTEL4D_TEST_PYTHON%" "%~dp0verify_traces.py" "%CD%\TraceSmoke.exe"
if errorlevel 1 goto consumerfailed
popd
popd
exit /b 0

:consumerfailed
popd
:failed
popd
exit /b 1
