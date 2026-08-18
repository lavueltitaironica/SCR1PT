#Requires -Version 5.1

<#
.SYNOPSIS
    Genera catalog.json para SCR1PT.

.DESCRIPTION
    Escanea recursivamente /SCR1PT, lee el .SYNOPSIS, los metadatos SCR1PT y
    requisitos declarados por cada archivo .ps1 y genera el catalogo oficial.

    D3PL0Y se mantiene como fuente externa oficial. El generador consulta su
    script en el repositorio independiente para obtener version y requisitos
    sin duplicarlo dentro de SCR1PT.

    Metadatos opcionales por script:

        # SCR1PT-Name: NOMBRE VISIBLE
        # SCR1PT-Version: 1.0.0
        # SCR1PT-Category: RED Y ENERGIA
        # SCR1PT-CategoryOrder: 20
        # SCR1PT-Order: 10
        # SCR1PT-RequiresAdmin: true
        # SCR1PT-Hidden: false

    Si SCR1PT-Version no existe, la version se intenta obtener de las variables
    $script:Version, $script:Scr1ptVersion, $Version o de una linea Version en
    .NOTES. Los requisitos de PowerShell y administrador se detectan tambien
    desde #Requires. Los scripts que se autoelevan mediante -Verb RunAs se
    marcan como herramientas que requieren privilegios administrativos.

    La descripcion se obtiene de .SYNOPSIS para evitar duplicar texto.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repositoryOwner = 'lavueltitaironica'
$repositoryName = 'SCR1PT'
$repositoryBranch = 'main'
$scriptsRoot = Join-Path $RepositoryRoot 'SCR1PT'
$catalogPath = Join-Path $RepositoryRoot 'catalog.json'
$launcherPath = Join-Path $RepositoryRoot 'SCR1PT.ps1'
$existingCatalog = $null
$existingCatalogRaw = ''

if (Test-Path -LiteralPath $catalogPath) {
    try {
        $existingCatalogRaw = Get-Content -LiteralPath $catalogPath -Raw
        $existingCatalog = $existingCatalogRaw | ConvertFrom-Json
    }
    catch {
        Write-Warning ('El catalogo existente no se puede reutilizar: {0}' -f $_.Exception.Message)
        $existingCatalog = $null
        $existingCatalogRaw = ''
    }
}

$d3pl0yRawUrl = 'https://raw.githubusercontent.com/lavueltitaironica/D3PL0Y/main/D3PL0Y.ps1'

function ConvertTo-Slug {
    param([Parameter(Mandatory)][string]$Text)

    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object Text.StringBuilder

    foreach ($character in $normalized.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($character)

        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }

    $slug = $builder.ToString().Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw ('No se puede generar un identificador para "{0}".' -f $Text)
    }

    return $slug
}

function Get-MetadataValue {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Name
    )

    $escapedName = [regex]::Escape($Name)
    $match = [regex]::Match(
        $Content,
        ('(?im)^\s*#\s*{0}\s*:\s*(.+?)\s*$' -f $escapedName)
    )

    if ($match.Success) {
        return [string]$match.Groups[1].Value.Trim()
    }

    return ''
}

function Get-Synopsis {
    param([Parameter(Mandatory)][string]$Content)

    $lines = @($Content -split "`r?`n")
    $capture = $false
    $parts = New-Object 'System.Collections.Generic.List[string]'

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if (-not $capture) {
            if ($trimmed -ieq '.SYNOPSIS') {
                $capture = $true
            }
            continue
        }

        if ($trimmed -match '^\.[A-Z][A-Z0-9]*\b' -or $trimmed -eq '#>') {
            break
        }

        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $parts.Add($trimmed)
        }
    }

    $synopsis = (($parts -join ' ') -replace '\s+', ' ').Trim()

    if ([string]::IsNullOrWhiteSpace($synopsis)) {
        return 'Script PowerShell de SCR1PT.'
    }

    if ($synopsis.Length -gt 180) {
        $synopsis = $synopsis.Substring(0, 177).TrimEnd() + '...'
    }

    return $synopsis
}

