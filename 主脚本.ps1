# 检查是否以管理员身份运行
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "错误：请以管理员身份运行此脚本！" -ForegroundColor Red
    Write-Host "`n按 Enter 键退出" -ForegroundColor Red
    Read-Host
    exit
}

# 获取当前脚本的目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# 目标进程名称（白名单进程不终止）
$processNames = @("SGuardSvc64", "SGuard64", "ACE-Tray", "browser", "delta_force_launcher", "icreateDf")#, "AclosGameProxy", "CrossProxy", "无畏契约登录器", "chrome"
$whitelist = @("delta_force_launcher", "browser", "AclosGameProxy", "CrossProxy", "无畏契约登录器", "icreateDf")  # 白名单进程，仅限制不终止

# 目标服务名称（使用 DisplayName，需确认）
$serviceNames = @("AntiCheatExpert Service", "AntiCheatExpert Protection")

# 检查 wmic 可用性
$wmicAvailable = $true
try {
    & wmic /? | Out-Null
} catch {
    $wmicAvailable = $false
    Write-Host "警告：wmic 不可用，I/O 优先级设置和部分终止方法可能受限。`n建议升级到 PowerShell 7 或使用第三方工具（如 Process Lasso）。" -ForegroundColor Yellow
}

Write-Host "`n=== 开始处理服务 ===" -ForegroundColor Cyan
# 停止相关服务
foreach ($service in $serviceNames) {
    Write-Host "`n检查服务: $service" -ForegroundColor White
    $svc = Get-Service -DisplayName $service -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq "Running") {
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                Write-Host "已停止服务: $service" -ForegroundColor Green
            } catch {
                Write-Host "无法停止服务 ${service}: $($_.Exception.Message)`n请检查服务权限或状态。" -ForegroundColor Yellow
            }
        }
        try {
            Set-Service -Name $svc.Name -StartupType Manual -ErrorAction Stop
            Write-Host "已将服务 ${service} 的启动类型设置为手动" -ForegroundColor Green
        } catch {
            Write-Host "无法设置服务 ${service} 的启动类型: $($_.Exception.Message)`n请检查服务配置。" -ForegroundColor Yellow
        }
    } else {
        Write-Host "未找到服务: $service`n请在 services.msc 中确认服务 DisplayName。" -ForegroundColor Yellow
    }
}

Write-Host "`n=== 开始处理进程 ===" -ForegroundColor Cyan
# 获取 CPU 核数量
$cpuCount = [Environment]::ProcessorCount
# 计算最后一个 CPU 核的亲和性掩码
$lastCpuMask = [IntPtr] (1 -shl ($cpuCount - 1))
Write-Host "CPU 核数量: $cpuCount, 最后一个 CPU 核: $($cpuCount - 1), 掩码: $lastCpuMask" -ForegroundColor White

