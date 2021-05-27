#!/usr/bin/env bash

exec 1>log.out 2>&1

blue=`tput setaf 2`
reset=`tput sgr0`

export DEBIAN_FRONTEND=noninteractive

echo "${blue}----------Starting Installation----------" > $(tty)

echo "Setting the Server Timezone to America/New_York" > $(tty)
echo "America/New_York" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

echo "Enabling Ubuntu Firewall. Allowing SSH, HTTP and HTTPS" > $(tty)
ufw enable -y
ufw allow 22
ufw allow 80
ufw allow 443

echo "Running system updates" > $(tty)
apt-get update && apt-get upgrade -y

echo "Installing system and application dependencies" > $(tty)
apt-get install -y php7.4 php7.4-cli php7.4-common php7.4-json \
                php7.4-opcache php7.4-mysql php7.4-mbstring \
                php7.4-zip php7.4-fpm php7.4-xml php7.4-ldap \
                redis-server mysql-server mysql-client nginx \
                git curl nano


echo "Starting php fpm" > $(tty)
service php7.4-fpm start

echo "Starting Redis server" > $(tty)
service redis-server start

echo "Installing the composer package manager" > $(tty)
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo "Starting MySQL service" > $(tty)
service mysql start

export MYSQL_PWD=`date +%s | sha256sum | base64 | head -c 32 ; echo;`

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

echo "Creating CMS Player database" > $(tty)
mysql -uroot -p${MYSQL_PWD} -e 'CREATE DATABASE cmsplayer;'

echo "Configuring nginx" > $(tty)
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
cat $(pwd)/nginx.config > /etc/nginx/sites-available/cmsplayer.conf
ln -s /etc/nginx/sites-available/cmsplayer.conf /etc/nginx/sites-enabled/cmsplayer.conf

echo "Generating nginx SSL certificate" > $(tty)
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/ST=PA/L=Pittsburgh/O=HQ/CN=localhost" \
    -keyout localhost.key  -out localhost.crt
mv localhost.crt /etc/ssl/certs/localhost.crt
mv localhost.key /etc/ssl/private/localhost.key

echo "Starting nginx service" > $(tty)
service nginx start

export APP_DIR=/var/www/cmsplayer

echo "Cloning CMS Player repo" > $(tty)
git clone https://github.com/sloan58/cmsrec.git ${APP_DIR}

echo "Installing application dependencies" > $(tty)
cd ${APP_DIR}
composer install --no-interaction --prefer-dist --optimize-autoloader

echo "Configuring app environment" > $(tty)
export MOUNT_PATH=`which mount`
cp .env.example .env
sed -i 's/APP_NAME=Laravel/APP_NAME="CMS Player"/g' .env
sed -i 's/APP_ENV=local/APP_ENV=production/g' .env
sed -i 's/APP_DEBUG=true/APP_DEBUG=false/g' .env
sed -i 's/DB_DATABASE=cmsrec/DB_DATABASE=cmsplayer/g' .env
sed -i "s/DB_PASSWORD=/DB_PASSWORD=${MYSQL_PWD}/g" .env
sed -i 's/CACHE_DRIVER=file/CACHE_DRIVER=redis/g' .env
sed -i 's/QUEUE_CONNECTION=sync/QUEUE_CONNECTION=redis/g' .env
sed -i 's/SESSION_DRIVER=file/SESSION_DRIVER=redis/g' .env
sed -i "s|MOUNT_PATH=/bin|MOUNT_PATH=${MOUNT_PATH}|g" .env
php artisan key:generate
php artisan migrate --force --seed

echo "Setting app file permissions" > $(tty)
chown -R www-data: ${APP_DIR}

echo $reset > $(tty)
echo "Installation Complete! Please find your application/server details below:" > $(tty)
echo "----------" > $(tty)
echo "MySQL Username: root" > $(tty)
echo "MySQL Password: ${MYSQL_PWD}" > $(tty)
echo -e "\n" > $(tty)
echo "Application Username: admin@cmsplayer.com" > $(tty)
echo "Application Password: secret" > $(tty)
echo "* You can change this password after logging in here: http://127.0.0.1:8005" > $(tty)
echo -e "\n" > $(tty)