#!/usr/bin/env bash
#
# ecoclean.sh - Script para eliminar archivos temporales (Sprint 1)
# Autor: [Tu Nombre]
# Fecha: [Fecha Actual]
# Descripción: Este script busca y elimina archivos con extensiones .tmp, .log y .bak
# en un directorio específico. Si no se proporciona directorio, se toma el actual.
#
# Uso: ./ecoclean.sh [directorio_opcional]
#
# Ejemplo: ./ecoclean.sh /home/usuario/descargas
#

# Ajustes para mayor robustez del script
set -e  # Detener ejecución si ocurre algún error
set -u  # Detener si se usan variables sin definir

# Variable que determina el directorio objetivo, por defecto el actual
TARGET_DIR="${1:-$(pwd)}"

#------------------------------------------------------------
# Función: clean_temp_files
# Descripción: Esta función busca archivos con extensiones .tmp, .log, .bak
#              en el directorio objetivo y los elimina. Finalmente, muestra
#              un resumen de lo que se ha borrado.
#------------------------------------------------------------
clean_temp_files() {
  # Declaramos un array con las extensiones de archivos temporales a eliminar
  local EXTENSIONS=("*.tmp" "*.log" "*.bak")

  # Contador de archivos eliminados
  local DELETED_COUNT=0

  # Recorremos cada patrón de extensión
  for EXT in "${EXTENSIONS[@]}"; do
    # Buscamos archivos con la extensión en el directorio objetivo
    # -type f: busca sólo archivos
    # -iname: busca sin distinguir mayúsculas
    # -print0 y xargs -0 para manejar espacios en los nombres
    find "${TARGET_DIR}" -type f -iname "${EXT}" -print0 | while IFS= read -r -d '' FILE; do
      # Verificamos si el archivo existe antes de eliminar
      if [[ -f "$FILE" ]]; then
        echo "Eliminando: $FILE"
        rm -f "$FILE"
        ((DELETED_COUNT++))
      fi
    done
  done

  # Mostramos un resumen de la cantidad de archivos eliminados
  echo "Total de archivos temporales eliminados: ${DELETED_COUNT}"
}

# Llamada a la función principal
clean_temp_files
