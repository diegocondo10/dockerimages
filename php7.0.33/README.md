# PHP 7.0.33 — Imágenes Docker LibelulaSoft

Imágenes base PHP 7.0.33 + Apache, multi-target. Pensadas para soportar proyectos legacy con `vendor/` hardcodeado (sin posibilidad de `composer require`).

## Imágenes publicadas

| Imagen | Para qué | Tamaño | Tags |
|---|---|---|---|
| [`libelulasoft/php7033-dev`](https://hub.docker.com/r/libelulasoft/php7033-dev) | Desarrollo local + Bitbucket Pipelines | ~635 MB | `2.1.0`, `2`, `latest` |
| [`libelulasoft/php7033-prod`](https://hub.docker.com/r/libelulasoft/php7033-prod) | Runtime productivo (AWS ECS) | ~582 MB | `2.1.0`, `2`, `latest` |

## ¿Por qué dos imágenes?

| Aspecto | DEV | PROD |
|---|---|---|
| Xdebug | ✅ (configurable) | ❌ |
| Composer 2.2 | ✅ | ❌ |
| PHPUnit (`/usr/local/bin/phpunit`) | ✅ | ❌ |
| `lint.sh`, `zip.sh`, `sync-dependencies.sh` | ✅ | ❌ |
| `git`, `unzip`, `zip` | ✅ | ❌ |
| `/opt/devtools/vendor` | full (`require` + `require-dev`) | trimmed (`--no-dev`) |
| OPcache habilitado | default (off) | ✅ tuneado para alta carga |
| `display_errors` | default | `0` (logs a stderr) |
| Apache logs | default (archivos) | a stdout/stderr (CloudWatch) |
| `auto_prepend_file` | ✅ | ✅ |
| `expose_php` | default | `0` |
| Hardening Apache | default | `ServerTokens Prod`, `ServerSignature Off`, `TraceEnable Off` |

## Stack técnico

| Componente | Versión |
|---|---|
| Base image | `php:7.0-apache` (Debian Stretch — EOL, repos archivados) |
| PHP | 7.0.33 |
| Apache | 2.4.x con `mod_rewrite`, `mod_headers` |
| Composer (solo dev) | 2.2 (último LTS con soporte PHP 7.0) |
| Xdebug (solo dev) | 2.7.2 — protocolo legacy puerto 9000 |
| MongoDB driver | mongodb 1.9.2 (PECL) |
| Imagick | imagick 3.4.4 (PECL) |
| OPcache (solo prod) | bundled, configurada para producción |

### Extensiones PHP habilitadas

`gd`, `soap`, `zip`, `bcmath`, `mongodb`, `imagick`, `xdebug` (solo en dev), `opcache` (solo en prod).

## Devtools (`/opt/devtools/vendor`)

Las imágenes traen un `composer install` pre-ejecutado en `/opt/devtools/`. Las clases quedan disponibles globalmente vía `auto_prepend_file=/opt/devtools/vendor/autoload.php`.

`devtools/composer.json`:

```json
{
    "require": {
        "vlucas/phpdotenv": "^4.0"
    },
    "require-dev": {
        "phpunit/phpunit": "^6.5"
    }
}
```

| Lib | dev | prod | Uso |
|---|---|---|---|
| `vlucas/phpdotenv` | ✅ | ✅ | Cargar `.env` en proyectos legacy sin tocar su composer |
| `phpunit/phpunit` | ✅ | ❌ | Testing en local + CI |

> **Codeception NO incluido en PHP 7.0**: sus dependencias transitivas (`symfony/polyfill-php80`) usan nullable types (`?Type`) introducidos en PHP 7.1. Para Codeception en proyectos PHP 7, instalalo en el vendor del proyecto con una versión compatible o migrá a la imagen PHP 8.

## Cómo buildear

> Build context = repo root (no `cd php7.0.33/`). Necesario para incluir `cicd/` y `devtools/`.

```bash
# DEV
docker build --target dev \
    -t libelulasoft/php7033-dev:2.1.0 \
    -t libelulasoft/php7033-dev:2 \
    -t libelulasoft/php7033-dev:latest \
    -f php7.0.33/Dockerfile .

# PROD
docker build --target prod \
    -t libelulasoft/php7033-prod:2.1.0 \
    -t libelulasoft/php7033-prod:2 \
    -t libelulasoft/php7033-prod:latest \
    -f php7.0.33/Dockerfile .

# DEV sin Xdebug (debugging sin overhead)
docker build --target dev --build-arg ENABLE_XDEBUG=false \
    -t libelulasoft/php7033-dev:2.1.0-noxdebug \
    -f php7.0.33/Dockerfile .
```

El stage `builder` se cachea entre `--target dev` y `--target prod` — el segundo build es muy rápido si el primero ya pasó.

## Cómo publicar

```bash
docker login -u libelulasoft

docker push --all-tags libelulasoft/php7033-dev
docker push --all-tags libelulasoft/php7033-prod
```

## Cómo usar

### Desarrollo local (`docker-compose.yaml`)

```yaml
services:
  devtools-sync:
    image: libelulasoft/php7033-dev:latest
    volumes:
      - ./host-vendor:/host-vendor
    entrypoint: sync-dependencies.sh
    restart: "no"

  web:
    image: libelulasoft/php7033-dev:latest
    depends_on:
      devtools-sync:
        condition: service_completed_successfully
    ports:
      - "8081:80"
    volumes:
      - .:/var/www/html
```

El servicio `devtools-sync` copia `/opt/devtools/vendor` de la imagen a `./host-vendor` en cada `up`. El proyecto agrega `host-vendor/` a `.gitignore` y configura el IDE para indexarlo:

`.vscode/settings.json`:
```json
{
  "intelephense.environment.includePaths": ["host-vendor"]
}
```

### Bitbucket Pipelines (CI)

```yaml
# bitbucket-pipelines.yml
pipelines:
  default:
    - step:
        image: libelulasoft/php7033-dev:latest
        script:
          - lint.sh frontend common
          - phpunit tests/
          - zip.sh application.zip
```

### Deploy productivo (ECS, desde junio 2026)

```dockerfile
# Dockerfile del proyecto
FROM libelulasoft/php7033-prod:latest

COPY . /var/www/html
COPY ./vhost.conf /etc/apache2/sites-available/000-default.conf
RUN chown -R www-data:www-data /var/www/html

WORKDIR /var/www/html
```

Build, push a ECR, update task definition.

## Uso de las clases de devtools

Cualquier proyecto que use cualquiera de estas imágenes puede hacer:

```php
<?php
use Dotenv\Dotenv;

$dotenv = Dotenv::createImmutable(__DIR__);
$dotenv->safeLoad();
```

Sin tener `vlucas/phpdotenv` en su `composer.json`. La clase la resuelve `auto_prepend_file` desde `/opt/devtools/vendor/autoload.php`.

> ⚠️ Si dos consumidores tienen versiones distintas de la misma lib (uno en su vendor, otro vía devtools), gana el autoloader que se carga primero — y el orden depende del flujo. Evitá meter en `require` libs que los proyectos consumidores ya tengan en su `vendor/`.

### Cuando el runtime NO es Docker (AWS EB nativo PHP)

`auto_prepend_file` solo se aplica donde la imagen Docker es el runtime efectivo (local con `-dev`, ECS con `-prod`). Si tu proyecto se deploya a **AWS EB con PHP nativo**, la imagen no corre allá y `auto_prepend_file` no existe.

Para que el proyecto use `Dotenv\Dotenv` **igual en local (Docker) que en EB nativo** sin modificar su `composer.json`, agregá una guardia condicional en el bootstrap (`frontend/web/index.php`, `web/index.php`, etc.):

```php
// Cargar autoloader de devtools SOLO si nadie cargó aún composer (caso EB nativo).
// En Docker (-dev/-prod) auto_prepend_file ya lo hizo → guardia false → skip.
if (!class_exists(\Composer\Autoload\ClassLoader::class, false)) {
    @include __DIR__ . '/../../host-vendor/autoload.php';
}
require __DIR__ . '/../../vendor/autoload.php';
```

**Por qué la guardia**: en Docker, el `auto_prepend_file` ya cargó `/opt/devtools/vendor/autoload.php`. Si después incluyeras `host-vendor/autoload.php` (que es una copia con el **mismo composer hash**), el segundo `require_once` intentaría redeclarar la clase `ComposerAutoloaderInit<hash>` y tirás `Fatal error: Cannot declare class`. La guardia detecta que composer ya está cargado y skipea.

**Para que ande en EB**: shippear `host-vendor/` en el zip de deploy. Eso significa sacarla del `.zipignore` y asegurarse de regenerarla con `sync-dependencies.sh` antes de empaquetar:

```bash
# En el script de build/deploy del proyecto:
docker compose run --rm devtools-sync   # genera ./host-vendor/
zip.sh application.zip                   # ahora SIN .zipignore para host-vendor/
```

> Esta guardia es el patrón estándar para legacy. Si tu proyecto ya tiene Composer real (PHP 7.4+ o 8.x con `composer install`), agregá la lib a tu propio `composer.json` y omitís todo este flujo.

## Tuning de prod (configs aplicadas)

### OPcache (`/usr/local/etc/php/conf.d/zz-opcache-prod.ini`)

```ini
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0
opcache.revalidate_freq=0
opcache.fast_shutdown=1
```

> ⚠️ `validate_timestamps=0` significa que **PHP no detecta cambios en archivos** después del primer load. Cualquier deploy requiere reiniciar el contenedor (o `opcache_reset()` programático). Es lo correcto para alta carga, pero hay que tenerlo presente.

### Errors (`zz-errors-prod.ini`)

```ini
display_errors=0
display_startup_errors=0
log_errors=1
error_log=/dev/stderr
error_reporting=E_ALL & ~E_DEPRECATED & ~E_STRICT
expose_php=0
```

### Apache

```apache
ErrorLog /dev/stderr
CustomLog /dev/stdout combined
ServerTokens Prod
ServerSignature Off
TraceEnable Off
```

## Scripts CI/CD (solo en imagen `-dev`)

Disponibles en `/usr/local/bin/`. Leen archivos de config desde el `CWD` del proyecto.

| Script | Función | Lee config de |
|---|---|---|
| `lint.sh` | Análisis de sintaxis PHP recursivo | `.lintignore` |
| `zip.sh` | Empaqueta el proyecto para deploy | `.zipignore` |
| `sync-dependencies.sh` | Copia `/opt/devtools/vendor` a `/host-vendor` | (no necesita config) |

## Troubleshooting

### `Class 'Dotenv\Dotenv' not found` en producción

Verificá que estés usando `libelulasoft/php7033-prod` (no la imagen vieja `php7033`). El `auto_prepend_file` solo está en las imágenes refactorizadas (≥ 2.1.0).

```bash
docker run --rm libelulasoft/php7033-prod:latest php -i | grep auto_prepend
# Debería mostrar: auto_prepend_file => /opt/devtools/vendor/autoload.php
```

### Cambios en archivos no se reflejan en prod

OPcache tiene `validate_timestamps=0`. Reiniciá el contenedor o llamá `opcache_reset()` desde un endpoint admin.

### IDE no indexa las clases de la imagen

Confirmá que el servicio `devtools-sync` corrió y la carpeta `host-vendor/` está poblada en el host. Después configurá el include path del IDE (ver sección "Desarrollo local").

### Apache logs no aparecen en CloudWatch

Solo en imagen `-prod` los logs van a stdout/stderr. En `-dev` van a archivos por default.

## Limitaciones conocidas

- **PHP 7.0.33 está EOL desde diciembre 2018**. Sin parches de seguridad upstream. Esta imagen existe puramente para **mantener proyectos legacy operativos** hasta migración. No usar para nuevos desarrollos.
- **Debian Stretch repos archivados**: el Dockerfile usa `archive.debian.org` con `Acquire::Check-Valid-Until "false"` y `AllowUnauthenticated=true`. Los paquetes están congelados en su estado de 2020.
- **Codeception no incluido** (ver sección Devtools).

## Cambios respecto a la imagen vieja `libelulasoft/php7033`

| Cambio | Detalle |
|---|---|
| Repos separados | `php7033` → `php7033-dev` y `php7033-prod` |
| Multi-target Dockerfile | `--target dev` / `--target prod` |
| Composer split | `require` (runtime) vs `require-dev` (testing) |
| Auto_prepend global | Permite `use Foo\Bar` sin tocar composer del proyecto |
| `sync-dependencies.sh` | Sync de devtools al host para indexado IDE |
| Imagen prod tuneada | OPcache, hardening, logs a stdout |

## Versionado

Esquema semántico `MAJOR.MINOR.PATCH`:
- **MAJOR** — incompatibilidad: cambio de PHP, base image, eliminación de extensión
- **MINOR** — agregado retrocompatible: nueva extensión, nueva lib en devtools
- **PATCH** — bugfix sin cambios funcionales

| Tag | Significado |
|---|---|
| `:2.1.0` | Versión específica (immutable, recomendado para CI) |
| `:2` | Última patch del major 2 |
| `:latest` | Última estable (alias del último `:MAJOR`) |
