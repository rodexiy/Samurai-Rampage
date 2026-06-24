$ErrorActionPreference = "Stop"
$ToolDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $ToolDirectory

$Url = "http://127.0.0.1:4317"
Write-Host "Iniciando Samurai Rampage Index Studio..." -ForegroundColor Red
Write-Host "O site ficará disponível apenas nesta máquina: $Url" -ForegroundColor DarkGray

Start-Job -ScriptBlock {
    param($TargetUrl)
    Start-Sleep -Milliseconds 900
    Start-Process $TargetUrl
} -ArgumentList $Url | Out-Null

node server.mjs
