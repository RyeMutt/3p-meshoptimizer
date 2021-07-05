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

version_str="0.16"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${version_str}.${build}" > "${stage}/VERSION.txt"

pushd "$MESHOPT_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        windows*)
            load_vsvars

            cmake ../${MESHOPT_SOURCE_DIR} -G"$AUTOBUILD_WIN_CMAKE_GEN" \
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

            stage_lib="${stage}"/lib
            stage_release="${stage_lib}"/release

            # Move the libs to release folder
            # mv "${stage}"/lib "${stage}"/release
            # mkdir "${stage_lib}"
            # mv "${stage}"/release "${stage_release}"


            # Make sure libs are stamped with the -id
            # fix_dylib_id doesn't really handle symlinks
            pushd "$stage_release"
            fix_dylib_id "meshoptimizer.dylib" || \
                echo "fix_dylib_id meshoptimizer.dylib failed, proceeding"
            fix_dylib_id "meshoptimizer.dylib" || \
                echo "fix_dylib_id meshoptimizer.dylib failed, proceeding"
            popd
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

            popd
            mkdir -p "${stage}/lib/release"
            mv ${stage}/lib/*.a "${stage}/lib/release"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp -a LICENSE.md "$stage/LICENSES/meshoptimizer.txt"
popd

#mkdir -p "$stage"/docs/meshoptimizer/
#cp -a README.Linden "$stage"/docs/meshoptimizer/