#!/bin/bash
# Unofficial PlexDevelopment Products Installer
# This script automatically detects your Linux distribution and installs selected Plex products

#----- Color Definitions -----#
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

#----- Global Variables -----#
INSTALL_DIR="/var/www/plex"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
DISTRIBUTION=""
PKG_MANAGER=""

#----- Utility Functions -----#
print_header() {
    echo -e "\n${BOLD}${PURPLE}#----- $1 -----#${NC}\n"
}

print_step() {
    echo -e "${BLUE}[+] ${CYAN}$1${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

#----- System Detection -----#
detect_system() {
    print_header "System Detection"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRIBUTION=$ID
        print_step "Detected distribution: ${BOLD}$DISTRIBUTION${NC}"
        
        # Determine package manager
        if [ -x "$(command -v apt)" ]; then
            PKG_MANAGER="apt"
        elif [ -x "$(command -v dnf)" ]; then
            PKG_MANAGER="dnf"
        elif [ -x "$(command -v yum)" ]; then
            PKG_MANAGER="yum"
        elif [ -x "$(command -v pacman)" ]; then
            PKG_MANAGER="pacman"
        elif [ -x "$(command -v zypper)" ]; then
            PKG_MANAGER="zypper"
        else
            print_error "Unable to determine package manager"
            exit 1
        fi
        
        print_success "Using package manager: ${BOLD}$PKG_MANAGER${NC}"
    else
        print_error "Unable to detect Linux distribution"
        exit 1
    fi
}

#----- Install Dependencies -----#
install_dependencies() {
    print_header "Installing Dependencies"
    
    print_step "Updating package lists..."
    case $PKG_MANAGER in
        apt)
            sudo apt update -y
            sudo apt install -y curl wget git unzip nginx certbot python3-certbot-nginx tmux \
                dnsutils net-tools nano bind9-utils whois iputils-ping zip unzip telnet \
                software-properties-common apt-transport-https ca-certificates gnupg
            
            # Install Node.js 20+
            print_step "Installing Node.js 20+..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt install -y nodejs
            ;;
        dnf|yum)
            sudo $PKG_MANAGER update -y
            sudo $PKG_MANAGER install -y curl wget git unzip nginx certbot python3-certbot-nginx tmux \
                bind-utils net-tools nano whois iputils zip unzip telnet \
                dnf-plugins-core
            
            # Install Node.js 20+
            print_step "Installing Node.js 20+..."
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo -E bash -
            sudo $PKG_MANAGER install -y nodejs
            ;;
        pacman)
            sudo pacman -Syu --noconfirm
            sudo pacman -S --noconfirm curl wget git unzip nginx certbot certbot-nginx tmux \
                bind dnsutils net-tools nano whois iputils inetutils zip unzip
            
            # Install Node.js 20+
            print_step "Installing Node.js 20+..."
            sudo pacman -S --noconfirm nodejs npm
            ;;
        zypper)
            sudo zypper refresh
            sudo zypper install -y curl wget git unzip nginx certbot python-certbot-nginx tmux \
                bind-utils net-tools nano whois iputils zip unzip \
                telnet
            
            # Install Node.js 20+
            print_step "Installing Node.js 20+..."
            sudo zypper install -y nodejs20
            ;;
        *)
            print_error "Unsupported package manager: $PKG_MANAGER"
            exit 1
            ;;
    esac
    
    # Verify node version
    NODE_VERSION=$(node -v)
    print_step "Node.js version: $NODE_VERSION"
    
    # Check if version starts with v20 or higher
    if [[ ! $NODE_VERSION =~ ^v[2-9][0-9] ]]; then
        print_warning "Node.js version 20+ is required. Your version may be incompatible."
        read -p "Continue anyway? (y/n): " continue_install
        if [[ $continue_install != "y" && $continue_install != "Y" ]]; then
            print_error "Installation aborted."
            exit 1
        fi
    fi
    
    # Add check for DNS lookup tools
    if ! command -v dig &> /dev/null && ! command -v nslookup &> /dev/null && ! command -v host &> /dev/null; then
        print_warning "No DNS lookup tools (dig, nslookup, or host) found. Domain validation may be limited."
    else
        print_success "DNS lookup tools found. Domain validation will be available."
    fi
    
    print_success "Dependencies installed successfully"
}

