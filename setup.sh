#!/usr/bin/env bash
set -euo pipefail

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
## Adding repos
sudo dnf copr enable solopasha/hyprland
sudo dnf copr enable maximizerr/SwayAura

# pacstrap of fedora
xargs sudo dnf install -y <pkglist.txt

# Ly Setup
sudo dnf install -y kernel-devel pam-devel libxcb-devel zig
git clone https://codeberg.org/AnErrupTion/ly.git ~/Downloads/
cd ~/Downloads/
zig build
sudo zig build installexe
sudo systemctl enable ly.service
sudo systemctl disable getty@tty2.service

# eza
curl -LO https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz
tar -xzf eza_x86_64-unknown-linux-gnu.tar.gz
sudo mv eza /usr/local/bin/
sudo chmod +x /usr/local/bin/eza
# Iosevka
mkdir -p ~/.local/share/fonts/iosevka
cd ~/.local/share/fonts/iosevka
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IosevkaTerm.zip
unzip IosevkaTerm.zip
rm IosevkaTerm.zip
# wikiman
RPM_URL=$(curl -s https://api.github.com/repos/filiparag/wikiman/releases/latest \
    | grep "browser_download_url" \
    | grep -E "wikiman.*\.rpm" \
    | cut -d '"' -f 4)
curl -LO "$RPM_URL"
RPM_FILE="${RPM_URL##*/}"
sudo dnf install -y "$RPM_FILE"
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
    # Systemd boot setup
    dracut --force
    # grub2-mkconfig -o /boot/grub2/grub.cfg

    # Variables
    EFI_DIR="/boot/efi"
    LOADER_DIR="$EFI_DIR/loader"
    ENTRIES_DIR="$LOADER_DIR/entries"
    ROOT_UUID=$(blkid -s UUID -o value /dev/disk/by-label/root 2>/dev/null || findmnt / -no SOURCE | xargs blkid -s UUID -o value)


    # setup systemd boot
    bootctl --path="$EFI_DIR" install
    mkdir -p "$LOADER_DIR"
cat > "$LOADER_DIR/loader.conf" <<EOF
default fedora
timeout 3
console-mode max
editor no
EOF

    mkdir -p "$ENTRIES_DIR"
cat > "$ENTRIES_DIR/fedora.conf" <<EOF
title Fedora 42
linux /vmlinuz
initrd /initramfs.img
options root=UUID=$ROOT_UUID rw splash
EOF

    # Update kernel/initramfs symlinks
    KERNEL_IMG=$(find /boot -maxdepth 1 -type f -name 'vmlinuz-*.x86_64' | sort -V | tail -n1)
    INITRD_IMG=$(find /boot -maxdepth 1 -type f -name 'initramfs-*.img' ! -name '*rescue*' | sort -V | tail -n1)
    ln -sf "$KERNEL_IMG" /boot/vmlinuz
    ln -sf "$INITRD_IMG" /boot/initramfs.img

    # Optional: Remove GRUB (commented out)
    # echo "[+] Removing GRUB (optional)..."
    # dnf remove -y grub2 grub2-efi grub2-tools

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
    sudo mkdir -p /etc/systemd/zram-generator.conf.d
    printf "[zram0]\nzram-size = min(ram / 2, 4096)\ncompression-algorithm = zstd\nswap-priority = 100\nfs-type = swap\n" \
        | sudo tee /etc/systemd/zram-generator.conf.d/00-zram.conf > /dev/null

    # services
    # rfkill unblock bluetooth
    # modprobe btusb || true
    systemctl enable NetworkManager NetworkManager-dispatcher
    if [[ "$hardware" == "hardware" ]]; then
        systemctl enable ly fstrim.timer acpid cronie ananicy-cpp libvirtd.socket cups ipp-usb docker.socket sshd
        if [[ "$extra" == "laptop" || "$extra" == "bluetooth" ]]; then
            systemctl enable bluetooth
        fi
        if [[ "$extra" == "laptop" ]]; then
            systemctl enable tlp
        fi
    else
        systemctl enable ly cronie ananicy-cpp sshd
    fi
    systemctl mask systemd-rfkill systemd-rfkill.socket
    systemctl disable NetworkManager-wait-online.service systemd-networkd.service systemd-resolved

    # prevent networkmanager from using systemd-resolved
    mkdir -p /etc/networkmanager/conf.d
    echo -e "[main]\nsystemd-resolved=false" | tee /etc/networkmanager/conf.d/no-systemd-resolved.conf >/dev/null

    # set dns handling to 'default'
    echo -e "[main]\ndns=default" | tee /etc/networkmanager/conf.d/dns.conf >/dev/null

    # firewalld setup
    firewall-cmd --set-default-zone=public
    firewall-cmd --permanent --remove-service=dhcpv6-client
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-service=ssh
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
    # echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-firewalld.conf
    # sudo sysctl -p /etc/sysctl.d/99-firewalld.conf
EOF

# Flatpak setup
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Configure static IP, gateway, and custom DNS
sudo tee /etc/NetworkManager/conf.d/dns.conf >/dev/null <<EOF
[main]
dns=none
EOF
sudo tee /etc/resolv.conf >/dev/null <<EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
sudo systemctl restart NetworkManager

# A cron job
(
    crontab -l 2>/dev/null
    echo "*/5 * * * * battery-alert.sh"
    echo "@daily $(which trash-empty) 30"
) | sort -u | crontab -
