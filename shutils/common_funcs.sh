# -*-* shell *-*-
#
# Common functions for xbps.
#

run_func_error() {
	local func="$1"

	remove_pkgdestdir_sighandler ${pkgname} $KEEP_AUTODEPS
	echo
	msg_error "$pkgver: '$func' interrupted!\n"
}

remove_pkgdestdir_sighandler() {
	local subpkg= _pkgname="$1" _kwrksrc="$2"

	setup_tmpl ${_pkgname}
	[ -z "$sourcepkg" ] && return 0

	# If there is any problem in the middle of writting the metadata,
	# just remove all files from destdir of pkg.

	for subpkg in ${subpackages}; do
		if [ -d "$XBPS_DESTDIR/${subpkg}-${version%_*}" ]; then
			rm -rf "$XBPS_DESTDIR/${subpkg}-${version%_*}"
		fi
		if [ -f ${wrksrc}/.xbps_do_install_${subpkg}_done ]; then
			rm -f ${wrksrc}/.xbps_do_install_${subpkg}_done
		fi
	done

	if [ -d "$XBPS_DESTDIR/${sourcepkg}-${version%_*}" ]; then
		rm -rf "$XBPS_DESTDIR/${sourcepkg}-${version%_*}"
		msg_red "$pkgver: removed files from DESTDIR...\n"
	fi

	remove_pkg_autodeps ${_kwrksrc}
}

run_func() {
	local rval= logpipe= logfile=

	[ -z "$1" ] && return 1

	if type ${1} >/dev/null 2>&1; then
		logpipe=/tmp/xbps_src_logpipe.$$
		if [ -d "${wrksrc}" ]; then
			logfile=${wrksrc}/.xbps_${1}.log
		else
			logfile=$(mktemp -t xbps_${1}_${pkgname}.log.XXXXXXXX)
		fi
		mkfifo "$logpipe"
		exec 3>&1
		tee "$logfile" < "$logpipe" &
		exec 1>"$logpipe" 2>"$logpipe"
		set -e
		trap "run_func_error $1 && return $?" INT
		msg_normal "$pkgver: running $1 phase...\n"
		$1 2>&1
		rval=$?
		set +e
		trap - INT
		exec 1>&3 2>&3 3>&-
		rm -f "$logpipe"
		if [ $rval -ne 0 ]; then
			msg_error "$pkgver: $1 failed!\n"
		else
			msg_normal "$pkgver: $1 phase done.\n"
			return 0
		fi
	fi
	return 255 # function not found.
}

msg_red() {
	# error messages in bold/red
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	if [ -n "$IN_CHROOT" ]; then
		printf >&2 "[chroot] => ERROR: $@"
	else
		printf >&2 "=> ERROR: $@"
	fi
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_red_nochroot() {
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	printf >&2 "$@"
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_error() {
	msg_red "$@"
	exit 1
}

msg_error_nochroot() {
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	printf >&2 "=> ERROR: $@"
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
	exit 1
}

msg_warn() {
	# warn messages in bold/yellow
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[33m"
	if [ -n "$IN_CHROOT" ]; then
		printf >&2 "[chroot] => WARNING: $@"
	else
		printf >&2 "=> WARNING: $@"
	fi
	[ -n "$NOCOLORS" ] || printf >&2  "\033[m"
}

msg_warn_nochroot() {
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[33m"
	printf >&2 "=> WARNING: $@"
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_normal() {
	# normal messages in bold
	[ -n "$NOCOLORS" ] || printf "\033[1m"
	if [ -n "$IN_CHROOT" ]; then
		printf "[chroot] => $@"
	else
		printf "=> $@"
	fi
	[ -n "$NOCOLORS" ] || printf "\033[m"
}

msg_normal_append() {
	[ -n "$NOCOLORS" ] || printf "\033[1m"
	printf "$@"
	[ -n "$NOCOLORS" ] || printf "\033[m"
}
