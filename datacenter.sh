#!/usr/bin/env bash
#===============================================================================
#  PROYECTO FINAL - SISTEMAS OPERACIONALES (Universidad Icesi)
#  Herramienta de administracion de Data Center  -  Version BASH (Linux)
#
#  Despliega un menu con 5 opciones utiles para el administrador:
#    1. Usuarios del sistema y su ultimo ingreso (login).
#    2. Filesystems/discos conectados con tamanio y espacio libre (en bytes).
#    3. Los 10 archivos mas grandes de un filesystem indicado (ruta completa).
#    4. Memoria libre y swap en uso (en bytes y porcentaje).
#    5. Backup de un directorio a una USB + catalogo de archivos y fechas.
#
#  Uso:   sudo ./datacenter.sh     (sudo recomendado para ver todos los datos)
#===============================================================================

# ---- Colores (solo estetica; se desactivan si la salida no es una terminal) --
if [ -t 1 ]; then
    AZUL='\033[1;34m'; VERDE='\033[1;32m'; AMAR='\033[1;33m'
    ROJO='\033[1;31m'; NEGRITA='\033[1m'; RESET='\033[0m'
else
    AZUL=''; VERDE=''; AMAR=''; ROJO=''; NEGRITA=''; RESET=''
fi

# ---- Funcion auxiliar: convierte kB (de /proc/meminfo) a bytes ---------------
kb_a_bytes() { echo $(( $1 * 1024 )); }

# ---- Funcion auxiliar: agrega separadores de miles a un numero ---------------
formatear_numero() { printf "%'d" "$1" 2>/dev/null || echo "$1"; }

pausa() {
    echo ""
    read -rp "Presione ENTER para volver al menu..." _
}

#-------------------------------------------------------------------------------
# OPCION 1: Usuarios del sistema y su ultimo ingreso
#-------------------------------------------------------------------------------
opcion_usuarios() {
    echo -e "${AZUL}====================================================================${RESET}"
    echo -e "${NEGRITA} 1) USUARIOS DEL SISTEMA Y SU ULTIMO INGRESO (LOGIN)${RESET}"
    echo -e "${AZUL}====================================================================${RESET}"

    # Se consideran "usuarios creados" root (UID 0) y los usuarios humanos
    # (UID >= 1000 y < 65534, excluyendo el usuario 'nobody').
    usuarios=$(awk -F: '($3==0) || ($3>=1000 && $3<65534) {print $1}' /etc/passwd)

    # Encabezado tomado de la salida de lastlog
    lastlog | head -n 1

    for u in $usuarios; do
        # 'lastlog -u' imprime el encabezado + la linea del usuario; tomamos la ultima
        lastlog -u "$u" 2>/dev/null | tail -n 1
    done
    pausa
}

#-------------------------------------------------------------------------------
# OPCION 2: Filesystems / discos conectados (tamanio y libre en bytes)
#-------------------------------------------------------------------------------
opcion_discos() {
    echo -e "${AZUL}====================================================================${RESET}"
    echo -e "${NEGRITA} 2) FILESYSTEMS / DISCOS CONECTADOS${RESET}"
    echo -e "${AZUL}====================================================================${RESET}"

    printf "${NEGRITA}%-22s %-8s %18s %18s  %s${RESET}\n" \
        "DISPOSITIVO" "TIPO" "TAMANIO(bytes)" "LIBRE(bytes)" "MONTADO EN"
    echo "--------------------------------------------------------------------------------------"

    # df -B1  => tamanios expresados en bytes (bloque de 1 byte).
    # Se excluyen los pseudo-filesystems para mostrar discos/volumenes reales.
    df -B1 --output=source,fstype,size,avail,target \
        -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null \
    | tail -n +2 \
    | while read -r src fstype size avail target; do
        printf "%-22s %-8s %18s %18s  %s\n" "$src" "$fstype" "$size" "$avail" "$target"
    done
    pausa
}

