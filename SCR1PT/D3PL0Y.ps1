#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    D3PL0Y v2.2.0

.DESCRIPTION
    Configura un equipo con Windows 11 de forma sencilla y fiable.

    D3PL0Y permite elegir entre tres perfiles:

    P0RT4L-SCR1PT:
    - Configuración general del equipo.
    - Instala Google Chrome, Google Drive y Tailscale.
    - Aplica los fondos específicos de P0RT4L-SCR1PT.

    STUD10-SCR1PT:
    - Configuración orientada a edición de imagen, vídeo y música.
    - Instala Google Chrome, Google Drive, Tailscale, Audacity y GIMP.
    - Aplica los fondos específicos de STUD10-SCR1PT.

    C0NTR0L-SCR1PT:
    - Configuración para un equipo de administración disponible 24/7.
    - Instala Chrome, Drive, Tailscale, PowerShell 7 y Visual Studio Code.
    - Prepara Tailscale desatendido, RDP con NLA limitado a Tailscale y WOL.
    - Genera un informe de salud semanal del equipo.

    Los tres perfiles:
    - Cambian el nombre del equipo para que coincida con el perfil.
    - Configuran las opciones de energía.
    - Desinstalan OneDrive y eliminan To Do, Xbox/Xbox Live y bloatware.
    - Reducen publicidad, sugerencias y telemetría.
    - Desactivan Widgets, Game DVR, búsquedas web y experiencias promocionales.
    - Aplican ajustes seguros de productividad y privacidad en Windows 11.
    - Usan una paleta verde en P0RT4L, morada en STUD10 y gris en C0NTR0L.
    - Descargan y aplican cursores, fondo de escritorio y pantalla de bloqueo.

.PARAMETER D3PL0YProfile
    Selecciona directamente P0RT4L-SCR1PT, STUD10-SCR1PT o
    C0NTR0L-SCR1PT.
    Si no se indica, D3PL0Y mostrará un menú interactivo.

.PARAMETER NoRestart
    Evita que el equipo se reinicie automáticamente al finalizar.
    Sin este parámetro, el equipo se reiniciará aunque alguna fase termine
    con errores.

.PARAMETER SkipDebloat
    Omite la desinstalación de OneDrive y de aplicaciones preinstaladas.

.PARAMETER RefreshAssets
    Fuerza la descarga de cursores aunque ya existan localmente.
    Los fondos se actualizan siempre para asegurar la versión del repositorio.

.EXAMPLE
    irm https://lavueltitaironica.com/install | iex

.EXAMPLE
    .\D3PL0Y.ps1 -D3PL0YProfile STUD10-SCR1PT

.EXAMPLE
    .\D3PL0Y.ps1 -D3PL0YProfile C0NTR0L-SCR1PT

.EXAMPLE
    .\D3PL0Y.ps1 -NoRestart
#>

[CmdletBinding()]
param(
    # No se usa ValidateSet aquí: Windows PowerShell 5.1 intenta validar el
    # valor nulo implícito al ejecutar el script mediante Invoke-Expression.
    # Select-D3PL0YProfile realiza la validación manual de forma compatible.
    [string]$D3PL0YProfile,

    [switch]$NoRestart,
    [switch]$SkipDebloat,
    [switch]$RefreshAssets
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

$ProjectName = 'D3PL0Y'
$Version = '2.2.0'

$RootFolder = 'C:\D3PL0Y'
$LogFolder = Join-Path $RootFolder 'Logs'
$ConfigFolder = Join-Path $RootFolder 'Configs'
$WallpaperFolder = Join-Path $RootFolder 'Wallpapers'
$CursorFolder = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'
$LockFolder = Join-Path $env:ProgramData 'D3PL0Y'

$RepositoryRaw = 'https://raw.githubusercontent.com/t3st-scr1pt/D3PL0Y/main'

$D3PL0YProfiles = [ordered]@{
    'P0RT4L-SCR1PT' = [pscustomobject]@{
        DisplayName = 'P0RT4L-SCR1PT'
        TargetComputerName = 'P0RT4L-SCR1PT'
        Description = 'D3PL0Y general para un equipo portátil de uso diario.'
        Apps = @(
            'Google.Chrome',
            'Google.GoogleDrive',
            'Tailscale.Tailscale'
        )
        AppNames = @(
            'Google Chrome',
            'Google Drive',
            'Tailscale'
        )
        Wallpaper = 'p0rt4l-scr1pt.png'
        Lockscreen = 'p0rt4l-scr1pt_lockscreen.png'
        ThemeName = 'verde P0RT4L'
        PrimaryColor = '#107C10'
        SecondaryColor = '#0E6D0E'
        SoftColor = '#81EF95'
        AccentColor = 0xFF107C10
        ColorizationColor = 0xC4107C10
        AccentColorMenu = 0xFF107C10
        StartColorMenu = 0xFF0E6D0E
        AccentPalette = [byte[]](
            0x95,0xEF,0x81,0x00,
            0x45,0xE5,0x32,0x00,
            0x19,0xA1,0x15,0x00,
            0x10,0x7C,0x10,0x00,
            0x0E,0x6D,0x0E,0x00,
            0x08,0x4B,0x08,0x00,
            0x03,0x2B,0x03,0x00,
            0x4C,0x4A,0x48,0x00
        )
        UiColor = 'Green'
        UiDarkColor = 'DarkGreen'
    }

    'STUD10-SCR1PT' = [pscustomobject]@{
        DisplayName = 'STUD10-SCR1PT'
        TargetComputerName = 'STUD10-SCR1PT'
        Description = 'D3PL0Y para edición de imagen, vídeo y música.'
        Apps = @(
            'Google.Chrome',
            'Google.GoogleDrive',
            'Tailscale.Tailscale',
            'Audacity.Audacity',
            'GIMP.GIMP.3'
        )
        AppNames = @(
            'Google Chrome',
            'Google Drive',
            'Tailscale',
            'Audacity',
            'GIMP'
        )
        Wallpaper = 'stud10-scr1pt.png'
        Lockscreen = 'stud10-scr1pt_lockscreen.png'
        ThemeName = 'LVI Music STUD10'
        PrimaryColor = '#602071'
        SecondaryColor = '#391344'
        SoftColor = '#D9C9DD'
        AccentColor = 0xFF712060
        ColorizationColor = 0xC4712060
        AccentColorMenu = 0xFF712060
        StartColorMenu = 0xFF712060
        AccentPalette = [byte[]](
            0xDD,0xC9,0xD9,0x00,
            0xBA,0x8F,0xB1,0x00,
            0x8E,0x50,0x82,0x00,
            0x71,0x20,0x60,0x00,
            0x5B,0x1A,0x4E,0x00,
            0x44,0x13,0x39,0x00,
            0x2C,0x0C,0x25,0x00,
            0x4C,0x4A,0x48,0x00
        )
        UiColor = 'DarkMagenta'
        UiDarkColor = 'DarkMagenta'
    }

    'C0NTR0L-SCR1PT' = [pscustomobject]@{
        DisplayName = 'C0NTR0L-SCR1PT'
        TargetComputerName = 'C0NTR0L-SCR1PT'
        Description = 'D3PL0Y para administración, supervisión y disponibilidad 24/7.'
        Apps = @(
            'Google.Chrome',
            'Google.GoogleDrive',
            'Tailscale.Tailscale',
            'Microsoft.PowerShell',
            'Microsoft.VisualStudioCode'
        )
        AppNames = @(
            'Google Chrome',
            'Google Drive',
            'Tailscale',
            'PowerShell 7',
            'Visual Studio Code'
        )
        Wallpaper = 'c0ntr0l-scr1pt.png'
        Lockscreen = 'c0ntr0l-scr1pt_lockscreen.png'
        ThemeName = 'gris plata C0NTR0L'
        PrimaryColor = '#8A929B'
        SecondaryColor = '#50575E'
        SoftColor = '#D7DCE2'
        AccentColor = 0xFF9B928A
        ColorizationColor = 0xC49B928A
        AccentColorMenu = 0xFF9B928A
        StartColorMenu = 0xFF5E5750
        AccentPalette = [byte[]](
            0xE2,0xDC,0xD7,0x00,
            0xD2,0xCB,0xC5,0x00,
            0xBF,0xB6,0xAE,0x00,
            0x9B,0x92,0x8A,0x00,
            0x80,0x77,0x6F,0x00,
            0x5E,0x57,0x50,0x00,
            0x3E,0x39,0x34,0x00,
            0x4C,0x4A,0x48,0x00
        )
        UiColor = 'Gray'
        UiDarkColor = 'DarkGray'
    }
}


$StatusFile = Join-Path $LogFolder 'estado.txt'
$SummaryFile = Join-Path $LogFolder 'Resumen.txt'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile = Join-Path $LogFolder ("install-{0}.log" -f $Timestamp)

$script:SuccessCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0
$script:FailedSteps = New-Object System.Collections.Generic.List[string]
$script:TranscriptStarted = $false
$script:ExplorerNeedsRestart = $false
$script:UiColor = 'Green'
$script:UiDarkColor = 'DarkGreen'

# =============================================================================
# FUNCIONES
# =============================================================================

function Write-D3PL0YLog
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $Color = switch ($Level)
    {
        'OK'    { $script:UiColor }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'Gray' }
    }

    $Line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    Write-Host $Line -ForegroundColor $Color
}

