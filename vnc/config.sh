#!/bin/bash

sudo apt-get install vnc4server -y
sudo apt-get install xfce4-session
cat <<EOF >~/.vnc/xstartup
#!/bin/sh

# Uncomment the following two lines for normal desktop:
# unset SESSION_MANAGER
# exec /etc/X11/xinit/xinitrc

[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
startxfce4 &
EOF


# start vnc server
vncserver -geometry 1440x900
