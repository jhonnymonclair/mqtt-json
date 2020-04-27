#!/bin/bash
###################################################
##
##  mqtt-json.sh
##  Shell script to publish Dump1090 data via a Mosquitto broker
##
###################################################
#
# Configuration variables
#
RPINAME=`uname -n`

# For a list of free public servers, check https://github.com/mqtt/mqtt.github.io/wiki/public_brokers
# MQTT broker
MQTTHOST="mqtt.eclipse.org"

# Change this to become something unique, so that you get your own topic path
#
MQTTPREFIX="jhonnymonclair"

# Descriptive topic, can be any string
#
TOPIC="ads-b"

nowold=0
messagesold=0

###################################################
##
## Wiedehopf's routine to scan for possible paths
##
###################################################
#
# List all paths, IN PREFERRED ORDER, separated by a SPACE
JSON_PATHS=("/run/adsbexchange-feed" "/run/readsb" "/run/dump1090-fa" "/run/dump1090-mutability" "/run/dump1090" )

JSON_DIR=""

# Do this a few times, in case we're still booting up (wait a bit between checks)
CHECK_LOOP=0
while [ "x$JSON_DIR" == "x" ]; do
        # Check the paths IN ORDER, preferring the first one we find
        for i in ${!JSON_PATHS[@]}; do
                CHECK=${JSON_PATHS[$i]}

                if [ -d $CHECK ]; then
                        JSON_DIR=$CHECK
                        break
                fi
        done

        # Couldn't find any of them...
        if [ "x$JSON_DIR" == "x" ]; then
                CHECK_LOOP=$(( CHECK_LOOP + 1 ))

                if [ $CHECK_LOOP -gt 4 ]; then
                        # Give up after 4 attempts
                        exit 10
                fi
                # Waiting a bit before next check
                sleep 20
        fi
done

while true
 do
        NOW=`cat $JSON_DIR/aircraft.json | jq '.now' | awk '{print int($0)}'`
        MESSAGES=`cat $JSON_DIR/aircraft.json | jq '.messages'`
        nowdelta=`expr $NOW - $nowold`
        messagesdelta=`expr $MESSAGES - $messagesold`
        RATE=`echo "$messagesdelta $nowdelta /p" | dc`
        AC_POS=`cat $JSON_DIR/aircraft.json | jq '[.aircraft[] | select(.seen_pos)] | length'`
        AC_TOT=`cat $JSON_DIR/aircraft.json | jq '[.aircraft[] | select(.seen < 60)] | length'`
        DUMP=`echo "Aircraft:$AC_TOT\nPosition:$AC_POS\nMsg/s:$RATE"`
        #echo $DUMP
        nowold=$NOW
        messagesold=$MESSAGES
        ADSBX="0"
        if pgrep feed-adsbx > /dev/null; then
                M=`pgrep -a -u adsbexchange python | grep -c 'mlat-client'`
                if [ $M -gt 0 ]; then
                        ADSBX="1"
                fi
        fi
        FR24="0"
        if pgrep fr24feed > /dev/null; then
                FR24="1"
        fi
        FA="0"
        if pgrep -f /usr/bin/piaware > /dev/null; then
                if pgrep -f /usr/lib/piaware/helpers/faup1090 > /dev/null; then
                        if pgrep -f /usr/lib/piaware/helpers/fa-mlat-client > /dev/null; then
                                FA="1"
                        fi
                fi
        fi
        PF="0"
        if pgrep pfclient > /dev/null; then
                PF="1"
        fi
        RBOX="0"
        if pgrep rbfeeder > /dev/null; then
                RBOX="1"
        fi
        OSKY="0"
        if pgrep openskyd-dump1090 > /dev/null; then
                OSKY="1"
        fi
        TEMP=`/opt/vc/bin/vcgencmd measure_temp`
        IPEXT=`curl -s https://api.ipify.org`
        IPLOC=`hostname -I`
        MORE=`echo "$TEMP\n$IPEXT\n$IPLOC"`
        /usr/bin/mosquitto_pub -h $MQTTHOST -t "$MQTTPREFIX/$RPINAME/$TOPIC" -m "{ \"dump\" : \"$DUMP\", \"adsbx\" : \"$ADSBX\", \"fr24\" : \"$FR24\", \"fa\" : \"$FA\", \"pf\" : \"$PF\", \"rbox\" : \"$RBOX\", \"osky\" : \"$OSKY\", \"more\" : \"$MORE\" }"
        sleep 5
 done