function Set-D3PL0YStatus
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status
    )

    Set-Content -LiteralPath $StatusFile -Value $Status -Encoding UTF8
}

function Invoke-D3PL0YStep
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor $script:UiDarkColor
    Write-Host $Name -ForegroundColor $script:UiColor
    Write-Host ('=' * 64) -ForegroundColor $script:UiDarkColor

    Set-D3PL0YStatus $Name

    try
    {
        & $Action
        $script:SuccessCount++
        Write-D3PL0YLog ('Completado: {0}' -f $Name) 'OK'
        return $true
    }
    catch
    {
        $script:ErrorCount++
        $Failure = '{0}: {1}' -f $Name, $_.Exception.Message
        $script:FailedSteps.Add($Failure)
        Write-D3PL0YLog ('Error en {0}' -f $Failure) 'ERROR'
        return $false
    }
}

function Write-D3PL0YWarning
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:WarningCount++
    Write-D3PL0YLog $Message 'WARN'
}

function Test-D3PL0YAdministrator
{
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Set-D3PL0YRegistryValueNative
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        $Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
        [string]$Type
    )

    $NativePath = if ($Path.StartsWith('HKCU:\'))
    {
        'HKCU\{0}' -f $Path.Substring(6)
    }
    elseif ($Path.StartsWith('HKLM:\'))
    {
        'HKLM\{0}' -f $Path.Substring(6)
    }
    else
    {
        throw "Ruta de Registro no compatible con reg.exe: $Path"
    }

    $NativeType = switch ($Type)
    {
        'String'       { 'REG_SZ' }
        'ExpandString' { 'REG_EXPAND_SZ' }
        'Binary'       { 'REG_BINARY' }
        'DWord'        { 'REG_DWORD' }
        'MultiString'  { 'REG_MULTI_SZ' }
        'QWord'        { 'REG_QWORD' }
    }

    $NativeData = switch ($Type)
    {
        'Binary'
        {
            ([byte[]]$Value | ForEach-Object {
                '{0:X2}' -f $_
            }) -join ''
        }
        'DWord'
        {
            $NumericValue = [Convert]::ToInt64($Value)

            if ($NumericValue -lt 0)
            {
                $NumericValue += 4294967296
            }

            '0x{0:X8}' -f $NumericValue
        }
        'QWord'
        {
            '0x{0:X16}' -f [Convert]::ToInt64($Value)
        }
        'MultiString'
        {
            ([string[]]$Value) -join '\0'
        }
        default
        {
            [string]$Value
        }
    }

    $Arguments = @(
        'ADD',
        $NativePath,
        '/v',
        $Name,
        '/t',
        $NativeType,
        '/d',
        $NativeData,
        '/f'
    )

    if ($Type -eq 'MultiString')
    {
        $Arguments += @('/s', '\0')
    }

    $NativeOutput = & reg.exe @Arguments 2>&1

    if ($LASTEXITCODE -ne 0)
    {
        throw (
            'reg.exe devolvió el código {0}: {1}' -f
            $LASTEXITCODE,
            (($NativeOutput | Out-String).Trim())
        )
    }
}

function Set-D3PL0YRegistryValue
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        $Value,

        [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
        [string]$Type = 'DWord'
    )

    if (-not (Test-Path -LiteralPath $Path))
    {
        try
        {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        catch
        {
            $ProviderError = $_.Exception.Message

            try
            {
                # reg.exe crea también la clave si todavía no existe.
                Set-D3PL0YRegistryValueNative `
                    -Path $Path `
                    -Name $Name `
                    -Value $Value `
                    -Type $Type

                $script:ExplorerNeedsRestart = $true
                return
            }
            catch
            {
                throw (
                    "No se pudo crear '{0}' ni escribir '{1}' como {2}. PowerShell: {3} Alternativa nativa: {4}" -f
                    $Path,
                    $Name,
                    $Type,
                    $ProviderError,
                    $_.Exception.Message
                )
            }
        }
    }

    $CurrentValue = $null
    $CurrentType = $null
    $PropertyExists = $false

    # Consultar una propiedad inexistente con Get-ItemPropertyValue y
    # ErrorAction Stop deja falsos errores en la transcripción. Esta consulta
    # permite distinguir creación y actualización sin ensuciar el registro.
    $CurrentProperties = Get-ItemProperty `
        -LiteralPath $Path `
        -Name $Name `
        -ErrorAction SilentlyContinue

    if ($null -ne $CurrentProperties)
    {
        $CurrentProperty = $CurrentProperties.PSObject.Properties[$Name]

        if ($null -ne $CurrentProperty)
        {
            $CurrentValue = $CurrentProperty.Value
            $PropertyExists = $true

            try
            {
                $RegistryKey = Get-Item `
                    -LiteralPath $Path `
                    -ErrorAction Stop

                $CurrentType = [string]$RegistryKey.GetValueKind($Name)
            }
            catch
            {
                $CurrentType = $null
            }
        }
    }

    $ValuesMatch = $false
    $TypesMatch = (
        $PropertyExists -and
        ($CurrentType -eq $Type)
    )

    if ($TypesMatch)
    {
        if (($CurrentValue -is [byte[]]) -and ($Value -is [byte[]]))
        {
            $CurrentBase64 = [Convert]::ToBase64String([byte[]]$CurrentValue)
            $ExpectedBase64 = [Convert]::ToBase64String([byte[]]$Value)
            $ValuesMatch = ($CurrentBase64 -eq $ExpectedBase64)
        }
        elseif (($CurrentValue -is [array]) -and ($Value -is [array]))
        {
            $ValuesMatch = (
                (($CurrentValue | ForEach-Object { [string]$_ }) -join "`0") -eq
                (($Value | ForEach-Object { [string]$_ }) -join "`0")
            )
        }
        else
        {
            $ValuesMatch = ([string]$CurrentValue -eq [string]$Value)
        }
    }

    if (-not $ValuesMatch)
    {
        try
        {
            # New-ItemProperty con -Force actualiza tanto el contenido como
            # el tipo. Set-ItemProperty conserva el tipo anterior y falla si
            # Windows o el fabricante dejaron el valor con un tipo anómalo.
            New-ItemProperty `
                -LiteralPath $Path `
                -Name $Name `
                -Value $Value `
                -PropertyType $Type `
                -Force `
                -ErrorAction Stop | Out-Null
        }
        catch
        {
            $ProviderError = $_.Exception.Message

            try
            {
                # Algunas claves de Windows 11 rechazan la operación del
                # proveedor de PowerShell aunque permitan la API nativa.
                Set-D3PL0YRegistryValueNative `
                    -Path $Path `
                    -Name $Name `
                    -Value $Value `
                    -Type $Type
            }
            catch
            {
                throw (
                    "No se pudo escribir '{0}' en '{1}' como {2}. PowerShell: {3} Alternativa nativa: {4}" -f
                    $Name,
                    $Path,
                    $Type,
                    $ProviderError,
                    $_.Exception.Message
                )
            }
        }

        $script:ExplorerNeedsRestart = $true
    }
}

function Set-D3PL0YOptionalRegistryValue
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        $Value,

        [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
        [string]$Type = 'DWord'
    )

    try
    {
        Set-D3PL0YRegistryValue `
            -Path $Path `
            -Name $Name `
            -Value $Value `
            -Type $Type
    }
    catch
    {
        Write-D3PL0YWarning (
            "Ajuste opcional omitido: '{0}' en '{1}'. {2}" -f
            $Name,
            $Path,
            $_.Exception.Message
        )
    }
}

