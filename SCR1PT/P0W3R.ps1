#Requires -Version 5.1
#Requires -RunAsAdministrator

# SCR1PT-Category: SISTEMA Y ENERGIA
# SCR1PT-CategoryOrder: 30
# SCR1PT-Order: 10

<#
.SYNOPSIS
    P0W3R v1.0.0 - Configura las opciones esenciales de energia de Windows.

.DESCRIPTION
    P0W3R aplica una configuracion de energia pensada para equipos que deben
    permanecer disponibles y no suspenderse automaticamente.

    Cambios aplicados al plan de energia activo:
    - Hibernacion: desactivada.
    - Apagar pantalla con corriente: Nunca.
    - Apagar pantalla con bateria: Nunca.
    - Suspender con corriente: Nunca.
    - Suspender con bateria: Nunca.
    - Boton de encendido/apagado con corriente y bateria: No hacer nada.
    - Boton de suspension con corriente y bateria: No hacer nada.
    - Cerrar la tapa con corriente y bateria: No hacer nada.

    El script registra cada operacion y muestra un resumen final.

.PARAMETER NoPause
    Evita la pausa final. Util para ejecucion automatizada desde SCR1PT.

.EXAMPLE
    .\P0W3R.ps1

.EXAMPLE
    .\P0W3R.ps1 -NoPause
#>

[CmdletBinding()]
param(
    [switch]$NoPause
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ProjectName = 'P0W3R'
$Version = '1.0.0'

$LogRoot = Join-Path $env:ProgramData 'SCR1PT\Logs'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile = Join-Path $LogRoot "P0W3R-$Timestamp.log"

$script:SuccessCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0
$script:Changes = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

# GUIDs oficiales de las opciones de botones y tapa de Windows.
$SubButtonsGuid = '4f971e89-eebd-4455-a8de-9e59040e7347'

$ButtonActions = @(
    [pscustomobject]@{
        Label = 'Boton de encendido/apagado'
        Guid  = '7648efa3-dd9c-4e3e-b566-50f929386280'
    },
    [pscustomobject]@{
        Label = 'Boton de suspension'
        Guid  = '96996bc0-ad50-47ec-923b-6f41874dd9eb'
    },
    [pscustomobject]@{
        Label = 'Cerrar la tapa'
        Guid  = '5ca83367-6e45-459f-a27b-476b1d01c936'
    }
)

function Write-P0W3RLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $Color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'Gray' }
    }

    $Line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    Write-Host $Line -ForegroundColor $Color

    try {
        Add-Content -LiteralPath $LogFile -Value $Line -Encoding UTF8
    }
    catch {
        # El log no debe impedir aplicar la configuracion.
    }
}

function Add-P0W3RChange {
    param([Parameter(Mandatory)][string]$Message)

    $script:Changes.Add($Message)
    $script:SuccessCount++
    Write-P0W3RLog $Message 'OK'
}

function Add-P0W3RWarning {
    param([Parameter(Mandatory)][string]$Message)

    $script:Warnings.Add($Message)
    $script:WarningCount++
    Write-P0W3RLog $Message 'WARN'
}

function Invoke-PowerCfg {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [string]$SuccessMessage
    )

    try {
        $Output = @(& powercfg.exe @Arguments 2>&1)

        if ($LASTEXITCODE -ne 0) {
            throw (($Output | Out-String).Trim())
        }

        Add-P0W3RChange $SuccessMessage
        return $true
    }
    catch {
        $script:ErrorCount++
        Add-P0W3RWarning (
            "No se pudo aplicar '{0}'. powercfg {1}. {2}" -f
            $SuccessMessage,
            ($Arguments -join ' '),
            $_.Exception.Message
        )
        return $false
    }
}

function Get-ActivePowerScheme {
    try {
        $Output = (& powercfg.exe /GETACTIVESCHEME 2>&1 | Out-String).Trim()

        if ($LASTEXITCODE -eq 0 -and $Output) {
            return $Output
        }
    }
    catch {
    }

    return 'No se pudo identificar el plan activo.'
}

function Show-Header {
    try {
        Clear-Host
    }
    catch {
    }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host '                           P0W3R' -ForegroundColor Green
    Write-Host '                  LA VUELTITA IRONICA' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ('  Windows Power Management Toolkit  |  v{0}' -f $Version) -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ''
}

