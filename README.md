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
