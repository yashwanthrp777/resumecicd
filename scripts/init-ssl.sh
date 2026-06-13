#!/bin/bash
# =============================================================
# AI Resume Analyzer — SSL Certificate Bootstrap Script
# =============================================================
# Run this ONCE on the EC2 server to obtain the initial
# Let's Encrypt SSL certificate for the domain.
#
# After this, automatic renewal is handled by the certbot
# container defined in docker-compose.yml.
#
# Usage: sudo bash scripts/init-ssl.sh
# =============================================================

set -e

DOMAIN="airesumeanalyser.duckdns.org"
EMAIL="yyashwanthrp@gmail.com"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "========================================="
echo "🔐 SSL Certificate Bootstrap"
echo "   Domain: $DOMAIN"
echo "   Email:  $EMAIL"
echo "========================================="

cd "$PROJECT_DIR"

# ---- Step 1: Create required directories ----
echo "📁 Creating certbot directories..."
mkdir -p certbot/conf
mkdir -p certbot/www

# ---- Step 2: Generate a temporary self-signed certificate ----
# WHY: Nginx needs valid cert files to start with the HTTPS block.
# We create a temporary self-signed cert so nginx can boot up,
# then replace it with the real Let's Encrypt cert.
echo "🔑 Generating temporary self-signed certificate..."
mkdir -p "certbot/conf/live/$DOMAIN"

docker run --rm \
  -v "$PROJECT_DIR/certbot/conf:/etc/letsencrypt" \
  alpine/openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout "/etc/letsencrypt/live/$DOMAIN/privkey.pem" \
    -out "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" \
    -subj "/CN=$DOMAIN"

echo "✅ Temporary self-signed certificate created"

# ---- Step 3: Start nginx and web app ----
# Nginx will start with the self-signed cert. This is enough for
# it to serve the ACME challenge on port 80 for Certbot.
echo "🚀 Starting nginx and web app..."
docker compose up -d web nginx

echo "⏳ Waiting for nginx to become ready..."
sleep 10

# ---- Step 4: Delete the temporary certificate ----
echo "🗑️  Removing temporary self-signed certificate..."
rm -rf "certbot/conf/live/$DOMAIN"
rm -rf "certbot/conf/archive/$DOMAIN"
rm -rf "certbot/conf/renewal/$DOMAIN.conf"

# ---- Step 5: Obtain the real Let's Encrypt certificate ----
echo "📜 Requesting real certificate from Let's Encrypt..."
docker run --rm \
  -v "$PROJECT_DIR/certbot/conf:/etc/letsencrypt" \
  -v "$PROJECT_DIR/certbot/www:/var/www/certbot" \
  certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "$DOMAIN"

echo "✅ Real Let's Encrypt certificate obtained!"

# ---- Step 6: Reload nginx with the real certificate ----
echo "🔄 Reloading nginx with real certificate..."
docker compose exec nginx nginx -s reload

# ---- Step 7: Start the full stack ----
echo "🚀 Starting all services..."
docker compose up -d

echo ""
echo "========================================="
echo "✅ SSL setup complete!"
echo "========================================="
echo ""
echo "Your site is now live at:"
echo "  🔒 https://$DOMAIN"
echo ""
echo "Certbot will automatically renew the certificate."
echo "You can verify the cert with:"
echo "  docker compose exec nginx openssl s_client -connect localhost:443 -servername $DOMAIN </dev/null 2>/dev/null | openssl x509 -noout -dates"
echo ""
