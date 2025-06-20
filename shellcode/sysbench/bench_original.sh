#!/bin/bash

################################################
# Author: Dave Chen                            #
# Mail: dave.jungler@gmail.com                 #
#                                              #
# MySQL/Sysbench Performance Testing Script   #
# Optimized version with improved error        #
# handling and security                        #
################################################

set -euo pipefail  # Improved error handling

# Configuration variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/sysbench_$(date +%Y%m%d_%H%M%S).log"

# Default values
disk=""
username="root"
password=""
nthread=""
raw=""
tran=""
avg=""
centric_db_host="${DB_HOST:-192.168.20.169}"
centric_db_username="${DB_USERNAME:-root}"
centric_db_password="${DB_PASSWORD:-}"
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
result_base_dir="${RESULT_DIR:-/home/dave/result}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error handling function
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Usage function
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -d DISK     Disk type [S4500, P4500, P4510] (required)
    -t THREADS  Number of threads [1, 2, 4, 8, 16] (required)
    -u USER     Database username (default: root)
    -p PASS     Database password (will prompt if not provided)
    -h          Show this help message

ENVIRONMENT VARIABLES:
    DB_HOST         Database host (default: 192.168.20.169)
    DB_USERNAME     Database username (default: root)
    DB_PASSWORD     Database password
    RESULT_DIR      Results directory (default: /home/dave/result)

EXAMPLES:
    $0 -d P4500 -t 4
    $0 -d S4500 -t 8 -u testuser -p testpass
EOF
}

# Validate parameters
validate_params() {
    if [[ -z "$disk" ]]; then
        error_exit "Disk type is required. Use -d option."
    fi
    
    if [[ -z "$nthread" ]]; then
        error_exit "Number of threads is required. Use -t option."
    fi
    
    if [[ ! "$disk" =~ ^(S4500|P4500|P4510)$ ]]; then
        error_exit "Invalid disk type: $disk. Must be S4500, P4500, or P4510."
    fi
    
    if [[ ! "$nthread" =~ ^[0-9]+$ ]] || [[ "$nthread" -lt 1 ]] || [[ "$nthread" -gt 32 ]]; then
        error_exit "Invalid thread count: $nthread. Must be a number between 1 and 32."
    fi
    
    if [[ -z "$password" ]]; then
        read -s -p "Enter database password: " password
        echo
        if [[ -z "$password" ]]; then
            error_exit "Password cannot be empty."
        fi
    fi
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -d)
            [[ -n "${2:-}" ]] || error_exit "Option -d requires an argument"
            disk="$2"
            shift 2
            ;;
        -t)
            [[ -n "${2:-}" ]] || error_exit "Option -t requires an argument"
            nthread="$2"
            shift 2
            ;;
        -u)
            [[ -n "${2:-}" ]] || error_exit "Option -u requires an argument"
            username="$2"
            shift 2
            ;;
        -p)
            [[ -n "${2:-}" ]] || error_exit "Option -p requires an argument"
            password="$2"
            shift 2
            ;;
        *)
            error_exit "Unknown option: $1. Use -h for help."
            ;;
    esac
done

# Validate all parameters
validate_params

log "Starting sysbench test with disk=$disk, threads=$nthread"

# Device mapping with validation
get_device_path() {
    local device_path=""
    case "$disk" in
        P4510)
            device_path="/dev/nvme0n1"
            ;;
        P4500)
            device_path="/dev/nvme1n1"
            ;;
        S4500)
            device_path="/dev/sdb"
            ;;
        *)
            error_exit "Unknown disk type: $disk"
            ;;
    esac
    
    if [[ ! -b "$device_path" ]]; then
        error_exit "Device $device_path does not exist or is not a block device"
    fi
    
    echo "$device_path"
}

# Install dependencies
do_deps() {
    log "Installing dependencies..."
    if ! command -v mysql &> /dev/null; then
        sudo apt-get update
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
    fi
    
    if ! command -v sysbench &> /dev/null; then
        sudo apt-get install -y sysbench
    fi
    
    log "Dependencies installed successfully"
}

