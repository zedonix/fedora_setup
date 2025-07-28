#!/usr/bin/env bash
set -euo pipefail

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
    sed -n '1p;3p' ~/fedora_setup/pkgs.txt | tr ' ' '\n' | grep -v '^$' >~/fedora_setup/pkglist.txt
    ;;
hardware)
    # For hardware:max, we will add lines 5 and/or 6 later based on $extra
    sed -n '1,4p' ~/fedora_setup/pkgs.txt | tr ' ' '\n' | grep -v '^$' >~/fedora_setup/pkglist.txt
    ;;
esac

# For hardware:max, add lines 5 and/or 6 based on $extra
if [[ "$hardware" == "hardware" ]]; then
    case "$extra" in
    laptop)
        # Add both line 5 and 6
        sed -n '5,6p' ~/fedora_setup/pkgs.txt | tr ' ' '\n' | grep -v '^$' >>~/fedora_setup/pkglist.txt
        ;;
    bluetooth)
        # Add only line 5
        sed -n '5p' ~/fedora_setup/pkgs.txt | tr ' ' '\n' | grep -v '^$' >>~/fedora_setup/pkglist.txt
        ;;
    none)
        # Do not add line 5 or 6
        ;;
    esac
fi

# Install stuff
## Adding repos
sudo dnf copr enable solopasha/hyprland

## External Install
curl -LO https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz
gunzip -c eza_x86_64-unknown-linux-gnu.tar.gz | cpio -idmv
sudo mv eza /usr/local/bin/
sudo chmod +x /usr/local/bin/eza

xargs sudo dnf install -y <~/fedora_setup/pkglist.txt
sudo dracut --force
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

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

# Copy config and dotfiles as the user
mkdir -p ~/Documents/default
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

# Clone fedora_setup
if ! git clone https://github.com/zedonix/fedora_setup.git ~/Documents/default/fedora_setup; then
    echo "Failed to clone fedora_setup. Continuing..."
fi
sudo bash <<'EOF'
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
EOF

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
    ln -sf ~/Documents/default/dotfiles/.gtk-bookmarks ~/.gtk-bookmarks || true

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
sudo bash <<'EOF'
    # tldr wiki setup
    curl -L "https://raw.githubusercontent.com/filiparag/wikiman/master/Makefile" -o "wikiman-makefile"
    make -f ./wikiman-makefile source-tldr
    make -f ./wikiman-makefile source-install
    make -f ./wikiman-makefile clean
EOF

# zram config
mkdir -p /etc/systemd/zram-generator.conf.d
cat >/etc/systemd/zram-generator.conf.d/00-zram.conf <<EOF
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# Services
# rfkill unblock bluetooth
# modprobe btusb || true
sudo bash <<'EOF'
systemctl enable NetworkManager NetworkManager-dispatcher
if [[ "$howMuch" == "max" ]]; then
    if [[ "$hardware" == "hardware" ]]; then
        systemctl enable ly fstrim.timer acpid cronie ananicy-cpp libvirtd.socket cups ipp-usb docker.socket sshd
    else
        systemctl enable ly cronie ananicy-cpp sshd cronie
    fi
    if [[ "$extra" == "laptop" || "$extra" == "bluetooth" ]]; then
        systemctl enable bluetooth
    fi
    if [[ "$extra" == "laptop" ]]; then
        systemctl enable tlp
    fi
fi
systemctl mask systemd-rfkill systemd-rfkill.socket
systemctl disable NetworkManager-wait-online.service systemd-networkd.service systemd-resolved

# Prevent NetworkManager from using systemd-resolved
mkdir -p /etc/NetworkManager/conf.d
echo -e "[main]\nsystemd-resolved=false" | tee /etc/NetworkManager/conf.d/no-systemd-resolved.conf >/dev/null

# Set DNS handling to 'default'
echo -e "[main]\ndns=default" | tee /etc/NetworkManager/conf.d/dns.conf >/dev/null
EOF

# firewalld setup
sudo firewall-cmd --set-default-zone=public
sudo firewall-cmd --permanent --remove-service=dhcpv6-client
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.0/24" accept'
sudo firewall-cmd --set-log-denied=all
# Create and assign a zone for virbr0
sudo firewall-cmd --permanent --new-zone=libvirt
sudo firewall-cmd --permanent --zone=libvirt --add-interface=virbr0
# Allow DHCP (ports 67, 68 UDP) and DNS (53 UDP)
sudo firewall-cmd --permanent --zone=libvirt --add-port=67/udp
sudo firewall-cmd --permanent --zone=libvirt --add-port=68/udp
sudo firewall-cmd --permanent --zone=libvirt --add-port=53/udp
# Enable masquerading for routed traffic (NAT)
sudo firewall-cmd --permanent --add-masquerade
sudo firewall-cmd --reload
sudo systemctl enable firewalld
# echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-firewalld.conf
# sudo sysctl -p /etc/sysctl.d/99-firewalld.conf

# Flatpak setup
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Libvirt setup
sudo virsh net-autostart default
sudo virsh net-start default

# Configure static IP, gateway, and custom DNS
nmcli con mod "Wired connection 1" ipv4.dns "1.1.1.1,1.0.0.1"
# 8.8.8.8,8.8.4.4
nmcli con mod "Wired connection 1" ipv4.ignore-auto-dns yes

# Apply changes
nmcli con down "Wired connection 1"
nmcli con up "Wired connection 1"

# A cron job
(
    crontab -l 2>/dev/null
    echo "*/5 * * * * battery-alert.sh"
    echo "@daily $(which trash-empty) 30"
) | sort -u | crontab -
