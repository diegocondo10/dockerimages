# LibelulaSoft — Docker Images

Imágenes PHP+Apache base para proyectos LibelulaSoft. Desde la versión **2.1.0**, cada PHP expone dos imágenes con propósitos distintos:

| Imagen | Para qué | Características |
|---|---|---|
| `libelulasoft/phpXXXX-dev` | Desarrollo local + Bitbucket Pipelines | Xdebug, Composer, PHPUnit, devtools, scripts CI/CD |
| `libelulasoft/phpXXXX-prod` | Runtime productivo (AWS ECS) | OPcache tuneado, sin Xdebug, sin tooling, logs a stdout/stderr |

Ambas comparten extensiones (`gd`, `soap`, `zip`, `bcmath`, `mongodb`, `imagick`) y traen Apache `mod_rewrite`. Las dos también traen `auto_prepend_file` apuntando a `/opt/devtools/vendor/autoload.php` para que proyectos legacy con vendor hardcodeado puedan usar libs como `phpdotenv` sin tocar su composer.

## Imágenes disponibles

| Directorio | DEV | PROD | PHP |
|---|---|---|---|
| `php7.0.33/` | `libelulasoft/php7033-dev` | `libelulasoft/php7033-prod` | 7.0.33 (Debian Stretch) |
| `php8.0.30/` | `libelulasoft/php8030` *(refactor pendiente)* | — | 8.0.30 |

---

## Cómo buildear (desde la raíz del repo)

> **Importante**: el build context es el repo root (no `cd php7.0.33/`). Necesario para incluir `cicd/` y `devtools/` en la imagen.

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

# DEV sin Xdebug (opcional)
docker build --target dev --build-arg ENABLE_XDEBUG=false \
    -t libelulasoft/php7033-dev:2.1.0-noxdebug \
    -f php7.0.33/Dockerfile .
```

El stage `builder` se cachea entre `--target dev` y `--target prod`, así que el segundo build es mucho más rápido si el primero ya pasó.

## Publicar en Docker Hub

```bash
docker login -u libelulasoft

