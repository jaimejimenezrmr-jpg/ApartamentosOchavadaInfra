# Puesta en marcha desde cero (entorno para el equipo)

Objetivo: tener `https://apartamentosochavada.com` funcionando en un servidor propio, visible solo para el
equipo hasta el lanzamiento público (finales de enero / principios de febrero de 2027).

| Pieza | Elección | Coste orientativo |
|---|---|---|
| Dominio | `apartamentosochavada.com` en **Cloudflare Registrar** (precio de coste) | ~10 $/año |
| DNS, TLS y protección | **Cloudflare** (plan gratuito) | 0 € |
| Acceso solo para el equipo | **Cloudflare Zero Trust · Access** (gratis hasta 50 usuarios) | 0 € |
| Servidor | **OVHcloud VPS-1**: 2 vCores / 4 GB / 40 GB NVMe, Ubuntu 24.04, centro de datos en Francia | desde 4,61 €/mes con IVA (más sin compromiso; confirmar en el pedido) |
| Copias del servidor | Copia automática diaria **incluida** en el VPS | 0 € |
| Tráfico | Ilimitado | 0 € |
| Código | Repositorios **privados** en GitHub | 0 € |

> Por qué OVHcloud y no Google Cloud/Azure: por ~10 €/mes da una máquina que en esas nubes costaría 30–40 € más
> tráfico, con panel, cortafuegos de red, snapshots y copia diaria. Empresa europea, datos en la UE (RGPD).
> Hetzner sería equivalente, pero en noviembre de 2026 sus planes compartidos no estaban disponibles.
>
> **Por qué VPS-1**: en noviembre de 2026 los VPS-2 y VPS-3 de OVHcloud estaban agotados. El VPS-1 basta para el
> equipo y para el arranque: la aplicación en marcha usa unos 2,4 GB (los límites por defecto de
> `docker-compose.yml`). Lo único más lento es compilar las imágenes en el servidor, que se hace de una en una
> (fase G). Si al hacer el pedido el VPS-2 vuelve a estar disponible, elíjalo; y si no, cuando haya stock puede
> **ampliar el VPS-1 a VPS-2 desde el panel, sin reinstalar** (sección «Ampliar el servidor»).

Tiempo estimado: 2–3 horas la primera vez (la emisión de certificados y la primera compilación son lo más lento).

---

## Fase A · Cuentas (una sola vez)

1. **Cloudflare**: cree la cuenta en https://dash.cloudflare.com con `apartamentosochavada@gmail.com` y active la
   verificación en dos pasos (My Profile → Authentication).
2. **OVHcloud**: cree la cuenta en https://www.ovhcloud.com/es-es/ (Mi cuenta → Crear una cuenta) con los datos
   fiscales del negocio, para que las facturas salgan a su nombre. Puede pedir verificar identidad y método de
   pago antes de activar el primer pedido. Active la verificación en dos pasos (Mi cuenta → Seguridad).
3. **GitHub**: la cuenta `jaimejimenezrmr-jpg` con los tres repositorios **privados** `ApartamentosOchavadaBackend`,
   `ApartamentosOchavadaFront` y `ApartamentosOchavadaInfra` (ya creados y subidos). Active la verificación en dos
   pasos y compruebe que los tres son privados (Settings → General → Danger Zone → visibilidad).
4. **Stripe**: cuenta en https://dashboard.stripe.com. Para el entorno del equipo use **solo las claves de test**
   (`sk_test_…`, `pk_test_…`): se pueden probar reservas con tarjetas de prueba sin cobros reales.
5. **Gmail**: en la cuenta de Google active la verificación en dos pasos y cree una **contraseña de aplicación**
   (Cuenta de Google → Seguridad → Contraseñas de aplicaciones). Será `SMTP_PASSWORD`.
6. **TTLock**: solicite la cuenta de desarrollador en https://euopen.ttlock.com (la aprueban ellos). Cuando llegue
   la cerradura, la cuenta de propietario de la app TTLock será `TTLOCK_USERNAME`/`TTLOCK_PASSWORD`.

## Fase B · Dominio

1. Cloudflare → **Domain Registration → Register Domains** → busque `apartamentosochavada.com` y regístrelo
   (renovación automática activada, privacidad WHOIS incluida).
   - Si prefiriera `.es`: regístrelo en un registrador español (DonDominio, Hostealo…) y en Cloudflare
     **Add a site** → cambie en el registrador los servidores DNS por los dos que le indique Cloudflare.
