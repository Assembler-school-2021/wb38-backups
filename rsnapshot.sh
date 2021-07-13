#!/bin/bash

FREQ=$1
BKCMD="/usr/bin/rsnapshot -c "
CONFDIR="/etc/rsnapshot.d"
REVMAIL="enrique.sanz@secuoyas.com"
ERRFILE="error.log"

for C in `ls $CONFDIR/*.conf`; do
    echo "Realizando backup de $C con la siguiente configuración:" | tee $ERRFILE
    grep -v "^#" $C | grep ^[a-zA-Z] | tee -a $ERRFILE
    $BKCMD $C $FREQ 2>&1 | tee -a $ERRFILE
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Hubo un error al crear el backup de $C"
        mail -s "Rsnapshot report" $REVMAIL < $ERRFILE
    fi
    rm $ERRFILE
done