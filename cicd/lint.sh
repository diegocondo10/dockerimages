#!/bin/bash

set -euo pipefail

# Contadores para estadísticas
passed_files=0
error_count=0
error_files=()
error_details=()

# Paths por defecto (pueden ser sobreescritos por argumentos)
default_paths=("frontend" "common")

# Si se pasan argumentos, usarlos como paths
if [ $# -gt 0 ]; then
    paths=("$@")
else
    paths=("${default_paths[@]}")
fi

# Leer .lintignore si existe
ignore_file=".lintignore"
exclude_args=()

if [ -f "$ignore_file" ]; then
    while IFS= read -r pattern || [ -n "$pattern" ]; do
        # Strip carriage returns (CRLF-safe para archivos editados en Windows)
        pattern="${pattern//$'\r'/}"
        # Ignorar líneas vacías o comentarios
        [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue
        exclude_args+=(-not -path "./$pattern*")
    done < "$ignore_file"
fi

echo "🔍 Iniciando análisis de sintaxis PHP..."
echo ""

# Escanear archivos
for path in "${paths[@]}"; do
    if [ ! -d "$path" ]; then
        echo "⚠️  Directorio no encontrado: $path"
        continue
    fi

    while IFS= read -r -d '' file; do
        output=$(php -l "$file" 2>&1 || true)

        if [[ "$output" != *"No syntax errors detected"* ]]; then
            echo "❌ [ERROR]  $file"
            error_count=$((error_count + 1))
            error_files+=("$file")
            error_details+=("$output")
        else
            echo "✅ [OK]     $file"
            passed_files=$((passed_files + 1))
        fi

    done < <(find "$path" -type f -name "*.php" "${exclude_args[@]}" -print0 2>/dev/null)
done

# Mostrar resumen
total_files=$((passed_files + error_count))
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen: $total_files archivos | ✅ $passed_files OK | ❌ $error_count errores"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$error_count" -gt 0 ]; then
    echo ""
    echo "⛔️ Archivos con errores de sintaxis:"
    echo ""
    for i in "${!error_files[@]}"; do
        echo "   • ${error_files[$i]}"
        echo "     ${error_details[$i]}" | head -1 | sed 's/^/     /'
        echo ""
    done
    exit 1
else
    echo ""
    echo "✅ Todos los archivos pasaron el análisis de sintaxis correctamente."
    echo ""
fi