function Get-CatalogDescription {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$DisplayName
    )

    $description = Get-Synopsis -Content $Content

    # Evita que tarjetas y README repitan "P0W3R v1.0.0 - ..." cuando el
    # nombre y la version ya se muestran en campos separados.
    $prefixPattern = '(?i)^{0}\s+v?[0-9]+(?:\.[0-9]+){{1,3}}\s*[-:]\s*' -f [regex]::Escape($DisplayName)
    $description = [regex]::Replace($description, $prefixPattern, '').Trim()

    if ([string]::IsNullOrWhiteSpace($description)) {
        return 'Script PowerShell de SCR1PT.'
    }

    return $description
}

function Get-IntegerMetadata {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Default
    )

    $value = Get-MetadataValue -Content $Content -Name $Name
    $number = 0

    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    if (-not [int]::TryParse($value, [ref]$number)) {
        throw ('{0} debe ser un numero entero. Valor recibido: {1}' -f $Name, $value)
    }

    return $number
}

function Get-ScriptVersion {
    param([Parameter(Mandatory)][string]$Content)

    $metadataVersion = Get-MetadataValue -Content $Content -Name 'SCR1PT-Version'

    if (-not [string]::IsNullOrWhiteSpace($metadataVersion)) {
        return $metadataVersion
    }

    $patterns = @(
        '(?im)^\s*\$script:(?:Scr1ptVersion|Version)\s*=\s*[''"]([^''"]+)[''"]',
        '(?im)^\s*\$Version\s*=\s*[''"]([^''"]+)[''"]',
        '(?im)^\s*Version\s*:?\s*([0-9]+(?:\.[0-9]+){1,3})\b',
        '(?im)^\s*[A-Za-z0-9_-]+\s+v([0-9]+(?:\.[0-9]+){1,3})\b'
    )

    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Content, $pattern)

        if ($match.Success) {
            return [string]$match.Groups[1].Value.Trim()
        }
    }

    return ''
}

function Get-MinimumPowerShellVersion {
    param([Parameter(Mandatory)][string]$Content)

    $match = [regex]::Match(
        $Content,
        '(?im)^\s*#requires\s+-version\s+([0-9]+(?:\.[0-9]+){0,3})\s*$'
    )

    if ($match.Success) {
        return [string]$match.Groups[1].Value.Trim()
    }

    return '5.1'
}

function Get-RequiresAdmin {
    param([Parameter(Mandatory)][string]$Content)

    if ([regex]::IsMatch($Content, '(?im)^\s*#requires\s+-runasadministrator\s*$')) {
        return $true
    }

    $metadata = Get-MetadataValue -Content $Content -Name 'SCR1PT-RequiresAdmin'

    if ($metadata -match '^(?i:true|yes|1)$') {
        return $true
    }

    # W0L y otras utilidades pueden gestionar su propia elevacion.
    if ([regex]::IsMatch($Content, '(?im)\-Verb\s+RunAs\b')) {
        return $true
    }

    return $false
}

function ConvertTo-RawPath {
    param([Parameter(Mandatory)][string]$RelativePath)

    $segments = @(
        ($RelativePath -replace '\\', '/') -split '/' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { [Uri]::EscapeDataString($_) }
    )

    return ($segments -join '/')
}

function Get-ExistingScript {
    param([Parameter(Mandatory)][string]$Id)

    if ($null -eq $existingCatalog -or
        $null -eq $existingCatalog.PSObject.Properties['scripts']) {
        return $null
    }

    foreach ($item in @($existingCatalog.scripts)) {
        if ($null -ne $item -and [string]$item.id -ieq $Id) {
            return $item
        }
    }

    return $null
}

