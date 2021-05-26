#!/usr/bin/env bash

exec 1>log.out 2>&1

blue=`tput setaf 2`
reset=`tput sgr0`

export DEBIAN_FRONTEND=noninteractive

echo "${blue}----------Starting Installation----------" > $(tty)

echo "Running apt package updates" > $(tty)
apt-get update && apt-get upgrade -y

echo "Setting the Server Timezone to America/New_York" > $(tty)
echo "America/New_York" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

echo "Enabling Ubuntu Firewall.  Allowing SSH, HTTP and HTTPS" > $(tty)
ufw enable
ufw allow 22
ufw allow 80
ufw allow 443

echo "Installing system and application dependencies" > $(tty)
apt-get install -y php7.4 php7.4-cli php7.4-common php7.4-json \
                   php7.4-opcache php7.4-mysql php7.4-mbstring \
                   php7.4-zip php7.4-fpm php7.4-xml php7.4-ldap redis \
                   mysql-server mysql-client nginx git curl nano


echo "Starting php fpm" > $(tty)
service php7.4-fpm start

echo "Installing the composer package manager" > $(tty)
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

export MYSQL_PWD=`date +%s | sha256sum | base64 | head -c 32 ; echo;`

echo "Starting MySQL service" > $(tty)
service mysql start

echo "Running MySQL secure installation" > $(tty)
sudo mysql_secure_installation 2>/dev/null <<MSI

y
2
${MYSQL_PWD}
${MYSQL_PWD}
y
y
y
y
y

MSI

echo "Updating MySQL root authentication settings" > $(tty)
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_PWD}';"
mysql -u root -p${MYSQL_PWD} -e 'USE mysql; UPDATE `user` SET `Host`="%" WHERE `User`="root" AND `Host`="localhost"; DELETE FROM `user` WHERE `Host` != "%" AND `User`="root"; FLUSH PRIVILEGES;'

echo "Configuring nginx" > $(tty)
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
cat $(pwd)/nginx.config > /etc/nginx/sites-available/cmsplayer.conf
ln -s /etc/nginx/sites-available/cmsplayer.conf /etc/nginx/sites-enabled/cmsplayer.conf

echo "Starting nginx service" > $(tty)
service nginx start

export APP_DIR=/var/www/cmsplayer

echo "Cloning CMS Player repo" > $(tty)
git clone https://github.com/sloan58/cmsrec.git ${APP_DIR}

echo "Installing application dependencies" > $(tty)
cd ${APP_DIR}
composer install

echo "Configuring app environment" > $(tty)
cp .env.example .env
php artisan key:generate

echo $reset > $(tty)
echo "Installation Complete! Please find your application/server details below:" > $(tty)
echo "----------" > $(tty)
echo "MySQL root password: ${MYSQL_PWD}" > $(tty)
echo $reset > $(tty)