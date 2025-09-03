# PowerShell script to get SHA-1 fingerprint from release keystore

$keystorePath = "C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\bragging_rights_app\android\app\bragging-rights-release.keystore"
$alias = "bragging_rights"
$storepass = "bragging2024"

# Try different possible keytool locations
$keytoolPaths = @(
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe",
    "C:\Program Files\Java\jdk-21\bin\keytool.exe",
    "C:\Program Files\Java\jdk-17\bin\keytool.exe",
    "C:\Program Files\Java\jdk-11\bin\keytool.exe",
    "${env:JAVA_HOME}\bin\keytool.exe"
)

$keytool = $null
foreach ($path in $keytoolPaths) {
    if (Test-Path $path) {
        $keytool = $path
        Write-Host "Found keytool at: $keytool" -ForegroundColor Green
        break
    }
}

if (-not $keytool) {
    Write-Host "ERROR: Could not find keytool.exe" -ForegroundColor Red
    Write-Host "Please ensure Java JDK or Android Studio is installed" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $keystorePath)) {
    Write-Host "ERROR: Keystore not found at: $keystorePath" -ForegroundColor Red
    exit 1
}

Write-Host "`nGetting SHA-1 fingerprint from release keystore..." -ForegroundColor Cyan
Write-Host "=" * 60

# Run keytool command
& $keytool -list -v -keystore $keystorePath -alias $alias -storepass $storepass | Select-String "SHA1:", "SHA-256:", "Certificate fingerprints" | ForEach-Object {
    $line = $_.Line.Trim()
    if ($line -match "SHA1:") {
        Write-Host "`nRELEASE SHA-1 FINGERPRINT:" -ForegroundColor Green
        Write-Host $line -ForegroundColor Yellow
        Write-Host "`nCopy this SHA-1 value to Firebase Console!" -ForegroundColor Cyan
    } elseif ($line -match "SHA-256:") {
        Write-Host "`nRELEASE SHA-256 FINGERPRINT (also add this):" -ForegroundColor Green
        Write-Host $line -ForegroundColor Yellow
    } else {
        Write-Host $line
    }
}

Write-Host "`n" + "=" * 60
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Go to https://console.firebase.google.com" -ForegroundColor White
Write-Host "2. Select your 'bragging-rights-ea6e1' project" -ForegroundColor White
Write-Host "3. Click the gear icon -> Project Settings" -ForegroundColor White
Write-Host "4. Scroll down to 'Your apps' section" -ForegroundColor White
Write-Host "5. Find your Android app (com.braggingrights.bragging_rights_app)" -ForegroundColor White
Write-Host "6. Click 'Add fingerprint'" -ForegroundColor White
Write-Host "7. Paste the SHA-1 value shown above" -ForegroundColor White
Write-Host "8. Also add the SHA-256 if shown" -ForegroundColor White
Write-Host "9. Download the updated google-services.json" -ForegroundColor White
Write-Host "10. Replace android/app/google-services.json with the new file" -ForegroundColor White