#!/bin/bash

# WINDOWS
#
# When using git bash on Windows, you can download wget from here : https://eternallybored.org/misc/wget/
# Copy wget.exe into C:\Program Files\Git\mingw64\bin
#
# Download 7za.exe from the 7-Zip extra archive at: https://www.7-zip.org/download.html
# Copy into C:\Program Files\Git\mingw64\bin
#
# WINDOWS CROSS-COMPILE
#
# Requires p7zip.
# On Linux, install with 'sudo apt install p7zip-full'
# On macOS, install with 'brew install p7zip'
# 
#

usage() {
	echo "Usage: "`basename "$0"`" -b <version> [OPTIONS]"
	echo "    -a <arch>    : Force architecture. e.g. x86, x64, arm, arm64, x86x64 (win32 only)"
	echo "    -r <arch>    : Source architecture. e.g. x86, x64, arm, arm64, x86x64 (win32 only)"
	echo "    -b <version> : Use build version. e.g. 0.105.3.35"
	echo "    -l <platform>: Platform. win32, macos, linux, rpi"
	echo "    -w <version> : Windows compiler version. e.g. mingw or llvm. Defaults to mingw"
	echo "    -t           : Apply additional timestamp to version. This is mainly for weekly builds. Fully released versions should NOT use this."
	echo "    -o           : Build bootstrap."
	echo "    -p           : Create a release package."
	echo "    -c           : Don't clean dirs."
	echo "    -m           : Build all modules."
	echo "    -s           : Build samples."
	echo "    -z           : Clean 'zips' dir."
	echo "    -y <file>    : Write build manifest YAML to <file>"
	exit 0
}

abort() {
	echo "Aborting"
	exit 0
}
	
if [[ $# -eq 0 ]] ; then
	usage
fi

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
trap abort SIGINT

test x$1 = x$'\x00' && shift || { set -o pipefail ; ( exec 2>&1 ; $0 $'\x00' "$@" ) | tee release_build_`date +%Y%m%d%H%M%S`.log ; exit $? ; }

echo ""
echo "Script arguments : $@"
echo ""

ORIG_ARGV=("$@")
SCRIPT_NAME="$(basename "$0")"
SCRIPT_PATH="$0"
# raw args
SCRIPT_ARGS_RAW="$*"

: "${GITHUB_RETRIES:=4}"     # default retries
: "${GITHUB_BACKOFF:=2}"     # base backoff seconds
: "${GITHUB_DEBUG:=0}"       # 1 = verbose debug

OPT_ARCH=""
SRC_ARCH=""
BUILD_VERSION=""
EXE=""
OS_PLATFORM=""
PLATFORM=""
CROSS_COMPILE=""
RELEASE_URL="https://github.com/bmx-ng/bmx-ng/releases/download/"
CLEAN_DIRS="y"
CLEAN_ZIPS=""
BUILD_SAMPLES=""
BUILD_BOOTSTRAP=""
PACKAGE_VERSION=""
USE_TIMESTAMP=""
MINGW_X86="i686-12.2.0-release-posix-dwarf-rt_v10-rev1.7z"
MINGW_X86_URL="https://github.com/niXman/mingw-builds-binaries/releases/download/12.2.0-rt_v10-rev1/i686-12.2.0-release-posix-dwarf-rt_v10-rev1.7z"
MINGW_X64="x86_64-12.2.0-release-posix-seh-rt_v10-rev1.7z"
MINGW_X64_URL="https://github.com/niXman/mingw-builds-binaries/releases/download/12.2.0-rt_v10-rev1/x86_64-12.2.0-release-posix-seh-rt_v10-rev1.7z"
LLVM_MINGW="llvm-mingw-20220323-ucrt-i686"
LLVM_MINGW_ZIP="llvm-mingw-20220323-ucrt-i686.zip"
LLVM_MINGW_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/20220323/llvm-mingw-20220323-ucrt-i686.zip"
WIN_VER="mingw"
TAG_FILENAME="version-tag.txt"
PACKAGE_FILENAME="package-name.txt"
PACKAGE_MIME_FILENAME="package-mime.txt"
MANIFEST_FILE=""
WRITE_MANIFEST=""
MANIFEST_TMP="temp-manifest.yml"

CC_MINGW_ARCH="x86_64"
CC_MINGW_VERSION_LINUX="10-posix"
CC_MINGW_VERSION_MACOS="11.0.0"

PLATFORMS=("win32" "linux" "rpi" "macos")
WIN_MINGW_ARCH=("x86" "x64" "x86x64")
WIN_LLVM_ARCH=("x86" "x64" "arm" "arm64")
MACOS_ARCH=("x64" "arm64")
LINUX_ARCH=("x86" "x64" "arm" "arm64" "riscv64")
RPI_ARCH=("arm" "arm64")
WIN_VERS=("mingw" "llvm")

MOD_LIST=("brl" "pub" "maxgui" "audio" "crypto" "image" "mky" "net" "random" "sdl" "steam" "text" "math" "archive" "collections")
SAMPLE_LIST=("aaronkoolen/AStar/astar_demo.bmx" "birdie/games/tempest/tempest.bmx" "birdie/games/tiledrop/tiledrop.bmx" "birdie/games/zombieblast/game.bmx" "breakout/breakout.bmx" "digesteroids/digesteroids.bmx" "firepaint/firepaint.bmx" "flameduck/circlemania/cmania.bmx" "flameduck/oldskool2/oldskool2.bmx" "hitoro/fireworks.bmx" "hitoro/shadowimage.bmx" "simonh/fireworks/fireworks.bmx" "simonh/snow/snowfall.bmx" "spintext/spintext.bmx" "starfieldpong/starfieldpong.bmx" "tempest/tempest.bmx")

get_arch() {
	ARCH=`uname -m`
}

validate_arch() {
	VAL_ARCH=$1
	TYPE=$2
	PLAT=$3

	case "$PLAT" in
		win32)
			if [[ ! " ${WIN_VERS[*]} " =~ " ${WIN_VER} " ]]; then
				echo "Invalid compiler version: $WIN_VER"
				exit 1
			fi

			case "$WIN_VER" in
				mingw)
					if [[ ! " ${WIN_MINGW_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
						echo "Invalid $TYPE arch for mingw: $VAL_ARCH"
						exit 1
					fi
					;;
				llvm)
					if [[ ! " ${WIN_LLVM_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
						echo "Invalid $TYPE arch for llvm: $VAL_ARCH"
						exit 1
					fi
					;;
			esac
			;;
		macos)
			if [[ ! " ${MACOS_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
				echo "Invalid $TYPE arch for macos: $VAL_ARCH"
				exit 1
			fi
			;;
		linux)
			if [[ ! " ${LINUX_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
				echo "Invalid $TYPE arch for linux: $VAL_ARCH"
				exit 1
			fi
			;;
		rpi)
			if [[ ! " ${RPI_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
				echo "Invalid $TYPE arch for rpi: $VAL_ARCH"
				exit 1
			fi
			;;
	esac
}

raspi_test() {
	PI=$(cat /proc/device-tree/model | tr -d '\0')

	if [[ $PI == Rasp* ]]; then
		OS_PLATFORM="rpi"
		if [[ $ARCH == "armv7l" ]]; then
			ARCH="arm"
		else
			ARCH=""
		fi
	fi
}

expand_platform() {
	case "$ARCH" in
		x86_64)
			ARCH="x64"
			;;
		arm*)
			case "$PLATFORM" in
				linux)
					raspi_test
					;;
			esac
			;;
	esac

	if [ ! -z "$OPT_ARCH" ]; then
		validate_arch $OPT_ARCH "" $PLATFORM
		

		if [[ "$OPT_ARCH" == *"x86"* ]]; then
			ARCH=x86
			CC_MINGW_ARCH="i686"
		else
			ARCH=$OPT_ARCH
		fi
	fi

	if [ -z "$SRC_ARCH" ]; then
		SRC_ARCH=$OPT_ARCH
	else
		validate_arch $SRC_ARCH "source" $OS_PLATFORM
	fi

	if [ -z "$OPT_ARCH" ]; then
		if [ -n "$CROSS_COMPILE" ]; then
			echo "Arch required for cross compile."
			exit -1
		fi

		echo "Arch not specified. Defaulting arch to : $ARCH"
		OPT_ARCH=$ARCH
	fi
}

init() {
	get_arch

	if [ ! -z "$PLATFORM" ]; then
		if [[ ! " ${PLATFORMS[*]} " =~ " ${PLATFORM} " ]]; then
			echo "Unknown plaform: $PLATFORM"
			exit 1
		fi
	fi

	case "$OSTYPE" in
		darwin*)
			OS_PLATFORM="macos"
			;; 
		linux*)
			OS_PLATFORM="linux"
			raspi_test
			;;
		msys*)
			OS_PLATFORM="win32"
			;;
		*)
			echo "Unknown platform: $OSTYPE"
			exit 1
			;;
	esac

	if [ -z "$PLATFORM" ]; then
		PLATFORM=$OS_PLATFORM
	fi

	if [ "$OS_PLATFORM" != "$PLATFORM" ];then
		if [ "$PLATFORM" != "win32" ] && [ "$PLATFORM" != "rpi" ]; then
			echo "Error: Cannot cross-compile to $PLATFORM on $OS_PLATFORM"
			exit 1
		else
			CROSS_COMPILE="y"
		fi
	fi

	expand_platform

	echo "OS Platform     : " $OS_PLATFORM
	echo -n "Target Platform :  $PLATFORM"
	if [ -n "$CROSS_COMPILE" ]; then
			echo " (cross-compile)"
	else
			echo ""
	fi
	echo "System Arch     : " $ARCH
	echo "Source Arch     : " $SRC_ARCH
	if [ -n "$BUILD_BOOTSTRAP" ]; then
		echo "Gen bootstrap   :  enabled"
	fi
}

