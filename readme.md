# OdooBashInstaller

Welcome to a simple installer (for Debian) for Odoo that doens't use Docker (*old school way*).

## How to use it

* Download this repository and enter the folder
* `chmod +x ./run.sh`
* `./run.sh [Oddo version, ex: 14] domain.old`

The script will take a while to download and do everything (25~ minutes), it will do this steps:

### Install

* `Nginx` for reverse proxy for HTTP and HTTPS
* `Odoo` (with the Nightly Debian packages and add the repository) and configure it for proxy mode
  * Install also `PostGreSQL` and `wkhtmltopdf`
* `certbot` to generate the certificate (with cronjob)
* Install `pip` packages per Odoo version automatically (if file exist)
  * Just copy and rename (as example) `14-requirements-example.txt` to `14-requirements.txt` and add the packages (this step before run the script)
* Create a folder `opt/extra-addons` already mapped for addons
* [WIP] Enable just 22, 80 and 443 as ports with `nftables`
* [WIP] DB backup with cron

## Notes

* **I get some errors about locales different on SSH**
  * `localectl set-locale LANG=it_IT.UTF-8` just change it with the locale you are using to fix it
* **Where it will be saved my pip packages?**
  * The script will add `/usr/lib/python3/dist-packages/odoo/addons` folder but automatically Odoo will add in `addons_path` setting value the python version folder like `/usr/local/lib/python3.9/dist-packages/odoo/addons`. This means that if you upgrade python you need to reinstall the packages, in case you need to be sure you can use `pip show [packagename]` and will show to you the folder path.
* **This script is safe?**
  * The script is checked with [ShellCheck](https://www.shellcheck.net/) for code quality but you can always read the code!
