#!/bin/bash
#=====================================================================================================================
## Author: canerce
#=====================================================================================================================
## Before running script:
## chmod +x setup.sh
#=====================================================================================================================
## Usage:
## sudo ./setup.sh ssc      :   Install only OpenText Application Security (Fortify Software Security Center)
## sudo ./setup.sh scc      :   Install only OpenText Fortify ScanCentral SAST
## sudo ./setup.sh all      :   Install OpenText Application Security (Fortify Software Security Center)
##                              and OpenText Fortify ScanCentral SAST
#=====================================================================================================================

set -euo pipefail
# Setup Folders
BUNDLE_FOLDER="bundles"
CERT_FOLDER="cert"
ARCHIVE_FOLDER="download"
ENV_FOLDER="env"

# Files
LICENSE_FILE="fortify.license"
PWTOOL_KEYS_FILE="pwtool.key"
PFX_FILE="fortify.pfx"
PFX_FILE_PASSWORD="changeit"

SSC_CONNECTOR_PORT="443"
SCC_CONNECTOR_PORT="4443"
STOREPASS="changeit"
MAX_HEAP="12G"

# Destination Folders
FORTIFY_HOME="/data/fortify"
SERVICE_SSC="ssc"
TOMCAT_SSC_DIR="/opt/$SERVICE_SSC"
SERVICE_SCC="scancentral"
TOMCAT_SCC_DIR="/opt/$SERVICE_SCC"

# Property Definitions
SSC_URL="https://fortify.example.local"
SCANCENTRAL_URL="https://scancentral.example.local/scancentral-ctrl"
WORKER_AUTH_TOKEN="67dcd21e-0414-401d-bf04-4aa54da3e0b4"
CLIENT_AUTH_TOKEN="67dcd21e-0414-401d-bf04-4aa54da3e0b4"
SSC_SCANCENTRAL_CTRL_SECRET="67dcd21e-0414-401d-bf04-4aa54da3e0b4"
SWAGGER_USERNAME="secops_user"
SWAGGER_PASSWORD="67dcd21e-0414-401d-bf04-4aa54da3e0b4"

# Database Definitions
DB_USERNAME="fortify_user"
DB_PASSWORD="Str0ngRuntimePass!"
DB_HOST="192.168.1.75"
DB_INSTANCE="ssc"
JDBC_URL="jdbc:sqlserver://$DB_HOST:1433;database=$DB_INSTANCE;sendStringParametersAsUnicode=false;encrypt=false"

delete_files() {
  local file_path=$1
  find "$file_path" -maxdepth 1 -type f -delete
}

cleanup_folders() {
  local folders=(
    "$CERT_FOLDER"
    "$ARCHIVE_FOLDER"
    "$ENV_FOLDER"
  )

  for folder in "${folders[@]}"; do
    if [[ -d "$folder" ]]; then
      echo "🧹 Deleting folder and contents: $folder"
      sudo rm -rf "$folder"
    else
      echo "⚠️ Folder not found, skipping: $folder"
    fi
  done
  sudo rm -rf "$FORTIFY_HOME/$BUNDLE_FOLDER"
  sudo rm -rf "$FORTIFY_HOME/_default_.autoconfig"
}

replace_with_variable() {
  local file_path=$1
  local key=$2
  local value=$3

  # Escape /, &, and \ for use in sed
  local escaped_value
  escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')

  sed -i "s|^$key=.*|$key=$escaped_value|" "$file_path"
}

encrypt_string() {
  local pwtool_path="$1"
  local key_file="$2"
  local plain_string="$3"

  expect <<EOF | grep -o '{fp0}.*' | head -n1 | tr -d '\r\n'
    set timeout -1
    spawn $pwtool_path $key_file
    expect "Enter a string to be encrypted:"
    send "$plain_string\r"
    expect "Encrypted value:"
    expect -re "({fp0}.*)\r"
    puts \$expect_out(1,string)
EOF
}

create_service() {
  local SERVICE_NAME=$1
  local TOMCAT_DIR=$2
  local SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
  local JAVA_HOME="$(dirname $(dirname $(update-alternatives --list java | head -n 1)))"
  cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Fortify $SERVICE_NAME service
After=syslog.target network.target

[Service]
Type=forking
Environment=JAVA_HOME=$JAVA_HOME
Environment=CATALINA_PID=$TOMCAT_DIR/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_DIR
Environment=CATALINA_BASE=$TOMCAT_DIR
Environment="JAVA_OPTS=-Dfortify.home=$FORTIFY_HOME -Duser.dir=$FORTIFY_HOME -Duser.home=$FORTIFY_HOME -Xmx$MAX_HEAP"

ExecStart=$TOMCAT_DIR/bin/startup.sh
ExecStop=$TOMCAT_DIR/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

  sudo chmod 644 "$SERVICE_FILE"
  sudo systemctl daemon-reload
  echo "✅ $SERVICE_NAME.service created"
}

