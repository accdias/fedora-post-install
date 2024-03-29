#!/bin/bash
export LANG=C

KERNEL_VERSION=$(uname -r)

# Disable CPU mitigations to improve performance on Desktop
sed -i -e 's/rhgb/mitigations=off rhgb/g' /etc/defaults/grub

[ -r /boot/grub2/grub.cfg ] && grub2-mkconfig -o /boot/grub2/grub.cfg
[ -r /boot/efi/EFI/fedora/grub.cfg ] && grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg

# Update the rescue image
/etc/kernel/postinst.d/51-dracut-rescue-postinst.sh ${KERNEL_VERSION} /boot/vmlinuz-${KERNEL_VERSION}

# Give virt-manager permissions for wheel group
cat << EOF >/etc/polkit-1/localauthority/50-local.d/50-org.virtman-libvirt-local-access.pkla
[Allow group virtman libvirt management permissions]
Identity=unix-group:wheel
Action=org.libvirt.unix.manage
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
restorecon -F /etc/polkit-1/localauthority/50-local.d/50-org.virtman-libvirt-local-access.pkla

cat << EOF >/etc/polkit-1/rules.d/80-libvirtd.rules
/* Allow users in wheel group to manage the libvirt daemon without authentication */
polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" &&
        subject.isInGroup("wheel")) {
            return polkit.Result.YES;
    }
});
EOF
restorecon -F /etc/polkit-1/rules.d/80-libvirtd.rules

# Enable tap-to-click on GDM (logon screen)
sudo su - gdm -s /bin/bash << EOF
export $(dbus-launch)
# Enable Wayland fractional screen scaling
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
gsettings set org.gnome.desktop.interface scaling-factor 1
# Configure Touchpad
gsettings set org.gnome.desktop.peripherals.touchpad click-method 'fingers'
gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing true
gsettings set org.gnome.desktop.peripherals.touchpad edge-scrolling-enabled false
gsettings set org.gnome.desktop.peripherals.touchpad left-handed 'mouse'
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
gsettings set org.gnome.desktop.peripherals.touchpad send-events 'enabled'
gsettings set org.gnome.desktop.peripherals.touchpad speed 0.5
gsettings set org.gnome.desktop.peripherals.touchpad tap-and-drag true
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
EOF

# US International with dead keys
gsettings set org.gnome.desktop.input-sources mru-sources "[('xkb', 'us+intl'), ('ibus', 'typing-booster:en_US')]"
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+intl')]"
# Set Right Alt as compose key
gsettings set org.gnome.desktop.input-sources xkb-options "['compose:ralt']"
# Use the same keyboard layout for all windows
gsettings set org.gnome.desktop.input-sources per-window false
# Disable automatic opening of folders while hovering on drag an drop operations
gsettings set org.gnome.nautilus.preferences open-folder-on-dnd-hover false
# Set default click action to minimize/maximize
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'
# Change Gnome Terminal word selection string
#profile_puuid=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
#gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$puuid/ word-char-exceptions '@ms "-=&#:/.?@+~_%;"'
#gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$puuid/ word-char-exceptions '@ms nothing'
# Set kitty as default Terminal
gsettings set org.gnome.desktop.default-applications.terminal exec 'kitty.desktop'

# Remove uncessary packages
sudo dnf remove -y abrt*

# Fix Google Chrome download icons
sudo dnf install -y gnome-icon-theme.noarch gnome-icon-theme-extras.noarch elementary-icon-theme.noarch

# Install extra packages
sudo dnf install -y tmate tmux tlp tlp-rdw icedtea-web
systemctl enable tlp.service

# Enable SSD trimmer
#sudo systemctl enable --now fstrim.timer

# Disable abrtd services
for unit in abrtd abrt-ccpp abrt-journal-core abrt-oops abrt-pstoreoops abrt-vmcore abrt-xorg; do
    sudo systemctl stop ${unit}.service
    sudo systemctl disable ${unit}.service
done

# Disable Gnome Software updates and notifications
for unit in packagekit dnf-makecache.service dnf-makecache.timer; do
    sudo systemctl stop ${unit}
    sudo systemctl disable ${unit}
done

# Change default I/O scheduler
cat << EOF >/etc/udev/rules.d/60-io-scheduler.rules
# set deadline scheduler for non-rotating disks
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="noop"
# set deadline scheduler for rotating disks
#ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="cfq"
EOF
restorecon -F /etc/udev/rules.d/60-io-scheduler.rules

