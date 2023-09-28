#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    echo "First parameter the Odoo version and the next one the domain"
    exit
fi

VERSION=$1
DOMAIN=$2
REPO_FOLDER=$(pwd)

echo "- Starting"

echo "export \$PATH=\$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /root/.bashrc

# Add the repository
cd /tmp || exit
wget -O - https://nightly.odoo.com/odoo.key >> /dev/null 2>&1
apt-key add odoo.key >> /dev/null 2>&1
cd "$REPO_FOLDER" || exit

echo "- Added Debian Odoo Nightly repo for $DOMAIN"

# Install everything
if [ -f /etc/apt/sources.list.d/odoo.list ]; then
  echo "deb http://nightly.odoo.com/$VERSION.0/nightly/deb/ ./" >> /etc/apt/sources.list.d/odoo.list
  apt update >> /dev/null 2>&1
fi
apt install odoo wkhtmltopdf nginx python3-certbot-nginx certbot python3-pip git -y >> /dev/null 2>&1

echo "- APT packages installed"

# Setup Certbot and Nginx
if [ ! -f /tmp/crontab_new ]; then
  echo '15 3 * * * /usr/bin/certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"' >> /tmp/crontab_new
  crontab /tmp/crontab_new

  echo "- Crontab configured"
fi

if [ -f /etc/nginx/conf.d/odoo.conf ]; then
  sed "s/replace_server_name/$DOMAIN/g" "$REPO_FOLDER/nginx.conf" > /etc/nginx/conf.d/odoo.conf
  certbot --nginx -d "$DOMAIN" >> /dev/null 2>&1
  systemctl restart nginx

  echo "- Nginx configured"
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
echo "addons_path = /usr/lib/python3/dist-packages/odoo/addons, /opt/extra-addons" >> /etc/odoo/odoo.conf
systemctl enable --now odoo >> /dev/null 2>&1
systemctl restart odoo

echo "- Odoo configured"

# Setup ports
chmod u+x "$REPO_FOLDER/port-rules.nft"
"$REPO_FOLDER/port-rules.nft"

echo "- Ports configured"

echo "- Done"
