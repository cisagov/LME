@echo off

(wmic computersystem get domain | findstr /v Domain | findstr /r /v "^$") > fqdn.txt
set /p FQDN=<fqdn.txt
set FQDN=%FQDN: =%
echo %FQDN%

:: Set the network directory to the network location containing all LME files
:: If you're using the recommended SYSVOL directory, the network directory is already correctly configured
set NETDIR=\\%FQDN%\SYSVOL\%FQDN%\LME

SET SYSMONDIR=C:\windows\sysmon
SET SYSMONBIN=Sysmon64.exe
SET SYSMONCONF=sysmon.xml
SET SIGCHECK=sigcheck64.exe


SET GLBSYSMONBIN=%NETDIR%\Sysmon\%SYSMONBIN%
SET GLBSYSMONCONFIG=%NETDIR%\Sysmon\%SYSMONCONF%
SET GLBSIGCHECK=%NETDIR%\%SIGCHECK%


:: Is Sysmon running  
sc query "Sysmon64" | find "STATE" | find "RUNNING"
If "%ERRORLEVEL%" NEQ "0" (
:: No, lets try to start it
goto startsysmon
) ELSE (
:: Yes, Lets see if it needs updating
goto checkversion
)


:startsysmon
sc start Sysmon64
If "%ERRORLEVEL%" EQU "1060" (
:: Wont start, Lets install it
goto installsysmon
) ELSE (
:: Started, Lets see if it needs updating
goto checkversion
)


  
:installsysmon
IF Not EXIST %SYSMONDIR% (
mkdir %SYSMONDIR%
)
copy %GLBSYSMONBIN% %SYSMONDIR% /y
copy %GLBSYSMONCONFIG% %SYSMONDIR% /y
copy %GLBSIGCHECK% %SYSMONDIR% /y
chdir %SYSMONDIR%
%SYSMONBIN% -i %SYSMONCONF% -accepteula
sc config Sysmon64 start= auto
goto :checkversion



:: Check if sysmon64.exe matches the hash of the central version 
:checkversion
chdir %SYSMONDIR%
IF EXIST *.txt DEL /F *.txt
IF NOT EXIST %SIGCHECK% (copy %GLBSIGCHECK% %SYSMONDIR% /y)
(sigcheck64.exe -n -nobanner /accepteula Sysmon64.exe) > %SYSMONDIR%\runningver.txt
(sigcheck64.exe -n -nobanner /accepteula %GLBSYSMONBIN%) > %SYSMONDIR%\latestver.txt
set /p runningver=<%SYSMONDIR%\runningver.txt
set /p latestver=<%SYSMONDIR%\latestver.txt
echo Currently running sysmon : %runningver%
echo Latest sysmon is %latestver% located at %GLBSYSMONBIN%
If "%runningver%" NEQ "%latestver%" (
goto uninstallsysmon
) ELSE (
goto updateconfig
)

:updateconfig
chdir %SYSMONDIR%
IF EXIST runningconfver.txt DEL /F runningconfver.txt
IF EXIST latestconfver.txt DEL /F latestconfver.txt
if NOT EXIST %SIGCHECK% (
copy %GLBSIGCHECK% %SYSMONDIR% /y)
::Added -c for the comparison, enables us to compare hashes
(sigcheck64.exe -h -c -nobanner /accepteula %SYSMONCONF%) > %SYSMONDIR%\runningconfver.txt
(sigcheck64.exe -h -c -nobanner /accepteula %GLBSYSMONCONFIG%) > %SYSMONDIR%\latestconfver.txt
::Looks for the 11th token in the csv of sigcheck. This is the MD5 hash. 12th token is SHA1, 15th is SHA2
for /F "delims=, tokens=11" %%h in (runningconfver.txt) DO (set runningconfver=%%h)
for /F "delims=, tokens=11" %%h in (latestconfver.txt) DO (set latestconfver=%%h)
::The following commands are not usful because they are comparing only the first line, which includes the path of the checked file. And this is always not eqal.
::set /p runningconfver=<%SYSMONDIR%\runningconfver.txt
::set /p latestconfver=<%SYSMONDIR%\latestconfver.txt
If "%runningconfver%" NEQ "%latestconfver%" (
copy %GLBSYSMONCONFIG% %SYSMONCONF% /y
chdir %SYSMONDIR%
(%SYSMONBIN% -c %SYSMONCONF%)
)

sc stop Sysmon64
sc start Sysmon64
EXIT /B 0

:uninstallsysmon
chdir %SYSMONDIR%
%SYSMONBIN% -u
goto installsysmon
