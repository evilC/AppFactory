#SingleInstance force
#NoEnv
#Include AppFactory.ahk

factory := new AppFactory()
factory.AddInputButton("MyHotkey", "w200", Func("SendGreeting"))
factory.AddControl("UserName", "Edit", "xm w200")
Gui, Show, x0 y0
return

SendGreeting(state){
	global factory
	if (state){ ; When the key is pressed
		name := factory.GuiControls.UserName.Get() ; Get the value of the Edit box
		Send Hi, My name is %name%	; Send greeting
	}
}

^Esc::
GuiClose:
	ExitApp
