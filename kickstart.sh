# =========
# Variables
# =========

os=$(uname)
dir="$(pwd)/binaries/$os"
disk=8
fs=disk0s1s$disk
boot_args="-v keepsyms=1 debug=0x2014e"

chmod +x "$dir"/*

# =========
# Functions
# =========

get_device_mode() {
    if [ "$os" = "Darwin" ]; then
        apples="$(system_profiler SPUSBDataType 2> /dev/null | grep -B1 'Vendor ID: 0x05ac' | grep 'Product ID:' | cut -dx -f2 | cut -d' ' -f1 | tail -r)"
    elif [ "$os" = "Linux" ]; then
        apples="$(lsusb | cut -d' ' -f6 | grep '05ac:' | cut -d: -f2)"
    fi
    local device_count=0
    local usbserials=""
    for apple in $apples; do
        case "$apple" in
            12a8|12aa|12ab)
            device_mode=normal
            device_count=$((device_count+1))
            ;;
            1281)
            device_mode=recovery
            device_count=$((device_count+1))
            ;;
            1227)
            device_mode=dfu
            device_count=$((device_count+1))
            ;;
            1222)
            device_mode=diag
            device_count=$((device_count+1))
            ;;
            1338)
            device_mode=checkra1n_stage2
            device_count=$((device_count+1))
            ;;
            4141)
            device_mode=pongo
            device_count=$((device_count+1))
            ;;
        esac
    done
    if [ "$device_count" = "0" ]; then
        device_mode=none
    elif [ "$device_count" -ge "2" ]; then
        echo "[-] Please attach only one device" > /dev/tty
        kill -30 0
        exit 1;
    fi
    if [ "$os" = "Linux" ]; then
        usbserials=$(cat /sys/bus/usb/devices/*/serial)
    elif [ "$os" = "Darwin" ]; then
        usbserials=$(system_profiler SPUSBDataType 2> /dev/null | grep 'Serial Number' | cut -d: -f2- | sed 's/ //')
    fi
    if grep -qE '(ramdisk tool|SSHRD_Script) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [0-9]{1,2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}' <<< "$usbserials"; then
        device_mode=ramdisk
    fi
    echo "$device_mode"
}



# Get device's iOS version from ideviceinfo if in normal mode
echo "[*] Waiting for device in DFU mode"
while [ "$(get_device_mode)" = "none" ]; do
    sleep 1;
done
echo $(echo "[*] Detected $(get_device_mode) mode device" | sed 's/dfu/DFU/')

if grep -E 'pongo|checkra1n_stage2|diag|recovery|normal' <<< "$(get_device_mode)"; then
    echo "[-] Detected device in unsupported mode '$(get_device_mode)'"
    exit 1;
fi

echo "[*] Booting PongoOS"
"$dir"/checkra1n -VEvpk binaries/Pongo.bin
echo "[*] Configuring PongoOS"

sleep 2
echo "[*] PongoOS Loaded"
sleep 2
echo "[*] Uploading KPF Payload"
echo "/send binaries/checkra1n-kpf-pongo" | "$dir"/pongoterm
echo "[*] Load modes"
echo "modload" | "$dir"/pongoterm
echo "[*] Execute KPF Payload"
echo "kpf" | "$dir"/pongoterm
echo "[*] Changing launchd to /jbin/launchd"
echo "launchd /jbin/launchd" | "$dir"/pongoterm > /dev/null 2>&1
echo "[*] Applying dtpatch for $fs"
echo "dtpatch $fs" | "$dir"/pongoterm > /dev/null 2>&1
echo "[*] Locking fuse"
echo "fuse lock" | "$dir"/pongoterm
echo "[*] Changing Boot Args to $boot_args"
echo "xargs $boot_args" | "$dir"/pongoterm
echo "xfb" | "$dir"/pongoterm
echo "[*] ACTIVATING SEP"
echo "sep auto" | "$dir"/pongoterm
echo "[*] SEP Activated"
echo "[*] Booting..."
echo "bootux" | "$dir"/pongoterm &> /dev/null || true