#----- Check Domain DNS -----#
check_domain_dns() {
    local domain=$1
    local skip_check=${2:-false}
    
    if [[ "$skip_check" == true ]]; then
        return 0
    fi
    
    print_step "Checking if domain $domain is pointed to this server..."
    
    # Get server's public IP
    local server_ip=$(curl -s https://ifconfig.me)
    if [ -z "$server_ip" ]; then
        server_ip=$(curl -s https://api.ipify.org)
    fi
    
    print_step "Server IP: $server_ip"
    
    # Check if domain resolves
    local domain_ip=""
    
    if command -v dig &> /dev/null; then
        domain_ip=$(dig +short A $domain | head -n1)
    elif command -v nslookup &> /dev/null; then
        domain_ip=$(nslookup $domain | grep -A1 'Name:' | grep 'Address:' | awk '{print $2}' | head -n1)
    elif command -v host &> /dev/null; then
        domain_ip=$(host $domain | grep 'has address' | awk '{print $4}' | head -n1)
    else
        print_warning "DNS lookup tools not found. Please install dig, nslookup, or host."
        
        while true; do
            read -p "Confirm domain $domain is pointed to $server_ip? (y/n/skip): " dns_confirm
            if [[ $dns_confirm == "y" || $dns_confirm == "Y" ]]; then
                return 0
            elif [[ $dns_confirm == "skip" ]]; then
                print_warning "Skipping domain validation. SSL setup might fail."
                return 0
            else
                print_step "Please update your DNS settings and try again."
            fi
        done
    fi
    
    if [ -z "$domain_ip" ]; then
        print_warning "Domain $domain does not resolve to any IP address."
        while true; do
            print_step "DNS configuration required:"
            print_step "1. Log in to your domain registrar or DNS provider"
            print_step "2. Add an A record pointing to $server_ip"
            print_step "3. Wait for DNS propagation (may take up to 24 hours)"
            read -p "Check DNS again? (y/n/skip): " dns_check
            if [[ $dns_check == "y" || $dns_check == "Y" ]]; then
                if command -v dig &> /dev/null; then
                    domain_ip=$(dig +short A $domain | head -n1)
                elif command -v nslookup &> /dev/null; then
                    domain_ip=$(nslookup $domain | grep -A1 'Name:' | grep 'Address:' | awk '{print $2}' | head -n1)
                elif command -v host &> /dev/null; then
                    domain_ip=$(host $domain | grep 'has address' | awk '{print $4}' | head -n1)
                fi
                
                if [ -n "$domain_ip" ] && [ "$domain_ip" == "$server_ip" ]; then
                    print_success "Domain $domain is now correctly pointed to this server!"
                    return 0
                elif [ -n "$domain_ip" ]; then
                    print_warning "Domain $domain is pointed to $domain_ip, not $server_ip"
                else
                    print_warning "Domain $domain still does not resolve"
                fi
            elif [[ $dns_check == "skip" ]]; then
                print_warning "Skipping domain validation. SSL setup might fail."
                return 0
            else
                print_error "Cannot proceed without proper DNS configuration"
                return 1
            fi
        done
    elif [ "$domain_ip" == "$server_ip" ]; then
        print_success "Domain $domain is correctly pointed to this server: $server_ip"
        return 0
    else
        print_warning "Domain $domain is pointed to $domain_ip, but this server's IP is $server_ip"
        while true; do
            print_step "DNS configuration required:"
            print_step "1. Log in to your domain registrar or DNS provider"
            print_step "2. Update the A record to point to $server_ip"
            print_step "3. Wait for DNS propagation (may take up to 24 hours)"
            read -p "Check DNS again? (y/n/skip): " dns_check
            if [[ $dns_check == "y" || $dns_check == "Y" ]]; then
                if command -v dig &> /dev/null; then
                    domain_ip=$(dig +short A $domain | head -n1)
                elif command -v nslookup &> /dev/null; then
                    domain_ip=$(nslookup $domain | grep -A1 'Name:' | grep 'Address:' | awk '{print $2}' | head -n1)
                elif command -v host &> /dev/null; then
                    domain_ip=$(host $domain | grep 'has address' | awk '{print $4}' | head -n1)
                fi
                
                if [ -n "$domain_ip" ] && [ "$domain_ip" == "$server_ip" ]; then
                    print_success "Domain $domain is now correctly pointed to this server!"
                    return 0
                elif [ -n "$domain_ip" ]; then
                    print_warning "Domain $domain is pointed to $domain_ip, not $server_ip"
                else
                    print_warning "Domain $domain does not resolve"
                fi
            elif [[ $dns_check == "skip" ]]; then
                print_warning "Skipping domain validation. SSL setup might fail."
                return 0
            else
                print_error "Cannot proceed without proper DNS configuration"
                return 1
            fi
        done
    fi
}

#----- Open Port in Firewall -----#
open_port() {
    local port=$1
    local description=$2
    
    print_step "Attempting to open port $port for $description..."
    
    # Check which firewall is in use
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian with UFW
        sudo ufw allow $port/tcp
        if [ $? -eq 0 ]; then
            print_success "Port $port opened using UFW"
        else
            print_warning "Failed to open port with UFW. You may need to open it manually."
        fi
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL/Fedora with firewalld
        sudo firewall-cmd --permanent --add-port=$port/tcp
        sudo firewall-cmd --reload
        if [ $? -eq 0 ]; then
            print_success "Port $port opened using firewalld"
        else
            print_warning "Failed to open port with firewalld. You may need to open it manually."
        fi
    elif command -v iptables &> /dev/null; then
        # Direct iptables as fallback
        sudo iptables -A INPUT -p tcp --dport $port -j ACCEPT
        if command -v iptables-save &> /dev/null; then
            case $PKG_MANAGER in
                apt)
                    sudo netfilter-persistent save
                    ;;
                dnf|yum)
                    sudo service iptables save
                    ;;
                pacman)
                    sudo iptables-save | sudo tee /etc/iptables/iptables.rules
                    ;;
                zypper)
                    sudo service SuSEfirewall2 save
                    ;;
            esac
        else
            print_warning "iptables-save not found. Firewall rules may not persist after reboot."
        fi
        print_success "Port $port opened using iptables"
    else
        print_warning "No supported firewall detected. Please open port $port manually in your firewall settings."
    fi
}


