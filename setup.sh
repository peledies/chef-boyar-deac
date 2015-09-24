 #!/bin/sh

green=$(tput setaf 2)
gold=$(tput setaf 3)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)

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
  echo "${gold}--- Setting up WIFI ---${green}"

  read -p "${cyan}Do you want to list nearby wifi: [y/n]" answer
  case "${answer}" in
      [yY])
          echo "${gold}--- Available WIFI ---${green}"
          iwlist wlan0 scan | egrep "ESSID" | cut -d: -f2- | tr -d '"'
  esac

  echo "${cyan}Enter SSID:${gold}"
  read SSID

  echo "${cyan}Enter password:${gold}"
  read password
  echo "${green}"

  timestamp=$(date +%s)

  echo "${gold}--- Creating backup interfaces file [${magenta}/etc/network/interfaces.$timestamp.BACKUP${gold}] ---${green}"
  # create a backup file
  cp /etc/network/interfaces /etc/network/interfaces.$timestamp.BACKUP

  echo "${gold}--- Writing configuration to interfaces config file [${magenta}/etc/network/interfaces${gold}] ---${green}"

  printf 'auto lo\n' > /etc/network/interfaces
  printf 'iface lo inet loopback\n' >> /etc/network/interfaces
  printf 'iface eth0 inet dhcp\n' >> /etc/network/interfaces
  printf 'allow-hotplug wlan0\n' >> /etc/network/interfaces
  printf '#wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf\n' >> /etc/network/interfaces
  printf 'iface wlan0 inet dhcp\n' >> /etc/network/interfaces
  printf 'wpa-ssid ' >> /etc/network/interfaces
  printf "$SSID" >> /etc/network/interfaces
  printf '\nwpa-key-mgmt WPA-PSK\n' >> /etc/network/interfaces
  printf 'wpa-group TKIP CCMP\n' >> /etc/network/interfaces
  printf 'wpa-psk ' >> /etc/network/interfaces
  printf "$password" >> /etc/network/interfaces

  echo "${gold}--- Restarting wlan0 ---${green}"

  ifdown wlan0
  ifup wlan0
}

##################################
# Disable Wifi dongle power save #
##################################
wifi_power_management () {
  echo "${gold}--- Disabling power save for wireless adapter ---${green}"

  printf '# Disable power management\n' > /etc/modprobe.d/8192cu.conf
  printf 'options 8192cu rtw_power_mgnt=0 rtw_enusbss=1 rtw_ips_mode=1' >> /etc/modprobe.d/8192cu.conf

  # we may require some wifi reconnection cron job to reconnect when a gateway
  # is turned off then back on. see example.
  # https://www.raspberrypi.org/forums/viewtopic.php?t=61665#p507263
}

###################
# Configure Avahi #
###################
avahi () {
  # Install Avahi-daemon
  echo "${gold}--- Installing Avahi ---${green}"
  apt-get install avahi-daemon

  # set avahi-daemon to start in run modes
  echo "${gold}--- Setting Avahi to start in all run levels---${green}"
  sudo update-rc.d avahi-daemon defaults
  
  timestamp=$(date +%s)
  
  # create a backup file
  echo "${gold}--- Creating backup config file [${magenta}/etc/avahi/avahi-daemon.BACKUP.$timestamp.conf${gold}] ---${green}"
  cp /etc/avahi/avahi-daemon.conf /etc/avahi/avahi-daemon.BACKUP.$timestamp.conf

  read -p "${cyan}Do you want to give this board a unique name (Default = raspberrypi): [y/n]" answer
  case "${answer}" in
    [yY])
        echo "${cyan}\nEnter name:${gold}"
        read NAME
  esac
  case "${answer}" in
    [nN])
        NAME="raspberrypi"
  esac

  echo "${gold}--- Writing changes to conf file [${magenta}/etc/avahi/avahi-daemon.conf${gold}] ---${green}"
  sudo sed -i "/host-name=/c\host-name=$NAME" /etc/avahi/avahi-daemon.conf
  sudo sed -i '/domain-name=/c\domain-name=local' /etc/avahi/avahi-daemon.conf
  sudo sed -i '/publish-addresses=/c\publish-addresses=yes' /etc/avahi/avahi-daemon.conf
  
  echo "${gold}--- Restarting Avahi ---${green}"
  /etc/init.d/avahi-daemon restart
}

