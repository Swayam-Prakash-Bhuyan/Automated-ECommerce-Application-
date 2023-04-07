#!/bin/bash
#
# This script automates ECommerce Application Deployment
# Author: Swayam Prakash Bhuyan


#######################################
# Print a message in a given color.
# Arguments:
#   Color. eg: green, red
#######################################
function print_color(){
  NC='\033[0m' # No Color

  case $1 in
    "green") COLOR='\033[0;32m' ;;
    "red") COLOR='\033[0;31m' ;;
    "*") COLOR='\033[0m' ;;
  esac
  echo -e "${COLOR}$2\033[0m"
}

#######################################
# Check the status of a given service. If not active exit script
# Arguments:
#   Service Name. eg: firewalld, mariadb
#######################################
function check_service_status()
{
  is_service_active=$(systemctl is-active $1)

  if [ $is_service_active = "active" ]
  then
    print_color "green" "Service $1 is active"
  else
    print_color "red" "Service $1 is not active"
    exit 1
  fi
}

#######################################
# Check the status of a firewalld rule. If not configured exit.
# Arguments:
#   Port Number. eg: 3306, 80
#######################################
function is_firewalld_rule_configured()
{
  firewalld_ports=$(sudo firewall-cmd --list-all --zone=public | grep ports)

  if [[ $firewalld_ports = *$1* ]]
  then
    print_color "green" "Port $1 configured"
  else
    print_color "red" "Port $1 not configured"
    exit 1
  fi
}

#######################################
# Check if a given item is present in an output
# Arguments:
#   1 - Output
#   2 - Item
#######################################
function check_item(){
  if [[ $1 = *$2* ]]
  then
    print_color "green" "Item $2 is present on the web page"
  else
    print_color "red" "Item $2 is not present on the web page"
  fi
}
echo " ------------------- Database Configuration -----------------------"
# Installs and Configures FirewallD
print_color "green" "Installing FirewallD..."
sudo yum install -y firewalld
sudo systemctl start firewalld
sudo systemctl enable firewalld

check_service_status firewalld

# Installs and Configures MariaDB
print_color "green" "Installing MariaDB..."
sudo yum install -y mariadb-server
sudo systemctl start mariadb 
sudo systemctl enable mariadb

check_service_status mariadb

# Add FirewallD rules for database
print_color "green" "Adding Firewall rules for DB..."
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload

is_firewalld_rule_configured 3306



# Configure Database
print_color "green" "Configure DB..."
cat > configure-db.sql <<- EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
EOF

sudo mysql < configure-db.sql


# Load inventory data into Database
print_color "green" "Loading inventory data into database"
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");

EOF

sudo mysql < db-load-script.sql

mysql_db_results=$(sudo mysql -e "use ecomdb; select * from products;")

if [[ $mysql_db_results == *Laptop* ]]
then
  print_color "green" "Inventory data loaded into MySQl"
else
  print_color "red" "Inventory data not loaded into MySQl"
  exit 1
fi
# ------------------- Web Server Configuration -----------------------

print_color "green" "Configuring Web Server..."
# Install apache web server and php
sudo yum install -y httpd php php-mysql

print_color "green" "Configuring FirewallD rules for Web Server..."
# Configure Firewall rules for web server
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload

is_firewalld_rule_configured 80

sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf


# Start and enable httpd service
print_color "green" "Starting web server..."


if [[ $check_service_status=inactive ]] || sudo systemctl status httpd | grep -q "Unit httpd.service could not be found.";
then
	sudo yum install -y httpd
fi

sudo systemctl start httpd
sudo systemctl enable httpd
check_service_status httpd


# Install GIT and download source code repository
print_color "green" "Cloning GIT repo..."
sudo yum install -y git

# Check if directory already exists
if [ -d "/var/www/html" ] && [ "$(ls -A /var/www/html)" ]; then
  # Directory exists and is not empty
  print_color "green" "Directory already exists and is not empty. Pulling the latest code."
  cd /var/www/html
  sudo git init
  sudo git pull 
  cd /home/bob
else
  # Directory does not exist or is empty
  echo "Directory does not exist or is empty. Cloning the code."
  sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/
fi


# Replace database IP with localhost
sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php

print_color "green" "All set"

web_page=$(curl http://localhost)

for item in Laptop Drone VR Watch Phone
do
  check_item "$web_page" $item
done