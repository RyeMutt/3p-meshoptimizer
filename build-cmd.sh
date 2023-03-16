#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x

# make errors fatal
set -e

# complain about unreferenced environment variables
set -u

if [ -z "$AUTOBUILD" ] ; then
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

top="$(pwd)"
stage="$top/stage"

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

MESHOPT_SOURCE_DIR="meshoptimizer"

# version will end with something like '160 /* 0.16 */'
version=$(perl -ne 's/^#define MESHOPTIMIZER_VERSION ([0-9]{3,4})/$1/ && print' "${MESHOPT_SOURCE_DIR}/src/meshoptimizer.h" | tr -d '\r' )
version_adj=$(awk -v a="$version" 'BEGIN{b = 1000; print (a / b)}')

build=${AUTOBUILD_BUILD_ID:=0}
echo "${version_adj}.${build}" > "${stage}/VERSION.txt"

pushd "$MESHOPT_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        windows*)
            load_vsvars

            cmake ../${MESHOPT_SOURCE_DIR} -G "$AUTOBUILD_WIN_CMAKE_GEN" \
                -A "$AUTOBUILD_WIN_VSPLATFORM" \
                -DCMAKE_INSTALL_PREFIX="$(cygpath -m "$stage")"
            build_sln "meshoptimizer.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" "Install"


            mkdir -p "$stage/lib/release"
            mv "$stage/lib/meshoptimizer.lib" \
                "$stage/lib/release/meshoptimizer.lib"

            mkdir -p "$stage/include/meshoptimizer"
            mv "$stage/include/meshoptimizer.h" \
                "$stage/include/meshoptimizer/meshoptimizer.h"

            rm -r "$stage/lib/cmake"

        ;;

        darwin*)
            cmake . -DCMAKE_INSTALL_PREFIX:STRING="${stage}"

            make
            make install

            mkdir -p "$stage/lib/release"
            mv "$stage/lib/libmeshoptimizer.a" \
                "$stage/lib/release/libmeshoptimizer.a"

            mkdir -p "$stage/include/meshoptimizer"
            mv "$stage/include/meshoptimizer.h" \
                "$stage/include/meshoptimizer/meshoptimizer.h"

            rm -r "$stage/lib/cmake"
        ;;

        linux*)
            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE}"

            # Handle any deliberate platform targeting
            if [ -z "${TARGET_CPPFLAGS:-}" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            rm -rf build && mkdir build && pushd build

            cmake .. -DCMAKE_INSTALL_PREFIX:STRING="${stage}" \

            make -j $AUTOBUILD_CPU_COUNT
            make install

            mkdir -p "$stage/lib/release"
            mv "$stage/lib/meshoptimizer.a" \
                "$stage/lib/release/meshoptimizer.a"

            mkdir -p "$stage/include/meshoptimizer"
            mv "$stage/include/meshoptimizer.h" \
                "$stage/include/meshoptimizer/meshoptimizer.h"

            rm -r "$stage/lib/cmake"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp -a LICENSE.md "$stage/LICENSES/meshoptimizer.txt"
popd

#mkdir -p "$stage"/docs/meshoptimizer/
#cp -a README.Linden "$stage"/docs/meshoptimizer/
