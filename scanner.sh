#!/bin/bash

# Advanced Network Scanner Script
# Combines rustscan for fast port discovery with nmap for detailed analysis

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <target_ip> [output_directory]"
    echo "Example: $0 192.168.1.100"
    echo "Example: $0 192.168.1.100 ./my_scan_results"
    echo ""
    echo "Note: Results are saved in the current directory by default"
    exit 1
}

# Check if target IP is provided
if [ $# -lt 1 ]; then
    print_error "Target IP is required"
    show_usage
fi

TARGET=$1
OUTPUT_DIR=${2:-"./scan_results"}

# Validate IP address format
if ! [[ $TARGET =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_error "Invalid IP address format"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCAN_DIR="$OUTPUT_DIR/scan_${TARGET}_$TIMESTAMP"
mkdir -p "$SCAN_DIR"

print_status "Starting comprehensive scan of $TARGET"
print_status "Results will be saved to: $SCAN_DIR"
print_status "Current working directory: $(pwd)"

# Step 1: Fast port discovery with rustscan
print_status "Step 1: Fast port discovery with rustscan..."
if rustscan -a "$TARGET" --ulimit 5000 --no-banner -- -oA "$SCAN_DIR/rustscan_initial" >/dev/null 2>&1; then
    print_success "Rustscan completed successfully"
else
    print_warning "Rustscan failed, falling back to nmap for port discovery..."
    sudo nmap -sS -O -F "$TARGET" -oA "$SCAN_DIR/nmap_initial"
fi


# Extract open ports from rustscan results
# Rustscan creates files with the target IP in the name, so we need to find the actual file
RUSTSCAN_NMAP_FILE=$(find "$SCAN_DIR" -name "*.nmap" -type f | head -1)

if [ ! -z "$RUSTSCAN_NMAP_FILE" ] && [ -f "$RUSTSCAN_NMAP_FILE" ]; then
    print_status "Extracting ports from: $RUSTSCAN_NMAP_FILE"
    PORTS=$(grep -o '[0-9]*/open' "$RUSTSCAN_NMAP_FILE" | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')
else
    # Fallback: use nmap to discover ports
    print_status "Using nmap for port discovery..."
    sudo nmap -sS -O -F "$TARGET" -oA "$SCAN_DIR/nmap_initial"
    PORTS=$(grep -o '[0-9]*/open' "$SCAN_DIR/nmap_initial.nmap" | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')
fi

if [ -z "$PORTS" ]; then
    print_error "No open ports found"
    exit 1
fi

print_success "Found open ports: $PORTS"

# Step 2: Comprehensive nmap scan on discovered ports
print_status "Step 2: Running comprehensive nmap scan on ports: $PORTS"
print_status "This includes: service detection, OS detection, vulnerability scanning, and script enumeration"

# Single comprehensive nmap scan with all necessary flags
sudo nmap -sV -sC -O -A --script vuln,safe,default,discovery,version -p "$PORTS" "$TARGET" -oA "$SCAN_DIR/nmap_comprehensive"

# UDP scan on common ports (separate as it's a different scan type)
print_status "Running UDP scan on common ports..."
sudo nmap -sU --top-ports 1000 "$TARGET" -oA "$SCAN_DIR/nmap_udp"

# Generate summary report
print_status "Generating summary report..."
cat > "$SCAN_DIR/scan_summary.txt" << EOL
Scan Summary for $TARGET
========================
Scan Date: $(date)
Target: $TARGET
Open Ports: $PORTS

Files Generated:
- rustscan_initial.* (Initial port discovery)
- nmap_comprehensive.* (Comprehensive scan with all flags)
- nmap_udp.* (UDP scan)

Formats available: .nmap, .xml, .gnmap
EOL

print_success "Scan completed successfully!"
print_success "Results saved in: $SCAN_DIR"
print_status "Summary report: $SCAN_DIR/scan_summary.txt"

# Show quick summary
echo ""
echo "=== QUICK SUMMARY ==="
echo "Target: $TARGET"
echo "Open Ports: $PORTS"
echo "Results Directory: $SCAN_DIR"
echo ""
echo "To view results:"
echo "  - Text format: cat $SCAN_DIR/nmap_comprehensive.nmap"
echo "  - XML format: $SCAN_DIR/nmap_comprehensive.xml"
echo "  - Grepable: $SCAN_DIR/nmap_comprehensive.gnmap"