function Get-RemoteScriptContent {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Name
    )

    try {
        $response = Invoke-WebRequest `
            -Uri $Url `
            -Headers @{ 'User-Agent' = 'SCR1PT-Catalog-Builder' } `
            -TimeoutSec 20

        $content = [string]$response.Content

        if ([string]::IsNullOrWhiteSpace($content)) {
            throw 'El archivo remoto esta vacio.'
        }

        return $content
    }
    catch {
        Write-Warning ('No se ha podido leer {0}: {1}' -f $Name, $_.Exception.Message)
        return ''
    }
}

if (-not (Test-Path -LiteralPath $scriptsRoot)) {
    throw ('No existe la carpeta de scripts: {0}' -f $scriptsRoot)
}

if (-not (Test-Path -LiteralPath $launcherPath)) {
    throw ('No existe el lanzador maestro: {0}' -f $launcherPath)
}

$categories = @{}
$scripts = New-Object 'System.Collections.Generic.List[object]'
$knownIds = @{}

function Register-Category {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Order
    )

    $id = ConvertTo-Slug -Text $Name

    if ($categories.ContainsKey($id)) {
        $existing = $categories[$id]

        if ($Order -lt [int]$existing.order) {
            $existing.order = $Order
        }

        return $id
    }

    $categories[$id] = [pscustomobject][ordered]@{
        id = $id
        name = $Name.Trim()
        order = $Order
    }

    return $id
}

# Informacion del lanzador maestro. Sirve al README y a consumidores externos
# sin obligarles a interpretar SCR1PT.ps1 por su cuenta.
$launcherContent = Get-Content -LiteralPath $launcherPath -Raw
$launcher = [pscustomobject][ordered]@{
    name = 'SCR1PT'
    version = Get-ScriptVersion -Content $launcherContent
    minPowerShell = Get-MinimumPowerShellVersion -Content $launcherContent
    url = 'https://raw.githubusercontent.com/lavueltitaironica/SCR1PT/main/SCR1PT.ps1'
}

# D3PL0Y vive en su repositorio oficial independiente. Solo se lee.
$d3Category = Register-Category -Name 'DESPLIEGUE' -Order 10
$d3Content = Get-RemoteScriptContent -Url $d3pl0yRawUrl -Name 'D3PL0Y.ps1'

$d3Version = ''
$d3MinimumPowerShell = '5.1'
$d3RequiresAdmin = $true

if (-not [string]::IsNullOrWhiteSpace($d3Content)) {
    $d3Version = Get-ScriptVersion -Content $d3Content
    $d3MinimumPowerShell = Get-MinimumPowerShellVersion -Content $d3Content
    $d3RequiresAdmin = Get-RequiresAdmin -Content $d3Content
}
else {
    # Un fallo temporal de red no debe borrar datos validos del catalogo.
    $previousD3 = Get-ExistingScript -Id 'd3pl0y'

    if ($null -ne $previousD3) {
        if ($null -ne $previousD3.PSObject.Properties['version']) {
            $d3Version = [string]$previousD3.version
        }

        if ($null -ne $previousD3.PSObject.Properties['minPowerShell'] -and
            -not [string]::IsNullOrWhiteSpace([string]$previousD3.minPowerShell)) {
            $d3MinimumPowerShell = [string]$previousD3.minPowerShell
        }

        if ($null -ne $previousD3.PSObject.Properties['requiresAdmin']) {
            $d3RequiresAdmin = [bool]$previousD3.requiresAdmin
        }
    }
}

$scripts.Add([pscustomobject][ordered]@{
    id = 'd3pl0y'
    name = 'D3PL0Y'
    version = $d3Version
    description = 'Despliegue automatizado y modular para Windows 11.'
    category = $d3Category
    order = 0
    fileName = 'D3PL0Y.ps1'
    url = $d3pl0yRawUrl
    source = 'D3PL0Y'
    requiresAdmin = [bool]$d3RequiresAdmin
    minPowerShell = $d3MinimumPowerShell
})
$knownIds['d3pl0y'] = $true

$files = @(
    Get-ChildItem -LiteralPath $scriptsRoot -Filter '*.ps1' -File -Recurse |
        Sort-Object -Property FullName
)

foreach ($file in $files) {
    # Una copia local de D3PL0Y nunca compite con su fuente oficial.
    if ($file.Name -ieq 'D3PL0Y.ps1') {
        continue
    }

    $content = Get-Content -LiteralPath $file.FullName -Raw
    $hidden = Get-MetadataValue -Content $content -Name 'SCR1PT-Hidden'

    if ($hidden -match '^(?i:true|yes|1)$') {
        continue
    }

    $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    $displayName = Get-MetadataValue -Content $content -Name 'SCR1PT-Name'

    if ([string]::IsNullOrWhiteSpace($displayName)) {
        $displayName = $baseName
    }

    $categoryName = Get-MetadataValue -Content $content -Name 'SCR1PT-Category'

    if ([string]::IsNullOrWhiteSpace($categoryName)) {
        $categoryName = 'OTROS'
    }

    $categoryOrder = Get-IntegerMetadata `
        -Content $content `
        -Name 'SCR1PT-CategoryOrder' `
        -Default 900

    $scriptOrder = Get-IntegerMetadata `
        -Content $content `
        -Name 'SCR1PT-Order' `
        -Default 100

    $categoryId = Register-Category -Name $categoryName -Order $categoryOrder
    $id = ConvertTo-Slug -Text $baseName

    if ($knownIds.ContainsKey($id)) {
        throw ('Dos scripts generan el mismo identificador: {0}' -f $id)
    }

    $knownIds[$id] = $true

    $rootFull = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    $fileFull = [IO.Path]::GetFullPath($file.FullName)

    if (-not $fileFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw ('El archivo esta fuera del repositorio: {0}' -f $file.FullName)
    }

    $relativePath = $fileFull.Substring($rootFull.Length).TrimStart('\', '/')
    $rawPath = ConvertTo-RawPath -RelativePath $relativePath
    $rawUrl = 'https://raw.githubusercontent.com/{0}/{1}/{2}/{3}' -f `
        $repositoryOwner,
        $repositoryName,
        $repositoryBranch,
        $rawPath

    $scripts.Add([pscustomobject][ordered]@{
        id = $id
        name = $displayName.Trim()
        version = Get-ScriptVersion -Content $content
        description = Get-CatalogDescription -Content $content -DisplayName $displayName
        category = $categoryId
        order = $scriptOrder
        fileName = $file.Name
        url = $rawUrl
        source = 'SCR1PT'
        requiresAdmin = [bool](Get-RequiresAdmin -Content $content)
        minPowerShell = Get-MinimumPowerShellVersion -Content $content
    })
}

