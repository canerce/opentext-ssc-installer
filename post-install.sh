#!/bin/bash
#=====================================================================================================================
## Author: canerce
#=====================================================================================================================
## Before running script:
## chmod +x setup.sh
#=====================================================================================================================
## Usage:
## sudo ./setup.sh          :   Install OpenText Static Application Security Testing (Fortify)
## sudo ./setup.sh worker   :   Install OpenText Static Application Security Testing (Fortify) 
##                               to use as a OpenText Fortify ScanCentral SAST Sensor
#=====================================================================================================================

set -euo pipefail

SCA_NAME="ssc"
SCA_DIR="/opt/${SCA_NAME}"
serviceContext_path="${SCA_DIR}/webapps/ROOT/WEB-INF/internal/serviceContext.xml"
TOKEN_NAME="scanCentralCtrlToken"
NEW_VALUE="365"

sudo apt install xmlstarlet -y -qq 2>/dev/null >/dev/null;
echo "✅ xmlstarlet installed"
sudo systemctl stop $SCA_NAME
sudo xmlstarlet ed -L -N x="http://www.springframework.org/schema/beans" -u "//x:bean[@id='$TOKEN_NAME']/x:property[@name='maxDaysToLive']/@value" -v "$NEW_VALUE" "$serviceContext_path"
echo "✅ scanCentralCtrlToken duration changed"
sudo systemctl start $SCA_NAME
echo "✅ Done"