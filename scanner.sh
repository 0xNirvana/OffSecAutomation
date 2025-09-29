#!/bin/bash

# Define the target and output directory
TARGET="$1"
# TIMESTAMP=$(date +"%Y%m%d_%H%M%S") # Removed timestamp as requested
OUTPUT_DIR="scan_results_${TARGET}"
RUSTSCAN_FILE="${OUTPUT_DIR}/1_rustscan_initial.txt"
NMAP_FILE="${OUTPUT_DIR}/2_nmap_detailed.txt"

# --- Function Definitions ---

# Check for required tools
check_tools() {
    local missing=0
    for tool in rustscan nmap; do
        if ! command -v "$tool" &> /dev/null; then
            echo "Error: Required tool '$tool' is not installed or not in PATH."
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        echo "Please install the missing tools and try again."
        exit 1
    fi
}

# --- Main Script Execution ---

# 1. Check for target argument
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <target_ip_or_hostname>"
    echo "Example: $0 192.168.1.1"
    exit 1
fi

# 2. Check for dependencies
check_tools

# 3. Create output directory
echo "[+] Creating output directory: $OUTPUT_DIR"
# Note: If this directory already exists, new scan results will overwrite previous ones.
mkdir -p "$OUTPUT_DIR"

# 4. Run RustScan for fast port discovery
echo "[+] Starting RustScan on all 65535 ports for $TARGET..."
# Run rustscan, disabling its internal nmap feature (-g/--execute) and piping the output
# to tee to save it immediately, and to grep for the port list.
# Run rustscan and display output while also capturing it
echo "[+] Running rustscan..."
RUSTSCAN_OUTPUT=$(rustscan -a "$TARGET" \
             --range 1-65535 \
             --timeout 1500 \
             --ulimit 10000 \
             --no-banner \
             --scripts none \
             -- -oG "$RUSTSCAN_FILE.grep" 2>&1 | tee /dev/tty)

# 5. Extract ports for Nmap
# Use greppable format for simple port extraction
if [ -f "${RUSTSCAN_FILE}.grep" ]; then
    # Extract from greppable format - much simpler!
    PORTS=$(grep -o '[0-9]*/open' "${RUSTSCAN_FILE}.grep" | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')
else
    # Fallback to parsing console output (remove ANSI codes first)
    PORTS=$(echo "$RUSTSCAN_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -o '\[.*\]' | tr -d '[]' | tr -d ' ')
fi


if [ -z "$PORTS" ]; then
    echo "[-] No open ports found by RustScan. Exiting Nmap phase."
    exit 0
fi

echo "[+] RustScan found the following open ports: $PORTS"
echo "---------------------------------------------------------"

# 6. Run Nmap for detailed scanning
echo "[+] Starting Nmap detailed scan on ports: $PORTS"
echo "[+] Results will be saved to: $NMAP_FILE"

# -sC: default scripts (safe and useful)
# -sV: version detection
# -p : specify ports
# -oN: save normal output to file
nmap -sC -sV -p "$PORTS" "$TARGET" -oN "$NMAP_FILE"

# 7. Final Summary
echo "---------------------------------------------------------"
echo "[*] Scan complete."
echo "[*] RustScan results (Initial Port List) saved to: $RUSTSCAN_FILE"
echo "[*] Nmap results (Detailed Service/Version) saved to: $NMAP_FILE"
echo "[*] All files located in the directory: $OUTPUT_DIR"
