#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    echo "First parameter the Odoo version and the next one the domain"
    exit
fi

VERSION=$1
DOMAIN=$2

# Add the repository
cd /tmp || exit
wget -O - https://nightly.odoo.com/odoo.key >> /dev/null 2>&1
apt-key add odoo.key >> /dev/null 2>&1
cd - || exit

# Install everything
echo "deb http://nightly.odoo.com/$VERSION.0/nightly/deb/ ./" >> /etc/apt/sources.list.d/odoo.list
apt update >> /dev/null 2>&1
apt install odoo wkhtmltopdf nginx python3-certbot-nginx certbot python3-pip git -y >> /dev/null 2>&1
if [ -f ./"$VERSION"-requirements.txt ]; then
  pip install -r ./"$VERSION"-requirements.txt >> /dev/null 2>&1
fi

# Setup Certbot and Nginx
echo '15 3 * * * /usr/bin/certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"' >> /tmp/crontab_new
crontab /tmp/crontab_new
sed "s/replace_server_name/$DOMAIN/g" ./nginx.conf > /etc/nginx/conf.d/odoo.conf
certbot --nginx -d "$DOMAIN"
systemctl restart nginx

# Setup Odoo
mkdir -p /opt/extra-addons/
cd /opt/extra-addons || exit
if [ -f ./git-clone-repo.txt ]; then
  while read line; do
    gitfolder=$(basename "$line" .git)
    git clone "$line" && >> /dev/null 2>&1
    cd "$gitfolder" || exit
    git checkout "$VERSION.0"
    cd ../
  done < ./git-clone-repo.txt
fi
cd - || exit
echo "proxy_mode = True" >> /etc/odoo/odoo.conf
echo "addons_path = /usr/lib/python3/dist-packages/odoo/addons, /opt/extra-addons" >> /etc/odoo/odoo.conf
systemctl enable --now odoo
systemctl restart odoo

# Setup ports
chmod u+x ./port-rules.nft
./port-rules.nft
