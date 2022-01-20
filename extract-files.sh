#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=land
VENDOR=xiaomi

# Load extractutils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in

    vendor/bin/gx_fpcmd|vendor/bin/gx_fpd)
        "${PATCHELF}" --remove-needed "libbacktrace.so" "${2}"
        "${PATCHELF}" --remove-needed "libunwind.so" "${2}"
        ;;
    
    vendor/bin/gx_fpd)
        "${PATCHELF}" --add-needed "liblog.so" "${2}"
        ;;

    vendor/lib64/hw/fingerprint.goodix.so)
        "${PATCHELF}" --remove-needed "libandroid_runtime.so" "${2}"
        ;;

    vendor/lib/libmmcamera2_sensor_modules.so)
        sed -i "s|/system/etc/camera|/vendor/etc/camera|g" "${2}"
        ;;

    vendor/lib/libmmcamera2_stats_modules.so)
        sed -i "s|libgui.so|libwui.so|g" "${2}"
        "${PATCHELF}" --replace-needed "libandroid.so" "libshim_android.so" "${2}"
        ;;

    vendor/lib/libmmsw_detail_enhancement.so|vendor/lib/libmmsw_platform.so|vendor/lib64/libmmsw_detail_enhancement.so|vendor/lib64/libmmsw_platform.so)
        sed -i "s|libgui.so|libwui.so|g" "${2}"
        ;;

    vendor/lib/libFaceGrade.so|vendor/lib/libarcsoft_beauty_shot.so)
        "${PATCHELF}" --remove-needed "libandroid.so" "${2}"
        ;;

    vendor/lib64/libfpservice.so)
        "${PATCHELF}" --add-needed "libshim_binder.so" "${2}"
        ;;

    vendor/lib64/libwvhidl.so)
        "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite.so" "libprotobuf-cpp-lite-v29.so" "${2}"
        ;;

    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

extract "${MY_DIR}/proprietary-files-qc.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
