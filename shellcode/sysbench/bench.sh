#!/bin/bash

################################################
# Author: Dave Chen                            #
# Mail: dave.jungler@gmail.com                 #
#                                              #
# MySQL Sysbench Performance Testing Script   #
# Optimized version with improved security     #
# and error handling                           #
################################################

set -euo pipefail  # Improved error handling

# Configuration variables
DISK=""
USERNAME="root"
PASSWORD=""
RAW_DEVICE=""
NTHREAD=""
RESULT_FOLDER=""
CENTRIC_DB_HOST="${CENTRIC_DB_HOST:-192.168.20.169}"
CENTRIC_DB_USERNAME="${CENTRIC_DB_USERNAME:-root}"
CENTRIC_DB_PASSWORD="${CENTRIC_DB_PASSWORD:-}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
MYSQL_DATABASE="dbtest"
SYSBENCH_TABLE_SIZE=10000
BENCHMARK_ITERATIONS=10
LOG_FILE="/tmp/sysbench_${TIMESTAMP}.log"

# Device mapping
declare -A DEVICE_MAP=(
    ["P4510"]="/dev/nvme0n1"
    ["P4500"]="/dev/nvme1n1" 
    ["S4500"]="/dev/sdb"
)

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error handling function
error_exit() {
    echo "ERROR: $*" >&2
    exit 1
}

# Function to display usage information
show_usage() {
    cat << EOF
Usage: $0 -d DISK_TYPE -t THREADS -u USERNAME -p PASSWORD [OPTIONS]

Required Parameters:
  -d DISK_TYPE     Disk type: S4500, P4500, or P4510
  -t THREADS       Number of threads: 1, 2, 4, 8, 12, 16
  -u USERNAME      MySQL username
  -p PASSWORD      MySQL password

Optional Parameters:
  -h               Show this help message
  --db-host HOST   Database host (default: $CENTRIC_DB_HOST)
  --db-user USER   Database username (default: $CENTRIC_DB_USERNAME)

Examples:
  $0 -d P4500 -t 4 -u root -p mypassword
  $0 -d S4500 -t 8 -u testuser -p testpass --db-host 192.168.1.100

EOF
}

# Function to validate parameters
validate_parameters() {
    local errors=0
    
    if [[ -z "$DISK" ]]; then
        echo "Error: Disk type (-d) is required" >&2
        errors=1
    elif [[ ! "${DEVICE_MAP[$DISK]+isset}" ]]; then
        echo "Error: Invalid disk type '$DISK'. Valid options: ${!DEVICE_MAP[*]}" >&2
        errors=1
    fi
    
    if [[ -z "$NTHREAD" ]]; then
        echo "Error: Number of threads (-t) is required" >&2
        errors=1
    elif ! [[ "$NTHREAD" =~ ^[0-9]+$ ]] || [[ "$NTHREAD" -lt 1 ]] || [[ "$NTHREAD" -gt 32 ]]; then
        echo "Error: Invalid thread count '$NTHREAD'. Must be a number between 1 and 32" >&2
        errors=1
    fi
    
    if [[ -z "$USERNAME" ]]; then
        echo "Error: MySQL username (-u) is required" >&2
        errors=1
    fi
    
    if [[ -z "$PASSWORD" ]]; then
        echo "Error: MySQL password (-p) is required" >&2
        errors=1
    fi
    
    if [[ $errors -eq 1 ]]; then
        echo ""
        show_usage
        exit 1
    fi
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    echo "Error: No parameters provided"
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
            if [[ -n "${2:-}" ]]; then
                DISK="$2"
                shift 2
            else
                echo "Error: -d requires a disk type argument" >&2
                exit 1
            fi
            ;;
        -t)
            if [[ -n "${2:-}" ]]; then
                NTHREAD="$2"
                shift 2
            else
                echo "Error: -t requires a thread count argument" >&2
                exit 1
            fi
            ;;
        -u)
            if [[ -n "${2:-}" ]]; then
                USERNAME="$2"
                shift 2
            else
                echo "Error: -u requires a username argument" >&2
                exit 1
            fi
            ;;
        -p)
            if [[ -n "${2:-}" ]]; then
                PASSWORD="$2"
                shift 2
            else
                echo "Error: -p requires a password argument" >&2
                exit 1
            fi
            ;;
        --db-host)
            if [[ -n "${2:-}" ]]; then
                CENTRIC_DB_HOST="$2"
                shift 2
            else
                echo "Error: --db-host requires a hostname argument" >&2
                exit 1
            fi
            ;;
        --db-user)
            if [[ -n "${2:-}" ]]; then
                CENTRIC_DB_USERNAME="$2"
                shift 2
            else
                echo "Error: --db-user requires a username argument" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            show_usage
            exit 1
            ;;
    esac
