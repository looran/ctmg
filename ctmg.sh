#!/bin/sh

# Copyright (c) 2014 Laurent Ghigonis <laurent@gouloum.fr>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

CT_SUFFIX=".ct"
CT_MAPPER_PREFIX="ct_"

usage() {
	cat <<-_EOF
	Usage: $PROGRAM [ new | delete | open | close ] container_path [cmd_arguments]
	    $PROGRAM new    container_path container_size (in MB)
	    $PROGRAM delete container_path
	    $PROGRAM open   container_path
	    $PROGRAM close  container_path
	    $PROGRAM list
	_EOF
}

#
# HELPERS
#

fatal_usage() {
	usage
	exit 1
}
fatal() {
	echo $1
	exit 1
}
trace() {
	echo "[-] $@"
	eval "$@"
}
yesno() {
	[[ -t 0 ]] || return 0
	local response
	read -r -p "$1 [y/N] " response
	[[ $response == [yY] ]] || exit 1
}
readarg_container() {
	# container_dir  = /home/myuser/
	container_dir="$(dirname $1)"
	# container_path = /home/myuser/bla.ct
	container_path="${container_dir}/$(basename $1 $CT_SUFFIX)${CT_SUFFIX}"
	# mount_path     = /home/myuser/bla/
	mount_path="${container_dir}/$(basename $container_path ${CT_SUFFIX})"
	# mapper_name    = ct_bla
	mapper_name="${CT_MAPPER_PREFIX}$(basename $mount_path)"
	# mapper_path    = /dev/mapper/ct_bla
	mapper_path="/dev/mapper/${mapper_name}"
}


#
# COMMANDS
#

do_new() {
	trace fallocate -l "${container_size}MiB" "$container_path"
	trace sudo cryptsetup --cipher aes-xts-plain64 \
		--key-size 512 --hash sha512 --iter-time 5000 \
		--use-random --verify-passphrase \
		luksFormat "$container_path"
	do_open 0
	trace sudo mkfs.ext4 "$mapper_path"
	do_open 1
}

do_delete() {
	trace rm -f "$container_path"
}

do_open() {
	do_mount=$1
	if [[ -e $mapper_path ]]; then
		echo "Mapper file $mapper_path already exists, not reopening"
	else
		trace losetup_path=$(sudo losetup --show -f "$container_path")
		trace sudo cryptsetup luksOpen "$losetup_path" "$mapper_name"
	fi
	if [[ $do_mount -eq 1 ]]; then
		trace mkdir -p "$mount_path"
		trace sudo mount "/dev/mapper/${mapper_name}" "$mount_path"
		trace sudo chown -R "$(id -u):$(id -g)" "$mount_path" # XXX optional
	fi
}

do_close() {
	trace sudo umount "$mount_path" || true
	trace rmdir "$mount_path" || true
	trace sudo cryptsetup luksClose $mapper_name
	trace losetup_path=$(sudo losetup -l | grep "$container_path" | awk '{print $1}')
	trace sudo losetup -d "$losetup_path"
}

do_list() {
	lsblk -l | grep "$CT_MAPPER_PREFIX"
}

#
# MAIN
#

PROGRAM="$(basename "$0")"
set -e

case "$1" in
n|new)
	[[ $# -ne 3 ]] && fatal_usage
	shift && readarg_container "$1"
	container_size="$2"
	do_new
	echo "[*] Created $container_path of size ${container_size}MB"
	echo "[*] Open and mounted"
	break;;
d|del|delete)
	[[ $# -ne 2 ]] && fatal_usage
	shift && readarg_container "$1"
	yesno "Are you sure you would like to delete $container_path?"
	do_close || true
	do_delete
	echo "[*] Deleted $container_path"
	break;;
c|close)
	[[ $# -ne 2 ]] && fatal_usage
	shift && readarg_container "$1"
	do_close
	echo "[*] Closed and unmounted $mount_path"
	break;;
l|list)
	[[ $# -ne 1 ]] && fatal_usage
	do_list
	break;;
help|-h)
	usage
	break;;
*)
	[[ $# -lt 1 ]] && fatal_usage
	[[ $1 == "open" || $1 == "o" ]] && shift
	readarg_container "$1"
	do_open 1
	echo "[*] Opened and mounted $mount_path"
	break;;
esac
exit 0
