#Requires AutoHotkey v2.0+
#SingleInstance Force

; ======================================================
;                   自动粘贴发送脚本
; 功能：每6秒自动粘贴剪贴板内容并发送
; 快捷键：PgUp启动/停止，F3退出
; ======================================================

; 全局变量
global isRunning := false        ; 运行状态标志
global timerObj := 0             ; 定时器对象
global interval := 6000          ; 间隔时间（毫秒）
global lastRunTime := 0          ; 上次运行时间

; 创建托盘菜单
CreateTrayMenu()

; 显示提示信息
ShowStartupTip()

; ======================================================
;                   热键定义
; ======================================================

; PgUp: 启动/停止脚本
PgUp::ToggleScript()

; F3: 退出脚本
F3::ExitScript()

; ======================================================
;                   主功能函数
; ======================================================

/**
 * 切换脚本运行状态
 */
ToggleScript() {
    global isRunning, timerObj, interval, lastRunTime
    
    if (!isRunning) {
        ; 启动脚本
        isRunning := true
        lastRunTime := A_TickCount
        
        ; 创建定时器
        timerObj := SetTimer(PasteAndSend, interval)
        
        ; 立即执行第一次操作
        PasteAndSend()
        
        ; 更新托盘图标和提示
        A_IconTip := "自动粘贴发送 - 运行中 (PgUp停止)"
        TraySetIcon("Shell32.dll", 238)  ; 绿色图标表示运行中
        
        ToolTip("✅ 脚本已启动，每6秒自动粘贴发送", 500, 500)
        SetTimer () => ToolTip(), -2000
    } else {
        ; 停止脚本
        isRunning := false
        if (timerObj) {
            SetTimer(timerObj, 0)  ; 停止定时器
            timerObj := 0
        }
        
        ; 更新托盘图标和提示
        A_IconTip := "自动粘贴发送 - 已停止 (PgUp启动)"
        TraySetIcon("Shell32.dll", 110)  ; 红色图标表示停止
        
        ToolTip("⏸️ 脚本已停止", 500, 500)
        SetTimer () => ToolTip(), -2000
    }
}

/**
 * 执行粘贴和发送操作
 */
PasteAndSend(*) {
    global isRunning, lastRunTime
    
    if (!isRunning) {
        return
    }
    
    try {
        ; 保存当前剪贴板内容
        originalClipboard := A_Clipboard
        
        ; 获取要发送的文本
        textToSend := A_Clipboard
        
        if (textToSend = "") {
            ToolTip("⚠️ 剪贴板为空，请先复制文本", 500, 500)
            SetTimer () => ToolTip(), -2000
            return
        }
        
        ; 显示正在执行的提示
        elapsed := A_TickCount - lastRunTime
        ToolTip("📤 正在发送... (" . Round(elapsed/1000, 1) . "秒前)", 500, 500)
        
        ; 模拟按键：粘贴 (Ctrl+V) 然后发送 (Enter)
        SendInput "^v"      ; 粘贴
        Sleep 100           ; 短暂等待确保粘贴完成
        SendInput "{Enter}" ; 发送
        
        ; 恢复原始剪贴板内容
        A_Clipboard := originalClipboard
        
        ; 更新上次运行时间
        lastRunTime := A_TickCount
        
        ; 显示成功提示
        textPreview := StrLen(textToSend) > 20 ? SubStr(textToSend, 1, 20) "..." : textToSend
        ToolTip("✅ 已发送: " . textPreview, 500, 500)
        SetTimer () => ToolTip(), -1500
        
    } catch as err {
        ToolTip("❌ 发送失败: " . err.Message, 500, 500)
        SetTimer () => ToolTip(), -3000
    }
}

/**
 * 退出脚本
 */
ExitScript() {
    global isRunning, timerObj
    
    ; 停止定时器
    if (isRunning && timerObj) {
        SetTimer(timerObj, 0)
    }
    
    ToolTip("👋 脚本退出中...", 500, 500)
    Sleep 500
    
    ; 清理资源
    A_Clipboard := ""  ; 清空剪贴板引用
    
    ExitApp
}

; ======================================================
;                   辅助函数
; ======================================================

/**
 * 创建托盘菜单
 */
