#Requires AutoHotkey v2.0
#SingleInstance Force
FileEncoding "UTF-8" ; 기본 파일 인코딩을 UTF-8로 설정
SetTitleMatchMode 2 ; 윈도우 제목 부분 일치 허용
DllCall("SetThreadDpiAwarenessContext", "ptr", -2) ; DPI 인식 (좌표 오차 방지)

; ==============================================================================
; 설정 (Configuration)
; ==============================================================================
global ImageFolder := "Images"
global ConfigFile := A_ScriptDir . "\macro_data.txt" ; 데이터 저장 파일
global SettingsFile := A_ScriptDir . "\settings.ini" ; 프로그램 설정 파일
global LocaleFile := A_ScriptDir . "\locales.ini" ; 언어 파일
global TargetWindowHwnd := 0 ; 선택된 대상 윈도우 핸들
global CurrentLang := "ko" ; 기본 언어
global LangData := Map()   ; 번역 데이터 저장소

; 매크로 동작 순서 정의 (Script Definition)
global MacroScript := [
    {Type: "Image", Image: "sample_start.png", Desc: "시작 버튼", Delay: 2000, Tolerance: 50, Enabled: true},
    {Type: "Coord", X: 500, Y: 300, Desc: "중앙 광고 닫기", Delay: 1000, Enabled: true},
    {Type: "Image", Image: "sample_reward.png", Desc: "보상 받기", Delay: 1000, Tolerance: 50, Enabled: true},
    {Type: "Image", Image: "sample_close.png", Desc: "닫기 버튼", Delay: 500, Tolerance: 50, Enabled: true}
]

; 초기화
LoadSettings() ; 언어 설정 로드
LoadLocale()   ; 번역 데이터 로드
LoadMacroData() ; 매크로 데이터 로드

; ==============================================================================
; GUI 초기화 (GUI Initialization)
; ==============================================================================
MyGui := Gui(, T("Title"))
MyGui.SetFont("s10", "Segoe UI")

; --- 메뉴바 (언어 설정) ---
MyMenuBar := MenuBar()
LangMenu := Menu()
LangMenu.Add("한국어", (*) => ChangeLanguage("ko"))
LangMenu.Add("English", (*) => ChangeLanguage("en"))
if (CurrentLang == "ko")
    LangMenu.Check("한국어")
else
    LangMenu.Check("English")
MyMenuBar.Add(T("Menu_Language"), LangMenu)
MyGui.MenuBar := MyMenuBar

; --- 윈도우 선택 영역 ---
MyGui.Add("Text", "x10 y15", T("TargetWindow"))
WindowDDL := MyGui.Add("DropDownList", "x+10 yp-3 w250 vTargetWindow Choose1", [T("FindLDPlayer")])
BtnRefresh := MyGui.Add("Button", "x+5 yp w80 h26", T("Refresh"))
BtnRefresh.OnEvent("Click", RefreshWindowList)

; 탭 컨트롤 추가
GuiTab := MyGui.Add("Tab3", "x10 y50 w500 h450", [T("Tab_Macro"), T("Tab_Editor")])

; --- 매크로 탭 ---
GuiTab.UseTab(1)
BtnStart := MyGui.Add("Button", "x20 y90 w100 h40", T("Btn_Start"))
BtnStop := MyGui.Add("Button", "x+10 yp w100 h40 Disabled", T("Btn_Stop"))
LogEdit := MyGui.Add("Edit", "x20 y140 w480 h340 ReadOnly", T("Log_Ready") . "`r`n")

; --- 스크립트 편집 탭 ---
GuiTab.UseTab(2)
global ScriptListView := MyGui.Add("ListView", "x20 y90 w480 h300 +Checked", [T("List_Run"), T("List_Type"), T("List_Target"), T("List_Desc"), T("List_Delay")])
ScriptListView.ModifyCol(1, "40 Center"), ScriptListView.ModifyCol(2, "60 Center"), ScriptListView.ModifyCol(3, "150"), ScriptListView.ModifyCol(4, "140"), ScriptListView.ModifyCol(5, "60 Center")
ScriptListView.OnEvent("ItemCheck", OnScriptItemCheck)

MyGui.Add("Button", "x20 y+15 w80 h30", T("Btn_Add")).OnEvent("Click", AddNewScript)
MyGui.Add("Button", "x+10 yp w80 h30", T("Btn_Modify")).OnEvent("Click", ModifyScript)
MyGui.Add("Button", "x+10 yp w80 h30", T("Btn_Delete")).OnEvent("Click", DeleteScript)
MyGui.Add("Button", "x+30 yp w80 h30", T("Btn_Up")).OnEvent("Click", MoveScriptUp)
MyGui.Add("Button", "x+10 yp w80 h30", T("Btn_Down")).OnEvent("Click", MoveScriptDown)


GuiTab.UseTab() ; 탭 선택 해제

BtnStart.OnEvent("Click", StartMacro)
BtnStop.OnEvent("Click", StopMacro)

