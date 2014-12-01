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

ZMI="https://sa.zmi.at/sa-update-german/GPG.KEY"
ZMI_ID="40F74481"

TMPDIR="$(mktemp -d)"

pushd $TMPDIR
wget "$ZMI"
if sudo sa-update --import GPG.KEY; then
   rm GPG.KEY
else
   echo "error: ZMI key import failed!"
fi



rmdir $TMPDIR
