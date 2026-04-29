#!/bin/bash

set -euo pipefail

# ============================================================
# sync-dependencies.sh
# Copia /opt/devtools/vendor (libs preinstaladas en la imagen
# DEV) al directorio /host-vendor (bind-mount al host).
# Permite que IDEs en el host (PhpStorm / VSCode + Intelephense)
# indexen las clases que viven en la imagen sin tener que
# instalarlas en el composer.json del proyecto consumidor.
#
# Solo aplica a la imagen DEV — la imagen PROD no se sincroniza
# (corre con su propio /opt/devtools listo para alta carga).
#
# Uso típico (docker-compose):
#   services:
#     devtools-sync:
#       image: libelulasoft/php7033-dev:latest
#       volumes:
#         - ./host-vendor:/host-vendor
#       entrypoint: sync-dependencies.sh
#       restart: "no"
# ============================================================

SRC="/opt/devtools/vendor"
DEST="/host-vendor"

if [ ! -d "$SRC" ]; then
    echo "❌ ERROR: $SRC no existe en la imagen." >&2
    echo "   Verificá que estés usando libelulasoft/php*-dev (no -prod)." >&2
    exit 1
fi

if [ ! -d "$DEST" ]; then
    echo "❌ ERROR: $DEST no está montado." >&2
    echo "   Agregá un bind mount al servicio:" >&2
    echo "     volumes:" >&2
    echo "       - ./host-vendor:/host-vendor" >&2
    exit 1
fi

echo "🔄 Sincronizando devtools al host..."
echo "   $SRC  →  $DEST"

# Limpiar destino (incluyendo archivos ocultos, sin tocar . / ..)
rm -rf "${DEST:?}"/* "${DEST:?}"/.[!.]* "${DEST:?}"/..?* 2>/dev/null || true

# Copiar preservando atributos
cp -a "$SRC/." "$DEST/"

pkg_count=$(find "$DEST" -mindepth 2 -maxdepth 3 -name composer.json 2>/dev/null | wc -l)
echo "✅ devtools sincronizados ($pkg_count paquetes)"