; 윈도우 닫기 이벤트
MyGui.OnEvent("Close", (*) => ExitApp())

; 초기 윈도우 목록 로드
RefreshWindowList()

MyGui.Show("w525 h520")
PopulateScriptList() ; 저장된 스크립트 목록 표시

; 전역 변수
global isRunning := false

; 단축키 설정
F1::StartMacro(0)
F2::StopMacro(0)

; ==============================================================================
; 언어 및 설정 관련 함수 (Language & Settings)
; ==============================================================================
LoadSettings() {
    global CurrentLang, SettingsFile
    try {
        CurrentLang := IniRead(SettingsFile, "General", "Language", "ko")
    } catch {
        CurrentLang := "ko"
    }
}

SaveSettings() {
    global CurrentLang, SettingsFile
    try {
        IniWrite(CurrentLang, SettingsFile, "General", "Language")
    }
}

LoadLocale() {
    global LangData, CurrentLang, LocaleFile
    if !FileExist(LocaleFile)
        return

    try {
        ; 인코딩 문제 방지를 위해 FileRead로 UTF-8 강제 지정
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
                if (parts.Length = 2) {
                    LangData[Trim(parts[1])] := Trim(parts[2])
                }
            }
        }
    }
}

T(key) {
    global LangData
    if LangData.Has(key)
        return LangData[key]
    return key ; 번역 없으면 키값 반환
}

ChangeLanguage(newLang) {
    global CurrentLang
    if (CurrentLang != newLang) {
        CurrentLang := newLang
        SaveSettings()
        Reload() ; 언어 변경 적용을 위해 재시작
    }
}

; ==============================================================================
; 이벤트 핸들러 및 기타
; ==============================================================================
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
        if (this_id = MyGui.Hwnd) ; 자기 자신은 제외
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
    global MyGui, ImageFolder, TargetWindowHwnd

    isEditMode := IsObject(p_data)
    actionType := isEditMode ? p_data.Type : "Image"
    savedData := false 

    EditGui := Gui("+Owner" . MyGui.Hwnd . " +ToolWindow", isEditMode ? T("Dlg_ModTitle") : T("Dlg_AddTitle"))
    EditGui.SetFont("s10", "Segoe UI")

    EditGui.Add("Text", "x20 y20", T("Dlg_Type"))
    RadioImage := EditGui.Add("Radio", "x+10 yp vActionType Group", T("Dlg_Img"))
    RadioCoord := EditGui.Add("Radio", "x+10 yp", T("Dlg_Coord"))
    
    ImgGroup := EditGui.Add("GroupBox", "x15 y60 w365 h95", T("Dlg_GrpImg"))
    TxtFile := EditGui.Add("Text", "x25 y80", T("Dlg_File"))
    ImgEdit := EditGui.Add("Edit", "x+5 yp w200 h22", isEditMode && actionType="Image" ? p_data.Image : "")
    BrowseBtn := EditGui.Add("Button", "x+5 yp w80 h24", T("Dlg_Browse"))
    TxtTol := EditGui.Add("Text", "x25 y+15", T("Dlg_Tol"))
    ToleranceEdit := EditGui.Add("Edit", "x+5 yp w80 h22", isEditMode && actionType="Image" && p_data.HasOwnProp("Tolerance") ? p_data.Tolerance : "50")
    UpDnTol := EditGui.Add("UpDown", "Range0-255", ToleranceEdit.Value)

    CoordGroup := EditGui.Add("GroupBox", "x15 y60 w365 h65", T("Dlg_GrpCoord"))
    TxtX := EditGui.Add("Text", "x25 y85", "X:")
    CoordXEdit := EditGui.Add("Edit", "x+5 yp w60 h22", isEditMode && actionType="Coord" ? p_data.X : "0")
    TxtY := EditGui.Add("Text", "x+10 yp", "Y:")
    CoordYEdit := EditGui.Add("Edit", "x+5 yp w60 h22", isEditMode && actionType="Coord" ? p_data.Y : "0")
    BtnPick := EditGui.Add("Button", "x+10 yp w100 h24", "좌표 찾기(F1)")

    EditGui.Add("Text", "x20 y170", T("Dlg_Desc"))
    DescEdit := EditGui.Add("Edit", "x+5 yp w330 h22", isEditMode ? p_data.Desc : "")
    EditGui.Add("Text", "x20 y+15", T("Dlg_Delay"))
    DelayEdit := EditGui.Add("Edit", "x+5 yp w100 h22", isEditMode ? p_data.Delay : "1000")
    EditGui.Add("UpDown", "Range0-600000", DelayEdit.Value)
    
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
        
        local data := {}
        if (RadioImage.Value) {
            if (ImgEdit.Value = "") {
                MsgBox T("Msg_ImgReq")
                return
            }
            toleranceVal := StrReplace(ToleranceEdit.Value, ",", "")
            
            if (!IsNumber(toleranceVal) or toleranceVal < 0 or toleranceVal > 255) {
                MsgBox T("Msg_TolReq")
                return
            }
            data := {Type: "Image", Image: ImgEdit.Value, Desc: DescEdit.Value, Delay: Round(delayVal), Tolerance: Round(toleranceVal)}
        } else {
             xVal := StrReplace(CoordXEdit.Value, ",", "")
             yVal := StrReplace(CoordYEdit.Value, ",", "")
             
             if (!IsNumber(xVal) or !IsNumber(yVal)) {
                MsgBox T("Msg_CoordReq")
                return
            }
            data := {Type: "Coord", X: Round(xVal), Y: Round(yVal), Desc: DescEdit.Value, Delay: Round(delayVal)}
        }
        
        savedData := data
        EditGui.Destroy()
    }

    RadioImage.Value := (actionType = "Image")
    RadioImage.OnEvent("Click", ToggleControls)
    RadioCoord.OnEvent("Click", ToggleControls)
    BrowseBtn.OnEvent("Click", SelectImageFile)
    BtnPick.OnEvent("Click", PickCoord)
    OkBtn.OnEvent("Click", OnOk)
    CancelBtn.OnEvent("Click", (*) => EditGui.Destroy())
    EditGui.OnEvent("Close", (*) => EditGui.Destroy())
    
    ToggleControls() 
    
    MyGui.Opt("+Disabled")
    EditGui.Show("w400 h320")
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