#----- Setup Nginx -----#
setup_nginx() {
    local domain=$1
    local port=$2
    local product=$3
    
    print_step "Setting up Nginx for $product at $domain (port $port)"
    
    # Create Nginx config
    if [[ "$product" == "plexstore" ]]; then
        # Special config for PlexStore with 502 page
        sudo tee "$NGINX_AVAILABLE/$domain.conf" > /dev/null << EOF
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    error_page 502 /502.html;
    location = /502.html {
        root $INSTALL_DIR/plexstore;
    }
}
EOF
    else
        # Standard config for other products
        sudo tee "$NGINX_AVAILABLE/$domain.conf" > /dev/null << EOF
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
    fi
    
    # Create a 502 error page for PlexStore
    if [[ "$product" == "plexstore" ]]; then
        sudo mkdir -p "$INSTALL_DIR/plexstore"
        sudo tee "$INSTALL_DIR/plexstore/502.html" > /dev/null << EOF
<!DOCTYPE html>
<html>
<head>
    <title>PlexStore - Service Unavailable</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #e74c3c; }
        p { font-size: 18px; }
    </style>
</head>
<body>
    <h1>502 - Service Unavailable</h1>
    <p>The PlexStore service is currently unavailable. Please try again later.</p>
    <p>If this issue persists, please contact the administrator.</p>