function Invoke-D3PL0YDownload
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [int]$Retries = 3,

        [switch]$Force
    )

    if ((Test-Path -LiteralPath $Destination) -and (-not $Force))
    {
        $ExistingFile = Get-Item -LiteralPath $Destination -ErrorAction SilentlyContinue

        if (($null -ne $ExistingFile) -and ($ExistingFile.Length -gt 0))
        {
            Write-D3PL0YLog ('Ya existe: {0}' -f $Destination)
            return
        }
    }

    $ParentFolder = Split-Path -Parent $Destination

    if (-not (Test-Path -LiteralPath $ParentFolder))
    {
        New-Item -ItemType Directory -Path $ParentFolder -Force | Out-Null
    }

    $TemporaryFile = '{0}.download' -f $Destination
    Remove-Item -LiteralPath $TemporaryFile -Force -ErrorAction SilentlyContinue

    for ($Attempt = 1; $Attempt -le $Retries; $Attempt++)
    {
        try
        {
            Invoke-WebRequest `
                -Uri $Uri `
                -OutFile $TemporaryFile `
                -UseBasicParsing `
                -TimeoutSec 90

            $DownloadedFile = Get-Item -LiteralPath $TemporaryFile -ErrorAction Stop

            if ($DownloadedFile.Length -le 0)
            {
                throw 'El archivo descargado está vacío.'
            }

            Move-Item `
                -LiteralPath $TemporaryFile `
                -Destination $Destination `
                -Force

            Write-D3PL0YLog ('Descargado: {0}' -f $Destination) 'OK'
            return
        }
        catch
        {
            Remove-Item -LiteralPath $TemporaryFile -Force -ErrorAction SilentlyContinue

            if ($Attempt -ge $Retries)
            {
                throw
            }

            Write-D3PL0YWarning (
                'Descarga fallida. Reintento {0} de {1}: {2}' -f
                $Attempt,
                $Retries,
                $Uri
            )

            Start-Sleep -Seconds (3 * $Attempt)
        }
    }
}

function Assert-D3PL0YPngFile
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf))
    {
        throw ('No existe la imagen descargada: {0}' -f $Path)
    }

    $ExpectedSignature = [byte[]](
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    )

    $Stream = [System.IO.File]::OpenRead($Path)

    try
    {
        if ($Stream.Length -lt $ExpectedSignature.Length)
        {
            throw ('La imagen PNG está vacía o incompleta: {0}' -f $Path)
        }

        foreach ($ExpectedByte in $ExpectedSignature)
        {
            if ($Stream.ReadByte() -ne $ExpectedByte)
            {
                throw ('El archivo descargado no es un PNG válido: {0}' -f $Path)
            }
        }
    }
    finally
    {
        $Stream.Dispose()
    }
}

function Set-D3PL0YCurrentUserLockScreen
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Add-Type -AssemblyName System.Runtime.WindowsRuntime

    $StorageFileType = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]

    $AsyncOperationMethod = @(
        [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            ($_.Name -eq 'AsTask') -and
            ($_.GetParameters().Count -eq 1) -and
            ($_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1')
        }
    )[0]

    $AsyncActionMethod = @(
        [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            ($_.Name -eq 'AsTask') -and
            ($_.GetParameters().Count -eq 1) -and
            ($_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction')
        }
    )[0]

    if (($null -eq $AsyncOperationMethod) -or ($null -eq $AsyncActionMethod))
    {
        throw 'No se encontraron los adaptadores asíncronos de Windows Runtime.'
    }

    $GetFileOperation = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]::GetFileFromPathAsync($Path)
    $GetFileTaskMethod = $AsyncOperationMethod.MakeGenericMethod($StorageFileType)
    $GetFileTask = $GetFileTaskMethod.Invoke($null, @($GetFileOperation))
    $GetFileTask.Wait()
    $StorageFile = $GetFileTask.Result

    $SetImageAction = [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime]::SetImageFileAsync($StorageFile)
    $SetImageTask = $AsyncActionMethod.Invoke($null, @($SetImageAction))
    $SetImageTask.Wait()
}

function Test-D3PL0YWingetPackage
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    $Output = & winget.exe list `
        --id $Id `
        --exact `
        --accept-source-agreements 2>$null | Out-String

    return (
        ($LASTEXITCODE -eq 0) -and
        ($Output -match [regex]::Escape($Id))
    )
}

function Install-D3PL0YWingetPackage
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    if (Test-D3PL0YWingetPackage -Id $Id)
    {
        Write-D3PL0YLog ('Ya está instalado: {0}' -f $Id) 'OK'
        return
    }

    Write-D3PL0YLog ('Instalando: {0}' -f $Id)

    & winget.exe install `
        --id $Id `
        --exact `
        --silent `
        --disable-interactivity `
        --accept-package-agreements `
        --accept-source-agreements

    $InstallExitCode = $LASTEXITCODE

    if (
        ($InstallExitCode -ne 0) -and
        (-not (Test-D3PL0YWingetPackage -Id $Id))
    )
    {
        throw (
            'WinGet no pudo instalar {0}. Código de salida: {1}' -f
            $Id,
            $InstallExitCode
        )
    }

    Write-D3PL0YLog ('Instalado: {0}' -f $Id) 'OK'
}

function Remove-D3PL0YAppxPackage
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $FoundPackage = $false

    # Se elimina primero el aprovisionamiento para impedir que Windows vuelva
    # a instalar la aplicación al crear usuarios nuevos.
    $ProvisionedMatches = @(
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $Name }
    )

    foreach ($Package in $ProvisionedMatches)
    {
        $FoundPackage = $true

        try
        {
            Remove-AppxProvisionedPackage `
                -Online `
                -PackageName $Package.PackageName `
                -ErrorAction Stop | Out-Null

            Write-D3PL0YLog ('Desaprovisionado: {0}' -f $Name) 'OK'
        }
        catch
        {
            $StillProvisioned = @(
                Get-AppxProvisionedPackage `
                    -Online `
                    -ErrorAction SilentlyContinue |
                Where-Object { $_.PackageName -eq $Package.PackageName }
            )

            if ($StillProvisioned.Count -eq 0)
            {
                Write-D3PL0YLog ('Ya no estaba aprovisionado: {0}' -f $Name) 'OK'
            }
            else
            {
                Write-D3PL0YWarning (
                    'No se pudo desaprovisionar {0}. {1}' -f
                    $Name,
                    $_.Exception.Message
                )
            }
        }
    }

    # Después se elimina de todos los perfiles existentes.
    $InstalledMatches = @(
        Get-AppxPackage `
            -AllUsers `
            -Name $Name `
            -ErrorAction SilentlyContinue
    )

    foreach ($Package in $InstalledMatches)
    {
        $FoundPackage = $true

        try
        {
            Remove-AppxPackage `
                -Package $Package.PackageFullName `
                -AllUsers `
                -ErrorAction Stop

            Write-D3PL0YLog ('Eliminado: {0}' -f $Name) 'OK'
        }
        catch
        {
            $StillInstalled = @(
                Get-AppxPackage `
                    -AllUsers `
                    -Name $Name `
                    -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.PackageFullName -eq $Package.PackageFullName
                }
            )

            if ($StillInstalled.Count -eq 0)
            {
                Write-D3PL0YLog ('Ya no estaba instalado: {0}' -f $Name) 'OK'
            }
            else
            {
                Write-D3PL0YWarning (
                    'No se pudo eliminar {0}. {1}' -f
                    $Name,
                    $_.Exception.Message
                )
            }
        }
    }

    $RemainingInstalled = @(
        Get-AppxPackage `
            -AllUsers `
            -Name $Name `
            -ErrorAction SilentlyContinue
    )

    $RemainingProvisioned = @(
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $Name }
    )

    if (
        ($RemainingInstalled.Count -eq 0) -and
        ($RemainingProvisioned.Count -eq 0)
    )
    {
        if (-not $FoundPackage)
        {
            Write-D3PL0YLog ('No estaba instalado: {0}' -f $Name)
        }
    }
    else
    {
        Write-D3PL0YWarning (
            'Persisten restos de {0}: instalados={1}, aprovisionados={2}' -f
            $Name,
            $RemainingInstalled.Count,
            $RemainingProvisioned.Count
        )
    }
}

function Uninstall-D3PL0YOneDrive
{
    Get-Process -Name OneDrive -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    $OneDriveSetupSucceeded = $false

    $OneDriveSetup = @(
        (Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'),
        (Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\Update\OneDriveSetup.exe')
    ) |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if ($null -ne $OneDriveSetup)
    {
        Write-D3PL0YLog 'Desinstalando Microsoft OneDrive.'

        try
        {
            $UninstallProcess = Start-Process `
                -FilePath $OneDriveSetup `
                -ArgumentList @('/uninstall', '/allusers') `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            if ($UninstallProcess.ExitCode -ne 0)
            {
                Write-D3PL0YWarning (
                    'OneDriveSetup devolvió el código {0}.' -f
                    $UninstallProcess.ExitCode
                )
            }
            else
            {
                $OneDriveSetupSucceeded = $true
                Write-D3PL0YLog 'OneDriveSetup completó la desinstalación.' 'OK'
            }
        }
        catch
        {
            Write-D3PL0YWarning (
                'No se pudo ejecutar OneDriveSetup. {0}' -f
                $_.Exception.Message
            )
        }

        Start-Sleep -Seconds 3
    }
    else
    {
        Write-D3PL0YLog 'No se encontró OneDriveSetup.exe.'
    }

    # WinGet queda como método alternativo. No se ejecuta después de un
    # OneDriveSetup correcto porque la entrada de aplicaciones puede tardar en
    # actualizarse y producir un aviso falso aunque OneDrive ya no esté.
    if (
        (-not $OneDriveSetupSucceeded) -and
        (Test-D3PL0YWingetPackage -Id 'Microsoft.OneDrive')
    )
    {
        & winget.exe uninstall `
            --id Microsoft.OneDrive `
            --exact `
            --silent `
            --disable-interactivity `
            --accept-source-agreements

        if (
            ($LASTEXITCODE -ne 0) -and
            (Test-D3PL0YWingetPackage -Id 'Microsoft.OneDrive')
        )
        {
            Write-D3PL0YWarning (
                'WinGet no pudo completar la desinstalación de OneDrive.'
            )
        }
    }

    Remove-ItemProperty `
        -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
        -Name 'OneDrive' `
        -Force `
        -ErrorAction SilentlyContinue

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' `
        -Name 'DisableFileSyncNGSC' `
        -Value 1 `
        -Type DWord

    foreach ($NamespacePath in @(
        'HKLM:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}',
        'HKLM:\SOFTWARE\Classes\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'
    ))
    {
        Set-D3PL0YRegistryValue `
            -Path $NamespacePath `
            -Name 'System.IsPinnedToNameSpaceTree' `
            -Value 0 `
            -Type DWord
    }

    Write-D3PL0YLog (
        'OneDrive deshabilitado. No se ha borrado ninguna carpeta de datos del usuario.'
    ) 'OK'
}

