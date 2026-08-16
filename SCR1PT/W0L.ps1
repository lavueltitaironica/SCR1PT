#Requires -Version 5.1

<#
.SYNOPSIS
    Configura Wake-on-LAN (WOL) en un adaptador de red fisico.

.DESCRIPTION
    - Solicita elevacion a administrador si es necesario.
    - Audita previamente los ajustes WOL expuestos por la BIOS/UEFI de equipos HP.
    - Permite elegir un adaptador fisico, incluso si esta desconectado.
    - Activa Wake on Magic Packet y limita el despertar a paquetes magicos.
    - Activa la administracion de energia que permite armar el adaptador.
    - Aplica propiedades avanzadas WOL expuestas por el controlador.
    - Registra el dispositivo con powercfg /deviceenablewake.
    - Desactiva Inicio rapido por defecto, sin desactivar la hibernacion.
    - Verifica la configuracion y crea un registro en ProgramData.

    La auditoria de BIOS es de solo lectura: informa de valores correctos,
    incorrectos o no verificables, pero no modifica firmware. La configuracion
    de Windows no puede garantizar por si sola WOL desde apagado S5; el resultado
    final depende del equipo, la BIOS, el firmware y, si se usa, la docking.

.PARAMETER AdapterName
    Nombre exacto del adaptador. Si se omite, se muestra un menu interactivo.

.PARAMETER KeepFastStartup
    Conserva Inicio rapido. Por defecto se desactiva para evitar el apagado
    hibrido, que no arma el adaptador para WOL.

.PARAMETER NoAdapterRestart
    No reinicia el adaptador al terminar. Los cambios se aplicaran tras
    reiniciar el equipo o deshabilitar/habilitar manualmente el adaptador.

.PARAMETER SkipBiosAudit
    Omite la auditoria previa de BIOS/UEFI. No se recomienda salvo que la BIOS
    ya se haya comprobado manualmente.

.PARAMETER ContinueOnBiosWarning
    Permite continuar sin confirmacion adicional cuando la auditoria detecta
    ajustes criticos incorrectos. No modifica esos ajustes de BIOS.

.EXAMPLE
    .\Configurar-WakeOnLAN.ps1

.EXAMPLE
    .\Configurar-WakeOnLAN.ps1 -AdapterName "Ethernet"

.EXAMPLE
    .\Configurar-WakeOnLAN.ps1 -KeepFastStartup -NoAdapterRestart

.EXAMPLE
    .\Configurar-WakeOnLAN.ps1 -AdapterName "Ethernet" -ContinueOnBiosWarning

.NOTES
    Version 1.2.0 (15/08/2026).
    Incorpora auditoria previa y de solo lectura de BIOS/UEFI HP mediante WMI.
    Incorpora la cabecera visual comun T3ST-SCR1PT.
    Conserva el selector visual, backup, registro y verificacion de la v1.1.0.
    Compatible con Windows PowerShell 5.1 y versiones posteriores de
    PowerShell ejecutadas en Windows.

    Para ejecutar mediante "irm URL | iex", abre PowerShell como administrador.
    La elevacion automatica solo esta disponible al ejecutar un archivo .ps1,
    porque una expresion remota no proporciona al script una ruta reutilizable.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [string]$AdapterName,

    [Parameter()]
    [switch]$KeepFastStartup,

    [Parameter()]
    [switch]$NoAdapterRestart,

    [Parameter()]
    [switch]$SkipBiosAudit,

    [Parameter()]
    [switch]$ContinueOnBiosWarning
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Warnings = New-Object 'System.Collections.Generic.List[string]'
$script:AppliedChanges = New-Object 'System.Collections.Generic.List[string]'
$script:TranscriptStarted = $false
$script:ExitCode = 0
$script:BiosAudit = $null
$script:T3stBrand = 'T3ST-SCR1PT'
$script:T3stModule = 'WOL CONFIGURATOR'
$script:T3stVersion = '1.2.0'

function Show-T3stHeader {
    $banner = @(
        'TTTTTTT  333333   SSSSSS  TTTTTTT       SSSSSS  CCCCC  RRRRR    1   PPPPPP  TTTTTTT'
        '   T          33  SS         T          SS      CC     RR  RR  11   PP  PP    T'
        '   T       3333   SSSSSS     T    ---   SSSSSS  CC     RRRRR    1   PPPPPP    T'
        '   T          33      SS     T              SS  CC     RR RR    1   PP        T'
        '   T      333333  SSSSSS     T          SSSSSS   CCCCC RR  RR  111  PP        T'
    )

    foreach ($line in $banner) {
        Write-Host $line -ForegroundColor Green
    }
    Write-Host ''
    Write-Host ("{0}  //  {1}" -f $script:T3stBrand, $script:T3stModule) -ForegroundColor Green
    Write-Host ("La Vueltita Ironica - SCR1PT  |  Version {0}" -f $script:T3stVersion) -ForegroundColor DarkGray
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Write-Success {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Add-WolWarning {
    param([Parameter(Mandatory)][string]$Text)
    $script:Warnings.Add($Text)
    Write-Warning $Text
}

function Add-WolChange {
    param([Parameter(Mandatory)][string]$Text)
    $script:AppliedChanges.Add($Text)
    Write-Success $Text
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-HpBiosSettings {
    try {
        return @(Get-CimInstance -Namespace 'root/HP/InstrumentedBIOS' `
            -ClassName 'HP_BIOSSetting' -ErrorAction Stop |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Name) })
    }
    catch {
        if (Get-Command Get-WmiObject -ErrorAction SilentlyContinue) {
            try {
                return @(Get-WmiObject -Namespace 'root\HP\InstrumentedBIOS' `
                    -Class 'HP_BIOSSetting' -ErrorAction Stop |
                    Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Name) })
            }
            catch {
                throw "La interfaz HP BIOS WMI no esta disponible: $($_.Exception.Message)"
            }
        }
        throw "La interfaz HP BIOS WMI no esta disponible: $($_.Exception.Message)"
    }
}

function Get-NormalizedBiosValue {
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return '' }
    $text = ((@($Value) -join ',') -replace '\s+', ' ').Trim()

    # Los formatos BCU/CMSL pueden marcar con * el valor actualmente activo.
    if ($text -match '(?i)(?:^|,)\s*\*\s*([^,]+)') {
        return $matches[1].Trim()
    }
    return $text
}

