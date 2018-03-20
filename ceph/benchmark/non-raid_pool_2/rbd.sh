#!/bin/bash
set -e

if [ -f "./rbdbench.txt" ];then
    echo "rbdbench.txt exist, deleting..."
    rm -rf ./rbdbench.txt
fi

# Create image in the rbd, size 10G
# rbd remove image1 --pool rbd 
rbd create -p rbd image1 --size 10240 --image-format 2

for i in {1..20}; do
    rbd bench-write image1 --pool=rbd | tee -a rbdbench.txt
done

# Cleanup the data after benchmarking
rbd rm image1 --pool rbd
