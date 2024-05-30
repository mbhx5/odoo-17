#!/bin/bash

# *****************************************************************************
# *                                                                           *
# *  Odoo 17 Installation Bash Script                                         *
# *                                                                           *
# *  Author: Zitouni Mahdi                                                    *
# *  Date:   February 7, 2024                                                 *
# *                                                                           *
# *****************************************************************************
echo -e "\e[1;34m"
echo "   OOO   DDD   OOO   OOO   17"
echo "  O   O  D  D O   O O   O      "
echo "  O   O  D  D O   O O   O      "
echo "  O   O  D  D O   O O   O      "
echo "   OOO   DDD   OOO   OOO      "
echo -e "\e[0m"
# *****************************************************************************
# Function to display a simplified progress bar
simple_progress_bar() {
    local duration=$1
    local interval=0.1
    local i=0

    echo -n "Progress: "
    
    while [ $i -lt $duration ]; do
        sleep $interval
        echo -n "="
        i=$((i + 1))
    done

    echo " Done"   # Move to the next line after the progress bar
}
# *****************************************************************************
# Function to check if the domain belongs to the actual host machine's public IP
check_domain_ip() {
    local domain=$1
    local machine_ip=$(hostname -I | cut -d' ' -f1)
    local domain_ip=$(dig +short "$domain" | head -n 1)  # Only take the first IP if multiple are returned

    echo "Machine IP: $machine_ip"
    echo "Domain IP: $domain_ip"

    if [ "$machine_ip" = "$domain_ip" ]; then
        return 0  # Domain belongs to the actual host machine's public IP
    else
        return 1  # Domain does not belong to the actual host machine's public IP
    fi
}
# *****************************************************************************
# Function to validate an email address
validate_email() {
    local email=$1
    local email_regex="^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,4}$"

    echo "Entered Email: $email"

    echo "$email" | grep -Pq "$email_regex"
    if [ $? -eq 0 ]; then
        return 0  # Valid email address
    else
        return 1  # Invalid email address
    fi
}
# *****************************************************************************
# Ask for the domain name
read -p "Enter the domain name for SSL certificate: " domain
while ! check_domain_ip "$domain"; do
    echo -e "\e[1;33mError: The domain does not belong to the actual host machine's public IP.\e[0m"
    read -p "Please enter a valid domain: " domain
done

# Ask for the email
read -p "Enter the email for SSL certificate: " email
while ! validate_email "$email"; do
    echo -e "\e[1;33mError: Invalid email address.\e[0m"
    read -p "Please enter a valid email address: " email
done
# *****************************************************************************
# Ask whether to change secrets or continue with installation
read -p "Do you want to change Postgres/Odoo Credentials? (yes/no): " change_secrets

if [ "$change_secrets" == "yes" ]; then
    # Execute secrets.sh script
    ./secrets.sh
else
    echo -e "\e[1;33mRunning With Demo Credentials!\e[0m"
fi
# *****************************************************************************
# Function to display a spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while ps -p $pid > /dev/null; do
        for i in $(seq 0 3); do
            echo -ne "\b${spinstr:$i:1}"
            sleep $delay
        done
    done

    echo -ne "\b "
}
# *****************************************************************************
# Function to install curl with a spinner
install_curl() {
    echo -e "\e[1;33mInstalling curl...\e[0m"  # Yellow color
    sudo apt-get update > /dev/null
    (sudo apt-get install -y curl > /dev/null 2>&1) &
    local spinner_pid=$!
    spinner $spinner_pid
    wait $spinner_pid
    echo -e "\e[1;32mCurl installation completed.\e[0m"  # Green color
    echo  # Add a space
}
# *****************************************************************************
# Function to install Docker with a spinner
install_docker() {
    echo -e "\e[1;33mInstalling Docker...\e[0m"
    curl -fsSL https://get.docker.com -o get-docker.sh > /dev/null
    (sudo sh get-docker.sh > /dev/null 2>&1) &
    local spinner_pid=$!
    spinner $spinner_pid
    wait $spinner_pid
    rm get-docker.sh
    echo  -e "\e[1;32mDocker installation completed.\e[0m"
}
# Function to install curl with a spinner
install_nginx() {
    echo -e "\e[1;33mInstalling nginx...\e[0m"  # Yellow color
    sudo apt-get update > /dev/null
    (sudo apt-get install -y nginx > /dev/null 2>&1) &
    local spinner_pid=$!
    spinner $spinner_pid
    wait $spinner_pid
    echo -e "\e[1;32mNginx installation completed.\e[0m"  # Green color
    echo  # Add a space
}
# Function to install curl with a spinner
install_certbot() {
    echo -e "\e[1;33mInstalling Certbot...\e[0m"  # Yellow color
    sudo apt-get update > /dev/null
    (sudo apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1) &
    local spinner_pid=$!
    spinner $spinner_pid
    wait $spinner_pid
    echo -e "\e[1;32mCertbot installation completed.\e[0m"  # Green color
    echo  # Add a space
}
cert_request() {
    echo -e "\e[1;33mRequesting certificate from let's Enscrypt...\e[0m"  # Yellow color
    (sudo certbot --nginx -d $domain --email $email --agree-tos > /dev/null 2>&1) &
    local spinner_pid=$!
    spinner $spinner_pid
    wait $spinner_pid
    echo -e "\e[1;32mCongrats !!! Certificate Obtained.\e[0m"  # Green color
    echo  # Add a space
}
# *****************************************************************************
# Run installation functions
install_curl
install_docker
install_nginx
install_certbot
mkdir -p /var/www/ssl-proof/$domain/.well-known
sudo cp ./nginx.conf /etc/nginx/sites-enabled/$domain.conf
sudo sed -i "s/server_name .*;/server_name $domain;/g" /etc/nginx/sites-enabled/$domain.conf
cert_request
#sudo certbot --nginx -d $domain -i nginx --email $email --agree-tos
sudo systemctl restart nginx.service
# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Set up Docker Compose services
echo -e "\e[1;32mSetting up Docker Compose services...\e[0m"
sudo docker-compose up -d

# Display messages for Docker services with colors
echo -e "\e[1;33mStarting Odoo service...\e[0m"  # Yellow color
simple_progress_bar 20
echo -e "\n\e[1;32mOdoo service is up!\e[0m"  # Green color

echo  # Add a space

echo -e "\e[1;33mStarting pgAdmin service...\e[0m"  # Yellow color
simple_progress_bar 20
echo -e "\n\e[1;32mpgAdmin service is up!\e[0m"  # Green color

echo  # Add a space

# Display clickable access URLs with colors
echo -e "\e[1;33mOdoo instance is accessible at: \e[34mhttps://$domain\e[0m"  # Yellow for message, Blue for URL
echo -e "\e[1;33mpgAdmin panel is accessible at: \e[34mhttp://$domain:5050\e[0m"  # Yellow for message, Blue for URL

echo  # Add a space

# Cleanup
echo -e "\e[1;33mCleaning up...\e[0m"  # Yellow color
# Add cleanup commands if necessary

echo -e "\e[1;32mScript execution complete!\e[0m"  # Green color
# *****************************************************************************

