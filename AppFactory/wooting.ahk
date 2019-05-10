#SingleInstance force
#NoEnv
#Include AppFactory.ahk
OutputDebug DBGVIEWCLEAR
Settings := {}

;~ msgbox % GetKeySC("F12")
;~ msgbox % GetKeyVK("F12")
;~ return

factory := new AppFactory()

scroller := new WootingKey("Scroller", Func("ScrollerAxisUpdate"))

;~ Gui, Add, Text, xm section, Stick ID
;~ factory.AddControl("JoyNum", "DDL", "x+5 yp-3 w40", "1||2|3|4|5|6|7|8", Func("GuiEvent").Bind("JoyNum"))
;~ Gui, Add, Text, x+5 ys, Axis
;~ factory.AddControl("JoyAxis", "DDL", "x+5 yp-3 w40", "X||Y|Z|R|U|V", Func("GuiEvent").Bind("JoyAxis"))
;~ Gui, Add, Slider, xm w150 hwndhSlider
;~ Gui, Add, Text, xm, Threshold `%
;~ factory.AddControl("Threshold", "Edit", "x+5 yp-3 w40", "50", Func("GuiEvent").Bind("Threshold"))

;~ SetTimer, WatchAxis, 20
;~ GuiControl, +g, % hSlider, Tes
;~ factory.AddInputButton("HK1", "w200", Func("InputEvent").Bind("1"))
;~ factory.AddInputButton("HK2", "xm w200", Func("InputEvent").Bind("2"))
;~ factory.AddControl("MyEdit", "Edit", "xm w200", "Default Value", Func("GuiEvent").Bind("MyEdit"))
;~ factory.AddControl("MyDDL", "DDL", "xm w200 AltSubmit", "One||Two|Three", Func("GuiEvent").Bind("MyDDL"))

Gui, Show, x0 y0
return

ScrollerAxisUpdate(value){
	ToolTip % "Scroller: " value
}

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

Class WootingKey {
	AxisWatcherState := 0
	AxisValue := 0
	;~ AnalogOutputEnabled := 0
	AnalogOutputState := 0 ; 0 = Off, 1 = Waiting to see if past threshold in timeout, 2 = In analog mode, 3 = Keypress activated, waiting for release
	__New(name, analogCallback){
		global factory
		this.Name := name
		this.AnalogCallback := analogCallback
		this.AxisWatcherFn := this.WatchAxis.Bind(this)
		this.StartAnalogFn := this.StartAnalogOutput.Bind(this)

		Gui, Add, Text, xm w100 section, % Name ":"
		Gui, Add, Text, x+5 ys, Stick ID
		factory.AddControl(name "-JoyNum", "DDL", "x+5 yp-3 w40", "1||2|3|4|5|6|7|8", this.JoyNumChanged.Bind(this))
		Gui, Add, Text, x+5 ys, Axis
		factory.AddControl(name "-JoyAxis", "DDL", "x+5 yp-3 w40", "X||Y|Z|R|U|V", this.JoyAxisChanged.Bind(this))
		Gui, Add, Slider, x+5 ys-3 w100 hwndhSlider
		this.hSlider := hSlider
		Gui, Add, Text, x+5 ys, Key
		this.KeyControl := factory.AddInputButton(name "-HK1", "x+5 yp-3 w200", this.KeyEvent.Bind(this), this.KeyChanged.Bind(this))
		Gui, Add, Text, x+5 ys, Threshold `%
		factory.AddControl("Threshold", "Edit", "x+5 yp-3 w40", "50", this.ThresholdChanged.Bind(this))
		
		this.SetAxisWatcherState(1)
	}
	
	StartAnalogOutput(){
		; Transition from AnalogOutputState 1 to 2
		this.AnalogOutputState := 2
		OutputDebug % "AHK| Mode: 1 -> 2 *BEGIN ANALOG*"
	}
	
	; ============ Raw Input Events ==========
	
	KeyEvent(state){
		ToolTip % "Key Event - Name: " this.Name " , State: " state
		fn := this.StartAnalogFn
		if (state){
			; Transition from AnalogOutputState 0 to 1
			SetTimer, % fn, -200
			this.AnalogOutputState := 1
			OutputDebug % "AHK| Mode: 0 -> 1 *WAIT FOR TIMEOUT*"
		} else {
			if (this.AnalogOutputState == 1){
				; Transition from AnalogOutputState 1 to 0 (Rap - released button before timer expired)
				SetTimer, % fn, Off
				OutputDebug % "AHK| Mode: 1 -> 0 *TIMEOUT ABORT*"
				this.AnalogOutputState := 0
			}
			/*
			else if (this.AnalogOutputState == 2){
				; ???
			}
			*/
			
		}
	}
	
	WatchAxis(){
		value := GetKeyState(this.JoyString)
		if (value == this.AxisValue)
			return
		this.AxisValue := value
		overThresh := value > this.Threshold
		/*
		if (overThresh && this.AnalogOutputState == 0){
			; Transition from AnalogOutputState 0 to 1
			
		} else 
		*/
		if (overThresh && this.AnalogOutputState == 2){
			; Continue Analog mode
			outVal := (value - this.Threshold) * this.OutputValueScaleFactor
			this.AnalogCallback.Call(outVal)
		} else if (overThresh && this.AnalogOutputState == 1){
			; Transition from AnalogOutputState 1 to 3 (Passed threshold before timer expired)
			fn := this.StartAnalogFn
			SetTimer, % fn, Off
			;~ Send % "{a down}"
			this.AnalogOutputState := 3
			OutputDebug % "AHK| Mode: 1 -> 3 *KEY PRESS*"
		} else if (!overThresh && this.AnalogOutputState == 3){
			; Transition from AnalogOutputState 3 to 0
			;~ Send % "{a up}"
			this.AnalogOutputState := 0
			OutputDebug % "AHK| Mode: 3 -> 0 *KEY RELEASE"
		} else if (value == 0 && this.AnalogOutputState == 2){
			; Transition from AnalogOutputState 2 to 0
			this.AnalogOutputState := 0
			OutputDebug % "AHK| Mode: 2-> 0 *END ANALOG*"
		} else if (!overThresh && this.AnalogOutputState == 2){
			OutputDebug % "AHK| Mode: 2-> 0 *ANALOG MODE WAITING FOR FULL RELEASE*"
			;~ this.AnalogCallback.Call(0)
		}
		GuiControl, , % this.hSlider, % value
	}
	
	; ========== Gui events ===========
	
	KeyChanged(bo){
		this.KeyName := this.KeyControl.BuildKeyName(bo.Binding[1])
	}
	
	JoyNumChanged(id){
		this.JoyNum := id
		this.SetAxisWatcherState(1)
	}
	
	JoyAxisChanged(axis){
		this.JoyAxis := axis
		this.SetAxisWatcherState(1)
	}
	
	ThresholdChanged(thresh){
		this.Threshold := thresh
		this.OutputValueScaleFactor := 100 / (100 - thresh)
	}
	
	SetAxisWatcherState(state){
		fn := this.AxisWatcherFn
		if (!state || state && this.AxisWatcherState){
			SetTimer, % fn, Off
		}
		if (state){
			this.JoyString := this.JoyNum "Joy" this.JoyAxis
			SetTimer, % fn, 20
		} else {
			SetTimer, % fn, Off
		}
	}

}

^Esc::
GuiClose:
	ExitApp
