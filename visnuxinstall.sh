#!/bin/bash
# =============================================================================
# Visnux Install Script — made by beamyyl (archinstall SUX!)
# Supports: UEFI or BIOS
# =============================================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }
ask()   { echo -e "${CYAN}[INPUT]${NC} $*"; }

restore_live() {
    if [ -n "${LIVE_PACMAN_CONF:-}" ] && [ -f "${LIVE_PACMAN_CONF}" ]; then
        cp "${LIVE_PACMAN_CONF}" /etc/pacman.conf
    fi
    if [ -n "${LIVE_MIRRORLIST:-}" ] && [ -f "${LIVE_MIRRORLIST}" ]; then
        cp "${LIVE_MIRRORLIST}" /etc/pacman.d/mirrorlist
    fi
}

trap restore_live EXIT

# =============================================================================
# Sanity checks
# =============================================================================
command -v pacman &>/dev/null || die "'pacman' not found. Are you booted from the visnux live ISO?"
[ "$(id -u)" -eq 0 ] || die "This installer must be run as root."

# =============================================================================
# Reminders
# =============================================================================
clear
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    VISNUX INSTALLER                      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
info "This script will install Visnux to /mnt."
info "Your partitions must be formatted and mounted BEFORE continuing."
echo ""
echo "  Mount commands (UEFI):"
echo ""
echo "    mount /dev/sdaR /mnt"
echo "    mkdir -p /mnt/boot/efi"
echo "    mount /dev/sdaB /mnt/boot/efi"
echo "    swapon /dev/sdaX"
echo ""
echo "  Mount commands (BIOS):"
echo ""
echo "    mount /dev/sdaR /mnt"
echo "    swapon /dev/sdaX"
echo ""
warn "If your partitions are NOT yet mounted, press Ctrl+C now,"
warn "mount them, then re-run this script."
echo ""
read -rp "  Press ENTER once your partitions are mounted..."
echo ""

mountpoint -q /mnt || die "/mnt is not mounted."
info "Root mount point verified."
echo ""

# =============================================================================
# Boot mode selection
# =============================================================================
info "============================================================"
info " BOOT MODE"
info "============================================================"
echo ""

while true; do
    ask "Boot mode — UEFI or BIOS?"
    ask "  1) UEFI  (modern systems, GPT disk)"
    ask "  2) BIOS  (legacy / older systems, MBR or GPT disk)"
    read -rp "  Choice [1/2]: " BOOT_CHOICE
    case "$BOOT_CHOICE" in
        1) BOOT_MODE="uefi"; break ;;
        2) BOOT_MODE="bios"; break ;;
        *) warn "Invalid choice. Enter 1 or 2." ;;
    esac
done
echo ""

if [ "$BOOT_MODE" = "uefi" ]; then
    mountpoint -q /mnt/boot/efi \
        || die "/mnt/boot/efi is not mounted. Mount your EFI partition and re-run."
    info "UEFI mode selected. EFI mount verified."
else
    info "BIOS mode selected."
    echo ""
    while true; do
        ask "Enter the disk to install GRUB to (e.g. /dev/sda, /dev/vda)."
        ask "Whole disk, NOT a partition."
        read -rp "  Install disk: " GRUB_DISK
        if [ -n "$GRUB_DISK" ] && [ -b "$GRUB_DISK" ]; then
            break
        fi
        warn "Invalid block device or empty. Please try again."
    done
    info "GRUB will be installed to: $GRUB_DISK"
fi
echo ""

# =============================================================================
# Declarative mode selection
# =============================================================================
info "============================================================"
info " INSTALL MODE"
info "============================================================"
echo ""