CreateTrayMenu() {
    A_TrayMenu.Delete()  ; 清除默认菜单
    
    A_TrayMenu.Add("启动/停止脚本 (PgUp)", (*) => ToggleScript())
    A_TrayMenu.Add("设置间隔时间", (*) => ShowIntervalSettings())
    A_TrayMenu.Add("查看统计信息", (*) => ShowStatistics())
    A_TrayMenu.Add()  ; 分隔线
    A_TrayMenu.Add("退出脚本 (F3)", (*) => ExitScript())
    
    A_TrayMenu.Default := "启动/停止脚本 (PgUp)"
    A_IconTip := "自动粘贴发送 - 已停止 (PgUp启动)"
    TraySetIcon("Shell32.dll", 110)  ; 初始图标
}

/**
 * 显示间隔时间设置界面
 */
ShowIntervalSettings() {
    global interval
    
    ; 创建设置窗口
    settingsGui := Gui("+AlwaysOnTop", "设置发送间隔")
    settingsGui.SetFont("s10", "Microsoft YaHei")
    
    settingsGui.Add("Text", "w300", "当前间隔: " . (interval//1000) . " 秒")
    
    intervalSlider := settingsGui.Add("Slider", "w300 Range1-60 ToolTip", interval//1000)
    intervalSlider.OnEvent("Change", IntervalSliderChanged.Bind(intervalSlider))
    
    previewText := settingsGui.Add("Text", "w300", "预览: 每 " . (interval//1000) . " 秒发送一次")
    
    settingsGui.Add("Button", "w100", "应用").OnEvent("Click", (*) => ApplyNewInterval(intervalSlider.Value))
    settingsGui.Add("Button", "x+20 w100", "取消").OnEvent("Click", (*) => settingsGui.Destroy())
    
    settingsGui.Show()
    
    ; 保存预览文本控件的引用
    previewText.Value := "预览: 每 " . (interval//1000) . " 秒发送一次"
}

/**
 * 滑块变化事件处理
 */
IntervalSliderChanged(ctrlObj, *) {
    ; 直接使用控件的父窗口来更新
    if (ctrlObj.Gui) {
        ; 查找预览文本控件（通常是第三个静态文本控件）
        for ctrl in ctrlObj.Gui {
            if (Type(ctrl) = "Gui.Text" && InStr(ctrl.Text, "预览:")) {
                ctrl.Text := "预览: 每 " . ctrlObj.Value . " 秒发送一次"
                break
            }
        }
    }
}

/**
 * 应用新的间隔时间
 */
ApplyNewInterval(seconds) {
    global interval, timerObj, isRunning
    
    interval := seconds * 1000
    
    ; 如果正在运行，重新设置定时器
    if (isRunning && timerObj) {
        SetTimer(timerObj, 0)  ; 停止旧定时器
        timerObj := SetTimer(PasteAndSend, interval)  ; 启动新定时器
    }
    
    ToolTip("✅ 间隔已设置为 " . seconds . " 秒", 500, 500)
    SetTimer () => ToolTip(), -2000
}

/**
 * 显示统计信息
 */
ShowStatistics() {
    global lastRunTime, interval, isRunning
    
    statsGui := Gui("+AlwaysOnTop", "统计信息")
    statsGui.SetFont("s10", "Microsoft YaHei")
    
    if (lastRunTime > 0) {
        timeSinceLast := A_TickCount - lastRunTime
        statsGui.Add("Text", "w300", "上次发送时间: " . FormatTime(lastRunTime, "HH:mm:ss"))
        statsGui.Add("Text", "w300", "距离上次发送: " . Round(timeSinceLast/1000, 1) . " 秒前")
    } else {
        statsGui.Add("Text", "w300", "脚本尚未发送过消息")
    }
    
    statsGui.Add("Text", "w300", "当前间隔: " . (interval//1000) . " 秒")
    statsGui.Add("Text", "w300", "运行状态: " . (isRunning ? "运行中" : "已停止"))
    
    statsGui.Add("Button", "w100", "确定").OnEvent("Click", (*) => statsGui.Destroy())
    
    statsGui.Show()
}

/**
 * 显示启动提示
 */
ShowStartupTip() {
    ToolTip("📋 自动粘贴发送脚本已加载`n按 PgUp 启动/停止`n按 F3 退出", 500, 500)
    SetTimer () => ToolTip(), -3000
}

; ======================================================
;                   脚本结束
; ======================================================