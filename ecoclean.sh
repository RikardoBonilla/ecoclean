#!/opt/homebrew/bin/bash
#
# ecoclean.sh - Script para eliminar archivos temporales y detectar/eliminar duplicados.
#
# Autor: Ricardo Andres Bonilla Prada
# Fecha: 2024-12-10
#
# Descripción:
# Sprint 1: Eliminar archivos temporales (.tmp, .log, .bak).
# Sprint 2: Detectar y eliminar duplicados basados en hash MD5.
# Sprint 3: Interfaz interactiva en terminal, con menú, confirmaciones y reporte previo.
# Sprint 4: Uso de archivo de configuración externo (ecoclean.conf) para personalizar extensiones y rutas.
# Sprint 5: Log detallado con fecha/hora y tamaño total liberado.
#
# Uso: ./ecoclean.sh [directorio_opcional]

set -e
set -u

# Intentar cargar la configuración
CONFIG_FILE="$(dirname "$0")/ecoclean.conf"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
else
  # Valores por defecto si no existe el archivo de configuración
  TEMP_EXTENSIONS="*.tmp *.log *.bak"
  CLEAN_DIRS="$(pwd)"
fi

# Se mantiene TARGET_DIR por compatibilidad, pero realmente usamos CLEAN_DIRS.
TARGET_DIR="${1:-$(pwd)}"

# Definir archivo de log
LOG_FILE="$(dirname "$0")/logs/ecoclean.log"
# Inicializar log (opcional, sólo la primera vez; si no quieres duplicar, omite si ya existe)
# echo "=== EcoClean Logging Start: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"

#------------------------------------------------------------
# Función: log_action
# Registra una acción en el archivo de log con fecha y hora.
#------------------------------------------------------------
log_action() {
  local MSG="$1"
  local TIMESTAMP
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$TIMESTAMP] $MSG" >> "$LOG_FILE"
}

#------------------------------------------------------------
# Función: get_temp_files
# Obtiene la lista de archivos temporales según las extensiones y directorios definidos.
#------------------------------------------------------------
get_temp_files() {
  local EXTENSIONS=($TEMP_EXTENSIONS)
  local DIRECTORIES=($CLEAN_DIRS)
  local FILES_FOUND=()

  for DIR in "${DIRECTORIES[@]}"; do
    for EXT in "${EXTENSIONS[@]}"; do
      while IFS= read -r -d '' FILE; do
        FILES_FOUND+=("$FILE")
      done < <(find "$DIR" -type f -iname "$EXT" -print0 2>/dev/null)
    done
  done

  for FILE in "${FILES_FOUND[@]}"; do
    echo "$FILE"
  done
}

#------------------------------------------------------------
# Función: remove_temp_files
# Elimina archivos temporales (pasados por stdin) y los cuenta, registrando en el log el tamaño liberado.
#------------------------------------------------------------
remove_temp_files() {
  local FILES=()
  local DELETED_COUNT=0
  local TOTAL_SIZE=0

  # Leer todos los archivos desde stdin
  while IFS= read -r FILE; do
    FILES+=("$FILE")
  done

  # Calcular tamaño total antes de eliminar
  for FILE in "${FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
      local SIZE
      SIZE=$(stat -f%z "$FILE")
      TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    fi
  done

  # Eliminar los archivos
  for FILE in "${FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
      echo "Eliminando: $FILE"
      rm -f "$FILE"
      ((DELETED_COUNT++))
    fi
  done

  echo "Total de archivos temporales eliminados: ${DELETED_COUNT}"

  # Registrar en el log
  if (( DELETED_COUNT > 0 )); then
    log_action "Eliminados $DELETED_COUNT archivos, liberados $TOTAL_SIZE bytes"
  else
    log_action "No se eliminaron archivos (0 bytes liberados)"
  fi
}

