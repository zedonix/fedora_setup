#!/usr/bin/env bash
set -euo pipefail

# Redirect all output (stdout & stderr) into the user’s home directory log
LOGFILE="${HOME}/fedora_setup.log"
# ensure log exists and is owned by the user
: >"${LOGFILE}"
exec > >(tee -a "$LOGFILE") 2>&1

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Variable set
username=piyush

# Which type of install?
# First choice: vm or hardware
echo "Choose one:"
select hardware in "vm" "hardware"; do
  [[ -n $hardware ]] && break
  echo "Invalid choice. Please select 1 for vm or 2 for hardware."
done

# extra choice: laptop or bluetooth or none
if [[ "$hardware" == "hardware" ]]; then
  echo "Choose one:"
  select extra in "laptop" "bluetooth" "none"; do
    [[ -n $extra ]] && break
    echo "Invalid choice."
  done
else
  extra="none"
fi

# Which type of packages?
# Main package selection
case "$hardware" in
vm)
  sed -n '1p;3p' pkgs.txt | tr ' ' '\n' | grep -v '^$' >>pkglist.txt
  ;;
hardware)
  # For hardware:max, we will add lines 5 and/or 6 later based on $extra
  sed -n '1,4p' pkgs.txt | tr ' ' '\n' | grep -v '^$' >>pkglist.txt
  ;;
esac

# For hardware:max, add lines 5 and/or 6 based on $extra
if [[ "$hardware" == "hardware" ]]; then
  case "$extra" in
  laptop)
    # Add both line 5 and 6
    sed -n '5,6p' pkgs.txt | tr ' ' '\n' | grep -v '^$' >>pkglist.txt
    ;;
  bluetooth)
    # Add only line 5
    sed -n '5p' pkgs.txt | tr ' ' '\n' | grep -v '^$' >>pkglist.txt
    ;;
  none)
    # Do not add line 5 or 6
    ;;
  esac
fi

# Install stuff
# dnf mirror
sudo tee -a /etc/dnf/dnf.conf <<EOF
fastestmirror=True
max_parallel_downloads=10
deltarpm=True
assumeyes=True
gpgcheck=True
EOF
## Adding repos
sudo dnf -y copr enable solopasha/hyprland
sudo dnf -y copr enable maximizerr/SwayAura

# pacstrap of fedora
xargs sudo dnf install -y <pkglist.txt

# Ly Setup
cd "$(mktemp -d)"
git clone https://codeberg.org/AnErrupTion/ly.git
cd ly
zig build
sudo zig build installexe

# Fix broken Fedora PAM config for ly
sudo tee /etc/pam.d/ly >/dev/null <<'EOF'
#%PAM-1.0
auth       include      system-auth
account    include      system-auth
password   include      system-auth
session    include      system-auth

# Optional: start keyring/wallets (safe even if not installed)
auth       optional     pam_gnome_keyring.so
session    optional     pam_gnome_keyring.so auto_start
session    optional     pam_kwallet5.so auto_start
EOF

# Write a static, tested SELinux policy for ly
cat <<'EOF' > ly.te
module ly 1.0;

require {
    type init_t;
    type tty_device_t;
    type var_log_t;
    type pam_var_run_t;
    type xserver_t;
    class chr_file { read write open ioctl };
    class file { open read write getattr };
    class unix_stream_socket connectto;
}

# Allow ly to access the TTY, logs, PAM socket, and X socket
allow init_t tty_device_t:chr_file { read write open ioctl };
allow init_t var_log_t:file { open read write };
allow init_t pam_var_run_t:file { getattr open read };
allow init_t xserver_t:unix_stream_socket connectto;
EOF

# Compile & install it
checkmodule -M -m -o ly.mod ly.te
semodule_package -o ly.pp -m ly.mod
sudo semodule -i ly.pp

sudo systemctl enable ly.service
sudo systemctl set-default multi-user.target
sudo systemctl disable getty@tty2.service

# eza
curl -LO https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz
tar -xzf eza_x86_64-unknown-linux-gnu.tar.gz
sudo mv eza /usr/local/bin/
sudo chmod +x /usr/local/bin/eza
# wikiman
RPM_URL=$(curl -s https://api.github.com/repos/filiparag/wikiman/releases/latest |
  grep "browser_download_url" |
  grep -E "wikiman.*\.rpm" |
  cut -d '"' -f 4)