function Set-D3PL0YComputerName
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    if ($TargetName.Length -gt 15)
    {
        throw "El nombre de equipo supera el límite de 15 caracteres: $TargetName"
    }

    $CurrentName = [Environment]::MachineName
    $PendingName = $null

    try
    {
        $PendingName = Get-ItemPropertyValue `
            -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' `
            -Name 'ComputerName' `
            -ErrorAction Stop
    }
    catch
    {
        $PendingName = $CurrentName
    }

    if ($PendingName -ieq $TargetName)
    {
        if ($CurrentName -ieq $TargetName)
        {
            Write-D3PL0YLog ('El equipo ya se llama {0}.' -f $TargetName) 'OK'
        }
        else
        {
            Write-D3PL0YLog (
                'El cambio de nombre a {0} ya está pendiente de reinicio.' -f
                $TargetName
            ) 'OK'
        }

        return
    }

    Rename-Computer -NewName $TargetName -Force -ErrorAction Stop
    Write-D3PL0YLog (
        'Nombre de equipo preparado: {0} -> {1}. Se aplicará al reiniciar.' -f
        $CurrentName,
        $TargetName
    ) 'OK'
}

function Get-D3PL0YTailscaleCli
{
    $Command = Get-Command tailscale.exe -ErrorAction SilentlyContinue

    if ($null -ne $Command)
    {
        return $Command.Source
    }

    foreach ($Candidate in @(
        (Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Tailscale\tailscale.exe')
    ))
    {
        if (
            (-not [string]::IsNullOrWhiteSpace($Candidate)) -and
            (Test-Path -LiteralPath $Candidate -PathType Leaf)
        )
        {
            return $Candidate
        }
    }

    return $null
}

function Enable-D3PL0YTailscaleUnattended
{
    $TailscaleCli = Get-D3PL0YTailscaleCli

    if ([string]::IsNullOrWhiteSpace($TailscaleCli))
    {
        throw 'No se encontró tailscale.exe después de instalar Tailscale.'
    }

    $HelperPath = Join-Path $ConfigFolder 'Enable-TailscaleUnattended.ps1'
    $TaskName = 'D3PL0Y-TailscaleUnattended'
    $HelperContent = @'
$ErrorActionPreference = 'SilentlyContinue'

$Candidates = @(
    (Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Tailscale\tailscale.exe')
)

$TailscaleCli = $Candidates |
    Where-Object {
        (-not [string]::IsNullOrWhiteSpace($_)) -and
        (Test-Path -LiteralPath $_ -PathType Leaf)
    } |
    Select-Object -First 1

if ($null -eq $TailscaleCli)
{
    exit 1
}

for ($Attempt = 1; $Attempt -le 60; $Attempt++)
{
    $StatusText = & $TailscaleCli status --json 2>$null | Out-String

    try
    {
        $Status = $StatusText | ConvertFrom-Json
    }
    catch
    {
        $Status = $null
    }

    if (($null -ne $Status) -and ($Status.BackendState -eq 'Running'))
    {
        & $TailscaleCli up --unattended=true --timeout=20s 2>$null | Out-Null

        if ($LASTEXITCODE -eq 0)
        {
            Disable-ScheduledTask `
                -TaskName 'D3PL0Y-TailscaleUnattended' `
                -ErrorAction SilentlyContinue | Out-Null

            exit 0
        }
    }

    Start-Sleep -Seconds 30
}

exit 3
'@

    Set-Content `
        -LiteralPath $HelperPath `
        -Value $HelperContent `
        -Encoding UTF8

    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $PowerShellExe = Join-Path `
        $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'
    $TaskAction = New-ScheduledTaskAction `
        -Execute $PowerShellExe `
        -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $HelperPath)
    $TaskTrigger = New-ScheduledTaskTrigger `
        -AtLogOn `
        -User $CurrentUser
    $TaskPrincipal = New-ScheduledTaskPrincipal `
        -UserId $CurrentUser `
        -LogonType Interactive `
        -RunLevel Highest
    $TaskSettings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 35)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $TaskAction `
        -Trigger $TaskTrigger `
        -Principal $TaskPrincipal `
        -Settings $TaskSettings `
        -Description 'Activa el modo desatendido de Tailscale después de que el usuario inicie sesión en su tailnet.' `
        -Force | Out-Null

    $StatusText = & $TailscaleCli status --json 2>$null | Out-String
    $BackendState = $null

    try
    {
        $BackendState = ($StatusText | ConvertFrom-Json).BackendState
    }
    catch
    {
        $BackendState = $null
    }

    if ($BackendState -eq 'Running')
    {
        & $TailscaleCli up --unattended=true --timeout=20s | Out-Null

        if ($LASTEXITCODE -eq 0)
        {
            Disable-ScheduledTask `
                -TaskName $TaskName `
                -ErrorAction SilentlyContinue | Out-Null

            Write-D3PL0YLog 'Tailscale configurado en modo desatendido.' 'OK'
            return
        }

        Write-D3PL0YWarning (
            'Tailscale está conectado, pero no aceptó todavía el modo desatendido. ' +
            'La tarea de inicio de sesión volverá a intentarlo.'
        )
        return
    }

    Write-D3PL0YWarning (
        'Tailscale aún requiere iniciar sesión. Tras hacerlo, la tarea ' +
        'D3PL0Y-TailscaleUnattended activará automáticamente el modo desatendido.'
    )
}

function Enable-D3PL0YRemoteDesktop
{
    $OperatingSystem = Get-CimInstance Win32_OperatingSystem
    $EditionId = Get-ItemPropertyValue `
        -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' `
        -Name 'EditionID' `
        -ErrorAction SilentlyContinue

    if (
        ($OperatingSystem.ProductType -eq 1) -and
        ($EditionId -notmatch 'Professional|Enterprise|Education|IoTEnterprise')
    )
    {
        Write-D3PL0YWarning (
            'Esta edición de Windows no admite conexiones RDP entrantes. ' +
            'La configuración de Escritorio remoto se ha omitido.'
        )
        return
    }

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' `
        -Name 'fDenyTSConnections' `
        -Value 0 `
        -Type DWord

    $RdpTcp =
        'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'

    Set-D3PL0YRegistryValue `
        -Path $RdpTcp `
        -Name 'UserAuthentication' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $RdpTcp `
        -Name 'SecurityLayer' `
        -Value 2 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $RdpTcp `
        -Name 'MinEncryptionLevel' `
        -Value 3 `
        -Type DWord

    if (-not (Get-Command New-NetFirewallRule -ErrorAction SilentlyContinue))
    {
        throw 'No están disponibles los cmdlets de Firewall de Windows.'
    }

    # Desactiva las reglas integradas, que permiten acceso desde toda la LAN.
    # D3PL0Y crea reglas propias limitadas al rango IPv4 de Tailscale.
    Get-NetFirewallRule `
        -Name 'RemoteDesktop-*' `
        -ErrorAction SilentlyContinue |
        Disable-NetFirewallRule -ErrorAction SilentlyContinue

    foreach ($Protocol in @('TCP', 'UDP'))
    {
        $RuleName = 'D3PL0Y-C0NTR0L-RDP-{0}' -f $Protocol
        $ExistingRule = Get-NetFirewallRule `
            -Name $RuleName `
            -ErrorAction SilentlyContinue

        if ($null -eq $ExistingRule)
        {
            New-NetFirewallRule `
                -Name $RuleName `
                -DisplayName ('D3PL0Y - RDP por Tailscale ({0})' -f $Protocol) `
                -Description 'Permite RDP únicamente desde direcciones IPv4 de Tailscale.' `
                -Direction Inbound `
                -Action Allow `
                -Enabled True `
                -Profile Any `
                -Protocol $Protocol `
                -LocalPort 3389 `
                -RemoteAddress '100.64.0.0/10' | Out-Null
        }
        else
        {
            $ExistingRule |
                Set-NetFirewallRule `
                    -Enabled True `
                    -Direction Inbound `
                    -Action Allow `
                    -Profile Any | Out-Null

            $ExistingRule |
                Get-NetFirewallAddressFilter |
                Set-NetFirewallAddressFilter `
                    -RemoteAddress '100.64.0.0/10' | Out-Null
        }
    }

    Write-D3PL0YLog (
        'RDP habilitado con NLA; el Firewall solo admite origen Tailscale (100.64.0.0/10).'
    ) 'OK'
}

