# 确保以管理员权限运行
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "此脚本需要以管理员权限运行！" -ForegroundColor Red
    Write-Host ""
    exit
}

# 获取脚本所在目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupFile = Join-Path $scriptDir "PowerSettingsBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"

# 提示用户是否备份注册表
Write-Host "是否备份注册表项？(y/n)" -ForegroundColor Cyan
$backupChoice = Read-Host
Write-Host ""
if ($backupChoice -eq 'y' -or $backupChoice -eq 'Y') {
    try {
        # 备份电源管理和 SGuard64.exe 相关的注册表项
        $regKey1 = "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00"
        $regKey2 = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SGuard64.exe"
        Start-Process -FilePath "reg" -ArgumentList "export `"$regKey1`" `"$backupFile`"" -NoNewWindow -Wait -ErrorAction Stop
        if (Test-Path $backupFile) {
            Write-Host "电源管理注册表已成功备份到 $backupFile" -ForegroundColor Green
            Write-Host ""
        } else {
            Write-Host "电源管理备份文件未生成，请检查权限或路径！" -ForegroundColor Red
            Write-Host ""
            exit
        }
        # 备份 SGuard64.exe 注册表项（如果存在）
        if (Test-Path $regKey2) {
            $sguardBackup = Join-Path $scriptDir "SGuardBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
            Start-Process -FilePath "reg" -ArgumentList "export `"$regKey2`" `"$sguardBackup`"" -NoNewWindow -Wait -ErrorAction Stop
            if (Test-Path $sguardBackup) {
                Write-Host "SGuard64.exe 注册表已成功备份到 $sguardBackup" -ForegroundColor Green
                Write-Host ""
            } else {
                Write-Host "SGuard64.exe 备份文件未生成，请检查权限或路径！" -ForegroundColor Red
                Write-Host ""
                exit
            }
        }
    }
    catch {
        Write-Host "注册表备份失败：$_" -ForegroundColor Red
        Write-Host ""
        exit
    }
} else {
    Write-Host "用户选择不备份注册表，继续执行修改操作。" -ForegroundColor White
    Write-Host ""
}

# 定义注册表路径
$regPath1 = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
$regPath2 = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318584"
$regPath3 = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\be337238-0d82-4146-a960-4f3749d470c7"
$regPath4 = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SGuard64.exe\PerfOptions"

# 设置第一个注册表路径的 ValueMax 和 ValueMin 为十进制 100
try {
    Set-ItemProperty -Path $regPath1 -Name "ValueMax" -Value 100 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $regPath1 -Name "ValueMin" -Value 100 -Type DWord -ErrorAction Stop
    Write-Host "注册表项 $regPath1 的 ValueMax 和 ValueMin 已成功设置为 100。" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "修改注册表 $regPath1 失败：$_" -ForegroundColor Red
    Write-Host ""
}

# 设置第二个注册表路径的 ValueMax 和 ValueMin 为十进制 100
try {
    Set-ItemProperty -Path $regPath2 -Name "ValueMax" -Value 100 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $regPath2 -Name "ValueMin" -Value 100 -Type DWord -ErrorAction Stop
    Write-Host "注册表项 $regPath2 的 ValueMax 和 ValueMin 已成功设置为 100。" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "修改注册表 $regPath2 失败：$_" -ForegroundColor Red
    Write-Host ""
}

# 删除子项 0
try {
    if (Test-Path "$regPath3\0") {
        Remove-Item -Path "$regPath3\0" -Force -ErrorAction Stop
        Write-Host "成功删除注册表子项 $regPath3\0。" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "注册表子项 $regPath3\0 不存在，无需删除。" -ForegroundColor White
        Write-Host ""
    }
}
catch {
    Write-Host "删除注册表子项 $regPath3\0 失败：$_" -ForegroundColor Red
    Write-Host ""
}

# 删除子项 3
try {
    if (Test-Path "$regPath3\3") {
        Remove-Item -Path "$regPath3\3" -Force -ErrorAction Stop
        Write-Host "成功删除注册表子项 $regPath3\3。" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "注册表子项 $regPath3\3 不存在，无需删除。" -ForegroundColor White
        Write-Host ""
    }
}
catch {
    Write-Host "删除注册表子项 $regPath3\3 失败：$_" -ForegroundColor Red
    Write-Host ""
}

# 设置 SGuard64.exe 的性能优先级
try {
    # 创建或确保 PerfOptions 子项存在
    if (-not (Test-Path $regPath4)) {
        New-Item -Path $regPath4 -Force -ErrorAction Stop | Out-Null
    }
    Set-ItemProperty -Path $regPath4 -Name "CpuPriorityClass" -Value 1 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $regPath4 -Name "IoPriority" -Value 1 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $regPath4 -Name "PagePriority" -Value 1 -Type DWord -ErrorAction Stop
    Write-Host "设置 SGuard64.exe 的性能优先级，reg作者id:112889380，树叶菌0v0，BV1x1gwzdEBn" -ForegroundColor Green    
    Write-Host "SGuard64.exe 的 CpuPriorityClass、IoPriority 和 PagePriority 已成功设置为 1。" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "设置 SGuard64.exe 性能优先级失败：$_" -ForegroundColor Red
    Write-Host ""
}

# 运行完成后暂停，不关闭脚本
Write-Host "脚本执行完成，按任意键继续..." -ForegroundColor Cyan
Write-Host ""
$null = Read-Host