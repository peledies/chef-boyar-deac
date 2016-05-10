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
  echo -n "${gold}Cleaning up install files${default}"
  rm /opt/LCD-show-151102.tar.gz > /dev/null 2>&1
  test_for_success $?
}

switch_to_LCD () {
  sudo /opt/LCD-show/LCD35-show
}

switch_to_HDMI () {
  sudo /opt/LCD-show/LCD-hdmi
}