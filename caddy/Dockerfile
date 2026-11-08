# syntax=docker/dockerfile:1.7
# Caddy con dos módulos:
#   - caddy-dns/cloudflare: certificados por reto DNS-01 (funciona con el proxy de Cloudflare activado)
#   - caddy-cloudflare-ip:   lista de IPs de Cloudflare actualizada para confiar en CF-Connecting-IP
FROM caddy:2-builder AS builder
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/WeidiDeng/caddy-cloudflare-ip

FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
# Comprueba la sintaxis al construir (no necesita red ni credenciales): un Caddyfile roto no llega a desplegarse.
RUN DOMAIN=example.com ACME_EMAIL=admin@example.com caddy adapt --config /etc/caddy/Caddyfile --adapter caddyfile > /dev/null
