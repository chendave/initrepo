#hello, dave
#sort and omit repeated lines
find ./* -name *.jar | awk -F '/' '{print $5}' > out.txt
sort -n out.txt | uniq   > outupdate.txt

