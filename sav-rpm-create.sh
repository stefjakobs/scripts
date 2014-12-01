#!/bin/bash

# Copyright (c) 2014 Stefan Jakobs <project AT localside.net>
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

SOURCES=/usr/src/packages/SOURCES/
SPECS=/usr/src/packages/SPECS/
RPMS=/usr/src/packages/RPMS/x86_64
SAV_VERSION="" #4.83
SAV_RELEASE=""
SAVDI_VERSION="" #4.83
SAVDI_RELEASE=""
SOPHIE_VERSION="" #3.06Beta
SOPHIE_RELEASE=""
HOME=/opt/mailrelay-setup/av-scanners/

function usage {
   echo "${0##*/} [-a <sav version>] [-b <sav release>]"
   echo "                  [-A <sav9 version>] [-B <sav9 release]"
   echo "                  [-s <sophie version>] [-r <sophie release>]"
   echo "                  [-S <savdi version>] [-R <savdi release>]"
   exit 1
}

function build {
   local package=$1
   local user=''
   if [ -n "$2" ]; then
      user="$2"
   fi
   test -d $SPECS || { echo "can not change to directory $SPECS"; exit 1; }
   pushd $SPECS
   echo "start to build $package:"
   if [[ "$user" == 'root' ]]; then
      rpmbuild -bb ${package}.spec
   else
      sudo -H -u vscan rpmbuild -bb ${package}.spec
   fi
   local status=$?
   popd
   return $status
}

while getopts ":a:b:A:B:r:s:S:R:" opt; do
  case $opt in
    a)
      SAV_VERSION="$OPTARG"
      ;;
    b)
      SAV_RELEASE="$OPTARG"
      ;;
    A)
      SAV9_VERSION="$OPTARG"
      ;;
    B)
      SAV9_RELEASE="$OPTARG"
      ;;
    r)
      SOPHIE_RELEASE="$OPTARG"
      ;;
    s)
      SOPHIE_VERSION="$OPTARG"
      ;;
    S)
      SAVDI_VERSION="$OPTARG"
      ;;
    R)
      SAVDI_RELEASE="$OPTARG"
      ;;
    \?)
      usage
      ;;
    :)
      usage
      ;;
  esac
done

# print usage if no version is named
if [ -z "$SOPHIE_VERSION" ] && [ -z "$SAV_VERSION" ] && \
   [ -z "$SAVDI_VERSION" ] && [ -z "$SAV9_VERSION" ]; then
   usage 
fi

if [ -n "$SAV_VERSION" ]; then
   # build sav
   for file in linux.amd64.v${SAV_VERSION}_glibc.2.3.tar.Z sophos-av.spec; do
      test -r $file || { echo "cannot find $file!"; exit 1; }
   done
   cp linux.amd64.v${SAV_VERSION}_glibc.2.3.tar.Z $SOURCES
   chmod 644 ${SOURCES}/linux.amd64.v${SAV_VERSION}_glibc.2.3.tar.Z
   cp sophos-av.spec $SPECS
   chmod 644 ${SPECS}/sophos-av.spec
   sed -i "s/^Version:.*$/Version:   ${SAV_VERSION}/" $SPECS/sophos-av.spec
   if [ -n "${SAV_RELEASE}" ]; then
      sed -i "s/^Release:.*$/Release:   ${SAV_RELEASE}/" $SPECS/sophos-av.spec
   fi
   build sophos-av
   sav_status=$?
   echo
fi

if [ -n "$SAV9_VERSION" ]; then
   # build sav
   for file in sav-linux-${SAV9_VERSION}-i386.tgz sav-protect.init sav-rms.init sav-web.init sophos-av9.spec; do
      test -r $file || { echo "cannot find $file!"; exit 1; }
   done
   cp sav-linux-${SAV9_VERSION}-i386.tgz sav-protect.init sav-rms.init sav-web.init $SOURCES
   chmod 644 ${SOURCES}/sav-linux-${SAV9_VERSION}-i386.tgz
   chmod 644 ${SOURCES}/sav-protect.init
   chmod 644 ${SOURCES}/sav-rms.init
   chmod 644 ${SOURCES}/sav-web.init
   cp sophos-av9.spec $SPECS
   chmod 644 ${SPECS}/sophos-av9.spec
   sed -i "s/^Version:.*$/Version:   ${SAV9_VERSION}/" $SPECS/sophos-av9.spec
   if [ -n "${SAV9_RELEASE}" ]; then
      sed -i "s/^Release:.*$/Release:   ${SAV9_RELEASE}/" $SPECS/sophos-av9.spec
   fi
   build sophos-av9 root
   sav9_status=$?
   echo
fi