done

# Validate all required parameters
validate_parameters

# Set derived variables
RAW_DEVICE="${DEVICE_MAP[$DISK]}"
RESULT_FOLDER="/home/dave/result/$DISK"

# Function to install dependencies
install_dependencies() {
    log "Installing required dependencies..."
    
    # Update package list
    if ! sudo apt-get update; then
        error_exit "Failed to update package list"
    fi
    
    # Install MySQL server
    if ! command -v mysql &> /dev/null; then
        log "Installing MySQL server..."
        if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server; then
            error_exit "Failed to install MySQL server"
        fi
    else
        log "MySQL server already installed"
    fi
    
    # Install sysbench
    if ! command -v sysbench &> /dev/null; then
        log "Installing sysbench..."
        if ! sudo apt-get install -y sysbench; then
            error_exit "Failed to install sysbench"
        fi
    else
        log "Sysbench already installed"
    fi
    
    # Install bc for calculations
    if ! command -v bc &> /dev/null; then
        log "Installing bc calculator..."
        if ! sudo apt-get install -y bc; then
            error_exit "Failed to install bc"
        fi
    fi
    
    log "Dependencies installation completed"
}

# Function to prepare the test environment
prepare_environment() {
    log "Preparing test environment for disk: $DISK"
    
    # Check if device exists
    if [[ ! -b "$RAW_DEVICE" ]]; then
        error_exit "Device $RAW_DEVICE does not exist"
    fi
    
    # Create result directory
    if [[ ! -d "$RESULT_FOLDER" ]]; then
        log "Creating result directory: $RESULT_FOLDER"
        if ! mkdir -p "$RESULT_FOLDER"; then
            error_exit "Failed to create result directory"
        fi
    fi
    
    # Create MySQL data directory
    local mysql_data_dir="/var/lib/mysqldb"
    if [[ ! -d "$mysql_data_dir" ]]; then
        log "Creating MySQL data directory: $mysql_data_dir"
        if ! sudo mkdir -p "$mysql_data_dir"; then
            error_exit "Failed to create MySQL data directory"
        fi
    fi
    
    # Mount the test device
    log "Mounting $RAW_DEVICE to $mysql_data_dir"
    if ! sudo mount -t ext4 "$RAW_DEVICE" "$mysql_data_dir"; then
        error_exit "Failed to mount $RAW_DEVICE"
    fi
    
    # Backup and copy MySQL data
    log "Setting up MySQL data directory"
    if [[ -d "/var/lib/mysql" ]]; then
        sudo rm -rf "${mysql_data_dir:?}"/*
        if ! sudo cp -r /var/lib/mysql/* "$mysql_data_dir/"; then
            error_exit "Failed to copy MySQL data"
        fi
        sudo chown -R mysql:mysql "$mysql_data_dir"
    fi
    
    # Optimize system for benchmarking
    log "Optimizing system for benchmarking"
    sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' && sudo sync
    sudo swapoff -a || true
    
    # Copy MySQL configuration
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/my.cnf" ]]; then
        log "Copying MySQL configuration"
        if ! sudo cp "$script_dir/my.cnf" /etc/mysql/; then
            error_exit "Failed to copy MySQL configuration"
        fi
    fi
    
    # Start MySQL service
    log "Starting MySQL service"
    if ! sudo systemctl start mysql; then
        error_exit "Failed to start MySQL service"
    fi
    
    # Wait for MySQL to be ready
    log "Waiting for MySQL to be ready..."
    local max_attempts=30
    local attempt=0
    while ! mysqladmin ping -u"$USERNAME" -p"$PASSWORD" --silent 2>/dev/null; do
        if [[ $attempt -ge $max_attempts ]]; then
            error_exit "MySQL failed to start within expected time"
        fi
        sleep 2
        ((attempt++))
    done
    
    log "Environment preparation completed"
}

# Function to run sysbench tests
run_sysbench() {
    log "Running sysbench tests with $NTHREAD threads"
    
    # Create thread-specific result directory
    local thread_result_dir="$RESULT_FOLDER/$NTHREAD"
    if [[ ! -d "$thread_result_dir" ]]; then
        log "Creating thread result directory: $thread_result_dir"
        if ! mkdir -p "$thread_result_dir"; then
            error_exit "Failed to create thread result directory"
        fi
    fi
    
    # Create test database
    log "Creating test database: $MYSQL_DATABASE"
    if ! mysql -u"$USERNAME" -p"$PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE"; then
        error_exit "Failed to create database $MYSQL_DATABASE"
    fi
    
    # Prepare sysbench test data
    log "Preparing sysbench test data (table size: $SYSBENCH_TABLE_SIZE)"
    if ! sysbench oltp_read_write \
        --table-size="$SYSBENCH_TABLE_SIZE" \
        --mysql-db="$MYSQL_DATABASE" \
        --mysql-user="$USERNAME" \
        --mysql-password="$PASSWORD" \
        prepare; then
        error_exit "Failed to prepare sysbench test data"
    fi
    
    # Run benchmark iterations
    log "Running $BENCHMARK_ITERATIONS benchmark iterations"
    for iteration in $(seq 1 "$BENCHMARK_ITERATIONS"); do
        log "Running iteration $iteration/$BENCHMARK_ITERATIONS"
        
        local output_file="$thread_result_dir/${iteration}.out"
        if ! sysbench oltp_read_write \
            --table-size="$SYSBENCH_TABLE_SIZE" \
            --threads="$NTHREAD" \
            --mysql-db="$MYSQL_DATABASE" \
            --mysql-user="$USERNAME" \
            --mysql-password="$PASSWORD" \
            --time=60 \
            --report-interval=10 \
            run | tee "$output_file"; then
            error_exit "Sysbench iteration $iteration failed"
        fi
        
        log "Iteration $iteration completed, results saved to $output_file"
    done
    
    log "Sysbench tests completed"
}

# Function to cleanup test environment
cleanup_environment() {
    log "Cleaning up test environment"
    
    # Cleanup sysbench test data
    if command -v sysbench &> /dev/null; then
        sysbench oltp_read_write \
            --mysql-db="$MYSQL_DATABASE" \
            --mysql-user="$USERNAME" \
            --mysql-password="$PASSWORD" \
            cleanup 2>/dev/null || true
    fi
    
    # Drop test database
    if command -v mysql &> /dev/null; then
        mysql -u"$USERNAME" -p"$PASSWORD" \
            -e "DROP DATABASE IF EXISTS $MYSQL_DATABASE" 2>/dev/null || true
    fi
    
    # Stop MySQL service
    sudo systemctl stop mysql 2>/dev/null || true
    
    # Unmount test device
    sudo umount /var/lib/mysqldb 2>/dev/null || true
    
    log "Cleanup completed"
}

# Function to analyze results
analyze_results() {
    log "Analyzing benchmark results"
    
    local thread_result_dir="$RESULT_FOLDER/$NTHREAD"
    if [[ ! -d "$thread_result_dir" ]]; then
        error_exit "Results directory not found: $thread_result_dir"
    fi
    
    cd "$thread_result_dir"
    
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

# Function to collect system information
collect_system_info() {
    log "Collecting system information..."
    
    read -p "Enter platform information: " platform
    read -p "Enter system memory size (GB): " mem
    read -p "Enter CPU information: " cpu
    
    log "Platform: $platform"
    log "Memory: $mem GB"
    log "CPU: $cpu"
}

# Function to write results to database
write_to_database() {
    if [[ -z "$CENTRIC_DB_PASSWORD" ]]; then
        log "Database password not provided, skipping database write"
        return 0
    fi
    
    log "Writing results to database..."
    
    if mysql -h "$CENTRIC_DB_HOST" \
          -u "$CENTRIC_DB_USERNAME" \
          -p"$CENTRIC_DB_PASSWORD" \
          -e "USE workload; 
              INSERT INTO bench_result(drivemodel, Platform, trans, avg, timestamp, extra, memory, CPU, threads) 
              VALUES ('$DISK', '$platform', '$res_tran', '$res_avg', '$TIMESTAMP', '', '$mem', '$cpu', '$NTHREAD');"; then
        log "Results written to database successfully"
    else
        log "Failed to write results to database"
    fi
}

# Trap to ensure cleanup on exit
trap 'cleanup_environment' EXIT

# Main execution flow
main() {
    log "=== Sysbench Performance Test Started ==="
    log "Configuration: disk=$DISK, threads=$NTHREAD, user=$USERNAME"
    
    install_dependencies
    prepare_environment
    run_sysbench
    analyze_results
    collect_system_info
    write_to_database
    
    log "=== Sysbench Performance Test Completed ==="
    log "Results saved in: $RESULT_FOLDER/$NTHREAD"
    log "Log file: $LOG_FILE"
}

# Run main function
main "$@"