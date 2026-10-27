# Genera las builds de distribucion en ./build (carpeta ignorada por git):
#   1) build/dungeon-soldier-prototipo-4.love        -> paquete LOVE (zip con main.lua en la raiz)
#   2) build/web/                                    -> version HTML5 (love.js, modo compatibilidad)
#   3) build/dungeon-soldier-prototipo-4-web.zip     -> ZIP listo para subir a itch.io (index.html en la raiz)
#
# Uso (desde cualquier carpeta, en PowerShell):
#   powershell -ExecutionPolicy Bypass -File tools/build_web.ps1
#
# Requisitos: Node.js/npm (para love.js). Si no se pasa -LoveJsIndex se usa
# "npx love.js@11.4.1", que descarga la herramienta de npm la primera vez.
# -LoveJsIndex permite apuntar a un node_modules/love.js/index.js ya instalado.
#
# Modo compatibilidad (-c): itch.io no envia los headers COOP/COEP por defecto,
# asi que la version con threads (SharedArrayBuffer) no corre ahi.

param(
    [string]$LoveJsIndex = "",
    [int]$MemoryBytes = 67108864,
    [string]$Title = "Dungeon Soldier - Prototipo 4",
    [string]$Name = "dungeon-soldier-prototipo-4"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root "build"
$lovePath = Join-Path $build "$Name.love"
$webDir = Join-Path $build "web"
$webZip = Join-Path $build "$Name-web.zip"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-ZipFromFiles($zipPath, $files) {
    # $files: lista de objetos { Full = ruta absoluta; Rel = ruta dentro del zip }.
    # Se escribe a mano para forzar '/' como separador (PhysFS/LOVE y itch.io lo exigen).
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in $files) {
            $entry = $f.Rel -replace '\\', '/'
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.Full, $entry, [System.IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $zip.Dispose() }
}

New-Item -ItemType Directory -Force -Path $build | Out-Null

# 1) Paquete .love: solo lo que el juego necesita en runtime.
$files = @()
foreach ($f in "main.lua", "conf.lua") {
    $files += [pscustomobject]@{ Full = (Join-Path $root $f); Rel = $f }
}
foreach ($d in "src", "lib", "Assets") {
    Get-ChildItem -Path (Join-Path $root $d) -Recurse -File |
        Where-Object { $_.Extension -ne ".code-workspace" } |
        ForEach-Object { $files += [pscustomobject]@{ Full = $_.FullName; Rel = $_.FullName.Substring($root.Length + 1) } }
}
New-ZipFromFiles $lovePath $files
Write-Host ("[1/3] {0} ({1} archivos)" -f $lovePath, $files.Count)

# 2) Version web con love.js
if (Test-Path $webDir) { Remove-Item $webDir -Recurse -Force }
$loveJsArgs = @("-c", "-m", "$MemoryBytes", "-t", $Title, $lovePath, $webDir)
if ($LoveJsIndex -ne "") {
    & node $LoveJsIndex @loveJsArgs
} else {
    & npx --yes "love.js@11.4.1" @loveJsArgs
}
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $webDir "index.html"))) {
    throw "love.js no genero build/web/index.html"
}
Write-Host "[2/3] $webDir"

# 3) ZIP para itch.io (index.html en la raiz del zip)
$webFiles = Get-ChildItem -Path $webDir -Recurse -File |
    ForEach-Object { [pscustomobject]@{ Full = $_.FullName; Rel = $_.FullName.Substring($webDir.Length + 1) } }
New-ZipFromFiles $webZip $webFiles
Write-Host ("[3/3] {0} ({1:N1} MB)" -f $webZip, ((Get-Item $webZip).Length / 1MB))