function Get-BiosValueAssessment {
    param(
        [AllowEmptyString()][string]$Value,
        [Parameter(Mandatory)][ValidateSet('Enabled', 'Disabled', 'Information')][string]$Desired
    )

    if ($Desired -eq 'Information') { return 'Info' }
    if ([string]::IsNullOrWhiteSpace($Value)) { return 'Unknown' }

    $enabledPattern = '(?i)^(enabled?|on|yes|si|activad[oa]|habilitad[oa]|encendid[oa]|boot to network|follow boot order|network boot)$'
    $disabledPattern = '(?i)^(disabled?|off|no|desactivad[oa]|deshabilitad[oa]|apagad[oa])$'

    $isEnabled = $Value -match $enabledPattern
    $isDisabled = $Value -match $disabledPattern

    if ($Desired -eq 'Enabled') {
        if ($isEnabled) { return 'Pass' }
        if ($isDisabled) { return 'Fail' }
    }
    else {
        if ($isDisabled) { return 'Pass' }
        if ($isEnabled) { return 'Fail' }
    }
    return 'Unknown'
}

function Test-HpBiosWolReadiness {
    param(
        [Parameter(Mandatory)]$Adapter,
        [switch]$Skip
    )

    Write-Section 'Auditoria previa de BIOS/UEFI'

    $items = New-Object 'System.Collections.Generic.List[object]'
    $result = [ordered]@{
        CheckedAt          = (Get-Date).ToString('o')
        Manufacturer       = $null
        Model              = $null
        BiosVersion        = $null
        Supported          = $false
        Status             = 'Unavailable'
        CriticalIssues     = 0
        ReviewItems        = 0
        UsesExternalNic    = $false
        SetupPassword      = 'No verificable'
        Items              = $items
    }

    if ($Skip) {
        $result.Status = 'Skipped'
        Add-WolWarning 'La auditoria de BIOS/UEFI se ha omitido mediante -SkipBiosAudit.'
        return [pscustomobject]$result
    }

    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        $result.Manufacturer = [string]$computerSystem.Manufacturer
        $result.Model = [string]$computerSystem.Model
        $result.BiosVersion = (@($bios.SMBIOSBIOSVersion) -join ', ')
    }
    catch {
        Add-WolWarning "No se ha podido identificar el equipo o su BIOS: $($_.Exception.Message)"
        $result.ReviewItems++
        return [pscustomobject]$result
    }

    Write-Host ("Fabricante / modelo : {0} / {1}" -f $result.Manufacturer, $result.Model)
    Write-Host ("Version de BIOS     : {0}" -f $result.BiosVersion)

    if ($result.Manufacturer -notmatch '(?i)\bHP\b|Hewlett[ -]Packard') {
        Add-WolWarning 'El equipo no se identifica como HP. La auditoria BIOS especifica de HP no es aplicable.'
        $result.ReviewItems++
        return [pscustomobject]$result
    }

    $settings = @()
    try {
        $settings = @(Get-HpBiosSettings)
    }
    catch {
        Add-WolWarning $_.Exception.Message
        $result.ReviewItems++
        return [pscustomobject]$result
    }

    if ($settings.Count -eq 0) {
        Add-WolWarning 'HP WMI responde, pero no ha devuelto ajustes de BIOS.'
        $result.ReviewItems++
        return [pscustomobject]$result
    }

    $result.Supported = $true
    $adapterIdentity = "{0} {1}" -f $Adapter.InterfaceDescription, $Adapter.PnPDeviceID
    $result.UsesExternalNic = $adapterIdentity -match '(?i)USB|dock|Thunderbolt|Type.?C'

    $passwordSettings = @($settings | Where-Object {
        [string]$_.Name -match '(?i)(setup|administrator|admin).*(password|contrasena)'
    })
    if ($passwordSettings.Count -gt 0) {
        $passwordValue = Get-NormalizedBiosValue -Value $passwordSettings[0].CurrentValue
        if ($passwordValue -match '(?i)not set|unset|clear|no configurad|sin configurar|disabled') {
            $result.SetupPassword = 'No configurada'
        }
        elseif ($passwordValue -match '(?i)set|configured|configurad|enabled') {
            $result.SetupPassword = 'Configurada'
        }
    }

    $rules = @(
        [pscustomobject]@{
            Id            = 'WakeOnLan'
            Label         = 'Wake on LAN'
            NamePattern   = '(?i)((wake|reactiv|activar).*\bLAN\b|\bLAN\b.*(wake|reactiv|activar))'
            ExcludePattern = '(?i)battery|bateria'
            Desired       = 'Enabled'
            Required      = $true
            CriticalIfBad = $true
        },
        [pscustomobject]@{
            Id            = 'S5PowerSaving'
            Label         = 'Ahorro maximo de energia en S5'
            NamePattern   = '(?i)(s5.*(maximum|maximo|max).*power|maximum.*power.*s5|deep.*sleep)'
            ExcludePattern = $null
            Desired       = 'Disabled'
            Required      = $false
            CriticalIfBad = $true
        },
        [pscustomobject]@{
            Id            = 'ExternalWake'
            Label         = 'Activacion mediante USB/USB-C/Thunderbolt/dock'
            NamePattern   = '(?i)(((usb|thunderbolt|type.?c|dock).*(wake|wakeup|reactiv|activar))|((wake|wakeup|reactiv|activar).*(usb|thunderbolt|type.?c|dock)))'
            ExcludePattern = $null
            Desired       = 'Enabled'
            Required      = [bool]$result.UsesExternalNic
            CriticalIfBad = $false
        },
        [pscustomobject]@{
            Id            = 'MacPassThrough'
            Label         = 'MAC Address Pass-Through'
            NamePattern   = '(?i)(mac.*(pass|paso)|host.?based.?mac)'
            ExcludePattern = $null
            Desired       = 'Information'
            Required      = $false
            CriticalIfBad = $false
        },
        [pscustomobject]@{
            Id             = 'WakeOnLanBattery'
            Label          = 'Wake on LAN usando bateria'
            NamePattern    = '(?i)((wake|reactiv|activar).*\bLAN\b|\bLAN\b.*(wake|reactiv|activar)).*(battery|bateria)|(battery|bateria).*((wake|reactiv|activar).*\bLAN\b)'
            ExcludePattern = $null
            Desired        = 'Information'
            Required       = $false
            CriticalIfBad  = $false
        }
    )

    foreach ($rule in $rules) {
        $matchedSettings = @($settings | Where-Object {
            ([string]$_.Name -match $rule.NamePattern) -and
            ([string]::IsNullOrWhiteSpace([string]$rule.ExcludePattern) -or
                [string]$_.Name -notmatch $rule.ExcludePattern)
        })
        if ($matchedSettings.Count -eq 0) {
            $status = if ($rule.Required) { 'Unknown' } else { 'NotExposed' }
            $items.Add([pscustomobject]@{
                Rule         = $rule.Id
                Label        = $rule.Label
                SettingName  = $null
                CurrentValue = $null
                Desired      = $rule.Desired
                Assessment   = $status
            })

            if ($rule.Required) {
                $result.ReviewItems++
                Write-Host ("[AVISO] {0}: la BIOS no expone un ajuste reconocible." -f $rule.Label) -ForegroundColor Yellow
            }
            else {
                Write-Host ("[--] {0}: no expuesto por esta BIOS." -f $rule.Label) -ForegroundColor DarkGray
            }
            continue
        }

        foreach ($setting in $matchedSettings) {
            $currentValue = Get-NormalizedBiosValue -Value $setting.CurrentValue
            $assessment = Get-BiosValueAssessment -Value $currentValue -Desired $rule.Desired
            $items.Add([pscustomobject]@{
                Rule         = $rule.Id
                Label        = $rule.Label
                SettingName  = [string]$setting.Name
                CurrentValue = $currentValue
                Desired      = $rule.Desired
                Assessment   = $assessment
            })

            switch ($assessment) {
                'Pass' {
                    Write-Host ("[OK] {0}: {1}" -f $setting.Name, $currentValue) -ForegroundColor Green
                }
                'Fail' {
                    if ($rule.CriticalIfBad) {
                        $result.CriticalIssues++
                        Write-Host ("[FALLO] {0}: {1} (se necesita {2})" -f `
                            $setting.Name, $currentValue, $rule.Desired) -ForegroundColor Red
                    }
                    else {
                        $result.ReviewItems++
                        Write-Host ("[AVISO] {0}: {1}" -f $setting.Name, $currentValue) -ForegroundColor Yellow
                    }
                }
                'Unknown' {
                    $result.ReviewItems++
                    Write-Host ("[AVISO] {0}: valor no reconocido '{1}'." -f `
                        $setting.Name, $currentValue) -ForegroundColor Yellow
                }
                'Info' {
                    Write-Host ("[INFO] {0}: {1}" -f $setting.Name, $currentValue) -ForegroundColor Gray
                }
            }
        }
    }

    Write-Host ("Contrasena de BIOS  : {0}" -f $result.SetupPassword) -ForegroundColor DarkGray
    Write-Host ("Ruta externa/dock   : {0}" -f $(if ($result.UsesExternalNic) { 'Detectada' } else { 'No detectada' })) -ForegroundColor DarkGray

    if ($result.CriticalIssues -gt 0) {
        $result.Status = 'Critical'
        Add-WolWarning "La auditoria BIOS ha detectado $($result.CriticalIssues) ajuste(s) critico(s) incompatible(s) con WOL."
    }
    elseif ($result.ReviewItems -gt 0) {
        $result.Status = 'Review'
        Add-WolWarning "La auditoria BIOS contiene $($result.ReviewItems) comprobacion(es) no concluyente(s)."
    }
    else {
        $result.Status = 'Ready'
        Write-Success 'Los ajustes WOL expuestos por la BIOS presentan valores compatibles.'
    }

    return [pscustomobject]$result
}

