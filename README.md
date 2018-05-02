
## Modern Server Stack

This is how to setup and configure a serverstack for a WordPress website.

The server stack:
- Varnish Cache sits at the front caching all pages
- Nginx server used as its just awesome
- HHVM runs the PHP files
- Redis Cache for object and db cache
- MariaDB for database
- Ubuntu 16.04 running the show

The Configuration files in this project works in following strategy
Port 443(Nginx) => Port 80(Varnish) => Port 8080(Nginx)
User browses through http :

- Recieves request at Port 80(Varnish)
- Redirects to https with 301 request

User browses through https

- Recieves request at Port 443(Nginx)
- Forwords Request to Varnish at Port 80
- If cache hit, return response
Else Forward request to Nginx at Port 8080
- Nginx initiates and run wordpress with HHVM and returns response

#### Getting Started
Install all available updates
```
sudo apt-get update
sudo apt-get upgrade
```
#### Install Prerequisites
```
sudo apt-get install unzip
```
#### Install Nginx
```
sudo apt-get install nginx
```

Files to configure Nginx
- /etc/nginx/nginx.conf
- /etc/nginx/sites-available/default
To edit files use `sudo nano filename`
#### Install Mariadb
Install Mariadb server and client
```
sudo apt-get install mariadb-server mariadb-client
```
Start Mariadb and enable it to run at boot
```
sudo systemctl start mysql
sudo systemctl enable mysql
```
Initialize Mariadb
```
sudo mysql_secure_installation
```
- press enter for no password
- 'y' to set a new root password
- type the password
- and press enter for the rest

Login the Maridabd and create a database for WordPress
```
sudo mysql -u root -p
```
- type root password
- `create database db_name;`Create a db
- `CREATE USER 'db_user'@'localhost' IDENTIFIED BY 'your-password';` Create a user and set password
- `GRANT ALL ON db_name.* TO 'db_user'@'localhost' IDENTIFIED BY 'your-password' WITH GRANT OPTION;`Grant permission to User for the database
- `FLUSH PRIVILEGES;`
- `EXIT;`
#### Install HHVM
```
sudo apt-get install software-properties-common
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0x5a16e7281be7a449
sudo add-apt-repository "deb http://dl.hhvm.com/ubuntu $(lsb_release -sc) main"
sudo apt-get update
sudo apt-get install -y hhvm
sudo /usr/share/hhvm/install_fastcgi.sh
sudo update-rc.d hhvm defaults
sudo /usr/bin/update-alternatives --install /usr/bin/php php /usr/bin/hhvm 60
```
To add FTP support to HHVM
```
nano /etc/hhvm/php.ini
```
- Add line `hhvm.enable_zend_compat = true`

Start HHVM
```
systemctl start hhvm
```
To test hhvm
```
cd /var/www/html/
nano info.php
 ```
 - Type in `<?php phpinfo(); ?>`and save file by Ctrl+X
 - go to ip/info.php in your browser
 - or type `php info.php` in your ssh console
 - `php -v` in your ssh console

#### Install WordPress
```
cd /var/www/html/
wget wordpress.org/latest.zip
unzip latest.zip
mv wordpress/* .
rm -rf wordpress/
```
To configure WP database
```
mv wp-config-sample.php wp-config.php
nano wp-config.php
```
#### Install Varnish Cache
```
mkdir /tmp/varnish
cd /tmp/varnish
curl -o varnish.deb https://repo.varnish-cache.org/pkg/5.0.0/varnish_5.0.0-1_amd64.deb
# Install dependencies
sudo apt-get install -f
# Install Varnish
dpkg -i varnish.deb
```
Files to configure Varnsih
- /etc/default/varnish
- /lib/systemd/system/varnish.service
- /etc/varnish/default.vcl
To edit files use `sudo nano filename`

Start Varnish and enable it to run at boot
```
update-rc.d varnish defaults
sudo systemctl enable varnish
```

#### Install Redis Cache
```
sudo apt-get update
sudo apt-get install redis-server
redis-server /etc/redis/redis.conf
```
Files to configure Redis
- /etc/redis/redis.conf
To edit files use `sudo nano filename

Add Redis to WordPress Config
```
nano /var/www/html/wp-config.php
```
add `define('WP_CACHE_KEY_SALT', 'example.com');` to the file

 Start Varnish and enable it to run at boot
```
service redis-server start
update-rc.d redis-server enable
update-rc.d redis-server defaults
```
#### Install VsFTPd
```
sudo apt-get install vsftpd
```
Create ssl files to enable SFTP
```
sudo openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/certs/vsftpd.pem -days 365
```
Files to configure Redis
 - /etc/vsftpd.conf
To edit files use `sudo nano filename

Make following edits
- write_enable=YES
-	listen=YES
-	comment listen_ipv6=YES
-	add to end of the file
```
user_sub_token=$USER
local_root=/home/$USER/ftp
pasv_min_port=40000
pasv_max_port=50000
pasv_address=elastic_ip
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
```

