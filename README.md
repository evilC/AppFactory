# AppFactory
A library for creating Apps with configurable inputs and settings.  

**Note that AppFactory ONLY works with [AutoHotkey_H](http://hotkeyit.github.io/v2/) v1**  
This is just an extended version of "Regular" AHK (AHK_L), it should not break any of your existing AHK_L scripts.  

To package a script for release:  
From the AHK_H distro `ahkdll-v1-release-master.zip` in the folder `ahkdll-v1-release-master\Win32a`, copy `AutoHotkey.exe` and `msvcr100.dll` to your script folder.  

Then rename `AutoHotkey.exe` to match your script, eg for `MyScript.ahk`, call it `MyScript.exe`  
If a new version of AHK comes out, you may or may not need to replace the EXE again, but the DLL should not change.  

**You cannot currently compile AppFactory scripts, however this is technically feasible** 
