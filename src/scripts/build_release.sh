#!/bin/bash

# WINDOWS
#
# When using git bash on Windows, you can download wget from here : https://eternallybored.org/misc/wget/
# Copy wget.exe into C:\Program Files\Git\mingw64\bin
#
# Download 7za.exe from the 7-Zip extra archive at: https://www.7-zip.org/download.html
# Copy into C:\Program Files\Git\mingw64\bin
#

usage() {
	echo "Usage: "`basename "$0"`" -b <version> [OPTIONS]"
	echo "    -a <arch>    : Force architecture. e.g. x86, x64, arm, x86x64 (win32 only)"
	echo "    -b <version> : Use build version. e.g. 0.105.3.35"
	echo "    -c           : Don't clean dirs."
	echo "    -s           : Build samples."
	echo "    -z           : Clean 'zips' dir."
	exit 0
}


if [[ $# -eq 0 ]] ; then
	usage
fi

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>release_build_`date +%Y%m%d%H%M%S`.log 2>&1

OPT_ARCH=""
BUILD_VERSION=""
EXE=""
PLATFORM="linux"
RELEASE_URL="https://github.com/bmx-ng/bmx-ng/releases/download/"
CLEAN_DIRS="y"
CLEAN_ZIPS=""
BUILD_SAMPLES=""
MINGW_X86="i686-8.1.0-release-posix-sjlj-rt_v6-rev0.7z"
MINGW_X86_URL="https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win32/Personal%20Builds/mingw-builds/8.1.0/threads-posix/sjlj/i686-8.1.0-release-posix-sjlj-rt_v6-rev0.7z"
MINGW_X64="x86_64-8.1.0-release-posix-seh-rt_v6-rev0.7z"
MINGW_X64_URL="https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/8.1.0/threads-posix/seh/x86_64-8.1.0-release-posix-seh-rt_v6-rev0.7z"


get_arch() {
	ARCH=`uname -m`
}

expand_platform() {
	case "$ARCH" in
		x86_64)
			ARCH="x64"
			;;
		arm*)
			PLATFORM="rpi"
			ARCH=""
			;;
	esac

	if [ ! -z "$OPT_ARCH" ]; then
		if [[ "$OPT_ARCH" == *"x86"* ]]; then
			ARCH=x86
		else
			ARCH=$OPT_ARCH
		fi
	fi
}

init() {
	get_arch
	case "$OSTYPE" in
		darwin*)
			PLATFORM="macos"
			;; 
		linux*) ;;
		msys*)
			PLATFORM="win32"
			;;
		*)
			echo "Unknown platform: $OSTYPE"
			exit 1
			;;
	esac

	expand_platform

	echo "Platform : " $PLATFORM
	echo "Arch     : " $ARCH
}

clean_dirs() {
	echo "--------------------"
	echo "-   CLEAN DIRS     -"
	echo "--------------------"

	echo "Removing release dir"
	rm -rf release

	echo "Removing temp dir"
	rm -rf temp

	if [ ! -z "$CLEAN_ZIPS" ]; then
		echo "Removing zips dir"
		rm -rf zips
	fi
}

make_dirs() {
	echo "--------------------"
	echo "-    MAKE DIRS     -"
	echo "--------------------"

	if [ ! -d "zips" ]; then
		echo "Creating zips dir"
		mkdir -p zips
	fi

	if [ ! -d "release" ]; then
		echo "Creating release dir"
		mkdir -p release
	fi

	if [ ! -d "temp" ]; then
		echo "Creating temp dir"
		mkdir -p temp
	fi

	case "$PLATFORM" in
		win32)
			if [ ! -d "mingw" ]; then
				echo "Creating mingw dir"
				mkdir -p mingw
			fi
	esac
}