function Confirm-BiosAuditContinuation {
    param(
        [AllowNull()]$Audit,
        [switch]$Override
    )

    if ($null -eq $Audit -or $Audit.Status -in @('Ready', 'Skipped')) { return }
    if ($Override) {
        Add-WolWarning 'Se continua pese al resultado de BIOS mediante -ContinueOnBiosWarning.'
        return
    }

    Write-Host ''
    if ($Audit.Status -eq 'Critical') {
        Write-Host 'La BIOS contiene ajustes criticos incompatibles con WOL.' -ForegroundColor Red
        $answer = Read-Host 'Continuar configurando Windows de todas formas? [s/N]'
        if ($answer -notmatch '^(?i)s(i)?$') {
            throw [System.OperationCanceledException]::new('Operacion detenida para corregir primero la BIOS/UEFI.')
        }
    }
    else {
        Write-Host 'La auditoria BIOS no ha podido verificar todos los requisitos.' -ForegroundColor Yellow
        $answer = Read-Host 'Continuar con la configuracion de Windows? [S/n]'
        if ($answer -match '^(?i)n(o)?$') {
            throw [System.OperationCanceledException]::new('Operacion detenida para revisar manualmente la BIOS/UEFI.')
        }
    }
}

function Get-PhysicalNetworkAdapters {
    try {
        return @(Get-NetAdapter -Physical -ErrorAction Stop |
            Where-Object { $_.HardwareInterface } |
            Sort-Object -Property ifIndex)
    }
    catch {
        return @(Get-NetAdapter -ErrorAction Stop |
            Where-Object { $_.HardwareInterface } |
            Sort-Object -Property ifIndex)
    }
}

function Get-AdapterTypeLabel {
    param([Parameter(Mandatory)]$Adapter)

    $description = "{0} {1} {2}" -f $Adapter.MediaType, $Adapter.PhysicalMediaType, $Adapter.InterfaceDescription
    if ($description -match '(?i)802\.11|wireless|wi-?fi|wlan') {
        return 'Wi-Fi'
    }
    if ($description -match '(?i)bluetooth') {
        return 'Bluetooth'
    }
    if ($Adapter.InterfaceType -eq 6 -or $description -match '(?i)802\.3|ethernet|gigabit|2\.5gbe|10gbe') {
        return 'Ethernet'
    }
    return 'Otro'
}

function Get-AdapterFriendlyLabel {
    param([Parameter(Mandatory)]$Adapter)

    $type = Get-AdapterTypeLabel -Adapter $Adapter
    $description = [string]$Adapter.InterfaceDescription

    switch ($type) {
        'Ethernet' {
            if ($description -match '(?i)USB|dock') {
                return 'Ethernet por cable mediante docking/USB'
            }
            return 'Ethernet por cable'
        }
        'Wi-Fi' {
            return 'Wi-Fi inalambrico'
        }
        'Bluetooth' {
            return 'Conexion Bluetooth'
        }
        default {
            return 'Otro adaptador de red'
        }
    }
}

function Get-AdapterStatusLabel {
    param([Parameter(Mandatory)]$Adapter)

    switch ([string]$Adapter.Status) {
        'Up'           { return 'Conectado' }
        'Disconnected' { return 'Desconectado' }
        'Disabled'     { return 'Deshabilitado' }
        'Not Present'  { return 'No presente' }
        default        { return [string]$Adapter.Status }
    }
}

function Get-AdapterConnectionInfo {
    param([Parameter(Mandatory)]$Adapter)

    $ipv4Address = $null
    $gateway = $null

    try {
        $configuration = Get-NetIPConfiguration -InterfaceIndex $Adapter.ifIndex -ErrorAction Stop
        if ($configuration) {
            $addressObject = @($configuration.IPv4Address |
                Where-Object { $_.IPAddress } |
                Select-Object -First 1)
            if ($addressObject.Count -gt 0) {
                $ipv4Address = [string]$addressObject[0].IPAddress
            }

            $gatewayObject = @($configuration.IPv4DefaultGateway |
                Where-Object { $_.NextHop } |
                Select-Object -First 1)
            if ($gatewayObject.Count -gt 0) {
                $gateway = [string]$gatewayObject[0].NextHop
            }
        }
    }
    catch {
        # Un adaptador desconectado puede no tener configuracion IP activa.
    }

    return [pscustomobject]@{
        IPv4       = $ipv4Address
        Gateway    = $gateway
        HasGateway = -not [string]::IsNullOrWhiteSpace($gateway)
    }
}

