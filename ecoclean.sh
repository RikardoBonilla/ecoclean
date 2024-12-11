#!/usr/bin/env bash
#
# ecoclean.sh - Script para eliminar archivos temporales y detectar/eliminar duplicados.
#
# Autor: Ricardo Andres Bonilla Prada
# Fecha: 2024-12-10
# Descripción:
# Sprint 1: Eliminar archivos temporales (.tmp, .log, .bak).
# Sprint 2: Detectar y eliminar duplicados basados en hash MD5.
#
# Uso: ./ecoclean.sh [directorio_opcional]
#

set -e
set -u

TARGET_DIR="${1:-$(pwd)}"

#------------------------------------------------------------
# Función: get_temp_files
# Obtiene la lista de archivos temporales.
#------------------------------------------------------------
get_temp_files() {
  local EXTENSIONS=("*.tmp" "*.log" "*.bak")
  local FILES_FOUND=()

  for EXT in "${EXTENSIONS[@]}"; do
    while IFS= read -r -d '' FILE; do
      FILES_FOUND+=("$FILE")
    done < <(find "${TARGET_DIR}" -type f -iname "${EXT}" -print0 2>/dev/null)
  done

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
# Retorna por stdout la lista de archivos que quedan tras la eliminación.
#
# Lógica:
# 1. Crear un archivo temporal para guardar "HASH FILE".
# 2. Calcular hash MD5 para cada archivo, guardar en ese archivo temporal.
# 3. Ordenar por HASH.
# 4. Recorrer el archivo: para cada grupo de HASH idéntico, conservar el primero
#    y eliminar los restantes.
# 5. Imprimir la lista final de archivos sin duplicados sobrantes.
#------------------------------------------------------------
remove_duplicates() {
  local OS_NAME
  OS_NAME=$(uname)

  # Leemos todos los archivos de stdin
  local FILES=()
  while IFS= read -r FILE; do
    FILES+=("$FILE")
  done

  # Si no hay archivos, devolvemos nada
  if (( ${#FILES[@]} == 0 )); then
    echo "No se encontraron archivos duplicados."
    return
  fi

  # Archivo temporal para hashes
  local TMP_HASH_FILE
  TMP_HASH_FILE=$(mktemp)

  # Generar hash para cada archivo y almacenarlo
  for FILE in "${FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
      local HASH
      if [[ "$OS_NAME" == "Darwin" ]]; then
        # macOS usa 'md5' en lugar de 'md5sum'
        HASH=$(md5 "$FILE" | awk '{print $4}')
      else
        HASH=$(md5sum "$FILE" | awk '{print $1}')
      fi
      echo "$HASH $FILE" >> "$TMP_HASH_FILE"
    fi
  done

  # Ordenar por HASH (primera columna)
  sort "$TMP_HASH_FILE" -o "$TMP_HASH_FILE"

  local CURRENT_HASH=""
  local TOTAL_DUPLICATES=0
  local UNIQUE_FILES=()

  while IFS= read -r LINE; do
    # Dividir línea en HASH y FILEPATH
    local HASH FILEPATH
    HASH=$(echo "$LINE" | awk '{print $1}')
    FILEPATH=$(echo "$LINE" | awk '{print $2}')

    if [[ "$HASH" != "$CURRENT_HASH" ]]; then
      # Nuevo grupo de HASH
      CURRENT_HASH="$HASH"
      UNIQUE_FILES+=("$FILEPATH")
    else
      # Mismo hash => duplicado, eliminar
      echo "Duplicado detectado. Eliminando: $FILEPATH"
      rm -f "$FILEPATH"
      ((TOTAL_DUPLICATES++))
    fi
  done < "$TMP_HASH_FILE"

  rm -f "$TMP_HASH_FILE"

  if (( TOTAL_DUPLICATES > 0 )); then
    echo "Total de duplicados eliminados: $TOTAL_DUPLICATES"
  else
    echo "No se encontraron archivos duplicados."
  fi

  # Imprimimos la lista de archivos resultantes (sin duplicados sobrantes)
  for UF in "${UNIQUE_FILES[@]}"; do
    echo "$UF"
  done
}

# Flujo Principal
TEMP_FILES=$(get_temp_files)
if [[ -z "$TEMP_FILES" ]]; then
  echo "No se encontraron archivos temporales."
  exit 0
fi

# 1. Eliminar duplicados y obtener lista final de archivos (sin duplicados)
UNIQUE_FILES=$(echo "$TEMP_FILES" | remove_duplicates)

# 2. Eliminar todos los archivos temporales resultantes (UNIQUE_FILES)
echo "$UNIQUE_FILES" | remove_temp_files