function Set-D3PL0YSecurityBaseline
{
    Set-NetFirewallProfile `
        -Profile Domain,Private,Public `
        -Enabled True `
        -ErrorAction Stop

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' `
        -Name 'EnableSmartScreen' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' `
        -Name 'ShellSmartScreenLevel' `
        -Value 'Warn' `
        -Type String

    $UacPolicy =
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

    Set-D3PL0YRegistryValue `
        -Path $UacPolicy `
        -Name 'EnableLUA' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $UacPolicy `
        -Name 'ConsentPromptBehaviorAdmin' `
        -Value 5 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $UacPolicy `
        -Name 'PromptOnSecureDesktop' `
        -Value 1 `
        -Type DWord

    try
    {
        if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue)
        {
            Set-MpPreference `
                -DisableRealtimeMonitoring $false `
                -ErrorAction Stop
        }
    }
    catch
    {
        Write-D3PL0YWarning (
            'Defender no permitió reafirmar la protección en tiempo real: {0}' -f
            $_.Exception.Message
        )
    }

    try
    {
        $WindowsUpdateService = Get-Service `
            -Name wuauserv `
            -ErrorAction Stop

        if ($WindowsUpdateService.StartType -eq 'Disabled')
        {
            Set-Service `
                -Name wuauserv `
                -StartupType Manual `
                -ErrorAction Stop
        }
    }
    catch
    {
        Write-D3PL0YWarning (
            'No se pudo comprobar o reactivar Windows Update: {0}' -f
            $_.Exception.Message
        )
    }

    try
    {
        $Smb1 = Get-WindowsOptionalFeature `
            -Online `
            -FeatureName SMB1Protocol `
            -ErrorAction Stop

        if ($Smb1.State -eq 'Enabled')
        {
            Disable-WindowsOptionalFeature `
                -Online `
                -FeatureName SMB1Protocol `
                -NoRestart `
                -ErrorAction Stop | Out-Null
        }
    }
    catch
    {
        Write-D3PL0YWarning (
            'No se pudo verificar o desactivar SMB1: {0}' -f
            $_.Exception.Message
        )
    }

    # No se deshabilita el cliente SMB2/3. Se bloquea únicamente la entrada
    # para que C0NTR0L no publique carpetas hasta que se configure expresamente.
    Get-NetFirewallRule `
        -Name 'FPS-SMB-In-*' `
        -ErrorAction SilentlyContinue |
        Disable-NetFirewallRule -ErrorAction SilentlyContinue

    Write-D3PL0YLog (
        'Defender, Firewall, SmartScreen, UAC y Windows Update se mantienen activos; SMB entrante queda cerrado.'
    ) 'OK'
}

function Install-D3PL0YHealthMonitoring
{
    $HealthFolder = Join-Path $LogFolder 'Health'
    $HealthScriptPath = Join-Path $ConfigFolder 'C0NTR0L-HealthReport.ps1'
    New-Item -ItemType Directory -Path $HealthFolder -Force | Out-Null

    $HealthScript = @'
$ErrorActionPreference = 'Continue'
$HealthFolder = 'C:\D3PL0Y\Logs\Health'
New-Item -ItemType Directory -Path $HealthFolder -Force | Out-Null
$ReportPath = Join-Path $HealthFolder ('Health-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$Lines = New-Object System.Collections.Generic.List[string]

function Add-HealthLine
{
    param([object]$Value = '')
    $script:Lines.Add([string]$Value)
}

Add-HealthLine '================================='
Add-HealthLine 'C0NTR0L-SCR1PT - INFORME DE SALUD'
Add-HealthLine '================================='
Add-HealthLine ('Fecha: {0}' -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'))
Add-HealthLine ('Equipo: {0}' -f $env:COMPUTERNAME)

try
{
    $Os = Get-CimInstance Win32_OperatingSystem
    $Uptime = (Get-Date) - $Os.LastBootUpTime
    Add-HealthLine ('Windows: {0} (build {1})' -f $Os.Caption, $Os.BuildNumber)
    Add-HealthLine ('Tiempo encendido: {0} días, {1} horas, {2} minutos' -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes)
}
catch
{
    Add-HealthLine ('Windows/uptime: ERROR - {0}' -f $_.Exception.Message)
}

Add-HealthLine ''
Add-HealthLine '[ESPACIO EN DISCOS]'
try
{
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
        Sort-Object DeviceID |
        ForEach-Object {
            $FreeGb = [math]::Round($_.FreeSpace / 1GB, 2)
            $SizeGb = [math]::Round($_.Size / 1GB, 2)
            $FreePercent = if ($_.Size -gt 0)
            {
                [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
            }
            else
            {
                0
            }

            Add-HealthLine ('{0} Libre {1} GB de {2} GB ({3}%)' -f $_.DeviceID, $FreeGb, $SizeGb, $FreePercent)
        }
}
catch
{
    Add-HealthLine ('ERROR - {0}' -f $_.Exception.Message)
}

Add-HealthLine ''
Add-HealthLine '[SALUD DE DISCOS FÍSICOS]'
try
{
    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue)
    {
        Get-PhysicalDisk |
            Sort-Object FriendlyName |
            ForEach-Object {
                Add-HealthLine ('{0}: Health={1}; Operational={2}; Size={3} GB' -f $_.FriendlyName, $_.HealthStatus, ($_.OperationalStatus -join ','), [math]::Round($_.Size / 1GB, 2))
            }
    }
    else
    {
        Get-CimInstance Win32_DiskDrive |
            ForEach-Object {
                Add-HealthLine ('{0}: Status={1}; Size={2} GB' -f $_.Model, $_.Status, [math]::Round($_.Size / 1GB, 2))
            }
    }
}
catch
{
    Add-HealthLine ('ERROR - {0}' -f $_.Exception.Message)
}

Add-HealthLine ''
Add-HealthLine '[MICROSOFT DEFENDER]'
try
{
    $Defender = Get-MpComputerStatus
    Add-HealthLine ('Antivirus activo: {0}' -f $Defender.AntivirusEnabled)
    Add-HealthLine ('Protección en tiempo real: {0}' -f $Defender.RealTimeProtectionEnabled)
    Add-HealthLine ('Firma actualizada: {0}' -f $Defender.AntivirusSignatureLastUpdated)
    Add-HealthLine ('Antispyware activo: {0}' -f $Defender.AntispywareEnabled)
}
catch
{
    Add-HealthLine ('ERROR - {0}' -f $_.Exception.Message)
}

Add-HealthLine ''
Add-HealthLine '[WINDOWS UPDATE]'
try
{
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $UpdateResult = $UpdateSearcher.Search('IsInstalled=0 and IsHidden=0')
    Add-HealthLine ('Actualizaciones pendientes: {0}' -f $UpdateResult.Updates.Count)
}
catch
{
    Add-HealthLine ('ERROR - {0}' -f $_.Exception.Message)
}

Add-HealthLine ''
Add-HealthLine '[CONECTIVIDAD]'
try
{
    $HttpsOk = Test-NetConnection `
        -ComputerName 'login.tailscale.com' `
        -Port 443 `
        -InformationLevel Quiet `
        -WarningAction SilentlyContinue
    Add-HealthLine ('Salida HTTPS: {0}' -f $HttpsOk)
}
catch
{
    Add-HealthLine ('Salida HTTPS: ERROR - {0}' -f $_.Exception.Message)
}

try
{
    $TailscaleService = Get-Service -Name Tailscale -ErrorAction Stop
    Add-HealthLine ('Servicio Tailscale: {0}' -f $TailscaleService.Status)

    $TailscaleCli = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'

    if (Test-Path -LiteralPath $TailscaleCli -PathType Leaf)
    {
        $StatusText = & $TailscaleCli status --json 2>$null | Out-String
        $Status = $StatusText | ConvertFrom-Json
        Add-HealthLine ('Estado Tailscale: {0}' -f $Status.BackendState)
        Add-HealthLine ('IP Tailscale: {0}' -f ($Status.TailscaleIPs -join ', '))
    }
}
catch
{
    Add-HealthLine ('Tailscale: ERROR - {0}' -f $_.Exception.Message)
}

$Lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Get-ChildItem -LiteralPath $HealthFolder -Filter 'Health-*.txt' -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 26 |
    Remove-Item -Force -ErrorAction SilentlyContinue
'@

    Set-Content `
        -LiteralPath $HealthScriptPath `
        -Value $HealthScript `
        -Encoding UTF8

    $PowerShellExe = Join-Path `
        $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'
    $TaskAction = New-ScheduledTaskAction `
        -Execute $PowerShellExe `
        -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $HealthScriptPath)
    $TaskTrigger = New-ScheduledTaskTrigger `
        -Weekly `
        -DaysOfWeek Sunday `
        -At ([datetime]::Today.AddHours(3))
    $TaskPrincipal = New-ScheduledTaskPrincipal `
        -UserId 'SYSTEM' `
        -LogonType ServiceAccount `
        -RunLevel Highest
    $TaskSettings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 20)

    Register-ScheduledTask `
        -TaskName 'D3PL0Y-C0NTR0L-Health' `
        -Action $TaskAction `
        -Trigger $TaskTrigger `
        -Principal $TaskPrincipal `
        -Settings $TaskSettings `
        -Description 'Informe semanal de salud de C0NTR0L-SCR1PT.' `
        -Force | Out-Null

    Write-D3PL0YLog (
        'Informe semanal registrado: domingos a las 03:00 en C:\D3PL0Y\Logs\Health.'
    ) 'OK'
}

