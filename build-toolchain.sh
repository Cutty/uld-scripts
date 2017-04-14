#!/bin/bash

set -e
set -x

stripws()
{
    echo -e $1 | awk '$1=$1'
}

absdir()
{
    pushd "$(echo "$*" | sed -e 's@^~@'"${HOME}"'@')" 2>&1 > /dev/null
    echo `pwd -P`
    popd 2>&1 > /dev/null
}

build_binutils()
{
    rm -rf $BUILD_DIR/binutils
    mkdir -p $BUILD_DIR/binutils
    pushd $BUILD_DIR/binutils

    if [ "x$DEBUG_BUILD_OPTIONS" != "x" ] ; then
        if [ -n "${CFLAGS+x}" ]; then
            ORIG_CFLAGS=$CFLAGS
        fi
        export CFLAGS=$DEBUG_BUILD_OPTIONS
    fi

    $SRC_DIR/$BINUTILS_DIR/configure \
        ${BINUTILS_CONFIG_OPTS} \
        --target=$TARGET \
        --prefix=$INSTALL_DIR \
        --infodir=$INSTALL_DIR_DOC/info \
        --mandir=$INSTALL_DIR_DOC/man \
        --htmldir=$INSTALL_DIR_DOC/html \
        --pdfdir=$INSTALL_DIR_DOC/pdf \
        --enable-poison-system-directories \
        --disable-nls \
        --disable-werror \
        --disable-sim \
        --disable-gdb \
        --enable-interwork \
        --enable-plugins \
        --with-sysroot=$INSTALL_DIR/$TARGET \
        "--with-pkgversion=$PKGVERSION"

    make -j$JOBS
    make install

    if [ "x$DEBUG_BUILD_OPTIONS" != "x" ] ; then
        unset CFLAGS
        if [ -n "${ORIG_CFLAGS+x}" ]; then
            CFLAGS=$ORIG_CFLAGS
            unset ORIG_CFLAGS
        fi
    fi

    popd
}

build_gcc_first()
{
    rm -rf $BUILD_DIR/gcc-first
    mkdir -p $BUILD_DIR/gcc-first
    pushd $BUILD_DIR/gcc-first

    $SRC_DIR/$GCC_DIR/configure \
        --target=$TARGET \
        --prefix=$INSTALL_DIR \
        --libexecdir=$INSTALL_DIR/lib \
        --infodir=$INSTALL_DIR_DOC/info \
        --mandir=$INSTALL_DIR_DOC/man \
        --htmldir=$INSTALL_DIR_DOC/html \
        --pdfdir=$INSTALL_DIR_DOC/pdf \
        --enable-languages=c \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --with-newlib \
        --without-headers \
        --with-gnu-as \
        --with-gnu-ld \
        --with-python-dir=share/gcc-$TARGET \
        --with-sysroot=$INSTALL_DIR/$TARGET \
        ${GCC_CONFIG_OPTS} \
        "${GCC_CONFIG_OPTS_LCPP}" \
        "--with-pkgversion=$PKGVERSION" \
        ${MULTILIB_LIST}

    if [ "x$DEBUG_BUILD_OPTIONS" != "x" ] ; then
        CFLAGS=$DEBUG_BUILD_OPTIONS make -j$JOBS all-gcc
    else
        make -j$JOBS all-gcc
    fi
    make install-gcc

    popd
}

build_newlib()
{
    rm -rf $BUILD_DIR/newlib
    mkdir -p $BUILD_DIR/newlib
    pushd $BUILD_DIR/newlib

    ORIG_PATH=$PATH
    PATH=$INSTALL_DIR/bin:$PATH

    CFLAGS_FOR_TARGET=$TARGET_CFLAGS \
    $SRC_DIR/$NEWLIB_DIR/configure \
        $NEWLIB_CONFIG_OPTS \
        --target=$TARGET \
        --prefix=$INSTALL_DIR \
        --infodir=$INSTALL_DIR_DOC/info \
        --mandir=$INSTALL_DIR_DOC/man \
        --htmldir=$INSTALL_DIR_DOC/html \
        --pdfdir=$INSTALL_DIR_DOC/pdf \
        --enable-newlib-io-long-long \
        --enable-newlib-register-fini \
        --disable-newlib-supplied-syscalls \
        --disable-nls

    make -j$JOBS
    make install

    PATH=$ORIG_PATH
    unset ORIG_PATH

    popd
}

build_newlib_nano()
{
    rm -rf $BUILD_DIR/newlib-nano
    mkdir -p $BUILD_DIR/newlib-nano
    pushd $BUILD_DIR/newlib-nano

    ORIG_PATH=$PATH
    PATH=$INSTALL_DIR/bin:$PATH

    CFLAGS_FOR_TARGET=$TARGET_CFLAGS \
    $SRC_DIR/$NEWLIB_NANO_DIR/configure \
        $NEWLIB_CONFIG_OPTS \
        --target=$TARGET \
        --prefix=$BUILD_DIR/target-libs \
        --disable-newlib-supplied-syscalls \
        --enable-newlib-reent-small \
        --disable-newlib-fvwrite-in-streamio \
        --disable-newlib-fseek-optimization \
        --disable-newlib-wide-orient \
        --enable-newlib-nano-malloc \
        --disable-newlib-unbuf-stream-opt \
        --enable-lite-exit \
        --enable-newlib-global-atexit \
        --enable-newlib-nano-formatted-io \
        --disable-nls

    make -j$JOBS
    make install

    PATH=$ORIG_PATH

    popd
}

