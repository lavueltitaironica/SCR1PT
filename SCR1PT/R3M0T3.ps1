#Requires -Version 5.1
#Requires -RunAsAdministrator

# SCR1PT-Category: RED Y ACCESO REMOTO
# SCR1PT-CategoryOrder: 20
# SCR1PT-Order: 20

<#
.SYNOPSIS
    R3M0T3 v2.0.0 - Prepara Windows para permanecer disponible para acceso remoto.

.DESCRIPTION
    R3M0T3 es independiente del proveedor de escritorio remoto.

    Configuracion general:
    - Suspension con corriente: Nunca.
    - Hibernacion automatica con corriente: Nunca.
    - Cerrar la tapa con corriente: No hacer nada.
    - Reduce ahorro agresivo en adaptadores fisicos activos sin reiniciarlos.
    - No modifica WakeOnMagicPacket ni otras opciones de WOL.
    - Diagnostica conectividad y servicios remotos instalados.

    Integraciones detectadas, SIN instalar software:
    - RustDesk:
        * Si esta instalado en Program Files y no existe servicio, intenta
          registrar el servicio mediante rustdesk.exe --install-service.
        * Configura el servicio RustDesk como Automatico y lo inicia.
        * No cambia ID, servidor, clave ni contrasena.
    - AnyDesk:
        * Si existe su servicio, lo configura como Automatico y lo inicia.
    - TeamViewer:
        * Si existe su servicio, lo configura como Automatico y lo inicia.

    R3M0T3 NO:
    - Instala RustDesk, AnyDesk, TeamViewer, Tailscale ni ninguna VPN.
    - Habilita RDP.
    - Abre puertos del firewall.
    - Cambia credenciales o contrasenas.
    - Configura acceso desatendido dentro del proveedor.
    - Reinicia adaptadores de red.
    - Configura Wake-on-LAN.

.PARAMETER SkipPower
    No modifica suspension, hibernacion ni tapa.

.PARAMETER SkipNetwork
    No modifica opciones de ahorro de adaptadores.

.PARAMETER SkipRemoteSoftware
    No comprueba ni repara servicios de software remoto.

.PARAMETER CheckOnly
    Solo diagnostica.

.PARAMETER NoPause
    Evita la pausa final.

.EXAMPLE
    .\R3M0T3.ps1

.EXAMPLE
    .\R3M0T3.ps1 -CheckOnly

.EXAMPLE
    .\R3M0T3.ps1 -SkipRemoteSoftware -NoPause

.NOTES
    Version 2.0.0.
    W0L.ps1 se ocupa de encender el equipo.
    R3M0T3.ps1 se ocupa de mantenerlo disponible cuando ya esta encendido.
#>

