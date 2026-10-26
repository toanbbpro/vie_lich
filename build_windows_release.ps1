param(
    [string]$Version = "2.1.0"
)

$ErrorActionPreference = "Stop"

Write-Host "Building VIE Lich Windows v$Version..." -ForegroundColor Cyan

# 1. Build Flutter release
Write-Host "[1/5] Flutter build..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed" }

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }

# 2. Build Go helper
Write-Host "[2/5] Building Go Helper..." -ForegroundColor Yellow
Push-Location windows_helper

# 2.1. Cập nhật version trong winres.json (nếu có)
if (Test-Path "winres.json") {
    $json = Get-Content winres.json -Raw | ConvertFrom-Json
    $json.RT_VERSION.APP.'#1'.'0000'.fixed.file_version = "$Version.0"
    $json.RT_VERSION.APP.'#1'.'0000'.fixed.product_version = "$Version.0"
    $json | ConvertTo-Json -Depth 10 | Set-Content winres.json
    Write-Host "   -> Updated version in winres.json to $Version.0"
}

# 2.2. Generate resource file (icon, version) nếu có winres.json
if (Test-Path "winres.json") {
    Write-Host "   -> Generating Windows resources (icon, version)..."
    go-winres make
    if ($LASTEXITCODE -ne 0) { 
        Pop-Location
        throw "go-winres make failed. Kiểm tra lại file icon (nên dùng .png thay vì .ico)." 
    }
}

# 2.3. Build helper chuẩn x64
$env:GOOS = "windows"
$env:GOARCH = "amd64"
go build -ldflags="-s -w -H windowsgui" -o vie_lich_helper.exe main.go
if ($LASTEXITCODE -ne 0) { 
    Pop-Location
    throw "go build helper failed" 
}
Pop-Location

# 3. Copy helper vao output
Write-Host "[3/5] Copying helper to output..." -ForegroundColor Yellow
$releaseDir = "build\windows\x64\runner\Release"
Copy-Item "windows_helper\vie_lich_helper.exe" "$releaseDir\" -Force

# 4. Prepare dist folder
Write-Host "[4/5] Preparing dist folder..." -ForegroundColor Yellow
if (Test-Path dist) { Remove-Item dist -Recurse -Force }
New-Item -ItemType Directory -Path dist | Out-Null

$folderName = "VIE_Lich_v${Version}_windows"
$stagingDir = "dist\$folderName"
New-Item -ItemType Directory -Path $stagingDir | Out-Null

Copy-Item -Path "$releaseDir\*" -Destination $stagingDir -Recurse -Force

# 5. Zip folder staging
Write-Host "[5/5] Zipping..." -ForegroundColor Yellow
$zipPath = "dist\$folderName.zip"
Compress-Archive -Path $stagingDir -DestinationPath $zipPath -Force

# Xoa staging folder (chi giu zip)
Remove-Item $stagingDir -Recurse -Force

$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "Done: $zipPath (${sizeMB} MB)" -ForegroundColor Green
Write-Host "Upload file nay len GitHub Release" -ForegroundColor Yellow