#!/bin/bash

# Usage: ./run-qemu.sh [image]
# Optional environment variables:
# QEMU_PATH: path to directory with qemu binary
# QEMU_BIN: qemu binary
# GDB_PORT: gdb server port
# MCU: qemu mcu switch
# BOARD: qemu board switch

#if [ "x$1" == "x--gdb" ]; then
#    HOST_GDB="gdb --args"
#    shift
#fi
for i in "$@"; do
    case $i in
    --gdb)
        HOST_GDB="gdb --args"
        shift
        ;;
    --loop)
        LOOP=yes
        shift
        ;;
    *)
        ;;
    esac
done

if [ "x$LOOP" == "xyes" ]; then
    echo looping
    trap "exit" INT
fi


#DEFAULT_IMAGE=$(dirname $0)/../uld-fdpic/bin/uld.elf
DEFAULT_IMAGE=$(dirname $0)/../uld-fdpic/bin/uld.elf

QEMU_PATH="${QEMU_PATH:-$(dirname $0)/../toolchain-install/bin}"
QEMU_BIN="${QEMU_BIN:-qemu-system-gnuarmeclipse}"
GDB_PORT="${GDB_PORT:-1234}"
MCU="${MCU:-STM32F103RB}"
BOARD="${BOARD:-generic}"
IMAGE="${1:-$DEFAULT_IMAGE}"

# Strip trailing '/' on directories and expand home directory.
QEMU_PATH=$(echo ${QEMU_PATH} | sed 's/\/*$//')
HOME=$(echo ${HOME} | sed 's/\/*$//')
IMAGE=$(echo ${IMAGE} | sed -e 's@^~@'"${HOME}"'@')

# qemu arguments:
# -S: freeze cpu on start.
# --semihosting-config enable=on,target=native: enable ARM SWI semihosting.
# --verbose --verbose: enable more debug messages.
# -monitor stdio: setup qemu monitor in this terminal.
# -serial null: setup null serial port.
# --gdb tcp::${GDB_PORT}: enable gdbserver on port.
# -mcu ${MCU}: select MCU.
# -board ${BOARD}: select board.
# --image ${IMAGE}: image to run (can be ELF file).
while
    ${HOST_GDB} ${QEMU_PATH}/${QEMU_BIN} \
        -S \
        --semihosting-config enable=on,target=native \
        --verbose --verbose \
        -monitor stdio \
        -serial null \
        --gdb tcp::${GDB_PORT} \
        -mcu ${MCU} \
        -board ${BOARD} \
        --image ${IMAGE}
    [ $? -eq 0 ] && [ "x$LOOP" == "xyes" ]
do :; done
