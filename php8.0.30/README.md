# PHP 8.0.30 — Imágenes Docker LibelulaSoft

Imagen base PHP 8.0.30 + Apache. Pensada para proyectos modernos que SÍ pueden usar `composer require` en su propio repositorio.

> ⚠️ **Estado actual**: imagen single-target (legacy del esquema 2.0.x). El refactor a multi-target `--dev` / `--prod` (igual al de `php7.0.33`) está planificado como **Fase 2** del rediseño. Ver [Roadmap](#roadmap) más abajo.

## Imagen publicada

| Imagen | Tags | Tamaño |
|---|---|---|
| [`libelulasoft/php8030`](https://hub.docker.com/r/libelulasoft/php8030) | `2.0.0`, `2`, `latest` | ~700 MB |

## Stack técnico

| Componente | Versión |
|---|---|
| Base image | `php:8.0-apache` (Debian Bullseye) |
| PHP | 8.0.30 |
| Apache | 2.4.x con `mod_rewrite` |
| Composer | 2.7 |
| Xdebug | 3.1.6 — protocolo Xdebug 3 puerto 9003 (configurable con `ARG ENABLE_XDEBUG`) |
| MongoDB driver | mongodb 1.11.0 (PECL) |
| Imagick | imagick 3.7.0 (PECL) |

### Extensiones PHP habilitadas

`gd`, `soap`, `zip`, `bcmath`, `mongodb`, `imagick`, `xdebug` (toggleable).

### Utilidades del sistema

`git`, `vim`, `nano`, `bash-completion`, `unzip`, `zip`.

## Devtools (`/opt/devtools/vendor`)

A diferencia de PHP 7.0.33, esta imagen incluye **Codeception 5** porque PHP 8 sí soporta los nullable types y typed properties que requiere.

`devtools/composer.json`:

```json
{
    "require": {
        "php": "~8.0.30",
        "phpunit/phpunit": "^9.6",
        "codeception/codeception": "^5.0",
        "codeception/module-asserts": "^3.0",
        "codeception/module-yii2": "^1.1",
        "codeception/module-phpbrowser": "^3.0",
        "codeception/module-db": "^3.0"
    }
}
```

Symlinks de testing en PATH:

| Bin | Sirve para |
|---|---|
| `/usr/local/bin/codecept` | Codeception |
| `/usr/local/bin/phpunit` | PHPUnit |

> **Diferencia con PHP 7.0.33**: en PHP 8 las libs van todas en `require` (no hay split aún). Esto cambia con la **Fase 2** del refactor (multi-target). Por ahora la imagen es single-purpose: dev local + CI.

## Cómo buildear

> Build context = repo root (no `cd php8.0.30/`). Necesario para incluir `cicd/` y `devtools/`.

```bash
# Build estándar (Xdebug habilitado)
docker build \
    -t libelulasoft/php8030:2.0.0 \
    -t libelulasoft/php8030:2 \
    -t libelulasoft/php8030:latest \
    -f php8.0.30/Dockerfile .

# Sin Xdebug (debugging sin overhead)
docker build --build-arg ENABLE_XDEBUG=false \
    -t libelulasoft/php8030:2-noxdebug \
    -f php8.0.30/Dockerfile .
```

## Cómo publicar

```bash
docker login -u libelulasoft

docker push libelulasoft/php8030:2.0.0
docker push libelulasoft/php8030:2
docker push libelulasoft/php8030:latest
```

## Cómo usar

### Desarrollo local (`docker-compose.yaml`)

```yaml
services:
  web:
    image: libelulasoft/php8030:latest
    ports:
      - "8082:80"
    volumes:
      - .:/var/www/html
    environment:
      - APACHE_RUN_USER=www-data
      - APACHE_RUN_GROUP=www-data
```

### Bitbucket Pipelines (CI)

```yaml
pipelines:
  default:
    - step:
        image: libelulasoft/php8030:latest
        script:
          - lint.sh frontend common
          - codecept run --no-colors
          - zip.sh application.zip
```

### Heredar en proyectos consumidores

```dockerfile
FROM libelulasoft/php8030:latest

COPY . /var/www/html
RUN chown -R www-data:www-data /var/www/html

WORKDIR /var/www/html
```

## Filosofía vs PHP 7.0.33

| Decisión | PHP 7.0.33 | PHP 8.0.30 |
|---|---|---|
| Proyecto consumidor maneja sus deps con Composer | ❌ (vendor hardcodeado, no se puede tocar) | ✅ |
| Imagen base trae libs runtime (`phpdotenv`) | ✅ (necesario para legacy) | ❌ (cada proyecto lo agrega a su composer) |
| Imagen base trae herramientas de testing | ✅ (PHPUnit) | ✅ (PHPUnit + Codeception 5) |
| `auto_prepend_file` | ✅ (devtools globalmente disponibles) | ❌ (proyectos modernos cargan su propio autoloader) |

> Esta filosofía cambia tras la **Fase 2** — PHP 8 también va a tener su `-dev` y `-prod` con tooling centralizado pero respetando que los proyectos manejan sus propias deps de runtime.

## Xdebug 3 — diferencia con PHP 7

Xdebug 3.x cambió el protocolo. Si venís de PHP 7 (Xdebug 2.7 puerto 9000), tenés que actualizar la config del cliente IDE para PHP 8:

| Setting | PHP 7 (Xdebug 2.x) | PHP 8 (Xdebug 3.x) |
|---|---|---|
| Modo activado | `xdebug.remote_enable=1` | `xdebug.mode=debug` |
| Inicio automático | `xdebug.remote_autostart=1` | `xdebug.start_with_request=yes` |
| Host del cliente | `xdebug.remote_host=host.docker.internal` | `xdebug.client_host=host.docker.internal` |
| Puerto | `xdebug.remote_port=9000` | `xdebug.client_port=9003` |

**En tu IDE (VSCode / PhpStorm)**, configurá el listener para puerto **9003** cuando uses esta imagen.

## Scripts CI/CD incluidos

Disponibles en `/usr/local/bin/`:

| Script | Función | Lee config de |
|---|---|---|
| `lint.sh` | Análisis de sintaxis PHP recursivo | `.lintignore` del CWD |
| `zip.sh` | Empaqueta el proyecto para deploy | `.zipignore` del CWD |

## Roadmap

### Fase 2 — refactor multi-target (próximo paso)

Replicar el modelo de `php7.0.33`:

- **`libelulasoft/php8030-dev`** — desarrollo local + CI:
  - Xdebug 3
  - Composer 2.7
  - PHPUnit 9, Codeception 5 + módulos Yii2
  - Scripts CI/CD (`lint.sh`, `zip.sh`, `sync-dependencies.sh`)
  - Auto_prepend para devtools
- **`libelulasoft/php8030-prod`** — runtime ECS:
  - Sin Xdebug, sin Composer, sin tooling
  - OPcache tuneado para alta carga
  - Logs Apache + PHP a stdout/stderr
  - Hardening (`expose_php=0`, `ServerTokens Prod`, etc.)
  - HEALTHCHECK incluido
  - Apache logs vía symlinks (`ln -sf /dev/stderr ...`) en vez de `sed` frágil
  - `composer.lock` commiteado para reproducibilidad bit-a-bit

### Mejoras a aplicar (de la auditoría de PHP 7.0.33)

Antes de codear PHP 8:
1. ✅ HEALTHCHECK desde el primer commit
2. ✅ `composer.lock` commiteado en `php8.0.30/devtools/`
3. ✅ Apache logs vía symlinks (no `sed`)
4. ✅ COPY explícito de `.ini` files en stage prod (no copy-todo + rm)
5. ⚠️ Considerar `USER www-data` con `Listen 8080` para defense-in-depth

## Troubleshooting

### Xdebug no rompe en mi IDE

- Verificá que el IDE escuche en puerto **9003** (no 9000 como PHP 7)
- En Windows/WSL, el host es `host.docker.internal` — solo funciona en Docker Desktop
- Confirmá que `ENABLE_XDEBUG` no esté en `false`

### Codeception no encuentra `module-yii2`

Está pre-instalado en `/opt/devtools/vendor/codeception/module-yii2`. Si tu proyecto tiene su propio `vendor/`, asegurate de invocar `codecept` desde la imagen (`/usr/local/bin/codecept`) y no desde tu vendor local que puede no tener el módulo.

## Limitaciones conocidas

- **PHP 8.0 está EOL desde noviembre 2023**. Para nuevos proyectos preferí PHP 8.1+ o 8.2+.
- **Imagen single-target (legacy)**: hasta que se complete Fase 2, no hay separación dev/prod. La misma imagen incluye Xdebug y tooling, lo cual es subóptimo para producción. No usar tal cual está en runtime de alta carga.

## Versionado

Esquema semántico `MAJOR.MINOR.PATCH`:

| Tag | Significado |
|---|---|
| `:2.0.0` | Versión específica (immutable) |
| `:2` | Última patch del major 2 |
| `:latest` | Última estable |