clean_dirs() {
	echo "--------------------"
	echo "-   CLEAN DIRS     -"
	echo "--------------------"

	echo "Removing release dir"
	rm -rf release

	echo "Removing temp dir"
	rm -rf temp

	if [ -n "$CLEAN_ZIPS" ]; then
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

			if [ ! -d "llvm" ]; then
				echo "Creating llvm dir"
				mkdir -p llvm
			fi
			;;
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

		DOWNLOAD_URL_ARCH=".${SRC_ARCH}"
		ARCHIVE_ARCH="${SRC_ARCH}_"
		PLAT=$OS_PLATFORM
		PLAT_EXTRA=""
		case "$PLAT" in
			win32)
				PLAT_EXTRA=".${WIN_VER}"
				if [[ "$OPT_ARCH" == "x86x64" ]]; then
					DOWNLOAD_URL_ARCH=""
					ARCHIVE_ARCH=""
				fi
				;;
			linux)
				if [ -n "$CROSS_COMPILE" ] && [ "$OS_PLATFORM" == "linux" ]; then
					if [ "$SRC_ARCH" == "arm" ] || [ "$SRC_ARCH" == "arm64" ]; then
						PLAT="rpi"
					fi
				fi
				;;
		esac

		SUFFIX=".tar.xz"
		URL="${RELEASE_URL}v${BUILD_VERSION}.${PLAT}${PLAT_EXTRA}${DOWNLOAD_URL_ARCH}/"
		ARCHIVE="BlitzMax_${PLAT}_"

		case "$PLAT" in
			win32)
				VER="${WIN_VER}_"
				ARCHIVE="${ARCHIVE}${VER}${ARCHIVE_ARCH}"
				SUFFIX=".7z"
				;;
			linux)
				ARCHIVE="${ARCHIVE}${ARCHIVE_ARCH}"
				;;
			rpi) 
				ARCHIVE="${ARCHIVE}${ARCHIVE_ARCH}"
				;;
			macos)
				ARCHIVE="${ARCHIVE}${ARCHIVE_ARCH}"
				SUFFIX=".zip"
				;;
		esac

		ARCHIVE="${ARCHIVE}${BUILD_VERSION}${SUFFIX}"

		if [ ! -f "${ARCHIVE}" ]; then

			URL="${URL}${ARCHIVE}"

			echo "Archive (${ARCHIVE}) not found. Downloading..."

			wget -nv $URL
		fi

		echo "Extracting ${ARCHIVE}"

		case "$OS_PLATFORM" in
			win32)
				7za x ${ARCHIVE}
				;;
			macos)
				unzip -q ${ARCHIVE}
				;;
			*)
				tar -xJf ${ARCHIVE} --no-same-owner
				;;
		esac
	else
		echo "Using local BlitzMax"
	fi
}

