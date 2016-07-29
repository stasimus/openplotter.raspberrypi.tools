#!/bin/bash

DEVICE=${1:-u-blox}

mkfifo /var/tmp/fifousb1
mkfifo /var/tmp/fifousb2
mkfifo /var/tmp/fifousb3

for sysdevpath in $(find /sys/bus/usb/devices/usb*/ -name dev); do
    (
        syspath="${sysdevpath%/dev}"
        devname="$(udevadm info -q name -p $syspath)"
        [[ "$devname" == "bus/"* ]] && continue
        eval "$(udevadm info -q property --export -p $syspath)"
        [[ -z "$ID_SERIAL" ]] && continue
        echo "/dev/$devname - $ID_SERIAL" > /var/tmp/fifousb3 &
        
        if [[ $ID_SERIAL =~ $DEVICE ]] 
        then
        	echo "/dev/$devname" > /var/tmp/fifousb1 &
        	echo "$ID_SERIAL" > /var/tmp/fifousb2 &
        fi        	
    )
done 

DEV_DEVICE_PATH=`cat /var/tmp/fifousb1`
DEVICE_FULL_NAME=`cat /var/tmp/fifousb2`

rm /var/tmp/fifousb1 /var/tmp/fifousb2

if [[ -z $DEV_DEVICE_PATH || -z $DEVICE_FULL_NAME ]]
then 
	echo "$DEVICE not found"
	exit 127
else
	echo "Found $DEV_DEVICE_PATH - $DEVICE_FULL_NAME"
fi

sleep 3s

echo "==================================================="
echo "Expecting $DEVICE to be mounted to $DEV_DEVICE_PATH"

USB_DEVICE=$(sudo lsusb | grep -i $DEVICE)

if [[ -z "$USB_DEVICE" ]]
then
	echo "Not found $DEVICE"
else
	echo "Found $DEVICE here $USB_DEVICE"
fi
echo "==================================================="

sleep 3s

sudo killall gpsd

( cmdpid=$BASHPID; (sleep 15; kill $cmdpid 2>/dev/null) & exec gpsmon $DEV_DEVICE_PATH )

sudo gpsd $DEV_DEVICE_PATH -F /var/run/gpsd.sock

( cmdpid2=$BASHPID; (sleep 15; kill $cmdpid2 2>/dev/null) & exec cgps -s )

exit 0