2. Cloudflare → el dominio → **SSL/TLS → Overview**: modo **Full (strict)**.
3. **SSL/TLS → Edge Certificates**: activar *Always Use HTTPS* y *Minimum TLS 1.2*.
4. **Token para los certificados** (lo usa Caddy): My Profile → API Tokens → Create Token → plantilla
   **Edit zone DNS** → *Zone Resources: Include → Specific zone → apartamentosochavada.com* → crear y **guardar el
   token** (solo se muestra una vez). Será `CLOUDFLARE_API_TOKEN`.

## Fase C · Servidor

1. **Clave SSH** en su ordenador (PowerShell):
   ```powershell
   ssh-keygen -t ed25519 -C "ochavada-admin"
   ```
   Copie el contenido de `C:\Users\<usuario>\.ssh\id_ed25519.pub`.
2. **Pedido del VPS**: https://www.ovhcloud.com/es-es/vps/ → **VPS-1** (o VPS-2 si está disponible) → Configurar:
   - Localización: **Gravelines** o **Estrasburgo** (Francia). Evite la «Local Zone» de Madrid: tiene menos
     funciones (copias, cortafuegos) y la latencia desde Francia es de pocos milisegundos.
   - Imagen: **Ubuntu 24.04** (sin aplicaciones preinstaladas).
   - Clave SSH: pegue la clave pública del paso 1. Así no se envía contraseña por email.
   - Copia de seguridad automática: compruebe que figura la **diaria incluida**.
   - Duración: sin compromiso (mensual) o con compromiso de 12 meses si quiere el precio más bajo.
   - Al terminar, en el panel (**Bare Metal Cloud → Servidores privados virtuales**) anote la IPv4 y, si aparece,
     la IPv6. Cambie el nombre visible a `ochavada-prod`.
