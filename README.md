# Apartamentos Ochavada · Despliegue

Docker Compose con cinco servicios:

| Servicio | Imagen | Función |
|---|---|---|
| `caddy` | `caddy:2` + módulos Cloudflare | HTTPS (Let's Encrypt por DNS-01), HTTP/3, enrutado, cabeceras de seguridad |
| `frontend` | `node:24-alpine` | Angular SSR (web pública, checkout, portal del huésped, backoffice) |
| `backend` | `eclipse-temurin:21-jre-alpine` | API Spring Boot 4 (migraciones Flyway al arrancar) |
| `postgres` | `postgres:16-alpine` | Base de datos (volumen `pgdata`) |
| `db-backup` | `postgres:16-alpine` | `pg_dump` diario con retención |

```
Internet → Cloudflare → caddy :443 ─┬─ /api/*  → backend:8080 ── postgres:5432   (red interna "data")
                                    └─ resto   → frontend:4000 (SSR) → backend
```

- La base de datos está en una red interna sin salida a internet; solo la ven el backend y las copias.
- Ningún puerto salvo 80/443 se publica. `/actuator/*` responde 404 desde fuera.
- Backend y frontend corren sin root, con sistema de ficheros de solo lectura, sin capacidades y con
  `no-new-privileges`. Las imágenes tienen comprobaciones de salud; cada servicio espera a que el anterior esté sano.
- Caddy solo acepta la IP de `CF-Connecting-IP` si la conexión viene de un rango de Cloudflare (lista actualizada
  cada 12 h) y se la pasa al backend como única `X-Forwarded-For` (límites de peticiones, auditoría, aperturas).
- El frontend envía en cada página una Content-Security-Policy con nonce por petición (sin `unsafe-inline` en
  scripts) y rechaza cabeceras `Host` que no sean el dominio (protección SSRF de Angular).

## Estructura

```
ApartamentosOchavada/
├── ApartamentosOchavadaBackend/   (Dockerfile)
├── ApartamentosOchavadaFront/     (Dockerfile)
└── ApartamentosOchavadaInfra/
    ├── docker-compose.yml
    ├── .env.example            → .env           dominio, Cloudflare, base de datos, datos del establecimiento
    ├── backend.env.example     → backend.env    secretos del backend (JWT, Stripe, SMTP, TTLock, SES, Beds24)
    ├── caddy/                  Dockerfile y Caddyfile
    ├── scripts/                backup.sh, restore.sh
    ├── backups/                copias (montado en el contenedor de copias)
    └── secrets/                ficheros opcionales montados en /app/secrets (p. ej. truststore de SES)
```

Los tres directorios deben estar al mismo nivel: Compose construye las imágenes desde `../ApartamentosOchavadaBackend`
y `../ApartamentosOchavadaFront`.

## Requisitos del servidor

- Linux con Docker Engine 24+ y el plugin Compose v2 (BuildKit activado, por defecto).
- 2 vCPU y 4 GB de RAM como mínimo (la compilación de las imágenes es lo más exigente).
- Puertos 80 y 443 (TCP y UDP) abiertos. Recomendado: aceptar en el cortafuegos solo los
  [rangos de Cloudflare](https://www.cloudflare.com/ips/) en esos puertos.

## Cloudflare

1. Registros DNS `A` (y `AAAA` si hay IPv6) para `@` y `www` apuntando al servidor, con el proxy activado (nube naranja).
2. SSL/TLS → modo **Full (strict)**.
3. Token de API (My Profile → API Tokens → plantilla «Edit zone DNS»), limitado a la zona del dominio:
   es `CLOUDFLARE_API_TOKEN`. Caddy lo usa para el reto DNS-01, así que los certificados se obtienen y renuevan
   aunque Cloudflare esté delante.

## Primer despliegue

```bash
cp .env.example .env
```

```bash
cp backend.env.example backend.env
```

Rellenar ambos. Secretos que hay que generar:

```bash
openssl rand -base64 32   # POSTGRES_PASSWORD y APP_CREDENTIALS_KEY (uno distinto para cada uno)
```

```bash
openssl rand -base64 48   # JWT_SECRET
```

```bash
openssl rand -hex 32      # BEDS24_WEBHOOK_TOKEN
```

Para crear el primer administrador, rellene `APP_BOOTSTRAP_ADMIN_*` en `backend.env`. Después:

```bash
docker compose up -d --build
```

```bash
docker compose ps
```

Cuando todos los servicios estén `healthy`, entre en `https://<dominio>/backoffice` con ese administrador
y **vacíe `APP_BOOTSTRAP_ADMIN_*`** en `backend.env`. Después aplique el cambio:

```bash
docker compose up -d backend
```

## Integraciones externas

| Servicio | Configuración |
|---|---|
| Stripe | Webhook `https://<dominio>/api/v1/webhooks/stripe` con los eventos indicados en `backend.env.example` |
| Beds24 | Webhook `https://<dominio>/api/v1/webhooks/beds24`, cabecera `X-Ochavada-Webhook-Token: <BEDS24_WEBHOOK_TOKEN>`; conectar desde Backoffice → Channel manager |
| Gmail (SMTP) | Contraseña de aplicación de la cuenta (verificación en 2 pasos obligatoria) en `SMTP_PASSWORD` |
| TTLock / SES.HOSPEDAJES | Credenciales en `backend.env`; activar con `TTLOCK_ENABLED` / `SES_ENABLED` |

## Operación

Actualizar a una nueva versión del código (recompila y sustituye los contenedores; las migraciones se aplican solas):

```bash
docker compose up -d --build
```

Ver registros:

```bash
docker compose logs -f --tail=200 backend
```

Estado de salud:

```bash
docker compose ps
```

### Copias de seguridad

`db-backup` hace un `pg_dump` cada día a `BACKUP_HOUR` (hora de Madrid), y otro al arrancar si no hay copia de hoy.
Las copias se guardan en `./backups` durante `BACKUP_RETENTION_DAYS` días. **Copie ese directorio fuera del
servidor** (otro proveedor o almacenamiento de objetos): una copia en el mismo disco no protege de su pérdida.

Copia inmediata:

```bash
docker compose restart db-backup
```

Restaurar (sustituye todos los datos actuales):

```bash
docker compose stop backend frontend
```

```bash
docker compose run --rm -e RESTORE_CONFIRM=si --entrypoint /bin/sh db-backup /scripts/restore.sh /backups/ochavada-AAAAMMDD-HHMM.dump
```

```bash
docker compose start backend frontend
```

## Volúmenes

| Volumen | Contenido | ¿Copia? |
|---|---|---|
| `pgdata` | Base de datos | Sí (vía `./backups`) |
| `caddy_data` | Certificados y claves ACME | Recomendable (evita límites de emisión al reinstalar) |
| `caddy_config` | Configuración generada por Caddy | No |
