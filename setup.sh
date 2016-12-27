#!/bin/bash

pushd $(dirname $0) > /dev/null; SCRIPTPATH=$(pwd); popd > /dev/null

source $SCRIPTPATH/assets/pretty_tasks.sh
source $SCRIPTPATH/assets/info_box.sh

##########################
# Ensure Root privileges #
##########################
if [ "$(whoami)" != "root" ]; then
  echo "${gold} !- You will need to run this with root, or sudo. -!"
  exit 1
fi

##########################
# wireless network setup #
##########################
wifi () {
  echo "${gold}--- Setting up WIFI ---${default}"

  read -p "${cyan}Do you want to list nearby wifi: [y/n]" answer
  case "${answer}" in
      [yY])
          scan_wifi
  esac

  echo "${cyan}Enter SSID:${gold}"
  read SSID

  echo "${cyan}Enter password:${gold}"
  read password
  echo "${default}"

  timestamp=$(date +%s)

  echo_start
  echo -n "${gold}Creating backup interfaces file [${magenta}/etc/network/interfaces.$timestamp.BACKUP${gold}]${default}"
  # create a backup file
  cp /etc/network/interfaces /etc/network/interfaces.$timestamp.BACKUP
  test_for_success $?

  echo_start
  echo -n "${gold}Writing configuration to interfaces config file [${magenta}/etc/network/interfaces${gold}]${default}"
  cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback
iface eth0 inet dhcp
allow-hotplug wlan0
#wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
iface wlan0 inet dhcp
wpa-ssid $SSID
nwpa-key-mgmt WPA-PSK
wpa-group TKIP CCMP
wpa-psk $password
EOF
  test_for_success $?

  echo_start
  echo -n "${gold}Restarting wlan0${default}"
  ifdown wlan0 > /dev/null 2>&1 && ifup wlan0 > /dev/null 2>&1
  test_for_success $?

  echo "WIFI Setup Complete."  
}

chk_device () {
  #check that USB wifi device is plugged in and seen
  echo_start
  echo -n "The RTL8188CUS device has been successfully located."
  if [[ -n $(lsusb | grep RTL8188CUS) ]]; then
    echo_success
  else
    echo_failure
    exit 1
  fi
}

scan_wifi () {
  MOVE_ONE="\\033[0G"
  MOVE_TWO="\\033[40G"
  MOVE_THREE="\\033[50G"
  H_ONE="\\033[5G"
  H_TWO="\\033[37G"
  H_THREE="\\033[51G"

  printf "\n\r${cyan} ${bold}${H_ONE}ESSID ${H_TWO}Security ${H_THREE}Signal \n\r"
  printf "==========================================================${default}\n\r"
  iwlist wlan0 scan | while read line
  do
     case $line in
      *ESSID*)
        line=${line#*ESSID:}
        ssid=$(sed -e 's/^"//' -e 's/"$//' <<< "$line")
        printf "${MOVE_ONE} $ssid"
          ;;
    *Encryption*)
      line=${line#*Encryption key:}
        printf "${MOVE_TWO}$line"
          ;;
    *Signal*level*)
      line=${line#*Signal level=}
        printf "${MOVE_THREE} $line \n\r"
          ;;
     esac
  done
  printf "\n\r"
}

##################################
# Disable Wifi dongle power save #
##################################
wifi_power_management () {
  echo "${gold}--- Disabling power save for wireless adapter ---${default}"

  echo_start
  echo -n "${gold}Writing configuration to interfaces config file [${magenta}/etc/network/interfaces${gold}]${default}"
  cat <<EOF > /etc/modprobe.d/8192cu.conf
# Disable power management
options 8192cu rtw_power_mgnt=0 rtw_enusbss=1 rtw_ips_mode=1
EOF
  test_for_success $?

  # we may require some wifi reconnection cron job to reconnect when a gateway
  # is turned off then back on. see example.
  # https://www.raspberrypi.org/forums/viewtopic.php?t=61665#p507263
}

###################
# Install Apache2 #
###################
install_apache () {
  # Install Apache2
  echo_start
  echo -n "${gold}Installing Apache2${default}"
  apt-get install apache2 -y > /dev/null 2>&1
  test_for_success $?
}

