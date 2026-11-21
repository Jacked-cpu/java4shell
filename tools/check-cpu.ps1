$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

Write-Host "CPU: $($cpu.Name)"

$coreinfo = Join-Path $here 'coreinfo.exe'
if (-not (Test-Path $coreinfo)) {
    $cmd = Get-Command coreinfo.exe -ErrorAction SilentlyContinue
    if ($cmd) { $coreinfo = $cmd.Source }
}

if (Test-Path $coreinfo) {
    $out = & $coreinfo -f 2>&1
    $need = 'AVX512F', 'AVX512BW', 'AVX512_VBMI', 'BMI2'
    $missing = @()
    foreach ($f in $need) {
        if ($out -match [regex]::Escape($f)) {
            Write-Host "  $f : present"
        } else {
            Write-Host "  $f : MISSING"
            $missing += $f
        }
    }
    if ($missing.Count -eq 0) {
        Write-Host 'Verdict: CPU can trigger Java4Shell (all flags present).'
    } else {
        Write-Host "Verdict: cannot trigger Java4Shell (missing: $($missing -join ', '))."
    }
} else {
    Write-Host 'coreinfo.exe not found. Download Sysinternals Coreinfo and place it next to this script:'
    Write-Host '  https://learn.microsoft.com/sysinternals/downloads/coreinfo'
    Write-Host 'Then run: coreinfo.exe -f   (look for AVX512F, AVX512BW, AVX512_VBMI, BMI2)'
}

if ($cpu.Name -match 'i7-1255U|Alder Lake|12th Gen') {
    Write-Host 'Note: consumer 12th-gen Intel parts have AVX-512 fused off. The lab will not reproduce here.'
}
