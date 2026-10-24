@echo off
setlocal EnableDelayedExpansion
title cat's nmap #
color 0A

:: ==============================================================
::                    c a t ' s   n m a p   #
::   a tiny nmap-style TCP connect scanner, written in batch
::   (powershell is used only for the raw tcp connects)
::
::   usage: catnmap.bat <target> [ports] [timeout_ms]
::     catnmap.bat 192.168.1.1 1-1024
::     catnmap.bat scanme.nmap.org 22,80,443,8080
:: ==============================================================

set "TARGET=%~1"
set "PORTS=%~2"
set "TIMEOUT=%~3"

if /i "%TARGET%"=="/?"    goto :usage
if /i "%TARGET%"=="-h"    goto :usage
if /i "%TARGET%"=="--help" goto :usage

if "%TARGET%"=="" set /p "TARGET=target ip / hostname : "
if "%PORTS%"==""  set /p "PORTS=ports (22,80,443 or 1-1024) : "
if "%PORTS%"==""  set "PORTS=1-1024"
if "%TIMEOUT%"=="" set "TIMEOUT=700"
set "PORTS=%PORTS: =%"

if "%TARGET%"=="" (
  echo no target given.
  pause
  exit /b
)

echo.
echo    /\_/\
echo   ( o.o )   cat's nmap #
echo    ^> ^^ ^<
echo  ===============================================
echo     tcp connect scan
echo  ===============================================
echo.

set "IP="
for /f "delims=" %%i in ('powershell -NoProfile -Command "try{(Resolve-DnsName -Name '%TARGET%' -Type A -ErrorAction Stop^).IPAddress}catch{}" 2^>nul') do set "IP=%%i"
if "%IP%"=="" set "IP=%TARGET%"

echo  [*] target    : %TARGET%
echo  [*] resolved  : %IP%
ping -n 1 -w 1000 %IP% >nul 2>&1
if errorlevel 1 (echo  [*] host      : seems DOWN ^(icmp may be filtered^)) else (echo  [*] host      : is UP)
echo  [*] ports     : %PORTS%
echo  [*] timeout   : %TIMEOUT% ms/port
echo.

:: ---- generate the powershell connect engine ----
set "PS1=%TEMP%\catnmap_%RANDOM%%RANDOM%.ps1"
> "%PS1%"  echo param([string]$t,[string]$p,[int]$to)
>>"%PS1%" echo function Get-Ports($s){
>>"%PS1%" echo   foreach($x in $s.Split(',')){
>>"%PS1%" echo     $x = $x.Trim()
>>"%PS1%" echo     if($x -match '^^(\d+)-(\d+)$'){ $a=[int]$Matches[1]; $b=[int]$Matches[2]; for($n=$a;$n -le $b;$n++){ $n } }
>>"%PS1%" echo     elseif($x -match '^^\d+$'){ [int]$x }
>>"%PS1%" echo   }
>>"%PS1%" echo }
>>"%PS1%" echo foreach($port in (Get-Ports $p)){
>>"%PS1%" echo   $c = New-Object System.Net.Sockets.TcpClient
>>"%PS1%" echo   $sw = [Diagnostics.Stopwatch]::StartNew()
>>"%PS1%" echo   try{
>>"%PS1%" echo     $iar = $c.BeginConnect($t,$port,$null,$null)
>>"%PS1%" echo     if($iar.AsyncWaitHandle.WaitOne($to,$false) -and $c.Connected){
>>"%PS1%" echo       $sw.Stop()
>>"%PS1%" echo       Write-Output ('OPEN ' + $port + ' ' + $sw.ElapsedMilliseconds)
>>"%PS1%" echo     }
>>"%PS1%" echo   }catch{}
>>"%PS1%" echo   $c.Close()
>>"%PS1%" echo }

:: ---- scan ----
echo  PORT       STATE     SERVICE
echo  ----       -----     -------
set /a OPEN=0
for /f "tokens=1,2,3" %%a in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" "%IP%" "%PORTS%" %TIMEOUT%') do (
  if /i "%%a"=="OPEN" (
    set /a OPEN+=1
    call :svc %%b
    echo   %%b/tcp    open      !SVC!
  )
)
echo.
if !OPEN!==0 (
  echo  no open ports found on %IP%
) else (
  echo  scan complete - !OPEN! port^(s^) open on %IP%
)
del "%PS1%" >nul 2>&1
echo.
pause
exit /b

:: ---- port -> service lookup ----
:svc
set "SVC=unknown"
if "%~1"=="20"    set "SVC=ftp-data"
if "%~1"=="21"    set "SVC=ftp"
if "%~1"=="22"    set "SVC=ssh"
if "%~1"=="23"    set "SVC=telnet"
if "%~1"=="25"    set "SVC=smtp"
if "%~1"=="53"    set "SVC=dns"
if "%~1"=="67"    set "SVC=dhcp"
if "%~1"=="80"    set "SVC=http"
if "%~1"=="110"   set "SVC=pop3"
if "%~1"=="135"   set "SVC=msrpc"
if "%~1"=="139"   set "SVC=netbios"
if "%~1"=="143"   set "SVC=imap"
if "%~1"=="161"   set "SVC=snmp"
if "%~1"=="389"   set "SVC=ldap"
if "%~1"=="443"   set "SVC=https"
if "%~1"=="445"   set "SVC=smb"
if "%~1"=="465"   set "SVC=smtps"
if "%~1"=="587"   set "SVC=smtp-sub"
if "%~1"=="993"   set "SVC=imaps"
if "%~1"=="995"   set "SVC=pop3s"
if "%~1"=="1433"  set "SVC=mssql"
if "%~1"=="1521"  set "SVC=oracle"
if "%~1"=="3306"  set "SVC=mysql"
if "%~1"=="3389"  set "SVC=rdp"
if "%~1"=="5432"  set "SVC=postgres"
if "%~1"=="5900"  set "SVC=vnc"
if "%~1"=="6379"  set "SVC=redis"
if "%~1"=="8080"  set "SVC=http-proxy"
if "%~1"=="8443"  set "SVC=https-alt"
if "%~1"=="27017" set "SVC=mongodb"
exit /b

:usage
echo.
echo   cat's nmap # - usage
echo   ----------------
echo   catnmap.bat ^<target^> [ports] [timeout_ms]
echo.
echo   target     : ip address or hostname
echo   ports      : 22,80,443   or a range like 1-1024
echo   timeout_ms : per-port wait, default 700
echo.
echo   examples:
echo     catnmap.bat 192.168.1.1 1-1024
echo     catnmap.bat scanme.nmap.org 22,80,443
echo.
exit /b