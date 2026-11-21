param(
    [string]$JdkZip,
    [switch]$Download,
    [string]$InstallDir = 'C:\java4shell',
    [string]$Version = '21.0.5+11'
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path $InstallDir 'jdk'

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if (-not (Test-Path $dest)) {
    if ($Download) {
        $url = "https://api.adoptium.net/v3/binary/version/jdk-$Version/windows/x64/jdk/hotspot/normal/eclipse"
        $zip = Join-Path $InstallDir 'jdk.zip'
        Write-Host "Downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    } elseif ($JdkZip) {
        $zip = $JdkZip
    } else {
        throw 'Pass -Download or -JdkZip <path to Windows x64 JDK zip>.'
    }

    $tmp = Join-Path $InstallDir 'extract'
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $root = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (-not $root) { throw 'Zip did not contain a JDK directory.' }
    Move-Item $root.FullName $dest
}

$java = Join-Path $dest 'bin\java.exe'
$javac = Join-Path $dest 'bin\javac.exe'
if (-not (Test-Path $java)) { throw "java.exe not found under $dest" }

Write-Host '--- CPU check (needs coreinfo.exe for true AVX-512 detection) ---'
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
Write-Host "CPU: $($cpu.Name)"
& 'powershell.exe' -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here '..\tools\check-cpu.ps1')

Write-Host '--- java -version ---'
& $java -version

Write-Host '--- compile target ---'
& $javac (Join-Path $here 'DecodeServer.java')
if ($LASTEXITCODE -ne 0) { throw 'javac failed' }

Write-Host '--- firewall rule for port 8080 (needs elevation) ---'
try {
    if (-not (Get-NetFirewallRule -DisplayName 'java4shell-lab-8080' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName 'java4shell-lab-8080' -Direction Inbound `
            -Protocol TCP -LocalPort 8080 -Action Allow | Out-Null
        Write-Host 'Created inbound rule java4shell-lab-8080.'
    } else {
        Write-Host 'Firewall rule already exists.'
    }
} catch {
    Write-Host "Could not add firewall rule (run PowerShell as Administrator): $($_.Exception.Message)"
}

Write-Host ''
Write-Host "Ready. Start the target with:"
Write-Host "  .\run-server.ps1 -Port 8080 -Mode vulnerable -JavaExe '$java' -JavacExe '$javac'"