function Show-TargetConfiguration {
    Write-Host 'Configuracion que se aplicara:' -ForegroundColor White
    Write-Host ''
    Write-Host '  Pantalla con corriente .......... Nunca'
    Write-Host '  Pantalla con bateria ............ Nunca'
    Write-Host '  Suspension con corriente ........ Nunca'
    Write-Host '  Suspension con bateria .......... Nunca'
    Write-Host '  Boton de encendido .............. No hacer nada'
    Write-Host '  Boton de suspension ............. No hacer nada'
    Write-Host '  Cerrar la tapa .................. No hacer nada'
    Write-Host '  Hibernacion ..................... Desactivada'
    Write-Host ''
}

function Show-Summary {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host '                         RESUMEN' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ('  Cambios aplicados : {0}' -f $script:SuccessCount) -ForegroundColor Green
    Write-Host ('  Advertencias      : {0}' -f $script:WarningCount) -ForegroundColor Yellow
    Write-Host ('  Errores            : {0}' -f $script:ErrorCount) -ForegroundColor $(if ($script:ErrorCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host ('  Log                : {0}' -f $LogFile) -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor DarkGreen

    if ($script:ErrorCount -eq 0) {
        Write-Host ''
        Write-Host 'Configuracion de energia aplicada correctamente.' -ForegroundColor Green
    }
    else {
        Write-Host ''
        Write-Host 'La configuracion termino con alguna incidencia. Revisa el resumen y el log.' -ForegroundColor Yellow
    }
}

# =============================================================================
# INICIALIZACION
# =============================================================================

New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
Show-Header

$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-P0W3RLog 'P0W3R debe ejecutarse como administrador.' 'ERROR'
    throw 'P0W3R debe ejecutarse como administrador.'
}

if (-not (Get-Command powercfg.exe -ErrorAction SilentlyContinue)) {
    Write-P0W3RLog 'No se ha encontrado powercfg.exe.' 'ERROR'
    throw 'powercfg.exe no esta disponible.'
}

Write-P0W3RLog ('Iniciando {0} v{1}.' -f $ProjectName, $Version)
Write-P0W3RLog ('Equipo: {0} | Usuario: {1}' -f $env:COMPUTERNAME, $env:USERNAME)
Write-P0W3RLog ('Plan activo: {0}' -f (Get-ActivePowerScheme))

Show-TargetConfiguration

# =============================================================================
# HIBERNACION
# =============================================================================

Invoke-PowerCfg `
    -Arguments @('/HIBERNATE', 'OFF') `
    -SuccessMessage 'Hibernacion desactivada.' | Out-Null

# =============================================================================
# PANTALLA Y SUSPENSION
# =============================================================================

Invoke-PowerCfg `
    -Arguments @('/CHANGE', 'monitor-timeout-ac', '0') `
    -SuccessMessage 'Pantalla con corriente: Nunca.' | Out-Null

Invoke-PowerCfg `
    -Arguments @('/CHANGE', 'monitor-timeout-dc', '0') `
    -SuccessMessage 'Pantalla con bateria: Nunca.' | Out-Null

Invoke-PowerCfg `
    -Arguments @('/CHANGE', 'standby-timeout-ac', '0') `
    -SuccessMessage 'Suspension con corriente: Nunca.' | Out-Null

Invoke-PowerCfg `
    -Arguments @('/CHANGE', 'standby-timeout-dc', '0') `
    -SuccessMessage 'Suspension con bateria: Nunca.' | Out-Null

# =============================================================================
# BOTONES Y TAPA
# =============================================================================

# Para estas opciones, el valor 0 equivale a "No hacer nada".
$TargetValue = 0

foreach ($Action in $ButtonActions) {
    Invoke-PowerCfg `
        -Arguments @(
            '/SETACVALUEINDEX',
            'SCHEME_CURRENT',
            $SubButtonsGuid,
            $Action.Guid,
            [string]$TargetValue
        ) `
        -SuccessMessage ("{0} con corriente: No hacer nada." -f $Action.Label) | Out-Null

    Invoke-PowerCfg `
        -Arguments @(
            '/SETDCVALUEINDEX',
            'SCHEME_CURRENT',
            $SubButtonsGuid,
            $Action.Guid,
            [string]$TargetValue
        ) `
        -SuccessMessage ("{0} con bateria: No hacer nada." -f $Action.Label) | Out-Null
}

# Reactiva el plan actual para garantizar que Windows recargue los valores.
Invoke-PowerCfg `
    -Arguments @('/SETACTIVE', 'SCHEME_CURRENT') `
    -SuccessMessage 'Plan de energia activo recargado.' | Out-Null

# =============================================================================
# FINAL
# =============================================================================

Show-Summary

if (-not $NoPause -and [Environment]::UserInteractive) {
    Write-Host ''
    Write-Host 'Pulsa ENTER para cerrar.' -ForegroundColor DarkGray
    [void](Read-Host)
}
