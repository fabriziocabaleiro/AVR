#!/bin/bash

set -x

if test $# -eq 0
then
    echo Target not set
    exit 1
else
    TARGET=$1
fi

if test "$TARGET" == "main"
then
    # PCC0001
    ADDR=$(avr-nm -B main.elf | grep -w SRAM_TCP_HEADER | awk '{print $1}')
    if test ${#ADDR} -ne 8
    then
        echo Unexpected address length
        exit 1
    fi

    NADDR=$(printf "%08x" $((0x$ADDR + 60)))
    if test "${ADDR:5:1}" != "${NADDR:5:1}"
    then
        echo SRAM_TCP_HEADER is going to wrap around ZL, reading of options may not work
        exit 1
    fi
fi

