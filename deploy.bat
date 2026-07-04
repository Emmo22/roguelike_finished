@echo off
REM Wrapper so deploy.sh runs under Git Bash (not the WSL bash shim).
"C:\Program Files\Git\bin\bash.exe" "%~dp0deploy.sh" %*