# 处理目标进程
foreach ($name in $processNames) {
    # 查找目标进程
    $processes = Get-Process -Name $name -ErrorAction SilentlyContinue

    if ($processes) {
        foreach ($process in $processes) {
            Write-Host "`n找到进程: $($process.Name), PID: $($process.Id)" -ForegroundColor White

            # 设置 CPU 亲和性为最后一个 CPU 核
            try {
                $process.ProcessorAffinity = $lastCpuMask
                Write-Host "已将 $($process.Name) 的 CPU 亲和性设置为 CPU $($cpuCount - 1)" -ForegroundColor Green
            } catch {
                Write-Host "无法设置 $($process.Name) 的 CPU 亲和性: $($_.Exception.Message)`n可能需要更高权限（如 SYSTEM）。" -ForegroundColor Yellow
            }

            # 设置进程优先级为低 (Idle)
            try {
                $process.PriorityClass = "Idle"
                Write-Host "已将 $($process.Name) 的优先级设置为低 (Idle)" -ForegroundColor Green
            } catch {
                Write-Host "无法设置 $($process.Name) 的优先级: $($_.Exception.Message)`n可能需要更高权限。" -ForegroundColor Yellow
            }

            # 设置 I/O 优先级为非常低 (Very Low)
            try {
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    # PowerShell 7+ 和 Windows 10 1809+ 支持 Set-ProcessIoPriority
                    Set-ProcessIoPriority -Id $process.Id -Priority VeryLow -ErrorAction Stop
                    Write-Host "已将 $($process.Name) 的 I/O 优先级设置为非常低 (Very Low)" -ForegroundColor Green
                } elseif ($wmicAvailable) {
                    # 回退到 wmic
                    & wmic process where processid=$($process.Id) call setpriority 1
                    Write-Host "已将 $($process.Name) 的 I/O 优先级设置为非常低 (Very Low, via wmic)" -ForegroundColor Green
                } else {
                    Write-Host "无法设置 $($process.Name) 的 I/O 优先级：系统不支持 wmic 且 PowerShell 版本过低`n建议升级 PowerShell 或使用 Process Lasso。" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "无法设置 $($process.Name) 的 I/O 优先级: $($_.Exception.Message)`n可能需要更高权限或第三方工具。" -ForegroundColor Yellow
            }

            # 仅对非白名单进程尝试终止
            if ($whitelist -notcontains $name) {
                Write-Host "`n尝试终止进程: $($process.Name), PID: $($process.Id)" -ForegroundColor White
                # 方法 1: Stop-Process
                try {
                    Stop-Process -Id $process.Id -Force -ErrorAction Stop
                    Write-Host "已通过 Stop-Process 成功终止 $($process.Name)" -ForegroundColor Green
                    continue
                } catch {
                    Write-Host "Stop-Process 无法终止 $($process.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                }

                # 方法 2: taskkill
                try {
                    & taskkill /PID $($process.Id) /F
                    Write-Host "已通过 taskkill 成功终止 $($process.Name)" -ForegroundColor Green
                    continue
                } catch {
                    Write-Host "taskkill 无法终止 $($process.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                }

                # 方法 3: wmic
                if ($wmicAvailable) {
                    try {
                        & wmic process where processid=$($process.Id) call terminate
                        Write-Host "已通过 wmic 成功终止 $($process.Name)" -ForegroundColor Green
                        continue
                    } catch {
                        Write-Host "wmic 无法终止 $($process.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            } else {
                Write-Host "进程 $($process.Name) 在白名单中，仅限制运行，不终止" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host "`n未找到进程: $name" -ForegroundColor Yellow
    }
}

Write-Host "`n=== 设置和关闭尝试完成 ===" -ForegroundColor Green
Write-Host "一次性脚本，每次游戏启动后，先不要点 :安装预启动ace: 弹窗的拒绝，否则无法停止进程，必须 :完全: 进入游戏，然后再点击脚本文件夹中的的 :ace kill启动.bat: 启动功能，如果卡在游戏启动界面，可以先终止游戏启动器进程或者重启电脑，然后在按照前面说的步骤进行重新操作。" -ForegroundColor Red
Write-Host "`n如果容易爆显存，可以运行脚本文件夹中的 :memreduct后台清理\64或32\memreduct.exe: 的程序，可以适当降低内存压力" -ForegroundColor Yellow
Write-Host "`n当前版本 : 1.0.3`n脚本没有更新能力，脚本后续会有修复bug之类的，如需更新`n请访问 : https://ftnknc.lanzouo.com/b0sxutpvc`n密码:1eo8" -ForegroundColor Green

# 添加选项菜单
while ($true) {
    Write-Host "`n请选择一个选项：" -ForegroundColor Cyan
    Write-Host "1. 运行 '更改电源计划' -建议使用卓越性能"
    Write-Host "2. 运行 '反作弊启动设置' -没啥大用，但必须有"
    Write-Host "3. 运行 '优化处理器性能与软件进程优先级' -集成了其他up的优化，建议尝试"
    Write-Host "4. 退出"

    $choice = Read-Host "请输入数字运行脚本，或者直接点击右上角关闭脚本"

    switch ($choice) {
        "1" {
            # 运行 '更改电源计划.ps1'
            $powerScriptPath = Join-Path -Path $scriptDir -ChildPath "更改电源计划.ps1"
            if (Test-Path -Path $powerScriptPath) {
                try {
                    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$powerScriptPath`"" -Verb RunAs -ErrorAction Stop
                    Write-Host "已运行 '更改电源计划'" -ForegroundColor Green
                } catch {
                    Write-Host "无法运行 '更改电源计划': $($_.Exception.Message)`n请确认文件路径或权限。" -ForegroundColor Yellow
                }
            } else {
                Write-Host "未找到 '更改电源计划' 文件: $powerScriptPath`n请确认文件是否存在于脚本目录中。" -ForegroundColor Yellow
            }
        }
        "2" {
            # 运行 '反作弊启动设置.ps1'
            $antiCheatScriptPath = Join-Path -Path $scriptDir -ChildPath "反作弊启动设置.ps1"
            if (Test-Path -Path $antiCheatScriptPath) {
                try {
                    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$antiCheatScriptPath`"" -Verb RunAs -ErrorAction Stop
                    Write-Host "已运行 '反作弊启动设置'" -ForegroundColor Green
                } catch {
                    Write-Host "无法运行 '反作弊启动设置': $($_.Exception.Message)`n请确认文件路径或权限。" -ForegroundColor Yellow
                }
            } else {
                Write-Host "未找到 '反作弊启动设置' 文件: $antiCheatScriptPath`n请确认文件是否存在于脚本目录中。" -ForegroundColor Yellow
            }
        }
        "3" {
            # 运行 '优化处理器性能与软件进程优先级.ps1'
            $antiCheatScriptPath = Join-Path -Path $scriptDir -ChildPath "优化处理器性能与软件进程优先级.ps1"
            if (Test-Path -Path $antiCheatScriptPath) {
                try {
                    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$antiCheatScriptPath`"" -Verb RunAs -ErrorAction Stop
                    Write-Host "已运行 '优化处理器性能与软件进程优先级'" -ForegroundColor Green
                } catch {
                    Write-Host "无法运行 '优化处理器性能与软件进程优先级': $($_.Exception.Message)`n请确认文件路径或权限。" -ForegroundColor Yellow
                }
            } else {
                Write-Host "未找到 '优化处理器性能与软件进程优先级' 文件: $antiCheatScriptPath`n请确认文件是否存在于脚本目录中。" -ForegroundColor Yellow
            }
        }
        "4" {
            # 退出脚本
            Write-Host "退出脚本" -ForegroundColor Cyan
            exit
        }
        default {
            Write-Host "无效的输入，请输入数字" -ForegroundColor Red
        }
    }
}