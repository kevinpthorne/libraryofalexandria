#!/bin/bash

# Check if a disk image path is provided as an argument
if [ $# -eq 0 ]; then
    echo "Please provide a disk image path as an argument."
    exit 1
fi

disk_image="$1"

# Check if the disk image file exists
if [ ! -f "$disk_image" ]; then
    echo "The specified disk image file does not exist: $disk_image"
    exit 1
fi

# List available disks using diskutil
disks=$(diskutil list | grep "/dev" | sed 's/\/dev\/\([^ ]*\).*/\1/')

diskutil list

# Prompt the user to select a disk
echo "Select a disk to flash: (don't put disk number)"
select disk in $disks; do
    if [[ $disk ]]; then
        break
    fi
    echo "Invalid option. Please try again."
done

# Confirm the disk selection
read -p "Are you sure you want to flash disk '$disk'? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Flashing cancelled."
    exit 1
fi

set -x  # show output

diskutil unmountDisk $disk

# Decompress the disk image on the fly and flash it to the selected disk
zstd -d -c "$disk_image" | sudo dd bs=8m of="/dev/$disk" status=progress

diskutil eject $disk

set +x ""

echo "Writing complete!"