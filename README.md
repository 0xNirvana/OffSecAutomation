# OSCP Setup Script

A comprehensive setup script for OSCP (Offensive Security Certified Professional) preparation. This script automates the installation and configuration of essential penetration testing tools on Kali Linux and Ubuntu systems.

## 🚀 Quick Start

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd OffSecAutomation
   ```

2. **Make the script executable:**
   ```bash
   chmod +x setup.sh
   ```

3. **Run the setup script:**
   ```bash
   ./setup.sh
   ```

That's it! The script will automatically install and configure all the required tools.

## 📋 What This Script Installs

### Core Tools
- **rustscan** - Ultra-fast port scanner
- **nmap** - Network mapper and security scanner
- **terminator** - Advanced terminal emulator
- **ligolo-ng** - Advanced tunneling tool

### Directory Structure
```
$HOME/tools/
├── scanner.sh          # Advanced network scanner script
├── ligolo.sh           # Ligolo helper script
└── ligolo/
    └── ligolo-ng       # Ligolo binary
```

## 🛠️ Tool Usage

### Network Scanner (`scanner.sh`)

The scanner script combines rustscan for fast port discovery with nmap for detailed analysis.

**Usage:**
```bash
# Basic usage
$HOME/tools/scanner.sh <target_ip>

# With custom output directory
$HOME/tools/scanner.sh <target_ip> /path/to/results
```

**Examples:**
```bash
# Scan a target
$HOME/tools/scanner.sh 192.168.1.100

# Scan with custom output directory
$HOME/tools/scanner.sh 192.168.1.100 /tmp/scan_results
```

**What the scanner does:**
1. **Fast Port Discovery** - Uses rustscan to quickly identify open ports
2. **Service Detection** - Detailed service and version detection
3. **Aggressive Scanning** - Comprehensive scan with OS detection
4. **Vulnerability Scanning** - Runs vulnerability detection scripts
5. **Script Scanning** - Executes safe and default nmap scripts
6. **UDP Scanning** - Scans common UDP ports

**Output Formats:**
- `.nmap` - Human-readable format
- `.xml` - XML format for parsing
- `.gnmap` - Grepable format
- `scan_summary.txt` - Summary report

### Ligolo Tunneling (`ligolo.sh`)

Ligolo-ng is an advanced tunneling tool for pivoting and lateral movement.

**Usage:**
```bash
# Start proxy server
$HOME/tools/ligolo.sh proxy

# Connect as agent to proxy
$HOME/tools/ligolo.sh agent <proxy_ip>
```

**Examples:**
```bash
# On your attacking machine (start proxy)
$HOME/tools/ligolo.sh proxy

# On compromised machine (connect to proxy)
$HOME/tools/ligolo.sh agent 192.168.1.100
```

## 🔧 Manual Installation

If the automated script fails, you can install tools manually:

### rustscan
```bash
# Method 1: Using cargo (if Rust is installed)
cargo install rustscan

# Method 2: Download binary
wget https://github.com/RustScan/RustScan/releases/latest/download/rustscan-*-x86_64-unknown-linux-gnu.tar.gz
tar -xzf rustscan-*.tar.gz
sudo mv rustscan /usr/local/bin/
```

### nmap
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install nmap

# Kali Linux
sudo apt update && sudo apt install nmap
```

### terminator
```bash
# Ubuntu/Debian
sudo apt install terminator

# Kali Linux
sudo apt install terminator
```

### ligolo-ng
```bash
# Download latest release
wget https://github.com/nicocha30/ligolo-ng/releases/latest/download/ligolo-ng_*_linux_amd64.tar.gz
tar -xzf ligolo-ng_*.tar.gz
chmod +x ligolo-ng
```

## 🎯 OSCP Workflow Integration

### Typical OSCP Enumeration Workflow

1. **Initial Reconnaissance:**
   ```bash
   # Quick network scan
   $HOME/tools/scanner.sh 10.10.10.10
   ```

2. **Service Enumeration:**
   ```bash
   # Check specific services
   nmap -sV -sC -p 80,443,22,21 10.10.10.10
   ```

3. **Web Application Testing:**
   ```bash
   # Directory enumeration
   gobuster dir -u http://10.10.10.10 -w /usr/share/wordlists/dirb/common.txt
   ```

4. **Pivoting (if needed):**
   ```bash
   # Start ligolo proxy
   $HOME/tools/ligolo.sh proxy
   
   # On compromised machine
   $HOME/tools/ligolo.sh agent <your_ip>
   ```

## 🔍 Troubleshooting

### Common Issues

1. **Permission Denied:**
   ```bash
   chmod +x setup.sh
   chmod +x $HOME/tools/scanner.sh
   chmod +x $HOME/tools/ligolo.sh
   ```

2. **Rustscan Installation Fails:**
   - Install Rust first: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
   - Or download the binary manually

3. **Ligolo Download Fails:**
   - Check internet connection
   - Verify GitHub access
   - Download manually from releases page

4. **Nmap Permission Issues:**
   ```bash
   # For SYN scans, you may need sudo
   sudo nmap -sS target
   ```

### Verification Commands

Check if tools are installed correctly:
```bash
# Check rustscan
rustscan --version

# Check nmap
nmap --version

# Check terminator
terminator --version

# Check ligolo
$HOME/tools/ligolo/ligolo-ng --help
```

## 📝 Notes

- This script is designed for Kali Linux and Ubuntu systems
- Some tools may require root privileges for certain operations
- The scanner script creates timestamped directories for each scan
- All scan results are saved in multiple formats for different use cases
- Ligolo requires network connectivity between proxy and agent

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the MIT License.

---

**Happy Hacking! 🔥**

*Good luck with your OSCP journey!*