#################
# Install nginx #
#################
install_nginx () {
  echo "${gold}--- Installing and configure Nginx ---${default}"

  # Install nginx
  echo_start
  echo -n "${gold}Installing Nginx${default}"
  apt-get install nginx -y > /dev/null 2>&1
  test_for_success $?

  # Configure nginx to work with php-fpm
  echo_start
  echo -n "${gold}Enabling php to work with nginx [${magenta}/etc/nginx/sites-enabled/default${gold}]${default}"
  cat <<EOF > /etc/nginx/sites-enabled/default
server {
  root /var/www;
  index index.php index.html index.htm;

  # Make site accessible from http://localhost/
  server_name kiosk.local;

  location ~ \.php$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass unix:/var/run/php5-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
  }
}
EOF
  test_for_success $?

  # Reload nginx default configuration
  echo_start
  echo -n "${gold}Reloading nginx default host${default}"
  sudo /etc/init.d/nginx reload > /dev/null 2>&1
  test_for_success $?
}

###############
# Install PHP #
###############
install_php () {
  # Install php
  echo_start
  echo -n "${gold}Installing PHP${default}"
  apt-get install php5 libapache2-mod-php5 -y > /dev/null 2>&1
  test_for_success $?
}
###################
# Install PHP-fpm #
###################
install_php_fpm () {
  # Install php-fpm
  echo_start
  echo -n "${gold}Installing PHP${default}"
  apt-get install php5-fpm -y > /dev/null 2>&1
  test_for_success $?
}

########################
# www-data Sudo access #
########################
www_sudo () {
  echo_start
  echo -n "${gold}Give www-data passwordless access to iwlist${default}"
  sudo echo "www-data ALL=(ALL) NOPASSWD: /sbin/iwlist" >> /etc/sudoers
  test_for_success $?
}

###################
# Configure Avahi #
###################
avahi () {
  echo "${gold}--- Installing and configure Avahi ---${default}"
  read -p "${cyan}Do you want to give this board a unique name (Default = raspberrypi): [y/n]" answer
  case "${answer}" in
    [yY])
        echo "${cyan}Enter name:${gold}"
        read NAME
  esac
  case "${answer}" in
    [nN])
        NAME="raspberrypi"
  esac

  # Install Avahi-daemon
  echo_start
  echo -n "${gold}Installing Avahi${default}"
  apt-get install avahi-daemon -y > /dev/null 2>&1
  test_for_success $?

  # set avahi-daemon to start in run modes
  echo_start
  echo -n "${gold}Setting Avahi to start in all run levels${default}"
  sudo update-rc.d avahi-daemon defaults > /dev/null 2>&1
  test_for_success $?

  timestamp=$(date +%s)
  
  # create a backup file
  echo_start
  echo -n "${gold}Creating backup config file [${magenta}/etc/avahi/avahi-daemon.BACKUP.$timestamp.conf${gold}]${default}"
  cp /etc/avahi/avahi-daemon.conf /etc/avahi/avahi-daemon.BACKUP.$timestamp.conf
  test_for_success $?

  echo_start
  echo -n "${gold}Writing changes to conf file [${magenta}/etc/avahi/avahi-daemon.conf${gold}]${default}"
  sudo sed -i "/host-name=/c\host-name=$NAME" /etc/avahi/avahi-daemon.conf
  sudo sed -i '/domain-name=/c\domain-name=local' /etc/avahi/avahi-daemon.conf
  sudo sed -i '/publish-addresses=/c\publish-addresses=yes' /etc/avahi/avahi-daemon.conf
  test_for_success $?
  
  echo_start
  echo -n "${gold}Restarting Avahi${default}"
  /etc/init.d/avahi-daemon restart > /dev/null 2>&1
  test_for_success $?
}

