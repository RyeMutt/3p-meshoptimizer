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

# the name of the file to include in version.c
VERSION_HEADER_FILE="$MESHOPT_SOURCE_DIR/src/meshoptimizer.h"

# the name of the #define macro to print from the included header in version.c
VERSION_MACRO="MESHOPTIMIZER_VERSION"

build=${AUTOBUILD_BUILD_ID:=0}

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

            # populate version_file - prefer this method of regex extraction
            # with a multitude of different tools - that can and does break over time.
            cl /DVERSION_HEADER_FILE="\"$VERSION_HEADER_FILE\"" \
               /DVERSION_MACRO="$VERSION_MACRO" \
               /Fo"$(cygpath -w "$stage/version.obj")" \
               /Fe"$(cygpath -w "$stage/version.exe")" \
               "$(cygpath -w "$top/version.c")"
            "$stage/version.exe" > "$stage/version.txt"
            rm "$stage"/version.{obj,exe}
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
            
            # populate version_file - prefer this method of regex extraction
            # with a multitude of different tools - that can and does break over time.
            cc -DVERSION_HEADER_FILE="\"$VERSION_HEADER_FILE\"" \
               -DVERSION_MACRO="$VERSION_MACRO" \
               -o "$stage/version" "$top/version.c"
            "$stage/version" > "$stage/version.txt"
            rm "$stage/version"
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

            mkdir -p "$stage/lib/release"
            mv "$stage/lib/libmeshoptimizer.a" \
                "$stage/lib/release/libmeshoptimizer.a"

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
