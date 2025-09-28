#!/bin/bash

# OSCP Setup Script
# This script configures a machine for OSCP preparation
# Designed specifically for Kali Linux

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to clean up problematic repositories
cleanup_repositories() {
    print_status "Cleaning up problematic repositories..."
    
    # Find and remove konghq repositories
    if find /etc/apt -name "*.list" -exec grep -l "konghq" {} \; 2>/dev/null | head -1; then
        print_status "Found konghq repositories, removing them..."
        find /etc/apt -name "*.list" -exec grep -l "konghq" {} \; 2>/dev/null | while read file; do
            print_status "Removing konghq entries from: $file"
            sudo sed -i '/konghq/d' "$file"
        done
        print_success "konghq repositories removed"
    else
        print_success "No problematic konghq repositories found"
    fi
    
    # Remove any other problematic repositories that might cause issues
    print_status "Checking for other problematic repositories..."
    if find /etc/apt -name "*.list" -exec grep -l "ubuntu" {} \; 2>/dev/null | head -1; then
        print_warning "Found Ubuntu repositories on Kali system"
        print_status "These may cause compatibility issues"
    fi
}

# Function to disable IPv6
disable_ipv6() {
    print_status "Disabling IPv6 to resolve connectivity issues..."
    
    # Check if IPv6 is already disabled
    if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" = "1" ]; then
        print_success "IPv6 is already disabled"
        return 0
    fi
    
    # Disable IPv6 temporarily
    print_status "Temporarily disabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 2>/dev/null || true
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 2>/dev/null || true
    
    # Disable IPv6 permanently
    print_status "Disabling IPv6 permanently..."
    if ! grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf; then
        echo "" | sudo tee -a /etc/sysctl.conf
        echo "# Disable IPv6 - Added by OSCP setup script" | sudo tee -a /etc/sysctl.conf
        echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
        echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
        echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
        print_success "IPv6 disabled permanently"
    else
        print_success "IPv6 already disabled in sysctl.conf"
    fi
    
    # Apply changes
    sudo sysctl -p 2>/dev/null || true
}

# Function to update package lists
update_packages() {
    print_status "Updating Kali package lists..."
    # Try to update with error handling
    if ! sudo apt update 2>/dev/null; then
        print_warning "apt update failed, trying with IPv4 only..."
        # Force IPv4 to avoid IPv6 connectivity issues
        sudo apt update -o Acquire::ForceIPv4=true 2>/dev/null || {
            print_warning "apt update still failed, continuing with installation..."
        }
    fi
}

# Function to install package if not present
install_if_missing() {
    local package=$1
    local install_cmd=$2
    
    if command_exists "$package"; then
        print_success "$package is already installed"
    else
        print_status "Installing $package..."
        eval "$install_cmd"
        if command_exists "$package"; then
            print_success "$package installed successfully"
        else
            print_error "Failed to install $package"
            return 1
        fi
    fi
}

# Function to create tools directory
create_tools_directory() {
    print_status "Creating tools directory in home folder..."
    mkdir -p "$HOME/tools"
    print_success "Tools directory created at $HOME/tools"
}

# Function to add tools directory to PATH
add_tools_to_path() {
    print_status "Adding tools directory to PATH..."
    
    TOOLS_PATH_LINE='export PATH="$HOME/tools:$PATH"'
    
    # Function to add to shell config file
    add_to_shell_config() {
        local config_file=$1
        local shell_name=$2
        
        if [ -f "$config_file" ]; then
            if ! grep -q 'export PATH="$HOME/tools:$PATH"' "$config_file"; then
                echo "" >> "$config_file"
                echo "# OSCP Tools - Added by setup script" >> "$config_file"
                echo "$TOOLS_PATH_LINE" >> "$config_file"
                print_success "Added tools directory to $shell_name config: $config_file"
            else
                print_success "Tools directory already in $shell_name PATH"
            fi
        else
            print_warning "$shell_name config file not found: $config_file"
        fi
    }
    
    # Add to bashrc
    add_to_shell_config "$HOME/.bashrc" "bash"
    
    # Add to zshrc
    add_to_shell_config "$HOME/.zshrc" "zsh"
    
    # Add to bash_profile if it exists
    if [ -f "$HOME/.bash_profile" ]; then
        add_to_shell_config "$HOME/.bash_profile" "bash_profile"
    fi
    
    # Add to profile if it exists
    if [ -f "$HOME/.profile" ]; then
        add_to_shell_config "$HOME/.profile" "profile"
    fi
    
    print_success "PATH configuration completed"
    print_status "Note: You may need to restart your terminal or run 'source ~/.bashrc' (or ~/.zshrc) for changes to take effect"
}