echo -e "${CYAN}[INPUT]${NC} Do you want to install Visnux in a declarative way?"
echo "  This installs VPK and uses /etc/visnux/visnux.conf."
echo "  !! If you will use declaratives, you *must* enable multilib (next question)."
echo "  y) Declarative (VPK)"
echo "  n) Traditional / imperative installer"
read -rp "  Choice [y/N]: " DECLARATIVE_CHOICE
USE_EXISTING_CONF="no"
if [[ "$DECLARATIVE_CHOICE" =~ ^[Yy]$ ]]; then
    DECLARATIVE_MODE="yes"

    echo ""
    ask "Do you want to use an already existing visnux.conf?"
    ask "  1) No  - generate one from your answers below"
    ask "  2) Yes - located in this folder as visnux.conf"
    read -rp "  Choice [1/2]: " CONF_CHOICE
    case "$CONF_CHOICE" in
        2)
            SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)"
            EXISTING_CONF="$SCRIPT_DIR/visnux.conf"
            [ -f "$EXISTING_CONF" ] || die "No visnux.conf found at $EXISTING_CONF"
            USE_EXISTING_CONF="yes"
            info "Using existing visnux.conf: $EXISTING_CONF"
            info "Desktop Environment selection will be skipped — it's defined in your visnux.conf."
            ;;
        *)
            USE_EXISTING_CONF="no"
            ;;
    esac
else
    DECLARATIVE_MODE="no"
fi
echo ""

# =============================================================================
# Multilib
# =============================================================================
while true; do
    ask "Enable the multilib repository (for 32-bit packages)? [Y/n]"
    read -rp "  Choice: " MULTILIB_CHOICE
    if [[ "$MULTILIB_CHOICE" =~ ^[Nn]$ ]]; then
        ENABLE_MULTILIB="no"; break
    elif [[ "$MULTILIB_CHOICE" =~ ^[Yy]$ ]] || [ -z "$MULTILIB_CHOICE" ]; then
        ENABLE_MULTILIB="yes"; break
    else
        warn "Please enter Y or n."
    fi
done
echo ""

# =============================================================================
# Init selection
# =============================================================================
info "============================================================"
info " INIT SYSTEM"
info "============================================================"
echo ""

while true; do
    ask "Init system?"
    ask "  1) systemd"
    ask "  2) dinit"
    ask "  3) openrc"
    read -rp "  Choice [1-3]: " INIT_CHOICE
    case "$INIT_CHOICE" in
        1) INIT_SYSTEM="systemd"; break ;;
        2) INIT_SYSTEM="dinit"; break ;;
        3) INIT_SYSTEM="openrc"; break ;;
        *) warn "Invalid choice. Enter 1, 2, or 3." ;;
    esac
done
echo ""

# =============================================================================
# Desktop Environment selection
# =============================================================================
if [ "$USE_EXISTING_CONF" = "yes" ]; then
    DESKTOP_ENV="(defined in visnux.conf)"
else
    info "============================================================"
    info " DESKTOP ENVIRONMENT"
    info "============================================================"
    echo ""

    while true; do
        ask "Desktop Environment?"
        ask "  1) KDE Plasma"
        ask "  2) Xfce4"
        ask "  3) Skip installing a Desktop Environment"
        read -rp "  Choice [1-3]: " DE_CHOICE
        case "$DE_CHOICE" in
            1) DESKTOP_ENV="kde"; break ;;
            2) DESKTOP_ENV="xfce"; break ;;
            3) DESKTOP_ENV="none"; break ;;
            *) warn "Invalid choice. Enter 1, 2, or 3." ;;
        esac
    done
    echo ""
fi

# =============================================================================
# System configuration
# =============================================================================
info "============================================================"
info " SYSTEM CONFIGURATION"
info "============================================================"
echo ""

while true; do
    ask "Enter a hostname for your new system."
    read -rp "  Hostname: " NEW_HOSTNAME
    if [ -n "$NEW_HOSTNAME" ]; then
        break
    fi
    warn "Hostname cannot be empty. Please try again."
done
echo ""

info "Configuration summary:"
echo "    Boot mode : $BOOT_MODE"
echo "    Init      : $INIT_SYSTEM"
echo "    Desktop   : $DESKTOP_ENV"
echo "    Multilib  : $ENABLE_MULTILIB"
echo "    Hostname  : $NEW_HOSTNAME"
echo ""
read -rp "  Press ENTER to continue..."
echo ""

# =============================================================================
# Base install
# =============================================================================
info "============================================================"
info " BASE INSTALL"
info "============================================================"
echo ""

