# AppFactory
A library for creating Apps with configurable inputs and settings.  

## [Discussion Thread on AHK forums](https://www.autohotkey.com/boards/viewtopic.php?t=38651)  

## What does it do?
In a typical AutoHotkey script, you declare a hotkey, and have it call some code when that hotkey is pressed, eg:
```
F1::
  Send Hi, my name is evilC
  return
 ```
However, if you wish to distribute your scripts to other people, each person may want to select their own hotkey (ie they may not want to use the `F1` key to send `Hi, my name is evilC`, they may want to use `Page Up`  
Normally, this would require the end-user to edit the AutoHotkey script, and they may not know how to do this.  
AppFactory solves this by allowing the end-user to select which Hotkey they wish to use by using a custom GuiControl.  
This selection is then saved to a settings file, so that next time the script is run, it remembers the user's selection.  
An AppFactory equivalent of the above code would be something like:  
```
factory.AddInputButton("MyHotkey", "w200", Func("TypeGreeting")) ; Add user-selectable hotkey GuiControl, point it at "TypeGreeting" function
; ...
TypeGreeting(state){
  if (state){  ; When key is pressed
    Send Hi, my name is evilC
  }
}
```

AppFactory also allows the script author to add "Persistent GuiControls" to their scripts (Edit boxes, check boxes, drop down lists etc) and the state of these are also saved to the settings file. This allows you to easily add configurable options to your scripts.  
Extending the above example, everybody is obviously not called `evilC`, so you would probably want to allow users of your script to set their own name. This can be done using a custom EditBox:

```
factory.AddInputButton("MyHotkey", "w200", Func("TypeGreeting")) ; Add user-selectable hotkey GuiControl, point it at "TypeGreeting" function
factory.AddControl("UserName", "Edit", "xm w200") ; Add user-editable EditBox GuiControl
; ...
TypeGreeting(state){
  Global factory ; Allow this function to see the appfactory object
  if (state){  ; When key is pressed
    name := factory.GuiControls.UserName.Get() ; Get value from the UserName GuiControl
    Send Hi, my name is %name%
  }
}
```

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

### Usage
#### Including the library
Alls scripts must reference the AppFactory library to be able to use it's functions
##### AHK_L (Regular AutoHotkey)
`#Include AppFactory.ahk`
##### AHK_H
`#Include ..\Source\AppFactory.ahk`
#### Initializing the library
`factory := new AppFactory()`

#### Adding GuiControls
##### Hotkey GuiControls

##### Persistent GuiControls  
This can be thought of as an equivelent to AHK's [`Gui, Add`](https://www.autohotkey.com/docs/commands/Gui.htm#Add) command, except that the value of the GuiControl is remembered between runs of the script.  
`obj := factory.AddControl(<Control Name>, <ControlType >, [<Options>, <Text>, <Callback>])`  
###### Control Name
The unique name for this control - should ideally have no spaces.  
This will be used by other commands to refer to this control  
###### ControlType
One of the normal [AHK names for GuiControl types](https://www.autohotkey.com/docs/commands/Gui.htm#Add)  
###### Options
(Optional) Options for the GuiControl (To control position, size etc)  
Uses the same format as if you were doing a normal AHK `Gui, Add` command  
###### Text
(Optional) Performs the same function as the Text parameter of Gui, Add (Sets default value etc)  
###### Callback
(Optional) A Function Object that is to be called whenever the contents of the control changes.  
The callback function is passed the new value of the control, eg:  
```
factory.AddControl("UserName", "Edit", "xm w200", "Default Value", Func("MyFunc"))
; ...
MyFunc(value){
  ; value holds the new value of the control
}
```
###### Return Value
A reference to the GuiControl object is returned by this function (`obj` in the above example), which may optionally be stored in a variable.  

###### Examples
`factory.AddControl("UserName", "Edit", "xm w200")` Create a control called `UserName`, of type `Edit`, positioned against the left margin, with a width of 200px  
`factory.AddControl("UserName", "Edit", "xm w200", "Default Value")` As before, but with a default value of `Default Value`  
`factory.AddControl("UserName", "Edit", "xm w200", "Default Value", Func("MyFunc"))` As before, but when the user types something in the Edit box, as each character is typed, fire the function `MyFunc` and pass it the new value  

