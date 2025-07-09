#!/bin/bash

# Copyright (C) 2025 John Turner

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

shopt -s nullglob

_help() {
    cat >/dev/stderr << EOF
Usage:
        mkchroot -c \${sysroot} -- bash
Options:
        -c:     path to container sysroot
        -m:     home directory to mount to /var/home
        -h:     hostname to set in the container
        -b:     directory to bind mount into container
        -r:     directory to ro bind mount into container
        -d:     directory to dev bind mount into container
EOF
}

_yesno() {
    case "${1}" in
        1|yes|YES)
            true
            ;;        
        *)
            false
            ;;
    esac
}

HOST_BINDS=(
    /mnt
)

HOST_RO_BINDS=(
    /etc/hosts.conf
    /etc/machine-id
    /etc/resolv.conf    
    /etc/shadow
    /etc/passwd
    /etc/subuid
    /etc/subgid
    /etc/sudoeros
    /etc/sudo.conf
)

HOST_DEV_BINDS=(
    /dev/dri
    /dev/nvidia*
)

args=()
root=""
home=""
hostname="chroot"
user="${USER}"
binds=(${HOST_BINDS[@]})
robinds=(${HOST_RO_BINDS[@]})
devbinds=(${HOST_DEV_BINDS[@]})

while getopts 'c:b:r:d:m:h:u:' opt; do
    case ${opt} in
        c)
            root="${OPTARG}"
            ;;
        b)
            binds+=("${OPTARG}")
            ;;
        r)
            robinds+=("${OPTARG}")
            ;;
        d)
            devbinds+=("${OPTARG}")
            ;;
        m)
            home="${OPTARG}"
            ;;
        h)
            hostname="${OPTARG}"
            ;;
    esac
done

while [[ ${1} != "--" && $# -gt 1 ]]; do
    shift
done

if [[ $# -lt 1 ]]; then
    _help
    exit 1
fi
shift

if [[ -z ${root} ]]; then
    _help
    exit 1
fi

if [[ ! -d ${root} ]]; then
    echo "${root} is not a directory" > /dev/stderr
    _help
    exit 1
fi

args+=(
    --unshare-ipc
    --unshare-pid
    --unshare-uts
    --unshare-cgroup

    --bind "${root}" /

    --clearenv
    --cap-add ALL
    --proc /proc
    --dev /dev
    --hostname "${hostname}"
    
    --tmpfs /run
    --tmpfs /tmp

    --setenv HOME /var/home
    --setenv TERM ${TERM:-xterm}
)

if [[ ${XDG_SESSION_TYPE} = wayland ]]; then
    args+=(
        --setenv XDG_SESSION_TYPE wayland        
        --setenv WAYLAND_DISPLAY ${WAYLAND_DISPLAY}
    )
fi

[[ -d ${home} ]] && args+=(--bind "${home}" /var/home --setenv HOME /var/home)

[[ -d ${XDG_RUNTIME_DIR} ]] && binds+=("${XDG_RUNTIME_DIR}")

for bind in ${binds[@]}; do
    [[ -e ${bind} ]] && args+=(--bind "${bind}" "${bind}")
done

for bind in ${robinds[@]}; do
    [[ -e ${bind} ]] && args+=(--ro-bind "${bind}" "${bind}")
done

for bind in ${devbinds[@]}; do
    [[ -e ${bind} ]] && args+=(--dev-bind "${bind}" "${bind}")
done

exec bwrap ${args[@]} "$@"