Add FTP User and Grant Access to html files
```
sudo adduser ftpuser
# -> set password
sudo usermod -a -G www-data ftpuser
usermod -g www-data ftpuser
sudo chown -R www-data:www-data /var/www
sudo chmod -R g+w /var/www
```
 Add user to ftp access
 ```
 echo "ftpuser" | sudo tee -a /etc/vsftpd.userlist
 ```
 Restart FTP server
 ```
 sudo systemctl restart vsftpd
 ```
#### Install LetsEncrypt SSL Certificates
 ```
sudo apt-get update
sudo apt-get install software-properties-common
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install certbot
 ```
 Issue SSL Certificates by HTTP Challenge
 ```
 sudo certbot certonly --webroot -w /var/www/example -d example.com -d www.example.com
 ```
**Automating renewal**
 The Certbot packages on your system come with a cron job that will renew your certificates automatically before they expire. Since Let's Encrypt certificates last for 90 days, it's highly advisable to take advantage of this feature. You can test automatic renewal for your certificates by running this command:
 ```
 sudo certbot renew --dry-run
 ```
#### Configure Firewall
```
# list firewall applications
sudo ufw app list
# IMPORTANT: as without ssh access you
# don't have access to the server ;)
sudo ufw allow ssh
# HTTP AND HTTPS access
sudo ufw allow 443
sudo ufw allow 80
# FTP access
sudo ufw allow 20:22/tcp
sudo ufw allow 40000:42000/tcp
# verify change
sudo ufw status
# Enable Firewall on startup
update-rc.d ufw defaults
```
#### Create Admin Folder
```
sudo mkdir /var/www/admin
sudo sh -c "echo -n 'username:' >> /var/www/admin/.htpasswd"
sudo sh -c "openssl passwd -apr1 >> /var/www/admin/.htpasswd"
# -> type password
cat /var/www/admin/.htpasswd
```
#### Install Adminer to Control MySql
```
sudo mkdir /var/www/admin/adminer
cd /var/www/admin/adminer
sudo wget -c https://www.adminer.org/latest-en.php -O index.php
```
#### Nginx Service Controls
```
# Nginx server Status
sudo systemctl status nginx
# Start Nginx server
sudo systemctl start nginx
# Restart Nginx server
sudo systemctl restart nginx
# Reload Nginx configurations
sudo systemctl reload nginx
# Stop Nginx server
sudo systemctl stop nginx
```
#### Mariadb Service Controls
```
# Mariadb server Status
sudo systemctl status mysql
# Start Mariadb server
sudo systemctl start mysql
# Restart Mariadb server
sudo systemctl restart mysql
# Reload Mariadb configurations
sudo systemctl reload mysql
# Stop Mariadb server
sudo systemctl stop mysql
```

#### Varnish Service Controls
```
# Varnish server Status
sudo systemctl status varnish
# Start Varnish server
sudo systemctl start varnish
# Restart Varnish server
sudo systemctl restart varnish
# Reload Varnish configurations
sudo systemctl reload varnish
# Stop Varnish server
sudo systemctl stop varnish
```
#### Redis Service Controls
```
# Redis server Status
sudo systemctl status redis
# Start Redis server
sudo systemctl start redis
# Restart Redis server
sudo systemctl restart redis
# Reload Redis configurations
sudo systemctl reload redis
# Stop Redis server
sudo systemctl stop redis
```
#### VsFTPd Service Controls
```
# VsFTPd server Status
sudo systemctl status vsftpd
# Start VsFTPd server
sudo systemctl start vsftpd
# Restart VsFTPd server
sudo systemctl restart vsftpd
# Reload VsFTPd configurations
sudo systemctl reload vsftpd
# Stop VsFTPd server
sudo systemctl stop vsftpd
```
#### To confirm running open ports
```
netstat -ntulp
```
#### Nginx Error Log
```
sudo tail -f /var/log/nginx/error.log
```
#### HHVM Error Log
```
sudo tail -f /var/log/hhvm/error.log
```
#### All Configuration Files
```
# Nginx
nano /etc/nginx/nginx.conf
nano /etc/nginx/sites-available/default
# HHVM
nano /etc/hhvm/php.ini
# Varnish
nano /etc/varnish/default.vcl
nano /etc/default/varnish
nano /lib/systemd/system/varnish.service
# Redis
nano /etc/redis/redis.conf
# VsFTPd
nano /etc/vsftpd.conf
```
#### If using W3TC plugin for Cache in WordPress
Add path to w3tc wordpress config in nginx config file
```
location / {
	include /path/to/wproot/nginx.conf;
}
```
#### Check RAM usage
```
# ram usage
watch -n 5 free -m
# apps using resources
ps aux
# clear cache
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```
#### Varnish Cache 504 error on Post Update
Edit the following
- w3tc - plugins/w3-total-cache/Util_AttachToActions.php
 Comment Line 18
```
		/*add_action( 'clean_post_cache', array(
				$o,
				'on_post_change'
			), 0, 2 );
		add_action( 'publish_post', array(
				$o,
				'on_post_change'
			), 0, 2 );*/
```
#### Varnish Cache WordPress Plugin
Edit the following
- plugins/varnish-http-purge/varnish-http-purge.php
Comment Line 186 and 189
```
//'save_post',
//'edit_post',
```
- wp-config.php
Add a line
```
define('VHP_VARNISH_IP','127.0.0.1');
```
