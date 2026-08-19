#Requires -Version 5.1
#Requires -RunAsAdministrator

# SCR1PT-Category: RED Y ACCESO REMOTO
# SCR1PT-CategoryOrder: 20
# SCR1PT-Order: 10

<#
.SYNOPSIS
    W0L v2.0.0 - Prepara un adaptador fisico de Windows para Wake-on-LAN.

.DESCRIPTION
    W0L se ocupa exclusivamente de Wake-on-LAN.

    Configura:
    - Seleccion de adaptador fisico, aunque este desconectado.
    - Wake on Magic Packet cuando el controlador lo expone.
    - Wake on Pattern desactivado cuando es compatible.
    - Propiedades avanzadas WOL habituales del controlador.
    - powercfg /deviceenablewake.
    - Inicio rapido desactivado por defecto para evitar apagado hibrido.
    - Auditoria BIOS/UEFI HP de solo lectura cuando esta disponible.
    - Diagnostico final con MAC y estado de wake.

    W0L NO:
    - Cambia suspension general de Windows.
    - Cambia la accion de la tapa.
    - Cambia botones de encendido o suspension.
    - Instala software remoto.
    - Reinicia el adaptador salvo que se use -RestartAdapter.

    La separacion es intencionada:
    - P0W3R.ps1 gestiona energia.
    - R3M0T3.ps1 gestiona disponibilidad remota.
    - 4CC3SS.ps1 combina W0L + R3M0T3.

.PARAMETER AdapterName
    Nombre exacto del adaptador. Si se omite, se muestra un selector.

.PARAMETER KeepFastStartup
    Conserva Inicio rapido.

.PARAMETER RestartAdapter
    Reinicia el adaptador al terminar para intentar aplicar inmediatamente
    propiedades del controlador. Puede cortar una sesion remota actual.

.PARAMETER SkipBiosAudit
    Omite la auditoria de BIOS/UEFI.

.PARAMETER ContinueOnBiosWarning
    Continua sin pedir confirmacion cuando la auditoria detecta advertencias.

.PARAMETER CheckOnly
    Solo audita. No modifica el equipo.

.PARAMETER NoPause
    Evita la pausa final.

.EXAMPLE
    .\W0L.ps1

.EXAMPLE
    .\W0L.ps1 -AdapterName "Ethernet"

.EXAMPLE
    .\W0L.ps1 -AdapterName "Ethernet" -RestartAdapter

.EXAMPLE
    .\W0L.ps1 -CheckOnly -NoPause

.NOTES
    Version 2.0.0.
    Cambio importante respecto a 1.4.x:
    la configuracion general de energia deja de pertenecer a W0L.
#>

