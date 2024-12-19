#!/bin/bash
# This script will help you to compile the linux kernel 6.10.10 and create a bootable disk image !
# To prevent grub destruction this script quit on error !

set -e

export current_dir=$PWD
export kernel_dir_compiled=$current_dir/linux-6.10.10.compiled
export kernel_dir_source=$current_dir/linux-6.10.10.source
ROOTFS_DIR="/tmp/my-rootfs"
IMG_NAME="disk.img"
QCOW2_NAME="disk.qcow2"
LOOP_DEVICE=""
nproc=$(nproc)
LOCAL_SHARE="/home/ubuntu/share-folder/autocompil/2600-Root-kit/Merlin2600"


requirements_install() {
    echo "Requirements install"

    if ! grep -q "docker.com" /etc/apt/sources.list.d/dockerce.list; then
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/dockerce.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/dockerce.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/dockerce.list > /dev/null
    else
        echo "Docker repository is already added."
    fi
    sudo apt update

    packages=("libelf-dev" "binutils-dev" "qemu-kvm" "qemu-utils" "dbus-x11" "parted" "apt-transport-https" "ca-certificates" "curl" "gnupg" "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "$package"; then
            echo "$package is already installed."
        else
            echo "Installing $package..."
            sudo apt install -y "$package"
        fi
    done

    if groups $USER | grep -q "docker"; then
        echo "User $USER is already in the docker group."
    else
        echo "Adding $USER to the docker group."
        sudo usermod -aG docker "$USER"
    fi

    echo "###############################     Requirements successfully installed !     #################################"
}

download_kernel() {
    if [ ! -d $kernel_dir_source ]; then
        echo "Downloading the linux kernel 6.10.10"
            wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.10.tar.xz
        echo "Linux kernel successfully downloaded !"

        echo "Extracting the linux kernel 6.10.10"
            tar -xf linux-6.10.10.tar.xz
            rm -rf linux-6.10.10.tar.xz
            mv linux-6.10.10 $kernel_dir_source
        echo "Linux kernel successfully extracted !"
        fi
}

compile_kernel() {
    if [ -d $kernel_dir_source ]; then
        echo "Compiling the linux kernel 6.10.10"

        if [ ! -d $kernel_dir_compiled ]; then
            cp -r $kernel_dir_source $kernel_dir_compiled
        fi
        cd $kernel_dir_compiled
        make defconfig
        make -j${nproc}
        cd $current_dir
        echo "Linux kernel successfully compiled !"
    else 
        echo "Kernel folder not found !"
        echo "Please download the kernel first !"
        exit 1
    fi
}

create_bootable_image() {
    echo "Choose a Qemu mode :"
    echo "1) Local share"
    echo "2) Distant mode"
    read -p "Enter your choice number : " choice

    # Définir le mode en fonction du choix
    case $choice in
        1)
            mode=1
            echo "Selected : Local share"
            ;;
        2)
            mode=2
            echo "Selected : Web server"
            ;;
     
        *)
            echo "Invalid Choice"
            return 1
            ;;
    esac


    LOOP_DEVICE=$(losetup -l | grep $IMG_NAME | awk '{print $1}')
            if [ -n "$LOOP_DEVICE" ]; then                
                echo "Found existing loop device: $LOOP_DEVICE, reusing it."
            else
                if [ ! -f $IMG_NAME ]; then
                echo "Creating a new empty disk image of 450MB !"
                sudo truncate -s 450M $IMG_NAME
                echo "Disk image $IMG_NAME successfully created !"
                fi            
            
                echo "Creating a bootable partition on the disk image !"               
                /sbin/parted -s $IMG_NAME mktable msdos                 
                /sbin/parted -s $IMG_NAME mkpart primary ext4 1 "100%"           
                /sbin/parted -s $IMG_NAME set 1 boot on

                echo "Creating a device to access disk image !"
                sudo losetup -Pf ${IMG_NAME}
                
                LOOP_DEVICE=$(losetup -l | grep $IMG_NAME | awk '{print $1}')
                echo "New loop device created: $LOOP_DEVICE"
            fi
        
            
            echo "###Formating the partition 1 to ext4 !"
            sudo mkfs.ext4 -F ${LOOP_DEVICE}p1

            echo "Creating a working directory to mount the partition!"
            if [ ! -d $ROOTFS_DIR ]; then
                mkdir -p $ROOTFS_DIR
            else
                sudo rm -rf $ROOTFS_DIR
                mkdir -p $ROOTFS_DIR
            fi          

            echo "### Mounting the first partition on this directory ! ###"
            sudo mount ${LOOP_DEVICE}p1 $ROOTFS_DIR

            echo "### Asking for docker to install Alpine Linux on the disk image !"
            sudo docker run --security-opt apparmor=unconfined -it --rm -v $ROOTFS_DIR:/my-rootfs alpine /bin/sh -c '

                    apk add openrc && 
                    apk add iproute2 && 
                    apk add busybox-extras && 
                    apk add iputils && 
                    apk add curl &&
                    apk add neofetch &&
                    apk add nano && 
                    apk add bash &&
                    apk add sudo && 
                    apk add agetty &&
                    apk add util-linux && apk add build-base && 
                    apk add linux-headers && 

                    ln -s agetty /etc/init.d/agetty.ttyS0 &&
                    echo ttyS0 > /etc/securetty &&
                    rc-update add agetty.ttyS0 default &&

                    rc-update add root default &&
                    echo "root:root" | chpasswd &&
                                                
                    echo "auto lo" >> /etc/network/interfaces &&
                    echo "iface lo inet loopback" >> /etc/network/interfaces &&
                    echo "auto eth0" >> /etc/network/interfaces &&
                    echo "iface eth0 inet dhcp" >> /etc/network/interfaces &&
                    rc-update add networking boot &&
                    
                    echo "nameserver 1.1.1.1" > /etc/resolv.conf &&
                    echo "Linux2600-Alpine" > /etc/hostname &&
                    echo "127.0.1.1 Linux2600-Alpine" >> /etc/hosts &&

                    
                    rc-update add devfs boot &&
                    rc-update add procfs boot &&
                    rc-update add sysfs boot &&
                    
            
                    for d in bin etc lib root sbin usr; do tar c "/$d" | tar x -C /my-rootfs; done &&
                    for dir in dev proc run sys var; do mkdir /my-rootfs/${dir}; done &&                  
                    exit
                    '
                    cat <<EOF | sudo tee $ROOTFS_DIR/etc/profile
