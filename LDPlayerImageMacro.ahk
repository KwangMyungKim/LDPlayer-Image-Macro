#Requires AutoHotkey v2.0
#SingleInstance Force
FileEncoding "UTF-8"
SetTitleMatchMode 2
DllCall("SetThreadDpiAwarenessContext", "ptr", -2)

; ==============================================================================
; 설정 (Configuration)
; ==============================================================================
global ImageFolder := "Images"
global ConfigFile := A_ScriptDir . "\macro_data.txt"
global SettingsFile := A_ScriptDir . "\settings.ini"
global LocaleFile := A_ScriptDir . "\locales.ini"
global TargetWindowHwnd := 0 
global CurrentLang := "ko" 
global MinimizeOnStart := 0 
global LangData := Map()   

; 매크로 동작 순서 정의
global MacroScript := [
    {Type: "Image", Image: "sample_start.png", Desc: "Start", Delay: 2000, Tolerance: 50, Enabled: true, Timeout: 0, Next: "", FailNext: ""},
    {Type: "Coord", X: 500, Y: 300, Desc: "CloseAd", Delay: 1000, Enabled: true, Timeout: 0, Next: "", FailNext: ""},
    {Type: "Image", Image: "sample_reward.png", Desc: "GetReward", Delay: 1000, Tolerance: 50, Enabled: true, Timeout: 0, Next: "", FailNext: ""},
    {Type: "Image", Image: "sample_close.png", Desc: "Close", Delay: 500, Tolerance: 50, Enabled: true, Timeout: 0, Next: "", FailNext: ""}
]

LoadSettings()
LoadLocale()
LoadMacroData()

; ==============================================================================
; GUI 초기화
; ==============================================================================
MyGui := Gui(, T("Title"))
MyGui.SetFont("s10", "Segoe UI")

MyMenuBar := MenuBar()
LangMenu := Menu()
LangMenu.Add("한국어", (*) => ChangeLanguage("ko"))
LangMenu.Add("English", (*) => ChangeLanguage("en"))
if (CurrentLang == "ko")
    LangMenu.Check("한국어")
else
    LangMenu.Check("English")
MyMenuBar.Add(T("Menu_Language"), LangMenu)

SettingsMenu := Menu()
SettingsMenu.Add(T("Menu_Minimize"), ToggleMinimizeOption)
if (MinimizeOnStart)
    SettingsMenu.Check(T("Menu_Minimize"))
MyMenuBar.Add(T("Menu_Settings"), SettingsMenu)

MyGui.MenuBar := MyMenuBar

MyGui.Add("Text", "x10 y15", T("TargetWindow"))
WindowDDL := MyGui.Add("DropDownList", "x+10 yp-3 w250 vTargetWindow Choose1", [T("FindLDPlayer")])
BtnRefresh := MyGui.Add("Button", "x+5 yp w80 h26", T("Refresh"))
BtnRefresh.OnEvent("Click", RefreshWindowList)

GuiTab := MyGui.Add("Tab3", "x10 y50 w500 h450", [T("Tab_Macro"), T("Tab_Editor")])

GuiTab.UseTab(1)
BtnStart := MyGui.Add("Button", "x20 y90 w100 h40", T("Btn_Start"))
BtnStop := MyGui.Add("Button", "x+10 yp w100 h40 Disabled", T("Btn_Stop"))
LogEdit := MyGui.Add("Edit", "x20 y140 w480 h340 ReadOnly", T("Log_Ready") . "`r`n")

GuiTab.UseTab(2)
global ScriptListView := MyGui.Add("ListView", "x20 y90 w480 h300 +Checked", [T("List_Run"), T("List_Type"), T("List_Target"), T("List_Name"), T("List_Delay")])
ScriptListView.ModifyCol(1, "40 Center"), ScriptListView.ModifyCol(2, "60 Center"), ScriptListView.ModifyCol(3, "150"), ScriptListView.ModifyCol(4, "140"), ScriptListView.ModifyCol(5, "60 Center")
ScriptListView.OnEvent("ItemCheck", OnScriptItemCheck)

