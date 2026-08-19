#Requires -Version 5.1
#Requires -RunAsAdministrator

# SCR1PT-Category: SISTEMA Y ENERGIA
# SCR1PT-CategoryOrder: 30
# SCR1PT-Order: 10

<#
.SYNOPSIS
    P0W3R v1.1.0 - Configura y diagnostica las opciones esenciales de energia de Windows.

.DESCRIPTION
    P0W3R centraliza la configuracion energetica general de SCR1PT.

    Por defecto conserva el comportamiento historico de P0W3R:
    - Hibernacion: desactivada.
    - Pantalla con corriente y bateria: Nunca.
    - Suspension con corriente y bateria: Nunca.
    - Boton de encendido: No hacer nada.
    - Boton de suspension: No hacer nada.
    - Cerrar la tapa: No hacer nada.

    Con -AcOnly aplica una variante mas apropiada para equipos que deben
    permanecer accesibles cuando estan enchufados:
    - Suspension con corriente: Nunca.
    - Hibernacion automatica con corriente: Nunca.
    - Cerrar la tapa con corriente: No hacer nada.
    - No modifica las opciones de bateria.
    - No desactiva globalmente la funcion de hibernacion.

    P0W3R NO configura Wake-on-LAN ni software de acceso remoto.

.PARAMETER AcOnly
    Aplica solo la configuracion de disponibilidad con corriente.

.PARAMETER CheckOnly
    Muestra la configuracion actual mediante powercfg sin modificar el equipo.

.PARAMETER NoPause
    Evita la pausa final. Util para ejecucion automatizada desde SCR1PT.

.EXAMPLE
    .\P0W3R.ps1

.EXAMPLE
    .\P0W3R.ps1 -AcOnly

.EXAMPLE
    .\P0W3R.ps1 -CheckOnly -NoPause

.NOTES
    Version 1.1.0.
    La configuracion de Wake-on-LAN pertenece a W0L.ps1.
    La disponibilidad para acceso remoto pertenece a R3M0T3.ps1.
#>

[CmdletBinding()]
param(
    [switch]$AcOnly,
    [switch]$CheckOnly,
    [switch]$NoPause
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ProjectName = 'P0W3R'
$Version = '1.1.0'
$LogRoot = Join-Path $env:ProgramData 'SCR1PT\Logs'
$LogFile = Join-Path $LogRoot ("P0W3R-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

$script:SuccessCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0

$SubButtonsGuid = '4f971e89-eebd-4455-a8de-9e59040e7347'
$PowerButtonGuid = '7648efa3-dd9c-4e3e-b566-50f929386280'
$SleepButtonGuid = '96996bc0-ad50-47ec-923b-6f41874dd9eb'
$LidActionGuid = '5ca83367-6e45-459f-a27b-476b1d01c936'

function Write-P0W3RLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','OK','WARN','ERROR')][string]$Level = 'INFO'
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
    }
}

function Add-Change {
    param([Parameter(Mandatory)][string]$Message)
    $script:SuccessCount++
    Write-P0W3RLog $Message 'OK'
}

function Add-Warning {
    param([Parameter(Mandatory)][string]$Message)
    $script:WarningCount++
    Write-P0W3RLog $Message 'WARN'
}

function Invoke-PowerCfg {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$SuccessMessage
    )

    try {
        $Output = @(& powercfg.exe @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw (($Output | Out-String).Trim())
        }

        Add-Change $SuccessMessage
        return $true
    }
    catch {
        $script:ErrorCount++
        Add-Warning (
            "No se pudo aplicar '{0}'. powercfg {1}. {2}" -f
            $SuccessMessage,
            ($Arguments -join ' '),
            $_.Exception.Message
        )
        return $false
    }
}

function Show-Header {
    try { Clear-Host } catch {}

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host '                           P0W3R' -ForegroundColor Green
    Write-Host '                  LA VUELTITA IRONICA' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ('  Windows Power Management Toolkit  |  v{0}' -f $Version) -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ''
}

function Show-CurrentConfiguration {
    Write-Host 'Plan de energia activo:' -ForegroundColor White
    & powercfg.exe /GETACTIVESCHEME
    Write-Host ''

    Write-Host 'Suspension / hibernacion:' -ForegroundColor White
    & powercfg.exe /QUERY SCHEME_CURRENT SUB_SLEEP
    Write-Host ''

    Write-Host 'Pantalla:' -ForegroundColor White
    & powercfg.exe /QUERY SCHEME_CURRENT SUB_VIDEO
    Write-Host ''

    Write-Host 'Botones y tapa:' -ForegroundColor White
    & powercfg.exe /QUERY SCHEME_CURRENT SUB_BUTTONS
    Write-Host ''
}

