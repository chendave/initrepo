#!/bin/bash
set -e

disk=""
username="root"
password="abc123"
folder="/home/dave/result/P4500"
raw=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h)
          echo "-d: [S4500, P4500, P4510], -t: [1, 2, 4], -u: database username, -p: database password"
          exit 3
          ;;
    -d)
          disk=$2
          shift 2
          ;;
    -t)
          nthread=$2
          shift 2
          ;;
    -u)
          username=$2
          shift 2
          ;;
    -p)
          password=$2
          echo $password
          shift 2
          ;;
    *)
          echo "-d: [S4500, P4500, P4510], -t: [1, 2, 4], -u: database username, -p: database password"
          exit 3
          ;;
  esac
done

do_prepare () {
  if [ $disk = 'P4510' ]; then
    raw="/dev/nvme0n1"
  else
     if [ $disk = 'P4500' ]; then
       raw="/dev/nvme1n1"
     else
       raw="/dev/sda"
     fi
  fi
  sudo mount -t xfs "$raw" /var/lib/mysqldb
  folder=/home/dave/result/$disk
  if [ ! -d "$folder" ]; then
       mkdir "$folder"
  fi
  cd /var/lib/mysqldb
  sudo rm -rf *
  sudo sh -c "cp -r /var/lib/mysql/* /var/lib/mysqldb/"
  sudo chown -R mysql:mysql /var/lib/mysqldb
  sudo service mysql start
}


do_sysbench () {
  # do_cleanup
  if [ ! -d "$folder" ]; then
      mkdir "$folder"
  fi
  mysql -u root -pabc123 -e "create database dbtest"
  sysbench --test=oltp --oltp-table-size=10000 --mysql-db=dbtest --mysql-user=$username --mysql-password=$password prepare
  for i in 1 4 8
  do
    mkdir $folder/$i
    for j in $(seq 1 10)
    do
     sysbench --test=oltp --oltp-table-size=10000 --num-threads=$i --oltp-test-mode=complex --mysql-db=dbtest --mysql-user=$username --mysql-password=$password run | tee $folder/$i/$j.out;
    done
  done
}

do_cleanup () {
   sysbench --test=oltp --mysql-db=dbtest --mysql-user=root --mysql-password=abc123 cleanup
   mysql -u root -pabc123 -e "drop database dbtest"
   sudo service mysql stop
   # Cleanup data, remove everyting!
   cd /var/lib/mysqldb
   rm -rf *
   sudo umount /var/lib/mysqldb 
}

# do_analysis () {
#   # Get the data and do analysis
# }

do_prepare
do_sysbench
do_cleanup