</body>
</html>
EOF
    fi
    
    # Enable site
    sudo ln -sf "$NGINX_AVAILABLE/$domain.conf" "$NGINX_ENABLED/"
    
    # Test Nginx config
    sudo nginx -t
    
    # Restart Nginx
    sudo systemctl restart nginx
    
    print_success "Nginx configured for $domain"
}

#----- Setup SSL with Certbot -----#
setup_ssl() {
    local domain=$1
    local email=$2
    
    print_step "Setting up SSL for $domain using Certbot"
    
    # Get SSL certificate
    sudo certbot --nginx -d $domain --non-interactive --agree-tos --email $email
    
    print_success "SSL certificate installed for $domain"
}

#----- Create Startup Script -----#
create_startup_script() {
    local product=$1
    local product_path=$2
    local service_name="plex-$product"
    local tmux_session_name="plex-$product"
    
    print_step "Creating startup script for $product using tmux..."
    
    # Create a more robust startup script that will run in tmux
    sudo tee "$product_path/start.sh" > /dev/null << EOF
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root

# Create a lock file to prevent multiple instances
LOCK_FILE="/tmp/$tmux_session_name.lock"

if [ -e \$LOCK_FILE ]; then
    PID=\$(cat \$LOCK_FILE)
    if ps -p \$PID > /dev/null; then
        echo "Process already running with PID \$PID"
        exit 0
    else
        echo "Removing stale lock file"
        rm -f \$LOCK_FILE
    fi
fi

# Store the PID
echo \$\$ > \$LOCK_FILE

# Check if the tmux session already exists
if ! /usr/bin/tmux has-session -t $tmux_session_name 2>/dev/null; then
    # Create a new tmux session
    /usr/bin/tmux new-session -d -s $tmux_session_name "cd $product_path && /usr/bin/node ."
    echo "Created new tmux session: $tmux_session_name"
    exit 0
else
    echo "Session $tmux_session_name already exists"
    exit 0
fi
EOF
    sudo chmod +x "$product_path/start.sh"
    
    # Create systemd service
    sudo tee "/etc/systemd/system/$service_name.service" > /dev/null << EOF
[Unit]
Description=Plex $product service
After=network.target

[Service]
Type=forking
User=root
ExecStart=$product_path/start.sh
Restart=on-failure
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=plex-$product

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable the service to start on boot
    sudo systemctl enable $service_name
    
    # Try to start the service
    if sudo systemctl start $service_name; then
        print_success "Service started successfully"
    else
        print_warning "Service failed to start. You can check the logs with: sudo journalctl -u $service_name"
        
        # As a fallback, run the script directly
        print_step "Attempting to run the start script directly..."
        sudo bash "$product_path/start.sh"
    fi
    
    print_success "Startup script created for $product"
    print_step "Please configure your bot first then you can start it with the commands below."
    print_step "To configure the bot run this command: nano $product_path/config.yml"
    print_step "You can start the service with: sudo systemctl start $service_name"
    print_step "You can attach to the tmux session with: tmux attach -t $tmux_session_name"
    print_step "The service is set to auto-start on system boot"
}
#----- Extract Product -----#
extract_product() {
    local archive_path=$1
    local extract_path=$2
    local product_name=$(basename "$extract_path")
    
    print_step "Extracting product from $archive_path to $extract_path..."
    
    # Create directory
    sudo mkdir -p "$extract_path"
    
    # Determine archive type and extract (redirect all output to prevent capture)
    if [[ "$archive_path" =~ \.zip$ ]]; then
        sudo unzip -o "$archive_path" -d "$extract_path" > /dev/null 2>&1
    elif [[ "$archive_path" =~ \.rar$ ]]; then
        # Check if unrar is installed
        if ! command -v unrar &> /dev/null; then
            print_step "Installing unrar..."
            case $PKG_MANAGER in
                apt)
                    sudo apt install -y unrar > /dev/null 2>&1
                    ;;
                dnf|yum)
                    sudo $PKG_MANAGER install -y unrar > /dev/null 2>&1
                    ;;
                pacman)
                    sudo pacman -S --noconfirm unrar > /dev/null 2>&1
                    ;;
                zypper)
                    sudo zypper install -y unrar > /dev/null 2>&1
                    ;;
            esac
        fi
        sudo unrar x "$archive_path" "$extract_path" > /dev/null 2>&1
    else
        print_error "Unsupported archive format: $archive_path"
        return 1
    fi
    
    print_success "Product extracted successfully"
    
    # Check for product subfolder without printing anything
    local final_path=""
    
    # Check if the product folder was created inside extract_path
    if [ -d "$extract_path/$product_name" ]; then
        final_path="$extract_path/$product_name"
    else
        # Check if there's any other directory created
        local subdir=$(find "$extract_path" -mindepth 1 -maxdepth 1 -type d | head -n 1)
        if [ -n "$subdir" ]; then
            final_path="$subdir"
        else
            final_path="$extract_path"
        fi
    fi
    
    print_step "Installation path: $final_path"
    # Return the path only
    echo "$final_path"
}

