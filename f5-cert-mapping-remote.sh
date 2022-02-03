#!/bin/bash
# Search /config and sub directories (partitions) for bigip.conf files

function get_certs_remote_tmsh() {
  LIST=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} run util bash -c "\"find /config -name bigip.conf -type f |  xargs  awk '\$2 == \\\\\\\"virtual\\\\\\\" {print \$3}' 2>/dev/null \"" | sort -u)
  #LIST=`find /config -name bigip.conf -type f |  xargs  awk '$2 == "virtual" {print $3}' 2> /dev/null | sort -u`
  VIRTS_CNT=0

  for VIRTS in ${LIST}
  do
    PROF=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} show /ltm virtual ${VIRTS} profiles | grep -B 1 " Ltm::${FILTERSTRING} Profile:" | cut -d: -f4 | grep -i "[a-z]" | sed s'/ //'g| sort -u)
    test -n "${PROF}" 2>&- && {
      VIRTS_CNT=$(expr $VIRTS_CNT + 1)
      for PCRT in ${PROF}
      do
        CERT=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} list /ltm profile ${COMMANDSTRING} ${PCRT} |  awk '$1 == "cert" {print $2}' 2> /dev/null | sort -u)
        test -n "${CERT}" 2>&- && {
          CIPHERS=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} list /ltm profile ${COMMANDSTRING} ${PCRT} ciphers | grep ciphers | awk '{print $2}')
          if [ "$CERT" = "none" ]
          then
            EXPIRATION="N/A"
            SAN="N/A"
          else
            CARTSTRING=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} list sys file ssl-cert recursive one-line | grep "ssl-cert ${CERT}")
            EXPIRATION=`grep -oP '(?<=expiration-string \").*GMT' <<<"$CARTSTRING"` #Expiration date of certificate
            SAN=`grep -oP '(?<=subject-alternative-name \").*?(?=\")' <<<"$CARTSTRING"` #Subject Alternative Name of certificate
            CN=`grep -oP '(?<=subject \"CN=).*?(?=,)' <<<"$CARTSTRING"` #Certificate Common Name
            CA=`grep -oP '(?<=issuer \"CN=).*?(?=,)' <<<"$CARTSTRING"` #Issuer Common Name (Certificate authority)
          fi
          VIP=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} list ltm virtual ${VIRTS} | grep destination | awk '{print $2}')
          echo "${SC}${HOST}${SP}${VIRTS}${SP}${PCRT}${SP}${FILTERSTRING}${SP}${CERT}${SP}${CIPHERS}${SP}${VIP}${SP}${CA}${SP}${EXPIRATION}${SP}${CN}${SP}${SAN}${SC}"
        }
      done
    }
  done
  return $VIRTS_CNT
}




SP=" " #separator character
SC="" #start/stop character
INPUT="-" # use STDIN for geting the hosts
while getopts ":hcsxf:" opt; do
  case $opt in
    h)
      echo \
"usage: $0 [-h] [-c] [-s] [-x] [-f <file>]

Get VIP certificate sumary from F5 
Summary shows boath client and server side certificates by default

Optional arguments:
 -h show this help message and exit
 -c show client side certificates only
 -s show server side certificates only
 -x generate the output in CSV format
 -f specify file from wich the hosts should be taken"
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
      SP="\",\""
      SC="\""
      ;;
    f)
      INPUT=${OPTARG}
      ;;
      
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      echo "See \"$0 -h\" for help" 1>&2
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

echo -n Username: >&2
read -e USR
echo -n Password: >&2
read -e -r -s PASS
echo >&2


if [ "$INPUT" == "-" ]; then
  echo "Enter Hosts to be used. for Ending the input press Ctrl+D" >&2
fi
HOSTS=$(cat $INPUT)

if [ "$SP" = " " ]
then
  echo "Host:       Virtual:          Profile:        Profile Type:        Certificate:          Ciphers:           VIP:          Issuer:     Cartificate Expiration:       CN:       SAN:"
  echo "_________________________________________________________________________________________________________________________________"
else
  echo "Host:,Virtual:,Profile:,Profile Type:,Certificate:,Ciphers:,VIP:,Issuer:,Cartificate Expiration:,CN:,SAN:"
fi

VIRTS_COUNT=0

#HOSTS="f5hosts.txt"
for HOST in $HOSTS

do
  ping $HOST -c 1 >/dev/null
  if [ $? -ne 0 ]; then
    echo $HOST unreachable >&2;
    continue
  fi

  if [ -z ${client+x} ] 
  then
    COMMANDSTRING="client-ssl"
    FILTERSTRING="ClientSSL"
    get_certs_remote_tmsh
    #VIRTS_COUNT=`expr $VIRTS_COUNT + $?`
  fi

  if [ -z ${server+x} ]
  then
    COMMANDSTRING="server-ssl"
    FILTERSTRING="ServerSSL"
    get_certs_remote_tmsh
    #VIRTS_COUNT=`expr $VIRTS_COUNT + $?`
  fi

done

if [ "$SP" = " " ]
then
  echo "Virtual server count: ${VIRTS_COUNT}"
fi

exit 0



