#!/bin/bash

# Kill previous processes in case you reload the script
killall -q waybar swaybg swaync walker

# Start the idle manager (e.g. your adapted hypridle)
# uwsm-app -- hypridle &

# uwsm-app -- mako &

# Start the status bar
# uwsm-app -- waybar &

# Start the wallpaper
# uwsm-app -- swaybg -i ~/.config/omarchy/current/background -m fill &

# uwsm-app -- /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

# Start the notification daemon
# swaync &

# Start Walker's background service
# uwsm-app -- walker --gapplication-service &

# Slow app launch fix -- set systemd vars
# uwsm-app -- systemctl --user import-environment $(env | cut -d'=' -f 1) &
# uwsm-app -- dbus-update-activation-environment --systemd --all &