# Function to install rustscan
install_rustscan() {
    print_status "Checking for rustscan..."
    if command_exists rustscan; then
        print_success "rustscan is already installed"
    else
        print_status "Installing rustscan..."
        
        # Try package manager first
        print_status "Trying package manager installation..."
        if sudo apt install -y rustscan 2>/dev/null; then
            if command_exists rustscan; then
                print_success "rustscan installed via package manager"
                return 0
            fi
        fi
        
        # If package manager fails, download from bee-san fork (more actively maintained)
        print_status "Package manager failed, downloading from bee-san fork..."
        
        # Detect system architecture
        ARCH=$(uname -m)
        case $ARCH in
            x86_64)
                ARCH_NAME="x86_64-unknown-linux-gnu"
                ;;
            aarch64|arm64)
                ARCH_NAME="aarch64-unknown-linux-gnu"
                ;;
            armv7l)
                ARCH_NAME="armv7-unknown-linux-gnueabihf"
                ;;
            *)
                print_error "Unsupported architecture: $ARCH"
                print_status "Manual installation:"
                print_status "1. Visit: https://github.com/bee-san/RustScan/releases"
                print_status "2. Download the appropriate file for your architecture"
                return 1
                ;;
        esac
        
        print_status "Detected architecture: $ARCH ($ARCH_NAME)"
        
        # Get latest release from bee-san fork
        print_status "Fetching latest release from bee-san fork..."
        LATEST_RELEASE=$(curl -s --connect-timeout 10 https://api.github.com/repos/bee-san/RustScan/releases/latest | grep "tag_name" | cut -d '"' -f 4)
        
        if [ -z "$LATEST_RELEASE" ] || [ "$LATEST_RELEASE" = "null" ]; then
            print_warning "Could not get latest release from API, trying alternative method..."
            # Try to get release info from the releases page directly
            LATEST_RELEASE=$(curl -s --connect-timeout 10 "https://github.com/bee-san/RustScan/releases" | grep -o 'tag/[^"]*' | head -1 | cut -d'/' -f2)
            
            if [ -z "$LATEST_RELEASE" ]; then
                print_error "Could not get latest release information"
                print_status "Manual installation:"
                print_status "1. Visit: https://github.com/bee-san/RustScan/releases"
                print_status "2. Download the appropriate file for your architecture"
                return 1
            fi
        fi
        
        print_status "Latest release: $LATEST_RELEASE"
        
        # Try different file formats for the architecture
        DOWNLOAD_SUCCESS=false
        for file_format in "rustscan-${LATEST_RELEASE}-${ARCH_NAME}.deb" "rustscan-${LATEST_RELEASE}-${ARCH_NAME}.tar.gz" "rustscan-${LATEST_RELEASE}-${ARCH_NAME}"; do
            DOWNLOAD_URL="https://github.com/bee-san/RustScan/releases/download/${LATEST_RELEASE}/${file_format}"
            print_status "Trying: $DOWNLOAD_URL"
            
            if wget "$DOWNLOAD_URL" -O "/tmp/${file_format}" 2>/dev/null; then
                print_success "Downloaded: $file_format"
                DOWNLOAD_SUCCESS=true
                DOWNLOADED_FILE="/tmp/${file_format}"
                break
            fi
        done
        
        if [ "$DOWNLOAD_SUCCESS" = false ]; then
            print_error "Failed to download any file for architecture $ARCH_NAME"
            print_status "Manual installation:"
            print_status "1. Visit: https://github.com/bee-san/RustScan/releases"
            print_status "2. Download the appropriate file for your architecture"
            return 1
        fi
        
        # Install based on file type
        if [[ "$DOWNLOADED_FILE" == *.deb ]]; then
            print_status "Installing .deb package..."
            if sudo dpkg -i "$DOWNLOADED_FILE" 2>/dev/null; then
                print_success "rustscan installed via .deb package"
                rm -f "$DOWNLOADED_FILE"
            else
                print_warning "dpkg installation failed, trying to fix dependencies..."
                sudo apt-get install -f -y
                if sudo dpkg -i "$DOWNLOADED_FILE" 2>/dev/null; then
                    print_success "rustscan installed via .deb package (after dependency fix)"
                    rm -f "$DOWNLOADED_FILE"
                else
                    print_error "Failed to install .deb package"
                    rm -f "$DOWNLOADED_FILE"
                    return 1
                fi
            fi
        elif [[ "$DOWNLOADED_FILE" == *.tar.gz ]]; then
            print_status "Extracting and installing binary..."
            if tar -xzf "$DOWNLOADED_FILE" -C /tmp/ 2>/dev/null; then
                # Find the rustscan binary
                RUSTSCAN_BINARY=$(find /tmp -name "rustscan" -type f 2>/dev/null | head -1)
                if [ ! -z "$RUSTSCAN_BINARY" ]; then
                    sudo mv "$RUSTSCAN_BINARY" /usr/local/bin/rustscan
                    sudo chmod +x /usr/local/bin/rustscan
                    print_success "rustscan binary installed"
                    rm -f "$DOWNLOADED_FILE"
                else
                    print_error "Could not find rustscan binary in archive"
                    rm -f "$DOWNLOADED_FILE"
                    return 1
                fi
            else
                print_error "Failed to extract archive"
                rm -f "$DOWNLOADED_FILE"
                return 1
            fi
        else
            # Assume it's a binary file
            print_status "Installing binary..."
            sudo mv "$DOWNLOADED_FILE" /usr/local/bin/rustscan
            sudo chmod +x /usr/local/bin/rustscan
            print_success "rustscan binary installed"
        fi
        
        # Verify installation
        if command_exists rustscan; then
            print_success "rustscan installed successfully"
        else
            print_error "rustscan installation failed"
            return 1
        fi
    fi
}

