sudo apt-get install gpsd gpsd-clients python-gps

#show the cgps terminal to confirm functionality
#cgps

#clone the py_spy.py script to the home directory
git clone https://github.com/peledies/pyspy.git ~/pyspy

touch ~/pyspy/track.json

echo "[]" > ~/pyspy/track.json

# enable the py_spy script to run on boot

#write out current crontab
crontab -l > ohmycron
#echo new cron into cron file
echo "@reboot /usr/bin/python /home/pi/pyspy/pyspy.py 2>&1"  >> ohmycron
#install new cron file
crontab ohmycron
rm ohmycron