<div align="center">

# SCR1PT

### Lanzador centralizado de scripts PowerShell

<!-- SCR1PT:DYNAMIC:BADGES:START -->
![Version](https://img.shields.io/badge/version-1.4.1-00FF00?style=for-the-badge&labelColor=111111)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=for-the-badge&logo=windows11&logoColor=white)
![Scripts](https://img.shields.io/badge/catalogo-3-00FF00?style=for-the-badge&labelColor=111111)
<!-- SCR1PT:DYNAMIC:BADGES:END -->

**Un punto de entrada. Varios scripts. Una misma identidad.**

[Ejecución rápida](#ejecución-rápida) · [Catálogo](#catálogo-actual) · [Uso local](#uso-local) · [Seguridad](#seguridad)

</div>

---

## ¿Qué es SCR1PT?

**SCR1PT** es el lanzador maestro de scripts PowerShell de [La Vueltita Irónica](https://lavueltitaironica.com). Proporciona un catálogo centralizado desde el que se pueden consultar y ejecutar herramientas de despliegue, configuración y administración de Windows.

El lanzador puede utilizarse de forma interactiva o mediante parámetros. Cada herramienta mantiene su propia lógica y sus propios requisitos, mientras `catalog.json` actúa como fuente común para el lanzador, la documentación y las integraciones externas.

## Ejecución rápida

Abre **PowerShell** y ejecuta:

```powershell
irm https://lavueltitaironica.com/scr1pt | iex
```

El comando descarga la versión publicada del lanzador y abre el menú principal.

## Catálogo actual

<!-- SCR1PT:DYNAMIC:CATALOG:START -->
| ID | Script | Version | Categoria | Administrador | PowerShell | Finalidad |
| --- | --- | ---: | --- | :---: | :---: | --- |
| `d3pl0y` | [D3PL0Y](https://github.com/lavueltitaironica/D3PL0Y/blob/main/D3PL0Y.ps1) | 2.2.0 | DESPLIEGUE | Si | 5.1+ | Despliegue automatizado y modular para Windows 11. |
| `w0l` | [W0L](https://github.com/lavueltitaironica/SCR1PT/blob/main/SCR1PT/W0L.ps1) | 1.4.0 | RED Y ENERGIA | Si | 5.1+ | Configura Wake-on-LAN (WOL) en un adaptador de red fisico. |
| `p0w3r` | [P0W3R](https://github.com/lavueltitaironica/SCR1PT/blob/main/SCR1PT/P0W3R.ps1) | 1.0.0 | SISTEMA Y ENERGIA | Si | 5.1+ | Configura las opciones esenciales de energia de Windows. |
<!-- SCR1PT:DYNAMIC:CATALOG:END -->

El catálogo se genera automáticamente a partir de los scripts publicados. Nombre, versión, categoría, requisitos y descripción se obtienen del propio código siempre que es posible. **D3PL0Y** se consulta desde su repositorio oficial independiente y no se duplica dentro de `SCR1PT/`.

## Cómo se mantiene el catálogo

Los scripts alojados en `SCR1PT/` pueden declarar metadatos ligeros como categoría, orden o versión. `tools/Build-Catalog.ps1` completa el resto leyendo `.SYNOPSIS`, `#Requires` y las variables de versión del propio script.

Cuando cambia un script, el lanzador maestro o alguno de los generadores, GitHub Actions vuelve a crear `catalog.json` y actualiza únicamente los bloques dinámicos de este README. Así se evita mantener a mano la misma información en varios sitios, una costumbre sorprendentemente popular para algo tan fácil de olvidar.

## Formas de uso

### Menú interactivo

```powershell
.\SCR1PT.ps1
```

Muestra el catálogo actual y permite seleccionar una herramienta.

### Consultar el catálogo

```powershell
.\SCR1PT.ps1 -List
```

### Ejecutar directamente una herramienta

```powershell
.\SCR1PT.ps1 -Run w0l
```

Sustituye `w0l` por el ID correspondiente del catálogo.

También puedes ejecutar una herramienta concreta mediante su ruta pública:

```powershell
irm https://lavueltitaironica.com/scr1pt/w0l | iex
```

## Uso local

Clona el repositorio y accede a su directorio:

```powershell
git clone https://github.com/LaVueltitaIronica/SCR1PT.git
Set-Location .\SCR1PT
.\SCR1PT.ps1
```

También puedes descargar el repositorio como ZIP y ejecutar `SCR1PT.ps1` desde la carpeta extraída.

## Estructura del repositorio

<!-- SCR1PT:DYNAMIC:STRUCTURE:START -->
```text
SCR1PT/
|-- SCR1PT.ps1
|-- catalog.json
|-- SCR1PT/
    |-- P0W3R.ps1
    `-- W0L.ps1
|-- tools/
|   |-- Build-Catalog.ps1
|   `-- Build-README.ps1
|-- .github/workflows/build-catalog.yml
`-- README.md
```
<!-- SCR1PT:DYNAMIC:STRUCTURE:END -->

- `SCR1PT.ps1`: lanzador maestro.
- `catalog.json`: fuente estructurada consumida por SCR1PT, este README y las interfaces públicas del proyecto.
- `SCR1PT/`: herramientas PowerShell mantenidas dentro de este repositorio.
- `tools/Build-Catalog.ps1`: genera el catálogo a partir del código.
- `tools/Build-README.ps1`: actualiza únicamente las zonas dinámicas de este README.
- `.github/workflows/build-catalog.yml`: automatiza ambos generadores.

## Requisitos

- Windows 10 u 11 para las herramientas de sistema de SCR1PT.
- Windows PowerShell 5.1 o superior como base del lanzador.
- Conexión a Internet para la ejecución remota.
- Permisos de administrador únicamente cuando la herramienta seleccionada los necesite.
- Los requisitos específicos de cada script aparecen en el catálogo.

## Funcionamiento

1. `SCR1PT.ps1` descarga `catalog.json`.
2. El lanzador valida y ordena categorías y scripts.
3. El usuario consulta el listado o selecciona una herramienta.
4. SCR1PT descarga el `.ps1` correspondiente desde su fuente oficial.
5. Se comprueban los requisitos del propio script.
6. La herramienta se ejecuta y gestiona la elevación cuando procede.

## Integración web

El catálogo de SCR1PT actúa como fuente común para el lanzador, la documentación y la página pública del proyecto.

Esto permite que las nuevas herramientas se incorporen al ecosistema sin mantener listados independientes en cada plataforma y sin duplicar manualmente la misma información.

## Seguridad

> [!IMPORTANT]
> `irm ... | iex` descarga y ejecuta el contenido publicado en ese momento. Utiliza únicamente las rutas oficiales y revisa el código antes de ejecutarlo en equipos sensibles.

- Los scripts pueden realizar cambios de sistema y solicitar permisos de administrador.
- La ejecución remota depende de la disponibilidad de Internet, GitHub y `lavueltitaironica.com`.
- Los metadatos del catálogo describen requisitos, pero el lanzador vuelve a comprobar el archivo descargado antes de ejecutarlo.
- Es recomendable probar nuevas versiones en un equipo de pruebas antes de aplicarlas de forma general.

## Proyectos relacionados

- [D3PL0Y](https://github.com/LaVueltitaIronica/D3PL0Y): despliegue automatizado y modular de Windows 11.
- [C3R3BR0](https://github.com/LaVueltitaIronica/C3R3BR0): automatización, domótica e infraestructura doméstica.

## Autoría

Desarrollado y mantenido por **[La Vueltita Irónica](https://lavueltitaironica.com)**.
