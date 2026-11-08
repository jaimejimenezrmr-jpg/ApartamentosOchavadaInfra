# Puesta en marcha desde cero (entorno para el equipo)

Objetivo: tener `https://apartamentosochavada.com` funcionando en un servidor propio, visible solo para el
equipo hasta el lanzamiento público (finales de enero / principios de febrero de 2027).

| Pieza | Elección | Coste orientativo |
|---|---|---|
| Dominio | `apartamentosochavada.com` en **Cloudflare Registrar** (precio de coste) | ~10 $/año |
| DNS | **Cloudflare** (plan gratuito, solo DNS: sin proxy, ver fase D) | 0 € |
| HTTPS | Let's Encrypt, obtenido y renovado por Caddy | 0 € |
| Servidor | **Contabo Cloud VPS 4**: 4 vCPU / 8 GB / 100 GB SSD, Ubuntu 24.04, región Unión Europea (Alemania) | 6,66 €/mes con IVA en contrato mensual (+2,42 € de alta una vez); 5,66 €/mes con 12 meses |
| Copias del servidor | **Auto Backup** de Contabo (diaria, 10 versiones) | ~2 €/mes (recomendado) |
| Tráfico | Ilimitado (puerto de 200 Mbit/s) | 0 € |
| Código | Repositorios **privados** en GitHub | 0 € |

> **Por qué Contabo**: en noviembre de 2026 la escasez de memoria RAM dejó sin stock todos los VPS de OVHcloud y
> los planes compartidos de Hetzner. Contabo tenía disponibilidad y da 8 GB por menos de 7 €/mes, el doble de lo
> que necesita la aplicación (en marcha ronda 1 GB; los límites de `docker-compose.yml` suman 3,5 GB). Empresa
> alemana, datos en la UE (RGPD).
>
> A cambio, su CPU es compartida con más clientes, el disco es SSD (no NVMe) y el soporte es más lento: para el
> equipo y 14 habitaciones sobra. Elija el **contrato mensual**: cuesta 1 € más al mes, pero no le ata si el
> proveedor no le convence. Cambiar de proveedor es sencillo: todo va en Docker y la base de datos tiene volcado
> diario (sección «Cambiar de servidor»).

Tiempo estimado: 2–3 horas la primera vez (la emisión de certificados y la primera compilación son lo más lento).

---

## Fase A · Cuentas (una sola vez)

1. **Cloudflare**: cree la cuenta en https://dash.cloudflare.com con `apartamentosochavada@gmail.com` y active la
   verificación en dos pasos (My Profile → Authentication).
2. **Contabo**: la cuenta se crea durante el primer pedido (fase C) con los datos fiscales del negocio, para que
   las facturas salgan a su nombre. A los clientes nuevos a veces les piden verificar la identidad antes de
   entregar el servidor. Después active la verificación en dos pasos en el panel de cliente
   (https://my.contabo.com).
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
2. Cloudflare → el dominio → **SSL/TLS → Overview**: modo **Full (strict)** (solo influye si algún día se activa el
   proxy; sin proxy los visitantes conectan directamente con el certificado de Caddy).
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
2. **Pedido del VPS**: https://contabo.com/es/vps/ → **Cloud VPS 4** → Seleccionar (si le ofrece pasar al
   Cloud VPS 6, no hace falta) → en el configurador:
   - Duración del contrato: **1 mes** (o 12 meses si ya lo tiene claro; evite 24 meses: se paga por adelantado).
   - Región: **Unión Europea** (gratis).
   - Almacenamiento: 100 GB SSD (el incluido).
   - Imagen: **Ubuntu** en su versión **24.04**.
   - **Auto Backup**: recomendado (~2 €/mes).
   - Red privada, IPv4 adicional, Object Storage y monitorización: no hacen falta.
   - Contraseña de `root`: genere una **larga y única** y guárdela en su gestor de contraseñas. Solo se usará
     para la primera conexión; en el paso 4 se desactiva el acceso con contraseña.
   - Complete datos de cliente y pago. Recibirá un email cuando el servidor esté listo (de minutos a unas horas)
     con su **IPv4** (y la IPv6). En el panel https://my.contabo.com póngale el nombre `ochavada-prod`.
