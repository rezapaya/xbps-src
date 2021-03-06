#!/bin/bash
#
# Passed arguments:
#	$1 - pkgname [REQUIRED]

add_rundep() {
	local dep="$1" i= rpkgdep= _depname= _rdeps= found=

	_depname="$($XBPS_UHELPER_CMD getpkgdepname ${dep} 2>/dev/null)"
	if [ -z "${_depname}" ]; then
		_depname="$($XBPS_UHELPER_CMD getpkgname ${dep} 2>/dev/null)"
	fi

	for i in ${run_depends}; do
		rpkgdep="$($XBPS_UHELPER_CMD getpkgdepname $i 2>/dev/null)"
		if [ -z "$rpkgdep" ]; then
			rpkgdep="$($XBPS_UHELPER_CMD getpkgname $i 2>/dev/null)"
		fi
		if [ "${rpkgdep}" != "${_depname}" ]; then
			continue
		fi
		$XBPS_UHELPER_CMD cmpver "$i" "$dep"
		rval=$?
		if [ $rval -eq 255 ]; then
			run_depends="${run_depends/${i}/${dep}}"
		fi
		found=1
	done
	if [ -z "$found" ]; then
		run_depends+=" ${dep}"
	fi
}

pkg_genrdeps() {
	local depsftmp f j tmplf mapshlibs sorequires

	mapshlibs=$XBPS_COMMONDIR/shlibs
	tmplf=$XBPS_SRCPKGDIR/$pkgname/template

	if [ -n "$noarch" -o -n "$noverifyrdeps" ]; then
		echo "$run_depends" > ${PKGDESTDIR}/rdeps
		return 0
	fi

	msg_normal "$pkgver: verifying required shlibs...\n"

	depsftmp=$(mktemp -t xbps_src_depstmp.XXXXXXXXXX) || exit 1
	find ${PKGDESTDIR} -type f -perm -u+w > $depsftmp 2>/dev/null

	exec 3<&0 # save stdin
	exec < $depsftmp
	while read f; do
		case "$(file -bi "$f")" in
			application/x-executable*|application/x-sharedlib*)
				for nlib in $($OBJDUMP -p "$f"|grep NEEDED|awk '{print $2}'); do
					if [ -z "$verify_deps" ]; then
						verify_deps="$nlib"
						continue
					fi
					for j in ${verify_deps}; do
						[ "$j" != "$nlib" ] && continue
						found_dup=1
						break
					done
					if [ -z "$found_dup" ]; then
						verify_deps="$verify_deps $nlib"
					fi
					unset found_dup
				done
				;;
		esac
	done
	exec 0<&3 # restore stdin
	rm -f $depsftmp

	#
	# Add required run time packages by using required shlibs resolved
	# above, the mapping is done thru the mapping_shlib_binpkg.txt file.
	#
	for f in ${verify_deps}; do
		unset _f j rdep _rdep rdepcnt soname _pkgname _rdepver found
		_f=$(echo "$f"|sed 's|\+|\\+|g')
		rdep="$(grep -E "^${_f}[[:blank:]]+.*$" $mapshlibs|awk '{print $2}')"
		rdepcnt="$(grep -E "^${_f}[[:blank:]]+.*$" $mapshlibs|awk '{print $2}'|wc -l)"
		if [ -z "$rdep" ]; then
			# Ignore libs by current pkg
			soname=$(find ${PKGDESTDIR} -name "$f")
			if [ -z "$soname" ]; then
				msg_red_nochroot "   SONAME: $f <-> UNKNOWN PKG PLEASE FIX!\n"
				broken=1
			else
				echo "   SONAME: $f <-> $pkgname (ignored)"
			fi
			continue
		elif [ "$rdepcnt" -gt 1 ]; then
			unset j found
			# Check if shlib is provided by multiple pkgs.
			for j in ${rdep}; do
				_pkgname=$($XBPS_UHELPER_CMD getpkgname "$j")
				# if there's a SONAME matching pkgname, use it.
				[ "${pkgname}" != "${_pkgname}" ] && continue
				found=1
				break
			done
			if [ -n "$found" ]; then
				_rdep=$j
			else
				# otherwise pick up the first one.
				for j in ${rdep}; do
					[ -z "${_rdep}" ] && _rdep=$j
				done
			fi
		else
			_rdep=$rdep
		fi
		_pkgname=$($XBPS_UHELPER_CMD getpkgname "${_rdep}" 2>/dev/null)
		_rdepver=$($XBPS_UHELPER_CMD getpkgversion "${_rdep}" 2>/dev/null)
		if [ -z "${_pkgname}" -o -z "${_rdepver}" ]; then
			msg_red_nochroot "   SONAME: $f <-> UNKNOWN PKG PLEASE FIX!\n"
			broken=1
			continue
		fi
		# Check if pkg is a subpkg of sourcepkg; if true, ignore version
		# in common/shlibs.
		_sdep="${_pkgname}>=${_rdepver}"
		for _subpkg in ${subpackages}; do
			if [ "${_subpkg}" = "${_pkgname}" ]; then
				_sdep="${_pkgname}-${version}_${revision}"
				break
			fi
		done

		if [ "${_pkgname}" != "${pkgname}" ]; then
			echo "   SONAME: $f <-> ${_sdep}"
			sorequires+="${f} "
		else
			# Ignore libs by current pkg
			echo "   SONAME: $f <-> ${_rdep} (ignored)"
			continue
		fi
		add_rundep "${_sdep}"
	done
	#
	# If pkg uses any unknown SONAME error out.
	#
	if [ -n "$broken" ]; then
		msg_error "$pkgver: cannot guess required shlibs, aborting!\n"
	fi

	if [ -n "$run_depends" ]; then
		echo "$run_depends" > ${PKGDESTDIR}/rdeps
	fi
	if [ -n "${sorequires}" ]; then
		echo "${sorequires}" > ${PKGDESTDIR}/shlib-requires
	fi
}

if [ $# -lt 1 -o $# -gt 2 ]; then
	echo "$(basename $0): invalid number of arguments: pkgname [cross-target]"
	exit 1
fi

PKGNAME="$1"
XBPS_CROSS_BUILD="$2"

. $XBPS_SHUTILSDIR/common.sh

for f in $XBPS_COMMONDIR/*.sh; do
	. $f
done

setup_pkg "$PKGNAME" $XBPS_CROSS_BUILD
setup_pkg_depends $PKGNAME

if [ ! -d "$PKGDESTDIR" ]; then
	msg_error "$pkgver: cannot access $PKGDESTDIR!\n"
fi

${PKGNAME}_package
pkgname=$PKGNAME

pkg_genrdeps

exit 0