#----- Install NPM Dependencies -----#
install_npm_dependencies() {
    local product_path=$1
    
    print_step "Installing NPM dependencies in $product_path..."
    
    # Check if package.json exists
    if [ ! -f "$product_path/package.json" ]; then
        print_warning "No package.json found in $product_path"
        ls -la "$product_path"
        return 1
    fi
    
    # Navigate to the product directory and install dependencies
    cd "$product_path" && sudo npm install
    
    if [ $? -eq 0 ]; then
        print_success "NPM dependencies installed successfully"
    else
        print_error "Failed to install NPM dependencies"
    fi
}

#----- Install PlexTickets -----#
install_plextickets() {
    print_header "Installing PlexTickets"
    
    local with_dashboard=$1
    local base_path="$INSTALL_DIR/plextickets"
    
    # Get archive path
    read -p "Enter the path to the PlexTickets archive file (zip/rar): " archive_path
    
    # Extract product and get the actual path (capture only the last line)
    local install_path=$(extract_product "$archive_path" "$base_path" | tail -n 1)
    
    # Verify the path exists (remove any escape sequences)
    if [ ! -d "$install_path" ]; then
        print_error "Installation path not found: $install_path"
        exit 1
    fi
    
    # Install NPM dependencies
    install_npm_dependencies "$install_path"
    
    # Check if dashboard should be installed
    if [ "$with_dashboard" = true ]; then
        local dashboard_port
        read -p "Enter port for PlexTickets Dashboard (default: 3000): " dashboard_port
        dashboard_port=${dashboard_port:-3000}
        # Open dashboard port in firewall
        open_port "$dashboard_port" "PlexTickets Dashboard"
        
        read -p "Enter domain for PlexTickets Dashboard (e.g., tickets.example.com): " domain
        read -p "Enter email for SSL certificate: " email
        
        read -p "Enter the path to the PlexTickets Dashboard archive file (zip/rar): " dashboard_archive
        
        # Create addons directory if it doesn't exist
        sudo mkdir -p "$install_path/addons"
        
        # Extract dashboard and get the actual path
        local dashboard_path=$(extract_product "$dashboard_archive" "$install_path/addons" | tail -n 1)
        
        
        if ! check_domain_dns "$domain"; then
            print_error "Domain verification failed for $domain"
            read -p "Do you want to proceed without proper DNS configuration? This may cause SSL setup to fail. (y/n): " proceed_anyway
            if [[ $proceed_anyway != "y" && $proceed_anyway != "Y" ]]; then
                print_error "Installation aborted."
                exit 1
            fi
        fi



        # Setup Nginx and SSL
        setup_nginx "$domain" "$dashboard_port" "plextickets"
        setup_ssl "$domain" "$email"
    fi
    
    # Ask about creating startup script
    read -p "Do you want to set up auto-start on boot? (y/n): " setup_startup
    if [[ $setup_startup == "y" || $setup_startup == "Y" ]]; then
        create_startup_script "plextickets" "$install_path"
    fi
    
    print_success "PlexTickets installed successfully"
}

