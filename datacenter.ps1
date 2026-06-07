<#
================================================================================
  PROYECTO FINAL - SISTEMAS OPERACIONALES (Universidad Icesi)
  Herramienta de administracion de Data Center  -  Version POWERSHELL (Windows)

  Despliega un menu con 5 opciones utiles para el administrador:
    1. Usuarios del sistema y su ultimo ingreso (login).
    2. Filesystems/discos conectados con tamanio y espacio libre (en bytes).
    3. Los 10 archivos mas grandes de un disco/filesystem indicado (ruta completa).
    4. Memoria libre y swap (archivo de paginacion) en uso (bytes y porcentaje).
    5. Backup de un directorio a una USB + catalogo de archivos y fechas.

  Uso (recomendado, como Administrador):
     powershell -ExecutionPolicy Bypass -File .\datacenter.ps1
================================================================================
#>

# ---- Funcion auxiliar: formatea un numero con separadores de miles -----------
function Format-Numero { param([double]$n) return ('{0:N0}' -f $n) }

function Pausa {
    Write-Host ""
    Read-Host "Presione ENTER para volver al menu" | Out-Null
}

#-------------------------------------------------------------------------------
# OPCION 1: Usuarios del sistema y su ultimo ingreso
#-------------------------------------------------------------------------------
function Opcion-Usuarios {
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host " 1) USUARIOS DEL SISTEMA Y SU ULTIMO INGRESO (LOGIN)"             -ForegroundColor White
    Write-Host "===================================================================" -ForegroundColor Cyan

    try {
        # Get-LocalUser: disponible en Windows 10/11 y Server 2016+
        $usuarios = Get-LocalUser | ForEach-Object {
            [PSCustomObject]@{
                Usuario       = $_.Name
                Habilitado    = $_.Enabled
                UltimoIngreso = if ($_.LastLogon) { $_.LastLogon } else { "Nunca" }
            }
        }
    }
    catch {
        # Respaldo para sistemas sin el modulo LocalAccounts
        Write-Host "(Get-LocalUser no disponible; usando Win32_UserAccount)" -ForegroundColor Yellow
        $usuarios = Get-CimInstance Win32_UserAccount -Filter "LocalAccount=True" |
            ForEach-Object {
                [PSCustomObject]@{
                    Usuario       = $_.Name
                    Habilitado    = (-not $_.Disabled)
                    UltimoIngreso = "No disponible"
                }
            }
    }

    $usuarios | Format-Table -AutoSize
    Pausa
}

#-------------------------------------------------------------------------------
# OPCION 2: Filesystems / discos conectados (tamanio y libre en bytes)
#-------------------------------------------------------------------------------
function Opcion-Discos {
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host " 2) FILESYSTEMS / DISCOS CONECTADOS"                              -ForegroundColor White
    Write-Host "===================================================================" -ForegroundColor Cyan

    # Win32_LogicalDisk entrega Size y FreeSpace ya en BYTES
    Get-CimInstance Win32_LogicalDisk | ForEach-Object {
        [PSCustomObject]@{
            Disco            = $_.DeviceID
            Sistema          = $_.FileSystem
            'Tamanio(bytes)' = if ($_.Size)      { Format-Numero $_.Size }      else { 0 }
            'Libre(bytes)'   = if ($_.FreeSpace) { Format-Numero $_.FreeSpace } else { 0 }
        }
    } | Format-Table -AutoSize
    Pausa
}

#-------------------------------------------------------------------------------
# OPCION 3: Los 10 archivos mas grandes de un disco/filesystem indicado
#-------------------------------------------------------------------------------
function Opcion-Grandes {
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host " 3) LOS 10 ARCHIVOS MAS GRANDES"                                  -ForegroundColor White
    Write-Host "===================================================================" -ForegroundColor Cyan

    $ruta = Read-Host "Ingrese la ruta del disco o filesystem (ej. C:\ o C:\Users)"
    if (-not (Test-Path $ruta)) {
        Write-Host "La ruta '$ruta' no existe." -ForegroundColor Red
        Pausa; return
    }

    Write-Host "Buscando en '$ruta' (esto puede tardar)..." -ForegroundColor Yellow

    Get-ChildItem -Path $ruta -Recurse -File -Force -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            [PSCustomObject]@{
                'Tamanio(bytes)'      = Format-Numero $_.Length
                'Trayectoria completa'= $_.FullName
            }
        } | Format-Table -AutoSize
    Pausa
}

#-------------------------------------------------------------------------------
# OPCION 4: Memoria libre y swap (archivo de paginacion) en uso
#-------------------------------------------------------------------------------
function Opcion-Memoria {
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host " 4) MEMORIA LIBRE Y SWAP EN USO"                                  -ForegroundColor White
    Write-Host "===================================================================" -ForegroundColor Cyan

    $os = Get-CimInstance Win32_OperatingSystem
    # Los valores vienen en KB -> se convierten a bytes (*1024)
    $memTotalB = [int64]$os.TotalVisibleMemorySize * 1024
    $memFreeB  = [int64]$os.FreePhysicalMemory    * 1024
    $memPct    = if ($memTotalB -gt 0) { [math]::Round(($memFreeB / $memTotalB) * 100, 1) } else { 0 }

    Write-Host "MEMORIA RAM" -ForegroundColor White
    Write-Host ("  Memoria libre : {0} bytes  ({1}%)" -f (Format-Numero $memFreeB), $memPct)
    Write-Host ("  Memoria total : {0} bytes"          -f (Format-Numero $memTotalB))
    Write-Host ""

    # En Windows el equivalente a "swap" es el archivo de paginacion (page file)
    $pf = Get-CimInstance Win32_PageFileUsage
    Write-Host "SWAP (Archivo de paginacion)" -ForegroundColor White
    if (-not $pf) {
        Write-Host "  El sistema no tiene archivo de paginacion configurado."
    }
    else {
        # AllocatedBaseSize y CurrentUsage vienen en MB -> a bytes (*1MB)
        $swapTotalB = ($pf | Measure-Object -Property AllocatedBaseSize -Sum).Sum * 1MB
        $swapUsedB  = ($pf | Measure-Object -Property CurrentUsage      -Sum).Sum * 1MB
        $swapPct    = if ($swapTotalB -gt 0) { [math]::Round(($swapUsedB / $swapTotalB) * 100, 1) } else { 0 }
        Write-Host ("  Swap en uso   : {0} bytes  ({1}%)" -f (Format-Numero $swapUsedB), $swapPct)
        Write-Host ("  Swap total    : {0} bytes"          -f (Format-Numero $swapTotalB))
    }
    Pausa
}

