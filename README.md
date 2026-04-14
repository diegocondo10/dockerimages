# LibelulaSoft — Docker Images

Imágenes PHP+Apache base para proyectos LibelulaSoft. Pensadas para **desarrollo local** (Xdebug activado por defecto). Las imágenes de producción son un step futuro separado.

## Imágenes disponibles

| Imagen | Tag | PHP | Xdebug | Composer |
|---|---|---|---|---|
| `libelulasoft/php7033` | `2`, `2.0.0`, `latest` | 7.0.33 (Debian Stretch) | 2.7.2 — puerto 9000 | 2.2 |
| `libelulasoft/php8030` | `2`, `2.0.0`, `latest` | 8.0.30 (Debian Bullseye) | 3.1.6 — puerto 9003 | 2.7 |

Extensiones incluidas en ambas: `gd`, `soap`, `zip`, `bcmath`, `mongodb`, `imagick`, Apache `mod_rewrite`.

---

## Cómo buildear (desde la raíz del repo)

> **Importante**: el build context es el repo root (no `cd phpX/`). Necesario para incluir `cicd/` y `devtools/` en la imagen.

```bash
# PHP 7.0.33
docker build -t libelulasoft/php7033:2.0.0 -t libelulasoft/php7033:2 -f php7.0.33/Dockerfile .

# PHP 8.0.30
docker build -t libelulasoft/php8030:2.0.0 -t libelulasoft/php8030:2 -f php8.0.30/Dockerfile .

# Sin Xdebug (por ejemplo para entornos staging futuros)
docker build --build-arg ENABLE_XDEBUG=false -t libelulasoft/php7033:2-noxdebug -f php7.0.33/Dockerfile .
```

## Publicar en Docker Hub

```bash
# Snapshot de rollback (ANTES de pisar :latest)
docker tag libelulasoft/php7033:latest libelulasoft/php7033:1-legacy
docker push libelulasoft/php7033:1-legacy

# Push de nueva versión
docker push libelulasoft/php7033:2.0.0
docker push libelulasoft/php7033:2
docker tag  libelulasoft/php7033:2 libelulasoft/php7033:latest
docker push libelulasoft/php7033:latest

# Ídem para php8030
```

## Rollback

```bash
docker pull libelulasoft/php7033:1-legacy
docker tag  libelulasoft/php7033:1-legacy libelulasoft/php7033:latest
docker push libelulasoft/php7033:latest
```

---

## Herramientas CI/CD incluidas

Los binarios `lint.sh` y `zip.sh` están en `/usr/local/bin/` en ambas imágenes.
Los proyectos consumidores pueden invocarlos directamente sin necesitar carpeta `cicd/` propia.

```yaml
# bitbucket-pipelines.yml — ejemplo
- step:
    image: libelulasoft/php8030:latest
    script:
      - lint.sh frontend common
      - zip.sh application.zip
```

Los scripts leen `.lintignore` / `.zipignore` desde el **CWD** del proyecto (funciona con bind-mount en `/var/www/html`).

---

## Dev tools de testing (`/opt/devtools`)

Para proyectos con `vendor/` hardcodeado (como los proyectos PHP 7 legacy sin `composer.json`), ambas imágenes pre-instalan herramientas de testing en `/opt/devtools/` — **completamente aisladas del vendor del proyecto**.

| Binario | PHP 7 | PHP 8 |
|---|---|---|
| `codecept` | — *(ver nota)* | Codeception 5.1 |
| `phpunit` | PHPUnit 6.5 | PHPUnit 9.6 |

Módulos PHP 8 pre-instalados: `module-asserts`, `module-yii2`, `module-phpbrowser`, `module-db`.

> **PHP 7 — Codeception no incluido**: Codeception 4.1 depende transitivamente de `symfony/polyfill-php80`, que usa nullable types (`?Type`) introducidos en PHP 7.1. PHP 7.0.33 no puede parsear ese código aunque `--ignore-platform-reqs` permita instalarlo. Para Codeception en proyectos PHP 7, instalala en el vendor del proyecto con una versión compatible o usá la imagen PHP 8.

```bash
# Desde dentro del contenedor (CWD = /var/www/html)
codecept run
phpunit tests/

# En bitbucket-pipelines con imagen base
- step:
    image: libelulasoft/php7033:latest
    script:
      - codecept run --no-colors
```

> **Prioridad de binarios**: si tu proyecto tiene `./vendor/bin/codecept`, ese gana cuando lo invocás con ruta explícita. El `codecept` de la imagen (en `/usr/local/bin/`) es el fallback para proyectos sin vendor de testing.

---

## Heredar en proyectos consumidores

```dockerfile
FROM libelulasoft/php8030:latest

# Tu configuración adicional aquí
COPY . /var/www/html
```

---

## Tags históricos

| Tag | Descripción |
|---|---|
| `:latest` | Apunta siempre a la versión estable actual |
| `:2`, `:2.0.0` | Imágenes multi-stage optimizadas (actual) |
| `:1-legacy` | Snapshot de la versión pre-refactor (rollback) |