function Get-AdapterRecommendationReason {
    param(
        [Parameter(Mandatory)]$Adapter,
        [Parameter(Mandatory)]$ConnectionInfo
    )

    $type = Get-AdapterTypeLabel -Adapter $Adapter
    if ($type -ne 'Ethernet') {
        if ($type -eq 'Wi-Fi') {
            return 'No recomendado: WOL clasico utiliza Ethernet por cable.'
        }
        return 'No recomendado para Wake-on-LAN.'
    }

    if ([string]$Adapter.Status -eq 'Up' -and $ConnectionInfo.HasGateway) {
        return 'Recomendado: Ethernet conectado y utilizado actualmente por Windows.'
    }
    if ([string]$Adapter.Status -eq 'Up') {
        return 'Candidato valido: Ethernet conectado, pero sin puerta de enlace detectada.'
    }
    return 'Candidato Ethernet, aunque actualmente aparece desconectado.'
}

function Select-NetworkAdapter {
    param(
        [Parameter(Mandatory)][array]$Adapters,
        [string]$RequestedName
    )

    if ($RequestedName) {
        $matches = @($Adapters | Where-Object { $_.Name -ieq $RequestedName })
        if ($matches.Count -eq 0) {
            throw "No existe un adaptador fisico con el nombre exacto '$RequestedName'."
        }
        if ($matches.Count -gt 1) {
            throw "Hay mas de un adaptador con el nombre '$RequestedName'. Ejecuta el script sin -AdapterName."
        }
        return $matches[0]
    }

    Write-Section 'Adaptadores de red fisicos'
    Write-Host 'Para Wake-on-LAN clasico debes elegir el adaptador ETHERNET POR CABLE.' -ForegroundColor Yellow
    Write-Host 'No elijas Wi-Fi ni Bluetooth. El script marca automaticamente la opcion mas adecuada.' -ForegroundColor Yellow
    Write-Host ''

    $menu = for ($i = 0; $i -lt $Adapters.Count; $i++) {
        $adapter = $Adapters[$i]
        $connectionInfo = Get-AdapterConnectionInfo -Adapter $adapter
        $type = Get-AdapterTypeLabel -Adapter $adapter
        $score = 0

        if ($type -eq 'Ethernet') { $score += 1000 }
        if ([string]$adapter.Status -eq 'Up') { $score += 200 }
        if ($connectionInfo.HasGateway) { $score += 100 }
        if ([string]$adapter.InterfaceDescription -notmatch '(?i)USB|dock') { $score += 10 }

        [pscustomobject]@{
            Number         = $i + 1
            Adapter        = $adapter
            Type           = $type
            FriendlyLabel  = Get-AdapterFriendlyLabel -Adapter $adapter
            StatusLabel    = Get-AdapterStatusLabel -Adapter $adapter
            ConnectionInfo = $connectionInfo
            Score          = $score
        }
    }

    $ethernetOptions = @($menu | Where-Object { $_.Type -eq 'Ethernet' })
    $recommended = $null
    if ($ethernetOptions.Count -gt 0) {
        $recommended = @($ethernetOptions |
            Sort-Object -Property Score -Descending |
            Select-Object -First 1)[0]
    }

    foreach ($option in $menu) {
        $isRecommended = $recommended -and $option.Number -eq $recommended.Number
        $marker = if ($isRecommended) { '  [RECOMENDADO]' } else { '' }
        $headingColor = if ($isRecommended) { 'Green' } elseif ($option.Type -eq 'Ethernet') { 'Cyan' } else { 'Gray' }
        $ipv4Text = if ($option.ConnectionInfo.IPv4) { $option.ConnectionInfo.IPv4 } else { 'No asignada' }
        $gatewayText = if ($option.ConnectionInfo.Gateway) { $option.ConnectionInfo.Gateway } else { 'No detectada' }
        $reason = Get-AdapterRecommendationReason -Adapter $option.Adapter -ConnectionInfo $option.ConnectionInfo
        if ($isRecommended) {
            $reasonColor = 'Green'
        }
        elseif ($option.Type -eq 'Ethernet') {
            $reasonColor = 'Cyan'
        }
        else {
            $reasonColor = 'DarkGray'
        }

        Write-Host ("[{0}] {1}{2}" -f $option.Number, $option.FriendlyLabel, $marker) -ForegroundColor $headingColor
        Write-Host ("    Nombre en Windows : {0}" -f $option.Adapter.Name)
        Write-Host ("    Estado            : {0}" -f $option.StatusLabel)
        Write-Host ("    Controlador       : {0}" -f $option.Adapter.InterfaceDescription)
        Write-Host ("    IPv4 / puerta     : {0} / {1}" -f $ipv4Text, $gatewayText)
        Write-Host ("    Velocidad         : {0}" -f $option.Adapter.LinkSpeed)
        Write-Host ("    Direccion MAC     : {0}" -f $option.Adapter.MacAddress)
        Write-Host ("    Valoracion        : {0}" -f $reason) -ForegroundColor $reasonColor
        Write-Host ''
    }

    if (-not $recommended) {
        Add-WolWarning 'No se ha detectado ningun adaptador Ethernet fisico. WOL clasico no puede configurarse sobre Wi-Fi o Bluetooth.'
        throw [System.InvalidOperationException]::new('Conecta o instala un adaptador Ethernet y vuelve a ejecutar el script.')
    }

    while ($true) {
        if ($recommended) {
            $answer = Read-Host "Elige un adaptador (1-$($Adapters.Count)), INTRO para usar el recomendado [$($recommended.Number)] o Q para cancelar"
            if ([string]::IsNullOrWhiteSpace($answer)) {
                Write-Host ("Seleccionado automaticamente: [{0}] {1}" -f $recommended.Number, $recommended.FriendlyLabel) -ForegroundColor Green
                return $recommended.Adapter
            }
        }
        else {
            $answer = Read-Host "Elige un adaptador (1-$($Adapters.Count)) o Q para cancelar"
        }

        if ($answer -match '^(?i)q$') {
            throw [System.OperationCanceledException]::new('Operacion cancelada por el usuario.')
        }

        $selectedNumber = 0
        if ([int]::TryParse($answer, [ref]$selectedNumber) -and
            $selectedNumber -ge 1 -and
            $selectedNumber -le $Adapters.Count) {
            $selectedOption = @($menu | Where-Object { $_.Number -eq $selectedNumber })[0]
            if ($selectedOption.Type -ne 'Ethernet') {
                Write-Host ''
                Write-Host 'Esa opcion no es Ethernet por cable y no sirve para WOL clasico.' -ForegroundColor Red
                if ($recommended) {
                    Write-Host ("Elige la opcion recomendada [{0}] o pulsa INTRO." -f $recommended.Number) -ForegroundColor Yellow
                }
                Write-Host ''
                continue
            }
            return $selectedOption.Adapter
        }

        Write-Host 'Seleccion no valida.' -ForegroundColor Yellow
    }
}

