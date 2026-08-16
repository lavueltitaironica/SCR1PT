#Requires -Version 5.1

<#
.SYNOPSIS
    SCR1PT v1.1.2 - Lanzador maestro de scripts PowerShell.

.DESCRIPTION
    Muestra el catalogo integrado de SCR1PT y ejecuta el script elegido en un
    proceso PowerShell independiente.

    El lanzador se aloja en la raiz del repositorio. Los scripts disponibles
    se alojan en la carpeta SCR1PT del mismo repositorio.

    Los scripts que requieren permisos de administrador se elevan de forma
    individual. El lanzador no necesita ejecutarse como administrador.

.PARAMETER List
    Muestra el catalogo y termina sin ejecutar ningun script.

.PARAMETER Run
    Ejecuta directamente un script mediante su identificador.
    Este parametro esta pensado para la ejecucion local de SCR1PT.ps1.

.PARAMETER NoPause
    No espera una pulsacion de Enter despues de ejecutar un script.

.EXAMPLE
    irm https://lavueltitaironica.com/scr1pt | iex

.EXAMPLE
    .\SCR1PT.ps1 -List

.EXAMPLE
    .\SCR1PT.ps1 -Run w0l

.NOTES
    Proyecto: SCR1PT
    Version: 1.1.2
    Repositorio: https://github.com/t3st-scr1pt/D3PL0Y
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$List,

    [Parameter()]
    # La validacion se realiza manualmente: ValidatePattern rechaza el valor
    # vacio implicito al ejecutar el script mediante Invoke-Expression.
    [string]$Run,

    [Parameter()]
    [switch]$NoPause
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ProjectName = 'SCR1PT'
$script:Version = '1.1.2'
$script:RepositoryRaw = 'https://raw.githubusercontent.com/t3st-scr1pt/D3PL0Y/main'
$script:ScriptsRaw = '{0}/SCR1PT' -f $script:RepositoryRaw
$script:AllowedRawPrefix = '{0}/' -f $script:ScriptsRaw
$script:TemporaryRoot = Join-Path ([IO.Path]::GetTempPath()) 'SCR1PT'

# =============================================================================
# CATALOGO DE SCRIPTS
# Para incorporar otro script, se anade una entrada a esta coleccion.
# Los archivos deben estar alojados en la carpeta /SCR1PT del repositorio.
# =============================================================================

$script:Catalog = [pscustomobject]@{
    schemaVersion = 1
    catalogVersion = '1.1.2'
    updated = '2026-08-15'
    scripts = @(
        [pscustomobject]@{
            id = 'd3pl0y'
            name = 'D3PL0Y'
            description = 'Despliega y configura Windows 11 mediante los perfiles P0RT4L, STUD10 y C0NTR0L.'
            category = 'Despliegue'
            version = '2.2.1'
            url = '{0}/D3PL0Y.ps1' -f $script:ScriptsRaw
            requiresAdmin = $true
            minPowerShell = '5.1'
            sha256 = ''
            arguments = @()
            enabled = $true
        }
        [pscustomobject]@{
            id = 'w0l'
            name = 'W0L - Wake On LAN'
            description = 'Configura energia, adaptador de red y comprobaciones necesarias para Wake On LAN.'
            category = 'Red y energia'
            version = '1.1.0'
            url = '{0}/W0L.ps1' -f $script:ScriptsRaw
            requiresAdmin = $true
            minPowerShell = '5.1'
            sha256 = ''
            arguments = @()
            enabled = $true
        }
    )
}

function Write-Scr1ptHeader {
    try {
        Clear-Host
    }
    catch {
        # La limpieza de pantalla no es imprescindible en hosts no interactivos.
    }

    Write-Host ''
    Write-Host '  _____  _____ _____  __ _____  _______' -ForegroundColor Green
    Write-Host ' / ____|/ ____|  __ \/_ |  __ \|__   __|' -ForegroundColor Green
    Write-Host '| (___ | |    | |__) || | |__) |  | |' -ForegroundColor Green
    Write-Host ' \___ \| |    |  _  / | |  ___/   | |' -ForegroundColor Green
    Write-Host ' ____) | |____| | \ \ | | |       | |' -ForegroundColor Green
    Write-Host '|_____/ \_____|_|  \_\|_|_|       |_|' -ForegroundColor Green
    Write-Host ''
    Write-Host ('  LANZADOR MAESTRO  |  v{0}' -f $script:Version) -ForegroundColor DarkGray
    Write-Host ''
}

