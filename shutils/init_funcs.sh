# -*-* shell *-*-

set_defvars() {
	local DDIRS= i=

	XBPS_HELPERSDIR=$XBPS_SHAREDIR/helpers
	XBPS_SHUTILSDIR=$XBPS_SHAREDIR/shutils
	XBPS_CROSSPFDIR=$XBPS_SHAREDIR/cross-profiles
	XBPS_META_PATH=$XBPS_MASTERDIR/var/db/xbps
	XBPS_PKGMETADIR=$XBPS_META_PATH/metadata

	if [ -n "$IN_CHROOT" ]; then
		XBPS_SRCPKGDIR=/xbps/srcpkgs
		XBPS_COMMONDIR=/xbps/common
		XBPS_DESTDIR=/destdir
		XBPS_BUILDDIR=/builddir
	else
		XBPS_SRCPKGDIR=$XBPS_DISTDIR/srcpkgs
		XBPS_COMMONDIR=$XBPS_DISTDIR/common
		XBPS_DESTDIR=$XBPS_MASTERDIR/destdir
		XBPS_BUILDDIR=$XBPS_MASTERDIR/builddir
	fi
	if [ -n "$XBPS_HOSTDIR" ]; then
		XBPS_PACKAGESDIR=$XBPS_HOSTDIR/binpkgs
		XBPS_SRCDISTDIR=$XBPS_HOSTDIR/sources
	else
		XBPS_SRCDISTDIR=$XBPS_MASTERDIR/host/sources
		XBPS_PACKAGESDIR=$XBPS_MASTERDIR/host/binpkgs
	fi
	XBPS_TRIGGERSDIR=$XBPS_SRCPKGDIR/xbps-triggers/files

	DDIRS="DISTDIR TRIGGERSDIR HELPERSDIR SRCPKGDIR SHUTILSDIR COMMONDIR"
	for i in ${DDIRS}; do
		eval val="\$XBPS_$i"
		if [ ! -d "$val" ]; then
			echo "WARNING: cannot find $i at $val."
		fi
	done

	for i in DESTDIR PACKAGESDIR BUILDDIR SRCDISTDIR; do
		eval val="\$XBPS_$i"
		if [ ! -d "$val" ]; then
			mdir=$(dirname $XBPS_MASTERDIR)
			[ -z "$IN_CHROOT" -a "$mdir" = "/" ] && continue
			[ -d $XBPS_DISTDIR/.git ] && mkdir -p $val
		fi
	done

	for f in $XBPS_SHUTILSDIR/*.sh $XBPS_COMMONDIR/*.sh; do
		[ -r "$f" ] && . $f
	done

	: ${XBPS_INSTALL:=xbps-install}
	: ${XBPS_QUERY:=xbps-query}
	: ${XBPS_RINDEX:=xbps-rindex}
	: ${XBPS_UHELPER:=xbps-uhelper}
	: ${XBPS_CREATE:=xbps-create}
	: ${XBPS_RECONFIGURE:=xbps-reconfigure}
	: ${XBPS_REMOVE:=xbps-remove}

	if [ -n "$IN_CHROOT" ]; then
		XBPS_UHELPER_CMD="$XBPS_UHELPER"
		XBPS_INSTALL_CMD="$XBPS_INSTALL"
		XBPS_QUERY_CMD="$XBPS_QUERY"
		XBPS_RINDEX_CMD="$XBPS_RINDEX"
		XBPS_RECONFIGURE_CMD="$XBPS_RECONFIGURE"
		XBPS_REMOVE_CMD="$XBPS_REMOVE"
	else
		XBPS_UHELPER_CMD="$XBPS_UHELPER -r $XBPS_MASTERDIR"
		XBPS_INSTALL_CMD="$XBPS_INSTALL -C /empty.conf -R $XBPS_PACKAGESDIR -r $XBPS_MASTERDIR"
		XBPS_QUERY_CMD="$XBPS_QUERY -C /empty.conf -D $XBPS_PACKAGESDIR -r $XBPS_MASTERDIR"
		XBPS_RINDEX_CMD="$XBPS_RINDEX"
		XBPS_RECONFIGURE_CMD="$XBPS_RECONFIGURE -r $XBPS_MASTERDIR"
		XBPS_REMOVE_CMD="$XBPS_REMOVE -r $XBPS_MASTERDIR"
	fi

	: ${XBPS_DIGEST_CMD:="$XBPS_UHELPER digest"}
	: ${XBPS_CMPVER_CMD:="$XBPS_UHELPER cmpver"}
	: ${XBPS_FETCH_CMD:="$XBPS_UHELPER fetch"}
	: ${XBPS_CREATE_CMD:=$XBPS_CREATE}

	XBPS_VERSION=$($XBPS_UHELPER -V|awk '{print $2}')
	XBPS_APIVER=$($XBPS_UHELPER -V|awk '{print $4}')

	[ ! -d "${XBPS_DISTDIR}/.git" ] && return

	if [ -z "$XBPS_SRC_REQ" -o -z "$XBPS_UTILS_REQ" -o \
	     -z "$XBPS_UTILS_API_REQ" -o -z "$BASE_CHROOT_REQ" ]; then
		echo "ERROR: missing defs from global-defs.sh!"
		exit 1
	fi
	$XBPS_UHELPER_CMD cmpver $(echo "$XBPS_SRC_VERSION"|awk '{print $1}') "$XBPS_SRC_REQ"
	if [ $? -eq 255 ]; then
		echo "ERROR: this xbps-src version is outdated! (>=$XBPS_SRC_REQ is required)"
		exit 1
	fi
	$XBPS_UHELPER_CMD cmpver "$XBPS_VERSION" "$XBPS_UTILS_REQ"
	if [ $? -eq 255 ]; then
		echo "ERROR: requires xbps-$XBPS_UTILS_REQ API: $XBPS_UTILS_API_REQ"
		exit 1
	fi
	$XBPS_UHELPER_CMD cmpver "$XBPS_APIVER" "$XBPS_UTILS_API_REQ"
	if [ $? -eq 255 ]; then
		echo "ERROR: requires xbps-$XBPS_UTILS_REQ API: $XBPS_UTILS_API_REQ"
		exit 1
	fi

	if [ -z "$XBPS_CROSSS_BUILD" ]; then
		export XBPS_TARGET_MACHINE=$XBPS_MACHINE
		export XBPS_QUERY_XCMD="$XBPS_QUERY_CMD"
		export XBPS_UHELPER_XCMD="$XBPS_UHELPER_CMD"
		export XBPS_INSTALL_XCMD="$XBPS_INSTALL_CMD"
		export XBPS_REMOVE_XCMD="$XBPS_REMOVE_CMD"
	fi

	export XBPS_VERSION XBPS_APIVER XBPS_UHELPER_CMD
	export XBPS_INSTALL_CMD XBPS_REMOVE_CMD XBPS_RECONFIGURE_CMD
	export XBPS_QUERY_CMD XBPS_RINDEX_CMD
	export XBPS_DIGEST_CMD XBPS_CMPVER_CMD XBPS_FETCH_CMD
}

set_cross_defvars() {
	local CROSSVARS= i= val=

	[ -z "$XBPS_CROSS_BUILD" ] && return 0

	if [ ! -r ${XBPS_CROSSPFDIR}/${XBPS_CROSS_BUILD}.sh ]; then
		echo "ERROR: missing cross build profile for ${XBPS_CROSS_BUILD}, exiting."
		exit 1
	fi

	. ${XBPS_CROSSPFDIR}/${XBPS_CROSS_BUILD}.sh

	if [ -z "$CHROOT_READY" ]; then
		echo "ERROR: chroot mode not activated (install a bootstrap)."
		exit 1
	elif [ -z "$IN_CHROOT" ]; then
		return 0
	fi

	# Install required pkgs for cross building.
	check_installed_pkg cross-${XBPS_CROSS_TRIPLET}-0.1_1
	if [ $? -ne 0 ]; then
		echo "Installing required cross pkg: cross-${XBPS_CROSS_TRIPLET}"
		$XBPS_INSTALL_CMD -Ay cross-${XBPS_CROSS_TRIPLET} 2>&1 >/dev/null
		if [ $? -ne 0 ]; then
			echo "ERROR: failed to install cross-${XBPS_CROSS_TRIPLET}"
			exit 1
		fi
	fi
	$XBPS_INSTALL_CMD -r /usr/${XBPS_CROSS_TRIPLET} \
		-Sy cross-vpkg-dummy 2>&1 >/dev/null
	if [ $? -ne 0 -a $? -ne 6 ]; then
		echo "ERROR: failed to install cross-vpkg-dummy"
		exit 1
	fi

	CROSSVARS="TARGET_ARCH CROSS_TRIPLET CROSS_CFLAGS CROSS_CXXFLAGS"
	for i in ${CROSSVARS}; do
		eval val="\$XBPS_$i"
		if [ -z "$val" ]; then
			echo "ERROR: XBPS_$i is not defined!"
			exit 1
		fi
	done

	XBPS_UHELPER_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_UHELPER -r /usr/${XBPS_CROSS_TRIPLET}"
	XBPS_INSTALL_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_INSTALL_CMD -c /host/repocache -r /usr/${XBPS_CROSS_TRIPLET}"
	XBPS_QUERY_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_QUERY_CMD -c /host/repocache -r /usr/${XBPS_CROSS_TRIPLET}"
	XBPS_RINDEX_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_RINDEX_CMD"
	XBPS_RECONFIGURE_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_RECONFIGURE_CMD -r /usr/${XBPS_CROSS_TRIPLET}"
	XBPS_REMOVE_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_REMOVE_CMD -r /usr/${XBPS_CROSS_TRIPLET}"

	export XBPS_CROSS_TRIPLET XBPS_CROSS_CFLAGS XBPS_CROSS_CXXFLAGS
	export XBPS_UHELPER_XCMD XBPS_INSTALL_XCMD XBPS_QUERY_XCMD
	export XBPS_RINDEX_XCMD XBPS_RECONFIGURE_XCMD XBPS_REMOVE_XCMD
	export XBPS_TARGET_MACHINE=$XBPS_TARGET_ARCH
	export XBPS_CROSS_BASE=/usr/$XBPS_CROSS_TRIPLET
}