download_repo_zip() {
	local name="$1"        # e.g. bmk
	local repo="$2"        # e.g. bmx-ng/bmk
	local ref="$3"         # e.g. master
	local local_zip="$4"   # e.g. zips/bmk.zip

	local sha zip_url zip_sha
	local attempt=0

	sha="$(resolve_github_sha "$repo" "$ref")"
	if [ -z "$sha" ]; then
		echo "Error: failed to resolve ${repo}@${ref} to a commit SHA"
		exit 1
	fi

	# Use codeload for direct ZIP download
	zip_url="https://codeload.github.com/${repo}/zip/${sha}"

	if [ ! -f "$local_zip" ]; then
		echo "Downloading ${name}.zip (${repo}@${ref} -> ${sha})"

		while :; do
			attempt=$((attempt + 1))
			rm -f "$local_zip"  # remove any partial file from prior attempt

			if command -v curl >/dev/null 2>&1; then
				# curl: use -w to get HTTP status, -L redirects
				http_code="$(
					curl -sS -L \
						-o "$local_zip" \
						-w "%{http_code}" \
						"$zip_url" || echo "000"
				)"
				ok=0
				[ "$http_code" = "200" ] && ok=1

				if [ "$ok" -ne 1 ]; then
					[ "${GITHUB_DEBUG:-0}" = "1" ] && echo "Zip download HTTP $http_code (attempt $attempt/${GITHUB_RETRIES:-4}): $zip_url" >&2
				fi
			else
				# wget: parse HTTP status from server response
				tmp_err="$(mktemp)"
				if wget -nv -S -O "$local_zip" "$zip_url" 2>"$tmp_err"; then
					http_code="$(awk '/^  HTTP\//{code=$2} END{print code+0}' "$tmp_err")"
					[ -z "$http_code" ] && http_code=200
				else
					http_code="$(awk '/^  HTTP\//{code=$2} END{print code+0}' "$tmp_err")"
					[ -z "$http_code" ] && http_code=000
					[ "${GITHUB_DEBUG:-0}" = "1" ] && { echo "wget error output:" >&2; tail -n +1 "$tmp_err" >&2; }
				fi
				rm -f "$tmp_err"
			fi

			# Sanity check: ensure it’s actually a ZIP (not an HTML error page)
			# ZIP files start with "PK" (0x50 0x4B)
			is_zip=0
			if [ -f "$local_zip" ]; then
				if head -c 2 "$local_zip" 2>/dev/null | LC_ALL=C grep -q '^PK'; then
					is_zip=1
				fi
			fi

			if [ "${is_zip}" -eq 1 ]; then
				break
			fi

			rm -f "$local_zip"

			# Decide retry
			case "$http_code" in
				429|500|502|503|504|000)
					if [ "$attempt" -lt "${GITHUB_RETRIES:-4}" ]; then
						[ "${GITHUB_DEBUG:-0}" = "1" ] && echo "Retrying zip download after backoff (HTTP $http_code)..." >&2
						_backoff_sleep "$attempt"
						continue
					fi
					;;
			esac

			echo "Error: failed to download ${name}.zip from $zip_url (HTTP $http_code)"
			exit 1
		done
	else
		echo "Using local ${local_zip}"
	fi

	zip_sha="$(sha256_file "$local_zip")"

	if [ -z "$zip_sha" ]; then
		echo "Warning: could not compute sha256 for $local_zip"
	fi

	if [ -n "$WRITE_MANIFEST" ]; then
		manifest_add_source "$MANIFEST_TMP" "$name" "$repo" "$ref" "$sha" "$zip_url" "$local_zip" "$zip_sha"
	fi
}

# Unzips a GitHub archive and renames the single top-level extracted folder.
# Example:
#   unzip_and_rename zips/bmx-ng.zip release bmx-ng BlitzMax
# This will unzip into release/, then move release/bmx-ng-* -> release/BlitzMax
unzip_and_rename() {
	local zip="$1"
	local dest="$2"
	local prefix="$3"   # e.g. "bmx-ng", "bcc", "brl.mod"
	local target="$4"   # e.g. "BlitzMax", "bcc", "brl.mod"

	# Ensure destination exists
	mkdir -p "$dest"

	# Unzip
	unzip -q "$zip" -d "$dest"

	# Find the extracted top-level folder (GitHub archives create exactly one)
	local extracted
	extracted="$(find "$dest" -maxdepth 1 -type d -name "${prefix}-*" | head -n 1)"

	if [ -z "$extracted" ]; then
		echo "Error: Could not find extracted folder matching ${dest}/${prefix}-* from $zip"
		exit 1
	fi

	# Remove existing target if present (optional safety)
	rm -rf "${dest}/${target}"

	mv "$extracted" "${dest}/${target}"
}

ditto_and_rename() {
	local zip="$1"
	local dest="$2"
	local prefix="$3"
	local target="$4"

	mkdir -p "$dest"
	ditto -x -k --sequesterRsrc --rsrc "$zip" "$dest"

	local extracted
	extracted="$(find "$dest" -maxdepth 1 -type d -name "${prefix}-*" | head -n 1)"
	if [ -z "$extracted" ]; then
		echo "Error: Could not find extracted folder matching ${dest}/${prefix}-* from $zip"
		exit 1
	fi

	rm -rf "${dest}/${target}"
	mv "$extracted" "${dest}/${target}"
}

sha256_file() {
	local file="$1"

	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$file" | tr -d '\r' | awk '{print $1}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$file" | tr -d '\r' | awk '{print $1}'
	else
		echo ""
		return 1
	fi
}

download() {
	echo "--------------------"
	echo "-    DOWNLOAD      -"
	echo "--------------------"

	if [ -n "$WRITE_MANIFEST" ]; then
		local created_utc
		created_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

		manifest_begin "$MANIFEST_TMP"
		manifest_add_invocation "$MANIFEST_TMP" "${ORIG_ARGV[@]}"
		manifest_add_build_header "$MANIFEST_TMP" "$created_utc"
	fi

	# mingw
	case "$PLATFORM" in
		win32)
			case "$WIN_VER" in
				mingw)
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
					;;
				llvm)
					if [ ! -f "mingw/$MINGW_X86" ]; then
						echo "Downloading $MINGW_X86"
						wget -nv -P mingw $MINGW_X86_URL
					fi

					if [ ! -f "llvm/$LLVM_MINGW_ZIP" ]; then
						echo "Downloading $LLVM_MINGW_ZIP"
						wget -nv -P llvm $LLVM_MINGW_URL
					fi
					;;
			esac
			;;
	esac

	# base
	download_repo_zip "bmx-ng" "bmx-ng/bmx-ng" "master" "zips/bmx-ng.zip"

	# apps
	download_repo_zip "bcc" "bmx-ng/bcc" "master" "zips/bcc.zip"
	download_repo_zip "bmk" "bmx-ng/bmk" "master" "zips/bmk.zip"
	download_repo_zip "maxide" "bmx-ng/maxide" "master" "zips/maxide.zip"

	# modules
	for mod in "${MOD_LIST[@]}"
	do
		download_repo_zip "${mod}.mod" "bmx-ng/${mod}.mod" "master" "zips/${mod}.mod.zip"
	done

	if [ -n "$WRITE_MANIFEST" ]; then
		case "$PLATFORM" in
		win32)
			case "$WIN_VER" in
			mingw)
				if [[ "$OPT_ARCH" == *"x86"* ]]; then
				manifest_add_toolchain "$MANIFEST_TMP" "mingw-builds-binaries" "win32/mingw" "$MINGW_X86" "$MINGW_X86_URL"
				fi
				if [[ "$OPT_ARCH" == *"x64"* ]]; then
				manifest_add_toolchain "$MANIFEST_TMP" "mingw-builds-binaries" "win32/mingw" "$MINGW_X64" "$MINGW_X64_URL"
				fi
				;;
			llvm)
				manifest_add_toolchain "$MANIFEST_TMP" "mingw-builds-binaries" "win32/llvm" "$MINGW_X86" "$MINGW_X86_URL"
				manifest_add_toolchain "$MANIFEST_TMP" "llvm-mingw" "win32/llvm" "$LLVM_MINGW_ZIP" "$LLVM_MINGW_URL"
				;;
			esac
			;;
		esac
	fi

	if [ -n "$WRITE_MANIFEST" ]; then
		# Default if user gave -y but empty (shouldn’t happen): use build-manifest.yml
		if [ -z "$MANIFEST_FILE" ]; then
			MANIFEST_FILE="build-manifest.yml"
		fi
		mv "$MANIFEST_TMP" "$MANIFEST_FILE"
		echo "Wrote build manifest: $MANIFEST_FILE"
	fi
}

