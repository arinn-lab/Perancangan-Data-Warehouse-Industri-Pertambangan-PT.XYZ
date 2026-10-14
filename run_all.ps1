# run_all.ps1
# Menjalankan seluruh pipeline dari nol dengan satu perintah:
#   .env -> SQL Server -> skema (init-scripts) -> ETL (standalone_etl.py lewat run_etl.py) -> validasi (tests/validate.sql)
#
# Cara pakai (Windows PowerShell, Docker Desktop harus sudah running):
#   powershell -ExecutionPolicy Bypass -File .\run_all.ps1

$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot
$compose = "docker-compose.lite.yml"

function Step($text) {
    Write-Host ""
    Write-Host "=== $text ===" -ForegroundColor Cyan
}

Step "0. Siapkan .env"
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host ".env dibuat dari .env.example"
}
$envText = Get-Content ".env" -Raw
if ($envText -notmatch "(?m)^MSSQL_SA_PASSWORD=.+") {
    throw "MSSQL_SA_PASSWORD belum diisi di .env"
}
$defaults = [ordered]@{
    MSSQL_HOST = "localhost"
    MSSQL_PORT = "1433"
    MSSQL_USER = "sa"
    MSSQL_DB   = "PTXYZ_DataWarehouse"
}
foreach ($k in $defaults.Keys) {
    if ($envText -notmatch ("(?m)^" + $k + "=")) {
        Add-Content ".env" ("`n" + $k + "=" + $defaults[$k])
    }
}
New-Item -ItemType Directory -Force -Path "logs", "tests" | Out-Null
$db = ((Select-String -Path ".env" -Pattern '^MSSQL_DB=(.+)$').Matches[0].Groups[1].Value).Trim()

Step "1. Bersihkan lingkungan lama (hanya milik proyek ini)"
docker compose -f $compose down -v --remove-orphans
Remove-Item "logs\etl_execution.log" -ErrorAction SilentlyContinue

Step "2. Nyalakan SQL Server, buat skema, lalu jalankan ETL"
docker compose -f $compose up -d
if ($LASTEXITCODE -ne 0) {
    throw "docker compose up gagal (cek: docker compose -f $compose logs db_init)"
}

Step "3. Menunggu ETL selesai (beberapa menit)"
$tries = 0
while (-not (docker ps -a --filter "name=ptxyz_etl" --format "{{.Names}}")) {
    Start-Sleep -Seconds 5
    $tries++
    if ($tries -gt 60) { throw "Container ETL tidak muncul" }
}
$code = (docker wait ptxyz_etl | Select-Object -First 1).ToString().Trim()
if ($code -ne "0") {
    docker logs --tail 30 ptxyz_etl
    throw "ETL gagal (exit code $code)"
}
Write-Host "ETL selesai. Log lengkap: logs\etl_execution.log"

Step "4. Validasi otomatis (tests/validate.sql)"
docker compose -f $compose exec -T -e DB=$db sqlserver bash -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -C -N -d $DB -b -W -i /tests/validate.sql'
$vcode = $LASTEXITCODE
if ($vcode -ne 0) {
    Write-Host "VALIDASI GAGAL" -ForegroundColor Red
    exit $vcode
}
Write-Host ""
Write-Host "SELESAI: pipeline dan validasi berhasil." -ForegroundColor Green