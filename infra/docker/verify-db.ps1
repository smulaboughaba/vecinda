$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
$migrationFile = Join-Path $repoRoot "backend\migrations\0001_initial_schema.sql"
$testsFile = Join-Path $repoRoot "backend\tests\sql_negative_checks.sql"

Write-Host "[1/5] Comprobando Docker Desktop..."
docker info --format "{{.ServerVersion}}" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker Desktop no está iniciado. Ábrelo y vuelve a ejecutar este script."
    exit 1
}

Write-Host "[2/5] Levantando PostgreSQL 16 (docker-compose)..."
docker compose -f $composeFile up -d --wait
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[3/5] Recreando base de datos limpia 'vecinda_test'..."
docker exec vecinda-postgres psql -U vecinda_admin -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS vecinda_test;"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
docker exec vecinda-postgres psql -U vecinda_admin -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE vecinda_test;"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[4/5] Aplicando migración 0001_initial_schema.sql..."
Get-Content -Raw -Encoding UTF8 $migrationFile | docker exec -i vecinda-postgres psql -U vecinda_admin -d vecinda_test -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[5/5] Ejecutando pruebas negativas SQL..."
Get-Content -Raw -Encoding UTF8 $testsFile | docker exec -i vecinda-postgres psql -U vecinda_admin -d vecinda_test -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK: Migración y suite negativa SQL verificadas en PostgreSQL 16." -ForegroundColor Green
