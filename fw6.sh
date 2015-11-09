#!/bin/sh

# Alle bestehenden Regeln löschen
ip6tables -F
ip6tables -X

# Zugriff über das Loopback‐Device erlauben
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT

# Uneingeschraenkter Zugriff auf den IPv6‐Tunnel vom Router aus
#ip6tables -A OUTPUT -o sixxs -j ACCEPT

# Zugriff aus dem lokalen Subnetz ebenfalls erlauben
ip6tables -A INPUT -i eth0 -j ACCEPT
ip6tables -A OUTPUT -o eth0 -j ACCEPT

# Source‐Routing‐Pakete gefaehrlich, nicht zugelassen
ip6tables -A INPUT -m rt --rt‐type 0 -j DROP
ip6tables -A FORWARD -m rt --rt‐type 0 -j DROP
ip6tables -A OUTPUT -m rt --rt‐type 0 -j DROP

# Verbindungslokale Adressen erlaubt
ip6tables -A INPUT -s fe80::/10 -j ACCEPT
ip6tables -A OUTPUT -s fe80::/10 -j ACCEPT

# Multicast‐Pakete zulassen
ip6tables -A INPUT -s ff00::/8 -j ACCEPT
ip6tables -A OUTPUT -s ff00::/8 -j ACCEPT

# ICMP‐Protokoll zur Fehlersuche zulassen
ip6tables -I INPUT -p icmpv6 -j ACCEPT
ip6tables -I OUTPUT -p icmpv6 -j ACCEPT
ip6tables -I FORWARD -p icmpv6 -j ACCEPT

# Uneingeschraenkter Zugriff auf den IPv6‐Tunnel aus dem Subnetz
#ip6tables -A FORWARD -m state --state NEW -i eth0 -o sixxs -s 2a01:198:514::/48 -j ACCEPT
ip6tables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Ueber den Tunnel eingehende SSH‐Verbindungen zulassen
#ip6tables -A FORWARD -i sixxs -p tcp ‐d 2a01:198:514::1 ‐‐dport 22 -j ACCEPT

# Ueber den Tunnel eingehenden Bittorrent‐Traffic erlauben
#ip6tables -A FORWARD -i sixxs -p tcp ‐d 2a01:198:514::1 ‐‐dport 33600:33604 -j ACCEPT

# Block 6to4 prefix
ip6tables -A OUTPUT -d 2002::/16 -j DROP

# Block Toredo
ip6tables -A OUTPUT -d 2001::/32 -j DROP

# Alles andere ist verboten
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP

