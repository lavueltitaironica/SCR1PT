#Requires -Version 5.1

<#
.SYNOPSIS
    Genera catalog.json para SCR1PT.

.DESCRIPTION
    Escanea recursivamente /SCR1PT, lee el .SYNOPSIS y los metadatos SCR1PT
    de cada archivo .ps1 y genera un catalogo compacto para el lanzador.

    Metadatos opcionales por script:

        # SCR1PT-Name: NOMBRE VISIBLE
        # SCR1PT-Category: RED Y ENERGIA
        # SCR1PT-CategoryOrder: 20
        # SCR1PT-Order: 10
        # SCR1PT-Hidden: false

    Si falta la categoria, el script se coloca en OTROS. La descripcion se toma
    siempre de .SYNOPSIS para evitar mantener el mismo texto en dos sitios.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repositoryOwner = 'lavueltitaironica'
$repositoryName = 'SCR1PT'
$repositoryBranch = 'main'
$scriptsRoot = Join-Path $RepositoryRoot 'SCR1PT'
$catalogPath = Join-Path $RepositoryRoot 'catalog.json'

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

    # El menu debe seguir siendo legible aunque alguien escriba una novela en SYNOPSIS.
    if ($synopsis.Length -gt 150) {
        $synopsis = $synopsis.Substring(0, 147).TrimEnd() + '...'
    }

    return $synopsis
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

function ConvertTo-RawPath {
    param([Parameter(Mandatory)][string]$RelativePath)

    $segments = @(
        ($RelativePath -replace '\\', '/') -split '/' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { [Uri]::EscapeDataString($_) }
    )

    return ($segments -join '/')
}

if (-not (Test-Path -LiteralPath $scriptsRoot)) {
    throw ('No existe la carpeta de scripts: {0}' -f $scriptsRoot)
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

        # Si varios scripts comparten categoria, se conserva el orden menor.
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

# D3PL0Y es una fuente externa oficial y siempre ocupa la primera posicion.
$d3Category = Register-Category -Name 'DESPLIEGUE' -Order 10
$scripts.Add([pscustomobject][ordered]@{
    id = 'd3pl0y'
    name = 'D3PL0Y'
    description = 'Despliegue automatizado y modular para Windows 11.'
    category = $d3Category
    order = 0
    fileName = 'D3PL0Y.ps1'
    url = 'https://raw.githubusercontent.com/lavueltitaironica/D3PL0Y/main/D3PL0Y.ps1'
    source = 'D3PL0Y'
})
$knownIds['d3pl0y'] = $true

$files = @(
    Get-ChildItem -LiteralPath $scriptsRoot -Filter '*.ps1' -File -Recurse |
        Sort-Object -Property FullName
)

foreach ($file in $files) {
    # Una copia antigua de D3PL0Y en /SCR1PT nunca debe competir con la fuente oficial.
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
        description = Get-Synopsis -Content $content
        category = $categoryId
        order = $scriptOrder
        fileName = $file.Name
        url = $rawUrl
        source = 'SCR1PT'
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

$catalog = [pscustomobject][ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    categories = $categoryList
    scripts = $scriptList
}

$json = $catalog | ConvertTo-Json -Depth 8
$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($catalogPath, ($json + [Environment]::NewLine), $utf8NoBom)

Write-Host ('Catalogo generado: {0}' -f $catalogPath) -ForegroundColor Green
Write-Host ('Scripts: {0} | Categorias: {1}' -f $scriptList.Count, $categoryList.Count)
