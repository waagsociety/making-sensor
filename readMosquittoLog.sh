echo $(cat /var/log/mosquitto/mosquitto.log | sed "s/\(^[0-9][0-9]*\):\(.*\)/echo \"\$\(date -d @\1\): \2\"/g") | sed 's/" echo/"\necho/g' | while read line;do eval $line;done
