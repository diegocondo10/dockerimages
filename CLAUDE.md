# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Propósito

Imágenes Docker base PHP+Apache para LibelulaSoft, publicadas en Docker Hub bajo `libelulasoft/`.

A partir de la refactorización 2.1.0, cada versión de PHP expone **dos imágenes con propósitos distintos**:

| Sufijo | Para qué | Características |
|---|---|---|
| `-dev` | Desarrollo local + Bitbucket Pipelines (CI) | Xdebug, PHPUnit, devtools completos, `auto_prepend_file`, scripts CI/CD |
| `-prod` | Runtime productivo (AWS ECS desde junio) | Sin Xdebug, sin tooling de testing, OPcache tuneado, logs a stdout/stderr |

## Imágenes disponibles

| Directorio | Tag DEV | Tag PROD | PHP |
|---|---|---|---|
| `php7.0.33/` | `libelulasoft/php7033-dev` | `libelulasoft/php7033-prod` | 7.0 (Debian Stretch archivado) |
| `php8.0.30/` | `libelulasoft/php8030` *(pendiente refactor multi-target)* | — | 8.0 |

Extensiones comunes: GD, SOAP, ZIP, BCMath, MongoDB, ImageMagick, Apache mod_rewrite. La imagen `-dev` además trae Xdebug y Composer.

## Comandos de build

> El build context es el repo root — siempre desde `C:\Proyectos\docker\`.

```bash
# DEV (local + CI)
docker build --target dev \
    -t libelulasoft/php7033-dev:2.1.0 \
    -t libelulasoft/php7033-dev:2 \
    -t libelulasoft/php7033-dev:latest \
    -f php7.0.33/Dockerfile .

# PROD (ECS futuro)
docker build --target prod \
    -t libelulasoft/php7033-prod:2.1.0 \
    -t libelulasoft/php7033-prod:2 \
    -t libelulasoft/php7033-prod:latest \
    -f php7.0.33/Dockerfile .

# DEV sin Xdebug (ej. si querés debuggear sin overhead)
docker build --target dev --build-arg ENABLE_XDEBUG=false \
    -t libelulasoft/php7033-dev:2.1.0-noxdebug \
    -f php7.0.33/Dockerfile .
```

## Push a Docker Hub

```bash
docker login -u libelulasoft

docker push --all-tags libelulasoft/php7033-dev
docker push --all-tags libelulasoft/php7033-prod
```

## Estrategia de devtools

`php7.0.33/devtools/composer.json` define las libs preinstaladas en la imagen:

| Sección | Va en `-dev` | Va en `-prod` | Ejemplo |
|---|---|---|---|
| `require` | ✓ | ✓ | `vlucas/phpdotenv` (runtime) |
| `require-dev` | ✓ | ✗ | `phpunit/phpunit` (testing) |

El `auto_prepend_file` global apunta a `/opt/devtools/vendor/autoload.php` en **ambas** imágenes, así proyectos legacy con vendor hardcodeado pueden hacer `use Dotenv\Dotenv;` sin tocar su `composer.json`.

Para agregar una lib nueva:
- **Solo dev (linter, analyzer, testing)** → `require-dev`
- **Runtime también en prod** → `require` (cuidado con conflictos vs proyectos que ya la tengan en su vendor)

## sync-dependencies.sh

Script en imagen `-dev` que copia `/opt/devtools/vendor` al bind-mount `/host-vendor`. Permite a IDEs (PhpStorm/VSCode + Intelephense) indexar las clases que viven en la imagen.

```yaml
# docker-compose7.yaml de un proyecto consumidor
services:
  devtools-sync:
    image: libelulasoft/php7033-dev:latest
    volumes:
      - ./host-vendor:/host-vendor
    entrypoint: sync-dependencies.sh
    restart: "no"

  web:
    depends_on:
      devtools-sync:
        condition: service_completed_successfully
    # ...
```

El proyecto consumidor agrega `host-vendor/` al `.gitignore` y `.zipignore`, y a `intelephense.environment.includePaths` en `.vscode/settings.json`.

## Tuning de la imagen `-prod`

Configs aplicadas (ver `php7.0.33/Dockerfile` stage `prod`):

- **OPcache**: `validate_timestamps=0`, `memory_consumption=256MB`, `max_accelerated_files=20000`, `interned_strings_buffer=16`
- **PHP errors**: `display_errors=0`, `log_errors=1`, `error_log=/dev/stderr`, `expose_php=0`
- **Apache logs**: `ErrorLog /dev/stderr`, `CustomLog /dev/stdout combined` (CloudWatch los captura automáticamente)
- **Hardening Apache**: `ServerTokens Prod`, `ServerSignature Off`, `TraceEnable Off`
- **Sin** Xdebug, scripts CI/CD, phpunit, ni devtools de require-dev

## Migración de proyectos consumidores

### Hoy (mayo) — todavía en AWS EB nativo PHP

Los proyectos siguen como están. La imagen `-dev` se usa solo para desarrollo local.

```yaml
# docker-compose7.yaml
services:
  web:
    image: libelulasoft/php7033-dev:latest  # ← cambio mínimo respecto a la imagen vieja
```

### Junio — migración a ECS

El `Dockerfile` del proyecto cambia a:

```dockerfile
FROM libelulasoft/php7033-prod:latest
COPY . /var/www/html
RUN chown -R www-data:www-data /var/www/html
```

El deploy a ECS toma esta imagen.

## Consideraciones clave

**PHP 7.0.33 — Debian Stretch EOL**: Los repositorios oficiales ya no existen. Ambas imágenes (`-dev` y `-prod`) usan `archive.debian.org` con validación de fechas deshabilitada. No cambiar las fuentes sin verificar compatibilidad.

**Xdebug — diferencias entre versiones**:
- PHP 7 dev: `xdebug.remote_enable`, `xdebug.remote_port=9000` — controlado por `ARG ENABLE_XDEBUG`
- PHP 8 dev: `xdebug.mode=debug`, `xdebug.client_port=9003` — idem

**MongoDB**: versión pinneada `mongodb-1.9.2` para PHP 7 (1.11.0 para PHP 8). Cambiar versión requiere verificar compatibilidad con la extensión PECL.

**Imagen vieja `libelulasoft/php7033`** (sin sufijo): queda obsoleta a partir de la 2.1.0. Mantenerla en Docker Hub solo como rollback hasta que todos los consumidores hayan migrado a `-dev` / `-prod`.