#----- Install PlexStaff -----#
install_plexstaff() {
    print_header "Installing PlexStaff"
    
    local base_path="$INSTALL_DIR/plexstaff"
    
    # Get archive path
    read -p "Enter the path to the PlexStaff archive file (zip/rar): " archive_path
    
    # Extract product and get the actual path (capture only the last line)
    local install_path=$(extract_product "$archive_path" "$base_path" | tail -n 1)
    
    # Verify the path exists
    if [ ! -d "$install_path" ]; then
        print_error "Installation path not found: $install_path"
        exit 1
    fi
    
    print_step "Using installation path: $install_path"
    
    # Install NPM dependencies
    install_npm_dependencies "$install_path"
    
    # Get port
    local port
    read -p "Enter port for PlexStaff (default: 3001): " port
    port=${port:-3001}
    # Open port in firewall
    open_port "$port" "PlexStaff"
    
    # Get domain and email
    read -p "Enter domain for PlexStaff (e.g., staff.example.com): " domain
    read -p "Enter email for SSL certificate: " email
    
    # Check if domain is pointed to this server
    if ! check_domain_dns "$domain"; then
        print_error "Domain verification failed for $domain"
        read -p "Do you want to proceed without proper DNS configuration? This may cause SSL setup to fail. (y/n): " proceed_anyway
        if [[ $proceed_anyway != "y" && $proceed_anyway != "Y" ]]; then
            print_error "Installation aborted."
            exit 1
        fi
    fi



    # Setup Nginx and SSL
    setup_nginx "$domain" "$port" "plexstaff"
    setup_ssl "$domain" "$email"
    
    # Ask about creating startup script
    read -p "Do you want to set up auto-start on boot? (y/n): " setup_startup
    if [[ $setup_startup == "y" || $setup_startup == "Y" ]]; then
        create_startup_script "plexstaff" "$install_path"
    fi
    
    print_success "PlexStaff installed successfully"
}

#----- Install PlexStatus -----#
install_plexstatus() {
    print_header "Installing PlexStatus"
    
    local base_path="$INSTALL_DIR/plexstatus"
    
    # Get archive path
    read -p "Enter the path to the PlexStatus archive file (zip/rar): " archive_path
    
    # Extract product and get the actual path (capture only the last line)
    local install_path=$(extract_product "$archive_path" "$base_path" | tail -n 1)
    
    # Verify the path exists
    if [ ! -d "$install_path" ]; then
        print_error "Installation path not found: $install_path"
        exit 1
    fi
    
    print_step "Using installation path: $install_path"
    
    # Install NPM dependencies
    install_npm_dependencies "$install_path"
    
    # Get port
    local port
    read -p "Enter port for PlexStatus (default: 3002): " port
    port=${port:-3002}
    # Open port in firewall
    open_port "$port" "PlexStatus"
    
    # Get domain and email
    read -p "Enter domain for PlexStatus (e.g., status.example.com): " domain
    read -p "Enter email for SSL certificate: " email
    


    # Check if domain is pointed to this server
    if ! check_domain_dns "$domain"; then
        print_error "Domain verification failed for $domain"
        read -p "Do you want to proceed without proper DNS configuration? This may cause SSL setup to fail. (y/n): " proceed_anyway
        if [[ $proceed_anyway != "y" && $proceed_anyway != "Y" ]]; then
            print_error "Installation aborted."
            exit 1
        fi
    fi
    # Setup Nginx and SSL
    setup_nginx "$domain" "$port" "plexstatus"
    setup_ssl "$domain" "$email"
    
    # Ask about creating startup script
    read -p "Do you want to set up auto-start on boot? (y/n): " setup_startup
    if [[ $setup_startup == "y" || $setup_startup == "Y" ]]; then
        create_startup_script "plexstatus" "$install_path"
    fi
    
    print_success "PlexStatus installed successfully"
}

