param(
    [string]$Version = "2.0.0"
)

$ErrorActionPreference = "Stop"

Write-Host "Building VIE Lich Windows..." -ForegroundColor Cyan

# 1. Build Flutter release
flutter clean
flutter pub get
flutter build windows --release

# 2. Build Go helper
Push-Location windows_helper
go build -o vie_lich_helper.exe main.go
Pop-Location

# 3. Copy helper vao output
$releaseDir = "build\windows\x64\runner\Release"
Copy-Item "windows_helper\vie_lich_helper.exe" "$releaseDir\" -Force

# 4. Prepare dist folder
if (Test-Path dist) { Remove-Item dist -Recurse -Force }
New-Item -ItemType Directory -Path dist | Out-Null

# 5. Tao staging folder (folder nay se thanh root entry trong zip)
$folderName = "VIE_Lich_v${Version}_windows"
$stagingDir = "dist\$folderName"
New-Item -ItemType Directory -Path $stagingDir | Out-Null

# 6. Copy toan bo file tu Release vao staging
Copy-Item -Path "$releaseDir\*" -Destination $stagingDir -Recurse -Force

# 7. Zip folder staging (bao gom chinh folder do lam root)
$zipPath = "dist\$folderName.zip"
Compress-Archive -Path $stagingDir -DestinationPath $zipPath -Force

# 8. Xoa staging folder (chi giu zip)
Remove-Item $stagingDir -Recurse -Force

$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "Done: $zipPath (${sizeMB} MB)" -ForegroundColor Green
Write-Host "Upload file nay len GitHub Release" -ForegroundColor Yellow