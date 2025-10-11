# run_flutter_web.ps1
# Starts the directions proxy and the Flutter web app automatically.

$ErrorActionPreference = "Stop"

Write-Host "Starting directions proxy on port 3000..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoProfile","-WindowStyle","Hidden","-Command","cd `"$PSScriptRoot\directions-proxy`"; npm install --silent; $env:PORT=3000; node index.js" | Out-Null

Start-Sleep -Seconds 2

Write-Host "Launching Flutter web app (web-server on http://localhost:8080)..." -ForegroundColor Green
flutter run -d web-server --web-hostname localhost --web-port 8080