#------------------------------------------------------------
# Función: remove_duplicates
# Detecta duplicados por hash MD5 y elimina todos menos uno por grupo.
# Registra en el log el número de duplicados y el tamaño liberado.
#------------------------------------------------------------
remove_duplicates() {
  declare -A HASH_MAP
  local OS_NAME
  OS_NAME=$(uname)

  local FILES=()
  while IFS= read -r FILE; do
    FILES+=("$FILE")
  done

  # Calcular hash y agrupar archivos por hash
  for FILE in "${FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
      local HASH
      if [[ "$OS_NAME" == "Darwin" ]]; then
        # macOS
        HASH=$(md5 "$FILE" | awk '{print $4}')
      else
        # Linux u otros con md5sum
        HASH=$(md5sum "$FILE" | awk '{print $1}')
      fi
      HASH_MAP["$HASH"]="${HASH_MAP["$HASH"]-} $FILE"
    fi
  done

  local TOTAL_DUPLICATES=0
  local TOTAL_DUPLICATE_SIZE=0
  local UNIQUE_FILES=()

  for KEY in "${!HASH_MAP[@]}"; do
    read -ra FILE_LIST <<< "${HASH_MAP["$KEY"]}"
    if (( ${#FILE_LIST[@]} > 1 )); then
      UNIQUE_FILES+=("${FILE_LIST[0]}")
      for (( i=1; i<${#FILE_LIST[@]}; i++ )); do
        echo "Duplicado detectado. Eliminando: ${FILE_LIST[i]}"
        if [[ -f "${FILE_LIST[i]}" ]]; then
          local SIZE
          SIZE=$(stat -f%z "${FILE_LIST[i]}")
          TOTAL_DUPLICATE_SIZE=$((TOTAL_DUPLICATE_SIZE + SIZE))
        fi
        rm -f "${FILE_LIST[i]}"
        ((TOTAL_DUPLICATES++))
      done
    else
      UNIQUE_FILES+=("${FILE_LIST[0]}")
    fi
  done

  if (( TOTAL_DUPLICATES > 0 )); then
    echo "Total de duplicados eliminados: $TOTAL_DUPLICATES"
    log_action "Eliminados $TOTAL_DUPLICATES archivos duplicados, liberados $TOTAL_DUPLICATE_SIZE bytes"
  else
    echo "No se encontraron archivos duplicados."
    log_action "No se eliminaron duplicados (0 bytes liberados)"
  fi

  for UF in "${UNIQUE_FILES[@]}"; do
    echo "$UF"
  done
}

#------------------------------------------------------------
# Función: show_temp_files
# Muestra la lista de archivos temporales (si hay).
#------------------------------------------------------------
show_temp_files() {
  local TEMP_FILES
  TEMP_FILES=$(get_temp_files)
  if [[ -z "$TEMP_FILES" ]]; then
    echo "No se encontraron archivos temporales."
  else
    echo "Archivos temporales encontrados:"
    echo "$TEMP_FILES"
  fi
}

#------------------------------------------------------------
# Función: process_duplicates
# Ejecuta la detección y eliminación de duplicados, mostrando el resultado.
#------------------------------------------------------------
process_duplicates() {
  local TEMP_FILES
  TEMP_FILES=$(get_temp_files)
  if [[ -z "$TEMP_FILES" ]]; then
    echo "No se encontraron archivos temporales para procesar duplicados."
    return
  fi

  echo "Se analizarán los siguientes archivos para detectar duplicados:"
  echo "$TEMP_FILES"

  read -r -p "¿Desea continuar con la eliminación de duplicados? [s/N]: " CONFIRM
  if [[ "$CONFIRM" =~ ^[Ss]$ ]]; then
    local UNIQUE_FILES
    UNIQUE_FILES=$(printf "%s\n" "$TEMP_FILES" | remove_duplicates)
    echo "Archivos resultantes tras eliminar duplicados:"
    echo "$UNIQUE_FILES"
  else
    echo "Operación cancelada."
  fi
}

#------------------------------------------------------------
# Función: remove_all_temp_files_with_confirmation
# Muestra los archivos temporales, pide confirmación y luego los elimina.
#------------------------------------------------------------
remove_all_temp_files_with_confirmation() {
  local TEMP_FILES
  TEMP_FILES=$(get_temp_files)
  if [[ -z "$TEMP_FILES" ]]; then
    echo "No se encontraron archivos temporales."
    return
  fi

  echo "Se eliminarán los siguientes archivos temporales:"
  echo "$TEMP_FILES"
  read -r -p "¿Está seguro de que desea eliminarlos? [s/N]: " CONFIRM
  if [[ "$CONFIRM" =~ ^[Ss]$ ]]; then
    printf "%s\n" "$TEMP_FILES" | remove_temp_files
  else
    echo "Operación cancelada."
  fi
}

#------------------------------------------------------------
# Función: show_menu
# Presenta al usuario un menú interactivo con opciones.
#------------------------------------------------------------
show_menu() {
  PS3="Seleccione una opción: "
  local OPTS=("Mostrar archivos temporales"
              "Detectar y eliminar duplicados"
              "Eliminar todos los archivos temporales"
              "Salir")

  select OPT in "${OPTS[@]}"; do
    case $REPLY in
      1)
        show_temp_files
        ;;
      2)
        process_duplicates
        ;;
      3)
        remove_all_temp_files_with_confirmation
        ;;
      4)
        echo "Saliendo..."
        break
        ;;
      *)
        echo "Opción inválida. Intente nuevamente."
        ;;
    esac
  done
}

# Flujo Principal
show_menu