if [ "$INIT_SYSTEM" = "systemd" ]; then
    command -v pacstrap &>/dev/null || die "'pacstrap' not found."

    info "Enabling parallel downloads on host..."
    sed -i 's/^#*ParallelDownloads = .*/ParallelDownloads = 12/' /etc/pacman.conf

    info "Installing keyrings and mirror ranking utilities on host..."
    pacman-key --init
    pacman-key --populate archlinux
    pacman -Sy archlinux-keyring --noconfirm
    pacman-key --init
    pacman-key --populate archlinux
    pacman -Sy rate-mirrors --noconfirm

    info "Ranking Arch mirrors..."
    rate-mirrors --allow-root arch | grep "https://" > /etc/pacman.d/mirrorlist
        if [ "$ENABLE_MULTILIB" = "yes" ]; then
        mkdir /mnt/etc -p
        cp /etc/pacman.conf /mnt/etc/pacman.conf
        cat >> /mnt/etc/pacman.conf <<'EOF'
[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
        fi
    info "Bootstrapping Visnux..."
    pacstrap /mnt base base-devel linux linux-firmware sof-firmware

else
    info "Preparing Artix repositories for pacstrap..."
    info "Configuring Arch repositories on live host..."
    if [ ! -f /etc/pacman.d/mirrorlist-arch ] || [ ! -s /etc/pacman.d/mirrorlist-arch ]; then
        mkdir -p /etc/pacman.d
        echo "Server = https://netcologne.de\$repo/os/\$arch" > /etc/pacman.d/mirrorlist-arch
    fi
    if ! grep -q '^\[extra\]$' /etc/pacman.conf; then
        cat >> /etc/pacman.conf <<'EOF'

[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
    fi

    info "Installing mirror ranking utilities on host..."
    pacman -Sy --noconfirm archlinux-keyring rate-mirrors

    ARTIX_BOOTSTRAP_CONF="/tmp/visnux-artix-bootstrap.conf"
    cat > "$ARTIX_BOOTSTRAP_CONF" <<EOF
[options]
Architecture = auto
Color
CheckSpace
ParallelDownloads = 12
SigLevel = Never

[system]
Server = https://mirror.netcologne.de/artix-linux/system/os/x86_64/
EOF

    info "Installing keyrings..."
    pacman --config "$ARTIX_BOOTSTRAP_CONF" -Sy --noconfirm artix-keyring
    
    info "Initializing local cryptographic keys..."
    pacman-key --init
    
    if [ ! -f /usr/share/pacman/keyrings/arch.gpg ] && [ -f /usr/share/pacman/keyrings/archlinux.gpg ]; then
        cp /usr/share/pacman/keyrings/archlinux.gpg /usr/share/pacman/keyrings/arch.gpg
    fi
    
    pacman-key --populate artix arch
    
    info "Ranking Artix mirrors..."
    mkdir -p /etc/pacman.d
    rate-mirrors --allow-root artix | grep -v "arkhost" | grep -v "garr.it" | grep "https://" > /etc/pacman.d/mirrorlist

    ARTIX_CONF="/tmp/visnux-artix.conf"
    cat > "$ARTIX_CONF" <<EOF
[options]
Architecture = auto
Color
CheckSpace
ParallelDownloads = 12
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[system]
Include = /etc/pacman.d/mirrorlist

[world]
Include = /etc/pacman.d/mirrorlist

[galaxy]
Include = /etc/pacman.d/mirrorlist
EOF

    info "Bootstrapping Visnux..."
    command -v pacstrap &>/dev/null || die "'pacstrap' not found."

    INIT_PKGS=""
    case "$INIT_SYSTEM" in
        openrc) INIT_PKGS="openrc elogind-openrc" ;;
        dinit)  INIT_PKGS="dinit elogind-dinit" ;;
    esac

    pacstrap -C "$ARTIX_CONF" /mnt base base-devel linux linux-firmware sof-firmware artix-keyring $INIT_PKGS

    info "Copying mirrorlists to the target system..."
    mkdir -p /mnt/etc/pacman.d
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    
    rate-mirrors --allow-root arch | grep "https://" > /etc/pacman.d/mirrorlist-arch
    cp /etc/pacman.d/mirrorlist-arch /mnt/etc/pacman.d/mirrorlist-arch

    info "Applying pacman cosmetic tweaks to chroot..."
    sed -i 's/^#*ParallelDownloads = .*/ParallelDownloads = 12/' /mnt/etc/pacman.conf
    sed -i '/^ParallelDownloads = 12/a Color\nILoveCandy' /mnt/etc/pacman.conf

    info "Installing Arch repository support inside the Artix chroot..."
    arch-chroot /mnt pacman -Sy --noconfirm artix-archlinux-support
    arch-chroot /mnt pacman-key --populate archlinux

    info "Adding Arch repositories to pacman.conf..."
    cat >> /mnt/etc/pacman.conf <<'EOF'