#----- Install PlexStore -----#
install_plexstore() {
    print_header "Installing PlexStore"
    
    local base_path="$INSTALL_DIR/plexstore"
    
    # Get archive path
    read -p "Enter the path to the PlexStore archive file (zip/rar): " archive_path
    
    # Extract product and get the actual path (capture only the last line)
    local install_path=$(extract_product "$archive_path" "$base_path" | tail -n 1)
    
    # Verify the path exists
    if [ ! -d "$install_path" ]; then
        print_error "Installation path not found: $install_path"
        exit 1
    fi
    
    print_step "Using installation path: $install_path"
    
    # Install NPM dependencies
    install_npm_dependencies "$install_path"
    
    # Get port
    local port
    read -p "Enter port for PlexStore (default: 3003): " port
    port=${port:-3003}
    # Open port in firewall
    open_port "$port" "PlexStore"
    
    # Get domain and email
    read -p "Enter domain for PlexStore (e.g., store.example.com): " domain
    read -p "Enter email for SSL certificate: " email
    
    # Check if domain is pointed to this server
    if ! check_domain_dns "$domain"; then
        print_error "Domain verification failed for $domain"
        read -p "Do you want to proceed without proper DNS configuration? This may cause SSL setup to fail. (y/n): " proceed_anyway
        if [[ $proceed_anyway != "y" && $proceed_anyway != "Y" ]]; then
            print_error "Installation aborted."
            exit 1
        fi
    fi



    # Setup Nginx and SSL with special 502 page
    setup_nginx "$domain" "$port" "plexstore"
    setup_ssl "$domain" "$email"
    
    # Create 502 error page in the correct location
    sudo tee "$install_path/502.html" > /dev/null << EOF
<!DOCTYPE html>
<html>
<head>
    <title>PlexStore - Service Unavailable</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #e74c3c; }
        p { font-size: 18px; }
    </style>
</head>
<body>
    <h1>502 - Service Unavailable</h1>
    <p>The PlexStore service is currently unavailable. Please try again later.</p>
    <p>If this issue persists, please contact the administrator.</p>
</body>
</html>
EOF
    
    # Ask about creating startup script
    read -p "Do you want to set up auto-start on boot? (y/n): " setup_startup
    if [[ $setup_startup == "y" || $setup_startup == "Y" ]]; then
        create_startup_script "plexstore" "$install_path"
    fi
    
    print_success "PlexStore installed successfully"
}

#----- Install PlexForms -----#
install_plexforms() {
    print_header "Installing PlexForms"
    
    local base_path="$INSTALL_DIR/plexforms"
    
    # Get archive path
    read -p "Enter the path to the PlexForms archive file (zip/rar): " archive_path
    
    # Extract product and get the actual path (capture only the last line)
    local install_path=$(extract_product "$archive_path" "$base_path" | tail -n 1)
    
    # Verify the path exists
    if [ ! -d "$install_path" ]; then
        print_error "Installation path not found: $install_path"
        exit 1
    fi
    
    print_step "Using installation path: $install_path"
    
    # Install NPM dependencies
    install_npm_dependencies "$install_path"
    
    # Get port
    local port
    read -p "Enter port for PlexForms (default: 3004): " port
    port=${port:-3004}
    # Open port in firewall
    open_port "$port" "PlexForms"
    
    # Get domain and email
    read -p "Enter domain for PlexForms (e.g., forms.example.com): " domain
    read -p "Enter email for SSL certificate: " email
    
    # Check if domain is pointed to this server
    if ! check_domain_dns "$domain"; then
        print_error "Domain verification failed for $domain"
        read -p "Do you want to proceed without proper DNS configuration? This may cause SSL setup to fail. (y/n): " proceed_anyway
        if [[ $proceed_anyway != "y" && $proceed_anyway != "Y" ]]; then
            print_error "Installation aborted."
            exit 1
        fi
    fi


    # Setup Nginx and SSL
    setup_nginx "$domain" "$port" "plexforms"
    setup_ssl "$domain" "$email"
    
    # Ask about creating startup script
    read -p "Do you want to set up auto-start on boot? (y/n): " setup_startup
    if [[ $setup_startup == "y" || $setup_startup == "Y" ]]; then
        create_startup_script "plexforms" "$install_path"
    fi
    
    print_success "PlexForms installed successfully"
}