function Select-D3PL0YProfile
{
    param(
        [string]$RequestedProfile
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedProfile))
    {
        $NormalizedProfile = $RequestedProfile.Trim().ToUpperInvariant()

        if ($D3PL0YProfiles.Keys -contains $NormalizedProfile)
        {
            return $NormalizedProfile
        }

        throw (
            'Perfil D3PL0Y no válido: {0}. Opciones válidas: {1}' -f
            $RequestedProfile,
            ($D3PL0YProfiles.Keys -join ', ')
        )
    }

    while ($true)
    {
        Write-Host ''
        Write-Host '╔════════════════════════════════════════════════════╗' -ForegroundColor DarkGreen
        Write-Host '║              SELECCIONA EL D3PL0Y                  ║' -ForegroundColor Green
        Write-Host '╠════════════════════════════════════════════════════╣' -ForegroundColor DarkGreen
        Write-Host '║ [1] P0RT4L-SCR1PT                                  ║' -ForegroundColor Green
        Write-Host '║     Equipo general: Chrome, Drive y Tailscale      ║' -ForegroundColor Gray
        Write-Host '║                                                    ║' -ForegroundColor DarkGreen
        Write-Host '║ [2] STUD10-SCR1PT                                  ║' -ForegroundColor Magenta
        Write-Host '║     Edición: añade Audacity y GIMP                 ║' -ForegroundColor Gray
        Write-Host '║                                                    ║' -ForegroundColor DarkGreen
        Write-Host '║ [3] C0NTR0L-SCR1PT                                 ║' -ForegroundColor Gray
        Write-Host '║     Administración y disponibilidad 24/7           ║' -ForegroundColor Gray
        Write-Host '║                                                    ║' -ForegroundColor DarkGreen
        Write-Host '║ [0] Cancelar                                       ║' -ForegroundColor Yellow
        Write-Host '╚════════════════════════════════════════════════════╝' -ForegroundColor DarkGreen

        $Choice = Read-Host 'Selecciona una opción'
        $NormalizedChoice = $Choice.Trim().ToUpperInvariant()

        if ($NormalizedChoice -in @('1', 'P0RT4L', 'P0RT4L-SCR1PT'))
        {
            return 'P0RT4L-SCR1PT'
        }

        if ($NormalizedChoice -in @('2', 'STUD10', 'STUD10-SCR1PT'))
        {
            return 'STUD10-SCR1PT'
        }

        if ($NormalizedChoice -in @('3', 'C0NTR0L', 'C0NTR0L-SCR1PT'))
        {
            return 'C0NTR0L-SCR1PT'
        }

        if ($NormalizedChoice -in @('0', 'Q', 'S', 'SALIR', 'CANCELAR'))
        {
            return $null
        }

        Write-Host ''
        Write-Host 'Selección no válida. Usa 1, 2, 3 o 0.' -ForegroundColor Red
    }
}

function Restart-D3PL0YExplorer
{
    Write-D3PL0YLog 'Actualizando la configuración visual de Windows.'

    & rundll32.exe 'user32.dll,UpdatePerUserSystemParameters'
    Start-Sleep -Seconds 2

    Stop-Process `
        -Name explorer `
        -Force `
        -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2
    Start-Process explorer.exe
}

# =============================================================================
# PREPARACIÓN
# =============================================================================

foreach ($Folder in @(
    $RootFolder,
    $LogFolder,
    $ConfigFolder,
    $WallpaperFolder,
    $CursorFolder,
    $LockFolder
))
{
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
}

try
{
    Start-Transcript -Path $LogFile -Append | Out-Null
    $script:TranscriptStarted = $true
}
catch
{
    Write-Host 'No se pudo iniciar la transcripción completa.' -ForegroundColor Yellow
}

$Banner = @"

██████╗ ██████╗ ██████╗ ██╗      ██████╗ ██╗   ██╗
██╔══██╗╚════██╗██╔══██╗██║     ██╔═████╗╚██╗ ██╔╝
██║  ██║ █████╔╝██████╔╝██║     ██║██╔██║ ╚████╔╝
██║  ██║ ╚═══██╗██╔═══╝ ██║     ████╔╝██║  ╚██╔╝
██████╔╝██████╔╝██║     ███████╗╚██████╔╝   ██║
╚═════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝    ╚═╝

╔════════════════════════════════════════════════════╗
║                    D3PL0Y                          ║
║                                                    ║
║   Instalación automática de aplicaciones           ║
║   Configuración personalizada de Windows 11         ║
╚════════════════════════════════════════════════════╝

"@

Write-Host $Banner -ForegroundColor Green

$SelectedD3PL0Y = Select-D3PL0YProfile -RequestedProfile $D3PL0YProfile

if ([string]::IsNullOrWhiteSpace($SelectedD3PL0Y))
{
    Set-D3PL0YStatus 'CANCELADO'
    Write-D3PL0YLog 'D3PL0Y cancelado por el usuario.'

    if ($script:TranscriptStarted)
    {
        try
        {
            Stop-Transcript | Out-Null
            $script:TranscriptStarted = $false
        }
        catch
        {
        }
    }

    return
}

$SelectedConfig = $D3PL0YProfiles[$SelectedD3PL0Y]
$script:UiColor = $SelectedConfig.UiColor
$script:UiDarkColor = $SelectedConfig.UiDarkColor
$InstalledAppSummary = $SelectedConfig.AppNames -join ', '
$DebloatSummary = if ($SkipDebloat)
{
    'Omitido mediante -SkipDebloat'
}
else
{
    'OneDrive y aplicaciones innecesarias eliminadas'
}
$PowerSummary = if ($SelectedD3PL0Y -eq 'C0NTR0L-SCR1PT')
{
    '24/7 con corriente; pantalla a 10 minutos; tapa sin acción; batería sin modificar'
}
else
{
    'Sin suspensión con corriente; pantalla a 20 minutos; batería 30/10 minutos'
}
$ControlSummary = if ($SelectedD3PL0Y -eq 'C0NTR0L-SCR1PT')
{
    'Tailscale desatendido, RDP+NLA limitado a Tailscale, seguridad reforzada e informe semanal'
}
else
{
    'No corresponde a este perfil'
}

Set-D3PL0YStatus ('INICIANDO {0}' -f $SelectedD3PL0Y)
Write-D3PL0YLog ('Perfil seleccionado: {0}' -f $SelectedD3PL0Y) 'OK'
Write-D3PL0YLog $SelectedConfig.Description

$Date = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
$Computer = $env:COMPUTERNAME
$User = $env:USERNAME

Write-Host '┌────────────────────────────────────────────────────┐' -ForegroundColor DarkGreen
Write-Host '│                  D3PL0Y STATUS                     │' -ForegroundColor DarkGreen
Write-Host '├────────────────────────────────────────────────────┤' -ForegroundColor DarkGreen
Write-Host ('│ HOSTNAME : {0,-38}│' -f $Computer) -ForegroundColor Green
Write-Host ('│ USER     : {0,-38}│' -f $User) -ForegroundColor Green
Write-Host ('│ DATE     : {0,-38}│' -f $Date) -ForegroundColor Green
Write-Host ('│ VERSION  : {0,-38}│' -f ('v{0}' -f $Version)) -ForegroundColor Green
Write-Host ('│ PROFILE  : {0,-38}│' -f $SelectedD3PL0Y) -ForegroundColor Magenta
Write-Host ('│ STATUS   : {0,-38}│' -f 'INITIALIZING') -ForegroundColor Yellow
Write-Host '└────────────────────────────────────────────────────┘' -ForegroundColor DarkGreen

# =============================================================================
# EJECUCIÓN
# =============================================================================

$PreflightPassed = Invoke-D3PL0YStep -Name 'Comprobaciones previas' -Action {

    if (-not (Test-D3PL0YAdministrator))
    {
        throw 'D3PL0Y debe ejecutarse como administrador.'
    }

    if (
        [Environment]::Is64BitOperatingSystem -and
        (-not [Environment]::Is64BitProcess)
    )
    {
        throw (
            'Ejecuta D3PL0Y desde Windows PowerShell de 64 bits; ' +
            'la consola x86 no puede aplicar correctamente la pantalla de bloqueo.'
        )
    }

    $OperatingSystem = Get-CimInstance Win32_OperatingSystem

    if ([version]$OperatingSystem.Version -lt [version]'10.0.22000')
    {
        throw (
            'D3PL0Y requiere Windows 11. Versión detectada: {0}' -f
            $OperatingSystem.Version
        )
    }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue))
    {
        throw (
            'WinGet no está disponible. Instala o actualiza ' +
            'App Installer desde Microsoft Store.'
        )
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    & winget.exe source update | Out-Null

    if ($LASTEXITCODE -ne 0)
    {
        Write-D3PL0YWarning 'No se pudieron actualizar las fuentes de WinGet.'
    }
}

if (-not $PreflightPassed)
{
    Set-D3PL0YStatus 'ABORTADO'

    if ($script:TranscriptStarted)
    {
        try
        {
            Stop-Transcript | Out-Null
            $script:TranscriptStarted = $false
        }
        catch
        {
        }
    }

    throw 'D3PL0Y se ha detenido porque falló una comprobación previa.'
}

Invoke-D3PL0YStep -Name 'Asignar nombre de equipo' -Action {

    Set-D3PL0YComputerName `
        -TargetName $SelectedConfig.TargetComputerName
} | Out-Null

Invoke-D3PL0YStep -Name 'Configurar energía' -Action {

    if ($SelectedD3PL0Y -eq 'C0NTR0L-SCR1PT')
    {
        # C0NTR0L solo modifica el comportamiento conectado a corriente.
        # Las opciones de batería quedan exactamente como estuvieran.
        $PowerCommands = @(
            @('-h', 'off'),
            @('/change', 'standby-timeout-ac', '0'),
            @('/change', 'monitor-timeout-ac', '10'),
            @('/setacvalueindex', 'scheme_current', 'sub_buttons', 'lidaction', '0'),
            @('/setactive', 'scheme_current')
        )
    }
    else
    {
        $PowerCommands = @(
            @('-h', 'off'),
            @('/change', 'standby-timeout-ac', '0'),
            @('/change', 'monitor-timeout-ac', '20'),
            @('/change', 'standby-timeout-dc', '30'),
            @('/change', 'monitor-timeout-dc', '10')
        )
    }

    foreach ($Arguments in $PowerCommands)
    {
        & powercfg.exe @Arguments | Out-Null

        if ($LASTEXITCODE -ne 0)
        {
            Write-D3PL0YWarning (
                'Powercfg devolvió un error para: {0}' -f
                ($Arguments -join ' ')
            )
        }
    }

    if ($SelectedD3PL0Y -eq 'C0NTR0L-SCR1PT')
    {
        Set-D3PL0YRegistryValue `
            -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' `
            -Name 'HiberbootEnabled' `
            -Value 0 `
            -Type DWord

        Write-D3PL0YLog (
            'C0NTR0L: sin suspensión con corriente, pantalla a 10 minutos, ' +
            'tapa sin acción, hibernación e inicio rápido desactivados. ' +
            'No se han modificado las opciones de batería.'
        ) 'OK'
    }
} | Out-Null

