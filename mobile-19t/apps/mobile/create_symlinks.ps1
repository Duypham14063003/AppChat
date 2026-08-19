$pluginDir = "windows\flutter\ephemeral\.plugin_symlinks"
New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null

$plugins = @{
    "firebase_core" = "C:\Users\ADMIN\AppData\Local\Pub\Cache\hosted\pub.dev\firebase_core-4.5.0"
    "flutter_secure_storage_windows" = "C:\Users\ADMIN\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_secure_storage_windows-3.1.2"
    "sqlite3_flutter_libs" = "C:\Users\ADMIN\AppData\Local\Pub\Cache\hosted\pub.dev\sqlite3_flutter_libs-0.5.42"
}

foreach ($plugin in $plugins.GetEnumerator()) {
    $linkPath = Join-Path $pluginDir $plugin.Key
    $targetPath = $plugin.Value
    
    if (Test-Path $linkPath) {
        Remove-Item $linkPath -Force -Recurse
    }
    
    try {
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath -ErrorAction Stop | Out-Null
        Write-Host "Created symlink for $($plugin.Key)"
    } catch {
        Write-Host "Failed to create symlink for $($plugin.Key), trying junction..."
        New-Item -ItemType Junction -Path $linkPath -Target $targetPath | Out-Null
        Write-Host "Created junction for $($plugin.Key)"
    }
}

Write-Host "Done!"