check_base() {
	echo "--------------------"
	echo "-  CHECK BLITZMAX  -"
	echo "--------------------"

	if [ ! -d "BlitzMax" ]; then
		if [ -z "$BUILD_VERSION" ]; then
			echo "BlitzMax missing and no build defined"
			exit 1
		fi

		DOWNLOAD_URL_ARCH=".${ARCH}"
		ARCHIVE_ARCH="${ARCH}_"
		case "$PLATFORM" in
			win32)
			if [[ "$OPT_ARCH" == "x86x64" ]]; then
				DOWNLOAD_URL_ARCH=""
				ARCHIVE_ARCH=""
			fi
		esac

		SUFFIX=".tar.xz"
		URL="${RELEASE_URL}v${BUILD_VERSION}.${PLATFORM}${DOWNLOAD_URL_ARCH}/"
		ARCHIVE="BlitzMax_${PLATFORM}_"

		case "$PLATFORM" in
			win32)
				ARCHIVE="${ARCHIVE}${ARCHIVE_ARCH}"
				SUFFIX=".7z"
				;;
			linux)
				ARCHIVE="${ARCHIVE}${ARCHIVE_ARCH}";;
			rpi) ;;
		esac

		ARCHIVE="${ARCHIVE}${BUILD_VERSION}${SUFFIX}"

		if [ ! -f "${ARCHIVE}" ]; then

			URL="${URL}${ARCHIVE}"

			echo "Archive (${ARCHIVE}) not found. Downloading..."

			wget -nv $URL
		fi

		echo "Extracting ${ARCHIVE}"

		case "$PLATFORM" in
			win32)
				7za x ${ARCHIVE}
				;;
			*)
				tar -xJf ${ARCHIVE}
				;;
		esac
	else
		echo "Using local BlitzMax"
	fi
}


download() {
	echo "--------------------"
	echo "-    DOWNLOAD      -"
	echo "--------------------"

	# mingw
	case "$PLATFORM" in
		win32)
			if [[ "$OPT_ARCH" == *"x86"* ]]; then
				if [ ! -f "mingw/$MINGW_X86" ]; then
					echo "Downloading $MINGW_X86"
					wget -nv -P mingw $MINGW_X86_URL
				fi
			fi

			if [[ "$OPT_ARCH" == *"x64"* ]]; then
				if [ ! -f "mingw/$MINGW_X64" ]; then
					echo "Downloading $MINGW_X64"
					wget -nv -P mingw $MINGW_X64_URL
				fi
			fi
	esac

	# base
	if [ ! -f zips/bmx-ng.zip ]; then
		echo "Downloading bmx-ng.zip"
		wget -nv -P zips https://github.com/bmx-ng/bmx-ng/archive/master.zip && \
			mv zips/master.zip zips/bmx-ng.zip
	else
		echo "Using local bmx-ng.zip"
	fi

	# apps
	if [ ! -f zips/bcc.zip ]; then
		echo "Downloading bcc.zip"
		wget -nv -P zips https://github.com/bmx-ng/bcc/archive/master.zip && \
			mv zips/master.zip zips/bcc.zip
	else
		echo "Using local bcc.zip"
	fi

	if [ ! -f zips/bmk.zip ]; then
		echo "Downloading bmk.zip"
		wget -nv -P zips https://github.com/bmx-ng/bmk/archive/master.zip && \
			mv zips/master.zip zips/bmk.zip
	else
		echo "Using local bmk.zip"
	fi

	if [ ! -f zips/maxide.zip ]; then
		echo "Downloading maxide.zip"
		wget -nv -P zips https://github.com/bmx-ng/maxide/archive/master.zip && \
			mv zips/master.zip zips/maxide.zip
	else
		echo "Using local maxide.zip"
	fi

	# modules
	if [ ! -f zips/pub.mod.zip ]; then
		echo "Downloading pub.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/pub.mod/archive/master.zip && \
			mv zips/master.zip zips/pub.mod.zip
	else
		echo "Using local pub.mod.zip"
	fi

	if [ ! -f zips/brl.mod.zip ]; then
		echo "Downloading brl.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/brl.mod/archive/master.zip && \
			mv zips/master.zip zips/brl.mod.zip
	else
		echo "Using local brl.mod.zip"
	fi

	if [ ! -f zips/sdl.mod.zip ]; then
		echo "Downloading sdl.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/sdl.mod/archive/master.zip && \
			mv zips/master.zip zips/sdl.mod.zip
	else
		echo "Using local sdl.mod.zip"
	fi

	if [ ! -f zips/maxgui.mod.zip ]; then
		echo "Downloading maxgui.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/maxgui.mod/archive/master.zip && \
			mv zips/master.zip zips/maxgui.mod.zip
	else
		echo "Using local maxgui.mod.zip"
	fi

	if [ ! -f zips/mky.mod.zip ]; then
		echo "Downloading mky.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/mky.mod/archive/master.zip && \
			mv zips/master.zip zips/mky.mod.zip
	else
		echo "Using local mky.mod.zip"
	fi

	if [ ! -f zips/crypto.mod.zip ]; then
		echo "Downloading crypto.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/crypto.mod/archive/master.zip && \
			mv zips/master.zip zips/crypto.mod.zip
	else
		echo "Using local crypto.mod.zip"
	fi

	if [ ! -f zips/audio.mod.zip ]; then
		echo "Downloading audio.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/audio.mod/archive/master.zip && \
			mv zips/master.zip zips/audio.mod.zip
	else
		echo "Using local audio.mod.zip"
	fi

	if [ ! -f zips/steam.mod.zip ]; then
		echo "Downloading steam.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/steam.mod/archive/master.zip && \
			mv zips/master.zip zips/steam.mod.zip
	else
		echo "Using local steam.mod.zip"
	fi

	if [ ! -f zips/text.mod.zip ]; then
		echo "Downloading text.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/text.mod/archive/master.zip && \
			mv zips/master.zip zips/text.mod.zip
	else
		echo "Using local text.mod.zip"
	fi

	if [ ! -f zips/dbg.mod.zip ]; then
		echo "Downloading dbg.mod.zip"
		wget -nv -P zips https://github.com/bmx-ng/dbg.mod/archive/master.zip && \
			mv zips/master.zip zips/dbg.mod.zip
	else
		echo "Using local dbg.mod.zip"
	fi
}

