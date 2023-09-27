#!/usr/bin/env bash

VERSION=$1
DOMAIN=$2

localectl set-locale LANG=it_IT.UTF-8

cd /tmp
wget -O - https://nightly.odoo.com/odoo.key >> /dev/null 2>&1
apt-key add odoo.key >> /dev/null 2>&1
cd -

echo "deb http://nightly.odoo.com/$VERSION.0/nightly/deb/ ./" >> /etc/apt/sources.list.d/odoo.list
apt update >> /dev/null 2>&1
apt install odoo wkhtmltopdf nginx python3-certbot-nginx certbot python3-pip -y #>> /dev/null 2>&1
mkdir -p /opt/extra-addons/

if [ "$VERSION" = '14' ]; then
  pip install odoo14-addons-oca-l10n-italy >> /dev/null 2>&1
else
  pip install odoo-addons-oca-l10n-italy >> /dev/null 2>&1
fi

echo '15 3 * * * /usr/bin/certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"' >> /tmp/crontab_new
crontab /tmp/crontab_new

sed "s/replace_server_name/$2/g" ./nginx.conf > /etc/nginx/conf.d/odoo.conf
systemctl restart nginx

echo "proxy_mode = True" >> /etc/odoo/odoo.conf
echo "addons_path = /usr/lib/python3/dist-packages/odoo/addons, /opt/extra-addons" >> /etc/odoo/odoo.conf

systemctl enable --now odoo
systemctl restart odoo