function Set-AcAvailability {
    Invoke-PowerCfg `
        -Arguments @('/CHANGE','standby-timeout-ac','0') `
        -SuccessMessage 'Suspension con corriente: Nunca.' | Out-Null

    Invoke-PowerCfg `
        -Arguments @('/CHANGE','hibernate-timeout-ac','0') `
        -SuccessMessage 'Hibernacion automatica con corriente: Nunca.' | Out-Null

    Invoke-PowerCfg `
        -Arguments @(
            '/SETACVALUEINDEX',
            'SCHEME_CURRENT',
            $SubButtonsGuid,
            $LidActionGuid,
            '0'
        ) `
        -SuccessMessage 'Cerrar la tapa con corriente: No hacer nada.' | Out-Null

    Invoke-PowerCfg `
        -Arguments @('/SETACTIVE','SCHEME_CURRENT') `
        -SuccessMessage 'Plan de energia activo recargado.' | Out-Null
}

function Set-FullAvailability {
    Invoke-PowerCfg `
        -Arguments @('/HIBERNATE','OFF') `
        -SuccessMessage 'Hibernacion desactivada.' | Out-Null

    foreach ($Item in @(
        @{ Args = @('/CHANGE','monitor-timeout-ac','0'); Text = 'Pantalla con corriente: Nunca.' },
        @{ Args = @('/CHANGE','monitor-timeout-dc','0'); Text = 'Pantalla con bateria: Nunca.' },
        @{ Args = @('/CHANGE','standby-timeout-ac','0'); Text = 'Suspension con corriente: Nunca.' },
        @{ Args = @('/CHANGE','standby-timeout-dc','0'); Text = 'Suspension con bateria: Nunca.' }
    )) {
        Invoke-PowerCfg -Arguments $Item.Args -SuccessMessage $Item.Text | Out-Null
    }

    $Actions = @(
        @{ Label = 'Boton de encendido'; Guid = $PowerButtonGuid },
        @{ Label = 'Boton de suspension'; Guid = $SleepButtonGuid },
        @{ Label = 'Cerrar la tapa'; Guid = $LidActionGuid }
    )

    foreach ($Action in $Actions) {
        Invoke-PowerCfg `
            -Arguments @(
                '/SETACVALUEINDEX',
                'SCHEME_CURRENT',
                $SubButtonsGuid,
                $Action.Guid,
                '0'
            ) `
            -SuccessMessage ("{0} con corriente: No hacer nada." -f $Action.Label) | Out-Null

        Invoke-PowerCfg `
            -Arguments @(
                '/SETDCVALUEINDEX',
                'SCHEME_CURRENT',
                $SubButtonsGuid,
                $Action.Guid,
                '0'
            ) `
            -SuccessMessage ("{0} con bateria: No hacer nada." -f $Action.Label) | Out-Null
    }

    Invoke-PowerCfg `
        -Arguments @('/SETACTIVE','SCHEME_CURRENT') `
        -SuccessMessage 'Plan de energia activo recargado.' | Out-Null
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
}

New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
Show-Header

if (-not (Get-Command powercfg.exe -ErrorAction SilentlyContinue)) {
    throw 'powercfg.exe no esta disponible.'
}

Write-P0W3RLog ('Iniciando {0} v{1}.' -f $ProjectName, $Version)
Write-P0W3RLog ('Equipo: {0} | Usuario: {1}' -f $env:COMPUTERNAME, $env:USERNAME)

if ($CheckOnly) {
    Show-CurrentConfiguration
    Show-Summary

    if (-not $NoPause -and [Environment]::UserInteractive) {
        Write-Host 'Pulsa ENTER para cerrar.' -ForegroundColor DarkGray
        [void](Read-Host)
    }
    return
}

if ($AcOnly) {
    Write-P0W3RLog 'Modo seleccionado: disponibilidad solo con corriente.'
    Set-AcAvailability
}
else {
    Write-P0W3RLog 'Modo seleccionado: disponibilidad completa (corriente + bateria).'
    Set-FullAvailability
}

Show-Summary

if (-not $NoPause -and [Environment]::UserInteractive) {
    Write-Host ''
    Write-Host 'Pulsa ENTER para cerrar.' -ForegroundColor DarkGray
    [void](Read-Host)
}