prepare() {
	echo "--------------------"
	echo "-     PREPARE      -"
	echo "--------------------"

	echo "Extracting bmx-ng"
	unzip -q zips/bmx-ng.zip -d release && \
		mv release/bmx-ng-master release/BlitzMax

	rm -rf release/BlitzMax/.github
	rm -rf release/BlitzMax/.gitignore

	mkdir -p release/BlitzMax/mod release/BlitzMax/bin

	# copy all to temp
	echo "Copying sources for build (into temp)"
	cp -R release/BlitzMax temp

	# bcc
	echo "Extracting bcc" 
	unzip -q zips/bcc.zip -d release/BlitzMax/src && \
		mv release/BlitzMax/src/bcc-master release/BlitzMax/src/bcc

	unzip -q zips/bcc.zip -d temp/BlitzMax/src && \
		mv temp/BlitzMax/src/bcc-master temp/BlitzMax/src/bcc

	# bmk
	echo "Extracting bmk" 
	unzip -q zips/bmk.zip -d release/BlitzMax/src && \
		mv release/BlitzMax/src/bmk-master release/BlitzMax/src/bmk

	unzip -q zips/bmk.zip -d temp/BlitzMax/src && \
		mv temp/BlitzMax/src/bmk-master temp/BlitzMax/src/bmk

	# maxide
	echo "Extracting maxide" 
	unzip -q zips/maxide.zip -d release/BlitzMax/src && \
		mv release/BlitzMax/src/maxide-master release/BlitzMax/src/maxide

	unzip -q zips/maxide.zip -d temp/BlitzMax/src && \
		mv temp/BlitzMax/src/maxide-master temp/BlitzMax/src/maxide

	# pub.mod
	echo "Extracting pub.mod" 
	unzip -q zips/pub.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/pub.mod-master release/BlitzMax/mod/pub.mod

	unzip -q zips/pub.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/pub.mod-master temp/BlitzMax/mod/pub.mod

	# brl.mod
	echo "Extracting brl.mod" 
	unzip -q zips/brl.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/brl.mod-master release/BlitzMax/mod/brl.mod

	unzip -q zips/brl.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/brl.mod-master temp/BlitzMax/mod/brl.mod

	# sdl.mod
	echo "Extracting sdl.mod" 
	unzip -q zips/sdl.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/sdl.mod-master release/BlitzMax/mod/sdl.mod

	unzip -q zips/sdl.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/sdl.mod-master temp/BlitzMax/mod/sdl.mod

	# maxgui.mod
	echo "Extracting maxgui.mod" 
	unzip -q zips/maxgui.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/maxgui.mod-master release/BlitzMax/mod/maxgui.mod

	unzip -q zips/maxgui.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/maxgui.mod-master temp/BlitzMax/mod/maxgui.mod

	# mky.mod
	echo "Extracting mky.mod" 
	unzip -q zips/mky.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/mky.mod-master release/BlitzMax/mod/mky.mod

	unzip -q zips/mky.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/mky.mod-master temp/BlitzMax/mod/mky.mod

	# crypto.mod
	echo "Extracting crypto.mod" 
	unzip -q zips/crypto.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/crypto.mod-master release/BlitzMax/mod/crypto.mod

	unzip -q zips/crypto.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/crypto.mod-master temp/BlitzMax/mod/crypto.mod

	# audio.mod
	echo "Extracting audio.mod" 
	unzip -q zips/audio.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/audio.mod-master release/BlitzMax/mod/audio.mod

	unzip -q zips/audio.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/audio.mod-master temp/BlitzMax/mod/audio.mod

	# steam.mod
	echo "Extracting steam.mod" 
	unzip -q zips/steam.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/steam.mod-master release/BlitzMax/mod/steam.mod

	unzip -q zips/steam.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/steam.mod-master temp/BlitzMax/mod/steam.mod

	# text.mod
	echo "Extracting text.mod" 
	unzip -q zips/text.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/text.mod-master release/BlitzMax/mod/text.mod

	unzip -q zips/text.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/text.mod-master temp/BlitzMax/mod/text.mod

	# dbg.mod
	echo "Extracting dbg.mod" 
	unzip -q zips/dbg.mod.zip -d release/BlitzMax/mod && \
		mv release/BlitzMax/mod/dbg.mod-master release/BlitzMax/mod/dbg.mod

	unzip -q zips/dbg.mod.zip -d temp/BlitzMax/mod && \
		mv temp/BlitzMax/mod/dbg.mod-master temp/BlitzMax/mod/dbg.mod

	case "$PLATFORM" in
		win32)
			if [[ "$OPT_ARCH" == *"x86"* ]]; then
				echo "Extracting x86 MinGW"
				7za x mingw/${MINGW_X86}
				mv mingw32 release/BlitzMax/MinGW32x86

				echo "Extracting x86 MinGW (into temp)"
				7za x mingw/${MINGW_X86}
				mv mingw32 temp/BlitzMax/MinGW32x86
			fi

			if [[ "$OPT_ARCH" == *"x64"* ]]; then
				echo "Extracting x64 MinGW"
				7za x mingw/${MINGW_X64}
				mv mingw64 release/BlitzMax/MinGW32x64

				echo "Extracting x64 MinGW (into temp)"
				7za x mingw/${MINGW_X64}
				mv mingw64 temp/BlitzMax/MinGW32x64
			fi
			;;
	esac

}

