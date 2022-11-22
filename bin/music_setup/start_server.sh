#!/bin/bash
echo "Paste listening ip:"
pactl load-module module-native-protocol-tcp listen=$(read v; echo $v)
sleep infinity
echo "Cleaning up"
pactl unload-module module-native-protocol-tcp
