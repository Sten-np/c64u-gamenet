<#
.SYNOPSIS
    C64U GameNet build script (ca65/ld65 from the cc65 suite).

.DESCRIPTION
    Targets:
      build      Assemble and link all programs into build\*.prg (default).
      verify     Build, then structurally verify every generated .prg.
      clean      Remove the build\ directory.
      bootstrap  Download the official cc65 Windows snapshot into tools\cc65.
      toolchain  Print the toolchain that will be used.

    Toolchain lookup order:
      1. $env:CC65_HOME\bin
      2. tools\cc65\bin   (created by the 'bootstrap' target)
      3. ca65 / ld65 on PATH

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\build.ps1 verify
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('build', 'verify', 'clean', 'bootstrap', 'toolchain')]
    [string]$Target = 'build'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

$Root     = $PSScriptRoot
$BuildDir = Join-Path $Root 'build'
$ObjDir   = Join-Path $BuildDir 'obj'
$Config   = Join-Path $Root 'cfg\c64-prg.cfg'
$IncDir   = Join-Path $Root 'src\include'
$ToolsDir = Join-Path $Root 'tools\cc65'
$Cc65Url  = 'https://sourceforge.net/projects/cc65/files/cc65-snapshot-win64.zip/download'

# Common modules linked into every program.
$CommonSources = @('src\common\basic_stub.s')

# Programs: output name -> program-specific sources.
$Programs = [ordered]@{
    'hello' = @('src\hello\hello.s')
}

$CpuFlags = @('--cpu', '6502')

function Find-Tool([string]$Name) {
    $candidates = @()
    if ($env:CC65_HOME) { $candidates += (Join-Path $env:CC65_HOME "bin\$Name.exe") }
    $candidates += (Join-Path $ToolsDir "bin\$Name.exe")
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "Cannot find '$Name'. Set CC65_HOME, put cc65 on PATH, or run: .\build.ps1 bootstrap"
}

function Invoke-Tool([string]$Exe, [string[]]$Arguments) {
    Write-Host ("  " + [IO.Path]::GetFileName($Exe) + ' ' + ($Arguments -join ' '))
    & $Exe @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "$([IO.Path]::GetFileName($Exe)) failed with exit code $LASTEXITCODE" }
}

