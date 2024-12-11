# EcoClean

**Autor:** Ricardo Andres Bonilla Prada  
**Fecha:** 2024-12-10

EcoClean es una herramienta en Bash que permite limpiar archivos temporales, detectar y eliminar duplicados, ofrecer una interfaz interactiva, gestionar configuraciones externas y registrar las acciones realizadas. Está orientada al uso personal y tiene potencial para ser comercializada en el futuro, ofreciendo una solución confiable y personalizable de limpieza de sistemas.

## Funcionalidades

- **Sprint 1:**  
  - Eliminar archivos temporales con extensiones `.tmp`, `.log` y `.bak`.
  
- **Sprint 2:**  
  - Detectar archivos duplicados (por hash MD5) y eliminar todos menos uno.
  
- **Sprint 3:**  
  - Interfaz interactiva en terminal con menús, confirmaciones y reportes previos.
  
- **Sprint 4:**  
  - Uso de un archivo de configuración externo (`ecoclean.conf`) para definir rutas y extensiones a limpiar, facilitando la personalización sin modificar el código.
  
- **Sprint 5:**  
  - Sistema de logging detallado con fecha y hora, registrando cuántos archivos se eliminaron y el espacio total liberado.

## Requisitos Previos

- **Sistema Operativo:**  
  - Probado en macOS con Bash 4+ (instalable vía Homebrew).  
  - Debería funcionar también en Linux con `md5sum` disponible.
- **Herramientas Necesarias:**  
  - Bash 4.0 o superior (en macOS, la versión por defecto es 3.2, por lo que se recomienda instalar Bash más reciente con `brew install bash` y ajustar el `#!/opt/homebrew/bin/bash` según la ruta).  
  - Comandos estándar: `find`, `stat`, `md5`, `md5sum`, `awk`.
  - Opcional: `dialog` o `whiptail` si se quieren interfaces más complejas (no requerido en esta versión).

## Instalación y Configuración

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/RikardoBonilla/ecoclean.git
   cd ecoclean
   ```

2. **Dar permisos de ejecución al script:**
   ```bash
   chmod +x ecoclean.sh
   ```

3. **Archivo de configuración (`ecoclean.conf`):**  
   Edite el archivo `ecoclean.conf` (si no existe, créelo) para personalizar las extensiones y directorios:
   ```bash
   # ecoclean.conf
   TEMP_EXTENSIONS="*.tmp *.log *.bak"
   CLEAN_DIRS="/Users/ricardo/Documents/ProjectsToIA/Bash/ecoclean /tmp"
   LOG_FILE="$(dirname "$0")/logs/ecoclean.log"
   ```
   
   - `TEMP_EXTENSIONS`: Lista de extensiones separadas por espacio.
   - `CLEAN_DIRS`: Lista de directorios separados por espacio donde se buscarán archivos temporales.

   Si no existe el archivo `ecoclean.conf`, el script usará extensiones y directorio actual por defecto.

4. **Directorio de logs:**
   Asegúrate de tener el directorio `logs` creado:
   ```bash
   mkdir -p logs
   ```
   
   El archivo `ecoclean.log` se generará automáticamente con las acciones realizadas.

## Uso

Ejecuta:
```bash
./ecoclean.sh 
```
o tambien puede ser :
```bash
/usr/local/bin/bash ./ecoclean.sh 
```
Aparecerá un menú interactivo con las siguientes opciones:

1. **Mostrar archivos temporales:**  
   Lista todos los archivos encontrados según las extensiones y rutas definidas en la configuración.

2. **Detectar y eliminar duplicados:**  
   Muestra qué archivos tienen duplicados y pregunta si deseas continuar con la eliminación.  
   Tras confirmar, elimina los duplicados y conserva uno solo, registrando la acción en el log.

3. **Eliminar todos los archivos temporales:**  
   Muestra todos los archivos temporales y pregunta si deseas eliminarlos.  
   Tras confirmar, elimina todos y registra la acción en el log, mostrando cuántos archivos se eliminaron y cuántos bytes se liberaron.

4. **Salir:**  
   Cierra el menú interactivo.

## Ejemplo de Flujo de Uso

1. Crea archivos temporales:
   ```bash
   touch test1.tmp test2.log test3.bak
   echo "Contenido de prueba" > test1.tmp
   cp test1.tmp test2.log
   cp test1.tmp test3.bak
   ```

2. Ejecuta EcoClean:
   ```bash
   ./ecoclean.sh
   ```
   
   - Opción 1: Verás los 3 archivos.
   - Opción 2: Detectará que hay duplicados. Presiona `s` para confirmar. Se eliminarán los duplicados dejando uno solo.
   - Opción 1 nuevamente: Ahora hay menos archivos.
   - Opción 3: Elimina todos los archivos restantes. Presiona `s` para confirmar.

3. Verifica el log:
   ```bash
   cat logs/ecoclean.log
   ```
   
   Encontrarás entradas con fecha, hora, cantidad de archivos eliminados y bytes liberados.

## Versiones

- **Bash:** Probado con Bash 5.1 (instalado vía Homebrew en macOS).
- **Herramientas del sistema:** Versión estándar del `find`, `stat`, `md5`/`md5sum` en macOS y Linux.
- **Compatibilidad:**  
  - macOS: Se requiere ajustar el `#!/opt/homebrew/bin/bash` a la ruta real de Bash 4+  
  - Linux: Debería funcionar usando `md5sum` en vez de `md5`.

## Posibles Mejoras Futuras

- **Soporte para múltiples perfiles de configuración:**  
  Permitir distintos archivos de configuración (`ecoclean_work.conf`, `ecoclean_home.conf`) y cargar uno u otro al inicio con un parámetro.
  
- **Notificaciones avanzadas:**  
  Enviar alertas por correo o notificaciones del sistema cuando se realice una limpieza grande o se encuentren muchos duplicados.
  
- **Interfaz gráfica:**  
  Integrar con herramientas como `dialog` o `whiptail` para ofrecer un menú más rico visualmente.
  
- **Soporte multiplataforma más robusto:**  
  Detección automática de entorno (macOS, Linux, WSL) y ajustar comandos (`md5` vs `md5sum`, `stat` vs `du`).
  
- **Registro ampliado:**  
  Guardar detalles como el nombre de cada archivo eliminado, su extensión, y mantener un historial rotativo del log para no crecer indefinidamente.

## Licencia

Este proyecto se puede adaptar o distribuir libremente (añadir la licencia que prefieras, por ejemplo MIT o GPL).