#-------------------------------------------------------------------------------
# OPCION 5: Backup de un directorio a una USB + catalogo
#-------------------------------------------------------------------------------
function Opcion-Backup {
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host " 5) BACKUP DE UN DIRECTORIO A UNA MEMORIA USB"                    -ForegroundColor White
    Write-Host "===================================================================" -ForegroundColor Cyan

    $origen = Read-Host "Directorio que desea respaldar (ej. C:\Users\Jose\Documentos)"
    if (-not (Test-Path $origen -PathType Container)) {
        Write-Host "El directorio de origen no existe." -ForegroundColor Red
        Pausa; return
    }

    # Deteccion de unidades extraibles (DriveType = 2 -> Removable / USB)
    Write-Host ""
    Write-Host "Unidades USB / extraibles detectadas:" -ForegroundColor Yellow
    $usb = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=2"
    if ($usb) {
        $usb | ForEach-Object { Write-Host ("   - {0}  ({1} libre)" -f $_.DeviceID, (Format-Numero $_.FreeSpace)) }
    } else {
        Write-Host "   (no se detectaron unidades extraibles; ingrese la ruta manualmente)"
    }
    Write-Host ""

    $destino = Read-Host "Ruta de destino en la USB (ej. E:\)"
    if (-not (Test-Path $destino -PathType Container)) {
        Write-Host "La ruta de destino no existe o la USB no esta conectada." -ForegroundColor Red
        Pausa; return
    }

    $fecha       = Get-Date -Format "yyyyMMdd_HHmmss"
    $nombreBase  = Split-Path $origen -Leaf
    $destDir     = Join-Path $destino ("backup_{0}_{1}" -f $nombreBase, $fecha)

    Write-Host "Copiando archivos a: $destDir" -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Copy-Item -Path (Join-Path $origen '*') -Destination $destDir -Recurse -Force -ErrorAction Stop
        Write-Host "Copia de archivos completada." -ForegroundColor Green
    }
    catch {
        Write-Host "Ocurrio un error durante la copia: $($_.Exception.Message)" -ForegroundColor Red
        Pausa; return
    }

    # ---- Generacion del catalogo ----
    $catalogo = Join-Path $destDir "catalogo.txt"
    $encabezado = @(
        "==================================================================="
        " CATALOGO DE RESPALDO"
        " Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        " Origen  : $origen"
        " Destino : $destDir"
        "==================================================================="
        ""
        ("{0,-55} {1}" -f "ARCHIVO", "ULTIMA MODIFICACION")
        "-------------------------------------------------------------------------"
    )
    $encabezado | Out-File -FilePath $catalogo -Encoding UTF8

    Get-ChildItem -Path $origen -Recurse -File |
        Sort-Object FullName |
        ForEach-Object {
            "{0,-55} {1}" -f $_.FullName, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        } | Out-File -FilePath $catalogo -Encoding UTF8 -Append

    $total = (Get-ChildItem -Path $origen -Recurse -File | Measure-Object).Count
    Write-Host "Catalogo creado: $catalogo" -ForegroundColor Green
    Write-Host "Backup finalizado. Se respaldaron $total archivos." -ForegroundColor Green
    Pausa
}

#-------------------------------------------------------------------------------
# MENU PRINCIPAL
#-------------------------------------------------------------------------------
function Menu-Principal {
    while ($true) {
        Clear-Host
        Write-Host "===================================================================" -ForegroundColor Cyan
        Write-Host "   HERRAMIENTA DE ADMINISTRACION DE DATA CENTER  (PowerShell)"       -ForegroundColor White
        Write-Host "===================================================================" -ForegroundColor Cyan
        Write-Host "   1) Usuarios del sistema y su ultimo ingreso"
        Write-Host "   2) Filesystems / discos conectados (tamanio y libre en bytes)"
        Write-Host "   3) Los 10 archivos mas grandes de un filesystem"
        Write-Host "   4) Memoria libre y swap en uso (bytes y porcentaje)"
        Write-Host "   5) Backup de un directorio a una USB (con catalogo)"
        Write-Host "   0) Salir"
        Write-Host "===================================================================" -ForegroundColor Cyan
        $opcion = Read-Host "Seleccione una opcion [0-5]"

        switch ($opcion) {
            '1' { Opcion-Usuarios }
            '2' { Opcion-Discos }
            '3' { Opcion-Grandes }
            '4' { Opcion-Memoria }
            '5' { Opcion-Backup }
            '0' { Write-Host "Saliendo..."; return }
            default { Write-Host "Opcion invalida. Intente de nuevo." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

# ---- Punto de entrada --------------------------------------------------------
Menu-Principal
