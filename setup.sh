#!/usr/bin/env bash
set -euo pipefail

# Redirect all output (stdout & stderr) into the user’s home directory log
# LOGFILE="${HOME}/fedora_setup.log"
# : >"${LOGFILE}"
# exec > >(tee -a "$LOGFILE") 2>&1

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Variable set
username=piyush
CHROOT="fedora-42-x86_64"

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
gpgcheck=True
EOF
sudo dnf clean all
sudo dnf makecache
sudo dnf upgrade --refresh
## Adding repos
sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf copr enable solopasha/hyprland
sudo dnf copr enable maximizerr/SwayAura:fedora-42-x86_64
sudo dnf makecache

# pacstrap of fedora
xargs sudo dnf install -y <pkglist.txt

cd "$(mktemp -d)"
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
cargo install starship --locked
cargo install eza

# Copy config and dotfiles as the user
mkdir -p ~/Downloads ~/Documents ~/Public ~/Templates ~/Videos ~/Pictures/Screenshots ~/.config
mkdir -p ~/Projects/work ~/Projects/sandbox
mkdir -p ~/Knowledge/wiki ~/Knowledge/reference ~/Knowledge/notes
mkdir -p ~/.local/bin ~/.cache/cargo-target ~/.local/state/bash ~/.local/state/zsh
touch ~/.local/state/bash/history ~/.local/state/zsh/history

git clone https://github.com/zedonix/scripts.git ~/Projects/personal/scripts
git clone https://github.com/zedonix/dotfiles.git ~/Projects/personal/dotfiles
git clone https://github.com/zedonix/archsetup.git ~/Projects/personal/archsetup
git clone https://github.com/zedonix/notes.git ~/Projects/personal/notes
git clone https://github.com/zedonix/GruvboxGtk.git ~/Projects/personal/GruvboxGtk
git clone https://github.com/zedonix/GruvboxQT.git ~/Projects/personal/GruvboxQT
git clone https://github.com/zedonix/fedora_setup.git ~/Projects/personal/fedora_setup
git clone https://github.com/CachyOS/ananicy-rules.git ~/Downloads/ananicy-rules

if [[ -d ~/Projects/personal/dotfiles ]]; then
  cp ~/Projects/personal/dotfiles/.config/sway/archLogo.png ~/Pictures/ 2>/dev/null || true
  cp ~/Projects/personal/dotfiles/pics/* ~/Pictures/ 2>/dev/null || true
  cp -r ~/Projects/personal/dotfiles/.local/share/themes/Gruvbox-Dark ~/.local/share/themes/ 2>/dev/null || true
  ln -sf ~/Projects/personal/dotfiles/.bashrc ~/.bashrc 2>/dev/null || true
  ln -sf ~/Projects/personal/dotfiles/.zshrc ~/.zshrc 2>/dev/null || true

  for link in ~/Projects/personal/dotfiles/.config/*; do
    ln -sf "$link" ~/.config/ 2>/dev/null || true
  done
  for link in ~/Projects/personal/scripts/bin/*; do
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
  ln -sf /home/$username/Projects/personal/dotfiles/.bashrc ~/.bashrc 2>/dev/null || true
  ln -sf /home/$username/Projects/personal/dotfiles/.zshrc ~/.zshrc 2>/dev/null || true
  ln -sf /home/$username/Projects/personal/dotfiles/.config/nvim/ ~/.config

  # Setup QT theme
  THEME_SRC="/home/$username/Projects/personal/GruvboxQT/"
  THEME_DEST="/usr/share/Kvantum/Gruvbox"
  mkdir -p "$THEME_DEST"
  cp "$THEME_SRC/gruvbox-kvantum.kvconfig" "$THEME_DEST/Gruvbox.kvconfig" 2>/dev/null || true
  cp "$THEME_SRC/gruvbox-kvantum.svg" "$THEME_DEST/Gruvbox.svg" 2>/dev/null || true

  # Install CachyOS Ananicy Rules
  ANANICY_RULES_SRC="/home/$username/Downloads/ananicy-rules"
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
  ln -sf "/home/$username/Projects/personal/dotfiles/policies.json" /etc/firefox/policies/policies.json 2>/dev/null || true

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
  systemctl enable NetworkManager NetworkManager-dispatcher greetd crond ananicy-cpp
  if [[ "$hardware" == "hardware" ]]; then
      systemctl enable fstrim.timer acpid libvirtd.socket cups ipp-usb docker.socket
      if [[ "$extra" == "laptop" || "$extra" == "bluetooth" ]]; then
          systemctl enable bluetooth
      fi
      if [[ "$extra" == "laptop" ]]; then
          systemctl enable tlp
      fi
  fi
  systemctl mask systemd-rfkill systemd-rfkill.socket
  systemctl disable NetworkManager-wait-online.service systemd-networkd.service systemd-resolved getty@tty2

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
) | crontab -
