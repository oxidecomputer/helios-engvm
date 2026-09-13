# Shared helpers for running a Helios VM under QEMU on a Windows host.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$script:Top = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Read config/defaults.sh and an optional override config/<name>.sh.  These are
# bash files, but they only contain simple KEY=VALUE assignments.
function Read-HeliosConfig {
    param([string]$Name)

    $cfg = @{ SSH_PORT = 478; }  # 0x1de
    $files = @("$script:Top\config\defaults.sh")
    if ($Name) { $files += "$script:Top\config\$Name.sh" }
    foreach ($file in $files) {
        $data = Get-Content $file -Raw | ConvertFrom-StringData
        foreach ($k in $data.Keys) {
            # bash arithmetic like $(( 2 * 1024 * 1024 )) is also valid PowerShell
            $cfg[$k] = if ($data[$k] -like '$((*))') { Invoke-Expression $data[$k] } else { $data[$k] }
        }
    }
    return $cfg
}

# Start the VM in the foreground with the serial console attached to this
# terminal. It's easier to use NAT rather than a bridge network, since the
# latter would require additional drivers in Windows.
function Start-HeliosVm {
    param([hashtable]$Cfg)

    $vmdir = "$script:Top\vm\$($Cfg.VM)"
    $root = Join-Path $vmdir 'root.qcow2'
    $meta = Join-Path $vmdir 'metadata.cpio'
    foreach ($f in $root, $meta) {
        if (-not (Test-Path $f)) {
            throw "VM $($Cfg.VM) does not exist ($f missing); run windows\create.ps1 first"
        }
    }

    $memMiB = [int64]$Cfg.MEM / 1024

    # disable-modern=on forces the legacy virtio transport, as the illumos vioblk driver
    # errors with the modern transport.
    $qemuArgs = @(
        '-name', $Cfg.VM,
        '-accel', 'whpx',
        '-machine', 'pc,hpet=on,vmport=off',
        '-cpu', 'host',
        '-smp', $Cfg.VCPU,
        '-m', $memMiB,
        '-rtc', 'base=utc,driftfix=slew',
        '-display', 'none',
        '-serial', 'mon:stdio',
        '-drive', "file=$root,if=none,id=root,format=qcow2",
        '-device', 'virtio-blk-pci,drive=root,bootindex=0,disable-modern=on',
        '-drive', "file=$meta,if=none,id=meta,format=raw",
        '-device', 'virtio-blk-pci,drive=meta,disable-modern=on',
        '-nic', "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:$($Cfg.SSH_PORT)-:22"
    )

    Write-Host "starting $($Cfg.VM) (console on this terminal; Ctrl-A X to quit, Ctrl-A C for QEMU monitor)"
    Write-Host "    qemu-system-x86_64 $($qemuArgs -join ' ')"
    Write-Host ''
    qemu-system-x86_64.exe @qemuArgs
}