function Get-PowerManagementSnapshot {
    param([Parameter(Mandatory)][string]$Name)

    try {
        $power = Get-NetAdapterPowerManagement -Name $Name -ErrorAction Stop
        return [pscustomobject]@{
            AllowComputerToTurnOffDevice = $power.AllowComputerToTurnOffDevice
            WakeOnMagicPacket            = $power.WakeOnMagicPacket
            WakeOnPattern                = $power.WakeOnPattern
            DeviceSleepOnDisconnect      = $power.DeviceSleepOnDisconnect
            SelectiveSuspend             = $power.SelectiveSuspend
        }
    }
    catch {
        Add-WolWarning "No se ha podido leer la administracion de energia del adaptador: $($_.Exception.Message)"
        return $null
    }
}

function Get-RelevantAdvancedProperties {
    param([Parameter(Mandatory)][string]$Name)

    try {
        return @(Get-NetAdapterAdvancedProperty -Name $Name -AllProperties -ErrorAction Stop |
            Where-Object {
                $keyword = [string]$_.RegistryKeyword
                $display = [string]$_.DisplayName
                $keyword -match '(?i)wake|magic|PME' -or
                $display -match '(?i)wake|magic|PME|activar|reactivar|despertar|paquete|apagado'
            } |
            Select-Object -Property @('DisplayName', 'DisplayValue', 'RegistryKeyword', 'RegistryValue'))
    }
    catch {
        Add-WolWarning "No se han podido leer las propiedades avanzadas: $($_.Exception.Message)"
        return @()
    }
}

function Save-BeforeSnapshot {
    param(
        [Parameter(Mandatory)]$Adapter,
        [Parameter(Mandatory)][string]$Path,
        [AllowNull()]$BiosAudit
    )

    try {
        $fastStartupValue = $null
        $powerRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
        try {
            $fastStartupValue = (Get-ItemProperty -Path $powerRegistryPath -Name HiberbootEnabled -ErrorAction Stop).HiberbootEnabled
        }
        catch {
            $fastStartupValue = 'No definido'
        }

        $snapshot = [pscustomobject]@{
            CapturedAt       = (Get-Date).ToString('o')
            ComputerName     = $env:COMPUTERNAME
            Adapter          = [pscustomobject]@{
                Name                 = $Adapter.Name
                InterfaceDescription = $Adapter.InterfaceDescription
                Status               = $Adapter.Status
                LinkSpeed            = $Adapter.LinkSpeed
                MacAddress            = $Adapter.MacAddress
                InterfaceGuid         = $Adapter.InterfaceGuid
                PnPDeviceID           = $Adapter.PnPDeviceID
            }
            FastStartupValue = $fastStartupValue
            BiosAudit        = $BiosAudit
            PowerManagement  = Get-PowerManagementSnapshot -Name $Adapter.Name
            Advanced         = @(Get-RelevantAdvancedProperties -Name $Adapter.Name)
        }

        $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
        Write-Host "Copia de la configuracion anterior: $Path" -ForegroundColor DarkGray
    }
    catch {
        Add-WolWarning "No se ha podido guardar la copia previa: $($_.Exception.Message)"
    }
}