#----- Main Script -----#
main() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  _____  _           _____                 _                                  _   "
    echo " |  __ \| |         |  __ \               | |                                | |  "
    echo " | |__) | | _____  _| |  | | _____   _____| | ___  _ __  _ __ ___   ___ _ __ | |_ "
    echo " |  ___/| |/ _ \ \/ / |  | |/ _ \ \ / / _ \ |/ _ \| '_ \| '_ \` _ \ / _ \ '_ \| __|"
    echo " | |    | |  __/>  <| |__| |  __/\ V /  __/ | (_) | |_) | | | | | |  __/ | | | |_ "
    echo " |_|    |_|\___/_/\_\_____/ \___| \_/ \___|_|\___/| .__/|_| |_| |_|\___|_| |_|\__|"
    echo "                                                  | |                             "
    echo "                                                  |_|                             "
    echo -e "${NC}"
    echo -e "${BOLD}${PURPLE}Installation Script for PlexDevelopment Products${NC}\n"

    
    # Detect system
    detect_system
    
    # Install dependencies
    install_dependencies
    
    # Create install directory
    sudo mkdir -p $INSTALL_DIR

    clear
    echo -e "${BOLD}${CYAN}"
    echo "  _____  _           _____                 _                                  _   "
    echo " |  __ \| |         |  __ \               | |                                | |  "
    echo " | |__) | | _____  _| |  | | _____   _____| | ___  _ __  _ __ ___   ___ _ __ | |_ "
    echo " |  ___/| |/ _ \ \/ / |  | |/ _ \ \ / / _ \ |/ _ \| '_ \| '_ \` _ \ / _ \ '_ \| __|"
    echo " | |    | |  __/>  <| |__| |  __/\ V /  __/ | (_) | |_) | | | | | |  __/ | | | |_ "
    echo " |_|    |_|\___/_/\_\_____/ \___| \_/ \___|_|\___/| .__/|_| |_| |_|\___|_| |_|\__|"
    echo "                                                  | |                             "
    echo "                                                  |_|                             "
    echo -e "${NC}"
    echo -e "${BOLD}${PURPLE}Installation Script for PlexDevelopment Products${NC}\n"


    # Product selection menu
    print_header "Product Selection"
    
    echo -e "${YELLOW}Please select a product to install:${NC}"
    echo -e "${CYAN}1) PlexTickets${NC}"
    echo -e "${CYAN}2) PlexStaff${NC}" 
    echo -e "${CYAN}3) PlexStatus${NC}"
    echo -e "${CYAN}4) PlexStore${NC}"
    echo -e "${CYAN}5) PlexForms${NC}"
    echo -e "${CYAN}0) Exit${NC}"
    
    read -p "Enter your choice (0-5): " choice
    
    case $choice in
        1)
            read -p "Install with dashboard? (y/n): " dashboard
            
            if [[ $dashboard == "y" || $dashboard == "Y" ]]; then
                install_plextickets true
            else
                install_plextickets false
            fi
            ;;
        2)
            install_plexstaff
            ;;
        3)
            install_plexstatus
            ;;
        4)
            install_plexstore
            ;;
        5)
            install_plexforms
            ;;
        0)
            print_warning "Installation canceled"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    print_header "Installation Complete"
    print_success "Thank you for using PlexDevelopment Installer!"
}

# Run the main function
main
