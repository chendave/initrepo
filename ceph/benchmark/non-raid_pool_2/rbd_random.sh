#!/bin/bash
set -e

if [ -f "./rbdbench_rand.txt" ];then
    echo "rbdbench_rand.txt exist, deleting..."
    rm -rf ./rbdbench_rand.txt
fi

# Create image in the rbd, size 10G
# rbd remove image1 --pool rbd 
rbd create -p rbd image1 --size 10240 --image-format 2

for i in {1..20}; do
    rbd bench-write image1 --pool=rbd --io-pattern rand | tee -a rbdbench_rand.txt
done

# Cleanup the data after benchmarking
rbd rm image1 --pool rbd
