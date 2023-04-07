#include %A_LineFile%\..\cJSON.ahk

Class AppFactory {
	_ThreadHeader := "`n#Persistent`n#NoTrayIcon`n#MaxHotkeysPerInterval 9999`n"
	_ThreadFooter := "`nautoexecute_done := 1`nreturn`n"
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
		; FileReplace(JSON.Dump(this.Settings, ,true), this._SettingsFile)
		FileReplace(JSON.Dump(this.Settings), this._SettingsFile) ; cJson
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
		State := 0			; The State of the input. Only really used for Repeat Suppress_Repeation
		
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
			Menu, % this.id, Add, % "Suppress_Repeat", % fn
			
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
			this.parent.InputThread.UpdateBinding(this.id, ObjShare(this.BindObject))
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
				; Suppress_Repeat Repeats
				this.BindObject.BindOptions.Suppress_Repeat := !this.BindObject.BindOptions.Suppress_Repeat
				this.SetMenuCheckState("Suppress_Repeat")
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
			; Menu, % this.id, Color, E4E4E4
			Menu, % this.id, Show, % cX+cW-(cH//2), % cY + (cH//2)  ; + cH
			; Menu, % this.id, Show, % cX+1, % cY + cH
		}
		
		; Builds a human-readable form of the BindObject
		BuildHumanReadable(){
			str := ""
			if (!this.BindObject.IOClass){
				str := "_"
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
		;~ FileRead, Script, % A_ScriptDir "\BindModeThread.ahk"
		;~ FileRead, Script, % A_LineFile "\..\BindModeThread.ahk"
Script=
(
#NoEnv

/*
Handles binding of the hotkeys for Bind Mode
Runs as a separate thread to the main application,
so that bind mode keys can be turned on and off quickly with Suspend
*/
/*
#Persistent
#NoTrayIcon
#MaxHotkeysPerInterval 9999
autoexecute_done := 1
*/
class _BindMapper {
	DetectionState := 0
	static IOClasses := {AHK_Common: 0, AHK_KBM_Input: 0, AHK_JoyBtn_Input: 0, AHK_JoyHat_Input: 0}
	__New(CallbackPtr){
		this.Callback := ObjShare(CallbackPtr)
		;this.Callback := CallbackPtr
		; Instantiate each of the IOClasses specified in the IOClasses array
		for name, state in this.IOClasses {
			; Instantiate an instance of a class that is a child class of this one. Thanks to HotkeyIt for this code!
			; Replace each 0 in the array with an instance of the relevant class
			call:=this.base[name]
			this.IOClasses[name] := new call(this.Callback)
			; debugging string
			if (i)
				names .= ", "
			names .= name
			i++
		}
		if (i){
			;OutputDebug `% "UCR| Bind Mode Thread loaded IOClasses: " names
		} else {
			OutputDebug `% "UCR| Bind Mode Thread WARNING! Loaded No IOClasses!"
		}
		Suspend, On
		global InterfaceSetDetectionState := ObjShare(this.SetDetectionState.Bind(this))
	}
	
	; A request was received from the main thread to set the Dection state
	SetDetectionState(state, IOClassMappingsPtr){
		if (state == this.DetectionState)
			return
		IOClassMappings := {}
		IOClassMappings := this.IndexedToAssoc(ObjShare(IOClassMappingsPtr))
		for name, ret in IOClassMappings {
			;OutputDebug `% "UCR| BindModeThread Starting watcher " name " with return type " ret
			this.IOClasses[name].SetDetectionState(state, ret)
		}
		this.DetectionState := state
	}
	
	; Converts an Indexed array of objects to an associative array
	; If you pass an associative array via ObjShare, you cannot enumerate it
	; So it is converted to an indexed array of objects, this converts it back.
	IndexedToAssoc(arr){
		ret := {}
		Loop `% arr.length(){
			obj := arr[A_Index], ret[obj.k] := obj.v
		}
		return ret
	}

	; ==================================================================================================================

	class AHK_Common {
		__New(callback){
			this.Callback := callback
		}
		
		SetDetectionState(state, ReturnIOClass){
			;OutputDebug `% "Turning Hotkeys " (state ? "On" : "Off")
			Suspend, `% (state ? "Off", "On")
		}
	}
	
	; ==================================================================================================================
	class AHK_KBM_Input {
		static IOClass := "AHK_KBM_Input"
		DebugMode := 2
		
		__New(callback){
			this.Callback := callback
			this.CreateHotkeys()
		}

		SetDetectionState(state, ReturnIOClass){
			;this.ReturnIOClass := ( state ? ReturnIOClass : 0)
			this.ReturnIOClass := ReturnIOClass

		}

		; Binds a key to every key on the keyboard and mouse
		; Passes VK codes to GetKeyName() to obtain names for all keys
		; List of VKs: https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx
		; Keys are stored in the settings file by VK number, not by name.
		; AHK returns non-standard names for some VKs, these are patched to Standard values
		; Numpad Enter appears to have no VK, it is synonymous with Enter (VK0xD). Seeing as VKs 0xE to 0xF are Undefined by MSDN, we use 0xE for Numpad Enter.
		CreateHotkeys(){
			static replacements := {33: "PgUp", 34: "PgDn", 35: "End", 36: "Home", 37: "Left", 38: "Up", 39: "Right", 40: "Down", 45: "Insert", 46: "Delete"}
			static pfx := "$*"
			static updown := [{e: 1, s: ""}, {e: 0, s: " up"}]
			; Cycle through all keys / mouse buttons
			Loop 256 {
				; Get the key name
				i := A_Index
				code := Format("{:x}", i)
				if (ObjHasKey(replacements, i)){
					n := replacements[i]
				} else {
					n := GetKeyName("vk" code)
				}
				if (n = "")
					continue
				; Down event, then Up event
				Loop 2 {
					blk := this.DebugMode = 2 || (this.DebugMode = 1 && i <= 2) ? "~" : ""
					fn := this.InputEvent.Bind(this, updown[A_Index].e, i)
					hotkey, `% pfx blk n updown[A_Index].s, `% fn, `% "On"
				}
			}
			i := 14, n := "NumpadEnter"	; Use 0xE for Nupad Enter
			Loop 2 {
				blk := this.DebugMode = 2 || (this.DebugMode = 1 && i <= 2) ? "~" : ""
				fn := this.InputEvent.Bind(this, updown[A_Index].e, i)
				hotkey, `% pfx blk n updown[A_Index].s, `% fn, `% "On"
			}
			/*
			; Cycle through all Joystick Buttons
			Loop 8 {
				j := A_Index
				Loop `% this.JoystickCaps[j].btns {
					btn := A_Index
					n := j "Joy" A_Index
					fn := this._JoystickButtonDown.Bind(this, 1, 2, btn, j)
					hotkey, `% pfx n, `% fn, `% "On"
				}
			}
			*/
			critical off
		}
		
		InputEvent(e, i){
			;tooltip `% "code: " i ", e: " e
			this.Callback.Call(e, i, 0, this.ReturnIOClass)
		}
	}
	
	; ==================================================================================================================
	class AHK_JoyBtn_Input {
		static IOClass := "AHK_JoyBtn_Input"
		DebugMode := 1
		JoystickCaps := []
		
		__New(callback){
			this.Callback := callback
			this.CreateHotkeys()
		}
		
		SetDetectionState(state, ReturnIOClass){
			;this.ReturnIOClass := ( state ? ReturnIOClass : 0)
			this.ReturnIOClass := ReturnIOClass
		}

		; Binds a key to every key on the keyboard and mouse
		; Passes VK codes to GetKeyName() to obtain names for all keys
		; List of VKs: https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx
		; Keys are stored in the settings file by VK number, not by name.
		; AHK returns non-standard names for some VKs, these are patched to Standard values
		; Numpad Enter appears to have no VK, it is synonymous with Enter (VK0xD). Seeing as VKs 0xE to 0xF are Undefined by MSDN, we use 0xE for Numpad Enter.
		CreateHotkeys(){
			static updown := [{e: 1, s: ""}, {e: 0, s: " up"}]
			this.GetJoystickCaps()
			Loop 8 {
				j := A_Index
				Loop `% this.JoystickCaps[j].btns {
					btn := A_Index
					n := j "Joy" A_Index
					fn := this.InputEvent.Bind(this, 1, btn, j)
					hotkey, `% n, `% fn, `% "On"
					fn := this.InputEvent.Bind(this, 0, btn, j)
					hotkey, `% n " up", `% fn, `% "On"
				}
			}
		}
		
		GetJoystickCaps(){
			Loop 8 {
				cap := {}
				cap.btns := GetKeyState(A_Index "JoyButtons")
				this.JoystickCaps.push(cap)
			}
		}
		
		InputEvent(e, i, deviceid){
			this.Callback.Call(e, i, deviceid, this.ReturnIOClass)
		}
	}

	; ==================================================================================================================
	class AHK_JoyHat_Input {
		static IOClass := "AHK_JoyHat_Input"
		DebugMode := 1
		HatStrings := {}
		
		__New(callback){
			this.Callback := callback
			Loop 8 {
				ji := GetKeyState(A_Index "JoyInfo")
				if (InStr(ji, "P")){
					this.HatStrings[A_Index "JoyPov"] := {DeviceID: A_Index, State: -1}
				}
			}
			this.HatWatcherFn := this.HatWatcher.Bind(this)
		}
		

		SetDetectionState(state, ReturnIOClass){
			;this.ReturnIOClass := ( state ? ReturnIOClass : 0)
			this.ReturnIOClass := ReturnIOClass
			fn := this.HatWatcherFn
			t := state ? 10 : "Off"
			SetTimer, `% fn, `% t
		}
		
		HatWatcher(){
			for bindstring, obj in this.HatStrings {
				state := GetKeyState(bindstring)
				if (obj.state == -1 && state != -1){
					; Press
					e := 1
				} else if (obj.state != -1 && state == -1){
					; Release
					e := 0
				} else {
					; No Change / Bad values
					continue
				}
				i := state == -1 ? -1 : (round(state / 9000) + 1)
				DeviceID := obj.DeviceID
				obj.state := state
				this.Callback.Call(e, i, deviceid, this.ReturnIOClass)
			}
		}
	}
}



  ObjShare(obj){
	static IDispatch,set:=VarSetCapacity(IDispatch, 16), init := NumPut(0x46000000000000c0, NumPut(0x20400, IDispatch, "int64"), "int64")
	if IsObject(obj)
		return  LresultFromObject(&IDispatch, 0, &obj)
	else if ObjectFromLresult(obj, &IDispatch, 0, getvar(com:=0))
		return MessageBox(NULL,A_ThisFunc ": LResult Object could not be created","Error",0)
	return ComObject(9,com,1)
}
)
		this.__BindModeThread := AhkThread(this._ThreadHeader "`nBindMapper := new _BindMapper(" ObjShare(this.ProcessBindModeInput.Bind(this)) ")`n" this._ThreadFooter Script)
		While !this.__BindModeThread.ahkgetvar.autoexecute_done
			Sleep 50 ; wait until variable has been set.
		
		; Create object to hold thread-safe boundfunc calls to the thread
		this._BindModeThread := {}
		this._BindModeThread.SetDetectionState := ObjShare(this.__BindModeThread.ahkgetvar("InterfaceSetDetectionState"))
		
		Gui, +HwndhOld
		Gui, new, +HwndHwnd
		Gui +ToolWindow -Border -SysMenu +AlwaysOnTop
		Gui, Font, S16 cWhite
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
		;OutputDebug % "UCR| UCR: Bind Mode Ended. Binding[1]: " bo.Binding[1] ", DeviceID: " bo.DeviceID ", IOClass: " this.SelectedBinding.IOClass
		callback.Call(bo)
	}
	
	; Turns on or off the hotkeys
	SetHotkeyState(state){
		if (state){
			Gui, % this.hBindModePrompt ":Show"
			;UCR.MoveWindowToCenterOfGui(this.hBindModePrompt)
		} else {
			Gui, % this.hBindModePrompt ":Hide"
		}
		; Convert associative array to indexed, as ObjShare breaks associative array enumeration
		IOClassMappings := this.AssocToIndexed(this.IOClassMappings)
		this._BindModeThread.SetDetectionState(state, ObjShare(IOClassMappings))
	}
	
	; Converts an associative array to an indexed array of objects
	; If you pass an associative array via ObjShare, you cannot enumerate it
	; So each base key/value pair is added to an indexed array
	; And the thread can re-build the associative array on the other end.
	AssocToIndexed(arr){
		ret := []
		for k, v in arr {
			ret.push({k: k, v: v})
		}
		return ret
	}
	
	; The BindModeThread calls back here
	ProcessBindModeInput(e, i, deviceid, IOClass){
		;ToolTip % "e " e ", i " i ", deviceid " deviceid ", IOClass " IOClass
		;if (ObjHasKey(this._Modifiers, i))
		if (i=1)
		return
		if (this.SelectedBinding.IOClass && (this.SelectedBinding.IOClass != IOClass)){
			; Changed binding IOCLass part way through.
			if (e){
				SoundGet, MasterVolume
    			SoundSet, 30
				SoundBeep, 500, 100
    			SoundSet, MasterVolume
				
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
				SoundGet, MasterVolume
    			SoundSet, 30
				SoundBeep, 500, 100
    			SoundSet, MasterVolume
					return
				}
				this.ModifierCount++
			} else if (max > this.ModifierCount) {
				; Second End Key pressed after first held
				SoundGet, MasterVolume
    			SoundSet, 30
				SoundBeep, 500, 100
    			SoundSet, MasterVolume
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
	; An additional thread that is always running and handles detection of input while in Normal Mode
	; This is done in an additional thread so that fixes to joystick input (Buttons and Hats) do not have to have loops in the main thread
	InitInputThread(){
		;~ FileRead, Script, % A_ScriptDir "\InputThread.ahk"
		;~ FileRead, Script, % A_LineFile "\..\InputThread.ahk"
		Script =
(


Class _InputThread {
	static IOClasses := {AHK_KBM_Input: 0, AHK_JoyBtn_Input: 0, AHK_JoyHat_Input: 0}
	DetectionState := 0
	UpdateBindingQueue := []	; An array of bindings waiting to be updated.
	UpdatingBindings := 0
	ControlMappings := {}
	
	__New(ProfileID, CallbackPtr){
		this.Callback := ObjShare(CallbackPtr)
		;this.Callback := CallbackPtr
		this.ProfileID := ProfileID ; Profile ID of parent profile. So we know which profile this thread serves
		names := ""
		i := 0
		; Instantiate each of the IOClasses specified in the IOClasses array
		for name, state in this.IOClasses {
			; Instantiate an instance of a class that is a child class of this one. Thanks to HotkeyIt for this code!
			; Replace each 0 in the array with an instance of the relevant class
			call:=this.base[name]
			this.IOClasses[name] := new call(this.Callback)
			; debugging string
			if (i)
				names .= ", "
			names .= name
			i++
		}
		if (i){
			; OutputDebug `% "UCR| Input Thread loaded IOClasses: " names
		} else {
			OutputDebug `% "UCR| Input Thread WARNING! Loaded No IOClasses!"
		}
		
		; Set up interfaces that the main thread can call
		global InterfaceUpdateBinding := ObjShare(this.UpdateBinding.Bind(this))
		;global InterfaceUpdateBindings := ObjShare(this.UpdateBindings.Bind(this))
		global InterfaceSetDetectionState := ObjShare(this.SetDetectionState.Bind(this))
		
		; Get a boundfunc for the method that processes binding updates
		;this.BindingQueueFn := this._ProcessBindingQueue.Bind(this)
		
		; Unreachable dummy label for hotkeys to bind to to clear binding
		if(0){
			UCR_INPUTHREAD_DUMMY_LABEL:
				return
		}

	}

	UpdateBinding(ControlGUID, boPtr){
		; msgbox, `% boPtr
		bo := ObjShare(boPtr).clone()
		iom := this.ControlMappings[ControlGuid]
		if (this.ControlMappings.HasKey(ControlGuid) && iom != bo.IOClass){
			this.IOClasses[iom].RemoveBinding(ControlGUID)
		}
		this.ControlMappings[ControlGuid] := bo.IOClass
		;OutputDebug `% "UCR| Updating binding for ControlGUID " ControlGUID ", IOClass " bo.IOClass
		; Direct the request to the appropriate IOClass that handles it
		try
		this.IOClasses[bo.IOClass].UpdateBinding(ControlGUID, bo)
		Catch, e
		{
			loop, `% bo.Binding.MaxIndex()
			bo.Binding[A_Index]:=""
			this._BindModeEnded(callback, bo)
		Gui +OwnDialogs
		MsgBox 0x40030, Not a Valid hotkey,`% "+ + .... This is not a Valid Hotkey" 
		}
	}
	
	;~ _SetDetectionState(state){
	SetDetectionState(state){
		OutputDebug `% "UCR| InputThread: Hotkey detection " (state ? "On" : "Off")
		if (state == this.DetectionState)
			return
		this.DetectionState := state
		for name, cls in this.IOClasses {
			cls.SetDetectionState(state)
		}
	}
	
	; Listens for Keyboard and Mouse input using the AHK Hotkey command
	class AHK_KBM_Input {
		DetectionState := 0
		_AHKBindings := {}
		
		__New(callback){
			this.callback := callback
			Suspend, On	; Start with detection off, even if we are passed bindings
		}
		
		UpdateBinding(ControlGUID, bo){
			this.RemoveBinding(ControlGUID)
			if (bo.Binding[1]){
				keyname := "$" this.BuildHotkeyString(bo)
				fn := this.KeyEvent.Bind(this, ControlGUID, 1)
				hotkey, `% keyname, `% fn, On
				fn := this.KeyEvent.Bind(this, ControlGUID, 0)
				hotkey, `% keyname " up", `% fn, On
				;OutputDebug `% "UCR| AHK_KBM_Input Added hotkey " keyname " for ControlGUID " ControlGUID
				this._AHKBindings[ControlGUID] := keyname
			}
		}
		
		SetDetectionState(state){
			; Are we already in the requested state?
			; This code is rigged so that either AHK_KBM_Input or AHK_JoyBtn_Input or both will not clash...
			; ... As long as all are turned on or off together, you won't get weird results.
			if (A_IsSuspended == state){
				;OutputDebug `% "UCR| Thread: AHK_KBM_Input IOClass turning Hotkey detection " (state ? "On" : "Off")
				Suspend, `% (state ? "Off" : "On")
			}
			this.DetectionState := state
		}
		
		RemoveBinding(ControlGUID){
			keyname := this._AHKBindings[ControlGUID]
			if (keyname){
				;OutputDebug `% "UCR| AHK_KBM_Input Removing hotkey " keyname " for ControlGUID " ControlGUID
				hotkey, `% keyname, UCR_INPUTHREAD_DUMMY_LABEL
				hotkey, `% keyname, Off
				hotkey, `% keyname " up", UCR_INPUTHREAD_DUMMY_LABEL
				hotkey, `% keyname " up", Off
				this._AHKBindings.Delete(ControlGUID)
			}
		}
		
		KeyEvent(ControlGUID, e){
			;OutputDebug `% "UCR| AHK_KBM_Input Key event for GuiControl " ControlGUID
			fn := this.InputEvent.Bind(this, ControlGUID, e)
			SetTimer, `% fn, -0
		}
		
		InputEvent(ControlGUID, state){
			this.Callback.Call(ControlGUID, state)
		}

		; Builds an AHK hotkey string (eg ~^a) from a BindObject
		BuildHotkeyString(bo){
			if (!bo.Binding.Length())
				return ""
			str := ""
			if (bo.BindOptions.Wild)
				str .= "*"
			if (!bo.BindOptions.Block)
				str .= "~"
			max := bo.Binding.Length()
			Loop `% max {
				key := bo.Binding[A_Index]
				if (A_Index = max){
					islast := 1
					nextkey := 0
				} else {
					islast := 0
					nextkey := bo[A_Index+1]
				}
				if (this.IsModifier(key) && (max > A_Index)){
					str .= this.RenderModifier(key)
				} else {
					str .= this.BuildKeyName(key)
				}
			}
			return str
		}
		
		; === COMMON WITH IOCLASS. MOVE TO INCLUDE =====
		static _Modifiers := ({91: {s: "#", v: "<"},92: {s: "#", v: ">"}
		,160: {s: "+", v: "<"},161: {s: "+", v: ">"}
		,162: {s: "^", v: "<"},163: {s: "^", v: ">"}
		,164: {s: "!", v: "<"},165: {s: "!", v: ">"}})

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
		; ================= END MOVE TO INCLUDE ======================
	}
	
	; Listens for Joystick Button input using AHK's Hotkey command
	; Joystick button Hotkeys in AHK immediately fire the up event after the down event...
	; ... so up events are emulated up using AHK's GetKeyState() function
	class AHK_JoyBtn_Input {
		HeldButtons := {}
		TimerWanted := 0		; Whether or not we WANT to run the ButtonTimer (NOT if it is actually running!)
		TimerRunning := 0
		DetectionState := 0		; Whether or not we are allowed to have hotkeys or be running the timer
		
		__New(Callback){
			this.Callback := Callback
			this.TimerFn := this.ButtonWatcher.Bind(this)
			Suspend, On	; Start with detection off, even if we are passed bindings
		}
		
		UpdateBinding(ControlGUID, bo){
			this.RemoveBinding(ControlGUID)
			if (bo.Binding[1]){
				keyname := this.BuildHotkeyString(bo)
				fn := this.KeyEvent.Bind(this, ControlGUID, 1)
				if (GetKeyState(bo.DeviceID "JoyAxes")) 
					try {
						hotkey, `% keyname, `% fn, On
					}
				else
					OutputDebug `% "UCR| Warning! AHK_JoyBtn_Input did not declare hotkey " keyname " because the stick is disconnected"
				;OutputDebug `% "UCR| AHK_JoyBtn_Input Added hotkey " keyname " for ControlGUID " ControlGUID
				this._AHKBindings[ControlGUID] := keyname
			}
		}
		
		SetDetectionState(state){
			; Are we already in the requested state?
			if (A_IsSuspended == state){
				;OutputDebug `% "UCR| Thread: AHK_JoyBtn_Input IOClass turning Hotkey detection " (state ? "On" : "Off")
				Suspend, `% (state ? "Off" : "On")
			}
			this.DetectionState := state
			this.ProcessTimerState()
		}
		
		RemoveBinding(ControlGUID){
			keyname := this._AHKBindings[ControlGUID]
			if (keyname){
				;OutputDebug `% "UCR| AHK_JoyBtn_Input Removing hotkey " keyname " for ControlGUID " ControlGUID
				try{
					hotkey, `% keyname, UCR_INPUTHREAD_DUMMY_LABEL
				}
				try{
					hotkey, `% keyname, Off
				}
				this._AHKBindings.Delete(ControlGUID)
			}
			;this._CurrentBinding := 0
		}
		
		KeyEvent(ControlGUID, e){
			; ToDo: Parent will not exist in thread!
			
			;OutputDebug `% "UCR| AHK_JoyBtn_Input Key event " e " for GuiControl " ControlGUID
			;this.Callback.Call(ControlGUID, e)
			fn := this.InputEvent.Bind(this, ControlGUID, e)
			SetTimer, `% fn, -0
			
			this.HeldButtons[this._AHKBindings[ControlGUID]] := ControlGUID
			if (!this.TimerWanted){
				this.TimerWanted := 1
				this.ProcessTimerState()
			}
		}
		
		InputEvent(ControlGUID, state){
			this.Callback.Call(ControlGUID, state)
		}

		ButtonWatcher(){
			for bindstring, ControlGUID in this.HeldButtons {
				if (!GetKeyState(bindstring)){
					this.HeldButtons.Delete(bindstring)
					;OutputDebug `% "UCR| AHK_JoyBtn_Input Key event 0 for GuiControl " ControlGUID
					;this.Callback.Call(ControlGUID, 0)
					fn := this.InputEvent.Bind(this, ControlGUID, 0)
					SetTimer, `% fn, -0
					if (IsEmptyAssoc(this.HeldButtons)){
						this.TimerWanted := 0
						this.ProcessTimerState()
						return
					}
				}
			}
		}
		
		ProcessTimerState(){
			fn := this.TimerFn
			if (this.TimerWanted && this.DetectionState && !this.TimerRunning){
				SetTimer, `% fn, 10
				this.TimerRunning := 1
				;OutputDebug `% "UCR| AHK_JoyBtn_Input Started ButtonWatcher " ControlGUID
			} else if ((!this.TimerWanted || !this.DetectionState) && this.TimerRunning){
				SetTimer, `% fn, Off
				this.TimerRunning := 0
				;OutputDebug `% "UCR| AHK_JoyBtn_Input Stopped ButtonWatcher " ControlGUID
			}
		}

		BuildHotkeyString(bo){
			return bo.Deviceid "Joy" bo.Binding[1]
		}
	}

	; Listens for Joystick Hat input using AHK's GetKeyState() function
	class AHK_JoyHat_Input {
		; Indexed by GetKeyState string (eg "1JoyPOV")
		; The HatWatcher timer is active while this array has items.
		; Contains an array of objects whose keys are the GUIDs of GuiControls mapped to that POV
		; Properties of those keys are the direction of the mapping and the state of the binding
		HatBindings := {}
		
		; GUID-Indexed array of sticks + directions that each GUIControl is mapped to, plus it's current state
		ControlMappings := {}
		
		; Which cardinal directions are pressed for each of the 8 compass directions, plus centre
		; Order is U, R, D, L
		static PovMap := {-1: [0,0,0,0], 1: [1,0,0,0], 2: [1,1,0,0] , 3: [0,1,0,0], 4: [0,1,1,0], 5: [0,0,1,0], 6: [0,0,1,1], 7: [0,0,0,1], 8: [1,0,0,1]}
		
		TimerRunning := 0
		TimerWanted := 0
		ConnectedSticks := [0,0,0,0,0,0,0,0]
		
		__New(Callback){
			this.Callback := Callback
			
			this.TimerFn := this.HatWatcher.Bind(this)
		}
		
		; Request from main thread to update binding
		UpdateBinding(ControlGUID, bo){
			;OutputDebug `% "UCR| AHK_JoyHat_Input " (bo.Binding[1] ? "Update" : "Remove" ) " Hat Binding - Device: " bo.DeviceID ", Direction: " bo.Binding[1]
			this._UpdateArrays(ControlGUID, bo)
			this.TimerWanted := !IsEmptyAssoc(this.ControlMappings)
			this.ProcessTimerState()
		}
		
		SetDetectionState(state){
			this.DetectionState := state
			this.ProcessTimerState()
		}
		
		ProcessTimerState(){
			fn := this.TimerFn
			if (this.TimerWanted && this.DetectionState && !this.TimerRunning){
				; Pre-cache connected sticks, as polling disconnected sticks takes lots of CPU
				Loop 8 {
					this.ConnectedSticks[A_Index] := GetKeyState(A_Index "JoyInfo")
				}
				SetTimer, `% fn, 10
				this.TimerRunning := 1
				;OutputDebug `% "UCR| AHK_JoyHat_Input Started HatWatcher"
			} else if ((!this.TimerWanted || !this.DetectionState) && this.TimerRunning){
				SetTimer, `% fn, Off
				this.TimerRunning := 0
				;OutputDebug `% "UCR| AHK_JoyHat_Input Stopped HatWatcher"
			}
		}

		; Updates the arrays which drive hat detection
		_UpdateArrays(ControlGUID, bo := 0){
			if (ObjHasKey(this.ControlMappings, ControlGUID)){
				; GuiControl already has binding
				bindstring := this.ControlMappings[ControlGUID].bindstring
				this.HatBindings[bindstring].Delete(ControlGUID)
				this.ControlMappings.Delete(ControlGUID)
				if (IsEmptyAssoc(this.HatBindings[bindstring])){
					this.HatBindings.Delete(bindstring)
					;OutputDebug `% "UCR| AHK_JoyHat_Input Removing Hat Bindstring " bindstring
				}
			}
			if (bo != 0 && bo.Binding[1]){
				; there is a new binding
				bindstring := bo.DeviceID "JoyPOV"
				if (!ObjHasKey(this.HatBindings, bindstring)){
					this.HatBindings[bindstring] := {}
					;OutputDebug `% "UCR| AHK_JoyHat_Input Adding Hat Bindstring " bindstring
				}
				this.HatBindings[bindstring, ControlGUID] := {dir: bo.Binding[1], state: 0}
				this.ControlMappings[ControlGUID] := {bindstring: bindstring}
			}
		}
		
		; Called on a timer when we are trying to detect hats
		HatWatcher(){
			for bindstring, bindings in this.HatBindings {
				if (!this.ConnectedSticks[SubStr(bindstring, 1, 1)]){
					; Do not poll unconnected sticks, it consumes a lot of cpu
					continue
				}
				state := GetKeyState(bindstring)
				state := (state = -1 ? -1 : round(state / 4500) + 1)
				for ControlGUID, obj in bindings {
					new_state := (this.PovMap[state, obj.dir] == 1)
					if (obj.state != new_state){
						obj.state := new_state
						;OutputDebug `% "UCR| InputThread: AHK_JoyHat_Input Direction " obj.dir " state " new_state " calling ControlGUID " ControlGUID
						; Use the thread-safe object to tell the main thread that the hat direction changed state
						;this.Callback.Call(ControlGUID, new_state)
						fn := this.InputEvent.Bind(this, ControlGUID, new_state)
						SetTimer, `% fn, -0
					}
				}
			}
		}
		
		InputEvent(ControlGUID, state){
			this.Callback.Call(ControlGUID, state)
		}
	}	
}

; Is an associative array empty?
IsEmptyAssoc(assoc){
	return !assoc._NewEnum()[k, v]
}

  ObjShare(obj){
	static IDispatch,set:=VarSetCapacity(IDispatch, 16), init := NumPut(0x46000000000000c0, NumPut(0x20400, IDispatch, "int64"), "int64")
	if IsObject(obj)
		return  LresultFromObject(&IDispatch, 0, &obj)
	else if ObjectFromLresult(obj, &IDispatch, 0, getvar(com:=0))
		return MessageBox(NULL,A_ThisFunc ": LResult Object could not be created","Error",0)
	return ComObject(9,com,1)
}
)
		
		; Cache script for profile InputThreads
		this._InputThreadScript := this._ThreadFooter Script 
		this._StartInputThread()
	}
	
	; Starts the "Input Thread" which handles detection of input
	_StartInputThread(){
		if (this.InputThread == 0){
			this.id := 1
			this._InputThread := AhkThread(this._ThreadHeader "`nInputThread := new _InputThread(""" this.id """," ObjShare(this.InputEvent.Bind(this)) ")`n" this._InputThreadScript)

			While !this._InputThread.ahkgetvar.autoexecute_done
				Sleep 10 ; wait until variable has been set.
			OutputDebug % "UCR| Input Thread started"

			; Get thread-safe boundfunc object for thread's SetHotkeyState
			this.InputThread := {}
			this.InputThread.UpdateBinding := ObjShare(this._InputThread.ahkgetvar("InterfaceUpdateBinding"))
			;this.InputThread.UpdateBindings := ObjShare(this._InputThread.ahkgetvar("InterfaceUpdateBindings"))
			this.InputThread.SetDetectionState := ObjShare(this._InputThread.ahkgetvar("InterfaceSetDetectionState"))
		}
	}
	
	InputEvent(ControlGUID, e){
		; Suppress_Repeat repeats
		if (this.IOControls[ControlGuid].BindObject.BindOptions.Suppress_Repeat && (this.IOControls[ControlGuid].State == e))
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
		BindOptions := {Block: 1, Wild: 0, Suppress_Repeat: 0}
	}
}