#-------------------------------------------------------------------------------
# OPCION 3: Los 10 archivos mas grandes de un filesystem indicado
#-------------------------------------------------------------------------------
opcion_grandes() {
    echo -e "${AZUL}====================================================================${RESET}"
    echo -e "${NEGRITA} 3) LOS 10 ARCHIVOS MAS GRANDES${RESET}"
    echo -e "${AZUL}====================================================================${RESET}"

    read -erp "Ingrese la ruta del disco o filesystem (ej. / o /home): " ruta
    ruta=${ruta:-/}

    if [ ! -d "$ruta" ]; then
        echo -e "${ROJO}La ruta '$ruta' no existe o no es un directorio.${RESET}"
        pausa; return
    fi

    echo ""
    echo -e "${AMAR}Buscando en '$ruta' (esto puede tardar)...${RESET}"
    echo ""
    printf "${NEGRITA}%18s   %s${RESET}\n" "TAMANIO(bytes)" "TRAYECTORIA COMPLETA"
    echo "------------------------------------------------------------------------"

    # -xdev: no cruza a otros filesystems (se queda en el disco indicado).
    # %s = tamanio en bytes, %p = ruta completa.
    find "$ruta" -xdev -type f -printf '%s\t%p\n' 2>/dev/null \
        | sort -rn \
        | head -n 10 \
        | while IFS=$'\t' read -r tam archivo; do
            printf "%18s   %s\n" "$tam" "$archivo"
          done
    pausa
}

#-------------------------------------------------------------------------------
# OPCION 4: Memoria libre y swap en uso (bytes y porcentaje)
#-------------------------------------------------------------------------------
opcion_memoria() {
    echo -e "${AZUL}====================================================================${RESET}"
    echo -e "${NEGRITA} 4) MEMORIA LIBRE Y SWAP EN USO${RESET}"
    echo -e "${AZUL}====================================================================${RESET}"

    mem_total_kb=$(awk '/^MemTotal:/  {print $2}' /proc/meminfo)
    mem_free_kb=$(awk  '/^MemFree:/   {print $2}' /proc/meminfo)
    swap_total_kb=$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)
    swap_free_kb=$(awk  '/^SwapFree:/ {print $2}' /proc/meminfo)

    mem_total_b=$(kb_a_bytes "$mem_total_kb")
    mem_free_b=$(kb_a_bytes "$mem_free_kb")
    swap_total_b=$(kb_a_bytes "$swap_total_kb")
    swap_free_kb=${swap_free_kb:-0}
    swap_used_kb=$(( swap_total_kb - swap_free_kb ))
    swap_used_b=$(kb_a_bytes "$swap_used_kb")

    # Porcentajes con un decimal (awk para flotantes)
    mem_pct=$(awk -v f="$mem_free_kb" -v t="$mem_total_kb" \
              'BEGIN{ if(t>0) printf "%.1f", (f/t)*100; else print "0.0" }')
    swap_pct=$(awk -v u="$swap_used_kb" -v t="$swap_total_kb" \
              'BEGIN{ if(t>0) printf "%.1f", (u/t)*100; else print "0.0" }')

    echo -e "${NEGRITA}MEMORIA RAM${RESET}"
    printf "  Memoria libre : %s bytes  (%s%%)\n" "$(formatear_numero "$mem_free_b")" "$mem_pct"
    printf "  Memoria total : %s bytes\n" "$(formatear_numero "$mem_total_b")"
    echo ""
    echo -e "${NEGRITA}SWAP${RESET}"
    if [ "$swap_total_kb" -eq 0 ]; then
        echo "  El sistema no tiene swap configurada."
    else
        printf "  Swap en uso   : %s bytes  (%s%%)\n" "$(formatear_numero "$swap_used_b")" "$swap_pct"
        printf "  Swap total    : %s bytes\n" "$(formatear_numero "$swap_total_b")"
    fi
    pausa
}