prepare() {
	echo "--------------------"
	echo "-     PREPARE      -"
	echo "--------------------"

	echo "Extracting bmx-ng"
	unzip_and_rename "zips/bmx-ng.zip" "release" "bmx-ng" "BlitzMax"

	rm -rf release/BlitzMax/.github
	rm -rf release/BlitzMax/.gitignore

	mkdir -p release/BlitzMax/mod release/BlitzMax/bin release/BlitzMax/lib

	# copy all to temp
	echo "Copying sources for build (into temp)"
	cp -R release/BlitzMax temp

	# bcc
	echo "Extracting bcc" 
	unzip_and_rename "zips/bcc.zip" "release/BlitzMax/src" "bcc" "bcc"
	unzip_and_rename "zips/bcc.zip" "temp/BlitzMax/src" "bcc" "bcc"

	# bmk
	echo "Extracting bmk"
	unzip_and_rename "zips/bmk.zip"    "release/BlitzMax/src" "bmk"    "bmk"
	unzip_and_rename "zips/bmk.zip"    "temp/BlitzMax/src"    "bmk"    "bmk"

	# maxide
	echo "Extracting maxide"
	unzip_and_rename "zips/maxide.zip" "release/BlitzMax/src" "maxide" "maxide"
	unzip_and_rename "zips/maxide.zip" "temp/BlitzMax/src"    "maxide" "maxide"

	# modules
	for mod in "${MOD_LIST[@]}"
	do
		echo "Extracting ${mod}.mod"
		case "$PLATFORM" in
			macos)
				ditto_and_rename "zips/${mod}.mod.zip" "release/BlitzMax/mod" "${mod}.mod" "${mod}.mod"
				ditto_and_rename "zips/${mod}.mod.zip" "temp/BlitzMax/mod"    "${mod}.mod" "${mod}.mod"
				;;
			*)
				unzip_and_rename "zips/${mod}.mod.zip" "release/BlitzMax/mod" "${mod}.mod" "${mod}.mod"
				unzip_and_rename "zips/${mod}.mod.zip" "temp/BlitzMax/mod"    "${mod}.mod" "${mod}.mod"
				;;
		esac
	done

	case "$PLATFORM" in
		win32)
			case "$WIN_VER" in
				mingw)
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
				llvm)
					echo "Extracting llvm-mingw"
					7za x llvm/${LLVM_MINGW_ZIP}
					mv ${LLVM_MINGW} release/BlitzMax/llvm-mingw

					echo "Extracting llvm-mingw (into temp)"
					7za x llvm/${LLVM_MINGW_ZIP}
					mv ${LLVM_MINGW} temp/BlitzMax/llvm-mingw

					echo "Extracting x86 MinGW (into temp)"
					7za x mingw/${MINGW_X86}
					mv mingw32 temp/BlitzMax/MinGW32x86
					;;
			esac
			;;
	esac

	case "$PLATFORM" in
		macos)
			echo "Copying bootstrap config"
			cp release/BlitzMax/src/bootstrap/bootstrap.cfg release/BlitzMax/bin
			cp temp/BlitzMax/src/bootstrap/bootstrap.cfg temp/BlitzMax/bin
			
			echo "Configuring bootstrap for $PLATFORM/$ARCH"
			echo -e "t\tmacos\t"$ARCH"\n$(cat temp/BlitzMax/bin/bootstrap.cfg)" > temp/BlitzMax/bin/bootstrap.cfg
			
			echo "Copying scripts"
			cp release/BlitzMax/src/macos/build_dist.sh release/BlitzMax
			cp release/BlitzMax/src/macos/run_me_first.command release/BlitzMax
			echo "Configuring script for $ARCH"
			sed -i "" "s/ARCH/$ARCH/g" release/BlitzMax/build_dist.sh
			;;
		esac
	
}

