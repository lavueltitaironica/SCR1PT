#Requires -Version 5.1

<#
.SYNOPSIS
    SCR1PT v1.4.0 - Lanzador maestro dinamico de scripts PowerShell.

.DESCRIPTION
    Descarga un unico catalogo JSON desde el repositorio oficial de SCR1PT.
    Ese catalogo contiene nombre, descripcion, categoria, orden y URL de cada
    script disponible.

    D3PL0Y se mantiene como primera opcion y se ejecuta desde su repositorio
    oficial independiente. Los demas scripts pueden organizarse en tantas
    categorias como sea necesario sin modificar este lanzador.

    El archivo catalog.json se genera automaticamente en GitHub a partir de los
    metadatos incluidos en cada .ps1 y de su bloque .SYNOPSIS. De este modo,
    SCR1PT realiza una sola peticion para construir el menu y descarga el codigo
    de un script unicamente cuando el usuario decide ejecutarlo.

    Cada script seleccionado se descarga a una carpeta temporal y se ejecuta
    como archivo .ps1 en un proceso PowerShell independiente.

    Si el archivo declara "#Requires -RunAsAdministrator", SCR1PT solicita
    elevacion solo para ese script. Los scripts que gestionen su propia
    elevacion pueden seguir haciendolo normalmente.

.PARAMETER List
    Consulta GitHub, muestra los scripts .ps1 disponibles y termina.

.PARAMETER Run
    Ejecuta directamente un script por identificador, nombre o nombre de
    archivo. Ejemplos: w0l, W0L o W0L.ps1.

.PARAMETER NoPause
    No espera una pulsacion de Enter despues de ejecutar un script.

.EXAMPLE
    irm https://lavueltitaironica.com/scr1pt | iex

.EXAMPLE
    .\SCR1PT.ps1 -List

.EXAMPLE
    .\SCR1PT.ps1 -Run w0l

.EXAMPLE
    .\SCR1PT.ps1 -Run D3PL0Y.ps1

.NOTES
    Proyecto: SCR1PT
    Version: 1.4.0
    Repositorio: https://github.com/lavueltitaironica/SCR1PT
    Carpeta de scripts: /SCR1PT
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$List,

    [Parameter()]
    [string]$Run,

    [Parameter()]
    [switch]$NoPause
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ProjectName = 'SCR1PT'
$script:Version = '1.4.0'

$script:RepositoryOwner = 'lavueltitaironica'
$script:RepositoryName = 'SCR1PT'
$script:RepositoryBranch = 'main'
$script:ScriptsPath = 'SCR1PT'

$script:RepositoryUrl = 'https://github.com/{0}/{1}' -f `
    $script:RepositoryOwner, $script:RepositoryName

$script:RepositoryRaw = 'https://raw.githubusercontent.com/{0}/{1}/{2}' -f `
    $script:RepositoryOwner,
    $script:RepositoryName,
    $script:RepositoryBranch

