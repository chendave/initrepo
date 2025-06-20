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

# Device mapping
declare -A DEVICE_MAP=(
    ["P4510"]="/dev/nvme0n1"
    ["P4500"]="/dev/nvme1n1" 
    ["S4500"]="/dev/sdb"
)


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
    echo "Installing required dependencies..."
    
    # Update package list
    if ! sudo apt-get update; then
        echo "Error: Failed to update package list" >&2
        exit 1
    fi
    
    # Install MySQL server
    if ! command -v mysql &> /dev/null; then
        echo "Installing MySQL server..."
        if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server; then
            echo "Error: Failed to install MySQL server" >&2
            exit 1
        fi
    else
        echo "MySQL server already installed"
    fi
    
    # Install sysbench
    if ! command -v sysbench &> /dev/null; then
        echo "Installing sysbench..."
        if ! sudo apt-get install -y sysbench; then
            echo "Error: Failed to install sysbench" >&2
            exit 1
        fi
    else
        echo "Sysbench already installed"
    fi
    
    echo "Dependencies installation completed"
}

# Function to prepare the test environment
prepare_environment() {
    echo "Preparing test environment for disk: $DISK"
    
    # Check if device exists
    if [[ ! -b "$RAW_DEVICE" ]]; then
        echo "Error: Device $RAW_DEVICE does not exist" >&2
        exit 1
    fi
    
    # Create result directory
    if [[ ! -d "$RESULT_FOLDER" ]]; then
        echo "Creating result directory: $RESULT_FOLDER"
        if ! mkdir -p "$RESULT_FOLDER"; then
            echo "Error: Failed to create result directory" >&2
            exit 1
        fi
    fi
    
    # Create MySQL data directory
    local mysql_data_dir="/var/lib/mysqldb"
    if [[ ! -d "$mysql_data_dir" ]]; then
        echo "Creating MySQL data directory: $mysql_data_dir"
        if ! sudo mkdir -p "$mysql_data_dir"; then
            echo "Error: Failed to create MySQL data directory" >&2
            exit 1
        fi
    fi
    
    # Mount the test device
    echo "Mounting $RAW_DEVICE to $mysql_data_dir"
    if ! sudo mount -t ext4 "$RAW_DEVICE" "$mysql_data_dir"; then
        echo "Error: Failed to mount $RAW_DEVICE" >&2
        exit 1
    fi
    
    # Backup and copy MySQL data
    echo "Setting up MySQL data directory"
    if [[ -d "/var/lib/mysql" ]]; then
        sudo rm -rf "${mysql_data_dir:?}"/*
        if ! sudo cp -r /var/lib/mysql/* "$mysql_data_dir/"; then
            echo "Error: Failed to copy MySQL data" >&2
            exit 1
        fi
        sudo chown -R mysql:mysql "$mysql_data_dir"
    fi
    
    # Optimize system for benchmarking
    echo "Optimizing system for benchmarking"
    sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' && sudo sync
    sudo swapoff -a || true
    
    # Copy MySQL configuration
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/my.cnf" ]]; then
        echo "Copying MySQL configuration"
        if ! sudo cp "$script_dir/my.cnf" /etc/mysql/; then
            echo "Error: Failed to copy MySQL configuration" >&2
            exit 1
        fi
    fi
    
    # Start MySQL service
    echo "Starting MySQL service"
    if ! sudo systemctl start mysql; then
        echo "Error: Failed to start MySQL service" >&2
        exit 1
    fi
    
    # Wait for MySQL to be ready
    echo "Waiting for MySQL to be ready..."
    local max_attempts=30
    local attempt=0
    while ! mysqladmin ping -u"$USERNAME" -p"$PASSWORD" --silent 2>/dev/null; do
        if [[ $attempt -ge $max_attempts ]]; then
            echo "Error: MySQL failed to start within expected time" >&2
            exit 1
        fi
        sleep 2
        ((attempt++))
    done
    
    echo "Environment preparation completed"
}


do_sysbench () {
  # do_cleanup
  if [ ! -d "$folder" ]; then
      mkdir "$folder"
  fi
  mysql -u $username -p$password -e "create database dbtest"
  sysbench --test=oltp --oltp-table-size=10000 --mysql-db=dbtest --mysql-user=$username --mysql-password=$password prepare
  # Either choose a range of threads or just pick up the num of thread from input.
  # for i in 1 4 8 12
  # NOTE(davechen): You can run multiple thead in the same loop, but we only pickup one each time to make us easier to write data into database;
  #for i in $nthread
  #do
  mkdir $folder/$nthread
  for j in $(seq 1 10)
  do
    sysbench --test=oltp --oltp-table-size=10000 --num-threads=$i --oltp-test-mode=complex --mysql-db=dbtest --mysql-user=$username --mysql-password=$password run | tee $folder/$nthread/$j.out;
  done
  #done
}

do_cleanup () {
  sysbench --test=oltp --mysql-db=dbtest --mysql-user=$username --mysql-password=$password cleanup || true
  mysql -u $username -p$password -e "drop database dbtest" || true
  sudo service mysql stop
  sudo umount /var/lib/mysqldb || true
}

do_analysis () {
  # fetch the data and do analysis
  # shell code below may has the issue if we run benchmark only one time, but it's okay for multiple times
  cd $folder/$nthread
  tran=`grep "transactions:" ./*.out -R | cut -d '(' -f2|cut -d ')' -f1 |awk -F" " '{print $1}' | awk '{a+=$1}END{print a}'`
  res_tran=$[$tran/10]
  avg=`grep "avg:" ./*.out -R | awk -F" " '{print $3}' | awk '{a+=$1}END{print a}'`
  res_avg=$[$avg/10]
}

do_collectinfo () {
  read -p "input the platform information here ..." platform
  read -p "input the size of system memory here ..." mem
  read -p "input the information of CPU here ..." cpu
}

do_writedatabase() {
  # connect to the database and write the final data into database;
  mysql -h $centric_db_host -u $centric_db_userame -p$centric_db_password -e "use workload; insert into bench_result(drivemodel, Platform, trans, avg, timestamp, extra, memory, CPU, threads) values (\"$disk\", \"$platform\", \"$res_tran\", \"$res_avg\", \"$timestamp\", "", \"$mem\", \"$cpu\", \"$nthread\")"
}

do_cleanup
# do_deps
do_prepare
do_sysbench
do_analysis
do_collectinfo
do_writedatabase
