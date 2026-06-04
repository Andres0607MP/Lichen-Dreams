# Script para iniciar Lichen Dreams Backend y Frontend
# Uso: .\start-project.ps1

$projectRoot = "C:\Users\mance\Documents\Steffi\Lichen-Dreams"

Write-Host "================================" -ForegroundColor Green
Write-Host "🚀 Iniciando Lichen Dreams" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""

# Verificar que Python está disponible
Write-Host "✓ Verificando Python..." -ForegroundColor Cyan
$pythonCheck = python --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Python no está instalado o no está en PATH" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Python encontrado: $pythonCheck" -ForegroundColor Green

# Verificar que MySQL está disponible
Write-Host "✓ Verificando MySQL..." -ForegroundColor Cyan
$mysqlCheck = mysql --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ MySQL encontrado: $mysqlCheck" -ForegroundColor Green
} else {
    Write-Host "⚠️  MySQL no está en PATH (puedes crearlo manualmente con MySQL Workbench)" -ForegroundColor Yellow
}

# Verificar que Flutter está disponible
Write-Host "✓ Verificando Flutter..." -ForegroundColor Cyan
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Flutter encontrado" -ForegroundColor Green
} else {
    Write-Host "⚠️  Flutter no está en PATH" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Iniciando Backend (Terminal 1)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Crear nueva ventana PowerShell para Backend
$backendScript = @"
cd '$projectRoot\backend'
`$venv = Join-Path -Path (Get-Location) -ChildPath 'venv'
if (Test-Path `$venv) {
    & '.\venv\Scripts\Activate.ps1'
    uvicorn main:app --reload --host 127.0.0.1 --port 8000
} else {
    Write-Host 'Error: venv no existe. Ejecuta:' -ForegroundColor Red
    Write-Host 'python -m venv venv' -ForegroundColor Yellow
    Write-Host '.\venv\Scripts\Activate.ps1' -ForegroundColor Yellow
    Write-Host 'pip install -r requirements.txt' -ForegroundColor Yellow
    pause
}
"@

Start-Process powershell -ArgumentList "-NoExit -Command $backendScript" -WindowStyle Normal -PassThru

Write-Host ""
Write-Host "✓ Terminal del backend abierta" -ForegroundColor Green
Write-Host "Espera 5 segundos para que se inicie..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Iniciando Frontend (Terminal 2)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Crear nueva ventana PowerShell para Frontend
$frontendScript = @"
cd '$projectRoot\frontend'
Write-Host 'Ejecutando Flutter...' -ForegroundColor Green
flutter run
"@

Start-Process powershell -ArgumentList "-NoExit -Command $frontendScript" -WindowStyle Normal -PassThru

Write-Host ""
Write-Host "✓ Terminal del frontend abierta" -ForegroundColor Green
Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "✅ PROYECTO INICIADO" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Backend: http://127.0.0.1:8000" -ForegroundColor Cyan
Write-Host "Swagger: http://127.0.0.1:8000/docs" -ForegroundColor Cyan
Write-Host ""
Write-Host "Presiona Enter para cerrar esta ventana..." -ForegroundColor Yellow
Read-Host
