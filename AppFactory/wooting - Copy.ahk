#SingleInstance force
#NoEnv
#Include AppFactory.ahk
Settings := {}

factory := new AppFactory()
Gui, Add, Text, xm section, Stick ID
factory.AddControl("JoyNum", "DDL", "x+5 yp-3 w40", "1||2|3|4|5|6|7|8", Func("GuiEvent").Bind("JoyNum"))
Gui, Add, Text, x+5 ys, Axis
factory.AddControl("JoyAxis", "DDL", "x+5 yp-3 w40", "X||Y|Z|R|U|V", Func("GuiEvent").Bind("JoyAxis"))
Gui, Add, Slider, xm w150 hwndhSlider
Gui, Add, Text, xm, Threshold `%
factory.AddControl("Threshold", "Edit", "x+5 yp-3 w40", "50", Func("GuiEvent").Bind("Threshold"))

SetTimer, WatchAxis, 20
;~ GuiControl, +g, % hSlider, Tes
;~ factory.AddInputButton("HK1", "w200", Func("InputEvent").Bind("1"))
;~ factory.AddInputButton("HK2", "xm w200", Func("InputEvent").Bind("2"))
;~ factory.AddControl("MyEdit", "Edit", "xm w200", "Default Value", Func("GuiEvent").Bind("MyEdit"))
;~ factory.AddControl("MyDDL", "DDL", "xm w200 AltSubmit", "One||Two|Three", Func("GuiEvent").Bind("MyDDL"))

Gui, Show, x0 y0
return

WatchAxis:
	value := GetKeyState(JoyString)
	GuiControl, , % hSlider, % value
	return

InputEvent(ctrl, state){
	Global factory
	Tooltip % "Input " ctrl " changed state to: " state " after " A_TickCount " ticks while MyEdit was '" factory.GuiControls.MyEdit.Get() "'"
}

GuiEvent(ctrl, state){
	global Settings, JoyString
	Settings[ctrl] := state
	JoyString := Settings.JoyNum "Joy" Settings.JoyAxis
	;~ Tooltip % "GuiControl " ctrl " changed state to: '" state "' after " A_TickCount " ticks"
}

^Esc::
GuiClose:
	ExitApp