build_apps() {
	echo "--------------------"
	echo "-   BUILD - apps   -"
	echo "--------------------"

	# initial bcc, built with current release
	echo "Building Initial bcc"
	BlitzMax/bin/bmk makeapp -r temp/BlitzMax/src/bcc/bcc.bmx && \
		cp temp/BlitzMax/src/bcc/bcc temp/BlitzMax/bin

	# copy current bmk and resources
	echo "Copying bmk"
	cp BlitzMax/bin/bmk temp/BlitzMax/bin && \
		cp BlitzMax/bin/core.bmk temp/BlitzMax/bin && \
		cp BlitzMax/bin/custom.bmk temp/BlitzMax/bin && \
		cp BlitzMax/bin/make.bmk temp/BlitzMax/bin

	G_OPTION=""
	if [ ! -z "$ARCH" ]; then
		G_OPTION="-g $ARCH"
	fi

	# re-build latest bcc with latest release
	echo "Building latest bcc"
	temp/BlitzMax/bin/bmk makeapp -a -r $G_OPTION temp/BlitzMax/src/bcc/bcc.bmx && \
		cp temp/BlitzMax/src/bcc/bcc release/BlitzMax/bin

	# build latest bmk
	echo "Building latest bmk"
	temp/BlitzMax/bin/bmk makeapp -r $G_OPTION temp/BlitzMax/src/bmk/bmk.bmx && \
		cp temp/BlitzMax/src/bmk/bmk release/BlitzMax/bin && \
		cp temp/BlitzMax/bin/core.bmk release/BlitzMax/bin && \
		cp temp/BlitzMax/bin/custom.bmk release/BlitzMax/bin && \
		cp temp/BlitzMax/bin/make.bmk release/BlitzMax/bin

	# build latest docmods
	echo "Building docmods"
	temp/BlitzMax/bin/bmk makeapp -r $G_OPTION temp/BlitzMax/src/docmods/docmods.bmx && \
		cp temp/BlitzMax/src/docmods/docmods release/BlitzMax/bin

	# build latest makedocs
	echo "Building makedocs"
	temp/BlitzMax/bin/bmk makeapp -r $G_OPTION temp/BlitzMax/src/makedocs/makedocs.bmx && \
		cp temp/BlitzMax/src/makedocs/makedocs release/BlitzMax/bin

	# build maxide
	echo "Building maxide"
	temp/BlitzMax/bin/bmk makeapp -r $G_OPTION -t gui temp/BlitzMax/src/maxide/maxide.bmx && \
		cp temp/BlitzMax/src/maxide/maxide release/BlitzMax/MaxIDE
}

