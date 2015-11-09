#!/bin/sh

# Veranlasse den kernel alle Ping-Anfragen zu ignorieren:
#sysctl -w net.ipv4.icmp_echo_ignore_all=1

# Veranlasse den kernel auf Ping-Anfragen zu reagieren:
#sysctl -w net.ipv4.icmp_echo_ignore_all=0

# Begrenze die Antwortrate auf Ping-Anfragen:
sysctl -w net.ipv4.icmp_echoreply_rate=10

#!/bin/sh

# Alle bestehenden Regeln löschen
iptables -F
iptables -X

# Zugriff über das Loopback‐Device erlauben
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Zugriff aus dem lokalen Subnetz ebenfalls erlauben
iptables -A INPUT -i eth0 -j ACCEPT
iptables -A OUTPUT -o eth0 -j ACCEPT

# Source‐Routing‐Pakete gefaehrlich, nicht zugelassen
iptables -A INPUT -m rt --rt‐type 0 -j DROP
iptables -A FORWARD -m rt --rt‐type 0 -j DROP
iptables -A OUTPUT -m rt --rt‐type 0 -j DROP

# Verbindungslokale Adressen erlaubt
iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -s 127.0.0.0/8 -j ACCEPT

# Multicast‐Pakete zulassen
iptables -A INPUT -s 224.0.0.0/4 -j ACCEPT
iptables -A OUTPUT -s 224.0.0.0/4 -j ACCEPT

# ICMP‐Protokoll zur Fehlersuche zulassen
iptables -I INPUT -p icmp -j ACCEPT
iptables -I OUTPUT -p icmp -j ACCEPT
iptables -I FORWARD -p icmp -j ACCEPT

iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Block 6to4 per protocol
iptables -A INPUT -p 41 -j DROP

# Block 6to4 IPv4 Anycast
iptables -A INPUT -d 192.88.99.1 -j DROP
iptables -A INPUT -s 192.88.99.1 -j DROP

# Alles andere ist verboten
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