[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF

    if [ "$ENABLE_MULTILIB" = "yes" ]; then
        cat >> /mnt/etc/pacman.conf <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
    fi

fi

info "Enabling parallel downloads inside chroot..."
sed -i 's/^#*ParallelDownloads = .*/ParallelDownloads = 12/' /mnt/etc/pacman.conf

# =============================================================================
# Fstab
# =============================================================================
info "============================================================"
info " FSTAB"
info "============================================================"

command -v genfstab &>/dev/null || die "'genfstab' not found."
info "Generating /etc/fstab..."
genfstab -U /mnt > /mnt/etc/fstab

info "fstab contents:"
cat /mnt/etc/fstab
echo ""

# =============================================================================
# Existing visnux.conf
# =============================================================================
if [ "$USE_EXISTING_CONF" = "yes" ]; then
    info "============================================================"
    info " EXISTING VISNUX.CONF"
    info "============================================================"
    info "Copying existing visnux.conf into the new system..."
    mkdir -p /mnt/etc/visnux
    cp "$EXISTING_CONF" /mnt/etc/visnux/visnux.conf
    echo ""
fi

# =============================================================================
# In-chroot script
# =============================================================================
info "============================================================"
info " WRITING IN-CHROOT SCRIPT"
info "============================================================"

cat > /mnt/root/chroot-install.sh <<CHROOT_EOF
#!/bin/bash
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "\${GREEN}[CHROOT]\${NC}  \$*"; }
warn()  { echo -e "\${YELLOW}[CHROOT]\${NC}  \$*"; }

BOOT_MODE="${BOOT_MODE}"
INIT_SYSTEM="${INIT_SYSTEM}"
DESKTOP_ENV="${DESKTOP_ENV}"
NEW_HOSTNAME="${NEW_HOSTNAME}"
GRUB_DISK="${GRUB_DISK}"
DECLARATIVE_MODE="${DECLARATIVE_MODE}"
USE_EXISTING_CONF="${USE_EXISTING_CONF}"

hwclock --systohc

if [ "\${DECLARATIVE_MODE}" != "yes" ]; then
    pacman -Sy --noconfirm git
    pacman -S --noconfirm ttf-iosevka-nerd ttf-adwaitamono-nerd
    pacman -S --noconfirm fish flatpak
    pacman -S --noconfirm papirus-icon-theme
fi
mkdir -p /usr/share/icons/hicolor/scalable/apps/
mkdir -p /usr/share/pixmaps/

echo "\${NEW_HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   \${NEW_HOSTNAME}.localdomain \${NEW_HOSTNAME}
EOF

cat > /etc/os-release <<'EOF'
NAME="Visnux"
PRETTY_NAME="Visnux Linux"
ID=visnux
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;85;255;85"
HOME_URL="https://visnux.duckdns.org/"
DOCUMENTATION_URL="https://visnux.duckdns.org/"
LOGO=visnux
EOF

cat > /etc/lsb-release <<'EOF'
DISTRIB_ID="Visnux"
DISTRIB_RELEASE="rolling"
DISTRIB_DESCRIPTION="Visnux Linux"
EOF

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# =============================================================================
# Desktop / system packages
# =============================================================================