$categoryList = @(
    $categories.Values |
        Sort-Object `
            @{ Expression = { [int]$_.order } }, `
            @{ Expression = { [string]$_.name } }
)

$scriptList = @(
    $scripts |
        Sort-Object `
            @{ Expression = {
                $categoryId = [string]$_.category
                [int]$categories[$categoryId].order
            } }, `
            @{ Expression = {
                if ($_.id -ieq 'd3pl0y') { 0 } else { 1 }
            } }, `
            @{ Expression = { [int]$_.order } }, `
            @{ Expression = { [string]$_.name } }
)

$previousGeneratedAt = ''

if ($null -ne $existingCatalog -and
    $null -ne $existingCatalog.PSObject.Properties['generatedAt']) {
    $previousGeneratedAt = [string]$existingCatalog.generatedAt
}

$catalog = [pscustomobject][ordered]@{
    schemaVersion = 1
    generatedAt = $previousGeneratedAt
    launcher = $launcher
    categories = $categoryList
    scripts = $scriptList
}

$candidateJson = $catalog | ConvertTo-Json -Depth 8
$existingTrimmed = $existingCatalogRaw.Trim()
$candidateTrimmed = $candidateJson.Trim()

if (-not [string]::IsNullOrWhiteSpace($existingTrimmed) -and
    $candidateTrimmed -eq $existingTrimmed) {
    Write-Host ('Catalogo sin cambios: {0}' -f $catalogPath) -ForegroundColor Green
    Write-Host (
        'Launcher: {0} | Scripts: {1} | Categorias: {2}' -f
        $launcher.version,
        $scriptList.Count,
        $categoryList.Count
    )
    return
}

$catalog.generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$json = $catalog | ConvertTo-Json -Depth 8
$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($catalogPath, ($json + [Environment]::NewLine), $utf8NoBom)

Write-Host ('Catalogo generado: {0}' -f $catalogPath) -ForegroundColor Green
Write-Host (
    'Launcher: {0} | Scripts: {1} | Categorias: {2}' -f
    $launcher.version,
    $scriptList.Count,
    $categoryList.Count
)