3. **Primera conexión con contraseña y alta de su clave** (sustituya `IP` por la IPv4 del servidor). Desde
   PowerShell en su ordenador, este comando copia su clave pública al servidor (le pedirá la contraseña de root):
   ```powershell
   type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
   ```
   La primera vez SSH preguntará si confía en el servidor: responda `yes`. Compruebe que ya entra **sin**
   contraseña:
   ```powershell
   ssh root@IP
   ```
   Si algún día pierde el acceso por SSH, el panel de Contabo tiene una consola **VNC** para entrar al servidor.
4. **Endurecimiento** (dentro del servidor, como root):
   ```bash
   apt update && apt -y full-upgrade
   adduser ochavada
   usermod -aG sudo ochavada
   rsync --archive --chown=ochavada:ochavada /root/.ssh /home/ochavada
   ```
   Solo claves SSH y sin root (el fichero `00-…` tiene prioridad sobre cualquier otro de la imagen):
   ```bash
   printf 'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' > /etc/ssh/sshd_config.d/00-ochavada.conf
   sshd -t && systemctl restart ssh
   ```
   ```bash
   apt -y install unattended-upgrades fail2ban git ufw
   dpkg-reconfigure -plow unattended-upgrades
   timedatectl set-timezone Europe/Madrid
   ```
   **Cortafuegos** (`ufw`). Sustituya `SU_IP` por la IP pública de su casa u oficina si es fija (la ve en
   https://ifconfig.me); si no es fija, use la segunda variante, que limita los intentos y se apoya en la clave
   SSH y fail2ban:
   ```bash
   ufw default deny incoming && ufw default allow outgoing
   ufw allow from SU_IP to any port 22 proto tcp
   ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 443/udp
   ufw enable
   ```
   Variante sin IP fija: en lugar de la segunda línea, `ufw limit 22/tcp`. `ufw enable` pide confirmación
   (`y`); compruebe después con `ufw status verbose`. Si se equivocara de IP o su IP cambiara y quedara fuera,
   entre por la consola VNC del panel y ejecute `ufw limit 22/tcp`.
   Docker gestiona por su cuenta los puertos que publica (en este proyecto solo 80 y 443, que deben estar
   abiertos); PostgreSQL y el backend no publican ninguno, así que no quedan expuestos.

   Memoria de intercambio (margen para la compilación de las imágenes). Con `swappiness` bajo, el sistema solo la
   usa cuando falta RAM, no en el día a día:
   ```bash
   fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
   echo '/swapfile none swap sw 0 0' >> /etc/fstab
   echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf && sysctl --system
   ```
   Desde **otra** terminal compruebe que entra como `ochavada` **antes** de cerrar la sesión de root:
   ```powershell
   ssh ochavada@IP
   ```
   Y que root ya no puede entrar (debe responder *Permission denied*):
   ```powershell
   ssh root@IP
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
| A | `@` | IPv4 del servidor | **Desactivado** (nube gris, «DNS only») |
| A | `www` | IPv4 del servidor | **Desactivado** |

**Por qué sin proxy**: en España, los operadores (Movistar, Vodafone, Orange, DIGI, MásMóvil…) bloquean por
orden judicial direcciones IP compartidas de Cloudflare durante los partidos de LaLiga, y con el proxy activado
la web deja de abrirse desde esas redes («no se puede conectar de forma segura»). Sin proxy, el dominio apunta a
la IP propia del servidor, que no se bloquea. Caddy obtiene y renueva su certificado igualmente (reto DNS-01 con
el token de Cloudflare) y el servidor se protege con `ufw` y fail2ban. Estado de los bloqueos: https://hayahora.futbol

Registros **AAAA** solo si el servidor tiene IPv6 **con salida a internet**: `ping -6 -c 3 one.one.one.one` debe
responder (tener una dirección IPv6 no basta). En el Cloud VPS de Contabo no la tenía, así que solo hay registros A.

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

El script de despliegue comprueba la configuración y el disco, compila las imágenes **de una en una** (así la
compilación nunca agota la memoria) y arranca todo esperando a que esté sano:
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

> **No aplicable con la configuración actual.** Cloudflare Access solo funciona con el proxy de Cloudflare
> activado, y se desactivó por los bloqueos de LaLiga (fase D). Mientras tanto la web es accesible para cualquiera
> que conozca la dirección; el backoffice sigue protegido por usuario y contraseña. Si en algún momento vuelve a
> activar el proxy, estos son los pasos:

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
email en Cloudflare Access si lo activa (fase H).

## Mantenimiento

Actualizar a una versión nueva del código:
```bash
cd /opt/ochavada/ApartamentosOchavadaInfra && bash scripts/deploy.sh
```
Hace `git pull` de los tres repositorios, compila de una en una y sustituye los contenedores. Mientras compila, la
versión anterior sigue atendiendo; el corte es solo el reinicio final (unos segundos). Las migraciones de la base
de datos se aplican solas al arrancar el backend.

Limpieza mensual de imágenes antiguas y de la caché de compilación (las compilaciones van llenando el disco):
```bash
docker image prune -f && docker builder prune -f --filter until=720h
```
```bash
df -h /
```

Copias: además del Auto Backup de Contabo (si lo contrató), el servicio `db-backup` deja un volcado diario en
`/opt/ochavada/ApartamentosOchavadaInfra/backups`; copie ese directorio periódicamente fuera del servidor, por
ejemplo desde PowerShell en su ordenador:
```powershell
scp -r ochavada@IP:/opt/ochavada/ApartamentosOchavadaInfra/backups $env:USERPROFILE\Documents\ochavada-backups
```
Antes de una actualización delicada, haga además un **snapshot** manual desde el panel de Contabo (incluye uno).

Memoria: cada contenedor tiene un límite (`mem_limit` en `docker-compose.yml`, unos 3,5 GB en total con los
valores por defecto, pensados para 8 GB). Para ver el consumo real:
```bash
docker stats --no-stream
```
Si un contenedor se reinicia solo y en `docker compose ps` aparece `OOMKilled`, súbale el límite en `.env`
(`BACKEND_MEM_LIMIT=2g`, por ejemplo) y aplique con `docker compose up -d`.

### Cambiar de servidor

Si más adelante quiere otro proveedor (o un servidor mayor): prepare el nuevo con las fases C, E y F, copie
`.env`, `backend.env` y `secrets/` del antiguo, arranque con `bash scripts/deploy.sh --no-pull`, restaure el
último volcado (cópielo a `backups/` y siga «Restaurar» en el README), cambie la IP en los registros DNS de Cloudflare (fase D) y,
cuando todo funcione, cancele el servidor antiguo. Los registros tienen TTL de 5 minutos: el cambio de IP llega
enseguida.

## Lista de comprobación final

- [ ] `https://apartamentosochavada.com` se abre con candado también desde datos móviles (en día de partido).
- [ ] `https://www.apartamentosochavada.com` redirige al dominio principal.
- [ ] El backoffice permite entrar con el administrador; las variables `APP_BOOTSTRAP_ADMIN_*` ya están vacías.
- [ ] Una reserva de prueba con tarjeta de test queda confirmada y llega el email.
- [ ] `docker compose ps` muestra todo `healthy` y hay un fichero de hoy en `backups/`.
- [ ] `sudo ufw status` muestra el cortafuegos activo con 22 (limitado o desde su IP), 80 y 443.
- [ ] En el panel de Contabo figura el Auto Backup (si lo contrató) y la verificación en dos pasos está activada.
- [ ] `ssh root@IP` y el acceso con contraseña son rechazados; `ssh ochavada@IP` entra con la clave.
