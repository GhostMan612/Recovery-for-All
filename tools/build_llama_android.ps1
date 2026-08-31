# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================

[CmdletBinding()]
param (
    [string]$NdkPath = "",
    [string]$LlamaSourceDir = "llama.cpp",
    [string]$OutputDir = "android/app/src/main/jniLibs/arm64-v8a"
)

$ErrorActionPreference = "Stop"

Write-Host "=== llama.cpp Android Release Build (arm64-v8a) ===" -ForegroundColor Cyan

# 1. Locate Android NDK
if (-not $NdkPath) {
    if ($env:ANDROID_NDK_HOME -and (Test-Path $env:ANDROID_NDK_HOME)) {
        $NdkPath = $env:ANDROID_NDK_HOME
    } elseif ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\ndk")) {
        $ndkDirs = Get-ChildItem "$env:ANDROID_HOME\ndk" | Sort-Object Name -Descending
        if ($ndkDirs.Count -gt 0) { $NdkPath = $ndkDirs[0].FullName }
    } elseif (Test-Path "C:\android\sdk\ndk") {
        $ndkDirs = Get-ChildItem "C:\android\sdk\ndk" | Sort-Object Name -Descending
        if ($ndkDirs.Count -gt 0) { $NdkPath = $ndkDirs[0].FullName }
    }
}

if (-not $NdkPath -or -not (Test-Path $NdkPath)) {
    Write-Error "Android NDK not found. Please set ANDROID_NDK_HOME or pass -NdkPath 'C:\android\sdk\ndk\<version>'."
    exit 1
}
Write-Host "Using NDK: $NdkPath" -ForegroundColor Green

$toolchainFile = "$NdkPath\build\cmake\android.toolchain.cmake"
if (-not (Test-Path $toolchainFile)) {
    Write-Error "CMake toolchain file missing at: $toolchainFile"
    exit 1
}

# 2. Locate llvm-strip
$llvmStrip = Get-ChildItem -Path "$NdkPath\toolchains\llvm\prebuilt" -Recurse -Filter "llvm-strip.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $llvmStrip) {
    Write-Warning "llvm-strip.exe not found in NDK. Binaries will not be stripped."
} else {
    Write-Host "Using Strip Tool: $($llvmStrip.FullName)" -ForegroundColor Green
}

# 3. Setup Directories
$projectRoot = Get-Location
$llamaDir = Join-Path $projectRoot $LlamaSourceDir
$buildDir = Join-Path $llamaDir "build_android"
$outDir = Join-Path $projectRoot $OutputDir

if (-not (Test-Path $llamaDir)) {
    Write-Warning "Source directory '$LlamaSourceDir' not found in project root. Skipping C++ compilation."
    Write-Host "Prebuilt .so files in $OutputDir will remain active." -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir -Force | Out-Null }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

# 4. Configure & Build CMake
Push-Location $buildDir
try {
    Write-Host "`n[1/3] Configuring CMake Release with LTO (arm64-v8a, API 24)..." -ForegroundColor Cyan
    cmake -G "Ninja" `
        -DCMAKE_TOOLCHAIN_FILE="$toolchainFile" `
        -DANDROID_ABI="arm64-v8a" `
        -DANDROID_PLATFORM="android-24" `
        -DCMAKE_BUILD_TYPE="Release" `
        -flto=auto `
        -DLLAMA_CURL=OFF `
        -DLLAMA_BUILD_COMMON=ON `
        -DBUILD_SHARED_LIBS=ON `
        ..

    Write-Host "`n[2/3] Compiling Release binaries..." -ForegroundColor Cyan
    cmake --build . --config Release -j 8

    # 5. Strip and Copy .so files
    Write-Host "`n[3/3] Stripping and copying .so files to jniLibs..." -ForegroundColor Cyan
    $soFiles = Get-ChildItem -Path . -Filter "*.so" -Recurse
    foreach ($file in $soFiles) {
        if ($llvmStrip) {
            Write-Host "Stripping: $($file.Name)"
            & $llvmStrip.FullName --strip-all $file.FullName
        }
        Copy-Item -Path $file.FullName -Destination (Join-Path $outDir $file.Name) -Force
        Write-Host "Copied -> $OutputDir/$($file.Name)" -ForegroundColor Green
    }
} finally {
    Pop-Location
}

Write-Host "`nNative arm64-v8a Release build complete and synced to jniLibs." -ForegroundColor Green