if (-not $SkipDebloat)
{
    Invoke-D3PL0YStep -Name 'Desinstalar OneDrive' -Action {

        Uninstall-D3PL0YOneDrive
    } | Out-Null

    Invoke-D3PL0YStep -Name 'Eliminar aplicaciones preinstaladas' -Action {

        # Lista deliberadamente conservadora: se mantienen Store, WinGet,
        # Terminal, Bloc de notas, Calculadora, Fotos, Paint, Cámara,
        # Recortes, codecs, Seguridad de Windows y componentes del sistema.
        $AppsToRemove = @(
            'Clipchamp.Clipchamp',
            'Microsoft.3DBuilder',
            'Microsoft.549981C3F5F10',
            'Microsoft.BingNews',
            'Microsoft.BingWeather',
            'Microsoft.Copilot',
            'Microsoft.GamingApp',
            'Microsoft.GetHelp',
            'Microsoft.Getstarted',
            'Microsoft.Microsoft3DViewer',
            'Microsoft.MicrosoftOfficeHub',
            'Microsoft.MicrosoftSolitaireCollection',
            'Microsoft.MixedReality.Portal',
            'Microsoft.OneDriveSync',
            'Microsoft.OutlookForWindows',
            'Microsoft.People',
            'Microsoft.PowerAutomateDesktop',
            'Microsoft.SkypeApp',
            'Microsoft.Todos',
            'Microsoft.WindowsFeedbackHub',
            'Microsoft.WindowsMaps',
            'Microsoft.Xbox.TCUI',
            'Microsoft.XboxApp',
            'Microsoft.XboxGameOverlay',
            'Microsoft.XboxGamingOverlay',
            'Microsoft.XboxIdentityProvider',
            'Microsoft.XboxSpeechToTextOverlay',
            'Microsoft.YourPhone',
            'Microsoft.ZuneMusic',
            'Microsoft.ZuneVideo',
            'MicrosoftTeams',
            'MSTeams'
        )

        foreach ($Target in $AppsToRemove)
        {
            Remove-D3PL0YAppxPackage -Name $Target
        }
    } | Out-Null
}
else
{
    Write-D3PL0YWarning (
        'Se ha omitido la desinstalación de OneDrive y del bloatware.'
    )
}

Invoke-D3PL0YStep -Name 'Configurar privacidad y sugerencias' -Action {

    $ContentDeliveryManager =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

    foreach ($Property in @(
        'SubscribedContent-338387Enabled',
        'SubscribedContent-338388Enabled',
        'SubscribedContent-338389Enabled',
        'SubscribedContent-353694Enabled',
        'SubscribedContent-353696Enabled',
        'RotatingLockScreenEnabled',
        'RotatingLockScreenOverlayEnabled',
        'SystemPaneSuggestionsEnabled',
        'SilentInstalledAppsEnabled',
        'SoftLandingEnabled'
    ))
    {
        Set-D3PL0YRegistryValue `
            -Path $ContentDeliveryManager `
            -Name $Property `
            -Value 0 `
            -Type DWord
    }

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' `
        -Name 'TurnOffWindowsCopilot' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' `
        -Name 'AllowTelemetry' `
        -Value 0 `
        -Type DWord

    $CloudContentPolicy =
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'

    foreach ($Property in @(
        'DisableTailoredExperiencesWithDiagnosticData',
        'DisableThirdPartySuggestions',
        'DisableWindowsConsumerFeatures',
        'DisableWindowsSpotlightFeatures',
        'DisableWindowsSpotlightOnActionCenter',
        'DisableWindowsSpotlightOnLockScreen',
        'DisableWindowsSpotlightOnSettings',
        'DisableWindowsSpotlightWindowsWelcomeExperience'
    ))
    {
        Set-D3PL0YRegistryValue `
            -Path $CloudContentPolicy `
            -Name $Property `
            -Value 1 `
            -Type DWord
    }

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' `
        -Name 'Enabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' `
        -Name 'TailoredExperiencesWithDiagnosticDataEnabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Input\TIPC' `
        -Name 'Enabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' `
        -Name 'ScoobeSystemSettingEnabled' `
        -Value 0 `
        -Type DWord
} | Out-Null

Invoke-D3PL0YStep -Name 'Optimizar componentes de Windows 11' -Action {

    Set-D3PL0YOptionalRegistryValue `
        -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' `
        -Name 'DisableSearchBoxSuggestions' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YOptionalRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' `
        -Name 'AllowNewsAndInterests' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YOptionalRegistryValue `
        -Path 'HKCU:\System\GameConfigStore' `
        -Name 'GameDVR_Enabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YOptionalRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' `
        -Name 'AppCaptureEnabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YOptionalRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' `
        -Name 'AllowGameDVR' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YOptionalRegistryValue `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
        -Name 'LongPathsEnabled' `
        -Value 1 `
        -Type DWord
} | Out-Null

Invoke-D3PL0YStep -Name 'Instalar aplicaciones' -Action {

    $Apps = @($SelectedConfig.Apps)
    $FailedApps = New-Object System.Collections.Generic.List[string]

    foreach ($App in $Apps)
    {
        Set-D3PL0YStatus ('INSTALANDO {0}' -f $App)

        try
        {
            Install-D3PL0YWingetPackage -Id $App
        }
        catch
        {
            $FailedApps.Add($App)
            Write-D3PL0YWarning $_.Exception.Message
        }
    }

    if ($FailedApps.Count -gt 0)
    {
        throw (
            'No se pudieron instalar estas aplicaciones: {0}' -f
            ($FailedApps -join ', ')
        )
    }
} | Out-Null

if ($SelectedD3PL0Y -eq 'C0NTR0L-SCR1PT')
{
    Invoke-D3PL0YStep -Name 'Reforzar seguridad de C0NTR0L' -Action {

        Set-D3PL0YSecurityBaseline
    } | Out-Null

    Invoke-D3PL0YStep -Name 'Configurar Tailscale desatendido' -Action {

        Enable-D3PL0YTailscaleUnattended
    } | Out-Null

    Invoke-D3PL0YStep -Name 'Configurar Escritorio remoto seguro' -Action {

        Enable-D3PL0YRemoteDesktop
    } | Out-Null

    Invoke-D3PL0YStep -Name 'Programar informe semanal de salud' -Action {

        Install-D3PL0YHealthMonitoring
    } | Out-Null
}

Invoke-D3PL0YStep -Name 'Aplicar tema oscuro y configurar Explorador' -Action {

    $Personalize =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

    Set-D3PL0YRegistryValue `
        -Path $Personalize `
        -Name 'AppsUseLightTheme' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Personalize `
        -Name 'SystemUsesLightTheme' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Personalize `
        -Name 'ColorPrevalence' `
        -Value 1 `
        -Type DWord

    $ExplorerAdvanced =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'HideFileExt' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'Hidden' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'TaskbarAl' `
        -Value 1 `
        -Type DWord

    try
    {
        Set-D3PL0YRegistryValue `
            -Path $ExplorerAdvanced `
            -Name 'TaskbarDa' `
            -Value 0 `
            -Type DWord
    }
    catch
    {
        # TaskbarDa solo controla la visibilidad de Widgets. Algunas versiones
        # OEM o políticas del sistema protegen este valor; no debe impedir que
        # se apliquen el tema y el resto de ajustes del Explorador.
        Write-D3PL0YWarning (
            'No se pudo ocultar el botón de Widgets mediante TaskbarDa: {0}' -f
            $_.Exception.Message
        )
    }

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'TaskbarMn' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'ShowTaskViewButton' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'ShowSyncProviderNotifications' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'LaunchTo' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'Start_AccountNotifications' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'Start_IrisRecommendations' `
        -Value 0 `
        -Type DWord

    $Search =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'

    Set-D3PL0YRegistryValue `
        -Path $Search `
        -Name 'SearchboxTaskbarMode' `
        -Value 0 `
        -Type DWord

    $ClassicContextMenu =
        'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'

    if (-not (Test-Path -LiteralPath $ClassicContextMenu))
    {
        New-Item -Path $ClassicContextMenu -Force | Out-Null
    }

    Set-Item -LiteralPath $ClassicContextMenu -Value '' -Force
    $script:ExplorerNeedsRestart = $true
} | Out-Null

Invoke-D3PL0YStep `
    -Name ('Aplicar paleta {0}' -f $SelectedConfig.ThemeName) `
    -Action {

    $Dwm = 'HKCU:\Software\Microsoft\Windows\DWM'

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'AccentColor' `
        -Value $SelectedConfig.AccentColor `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'ColorizationColor' `
        -Value $SelectedConfig.ColorizationColor `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'EnableWindowColorization' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'ColorPrevalence' `
        -Value 1 `
        -Type DWord

    $Accent =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'

    Set-D3PL0YRegistryValue `
        -Path $Accent `
        -Name 'AccentPalette' `
        -Value $SelectedConfig.AccentPalette `
        -Type Binary

    Set-D3PL0YRegistryValue `
        -Path $Accent `
        -Name 'AccentColorMenu' `
        -Value $SelectedConfig.AccentColorMenu `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Accent `
        -Name 'StartColorMenu' `
        -Value $SelectedConfig.StartColorMenu `
        -Type DWord
} | Out-Null

