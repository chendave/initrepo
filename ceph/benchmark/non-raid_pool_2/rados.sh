#!/bin/bash
set -e

radosbenchmark()
{
if [ -f "./radosbench$1.txt" ];then
  echo "radosbench$1.txt already exist, deleting..."
  rm -rf ./radosbench$1.txt
fi

#Cleanup data firstly
output=`rados ls --pool rbd | wc -l`
if [ $output -gt 0 ]
then
  rados cleanup -p rbd --prefix benchmark_data
  # rados -p rbd cleanup
fi

#TODO(davechen): Get it clear what's write it is? seq or rand?
echo -e "----------------write---------------\n\n" > radosbench$1.txt
for num in {1..10}; do
  rados bench -p rbd $1 write --no-cleanup | tee -a radosbench$1.txt
done

echo -e "------------------sequential read---------------\n\n" >> radosbench$1.txt

for num in {1..10}; do
  rados bench -p rbd $1 seq | tee -a radosbench$1.txt
done

echo -e "------------------random read---------------\n\n" >> radosbench$1.txt

for num in {1..10}; do
  rados bench -p rbd $1 rand | tee -a radosbench$1.txt
done
return 0
}


for i in 5 10 15 20 25 30;
do
  ret=`radosbenchmark $i`
done

# Cleanup the pool after testing.
rados cleanup -p rbd --prefix benchmark_data
# The below command cannot cleanup all the data sometimes.
# rados -p rbd cleanup
