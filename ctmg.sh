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

usage() {
	cat <<-_EOF
	Usage: $PROGRAM [ new | delete | open | close ] container_path [cmd_arguments]
	    $PROGRAM new	container_path container_size
	    $PROGRAM delete	container_path
	    $PROGRAM open	container_path
	    $PROGRAM close	container_path
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
	eval $@
}
yesno() {
	[[ -t 0 ]] || return 0
	local response
	read -r -p "$1 [y/N] " response
	[[ $response == [yY] ]] || exit 1
}

#
# COMMANDS
#

do_new() {
	trace dd if=/dev/zero of=$container_path bs=1 count=$container_size
	trace sudo cryptsetup --cipher aes-xts-plain64 \
		--key-size 512 --hash sha512 --iter-time 5000 \
		--use-random --verify-passphrase \
		luksFormat $container_path
	trace sudo mkfs.ext4 $mapper_path
}

do_delete() {
	rm -f $container_path
}

do_open() {
	trace sudo cryptsetup luksOpen $container_path $mapper_name
	mkdir $mount_path
	mount /dev/mapper/$mapper_name $mount_path
}

do_close() {
	trace sudo cryptsetup luksClose $mapper_name
}

#
# MAIN
#

PROGRAM="$(basename $0)"

[[ $# -lt 2 ]] && fatal_usage
cmd=$1
container_dir="$(dirname $1)"						# /home/myuser/
container_path="${container_dir}/$(basename $2 $CT_SUFFIX)${CT_SUFFIX}"	# /home/myuser/bla.ct
mount_path="${container_dir}/$(basename $container_path ${CT_SUFFIX})"	# /home/myuser/bla/
mapper_name="${CT_MAPPER_PREFIX}_$(basename $mount_path)"		# ct_bla
mapper_path="/dev/mapper/${mapper_name}"				# /dev/mapper/ct_bla

set -e

case $cmd in
n|new)
	[[ $# -ne 3 ]] && fatal_usage
	container_size="$3"
	do_new
	echo "Created $container_path of size $container_size"
	break;;
d|del|delete)
	[[ $# -ne 2 ]] && fatal_usage

	yesno "Are you sure you would like to delete $container_path?"
	do_close && true
	do_delete
	echo "Deleted $container_path"
	break;;
o|open)
	[[ $# -ne 2 ]] && fatal_usage
	do_open
	echo "Mounted $mount_path"
	break;;
c|close)
	[[ $# -ne 2 ]] && fatal_usage
	do_close
	echo "Unmounted $mount_path"
	break;;
esac
exit 0
