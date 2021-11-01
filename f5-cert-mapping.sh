#!/bin/bash
# Search /config and sub directories (partitions) for bigip.conf files

function get_certs() {

  LIST=`find /config -name bigip.conf |  xargs  awk '$2 == "virtual" {print $3}' 2> /dev/null | sort -u`
  VIRTS=0
  for VAL in ${LIST}
  do
    PROF=`tmsh show /ltm virtual ${VAL} profiles 2> /dev/null | grep -B 1 " Ltm::${filterstring} Profile:" | cut -d: -f4 | grep -i "[a-z]" | sed s'/ //'g| sort -u`
    test -n "${PROF}" 2>&- && {
      VIRTS=`expr $VIRTS + 1`
      for PCRT in ${PROF}
      do
        CERT=`tmsh list /ltm profile ${commandstring} ${PCRT} |  awk '$1 == "cert" {print $2}' 2> /dev/null | sort -u`
        test -n "${CERT}" 2>&- && {
          CIPHERS=`tmsh list /ltm profile ${commandstring} ${PCRT} ciphers | grep ciphers | awk '{print $2}'`
          if [ "$CERT" = "none" ]
          then
            EXPIRATION="N/A"
          else
            EXPIRATION=`tmsh list sys file ssl-cert recursive one-line | grep ${CERT} | grep -oh 'expiration-string .*GMT' | cut -c 20-`
          fi
          VIP=`tmsh list ltm virtual ${VAL} | grep destination | awk '{print $2}'`
          echo "${VAL}${SP}${PCRT}${SP}${CERT}${SP}${CIPHERS}${SP}${VIP}${SP}${EXPIRATION}"
        }
      done
    }
  done
  return $VIRTS
}


SP=" " #separator character
while getopts ":hcsx" opt; do
  case $opt in
    h)
      echo \
"usage: $0 [-h] [-c] [-s] [-x]

Get VIP certivicate sumary from F5 
Summary shows boath client and server side certificates by default

Optional arguments:
 -h show this help message and exit
 -c show client side certificates only
 -s show server side certificates only
 -x generate the output in CSV format"
      exit 0
      ;;
    c)
      if [ -z ${client+x} ]
      then
        server=""
      else
        echo "Parameter -c and -s can not be used together" 1>&2
        echo "See \"$0 -h\" for help" 1>&2
        exit 1 
      fi
      ;;
    s)
      if [ -z ${server+x} ]
      then
        client=""
      else
        echo "Parameter -c and -s can not be used together" 1>&2
        echo "See \"$0 -h\" for help" 1>&2
        exit 1 
      fi
      ;;
    x)
      SP=","
      ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      echo "See \"$0 -h\" for help" 1>&2
      exit 1
      ;;
  esac
done

if [ "$SP" = " " ]
then
  echo "Virtual:          Profile:        Certificate:          Ciphers:           VIP:          Cartificate Expiration:"
  echo "________________________________________________________________________________________________________________"
else
  echo "Virtual:,Profile:,Certificate:,Ciphers:,VIP:,Cartificate Expiration:"
fi

VIRTS_COUNT=0

if [ -z ${server+x} ]
then
  commandstring="server-ssl"
  filterstring="ServerSSL"
  get_certs
  VIRTS_COUNT=`expr $VIRTS_COUNT + $?`
fi


if [ -z ${client+x} ] 
then
  commandstring="client-ssl"
  filterstring="ClientSSL"
  get_certs
  VIRTS_COUNT=`expr $VIRTS_COUNT + $?`
fi


if [ "$SP" = " " ]
then
  echo "Virtual server count: ${VIRTS_COUNT}"
fi

exit 0


