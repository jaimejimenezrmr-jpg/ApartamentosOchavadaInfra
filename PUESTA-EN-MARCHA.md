# Puesta en marcha desde cero (entorno para el equipo)

Objetivo: tener `https://apartamentosochavada.com` funcionando en un servidor propio, visible solo para el
equipo hasta el lanzamiento público (finales de enero / principios de febrero de 2027).

| Pieza | Elección | Coste orientativo |
|---|---|---|
| Dominio | `apartamentosochavada.com` en **Cloudflare Registrar** (precio de coste) | ~10 $/año |
| DNS, TLS y protección | **Cloudflare** (plan gratuito) | 0 € |
| Acceso solo para el equipo | **Cloudflare Zero Trust · Access** (gratis hasta 50 usuarios) | 0 € |
| Servidor | **Hetzner Cloud**, 4 vCPU / 8 GB, Ubuntu 24.04, centro de datos en Alemania | ~10–20 €/mes (confirmar en la consola) |
| Copias del servidor | Copias automáticas de Hetzner (+20 % del precio del servidor) | ~2–4 €/mes |
| Código | Repositorios **privados** en GitHub | 0 € |

> Por qué Hetzner y no Google Cloud/Azure: por 10–20 €/mes da una máquina que en esas nubes costaría 30–40 €
> más tráfico, con consola, API, cortafuegos, snapshots y copias. Datos en la UE (RGPD). Alternativa equivalente:
> OVHcloud VPS. Los precios de Hetzner han cambiado en 2026: verifique el importe exacto al crear el servidor.

Tiempo estimado: 2–3 horas la primera vez (la emisión de certificados y la primera compilación son lo más lento).

---

## Fase A · Cuentas (una sola vez)

1. **Cloudflare**: cree la cuenta en https://dash.cloudflare.com con `apartamentosochavada@gmail.com` y active la
   verificación en dos pasos (My Profile → Authentication).
2. **Hetzner**: cree la cuenta en https://accounts.hetzner.com. Piden verificar identidad y un método de pago;
   la aprobación puede tardar unas horas. Active la verificación en dos pasos.
3. **GitHub**: cree (o use) una cuenta y tres repositorios **privados**: `ochavada-backend`, `ochavada-front`,
   `ochavada-infra`. Active la verificación en dos pasos.
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
2. Hetzner Cloud Console → **New project** «Ochavada» → **Add Server**:
   - Ubicación: Falkenstein o Nuremberg (Alemania).
   - Imagen: **Ubuntu 24.04**.
   - Tipo: **4 vCPU / 8 GB** (x86 «CX» o ARM «CAX»; las imágenes funcionan en ambas).
   - Networking: IPv4 + IPv6.
   - SSH key: pegue la clave pública.
   - **Backups**: activadas.
   - Nombre: `ochavada-prod`.
3. **Firewall** (Hetzner → Firewalls → Create) y aplíquelo al servidor:
   - Entrada TCP 22 solo desde su IP (o su rango) — es el acceso de administración.
   - Entrada TCP 80 y 443, y UDP 443, desde cualquier origen.
   - (Opcional, más seguro: limitar 80/443 a los rangos de https://www.cloudflare.com/ips/.)
4. **Primera conexión y endurecimiento** (sustituya `IP` por la IPv4 del servidor):
   ```bash
   ssh root@IP
   ```
   Dentro del servidor:
   ```bash
   apt update && apt -y full-upgrade
   adduser ochavada
   usermod -aG sudo ochavada
   rsync --archive --chown=ochavada:ochavada ~/.ssh /home/ochavada
   ```
   ```bash
   sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/; s/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
   systemctl restart ssh
   ```
   ```bash
   apt -y install unattended-upgrades fail2ban git
   dpkg-reconfigure -plow unattended-upgrades
   timedatectl set-timezone Europe/Madrid
   ```
   Memoria de intercambio (ayuda en la compilación de las imágenes):
   ```bash
   fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
   echo '/swapfile none swap sw 0 0' >> /etc/fstab
   ```
   Desde otra terminal compruebe que entra como `ochavada` **antes** de cerrar la sesión de root:
   ```bash
   ssh ochavada@IP
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

## Fase E · Código en el servidor

1. En su ordenador, suba cada proyecto a su repositorio privado de GitHub (`git init`, `git add`, `git commit`,
   `git remote add origin …`, `git push`). Compruebe que **no** se suben `.env`, `backend.env`, `backups/` ni
   `secrets/` (los `.gitignore` ya los excluyen).
2. En el servidor, una **deploy key** de solo lectura para clonar:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/github_ochavada -N "" -C "ochavada-prod"
   cat ~/.ssh/github_ochavada.pub
   ```
   Añádala en GitHub a cada repositorio: Settings → Deploy keys → Add (sin permiso de escritura). Después:
   ```bash
   printf 'Host github.com\n  IdentityFile ~/.ssh/github_ochavada\n  IdentitiesOnly yes\n' >> ~/.ssh/config
   sudo mkdir -p /opt/ochavada && sudo chown ochavada:ochavada /opt/ochavada && cd /opt/ochavada
   git clone git@github.com:<usuario>/ochavada-backend.git ApartamentosOchavadaBackend
   git clone git@github.com:<usuario>/ochavada-front.git ApartamentosOchavadaFront
   git clone git@github.com:<usuario>/ochavada-infra.git ApartamentosOchavadaInfra
   ```
   Los tres directorios deben quedar al mismo nivel, con esos nombres exactos.

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

```bash
docker compose up -d --build
```

La primera compilación tarda 10–20 minutos. Siga el estado con:
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
cd /opt/ochavada
git -C ApartamentosOchavadaBackend pull && git -C ApartamentosOchavadaFront pull && git -C ApartamentosOchavadaInfra pull
cd ApartamentosOchavadaInfra && docker compose up -d --build
```

Limpieza de imágenes antiguas (mensual):
```bash
docker image prune -f
```

Copias: además de las copias automáticas de Hetzner, el servicio `db-backup` deja un volcado diario en
`/opt/ochavada/ApartamentosOchavadaInfra/backups`; copie ese directorio periódicamente fuera del servidor.

## Lista de comprobación final

- [ ] `https://apartamentosochavada.com` pide el código de Cloudflare Access y luego muestra la web.
- [ ] `https://www.apartamentosochavada.com` redirige al dominio principal.
- [ ] El backoffice permite entrar con el administrador; las variables `APP_BOOTSTRAP_ADMIN_*` ya están vacías.
- [ ] Una reserva de prueba con tarjeta de test queda confirmada y llega el email.
- [ ] `docker compose ps` muestra todo `healthy` y hay un fichero de hoy en `backups/`.
- [ ] Las copias automáticas de Hetzner están activadas.