build_apps() {
	echo "--------------------"
	echo "-   BUILD - apps   -"
	echo "--------------------"

	G_OPTION=""
	if [ -n "$ARCH" ]; then
		G_OPTION="-g $ARCH"
	fi

	# detect bootstrap
	if [ -d BlitzMax/dist/bootstrap ]; then

		PLAT=$PLATFORM
		case "$PLATFORM" in
			rpi) 
				PLAT="raspberrypi"
				;;
		esac

		BCC_BUILD="bcc.console.release.${PLAT}.${ARCH}.build"
		BMK_BUILD="bmk.console.release.${PLAT}.${ARCH}.build"

		# detect macos bootstrap build
		case "$PLATFORM" in
			macos)
				# try the other arch
				if [ ! -f "BlitzMax/dist/bootstrap/src/bcc/$BCC_BUILD" ]; then
					case "$ARCH" in 
						arm64)
							BCC_BUILD="bcc.console.release.macos.x64.build"
							BMK_BUILD="bmk.console.release.macos.x64.build"
							;;
						x64)
							BCC_BUILD="bcc.console.release.macos.arm64.build"
							BMK_BUILD="bmk.console.release.macos.arm64.build"
							;;
					esac
				fi
				;;
		esac

		if [ -f "BlitzMax/dist/bootstrap/src/bcc/$BCC_BUILD" ]; then
			echo "Bootstrap detected"
			USING_BOOTSTRAP="y"

			CUR=`pwd`
			cd BlitzMax/dist/bootstrap/src/bcc

			echo "Building bootstrap bcc"
			source "$BCC_BUILD"

			cd "$CUR"

			if [ ! -s "BlitzMax/bin/bcc" ]; then
				echo "bcc does not exist. Copying bootstrap bcc to bin"
				cp BlitzMax/dist/bootstrap/src/bcc/bcc BlitzMax/bin/bcc
			fi

			cd BlitzMax/dist/bootstrap/src/bmk

			echo "Building bootstrap bmk"
			source "$BMK_BUILD"

			cd "$CUR"

			if [ ! -s "BlitzMax/bin/bmk" ]; then
				echo "bmk does not exist. Copying bootstrap bmk to bin"
				cp BlitzMax/dist/bootstrap/src/bmk/bmk BlitzMax/bin/bmk
			fi
		fi
	fi

	# initial bcc, built with current release
	echo ""
	echo "Building Initial bcc (using current release)"
	if ! BlitzMax/bin/bmk makeapp -r -single temp/BlitzMax/src/bcc/bcc.bmx; then
		echo "Failed to build initial bcc"
		exit 1
	fi
	cp temp/BlitzMax/src/bcc/bcc temp/BlitzMax/bin


	# initial bmk, built with new bcc and current bmk
	echo ""
	echo "Copying current bmk"
	cp BlitzMax/bin/bmk temp/BlitzMax/bin && \
		cp BlitzMax/bin/core.bmk temp/BlitzMax/bin && \
		cp BlitzMax/bin/custom.bmk temp/BlitzMax/bin && \
		cp BlitzMax/bin/make.bmk temp/BlitzMax/bin

	echo "Building Initial bmk"

	if [ -n "$CROSS_COMPILE" ];then
		OPTION=""
	else
		OPTION="$G_OPTION"
	fi

	TARG_ARCH=""

	# for windows native build, we need to ensure correct arch is set for initial bmk build
	# otherwise it will use the default arch of the starting bmk, while the chosen compiler may be of a different arch
	if [ -z "$CROSS_COMPILE" ];then
		case "$PLATFORM" in
			win32)
				if [[ "$OPT_ARCH" == "x64" ]]; then
					TARG_ARCH="-g x64"
				elif [[ "$OPT_ARCH" == *"x86"* ]]; then
					TARG_ARCH="-g x86"
				fi
				;;
		esac
	fi

	echo ""
	echo "Building Initial bmk (using initial bcc and current bmk)"
	if temp/BlitzMax/bin/bmk makeapp -r -single $TARG_ARCH temp/BlitzMax/src/bmk/bmk.bmx; then
		retries=0
		while [ $retries -lt 30 ]
		do
			rm temp/BlitzMax/bin/bmk && \
			cp temp/BlitzMax/src/bmk/bmk temp/BlitzMax/bin 2>/dev/null
			if [ $? -eq 0 ]; then
				break
			else
				echo "bmk is busy... Attempt $((retries + 1))"
				sleep 1
				retries=$((retries + 1))
			fi
		done
		if [ $retries -eq 30 ]; then
			echo "bmk still busy after 30 seconds. Exiting..."
			exit -1
		fi
	else
		echo ""
		echo "Failed to build bmk"
		exit -1
	fi

	# copy bmk resources
	echo "Copying bmk resources"
	cp temp/BlitzMax/src/bmk/core.bmk temp/BlitzMax/bin && \
		cp temp/BlitzMax/src/bmk/custom.bmk temp/BlitzMax/bin && \
		cp temp/BlitzMax/src/bmk/make.bmk temp/BlitzMax/bin

	C_OPTION="-single"

	if [ -n "$CROSS_COMPILE" ];then

		case "$PLATFORM" in
			win32)
			
				C_OPTION="-l $PLATFORM -single"
				C_EXT=".exe"

				echo "Applying cross-platform configuration"
				case "$OS_PLATFORM" in
					macos)
						echo "

						addoption path_to_ar \"/opt/homebrew/bin/$CC_MINGW_ARCH-w64-mingw32-ar\"
						addoption path_to_ld \"/opt/homebrew/bin/$CC_MINGW_ARCH-w64-mingw32-ld\"
						addoption path_to_gcc \"/opt/homebrew/bin/$CC_MINGW_ARCH-w64-mingw32-gcc\"
						addoption path_to_gpp \"/opt/homebrew/bin/$CC_MINGW_ARCH-w64-mingw32-g++\"
						addoption path_to_windres \"/opt/homebrew/bin/$CC_MINGW_ARCH-w64-mingw32-windres\"

						addoption path_to_mingw_lib \"/opt/homebrew/Cellar/mingw-w64/$CC_MINGW_VERSION_MACOS/toolchain-$CC_MINGW_ARCH/$CC_MINGW_ARCH-w64-mingw32/lib\"
						addoption path_to_mingw_lib2 \"/opt/homebrew/Cellar/mingw-w64/$CC_MINGW_VERSION_MACOS/toolchain-$CC_MINGW_ARCH/$CC_MINGW_ARCH-w64-mingw32/lib\"

						" >> temp/BlitzMax/bin/custom.bmk

						;;
					linux)
						echo "

						addoption path_to_ar \"/usr/bin/$CC_MINGW_ARCH-w64-mingw32-ar\"
						addoption path_to_ld \"/usr/bin/$CC_MINGW_ARCH-w64-mingw32-ld\"
						addoption path_to_gcc \"/usr/bin/$CC_MINGW_ARCH-w64-mingw32-gcc\"
						addoption path_to_gpp \"/usr/bin/$CC_MINGW_ARCH-w64-mingw32-g++\"
						addoption path_to_windres \"/usr/bin/$CC_MINGW_ARCH-w64-mingw32-windres\"

						addoption path_to_mingw_lib \"/usr/lib/gcc/$CC_MINGW_ARCH-w64-mingw32/$CC_MINGW_VERSION_LINUX\"
						addoption path_to_mingw_lib2 \"/usr/$CC_MINGW_ARCH-w64-mingw32/lib\"

						" >> temp/BlitzMax/bin/custom.bmk
						;;
				esac
				;;
			rpi)
				C_OPTION="-l raspberrypi -single"
				C_EXT=""
				;;
		esac
	fi

	echo ""
	echo "Ready to build"
	echo ""
	echo "bcc version : $(temp/BlitzMax/bin/bcc -v)"
	echo "bmk version : $(temp/BlitzMax/bin/bmk -v)"
	echo ""

	case "$PLATFORM" in
		macos)
			echo "Creating bootstrap"

			if ! temp/BlitzMax/bin/bmk makebootstrap -a -r; then
				echo ""
				echo "Failed to build bootstrap"
				exit -1
			fi
			
			echo "Copying bootstrap to release"
			mv temp/BlitzMax/dist release/BlitzMax

			echo "Copying bmk resources"
			cp temp/BlitzMax/src/bmk/core.bmk release/BlitzMax/bin && \
			cp temp/BlitzMax/src/bmk/custom.bmk release/BlitzMax/bin && \
			cp temp/BlitzMax/src/bmk/make.bmk release/BlitzMax/bin
			;;
		*)
			# re-build latest bcc with latest release
			echo "Building latest bcc"
			if ! temp/BlitzMax/bin/bmk makeapp -a -r $G_OPTION $C_OPTION temp/BlitzMax/src/bcc/bcc.bmx; then
				echo ""
				echo "Failed to build latest bcc"
				exit -1
			fi
			cp temp/BlitzMax/src/bcc/bcc$C_EXT release/BlitzMax/bin

			if [ -z "$CROSS_COMPILE" ];then
				echo "Copying latest bcc to bin"
				# build using the latest bcc
				cp temp/BlitzMax/src/bcc/bcc$C_EXT temp/BlitzMax/bin
			fi

			# clean build with the latest modules
			echo ""
			echo "Resetting modules to compile with latest bcc"
			rm -rf temp/BlitzMax/mod
			cp -R release/BlitzMax/mod temp/BlitzMax

			# build latest bmk
			echo "Building latest bmk"
			if ! temp/BlitzMax/bin/bmk makeapp -a -r $G_OPTION $C_OPTION temp/BlitzMax/src/bmk/bmk.bmx; then
				echo ""
				echo "Failed to build latest bmk"
				exit -1
			fi
			cp temp/BlitzMax/src/bmk/bmk$C_EXT release/BlitzMax/bin && \
			cp temp/BlitzMax/src/bmk/core.bmk release/BlitzMax/bin && \
			cp temp/BlitzMax/src/bmk/custom.bmk release/BlitzMax/bin && \
			cp temp/BlitzMax/src/bmk/make.bmk release/BlitzMax/bin

			if [ -z "$CROSS_COMPILE" ];then
				echo "Copying latest bmk to bin"
				# build using the latest bmk
				cp temp/BlitzMax/src/bmk/bmk$C_EXT temp/BlitzMax/bin
			fi

			# build bootstrap
			if [ -n "$BUILD_BOOTSTRAP" ];then
				echo "Configuring bootstrap"
				cp temp/BlitzMax/src/bootstrap/bootstrap.cfg temp/BlitzMax/bin

				PLAT=$PLATFORM

				case "$PLATFORM" in
					rpi) 
						PLAT="raspberrypi"
						;;
				esac

				echo -e "\nt\t${PLAT}\t${ARCH}\n" >> temp/BlitzMax/bin/bootstrap.cfg

				echo "Building bootstrap"
				if ! temp/BlitzMax/bin/bmk makebootstrap; then
					echo ""
					echo "Failed to build bootstrap"
					exit -1
				fi
				mv temp/BlitzMax/dist release/BlitzMax
			fi

			# build latest docmods
			echo "Building docmods"
			if ! temp/BlitzMax/bin/bmk makeapp -r $G_OPTION $C_OPTION temp/BlitzMax/src/docmods/docmods.bmx; then
				echo ""
				echo "Failed to build docmods"
				exit -1
			fi
			cp temp/BlitzMax/src/docmods/docmods$C_EXT release/BlitzMax/bin

			# build latest makedocs
			echo "Building makedocs"
			if ! temp/BlitzMax/bin/bmk makeapp -r $G_OPTION $C_OPTION temp/BlitzMax/src/makedocs/makedocs.bmx; then
				echo ""
				echo "Failed to build makedocs"
				exit -1
			fi
			cp temp/BlitzMax/src/makedocs/makedocs$C_EXT release/BlitzMax/bin

			# build maxide
			echo "Building maxide"
			if ! temp/BlitzMax/bin/bmk makeapp -r $G_OPTION $C_OPTION -t gui temp/BlitzMax/src/maxide/maxide.bmx; then
				echo ""
				echo "Failed to build maxide"
				exit -1
			fi
			cp temp/BlitzMax/src/maxide/maxide$C_EXT release/BlitzMax/MaxIDE$C_EXT
			;;
	esac
}