[CmdletBinding()]
param(
    [string]$AdapterName,
    [switch]$KeepFastStartup,
    [switch]$RestartAdapter,
    [switch]$SkipBiosAudit,
    [switch]$ContinueOnBiosWarning,
    [switch]$CheckOnly,
    [switch]$NoPause
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ProjectName = 'W0L'
$Version = '2.0.0'
$LogRoot = Join-Path $env:ProgramData 'SCR1PT\Logs'
$LogFile = Join-Path $LogRoot ("W0L-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$ReportFile = Join-Path $LogRoot ("W0L-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

$script:SuccessCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0

function Write-W0LLog {
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
    Write-W0LLog $Message 'OK'
}

function Add-Warning {
    param([Parameter(Mandatory)][string]$Message)
    $script:WarningCount++
    Write-W0LLog $Message 'WARN'
}

function Add-Error {
    param([Parameter(Mandatory)][string]$Message)
    $script:ErrorCount++
    Write-W0LLog $Message 'ERROR'
}

function Show-Header {
    try { Clear-Host } catch {}

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host '                            W0L' -ForegroundColor Green
    Write-Host '                  LA VUELTITA IRONICA' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ('  Wake-on-LAN Toolkit                |  v{0}' -f $Version) -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ''
}

function Test-ValidMac {
    param([string]$Mac)

    if ([string]::IsNullOrWhiteSpace($Mac)) {
        return $false
    }

    $Normalized = ($Mac -replace '[^0-9A-Fa-f]','').ToUpperInvariant()
    if ($Normalized -notmatch '^[0-9A-F]{12}$') {
        return $false
    }

    return ($Normalized -notin @('000000000000','FFFFFFFFFFFF'))
}

function Get-PhysicalAdapters {
    try {
        return @(
            Get-NetAdapter -Physical -ErrorAction Stop |
                Where-Object { Test-ValidMac $_.MacAddress } |
                Sort-Object -Property Status, Name
        )
    }
    catch {
        Add-Error ("No se pudieron enumerar adaptadores fisicos: {0}" -f $_.Exception.Message)
        return @()
    }
}

function Select-W0LAdapter {
    param([string]$RequestedName)

    $Adapters = Get-PhysicalAdapters

    if ($Adapters.Count -eq 0) {
        throw 'No se han encontrado adaptadores fisicos con una MAC valida.'
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedName)) {
        $Match = @($Adapters | Where-Object { $_.Name -eq $RequestedName })

        if ($Match.Count -eq 1) {
            return $Match[0]
        }

        throw "No se ha encontrado un adaptador fisico llamado '$RequestedName'."
    }

    if ($Adapters.Count -eq 1) {
        Write-W0LLog ("Adaptador seleccionado automaticamente: {0}" -f $Adapters[0].Name)
        return $Adapters[0]
    }

    Write-Host 'Adaptadores fisicos disponibles:' -ForegroundColor White
    Write-Host ''

    for ($i = 0; $i -lt $Adapters.Count; $i++) {
        $Adapter = $Adapters[$i]
        Write-Host (
            '  [{0}] {1} | {2} | {3} | {4}' -f
            ($i + 1),
            $Adapter.Name,
            $Adapter.InterfaceDescription,
            $Adapter.Status,
            $Adapter.MacAddress
        )
    }

    Write-Host ''

    while ($true) {
        $Choice = Read-Host 'Selecciona el adaptador'
        $Index = 0

        if ([int]::TryParse($Choice, [ref]$Index)) {
            if ($Index -ge 1 -and $Index -le $Adapters.Count) {
                return $Adapters[$Index - 1]
            }
        }

        Write-Host 'Seleccion no valida.' -ForegroundColor Yellow
    }
}

function Get-HpBiosAudit {
    param([switch]$Skip)

    $Result = [ordered]@{
        Supported = $false
        Manufacturer = $null
        Model = $null
        BiosVersion = $null
        Status = 'NotChecked'
        Items = @()
        WarningCount = 0
    }

    if ($Skip) {
        $Result.Status = 'Skipped'
        return [pscustomobject]$Result
    }

    try {
        $System = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $Bios = Get-CimInstance Win32_BIOS -ErrorAction Stop

        $Result.Manufacturer = [string]$System.Manufacturer
        $Result.Model = [string]$System.Model
        $Result.BiosVersion = [string]$Bios.SMBIOSBIOSVersion
    }
    catch {
        $Result.Status = 'Unavailable'
        $Result['WarningCount']++
        return [pscustomobject]$Result
    }

    if ($Result.Manufacturer -notmatch '(?i)\bHP\b|Hewlett[ -]Packard') {
        $Result.Status = 'NotHP'
        return [pscustomobject]$Result
    }

    try {
        $Settings = @(
            Get-CimInstance `
                -Namespace 'root/HP/InstrumentedBIOS' `
                -ClassName 'HP_BIOSSetting' `
                -ErrorAction Stop
        )
    }
    catch {
        $Result.Status = 'HpWmiUnavailable'
        $Result['WarningCount']++
        return [pscustomobject]$Result
    }

    $Result.Supported = $true

    $Relevant = @(
        $Settings |
            Where-Object {
                [string]$_.Name -match '(?i)wake.*lan|lan.*wake|s5.*wake|wake.*s5'
            }
    )

    if ($Relevant.Count -eq 0) {
        $Result.Status = 'NoMatchingSettings'
        $Result['WarningCount']++
        return [pscustomobject]$Result
    }

    $Items = @()

    foreach ($Setting in $Relevant) {
        $Value = $null

        foreach ($PropertyName in @('CurrentValue','Value','CurrentSetting','SettingValue')) {
            if ($Setting.PSObject.Properties.Name -contains $PropertyName) {
                $Candidate = $Setting.$PropertyName
                if ($null -ne $Candidate -and -not [string]::IsNullOrWhiteSpace([string]$Candidate)) {
                    $Value = [string]$Candidate
                    break
                }
            }
        }

        $Assessment = 'Review'
        if ($Value -match '(?i)enabled|enable|on|boot to hard drive|boot to normal boot order') {
            $Assessment = 'Pass'
        }
        elseif ($Value -match '(?i)disabled|disable|off') {
            $Assessment = 'Fail'
            $Result['WarningCount']++
        }

        $Items += [pscustomobject]@{
            Name = [string]$Setting.Name
            Value = $Value
            Assessment = $Assessment
        }
    }

    $Result.Items = $Items

    if ($Result.WarningCount -gt 0) {
        $Result.Status = 'Warning'
    }
    else {
        $Result.Status = 'OK'
    }

    return [pscustomobject]$Result
}

function Show-BiosAudit {
    param($Audit)

    Write-Host ''
    Write-Host 'BIOS / UEFI' -ForegroundColor White

    if ($Audit.Manufacturer) {
        Write-Host ('  Equipo       : {0} {1}' -f $Audit.Manufacturer, $Audit.Model)
        Write-Host ('  BIOS         : {0}' -f $Audit.BiosVersion)
    }

    switch ($Audit.Status) {
        'Skipped' {
            Write-Host '  Auditoria    : Omitida' -ForegroundColor Yellow
        }
        'NotHP' {
            Write-Host '  Auditoria    : No aplicable; auditoria WMI implementada solo para HP.' -ForegroundColor Gray
        }
        'HpWmiUnavailable' {
            Write-Host '  Auditoria    : HP detectado, pero HP BIOS WMI no esta disponible.' -ForegroundColor Yellow
        }
        'NoMatchingSettings' {
            Write-Host '  Auditoria    : No se localizaron ajustes WOL reconocibles.' -ForegroundColor Yellow
        }
        default {
            Write-Host ('  Auditoria    : {0}' -f $Audit.Status)

            foreach ($Item in $Audit.Items) {
                $Color = switch ($Item.Assessment) {
                    'Pass' { 'Green' }
                    'Fail' { 'Red' }
                    default { 'Yellow' }
                }

                Write-Host (
                    '    [{0}] {1}: {2}' -f
                    $Item.Assessment,
                    $Item.Name,
                    $Item.Value
                ) -ForegroundColor $Color
            }
        }
    }

    Write-Host ''
}

function Set-FastStartup {
    if ($KeepFastStartup) {
        Write-W0LLog 'Inicio rapido conservado por parametro -KeepFastStartup.'
        return
    }

    try {
        $Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
        Set-ItemProperty `
            -LiteralPath $Path `
            -Name 'HiberbootEnabled' `
            -Value 0 `
            -Type DWord `
            -ErrorAction Stop

        Add-Change 'Inicio rapido desactivado.'
    }
    catch {
        Add-Warning ("No se pudo desactivar Inicio rapido: {0}" -f $_.Exception.Message)
    }
}

function Set-WakePowerManagement {
    param([Parameter(Mandatory)]$Adapter)

    try {
        $Current = Get-NetAdapterPowerManagement -Name $Adapter.Name -ErrorAction Stop
        $Params = @{
            Name = $Adapter.Name
            NoRestart = $true
            Confirm = $false
        }

        if (
            $Current.PSObject.Properties.Name -contains 'WakeOnMagicPacket' -and
            [string]$Current.WakeOnMagicPacket -ne 'Unsupported'
        ) {
            $Params['WakeOnMagicPacket'] = 'Enabled'
        }

        if (
            $Current.PSObject.Properties.Name -contains 'WakeOnPattern' -and
            [string]$Current.WakeOnPattern -ne 'Unsupported'
        ) {
            $Params['WakeOnPattern'] = 'Disabled'
        }

        if ($Params.Keys.Count -gt 3) {
            Set-NetAdapterPowerManagement @Params -ErrorAction Stop | Out-Null
            Add-Change 'Gestion de energia WOL configurada sin reiniciar la NIC.'
        }
        else {
            Add-Warning 'El controlador no expone WakeOnMagicPacket/WakeOnPattern mediante NetAdapter.'
        }
    }
    catch {
        Add-Warning ("No se pudo ajustar NetAdapterPowerManagement: {0}" -f $_.Exception.Message)
    }
}

function Find-PreferredDisplayValue {
    param(
        [AllowNull()]$Property,
        [Parameter(Mandatory)][ValidateSet('Enable','Disable')][string]$Mode
    )

    if ($null -eq $Property) {
        return $null
    }

    $Values = @($Property.ValidDisplayValues)

    if ($Values.Count -eq 0) {
        return $null
    }

    if ($Mode -eq 'Enable') {
        $Patterns = @(
            '(?i)^enabled?$',
            '(?i)^activad[oa]$',
            '(?i)magic packet',
            '(?i)^on$'
        )
    }
    else {
        $Patterns = @(
            '(?i)^disabled?$',
            '(?i)^desactivad[oa]$',
            '(?i)^off$'
        )
    }

    foreach ($Pattern in $Patterns) {
        $Match = $Values | Where-Object { [string]$_ -match $Pattern } | Select-Object -First 1
        if ($Match) {
            return [string]$Match
        }
    }

    return $null
}

function Set-WakeAdvancedProperties {
    param([Parameter(Mandatory)]$Adapter)

    try {
        $Properties = @(
            Get-NetAdapterAdvancedProperty `
                -Name $Adapter.Name `
                -AllProperties `
                -ErrorAction Stop
        )
    }
    catch {
        Add-Warning ("No se pudieron leer propiedades avanzadas: {0}" -f $_.Exception.Message)
        return
    }

    $Rules = @(
        @{
            Pattern = '(?i)wake.*magic|magic.*packet'
            Mode = 'Enable'
            Label = 'Wake on Magic Packet'
        },
        @{
            Pattern = '(?i)shutdown.*wake|wake.*shutdown'
            Mode = 'Enable'
            Label = 'Shutdown Wake-on-LAN'
        },
        @{
            Pattern = '(?i)wake.*pattern|pattern.*wake'
            Mode = 'Disable'
            Label = 'Wake on Pattern'
        }
    )

    foreach ($Rule in $Rules) {
        $Matches = @(
            $Properties |
                Where-Object {
                    [string]$_.DisplayName -match $Rule.Pattern
                }
        )

        foreach ($Property in $Matches) {
            $Desired = Find-PreferredDisplayValue -Property $Property -Mode $Rule.Mode

            if ([string]::IsNullOrWhiteSpace($Desired)) {
                Write-W0LLog (
                    "Propiedad '{0}' detectada, pero no se reconoce un valor seguro para automatizarla." -f
                    $Property.DisplayName
                ) 'WARN'
                continue
            }

            if ([string]$Property.DisplayValue -eq $Desired) {
                Write-W0LLog (
                    "Propiedad '{0}' ya esta en '{1}'." -f
                    $Property.DisplayName,
                    $Desired
                )
                continue
            }

            try {
                Set-NetAdapterAdvancedProperty `
                    -Name $Adapter.Name `
                    -DisplayName $Property.DisplayName `
                    -DisplayValue $Desired `
                    -NoRestart `
                    -ErrorAction Stop

                Add-Change (
                    "Propiedad '{0}' -> '{1}'." -f
                    $Property.DisplayName,
                    $Desired
                )
            }
            catch {
                Add-Warning (
                    "No se pudo cambiar '{0}': {1}" -f
                    $Property.DisplayName,
                    $_.Exception.Message
                )
            }
        }
    }
}

function Enable-DeviceWake {
    param([Parameter(Mandatory)]$Adapter)

    try {
        $DeviceName = [string]$Adapter.InterfaceDescription
        $Output = @(& powercfg.exe /deviceenablewake $DeviceName 2>&1)

        if ($LASTEXITCODE -ne 0) {
            throw (($Output | Out-String).Trim())
        }

        Add-Change ("Dispositivo armado para despertar: {0}" -f $DeviceName)
    }
    catch {
        Add-Warning ("powercfg /deviceenablewake no pudo aplicarse: {0}" -f $_.Exception.Message)
    }
}

function Restart-W0LAdapter {
    param([Parameter(Mandatory)]$Adapter)

    if (-not $RestartAdapter) {
        Write-W0LLog (
            'No se reinicia el adaptador. Es el comportamiento seguro por defecto para no cortar sesiones remotas.'
        )
        return
    }

    Write-Host ''
    Write-Host 'ATENCION: reiniciar la NIC puede cortar una sesion remota actual.' -ForegroundColor Yellow

    try {
        Restart-NetAdapter -Name $Adapter.Name -Confirm:$false -ErrorAction Stop
        Add-Change 'Adaptador reiniciado para aplicar cambios.'
        Start-Sleep -Seconds 3
    }
    catch {
        Add-Warning ("No se pudo reiniciar el adaptador: {0}" -f $_.Exception.Message)
    }
}

function Get-WakeArmedDevices {
    try {
        return @(& powercfg.exe /devicequery wake_armed 2>$null)
    }
    catch {
        return @()
    }
}

function Show-Diagnostics {
    param(
        [Parameter(Mandatory)]$Adapter,
        $BiosAudit
    )

    $WakeArmed = Get-WakeArmedDevices
    $IsArmed = [bool](
        $WakeArmed |
            Where-Object {
                [string]$_ -eq [string]$Adapter.InterfaceDescription
            }
    )

    $PowerManagement = $null
    try {
        $PowerManagement = Get-NetAdapterPowerManagement -Name $Adapter.Name -ErrorAction Stop
    }
    catch {
    }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host '                       DIAGNOSTICO WOL' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ('  Adaptador                 : {0}' -f $Adapter.Name)
    Write-Host ('  Descripcion               : {0}' -f $Adapter.InterfaceDescription)
    Write-Host ('  Estado                    : {0}' -f $Adapter.Status)
    Write-Host ('  MAC                       : {0}' -f $Adapter.MacAddress)
    Write-Host ('  powercfg wake_armed       : {0}' -f $(if ($IsArmed) { 'SI' } else { 'NO / NO VERIFICABLE' }))

    if ($PowerManagement) {
        if ($PowerManagement.PSObject.Properties.Name -contains 'WakeOnMagicPacket') {
            Write-Host ('  WakeOnMagicPacket         : {0}' -f $PowerManagement.WakeOnMagicPacket)
        }

        if ($PowerManagement.PSObject.Properties.Name -contains 'WakeOnPattern') {
            Write-Host ('  WakeOnPattern             : {0}' -f $PowerManagement.WakeOnPattern)
        }
    }

    Write-Host ('  BIOS audit                : {0}' -f $BiosAudit.Status)
    Write-Host '============================================================' -ForegroundColor DarkGreen
    Write-Host ''

    $Report = [ordered]@{
        Timestamp = (Get-Date).ToString('o')
        ComputerName = $env:COMPUTERNAME
        Adapter = [ordered]@{
            Name = [string]$Adapter.Name
            Description = [string]$Adapter.InterfaceDescription
            Status = [string]$Adapter.Status
            MacAddress = [string]$Adapter.MacAddress
        }
        WakeArmed = $IsArmed
        BiosAudit = $BiosAudit
        SuccessCount = $script:SuccessCount
        WarningCount = $script:WarningCount
        ErrorCount = $script:ErrorCount
    }

    try {
        $Report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportFile -Encoding UTF8
        Write-W0LLog ("Informe JSON: {0}" -f $ReportFile)
    }
    catch {
        Add-Warning ("No se pudo guardar el informe JSON: {0}" -f $_.Exception.Message)
    }
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

Write-W0LLog ('Iniciando {0} v{1}.' -f $ProjectName, $Version)
Write-W0LLog ('Equipo: {0} | Usuario: {1}' -f $env:COMPUTERNAME, $env:USERNAME)

$Adapter = Select-W0LAdapter -RequestedName $AdapterName
Write-W0LLog (
    "Adaptador objetivo: {0} | {1} | MAC {2}" -f
    $Adapter.Name,
    $Adapter.InterfaceDescription,
    $Adapter.MacAddress
)

$BiosAudit = Get-HpBiosAudit -Skip:$SkipBiosAudit
Show-BiosAudit -Audit $BiosAudit

if (
    -not $CheckOnly -and
    $BiosAudit.WarningCount -gt 0 -and
    -not $ContinueOnBiosWarning -and
    [Environment]::UserInteractive
) {
    $Answer = Read-Host 'La auditoria BIOS tiene advertencias. Continuar con Windows? [S/N]'
    if ($Answer -notmatch '^(?i)s|si|y|yes$') {
        Write-W0LLog 'Operacion cancelada por el usuario.' 'WARN'
        Show-Diagnostics -Adapter $Adapter -BiosAudit $BiosAudit
        Show-Summary
        return
    }
}

if (-not $CheckOnly) {
    Set-FastStartup
    Set-WakePowerManagement -Adapter $Adapter
    Set-WakeAdvancedProperties -Adapter $Adapter
    Enable-DeviceWake -Adapter $Adapter
    Restart-W0LAdapter -Adapter $Adapter
}

Show-Diagnostics -Adapter $Adapter -BiosAudit $BiosAudit
Show-Summary

Write-Host ''
Write-Host 'NOTA: WOL desde apagado S5 depende tambien de BIOS/UEFI, firmware, NIC, docking y red.' -ForegroundColor Gray
Write-Host 'W0L configura Windows, pero no puede imponer capacidades que el hardware no tenga.' -ForegroundColor Gray
Write-Host ''

if (-not $NoPause -and [Environment]::UserInteractive) {
    Write-Host 'Pulsa ENTER para cerrar.' -ForegroundColor DarkGray
    [void](Read-Host)
}