trust_certificates() {
  echo -e "\e[1;32m.: Adding certificates to JDK keystore\e[0m"
  if java -version &>/dev/null; then
    echo -e "\e[1;32m.: Adding certificates to JDK keystore\e[0m"
    for cert in "$CERT_FOLDER"/*.crt; do
      if [ -f "$cert" ]; then
          ALIAS="$(basename -s .crt "$cert")"
          if ! keytool -list -cacerts -storepass "$STOREPASS" -alias "$ALIAS" >/dev/null 2>&1; then
            sudo keytool -importcert -noprompt -trustcacerts -alias $ALIAS -file $cert -cacerts -storepass "$STOREPASS" 2>/dev/null
            echo "✅ $ALIAS.crt imported"
          else
            echo "✅ Certificate alias $ALIAS already exists in keystore, skipping import."
          fi
        fi
    done
  else
    echo "❌ Java is not available. Cannot import certificates."
    return 1
  fi
}

[[ -d "$BUNDLE_FOLDER" ]] || { echo "❌ $BUNDLE_FOLDER folder is missing"; exit 1; }
[[ -d "$CERT_FOLDER" ]] || { echo "❌ $CERT_FOLDER folder is missing"; exit 1; }
[[ -d "$ARCHIVE_FOLDER" ]] || { echo "❌ $ARCHIVE_FOLDER folder is missing"; exit 1; }
[[ -d "$ENV_FOLDER" ]] || { echo "❌ $ENV_FOLDER folder is missing"; exit 1; }
[[ -f "$CERT_FOLDER/$PFX_FILE" ]] || { echo "❌ $PFX_FILE is missing"; exit 1; }
[[ -f "$ARCHIVE_FOLDER/ssc.war" ]] || { echo "❌ ssc.war is missing"; exit 1; }
[[ -f "$ENV_FOLDER/$LICENSE_FILE" ]] || { echo "❌ license file is missing"; exit 1; }
[[ -f "$ENV_FOLDER/server.xml" ]] || { echo "❌ server.xml is missing"; exit 1; }
[[ -f "$ENV_FOLDER/web.xml" ]] || { echo "❌ web.xml is missing"; exit 1; }

# Installing Requirements
install_requirements(){
  echo -e "\e[1;32m.: Installing Requirements\e[0m"
  sudo apt update -y -qq 2>/dev/null >/dev/null;
  sudo apt install libarchive-tools -y -qq 2>/dev/null >/dev/null;
  echo "✅ bsdtar installed"
  sudo apt install expect -y -qq 2>/dev/null >/dev/null;
  echo "✅ expect installed"
  sudo apt install fonts-dejavu -y -qq 2>/dev/null >/dev/null;
  echo "✅ Fonts installed"
  echo -e "\e[1;32m.: Checking for JDK 17\e[0m"
  if ! java -version 2>&1 | grep -q 'openjdk version "17'; then
    echo "⚠️ JDK 17 not found. Installing JDK 17..."
    sudo apt install openjdk-17-jdk -y -qq 2>/dev/null >/dev/null;
    echo "✅ JDK 17 installed"
  else
    echo "✅ JDK 17 is already installed"
  fi
}

install_ssc(){
  # Destination Folder Creation
  echo -e "\e[1;32m.: Creating Base Folders\e[0m"
  sudo mkdir -p $TOMCAT_SSC_DIR
  sudo mkdir -p $FORTIFY_HOME/$BUNDLE_FOLDER
  echo "✅ Folders created"
  
  # Preparing SSC Files
  echo -e "\e[1;32m.: Preparing SSC\e[0m"
  TOMCAT_ZIP=$(find "$ARCHIVE_FOLDER" -maxdepth 1 -name 'apache-tomcat*.zip' -print -quit | xargs readlink -f)
  if [[ -f "$TOMCAT_ZIP" ]]; then
    sudo bsdtar -xf "$TOMCAT_ZIP" --strip-components 1 -C "$TOMCAT_SSC_DIR"
    echo "📦 Tomcat extracted"
  else
    echo "❌ Tomcat ZIP not found in $ARCHIVE_FOLDER"
    exit 1
  fi
  delete_files "$TOMCAT_SSC_DIR"
  sudo rm -f "$TOMCAT_SSC_DIR/conf/tomcat-users.xml"
  sudo rm -f "$TOMCAT_SSC_DIR/conf/tomcat-users.xsd"
  sudo rm -f "$TOMCAT_SSC_DIR/conf/server.xml"
  sudo rm -f "$TOMCAT_SSC_DIR/conf/web.xml"
  sudo find "$TOMCAT_SSC_DIR/webapps/" -mindepth 1 -maxdepth 1 -type d -exec rm -r {} +
  sudo mv "./$ARCHIVE_FOLDER/ssc.war" "$TOMCAT_SSC_DIR/webapps/ROOT.war"
  sudo mv -T "./$BUNDLE_FOLDER" "$FORTIFY_HOME/$BUNDLE_FOLDER"
  sudo mv "./$ENV_FOLDER/$LICENSE_FILE" "$FORTIFY_HOME/"
  sudo cp "./$ENV_FOLDER/server.xml" "$TOMCAT_SSC_DIR/conf/"
  sudo cp "./$ENV_FOLDER/web.xml" "$TOMCAT_SSC_DIR/conf/"
  sudo cp "./$CERT_FOLDER/$PFX_FILE" "$TOMCAT_SSC_DIR/conf/"
  sudo sed -i "s/CERTIFICATE_KEYSTORE_PASSWORD/$PFX_FILE_PASSWORD/g" "$TOMCAT_SSC_DIR/conf/server.xml"
  sudo sed -i "s/CONNECTOR_PORT/$SSC_CONNECTOR_PORT/g" "$TOMCAT_SSC_DIR/conf/server.xml"
  sudo sed -i "s/PFX_FILE_NAME/$PFX_FILE/g" "$TOMCAT_SSC_DIR/conf/server.xml"
  sudo rm $TOMCAT_SSC_DIR/bin/*.bat
  sudo chmod +x $TOMCAT_SSC_DIR/bin/*.sh
  
  echo "✅ Tomcat files customized"
  
  PROCESS_SEED_BUNDLE=$(find "$FORTIFY_HOME/$BUNDLE_FOLDER" -maxdepth 1 -name 'Fortify_Process_Seed*.zip' -print -quit)
  REPORT_SEED_BUNDLE=$(find "$FORTIFY_HOME/$BUNDLE_FOLDER" -maxdepth 1 -name 'Fortify_Report_Seed*.zip' -print -quit)
  PCI_BASIC_SEED_BUNDLE=$(find "$FORTIFY_HOME/$BUNDLE_FOLDER" -maxdepth 1 -name 'Fortify_PCI_Basic_Seed*.zip' -print -quit)
  PCI_SSF_SEED_BUNDLE=$(find "$FORTIFY_HOME/$BUNDLE_FOLDER" -maxdepth 1 -name 'Fortify_PCI_SSF_Basic_Seed*.zip' -print -quit)
  
  [[ -f "$PROCESS_SEED_BUNDLE" ]] || { echo "❌ Fortify_Process_Seed file missing"; exit 1; }
  [[ -f "$REPORT_SEED_BUNDLE" ]] || { echo "❌ Fortify_Report_Seed file missing"; exit 1; }
  [[ -f "$PCI_BASIC_SEED_BUNDLE" ]] || { echo "❌ Fortify_PCI_Basic_Seed file missing"; exit 1; }
  [[ -f "$PCI_SSF_SEED_BUNDLE" ]] || { echo "❌ Fortify_PCI_SSF_Basic_Seed file missing"; exit 1; }

  cat <<EOF > "$FORTIFY_HOME/_default_.autoconfig"
appProperties:
  host.url: '$SSC_URL'
  searchIndex.location: '$FORTIFY_HOME/index'
  host.validation: false

datasourceProperties:
  db.username: '$DB_USERNAME'
  db.password: '$DB_PASSWORD'
  jdbc.url: '$JDBC_URL'

dbMigrationProperties:
  migration.enabled: true

seeds:
  - '$PROCESS_SEED_BUNDLE'
  - '$REPORT_SEED_BUNDLE'
  - '$PCI_BASIC_SEED_BUNDLE'
  - '$PCI_SSF_SEED_BUNDLE'
EOF
  echo "✅ SSC autoconfig file created"
  create_service "$SERVICE_SSC" "$TOMCAT_SSC_DIR"
}

install_scc(){
  # Destination Folder Creation
  echo -e "\e[1;32m.: Creating Base Folders\e[0m"
  sudo mkdir -p $TOMCAT_SCC_DIR
  echo "✅ Folders created"

  # Preparing ScanCentral Files
  echo -e "\e[1;32m.: Preparing ScanCentral\e[0m"
  SCC_ZIP=$(find "$ARCHIVE_FOLDER" -maxdepth 1 -name 'Fortify_ScanCentral_Controller*.zip' -print -quit | xargs readlink -f)
  if [[ -f "$SCC_ZIP" ]]; then
    bsdtar -xf "$SCC_ZIP" -C "$ARCHIVE_FOLDER"
  else
    echo "❌ ScanCentral ZIP not found in $ARCHIVE_FOLDER"
    exit 1
  fi
  sudo mv -T "./$ARCHIVE_FOLDER/tomcat/" "$TOMCAT_SCC_DIR/"
  echo "📦 Tomcat & webapp extracted"
  delete_files "$TOMCAT_SCC_DIR"
  sudo rm -f "$TOMCAT_SCC_DIR/conf/tomcat-users.xml"
  sudo rm -f "$TOMCAT_SCC_DIR/conf/tomcat-users.xsd"
  sudo rm -f "$TOMCAT_SCC_DIR/conf/server.xml"
  sudo rm -f "$TOMCAT_SCC_DIR/conf/web.xml"
  sudo cp "./$ENV_FOLDER/server.xml" "$TOMCAT_SCC_DIR/conf/"
  sudo cp "./$ENV_FOLDER/web.xml" "$TOMCAT_SCC_DIR/conf/"
  sudo cp "./$CERT_FOLDER/$PFX_FILE" "$TOMCAT_SCC_DIR/conf/"
  sudo sed -i "s/CERTIFICATE_KEYSTORE_PASSWORD/$PFX_FILE_PASSWORD/g" "$TOMCAT_SCC_DIR/conf/server.xml"
  sudo sed -i "s/CONNECTOR_PORT/$SCC_CONNECTOR_PORT/g" "$TOMCAT_SCC_DIR/conf/server.xml"
  sudo sed -i "s/PFX_FILE_NAME/$PFX_FILE/g" "$TOMCAT_SCC_DIR/conf/server.xml"
  sudo rm $TOMCAT_SCC_DIR/bin/*.bat
  sudo chmod +x $TOMCAT_SCC_DIR/bin/*.sh
  
  echo "✅ ScanCentral files customized"
  create_service "$SERVICE_SCC" "$TOMCAT_SCC_DIR"
  
  PWTOOL_BIN_PATH="./$ARCHIVE_FOLDER/bin/pwtool"
  if [[ -f "$PWTOOL_BIN_PATH" ]]; then
    sudo chmod +x "$PWTOOL_BIN_PATH"
  else
    echo "❌ pwtool not found in $ARCHIVE_FOLDER/bin"
    exit 1
  fi
  SCANCENTRAL_CONFIG_FILE="$TOMCAT_SCC_DIR/webapps/scancentral-ctrl/WEB-INF/classes/config.properties"
  sed -i "s|^#pwtool_keys_file=.*|pwtool_keys_file=\${catalina.base}/$PWTOOL_KEYS_FILE|" "$SCANCENTRAL_CONFIG_FILE"
  
  ENCRYPTED_WORKER_AUTH_TOKEN=$(encrypt_string $PWTOOL_BIN_PATH "$TOMCAT_SCC_DIR/$PWTOOL_KEYS_FILE" "$WORKER_AUTH_TOKEN")
  replace_with_variable "$SCANCENTRAL_CONFIG_FILE" "worker_auth_token" "$ENCRYPTED_WORKER_AUTH_TOKEN"
  ENCRYPTED_CLIENT_AUTH_TOKEN=$(encrypt_string $PWTOOL_BIN_PATH "$TOMCAT_SCC_DIR/$PWTOOL_KEYS_FILE" "$CLIENT_AUTH_TOKEN")
  replace_with_variable "$SCANCENTRAL_CONFIG_FILE" "client_auth_token" "$ENCRYPTED_CLIENT_AUTH_TOKEN"
  ENCRYPTED_SSC_SCANCENTRAL_CTRL_SECRET=$(encrypt_string $PWTOOL_BIN_PATH "$TOMCAT_SCC_DIR/$PWTOOL_KEYS_FILE" "$SSC_SCANCENTRAL_CTRL_SECRET")
  replace_with_variable "$SCANCENTRAL_CONFIG_FILE" "ssc_scancentral_ctrl_secret" "$ENCRYPTED_SSC_SCANCENTRAL_CTRL_SECRET"
  replace_with_variable "$SCANCENTRAL_CONFIG_FILE" "ssc_url" "$SSC_URL"
  replace_with_variable "$SCANCENTRAL_CONFIG_FILE" "this_url" "$SCANCENTRAL_URL"
  replace_with_variable "$SCANCENTRAL_CONFIG_FILE" "client_auto_update" "true"
  ENCRYPTED_SWAGGER_USERNAME=$(encrypt_string $PWTOOL_BIN_PATH "$TOMCAT_SCC_DIR/$PWTOOL_KEYS_FILE" "$SWAGGER_USERNAME")
  replace_with_variable "$SCANCENTRAL_CONFIG_FILE" "swagger_username" "$ENCRYPTED_SWAGGER_USERNAME"
  ENCRYPTED_SWAGGER_PASSWORD=$(encrypt_string $PWTOOL_BIN_PATH "$TOMCAT_SCC_DIR/$PWTOOL_KEYS_FILE" "$SWAGGER_PASSWORD")
  replace_with_variable "$SCANCENTRAL_CONFIG_FILE" "swagger_password" "$ENCRYPTED_SWAGGER_PASSWORD"
  echo "✅ ScanCentral config.properties file edited"
}

if [[ $# -lt 1 ]]; then
  echo "❌ No install target specified. Use: ssc | scc | all"
  exit 1
fi

if [[ "$1" == "ssc" ]]; then
  install_requirements
  install_ssc
  trust_certificates
  echo -e "\n\e[1;32mTo start services and add to startup:\e[0m\n"
  echo "sudo systemctl start $SERVICE_SSC.service"
  echo "sudo systemctl enable $SERVICE_SSC.service"
  echo -e "\n\e[1;32mTo reach applications:\e[0m\n"
  echo "Fortify SSC URL: $SSC_URL"
  echo -e "\n\e[1;32mTo reach logs:\e[0m\n"
  echo "Fortify SSC Logs: $FORTIFY_HOME/_default_/logs"
  echo "Fortify SSC Tomcat Logs: $TOMCAT_SSC_DIR/logs"
  echo -e "\n✅ Installation completed"
elif [[ "$1" == "scc" ]]; then
  install_requirements
  install_scc
  trust_certificates
  echo -e "\n\e[1;32mTo start services and add to startup:\e[0m\n"
  echo "sudo systemctl start $SERVICE_SCC.service"
  echo "sudo systemctl enable $SERVICE_SCC.service"
  echo -e "\n\e[1;32mTo reach applications:\e[0m\n"
  echo "Fortify ScanCentral URL: $SCANCENTRAL_URL"
  echo -e "\n\e[1;32mTo reach logs:\e[0m\n"
  echo "Fortify ScanCentral & Tomcat Logs: $TOMCAT_SCC_DIR/logs"
  echo -e "\n✅ Installation completed"
elif [[ "$1" == "all" ]]; then
  install_requirements
  install_ssc
  install_scc
  trust_certificates
  echo -e "\n\e[1;32mTo start services and add to startup:\e[0m\n"
  echo "sudo systemctl start $SERVICE_SSC.service"
  echo "sudo systemctl start $SERVICE_SCC.service"
  echo "sudo systemctl enable $SERVICE_SSC.service"
  echo "sudo systemctl enable $SERVICE_SCC.service"
  echo -e "\n\e[1;32mTo reach applications:\e[0m\n"
  echo "Fortify SSC URL: $SSC_URL"
  echo "Fortify ScanCentral URL: $SCANCENTRAL_URL"
  echo -e "\n\e[1;32mTo reach logs:\e[0m\n"
  echo "Fortify SSC Logs: $FORTIFY_HOME/_default_/logs"
  echo "Fortify SSC Tomcat Logs: $TOMCAT_SSC_DIR/logs"
  echo "Fortify ScanCentral & Tomcat Logs: $TOMCAT_SCC_DIR/logs"
  echo -e "\n✅ Installation completed"
else
  echo "❌ Unknown argument"
fi
echo -e "\e[1;32m.: Starting Cleaning\e[0m"
cleanup_folders