function Write-Scr1ptStatus {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $settings = switch ($Type) {
        'Info'    { @{ Label = 'INFO';  Color = 'Cyan' } }
        'Success' { @{ Label = 'OK';    Color = 'Green' } }
        'Warning' { @{ Label = 'AVISO'; Color = 'Yellow' } }
        'Error'   { @{ Label = 'ERROR'; Color = 'Red' } }
    }

    Write-Host ('[{0}] ' -f $settings.Label) -NoNewline -ForegroundColor $settings.Color
    Write-Host $Message
}

function Get-OptionalProperty {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [AllowNull()]
        [object]$DefaultValue = $null
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }

    return $property.Value
}

function Test-IsAdministrator {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        return $false
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-TrustedRawUrl {
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    $parsedUrl = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$parsedUrl)) {
        return $false
    }

    return (
        $parsedUrl.Scheme -eq 'https' -and
        $parsedUrl.Host -eq 'raw.githubusercontent.com' -and
        $Url.StartsWith($script:AllowedRawPrefix, [StringComparison]::OrdinalIgnoreCase)
    )
}

function Enable-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        # PowerShell 7 puede delegar la seleccion de TLS al sistema operativo.
    }
}

function Get-Scr1ptCatalog {
    Assert-Scr1ptCatalog -Catalog $script:Catalog
    return $script:Catalog
}

function Assert-Scr1ptCatalog {
    param(
        [Parameter(Mandatory)]
        [object]$Catalog
    )

    $schemaVersion = Get-OptionalProperty -InputObject $Catalog -Name 'schemaVersion'
    if ([int]$schemaVersion -ne 1) {
        throw ('Version de esquema no compatible: {0}.' -f $schemaVersion)
    }

    $scriptsProperty = $Catalog.PSObject.Properties['scripts']
    if ($null -eq $scriptsProperty) {
        throw 'El catalogo no contiene la propiedad scripts.'
    }

    $knownIds = @{}
    foreach ($item in @($Catalog.scripts)) {
        $id = [string](Get-OptionalProperty -InputObject $item -Name 'id' -DefaultValue '')
        $name = [string](Get-OptionalProperty -InputObject $item -Name 'name' -DefaultValue '')
        $url = [string](Get-OptionalProperty -InputObject $item -Name 'url' -DefaultValue '')

        if ($id -notmatch '^[a-z0-9][a-z0-9-]*$') {
            throw ('El catalogo contiene un identificador no valido: {0}.' -f $id)
        }
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw ('El script {0} no tiene nombre.' -f $id)
        }
        if (-not (Test-TrustedRawUrl -Url $url)) {
            throw ('El script {0} utiliza una URL no permitida.' -f $id)
        }
        if ($knownIds.ContainsKey($id)) {
            throw ('El identificador {0} aparece duplicado en el catalogo.' -f $id)
        }

        $sha256 = [string](Get-OptionalProperty -InputObject $item -Name 'sha256' -DefaultValue '')
        if ($sha256 -and $sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
            throw ('El hash SHA-256 de {0} no es valido.' -f $id)
        }

        $knownIds[$id] = $true
    }
}

function Get-EnabledScripts {
    param(
        [Parameter(Mandatory)]
        [object]$Catalog
    )

    return @(
        $Catalog.scripts |
            Where-Object {
                $enabled = Get-OptionalProperty -InputObject $_ -Name 'enabled' -DefaultValue $true
                [bool]$enabled
            } |
            Sort-Object -Property @(
                @{ Expression = { [string](Get-OptionalProperty -InputObject $_ -Name 'category' -DefaultValue 'Otros') } },
                @{ Expression = { [string]$_.name } }
            )
    )
}

function Test-ScriptCompatibility {
    param(
        [Parameter(Mandatory)]
        [object]$ScriptEntry
    )

    $minimumText = [string](Get-OptionalProperty -InputObject $ScriptEntry -Name 'minPowerShell' -DefaultValue '5.1')
    $minimum = $null

    if (-not [Version]::TryParse($minimumText, [ref]$minimum)) {
        return $false
    }

    return $PSVersionTable.PSVersion -ge $minimum
}