build_samples() {
	echo "--------------------"
	echo "- BUILD - samples  -"
	echo "--------------------"

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/aaronkoolen/AStar/astar_demo.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/birdie/games/tempest/tempest.bmx
	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/birdie/games/tiledrop/tiledrop.bmx
	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/birdie/games/zombieblast/game.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/breakout/breakout.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/digesteroids/digesteroids.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/firepaint/firepaint.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/flameduck/circlemania/cmania.bmx
	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/flameduck/oldskool2/oldskool2.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/hitoro/fireworks.bmx
	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/hitoro/shadowimage.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/simonh/fireworks/fireworks.bmx
	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/simonh/snow/snowfall.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/spintext/spintext.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/starfieldpong/starfieldpong.bmx

	temp/BlitzMax/bin/bmk makeapp -r temp/BlitzMax/samples/tempest/tempest.bmx
}


while getopts ":a:b:cfs" options; do
	case "${options}" in
		a)
			OPT_ARCH=${OPTARG}
			;;
		b)
			BUILD_VERSION=${OPTARG}
			;;
		c)
			CLEAN_DIRS=""
			;;
		z)
			CLEAN_ZIPS="y"
			;;
		s)
			BUILD_SAMPLEs="y"
			;;
		:)
			echo "Error: -${OPTARG} requires an argument."
			exit 1
			;;
	esac
done

init

if [ ! -z "$CLEAN_DIRS" ]; then
	clean_dirs
fi
make_dirs
check_base
download
prepare
build_apps
if [ ! -z "$BUILD_SAMPLES" ]; then
	build_samples
fi

echo "--------------------"
echo "-     FINISHED     -"
echo "--------------------"
