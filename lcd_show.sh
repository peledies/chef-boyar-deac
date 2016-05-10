install_LCD_show () {
  echo_start
  echo -n "${gold}Downloading LCD-show${default}"
  wget -O /opt/LCD-show-151102.tar.gz http://www.spotpear.com/download/diver24-5/LCD-show-151102.tar.gz  > /dev/null 2>&1
  test_for_success $?

  echo_start
  echo -n "${gold}Unziping LCD-show to /opt/LCD-show${default}"
  tar xvf /opt/LCD-show-151102.tar.gz --directory /opt > /dev/null 2>&1
  test_for_success $?

  echo_start
  echo -n "${gold}Cleaning up downloaded files${default}"
  rm /opt/LCD-show-151102.tar.gz > /dev/null 2>&1
  test_for_success $?

  echo_start
  echo -n "${gold}Creating absolute path variable in LCD-show scripts${default}"
  sed -i '1s/^/DIR=$(dirname $0)\n/' <<< ls /opt/LCD-show/LCD* > /dev/null 2>&1
  test_for_success $?

  echo_start
  echo -n "${gold}Updating LCD-show scripts to use absolute path variable${default}"
  sed -i 's/\.\//$DIR\//g' <<< ls /opt/LCD-show/LCD* > /dev/null 2>&1
  test_for_success $?  
}

switch_to_LCD () {
  sudo /opt/LCD-show/LCD35-show
}

switch_to_HDMI () {
  sudo /opt/LCD-show/LCD-hdmi
}