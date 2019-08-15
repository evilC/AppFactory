#include %A_LineFile%\..\JSON.ahk
#include %A_LineFile%\..\BindModeThread.ahk
#include %A_LineFile%\..\InputThread.ahk

; "hotkey, if" needs to have actual #if blocks to match to, so declare empty ones
#If _AppFactoryBindMode
#If !_AppFactoryBindMode
#If

_AppFactoryBindMode := 0

Class AppFactory {
	InputThread := 0
	IOControls := {}
	GuiControls := {}
	Settings := {}
	
	; ====================== PUBLIC METHODS. USER SCRIPTS SHOULD ONLY CALL THESE ========================
	AddInputButton(guid, options, callback){
		this.IOControls[guid] := new this._IOControl(this, guid, options, callback)
		this.IOControls[guid].SetBinding(this.Settings.IOControls[guid])
	}
	
	AddControl(guid, ctrltype, options := "", default := "", callback := 0){
		this.GuiControls[guid] := new this._GuiControl(this, guid, ctrltype, options, default, callback)
		if (this.Settings.GuiControls.Haskey(guid)){
			this.GuiControls[guid].SetValue(this.Settings.GuiControls[guid])
		} else {
			if (this.GuiControls[guid].IsListType){
				d := RegExMatch(default, "(.*)\|\|", out)
				default := out1
			}
			this.GuiControls[guid].SetValue(default)
		}
		
	}
	
	; ====================== PRIVATE METHODS. USER SCRIPTS SHOULD NOT CALL THESE ========================
	__New(hwnd := 0){
		this._SettingsFile := RegExReplace(A_ScriptName, ".ahk|.exe", ".ini")

		this.InitBindMode()
		this.InitInputThread()
		
		if (hwnd == 0)
			Gui, +Hwndhwnd
		this.hwnd := hwnd
		
		FileRead, j, % this._SettingsFile
		if (j == ""){
			j := {IOControls: {}, GuiControls: {}}
		} else {
			j := JSON.Load(j)
		}
		this.Settings := j
		this.InputThread.SetDetectionState(1)
	}
	
	; When bind mode ends, the GuiControl will call this method to request that the setting be saved
	_BindingChanged(ControlGuid, bo){
		this.Settings.IOControls[ControlGuid] := bo
		this._SaveSettings()
	}
	
	_GuiControlChanged(ControlGuid, value){
		this.Settings.GuiControls[ControlGuid] := value
		this._SaveSettings()
	}
	
	_SaveSettings(){
		FileDelete, % this._SettingsFile
		FileAppend, % JSON.Dump(this.Settings, ,true), % this._SettingsFile
	}
	
	; ============================================================================================
	; ==================================== GUICONTROLS ===========================================
	; ============================================================================================
	class _GuiControl {
		static _ListTypes := {ListBox: 1, DDL: 1, DropDownList: 1, ComboBox: 1, Tab: 1, Tab2: 1, Tab3: 1}
		_Value := ""
		
		Get(){
			return this._Value
		}
		
		__New(parent, guid, ctrltype, options, default, callback){
			this.id := guid
			this.parent := parent
			this.Callback := callback
			this.Default := default
			
			if (ObjHasKey(this._ListTypes, ctrltype)){
				this.IsListType := 1
				; Detect if this List Type uses AltSubmit
				if (InStr(options, "altsubmit"))
					this.IsAltSubmitType := 1
				else 
					this.IsAltSubmitType := 0
			} else {
				this.IsListType := 0
				this.IsAltSubmitType := 0
			}
			
			Gui, % this.parent.hwnd ":Add", % ctrltype, % "hwndhwnd " options, % default
			this.hwnd := hwnd
			fn := this.ControlChanged.Bind(this)
			this.ChangeValueFn := fn
			this._SetGLabel(1)
			
			return this
		}
		
		SetControlState(value){
			this._SetGlabel(0)						; Turn off g-label to avoid triggering save
			cmd := ""
			if (this.IsListType){
				cmd := (this.IsAltSubmitType ? "choose" : "choosestring")
			}
			GuiControl, % this.parent.hwnd ":" cmd, % this.hwnd, % value
			this._SetGlabel(1)						; Turn g-label back on
		}
		
		; Turns on or off the g-label for the GuiControl
		; This is needed to work around not being able to programmatically set GuiControl without triggering g-label
		_SetGlabel(state){
			if (state){
				fn := this.ChangeValueFn
				GuiControl, % this.parent.hwnd ":+g", % this.hwnd, % fn
			} else {
				GuiControl, % this.parent.hwnd ":-g", % this.hwnd
			}
		}
		
		; User interacted with GuiControl
		ControlChanged(){
			GuiControlGet, value, % this.parent.hwnd ":" , % this.hwnd
			this._Value := value
			if (this.Callback != 0){
				this.Callback.call(value)
			}
			this.parent._GuiControlChanged(this.id, value)
		}
		
		; Called on load of settings
		SetValue(value){
			this._Value := value
			this.Callback.call(value)
			this.SetControlState(value)
		}
	}
	
	; ============================================================================================
	; ==================================== IOCONTROLS ============================================
	; ============================================================================================
	class _IOControl {
		guid := 0			; The unique ID/Name for this IOControl
		Callback := 0		; Holds the user's callback for this IOControl
		BindObject := 0		; Holds the BindObject describing the current binding
		State := 0			; The State of the input. Only really used for Repeat Suppression
		
		static _Modifiers := ({91: {s: "#", v: "<"},92: {s: "#", v: ">"}
		,160: {s: "+", v: "<"},161: {s: "+", v: ">"}
		,162: {s: "^", v: "<"},163: {s: "^", v: ">"}
		,164: {s: "!", v: "<"},165: {s: "!", v: ">"}})

		__New(parent, guid, options, callback){
			this.id := guid
			this.parent := parent
			this.Callback := callback
			this.BindObject := new this.parent._BindObject()
			Gui, % this.parent.hwnd ":Add", Button, % "hwndhReadout " options , Select an Input Button
			this.hReadout := hReadout
			fn := this.OpenMenu.Bind(this)
			GuiControl, % this.parent.hwnd ":+g", % hReadout, % fn			
			
			fn := this.IOControlChoiceMade.Bind(this, 1)
			Menu, % this.id, Add, % "Select Binding...", % fn
			
			fn := this.IOControlChoiceMade.Bind(this, 2)
			Menu, % this.id, Add, % "Block", % fn
			
			fn := this.IOControlChoiceMade.Bind(this, 3)
			Menu, % this.id, Add, % "Wild", % fn
			
			fn := this.IOControlChoiceMade.Bind(this, 4)
			Menu, % this.id, Add, % "Suppress Repeats", % fn
			
			fn := this.IOControlChoiceMade.Bind(this, 5)
			Menu, % this.id, Add, % "Clear", % fn
			
		}
		
		SetBinding(bo){
			if (IsObject(bo)){
				bo := bo
				this.BindObject := bo
			} else {
				this.BindObject.Binding := []
			}
			this.parent.InputThread.UpdateBinding(this.id, this.BindObject)
			GuiControl, % this.parent.hwnd ":" , % this.hReadout, % this.BuildHumanReadable()
			for opt, state in bo.BindOptions {
				this.SetMenuCheckState(opt, state)
			}
		}
		
		IOControlChoiceMade(val){
			if (val == 1){
				; Bind
				this.parent.InputThread.SetDetectionState(0)
				this.parent.StartBindMode(this.BindModeEnded.Bind(this))
			} else if (val == 2){
				; Block
				this.BindObject.BindOptions.Block := !this.BindObject.BindOptions.Block
				this.SetMenuCheckState("Block")
				this.BindModeEnded(this.BindObject)
			} else if (val == 3){
				; Wild
				this.BindObject.BindOptions.Wild := !this.BindObject.BindOptions.Wild
				this.SetMenuCheckState("Wild")
				this.BindModeEnded(this.BindObject)
			} else if (val == 4){
				; Suppress Repeats
				this.BindObject.BindOptions.Suppress := !this.BindObject.BindOptions.Suppress
				this.SetMenuCheckState("Suppress")
				this.BindModeEnded(this.BindObject)
			} else if (val == 5){
				; Clear
				this.BindObject := new this.parent._BindObject()
				this.BindModeEnded(this.BindObject)
			}
		}
		
		SetMenuCheckState(which){
			state := this.BindObject.BindOptions[which]
			try Menu, % this.id, % (state ? "Check" : "UnCheck"), % which
		}
		
		BindModeEnded(bo){
			this.SetBinding(bo)
			this.parent._BindingChanged(this.id, bo)
			this.parent.InputThread.SetDetectionState(1)
		}
		
		OpenMenu(){
			ControlGetPos, cX, cY, cW, cH,, % "ahk_id " this.hReadout
			Menu, % this.id, Show, % cX+1, % cY + cH
		}
		
		; Builds a human-readable form of the BindObject
		BuildHumanReadable(){
			str := ""
			if (!this.BindObject.IOClass){
				str := "Select an Input Button..."
			} else if (this.BindObject.IOClass == "AHK_KBM_Input"){
				max := this.BindObject.Binding.length()
				Loop % max {
					str .= this.BuildKeyName(this.BindObject.Binding[A_Index])
					if (A_Index != max)
						str .= " + "
				}
			} else if (this.BindObject.IOClass == "AHK_JoyBtn_Input"){
				return "Stick " this.BindObject.DeviceID " Button " this.BindObject.Binding[1]
			} else if (this.BindObject.IOClass == "AHK_JoyHat_Input"){
				static hat_directions := ["Up", "Right", "Down", "Left"]
				return "Stick " this.BindObject.DeviceID ", Hat " hat_directions[this.BindObject.Binding[1]]
			}
			return str
		}
		
		; Builds the AHK key name
		BuildKeyName(code){
			static replacements := {33: "PgUp", 34: "PgDn", 35: "End", 36: "Home", 37: "Left", 38: "Up", 39: "Right", 40: "Down", 45: "Insert", 46: "Delete"}
			static additions := {14: "NumpadEnter"}
			if (ObjHasKey(replacements, code)){
				return replacements[code]
			} else if (ObjHasKey(additions, code)){
				return additions[code]
			} else {
				return GetKeyName("vk" Format("{:x}", code))
			}
		}
		
		; Returns true if this Button is a modifier key on the keyboard
		IsModifier(code){
			return ObjHasKey(this._Modifiers, code)
		}
		
		; Renders the keycode of a Modifier to it's AHK Hotkey symbol (eg 162 for LCTRL to ^)
		RenderModifier(code){
			return this._Modifiers[code].s
		}
	}
	
	; ====================================== BINDMODE THREAD ==============================================
	; An additional thread that is always running and handles detection of input while in Bind Mode (User selecting hotkeys)
	InitBindMode(){
		
		this._BindModeThread := new _BindMapper(this.ProcessBindModeInput.Bind(this))
		
		Gui, +HwndhOld
		Gui, new, +HwndHwnd
		Gui +ToolWindow -Border
		Gui, Font, S15
		Gui, Color, Red
		this.hBindModePrompt := hwnd
		Gui, Add, Text, Center, Press the button(s) you wish to bind to this control.`n`nBind Mode will end when you release a key.
		Gui, % hOld ":Default"
	}
	
	;IOClassMappings, this._BindModeEnded.Bind(this, callback)
	StartBindMode(callback){
		IOClassMappings := {AHK_Common: 0, AHK_KBM_Input: "AHK_KBM_Input", AHK_JoyBtn_Input: "AHK_JoyBtn_Input", AHK_JoyHat_Input: "AHK_JoyHat_Input"}
		this._callback := callback
		
		this.SelectedBinding := new this._BindObject()
		this.BindMode := 1
		this.EndKey := 0
		this.HeldModifiers := {}
		this.ModifierCount := 0
		; IOClassMappings controls which type each IOClass reports as.
		; ie we need the AHK_KBM_Input class to report as AHK_KBM_Output when we are binding an output key
		this.IOClassMappings := IOClassMappings
		this.SetHotkeyState(1)
	}
	
	; Bind Mode ended. Pass the BindObject and it's IOClass back to the GuiControl that requested the binding
	_BindModeEnded(callback, bo){
		OutputDebug % "UCR| UCR: Bind Mode Ended. Binding[1]: " bo.Binding[1] ", DeviceID: " bo.DeviceID ", IOClass: " this.SelectedBinding.IOClass
		callback.Call(bo)
	}
	
	; Turns on or off the hotkeys
	SetHotkeyState(state){
		global _AppFactoryBindMode
		_AppFactoryBindMode := state
		if (state){
			Gui, % this.hBindModePrompt ":Show"
			;UCR.MoveWindowToCenterOfGui(this.hBindModePrompt)
		} else {
			Gui, % this.hBindModePrompt ":Hide"
		}
		this._BindModeThread.SetDetectionState(state, this.IOClassMappings)
	}
	
	; The BindModeThread calls back here
	ProcessBindModeInput(e, i, deviceid, IOClass){
		;ToolTip % "e " e ", i " i ", deviceid " deviceid ", IOClass " IOClass
		;if (ObjHasKey(this._Modifiers, i))
		if (this.SelectedBinding.IOClass && (this.SelectedBinding.IOClass != IOClass)){
			; Changed binding IOCLass part way through.
			if (e){
				SoundBeep, 500, 100
			}
			return
		}
		max := this.SelectedBinding.Binding.length()
		if (e){
			for idx, code in  this.SelectedBinding.Binding {
				if (i == code)
					return	; filter repeats
			}
			this.SelectedBinding.Binding.push(i)
			this.SelectedBinding.DeviceID := DeviceID
			if (this.AHK_KBM_Input.IsModifier(i)){
				if (max > this.ModifierCount){
					; Modifier pressed after end key
					SoundBeep, 500, 100
					return
				}
				this.ModifierCount++
			} else if (max > this.ModifierCount) {
				; Second End Key pressed after first held
				SoundBeep, 500, 100
				return
			}
			this.SelectedBinding.IOClass := IOClass
		} else {
			this.BindMode := 0
			this.SetHotkeyState(0, this.IOClassMappings)
			;ret := {Binding:[i], DeviceID: deviceid, IOClass: this.IOClassMappings[IOClass]}
			
			;OutputDebug % "UCR| BindModeHandler: Bind Mode Ended. Binding[1]: " this.SelectedBinding.Binding[1] ", DeviceID: " this.SelectedBinding.DeviceID ", IOClass: " this.SelectedBinding.IOClass
			this._Callback.Call(this.SelectedBinding)
		}
	}

	; ====================================== INPUT THREAD ==============================================
	InitInputThread(){
		this.InputThread := new _InputThread(this.InputEvent.Bind(this))
	}
	
	InputEvent(ControlGUID, e){
		; Suppress repeats
		if (this.IOControls[ControlGuid].BindObject.BindOptions.Suppress && (this.IOControls[ControlGuid].State == e))
			return
		this.IOControls[ControlGuid].State := e
		; Fire the callback
		this.IOControls[ControlGuid].Callback.call(e)
	}
	
	; ====================================== MISC ==============================================
	; Describes a binding. Used internally and dumped to the INI file
	class _BindObject {
		IOClass := ""
		DeviceID := 0 		; Device ID, eg Stick ID for Joystick input or vGen output
		Binding := []		; Codes of the input(s) for the Binding. Is an indexed array once set
							; Normally a single element, but for KBM could be up to 4 modifiers plus a key/button
		BindOptions := {Block: 0, Wild: 0, Suppress: 0}
	}
}