#!/bin/bash

# http://raspberry-at-home.com/hotspot-wifi-access-point/

#variables init
AP_CHANNEL=1
run_time=`date +%Y%m%d%H%M`
log_file="ap_setup_log.${run_time}"

green=$(tput setaf 2)
gold=$(tput setaf 3)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)

BOOTUP=color
RES_COL=0
RES_COL_B=20
MOVE_TO_COL_B="echo -en \\033[${RES_COL_B}G"
MOVE_TO_COL="echo -en \\033[${RES_COL}G"
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_WARNING="echo -en \\033[1;33m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
CHIPSET="no"

echo_start() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_SUCCESS
  echo -n $"..."
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  $MOVE_TO_COL_B
  return 0
}

echo_success() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_SUCCESS
  echo -n $" OK "
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\n"
  return 0
}

echo_done() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_SUCCESS
  echo -n $" DONE "
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\n"
  return 0
}

echo_failure() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_FAILURE
  echo -n $"FAILED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\n"
  return 1
}

test_for_success() {
   rc=$1
  if [[ $rc -eq 0 ]] ; then
    echo_success
  else
    echo_failure
    exit $rc
  fi
}

# Update Repositories
#echo_start
#echo -n "Updating repositories"
#apt-get update > /dev/null 2>&1
#test_for_success $?

# Get new Broadcast SSID
read -p "Please provide your new SSID to be broadcasted by RPi (i.e. My_Raspi_AP): " AP_SSID

# Get the new AP password
read -s -p "Please provide password for your new wireless network (8-63 characters): " AP_WPA_PASSPHRASE
echo ""
if [ `echo $AP_WPA_PASSPHRASE | wc -c` -lt 8 ] || [ `echo $AP_WPA_PASSPHRASE | wc -c` -gt 63 ]; then
	echo "Sorry, but the password is either to long or too short. Setup will now exit. Start again."
	exit 9
fi  
echo ""
#if [ -f /etc/sysctl.conf.bak ]; then
#        echo "File /etc/sysctl.conf.bak was found. Most likely you have run the setup already. Your prevous configuration was backed up "
#        echo "in several .bak files. Running setup again would overwrite the backup files. If you want to run setup again, remove /etc/sysctl.conf.bak."
#        exit 1;
#fi

echo "Checking network interfaces..."                                                                   
NONIC=`netstat -i | grep ^wlan | cut -d ' ' -f 1 | wc -l`

if [ ${NONIC} -lt 1 ]; then
        echo "There are no wireless network interfaces... Exiting"                                               
        exit 1
elif [ ${NONIC} -gt 1 ]; then
        echo "You have more than one wlan interface. Please select the interface to become AP: "         
        select INTERFACE in `netstat -i | grep ^wlan | cut -d ' ' -f 1`
        do
                NIC=${INTERFACE}
		break
        done
        exit 1
else
        NIC=`netstat -i | grep ^wlan | cut -d ' ' -f 1`
fi

# Get the WAN adapter port
read -p "Please provide network interface that will be used as WAN connection (i.e. eth0): " WAN 
DNS=`netstat -rn | grep ${WAN} | grep UG | tr -s " " "X" | cut -d "X" -f 2`
echo "DNS will be set to " ${DNS}               								
echo "You can change DNS addresses for the new network in /etc/dhcp/dhcpd.conf"   

echo ""
read -p "Please provide your new AP network (i.e. 192.168.10.X). Remember to put X at the end!!!  " NETWORK 

if [ `echo ${NETWORK} | grep X$ | wc -l` -eq 0 ]; then
	echo "Invalid AP network provided... No X was found at the end of you input. Setup will now exit."
	exit 4
fi	
AP_ADDRESS=`echo ${NETWORK} | tr \"X\" \"1\"`
AP_UPPER_ADDR=`echo ${NETWORK} | tr \"X\" \"9\"`
AP_LOWER_ADDR=`echo ${NETWORK} | tr \"X\" \"2\"`
SUBNET=`echo ${NETWORK} | tr \"X\" \"0\"`


