# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
# tools/build_llama_android.ps1
# Release-optimized, LTO + stripped build for llama_cpp_dart (arm64-v8a).
# Resolves ASK-2: unstripped debug .so files cause APK bloat & tok/s loss
# on Moto G 2025 fleet. Output replaces android/app/src/main/jniLibs/arm64-v8a/*.so
#
# Usage:
#   pwsh -ExecutionPolicy Bypass -File tools/build_llama_android.ps1
#   pwsh -File tools/build_llama_android.ps1 -LlamaSourceDir C:\llama.cpp
#   pwsh -File tools/build_llama_android.ps1 -NdkPath C:\android\sdk\ndk\28.2.13676358
#
# Prereqs: Android NDK 28.2+, CMake 3.22+, Ninja (bundled with NDK), llvm-strip
# EXIT CODES: 0 success, 1 NDK not found, 2 llama.cpp not found, 3 cmake failed, 4 strip failed

[CmdletBinding()]
param(
    [string]$LlamaSourceDir = "",
    [string]$NdkPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-Ndk {
    param([string]$Hint)
    if ($Hint -and (Test-Path "$Hint/build/cmake/android.toolchain.cmake")) { return (Resolve-Path $Hint).Path }
    foreach ($envVar in @($env:ANDROID_NDK_HOME, $env:NDK_HOME, $env:ANDROID_NDK)) {
        if ($envVar -and (Test-Path "$envVar/build/cmake/android.toolchain.cmake")) { return (Resolve-Path $envVar).Path }
    }
    $homeNdk = $env:ANDROID_HOME
    if ($homeNdk) {
        $candidates = Get-ChildItem -Path "$homeNdk/ndk" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($c in $candidates) {
            if (Test-Path "$($c.FullName)/build/cmake/android.toolchain.cmake") { return $c.FullName }
        }
        # also check ndk-bundle legacy
        if (Test-Path "$homeNdk/ndk-bundle/build/cmake/android.toolchain.cmake") { return "$homeNdk/ndk-bundle" }
    }
    # hard-coded fallback from this machine
    foreach ($p in @("C:\android\sdk\ndk\28.2.13676358", "C:\android\ndk\28.2.13676358")) {
        if (Test-Path "$p/build/cmake/android.toolchain.cmake") { return $p }
    }
    return $null
}

function Find-LlamaSource {
    param([string]$Hint)
    if ($Hint -and (Test-Path "$Hint/CMakeLists.txt")) { return (Resolve-Path $Hint).Path }
    $candidates = @(
        "$PSScriptRoot/../llama.cpp",
        "$PSScriptRoot/../../llama.cpp",
        "C:\llama.cpp",
        "$env:USERPROFILE\llama.cpp"
    )
    foreach ($c in $candidates) {
        if (Test-Path "$c/CMakeLists.txt") { return (Resolve-Path $c).Path }
    }
    return $null
}

$ndk = Find-Ndk -Hint $NdkPath
if (-not $ndk) {
    Write-Error "NDK not found. Set `$env:ANDROID_NDK_HOME or pass -NdkPath C:\android\sdk\ndk\28.2.*"
    exit 1
}
$toolchain = "$ndk/build/cmake/android.toolchain.cmake"
$stripBin = "$ndk/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip.exe"
if (-not (Test-Path $stripBin)) { $stripBin = "$ndk/toolchains/llvm/prebuilt/windows/bin/llvm-strip.exe" }

$llamaDir = Find-LlamaSource -Hint $LlamaSourceDir
if (-not $llamaDir) {
    Write-Error "llama.cpp source not found. Pass -LlamaSourceDir <path> where CMakeLists.txt lives."
    exit 2
}

$buildDir = Join-Path $llamaDir "build_android"
$outDir = Join-Path $PSScriptRoot "../android/app/src/main/jniLibs/arm64-v8a"
$outDir = (Resolve-Path $outDir -ErrorAction SilentlyContinue)?.Path
if (-not $outDir) { $outDir = Join-Path $PSScriptRoot "..\android\app\src\main\jniLibs\arm64-v8a" | Resolve-Path | Select-Object -ExpandProperty Path }

Write-Host "NDK: $ndk" -ForegroundColor Cyan
Write-Host "llama.cpp: $llamaDir" -ForegroundColor Cyan
Write-Host "build dir: $buildDir" -ForegroundColor Cyan
Write-Host "output: $outDir" -ForegroundColor Cyan
if (-not (Test-Path $stripBin)) { Write-Warning "llvm-strip not found at $stripBin — stripping will be skipped (still Release+LTO)." }

# Ensure output dir exists
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

Push-Location $buildDir
try {
    Write-Host "`n[1/4] CMake configure (Release, LTO, arm64-v8a, api 24)..." -ForegroundColor Yellow
    $cmakeArgs = @(
        "-DCMAKE_TOOLCHAIN_FILE=`"$toolchain`"",
        "-DANDROID_ABI=arm64-v8a",
        "-DANDROID_PLATFORM=android-24",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_CXX_FLAGS=-flto=auto",
        "-DCMAKE_C_FLAGS=-flto=auto",
        "-DLLAMA_CURL=OFF",
        "-DLLAMA_BUILD_COMMON=ON",
        "-DBUILD_SHARED_LIBS=ON",
        "-DLLAMA_NATIVE=OFF",
        $llamaDir
    )
    $cmd = "cmake $($cmakeArgs -join ' ')"
    Write-Host $cmd
    $proc = Start-Process -FilePath "cmake" -ArgumentList $cmakeArgs -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) { Write-Error "CMake configure failed (exit $($proc.ExitCode))"; exit 3 }

    Write-Host "`n[2/4] Building (cmake --build . --config Release)..." -ForegroundColor Yellow
    $proc = Start-Process -FilePath "cmake" -ArgumentList @("--build", ".", "--config", "Release", "-j", "8") -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) { Write-Error "CMake build failed (exit $($proc.ExitCode))"; exit 3 }

    Write-Host "`n[3/4] Stripping .so files with llvm-strip --strip-all..." -ForegroundColor Yellow
    $soFiles = Get-ChildItem -Path $buildDir -Recurse -Filter "*.so" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "CMakeFiles" }
    if (-not $soFiles -or $soFiles.Count -eq 0) {
        # Fallback: check common output locations
        $soFiles = Get-ChildItem -Path "$buildDir/src", "$buildDir/common", "$buildDir/ggml/src", "$buildDir" -Filter "*.so" -ErrorAction SilentlyContinue
    }
    if ($soFiles.Count -eq 0) {
        Write-Warning "No .so files found under $buildDir — check build output manually."
    } else {
        foreach ($so in $soFiles) {
            $before = $so.Length
            if (Test-Path $stripBin) {
                $p = Start-Process -FilePath $stripBin -ArgumentList @("--strip-all", "`"$($so.FullName)`"") -NoNewWindow -Wait -PassThru
                if ($p.ExitCode -ne 0) { Write-Warning "strip failed for $($so.Name) (exit $($p.ExitCode))" }
                $after = (Get-Item $so.FullName).Length
                $saved = $before - $after
                Write-Host "  stripped $($so.Name): $before -> $after bytes (saved $saved)" -ForegroundColor DarkGray
            } else {
                Write-Host "  (no strip) $($so.Name): $before bytes" -ForegroundColor DarkGray
            }
        }
    }

    Write-Host "`n[4/4] Copying optimized .so files to $outDir ..." -ForegroundColor Yellow
    $targets = @("libllama.so", "libggml.so", "libggml-base.so", "libggml-cpu.so", "libmtmd.so", "libllama-common.so")
    $copied = 0
    foreach ($name in $targets) {
        $src = $soFiles | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $src) { $src = Get-ChildItem -Path $buildDir -Recurse -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if ($src) {
            Copy-Item -Path $src.FullName -Destination (Join-Path $outDir $name) -Force
            $sz = (Get-Item (Join-Path $outDir $name)).Length
            Write-Host "  copied $name -> $sz bytes" -ForegroundColor Green
            $copied++
        } else {
            Write-Warning "  missing $name — not copied (build may have renamed it)"
        }
    }
    # Also copy any other .so that appeared (future-proof)
    foreach ($so in $soFiles) {
        if ($targets -notcontains $so.Name) {
            Copy-Item -Path $so.FullName -Destination (Join-Path $outDir $so.Name) -Force
            Write-Host "  copied extra $($so.Name)" -ForegroundColor DarkGray
            $copied++
        }
    }

    Write-Host "`nDone. $copied file(s) in $outDir" -ForegroundColor Green
    Get-ChildItem $outDir -Filter "*.so" | ForEach-Object { Write-Host "  $($_.Name)  $($_.Length) bytes" }
    Write-Host "`nNext: flutter pub get; flutter analyze; flutter test; rebuild APK in Android Studio (Release) and measure tok/s on Moto G 2025." -ForegroundColor Cyan
}
finally {
    Pop-Location
}