get_version() {
	# Extracting the version from bcc's version.bmx file
	bcc_version=$(grep 'Const BCC_VERSION:String' temp/BlitzMax/src/bcc/version.bmx | sed -n 's/.*Const BCC_VERSION:String = "\(.*\)".*/\1/p')

	# Extracting the version from bmk's version.bmx file
	bmk_version=$(grep 'Const BMK_VERSION:String' temp/BlitzMax/src/bmk/version.bmx | sed -n 's/.*Const BMK_VERSION:String = "\(.*\)".*/\1/p')

	# Building the PACKAGE_VERSION variable
	PACKAGE_VERSION="$bcc_version.$bmk_version"

	# Append the timestamp
	if [ -n "$USE_TIMESTAMP" ]; then
		timestamp=$(date +%Y%m%d%H%M)
		PACKAGE_VERSION="$PACKAGE_VERSION.$timestamp"
	fi

	if [ -n "$WRITE_MANIFEST" ] && [ -n "$MANIFEST_FILE" ] && [ -f "$MANIFEST_FILE" ]; then
		manifest_set_package_version "$MANIFEST_FILE" "$PACKAGE_VERSION"
	fi

	echo "Building package version $PACKAGE_VERSION"
}

write_version_tag() {
	echo "Writing version tag to ${TAG_FILENAME}"
	echo "$PACKAGE_VERSION" > ${TAG_FILENAME}
}

package() {
	echo "--------------------"
	echo "-     PACKAGE      -"
	echo "--------------------"

	echo "Cleanup"
	rm -f release/BlitzMax/mod/image.mod/raw.mod/examples/gh2.rw2

	if [ -n "$WRITE_MANIFEST" ] && [ -n "$MANIFEST_FILE" ] && [ -f "$MANIFEST_FILE" ]; then
		echo "Copying manifest to release"
		manifest_copy_to_release "$MANIFEST_FILE" "release/BlitzMax"
	fi

	Z_SUFFIX=""
	PACKAGE_MIME_TYPE=""

	case "$PLATFORM" in
		win32)
			PACK_ARCH="_$OPT_ARCH"
			if [[ "$OPT_ARCH" == "x86x64" ]]; then
				PACK_ARCH=""
			fi
			ZIP_THREADS=""
			if [[ -z "$CROSS_COMPILE" ]]; then
				ZIP_THREADS="-mmt4"
			fi
			ZIP="BlitzMax_win32${PACK_ARCH}_${WIN_VER}_${PACKAGE_VERSION}"
			Z_SUFFIX=".7z"
			PACKAGE_MIME_TYPE="application/x-7z-compressed"
			echo "Creating release zip : ${ZIP}${Z_SUFFIX}"

			cd release
			7za a -mx9 ${ZIP_THREADS} ../${ZIP}${Z_SUFFIX} BlitzMax/
			cd ..
			;;
		linux)
			ZIP="BlitzMax_linux_${OPT_ARCH}_${PACKAGE_VERSION}"
			Z_SUFFIX=".tar.xz"
			PACKAGE_MIME_TYPE="application/x-xz"
			echo "Creating release zip : ${ZIP}${Z_SUFFIX}"
			
			cd release
			tar -cf ${ZIP}.tar BlitzMax --no-same-owner
			xz -z ${ZIP}.tar
			mv ${ZIP}.tar.xz ..
			cd ..
			;;
		rpi)
			ZIP="BlitzMax_rpi_${OPT_ARCH}_${PACKAGE_VERSION}"
			Z_SUFFIX=".tar.xz"
			PACKAGE_MIME_TYPE="application/x-xz"
			echo "Creating release zip : ${ZIP}"
			
			cd release
			tar -cf ${ZIP}.tar BlitzMax
			xz -z ${ZIP}.tar
			mv ${ZIP}.tar.xz ..
			cd ..
			;;
		macos)
			ZIP="BlitzMax_macos_${OPT_ARCH}_${PACKAGE_VERSION}"
			Z_SUFFIX=".zip"
			PACKAGE_MIME_TYPE="application/zip"
			echo "Creating release zip : ${ZIP}${Z_SUFFIX}"
			
			cd release
			zip -9 -r -q ${ZIP}${Z_SUFFIX} BlitzMax
			mv ${ZIP}${Z_SUFFIX} ..
			cd ..
			;;
	esac

	echo "Writing package filename to ${PACKAGE_FILENAME}"
	echo "${ZIP}${Z_SUFFIX}" > ${PACKAGE_FILENAME}
	echo "Writing package mime type to ${PACKAGE_MIME_FILENAME}"
	echo "${PACKAGE_MIME_TYPE}" > ${PACKAGE_MIME_FILENAME}
}

