# Usage: windows\download.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Top = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Keep these in sync with download.sh.
$namebase = 'helios-qemu-ttya-full'
$name = "$namebase-20260509.raw"
$namegz = "$name.gz"
$url = "https://pkg.oxide.computer/seed/$namegz"
$sha256 = '42bce6068be61e38d5e5c83a70f3b55331e257111aca2cafafe65f6af577b6f1'
$sha256gz = '32ce1d6d87fef4089dc7ee10060787b4959a936b0c57066b2c3ecdd34c393d4f'
$sizegz = 2617732910

function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 $Path).Hash.ToLowerInvariant()
}

$input_ = Join-Path $Top 'input'
$tmp = Join-Path $Top 'tmp'
New-Item -ItemType Directory -Force $input_, $tmp | Out-Null

$target = Join-Path $input_ $name
$gz = Join-Path $tmp $namegz

while ($true) {
    if (Test-Path $target) {
        Write-Host "checking hash on existing file $target..."
        if ((Get-Sha256 $target) -eq $sha256) {
            Write-Host 'seed image downloaded ok'
            break
        }
        Write-Host 'seed image hash does not match, removing'
        Remove-Item $target -Force
    }

    # We try to continue downloading a partial file, as the image is quite
    # large.
    if (-not (Test-Path $gz) -or (Get-Item $gz).Length -ne $sizegz) {
        Write-Host "downloading gz file $url..."
        curl.exe -C - -f -o $gz $url
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'download failure, retrying...'
            Start-Sleep 3
            continue
        }
    } else {
        Write-Host "gzip file $gz is correct size, skipping download"
    }

    Write-Host "checking hash on existing gz file $gz..."
    if ((Get-Sha256 $gz) -ne $sha256gz) {
        Write-Host 'seed image gz not ok, removing'
        Remove-Item $gz -Force
        continue
    }

    Write-Host "extracting $gz"
    $extracted = "$gz.extracted"
    Remove-Item $extracted -Force -ErrorAction SilentlyContinue
    $in = [IO.File]::OpenRead($gz)
    $out = [IO.File]::Create($extracted)
    try {
        $gzs = New-Object IO.Compression.GZipStream($in, [IO.Compression.CompressionMode]::Decompress)
        $gzs.CopyTo($out, 4MB)
        $gzs.Dispose()
    } finally {
        $out.Dispose()
        $in.Dispose()
    }

    Write-Host "moving $extracted -> $target"
    Move-Item $extracted $target -Force
}

# Create a symbolic link that points the base name (without a timestamp) to the
# image we just downloaded.
$link = Join-Path $input_ "$namebase.raw"
Remove-Item $link -Force -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Path $link -Target $name | Out-Null