if [ "\${DECLARATIVE_MODE}" = "yes" ]; then
    mkdir -p /etc/visnux /var/lib/vpk

    if [ "\${USE_EXISTING_CONF}" = "yes" ]; then
        info "Using existing /etc/visnux/visnux.conf."
    else
        info "Declarative installation selected. Generating /etc/visnux/visnux.conf..."

        DESKTOP_METAPKGS=""
        DESKTOP_PKGS=""
        SERVICE_PKGS="networkmanager"
        ENABLED_SERVICES="NetworkManager"
        if [ "\${INIT_SYSTEM}" != "systemd" ]; then
            SERVICE_PKGS="\${SERVICE_PKGS} turnstile"
            if [ "\${INIT_SYSTEM}" = "openrc" ]; then
                ENABLED_SERVICES="\${ENABLED_SERVICES} turnstile"
            else
                ENABLED_SERVICES="\${ENABLED_SERVICES} turnstiled"
            fi
        fi

        if [ "\${DESKTOP_ENV}" = "kde" ]; then
            DESKTOP_METAPKGS="plasma"
            DESKTOP_PKGS="ark konsole dolphin xdg-desktop-portal-kde wl-clipboard"
        elif [ "\${DESKTOP_ENV}" = "xfce" ]; then
            DESKTOP_METAPKGS="xfce4"
            DESKTOP_PKGS="xfce4-whiskermenu-plugin ark xclip maim xfce4-pulseaudio-plugin"
        else
            info "Skipping Desktop Environment installation."
        fi

        if [ "\${DESKTOP_ENV}" != "none" ]; then
            SERVICE_PKGS="\${SERVICE_PKGS} sddm power-profiles-daemon pipewire wireplumber pipewire-pulse"
            ENABLED_SERVICES="\${ENABLED_SERVICES} sddm power-profiles-daemon"
        fi

        cat > /etc/visnux/visnux.conf <<EOF
# Visnux's configuration file

[kernel]
pkgs = { linux, linux-headers, linux-firmware, sof-firmware }

[bootmgr]
pkgs = { grub, efibootmgr }

[desktop]
metapkgs = { \${DESKTOP_METAPKGS} }
pkgs = { \${DESKTOP_PKGS} }

[fonts]
pkgs = { ttf-iosevka-nerd, ttf-adwaitamono-nerd }

[packages]
pkgs = { git, papirus-icon-theme, neovim, nano, sudo, fish, flatpak, fastfetch, kitty }

[services]
pkgs = { \${SERVICE_PKGS} }
enabled = { \${ENABLED_SERVICES} }

[drivers]
pkgs = { mesa, lib32-mesa, vulkan-intel, lib32-vulkan-intel, vulkan-radeon, lib32-vulkan-radeon, vulkan-nouveau, lib32-vulkan-nouveau, vulkan-swrast, lib32-vulkan-swrast, libva, intel-media-driver }

# User example
# [user:beamy]
# groups = { wheel, audio, video, input }
# shell = /usr/bin/fish
# [user-services]
# beamy = { pipewire, wireplumber, pipewire-pulse }

# Do NOT change the init line. If you wanna switch inits, clean reinstall is the safest way to do so.
init = \${INIT_SYSTEM}
EOF
    fi

    info "Fetching vpk from larphub..."
    sudo pacman -Sy git --noconfirm
    git clone https://github.com/realv1sta/larphub
    cp larphub/vpk /usr/bin/vpk
    chmod +x /usr/bin/vpk
    rm -rf larphub

    info "Synchronizing declarative package state..."
    vpk sync
else
# =============================================================================

if [ "\${INIT_SYSTEM}" = "systemd" ]; then

    if [ "\${DESKTOP_ENV}" = "kde" ]; then
        pacman -S plasma ark konsole dolphin xdg-desktop-portal-kde wl-clipboard kitty fastfetch sddm networkmanager neovim nano sudo power-profiles-daemon --noconfirm
        systemctl enable NetworkManager
        systemctl enable sddm --force
        pacman -Rnsdd plasma-bigscreen --noconfirm

    elif [ "\${DESKTOP_ENV}" = "xfce" ]; then
        pacman -S xfce4 xfce4-whiskermenu-plugin ark xclip maim xfce4-pulseaudio-plugin kitty fastfetch sddm networkmanager neovim nano sudo power-profiles-daemon --noconfirm
        systemctl enable NetworkManager
        systemctl enable sddm --force

    else
        info "Skipping Desktop Environment installation."
        pacman -S networkmanager neovim nano sudo --noconfirm
        systemctl enable NetworkManager
    fi

