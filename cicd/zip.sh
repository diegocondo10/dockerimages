#!/bin/bash

set -euo pipefail

output_file="${1:-application.zip}"
ignore_file=".zipignore"
exclude_args=()

# Leer .zipignore si existe
if [ -f "$ignore_file" ]; then
    while IFS= read -r pattern || [ -n "$pattern" ]; do
        # Strip carriage returns (CRLF-safe para archivos editados en Windows)
        pattern="${pattern//$'\r'/}"
        # Ignorar líneas vacías o comentarios
        [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue
        # Prefijo ./ necesario: zip -r . almacena rutas como ./.git, ./vendor, etc.
        exclude_args+=(-x "./${pattern}" -x "./${pattern}/" -x "./${pattern}/*")
    done < "$ignore_file"
fi

echo "📦 Creando $output_file..."

# Usar compresión rápida (-1) y excluir patrones del .zipignore
zip -1 -r "$output_file" . "${exclude_args[@]}"

echo "✅ $output_file creado exitosamente"
ls -lh "$output_file"
