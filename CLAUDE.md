# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Propósito

Imágenes Docker personalizadas PHP+Apache para LibelulaSoft, publicadas en Docker Hub bajo `libelulasoft/`.

## Imágenes disponibles

| Directorio | Tag Docker Hub | PHP | Xdebug |
|---|---|---|---|
| `php7.0.33/` | `libelulasoft/php7033` | 7.0 (Debian Stretch archivado) | 2.7.2 — puerto 9000 |
| `php8.0.30/` | `libelulasoft/php8030` | 8.0 | 3.x — puerto 9003 |

Ambas incluyen: GD, SOAP, ZIP, BCMath, MongoDB, ImageMagick, Composer 2, Apache mod_rewrite.

## Comandos de build y publicación

```bash
# PHP 7.0.33
cd php7.0.33
docker build -t libelulasoft/php7033:1.1 .
docker tag libelulasoft/php7033:1.1 libelulasoft/php7033:latest
docker push libelulasoft/php7033:latest

# PHP 8.0.30 (Xdebug habilitado por defecto)
cd php8.0.30
docker build -t libelulasoft/php8030:1 .

# PHP 8.0.30 sin Xdebug
docker build --build-arg ENABLE_XDEBUG=false -t libelulasoft/php8030:1 .

docker tag libelulasoft/php8030:1 libelulasoft/php8030:latest
docker push libelulasoft/php8030:latest
```

## Consideraciones clave

**PHP 7.0.33 — Debian Stretch EOL**: Los repositorios oficiales ya no existen. El Dockerfile usa `archive.debian.org` con validación de fechas deshabilitada (`Acquire::Check-Valid-Until "false"`) y paquetes no autenticados permitidos. No cambiar estas fuentes sin verificar compatibilidad.

**Xdebug — diferencias entre versiones**:
- PHP 7: config legacy (`xdebug.remote_enable`, `xdebug.remote_port=9000`) — Xdebug siempre activo
- PHP 8: config Xdebug 3 (`xdebug.mode=debug`, `xdebug.client_port=9003`) — controlado por `ARG ENABLE_XDEBUG`

**MongoDB**: versiones pinneadas (`mongodb-1.9.2` para PHP 7, `mongodb-1.11.0` para PHP 8). Cambiar versión requiere verificar compatibilidad con la extensión PECL y la versión de PHP.
