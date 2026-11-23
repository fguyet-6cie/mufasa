#!/bin/bash
# Installation automatique de la « boîte aux lettres » MUFASA (serveur MQTT Mosquitto)
# sur un petit serveur Ubuntu (par exemple l'offre gratuite d'Oracle Cloud).
#
# À coller dans « Script d'initialisation » (cloud-init) à la création du serveur.
# Remplir seulement les 4 lignes ci-dessous, entre les guillemets.

DOMAINE="a-remplir"            # nom choisi sur duckdns.org, SANS « .duckdns.org »
JETON_DUCKDNS="a-remplir"      # le « token » affiché en haut de duckdns.org
IDENTIFIANT="mufasa"           # identifiant à mettre dans l'appli
MOT_DE_PASSE="a-remplir"       # mot de passe à mettre dans l'appli (long, sans guillemets)

# ---------------------------------------------------------------------------
# Rien à modifier en dessous.
set -u
export DEBIAN_FRONTEND=noninteractive
NOM="$DOMAINE.duckdns.org"
exec > >(tee -a /var/log/mufasa-installation.log) 2>&1
echo "== Installation MUFASA : $(date)"

apt-get update
apt-get install -y mosquitto certbot curl

# 1. DuckDNS : le nom $NOM pointe vers l'adresse de ce serveur (mis à jour toutes les 5 min).
cat > /usr/local/bin/mufasa-duckdns.sh <<EOF
#!/bin/bash
curl -fsS "https://www.duckdns.org/update?domains=$DOMAINE&token=$JETON_DUCKDNS&ip=" -o /var/log/mufasa-duckdns.txt
EOF
chmod 700 /usr/local/bin/mufasa-duckdns.sh
echo "*/5 * * * * root /usr/local/bin/mufasa-duckdns.sh" > /etc/cron.d/mufasa-duckdns
/usr/local/bin/mufasa-duckdns.sh || true
grep -q OK /var/log/mufasa-duckdns.txt || echo "!! DuckDNS a répondu KO : vérifier le nom et le token (mettre l'adresse à la main sur duckdns.org en attendant)"

# 2. Pare-feu interne du serveur (les images Oracle bloquent tout sauf SSH) :
#    ouvre 80 (certificat) et 8883 (MQTT chiffré).
for p in 80 8883; do
  iptables -C INPUT -p tcp --dport $p -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport $p -j ACCEPT
done
command -v netfilter-persistent >/dev/null && netfilter-persistent save

# 3. Mot de passe de la boîte aux lettres.
mosquitto_passwd -b -c /etc/mosquitto/passwd "$IDENTIFIANT" "$MOT_DE_PASSE"
chown mosquitto:mosquitto /etc/mosquitto/passwd
chmod 600 /etc/mosquitto/passwd

# 4. Réglages de Mosquitto : uniquement chiffré (TLS, port 8883), avec mot de passe.
mkdir -p /etc/mosquitto/certs
cat > /etc/mosquitto/conf.d/mufasa.conf <<EOF
per_listener_settings false
allow_anonymous false
password_file /etc/mosquitto/passwd
listener 8883
certfile /etc/mosquitto/certs/fullchain.pem
keyfile /etc/mosquitto/certs/privkey.pem
max_packet_size 262144
EOF

# 5. Certificat gratuit Let's Encrypt, recopié pour Mosquitto à chaque renouvellement.
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/mosquitto.sh <<EOF
#!/bin/bash
cp /etc/letsencrypt/live/$NOM/fullchain.pem /etc/letsencrypt/live/$NOM/privkey.pem /etc/mosquitto/certs/
chown mosquitto:mosquitto /etc/mosquitto/certs/*.pem
chmod 600 /etc/mosquitto/certs/privkey.pem
systemctl restart mosquitto
EOF
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/mosquitto.sh

# Le certificat ne s'obtient que quand les ports 80 et 8883 sont ouverts côté Oracle :
# on réessaie tout seul toutes les 15 minutes jusqu'à réussir.
cat > /usr/local/bin/mufasa-certificat.sh <<EOF
#!/bin/bash
until [ -f /etc/letsencrypt/live/$NOM/fullchain.pem ]; do
  /usr/local/bin/mufasa-duckdns.sh
  certbot certonly --standalone -d $NOM --non-interactive --agree-tos \
    --register-unsafely-without-email && break
  echo "Certificat pas encore obtenu, nouvel essai dans 15 min"
  sleep 900
done
/etc/letsencrypt/renewal-hooks/deploy/mosquitto.sh
echo "== MUFASA prêt : $NOM port 8883"
EOF
chmod 700 /usr/local/bin/mufasa-certificat.sh

cat > /etc/systemd/system/mufasa-certificat.service <<EOF
[Unit]
Description=Certificat MUFASA
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/etc/letsencrypt/live/$NOM/fullchain.pem

[Service]
Type=simple
ExecStart=/usr/local/bin/mufasa-certificat.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now mufasa-certificat.service
systemctl enable mosquitto

# 6. Mises à jour de sécurité automatiques.
apt-get install -y unattended-upgrades
echo "== Installation terminée (le certificat arrive dès que les ports sont ouverts)"