$script:CatalogFileName = 'catalog.json'
$script:CatalogRawUrl = '{0}/{1}' -f `
    $script:RepositoryRaw,
    $script:CatalogFileName

$script:TemporaryRoot = Join-Path ([IO.Path]::GetTempPath()) 'SCR1PT'

$script:WebHeaders = @{
    'User-Agent' = 'SCR1PT-PowerShell-Launcher'
    'Cache-Control' = 'no-cache'
}

function Write-Scr1ptHeader {
    try {
        Clear-Host
    }
    catch {
        # La limpieza de pantalla no es imprescindible.
    }

    Write-Host ''
    Write-Host '  _____  _____ _____  __ _____  _______' -ForegroundColor Green
    Write-Host ' / ____|/ ____|  __ \/_ |  __ \|__   __|' -ForegroundColor Green
    Write-Host '| (___ | |    | |__) || | |__) |  | |' -ForegroundColor Green
    Write-Host ' \___ \| |    |  _  / | |  ___/   | |' -ForegroundColor Green
    Write-Host ' ____) | |____| | \ \ | | |       | |' -ForegroundColor Green
    Write-Host '|_____/ \_____|_|  \_\|_|_|       |_|' -ForegroundColor Green
    Write-Host ''
    Write-Host ('  LANZADOR MAESTRO DINAMICO  |  v{0}' -f $script:Version) -ForegroundColor DarkGray
    Write-Host '  LA VUELTITA IRONICA' -ForegroundColor Green
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

function Enable-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        # PowerShell 7 puede delegar la seleccion de TLS al sistema.
    }
}

function Test-IsAdministrator {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        return $false
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
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

    if (
        $parsedUrl.Scheme -ne 'https' -or
        $parsedUrl.Host -ne 'raw.githubusercontent.com'
    ) {
        return $false
    }

    $segments = @(
        $parsedUrl.AbsolutePath.Trim('/') -split '/' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($segments.Count -lt 4) {
        return $false
    }

    if ($segments[0] -ine $script:RepositoryOwner) {
        return $false
    }

    $lastSegment = [Uri]::UnescapeDataString([string]$segments[$segments.Count - 1])

    return [IO.Path]::GetExtension($lastSegment) -ieq '.ps1'
}

function ConvertTo-Scr1ptId {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $id = $Name.Trim().ToLowerInvariant()
    $id = $id -replace '[^a-z0-9]+', '-'
    $id = $id.Trim('-')

    if ([string]::IsNullOrWhiteSpace($id)) {
        throw ('No se puede generar un identificador valido para "{0}".' -f $Name)
    }

    return $id
}

function Assert-Scr1ptEntries {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Scripts
    )

    $knownIds = @{}

    foreach ($item in $Scripts) {
        $id = [string]$item.id
        $name = [string]$item.name
        $fileName = [string]$item.fileName
        $url = [string]$item.url
        $categoryId = [string]$item.categoryId
        $categoryName = [string]$item.categoryName

        if ($id -notmatch '^[a-z0-9][a-z0-9-]*$') {
            throw ('Identificador de catalogo no valido: {0}' -f $id)
        }

        if ($knownIds.ContainsKey($id)) {
            throw ('El catalogo contiene el identificador duplicado "{0}".' -f $id)
        }

        if ([string]::IsNullOrWhiteSpace($name)) {
            throw ('El script {0} no tiene nombre visible.' -f $id)
        }

        if ([IO.Path]::GetFileName($fileName) -ne $fileName -or
            [IO.Path]::GetExtension($fileName) -ine '.ps1') {
            throw ('Nombre de archivo no valido en el catalogo: {0}' -f $fileName)
        }

        if ([string]::IsNullOrWhiteSpace($categoryId) -or
            [string]::IsNullOrWhiteSpace($categoryName)) {
            throw ('El script {0} no tiene una categoria valida.' -f $name)
        }

        if (-not (Test-TrustedRawUrl -Url $url)) {
            throw ('URL RAW no permitida para {0}.' -f $fileName)
        }

        $knownIds[$id] = $true
    }
}

function Get-Scr1ptCatalog {
    Write-Scr1ptStatus -Type Info -Message 'Descargando catalogo de SCR1PT...'
    Enable-Tls12

    $response = Invoke-WebRequest `
        -Uri $script:CatalogRawUrl `
        -UseBasicParsing `
        -Headers $script:WebHeaders

    $json = [string]$response.Content

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw 'GitHub ha devuelto un catalogo vacio.'
    }

    $payload = ConvertFrom-Json -InputObject $json

    if ($null -eq $payload) {
        throw 'No se ha podido interpretar catalog.json.'
    }

    if ($null -eq $payload.PSObject.Properties['schemaVersion'] -or
        [int]$payload.schemaVersion -ne 1) {
        throw 'La version del esquema de catalog.json no es compatible.'
    }

    $categoryMap = @{}

    foreach ($category in @($payload.categories)) {
        if ($null -eq $category) {
            continue
        }

        $categoryId = [string]$category.id
        $categoryName = [string]$category.name
        $categoryOrder = 500

        if ($null -ne $category.PSObject.Properties['order']) {
            $categoryOrder = [int]$category.order
        }

        if ([string]::IsNullOrWhiteSpace($categoryId) -or
            [string]::IsNullOrWhiteSpace($categoryName)) {
            throw 'catalog.json contiene una categoria sin id o nombre.'
        }

        $categoryMap[$categoryId] = [pscustomobject]@{
            id = $categoryId
            name = $categoryName
            order = $categoryOrder
        }
    }

    $entries = New-Object 'System.Collections.Generic.List[object]'

    foreach ($item in @($payload.scripts)) {
        if ($null -eq $item) {
            continue
        }

        $categoryId = [string]$item.category

        if (-not $categoryMap.ContainsKey($categoryId)) {
            throw ('El script {0} referencia una categoria inexistente: {1}' -f `
                $item.name, $categoryId)
        }

        $category = $categoryMap[$categoryId]
        $description = ''
        $scriptOrder = 100
        $source = 'SCR1PT'

        if ($null -ne $item.PSObject.Properties['description']) {
            $description = [string]$item.description
        }

        if ($null -ne $item.PSObject.Properties['order']) {
            $scriptOrder = [int]$item.order
        }

        if ($null -ne $item.PSObject.Properties['source']) {
            $source = [string]$item.source
        }

        $entries.Add([pscustomobject]@{
            id = [string]$item.id
            name = [string]$item.name
            fileName = [string]$item.fileName
            url = [string]$item.url
            description = $description
            categoryId = [string]$category.id
            categoryName = [string]$category.name
            categoryOrder = [int]$category.order
            order = $scriptOrder
            source = $source
        })
    }

    $scripts = @($entries)

    if ($scripts.Count -eq 0) {
        throw 'catalog.json no contiene ningun script disponible.'
    }

    Assert-Scr1ptEntries -Scripts $scripts

    $d3pl0y = @($scripts | Where-Object { $_.id -ieq 'd3pl0y' })

    if ($d3pl0y.Count -ne 1) {
        throw 'catalog.json debe contener exactamente una entrada con id "d3pl0y".'
    }

    $d3pl0yCategory = [string]$d3pl0y[0].categoryId

    $ordered = @(
        $scripts |
            Sort-Object `
                @{ Expression = {
                    if ($_.categoryId -ieq $d3pl0yCategory) { -1000 }
                    else { [int]$_.categoryOrder }
                } }, `
                @{ Expression = {
                    if ($_.id -ieq 'd3pl0y') { 0 }
                    else { 1 }
                } }, `
                @{ Expression = { [int]$_.order } }, `
                @{ Expression = { [string]$_.name } }
    )

    $categoryCount = @($ordered | Select-Object -ExpandProperty categoryId -Unique).Count

    Write-Scr1ptStatus `
        -Type Success `
        -Message ('Catalogo preparado: {0} script(s) en {1} categoria(s).' -f `
            $ordered.Count, $categoryCount)

    return $ordered
}

function Show-Scr1ptCatalog {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Scripts,

        [Parameter()]
        [switch]$Numbered
    )

    Write-Host ''
    Write-Host '  SCRIPTS DISPONIBLES' -ForegroundColor Cyan
    Write-Host '  -------------------' -ForegroundColor DarkGray

    if ($Scripts.Count -eq 0) {
        Write-Scr1ptStatus -Type Warning -Message 'No hay scripts disponibles.'
        return
    }

    $currentCategory = ''

    for ($index = 0; $index -lt $Scripts.Count; $index++) {
        $item = $Scripts[$index]
        $categoryName = [string]$item.categoryName

        if ($categoryName -ine $currentCategory) {
            Write-Host ''
            Write-Host ('  {0}' -f $categoryName.ToUpperInvariant()) -ForegroundColor Cyan
            Write-Host '  ----------------------------------------------------' -ForegroundColor DarkGray
            $currentCategory = $categoryName
        }

        if ($Numbered) {
            Write-Host ('  [{0,2}] ' -f ($index + 1)) -NoNewline -ForegroundColor Green
        }
        else {
            Write-Host '  - ' -NoNewline -ForegroundColor Green
        }

        Write-Host ([string]$item.name) -ForegroundColor White

        if (-not [string]::IsNullOrWhiteSpace([string]$item.description)) {
            Write-Host ('       {0}' -f [string]$item.description) -ForegroundColor DarkGray
        }
    }
}

