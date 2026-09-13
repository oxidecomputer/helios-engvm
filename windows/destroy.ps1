# Usage: windows\destroy.ps1 [-Config <name>]

param([string]$Config)

. (Join-Path $PSScriptRoot 'lib.ps1')

$cfg = Read-HeliosConfig $Config
$vmdir = "$script:Top\vm\$($cfg.VM)"

if (Test-Path $vmdir) {
    Write-Host "removing $vmdir"
    Remove-Item $vmdir -Recurse -Force
} else {
    Write-Host "VM $($cfg.VM) does not exist"
}