# Function to install nmap
install_nmap() {
    print_status "Checking for nmap..."
    if command_exists nmap; then
        print_success "nmap is already installed"
    else
        print_status "Installing nmap..."
        sudo apt install -y nmap
        
        if command_exists nmap; then
            print_success "nmap installed successfully"
        else
            print_error "Failed to install nmap"
            return 1
        fi
    fi
}

# Function to create scanner script
create_scanner_script() {
    print_status "Copying scanner.sh script..."
    
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy scanner.sh to tools directory
    if [ -f "$SCRIPT_DIR/scanner.sh" ]; then
        cp "$SCRIPT_DIR/scanner.sh" "$HOME/tools/scanner.sh"
        chmod +x "$HOME/tools/scanner.sh"
        print_success "scanner.sh copied and made executable"
    else
        print_error "scanner.sh not found in script directory"
        return 1
    fi
}

# Function to install terminator
install_terminator() {
    print_status "Installing terminator..."
    if command_exists terminator; then
        print_success "terminator is already installed"
    else
        sudo apt install -y terminator
        
        if command_exists terminator; then
            print_success "terminator installed successfully"
        else
            print_error "Failed to install terminator"
            return 1
        fi
    fi
}

# Function to install ligolo
install_ligolo() {
    print_status "Installing ligolo..."
    
    # Create ligolo directory
    LIGOLO_DIR="$HOME/tools/ligolo"
    mkdir -p "$LIGOLO_DIR"
    
    # Check if ligolo-ng is already installed
    if [ -f "$LIGOLO_DIR/ligolo-ng" ]; then
        print_success "ligolo-ng is already installed"
    else
        print_status "Downloading ligolo-ng..."
        
        # Get latest release
        LATEST_RELEASE=$(curl -s https://api.github.com/repos/nicocha30/ligolo-ng/releases/latest | grep "tag_name" | cut -d '"' -f 4)
        
        if [ -z "$LATEST_RELEASE" ] || [ "$LATEST_RELEASE" = "null" ]; then
            print_error "Failed to get latest release information"
            print_status "Manual installation:"
            print_status "1. Visit: https://github.com/nicocha30/ligolo-ng/releases"
            print_status "2. Download the latest release manually"
            return 1
        fi
        
        # Download and extract
        cd "$LIGOLO_DIR"
        wget "https://github.com/nicocha30/ligolo-ng/releases/download/${LATEST_RELEASE}/ligolo-ng_${LATEST_RELEASE}_linux_amd64.tar.gz" -O ligolo.tar.gz
        tar -xzf ligolo.tar.gz
        chmod +x ligolo-ng
        rm ligolo.tar.gz
        
        if [ -f "$LIGOLO_DIR/ligolo-ng" ]; then
            print_success "ligolo-ng installed successfully"
        else
            print_error "Failed to install ligolo-ng"
            return 1
        fi
    fi
    
    # Create ligolo helper script
    cat > "$HOME/tools/ligolo.sh" << 'EOF'
#!/bin/bash

# Ligolo Helper Script
# Usage: ./ligolo.sh [proxy|agent]

LIGOLO_DIR="$HOME/tools/ligolo"

case "$1" in
    "proxy")
        echo "Starting Ligolo Proxy Server..."
        cd "$LIGOLO_DIR"
        ./ligolo-ng proxy -l 8080
        ;;
    "agent")
        if [ -z "$2" ]; then
            echo "Usage: $0 agent <proxy_ip>"
            echo "Example: $0 agent 192.168.1.100"
            exit 1
        fi
        echo "Starting Ligolo Agent connecting to $2..."
        cd "$LIGOLO_DIR"
        ./ligolo-ng agent -connect "$2:8080"
        ;;
    *)
        echo "Usage: $0 [proxy|agent]"
        echo "  proxy  - Start the proxy server"
        echo "  agent  - Connect to proxy server (requires proxy IP)"
        echo ""
        echo "Examples:"
        echo "  $0 proxy"
        echo "  $0 agent 192.168.1.100"
        ;;
