#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://kodi.tv/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Setting Up Hardware Acceleration"
$STD apt-get -y install {va-driver-all,ocl-icd-libopencl1,intel-opencl-icd,vainfo,intel-gpu-tools}
if [[ "$CTTYPE" == "0" ]]; then
  chgrp video /dev/dri
  chmod 755 /dev/dri
  chmod 660 /dev/dri/*
  $STD adduser $(id -u -n) video
  $STD adduser $(id -u -n) render
fi
msg_ok "Set Up Hardware Acceleration"

msg_info "Setting Up kodi User"
$STD useradd -d /home/kodi -m kodi
$STD gpasswd -a kodi audio
$STD gpasswd -a kodi video
$STD gpasswd -a kodi render
$STD groupadd -r autologin
$STD gpasswd -a kodi autologin
$STD gpasswd -a kodi input # to enable direct access to devices
msg_ok "Set Up kodi User"

msg_info "Installing lightdm"
DEBIAN_FRONTEND=noninteractive $STD apt-get install -y lightdm
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
msg_ok "Installed lightdm"

msg_info "Setting Up deb-multimedia Repository"
cat <<EOF >/etc/apt/sources.list.d/deb-multimedia.sources
Types: deb
URIs: https://www.deb-multimedia.org
Suites: bookworm bookworm-backports
Components: main
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp
EOF
KEYRING_CHECKSUM="8dc6cbb266c701cfe58bd1d2eb9fe2245a1d6341c7110cfbfe3a5a975dcf97ca"
KEYRING_DEB=$(mktemp deb-multimedia-keyring.XXXX.deb)
$STD curl -o "$KEYRING_DEB" https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2024.9.1_all.deb
if ! echo "$KEYRING_CHECKSUM $KEYRING_DEB" | sha256sum --check --status; then
  msg_error "Checksum of downloaded deb-multi-media-keyring file does not match"
  exit 1
fi
$STD dpkg -i "$KEYRING_DEB"
$STD apt-get -y update
$STD apt-get -y dist-upgrade
msg_ok "Set Up deb-multimedia Repository"

msg_info "Installing Kodi"
$STD apt-get install -y -t stable-backports kodi{,-{inputstream-adaptive,peripheral-joystick}}
msg_ok "Installed Kodi"

msg_info "Updating xsession"
cat <<EOF >/usr/share/xsessions/kodi-alsa.desktop
[Desktop Entry]
Name=Kodi-alsa
Comment=This session will start Kodi media center with alsa support
Exec=env AE_SINK=ALSA kodi-standalone
TryExec=env AE_SINK=ALSA kodi-standalone
Type=Application
EOF
msg_ok "Updated xsession"

msg_info "Setting up autologin"
mkdir -p /etc/lightdm/lightdm.conf.d/
cat <<EOF >/etc/lightdm/lightdm.conf.d/autologin-kodi.conf
[Seat:*]
autologin-user=kodi
autologin-session=kodi-alsa
EOF
msg_ok "Set up autologin"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

msg_info "Starting X"
systemctl start lightdm
ln -fs /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
msg_info "Started X"