function Set-AdapterPowerOptions {
    param([Parameter(Mandatory)][string]$Name)

    Write-Section 'Administracion de energia del adaptador'

    if (-not (Get-Command Get-NetAdapterPowerManagement -ErrorAction SilentlyContinue) -or
        -not (Get-Command Set-NetAdapterPowerManagement -ErrorAction SilentlyContinue)) {
        Add-WolWarning 'Los cmdlets de administracion de energia NetAdapter no estan disponibles.'
        return
    }

    try {
        $power = Get-NetAdapterPowerManagement -Name $Name -ErrorAction Stop
        $desiredSettings = [ordered]@{
            AllowComputerToTurnOffDevice = 'Enabled'
            WakeOnMagicPacket            = 'Enabled'
            WakeOnPattern                = 'Disabled'
            DeviceSleepOnDisconnect      = 'Disabled'
            SelectiveSuspend             = 'Disabled'
        }

        $changed = New-Object 'System.Collections.Generic.List[string]'
        foreach ($settingName in $desiredSettings.Keys) {
            $property = $power.PSObject.Properties[$settingName]
            if ($null -eq $property) {
                continue
            }

            $currentValue = [string]$property.Value
            if ($currentValue -eq 'Unsupported') {
                Write-Host "[--] $settingName no esta soportado por el controlador." -ForegroundColor DarkGray
                continue
            }

            $desiredValue = $desiredSettings[$settingName]
            if ($currentValue -ne $desiredValue) {
                try {
                    $property.Value = $desiredValue
                    $changed.Add("$settingName=$desiredValue")
                }
                catch {
                    Add-WolWarning ("No se ha podido preparar {0}={1}: {2}" -f `
                        $settingName, $desiredValue, $_.Exception.Message)
                }
            }
            else {
                Write-Host "[OK] $settingName ya estaba en $desiredValue." -ForegroundColor DarkGreen
            }
        }

        if ($changed.Count -gt 0) {
            $power | Set-NetAdapterPowerManagement -NoRestart -Confirm:$false -ErrorAction Stop
            foreach ($item in $changed) {
                Add-WolChange "Configurado $item."
            }
        }
        else {
            Write-Success 'La administracion de energia ya tenia los valores WOL solicitados.'
        }
    }
    catch {
        Add-WolWarning "No se ha podido aplicar la administracion de energia: $($_.Exception.Message)"

        # Intento minimo de respaldo con los parametros oficialmente expuestos.
        try {
            Set-NetAdapterPowerManagement -Name $Name `
                -WakeOnMagicPacket Enabled `
                -WakeOnPattern Disabled `
                -DeviceSleepOnDisconnect Disabled `
                -SelectiveSuspend Disabled `
                -NoRestart -Confirm:$false -ErrorAction Stop
            Add-WolChange 'Aplicados los parametros WOL disponibles mediante el metodo alternativo.'
        }
        catch {
            Add-WolWarning "El metodo alternativo de energia tambien ha fallado: $($_.Exception.Message)"
        }
    }
}

function Find-DesiredRegistryValue {
    param(
        [Parameter(Mandatory)]$Property,
        [Parameter(Mandatory)][ValidateSet('Enable', 'Disable')][string]$Action
    )

    $displayValues = @($Property.ValidDisplayValues)
    $registryValues = @($Property.ValidRegistryValues)
    $pairCount = [Math]::Min($displayValues.Count, $registryValues.Count)

    if ($Action -eq 'Enable') {
        $wordPattern = '(?i)(^|\W)(enabled?|on|activad[oa]|habilitad[oa]|encendid[oa]|si)($|\W)'
        $fallback = '1'
    }
    else {
        $wordPattern = '(?i)(^|\W)(disabled?|off|desactivad[oa]|deshabilitad[oa]|apagad[oa]|no)($|\W)'
        $fallback = '0'
    }

    for ($i = 0; $i -lt $pairCount; $i++) {
        if ([string]$displayValues[$i] -match $wordPattern) {
            return [string]$registryValues[$i]
        }
    }

    $keyword = [string]$Property.RegistryKeyword
    if ($keyword -match '(?i)^\*?(WakeOnMagicPacket|WakeOnPattern|WakeOnLink|S5WakeOnLan|WakeFromShutdown|ShutdownWakeOnLan|WakeOnMagicPacketFromS5|EnablePME|PME)$') {
        return $fallback
    }

    return $null
}

function Set-RelevantAdvancedProperties {
    param([Parameter(Mandatory)][string]$Name)

    Write-Section 'Propiedades avanzadas del controlador'

    try {
        $properties = @(Get-NetAdapterAdvancedProperty -Name $Name -AllProperties -ErrorAction Stop)
    }
    catch {
        Add-WolWarning "No se pueden consultar las propiedades avanzadas: $($_.Exception.Message)"
        return
    }

    $rules = @(
        [pscustomobject]@{
            Label          = 'Wake on Magic Packet'
            Action         = 'Enable'
            KeywordPattern = '(?i)^\*?(WakeOnMagicPacket|WakeOnMagic)$'
            DisplayPattern = '(?i)(wake|activar|reactivar|despertar).*(magic|m.gic)|magic packet|paquete m.gico'
        },
        [pscustomobject]@{
            Label          = 'Wake desde apagado / S5'
            Action         = 'Enable'
            KeywordPattern = '(?i)^(S5WakeOnLan|WakeFromShutdown|ShutdownWakeOnLan|WakeOnMagicPacketFromS5)$'
            DisplayPattern = '(?i)(shutdown|apagado|s5).*(wake|activar|reactivar)|(wake|activar|reactivar).*(shutdown|apagado|s5)'
        },
        [pscustomobject]@{
            Label          = 'PME para WOL'
            Action         = 'Enable'
            KeywordPattern = '(?i)^(EnablePME|PME)$'
            DisplayPattern = '(?i)\bPME\b.*(wake|activar)|(wake|activar).*\bPME\b'
        },
        [pscustomobject]@{
            Label          = 'Wake on Pattern'
            Action         = 'Disable'
            KeywordPattern = '(?i)^\*?WakeOnPattern$'
            DisplayPattern = '(?i)(wake|activar|reactivar|despertar).*(pattern|patr.n)|(pattern|patr.n).*(wake|activar|reactivar)'
        },
        [pscustomobject]@{
            Label          = 'Wake on Link'
            Action         = 'Disable'
            KeywordPattern = '(?i)^\*?WakeOnLink$'
            DisplayPattern = '(?i)(wake|activar|reactivar|despertar).*(link|v.nculo|conexi.n)|(link|v.nculo|conexi.n).*(wake|activar|reactivar)'
        }
    )

    $processed = @{}
    $matchedCount = 0

    foreach ($rule in $rules) {
        $matchingProperties = @($properties | Where-Object {
            ([string]$_.RegistryKeyword -match $rule.KeywordPattern) -or
            ([string]$_.DisplayName -match $rule.DisplayPattern)
        })

        foreach ($property in $matchingProperties) {
            $identity = "{0}|{1}" -f $property.RegistryKeyword, $property.DisplayName
            if ($processed.ContainsKey($identity)) {
                continue
            }
            $processed[$identity] = $true
            $matchedCount++

            $targetValue = Find-DesiredRegistryValue -Property $property -Action $rule.Action
            if ($null -eq $targetValue) {
                Add-WolWarning "No se puede determinar un valor seguro para '$($property.DisplayName)' ($($property.RegistryKeyword)); no se modifica."
                continue
            }

            $currentValue = (@($property.RegistryValue) -join ',')
            if ($currentValue -eq $targetValue) {
                Write-Host "[OK] $($rule.Label) ya tiene el valor correcto ($targetValue)." -ForegroundColor DarkGreen
                continue
            }

            try {
                Set-NetAdapterAdvancedProperty -Name $Name `
                    -RegistryKeyword $property.RegistryKeyword `
                    -RegistryValue $targetValue `
                    -NoRestart -Confirm:$false -ErrorAction Stop
                Add-WolChange "Configurado $($rule.Label) [$($property.RegistryKeyword)]=$targetValue."
            }
            catch {
                Add-WolWarning "No se ha podido configurar '$($rule.Label)' ($($property.RegistryKeyword)): $($_.Exception.Message)"
            }
        }
    }

    if ($matchedCount -eq 0) {
        Add-WolWarning 'El controlador no expone propiedades avanzadas WOL reconocibles. Se conserva la configuracion aplicada por NetAdapter y powercfg.'
    }
}

function Normalize-DeviceName {
    param([AllowEmptyString()][string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace '\s+', ' ').Trim() -replace ' #\d+$', '').ToLowerInvariant()
}

function Enable-PowerCfgWake {
    param([Parameter(Mandatory)]$Adapter)

    Write-Section 'Registro del dispositivo en powercfg'

    $programmableDevices = @()
    try {
        $programmableDevices = @(& powercfg.exe /devicequery wake_programmable 2>$null |
            ForEach-Object { ([string]$_).Trim() } |
            Where-Object { $_ })
    }
    catch {
        Add-WolWarning "No se ha podido consultar powercfg /devicequery wake_programmable: $($_.Exception.Message)"
    }

    $adapterNames = @($Adapter.InterfaceDescription, $Adapter.Name) |
        Where-Object { $_ } |
        ForEach-Object { Normalize-DeviceName -Text ([string]$_) }

    $matches = @($programmableDevices | Where-Object {
        $deviceName = Normalize-DeviceName -Text ([string]$_)
        $isMatch = $false
        foreach ($adapterDeviceName in $adapterNames) {
            if ($deviceName -eq $adapterDeviceName -or
                ($deviceName.Length -gt 8 -and $adapterDeviceName.Contains($deviceName)) -or
                ($adapterDeviceName.Length -gt 8 -and $deviceName.Contains($adapterDeviceName))) {
                $isMatch = $true
                break
            }
        }
        $isMatch
    })

    if ($matches.Count -eq 0) {
        # Algunos controladores no aparecen en la consulta hasta que se intenta
        # armarlos directamente por su descripcion de interfaz.
        $matches = @([string]$Adapter.InterfaceDescription)
    }

    $armed = $false
    foreach ($device in ($matches | Select-Object -Unique)) {
        $output = @(& powercfg.exe /deviceenablewake $device 2>&1)
        if ($LASTEXITCODE -eq 0) {
            Add-WolChange "powercfg ha autorizado a '$device' para despertar el equipo."
            $armed = $true
            break
        }
        Write-Host ($output -join [Environment]::NewLine) -ForegroundColor DarkGray
    }

    if (-not $armed) {
        Add-WolWarning 'powercfg no ha podido armar el adaptador. Puede deberse al controlador, BIOS/UEFI o al uso de un dock USB.'
    }
}

function Set-FastStartup {
    param([switch]$Keep)

    Write-Section 'Inicio rapido de Windows'

    $powerRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
    if ($Keep) {
        Write-Host '[--] Inicio rapido se conserva por peticion del usuario.' -ForegroundColor Yellow
        return
    }

    try {
        $current = $null
        try {
            $current = (Get-ItemProperty -Path $powerRegistryPath -Name HiberbootEnabled -ErrorAction Stop).HiberbootEnabled
        }
        catch {
            $current = $null
        }

        if ($current -eq 0) {
            Write-Success 'Inicio rapido ya estaba desactivado.'
            return
        }

        New-ItemProperty -Path $powerRegistryPath -Name HiberbootEnabled `
            -PropertyType DWord -Value 0 -Force -ErrorAction Stop | Out-Null
        Add-WolChange 'Inicio rapido desactivado. La hibernacion no se ha desactivado.'
    }
    catch {
        Add-WolWarning "No se ha podido desactivar Inicio rapido: $($_.Exception.Message)"
    }
}

function Restart-SelectedAdapter {
    param(
        [Parameter(Mandatory)]$Adapter,
        [switch]$Skip
    )

    Write-Section 'Aplicacion de cambios'

    if ($Skip) {
        Add-WolWarning 'No se ha reiniciado el adaptador. Reinicia Windows para aplicar todas las propiedades avanzadas.'
        return
    }

    if ([string]$Adapter.Status -eq 'Disabled') {
        Add-WolWarning 'El adaptador esta deshabilitado. Los cambios se aplicaran cuando se habilite o se reinicie Windows.'
        return
    }

    try {
        Restart-NetAdapter -Name $Adapter.Name -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 2
        Add-WolChange 'Adaptador reiniciado para aplicar los cambios.'
    }
    catch {
        Add-WolWarning "No se ha podido reiniciar el adaptador: $($_.Exception.Message). Reinicia Windows manualmente."
    }
}

function Test-WolConfiguration {
    param(
        [Parameter(Mandatory)]$Adapter,
        [Parameter(Mandatory)][bool]$FastStartupWasKept,
        [AllowNull()]$BiosAudit
    )

    Write-Section 'Verificacion final'

    $freshAdapter = Get-NetAdapter -Name $Adapter.Name -ErrorAction SilentlyContinue
    $power = Get-PowerManagementSnapshot -Name $Adapter.Name
    $armedDevices = @(& powercfg.exe /devicequery wake_armed 2>$null |
        ForEach-Object { ([string]$_).Trim() } |
        Where-Object { $_ })

    $normalizedArmed = @($armedDevices | ForEach-Object { Normalize-DeviceName -Text $_ })
    $normalizedNames = @($Adapter.InterfaceDescription, $Adapter.Name) |
        Where-Object { $_ } |
        ForEach-Object { Normalize-DeviceName -Text ([string]$_) }
    $isArmed = $false
    foreach ($armedName in $normalizedArmed) {
        foreach ($adapterDeviceName in $normalizedNames) {
            if ($armedName -eq $adapterDeviceName -or
                ($armedName.Length -gt 8 -and $adapterDeviceName.Contains($armedName)) -or
                ($adapterDeviceName.Length -gt 8 -and $armedName.Contains($adapterDeviceName))) {
                $isArmed = $true
                break
            }
        }
        if ($isArmed) { break }
    }

    $fastStartupState = 'Conservado'
    if (-not $FastStartupWasKept) {
        try {
            $hiberboot = (Get-ItemProperty `
                -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' `
                -Name HiberbootEnabled -ErrorAction Stop).HiberbootEnabled
            if ($hiberboot -eq 0) { $fastStartupState = 'Desactivado' } else { $fastStartupState = 'Activo' }
        }
        catch {
            $fastStartupState = 'No verificable'
        }
    }

    $summary = [pscustomobject]@{
        Equipo                         = $env:COMPUTERNAME
        Adaptador                      = $Adapter.Name
        Controlador                    = $Adapter.InterfaceDescription
        Tipo                           = Get-AdapterTypeLabel -Adapter $Adapter
        Estado                         = if ($freshAdapter) { $freshAdapter.Status } else { 'No disponible' }
        MAC                            = $Adapter.MacAddress
        AllowComputerToTurnOffDevice   = if ($power) { $power.AllowComputerToTurnOffDevice } else { 'No verificable' }
        WakeOnMagicPacket              = if ($power) { $power.WakeOnMagicPacket } else { 'No verificable' }
        WakeOnPattern                  = if ($power) { $power.WakeOnPattern } else { 'No verificable' }
        DeviceSleepOnDisconnect        = if ($power) { $power.DeviceSleepOnDisconnect } else { 'No verificable' }
        SelectiveSuspend               = if ($power) { $power.SelectiveSuspend } else { 'No verificable' }
        RegistradoEnPowerCfgWakeArmed  = if ($isArmed) { 'Si' } else { 'No' }
        InicioRapido                   = $fastStartupState
        AuditoriaBIOS                  = if ($BiosAudit) { $BiosAudit.Status } else { 'No disponible' }
    }
    $summary | Format-List

    $coreConfigured = $power -and
        ([string]$power.WakeOnMagicPacket -eq 'Enabled') -and
        ([string]$power.WakeOnPattern -eq 'Disabled')

    if ($coreConfigured -and $isArmed) {
        Write-Success 'Windows ha quedado configurado para WOL mediante paquete magico.'
    }
    elseif ($coreConfigured) {
        Add-WolWarning 'La opcion de paquete magico esta activa, pero powercfg no muestra el adaptador en wake_armed.'
        $script:ExitCode = [Math]::Max($script:ExitCode, 2)
    }
    else {
        Add-WolWarning 'No se ha podido verificar completamente la configuracion WOL del controlador.'
        $script:ExitCode = [Math]::Max($script:ExitCode, 2)
    }

    $adapterType = Get-AdapterTypeLabel -Adapter $Adapter
    if ($adapterType -ne 'Ethernet') {
        Add-WolWarning "El adaptador seleccionado es de tipo $adapterType. WoWLAN depende del controlador y del firmware; WOL clasico usa Ethernet."
    }
    if ([string]$Adapter.InterfaceDescription -match '(?i)USB|dock') {
        Add-WolWarning 'El adaptador parece pertenecer a USB/dock. El dock debe conservar alimentacion y la BIOS debe admitir Wake on LAN/USB/dock.'
    }

    Write-Host 'Estados de energia disponibles (powercfg /a):' -ForegroundColor DarkGray
    & powercfg.exe /a 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
}

if ($env:OS -ne 'Windows_NT') {
    throw 'Este script solo puede ejecutarse en Windows.'
}

if (-not (Test-IsAdministrator)) {
    if (-not $PSCommandPath) {
        throw 'Esta ejecucion remota necesita permisos elevados. Abre PowerShell como administrador y repite el comando irm ... | iex.'
    }

    Write-Host 'Solicitando permisos de administrador...' -ForegroundColor Yellow
    $launchArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($AdapterName) {
        $escapedName = $AdapterName.Replace('"', '\"')
        $launchArguments += " -AdapterName `"$escapedName`""
    }
    if ($KeepFastStartup) { $launchArguments += ' -KeepFastStartup' }
    if ($NoAdapterRestart) { $launchArguments += ' -NoAdapterRestart' }
    if ($SkipBiosAudit) { $launchArguments += ' -SkipBiosAudit' }
    if ($ContinueOnBiosWarning) { $launchArguments += ' -ContinueOnBiosWarning' }
    if ($WhatIfPreference) { $launchArguments += ' -WhatIf' }

    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList $launchArguments -Verb RunAs -ErrorAction Stop | Out-Null
    $global:LASTEXITCODE = 0
    return
}

$logRoot = Join-Path $env:ProgramData 'WOL-Configurator\Logs'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $logRoot "WOL-$timestamp.log"
$beforePath = Join-Path $logRoot "WOL-$timestamp-antes.json"

try {
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    Start-Transcript -LiteralPath $logPath -Force | Out-Null
    $script:TranscriptStarted = $true

    Clear-Host
    Show-T3stHeader
    Write-Host 'Configuracion de Wake-on-LAN para Windows' -ForegroundColor Gray

    Import-Module NetAdapter -ErrorAction Stop
    $adapters = @(Get-PhysicalNetworkAdapters)
    if ($adapters.Count -eq 0) {
        throw 'No se han encontrado adaptadores de red fisicos.'
    }

    $selectedAdapter = Select-NetworkAdapter -Adapters $adapters -RequestedName $AdapterName
    $selectedType = Get-AdapterTypeLabel -Adapter $selectedAdapter

    Write-Section 'Seleccion'
    [pscustomobject]@{
        Nombre      = $selectedAdapter.Name
        Tipo        = $selectedType
        Estado      = $selectedAdapter.Status
        Velocidad   = $selectedAdapter.LinkSpeed
        MAC         = $selectedAdapter.MacAddress
        Controlador = $selectedAdapter.InterfaceDescription
    } | Format-List

    if ($selectedType -ne 'Ethernet') {
        Write-Host 'AVISO: WOL clasico esta pensado para Ethernet. Este adaptador puede requerir WoWLAN.' -ForegroundColor Yellow
    }
    if ([string]$selectedAdapter.Status -eq 'Up' -and -not $NoAdapterRestart) {
        Write-Host 'La red se interrumpira unos segundos al reiniciar el adaptador.' -ForegroundColor Yellow
    }

    $script:BiosAudit = Test-HpBiosWolReadiness -Adapter $selectedAdapter -Skip:$SkipBiosAudit
    Confirm-BiosAuditContinuation -Audit $script:BiosAudit -Override:$ContinueOnBiosWarning

    if (-not $AdapterName) {
        $confirmation = Read-Host 'Aplicar esta configuracion? [S/n]'
        if ($confirmation -match '^(?i)n(o)?$') {
            throw [System.OperationCanceledException]::new('Operacion cancelada por el usuario.')
        }
    }

    Save-BeforeSnapshot -Adapter $selectedAdapter -Path $beforePath -BiosAudit $script:BiosAudit

    if ($PSCmdlet.ShouldProcess($selectedAdapter.Name, 'Configurar Wake-on-LAN')) {
        Set-FastStartup -Keep:$KeepFastStartup
        Set-AdapterPowerOptions -Name $selectedAdapter.Name
        Set-RelevantAdvancedProperties -Name $selectedAdapter.Name
        Enable-PowerCfgWake -Adapter $selectedAdapter
        Restart-SelectedAdapter -Adapter $selectedAdapter -Skip:$NoAdapterRestart
        Test-WolConfiguration -Adapter $selectedAdapter `
            -FastStartupWasKept ([bool]$KeepFastStartup) -BiosAudit $script:BiosAudit
    }

    Write-Section 'Resultado'
    Write-Host "Cambios aplicados: $($script:AppliedChanges.Count)"
    Write-Host "Advertencias:      $($script:Warnings.Count)"
    Write-Host "Registro:           $logPath"
    Write-Host "Copia previa:       $beforePath"
    Write-Host "MAC para enviar el Magic Packet: $($selectedAdapter.MacAddress)" -ForegroundColor Cyan

    if ($script:Warnings.Count -gt 0) {
        Write-Host ''
        Write-Host 'Advertencias registradas:' -ForegroundColor Yellow
        foreach ($warningText in $script:Warnings) {
            Write-Host " - $warningText" -ForegroundColor Yellow
        }
    }

    Write-Host ''
    switch ($script:BiosAudit.Status) {
        'Ready' {
            Write-Host 'La auditoria no ha encontrado ajustes BIOS incompatibles entre los valores expuestos por HP.' -ForegroundColor Green
        }
        'Critical' {
            Write-Host 'Corrige los ajustes BIOS marcados como FALLO antes de considerar terminada la configuracion.' -ForegroundColor Red
        }
        'Review' {
            Write-Host 'Revisa manualmente en BIOS/UEFI las comprobaciones que no han sido concluyentes.' -ForegroundColor Yellow
        }
        'Unavailable' {
            Write-Host 'La BIOS no se ha podido auditar; comprueba manualmente Wake on LAN y Wake on USB/dock.' -ForegroundColor Yellow
        }
        'Skipped' {
            Write-Host 'La auditoria BIOS fue omitida. La configuracion de Windows no valida el firmware.' -ForegroundColor Yellow
        }
    }
    Write-Host 'Para la primera prueba, usa Suspension o Hibernacion y envia el paquete desde otro dispositivo.' -ForegroundColor Yellow
}
catch [System.OperationCanceledException] {
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    $script:ExitCode = 1
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    $script:ExitCode = 1
}
finally {
    if ($script:TranscriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
    }
}

if ($PSCommandPath) {
    exit $script:ExitCode
}

$global:LASTEXITCODE = $script:ExitCode
return
