#!/bin/bash

# made by king dudas the THIRD (The SECOND disciple)
# Beamy pls go see if this work
# i cant test this in vm idk why
# ily daddy

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
cyan='\033[0;36m'
nc='\033[0m'

infoMsg() { echo -e "${green}[INFO]${nc}  $*"; }
warnMsg() { echo -e "${yellow}[WARN]${nc}  $*"; }
errMsg()  { echo -e "${red}[FAIL]${nc}  $*"; }

stateDir="/var/lib/visnux-update"
stateFile="${stateDir}/last-commit"
workDir=""
updateFailed=0
grubChanged=0

cleanupFn() {
    if [ -n "$workDir" ] && [ -d "$workDir" ]; then
        rm -rf "$workDir"
    fi
}

trap cleanupFn EXIT

if [ "$(id -u)" -ne 0 ]; then
    infoMsg "root privileges required, re-running with sudo..."
    exec sudo "$0" "$@"
fi

if ! command -v git >/dev/null 2>&1; then
    errMsg "'git' not found. install it first: pacman -S git"
    exit 1
fi

if ! command -v flock >/dev/null 2>&1; then
    errMsg "'flock' not found. install util-linux first."
    exit 1
fi

if ! mkdir -p "$stateDir"; then
    errMsg "failed to create ${stateDir}."
    exit 1
fi

if ! touch "${stateDir}/.writetest"; then
    errMsg "no write access to ${stateDir}."
    exit 1
fi

rm -f "${stateDir}/.writetest"

exec 9>/run/visnux-update.lock

if ! flock -n 9; then
    errMsg "another visnux update is already running."
    exit 1
fi

echo ""
echo -e "${cyan}=== visnux system update ===${nc}"
echo ""

workDir="$(mktemp -d /tmp/visnux-update.XXXXXX)"

if [ ! -d "$workDir" ]; then
    errMsg "failed to create temporary directory."
    exit 1
fi

larphubDir="${workDir}/larphub"

infoMsg "fetching latest larphub..."

if ! git clone --quiet --depth 1 \
    https://github.com/realv1sta/larphub \
    "$larphubDir"; then

    errMsg "failed to clone larphub. check your internet connection."
    exit 1
fi

if [ ! -f "${larphubDir}/visnuxinstall.sh" ]; then
    errMsg "repository does not appear to be a visnux repository."
    exit 1
fi

latestCommit="$(git -C "$larphubDir" rev-parse HEAD 2>/dev/null)"

if [ -z "$latestCommit" ]; then
    errMsg "failed to determine latest commit."
    exit 1
fi

lastCommit=""

if [ -f "$stateFile" ]; then
    lastCommit="$(head -n 1 "$stateFile")"
fi

if [ "$latestCommit" = "$lastCommit" ]; then
    infoMsg "already up to date (commit ${latestCommit:0:8})."
    exit 0
fi

if [ -n "$lastCommit" ]; then
    infoMsg "update available: ${lastCommit:0:8} -> ${latestCommit:0:8}"
else
    infoMsg "no previous update recorded. performing initial sync."
fi

echo ""

if [ -d "${larphubDir}/neveraskmewhatthisis/Office-sidebar" ]; then
    infoMsg "updating grub theme..."

    grubThemeSource="${larphubDir}/neveraskmewhatthisis/Office-sidebar"
    grubThemeTemp="${workDir}/Office-sidebar"
    grubThemeDir="/boot/grub/themes/Office-sidebar"
    grubThemeBackup="${workDir}/Office-sidebar.old"

    if ! cp -a "$grubThemeSource" "$grubThemeTemp"; then
        errMsg "failed to prepare grub theme."
        updateFailed=1
    else
        mkdir -p /boot/grub/themes

        if [ -d "$grubThemeDir" ]; then
            if ! cp -a "$grubThemeDir" "$grubThemeBackup"; then
                errMsg "failed to back up existing grub theme."
                updateFailed=1
            fi
        fi

        if [ "$updateFailed" -eq 0 ]; then
            rm -rf "$grubThemeDir"

            if ! mv "$grubThemeTemp" "$grubThemeDir"; then
                errMsg "failed to install new grub theme."
                updateFailed=1

                rm -rf "$grubThemeDir"

                if [ -d "$grubThemeBackup" ]; then
                    cp -a "$grubThemeBackup" "$grubThemeDir"
                fi
            else
                grubChanged=1
            fi
        fi
    fi
else
    warnMsg "grub theme folder not found, skipping."
fi

if [ -f "${larphubDir}/visnux.svg" ]; then
    infoMsg "updating visnux.svg..."

    iconDir="/usr/share/icons/hicolor/scalable/apps"
    iconFile="${iconDir}/visnux.svg"

    mkdir -p "$iconDir"

    if ! cmp -s "${larphubDir}/visnux.svg" "$iconFile" 2>/dev/null; then
        if ! cp "${larphubDir}/visnux.svg" "$iconFile"; then
            errMsg "failed to update visnux.svg."
            updateFailed=1
        fi
    else
        infoMsg "visnux.svg unchanged."
    fi
else
    warnMsg "visnux.svg not found, skipping."
fi

if [ -f "${larphubDir}/visnux.png" ]; then
    infoMsg "updating visnux.png..."

    pixmapDir="/usr/share/pixmaps"
    pixmapFile="${pixmapDir}/visnux.png"

    mkdir -p "$pixmapDir"

    if ! cmp -s "${larphubDir}/visnux.png" "$pixmapFile" 2>/dev/null; then
        if ! cp "${larphubDir}/visnux.png" "$pixmapFile"; then
            errMsg "failed to update visnux.png."
            updateFailed=1
        fi
    else
        infoMsg "visnux.png unchanged."
    fi