# Prepare test environment
do_prepare() {
    log "Preparing test environment..."
    
    raw=$(get_device_path)
    folder="$result_base_dir/$disk"
    
    # Create result directory
    mkdir -p "$folder"
    
    # Create mount point if it doesn't exist
    sudo mkdir -p /var/lib/mysqldb
    
    # Check if device is already mounted
    if mountpoint -q /var/lib/mysqldb; then
        log "Unmounting existing mount at /var/lib/mysqldb"
        sudo umount /var/lib/mysqldb
    fi
    
    # Mount the device
    log "Mounting $raw to /var/lib/mysqldb"
    sudo mount -t ext4 "$raw" /var/lib/mysqldb
    
    # Backup and setup MySQL data
    if [[ -d /var/lib/mysql ]]; then
        log "Backing up MySQL data..."
        sudo rm -rf /var/lib/mysqldb/*
        sudo cp -r /var/lib/mysql/* /var/lib/mysqldb/
        sudo chown -R mysql:mysql /var/lib/mysqldb
    fi
    
    # Clear caches for accurate benchmarking
    log "Clearing system caches..."
    sudo sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    sudo swapoff -a 2>/dev/null || true
    
    # Copy MySQL configuration
    if [[ -f "$SCRIPT_DIR/my.cnf" ]]; then
        sudo cp "$SCRIPT_DIR/my.cnf" /etc/mysql/
    fi
    
    # Start MySQL service
    log "Starting MySQL service..."
    sudo systemctl start mysql || sudo service mysql start
    
    log "Environment preparation completed"
}

# Run sysbench tests
do_sysbench() {
    log "Running sysbench tests..."
    
    local test_folder="$folder/$nthread"
    mkdir -p "$test_folder"
    
    # Create test database
    log "Creating test database..."
    mysql -u "$username" -p"$password" -e "DROP DATABASE IF EXISTS dbtest; CREATE DATABASE dbtest;" 2>/dev/null
    
    # Prepare sysbench data using modern syntax
    log "Preparing sysbench data..."
    sysbench oltp_read_write \
        --table-size=10000 \
        --mysql-db=dbtest \
        --mysql-user="$username" \
        --mysql-password="$password" \
        prepare
    
    # Run benchmark tests
    log "Running benchmark tests (10 iterations)..."
    for j in $(seq 1 10); do
        log "Running test iteration $j/$10"
        sysbench oltp_read_write \
            --table-size=10000 \
            --threads="$nthread" \
            --mysql-db=dbtest \
            --mysql-user="$username" \
            --mysql-password="$password" \
            --time=60 \
            run | tee "$test_folder/$j.out"
    done
    
    log "Sysbench tests completed"
}

# Cleanup function
do_cleanup() {
    log "Cleaning up..."
    
    # Cleanup sysbench data
    sysbench oltp_read_write \
        --mysql-db=dbtest \
        --mysql-user="$username" \
        --mysql-password="$password" \
        cleanup 2>/dev/null || true
    
    # Drop test database
    mysql -u "$username" -p"$password" -e "DROP DATABASE IF EXISTS dbtest;" 2>/dev/null || true
    
    # Stop MySQL service
    sudo systemctl stop mysql 2>/dev/null || sudo service mysql stop 2>/dev/null || true
    
    # Unmount device
    sudo umount /var/lib/mysqldb 2>/dev/null || true
    
    log "Cleanup completed"
}

# Analyze results
do_analysis() {
    log "Analyzing results..."
    
    local test_folder="$folder/$nthread"
    cd "$test_folder"
    
    # Calculate average transactions per second
    local total_tps=0
    local total_latency=0
    local count=0
    
    for file in *.out; do
        if [[ -f "$file" ]]; then
            local tps=$(grep "transactions:" "$file" | grep -oP '\(\K[0-9.]+(?= per sec\))' || echo "0")
            local latency=$(grep "avg:" "$file" | grep -oP 'avg:\s*\K[0-9.]+' || echo "0")
            
            if [[ -n "$tps" && "$tps" != "0" ]]; then
                total_tps=$(echo "$total_tps + $tps" | bc -l)
                total_latency=$(echo "$total_latency + $latency" | bc -l)
                ((count++))
            fi
        fi
    done
    
    if [[ $count -gt 0 ]]; then
        res_tran=$(echo "scale=2; $total_tps / $count" | bc -l)
        res_avg=$(echo "scale=2; $total_latency / $count" | bc -l)
        
        log "Average TPS: $res_tran"
        log "Average Latency: $res_avg ms"
    else
        error_exit "No valid test results found"
    fi
}

# Collect system information
do_collectinfo() {
    log "Collecting system information..."
    
    # Try to detect system info automatically
    platform=$(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
    mem=$(free -h | awk '/^Mem:/ {print $2}' || echo "Unknown")
    cpu=$(lscpu | grep "Model name" | cut -d: -f2 | xargs || echo "Unknown")
    
    log "Platform: $platform"
    log "Memory: $mem"
    log "CPU: $cpu"
    
    # Allow manual override if needed
    read -p "Platform [$platform]: " input_platform
    platform=${input_platform:-$platform}
    
    read -p "Memory [$mem]: " input_mem
    mem=${input_mem:-$mem}
    
    read -p "CPU [$cpu]: " input_cpu
    cpu=${input_cpu:-$cpu}
}

# Write results to database
do_writedatabase() {
    if [[ -z "$centric_db_password" ]]; then
        log "No database password provided, skipping database write"
        return 0
    fi
    
    log "Writing results to database..."
    
    mysql -h "$centric_db_host" \
          -u "$centric_db_username" \
          -p"$centric_db_password" \
          -e "USE workload; 
              INSERT INTO bench_result(drivemodel, Platform, trans, avg, timestamp, extra, memory, CPU, threads) 
              VALUES ('$disk', '$platform', '$res_tran', '$res_avg', '$timestamp', '', '$mem', '$cpu', '$nthread');" \
    && log "Results written to database successfully" \
    || log "Failed to write results to database"
}

# Trap to ensure cleanup on exit
trap 'do_cleanup' EXIT

# Main execution flow
main() {
    log "=== Sysbench Performance Test Started ==="
    log "Configuration: disk=$disk, threads=$nthread, user=$username"
    
    do_deps
    do_prepare
    do_sysbench
    do_analysis
    do_collectinfo
    do_writedatabase
    
    log "=== Sysbench Performance Test Completed ==="
    log "Results saved in: $folder/$nthread"
    log "Log file: $LOG_FILE"
}

# Run main function
main "$@"