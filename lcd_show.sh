install_LCD_show () {
  echo_start
  echo -n "${gold}Downloading LCD-show${green}"
  wget -O ~/LCD-show-151102.tar.gz http://www.spotpear.com/download/diver24-5/LCD-show-151102.tar.gz
  test_for_success $?

  echo_start
  echo -n "${gold}Unziping LCD-show${green}"
  tar xvf ~/LCD-show-151102.tar.gz
  test_for_success $?
}

switch_to_LCD () {
  cd ~/LCD-show
  sudo ./LCD35-show
  cd .
}

switch_to_HDMI () {
  cd ~/LCD-show
  sudo ./HDMI-show
  cd .
}