docker push --all-tags libelulasoft/php7033-dev
docker push --all-tags libelulasoft/php7033-prod
```

> Para los repos `*-dev` y `*-prod` la primera vez Docker Hub los crea al primer push (necesitás permiso de write en la organización `libelulasoft/`).

## Rollback

Cada imagen tiene tags semánticos `:MAJOR.MINOR.PATCH`. Para volver a una versión:

```bash
docker pull libelulasoft/php7033-dev:2.0.0
docker tag  libelulasoft/php7033-dev:2.0.0 libelulasoft/php7033-dev:latest
docker push libelulasoft/php7033-dev:latest
```

---

## Diferencias DEV vs PROD (PHP 7.0.33)

| Aspecto | DEV | PROD |
|---|---|---|
| **Xdebug** | ✓ (configurable con `ENABLE_XDEBUG`) | ✗ (eliminado) |
| **Composer** | ✓ | ✗ |
| **`/opt/devtools`** | full (require + require-dev) | trimmed (`--no-dev`) |
| **PHPUnit (`/usr/local/bin/phpunit`)** | ✓ | ✗ |
| **`sync-dependencies.sh`** | ✓ | ✗ |
| **`lint.sh`, `zip.sh`** | ✓ | ✗ |
| **`auto_prepend_file`** | ✓ | ✓ |
| **OPcache** | default | tuneado para alta carga |
| **`display_errors`** | default | `0` (logs a stderr) |
| **Apache logs** | default | a stdout/stderr (CloudWatch) |
| **`expose_php`** | default | `0` |
| **Hardening Apache** | default | `ServerTokens Prod`, `ServerSignature Off`, `TraceEnable Off` |

---

## Devtools en la imagen base (`/opt/devtools`)

`php7.0.33/devtools/composer.json` define qué libs vienen pre-instaladas:

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

- **`require`** → entra en `-dev` Y en `-prod` (libs runtime)
- **`require-dev`** → solo en `-dev` (testing/análisis)

El `auto_prepend_file` carga `/opt/devtools/vendor/autoload.php` en cada request, así proyectos consumidores pueden hacer `use Dotenv\Dotenv;` sin agregarlo a su propio composer.

> **Cuándo NO meter algo en `require`**: si la lib es comúnmente usada en proyectos modernos que SÍ pueden hacer `composer require`, dejala fuera y que cada proyecto la maneje. La imagen base apunta a darles oxígeno a los legacy con vendor hardcodeado, no a centralizar todas las dependencias del ecosistema.

---

## Cargar las clases de devtools en runtime (proyectos legacy)

`auto_prepend_file` solo se aplica donde la imagen Docker es el runtime — en local (con `-dev`) y en ECS futuro (con `-prod`). En **AWS EB con PHP nativo** (deploy actual de varios proyectos hasta junio 2026), la imagen no corre, así que la directiva no existe en ese servidor.

Para que un proyecto legacy use `use Dotenv\Dotenv;` **tanto en local como en EB nativo** sin tocar su `composer.json`, agregás una guardia condicional en su bootstrap (ej. `frontend/web/index.php`, `web/index.php`):

```php
// Cargar autoloader de devtools SOLO si todavía no hay un ClassLoader registrado.
// En Docker (-dev/-prod) auto_prepend_file ya lo cargó → guardia false → skip.
// En EB nativo PHP no hay nada cargado → guardia true → include desde host-vendor/.
if (!class_exists(\Composer\Autoload\ClassLoader::class, false)) {
    @include __DIR__ . '/../../host-vendor/autoload.php';
}
require __DIR__ . '/../../vendor/autoload.php';
```

> ⚠️ **Sin la guardia, en local rompe**: si el proyecto corre en Docker con la imagen `-dev`, `auto_prepend_file` ya cargó `/opt/devtools/vendor/autoload.php` (mismo composer hash que `host-vendor/autoload.php`). Un `@include` sin guardia provoca `Cannot redeclare class ComposerAutoloaderInit<hash>`.

Para que esto funcione en EB nativo además hay que **shippear** `host-vendor/` en el bundle de deploy (sacarla del `.zipignore`) y asegurarse de que el sync se ejecute antes del `zip.sh`. Documentar caso a caso en cada proyecto consumidor.

---

## Sincronización al host para indexado IDE

La imagen `-dev` trae `sync-dependencies.sh` en el PATH. Los proyectos consumidores lo invocan vía un servicio init en `docker-compose.yaml`:

```yaml
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
    # ... resto
```

`./host-vendor/` se gitignorea/zipignora y se agrega a `intelephense.environment.includePaths` en `.vscode/settings.json` para que VSCode/PhpStorm autocompleten las clases.

---

## Herramientas CI/CD incluidas (solo `-dev`)

| Script | Función |
|---|---|
| `lint.sh` | Análisis de sintaxis PHP (php -l) recursivo, lee `.lintignore` |
| `zip.sh` | Empaqueta el proyecto para deploy, lee `.zipignore` |
| `sync-dependencies.sh` | Copia `/opt/devtools/vendor` al bind-mount `/host-vendor` |

```yaml
# bitbucket-pipelines.yml — ejemplo
- step:
    image: libelulasoft/php7033-dev:latest
    script:
      - lint.sh frontend common
      - phpunit tests/
      - zip.sh application.zip
```

---

## Heredar en proyectos consumidores

### Para desarrollo local (siempre `-dev`)

```yaml
# docker-compose.yaml
services:
  web:
    image: libelulasoft/php7033-dev:latest
    volumes:
      - .:/var/www/html
    # ...
```

### Para deploy productivo a ECS (a partir de junio)

```dockerfile
# Dockerfile del proyecto
FROM libelulasoft/php7033-prod:latest

COPY . /var/www/html
RUN chown -R www-data:www-data /var/www/html

WORKDIR /var/www/html
```

El proyecto se buildea sobre la base prod, se pushea a ECR, y la task definition de ECS lo referencia.

---

## Migración desde la imagen vieja `libelulasoft/php7033`

La imagen sin sufijo (`libelulasoft/php7033`) queda **obsoleta** desde 2.1.0. Sigue disponible en Docker Hub para rollback de consumidores que aún no migraron, pero no recibirá actualizaciones.

Cambios mínimos en consumidores:

```diff
- image: libelulasoft/php7033:latest
+ image: libelulasoft/php7033-dev:latest
```
