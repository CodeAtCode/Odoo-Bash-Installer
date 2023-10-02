#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    echo "First parameter the Odoo version and the next one the domain"
    exit
fi

VERSION=$1
DOMAIN=$2
REPO_FOLDER=$(pwd)

echo "- Starting"

echo "PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'" >> /root/.bashrc

# Add repository
if [ ! -f /etc/apt/sources.list.d/odoo.list ]; then
  echo "- Adding Debian Odoo Nightly repo for $DOMAIN"
  cd /tmp || exit
  apt update >> /dev/null 2>&1
  apt install gnupg -y >> /dev/null 2>&1
  wget -q -O - https://nightly.odoo.com/odoo.key | gpg --dearmor -o /usr/share/keyrings/odoo-archive-keyring.gpg
  { echo "deb [signed-by=/usr/share/keyrings/odoo-archive-keyring.gpg] https://nightly.odoo.com/$VERSION.0/nightly/deb/ ./" | sudo tee /etc/apt/sources.list.d/odoo.list; }  >> /dev/null 2>&1
  cd "$REPO_FOLDER" || exit
fi

# Install everything
echo "- APT packages installing"
apt update >> /dev/null 2>&1
apt install odoo wkhtmltopdf nftables nginx python3-certbot-nginx certbot python3-pip python3-pdfminer git -y >> /dev/null 2>&1

# Setup Certbot and Nginx
if [ ! -f /tmp/crontab_new ]; then
  echo '15 3 * * * /usr/bin/certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"' >> /tmp/crontab_new
  crontab /tmp/crontab_new

  echo "- Crontab configured"
fi

if [ ! -f /etc/nginx/sites-enabled/odoo.conf ]; then
  certbot --nginx -d "$DOMAIN" >> /dev/null 2>&1
  rm /etc/nginx/sites-enabled/default
  sed "s/replace_server_name/$DOMAIN/g" "$REPO_FOLDER/nginx.conf" > /etc/nginx/sites-enabled/odoo.conf
  systemctl restart nginx

  echo "- Nginx ready with SSL certificate"
fi

# Download Odoo git modules
mkdir -p /opt/extra-addons/
if [ -f "$REPO_FOLDER/git-clone-repo.txt" ]; then
  cd /opt/extra-addons || exit
  while read -r line; do
    gitfolder=$(basename "$line" .git)
    echo "Downloading $line"
    git clone "$line" >> /dev/null 2>&1
    cd "$gitfolder" || exit
    git checkout "$VERSION.0" >> /dev/null 2>&1
    if [ -f "$REPO_FOLDER/git-clone-repo.txt" ]; then
      pip install -r requirements.txt --break-system-packages >> /dev/null 2>&1
    fi
    cd ../
  done < "$REPO_FOLDER/git-clone-repo.txt"

  echo "- Git clone executed"
fi
cd "$REPO_FOLDER" || exit

# Download Odoo pip modules
if [ -f "$REPO_FOLDER/$VERSION-requirements.txt" ]; then
  pip install -r "$REPO_FOLDER/$VERSION-requirements.txt" >> /dev/null 2>&1

  echo "- Pip executed"
fi

# Setup Odoo
echo "proxy_mode = True" >> /etc/odoo/odoo.conf
addonspath=''
for D in `find . -maxdepth 1 -type d`; do 
  addonspath=$PWD${D#.}","; 
done
echo "addons_path = /usr/lib/python3/dist-packages/odoo/addons, $addonspath" >> /etc/odoo/odoo.conf
systemctl enable --now odoo >> /dev/null 2>&1
systemctl restart odoo

echo "- Odoo configured"

# Setup ports
chmod u+x "$REPO_FOLDER/port-rules.nft"
"$REPO_FOLDER/port-rules.nft"
/usr/sbin/nft list ruleset > /etc/nftables.conf

echo "- Ports configured"

echo "- Done"
