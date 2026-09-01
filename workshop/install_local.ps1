param(
    [string]$TargetRoot = (Join-Path $env:USERPROFILE 'Zomboid\mods'),
    [switch]$IncludeKI5
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Join-Path $PSScriptRoot 'Contents\mods'
$modules = @('VehicleLivingSlots')
if ($IncludeKI5) { $modules += 'VehicleLivingSlotsKI5Campers' }

New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($module in $modules) {
    $source = Join-Path $sourceRoot $module
    $target = Join-Path $TargetRoot $module
    if (-not (Test-Path -LiteralPath (Join-Path $source 'mod.info'))) {
        throw "Missing source Mod: $module"
    }
    if (Test-Path -LiteralPath $target) {
        $backup = "$target.backup-$stamp"
        Move-Item -LiteralPath $target -Destination $backup
        Write-Host "Backed up $module to $backup"
    }
    Copy-Item -LiteralPath $source -Destination $target -Recurse
    if (-not (Test-Path -LiteralPath (Join-Path $target 'mod.info'))) {
        throw "Installation verification failed: $module"
    }
    Write-Host "Installed $module to $target"
}