MyGui.Add("Button", "x20 y+15 w80 h30", T("Btn_Add")).OnEvent("Click", AddNewScript)
MyGui.Add("Button", "x+10 yp w80 h30", T("Btn_Modify")).OnEvent("Click", ModifyScript)
MyGui.Add("Button", "x+10 yp w80 h30", T("Btn_Delete")).OnEvent("Click", DeleteScript)
MyGui.Add("Button", "x+30 yp w80 h30", T("Btn_Up")).OnEvent("Click", MoveScriptUp)
MyGui.Add("Button", "x+10 yp w80 h30", T("Btn_Down")).OnEvent("Click", MoveScriptDown)


GuiTab.UseTab()

BtnStart.OnEvent("Click", StartMacro)
BtnStop.OnEvent("Click", StopMacro)

MyGui.OnEvent("Close", (*) => ExitApp())

RefreshWindowList()

MyGui.Show("w525 h550") 
PopulateScriptList()

global isRunning := false

F1::StartMacro(0)
F2::StopMacro(0)

; ==============================================================================
; 함수 정의
; ==============================================================================
LoadSettings() {
    global CurrentLang, MinimizeOnStart, SettingsFile
    try {
        CurrentLang := IniRead(SettingsFile, "General", "Language", "ko")
        MinimizeOnStart := IniRead(SettingsFile, "General", "MinimizeOnStart", 0)
    } catch {
        CurrentLang := "ko"
        MinimizeOnStart := 0
    }
}

SaveSettings() {
    global CurrentLang, MinimizeOnStart, SettingsFile
    try {
        IniWrite(CurrentLang, SettingsFile, "General", "Language")
        IniWrite(MinimizeOnStart, SettingsFile, "General", "MinimizeOnStart")
    }
}

ToggleMinimizeOption(*) {
    global MinimizeOnStart, SettingsMenu
    MinimizeOnStart := !MinimizeOnStart
    if (MinimizeOnStart)
        SettingsMenu.Check(T("Menu_Minimize"))
    else
        SettingsMenu.Uncheck(T("Menu_Minimize"))
    SaveSettings()
}

LoadLocale() {
    global LangData, CurrentLang, LocaleFile
    if !FileExist(LocaleFile)
        return

    try {
        content := FileRead(LocaleFile, "UTF-8")
        currentSection := ""
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line = "" || SubStr(line, 1, 1) = ";")
                continue
            if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]") {
                currentSection := SubStr(line, 2, -1)
                continue
            }
            if (currentSection = CurrentLang) {
                parts := StrSplit(line, "=", 2)
                if (parts.Length = 2)
                    LangData[Trim(parts[1])] := Trim(parts[2])
            }
        }
    }
}

T(key) {
    global LangData
    if LangData.Has(key)
        return LangData[key]
    return key
}

ChangeLanguage(newLang) {
    global CurrentLang
    if (CurrentLang != newLang) {
        CurrentLang := newLang
        SaveSettings()
        Reload()
    }
}

OnScriptItemCheck(LV, Item, Checked) {
    global MacroScript
    if (Item > 0 && Item <= MacroScript.Length) {
        MacroScript[Item].Enabled := Checked
        SaveMacroData()
    }
}

RefreshWindowList(*) {
    global WindowDDL, TargetWindowList, MyGui
    TargetWindowList := [] 
    WindowDDL.Delete()
    
    ids := WinGetList("LDPlayer")
    if (ids.Length = 0)
        ids := WinGetList("Android")

    for this_id in ids {
        if (this_id = MyGui.Hwnd)
            continue
        try {
            title := WinGetTitle(this_id)
            if (title != "") {
                WindowDDL.Add([title])
                TargetWindowList.Push(this_id)
            }
        }
    }
    
    if (TargetWindowList.Length > 0) {
        WindowDDL.Choose(1)
    } else {
        WindowDDL.Add([T("Cmb_NoLD")])
        WindowDDL.Choose(1)
    }
}

