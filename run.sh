#!/usr/bin/env bash

VERSION=$1
DOMAIN=$2
wget -O - https://nightly.odoo.com/odoo.key | apt-key add -
echo "deb http://nightly.odoo.com/$VERSION.0/nightly/deb/ ./" >> /etc/apt/sources.list.d/odoo.list
apt update
apt install odoo wkhtmltopdf nginx -y
apt install certbot python-certbot-nginx python-pip -y
mkdir -p /opt/extra-addons/

if [ $VERSION = '14' ];
  pip install odoo14-addons-oca-l10n-italy
else
  pip install odoo-addons-oca-l10n-italy
fi

systemctl enable --now odoo

sudo crontab -e 15 3 * * * /usr/bin/certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"

sed "s/\{server_name\}/$2/g" ./nginx.conf > /etc/nginx/conf.d/odoo.conf

systemctl restart nginx

echo "proxy_mode = True" >> /etc/odoo/odoo.conf
echo "addons_path = /usr/lib/python3/dist-packages/odoo/addons, /opt/extra-addons" >> /etc/odoo/odoo.conf

systemctl restart odoo
