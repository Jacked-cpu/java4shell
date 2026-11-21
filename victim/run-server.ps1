param(
    [int]$Port = 8080,
    [ValidateSet('vulnerable', 'no-intrinsic', 'no-avx512')]
    [string]$Mode = 'vulnerable',
    [int]$HotLoop = 20000,
    [string]$JavaExe = 'java',
    [string]$JavacExe = 'javac'
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'DecodeServer.java'
$cls = Join-Path $here 'DecodeServer.class'

if (-not (Test-Path $cls) -or (Get-Item $src).LastWriteTime -gt (Get-Item $cls).LastWriteTime) {
    Write-Host "Compiling $src"
    & $JavacExe $src
    if ($LASTEXITCODE -ne 0) { throw 'javac failed' }
}

$flags = @()
switch ($Mode) {
    'no-intrinsic' { $flags += '-XX:-UseBASE64Intrinsics' }
    'no-avx512'    { $flags += '-XX:UseAVX=2' }
}
$flags += '-XX:+PrintCompilation'

Write-Host "Mode=$Mode Port=$Port HotLoop=$HotLoop"
Write-Host "Flags: $($flags -join ' ')"
Write-Host 'Press Ctrl+C to stop.'
& $JavaExe @flags "-Dlab.hotloop=$HotLoop" -cp $here DecodeServer $Port