echo "========================================================================"
echo "Your network settings will be:"                                                                   
echo "AP NIC address: ${AP_ADDRESS}  "                                                                  
echo "Subnet:  ${SUBNET} "																				
echo "Addresses assigned by DHCP will be from  ${AP_LOWER_ADDR} to ${AP_UPPER_ADDR}"                    
echo "Netmask: 255.255.255.0"                                                                           
echo "WAN: ${WAN}"																						

read -n 1 -p "Continue? (y/n):" GO
echo ""
        if [ ${GO,,} = "y" ]; then
                sleep 1
        else
				exit 2
        fi


echo "Setting up  $NIC"                                                                                 

echo_start
echo -n "Downloading and installing packages: hostapd isc-dhcp-server iptables."
apt-get -y install hostapd isc-dhcp-server iptables > /dev/null 2>&1
test_for_success $?

echo_start
echo -n "Stopping hostapd"
service hostapd stop > /dev/null 2>&1
test_for_success $?

echo_start
echo -n "Stopping isc-dhcp-server"
service isc-dhcp-server stop > /dev/null 2>&1
test_for_success

echo "${cyan} -- Backups -- ${green}"                                                                                         

if [ -f /etc/dhcp/dhcpd.conf ]; then
        echo_start
        echo -n "Creating Backup /etc/dhcp/dhcpd.conf.bak.${run_time}"                              
        cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak.${run_time}
        test_for_success $?
fi

if [ -f /etc/hostapd/hostapd.conf ]; then
        echo_start
        echo -n "Creating Backup /etc/hostapd/hostapd.conf.bak.${run_time}"   
        cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak.${run_time}
        test_for_success $?
fi

if [ -f /etc/default/isc-dhcp-server ]; then
        echo_start
        echo -n "Creating Backup /etc/default/isc-dhcp-server.bak.${run_time}"
        cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak.${run_time}
        test_for_success $?
fi

if [ -f /etc/sysctl.conf ]; then
        echo_start
        echo -n "Creating Backup /etc/sysctl.conf.bak.${run_time}"
        cp /etc/sysctl.conf /etc/sysctl.conf.bak.${run_time}
        test_for_success $?                                       
fi

if [ -f /etc/network/interfaces ]; then
        echo_start
        echo -n "Creating Backup /etc/network/interfaces.bak.${run_time}"
        cp /etc/network/interfaces /etc/network/interfaces.bak.${run_time}
        test_for_success $?
fi

 
echo "${cyan} -- Setting up Access Point --${green}"                                                                                  

echo_start
echo -n "Configure isc-dhcp-server"
cat <<EOF > /etc/default/isc-dhcp-server
DHCPD_CONF="/etc/dhcp/dhcpd.conf"
INTERFACES="$NIC"
EOF
test_for_success $?

echo_start
echo -n "Configure hostapd"                                                           
echo "DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"" > /etc/default/hostapd
test_for_success $?

echo_start
echo -n "Configure dhcpd"
cat <<EOF > /etc/dhcp/dhcpd.conf
ddns-update-style none;
default-lease-time 86400;
max-lease-time 86400;
subnet $SUBNET netmask 255.255.255.0 {
range $AP_LOWER_ADDR $AP_UPPER_ADDR;
option domain-name-servers 8.8.8.8, 8.8.4.4;
option domain-name "home";
option routers $AP_ADDRESS;
}
EOF
test_for_success $?

echo "${cyan} -- Configure: /etc/hostapd/hostapd.conf --${green}"                                                      
if [ ! -f /etc/hostapd/hostapd.conf ]; then
	touch /etc/hostapd/hostapd.conf
fi

echo_start
echo -n "Configure hostapd"
cat <<EOF > /etc/hostapd/hostapd.conf
interface=$NIC
ssid=$AP_SSID
channel=$AP_CHANNEL
# WPA and WPA2 configuration
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$AP_WPA_PASSPHRASE
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
# Hardware configuration
EOF
test_for_success $?