[CmdletBinding()]
param(
    [switch]$SkipPower,
    [switch]$SkipNetwork,
    [switch]$SkipRemoteSoftware,
    [switch]$CheckOnly,
    [switch]$NoPause
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ProjectName = 'R3M0T3'
$Version = '2.0.0'
$LogRoot = Join-Path $env:ProgramData 'SCR1PT\Logs'
$LogFile = Join-Path $LogRoot ("R3M0T3-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

$SubButtonsGuid = '4f971e89-eebd-4455-a8de-9e59040e7347'
$LidActionGuid = '5ca83367-6e45-459f-a27b-476b1d01c936'

$script:SuccessCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0

function Write-R3M0T3Log {
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
    Write-R3M0T3Log $Message 'OK'
}

function Add-Warning {
    param([Parameter(Mandatory)][string]$Message)
    $script:WarningCount++
    Write-R3M0T3Log $Message 'WARN'
}

function Add-Error {
    param([Parameter(Mandatory)][string]$Message)
    $script:ErrorCount++
    Write-R3M0T3Log $Message 'ERROR'
}

function Show-Header {
    try { Clear-Host } catch {}

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host '                          R3M0T3' -ForegroundColor Green
    Write-Host '                  LA VUELTITA IRONICA' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ('  Remote Availability Toolkit        |  v{0}' -f $Version) -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ''
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
        Add-Warning (
            "No se pudo aplicar '{0}': {1}" -f
            $SuccessMessage,
            $_.Exception.Message
        )
        return $false
    }
}

function Set-RemotePowerAvailability {
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

function Get-ActivePhysicalAdapters {
    try {
        return @(
            Get-NetAdapter -Physical -ErrorAction Stop |
                Where-Object {
                    $_.Status -eq 'Up' -and
                    $_.HardwareInterface -eq $true
                }
        )
    }
    catch {
        Add-Warning ("No se pudieron enumerar adaptadores activos: {0}" -f $_.Exception.Message)
        return @()
    }
}

function Set-RemoteNetworkAvailability {
    $Adapters = Get-ActivePhysicalAdapters

    if ($Adapters.Count -eq 0) {
        Add-Warning 'No se han encontrado adaptadores fisicos activos.'
        return
    }

    foreach ($Adapter in $Adapters) {
        try {
            $Current = Get-NetAdapterPowerManagement -Name $Adapter.Name -ErrorAction Stop

            $Params = @{
                Name = $Adapter.Name
                NoRestart = $true
                Confirm = $false
            }

            $CanChange = $false

            if (
                $Current.PSObject.Properties.Name -contains 'DeviceSleepOnDisconnect' -and
                [string]$Current.DeviceSleepOnDisconnect -ne 'Unsupported'
            ) {
                $Params['DeviceSleepOnDisconnect'] = 'Disabled'
                $CanChange = $true
            }

            if (
                $Current.PSObject.Properties.Name -contains 'SelectiveSuspend' -and
                [string]$Current.SelectiveSuspend -ne 'Unsupported'
            ) {
                $Params['SelectiveSuspend'] = 'Disabled'
                $CanChange = $true
            }

            if ($CanChange) {
                Set-NetAdapterPowerManagement @Params -ErrorAction Stop | Out-Null
                Add-Change (
                    "Ahorro agresivo reducido en '{0}' sin reiniciar el adaptador." -f
                    $Adapter.Name
                )
            }
            else {
                Write-R3M0T3Log (
                    "El adaptador '{0}' no expone DeviceSleepOnDisconnect/SelectiveSuspend configurables." -f
                    $Adapter.Name
                )
            }
        }
        catch {
            Add-Warning (
                "No se pudo ajustar '{0}': {1}" -f
                $Adapter.Name,
                $_.Exception.Message
            )
        }
    }
}

function Get-RustDeskExecutable {
    $Candidates = @()

    if ($env:ProgramFiles) {
        $Candidates += (Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe')
    }

    if (${env:ProgramFiles(x86)}) {
        $Candidates += (Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe')
    }

    foreach ($Candidate in $Candidates) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return $Candidate
        }
    }

    return $null
}

function Get-ServiceByNames {
    param([Parameter(Mandatory)][string[]]$Names)

    foreach ($Name in $Names) {
        $Service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($Service) {
            return $Service
        }
    }

    return $null
}

function Set-ServiceReady {
    param(
        [Parameter(Mandatory)]$Service,
        [Parameter(Mandatory)][string]$Label
    )

    try {
        Set-Service -Name $Service.Name -StartupType Automatic -ErrorAction Stop

        $Current = Get-Service -Name $Service.Name -ErrorAction Stop
        if ($Current.Status -ne 'Running') {
            Start-Service -Name $Service.Name -ErrorAction Stop
            $Current.WaitForStatus('Running', [TimeSpan]::FromSeconds(15))
        }

        Add-Change ("{0}: servicio Automatico y Running." -f $Label)
        return $true
    }
    catch {
        Add-Warning (
            "{0}: no se pudo preparar el servicio. {1}" -f
            $Label,
            $_.Exception.Message
        )
        return $false
    }
}

function Repair-RustDesk {
    $Executable = Get-RustDeskExecutable
    $Service = Get-ServiceByNames -Names @('RustDesk','Rustdesk')

    if (-not $Executable -and -not $Service) {
        return
    }

    Write-R3M0T3Log 'RustDesk detectado.'

    if (-not $Service -and $Executable) {
        try {
            Write-R3M0T3Log 'RustDesk esta instalado, pero no existe servicio. Intentando registrarlo...'

            $Process = Start-Process `
                -FilePath $Executable `
                -ArgumentList '--install-service' `
                -Wait `
                -PassThru `
                -WindowStyle Hidden `
                -ErrorAction Stop

            for ($i = 0; $i -lt 10; $i++) {
                Start-Sleep -Seconds 2
                $Service = Get-ServiceByNames -Names @('RustDesk','Rustdesk')
                if ($Service) {
                    break
                }
            }

            if ($Service) {
                Add-Change 'RustDesk: servicio registrado.'
            }
            else {
                Add-Warning 'RustDesk: no se pudo confirmar la creacion del servicio.'
                return
            }
        }
        catch {
            Add-Warning ("RustDesk: fallo instalando servicio. {0}" -f $_.Exception.Message)
            return
        }
    }

    if ($Service) {
        Set-ServiceReady -Service $Service -Label 'RustDesk' | Out-Null
    }
}

function Repair-AnyDesk {
    $Service = Get-ServiceByNames -Names @('AnyDesk','AnyDesk Service')
    if ($Service) {
        Write-R3M0T3Log 'AnyDesk detectado.'
        Set-ServiceReady -Service $Service -Label 'AnyDesk' | Out-Null
    }
}

function Repair-TeamViewer {
    $Service = Get-ServiceByNames -Names @('TeamViewer','TeamViewer_Service')
    if ($Service) {
        Write-R3M0T3Log 'TeamViewer detectado.'
        Set-ServiceReady -Service $Service -Label 'TeamViewer' | Out-Null
    }
}

function Repair-RemoteSoftware {
    Repair-RustDesk
    Repair-AnyDesk
    Repair-TeamViewer
}

function Get-RemoteServices {
    $Results = @()

    foreach ($Definition in @(
        @{ Label = 'RustDesk'; Names = @('RustDesk','Rustdesk') },
        @{ Label = 'AnyDesk'; Names = @('AnyDesk','AnyDesk Service') },
        @{ Label = 'TeamViewer'; Names = @('TeamViewer','TeamViewer_Service') }
    )) {
        $Service = Get-ServiceByNames -Names $Definition.Names

        if ($Service) {
            $Results += [pscustomobject]@{
                Label = $Definition.Label
                Name = $Service.Name
                Status = [string]$Service.Status
                StartType = [string]$Service.StartType
            }
        }
    }

    return $Results
}

function Show-Diagnostics {
    $Adapters = Get-ActivePhysicalAdapters
    $Services = Get-RemoteServices
    $RustDeskExe = Get-RustDeskExecutable

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host '                       DIAGNOSTICO' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ('  Equipo                    : {0}' -f $env:COMPUTERNAME)
    Write-Host ('  Usuario                   : {0}' -f $env:USERNAME)
    Write-Host ('  Adaptadores activos       : {0}' -f $Adapters.Count)

    foreach ($Adapter in $Adapters) {
        Write-Host ('    - {0} | {1} | {2}' -f $Adapter.Name, $Adapter.LinkSpeed, $Adapter.Status) -ForegroundColor Gray
    }

    if ($RustDeskExe) {
        Write-Host ('  RustDesk executable       : {0}' -f $RustDeskExe)
    }

    if ($Services.Count -eq 0) {
        Write-Host '  Servicios remotos         : Ninguno de los proveedores reconocidos detectado.'
    }
    else {
        Write-Host '  Servicios remotos:'

        foreach ($Service in $Services) {
            Write-Host (
                '    - {0}: {1} / inicio {2}' -f
                $Service.Label,
                $Service.Status,
                $Service.StartType
            )
        }
    }

    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ''
    Write-Host 'R3M0T3 no configura el acceso desatendido dentro de cada proveedor.' -ForegroundColor Yellow
    Write-Host 'ID, contrasena permanente, permisos y servidor siguen perteneciendo a RustDesk/AnyDesk/TeamViewer.' -ForegroundColor Gray
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
}

New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
Show-Header

Write-R3M0T3Log ('Iniciando {0} v{1}.' -f $ProjectName, $Version)
Write-R3M0T3Log ('Equipo: {0} | Usuario: {1}' -f $env:COMPUTERNAME, $env:USERNAME)

if ($CheckOnly) {
    Show-Diagnostics
    Show-Summary

    if (-not $NoPause -and [Environment]::UserInteractive) {
        Write-Host 'Pulsa ENTER para cerrar.' -ForegroundColor DarkGray
        [void](Read-Host)
    }
    return
}

if (-not $SkipPower) {
    Set-RemotePowerAvailability
}
else {
    Write-R3M0T3Log 'Configuracion de energia omitida por -SkipPower.'
}

if (-not $SkipNetwork) {
    Set-RemoteNetworkAvailability
}
else {
    Write-R3M0T3Log 'Configuracion de red omitida por -SkipNetwork.'
}

if (-not $SkipRemoteSoftware) {
    Repair-RemoteSoftware
}
else {
    Write-R3M0T3Log 'Comprobacion de software remoto omitida por -SkipRemoteSoftware.'
}

Show-Diagnostics
Show-Summary

Write-Host ''
Write-Host 'R3M0T3 prepara Windows para seguir disponible; no garantiza una sesion remota ininterrumpida.' -ForegroundColor Gray
Write-Host 'Si Internet se corta, el objetivo es que puedas volver a conectar cuando la red regrese.' -ForegroundColor Gray
Write-Host ''

if (-not $NoPause -and [Environment]::UserInteractive) {
    Write-Host 'Pulsa ENTER para cerrar.' -ForegroundColor DarkGray
    [void](Read-Host)
}