if [ -n "$SOPHIE_VERSION" ]; then
   # build sophie
   for file in sophie.init sophie-${SOPHIE_VERSION}.tar.bz2 sophie.spec; do
      test -r $file || { echo "cannot find $file!"; exit 1; }
   done
   cp sophie.init sophie-${SOPHIE_VERSION}.tar.bz2 $SOURCES
   chmod 644 ${SOURCES}/sophie.init ${SOURCES}/sophie-${SOPHIE_VERSION}.tar.bz2
   cp sophie.spec $SPECS
   chmod 644 ${SPECS}/sophie.spec
   sed -i "s/^Version:.*$/Version:   ${SOPHIE_VERSION}/" $SPECS/sophie.spec
   if [ -n "${SOPHIE_RELEASE}" ]; then
      sed -i "s/^Release:.*$/Release:   ${SOPHIE_RELEASE}/" $SPECS/sophie.spec
   fi
   build sophie
   sophie_status=$?
fi

if [ -n "$SAVDI_VERSION" ]; then
   # build savdi
   for file in savdi.init savdi-${SAVDI_VERSION}-linux-64bit.tar savdi.spec; do
      test -r $file || { echo "cannot find $file!"; exit 1; }
   done
   cp savdi.init savdi-${SAVDI_VERSION}-linux-64bit.tar $SOURCES
   chmod 644 ${SOURCES}/savdi.init ${SOURCES}/savdi-${SAVDI_VERSION}-linux-64bit.tar
   cp savdi.spec $SPECS
   chmod 644 ${SPECS}/savdi.spec
   sed -i "s/^Version:.*$/Version:   ${SAVDI_VERSION}/" $SPECS/savdi.spec
   if [ -n "${SAVDI_RELEASE}" ]; then
      sed -i "s/^Release:.*$/Release:   ${SAVDI_RELEASE}/" $SPECS/savdi.spec
   fi
   build savdi
   savdi_status=$?
fi


# print results and move packages
echo
if [ -n "$SOPHIE_VERSION" ]; then
   test -d $RPMS || echo "can not find RPM directory $RPMS"
   if [ $sophie_status -eq 0 ]; then
      mv $RPMS/sophie-${SOPHIE_VERSION}*.rpm $HOME/
      echo "sophie build was successful"
      ## cleanup
      test -e ${SOURCES}/sophie-${SOPHIE_VERSION}.tar.bz2 && rm ${SOURCES}/sophie-${SOPHIE_VERSION}.tar.bz2
      test -e ${SOURCES}/sophie.init && rm ${SOURCES}/sophie.init
   else
      echo "sophie build failed"
   fi
fi
if [ -n "$SAV_VERSION" ]; then
   test -d $RPMS || echo "can not find RPM directory $RPMS"
   if [ $sav_status -eq 0 ]; then
      mv $RPMS/sophos-av-${SAV_VERSION}*.rpm $HOME/
      test -e ${SOURCES}/linux.amd64.v${SAV_VERSION}_glibc.2.3.tar.Z && rm ${SOURCES}/linux.amd64.v${SAV_VERSION}_glibc.2.3.tar.Z
      echo "sophos-av build was successful"
   else
      echo "sophos-av build failed"
   fi
fi
if [ -n "$SAV9_VERSION" ]; then
   test -d $RPMS || echo "can not find RPM directory $RPMS"
   if [ $sav9_status -eq 0 ]; then
      mv $RPMS/sophos-av-${SAV9_VERSION}*.rpm $HOME/
      test -e ${SOURCES}/sav-linux-${SAV9_VERSION}-i386.tgz && rm ${SOURCES}/sav-linux-${SAV9_VERSION}-i386.tgz
      test -e ${SOURCES}/sav-protect.init && rm ${SOURCES}/sav-protect.init
      test -e ${SOURCES}/sav-rms.init && rm ${SOURCES}/sav-rms.init
      test -e ${SOURCES}/sav-web.init && rm ${SOURCES}/sav-web.init
      echo "sophos-av build was successful"
   else
      echo "sophos-av build failed"
   fi
fi
if [ -n "$SAVDI_VERSION" ]; then
   test -d $RPMS || echo "can not find RPM directory $RPMS"
   if [ $savdi_status -eq 0 ]; then
      mv $RPMS/savdi-${SAVDI_VERSION}*.rpm $HOME/
      echo "savdi build was successful"
      ## cleanup
      test -e ${SOURCES}/savdi-${SAVDI_VERSION}-linux-64bit.tar && rm ${SOURCES}/savdi-${SAVDI_VERSION}-linux-64bit.tar
      test -e ${SOURCES}/savdi.init && rm ${SOURCES}/savdi.init
   else
      echo "savdi build failed"
   fi
fi

