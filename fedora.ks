#version=DEVEL
# Fedora Everything ISO
cdrom

#### 1) Localization & Time
lang en_US.UTF-8
keyboard us
timezone Asia/Kolkata --utc
authselect select sssd --force

#### 2) Security
selinux --enforcing

#### 3) Authentication (interactive)
# No 'rootpw' → installer will ask.
# No 'network --hostname' → installer will ask.

#### 4) User Account (interactive password)
user --name=piyush --groups=wheel --shell=/bin/bash

#### 5) Networking
network --bootproto=dhcp --device=link --hostname=fedoraPC

#### 6) Bootloader: install GRUB to EFI as fallback
# bootloader --bootloader-id=Fedora --location=uefi --timeout=5

#### 7) Partitioning: GPT + interactive
# zerombr
# clearpart --all --initlabel
# No 'part' → installer prompts you to create an EFI partition, root, swap, etc.

#### 8) Default target → graphical (for ly DM)
# Will switch in %post.

%packages --nobase
@core
@kernel
@development-tools
kernel
kernel-headers
efibootmgr
os-prober
sudo
zram-generator
NetworkManager
git
git-delta
reflector
exfat-utils
mtools
dosfstools
neovim
bash-completion
zoxide
linux-firmware
microcode_ctl
acpid
acpi
borg
ntfs-3g
inotify-tools
openssh-server
ncdu
fzf
github-cli
ripgrep
sqlite
cronie
ufw
trash-cli
curl
wget
playerctl
ffmpeg
imagemagick
man-db
man-pages
tldr
pipewire
wireplumber
pipewire-pulseaudio
wf-recorder
xorg-xwayland
xdg-desktop-portal-wlr
xdg-desktop-portal-gtk
ly
sway
swaybg
swaylock
swayidle
kanshi
discord
firefox
zathura
pcmanfm
qbittorrent
mpv
fuzzel
qalculate-gtk
foot
htop
tmux
asciinema
yt-dlp
tesseract
papirus-icon-theme
google-noto-sans-fonts
qt6-wayland
kvantum
mako
grim
slurp
texlive-scheme-full
pandoc
nodejs
npm
python3-pip
lua
luarocks
%end

%post --log=/root/ks-post.log
# 1) Set graphical.target for ly DM
systemctl set-default graphical.target

# 2) Enable services
systemctl enable NetworkManager cronie sshd libvirtd bluetooth ly

# 3) Add Flathub remote
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 4) Install systemd‑boot into the EFI System Partition
#    Assumes your EFI is mounted at /boot/efi by Anaconda.
bootctl --path=/boot/efi install

#    Create loader config
cat > /boot/efi/loader/loader.conf << 'EOF'
default fedora
EOF

#    Generate an entry for your Fedora root
rootdev=$(findmnt / -o SOURCE -n)
rootuuid=$(blkid -s UUID -o value "$rootdev")
cat > /boot/efi/loader/entries/fedora.conf << EOF
title   Fedora Linux
linux   /vmlinuz
initrd  /initramfs
options root=UUID=${rootuuid} ro quiet
EOF

su - piyush -c '
  set -e
    mkdir -p ~/Documents/default