build_modules() {
	echo "--------------------"
	echo "- BUILD - modules  -"
	echo "--------------------"

	G_OPTION=""
	if [ -n "$ARCH" ]; then
		G_OPTION="-g $ARCH"
	fi

	temp/BlitzMax/bin/bmk makemods -a $G_OPTION
}

build_samples() {
	echo "--------------------"
	echo "- BUILD - samples  -"
	echo "--------------------"

	G_OPTION=""
	if [ -n "$ARCH" ]; then
		G_OPTION="-g $ARCH"
	fi

	for sample in "${SAMPLE_LIST[@]}"
	do
		temp/BlitzMax/bin/bmk makeapp -r $G_OPTION temp/BlitzMax/samples/${sample}
	done
}

_backoff_sleep() {
	local attempt="$1"
	local base="${GITHUB_BACKOFF}"
	sleep $(( base ** attempt ))
}

# Extract a JSON "message" field from GitHub error payloads
_json_message() {
	sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

# Extract a header value from a headers file
_header_value() {
	local key="$1" file="$2"
	awk -v k="$key" '
		BEGIN{IGNORECASE=1}
		$0 ~ ("^" k ":") {
			sub(/^[^:]*:[[:space:]]*/, "", $0)
			sub(/\r$/, "", $0)
			print $0
			exit
		}
	' "$file"
}

# Fetch JSON from GitHub API (uses GITHUB_TOKEN if available to avoid rate limits)
github_api_get() {
	local url="$1"
	local attempt=0

	# Common headers
	local headers=(
		-H "Accept: application/vnd.github+json"
		-H "X-GitHub-Api-Version: 2022-11-28"
	)
	# Auth header only if token is available
	if [ -n "$GITHUB_TOKEN" ]; then
		headers+=(-H "Authorization: Bearer $GITHUB_TOKEN")
	fi

	while :; do
		attempt=$((attempt + 1))

		if command -v curl >/dev/null 2>&1; then
			local body_file headers_file http_code
			body_file="$(mktemp)"
			headers_file="$(mktemp)"

			http_code="$(
				curl -sS -L \
					"${headers[@]}" \
					-D "$headers_file" \
					-o "$body_file" \
					-w "%{http_code}" \
					"$url" || echo "000"
			)"

			# Pull some useful headers
			local rl_remaining rl_reset retry_after req_id
			rl_remaining="$(_header_value "X-RateLimit-Remaining" "$headers_file")"
			rl_reset="$(_header_value "X-RateLimit-Reset" "$headers_file")"
			retry_after="$(_header_value "Retry-After" "$headers_file")"
			req_id="$(_header_value "X-GitHub-Request-Id" "$headers_file")"

			if [ "$GITHUB_DEBUG" = "1" ]; then
				echo "GitHub API GET (attempt $attempt/$GITHUB_RETRIES): HTTP $http_code  url=$url" >&2
				[ -n "$req_id" ] && echo "  X-GitHub-Request-Id: $req_id" >&2
				[ -n "$rl_remaining" ] && echo "  X-RateLimit-Remaining: $rl_remaining" >&2
				[ -n "$rl_reset" ] && echo "  X-RateLimit-Reset: $rl_reset" >&2
				[ -n "$retry_after" ] && echo "  Retry-After: $retry_after" >&2
			fi

			# success!
			if [ "$http_code" = "200" ]; then
				cat "$body_file"
				rm -f "$body_file" "$headers_file"
				return 0
			fi

			# On errors, log a short body message (helps with 403/404/rate-limit)
			if [ "$GITHUB_DEBUG" = "1" ]; then
				local msg
				msg="$(head -c 1200 "$body_file" | _json_message)"
				echo "  Error message: ${msg:-<none>}" >&2
				echo "  Body (first 400 bytes):" >&2
				head -c 400 "$body_file" >&2 || true
				echo >&2
			fi

			rm -f "$body_file" "$headers_file"

			# Decide retry behaviour based on status
			case "$http_code" in
				429|500|502|503|504|000)
					# Respect Retry-After if present (best for 429 / abuse limits)
					if [ -n "$retry_after" ] && [ "$retry_after" -ge 1 ] 2>/dev/null; then
						if [ "$attempt" -lt "$GITHUB_RETRIES" ]; then
							[ "$GITHUB_DEBUG" = "1" ] && echo "  Sleeping Retry-After: $retry_after" >&2
							sleep "$retry_after"
							continue
						fi
					fi

					if [ "$attempt" -lt "$GITHUB_RETRIES" ]; then
						_backoff_sleep "$attempt"
						continue
					fi
					echo "GitHub API request failed with status $http_code: $url" >&2
					return 1
					;;
				403)
					# 403 can be rate-limit, abuse-limit, or permission.
					# If rate limit remaining is 0, back off and retry; otherwise fail fast.
					if [ "$rl_remaining" = "0" ] && [ "$attempt" -lt "$GITHUB_RETRIES" ]; then
						# If reset is available, sleep until reset (cap to something sane if you like)
						if [ -n "$rl_reset" ] && [ "$rl_reset" -ge 1 ] 2>/dev/null; then
							# rl_reset is unix epoch seconds
							local now wait
							now="$(date +%s)"
							wait=$(( rl_reset - now + 1 ))
							if [ "$wait" -gt 0 ] && [ "$wait" -lt 600 ]; then
								[ "$GITHUB_DEBUG" = "1" ] && echo "  Rate-limited; sleeping $wait seconds until reset" >&2
								sleep "$wait"
								continue
							fi
						fi
						_backoff_sleep "$attempt"
						continue
					fi
					echo "GitHub API rate limit exceeded or access forbidden: $url" >&2
					return 1
					;;
				*)
					# Non-retriable (404, 401, 422, etc.)
					echo "GitHub API request failed with status $http_code: $url" >&2
					return 1
					;;
			esac

		else
			# --- wget fallback ---
			local out=""
			if [ -n "$GITHUB_TOKEN" ]; then
				out="$(wget -qO- \
					--header="Accept: application/vnd.github+json" \
					--header="X-GitHub-Api-Version: 2022-11-28" \
					--header="Authorization: Bearer $GITHUB_TOKEN" \
					"$url" 2>/dev/null)" || out=""
			else
				out="$(wget -qO- \
					--header="Accept: application/vnd.github+json" \
					--header="X-GitHub-Api-Version: 2022-11-28" \
					"$url" 2>/dev/null)" || out=""
			fi

			if [ -n "$out" ]; then
				echo "$out"
				return 0
			fi

			if [ "$GITHUB_DEBUG" = "1" ]; then
				echo "GitHub API GET failed (wget) attempt $attempt/$GITHUB_RETRIES: $url" >&2
			fi

			if [ "$attempt" -lt "$GITHUB_RETRIES" ]; then
				_backoff_sleep "$attempt"
				continue
			fi

			return 1
		fi
	done
}