#######################
# General Setup Tasks #
#######################
general () {
  # Install VIM
  echo_start
  echo -n "${gold}Installing VIM${default}"
  sudo apt-get install vim -y > /dev/null 2>&1
  test_for_success $?

  if [ ! -e /home/pi/.vimrc ]; then
    touch /home/pi/.vimrc
    chown pi /home/pi/.vimrc
    chgrp pi /home/pi/.vimrc
  fi

  # Configure VIM
  echo_start
  echo -n "${gold}Updating VIM Config file [${magenta}~/.vimrc${gold}]"
  printf "syntax on\n" > /home/pi/.vimrc
  printf "colorscheme desert\n" >> /home/pi/.vimrc
  test_for_success $?

  # Install git
  echo_start
  echo -n "${gold}Installing git${default}"
  apt-get install git -y > /dev/null 2>&1
  test_for_success $?
}

chef () {
  # buy this guy a beer
  # http://everydaytinker.com/raspberry-pi/installing-chef-client-on-a-raspberry-pi-2-model-b/

  #Chef requires ruby >= 2.0
  echo "${gold}--- Updating Aptitude package library ---${default}"
  apt-get update
  
  echo "${gold}--- Removing ruby 1.9 ---${default}"
  apt-get purge ruby1.9 -y

  # install our build dependencie
  echo "${gold}--- install chef build dependencies ---${default}"
  apt-get install build-essential libyaml-dev libssl-dev

  # download ruby 2.2.2
  echo "${gold}--- Downloading ruby 2.2.2 ---${default}"
  wget http://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.2.tar.gz

  # untar and enter the Ruby source directory
  echo "${gold}--- unpacking ruby 2.2.2 ---${default}"
  tar -xvzf ruby-2.2.2.tar.gz
  cd ruby-2.2.2

  # Run the configure script to prepare for compiling
  echo "${gold}--- Run the configure script to prepare for compiling ---${default}"
  ./configure --enable-shared --disable-install-doc --disable-install-rdoc --disable-install-capi

  # This will install Ruby to /usr/local/bin/ruby by default.
  echo "${gold}--- install Ruby to /usr/local/bin/ruby ---${default}"
  make install

  # Logout and log back in to ensure your path picks up the new Ruby
  # exit

  # dont install all the gem documentation
  echo "gem: --no-document" >> ~/.gemrc

  # install the Chef Rubygem without documentation
  echo "${gold}--- Install the Chef Rubygem without documentation ---${default}"
  gem install chef --no-ri --no-rdoc

  # show chef-server version
  echo "${gold}--- Chef has been installed to the following version ---${default}"
  chef-client --version
}

purge_gui () {
  gui="
    gstreamer1.0-x gstreamer1.0-omx gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-alsa
    gstreamer1.0-libav
    epiphany-browser
    lxde lxtask menu-xdg gksu
    xpdf gtk2-engines alsa-utils
    netsurf-gtk zenity
    desktop-base lxpolkit
    weston
    omxplayer
    raspberrypi-artwork
    lightdm gnome-themes-standard-data gnome-icon-theme
    qt50-snapshot qt50-quick-particle-examples
    lxappearance
    lxde-common lxde-icon-theme
    lxinput
    lxpanel
    lxrandr
    lxsession-edit
    lxshortcut
    lxterminal
  "
  x11="
    obconf
    openbox
    raspberrypi-artwork
    xarchiver
    xinit
    xserver-xorg
    xserver-xorg-video-fbdev
    x11-utils
    x11-common
    x11-session
    utils
    xserver-xorg-video-fbturbo
  "
  read -p "${cyan}Are you sure you want to remove all GUI components: [y/n]${gold} " answer
  case "${answer}" in
      [yY])
        echo "${gold}--- Removing unnecessary GUI files ---${default}"
        for i in $gui; do
          echo apt-get -y remove --purge $i
        done

        echo "${gold}--- Removing unnecessary X11 files ---${default}"
        for i in $x11; do
          echo apt-get -y remove --purge $i
        done
  esac

  # Clean up unused packages
  apt-get -y autoremove
}