else
    warnMsg "visnux.png not found, skipping."
fi

if [ -d "${larphubDir}/walls/visnux-walls" ]; then
    infoMsg "updating wallpapers..."

    wallpaperSource="${larphubDir}/walls/visnux-walls"
    wallpaperDir="/usr/share/wallpapers"
    backgroundDir="/usr/share/backgrounds/visnux"

    wallpaperTemp="${workDir}/wallpapers"
    wallpaperBackup="${workDir}/wallpapers.old"

    mkdir -p "$wallpaperTemp"
    mkdir -p "$wallpaperDir"
    mkdir -p "$backgroundDir"

    if ! cp -a "${wallpaperSource}/." "$wallpaperTemp/"; then
        errMsg "failed to prepare wallpapers."
        updateFailed=1
    else
        if [ -d "${wallpaperDir}/visnux-walls" ]; then
            if ! cp -a \
                "${wallpaperDir}/visnux-walls" \
                "${wallpaperBackup}-wallpapers"; then

                errMsg "failed to back up existing wallpapers."
                updateFailed=1
            fi
        fi

        if [ -d "${backgroundDir}/visnux-walls" ]; then
            if ! cp -a \
                "${backgroundDir}/visnux-walls" \
                "${wallpaperBackup}-backgrounds"; then

                errMsg "failed to back up existing backgrounds."
                updateFailed=1
            fi
        fi

        if [ "$updateFailed" -eq 0 ]; then
            rm -rf "${wallpaperDir}/visnux-walls"
            rm -rf "${backgroundDir}/visnux-walls"

            wallpaperOK=1
            backgroundOK=1

            if ! cp -a "$wallpaperTemp" "${wallpaperDir}/visnux-walls"; then
                wallpaperOK=0
            fi

            if ! cp -a "$wallpaperTemp" "${backgroundDir}/visnux-walls"; then
                backgroundOK=0
            fi

            if [ "$wallpaperOK" -eq 0 ] || [ "$backgroundOK" -eq 0 ]; then
                errMsg "failed to update wallpapers."
                updateFailed=1

                rm -rf "${wallpaperDir}/visnux-walls"
                rm -rf "${backgroundDir}/visnux-walls"

                if [ -d "${wallpaperBackup}-wallpapers" ]; then
                    cp -a \
                        "${wallpaperBackup}-wallpapers" \
                        "${wallpaperDir}/visnux-walls"
                fi

                if [ -d "${wallpaperBackup}-backgrounds" ]; then
                    cp -a \
                        "${wallpaperBackup}-backgrounds" \
                        "${backgroundDir}/visnux-walls"
                fi
            fi
        fi
    fi
else
    warnMsg "wallpaper folder not found, skipping."
fi

fastfetchDir="/etc/skel/.config/fastfetch"

if [ -f "${larphubDir}/neveraskmewhatthisis/config.jsonc" ]; then
    infoMsg "updating fastfetch config..."

    mkdir -p "$fastfetchDir"

    if ! cmp -s \
        "${larphubDir}/neveraskmewhatthisis/config.jsonc" \
        "${fastfetchDir}/config.jsonc" 2>/dev/null; then

        if ! cp \
            "${larphubDir}/neveraskmewhatthisis/config.jsonc" \
            "${fastfetchDir}/config.jsonc"; then

            errMsg "failed to update fastfetch config."
            updateFailed=1
        fi
    else
        infoMsg "fastfetch config unchanged."
    fi
else
    warnMsg "fastfetch config not found, skipping."
fi

if [ -x "${larphubDir}/colorlogo.sh" ]; then
    infoMsg "updating fastfetch logo..."

    mkdir -p "$fastfetchDir"

    logoTemp="${workDir}/logo.txt"

    if ! (
        cd "$larphubDir" &&
        ./colorlogo.sh > "$logoTemp"
    ); then

        errMsg "failed to generate fastfetch logo."
        updateFailed=1

    elif [ ! -s "$logoTemp" ]; then

        errMsg "fastfetch logo generator produced no output."
        updateFailed=1

    elif ! cmp -s "$logoTemp" "${fastfetchDir}/logo.txt" 2>/dev/null; then

        if ! cp "$logoTemp" "${fastfetchDir}/logo.txt"; then
            errMsg "failed to update fastfetch logo."
            updateFailed=1
        fi

    else
        infoMsg "fastfetch logo unchanged."
    fi
else
    warnMsg "colorlogo.sh not found or not executable, skipping."
fi

if [ "$grubChanged" -eq 1 ]; then
    if command -v grub-mkconfig >/dev/null 2>&1; then
        infoMsg "regenerating grub config..."

        if ! grub-mkconfig -o /boot/grub/grub.cfg; then
            errMsg "grub-mkconfig failed."
            updateFailed=1
        fi
    else
        warnMsg "grub-mkconfig not found, skipping."
    fi
fi

if [ "$updateFailed" -eq 1 ]; then
    echo ""
    errMsg "update finished with errors."
    errMsg "commit ${latestCommit:0:8} was not marked as synced."
    exit 1
fi

stateTemp="${stateFile}.tmp"

if ! printf '%s\n' "$latestCommit" > "$stateTemp"; then
    errMsg "failed to write update state."
    rm -f "$stateTemp"
    exit 1
fi

if ! mv -f "$stateTemp" "$stateFile"; then
    errMsg "failed to save update state."
    rm -f "$stateTemp"
    exit 1
fi

echo ""
infoMsg "update complete (commit ${latestCommit:0:8})"
