/*
Demonstrates a Dynamic Drop-Down-List (DDL) GuiControl
End-Users can add / remove items to the DDL, and the current selection is remembered between runs
*/
#SingleInstance force
#NoEnv
#Include AppFactory.ahk
factory := new AppFactory()

; Add array as a CustomSetting called DDDL_Contents to hold values in DDL
factory.AddCustomSetting("DDDL_Contents", [])
; Get current value of DDDL_Contents CustomSetting from AppFactory
arr := factory.CustomSettings.DDDL_Contents.Get()

; Convert array to | separated list
l := factory.BuildDdlListFromArray(arr)
; Create Dynamic DDL with options that were in the DDDL_Contents CustomSetting
Gui, Add, Text, xm y+5 w100 , Window Name
factory.AddControl("DDDL", "DDL", "x+5 yp-2 w200", l, Func("DDDL_Changed"))
Gui, Add, Button, x+5 yp-1 w75 gRemove, Remove

Gui, Add, Text, xm y+5 w100 section, Activate Hotkey
Gui, Add, Text, x+5 w200 hwndhActivateHint, No Window Selected
; Add Hotkeys
for k, v in arr {
	factory.AddInputButton("Activate " v, "w280 x115 ys-2 Hidden", Func("Activate").Bind(v))
}

; Get Currently selected window
item := factory.GuiControls.DDDL.Get()
SetVisibleHotkey(item)

Gui, Add, Button, xm ys+30 w385 gAdd, Add New Window
Gui, Show,, Dynamic DDL with Hotkeys demo
return

Add:
	; Set WindowSelectMode to true, which enables the LButton hotkey
	; The next window to be clicked on will be added
	ToolTip Click on window to add
	WindowSelectMode := true
	return

Remove:
	item := factory.GuiControls.DDDL.Get()
	; Remove item from GuiControl
	factory.GuiControls.DDDL.RemoveCurrentItem()
	; Remove item from DDDL_Contents CustomSetting
	value := factory.CustomSettings.DDDL_Contents.Get()
	Loop % value.Length() {
		v := value[A_Index]
		if (v == item){
			value.RemoveAt(A_Index)
			break
		}
	}
	factory.CustomSettings.DDDL_Contents.SetValue(value)
	RemoveHotkey(item)
	return

#if WindowSelectMode
~LButton::
	Tooltip
	WindowSelectMode := false
	windowHwnd := WinExist("A")
	WinGetClass, windowClass , % "ahk_id " windowHwnd
	winTitle := "ahk_class " windowClass
	; Add Item to GuiControl
	factory.GuiControls.DDDL.AddItem(winTitle)
	; Add item to DDDL_Contents CustomSetting
	value := factory.CustomSettings.DDDL_Contents.Get()
	value.Push(winTitle)
	factory.CustomSettings.DDDL_Contents.SetValue(value)
	AddHotkey(winTitle)
	return
#if

DDDL_Changed(value){
	SetVisibleHotkey(value)
}

Activate(windowName, state){
	if (state)
		WinActivate, % windowName
}

AddHotkey(windowName){
	global factory
	factory.AddInputButton("Activate " windowName, "w200 x115 ys Hidden", Func("Activate").Bind(windowName))
}

RemoveHotkey(windowName){
	global factory
	factory.RemoveInputButton("Activate " windowName)
	SetVisibleHotkey("")	; AHK does not support removing GuiControls, so just hide it
}

SetVisibleHotkey(hkName := ""){
	global factory, hActivateLabel
	static currentVisibleHotkey := ""
	if (currentVisibleHotkey != ""){
		currentVisibleHotkey.SetVisible(false)
	}
	if (hkName == ""){
		GuiControl, Show, % hActivateHint
	} else {
		GuiControl, Hide, % hActivateHint
		hkControl := factory.IOControls["Activate " hkName]
		hkControl.SetVisible(true)
		currentVisibleHotkey := hkControl
	}
}


^Esc::
GuiClose:
	ExitApp
