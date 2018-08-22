#!/bin/bash
set -e

disk=""
username="root"
password="abc123"
folder="/home/dave/result/P4500"
raw=""
tran=""
avg=""
centric_db_host="192.168.20.169"
centric_db_userame="root"
centric_db_password="DELL-esi-db1"
timestamp=`date +"%Y-%m-%d_%H-%M-%S"`


while [ $# -gt 0 ]; do
  case "$1" in
    -h)
          echo "Usage: -d: [S4500, P4500, P4510], -t: [1, 2, 4], -u: database username, -p: database password"
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
  mysql -u $username -p$password -e "create database dbtest"
  sysbench --test=oltp --oltp-table-size=10000 --mysql-db=dbtest --mysql-user=$username --mysql-password=$password prepare
  for i in 1 4 8 12
  # for i in 12
  do
    mkdir $folder/$i
    for j in $(seq 1 10)
    do
     sysbench --test=oltp --oltp-table-size=10000 --num-threads=$i --oltp-test-mode=complex --mysql-db=dbtest --mysql-user=$username --mysql-password=$password run | tee $folder/$i/$j.out;
    done
  done
}

do_cleanup () {
  #umount
  #cleanup data, rm xxx
  # cd /var/lib/mysqldb
  # rm -rf *
  sysbench --test=oltp --mysql-db=dbtest --mysql-user=$username --mysql-password=$password cleanup
  mysql -u $username -p$password -e "drop database dbtest"
  sudo service mysql stop
  sudo umount /var/lib/mysqldb 
}

do_analysis () {
  # fetch the data and do analysis
  # shell code below may has the issue if we run benchmark only one time, but it's okay for multiple times
  tran=`grep "transactions:" ./*.out -R | cut -d '(' -f2|cut -d ')' -f1 |awk -F" " '{print $1}' | awk '{a+=$1}END{print a}'`
  avg=`grep "avg:" ./*.out -R | awk -F" " '{print $3}' | awk '{a+=$1}END{print a}'`
}


do_writedatabase() {
  # connect to the database and write the final data into database;
  mysql -h $centric_db_host -u $centric_db_userame -p$centric_db_password -e "use sysbench; insert into bench_result(drivemodel, trans, avg, timestamp) values (\"$disk\", \"$tran\", \"$avg\", \"$timestamp\")"
}

do_cleanup
do_prepare
do_sysbench
do_analysis
do_writedatabase
