#!/bin/bash

function check_sram_offset
{
    a=$(avr-nm $1 | grep -w $2 | awk '{print $1}' | sed 's/^0\+//')
    test -z "$a" && a=0
    b=$(avr-nm $1 | grep -w $3 | awk '{print $1}' | sed 's/^0\+//')
    test -z "$b" && b=0
    echo "$2 == $3 - $4 ---> 0x$a == 0x$b - $4"
    diff=$((0x$a - 0x$b + $4))
    case $diff in
        0)
            ;;
        *)
            echo "Error: '$2' not '$4' bytes before '$3'"
            exit 1
            ;;
    esac
}

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
        echo Error: Unexpected address length
        exit 1
    fi

    NADDR=$(printf "%08x" $((0x$ADDR + 60)))
    if test "${ADDR:5:1}" != "${NADDR:5:1}"
    then
        echo "Error: SRAM_TCP_HEADER ($ADDR) is going to wrap around ZL, reading of options may not work"
        exit 1
    fi

    # PCC0002
    check_sram_offset Objs/enc28j60.o SRAM_ENC_RPKT_STATUS2 SRAM_ENC_ETH_HEADER 1

    # PCC0003
    check_sram_offset Objs/enc28j60.o SRAM_ENC_ETH_TYPE_LEN_L SRAM_ENC_MAC_DST_PTR 1

    # Example of check_sram_offset with offset > 1
    # # PCC0003
    # TBL_LEN=$(($(avr-gcc -mmcu=atmega8 -E comm.S|grep ^"SRAM_COMM_TABLE:" | sed 's/.*skip//')))
    # check_sram_offset Objs/comm.o SRAM_COMM_TABLE SRAM_COMM_RR_ITERATOR $TBL_LEN
fi