function Invoke-Bootstrap {
    if (Test-Path -LiteralPath (Join-Path $ToolsDir 'bin\ca65.exe')) {
        Write-Host "cc65 already present in $ToolsDir"
        return
    }
    $zip = Join-Path ([IO.Path]::GetTempPath()) 'cc65-snapshot-win64.zip'
    Write-Host "Downloading $Cc65Url"
    & curl.exe -sSfL -o $zip $Cc65Url
    if ($LASTEXITCODE -ne 0) { throw "Download failed (curl exit code $LASTEXITCODE)" }
    Write-Host ("SHA256: " + (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash)
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
    & tar.exe -xf $zip -C $ToolsDir
    if ($LASTEXITCODE -ne 0) { throw "Extraction failed (tar exit code $LASTEXITCODE)" }
    Remove-Item -LiteralPath $zip -Force
    Show-Toolchain
}

function Show-Toolchain {
    foreach ($t in 'ca65', 'ld65') {
        $exe = Find-Tool $t
        Write-Host "$t : $exe"
        & $exe --version
    }
}

function Invoke-Build {
    $ca65 = Find-Tool 'ca65'
    $ld65 = Find-Tool 'ld65'
    New-Item -ItemType Directory -Force -Path $ObjDir | Out-Null

    $built = @()
    foreach ($name in $Programs.Keys) {
        Write-Host "Building $name.prg"
        $objects = @()
        foreach ($src in ($CommonSources + $Programs[$name])) {
            $srcPath = Join-Path $Root $src
            $base    = [IO.Path]::GetFileNameWithoutExtension($src)
            $obj     = Join-Path $ObjDir "$name-$base.o"
            $lst     = Join-Path $ObjDir "$name-$base.lst"
            Invoke-Tool $ca65 ($CpuFlags + @('-g', '-I', $IncDir, '-l', $lst, '-o', $obj, $srcPath))
            $objects += $obj
        }
        $prg = Join-Path $BuildDir "$name.prg"
        Invoke-Tool $ld65 (@('-C', $Config,
                             '-m', (Join-Path $BuildDir "$name.map"),
                             '-Ln', (Join-Path $BuildDir "$name.lbl"),
                             '-o', $prg) + $objects)
        Write-Host ("  -> $prg (" + (Get-Item -LiteralPath $prg).Length + " bytes)")
        $built += $prg
    }
    return $built
}

# Structural check of a BASIC-stub .prg produced with cfg\c64-prg.cfg.
function Test-Prg([string]$Prg) {
    $b = [IO.File]::ReadAllBytes($Prg)
    $errors = @()
    if ($b.Length -lt 16) { throw "$Prg is too short ($($b.Length) bytes)" }

    $load = $b[0] + 256 * $b[1]
    if ($load -ne 0x0801) { $errors += ('load address is ${0:X4}, expected $0801' -f $load) }

    # BASIC line starts at file offset 2 (= memory $0801).
    $link = $b[2] + 256 * $b[3]
    $line = $b[4] + 256 * $b[5]
    if ($b[6] -ne 0x9E) { $errors += ('expected SYS token $9E, found ${0:X2}' -f $b[6]) }

    $i = 7; $digits = ''
    while ($i -lt $b.Length -and $b[$i] -ne 0) { $digits += [char]$b[$i]; $i++ }
    $lineEnd = $i                               # offset of the line's 0 terminator
    $expectedLink = $load + ($lineEnd + 1) - 2  # memory address after terminator
    if ($link -ne $expectedLink) { $errors += ('line link ${0:X4}, expected ${1:X4}' -f $link, $expectedLink) }
    if (($lineEnd + 2) -ge $b.Length -or $b[$lineEnd + 1] -ne 0 -or $b[$lineEnd + 2] -ne 0) {
        $errors += 'missing end-of-program marker (two zero bytes)'
    }
    if ($digits -notmatch '^\d+$') { $errors += "SYS argument '$digits' is not decimal" }

    # SYS target must equal the 'start' label and lie inside the file image.
    $lbl = [IO.Path]::ChangeExtension($Prg, '.lbl')
    $start = $null
    if (Test-Path -LiteralPath $lbl) {
        $m = Select-String -LiteralPath $lbl -Pattern '^al\s+([0-9A-Fa-f]+)\s+\.start$' | Select-Object -First 1
        if ($m) { $start = [Convert]::ToInt32($m.Matches[0].Groups[1].Value, 16) }
    }
    if ($null -eq $start) { $errors += "symbol 'start' not found in $lbl" }
    elseif ($digits -match '^\d+$' -and [int]$digits -ne $start) {
        $errors += ('SYS {0} does not match start=${1:X4} ({2})' -f $digits, $start, $start)
    }
    $endAddr = $load + $b.Length - 2
    if ($digits -match '^\d+$' -and ([int]$digits -lt $load -or [int]$digits -ge $endAddr)) {
        $errors += "SYS target $digits is outside the loaded image"
    }

    if ($errors.Count -gt 0) {
        throw ("Verification FAILED for ${Prg}:`n  " + ($errors -join "`n  "))
    }
    Write-Host ('  OK {0}: {1} bytes, load ${2:X4}-${3:X4}, {4} SYS {5}' -f `
        [IO.Path]::GetFileName($Prg), $b.Length, $load, ($endAddr - 1), $line, $digits)
}

switch ($Target) {
    'clean' {
        if (Test-Path -LiteralPath $BuildDir) { Remove-Item -LiteralPath $BuildDir -Recurse -Force }
        Write-Host 'Cleaned build\'
    }
    'bootstrap' { Invoke-Bootstrap }
    'toolchain' { Show-Toolchain }
    'build'     { Invoke-Build | Out-Null }
    'verify' {
        $prgs = Invoke-Build
        Write-Host 'Verifying'
        foreach ($p in $prgs) { Test-Prg $p }
    }
}
