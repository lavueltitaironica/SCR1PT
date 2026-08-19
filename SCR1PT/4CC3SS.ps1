#Requires -Version 5.1
#Requires -RunAsAdministrator

# SCR1PT-Category: RED Y ACCESO REMOTO
# SCR1PT-CategoryOrder: 20
# SCR1PT-Order: 30

<#
.SYNOPSIS
    4CC3SS v1.0.0 - Preparacion completa de un equipo Windows para acceso remoto.

.DESCRIPTION
    4CC3SS es el orquestador de acceso remoto de SCR1PT.

    Ejecuta, en este orden:
    1. W0L.ps1
       Prepara el adaptador para poder encender el equipo por Wake-on-LAN.
    2. R3M0T3.ps1
       Prepara Windows para seguir disponible cuando el equipo ya esta encendido.

    4CC3SS NO duplica la logica de esos scripts.

    Resolucion de scripts:
    - Si W0L.ps1 y R3M0T3.ps1 existen junto a 4CC3SS.ps1, usa esas copias.
    - Si no existen (por ejemplo al ejecutar 4CC3SS mediante irm | iex),
      descarga temporalmente las versiones publicadas en el repositorio oficial
      de La Vueltita Ironica / SCR1PT.

    El software de acceso remoto sigue siendo eleccion del usuario.
    R3M0T3 no instala RustDesk, AnyDesk, TeamViewer, Tailscale ni RDP.

.PARAMETER AdapterName
    Adaptador que se pasa a W0L. Si se omite, W0L muestra su selector.

.PARAMETER KeepFastStartup
    Pasa -KeepFastStartup a W0L.

.PARAMETER RestartAdapter
    Pasa -RestartAdapter a W0L.
    Puede cortar una sesion remota actual.

.PARAMETER SkipBiosAudit
    Pasa -SkipBiosAudit a W0L.

.PARAMETER ContinueOnBiosWarning
    Pasa -ContinueOnBiosWarning a W0L.

.PARAMETER SkipPower
    Pasa -SkipPower a R3M0T3.

.PARAMETER SkipNetwork
    Pasa -SkipNetwork a R3M0T3.

.PARAMETER SkipRemoteSoftware
    Pasa -SkipRemoteSoftware a R3M0T3.

.PARAMETER SkipWol
    Omite W0L.

.PARAMETER SkipRemote
    Omite R3M0T3.

.PARAMETER CheckOnly
    Ejecuta ambos scripts en modo diagnostico.

.PARAMETER NoPause
    Evita la pausa final.

.EXAMPLE
    .\4CC3SS.ps1

.EXAMPLE
    .\4CC3SS.ps1 -AdapterName "Ethernet"

.EXAMPLE
    .\4CC3SS.ps1 -CheckOnly -NoPause

.NOTES
    Version 1.0.0.
#>