; ==============================================================================
; 매크로 로직 (Macro Logic)
; ==============================================================================
StartMacro(*) {
    global isRunning, TargetWindowHwnd, TargetWindowList, WindowDDL
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
    BtnStart.Enabled := false
    BtnStop.Enabled := true
    AddLog(T("Log_Start"))
    AddLog(T("Log_Notice"))
    
    SetTimer(MacroLoop, 100)
}

StopMacro(*) {
    global isRunning
    if (!isRunning)
        return

    isRunning := false
    BtnStart.Enabled := true
    BtnStop.Enabled := false
    SetTimer(MacroLoop, 0)
    AddLog(T("Log_Stop"))
}

MacroLoop() {
    global isRunning, MacroScript, TargetWindowHwnd
    if (!isRunning)
        return

    if !WinExist(TargetWindowHwnd) {
        StopMacro(0)
        AddLog(T("Log_WindowGone"))
        return
    }
    
    CoordMode "Mouse", "Screen"

    For index, step in MacroScript {
        if (!isRunning)
            break

        if (step.HasOwnProp("Enabled") && step.Enabled == false)
            continue

        actionTaken := false
        if (step.Type = "Image") {
            imagePath := ImageFolder . "\" . step.Image
            if !FileExist(imagePath) {
                continue 
            }
            local currentTolerance := (step.HasOwnProp("Tolerance") ? step.Tolerance : 50)
            if (FindAndClick(imagePath, currentTolerance)) {
                AddLog(T("Log_FoundClick") . step.Desc . " (*" . currentTolerance . ")")
                actionTaken := true
            }
        } else if (step.Type = "Coord") {
            try {
                ControlClick("x" . step.X . " y" . step.Y, TargetWindowHwnd, , "Left", 1, "NA")
                AddLog(T("Log_CoordClick") . step.Desc . " (" . step.X . ", " . step.Y . ")")
                actionTaken := true
            } catch {
                AddLog(T("Log_ClickFail"))
            }
        }

        if (actionTaken) {
             Sleep(step.Delay)
        }
    }
    
    Sleep(200)
}

FindAndClick(imagePath, p_tolerance := 50) {
    global TargetWindowHwnd
    CoordMode "Pixel", "Screen"
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
            ControlClick("x" . clientClickX . " y" . clientClickY, TargetWindowHwnd, , "Left", 1, "NA")
            return true
        }
    } catch as err {
        AddLog(T("Log_Err") . err.Message)
    }
    return false
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
        SendMessage(0x00B1, -2, -1, LogEdit.Hwnd, MyGui.Hwnd)
        SendMessage(0x00C2, 0, StrPtr(finalText), LogEdit.Hwnd, MyGui.Hwnd)
        SendMessage(0x00B1, -1, -1, LogEdit.Hwnd, MyGui.Hwnd)
        SendMessage(0x00B7, 0, 0, LogEdit.Hwnd, MyGui.Hwnd)
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
        line := type . "|" . img . "|" . x . "|" . y . "|" . desc . "|" . delay . "|" . tolerance . "|" . enabled
        fileContent .= line . "`n"
    }
    try {
        if FileExist(ConfigFile)
            FileDelete(ConfigFile)
        FileAppend(fileContent, ConfigFile, "UTF-8")
        ; MsgBox T("Msg_SaveSuccess") . ConfigFile 
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
            newScript.Push(step)
        }
        if (newScript.Length > 0) {
            MacroScript := newScript
            ; MsgBox T("Msg_LoadSuccess") . newScript.Length 
        }
    } catch as err {
        MsgBox T("Msg_LoadFail") . err.Message
    }
}