# Create Android devices udev rules
cat << EOF >/etc/udev/rules.d/51-android.rules
# /etc/udev/rules.d/51-android.rules
# NEC
SUBSYSTEM=="usb",ATTRS{idVendor}=="0409", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Gigabyte
SUBSYSTEM=="usb",ATTRS{idVendor}=="0414", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Philips
SUBSYSTEM=="usb",ATTRS{idVendor}=="0471", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Kyocera
SUBSYSTEM=="usb",ATTRS{idVendor}=="0482", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Foxconn
SUBSYSTEM=="usb",ATTRS{idVendor}=="0489", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Fujitsu
SUBSYSTEM=="usb",ATTRS{idVendor}=="04c5", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Fujitsu Toshiba
SUBSYSTEM=="usb",ATTRS{idVendor}=="04c5", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# PMC-Sierra
SUBSYSTEM=="usb",ATTRS{idVendor}=="04da", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Sharp
SUBSYSTEM=="usb",ATTRS{idVendor}=="04dd", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Samsung
SUBSYSTEM=="usb",ATTRS{idVendor}=="04e8", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Acer
SUBSYSTEM=="usb",ATTRS{idVendor}=="0502", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Sony
SUBSYSTEM=="usb",ATTRS{idVendor}=="054c", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Qualcomm
SUBSYSTEM=="usb",ATTRS{idVendor}=="05c6", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Garmin-Asus
SUBSYSTEM=="usb",ATTRS{idVendor}=="091e", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Toshiba
SUBSYSTEM=="usb",ATTRS{idVendor}=="0930", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Nvidia
SUBSYSTEM=="usb",ATTRS{idVendor}=="0955", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# ASUS
SUBSYSTEM=="usb",ATTRS{idVendor}=="0b05", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# HTC
SUBSYSTEM=="usb",ATTRS{idVendor}=="0bb4", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# MTK
SUBSYSTEM=="usb",ATTRS{idVendor}=="0e8d", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Sony Ericsson
SUBSYSTEM=="usb",ATTRS{idVendor}=="0fce", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# LG
SUBSYSTEM=="usb",ATTRS{idVendor}=="1004", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Hisense
SUBSYSTEM=="usb",ATTRS{idVendor}=="109b", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Pantech
SUBSYSTEM=="usb",ATTRS{idVendor}=="10a9", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Huawei
SUBSYSTEM=="usb",ATTRS{idVendor}=="12d1", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Multilaser
SUBSYSTEM=="usb",ATTRS{idVendor}=="1782", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Lenovo
SUBSYSTEM=="usb",ATTRS{idVendor}=="17ef", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Google
SUBSYSTEM=="usb",ATTRS{idVendor}=="18d1", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Amazon
SUBSYSTEM=="usb",ATTRS{idVendor}=="1949", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# ZTE
SUBSYSTEM=="usb",ATTRS{idVendor}=="19d2", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Pegatron
SUBSYSTEM=="usb",ATTRS{idVendor}=="1d4d", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# SK Telesys
SUBSYSTEM=="usb",ATTRS{idVendor}=="1f53", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Haier
SUBSYSTEM=="usb",ATTRS{idVendor}=="201E", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Nook
SUBSYSTEM=="usb",ATTRS{idVendor}=="2080", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# KT Tech
SUBSYSTEM=="usb",ATTRS{idVendor}=="2116", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# OTGV
SUBSYSTEM=="usb",ATTRS{idVendor}=="2257", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Motorola
SUBSYSTEM=="usb",ATTRS{idVendor}=="22b8", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# OPPO
SUBSYSTEM=="usb",ATTRS{idVendor}=="22d9", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Teleepoch
SUBSYSTEM=="usb",ATTRS{idVendor}=="2340", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# K-Touch
SUBSYSTEM=="usb",ATTRS{idVendor}=="24e3", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Xiaomi
SUBSYSTEM=="usb",ATTRS{idVendor}=="2717", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# Dell
SUBSYSTEM=="usb",ATTRS{idVendor}=="413c", MODE="0644",GROUP="wheel",SYMLINK+="android%n"
# End of file
EOF

# Set default fonts
gesettings set org.gnome.desktop.interface font-name 'Roboto 10'
gesettings set org.gnome.desktop.interface document-font-name 'Roboto 10'
gesettings set org.gnome.desktop.interface monospace-font-name 'Roboto Mono 10'