build_gcc_final()
{
    rm -f $INSTALL_DIR/$TARGET/usr
    ln -s . $INSTALL_DIR/$TARGET/usr

    rm -rf $BUILD_DIR/gcc-final
    mkdir -p $BUILD_DIR/gcc-final
    pushd $BUILD_DIR/gcc-final

    CFLAGS_FOR_TARGET=$TARGET_CFLAGS \
    CXXFLAGS_FOR_TARGET=$TARGET_CFLAGS \
    $SRC_DIR/$GCC_DIR/configure \
        --target=$TARGET \
        --prefix=$INSTALL_DIR \
        --libexecdir=$INSTALL_DIR/lib \
        --infodir=$INSTALL_DIR_DOC/info \
        --mandir=$INSTALL_DIR_DOC/man \
        --htmldir=$INSTALL_DIR_DOC/html \
        --pdfdir=$INSTALL_DIR_DOC/pdf \
        --enable-languages=c,c++ \
        --enable-plugins \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --with-gnu-as \
        --with-gnu-ld \
        --with-newlib \
        --with-headers=yes \
        --with-python-dir=share/gcc-$TARGET \
        --with-sysroot=$INSTALL_DIR/$TARGET \
        $GCC_CONFIG_OPTS \
        "${GCC_CONFIG_OPTS_LCPP}" \
        "--with-pkgversion=$PKGVERSION" \
        ${MULTILIB_LIST}

    if [ "x$DEBUG_BUILD_OPTIONS" != "x" ]; then
        CXXFLAGS="$DEBUG_BUILD_OPTIONS" \
        INHIBIT_LIBC_CFLAGS="-DUSE_TM_CLONE_REGISTRY=0" \
        make -j$JOBS
    else
        INHIBIT_LIBC_CFLAGS="-DUSE_TM_CLONE_REGISTRY=0" \
        make -j$JOBS
    fi
    make install

    popd
}

copy_newlib_nano()
{
    mkdir -p $INSTALL_DIR/$TARGET/include/newlib-nano
    cp -f $BUILD_DIR/target-libs/$TARGET/include/newlib.h \
        $INSTALL_DIR/$TARGET/include/newlib-nano/newlib.h

    for subdir in . thumb armv7-m thumb-fdpic armv7-m-fdpic; do
        nano_src_dir=$BUILD_DIR/target-libs/$TARGET/lib/$subdir/
        nano_dst_dir=$INSTALL_DIR/$TARGET/lib/$subdir/
        # Note: Copying standard libstdc++/libsupc++ as nano version.
        cp -f "${nano_dst_dir}/libstdc++.a" "${nano_dst_dir}/libstdc++_nano.a"
        cp -f "${nano_dst_dir}/libsupc++.a" "${nano_dst_dir}/libsupc++_nano.a"

        cp -f "${nano_src_dir}/libc.a" "${nano_dst_dir}/libc_nano.a"
        cp -f "${nano_src_dir}/libg.a" "${nano_dst_dir}/libg_nano.a"
        cp -f "${nano_src_dir}/librdimon.a" "${nano_dst_dir}/librdimon_nano.a"
        cp -f "${nano_src_dir}/nano.specs" "${nano_dst_dir}/"
        cp -f "${nano_src_dir}/rdimon.specs" "${nano_dst_dir}/"
        cp -f "${nano_src_dir}/nosys.specs" "${nano_dst_dir}/"
        cp -f "${nano_src_dir}/"*crt0.o "${nano_dst_dir}/"
    done
}

build_gdb()
{
    rm -rf $BUILD_DIR/gdb
    mkdir -p $BUILD_DIR/gdb
    pushd $BUILD_DIR/gdb

    if [ "x$DEBUG_BUILD_OPTIONS" != "x" ] ; then
        if [ -n "${CFLAGS+x}" ]; then
            ORIG_CFLAGS=$CFLAGS
        fi
        export CFLAGS=$DEBUG_BUILD_OPTIONS
    fi

    $SRC_DIR/$GDB_DIR/configure \
        --target=$TARGET \
        --prefix=$INSTALL_DIR \
        --infodir=$INSTALL_DIR_DOC/info \
        --mandir=$INSTALL_DIR_DOC/man \
        --htmldir=$INSTALL_DIR_DOC/html \
        --pdfdir=$INSTALL_DIR_DOC/pdf \
        --disable-nls \
        --disable-sim \
        --disable-gas \
        --disable-binutils \
        --disable-ld \
        --disable-gprof \
        --disable-werror \
        --with-libexpat \
        --with-lzma=no \
        --with-system-gdbinit=$INSTALL_DIR/$HOST_NATIVE/$TARGET/lib/gdbinit \
        --with-python=yes \
        $GDB_CONFIG_OPTS \
        $GDB_EXTRA_CONFIG_OPTS \
        '--with-gdb-datadir='\''${prefix}'\''/'$TARGET'/share/gdb' \
        "--with-pkgversion=$PKGVERSION"

    make -j$JOBS
    make install

    if [ "x$DEBUG_BUILD_OPTIONS" != "x" ] ; then
        unset CFLAGS
        if [ -n "${ORIG_CFLAGS+x}" ]; then
            CFLAGS=$ORIG_CFLAGS
            unset ORIG_CFLAGS
        fi
    fi

    popd
}

