# CI/CD - Herramientas de Integración Continua

## zip.sh - Empaquetador de Aplicacion

Script para crear el archivo zip de la aplicacion para deploy en AWS Elastic Beanstalk. Utiliza compresion rapida y excluye archivos innecesarios.

### Uso

```bash
# Crear application.zip (nombre por defecto)
./cicd/zip.sh

# Crear zip con nombre personalizado
./cicd/zip.sh mi-app.zip
```

### Archivo .zipignore

Puedes crear un archivo `.zipignore` en la raiz del proyecto para excluir archivos y carpetas del zip.

**Formato:**

```
# Comentarios con #
.git
node_modules
tests
*.log
```

- Cada linea representa un patron a excluir
- Las lineas vacias y comentarios (iniciando con `#`) son ignorados

### Caracteristicas

- **Compresion rapida**: Usa nivel -1 para maxima velocidad
- **Exclusiones configurables**: Soporte para `.zipignore`
- **Salida informativa**: Muestra tamanio del archivo generado

---

## lint.sh - Validador de Sintaxis PHP

Script de linting que valida la sintaxis de archivos PHP en el proyecto utilizando `php -l`. Muestra el estado de cada archivo mientras se procesa y al final un resumen con el detalle de errores.

### Requisitos

- Bash 4.0+
- PHP CLI instalado y disponible en el PATH

### Uso

```bash
# Ejecutar con directorios por defecto (frontend, common)
./cicd/lint.sh

# Ejecutar con directorios personalizados
./cicd/lint.sh src api services

# Ejecutar en un solo directorio
./cicd/lint.sh frontend
```

### Directorios por Defecto

El script analiza los siguientes directorios si no se especifican argumentos:

- `frontend`
- `common`

### Archivo .lintignore

Puedes crear un archivo `.lintignore` en la raiz del proyecto para excluir rutas del analisis.

**Formato:**

```
# Comentarios con #
vendor
node_modules
tests/fixtures
```

- Cada linea representa un patron de ruta a excluir
- Las lineas vacias y comentarios (iniciando con `#`) son ignorados

### Salida

El script muestra el estado de cada archivo mientras lo procesa:

```
🔍 Iniciando análisis de sintaxis PHP...

✅ [OK]     frontend/index.php
✅ [OK]     frontend/login.php
❌ [ERROR]  frontend/broken.php
✅ [OK]     common/utils.php
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Resumen: 150 archivos | ✅ 149 OK | ❌ 1 errores
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⛔️ Archivos con errores de sintaxis:

   • frontend/broken.php
     Parse error: syntax error, unexpected '}' in frontend/broken.php on line 15
```

### Codigos de Salida

| Codigo | Descripcion |
|--------|-------------|
| `0` | Todos los archivos pasaron la validacion |
| `1` | Se encontraron errores de sintaxis |

### Caracteristicas

- **Estado por archivo**: Muestra el resultado de cada archivo mientras se procesa
- **Resumen final**: Estadisticas totales al finalizar el escaneo
- **Detalle de errores**: Incluye el mensaje de error de PHP para cada archivo con problemas
- **Paths personalizables**: Acepta directorios como argumentos
- **Exclusiones configurables**: Soporte para `.lintignore`

### Integracion con CI/CD

#### GitHub Actions

```yaml
- name: PHP Lint
  run: ./cicd/lint.sh
```

#### GitLab CI

```yaml
lint:
  script:
    - ./cicd/lint.sh
```

#### Jenkins

```groovy
stage('Lint') {
    steps {
        sh './cicd/lint.sh'
    }
}
```

### Solucion de Problemas

| Problema | Solucion |
|----------|----------|
| `php: command not found` | Instalar PHP CLI o agregarlo al PATH |
| `Permission denied` | Ejecutar `chmod +x cicd/lint.sh` |
| `Directorio no encontrado` | Verificar que los paths existan |
