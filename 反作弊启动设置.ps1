# 检查管理员权限
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "请以管理员身份运行此脚本！" -ForegroundColor Red
    Pause
    Exit
}

# 定义目标服务列表（包含新增的服务）
$services = @(
    "ACE-BASE",
    "ace-game",
    "ace-game-0",
    "TesSafe",
    "AntiCheatExpert Protection",
    "AntiCheatExpert Service",
    "ACE-CORE302706"
)

# 菜单界面
function Show-Menu {
    Clear-Host
    Write-Host "优先设置为禁用 (Disabled)，如果出现无法正常启动游戏就设置回手动启动 (Manual)" -ForegroundColor Red
    Write-Host ""
    Write-Host ""
    Write-Host "===== 反作弊服务启动类型设置 =====" -ForegroundColor Cyan
    Write-Host "1. 设置为手动启动 (Manual)"
    Write-Host "2. 设置为禁用 (Disabled)"
    Write-Host "3. 退出"
    Write-Host "=================================" -ForegroundColor Cyan
}

# 主循环
while ($true) {
    Show-Menu
    $choice = Read-Host "请选择操作 (1-3)"
    
    switch ($choice) {
        "1" {
            # 设置为手动启动
            foreach ($service in $services) {
                try {
                    Set-Service -Name $service -StartupType Manual -ErrorAction Stop
                    Write-Host "已设置 [$service] 为手动启动" -ForegroundColor Green
                } catch {
                    Write-Host "无法设置 [$service]：可能服务不存在或权限不足" -ForegroundColor Red
                }
            }
            Pause
        }
        "2" {
            # 设置为禁用
            foreach ($service in $services) {
                try {
                    Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
                    Write-Host "已设置 [$service] 为禁用" -ForegroundColor Green
                } catch {
                    Write-Host "无法设置 [$service]：可能服务不存在或权限不足" -ForegroundColor Red
                }
            }
            Pause
        }
        "3" {
            # 退出脚本
            Exit
        }
        default {
            Write-Host "无效输入，请重新选择！" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}