esac
EOF

    chmod +x "$HOME/tools/ligolo.sh"
    print_success "ligolo helper script created"
}

# Main execution
main() {
    echo "=========================================="
    echo "    OSCP Setup Script"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root is not recommended. Please run as regular user."
        print_status "The script will prompt for sudo when needed."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Clean up problematic repositories
    cleanup_repositories
    
    # Disable IPv6 to resolve connectivity issues
    disable_ipv6
    
    # Update package lists
    update_packages
    
    # Create tools directory
    create_tools_directory
    
    # Add tools directory to PATH
    add_tools_to_path
    
    # Install required tools (nmap first as requested)
    install_nmap
    install_rustscan
    install_terminator
    install_ligolo
    
    # Create scanner script
    create_scanner_script
    
    echo ""
    echo "=========================================="
    print_success "OSCP setup completed successfully on Kali Linux!"
    echo "=========================================="
    echo ""
    echo "Installed tools:"
    echo "  - Tools directory: $HOME/tools"
    echo "  - nmap: $(which nmap 2>/dev/null || echo 'Not found')"
    echo "  - rustscan: $(which rustscan 2>/dev/null || echo 'Not found')"
    echo "  - terminator: $(which terminator 2>/dev/null || echo 'Not found')"
    echo "  - ligolo-ng: $HOME/tools/ligolo/ligolo-ng"
    echo ""
    echo "PATH Configuration:"
    echo "  - Tools directory added to PATH in shell config files"
    echo "  - You can now use 'scanner.sh' and 'ligolo.sh' from anywhere"
    echo ""
    echo "Usage:"
    echo "  - Scanner: scanner.sh <target_ip> (or $HOME/tools/scanner.sh <target_ip>)"
    echo "  - Ligolo: ligolo.sh [proxy|agent] (or $HOME/tools/ligolo.sh [proxy|agent])"
    echo ""
    print_status "Note: Restart your terminal or run 'source ~/.bashrc' (or ~/.zshrc) to use tools from anywhere"
    echo ""
    print_status "Happy hacking! 🔥"
}

# Run main function
main "$@"