# Custom global profile for Alpine Linux
export PATH=\$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PS1="\u@\h:\w\$ "
alias ll='ls -la'
alias reboot='reboot -f'
neofetch
EOF

if [ $mode -eq 1 ]; then
    # Local share mode
   
cat <<EOF | sudo tee $ROOTFS_DIR/etc/local.d/mount_shared_folder.start
#!/bin/sh
# Script pour monter automatiquement le dossier partagé
mkdir -p /mnt
mkdir -p /mnt/shared_folder
mount -t 9p -o trans=virtio shared_folder /mnt/shared_folder
EOF

            sudo chmod +x $ROOTFS_DIR/etc/local.d/mount_shared_folder.start
            sudo chroot $ROOTFS_DIR rc-update add local default
fi


            echo "### Preparing grub ###" 
            sudo mkdir -p $ROOTFS_DIR/boot/grub

            echo "### Copying the compiled kernel to the disk image ! ###"
            sudo cp ${kernel_dir_compiled}/arch/x86/boot/bzImage $ROOTFS_DIR/boot/vmlinuz

            echo "### Creating the grub.cfg file ! ###"
            cat <<EOF | sudo tee $ROOTFS_DIR/boot/grub/grub.cfg
serial
terminal_input serial
terminal_output serial
set root=(hd0,1)
timeout=1
menuentry "Linux2600" {
    linux /boot/vmlinuz root=/dev/sda1 console=ttyS0 noapic
}
EOF
            # sudo nano $ROOTFS_DIR/boot/grub/grub.cfg
            
            echo "### Installing Grub on the disk image ! ###"
            sudo grub-install --directory=/usr/lib/grub/i386-pc --boot-directory=$ROOTFS_DIR/boot ${LOOP_DEVICE}

            echo "### Cleanning UP ! ###"
            sudo umount $ROOTFS_DIR
            # sudo losetup -d ${LOOP_DEVICE}
            sudo rm -rf $ROOTFS_DIR
            # sudo rm -rf ${LOOP_DEVICE}   

            echo "### Disk image $IMG_NAME successfully created ! ###"

            echo "###   Converting the disk image to qcow2 format ! ###"

            qemu-img convert -f raw -c -O qcow2 $IMG_NAME $QCOW2_NAME

}

qemu_start_img() {
    echo "### Disk image $QCOW2_NAME START ! ###"
    if [ $mode -eq 1 ]; then
        # Local share mode
        echo "QEMU Local share mode starting"
        gnome-terminal -- bash -c "qemu-system-x86_64 -hda $QCOW2_NAME -nographic -enable-kvm -netdev user,id=mynet0,hostfwd=tcp::2606-:2606 -device virtio-net-pci,netdev=mynet0 -virtfs local,path=$LOCAL_SHARE,mount_tag=shared_folder,security_model=mapped-xattr ; exec bash"
    elif [ $mode -eq 2 ]; then
        # Web distant mode
        echo "QEMU Web distant mode starting"
        gnome-terminal -- bash -c "qemu-system-x86_64 -hda $QCOW2_NAME -nographic -enable-kvm -netdev user,id=mynet0,hostfwd=tcp::2606-:2606 -device virtio-net-pci,netdev=mynet0 ; exec bash"
    else
        echo "Invalid Choice"
        return 1
    fi   

}


display_menu() {
    echo "Welcome to the Auto_cow.sh script!"
    echo "This script will help you to compile the linux kernel 6.10.10 and create a bootable disk image!"
    echo "What do you want to do?"

    echo "1. Install requirements"
    echo "2. Download the linux kernel 6.10.10"
    echo "3. Compile the linux kernel 6.10.10"
    echo "4. Create a bootable disk image"
    echo "5. Compile the kernel and create a bootable disk image"
    echo "6. Start the disk image"
    echo "7. Exit"
}

while true; do
    display_menu

    read -p "What do you wanna do ? :   " choice

case "$choice" in     
    1) 
    # Requirements install
    requirements_install
    ;;

    2) 
    # Download the linux kernel 6.10.10
    download_kernel
    ;;

    3)
    # Compile the linux kernel 6.10.10
    compile_kernel      
    ;;
    
    4) 
    # Create a bootable disk image
    create_bootable_image
    qemu_start_img
    ;;  
    
    5)
    # Compile the kernel and create a bootable disk image
    compile_kernel
    create_bootable_image
    qemu_start_img
    ;;

    6)
    # Start the disk image
    qemu_start_img
    ;;

    7)  # Exit
            echo "Goodbye!"
            exit 0
    ;;

    *)  # Invalid option
        echo "Invalid option, please try again."
        ;;
    esac

    echo ""
    echo "Press Enter to return to the menu..."
    read 

done