[CmdletBinding()]
param(
    [string]$AdapterName,
    [switch]$KeepFastStartup,
    [switch]$RestartAdapter,
    [switch]$SkipBiosAudit,
    [switch]$ContinueOnBiosWarning,
    [switch]$SkipPower,
    [switch]$SkipNetwork,
    [switch]$SkipRemoteSoftware,
    [switch]$SkipWol,
    [switch]$SkipRemote,
    [switch]$CheckOnly,
    [switch]$NoPause
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ProjectName = '4CC3SS'
$Version = '1.0.0'
$RepositoryRawRoot = 'https://raw.githubusercontent.com/lavueltitaironica/SCR1PT/main/SCR1PT'

$LogRoot = Join-Path $env:ProgramData 'SCR1PT\Logs'
$LogFile = Join-Path $LogRoot ("4CC3SS-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$TempRoot = Join-Path $env:TEMP ("SCR1PT-4CC3SS-{0}" -f ([guid]::NewGuid().ToString('N')))

$script:SuccessCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0
$script:DownloadedFiles = New-Object System.Collections.Generic.List[string]

function Write-4CC3SSLog {
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

function Show-Header {
    try { Clear-Host } catch {}

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host '                          4CC3SS' -ForegroundColor Green
    Write-Host '                  LA VUELTITA IRONICA' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ('  Complete Remote Access Setup       |  v{0}' -f $Version) -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ''
}

function Resolve-Scr1ptChild {
    param([Parameter(Mandatory)][ValidateSet('W0L.ps1','R3M0T3.ps1')][string]$FileName)

    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $Local = Join-Path $PSScriptRoot $FileName

        if (Test-Path -LiteralPath $Local -PathType Leaf) {
            Write-4CC3SSLog ("Usando copia local: {0}" -f $Local)
            return $Local
        }
    }

    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
    $Destination = Join-Path $TempRoot $FileName
    $Uri = '{0}/{1}' -f $RepositoryRawRoot, $FileName

    Write-4CC3SSLog ("Descargando {0} desde el repositorio oficial..." -f $FileName)

    try {
        Invoke-WebRequest `
            -UseBasicParsing `
            -Uri $Uri `
            -OutFile $Destination `
            -TimeoutSec 60 `
            -ErrorAction Stop

        if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
            throw 'La descarga no produjo un archivo.'
        }

        try {
            Unblock-File -LiteralPath $Destination -ErrorAction SilentlyContinue
        }
        catch {
        }

        $script:DownloadedFiles.Add($Destination)
        Write-4CC3SSLog ("Descarga completada: {0}" -f $FileName) 'OK'
        return $Destination
    }
    catch {
        throw "No se pudo obtener $FileName. $($_.Exception.Message)"
    }
}

function Invoke-W0LStage {
    if ($SkipWol) {
        Write-4CC3SSLog 'W0L omitido por -SkipWol.' 'WARN'
        return
    }

    Write-Host ''
    Write-Host '>>>>>>>>>>>>>>>>>>>>>>>> W0L <<<<<<<<<<<<<<<<<<<<<<<<' -ForegroundColor Cyan
    Write-Host ''

    try {
        $Path = Resolve-Scr1ptChild -FileName 'W0L.ps1'
        $Params = @{
            NoPause = $true
        }

        if (-not [string]::IsNullOrWhiteSpace($AdapterName)) {
            $Params['AdapterName'] = $AdapterName
        }

        if ($KeepFastStartup) {
            $Params['KeepFastStartup'] = $true
        }

        if ($RestartAdapter) {
            $Params['RestartAdapter'] = $true
        }

        if ($SkipBiosAudit) {
            $Params['SkipBiosAudit'] = $true
        }

        if ($ContinueOnBiosWarning) {
            $Params['ContinueOnBiosWarning'] = $true
        }

        if ($CheckOnly) {
            $Params['CheckOnly'] = $true
        }

        & $Path @Params
        $script:SuccessCount++
        Write-4CC3SSLog 'Etapa W0L finalizada.' 'OK'
    }
    catch {
        $script:ErrorCount++
        Write-4CC3SSLog ("Etapa W0L fallo: {0}" -f $_.Exception.Message) 'ERROR'
    }
}

function Invoke-R3M0T3Stage {
    if ($SkipRemote) {
        Write-4CC3SSLog 'R3M0T3 omitido por -SkipRemote.' 'WARN'
        return
    }

    Write-Host ''
    Write-Host '>>>>>>>>>>>>>>>>>>>>>>> R3M0T3 <<<<<<<<<<<<<<<<<<<<<<<' -ForegroundColor Cyan
    Write-Host ''

    try {
        $Path = Resolve-Scr1ptChild -FileName 'R3M0T3.ps1'
        $Params = @{
            NoPause = $true
        }

        if ($SkipPower) {
            $Params['SkipPower'] = $true
        }

        if ($SkipNetwork) {
            $Params['SkipNetwork'] = $true
        }

        if ($SkipRemoteSoftware) {
            $Params['SkipRemoteSoftware'] = $true
        }

        if ($CheckOnly) {
            $Params['CheckOnly'] = $true
        }

        & $Path @Params
        $script:SuccessCount++
        Write-4CC3SSLog 'Etapa R3M0T3 finalizada.' 'OK'
    }
    catch {
        $script:ErrorCount++
        Write-4CC3SSLog ("Etapa R3M0T3 fallo: {0}" -f $_.Exception.Message) 'ERROR'
    }
}

function Remove-TemporaryFiles {
    if (Test-Path -LiteralPath $TempRoot) {
        try {
            Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction Stop
            Write-4CC3SSLog 'Archivos temporales eliminados.'
        }
        catch {
            $script:WarningCount++
            Write-4CC3SSLog (
                "No se pudieron eliminar todos los temporales: {0}" -f
                $_.Exception.Message
            ) 'WARN'
        }
    }
}

function Show-Summary {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host '                      RESUMEN 4CC3SS' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ('  Etapas completadas : {0}' -f $script:SuccessCount) -ForegroundColor Green
    Write-Host ('  Advertencias       : {0}' -f $script:WarningCount) -ForegroundColor Yellow
    Write-Host ('  Errores             : {0}' -f $script:ErrorCount) -ForegroundColor $(if ($script:ErrorCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host ('  Log                 : {0}' -f $LogFile) -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ''

    Write-Host 'Resultado esperado:' -ForegroundColor White
    Write-Host '  W0L    -> poder encender el equipo remotamente.' -ForegroundColor Gray
    Write-Host '  R3M0T3 -> poder volver a acceder cuando el equipo ya esta encendido.' -ForegroundColor Gray
    Write-Host ''
}

New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
Show-Header

Write-4CC3SSLog ('Iniciando {0} v{1}.' -f $ProjectName, $Version)
Write-4CC3SSLog ('Equipo: {0} | Usuario: {1}' -f $env:COMPUTERNAME, $env:USERNAME)

try {
    Invoke-W0LStage
    Invoke-R3M0T3Stage
}
finally {
    Remove-TemporaryFiles
}

Show-Summary

if ($script:ErrorCount -eq 0) {
    Write-Host '4CC3SS ha terminado sin errores de etapa.' -ForegroundColor Green
}
else {
    Write-Host '4CC3SS ha terminado con alguna incidencia. Revisa los logs individuales de W0L/R3M0T3.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'El acceso desatendido debe estar configurado tambien dentro del software remoto elegido.' -ForegroundColor Yellow
Write-Host ''

if (-not $NoPause -and [Environment]::UserInteractive) {
    Write-Host 'Pulsa ENTER para cerrar.' -ForegroundColor DarkGray
    [void](Read-Host)
}