# Configure Touchpad
gsettings set org.gnome.desktop.peripherals.touchpad send-events 'enabled'
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.desktop.peripherals.touchpad left-handed 'mouse'
gsettings set org.gnome.desktop.peripherals.touchpad click-method 'fingers'
gsettings set org.gnome.desktop.peripherals.touchpad speed 0.5
gsettings set org.gnome.desktop.peripherals.touchpad tap-and-drag true
gsettings set org.gnome.desktop.peripherals.touchpad edge-scrolling-enabled false
gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing true

# Workaround for touchpad phantom tap-clicks
cat << EOF >/etc/udev/rules.d/90-psmouse.rules
ACTION=="add|change", SUBSYSTEM=="module", DEVPATH=="/module/psmouse", ATTR{parameters/synaptics_intertouch}="0"
EOF
restorecon -F /etc/udev/rules.d/90-psmouse.rules

# Configure trackpoint for scrolling when combined with physical middle button
cat << EOF >/etc/X11/xorg.conf.d/90-trackpoint.conf
Section "InputClass"
    Identifier "Trackpoint Scrolling"
    MatchProduct "TPPS/2 IBM TrackPoint"
    MatchDevicePath "/dev/input/event*"
    # Configure wheel emulation, using middle button and "natural scrolling".
    Option "EmulateWheel" "on"
    Option "EmulateWheelButton" "2"
    Option "EmulateWheelTimeout" "200"
    Option "EmulateWheelInertia" "7"
    Option "XAxisMapping" "7 6"
    Option "YAxisMapping" "5 4"
    # Set up an acceleration config ("mostly linear" profile, factor 5.5).
    Option "AccelerationProfile" "3"
    Option "AccelerationNumerator" "55"
    Option "AccelerationDenominator" "10"
    Option "ConstantDeceleration" "3"
EndSection
EOF
restorecon -F /etc/X11/xorg.conf.d/90-trackpoint.conf

#for key in $(gsettings list-keys org.gnome.desktop.peripherals.touchpad); do
#   echo -n "$key: ";
#   gsettings get org.gnome.desktop.peripherals.touchpad $key;
#done
#send-events: 'enabled'
#natural-scroll: true
#tap-to-click: true
#two-finger-scrolling-enabled: true
#left-handed: 'mouse'
#click-method: 'fingers'
#speed: 0.0
#tap-and-drag: false
#edge-scrolling-enabled: false
#disable-while-typing: true

# dconf dump /org/gnome/terminal/legacy/profiles:/

cat << EOF | dconf load /org/gnome/terminal/legacy/profiles:/
[/]
list=['b1dcc9dd-5262-4d8d-a863-c897e6d979b9', 'c4d30e10-0fc6-4d6a-84e1-368876bdbc8e', '5560419d-7f12-4ccf-8428-caf01ea36e5e', '61c23868-3203-4972-ab69-b29958b8f581', 'c1849c35-53b2-43fb-b06b-e5fb797805aa', 'd43f4948-7707-4b61-adc9-93eeb3d5f319']
default='d43f4948-7707-4b61-adc9-93eeb3d5f319'

