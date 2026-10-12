param([string]$Version = '1.0.4')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifactRoot = Join-Path $projectRoot 'artifacts'
$packagingRoot = Join-Path $projectRoot '.packaging'
[System.IO.Directory]::CreateDirectory($artifactRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($packagingRoot) | Out-Null

# 从项目本身读取文件清单，遵循 .gitignore，排除编译产物与打包缓存。
Push-Location $projectRoot
try {
    $sourceNames = @(& rg --files --hidden --no-require-git -g '!artifacts/**' -g '!.packaging/**' -g '!.dart_tool/**' -g '!build/**' -g '!.git/**')
    if ($LASTEXITCODE -ne 0) { throw '无法读取项目文件清单' }
} finally { Pop-Location }

$sourceZip = Join-Path $artifactRoot "ClassManager-v$Version-source.zip"
$zipStream = [System.IO.File]::Open($sourceZip, [System.IO.FileMode]::Create)
$sourceArchive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in $sourceNames) {
        $entryName = 'ClassManager-New/' + $name.Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($sourceArchive, (Join-Path $projectRoot $name), $entryName) | Out-Null
    }
} finally { $sourceArchive.Dispose(); $zipStream.Dispose() }

$builtApk = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'
if (Test-Path -LiteralPath $builtApk) {
    Copy-Item -LiteralPath $builtApk -Destination (Join-Path $artifactRoot "ClassManager-v$Version.apk")
}

$baselineRoot = Join-Path $packagingRoot 'base'
if (Test-Path -LiteralPath $baselineRoot) {
    $snapshotName = 'snapshot-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss-fff')
    $snapshotRoot = Join-Path $packagingRoot $snapshotName
    foreach ($name in $sourceNames) {
        $snapshotFile = [System.IO.Path]::GetFullPath((Join-Path $snapshotRoot $name))
        if (-not $snapshotFile.StartsWith($snapshotRoot + [System.IO.Path]::DirectorySeparatorChar)) { throw '非法打包路径' }
        [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($snapshotFile)) | Out-Null
        Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $snapshotFile
    }
    Push-Location $packagingRoot
    try {
        $patchLines = & git diff --no-index --src-prefix=a/ --dst-prefix=b/ -- base $snapshotName
        if ($LASTEXITCODE -gt 1) { throw '生成补丁失败' }
        $patchText = ($patchLines -join "`n").Replace('a/base/', 'a/').Replace("b/$snapshotName/", 'b/').Replace("a/$snapshotName/", 'a/').Replace('b/base/', 'b/') + "`n"
        $patchFile = Join-Path $artifactRoot "ClassManager-v1.0.3-to-v$Version.patch"
        [System.IO.File]::WriteAllText($patchFile, $patchText, [System.Text.UTF8Encoding]::new($false))
        Push-Location $baselineRoot
        try {
            & git apply --check $patchFile
            if ($LASTEXITCODE -ne 0) { throw '补丁应用检查失败' }
        } finally { Pop-Location }
    } finally { Pop-Location }
} else {
    Write-Output '未找到 .packaging/base 基线，仅打包源码与安装包。'
}

$global:LASTEXITCODE = 0
Get-ChildItem -LiteralPath $artifactRoot -File | Select-Object Name, Length
