@echo off 

rem # Written by Lidor Goren (lidor@us.ibm.com)

rem # This script will compare two version numbers of the form x[.y[.z[..]]]
rem # and print out 1 if the first version is equal to or higher than the second

rem setlocal ENABLEDELAYEDEXPANSION

setlocal
set V1=%1
set V2=%2

rem echo %V1%
rem echo %V2%

:loop
rem # Extract the most major version number (i.e. first element in split by '.')
for /f "delims=." %%a in ("%V1%") do set e1=%%a
rem echo %e1%
for /f "delims=." %%a in ("%V2%") do set e2=%%a
rem echo %e2%

if %e1% gtr %e2% goto :return_true
if %e1% lss %e2% goto :return_false
	
rem # Loop if both strings still contain '.' (we compare string substitutions to find out)
if not "%V1:.=%"=="%V1%" (if not "%V2:.=%"=="%V2%" (
  set V1=%V1:*.=%
  set V2=%V2:*.=%
  goto :loop
))

if not "%V2:.=%"=="%V2%" goto :return_false

:return_true
echo 1
goto :end

:return_false
echo 0
goto :end

:end
endlocal
