<div align="center">

# SCR1PT

### Lanzador centralizado de scripts PowerShell

![Versión](https://img.shields.io/badge/versión-1.1.2-00FF00?style=for-the-badge&labelColor=111111)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=for-the-badge&logo=windows11&logoColor=white)
![Scripts](https://img.shields.io/badge/catálogo-2-00FF00?style=for-the-badge&labelColor=111111)

**Un punto de entrada. Varios scripts. Una misma identidad.**

[Ejecución rápida](#ejecución-rápida) · [Catálogo](#catálogo-actual) · [Uso local](#uso-local) · [Seguridad](#seguridad)

</div>

---

## ¿Qué es SCR1PT?

**SCR1PT** es el lanzador maestro de scripts PowerShell de [La Vueltita Irónica](https://lavueltitaironica.com). Proporciona un catálogo centralizado desde el que se pueden consultar y ejecutar herramientas de despliegue, configuración y administración de Windows.

El lanzador puede utilizarse de forma interactiva o mediante parámetros. No necesita iniciarse como administrador: cuando una herramienta requiere privilegios elevados, gestiona su propia elevación.

## Ejecución rápida

Abre **PowerShell** y ejecuta:

```powershell
irm https://lavueltitaironica.com/scr1pt | iex
```

El comando descarga la versión publicada del lanzador y abre el menú principal.

## Catálogo actual

| ID | Script | Versión | Administrador | Finalidad |
| --- | --- | ---: | :---: | --- |
| `d3pl0y` | [D3PL0Y](https://github.com/LaVueltitaIronica/D3PL0Y) | 2.2.1 | Sí | Despliega y configura Windows 11 mediante los perfiles `P0RT4L`, `STUD10` y `C0NTR0L`. |
| `w0l` | W0L — Wake On LAN | 1.1.0 | Sí | Configura las opciones de energía, el adaptador de red y las comprobaciones necesarias para Wake On LAN. |

El catálogo está integrado en `SCR1PT.ps1`. Cada entrada define su identificador, versión, descripción, requisitos y ubicación de descarga.

## Formas de uso

### Menú interactivo

```powershell
.\SCR1PT.ps1
```

Muestra el catálogo y permite seleccionar una herramienta.

### Consultar el catálogo

```powershell
.\SCR1PT.ps1 -List
```

### Ejecutar directamente una herramienta

```powershell
.\SCR1PT.ps1 -Run w0l
```

Sustituye `w0l` por el ID correspondiente del catálogo.

## Uso local

Clona el repositorio y accede a su directorio:

```powershell
git clone https://github.com/LaVueltitaIronica/SCR1PT.git
Set-Location .\SCR1PT
.\SCR1PT.ps1
```

También puedes descargar el repositorio como ZIP desde GitHub y ejecutar `SCR1PT.ps1` desde la carpeta extraída.

## Estructura del repositorio

```text
SCR1PT/
├── SCR1PT.ps1
├── SCR1PT/
│   ├── D3PL0Y.ps1
│   └── W0L.ps1
└── README.md
```

- `SCR1PT.ps1`: lanzador maestro y catálogo.
- `SCR1PT/`: scripts disponibles para descarga y ejecución.
- `README.md`: documentación del proyecto.

## Requisitos

- Windows 10 u 11.
- Windows PowerShell 5.1 o superior.
- Conexión a Internet para la ejecución remota.
- Permisos de administrador para las herramientas que los indiquen.
- Windows 11 para utilizar D3PL0Y.

## Funcionamiento

1. `SCR1PT.ps1` carga el catálogo integrado.
2. El usuario consulta el listado o selecciona una herramienta.
3. El lanzador descarga el script correspondiente desde su ubicación oficial.
4. Se comprueban sus requisitos básicos.
5. El script seleccionado se ejecuta y solicita elevación cuando la necesita.

## Seguridad

> [!IMPORTANT]
> `irm ... | iex` descarga y ejecuta el contenido publicado en ese momento. Utiliza únicamente la URL oficial y revisa el código antes de ejecutarlo en equipos sensibles.

- Los scripts pueden realizar cambios de sistema y solicitar permisos de administrador.
- La ejecución remota depende de la disponibilidad de Internet, GitHub y `lavueltitaironica.com`.
- La versión actual del catálogo todavía no incorpora valores SHA-256 para verificar los archivos descargados.
- Es recomendable probar nuevas versiones en un equipo de pruebas antes de aplicarlas a otros sistemas.

## Proyectos relacionados

- [D3PL0Y](https://github.com/LaVueltitaIronica/D3PL0Y): despliegue automatizado y modular de Windows 11.
- [C3R3BR0](https://github.com/LaVueltitaIronica/C3R3BR0): automatización, domótica e infraestructura doméstica.

## Autoría

Desarrollado y mantenido por **[La Vueltita Irónica](https://lavueltitaironica.com)**.