#-------------------------------------------------------------------------------
# OPCION 5: Backup de un directorio a una USB + catalogo
#-------------------------------------------------------------------------------
opcion_backup() {
    echo -e "${AZUL}====================================================================${RESET}"
    echo -e "${NEGRITA} 5) BACKUP DE UN DIRECTORIO A UNA MEMORIA USB${RESET}"
    echo -e "${AZUL}====================================================================${RESET}"

    read -erp "Directorio que desea respaldar (ej. /home/usuario/docs): " origen
    if [ ! -d "$origen" ]; then
        echo -e "${ROJO}El directorio de origen no existe.${RESET}"
        pausa; return
    fi

    # Deteccion de posibles memorias USB montadas
    echo ""
    echo -e "${AMAR}Posibles destinos USB detectados:${RESET}"
    detectados=$(find /media /run/media /mnt -maxdepth 2 -mindepth 1 -type d 2>/dev/null)
    if [ -n "$detectados" ]; then
        echo "$detectados" | sed 's/^/   - /'
    else
        echo "   (no se detectaron montajes automaticos; ingrese la ruta manualmente)"
    fi
    echo ""

    read -erp "Ruta de destino en la USB (ej. /media/usuario/USB): " destino
    if [ ! -d "$destino" ]; then
        echo -e "${ROJO}La ruta de destino no existe o la USB no esta montada.${RESET}"
        pausa; return
    fi
    if [ ! -w "$destino" ]; then
        echo -e "${ROJO}No tiene permisos de escritura en '$destino'.${RESET}"
        pausa; return
    fi

    fecha=$(date +%Y%m%d_%H%M%S)
    nombre_base=$(basename "$origen")
    dest_dir="$destino/backup_${nombre_base}_${fecha}"

    echo ""
    echo -e "${AMAR}Copiando archivos a: $dest_dir${RESET}"
    mkdir -p "$dest_dir"

    # -a : conserva permisos, fechas y enlaces. Copiamos el contenido del origen.
    if cp -a "$origen/." "$dest_dir/" 2>/dev/null; then
        echo -e "${VERDE}Copia de archivos completada.${RESET}"
    else
        echo -e "${ROJO}Ocurrio un error durante la copia.${RESET}"
        pausa; return
    fi

    # ---- Generacion del catalogo ----
    catalogo="$dest_dir/catalogo.txt"
    {
        echo "==================================================================="
        echo " CATALOGO DE RESPALDO"
        echo " Generado: $(date '+%Y-%m-%d %H:%M:%S')"
        echo " Origen  : $origen"
        echo " Destino : $dest_dir"
        echo "==================================================================="
        echo ""
        printf "%-55s %s\n" "ARCHIVO" "ULTIMA MODIFICACION"
        echo "-------------------------------------------------------------------------"
        find "$origen" -type f -printf '%p\t%TY-%Tm-%Td %TH:%TM:%.2TS\n' 2>/dev/null \
            | sort \
            | while IFS=$'\t' read -r archivo modif; do
                printf "%-55s %s\n" "$archivo" "$modif"
              done
    } > "$catalogo"

    total=$(find "$origen" -type f | wc -l)
    echo -e "${VERDE}Catalogo creado: $catalogo${RESET}"
    echo -e "${VERDE}Backup finalizado. Se respaldaron $total archivos.${RESET}"
    pausa
}

#-------------------------------------------------------------------------------
# MENU PRINCIPAL
#-------------------------------------------------------------------------------
menu_principal() {
    while true; do
        clear 2>/dev/null
        echo -e "${AZUL}===================================================================${RESET}"
        echo -e "${NEGRITA}   HERRAMIENTA DE ADMINISTRACION DE DATA CENTER  (BASH / Linux)${RESET}"
        echo -e "${AZUL}===================================================================${RESET}"
        echo "   1) Usuarios del sistema y su ultimo ingreso"
        echo "   2) Filesystems / discos conectados (tamanio y libre en bytes)"
        echo "   3) Los 10 archivos mas grandes de un filesystem"
        echo "   4) Memoria libre y swap en uso (bytes y porcentaje)"
        echo "   5) Backup de un directorio a una USB (con catalogo)"
        echo "   0) Salir"
        echo -e "${AZUL}===================================================================${RESET}"
        read -rp "Seleccione una opcion [0-5]: " opcion

        case "$opcion" in
            1) opcion_usuarios ;;
            2) opcion_discos ;;
            3) opcion_grandes ;;
            4) opcion_memoria ;;
            5) opcion_backup ;;
            0) echo "Saliendo..."; exit 0 ;;
            *) echo -e "${ROJO}Opcion invalida. Intente de nuevo.${RESET}"; sleep 1 ;;
        esac
    done
}

# ---- Punto de entrada --------------------------------------------------------
menu_principal