Invoke-D3PL0YStep -Name 'Aplicar cursores' -Action {

    $CursorMap = [ordered]@{
        Arrow       = 'arrow_eoa.cur'
        AppStarting = 'busy_eoa.cur'
        Crosshair   = 'cross_eoa.cur'
        SizeWE      = 'ew_eoa.cur'
        Help        = 'helpsel_eoa.cur'
        IBeam       = 'ibeam_eoa.cur'
        Hand        = 'link_eoa.cur'
        SizeAll     = 'move_eoa.cur'
        SizeNESW    = 'nesw_eoa.cur'
        SizeNS      = 'ns_eoa.cur'
        SizeNWSE    = 'nwse_eoa.cur'
        NWPen       = 'pen_eoa.cur'
        Person      = 'person_eoa.cur'
        Pin         = 'pin_eoa.cur'
        No          = 'unavail_eoa.cur'
        UpArrow     = 'up_eoa.cur'
        Wait        = 'wait_eoa.cur'
    }

    foreach ($Entry in $CursorMap.GetEnumerator())
    {
        $Destination = Join-Path $CursorFolder $Entry.Value
        $Uri = '{0}/configs/cursors/{1}' -f $RepositoryRaw, $Entry.Value

        Invoke-D3PL0YDownload `
            -Uri $Uri `
            -Destination $Destination `
            -Force:$RefreshAssets

        Set-D3PL0YRegistryValue `
            -Path 'HKCU:\Control Panel\Cursors' `
            -Name $Entry.Key `
            -Value $Destination `
            -Type String
    }

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Control Panel\Cursors' `
        -Name '(Default)' `
        -Value 'D3PL0Y' `
        -Type String

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Control Panel\Cursors' `
        -Name 'CursorBaseSize' `
        -Value 48 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Control Panel\Mouse' `
        -Name 'MouseSensitivity' `
        -Value '13' `
        -Type String

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Accessibility' `
        -Name 'CursorType' `
        -Value 6 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Accessibility' `
        -Name 'CursorColor' `
        -Value 65280 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Accessibility' `
        -Name 'CursorSize' `
        -Value 2 `
        -Type DWord

    if (-not ('D3PL0YCursorRefresh' -as [type]))
    {
        Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class D3PL0YCursorRefresh
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(
        uint uiAction,
        uint uiParam,
        IntPtr pvParam,
        uint fWinIni
    );
}
'@
    }

    [D3PL0YCursorRefresh]::SystemParametersInfo(
        0x57,
        0,
        [IntPtr]::Zero,
        (0x01 -bor 0x02)
    ) | Out-Null
} | Out-Null

Invoke-D3PL0YStep -Name 'Aplicar fondo de escritorio' -Action {

    $WallpaperFile = Join-Path $WallpaperFolder $SelectedConfig.Wallpaper
    $WallpaperUri = '{0}/wallpapers/{1}' -f (
        $RepositoryRaw,
        $SelectedConfig.Wallpaper
    )

    Invoke-D3PL0YDownload `
        -Uri $WallpaperUri `
        -Destination $WallpaperFile `
        -Force

    Assert-D3PL0YPngFile -Path $WallpaperFile

    if (-not ('D3PL0YWallpaper' -as [type]))
    {
        Add-Type @'
using System.Runtime.InteropServices;

public static class D3PL0YWallpaper
{
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SystemParametersInfo(
        int uAction,
        int uParam,
        string lpvParam,
        int fuWinIni
    );
}
'@
    }

    $WallpaperApplied = [D3PL0YWallpaper]::SystemParametersInfo(
        20,
        0,
        $WallpaperFile,
        3
    )

    if (-not $WallpaperApplied)
    {
        throw 'Windows no confirmó la aplicación del fondo de escritorio.'
    }

    Write-D3PL0YLog (
        'Fondo de escritorio aplicado para {0}: {1}' -f
        $SelectedD3PL0Y,
        $SelectedConfig.Wallpaper
    ) 'OK'
} | Out-Null

Invoke-D3PL0YStep -Name 'Configurar pantalla de bloqueo' -Action {

    $LockImage = Join-Path $LockFolder $SelectedConfig.Lockscreen
    $LockUri = '{0}/wallpapers/{1}' -f (
        $RepositoryRaw,
        $SelectedConfig.Lockscreen
    )

    Invoke-D3PL0YDownload `
        -Uri $LockUri `
        -Destination $LockImage `
        -Force

    Assert-D3PL0YPngFile -Path $LockImage

    # Aplica la imagen al usuario actual mediante la API de Windows. Este es el
    # método principal en Windows 11 Pro sin administración MDM.
    try
    {
        Set-D3PL0YCurrentUserLockScreen -Path $LockImage
        Write-D3PL0YLog 'Pantalla de bloqueo aplicada al usuario actual.' 'OK'
    }
    catch
    {
        Write-D3PL0YWarning (
            'La API de pantalla de bloqueo no respondió. Se usarán las directivas de respaldo. {0}' -f
            $_.Exception.Message
        )
    }

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' `
        -Name 'LockScreenImage' `
        -Value $LockImage `
        -Type String

    # PersonalizationCSP sirve como respaldo en ediciones/builds de Windows 11
    # que no aplican inmediatamente la directiva clásica de Personalization.
    $PersonalizationCsp =
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'

    Set-D3PL0YRegistryValue `
        -Path $PersonalizationCsp `
        -Name 'LockScreenImagePath' `
        -Value $LockImage `
        -Type String

    Set-D3PL0YRegistryValue `
        -Path $PersonalizationCsp `
        -Name 'LockScreenImageUrl' `
        -Value $LockImage `
        -Type String

    Set-D3PL0YRegistryValue `
        -Path $PersonalizationCsp `
        -Name 'LockScreenImageStatus' `
        -Value 1 `
        -Type DWord

    Write-D3PL0YLog (
        'Pantalla de bloqueo preparada para {0}: {1}. Se aplicará al reiniciar.' -f
        $SelectedD3PL0Y,
        $SelectedConfig.Lockscreen
    ) 'OK'
} | Out-Null

Invoke-D3PL0YStep -Name 'Actualizar entorno gráfico' -Action {

    Restart-D3PL0YExplorer
    $script:ExplorerNeedsRestart = $false
} | Out-Null

# =============================================================================
# RESUMEN FINAL
# =============================================================================

$FinalStatus = if ($script:ErrorCount -eq 0)
{
    'COMPLETADO'
}
else
{
    'COMPLETADO CON ERRORES'
}

Set-D3PL0YStatus $FinalStatus

$FailureSummary = if ($script:FailedSteps.Count -eq 0)
{
    'Ninguna.'
}
else
{
    '- ' + ($script:FailedSteps -join "`r`n- ")
}

$Summary = @"
=================================
D3PL0Y
=================================

Versión: $Version
Perfil: $SelectedD3PL0Y
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
Estado: $FinalStatus
Equipo: $env:COMPUTERNAME
Nombre objetivo: $($SelectedConfig.TargetComputerName)
Usuario: $env:USERNAME

Fases completadas: $script:SuccessCount
Avisos: $script:WarningCount
Errores: $script:ErrorCount

Fases con error:
$FailureSummary

Log:
$LogFile

Notas:
- Aplicaciones del perfil: $InstalledAppSummary.
- Limpieza de Windows: $DebloatSummary.
- Energía: $PowerSummary.
- Funciones C0NTR0L: $ControlSummary.
- Paleta: $($SelectedConfig.ThemeName) — principal $($SelectedConfig.PrimaryColor), secundaria $($SelectedConfig.SecondaryColor), suave $($SelectedConfig.SoftColor).
- Fondo de escritorio: $($SelectedConfig.Wallpaper).
- Pantalla de bloqueo: $($SelectedConfig.Lockscreen).
- Los archivos de la carpeta OneDrive del usuario no se eliminan.
"@

Set-Content `
    -LiteralPath $SummaryFile `
    -Value $Summary `
    -Encoding UTF8

Write-Host ''
Write-Host $Summary -ForegroundColor $script:UiColor

if ($script:TranscriptStarted)
{
    try
    {
        Stop-Transcript | Out-Null
    }
    catch
    {
    }
}

if (-not $NoRestart)
{
    Write-Host ''
    Write-Host (
        'El equipo se reiniciará en 30 segundos. ' +
        'Ejecuta shutdown /a para cancelarlo.'
    ) -ForegroundColor Yellow

    $RestartDetail = if ($script:FailedSteps.Count -gt 0)
    {
        $FirstFailure = $script:FailedSteps[0]

        if ($FirstFailure.Length -gt 300)
        {
            $FirstFailure = $FirstFailure.Substring(0, 300)
        }

        ' - ERROR: {0}' -f $FirstFailure
    }
    else
    {
        ''
    }

    $RestartComment = 'D3PL0Y v{0} - {1} - {2}{3}' -f (
        $Version,
        $SelectedD3PL0Y,
        $FinalStatus,
        $RestartDetail
    )

    & shutdown.exe `
        /r `
        /t 30 `
        /c $RestartComment
}
else
{
    Write-Host 'Reinicio automático omitido mediante -NoRestart.' -ForegroundColor Yellow
}