curl -LO "$RPM_URL"
RPM_FILE="${RPM_URL##*/}"
sudo dnf install -y "$RPM_FILE"
# Iosevka
mkdir -p ~/.local/share/fonts/iosevka
cd ~/.local/share/fonts/iosevka
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IosevkaTerm.zip
unzip IosevkaTerm.zip
rm IosevkaTerm.zip
# unp
python3 -m pip install --user unp

# Copy config and dotfiles as the user
mkdir -p ~/.local/state/bash ~/.local/state/zsh
mkdir -p ~/Downloads ~/Documents/default ~/Documents/projects ~/Public ~/Templates/wiki ~/Videos ~/Pictures/Screenshots ~/.config
mkdir -p ~/.local/share/npm ~/.cache/npm ~/.config/npm/config ~/.local/bin
touch ~/.local/state/bash/history ~/.local/state/zsh/history ~/Templates/wiki/index.md

git clone https://github.com/zedonix/scripts.git ~/Documents/default/scripts
git clone https://github.com/zedonix/dotfiles.git ~/Documents/default/dotfiles
git clone https://github.com/zedonix/archsetup.git ~/Documents/default/archsetup
git clone https://github.com/zedonix/notes.git ~/Documents/default/notes
git clone https://github.com/CachyOS/ananicy-rules.git ~/Documents/default/ananicy-rules
git clone https://github.com/zedonix/GruvboxGtk.git ~/Documents/default/GruvboxGtk
git clone https://github.com/zedonix/GruvboxQT.git ~/Documents/default/GruvboxQT
git clone https://github.com/zedonix/fedora_setup.git ~/Documents/default/fedora_setup

