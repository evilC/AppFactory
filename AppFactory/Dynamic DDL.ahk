/*
Demonstrates a Dynamic Drop-Down-List (DDL) GuiControl
End-Users can add / remove items to the DDL, and the current selection is remembered between runs
*/
#SingleInstance force
#NoEnv
#Include AppFactory.ahk
factory := new AppFactory()

Gui, Add, Text, xm w100 , Dynamic DDL
; Add array as a CustomSetting called DDDL_Contents to hold values in DDL
factory.AddCustomSetting("DDDL_Contents", [])
; Get current value of DDDL_Contents CustomSetting from AppFactory
arr := factory.CustomSettings.DDDL_Contents.Get()
; Convert array to | separated list
l := factory.BuildDdlListFromArray(arr)
; Create Dynamic DDL with options that were in the DDDL_Contents CustomSetting
factory.AddControl("DDDL", "DDL", "x+5 w200", l)
; Create Add / Remove buttons to add / remove items to the DDL
Gui, Add, Button, x+5 gRemove, Remove
Gui, Add, Button, xm w100 gAdd, Add
Gui, Add, Edit, x+5 vAddText w200
Gui, Show
return

Add:
	Gui, Submit, NoHide
	; Add Item to GuiControl
	factory.GuiControls.DDDL.AddItem(AddText)
	; Add item to DDDL_Contents CustomSetting
	value := factory.CustomSettings.DDDL_Contents.Get()
	value.Push(AddText)
	factory.CustomSettings.DDDL_Contents.SetValue(value)
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
	return

^Esc::
GuiClose:
	ExitApp
