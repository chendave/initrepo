#!/bin/bash

################################################
#Author: Dave Chen                             #
#Mail: dave.jungler@gmail.com                  #
#                                              #
# Since the name of device may vary, you need  #
# rename the device per the real situation.    #
################################################


set -e

disk=""
username="root"
password="abc123"
# folder="/home/dave/result/P4500"
raw=""
tran=""
avg=""
centric_db_host="192.168.20.169"
centric_db_userame="root"
centric_db_password="DELL-esi-db1"
timestamp=`date +"%Y-%m-%d_%H-%M-%S"`


if [ $# -eq 0 ]; then
  echo "No parameters, pls input parameters:"
  echo "Usage: -d: [S4500, P4500, P4510], -t: [1, 2, 4], -u: database username, -p: database password"
fi

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

# TODO(davechen): Properly, password for database is needed here, will update the code later.
do_deps () {
 sudo -E -H apt-get install mysql-server -y
 sudo -E -H apt-get install sysbench -y
}

#TODO(davechen): Possible to remove hardcode here?
do_prepare () {
  if [ $disk = 'P4510' ]; then
    raw="/dev/nvme0n1"
  else
     if [ $disk = 'P4500' ]; then
       raw="/dev/nvme1n1"
     else
       raw="/dev/sdb"
     fi
  fi
  sudo mount -t ext4 "$raw" /var/lib/mysqldb
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
  # Either choose a range of threads or just pick up the num of thread from input.
  # for i in 1 4 8 12
  for i in $nthread
  do
    mkdir $folder/$i
    for j in $(seq 1 10)
    do
     sysbench --test=oltp --oltp-table-size=10000 --num-threads=$i --oltp-test-mode=complex --mysql-db=dbtest --mysql-user=$username --mysql-password=$password run | tee $folder/$i/$j.out;
    done
  done
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
  cd $folder/1
  tran=`grep "transactions:" ./*.out -R | cut -d '(' -f2|cut -d ')' -f1 |awk -F" " '{print $1}' | awk '{a+=$1}END{print a}'`
  res_tran=$[$tran/10]
  avg=`grep "avg:" ./*.out -R | awk -F" " '{print $3}' | awk '{a+=$1}END{print a}'`
  res_avg=$[$avg/10]
}


do_writedatabase() {
  # connect to the database and write the final data into database;
  mysql -h $centric_db_host -u $centric_db_userame -p$centric_db_password -e "use workload; insert into bench_result(drivemodel, trans, avg, timestamp) values (\"$disk\", \"$res_tran\", \"$res_avg\", \"$timestamp\")"
}

do_cleanup
# do_deps
do_prepare
do_sysbench
do_analysis
do_writedatabase
