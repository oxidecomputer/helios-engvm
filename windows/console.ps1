# Usage: windows\console.ps1 [-Config <name>]

param([string]$Config)

. (Join-Path $PSScriptRoot 'lib.ps1')

Start-HeliosVm (Read-HeliosConfig $Config)
