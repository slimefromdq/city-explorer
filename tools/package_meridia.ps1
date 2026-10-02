param(
    [Parameter(Mandatory=$true)][string]$EnginePath,
    [string]$OutputDirectory = 'tests/out/Meridia-Windows'
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
if (-not $releaseRoot.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Package output must remain inside the repository.'
}
if (Test-Path -LiteralPath $releaseRoot) { throw 'Choose a new output directory; existing packages are preserved.' }
$projectRoot = Join-Path $releaseRoot 'project'
New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
$files = git -C $repoRoot ls-files --cached --others --exclude-standard
foreach ($file in $files) {
    if ($file.StartsWith('docs/') -or $file.StartsWith('tests/') -or $file.StartsWith('tools/')) { continue }
    $source = Join-Path $repoRoot $file
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    $destination = Join-Path $projectRoot $file
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
}
# Class-name registration is needed when running a source package without an
# editor import. All imported resources are copied so the runtime is self-contained.
New-Item -ItemType Directory -Path (Join-Path $projectRoot '.godot') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot '.godot/global_script_class_cache.cfg') -Destination (Join-Path $projectRoot '.godot/global_script_class_cache.cfg')
Copy-Item -LiteralPath (Join-Path $repoRoot '.godot/imported') -Destination (Join-Path $projectRoot '.godot/imported') -Recurse
foreach ($remap in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'walk') -Filter '*.import' -File) {
    Copy-Item -LiteralPath $remap.FullName -Destination (Join-Path $projectRoot 'walk')
}
Copy-Item -LiteralPath $EnginePath -Destination (Join-Path $releaseRoot 'Meridia.exe')
Copy-Item -LiteralPath (Join-Path $repoRoot 'tests/out/GODOT-LICENSE.txt') -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $repoRoot 'tests/out/GODOT-THIRD-PARTY.json') -Destination $releaseRoot
$launcher = '@echo off' + "`r`n" + 'cd /d "%~dp0"' + "`r`n" + 'start "Meridia City" "Meridia.exe" --path "project" res://walk/Meridia.tscn' + "`r`n"
[IO.File]::WriteAllText((Join-Path $releaseRoot 'Play Meridia.cmd'), $launcher)
[IO.File]::WriteAllText((Join-Path $releaseRoot 'README.txt'), "Meridia City - exploration milestone`r`n`r`nExtract the entire ZIP, then double-click Play Meridia.cmd.`r`nWindows 64-bit, Vulkan-capable GPU. Runtime: Godot 4.7.2 Forward+.`r`n`r`nWASD move, mouse look, Shift run, Space jump, M walking map.`r`nEsc releases mouse. F1 returns to the launch screen.`r`nStation, trains, tower, lake loop and civic terraces are connected.`r`nCivic interiors are closed; stay on marked exploration paths.`r`n`r`nIncludes the Godot editor runtime to avoid requiring a separate installation.`r`nGodot and third-party runtime licenses are included alongside this file.`r`n")
$zip = $releaseRoot + '.zip'
if (Test-Path -LiteralPath $zip) { throw 'Existing ZIP is preserved; choose a new output directory.' }
Compress-Archive -LiteralPath $releaseRoot -DestinationPath $zip -CompressionLevel Optimal
Get-FileHash -LiteralPath $zip -Algorithm SHA256