PopulateScriptList() {
    global MacroScript, ScriptListView
    ScriptListView.Delete() 
    For index, step in MacroScript {
        typeText := (step.Type = "Image") ? T("Type_Image") : ((step.Type = "Coord") ? T("Type_Coord") : T("Type_Error"))
        targetText := (step.Type = "Image") ? step.Image . " (*" . step.Tolerance . ")" : step.X . ", " . step.Y
        
        ScriptListView.Add(, "", typeText, targetText, step.Desc, step.Delay)
        
        if (!step.HasOwnProp("Enabled") || step.Enabled) {
            ScriptListView.Modify(index, "Check")
            step.Enabled := true 
        } else {
            ScriptListView.Modify(index, "-Check")
        }
    }
}

AddNewScript(*) {
    global MacroScript
    newData := ShowScriptEditDialog()
    if (IsObject(newData)) {
        MacroScript.Push(newData)
        PopulateScriptList()
        SaveMacroData()
    }
}

ModifyScript(*) {
    global MacroScript, ScriptListView
    focusedRow := ScriptListView.GetNext(0, "F")
    if (focusedRow = 0) {
        MsgBox T("Msg_SelectEdit")
        return
    }
    existingData := MacroScript[focusedRow]
    newData := ShowScriptEditDialog(existingData)
    if (IsObject(newData)) {
        MacroScript[focusedRow] := newData
        PopulateScriptList()
        ScriptListView.Modify(focusedRow, "Select Focus")
        SaveMacroData()
    }
}