#check that USB wifi device is plugged in and seen
echo_start
echo -n "The RTL8188CUS device has been successfully located."
if [[ -n $(lsusb | grep RTL8188CUS) ]]; then
  echo "driver=rtl871xdrv"                         >> /etc/hostapd/hostapd.conf
  echo "ieee80211n=1"                              >> /etc/hostapd/hostapd.conf
  echo "device_name=RTL8192CU"                     >> /etc/hostapd/hostapd.conf
  echo "manufacturer=Realtek"                      >> /etc/hostapd/hostapd.conf

  echo -n " - Download and install: special hostapd version"                                           
  wget "http://raspberry-at-home.com/files/hostapd.gz"                                           
     gzip -d hostapd.gz
     chmod 755 hostapd
     cp hostapd /usr/sbin/

  echo_success
  
else
  echo "driver=nl80211"                            >> /etc/hostapd/hostapd.conf
  echo_failure
  echo "This Utility is made specfifically for use with WiFi modules containing the RTL8188CUS chipset"
  exit 1
fi

echo "hw_mode=g"                                         >> /etc/hostapd/hostapd.conf

echo "Configure: /etc/sysctl.conf"                                                               
echo "net.ipv4.ip_forward=1"                             >> /etc/sysctl.conf 

echo "${cyan} -- Configure: iptables -- ${green}"                                                                       
iptables -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE
iptables -A FORWARD -i ${WAN} -o ${NIC} -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ${NIC} -o ${WAN} -j ACCEPT
sh -c "iptables-save > /etc/iptables.ipv4.nat"

echo_start
echo -n "Configure Network Interface conf [/etc/network/interfaces]"
cat <<EOF > /etc/network/interfaces
auto $NIC
allow-hotplug $NIC
iface $NIC inet static
        address $AP_ADDRESS
        netmask 255.255.255.0
        up iptables-restore < /etc/iptables.ipv4.nat
EOF
test_for_success $?

if [ ${CHIPSET,,} = "yes" ]; then 
	echo "Download and install: special hostapd version"                                           
	wget "http://raspberry-at-home.com/files/hostapd.gz"                                           
     gzip -d hostapd.gz
     chmod 755 hostapd
     cp hostapd /usr/sbin/
fi

ifdown ${NIC}                                                                                    
ifup ${NIC}                                                                                      
service hostapd start                                                                          
service isc-dhcp-server start                                                                  

echo ""                                                                                        
read -n 1 -p "Would you like to start AP on boot? (y/n): " startup_answer                       
echo ""
if [ ${startup_answer,,} = "y" ]; then
        echo "${cyan} -- Configure: startup --${green}"                                                              
        update-rc.d hostapd enable                                                             
        update-rc.d isc-dhcp-server enable                                                     

echo_start
echo -n "configure rc.d to restart services after boot"
cat <<EOF > /etc/rc.local
#!/bin/sh -e
# Print the IP address
_IP=$(hostname -I) || true
if [ "$_IP" ]; then
  printf "My IP address is %s\n" "$_IP"
fi

sudo service hostapd stop
sudo service isc-dhcp-server stop
sudo ifdown wlan0
sudo ifup wlan0
sudo service hostapd restart
sudo service isc-dhcp-server restart

exit 0
EOF
test_for_success $?

else
        echo "In case you change your mind, please run below commands if you want AP to start on boot:"                       
        echo "update-rc.d hostapd enable"                                                      
        echo "update-rc.d isc-dhcp-server enable"                                              
fi



echo ""                                                                                        
echo "Do not worry if you see something like: [FAIL] Starting ISC DHCP server above... this is normal :)"               
echo ""                                                                                        
echo "REMEMBER TO RESTART YOUR RASPBERRY PI!!!"                                                
echo ""                                                                                        
echo "Enjoy and visit raspberry-at-home.com"                                                   

exit 0