if [[ -d ~/Documents/default/dotfiles ]]; then
  cp ~/Documents/default/dotfiles/.config/sway/archLogo.png ~/Pictures/ 2>/dev/null || true
  cp ~/Documents/default/dotfiles/pics/* ~/Pictures/ 2>/dev/null || true
  cp -r ~/Documents/default/dotfiles/.local/share/themes/Gruvbox-Dark ~/.local/share/themes/ 2>/dev/null || true
  ln -sf ~/Documents/default/dotfiles/.bashrc ~/.bashrc 2>/dev/null || true
  ln -sf ~/Documents/default/dotfiles/.zshrc ~/.zshrc 2>/dev/null || true
  ln -sf ~/Documents/default/dotfiles/.gtk-bookmarks ~/.gtk-bookmarks || true

  for link in ~/Documents/default/dotfiles/.config/*; do
    ln -sf "$link" ~/.config/ 2>/dev/null || true
  done
  for link in ~/Documents/default/scripts/bin/*; do
    ln -sf "$link" ~/.local/bin 2>/dev/null || true
  done
fi
# Clone tpm
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

sudo env hardware="$hardware" extra="$extra" username="$username" bash <<'EOF'
  dracut --force
  sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
  grub2-mkconfig -o /boot/grub2/grub.cfg

  # User setup
  if [[ "$hardware" == "hardware" ]]; then
      usermod -aG wheel,video,audio,lp,scanner,kvm,libvirt,docker "$username"
  else
      usermod -aG wheel,video,audio,lp "$username"
  fi

  # Sudo Configuration
  echo "%wheel ALL=(ALL) ALL" >/etc/sudoers.d/wheel
  echo "Defaults timestamp_timeout=-1" >/etc/sudoers.d/timestamp
  chmod 440 /etc/sudoers.d/wheel /etc/sudoers.d/timestamp

  # Root .config
  mkdir -p ~/.config ~/.local/state/bash ~/.local/state/zsh
  echo '[[ -f ~/.bashrc ]] && . ~/.bashrc' >~/.bash_profile
  touch ~/.local/state/zsh/history ~/.local/state/bash/history
  ln -sf /home/$username/Documents/default/dotfiles/.bashrc ~/.bashrc 2>/dev/null || true
  ln -sf /home/$username/Documents/default/dotfiles/.zshrc ~/.zshrc 2>/dev/null || true
  ln -sf /home/$username/Documents/default/dotfiles/.config/nvim/ ~/.config

  # Setup QT theme
  THEME_SRC="/home/$username/Documents/default/GruvboxQT/"
  THEME_DEST="/usr/share/Kvantum/Gruvbox"
  mkdir -p "$THEME_DEST"
  cp "$THEME_SRC/gruvbox-kvantum.kvconfig" "$THEME_DEST/Gruvbox.kvconfig" 2>/dev/null || true
  cp "$THEME_SRC/gruvbox-kvantum.svg" "$THEME_DEST/Gruvbox.svg" 2>/dev/null || true

  # Install CachyOS Ananicy Rules
  ANANICY_RULES_SRC="/home/$username/Documents/default/ananicy-rules"
  mkdir -p /etc/ananicy.d

  cp -r "$ANANICY_RULES_SRC/00-default" /etc/ananicy.d/ 2>/dev/null || true
  cp "$ANANICY_RULES_SRC/"*.rules /etc/ananicy.d/ 2>/dev/null || true
  cp "$ANANICY_RULES_SRC/00-cgroups.cgroups" /etc/ananicy.d/ 2>/dev/null || true
  cp "$ANANICY_RULES_SRC/00-types.types" /etc/ananicy.d/ 2>/dev/null || true
  cp "$ANANICY_RULES_SRC/ananicy.conf" /etc/ananicy.d/ 2>/dev/null || true

  chmod -R 644 /etc/ananicy.d/*
  chmod 755 /etc/ananicy.d/00-default

  # Firefox policy
  mkdir -p /etc/firefox/policies
  ln -sf "/home/$username/Documents/default/dotfiles/policies.json" /etc/firefox/policies/policies.json 2>/dev/null || true

  # tldr wiki setup
  curl -L "https://raw.githubusercontent.com/filiparag/wikiman/master/Makefile" -o "wikiman-makefile"
  make -f ./wikiman-makefile source-tldr
  make -f ./wikiman-makefile source-install
  make -f ./wikiman-makefile clean

  # zram config
  mkdir -p /etc/systemd/zram-generator.conf.d
  printf "[zram0]\nzram-size=min(ram/2,4096)\ncompression-algorithm=zstd\nswap-priority=100\nfs-type=swap\n"| tee /etc/systemd/zram-generator.conf.d/00-zram.conf > /dev/null

  # services
  # rfkill unblock bluetooth
  # modprobe btusb || true
  systemctl enable NetworkManager NetworkManager-dispatcher
  if [[ "$hardware" == "hardware" ]]; then
      systemctl enable ly fstrim.timer acpid crond ananicy-cpp libvirtd.socket cups ipp-usb docker.socket
      if [[ "$extra" == "laptop" || "$extra" == "bluetooth" ]]; then
          systemctl enable bluetooth
      fi
      if [[ "$extra" == "laptop" ]]; then
          systemctl enable tlp
      fi
  else
      systemctl enable ly crond ananicy-cpp
  fi
  systemctl mask systemd-rfkill systemd-rfkill.socket
  systemctl disable NetworkManager-wait-online.service systemd-networkd.service systemd-resolved

  # prevent networkmanager from using systemd-resolved
  mkdir -p /etc/networkmanager/conf.d
  printf "[main]\nsystemd-resolved=false\n" | sudo tee /etc/networkmanager/conf.d/no-systemd-resolved.conf

  # firewalld setup
  # firewall-cmd --set-default-zone=public
  firewall-cmd --permanent --remove-service=dhcpv6-client
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  # firewall-cmd --permanent --add-service=ssh
  firewall-cmd --permanent --add-service=dns
  firewall-cmd --permanent --add-service=dhcp
  firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.0/24" accept'
  firewall-cmd --set-log-denied=all
  # Create and assign a zone for virbr0
  firewall-cmd --permanent --new-zone=libvirt
  firewall-cmd --permanent --zone=libvirt --add-interface=virbr0
  # Allow DHCP (ports 67, 68 UDP) and DNS (53 UDP)
  # firewall-cmd --permanent --zone=libvirt --add-port=67/udp
  # firewall-cmd --permanent --zone=libvirt --add-port=68/udp
  # firewall-cmd --permanent --zone=libvirt --add-port=53/udp
  # Enable masquerading for routed traffic (NAT)
  firewall-cmd --permanent --add-masquerade
  firewall-cmd --reload
  systemctl enable firewalld
  # echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-firewalld.conf
  # sysctl -p /etc/sysctl.d/99-firewalld.conf
EOF

# Configure static IP, gateway, and custom DNS
sudo tee /etc/NetworkManager/conf.d/dns.conf >/dev/null <<EOF
[main]
dns=none
systemd-resolved=false
EOF
sudo systemctl restart NetworkManager

# Flatpak setup
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# A cron job
(
  crontab -l 2>/dev/null
  echo "*/5 * * * * battery-alert.sh"
  echo "@daily $(which trash-empty) 30"
) | sort -u | uniq | crontab -
