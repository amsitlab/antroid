#!/bin/bash

PROJECTNAME="antroid"
VERSION="1.0"
LIBDIR="lib"
BUILDDIR="build"
CLASSESDIR="${BUILDDIR}/classes"
DISTDIR="dist"
SRCDIR="src"
JAVASRCDIR="${SRCDIR}/main/java"
RESDIR="${SRCDIR}/resources"
DLURL="https://archive.apache.org/dist/ant/binaries/apache-ant-1.9.6-bin.tar.bz2"
ANT_ARCHIVE=$(basename "${DLURL}")
ANT_DIR=${ANT_ARCHIVE%-bin.tar.bz2}


__remove() {
	if [ -r "${1}" ]; then
		echo "[remove] ${1}"
		rm -fr $1
	fi
}

__mkdir() {
	if [ ! -d "${1}" ]; then
		echo "[mkdir] ${1}"
		mkdir -p $1
	fi
}

__classpath() {
	CLASSPATH=$(find lib -type f -name "*.jar"| \
		tr "\n" ":" );
	CLASSPATH+=$(find "apache-ant-1.9.6/lib" -type f -name "*.jar"| \
		tr "\n" ":" );

	CLASSPATH=${CLASSPATH%:}
}

__missing() {
	echo "[missing] apt install -y ${1}"
	MISSING=1
}

__download() {

	[[ ! -r "./${ANT_ARCHIVE}" ]] && \
		echo "[download] ${DLURL}" && \
		curl -LO "${DLURL}";
}

__extract() {

	if [ ! -d "${ANT_DIR}" ]; then	
		for f in $(tar --wildcards -xvjf "${ANT_ARCHIVE}" "*.jar"); do
			echo "[extract] ${f} from ${ANT_ARCHIVE}";
		done
	fi
}

__init() {
	
	local sdkversion=$(getprop "ro.build.version.sdk");
	[[ $sdkversion -gt 24 ]] && \
		ecjsuffix="" || \
		ecjsuffix="4.6";

	deps="ecj dx curl dpkg tar"

	local silentcheck=""
	for pkg in ${deps}; do

		silentcheck="$(which $pkg)"
		if [[ "x${silentcheck}" == "x" ]]; then
			[[ "${pkg}" == "ecj" ]] && pkg+="${ecjsuffix}";
			__missing "${pkg}";
		fi
	done
	[[ $MISSING -eq 1 ]] && exit 1;

}

__dexing() {
	local files=$(find $ANT_DIR -type f -name "*.jar");
	local name=""
	for f in ${files}; do
		name=$(basename $f)
		if [ "$name" == "ant.jar" ]; then
			# skip dexing ant.jar
			# we will built it next
			continue;
		fi

		if [ ! -r "${DISTDIR}/${name}" ]; then
			echo "[dexing] ${f}"
			dx --dex \
				--keep-classes \
				--output ${DISTDIR}/${name} \
				$f
			sleep 5
		fi
	done
}

__create_ant_jar () {

	if [[ -d "$ANT_DIR" && -r "${ANT_DIR}/lib/ant.jar" ]]; then
		unzip -d $CLASSESDIR "${ANT_DIR}/lib/ant.jar"
		local files=$(find "${CLASSESDIR}/org/apache/tools/ant/" -name "AntClassLoader*" -maxdepth 1);
		for f in $files; do
			__remove $f
		done
		ecj -verbose -d $CLASSESDIR -cp $CLASSPATH "${JAVASRCDIR}/org/apache/tools/ant/AntClassLoader.java";
		if [ -f "${DISTDIR}/ant.jar" ]; then
			__remove "${DISTDIR}/ant.jar"
		fi
		
		dx --dex --verbose --keep-classes --output "${DISTDIR}/ant.jar" $CLASSESDIR;
	fi


}

main() {

	__init

	__remove $CLASSESDIR
	__remove $BUILDDIR
	__mkdir $BUILDDIR
	__mkdir $CLASSESDIR
	__mkdir $SRCDIR
	__mkdir $JAVASRCDIR
	__mkdir $RESDIR
	__mkdir $LIBDIR
	__mkdir $DISTDIR

	__download
	__extract

	__dexing
	__classpath
	__create_ant_jar

}


main