purge_educational (){
  edu="
    idle python3-pygame python-pygame python-tk
    idle3 python3-tk
    python3-rpi.gpio
    python-serial python3-serial
    python-picamera python3-picamera
    debian-reference-en dillo x2x
    scratch nuscratch
    raspberrypi-ui-mods
    timidity
    smartsim penguinspuzzle
    pistore
    sonic-pi
    python3-numpy
    python3-pifacecommon python3-pifacedigitalio python3-pifacedigital-scratch-handler python-pifacecommon python-pifacedigitalio
    oracle-java8-jdk
    minecraft-pi python-minecraftpi
    wolfram-engine
  "
  read -p "${cyan}Are you sure you want to remove all Educational components: [y/n]${gold} " answer
  case "${answer}" in
      [yY])
        # aparently raspberrypi-ui-mods removes this file. we need it for wifi
        cp /etc/network/interfaces /etc/network/interfaces.bak
        echo "${gold}--- Removing unnecessary Educational files ---${default}"
        for i in $edu; do
          apt-get -y remove --purge $i
        done
        mv /etc/network/interfaces.bak /etc/network/interfaces
        rm /etc/network/interfaces.bak
  esac
}

setup_access_point () {
  source $SCRIPTPATH/ap_setup.sh
}

LCD_show () {
  source $SCRIPTPATH/lcd_show.sh
}
install_python_3 () {
  RELEASE=3.5.1
 
  # install dependencies
  sudo apt-get install -y libbz2-dev liblzma-dev libsqlite3-dev libncurses5-dev libgdbm-dev zlib1g-dev libreadline-dev libssl-dev tk-dev
   
  # download and build Python
  mkdir ~/python3
  cd ~/python3
  wget https://www.python.org/ftp/python/$RELEASE/Python-$RELEASE.tar.xz
  tar xvf Python-$RELEASE.tar.xz
  cd Python-$RELEASE
  ./configure
  make
  sudo make install
  sudo rm -rf ~/python3/Python-$RELEASE
  cd ~
}
_menu () {
  clear
  echo "${cyan}  Choose an Option"
  echo " ===================${normal}"
  echo "${magenta}  1 ${default}- Wifi Access Point"
  echo "${magenta}  2 ${default}- Wifi Client"
  echo "${magenta}  3 ${default}- Configure IP - Static"
  echo "${magenta}  4 ${default}- Configure IP - DHCP"
  echo "${magenta}  5 ${default}- Current Status"
  echo "${magenta}  6 ${default}- Wifi Scan"
  echo "${magenta}  7 ${default}- Disable power saving for wifi"
  echo "${magenta}  8 ${default}- Configure Avahi (zeroconf)"
  echo "${magenta}  9 ${default}- Install Chef"
  echo "${magenta}  10 ${default}- Remove Educational components"
  echo "${magenta}  11 ${default}- Remove GUI components"
  echo "${magenta}  12 ${default}- Install VIM, GIT"
  echo "${magenta}  13 ${default}- Install Apache, PHP"
  echo "${magenta}  14 ${default}- Install Nginx, PHP"
  echo "${magenta}  15 ${default}- Grant www-data access to iwlist"
  echo "${magenta}  16 ${default}- LCD-show - (for GPIO attached LCD's)"
  echo "${magenta}  17 ${default}- Python 3 - (Install Python 3.5.1)"

  while true; do
    read -p "${cyan} Select an option from the list above: ${gold}" answer
    case $answer in
      1 ) clear; setup_access_point; break;;
      2 ) clear; wifi; break;;
      3 ) clear; cfg_static_ip; break;;
      4 ) clear; cfg_dhcp_ip; break;;
      5 ) clear; chk_status; break;;
      6 ) clear; scan_wifi; break;;
      7 ) clear; wifi_power_management; break;;
      8 ) clear; avahi; break;;
      9 ) clear; chef; break;;
      10 ) clear; purge_educational; break;;
      11 ) clear; purge_gui; break;;
      12 ) clear; general; break;;
      13 ) clear; install_apache; install_php; break;;
      14 ) clear; install_nginx; install_php_fpm; break;;
      15 ) clear; www_sudo; break;;
      16 ) clear; LCD_show; break;;
      17 ) clear; install_python_3; break;;
      * ) echo "Please select a valid option.";;
    esac
  done
}

_menu