function Show-Scr1ptCatalog {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Scripts,

        [Parameter()]
        [switch]$Numbered
    )

    if ($Scripts.Count -eq 0) {
        Write-Scr1ptStatus -Type Warning -Message 'El catalogo no contiene scripts habilitados.'
        return
    }

    $currentCategory = $null
    for ($index = 0; $index -lt $Scripts.Count; $index++) {
        $item = $Scripts[$index]
        $category = [string](Get-OptionalProperty -InputObject $item -Name 'category' -DefaultValue 'Otros')
        if ($category -ne $currentCategory) {
            Write-Host ''
            Write-Host ('  {0}' -f $category.ToUpperInvariant()) -ForegroundColor Cyan
            Write-Host ('  {0}' -f ('-' * $category.Length)) -ForegroundColor DarkGray
            $currentCategory = $category
        }

        $prefix = if ($Numbered) { '[{0,2}]' -f ($index + 1) } else { '  - ' }
        $requiresAdmin = [bool](Get-OptionalProperty -InputObject $item -Name 'requiresAdmin' -DefaultValue $false)
        $adminLabel = if ($requiresAdmin) { ' [ADMIN]' } else { '' }
        $compatible = Test-ScriptCompatibility -ScriptEntry $item
        $compatibilityLabel = if ($compatible) { '' } else { ' [NO COMPATIBLE]' }
        $version = [string](Get-OptionalProperty -InputObject $item -Name 'version' -DefaultValue '')
        $versionLabel = if ($version) { ' v{0}' -f $version } else { '' }

        Write-Host ('  {0} ' -f $prefix) -NoNewline -ForegroundColor Green
        Write-Host ('{0}{1}{2}{3}' -f $item.name, $versionLabel, $adminLabel, $compatibilityLabel) -ForegroundColor White

        $description = [string](Get-OptionalProperty -InputObject $item -Name 'description' -DefaultValue '')
        if ($description) {
            Write-Host ('       {0}' -f $description) -ForegroundColor DarkGray
        }
    }
}

function Get-PowerShellExecutable {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $processPath = (Get-Process -Id $PID).Path
        if ($processPath) {
            return $processPath
        }
    }

    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $windowsPowerShell) {
        return $windowsPowerShell
    }

    throw 'No se ha podido localizar un ejecutable de PowerShell compatible.'
}

function Save-Scr1ptPayload {
    param(
        [Parameter(Mandatory)]
        [object]$ScriptEntry
    )

    $url = [string]$ScriptEntry.url
    if (-not (Test-TrustedRawUrl -Url $url)) {
        throw 'La URL del script no esta permitida.'
    }

    $sessionFolder = Join-Path $script:TemporaryRoot ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $sessionFolder -Force | Out-Null

    $safeId = [string]$ScriptEntry.id
    $destination = Join-Path $sessionFolder ('{0}.ps1' -f $safeId)

    Enable-Tls12
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers @{
        'User-Agent' = 'SCR1PT-PowerShell-Launcher'
        'Cache-Control' = 'no-cache'
    }

    # Windows PowerShell 5.1 interpreta los archivos UTF-8 sin BOM usando la
    # pagina de codigos ANSI del sistema. Esto puede romper cadenas que
    # contienen acentos o caracteres graficos. Se normaliza cada descarga a
    # UTF-8 con BOM antes de ejecutarla como archivo PS1.
    $content = [string]$response.Content
    if ($content.Length -gt 0 -and $content[0] -eq [char]0xFEFF) {
        $content = $content.Substring(1)
    }

    $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
    [IO.File]::WriteAllText($destination, $content, $utf8WithBom)

    $fileInfo = Get-Item -LiteralPath $destination
    if ($fileInfo.Length -eq 0) {
        throw 'GitHub ha devuelto un archivo vacio.'
    }

    $firstLine = Get-Content -LiteralPath $destination -TotalCount 1
    if ($firstLine -match '^\s*<(?:!DOCTYPE|html)') {
        throw 'La descarga recibida no es un script PowerShell.'
    }

    $expectedHash = [string](Get-OptionalProperty -InputObject $ScriptEntry -Name 'sha256' -DefaultValue '')
    if ($expectedHash) {
        $actualHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($actualHash -ne $expectedHash.ToUpperInvariant()) {
            throw 'La comprobacion SHA-256 ha fallado. El archivo no se ejecutara.'
        }
        Write-Scr1ptStatus -Type Success -Message 'Integridad SHA-256 verificada.'
    }

    return $destination
}

function Invoke-Scr1ptEntry {
    param(
        [Parameter(Mandatory)]
        [object]$ScriptEntry
    )

    if (-not (Test-ScriptCompatibility -ScriptEntry $ScriptEntry)) {
        $minimum = [string](Get-OptionalProperty -InputObject $ScriptEntry -Name 'minPowerShell' -DefaultValue '5.1')
        throw ('Este script requiere PowerShell {0} o posterior.' -f $minimum)
    }

    $requiresAdmin = [bool](Get-OptionalProperty -InputObject $ScriptEntry -Name 'requiresAdmin' -DefaultValue $false)
    $arguments = @(
        Get-OptionalProperty -InputObject $ScriptEntry -Name 'arguments' -DefaultValue @() |
            ForEach-Object { [string]$_ }
    )

    Write-Scr1ptStatus -Type Info -Message ('Descargando {0}...' -f $ScriptEntry.name)
    $payloadPath = Save-Scr1ptPayload -ScriptEntry $ScriptEntry

    try {
        $powerShellExe = Get-PowerShellExecutable
        $directArguments = @(
            '-NoLogo'
            '-NoProfile'
            '-ExecutionPolicy'
            'Bypass'
            '-File'
            $payloadPath
        )

        foreach ($argument in $arguments) {
            $directArguments += $argument
        }

        Write-Scr1ptStatus -Type Info -Message ('Ejecutando {0}...' -f $ScriptEntry.name)

        if ($requiresAdmin -and -not (Test-IsAdministrator)) {
            Write-Scr1ptStatus -Type Info -Message 'Windows solicitara permisos de administrador.'

            $elevatedArguments = @(
                '-NoLogo'
                '-NoProfile'
                '-ExecutionPolicy'
                'Bypass'
                '-File'
                ('"{0}"' -f $payloadPath.Replace('"', '\"'))
            )
            foreach ($argument in $arguments) {
                $elevatedArguments += ('"{0}"' -f $argument.Replace('"', '\"'))
            }

            $process = Start-Process -FilePath $powerShellExe -ArgumentList $elevatedArguments -Verb RunAs -Wait -PassThru
            $exitCode = $process.ExitCode
        }
        else {
            & $powerShellExe @directArguments
            $exitCode = $LASTEXITCODE
        }

        if ($exitCode -eq 0) {
            Write-Scr1ptStatus -Type Success -Message ('{0} ha finalizado correctamente.' -f $ScriptEntry.name)
        }
        else {
            Write-Scr1ptStatus -Type Warning -Message ('{0} ha finalizado con el codigo {1}.' -f $ScriptEntry.name, $exitCode)
        }
    }
    finally {
        $sessionFolder = Split-Path -Parent $payloadPath
        if (Test-Path -LiteralPath $sessionFolder) {
            Remove-Item -LiteralPath $sessionFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Wait-Scr1pt {
    if (-not $NoPause) {
        Write-Host ''
        [void](Read-Host 'Pulsa Enter para volver al menu')
    }
}

try {
    $catalog = Get-Scr1ptCatalog
    $scripts = @(Get-EnabledScripts -Catalog $catalog)

    if ($List) {
        Show-Scr1ptCatalog -Scripts $scripts
        return
    }

    if ($Run) {
        if ($Run -notmatch '^[a-z0-9][a-z0-9-]*$') {
            throw ('El identificador indicado en -Run no es valido: {0}.' -f $Run)
        }

        $selected = @($scripts | Where-Object { $_.id -eq $Run })
        if ($selected.Count -ne 1) {
            throw ('No existe ningun script habilitado con el identificador {0}.' -f $Run)
        }
        Invoke-Scr1ptEntry -ScriptEntry $selected[0]
        return
    }

    do {
        Write-Scr1ptHeader

        $catalogVersion = [string](Get-OptionalProperty -InputObject $catalog -Name 'catalogVersion' -DefaultValue 'sin version')
        $updated = [string](Get-OptionalProperty -InputObject $catalog -Name 'updated' -DefaultValue 'sin fecha')
        Write-Host ('  Catalogo {0} | Actualizado: {1}' -f $catalogVersion, $updated) -ForegroundColor DarkGray

        Show-Scr1ptCatalog -Scripts $scripts -Numbered

        Write-Host ''
        Write-Host '  [S] Salir' -ForegroundColor Cyan
        Write-Host ''

        $choice = (Read-Host 'Selecciona una opcion').Trim()

        if ($choice -match '(?i)^s$') {
            break
        }

        $selectionNumber = 0
        if (-not [int]::TryParse($choice, [ref]$selectionNumber) -or
            $selectionNumber -lt 1 -or
            $selectionNumber -gt $scripts.Count) {
            Write-Scr1ptStatus -Type Warning -Message 'Seleccion no valida.'
            Wait-Scr1pt
            continue
        }

        try {
            Invoke-Scr1ptEntry -ScriptEntry $scripts[$selectionNumber - 1]
        }
        catch {
            Write-Scr1ptStatus -Type Error -Message $_.Exception.Message
        }

        Wait-Scr1pt
    }
    while ($true)
}
catch {
    Write-Host ''
    Write-Scr1ptStatus -Type Error -Message $_.Exception.Message
    Write-Host ''
    Write-Host 'SCR1PT no ha realizado ninguna ejecucion.' -ForegroundColor Yellow
    throw
}
