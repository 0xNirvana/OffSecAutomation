#!/bin/bash

# OSCP Setup Script
# This script configures a machine for OSCP preparation
# Compatible with Kali Linux and Ubuntu

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

# Function to update package lists
update_packages() {
    print_status "Updating package lists..."
    if command_exists apt; then
        sudo apt update
    elif command_exists apt-get; then
        sudo apt-get update
    else
        print_warning "No apt package manager found. Please install packages manually."
        return 1
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
        
        # Try different installation methods
        if command_exists cargo; then
            print_status "Installing rustscan via cargo..."
            cargo install rustscan
        elif command_exists wget; then
            print_status "Downloading rustscan binary..."
            
            # Try to get latest release with better error handling
            LATEST_RELEASE=$(curl -s https://api.github.com/repos/RustScan/RustScan/releases/latest | grep "tag_name" | cut -d '"' -f 4)
            
            if [ -z "$LATEST_RELEASE" ] || [ "$LATEST_RELEASE" = "null" ]; then
                print_warning "Could not get latest release info, trying alternative method..."
                # Try the bee-san fork which is more actively maintained
                LATEST_RELEASE=$(curl -s https://api.github.com/repos/bee-san/RustScan/releases/latest | grep "tag_name" | cut -d '"' -f 4)
                
                if [ -z "$LATEST_RELEASE" ] || [ "$LATEST_RELEASE" = "null" ]; then
                    print_error "Could not determine latest release version"
                    print_status "Trying to install from package manager instead..."
                    
                    # Try package manager installation
                    if command_exists apt; then
                        print_status "Installing rustscan via apt..."
                        sudo apt update
                        sudo apt install -y rustscan
                    elif command_exists snap; then
                        print_status "Installing rustscan via snap..."
                        sudo snap install rustscan
                    else
                        print_error "Cannot install rustscan. Please install manually."
                        print_status "Manual installation:"
                        print_status "1. Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
                        print_status "2. Install rustscan: cargo install rustscan"
                        return 1
                    fi
                else
                    # Use bee-san fork
                    print_status "Using bee-san fork of rustscan..."
                    wget "https://github.com/bee-san/RustScan/releases/download/${LATEST_RELEASE}/rustscan-${LATEST_RELEASE}-x86_64-unknown-linux-gnu.tar.gz" -O /tmp/rustscan.tar.gz
                fi
            else
                # Use original repository
                print_status "Using original rustscan repository..."
                wget "https://github.com/RustScan/RustScan/releases/download/${LATEST_RELEASE}/rustscan-${LATEST_RELEASE}-x86_64-unknown-linux-gnu.tar.gz" -O /tmp/rustscan.tar.gz
            fi
            
            # If we got a release version, proceed with download
            if [ ! -z "$LATEST_RELEASE" ] && [ "$LATEST_RELEASE" != "null" ]; then
                if [ -f "/tmp/rustscan.tar.gz" ]; then
                    tar -xzf /tmp/rustscan.tar.gz -C /tmp/
                    sudo mv /tmp/rustscan /usr/local/bin/
                    sudo chmod +x /usr/local/bin/rustscan
                    rm /tmp/rustscan.tar.gz
                else
                    print_error "Failed to download rustscan binary"
                    return 1
                fi
            fi
        else
            print_error "Cannot install rustscan. Please install cargo, wget, or use package manager."
            print_status "Manual installation options:"
            print_status "1. Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            print_status "2. Install rustscan: cargo install rustscan"
            print_status "3. Or install wget: sudo apt install wget"
            return 1
        fi
        
        if command_exists rustscan; then
            print_success "rustscan installed successfully"
        else
            print_error "Failed to install rustscan"
            print_status "You can try manual installation:"
            print_status "1. Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            print_status "2. Install rustscan: cargo install rustscan"
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
        if command_exists apt; then
            sudo apt install -y nmap
        elif command_exists apt-get; then
            sudo apt-get install -y nmap
        else
            print_error "Cannot install nmap. Please install manually."
            return 1
        fi
        
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
        if command_exists apt; then
            sudo apt install -y terminator
        elif command_exists apt-get; then
            sudo apt-get install -y terminator
        else
            print_error "Cannot install terminator. Please install manually."
            return 1
        fi
        
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
        print_warning "Running as root. Some installations may not work properly."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Update package lists
    update_packages
    
    # Create tools directory
    create_tools_directory
    
    # Add tools directory to PATH
    add_tools_to_path
    
    # Install required tools
    install_rustscan
    install_nmap
    install_terminator
    install_ligolo
    
    # Create scanner script
    create_scanner_script
    
    echo ""
    echo "=========================================="
    print_success "OSCP setup completed successfully!"
    echo "=========================================="
    echo ""
    echo "Installed tools:"
    echo "  - Tools directory: $HOME/tools"
    echo "  - rustscan: $(which rustscan 2>/dev/null || echo 'Not found')"
    echo "  - nmap: $(which nmap 2>/dev/null || echo 'Not found')"
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
