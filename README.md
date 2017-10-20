# AppFactory
A library for creating Apps with configurable inputs and settings.  

## AutoHotkey versions
### AHK_L (Regular AutoHotkey)  
Use AHK_L 1.x from [here](http://AutoHotkey.com)  
Use the version from the `AppFactory` folder.

### AHK_H  
Use the version from the `AppFactory_H` folder.  
You will need [AutoHotkey_H](http://hotkeyit.github.io/v2/) (Supports v1 only)  
To package a script for release:  
From the AHK_H distro `ahkdll-v1-release-master.zip` in the folder `ahkdll-v1-release-master\Win32a`, copy `AutoHotkey.exe` and `msvcr100.dll` to your script folder.  

Then rename `AutoHotkey.exe` to match your script, eg for `MyScript.ahk`, call it `MyScript.exe`  
If a new version of AHK comes out, you may or may not need to replace the EXE again, but the DLL should not change.  
