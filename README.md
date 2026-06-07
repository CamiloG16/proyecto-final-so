Integrantes:` 
`Juan Camilo García`
`Luciano Barbosa`
`Jose David Mayor
`Karen Andrea Mosquera"

# Herramienta de Administración de Data Center

Proyecto Final — **Sistemas Operacionales**
Universidad Icesi · Facultad de Ingeniería, Diseño y Ciencias Aplicadas

Este repositorio contiene **dos herramientas** que facilitan las labores del administrador de un data center, una desarrollada en **BASH** (Linux) y otra en **PowerShell** (Windows). Ambas despliegan un menú con las mismas cinco opciones requeridas en
el enunciado.

---

## Contenido del repositorio

| Archivo | Descripción |
|---|---|
| `datacenter.sh` | Herramienta para sistemas Linux (BASH). |
| `datacenter.ps1` | Herramienta para sistemas Windows (PowerShell). |
| `README.md` | Este documento. |

---

## Funcionalidades del menú

Cada herramienta presenta el mismo menú con estas opciones:

1. **Usuarios y último ingreso** — lista los usuarios creados en el sistema junto con la fecha y hora de su último login.
2. **Filesystems / discos** — muestra los discos o sistemas de archivos conectados, con su tamaño y espacio libre **en bytes**.
3. **10 archivos más grandes** — pide al usuario una ruta (disco o filesystem) y muestra el nombre, el tamaño y la **trayectoria completa** de los 10 archivos más grandes que contiene.
4. **Memoria y swap** — reporta la memoria libre y el espacio de swap en uso, **en bytes y en porcentaje**.
5. **Backup a USB** — copia un directorio indicado hacia una memoria USB y genera un **catálogo** con el nombre de cada archivo y su fecha de última modificación.

---

## Requisitos

### Linux (`datacenter.sh`)
- Bash 4 o superior.
- Utilidades estándar: `coreutils` (`df`, `find`, `sort`, `cp`, `awk`), y `util-linux` (`lastlog`).
- Se recomienda ejecutar con `sudo` para que la opción 1 muestre el último login de todos los usuarios.

### Windows (`datacenter.ps1`)
- Windows 10 / 11 o Windows Server 2016 o superior.
- PowerShell 5.1 o superior (incluido por defecto en Windows).
- Se recomienda ejecutar una terminal **como Administrador** para acceder a toda la información del sistema.

---

## Cómo ejecutar

### Linux

```bash
# Dar permisos de ejecución (solo la primera vez)
chmod +x datacenter.sh

# Ejecutar (sudo recomendado)
sudo ./datacenter.sh
```

### Windows

```powershell
# Desde PowerShell (preferiblemente como Administrador)
powershell -ExecutionPolicy Bypass -File .\datacenter.ps1
```

> Si PowerShell bloquea la ejecución de scripts, el parámetro `-ExecutionPolicy Bypass` permite correrlo sin cambiar la política global del equipo.

---

## Detalle técnico por opción

### 1. Usuarios y último ingreso
- **Linux:** se leen los usuarios desde `/etc/passwd` (se incluye `root` con UID 0 y los usuarios humanos con UID entre 1000 y 65533) y se consulta `lastlog` para obtener el último login.
- **Windows:** se usa `Get-LocalUser` con la propiedad `LastLogon`. Si el cmdlet no está disponible, se recurre a `Win32_UserAccount`.

### 2. Filesystems / discos (en bytes)
- **Linux:** `df -B1` expresa el tamaño y el espacio disponible directamente en bytes (bloque de 1 byte). Se omiten pseudo-filesystems (`tmpfs`, `devtmpfs`, etc.).
- **Windows:** `Win32_LogicalDisk` entrega `Size` y `FreeSpace` ya en bytes.

### 3. Los 10 archivos más grandes
- **Linux:** `find <ruta> -xdev -type f -printf '%s\t%p\n'` lista tamaño + ruta; se ordena con `sort -rn` y se toman los primeros 10. La opción `-xdev` evita cruzar a otros filesystems.
- **Windows:** `Get-ChildItem -Recurse -File` ordenado por `Length` de forma descendente, tomando los primeros 10 con `Select-Object -First 10`.

### 4. Memoria y swap (bytes y porcentaje)
- **Linux:** se leen `MemTotal`, `MemFree`, `SwapTotal` y `SwapFree` de `/proc/meminfo` (valores en kB → se multiplican por 1024). El swap en uso = `SwapTotal − SwapFree`.
- **Windows:** `Win32_OperatingSystem` aporta la memoria física (en KB) y `Win32_PageFileUsage` el archivo de paginación —equivalente al swap— en MB.

### 5. Backup a USB con catálogo
- Se solicita el directorio de origen y la ruta de destino en la USB (las herramientas detectan automáticamente posibles unidades extraíbles).
- Se crea una carpeta `backup_<nombre>_<fecha>` y se copian los archivos conservando estructura, permisos y fechas.
- Se genera `catalogo.txt` con el nombre de cada archivo y su fecha de última modificación.

---

## Notas
- Las opciones que recorren todo un disco (2, 3 y 5) pueden tardar según el tamaño del filesystem.
- Para resultados completos en la opción 1, ejecutar con privilegios de administrador / `sudo`.

---

*Proyecto académico — Universidad Icesi.*