[:5560419d-7f12-4ccf-8428-caf01ea36e5e]
foreground-color='#ffffffffffff'
visible-name='Dark Pastel Roboto Mono Regular 10'
scrollbar-policy='never'
login-shell=true
palette=['#000000000000', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#bbbbbbbbbbbb', '#555555555555', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#ffffffffffff']
use-system-font=false
cursor-colors-set=false
highlight-colors-set=false
use-theme-colors=false
use-transparent-background=true
font='Roboto Mono 10'
scrollback-unlimited=true
bold-color-same-as-fg=true
bold-color='#bbbbbbbbbbbb'
background-color='#000000000000'
background-transparency-percent=17
audible-bell=false

[:b1dcc9dd-5262-4d8d-a863-c897e6d979b9]
foreground-color='rgb(170,170,170)'
visible-name='Monospace Regular 10'
scrollbar-policy='never'
login-shell=true
palette=['rgb(0,0,0)', 'rgb(170,0,0)', 'rgb(0,170,0)', 'rgb(170,85,0)', 'rgb(0,0,170)', 'rgb(170,0,170)', 'rgb(0,170,170)', 'rgb(170,170,170)', 'rgb(85,85,85)', 'rgb(255,85,85)', 'rgb(85,255,85)', 'rgb(255,255,85)', 'rgb(85,85,255)', 'rgb(255,85,255)', 'rgb(85,255,255)', 'rgb(255,255,255)']
use-system-font=false
cursor-colors-set=false
highlight-colors-set=false
use-theme-colors=false
use-transparent-background=true
font='Monospace 10'
scrollback-unlimited=true
bold-color-same-as-fg=true
background-color='rgb(0,0,0)'
background-transparency-percent=17
audible-bell=false

[:d43f4948-7707-4b61-adc9-93eeb3d5f319]
foreground-color='#ffffffffffff'
visible-name='Dark Pastel Fira Mono Medium 10'
scrollbar-policy='never'
login-shell=true
palette=['#000000000000', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#bbbbbbbbbbbb', '#555555555555', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#ffffffffffff']
use-system-font=false
cursor-colors-set=false
highlight-colors-set=false
use-theme-colors=false
use-transparent-background=true
font='Fira Mono Medium 10'
scrollback-unlimited=true
bold-color-same-as-fg=true
bold-color='#bbbbbbbbbbbb'
background-color='#000000000000'
background-transparency-percent=17
audible-bell=false

[:c1849c35-53b2-43fb-b06b-e5fb797805aa]
foreground-color='#ffffffffffff'
visible-name='Dark Pastel Anonymous Pro Regular 11'
scrollbar-policy='never'
login-shell=true
palette=['#000000000000', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#bbbbbbbbbbbb', '#555555555555', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#ffffffffffff']
use-system-font=false
cursor-colors-set=false
highlight-colors-set=false
use-theme-colors=false
use-transparent-background=true
font='Anonymous Pro 11'
scrollback-unlimited=true
bold-color-same-as-fg=true
bold-color='#bbbbbbbbbbbb'
background-color='#000000000000'
background-transparency-percent=17
audible-bell=false

[:61c23868-3203-4972-ab69-b29958b8f581]
foreground-color='#ffffffffffff'
visible-name='Dark Pastel Roboto Mono Medium 10'
scrollbar-policy='never'
login-shell=true
palette=['#000000000000', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#bbbbbbbbbbbb', '#555555555555', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#ffffffffffff']
use-system-font=false
cursor-colors-set=false
highlight-colors-set=false
use-theme-colors=false
use-transparent-background=true
font='Roboto Mono Medium 10'
scrollback-unlimited=true
bold-color-same-as-fg=true
bold-color='#bbbbbbbbbbbb'
background-color='#000000000000'
background-transparency-percent=17
audible-bell=false

[:c4d30e10-0fc6-4d6a-84e1-368876bdbc8e]
foreground-color='#ffffffffffff'
visible-name='Dark Pastel Droid Sans Mono Regular 10'
scrollbar-policy='never'
login-shell=true
palette=['#000000000000', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#bbbbbbbbbbbb', '#555555555555', '#ffff55555555', '#5555ffff5555', '#ffffffff5555', '#55555555ffff', '#ffff5555ffff', '#5555ffffffff', '#ffffffffffff']
use-system-font=false
cursor-colors-set=false
highlight-colors-set=false
use-theme-colors=false
use-transparent-background=true
font='Droid Sans Mono 10'
scrollback-unlimited=true
use-theme-background=false
bold-color-same-as-fg=true
bold-color='#bbbbbbbbbbbb'
background-color='#000000000000'
background-transparency-percent=17
audible-bell=false
EOF

# Fix Faience theme system icons
FAIENCE_DIR='/usr/share/icons/Faience/apps/scalable'
if [[ -d ${FAIENCE_DIR} ]]; then
    if [[ cd ${FAIENCE_DIR} ]]; then
        sudo ln -sf ./accessories-calculator.svg org.gnome.Calculator.svg
        sudo ln -sf ./clock.svg org.gnome.clocks.svg
        sudo ln -sf ./eog.svg org.gnome.eog.svg
        sudo ln -sf ./web-browser.svg org.gnome.Epiphany.svg
        sudo ln -sf ./evince.svg org.gnome.Evince.svg
        sudo ln -sf ./text-editor.svg org.gnome.gedit.svg
        sudo ln -sf ./system-file-manager.svg org.gnome.Nautilus.svg
        sudo ln -sf ../../categories/scalable/preferences-desktop.svg org.gnome.Settings.svg
        sudo ln -sf ./update-manager.svg org.gnome.Software.svg
        sudo ln -sf ./utilities-terminal.svg org.gnome.Terminal.svg
        sudo ln -sf ./totem.svg org.gnome.Totem.svg
    fi
fi

# End of file