#######################
# General Setup Tasks #
#######################
general () {
  echo "${gold}--- Updating Aptitude package library ---${green}"

  # update package library
  sudo apt-get update

  echo "${gold}--- Installing VIM ---${green}"
  # Install VIM
  sudo apt-get install vim

  printf "syntax on\n" > ~/.vimrc
  printf "colorscheme desert\n" >> ~/.vimrc

  echo "${gold}--- Installing git ---${green}"
  # Install git
  apt-get install git
}

chef () {
  # buy this guy a beer
  # http://everydaytinker.com/raspberry-pi/installing-chef-client-on-a-raspberry-pi-2-model-b/

  #Chef requires ruby >= 2.0
  echo "${gold}--- Updating Aptitude package library ---${green}"
  apt-get update
  
  echo "${gold}--- Removing ruby 1.9 ---${green}"
  apt-get purge ruby1.9 -y

  # install our build dependencie
  echo "${gold}--- install chef build dependencies ---${green}"
  apt-get install build-essential libyaml-dev libssl-dev

  # download ruby 2.2.2
  echo "${gold}--- Downloading ruby 2.2.2 ---${green}"
  wget http://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.2.tar.gz

  # untar and enter the Ruby source directory
  echo "${gold}--- unpacking ruby 2.2.2 ---${green}"
  tar -xvzf ruby-2.2.2.tar.gz
  cd ruby-2.2.2

  # Run the configure script to prepare for compiling
  echo "${gold}--- Run the configure script to prepare for compiling ---${green}"
  ./configure --enable-shared --disable-install-doc --disable-install-rdoc --disable-install-capi

  # This will install Ruby to /usr/local/bin/ruby by default.
  echo "${gold}--- install Ruby to /usr/local/bin/ruby ---${green}"
  make install

  # Logout and log back in to ensure your path picks up the new Ruby
  # exit

  # dont install all the gem documentation
  echo "gem: --no-document" >> ~/.gemrc

  # install the Chef Rubygem without documentation
  echo "${gold}--- Install the Chef Rubygem without documentation ---${green}"
  gem install chef --no-ri --no-rdoc

  # show chef-server version
  echo "${gold}--- Chef has been installed to the following version ---${green}"
  chef-client --version
}

purge () {
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
  read -p "${cyan}Do you want to remove GUI components: [y/n]${gold} " answer
  case "${answer}" in
      [yY])
        echo "${gold}--- Removing unnecessary GUI files ---${green}"
        for i in $gui; do
          echo apt-get -y remove --purge $i
        done
  esac

  read -p "${cyan}Do you want to remove Educational components: [y/n]${gold} " answer
  case "${answer}" in
      [yY])
        # aparently raspberrypi-ui-mods removes this file. we need it for wifi
        cp /etc/network/interfaces /etc/network/interfaces.bak
        echo "${gold}--- Removing unnecessary Educational files ---${green}"
        for i in $edu; do
          apt-get -y remove --purge $i
        done
        mv /etc/network/interfaces.bak /etc/network/interfaces
  esac

  read -p "${cyan}Do you want to remove X11 components: [y/n]${gold} " answer
  case "${answer}" in
      [yY])
        echo "${gold}--- Removing unnecessary X11 files ---${green}"
        for i in $x11; do
          echo apt-get -y remove --purge $i
        done
  esac


  # Clean up unused packages
  apt-get -y autoremove
}

read -p "${cyan}Do you want to setup wifi: [y/n]${gold} " answer
case "${answer}" in
    [yY])
        wifi;;
esac
read -p "${cyan}Do you want to disable power saving for wifi. This will make the unit more responsive after extended idle times: [y/n]${gold} " answer
case "${answer}" in
    [yY])
        wifi_power_management;;
esac


read -p "${cyan}Do you want to do the general setup: [y/n]${gold} " answer
case "${answer}" in
    [yY])
        general;;
esac

read -p "${cyan}Do you want to setup avahi: [y/n]${gold} " answer
case "${answer}" in
    [yY])
        avahi;;
esac

read -p "${cyan}Do you want to setup chef: [y/n]${gold} " answer
case "${answer}" in
    [yY])
        chef;;
esac

read -p "${cyan}Do you want to purge unnecessary GUI files to save space (≈500mb): [y/n]${gold} " answer
case "${answer}" in
    [yY])
        purge;;
esac