configuration
=============
pool size: 2
osd size: 3
pg (pgp) num: 128
osd nodes are separated across two different nodes
rbd image size: 10G (10240M)

Shell command to pull out the data we need
==========================================
head 10 and sum:
$ grep "Bandwidth " ./radosbench5.txt | head -10 | awk -F: '{print $2}' | awk '{a+=$1}END{print a}'


middle 10 and sum:
$ grep "Bandwidth " ./radosbench5.txt | head -n 20 | tail -n 10  | awk -F: '{print $2}' | awk '{a+=$1}END{print a}'


tail 10 and sum：
$ grep "Bandwidth " ./radosbench5.txt | tail -n 10  | awk -F: '{print $2}' | awk '{a+=$1}END{print a}'

