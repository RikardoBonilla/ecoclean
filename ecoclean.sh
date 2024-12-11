#!/opt/homebrew/bin/bash
#
# ecoclean.sh - Script para eliminar archivos temporales y detectar/eliminar duplicados.
#
# Autor: Ricardo Andres Bonilla Prada
# Fecha: 2024-12-10
# Descripción:
# Sprint 1: Eliminar archivos temporales (.tmp, .log, .bak).
# Sprint 2: Detectar y eliminar duplicados basados en hash MD5.
# Sprint 3: Interfaz interactiva en terminal, con menú, confirmaciones y reporte previo.
# Sprint 4: Uso de archivo de configuración externo (ecoclean.conf) para personalizar extensiones y rutas.
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

# Se mantiene TARGET_DIR por compatibilidad, 
# pero ahora los archivos se buscarán en CLEAN_DIRS.
TARGET_DIR="${1:-$(pwd)}"

#------------------------------------------------------------
# Función: get_temp_files
# Obtiene la lista de archivos temporales según las extensiones y directorios definidos.
#------------------------------------------------------------
get_temp_files() {
  # Convertir las variables a arreglos
  local EXTENSIONS=($TEMP_EXTENSIONS)
  local DIRECTORIES=($CLEAN_DIRS)

  local FILES_FOUND=()

  # Buscar en cada directorio y para cada extensión
  for DIR in "${DIRECTORIES[@]}"; do
    for EXT in "${EXTENSIONS[@]}"; do
      while IFS= read -r -d '' FILE; do
        FILES_FOUND+=("$FILE")
      done < <(find "$DIR" -type f -iname "$EXT" -print0 2>/dev/null)
    done
  done

  # Imprimir la lista de archivos encontrados, uno por línea
  for FILE in "${FILES_FOUND[@]}"; do
    echo "$FILE"
  done
}

#------------------------------------------------------------
# Función: remove_temp_files
# Elimina archivos temporales (pasados por stdin) y los cuenta.
#------------------------------------------------------------
remove_temp_files() {
  local DELETED_COUNT=0
  while IFS= read -r FILE; do
    if [[ -f "$FILE" ]]; then
      echo "Eliminando: $FILE"
      rm -f "$FILE"
      ((DELETED_COUNT++))
    fi
  done
  echo "Total de archivos temporales eliminados: ${DELETED_COUNT}"
}

#------------------------------------------------------------
# Función: remove_duplicates
# Detecta duplicados por hash MD5 y elimina todos menos uno por grupo.
# Devuelve por stdout la lista de archivos que quedan tras la eliminación.
#------------------------------------------------------------
remove_duplicates() {
  declare -A HASH_MAP
  local OS_NAME
  OS_NAME=$(uname)

  local FILES=()
  while IFS= read -r FILE; do
    FILES+=("$FILE")
  done

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

      # Evitar variable no inicializada usando "${...-}"
      HASH_MAP["$HASH"]="${HASH_MAP["$HASH"]-} $FILE"
    fi
  done

  local TOTAL_DUPLICATES=0
  local UNIQUE_FILES=()

  for KEY in "${!HASH_MAP[@]}"; do
    read -ra FILE_LIST <<< "${HASH_MAP["$KEY"]}"
    if (( ${#FILE_LIST[@]} > 1 )); then
      # Conservar el primero, eliminar los demás
      UNIQUE_FILES+=("${FILE_LIST[0]}")
      for (( i=1; i<${#FILE_LIST[@]}; i++ )); do
        echo "Duplicado detectado. Eliminando: ${FILE_LIST[i]}"
        rm -f "${FILE_LIST[i]}"
        ((TOTAL_DUPLICATES++))
      done
    else
      UNIQUE_FILES+=("${FILE_LIST[0]}")
    fi
  done

  if (( TOTAL_DUPLICATES > 0 )); then
    echo "Total de duplicados eliminados: $TOTAL_DUPLICATES"
  else
    echo "No se encontraron archivos duplicados."
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
    # Usar printf para asegurar que cada archivo se procese en una línea separada
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
    # Aquí también usamos printf para asegurar la correcta lectura línea a línea
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