3. **Cortafuegos de red de OVHcloud** (actúa antes de llegar al servidor, por eso protege también los puertos que
   publica Docker): panel → **Bare Metal Cloud → Network → Direcciones IP públicas** → en la IPv4 del VPS,
   «…» → **Crear el Edge Network Firewall** → activarlo y añadir reglas, en este orden de prioridad:
   - 0 · Autorizar TCP, puerto destino 22, IP origen = su IP fija (si no tiene IP fija, sáltese esta regla y la
     de cierre del 22; el acceso seguirá limitado a su clave SSH y fail2ban).
   - 1 · Autorizar TCP, puerto destino 80.
   - 2 · Autorizar TCP, puerto destino 443.
   - 3 · Autorizar UDP, puerto destino 443.
   - 4 · Autorizar TCP con la opción *established* (respuestas a conexiones que inicia el servidor: Docker,
     Stripe, TTLock, GitHub…).
   - 5 · Autorizar UDP, puerto origen 53 (respuestas DNS) y 6 · UDP puerto origen 123 (hora, NTP).
   - 19 · Denegar IPv4 (todo lo demás).
   (Opcional, más seguro: limitar 80/443 a los rangos de https://www.cloudflare.com/ips/, una regla por rango.)

   Si los nombres de las opciones del panel difieren, lo importante es el resultado: entrada solo a 22 (desde su
   IP), 80 y 443; respuestas permitidas; todo lo demás denegado. Ese cortafuegos filtra IPv4; por IPv6 solo
   quedan expuestos 22/80/443 (PostgreSQL y el backend no publican puertos). Si una regla le dejara fuera, entre
   por la consola **KVM** del panel del VPS y corríjala.
4. **Primera conexión y endurecimiento** (sustituya `IP` por la IPv4 del servidor). OVHcloud crea el usuario
   `ubuntu` con `sudo`; root no tiene acceso por SSH:
   ```bash
   ssh ubuntu@IP
   ```
   Dentro del servidor, abra una sesión de administrador:
   ```bash
   sudo -i
   ```
   ```bash
   apt update && apt -y full-upgrade
   adduser ochavada
   usermod -aG sudo ochavada
   rsync --archive --chown=ochavada:ochavada /home/ubuntu/.ssh /home/ochavada
   ```
   Solo claves SSH y sin root (el fichero `00-…` tiene prioridad sobre el que deja la imagen de OVHcloud):
   ```bash
   printf 'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' > /etc/ssh/sshd_config.d/00-ochavada.conf
   sshd -t && systemctl restart ssh
   ```
   ```bash
   apt -y install unattended-upgrades fail2ban git
   dpkg-reconfigure -plow unattended-upgrades
   timedatectl set-timezone Europe/Madrid
   ```
   Memoria de intercambio (imprescindible con 4 GB: la compilación de las imágenes la necesita). Con
   `swappiness` bajo, el sistema solo la usa cuando falta RAM, no en el día a día:
   ```bash
   fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
   echo '/swapfile none swap sw 0 0' >> /etc/fstab
   echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf && sysctl --system
   ```
   Desde otra terminal compruebe que entra como `ochavada` **antes** de cerrar la sesión de `ubuntu`:
   ```bash
   ssh ochavada@IP
   ```
   Ya como `ochavada`, elimine el usuario genérico para dejar un único acceso:
   ```bash
   sudo deluser --remove-home ubuntu
   ```
5. **Docker** (repositorio oficial):
   ```bash
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker ochavada
   ```
   Cierre la sesión y vuelva a entrar; compruebe:
   ```bash
   docker version && docker compose version
   ```

## Fase D · DNS

Cloudflare → el dominio → **DNS → Records**:

| Tipo | Nombre | Contenido | Proxy |
|---|---|---|---|
| A | `@` | IPv4 del servidor | Activado (nube naranja) |
| A | `www` | IPv4 del servidor | Activado |
| AAAA | `@` | IPv6 del servidor | Activado |
| AAAA | `www` | IPv6 del servidor | Activado |

Los registros AAAA solo si el VPS tiene IPv6 activa (`ip -6 addr show scope global` muestra una dirección y
`ping -6 -c 3 one.one.one.one` responde). Si no, deje solo los A: Cloudflare sigue sirviendo la web por IPv6 a
los visitantes.

## Fase E · Código en el servidor

Los tres repositorios privados ya están en GitHub (`jaimejimenezrmr-jpg/ApartamentosOchavadaBackend`,
`…/ApartamentosOchavadaFront` y `…/ApartamentosOchavadaInfra`). El servidor los clona con **deploy keys** de solo
lectura: si alguien entrara en el servidor, no podría modificar el código ni ver otros repositorios.

1. **Una clave por repositorio** (GitHub no permite usar la misma deploy key en dos repositorios). En el servidor,
   como `ochavada`:
   ```bash
   for r in Backend Front Infra; do
     ssh-keygen -t ed25519 -f ~/.ssh/deploy_${r,,} -N "" -C "ochavada-prod-${r,,}"
     printf 'Host github-%s\n  HostName github.com\n  User git\n  IdentityFile ~/.ssh/deploy_%s\n  IdentitiesOnly yes\n\n' "${r,,}" "${r,,}" >> ~/.ssh/config
     echo "=== ApartamentosOchavada$r"; cat ~/.ssh/deploy_${r,,}.pub
   done
   chmod 600 ~/.ssh/config
   ```
2. **Añada cada clave a su repositorio**: en GitHub, el repositorio → Settings → Deploy keys → **Add deploy key**.
   Título `ochavada-prod`, pegue la línea `ssh-ed25519 …` que salió bajo su nombre y deje **sin marcar**
   *Allow write access*. Repita en los tres.
3. **Clone** los tres al mismo nivel (los nombres de carpeta son los que espera `scripts/deploy.sh`):
   ```bash
   sudo mkdir -p /opt/ochavada && sudo chown ochavada:ochavada /opt/ochavada && cd /opt/ochavada
   ```
   ```bash
   git clone github-backend:jaimejimenezrmr-jpg/ApartamentosOchavadaBackend.git
   ```
   ```bash
   git clone github-front:jaimejimenezrmr-jpg/ApartamentosOchavadaFront.git
   ```
   ```bash
   git clone github-infra:jaimejimenezrmr-jpg/ApartamentosOchavadaInfra.git
   ```
   La primera vez SSH pregunta si confía en github.com: compruebe que la huella mostrada es
   `SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU` (la publicada por GitHub para ED25519) y responda `yes`.

   Si un `git clone` responde *Permission denied* o *Repository not found*, la clave de ese repositorio no está
   añadida en su Deploy keys (o se pegó en otro repositorio).

## Fase F · Configuración

```bash
cd /opt/ochavada/ApartamentosOchavadaInfra
cp .env.example .env && cp backend.env.example backend.env
chmod 600 .env backend.env
```

Genere los secretos en el propio servidor:
```bash
openssl rand -base64 32   # POSTGRES_PASSWORD
openssl rand -base64 32   # APP_CREDENTIALS_KEY (otro distinto)
openssl rand -base64 48   # JWT_SECRET
```

Rellene con `nano .env`:
- `DOMAIN=apartamentosochavada.com`, `ACME_EMAIL`, `CLOUDFLARE_API_TOKEN`, `POSTGRES_PASSWORD`.
- Datos del establecimiento (`PROPERTY_*`); el teléfono y el registro de turismo cuando los tenga.

Rellene con `nano backend.env`, para el entorno del equipo:
- `JWT_SECRET`, `APP_CREDENTIALS_KEY`.
- Stripe **de test**: `STRIPE_SECRET_KEY=sk_test_…`, `STRIPE_PUBLISHABLE_KEY=pk_test_…` (el webhook, en la fase H).
- Gmail: `SMTP_PASSWORD` = contraseña de aplicación.
- `TTLOCK_ENABLED=false` hasta tener la cerradura; `SES_ENABLED=false`; `BEDS24_ENABLED=false`;
  `VERIFACTU_ENABLED=false`.
- `INVOICE_ISSUER_NAME` e `INVOICE_ISSUER_TAX_ID` con los datos fiscales reales.
- Primer administrador: `APP_BOOTSTRAP_ADMIN_EMAIL`, `APP_BOOTSTRAP_ADMIN_PASSWORD` (larga y única; después
  podrá cambiarla en Backoffice → Mi cuenta).

## Fase G · Arranque

El script de despliegue comprueba la configuración y el disco, compila las imágenes **de una en una** (con 4 GB,
compilarlas a la vez agota la memoria) y arranca todo esperando a que esté sano:
```bash
bash scripts/deploy.sh --no-pull
```
La primera vez tarda 20–40 minutos con 2 vCores; las siguientes, bastante menos gracias a la caché. Si termina
con error, o para seguir el estado:
```bash
docker compose ps
```
```bash
docker compose logs -f caddy backend
```

Cuando todos los servicios estén `healthy` y Caddy haya obtenido el certificado (`certificate obtained
successfully` en sus registros), abra `https://apartamentosochavada.com`.

Después **vacíe** `APP_BOOTSTRAP_ADMIN_EMAIL` y `APP_BOOTSTRAP_ADMIN_PASSWORD` en `backend.env` y aplique:
```bash
docker compose up -d backend
```

## Fase H · Solo para el equipo hasta el lanzamiento (Cloudflare Access)

1. Cloudflare → **Zero Trust** → elija el plan **Free** (puede pedir un método de pago aunque no cobre).
2. **Access → Applications → Add an application → Self-hosted**:
   - Dominio: `apartamentosochavada.com` (todo el sitio) y otra entrada para `www.apartamentosochavada.com`.
   - Política **Allow** · *Include → Emails*: los correos del equipo. Método de acceso: código de un solo uso
     por email (One-time PIN).
3. **Excepción para los webhooks** (Stripe y Beds24 no pueden identificarse en Access): otra aplicación
   self-hosted con la ruta `apartamentosochavada.com/api/v1/webhooks/*` y una política **Bypass** · *Everyone*.
4. Cada miembro del equipo entra con su email y un código; además necesita su usuario del backoffice.
5. El día del lanzamiento basta con eliminar la aplicación de Access para que la web sea pública.

## Fase I · Integraciones del entorno del equipo

- **Stripe (test)**: Developers → Webhooks → Add endpoint `https://apartamentosochavada.com/api/v1/webhooks/stripe`
  con los eventos `payment_intent.succeeded`, `payment_intent.payment_failed`, `payment_intent.processing`,
  `payment_intent.requires_action`, `payment_intent.canceled`. Copie el *signing secret* a `STRIPE_WEBHOOK_SECRET`
  y aplique con `docker compose up -d backend`. Pruebe una reserva con la tarjeta `4242 4242 4242 4242`.
- **Email**: haga una reserva de prueba con su correo y compruebe que llega la confirmación con el enlace a
  «Mi estancia».
- **TTLock** (cuando llegue la cerradura): empareje cerradura y pasarela en la app TTLock con la cuenta de
  propietario, rellene `TTLOCK_*` y `TTLOCK_ENABLED=true`, aplique, y en Backoffice → Cerraduras añada la
  cerradura desde la cuenta TTLock y asígnela a su unidad.

## Fase J · Carga inicial en el backoffice

En `https://apartamentosochavada.com/backoffice` con el administrador:
1. **Catálogo → Servicios**: equipamiento (Wi-Fi, aire acondicionado, cocina…).
2. **Catálogo → Tipologías**: cada tipo de habitación, con descripción, capacidad, precio «desde» y fotos
   (URL https de una imagen alojada; la subida directa aún no existe).
3. **Catálogo → Unidades**: las 14 habitaciones con su número.
4. **Catálogo → Planes de tarifa** y **Tarifas**: precios base, temporadas y estancias mínimas.
5. **Cerraduras**: la entrada principal (tipo «Entrada principal») y cada habitación (tipo «Unidad»).

## Fase K · Usuarios del equipo

En Backoffice → **Usuarios** cree un usuario por persona (nunca cuentas compartidas):
- **Recepción**: reservas, rack, huéspedes, cobros, facturas, SES y cerraduras.
- **Limpieza**: solo el tablero de limpieza.
- **Administración**: además catálogo, tarifas, usuarios y channel manager.

Al crearlo se muestra una contraseña temporal **una sola vez**: entréguesela en persona o por teléfono. En su primer
acceso tendrá que elegir la suya. Si alguien deja el equipo, desactívelo (sus sesiones se cierran al momento); si
pierde el móvil, use «Cerrar sesiones»; si olvida la contraseña, «Resetear contraseña». Recuerde añadir también su
email en Cloudflare Access (fase H).

## Mantenimiento

Actualizar a una versión nueva del código:
```bash
cd /opt/ochavada/ApartamentosOchavadaInfra && bash scripts/deploy.sh
```
Hace `git pull` de los tres repositorios, compila de una en una y sustituye los contenedores. Mientras compila, la
versión anterior sigue atendiendo; el corte es solo el reinicio final (unos segundos). Las migraciones de la base
de datos se aplican solas al arrancar el backend.

Limpieza mensual de imágenes antiguas y de la caché de compilación (el disco es de 40 GB):
```bash
docker image prune -f && docker builder prune -f --filter until=720h
```
```bash
df -h /
```

Copias: además de la copia automática diaria del VPS (panel de OVHcloud → el VPS → Copia de seguridad
automática), el servicio `db-backup` deja un volcado diario en `/opt/ochavada/ApartamentosOchavadaInfra/backups`;
copie ese directorio periódicamente fuera del servidor. Antes de una actualización delicada, haga además un
**snapshot** manual desde el panel.

Memoria: cada contenedor tiene un límite (`mem_limit` en `docker-compose.yml`, unos 2,4 GB en total con los
valores por defecto). Para ver el consumo real:
```bash
docker stats --no-stream
```
Si un contenedor se reinicia solo y en `docker compose ps` aparece `OOMKilled`, súbale el límite en `.env`
(`BACKEND_MEM_LIMIT=1536m`, por ejemplo) y aplique con `docker compose up -d`.

### Ampliar el servidor (VPS-1 → VPS-2)

Cuando haya stock, desde el panel de OVHcloud → el VPS → **Modelo / Cambiar de oferta**: se reinicia con más RAM,
CPU y disco, conservando datos, IP y configuración (no se puede volver a un modelo inferior). Después:
1. Amplíe la partición si `df -h /` no muestra el disco nuevo: `sudo growpart /dev/sda 1 && sudo resize2fs /dev/sda1`
   (compruebe antes el nombre del disco con `lsblk`).
2. Suba los límites en `.env`: `BACKEND_MEM_LIMIT=1536m`, `POSTGRES_MEM_LIMIT=1g`, `FRONTEND_MEM_LIMIT=512m`,
   `CADDY_MEM_LIMIT=256m`, `BACKUP_MEM_LIMIT=256m`, y aplique con `docker compose up -d`.

## Lista de comprobación final

- [ ] `https://apartamentosochavada.com` pide el código de Cloudflare Access y luego muestra la web.
- [ ] `https://www.apartamentosochavada.com` redirige al dominio principal.
- [ ] El backoffice permite entrar con el administrador; las variables `APP_BOOTSTRAP_ADMIN_*` ya están vacías.
- [ ] Una reserva de prueba con tarjeta de test queda confirmada y llega el email.
- [ ] `docker compose ps` muestra todo `healthy` y hay un fichero de hoy en `backups/`.
- [ ] En el panel de OVHcloud la copia automática del VPS figura activa y el Edge Network Firewall está activado.
- [ ] `ssh root@IP` y el acceso con contraseña son rechazados; `ssh ochavada@IP` entra con la clave.
