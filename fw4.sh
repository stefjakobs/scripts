#!/bin/sh

# Veranlasse den kernel alle Ping-Anfragen zu ignorieren:
#sysctl -w net.ipv4.icmp_echo_ignore_all=1

# Veranlasse den kernel auf Ping-Anfragen zu reagieren:
#sysctl -w net.ipv4.icmp_echo_ignore_all=0

# Begrenze die Antwortrate auf Ping-Anfragen:
sysctl -w net.ipv4.icmp_echoreply_rate=10

