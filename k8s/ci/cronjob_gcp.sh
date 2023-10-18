# m h  dom mon dow   command
SHELL=/bin/bash
0 9 * * * cd /home/ruquan_zhao && ./sync.sh >> log.out 2>&1