build_qemu()
{
    rm -rf $BUILD_DIR/qemu
    mkdir -p $BUILD_DIR/qemu
    pushd $BUILD_DIR/qemu

    pushd $SRC_DIR/$QEMU_DIR
    git submodule update --init dtc
    popd

    LDFLAGS='-Wl,-rpath=\$$ORIGIN' \
    $SRC_DIR/$QEMU_DIR/configure \
        ${QEMU_CONFIG_OPTS} \
        --target-list="gnuarmeclipse-softmmu" \
        --prefix=$INSTALL_DIR \
        --docdir=$INSTALL_DIR_DOC/doc \
        --mandir=$INSTALL_DIR_DOC/man \
        --disable-werror \
        --enable-debug \
        --enable-debug-info

    V=1 make -j$JOBS
    V=1 make install

    popd
}

usage()
{
cat<<EOF
Usage: $0 [--debug] [--root-dir=<path>] [-j<jobs>] [--help] [clean]

Build the GNU Tools with FDPIC ABI support for ARM Embedded Processors.

positional arguments:
    clean               remove build/install files.

optional arguments:
    --debug             enable debug for host programs.
    --root-dir=<path>   src/build/install directory, this should contain
                        toolchain-src.
    -j<jobs>            number of jobs to run.
    --help              show this message.
EOF
}

parse_args()
{
    for arg; do
        echo $arg
        case $arg in
            --debug)
                DEBUG_BUILD_OPTIONS="-O0 -g"
                debug_build=yes
                ;;
            --root-dir=*)
                ROOT_DIR=$(absdir `echo $arg | sed -e "s/--root-dir=//g"`)
                ;;
            -j*)
                JOBS=`echo $arg | sed -e "s/-j//g"`
                ;;
            clean)
                clean=yes
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done
}


# Variables required before parse_args.
HOME=$(echo ${HOME} | sed 's/\/*$//') # Strip trailing '/' on home.
script_path=$(absdir "$(dirname $0)")

# Variables that may be modified by the command line options.
# --debug
debug_build=no
DEBUG_BUILD_OPTIONS=
# --root-dir
ROOT_DIR=$(absdir "${script_path}/..")
# -j
JOBS="${JOBS:-`grep ^processor /proc/cpuinfo|wc -l`}"
# clean
clean=no

# Parse args.
parse_args $@

# Optional environment variables.
BINUTILS_CONFIG_OPTS="${BINUTILS_CONFIG_OPTS:-}"
GCC_CONFIG_OPTS="${GCC_CONFIG_OPTS:-}"
NEWLIB_CONFIG_OPTS="${NEWLIB_CONFIG_OPTS:-}"
GDB_CONFIG_OPTS="${GDB_CONFIG_OPTS:-}"
QEMU_CONFIG_OPTS="${QEMU_CONFIG_OPTS:-}"


# Set the remaining variables.
TARGET=arm-none-eabifdpic
TARGET_CFLAGS='-g -O2 -ffunction-sections -fdata-sections -mthumb -march=armv7-m'
HOST_NATIVE=`uname -m | sed -e 'y/XI/xi/'`-linux-gnu

# Path variables.
SRC_DIR=$ROOT_DIR/toolchain-src
BINUTILS_DIR=binutils
GCC_DIR=gcc
NEWLIB_DIR=newlib
NEWLIB_NANO_DIR=newlib
GDB_DIR=gdb
QEMU_DIR=qemu

BUILD_DIR=$ROOT_DIR/toolchain-build
INSTALL_DIR=$ROOT_DIR/toolchain-install
INSTALL_DIR_DOC=$ROOT_DIR/toolchain-install/share/doc/gcc-$TARGET

# GCC config/make variables.
GCC_CONFIG_OPTS_LCPP="--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm"
PKGVERSION="GNU Tools with FDPIC ABI support for ARM Embedded Processors"
# GCC will filter out multilib targets using MULTILIB* from files in tmake_file
MULTILIB_LIST="--with-multilib-list=armv6-m,armv7-m,armv7e-m,armv7-r,armv8-m.base,armv8-m.main"

# clean 'target'
if [ "x$clean" == "xyes" ]; then
    rm -rf $BUILD_DIR
    rm -rf $INSTALL_DIR
    exit 0
fi

build_binutils
build_gcc_first
build_newlib
build_newlib_nano
build_gcc_final
# Note: Skip building libstdc++/libsupc++ against nano.  Just copy the
# standard versions in copy_newlib_nano for now.
copy_newlib_nano
#build_gdb
build_qemu
