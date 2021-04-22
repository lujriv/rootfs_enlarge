#!/bin/bash

# Adapted for linux-wiiu from raspi-config's init_resize.sh

reboot_pi () {
  reboot
  exit 0
}

check_commands () {
  for COMMAND in grep cut sed parted fdisk findmnt partprobe; do
    if ! command -v $COMMAND > /dev/null; then
      FAIL_REASON="$COMMAND not found"
      return 1
    fi
  done
  return 0
}

get_variables () {
  ROOT_PART_DEV=$(findmnt / -o source -n)
  ROOT_PART_NAME=$(echo "$ROOT_PART_DEV" | cut -d "/" -f 3)
  ROOT_DEV_NAME=$(echo /sys/block/*/"${ROOT_PART_NAME}" | cut -d "/" -f 4)
  ROOT_DEV="/dev/${ROOT_DEV_NAME}"
  ROOT_PART_NUM=$(cat "/sys/block/${ROOT_DEV_NAME}/${ROOT_PART_NAME}/partition")

  ROOT_DEV_SIZE=$(cat "/sys/block/${ROOT_DEV_NAME}/size")
  TARGET_END=$((ROOT_DEV_SIZE - 1024))
}

check_variables () {
  if [ ! -b "$ROOT_DEV" ] || [ ! -b "$ROOT_PART_DEV" ] ; then
    FAIL_REASON="Could not determine partitions"
    return 1
  fi
}

main () {
  get_variables

  if ! check_variables; then
    return 1
  fi

  echo Fixing GPT...
  echo "Please ignore any warnings - you don't need to do anything."
  echo

  parted "$ROOT_DEV" p fix q

  echo "Resizing partition... Please wait."
  echo "Please ignore any warnings - you don't need to do anything."
  echo

  if ! parted -a none "$ROOT_DEV" u s resizepart "$ROOT_PART_NUM" "$TARGET_END"; then
    FAIL_REASON="Root partition resize failed"
    return 1
  fi

  partprobe "$ROOT_DEV"
  fix_partuuid

  echo "Resizing filesystem... Please wait."
  echo

  resize2fs "$ROOT_PART_DEV" -p

  return 0
}

if main; then
  echo "Resized root filesystem. Rebooting in 5 seconds..."
  sleep 5
else
  echo "Could not expand filesystem, please contact the devs!.\n${FAIL_REASON}"
  exit
fi

reboot_pi
