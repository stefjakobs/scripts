#!/bin/bash

# Copyright (c) 2014 Stefan Jakobs <projects AT localside.net>
#####################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
######################################################################

# TODO
# create: pkg-debian/DEBIAN/control:
# Package: zarafa-outlook-client
# Version: 7.1.11-46779
# Architecture: all
# Essential: no
# Section: mail
# Priority: optional
# Depends: python (>=2.3)
# Maintainer: Stefan Jakobs
# Installed-Size: 14108
# Description: Zarafa Outlook Client
#
# create: pkg-debian/DEBIAN/

# TODO: set permissions of pkg-debian/var/lib/zarafa/client/

function usage() {
   echo "$0 <path/to/zarafaclient-maj.min.patch-release.msi>"
   echo
   exit 1
}

if [ -z "$1" ]; then
  usage ;
elif [ ! -r "$1" ]; then
  echo "error: can not access $1"
  exit 1
fi
msi="$1"

filename="${msi##*/}"
version="$(echo $filename | cut -d- -f2)"
release="$(echo $filename | cut -d- -f3 | cut -d. -f1)"
size="$(du $msi | cut -f1)"

echo "create deb package: $filename"
echo "   version: $version"
echo "   release: $release"
echo "   size:    $size"
echo

if [ -d pkg-debian/var/lib/zarafa/client/ ]; then
   rm pkg-debian/var/lib/zarafa/client/*
else
   mkdir -p pkg-debian/var/lib/zarafa/client
fi
cp "$msi" pkg-debian/var/lib/zarafa/client/

find . -type f ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -printf '%P ' | xargs md5sum > pkg-debian/DEBIAN/md5sums
sed -i "s/^\(Version: \).*$/\1${version}-${release}/" pkg-debian/DEBIAN/control
sed -i "s/^\(Installed-Size: \).*$/\1${size}/" pkg-debian/DEBIAN/control
#version="$(ls -1 pkg-debian/var/lib/zarafa/client/*.msi | cut -d- -f3-4 | cut -d. -f1-3)"

dpkg -b pkg-debian/ zarafa-outlook-client_${version}-${release}_amd64.deb