function Resolve-Scr1ptSelection {
    param(
        [Parameter(Mandatory)]
        [object[]]$Scripts,

        [Parameter(Mandatory)]
        [string]$Value
    )

    $needle = $Value.Trim()

    if ([string]::IsNullOrWhiteSpace($needle)) {
        return $null
    }

    $matches = @(
        $Scripts |
            Where-Object {
                $_.id -ieq $needle -or
                $_.name -ieq $needle -or
                $_.fileName -ieq $needle -or
                $_.fileName -ieq ('{0}.ps1' -f $needle)
            }
    )

    if ($matches.Count -eq 1) {
        return $matches[0]
    }

    if ($matches.Count -gt 1) {
        throw ('La seleccion "{0}" coincide con mas de un script.' -f $Value)
    }

    return $null
}

function Get-PowerShellExecutable {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        try {
            $processPath = (Get-Process -Id $PID).Path

            if (-not [string]::IsNullOrWhiteSpace($processPath)) {
                return $processPath
            }
        }
        catch {
            # Se intentara usar otro ejecutable.
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:SystemRoot)) {
        $windowsPowerShell = Join-Path `
            $env:SystemRoot `
            'System32\WindowsPowerShell\v1.0\powershell.exe'

        if (Test-Path -LiteralPath $windowsPowerShell) {
            return $windowsPowerShell
        }
    }

    $command = Get-Command powershell.exe -ErrorAction SilentlyContinue

    if ($null -ne $command) {
        return $command.Source
    }

    $command = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if ($null -ne $command) {
        return $command.Source
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

    $sessionFolder = Join-Path `
        $script:TemporaryRoot `
        ([Guid]::NewGuid().ToString('N'))

    New-Item -ItemType Directory -Path $sessionFolder -Force | Out-Null

    $destination = Join-Path $sessionFolder ([string]$ScriptEntry.fileName)

    try {
        Enable-Tls12

        $response = Invoke-WebRequest `
            -Uri $url `
            -UseBasicParsing `
            -Headers $script:WebHeaders

        $content = [string]$response.Content

        if ([string]::IsNullOrWhiteSpace($content)) {
            throw 'GitHub ha devuelto un archivo vacio.'
        }

        if ($content[0] -eq [char]0xFEFF) {
            $content = $content.Substring(1)
        }

        if ($content -match '^\s*<(?:!DOCTYPE|html)') {
            throw 'La descarga recibida no es un script PowerShell.'
        }

        # Windows PowerShell 5.1 puede interpretar UTF-8 sin BOM con la pagina
        # de codigos ANSI. Normalizamos a UTF-8 con BOM antes de ejecutar.
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [IO.File]::WriteAllText($destination, $content, $utf8WithBom)

        $fileInfo = Get-Item -LiteralPath $destination

        if ($fileInfo.Length -eq 0) {
            throw 'El archivo temporal generado esta vacio.'
        }

        return $destination
    }
    catch {
        if (Test-Path -LiteralPath $sessionFolder) {
            Remove-Item `
                -LiteralPath $sessionFolder `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }

        throw
    }
}

function Get-Scr1ptPayloadRequirements {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $minimumPowerShell = '5.1'

    $versionMatch = [regex]::Match(
        $content,
        '(?im)^\s*#requires\s+-version\s+([0-9]+(?:\.[0-9]+){0,3})\s*$'
    )

    if ($versionMatch.Success) {
        $minimumPowerShell = [string]$versionMatch.Groups[1].Value
    }

    $requiresAdmin = [regex]::IsMatch(
        $content,
        '(?im)^\s*#requires\s+-runasadministrator\s*$'
    )

    # Convencion opcional para futuros scripts SCR1PT:
    # # SCR1PT-RequiresAdmin: true
    if (-not $requiresAdmin) {
        $requiresAdmin = [regex]::IsMatch(
            $content,
            '(?im)^\s*#\s*SCR1PT-RequiresAdmin\s*:\s*(?:true|yes|1)\s*$'
        )
    }

    return [pscustomobject]@{
        minimumPowerShell = $minimumPowerShell
        requiresAdmin = $requiresAdmin
    }
}

function Test-ScriptCompatibility {
    param(
        [Parameter(Mandatory)]
        [string]$MinimumPowerShell
    )

    $minimum = $null

    if (-not [Version]::TryParse($MinimumPowerShell, [ref]$minimum)) {
        $message = 'El script declara una version minima de PowerShell no valida: {0}.' -f `
            $MinimumPowerShell
        throw $message
    }

    return $PSVersionTable.PSVersion -ge $minimum
}