else

    if [ "\${DESKTOP_ENV}" = "kde" ]; then
        DE_PKGS="plasma konsole dolphin"
        DESKTOP_PKGS="kitty ark xdg-desktop-portal-kde fastfetch wl-clipboard sddm sddm-\${INIT_SYSTEM} power-profiles-daemon power-profiles-daemon-\${INIT_SYSTEM} pipewire pipewire-\${INIT_SYSTEM} pipewire-pulse pipewire-pulse-\${INIT_SYSTEM} wireplumber wireplumber-\${INIT_SYSTEM}"

    elif [ "\${DESKTOP_ENV}" = "xfce" ]; then
        DE_PKGS="xorg-server xfce4 xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin"
        DESKTOP_PKGS="kitty ark fastfetch sddm xclip maim sddm-\${INIT_SYSTEM} power-profiles-daemon power-profiles-daemon-\${INIT_SYSTEM} pipewire pipewire-\${INIT_SYSTEM} pipewire-pulse pipewire-pulse-\${INIT_SYSTEM} wireplumber wireplumber-\${INIT_SYSTEM}"

    else
        DE_PKGS=""
        DESKTOP_PKGS=""
        info "Skipping Desktop Environment installation."
    fi

    pacman -S \
        \${DE_PKGS} \
        \${DESKTOP_PKGS} \
        turnstile turnstile-\${INIT_SYSTEM} \
        networkmanager networkmanager-\${INIT_SYSTEM} \
        dbus dbus-\${INIT_SYSTEM} \
        neovim nano sudo \
        --noconfirm

    case "\${INIT_SYSTEM}" in
        openrc)
            rc-update add dbus default
            rc-update add elogind default
            rc-update add NetworkManager default
            rc-update add turnstile default
            if [ "\${DESKTOP_ENV}" != "none" ]; then
                rc-update add sddm default
                rc-update add power-profiles-daemon default
            fi
            ;;

        dinit)
            ln -sf ../dbus /etc/dinit.d/boot.d/
            ln -sf ../elogind /etc/dinit.d/boot.d/
            ln -sf ../NetworkManager /etc/dinit.d/boot.d/
            ln -sf ../turnstiled /etc/dinit.d/boot.d/
            if [ "\${DESKTOP_ENV}" != "none" ]; then
                ln -sf ../sddm /etc/dinit.d/boot.d/
                ln -sf ../power-profiles-daemon /etc/dinit.d/boot.d/
            fi
            ;;
    esac

fi


fi
# =============================================================================
# DRIVERS
# =============================================================================

if [ "\${DECLARATIVE_MODE}" = "yes" ]; then
    info "Drivers are managed by VPK."
else

info "Installing mesa drivers for intel, amd and nouveau..."
sudo pacman -S mesa lib32-mesa \
  vulkan-intel lib32-vulkan-intel \
  vulkan-radeon lib32-vulkan-radeon \
  vulkan-nouveau lib32-vulkan-nouveau \
  vulkan-swrast lib32-vulkan-swrast \
  libva intel-media-driver --noconfirm --needed


fi
# =============================================================================
# GRUB
# =============================================================================

info "Installing GRUB..."
if [ "\${DECLARATIVE_MODE}" = "yes" ]; then
    if [ "\${BOOT_MODE}" = "uefi" ]; then
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Visnux --recheck
    else
        grub-install --recheck "\${GRUB_DISK}"
    fi
else
    if [ "\${BOOT_MODE}" = "uefi" ]; then
        pacman -S --noconfirm grub efibootmgr
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Visnux --recheck
    else
        pacman -S --noconfirm grub
        grub-install --recheck "\${GRUB_DISK}"
    fi
fi
sed -i 's/GRUB_DISTRIBUTOR="Arch"/GRUB_DISTRIBUTOR="Visnux"/' /etc/default/grub
sed -i 's/GRUB_DISTRIBUTOR="Artix"/GRUB_DISTRIBUTOR="Visnux"/' /etc/default/grub

