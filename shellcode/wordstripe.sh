#follow is sample content in out.txt
#this utility is used to stripe some useless word from the output
#dpkg: warning: files list file for package 'gnome-power-manager' missing; assuming package has no files currently installed
cat /home/dave/out.txt | while read LINE  
do
        #echo $LINE | sed "s/' .*//; s/.*'//";
        res=`echo $LINE | sed "s/' .*//; s/.*'//"`;
        echo "will reinstall this packages: "
        echo $res;
        #read -p "Do you wish to install this program?";
        #apt-get install --reinstall "$res";
        #echo $res
        sleep 2s
        apt-get install --reinstall "$res";
done
