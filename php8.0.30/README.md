# PHP 8.0.30 — Imágenes Docker LibelulaSoft

Imágenes base PHP 8.0.30 + Apache, multi-target. Pensadas para proyectos modernos que pueden manejar sus deps con Composer en su propio repositorio + tooling estandarizado de testing en la imagen.

## Imágenes publicadas

| Imagen | Para qué | Tamaño aprox. | Tags |
|---|---|---|---|
| [`libelulasoft/php8030-dev`](https://hub.docker.com/r/libelulasoft/php8030-dev) | Desarrollo local + Bitbucket Pipelines | ~750 MB | `2.1.0`, `2`, `latest` |
| [`libelulasoft/php8030-prod`](https://hub.docker.com/r/libelulasoft/php8030-prod) | Runtime productivo (AWS ECS) | ~430 MB | `2.1.0`, `2`, `latest` |

## ¿Por qué dos imágenes?

| Aspecto | DEV | PROD |
|---|---|---|
| Xdebug 3 | ✅ (configurable) | ❌ |
| Composer 2.7 | ✅ | ❌ |
| PHPUnit (`/usr/local/bin/phpunit`) | ✅ | ❌ |
| Codeception (`/usr/local/bin/codecept`) | ✅ | ❌ |
| `lint.sh`, `zip.sh`, `sync-dependencies.sh` | ✅ | ❌ |
| `git`, `vim`, `nano`, `unzip`, `zip` | ✅ | ❌ |
| `/opt/devtools/vendor` | full (`require` + `require-dev`) | trimmed (`--no-dev`) |
| OPcache habilitado | default (off) | ✅ tuneado para alta carga |
| `display_errors` | default | `0` (logs a stderr) |
| Apache logs | default (archivos) | a stdout/stderr (CloudWatch) |
| `auto_prepend_file` | ✅ | ✅ |
| `expose_php` | default | `0` |
| HEALTHCHECK | ❌ | ✅ TCP check al puerto 80 |
| Hardening Apache | default | `ServerTokens Prod`, `ServerSignature Off`, `TraceEnable Off` |

## Stack técnico

| Componente | Versión |
|---|---|
| Base image | `php:8.0-apache` (Debian Bullseye) |
| PHP | 8.0.30 |
| Apache | 2.4.x con `mod_rewrite`, `mod_headers` |
| Composer (solo dev) | 2.7 |
| Xdebug (solo dev) | 3.1.6 — protocolo Xdebug 3 puerto 9003 |
| MongoDB driver | mongodb 1.11.0 (PECL) |
| Imagick | imagick 3.7.0 (PECL) |
| OPcache (solo prod) | bundled, configurada para producción |

### Extensiones PHP habilitadas

`gd`, `soap`, `zip`, `bcmath`, `mongodb`, `imagick`, `xdebug` (solo en dev), `opcache` (solo en prod).

## Devtools (`/opt/devtools/vendor`)

Las imágenes traen un `composer install` pre-ejecutado en `/opt/devtools/`. Las clases quedan disponibles globalmente vía `auto_prepend_file=/opt/devtools/vendor/autoload.php`.

`devtools/composer.json`:

```json
{
    "require": {
        "php": "~8.0.30",
        "vlucas/phpdotenv": "^5.0"
    },
    "require-dev": {
        "phpunit/phpunit": "^9.6",
        "codeception/codeception": "^5.0",
        "codeception/module-asserts": "^3.0",
        "codeception/module-yii2": "^1.1",
        "codeception/module-phpbrowser": "^3.0",
        "codeception/module-db": "^3.0"
    }
}
```

| Lib | dev | prod | Uso |
|---|---|---|---|
| `vlucas/phpdotenv` | ✅ | ✅ | Cargar `.env` (proyectos modernos pueden tenerlo en su propio composer también) |
| `phpunit/phpunit` | ✅ | ❌ | Testing |
| `codeception/codeception` + módulos | ✅ | ❌ | Testing E2E + Yii2 |

`composer.lock` está commiteado en `php8.0.30/devtools/` para reproducibilidad bit-a-bit.

## Cómo buildear

> Build context = repo root (no `cd php8.0.30/`). Necesario para incluir `cicd/` y `devtools/`.

```bash
# DEV
docker build --target dev \
    -t libelulasoft/php8030-dev:2.1.0 \
    -t libelulasoft/php8030-dev:2 \
    -t libelulasoft/php8030-dev:latest \
    -f php8.0.30/Dockerfile .

# PROD
docker build --target prod \
    -t libelulasoft/php8030-prod:2.1.0 \
    -t libelulasoft/php8030-prod:2 \
    -t libelulasoft/php8030-prod:latest \
    -f php8.0.30/Dockerfile .

# DEV sin Xdebug (debugging sin overhead)
docker build --target dev --build-arg ENABLE_XDEBUG=false \
    -t libelulasoft/php8030-dev:2.1.0-noxdebug \
    -f php8.0.30/Dockerfile .
```

El stage `builder` se cachea entre `--target dev` y `--target prod` — el segundo build es muy rápido si el primero ya pasó.

## Cómo publicar

```bash
docker login -u libelulasoft

docker push --all-tags libelulasoft/php8030-dev
docker push --all-tags libelulasoft/php8030-prod
```

## Cómo usar

### Desarrollo local (`docker-compose.yaml`)

```yaml
services:
  devtools-sync:
    image: libelulasoft/php8030-dev:latest
    volumes:
      - ./host-vendor:/host-vendor
    entrypoint: sync-dependencies.sh
    restart: "no"

  web:
    image: libelulasoft/php8030-dev:latest
    depends_on:
      devtools-sync:
        condition: service_completed_successfully
    ports:
      - "8082:80"
    volumes:
      - .:/var/www/html
```

### Bitbucket Pipelines (CI)

```yaml
pipelines:
  default:
    - step:
        image: libelulasoft/php8030-dev:latest
        script:
          - lint.sh frontend common
          - codecept run --no-colors
          - zip.sh application.zip
```

### Deploy productivo (ECS)

```dockerfile
# Dockerfile del proyecto
FROM libelulasoft/php8030-prod:latest

COPY . /var/www/html
COPY ./vhost.conf /etc/apache2/sites-available/000-default.conf
RUN chown -R www-data:www-data /var/www/html

WORKDIR /var/www/html
```

## Filosofía vs PHP 7.0.33

| Decisión | PHP 7.0.33 | PHP 8.0.30 |
|---|---|---|
| Proyecto consumidor maneja sus deps con Composer | ❌ (vendor hardcodeado) | ✅ |
| Imagen base trae libs runtime (`phpdotenv`) | ✅ (necesario para legacy) | ✅ (común a varios proyectos) |
| Imagen base trae herramientas de testing | ✅ (PHPUnit) | ✅ (PHPUnit + Codeception 5) |
| `auto_prepend_file` | ✅ | ✅ |
| `composer.lock` commiteado | ❌ (pendiente) | ✅ |
| HEALTHCHECK | ❌ (pendiente) | ✅ |
| Apache logs por symlinks | ❌ (vía sed, pendiente fix) | ✅ |

## Xdebug 3 — diferencia con PHP 7

Xdebug 3.x cambió el protocolo. Si venís de PHP 7 (Xdebug 2.7 puerto 9000), tenés que actualizar la config del cliente IDE para PHP 8:

| Setting | PHP 7 (Xdebug 2.x) | PHP 8 (Xdebug 3.x) |
|---|---|---|
| Modo activado | `xdebug.remote_enable=1` | `xdebug.mode=debug` |
| Inicio automático | `xdebug.remote_autostart=1` | `xdebug.start_with_request=yes` |
| Host del cliente | `xdebug.remote_host=host.docker.internal` | `xdebug.client_host=host.docker.internal` |
| Puerto | `xdebug.remote_port=9000` | `xdebug.client_port=9003` |

**En tu IDE (VSCode / PhpStorm)**, configurá el listener para puerto **9003** cuando uses esta imagen.

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

Logs vía symlinks (más robusto que `sed` sobre `apache2.conf`):

```bash
ln -sf /dev/stderr /var/log/apache2/error.log
ln -sf /dev/stdout /var/log/apache2/access.log
ln -sf /dev/stdout /var/log/apache2/other_vhosts_access.log
```

Hardening:
```apache
ServerTokens Prod
ServerSignature Off
TraceEnable Off
```

### HEALTHCHECK

TCP check al puerto 80 vía PHP CLI (sin necesidad de instalar `curl`):

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD php -r "exit(@stream_socket_client('tcp://127.0.0.1:80', \$e, \$es, 1) ? 0 : 1);"
```

## Scripts CI/CD (solo en imagen `-dev`)

Disponibles en `/usr/local/bin/`. Leen archivos de config desde el `CWD` del proyecto.

| Script | Función | Lee config de |
|---|---|---|
| `lint.sh` | Análisis de sintaxis PHP recursivo | `.lintignore` |
| `zip.sh` | Empaqueta el proyecto para deploy | `.zipignore` |
| `sync-dependencies.sh` | Copia `/opt/devtools/vendor` a `/host-vendor` | (no necesita config) |

## Troubleshooting

### Xdebug no rompe en mi IDE

- Verificá que el IDE escuche en puerto **9003** (no 9000 como PHP 7)
- En Windows/WSL, el host es `host.docker.internal` — solo funciona en Docker Desktop
- Confirmá que `ENABLE_XDEBUG` no esté en `false`

### Codeception no encuentra `module-yii2`

Está pre-instalado en `/opt/devtools/vendor/codeception/module-yii2`. Si tu proyecto tiene su propio `vendor/`, asegurate de invocar `codecept` desde la imagen (`/usr/local/bin/codecept`) y no desde tu vendor local que puede no tener el módulo.

### Cambios en archivos no se reflejan en prod

OPcache tiene `validate_timestamps=0`. Reiniciá el contenedor o llamá `opcache_reset()` desde un endpoint admin.

### IDE no indexa las clases de la imagen

Confirmá que el servicio `devtools-sync` corrió y la carpeta `host-vendor/` está poblada en el host. Después configurá el include path del IDE:

`.vscode/settings.json`:
```json
{
  "intelephense.environment.includePaths": ["host-vendor"]
}
```

## Limitaciones conocidas

- **PHP 8.0 está EOL desde noviembre 2023**. Para nuevos proyectos preferí PHP 8.1+ o 8.2+.
- **Auto_prepend con phpdotenv en proyectos modernos**: si tu proyecto tiene `vlucas/phpdotenv` en su propio `composer.json` con otra versión, va a haber conflicto. Si no necesitás esa lib desde la imagen, comentá la entrada en `php8.0.30/devtools/composer.json` y rebuildeá.

## Versionado

Esquema semántico `MAJOR.MINOR.PATCH`:

| Tag | Significado |
|---|---|
| `:2.1.0` | Versión específica (immutable, recomendado para CI) |
| `:2` | Última patch del major 2 |
| `:latest` | Última estable (alias del último `:MAJOR`) |

Cambios respecto a la imagen vieja `libelulasoft/php8030` (sin sufijo, single-target):

- Repos separados (`-dev` y `-prod`)
- Multi-target Dockerfile
- Composer split `require` / `require-dev`
- `composer.lock` commiteado
- HEALTHCHECK en prod
- Apache logs vía symlinks (no `sed`)
- Imagen prod tuneada (OPcache, hardening, logs a stdout)
