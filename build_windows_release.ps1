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
$goBin = "$((go env GOPATH))\bin"
if ((Test-Path $goBin) -and ($env:PATH -notlike "*$goBin*")) {
    $env:PATH = "$goBin;$env:PATH"
}
Push-Location windows_helper

# 2.1. Tìm file winres.json — hỗ trợ cả 2 vị trí:
#   - winres\winres.json (mặc định của `go-winres init`)
#   - winres.json       (nếu user tự đặt ở thư mục gốc)
$winresPath = $null
if (Test-Path "winres\winres.json") {
    $winresPath = "winres\winres.json"
} elseif (Test-Path "winres.json") {
    $winresPath = "winres.json"
}

Write-Host "   -> winresPath: $winresPath"

# 2.2. Cập nhật version trong winres.json
if ($winresPath) {
    try {
        # Đọc bằng .NET (tự handle BOM nếu có)
        $resolvedPath = (Resolve-Path $winresPath).Path
        $rawContent = [System.IO.File]::ReadAllText($resolvedPath)
        $json = $rawContent | ConvertFrom-Json

        $rtVersionRoot = $json.RT_VERSION

        if ($rtVersionRoot) {
            # Lấy key đầu tiên (thường là "#1") — không hard-code
            $firstKey = $rtVersionRoot.PSObject.Properties.Name | Select-Object -First 1
            if ($firstKey) {
                $versionBlock = $rtVersionRoot.$firstKey.'0000'

                if ($versionBlock -and $versionBlock.fixed) {
                    $versionBlock.fixed.file_version    = "$Version.0"
                    $versionBlock.fixed.product_version = "$Version.0"
                }

                if ($versionBlock -and $versionBlock.info) {
                    $langKey = $versionBlock.info.PSObject.Properties.Name | Select-Object -First 1
                    if ($langKey) {
                        $infoBlock = $versionBlock.info.$langKey
                        if ($infoBlock.FileVersion)    { $infoBlock.FileVersion    = "$Version.0" }
                        if ($infoBlock.ProductVersion) { $infoBlock.ProductVersion = "$Version.0" }
                    }
                }

                # QUAN TRỌNG: Ghi file KHÔNG BOM.
                # PowerShell 5.1 `Set-Content -Encoding UTF8` luôn thêm BOM (EF BB BF)
                # → go-winres (Go json parser) không đọc được → lỗi `invalid character '\ufeff'`.
                # Dùng .NET WriteAllText với UTF8Encoding(false) để bypass.
                $newContent = $json | ConvertTo-Json -Depth 10
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($resolvedPath, $newContent, $utf8NoBom)

                Write-Host "   -> Updated version in $winresPath to $Version.0"
            } else {
                Write-Host "   -> WARNING: RT_VERSION trong, giu nguyen version" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   -> WARNING: Khong co RT_VERSION block, giu nguyen version" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   -> WARNING: Loi parse winres.json: $_" -ForegroundColor Yellow
    }
}

# 2.3. Xoá file .syso cũ (tránh build pick up file cũ khi winres.json không thay đổi)
Get-ChildItem -Filter "*.syso" -ErrorAction SilentlyContinue | Remove-Item -Force

# 2.4. Generate resource file (icon, version)
if ($winresPath) {
    Write-Host "   -> Generating Windows resources (icon, version)..."
    go-winres make
    if ($LASTEXITCODE -ne 0) { 
        Pop-Location
        throw "go-winres make failed. Kiem tra file icon/winres.json." 
    }
    
    # Verify .syso được tạo
    $sysoFiles = Get-ChildItem -Filter "*.syso" -ErrorAction SilentlyContinue
    if ($sysoFiles.Count -eq 0) {
        Pop-Location
        throw "go-winres make chay thanh cong nhung khong tao .syso. Kiem tra winres.json."
    }
    Write-Host "   -> Generated: $($sysoFiles.Name -join ', ')"
}

# 2.5. Build helper chuẩn x64
$env:GOOS = "windows"
$env:GOARCH = "amd64"
go build -ldflags="-s -w -H windowsgui" -o vie_lich_helper.exe .
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