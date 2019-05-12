/*
Example showing app-specific hotkeys
*/
#SingleInstance force
#Include AppFactory.ahk

factory := new AppFactory(, Func("EnableHotkeys")) ; Pass function object as 2nd parameter
factory.AddInputButton("HK1", "w200", Func("HK1"))
Gui, Show
return

; Return true if hotkeys should be enabled, else false
EnableHotkeys(){
	return WinActive("ahk_class Notepad")
}

^Esc::
GuiClose:
	ExitApp

HK1(state){
	Tooltip % "Input changed state to: " state " @ " A_TickCount
}