resolve_github_sha() {
  local repo="$1"
  local ref="$2"
  local url="https://api.github.com/repos/${repo}/commits/${ref}"

  local json
  if ! json="$(github_api_get "$url")"; then
    [ "$GITHUB_DEBUG" = "1" ] && echo "Error: GitHub API request failed for ${repo}@${ref} (${url})" >&2
    echo ""
    return 1
  fi

  local sha=""
  if command -v jq >/dev/null 2>&1; then
    sha="$(printf '%s' "$json" | jq -r '.sha // empty' 2>/dev/null)"
  else
    sha="$(printf '%s' "$json" | sed -n 's/.*"sha":[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p' | head -n 1)"
  fi

  if [ -z "$sha" ] && [ "$GITHUB_DEBUG" = "1" ]; then
    local msg
    msg="$(printf '%s' "$json" | _json_message)"
    echo "Error: Could not extract SHA for ${repo}@${ref}. GitHub message: ${msg:-<none>}" >&2
    echo "Raw JSON (first 400 bytes):" >&2
    printf '%s' "$json" | head -c 400 >&2 || true
    echo >&2
  fi

  echo "$sha"
}

manifest_begin() {
	local out="$1"

	cat > "$out" <<EOF
schema: 1
product: BlitzMax NG
package_version: ""
EOF

	echo "" >> "$out"
}

manifest_add_build_header() {
	local out="$1"
	local created_utc="$2"

	cat >> "$out" <<EOF
build:
	created_utc: "$created_utc"
	platform: "$PLATFORM"
	arch: "$OPT_ARCH"
	source_arch: "$SRC_ARCH"
	host_os: "$OS_PLATFORM"
	cross_compile: "$( [ -n "$CROSS_COMPILE" ] && echo true || echo false )"
	win_compiler: "$WIN_VER"

sources:
EOF
}

manifest_add_invocation() {
	local out="$1"
	shift

	echo "invocation:" >> "$out"
	echo "  script: \"$SCRIPT_PATH\"" >> "$out"
	echo "  command_line: \"$SCRIPT_ARGS_RAW\"" >> "$out"
	echo "  argv:" >> "$out"

	for arg in "$@"; do
		# basic YAML escaping for quotes/backslashes
		local esc="${arg//\\/\\\\}"
		esc="${esc//\"/\\\"}"
		echo "    - \"$esc\"" >> "$out"
	done

	echo "" >> "$out"
}

manifest_add_source() {
	local out="$1"
	local name="$2"
	local repo="$3"
	local ref="$4"
	local sha="$5"
	local zip_url="$6"
	local local_zip="$7"
	local zip_sha="$8"

	cat >> "$out" <<EOF
	- name: "$name"
		repo: "$repo"
		ref: "$ref"
		commit: "$sha"
		zip_url: "$zip_url"
		local_zip: "$local_zip"
		zip_sha256: "$zip_sha"
EOF
}

manifest_add_toolchain() {
	local out="$1"
	local name="$2"
	local used_for="$3"
	local filename="$4"
	local url="$5"

	# Ensure toolchains section exists once
	if ! grep -q "^toolchains:" "$out" 2>/dev/null; then
		echo "" >> "$out"
		echo "toolchains:" >> "$out"
	fi

	cat >> "$out" <<EOF
	- name: "$name"
		used_for: "$used_for"
		filename: "$filename"
		url: "$url"
EOF
}

manifest_set_package_version() {
	local out="$1"
	local version="$2"

	# Replace the first package_version line
	# macOS sed needs -i "" ; GNU sed needs -i
	if sed --version >/dev/null 2>&1; then
		sed -i "s/^package_version: .*/package_version: \"${version}\"/" "$out"
	else
		sed -i "" "s/^package_version: .*/package_version: \"${version}\"/" "$out"
	fi
}

manifest_copy_to_release() {
	local tmp="$1"
	local final="$2"

	mv "$tmp" "$final"
	echo "Wrote build manifest: $final"
}

while getopts ":a:b:w:r:l:pcfmsztoy:" options; do
	case "${options}" in
		a)
			OPT_ARCH=${OPTARG}
			;;
		r)
			SRC_ARCH=${OPTARG}
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
		m)
			BUILD_MODULES="y"
			;;
		s)
			BUILD_SAMPLEs="y"
			;;
		p)
			PACKAGE_VERSION="y"
			;;
		t)
			USE_TIMESTAMP="y"
			;;
		w)
			WIN_VER=${OPTARG}
			;;
		l)
			PLATFORM=${OPTARG}
			;;
		o)
			BUILD_BOOTSTRAP="y"
			;;
		y)
			MANIFEST_FILE=${OPTARG}
			WRITE_MANIFEST="y"
			;;
		:)
			echo "Error: -${OPTARG} requires an argument."
			exit 1
			;;
	esac
done

init
if [ -n "$CLEAN_DIRS" ]; then
	clean_dirs
fi
make_dirs
check_base
download
prepare
build_apps
if [ -n "$BUILD_MODULES" ]; then
	build_modules
fi
if [ -n "$PACKAGE_VERSION" ]; then
	get_version
	write_version_tag
	package
fi
if [ -n "$BUILD_SAMPLES" ]; then
	build_samples
fi

echo "--------------------"
echo "-     FINISHED     -"
echo "--------------------"