git clone https://github.com/realv1sta/larphub
cp -r larphub/neveraskmewhatthisis/Office-sidebar /boot/grub/themes
cp larphub/visnux.svg /usr/share/icons/hicolor/scalable/apps/visnux.svg
cp larphub/visnux.png /usr/share/pixmaps/visnux.png
mkdir -p ~/.config/fastfetch
chmod +x larphub/colorlogo.sh && cd larphub/ && ./colorlogo.sh > ~/.config/fastfetch/logo.txt
cp neveraskmewhatthisis/config.jsonc ~/.config/fastfetch/
mkdir -p /etc/skel/.config
cp -r neveraskmewhatthisis/xfce4 /etc/skel/.config/
cp -r neveraskmewhatthisis/fish /etc/skel/.config/
cp neveraskmewhatthisis/plasma-org.kde.plasma.desktop-appletsrc /etc/skel/.config/
cp -r neveraskmewhatthisis/otherconfigs/* /etc/skel/.config
git clone https://github.com/beamyyl/fastfetch
cp -r fastfetch/* /etc/skel/.config/
./colorlogo.sh > /etc/skel/.config/fastfetch/logo.txt
mkdir -p /usr/share/wallpapers/
mkdir -p /usr/share/backgrounds/visnux
cp -r walls/visnux-walls/* /usr/share/wallpapers/
cp -r walls/visnux-walls/* /usr/share/backgrounds/visnux/
cd ..
rm -rf larphub

fallocate -l 8G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

echo 'GRUB_THEME=/boot/grub/themes/Office-sidebar/theme.txt' | tee -a /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
info "============================================================"
info " Set the ROOT password:"
info "============================================================"

while ! passwd; do
    warn "Password change failed or passwords did not match. Please try again."
done

echo ""
echo -e "\${CYAN}[INPUT]\${NC} Would you like to create a new user? (y/n)"
read -rp "  Choice: " CREATE_USER

if [[ "\${CREATE_USER}" =~ ^[Yy]$ ]]; then

    while true; do
        echo -e "\${CYAN}[INPUT]\${NC} Enter the new username:"
        read -rp "  Username: " NEW_USER

        if [ -n "\${NEW_USER}" ]; then
            break
        fi

        warn "Username cannot be empty. Please try again."
    done

    echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
    chmod 440 /etc/sudoers.d/wheel

    useradd -m -G wheel,audio,video,input -s /usr/bin/fish "\${NEW_USER}"

    info "User '\${NEW_USER}' created and added to: wheel, audio, video, input"
    info "Set a password for '\${NEW_USER}':"

    while ! passwd "\${NEW_USER}"; do
        warn "Password change failed or passwords did not match. Please try again."
    done

    info "Cloning and setting up dotfiles for '\${NEW_USER}'..."
    su - "\${NEW_USER}" -c "cd ~ && mkdir -p ~/.config && git clone https://github.com/beamyyl/maindots && cp -r maindots/* ~/.config/ && rm -rf maindots && [ ! -f ~/.config/fastfetch/config.jsonc ] || sed -i 's/\"top\": 2/\"top\": 1/' ~/.config/fastfetch/config.jsonc"
    info "Dotfiles installed successfully."
    info "User setup complete."

    if [ "\${DECLARATIVE_MODE}" = "yes" ]; then
        cat >> /etc/visnux/visnux.conf <<EOF

[user:\${NEW_USER}]
groups = { wheel, audio, video, input }
shell = /usr/bin/fish
EOF
        info "Added '\${NEW_USER}' to /etc/visnux/visnux.conf."
        info "VPK now owns the declarative state of this user."
        vpk sync
    fi

elif [[ "\${CREATE_USER}" =~ ^[Nn]$ ]]; then
    info "Skipping user creation."
else
    warn "Invalid choice '\${CREATE_USER}'. Skipping user creation."
fi

echo ""
info "============================================================"
info " Installation complete!"
info "============================================================"
info " Exit the chroot and reboot:"
info ""
info "    exit"
info "    umount -R /mnt"
info "    reboot"
info "============================================================"
CHROOT_EOF

chmod +x /mnt/root/chroot-install.sh
info "In-chroot script written."
echo ""

# =============================================================================
# Chroot
# =============================================================================
info "============================================================"
info " ENTERING CHROOT"
info "============================================================"
echo ""

arch-chroot /mnt /bin/bash /root/chroot-install.sh

# =============================================================================
# Cleanup
# =============================================================================
info "============================================================"
info " CLEANUP"
info "============================================================"

rm -f /mnt/root/chroot-install.sh

if [ "$INIT_SYSTEM" != "systemd" ]; then
    restore_live
    rm -f \
        "$ARTIX_BOOTSTRAP_CONF" \
        "$ARTIX_CONF"
fi

info "Unmounting filesystems..."
umount -R /mnt 2>/dev/null || true

echo ""
info "============================================================"
info " All done! Remove your installation media and reboot."
info "============================================================"
