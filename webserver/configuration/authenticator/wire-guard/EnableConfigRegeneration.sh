#!/bin/sh
###########################################################################################################
# Description: If a user has lost their wireguard configuration and QR code for some reason you might want
# to allow them to regenerate a new QRCode and client config and that is done simply by running
# ${BUILD_HOME}/helpers/server/ExecuteOnRemoteMachine.sh "enable-wireguard-regeneration" 
#which will call this script which does the work for us
# Once the email address is removed from the PROCESSED_EMAILS file it means that the QRCode and Client Config
# can be regenrated and installed into the wireguard client. 
# This needs to be run on all authenticator machines so if you have multiple authenticators you will need to run
# this for each one to ensure that the user can successfully regenerate a wireguard config and QR code
# Author : Peter Winter
# Date: 17/05/2017
######################################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################################################
#######################################################################################################
#set -x


email_address="${1}"

/bin/sed -i "/${email_address}/d" ${HOME}/runtime/wire-guard/PROCESSED_EMAILS
