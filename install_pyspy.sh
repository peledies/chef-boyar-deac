info_box "Installing PySpy"

echo_start
echo -n "${gold}Downloading gps driver and utilities${default}"
sudo apt-get install gpsd gpsd-clients python-gps > /dev/null 2>&1
test_for_success $?

if [ -d /home/pi/pyspy ]; then
  echo_start
  echo -n "${gold}Removing existing /home/pi/pyspy directory${default}"
  rm -rf /home/pi/pyspy
  test_for_success $?                                  
fi

#clone the py_spy.py script to the home directory
echo_start
echo -n "${gold}Cloning python gps script into ~/pyspy${default}"
git clone https://github.com/peledies/pyspy.git /home/pi/pyspy > /dev/null 2>&1
test_for_success $?

echo_start
echo -n "${gold}Creating ~/pypsy/track.json${default}"
touch /home/pi/pyspy/track.json > /dev/null 2>&1
test_for_success $?

echo_start
echo -n "${gold}Modifying permissions of pyspy${default}"
sudo chown -R pi:pi /home/pi/pyspy > /dev/null 2>&1
sudo chmod 755 -R /home/pi/pyspy > /dev/null 2>&1
test_for_success $?

if grep -Fxq "@reboot gpspipe -w | grep lat >> /home/pi/pyspy/track.json 2>&1" /var/spool/cron/crontabs/root
then
  echo_start
  echo -n "${gold}Skipping crontab addition, line exists${default}"
  test_for_success $?
else
  echo_start
  echo -n "${gold}Adding line to root crontab to start logging data on boot${default}"
  #write out current crontab
  crontab -l > ohmycron
  #echo new cron into cron file
  echo "@reboot gpspipe -w | grep lat >> /home/pi/pyspy/track.json 2>&1"  >> ohmycron
  #install new cron file
  crontab ohmycron
  rm ohmycron
  test_for_success $?
fi



echo ""
echo -n "${gold}You can type ${cyan}cgps${gold} to get an instant view of the gps data${default}"
echo ""