ShowScriptEditDialog(p_data := "") {
    global MyGui, ImageFolder, TargetWindowHwnd, MacroScript

    isEditMode := IsObject(p_data)
    actionType := isEditMode ? p_data.Type : "Image"
    savedData := false 

    EditGui := Gui("+Owner" . MyGui.Hwnd . " +ToolWindow", isEditMode ? T("Dlg_ModTitle") : T("Dlg_AddTitle"))
    EditGui.SetFont("s10", "Segoe UI")

    EditGui.Add("Text", "x20 y20", T("Dlg_Type"))
    RadioImage := EditGui.Add("Radio", "x+10 yp vActionType Group", T("Dlg_Img"))
    RadioCoord := EditGui.Add("Radio", "x+10 yp", T("Dlg_Coord"))
    
    ; 이미지 그룹 (높이 140으로 증가)
    ImgGroup := EditGui.Add("GroupBox", "x15 y60 w370 h140", T("Dlg_GrpImg"))
    TxtFile := EditGui.Add("Text", "x25 y80 w40", T("Dlg_File"))
    ImgEdit := EditGui.Add("Edit", "x+5 yp w220 h22", isEditMode && actionType="Image" ? p_data.Image : "")
    BrowseBtn := EditGui.Add("Button", "x+5 yp w80 h24", T("Dlg_Browse"))
    TxtTol := EditGui.Add("Text", "x25 y+15", T("Dlg_Tol"))
    ToleranceEdit := EditGui.Add("Edit", "x+5 yp w80 h22", isEditMode && actionType="Image" && p_data.HasOwnProp("Tolerance") ? p_data.Tolerance : "50")
    UpDnTol := EditGui.Add("UpDown", "Range0-255", ToleranceEdit.Value)
    TxtTime := EditGui.Add("Text", "x25 y+15", T("Dlg_Timeout"))
    TimeoutEdit := EditGui.Add("Edit", "x+5 yp w80 h22", isEditMode && actionType="Image" && p_data.HasOwnProp("Timeout") ? p_data.Timeout : "0")

    ; 좌표 그룹 (이미지 그룹과 같은 위치)
    CoordGroup := EditGui.Add("GroupBox", "x15 y60 w370 h140", T("Dlg_GrpCoord"))
    TxtX := EditGui.Add("Text", "x25 y85", "X:")
    CoordXEdit := EditGui.Add("Edit", "x+5 yp w60 h22", isEditMode && actionType="Coord" ? p_data.X : "0")
    TxtY := EditGui.Add("Text", "x+10 yp", "Y:")
    CoordYEdit := EditGui.Add("Edit", "x+5 yp w60 h22", isEditMode && actionType="Coord" ? p_data.Y : "0")
    BtnPick := EditGui.Add("Button", "x+10 yp w100 h24", "좌표 찾기(F1)")

    ; 공통 입력 (위치 하향 조정 y220)
    EditGui.Add("Text", "x20 y220", T("Dlg_Desc"))
    DescEdit := EditGui.Add("Edit", "x+5 yp w300 h22", isEditMode ? p_data.Desc : "")
    
    EditGui.Add("Text", "x20 y+15", T("Dlg_Delay"))
    DelayEdit := EditGui.Add("Edit", "x+5 yp w80 h22", isEditMode ? p_data.Delay : "1000")
    EditGui.Add("UpDown", "Range0-600000", DelayEdit.Value)

    ; 이름 목록 생성
    NameList := [""] 
    For step in MacroScript {
        if (step.Desc != "")
            NameList.Push(step.Desc)
    }

    EditGui.Add("Text", "x20 y+15", T("Dlg_Next"))
    NextEdit := EditGui.Add("DropDownList", "x+5 yp w150 Choose1", NameList) ; 너비 증가
    if (isEditMode && p_data.HasOwnProp("Next") && p_data.Next != "") {
        try NextEdit.Text := p_data.Next
    }
    
    EditGui.Add("Text", "x20 y+15", T("Dlg_FailNext")) ; 줄바꿈
    FailNextEdit := EditGui.Add("DropDownList", "x+5 yp w150 Choose1", NameList) ; 너비 증가
    if (isEditMode && p_data.HasOwnProp("FailNext") && p_data.FailNext != "") {
        try FailNextEdit.Text := p_data.FailNext
    }

    OkBtn := EditGui.Add("Button", "x70 y+30 w120 h30 Default", T("Btn_Ok"))
    CancelBtn := EditGui.Add("Button", "x+10 yp w120 h30", T("Btn_Cancel"))
    
    ToggleControls := (*) => (
        ImgGroup.Visible := RadioImage.Value,
        TxtFile.Visible := RadioImage.Value,
        ImgEdit.Visible := RadioImage.Value,
        BrowseBtn.Visible := RadioImage.Value,
        TxtTol.Visible := RadioImage.Value,
        ToleranceEdit.Visible := RadioImage.Value,
        UpDnTol.Visible := RadioImage.Value,
        TxtTime.Visible := RadioImage.Value,
        TimeoutEdit.Visible := RadioImage.Value,
        
        CoordGroup.Visible := RadioCoord.Value,
        TxtX.Visible := RadioCoord.Value,
        CoordXEdit.Visible := RadioCoord.Value,
        TxtY.Visible := RadioCoord.Value,
        CoordYEdit.Visible := RadioCoord.Value,
        BtnPick.Visible := RadioCoord.Value
    )

    SelectImageFile(*) {
        SelectedFile := FileSelect("3", A_WorkingDir . "\" . ImageFolder, "이미지 선택", "Images (*.png; *.jpg; *.bmp)")
        if (SelectedFile) {
            SplitPath(SelectedFile, &OutFileName)
            ImgEdit.Value := OutFileName
        }
    }
    
    CaptureCoord(*) {
        Hotkey "F1", "Off"
        ToolTip()
        CoordMode "Mouse", "Screen"
        MouseGetPos(&mX, &mY)
        finalX := mX
        finalY := mY
        if (TargetWindowHwnd && WinExist(TargetWindowHwnd)) {
            WinGetClientPos(&wX, &wY,,, TargetWindowHwnd)
            finalX := mX - wX
            finalY := mY - wY
        }
        CoordXEdit.Value := finalX
        CoordYEdit.Value := finalY
        EditGui.Opt("-Disabled")
        WinActivate(EditGui)
    }

    PickCoord(*) {
        EditGui.Opt("+Disabled")
        ToolTip("원하는 위치에 마우스를 올리고 [F1] 키를 누르세요.")
        Hotkey "F1", CaptureCoord, "On"
    }
    
    OnOk(*) {
        if (DescEdit.Value = "") {
            MsgBox T("Msg_DescReq")
            return
        }
        
        delayVal := StrReplace(DelayEdit.Value, ",", "")
        nextVal := NextEdit.Text
        failNextVal := FailNextEdit.Text
        
        local data := {}
        if (RadioImage.Value) {
            if (ImgEdit.Value = "") {
                MsgBox T("Msg_ImgReq")
                return
            }
            tolVal := StrReplace(ToleranceEdit.Value, ",", "")
            timeVal := StrReplace(TimeoutEdit.Value, ",", "")
            
            if (!IsNumber(tolVal) or tolVal < 0 or tolVal > 255) {
                MsgBox T("Msg_TolReq")
                return
            }
            data := {Type: "Image", Image: ImgEdit.Value, Desc: DescEdit.Value, Delay: Round(delayVal), Tolerance: Round(tolVal), Timeout: Round(timeVal), Next: nextVal, FailNext: failNextVal}
        } else {
             xVal := StrReplace(CoordXEdit.Value, ",", "")
             yVal := StrReplace(CoordYEdit.Value, ",", "")
             if (!IsNumber(xVal) or !IsNumber(yVal)) {
                MsgBox T("Msg_CoordReq")
                return
            }
            data := {Type: "Coord", X: Round(xVal), Y: Round(yVal), Desc: DescEdit.Value, Delay: Round(delayVal), Timeout: 0, Next: nextVal, FailNext: failNextVal}
        }
        savedData := data
        EditGui.Destroy()
    }

    RadioImage.Value := (actionType = "Image")
    RadioCoord.Value := (actionType = "Coord") 

    RadioImage.OnEvent("Click", ToggleControls)
    RadioCoord.OnEvent("Click", ToggleControls)
    BrowseBtn.OnEvent("Click", SelectImageFile)
    BtnPick.OnEvent("Click", PickCoord)
    OkBtn.OnEvent("Click", OnOk)
    CancelBtn.OnEvent("Click", (*) => EditGui.Destroy())
    EditGui.OnEvent("Close", (*) => EditGui.Destroy())
    
    ToggleControls() 
    
    MyGui.Opt("+Disabled")
    EditGui.Show("w420 h550") ; 높이 증가
    WinWaitClose(EditGui)
    MyGui.Opt("-Disabled")
    WinActivate(MyGui)
    
    return savedData
}

DeleteScript(*) {
    global MacroScript, ScriptListView
    focusedRow := ScriptListView.GetNext(0, "F")
    if (focusedRow = 0) {
        MsgBox T("Msg_SelectDel")
        return
    }
    MacroScript.RemoveAt(focusedRow)
    PopulateScriptList()
    SaveMacroData()
}

MoveScriptUp(*) {
    global MacroScript, ScriptListView
    focusedRow := ScriptListView.GetNext(0, "F")
    if (focusedRow <= 1) { 
        return
    }
    item := MacroScript.RemoveAt(focusedRow)
    MacroScript.InsertAt(focusedRow - 1, item)
    PopulateScriptList()
    ScriptListView.Modify(focusedRow - 1, "Select Focus")
    SaveMacroData()
}

MoveScriptDown(*) {
    global MacroScript, ScriptListView
    focusedRow := ScriptListView.GetNext(0, "F")
    if (focusedRow = 0 or focusedRow = ScriptListView.GetCount()) { 
        return
    }
    item := MacroScript.RemoveAt(focusedRow)
    MacroScript.InsertAt(focusedRow + 1, item)
    PopulateScriptList()
    ScriptListView.Modify(focusedRow + 1, "Select Focus")
    SaveMacroData()
}

StartMacro(*) {
    global isRunning, TargetWindowHwnd, TargetWindowList, WindowDDL, MinimizeOnStart, CurrentStepIndex
    if (isRunning)
        return

    idx := WindowDDL.Value
    if (idx = 0 or !TargetWindowList.Has(idx) or idx > TargetWindowList.Length) {
        MsgBox T("Msg_SelectWindow")
        return
    }
    TargetWindowHwnd := TargetWindowList[idx]

    if !WinExist(TargetWindowHwnd) {
        AddLog(T("Msg_WindowNotFound"))
        RefreshWindowList()
        return
    }

    isRunning := true
    CurrentStepIndex := 1 ; 인덱스 초기화
    BtnStart.Enabled := false
    BtnStop.Enabled := true
    AddLog(T("Log_Start"))
    
    if (MinimizeOnStart)
        MyGui.Minimize()
    
    SetTimer(MacroLoopStep, 100) 
}

StopMacro(*) {
    global isRunning, MinimizeOnStart
    if (!isRunning)
        return

    isRunning := false
    BtnStart.Enabled := true
    BtnStop.Enabled := false
    SetTimer(MacroLoopStep, 0)
    AddLog(T("Log_Stop"))
    
    if (MinimizeOnStart)
        MyGui.Restore()
}

MacroLoopStep() {
    global isRunning, MacroScript, TargetWindowHwnd, CurrentStepIndex
    if (!isRunning)
        return

    if !WinExist(TargetWindowHwnd) {
        StopMacro(0)
        AddLog(T("Log_WindowGone"))
        return
    }
    
    if (CurrentStepIndex > MacroScript.Length) {
        CurrentStepIndex := 1
        return 
    }

    step := MacroScript[CurrentStepIndex]
    
    if (step.HasOwnProp("Enabled") && step.Enabled == false) {
        CurrentStepIndex++
        return 
    }

    actionResult := false
    CoordMode "Mouse", "Screen"

    if (step.Type = "Image") {
        imagePath := ImageFolder . "\" . step.Image
        if !FileExist(imagePath) {
            AddLog(T("Msg_ImageNotFound") . step.Image)
            actionResult := false 
        } else {
            tol := step.HasOwnProp("Tolerance") ? step.Tolerance : 50
            timeout := step.HasOwnProp("Timeout") ? step.Timeout : 0
            if (FindAndClick(imagePath, tol, timeout)) {
                AddLog(T("Log_FoundClick") . step.Desc)
                actionResult := true
            } else {
                actionResult := false
            }
        }
    } else if (step.Type = "Coord") {
        try {
            PostClick(step.X, step.Y, TargetWindowHwnd)
            AddLog(T("Log_CoordClick") . step.Desc)
            actionResult := true
        } catch {
            AddLog(T("Log_ClickFail"))
            actionResult := false
        }
    }

    nextName := ""
    if (actionResult) {
        if (step.HasOwnProp("Next") && step.Next != "")
            nextName := step.Next
    } else {
        if (step.HasOwnProp("FailNext") && step.FailNext != "")
            nextName := step.FailNext
    }
    
    if (nextName != "") {
        foundIndex := 0
        Loop MacroScript.Length {
            if (MacroScript[A_Index].Desc = nextName) {
                foundIndex := A_Index
                break
            }
        }
        
        if (foundIndex > 0) {
            CurrentStepIndex := foundIndex
        } else {
            AddLog(T("Log_JumpFail") . nextName)
            CurrentStepIndex++
        }
    } else {
        CurrentStepIndex++
    }
    
    if (actionResult)
        Sleep(step.Delay)
}

FindAndClick(imagePath, p_tolerance := 50, p_timeout := 0) {
    global TargetWindowHwnd
    CoordMode "Pixel", "Screen"
    
    StartTime := A_TickCount
    Loop {
        try {
            WinGetPos(&wX, &wY, &wW, &wH, TargetWindowHwnd)
            searchX1 := wX
            searchY1 := wY
            searchX2 := wX + wW
            searchY2 := wY + wH
            
            if ImageSearch(&FoundScreenX, &FoundScreenY, searchX1, searchY1, searchX2, searchY2, "*" . p_tolerance . " " . imagePath) {
                GetImageSize(imagePath, &imgW, &imgH)
                CenterScreenX := FoundScreenX + (imgW // 2)
                CenterScreenY := FoundScreenY + (imgH // 2)
                WinGetClientPos(&cX, &cY,,, TargetWindowHwnd)
                clientClickX := CenterScreenX - cX
                clientClickY := CenterScreenY - cY
                
                PostClick(clientClickX, clientClickY, TargetWindowHwnd)
                return true
            }
        } catch as err {
            AddLog(T("Log_Err") . err.Message)
            return false
        }
        
        if (p_timeout <= 0 || (A_TickCount - StartTime) > p_timeout * 1000)
            break
            
        Sleep(500) 
    }
    return false
}

PostClick(x, y, hwnd) {
    try {
        if WinActive(hwnd) {
            prevMode := A_CoordModeMouse
            CoordMode "Mouse", "Client"
            Click x, y
            CoordMode "Mouse", prevMode
        } else {
            ControlClick("x" . x . " y" . y, hwnd, , "Left", 1, "D NA Pos")
            Sleep(30)
            ControlClick("x" . x . " y" . y, hwnd, , "Left", 1, "U NA Pos")
        }
    } catch {
    }
}

GetImageSize(path, &w, &h) {
    try {
        tempGui := Gui()
        pic := tempGui.Add("Picture",, path)
        pic.GetPos(,, &w, &h)
        tempGui.Destroy()
    } catch {
        w := 0
        h := 0
    }
}

AddLog(text) {
    timestamp := FormatTime(, "HH:mm:ss")
    finalText := "[" . timestamp . "] " . text . "`r`n"
    try {
        LogEdit.Value .= finalText
        SendMessage(0x0115, 7, 0, LogEdit.Hwnd, MyGui.Hwnd)
    }
}

SaveMacroData() {
    global MacroScript, ConfigFile
    fileContent := ""
    For index, step in MacroScript {
        type := step.HasOwnProp("Type") ? step.Type : "Image"
        img := step.HasOwnProp("Image") ? step.Image : ""
        x := step.HasOwnProp("X") ? step.X : 0
        y := step.HasOwnProp("Y") ? step.Y : 0
        desc := step.HasOwnProp("Desc") ? step.Desc : ""
        delay := step.HasOwnProp("Delay") ? step.Delay : 0
        tolerance := step.HasOwnProp("Tolerance") ? step.Tolerance : 50
        enabled := (step.HasOwnProp("Enabled") && step.Enabled) ? 1 : 0
        timeout := step.HasOwnProp("Timeout") ? step.Timeout : 0
        next := step.HasOwnProp("Next") ? step.Next : ""
        failNext := step.HasOwnProp("FailNext") ? step.FailNext : ""
        
        line := type . "|" . img . "|" . x . "|" . y . "|" . desc . "|" . delay . "|" . tolerance . "|" . enabled . "|" . timeout . "|" . next . "|" . failNext
        fileContent .= line . "`n"
    }
    try {
        if FileExist(ConfigFile)
            FileDelete(ConfigFile)
        FileAppend(fileContent, ConfigFile, "UTF-8")
    } catch as err {
        MsgBox T("Msg_SaveFail") . err.Message
    }
}

LoadMacroData() {
    global MacroScript, ConfigFile
    if !FileExist(ConfigFile)
        return

    try {
        content := FileRead(ConfigFile, "UTF-8")
        newScript := []
        Loop Parse, content, "`n", "`r" {
            if (A_LoopField = "")
                continue
            parts := StrSplit(A_LoopField, "|")
            if (parts.Length < 6) 
                continue
            step := {}
            step.Type := Trim(parts[1])
            step.Image := parts[2]
            step.X := Integer(parts[3])
            step.Y := Integer(parts[4])
            step.Desc := parts[5]
            step.Delay := Integer(parts[6])
            if (parts.Length >= 7)
                step.Tolerance := Integer(parts[7])
            else
                step.Tolerance := 50
            if (parts.Length >= 8)
                step.Enabled := (Integer(parts[8]) == 1)
            else
                step.Enabled := true
            
            if (parts.Length >= 9)
                step.Timeout := Integer(parts[9])
            else
                step.Timeout := 0
                
            if (parts.Length >= 10)
                step.Next := parts[10]
            else
                step.Next := ""
                
            if (parts.Length >= 11)
                step.FailNext := parts[11]
            else
                step.FailNext := ""

            newScript.Push(step)
        }
        if (newScript.Length > 0) {
            MacroScript := newScript
        }
    } catch as err {
        MsgBox T("Msg_LoadFail") . err.Message
    }
}