username="piyush"
    # Clone scripts
    if ! git clone https://github.com/zedonix/scripts.git ~/Documents/default/scripts; then
      echo "Failed to clone scripts. Continuing..."
    fi
    # Clone dotfiles
    if ! git clone https://github.com/zedonix/dotfiles.git ~/Documents/default/dotfiles; then
      echo "Failed to clone dotfiles. Continuing..."
    fi

    # Clone archsetup
    if ! git clone https://github.com/zedonix/archsetup.git ~/Documents/default/archsetup; then
      echo "Failed to clone archsetup. Continuing..."
    fi

    # Clone Notes
    if ! git clone https://github.com/zedonix/notes.git ~/Documents/default/notes; then
      echo "Failed to clone ananicy-rules. Continuing..."
    fi

    # Clone ananicy-rules
    if ! git clone https://github.com/CachyOS/ananicy-rules.git ~/Documents/default/ananicy-rules; then
      echo "Failed to clone ananicy-rules. Continuing..."
    fi

    # Clone GruvboxGtk
    if ! git clone https://github.com/zedonix/GruvboxGtk.git ~/Documents/default/GruvboxGtk; then
      echo "Failed to clone GruvboxGtk. Continuing..."
    fi

    # Clone GruvboxQT
    if ! git clone https://github.com/zedonix/GruvboxQT.git ~/Documents/default/GruvboxQT; then
      echo "Failed to clone GruvboxQT. Continuing..."
    fi

  # Setup QT theme
  THEME_SRC="/home/$username/Documents/default/GruvboxQT/"
  THEME_DEST="/usr/share/Kvantum/Gruvbox"
  mkdir -p "$THEME_DEST"
  cp "$THEME_SRC/gruvbox-kvantum.kvconfig" "$THEME_DEST/Gruvbox.kvconfig" 2>/dev/null || true
  cp "$THEME_SRC/gruvbox-kvantum.svg" "$THEME_DEST/Gruvbox.svg" 2>/dev/null || true

  mkdir -p ~/Downloads ~/Documents/projects ~/Public ~/Templates/wiki ~/Videos ~/Pictures/Screenshots ~/.config ~/.local/state/bash ~/.local/state/zsh
  mkdir -p ~/.local/share/npm ~/.cache/npm ~/.config/npm/config ~/.local/bin
  touch ~/.local/state/bash/history ~/.local/state/zsh/history ~/Templates/wiki/index.md

  # Copy and link files (only if dotfiles exists)
  if [[ -d ~/Documents/default/dotfiles ]]; then
    cp ~/Documents/default/dotfiles/.config/sway/archLogo.png ~/Pictures/ 2>/dev/null || true
    cp ~/Documents/default/dotfiles/pics/* ~/Pictures/ 2>/dev/null || true
    cp -r ~/Documents/default/dotfiles/.local/share/themes/Gruvbox-Dark ~/.local/share/themes/ 2>/dev/null || true
    ln -sf ~/Documents/default/dotfiles/.bashrc ~/.bashrc 2>/dev/null || true
    ln -sf ~/Documents/default/dotfiles/.zshrc ~/.zshrc 2>/dev/null || true
    ln -sf ~/Documents/default/dotfiles/.gtk-bookmarks ~/.git-bookmarks || true

    for link in ~/Documents/default/dotfiles/.config/*; do
      ln -sf "$link" ~/.config/ 2>/dev/null || true
    done
    for link in ~/Documents/default/scripts/bin/*; do
      ln -sf "$link" ~/.local/bin 2>/dev/null || true
    done
  fi

  # Clone tpm
  if ! git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm; then
    echo "Failed to clone tpm. Continuing..."
  fi
'
# want to run in root

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
fi

  # tldr wiki setup
  curl -L "https://raw.githubusercontent.com/filiparag/wikiman/master/Makefile" -o "wikiman-makefile"
  make -f ./wikiman-makefile source-tldr
  make -f ./wikiman-makefile source-install
  make -f ./wikiman-makefile clean

# zram config
# Get total memory in MiB
TOTAL_MEM=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
ZRAM_SIZE=$((TOTAL_MEM / 2))

# Create zram config
mkdir -p /etc/systemd/zram-generator.conf.d

cat >/etc/systemd/zram-generator.conf.d/00-zram.conf <<EOF
[zram0]
zram-size = ${ZRAM_SIZE}
compression-algorithm = zstd #lzo-rle
swap-priority = 100
fs-type = swap
EOF


# Prevent NetworkManager from using systemd-resolved
mkdir -p /etc/NetworkManager/conf.d
echo -e "[main]\nsystemd-resolved=false" | tee /etc/NetworkManager/conf.d/no-systemd-resolved.conf >/dev/null

# Set DNS handling to 'default'
echo -e "[main]\ndns=default" | tee /etc/NetworkManager/conf.d/dns.conf >/dev/null

# 7) Mask unwanted units
systemctl mask systemd-rfkill systemd-rfkill.socket
systemctl disable NetworkManager-wait-online.service systemd-networkd.service systemd-resolved

%end
