# Usage: windows\create.ps1 [-Config <name>]

param([string]$Config)

. (Join-Path $PSScriptRoot 'lib.ps1')

$cfg = Read-HeliosConfig $Config
$Top = $script:Top
$vmdir = "$Top\vm\$($cfg.VM)"

# Check to see if the VM exists already.  We don't want to make it too easy to
# accidentally destroy your work.
if (Test-Path $vmdir) {
    Write-Host ''
    Write-Host "VM $($cfg.VM) exists already; run windows\destroy.ps1 if you want to recreate"
    Write-Host ''
    exit 1
}

$image = Join-Path $Top "input\$($cfg.INPUT_IMAGE)"

# Build the guest's authorized_keys from the user's public keys, unless one
# has been provided already.
$cpiodir = Join-Path $Top 'input\cpio'
New-Item -ItemType Directory -Force $cpiodir | Out-Null
$keyfile = Join-Path $cpiodir 'authorized_keys'
if (-not (Test-Path $keyfile)) {
    Get-Content "$env:USERPROFILE\.ssh\*.pub" | Set-Content $keyfile -Encoding ascii
}

# Produce the firstboot script that will run in the new guest to set up a basic
# user account.  Windows has no uid to mirror, so use 1000 and the lower-cased
# Windows username.
$xname = $env:USERNAME.ToLowerInvariant()
$xid = 1000

$firstboot = @"
#!/bin/bash
set -o errexit
set -o pipefail
set -o xtrace
echo 'Just a moment...' >/dev/msglog
/sbin/zfs create 'rpool/home/$xname'
/usr/sbin/useradd -u '$xid' -g staff -c '$xname' -d '/home/$xname' \
    -P 'Primary Administrator' -s /bin/bash '$xname'
/bin/passwd -N '$xname'
/bin/mkdir '/home/$xname/.ssh'
if [[ -f /root/.ssh/authorized_keys ]]; then
	/bin/cp /root/.ssh/authorized_keys '/home/$xname/.ssh/authorized_keys'
fi
/bin/chown -R '${xname}:staff' '/home/$xname'
/bin/chmod 0700 '/home/$xname'
/bin/sed -i \
    -e '/^PATH=/s#`$#:/opt/ooce/bin:/opt/ooce/sbin#' \
    /etc/default/login
/bin/ntpdig -S 0.pool.ntp.org || true
(
	echo
	echo
	banner 'oh, hello!'
	echo
	echo
	if [[ -s '/home/$xname/.ssh/authorized_keys' ]]; then
		echo "You should be able to SSH to your VM from the host:"
		echo
		echo "    ssh -p $($cfg.SSH_PORT) $xname@localhost"
	else
		echo "No SSH keys were provided!"
		echo
		echo "Press Enter and use the console to log in as root."
	fi
	echo
	echo
) >/dev/msglog
exit 0
"@

$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $cpiodir 'firstboot.sh'), $firstboot.Replace("`r`n", "`n"), $utf8)

# Set the hostname of the guest to the same name as the VM name.
[IO.File]::WriteAllText((Join-Path $cpiodir 'nodename'), "$($cfg.VM)`n", $utf8)

New-Item -ItemType Directory -Force $vmdir | Out-Null

# Create the metadata volume.
$meta = Join-Path $vmdir 'metadata.cpio'
tar.exe --format odc -cf $meta -C $cpiodir (Get-ChildItem $cpiodir -Name)
qemu-img.exe resize -f raw $meta 1M

# Then, create the Helios disk from the seed image.
$root = Join-Path $vmdir 'root.qcow2'
Write-Host "converting $image -> $root ..."
qemu-img.exe convert -f raw -O qcow2 $image $root
qemu-img.exe resize $root $cfg.SIZE

Start-HeliosVm $cfg