function Invoke-Scr1ptEntry {
    param(
        [Parameter(Mandatory)]
        [object]$ScriptEntry
    )

    Write-Scr1ptStatus `
        -Type Info `
        -Message ('Descargando {0}...' -f $ScriptEntry.fileName)

    $payloadPath = Save-Scr1ptPayload -ScriptEntry $ScriptEntry

    try {
        $requirements = Get-Scr1ptPayloadRequirements -Path $payloadPath
        $minimumPowerShell = [string]$requirements.minimumPowerShell

        if (-not (Test-ScriptCompatibility -MinimumPowerShell $minimumPowerShell)) {
            $message = '{0} requiere PowerShell {1} o posterior. Version actual: {2}.' -f `
                $ScriptEntry.fileName,
                $minimumPowerShell,
                $PSVersionTable.PSVersion

            throw $message
        }

        $powerShellExe = Get-PowerShellExecutable

        $directArguments = @(
            '-NoLogo'
            '-NoProfile'
            '-ExecutionPolicy'
            'Bypass'
            '-File'
            $payloadPath
        )

        Write-Scr1ptStatus `
            -Type Info `
            -Message ('Ejecutando {0}...' -f $ScriptEntry.name)

        if ([bool]$requirements.requiresAdmin -and -not (Test-IsAdministrator)) {
            Write-Scr1ptStatus `
                -Type Info `
                -Message (
                    'El script declara que necesita permisos de administrador. ' +
                    'Windows mostrara el control de cuentas de usuario.'
                )

            $quotedPayload = '"{0}"' -f $payloadPath.Replace('"', '\"')

            $elevatedArguments = @(
                '-NoLogo'
                '-NoProfile'
                '-ExecutionPolicy'
                'Bypass'
                '-File'
                $quotedPayload
            )

            $process = Start-Process `
                -FilePath $powerShellExe `
                -ArgumentList $elevatedArguments `
                -Verb RunAs `
                -Wait `
                -PassThru

            $exitCode = $process.ExitCode
        }
        else {
            & $powerShellExe @directArguments
            $exitCode = $LASTEXITCODE
        }

        if ($null -eq $exitCode) {
            $exitCode = 0
        }

        if ($exitCode -eq 0) {
            Write-Scr1ptStatus `
                -Type Success `
                -Message ('{0} ha finalizado correctamente.' -f $ScriptEntry.name)
        }
        else {
            $message = '{0} ha finalizado con el codigo {1}.' -f `
                $ScriptEntry.name, $exitCode

            Write-Scr1ptStatus -Type Warning -Message $message
        }
    }
    finally {
        $sessionFolder = Split-Path -Parent $payloadPath

        if (Test-Path -LiteralPath $sessionFolder) {
            Remove-Item `
                -LiteralPath $sessionFolder `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

function Wait-Scr1pt {
    if (-not $NoPause) {
        Write-Host ''
        [void](Read-Host 'Pulsa Enter para volver al menu')
    }
}

function Write-Scr1ptRepositoryInfo {
    param(
        [Parameter(Mandatory)]
        [object[]]$Scripts
    )

    $scriptCount = $Scripts.Count
    $categoryCount = @($Scripts | Select-Object -ExpandProperty categoryId -Unique).Count

    $repositoryLine = '  GitHub: {0}/{1} | Rama: {2}' -f `
        $script:RepositoryOwner,
        $script:RepositoryName,
        $script:RepositoryBranch

    $catalogLine = '  Catalogo: {0} | {1} script(s) | {2} categoria(s)' -f `
        $script:CatalogFileName,
        $scriptCount,
        $categoryCount

    $runtimeLine = '  Inicio: 1 descarga de catalogo | Script: se descarga solo al ejecutarlo'

    Write-Host $repositoryLine -ForegroundColor DarkGray
    Write-Host $catalogLine -ForegroundColor DarkGray
    Write-Host $runtimeLine -ForegroundColor DarkGray
}

try {
    Write-Scr1ptHeader
    $scripts = @(Get-Scr1ptCatalog)

    if ($List) {
        Write-Scr1ptRepositoryInfo -Scripts $scripts
        Show-Scr1ptCatalog -Scripts $scripts
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($Run)) {
        $selected = Resolve-Scr1ptSelection -Scripts $scripts -Value $Run

        if ($null -eq $selected) {
            $message = 'No existe ningun script disponible que coincida con "{0}".' -f $Run
            throw $message
        }

        Invoke-Scr1ptEntry -ScriptEntry $selected
        return
    }

    do {
        Write-Scr1ptHeader
        Write-Scr1ptRepositoryInfo -Scripts $scripts
        Show-Scr1ptCatalog -Scripts $scripts -Numbered

        Write-Host ''
        Write-Host '  [R] Actualizar catalogo desde GitHub' -ForegroundColor Cyan
        Write-Host '  [S] Salir' -ForegroundColor Cyan
        Write-Host ''

        $choice = (Read-Host 'Selecciona una opcion').Trim()

        if ($choice -match '(?i)^s$') {
            break
        }

        if ($choice -match '(?i)^r$') {
            try {
                Write-Host ''
                $scripts = @(Get-Scr1ptCatalog)
            }
            catch {
                Write-Scr1ptStatus -Type Error -Message $_.Exception.Message
                Wait-Scr1pt
            }

            continue
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
