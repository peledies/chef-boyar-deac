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

lcd_show () {
  sudo /opt/LCD-show/LCD$1-show
}

lcd_show_hdmi () {
  sudo /opt/LCD-show/LCD-hdmi
}

_lcd_show_menu () {
  clear
  echo "${cyan}  LCD-show menu"
  echo " ===================${normal}"
  echo "${magenta}  1 ${default}- Install LCD-show"
  echo "${magenta}  2 ${default}- 3.2\" LCD output"
  echo "${magenta}  3 ${default}- 3.5\" LCD output"
  echo "${magenta}  4 ${default}- 4\" LCD output"
  echo "${magenta}  5 ${default}- 5\" LCD output"
  echo "${magenta}  6 ${default}- LCD-show - Switch to HDMI output"

  while true; do
    read -p "${cyan} Select an option from the list above: ${gold}" answer
    case $answer in
      1 ) clear; install_LCD_show; break;;
      2 ) clear; lcd_show 32; break;;
      3 ) clear; lcd_show 35; break;;
      4 ) clear; lcd_show 4; break;;
      5 ) clear; lcd_show 5; break;;
      6 ) clear; lcd_show_hdmi; break;;
      * ) echo "Please select an option.";;
    esac
  done
}

_lcd_show_menu