#!/bin/bash
# Search /config and sub directories (partitions) for bigip.conf files

function get_certs_remote_tmsh() {
  LIST=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} run util bash -c "\"find /config -name bigip.conf -type f |  xargs  awk '\$2 == \\\\\\\"virtual\\\\\\\" {print \$3}' 2>/dev/null \"" | sort -u)

  #VIRTS_CNT=0 #count VIPS

  for VIRTS in ${LIST}
  do
    echo -en "\r\033[K" 1>&2
    echo -en "Processing VS ${VIRTS} on host ${HOST}" 1>&2
    PROF=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} show /ltm virtual ${VIRTS} profiles | grep -B 1 " Ltm::${FILTERSTRING} Profile:" | cut -d: -f4 | grep -i "[a-z]" | sed s'/ //'g| sort -u)
    test -n "${PROF}" 2>&- && {
      #VIRTS_CNT=$(expr $VIRTS_CNT + 1) #count VIPS
      for PCRT in ${PROF}
      do
        CERT=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} list /ltm profile ${COMMANDSTRING} ${PCRT} | awk '$1 == "cert" {print $2}' 2> /dev/null | sed '/^\/\|^none$/!s/^/Common\//' | sed 's/^\///' | sort -u )
        test -n "${CERT}" 2>&- && {
          CIPHERS=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} list /ltm profile ${COMMANDSTRING} ${PCRT} ciphers | grep ciphers | awk '{print $2}')
          if [ "$CERT" = "none" ]
          then
            EXPIRATION="N/A"
            SAN="N/A"
          else
            CARTSTRING=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} 'cd /; list sys file ssl-cert recursive one-line' | grep "ssl-cert ${CERT}")
            EXPIRATION=`grep -oP '(?<=expiration-string \").*GMT' <<<"$CARTSTRING"` #Expiration date of certificate
            SAN=`grep -oP '(?<=subject-alternative-name \").*?(?=\")' <<<"$CARTSTRING"` #Subject Alternative Name of certificate
            CN=`grep -oP '(?<=subject \"CN=).*?(?=,)' <<<"$CARTSTRING"` #Certificate Common Name
            CA=`grep -oP '(?<=issuer \"CN=).*?(?=,)' <<<"$CARTSTRING"` #Issuer Common Name (Certificate authority)
          fi
          VIP=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST}  list ltm virtual ${VIRTS} | grep destination | awk '{print $2}')
          echo "${HOST};${VIRTS};${PCRT};${FILTERSTRING};${CERT};${CIPHERS};${VIP};${CA};${EXPIRATION};${CN};${SAN}"
        }
      done
    }
  done
  echo -en "\r\033[K" 1>&2
  #return $VIRTS_CNT #count VIPS
}


function get_certs_remote_bash() { #TODO
  LIST=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} "find /config -name bigip.conf -type f |  xargs  awk '\$2 == \"virtual\" {print \$3}' 2>/dev/null " | sort -u)

  #VIRTS_CNT=0 #count VIPS

  for VIRTS in ${LIST}
  do
    echo -en "\r\033[K" 1>&2
    echo -en "Processing VS ${VIRTS} on host ${HOST}" 1>&2
    PROF=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} tmsh show /ltm virtual ${VIRTS} profiles | grep -B 1 " Ltm::${FILTERSTRING} Profile:" | cut -d: -f4 | grep -i "[a-z]" | sed s'/ //'g| sort -u)
    test -n "${PROF}" 2>&- && {
      #VIRTS_CNT=$(expr $VIRTS_CNT + 1) #count VIPS
      for PCRT in ${PROF}
      do
        CERT=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} tmsh list /ltm profile ${COMMANDSTRING} ${PCRT} |  awk '$1 == "cert" {print $2}' 2> /dev/null | sed '/^\/\|^none$/!s/^/Common\//' | sed 's/^\///' | sort -u)
        test -n "${CERT}" 2>&- && {
          CIPHERS=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} tmsh list /ltm profile ${COMMANDSTRING} ${PCRT} ciphers | grep ciphers | awk '{print $2}')
          if [ "$CERT" = "none" ]
          then
            EXPIRATION="N/A"
            SAN="N/A"
          else
            CARTSTRING=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} tmsh -q -c "\"cd /; list sys file ssl-cert recursive one-line\"" | grep "ssl-cert ${CERT}")
            EXPIRATION=`grep -oP '(?<=expiration-string \").*GMT' <<<"$CARTSTRING"` #Expiration date of certificate
            SAN=`grep -oP '(?<=subject-alternative-name \").*?(?=\")' <<<"$CARTSTRING"` #Subject Alternative Name of certificate
            CN=`grep -oP '(?<=subject \"CN=).*?(?=,)' <<<"$CARTSTRING"` #Certificate Common Name
            CA=`grep -oP '(?<=issuer \"CN=).*?(?=,)' <<<"$CARTSTRING"` #Issuer Common Name (Certificate authority)
          fi
          VIP=$(echo ${PASS} | sshpass ssh -q -o ConnectTimeout=50 ${USR}@${HOST} tmsh list ltm virtual ${VIRTS} | grep destination | awk '{print $2}')
          echo "${HOST};${VIRTS};${PCRT};${FILTERSTRING};${CERT};${CIPHERS};${VIP};${CA};${EXPIRATION};${CN};${SAN}"
        }
      done
    }
  done
  echo -en "\r\033[K" 1>&2
  #return $VIRTS_CNT #count VIPS

}


function get_certs_remote() {
  echo -n Username: >&2
  read -e USR
  echo -n Password: >&2
  read -e -r -s PASS
  echo >&2


  if [ "$INPUT" == "-" ]; then
    echo "Enter Hosts to be used. for Ending the input press Ctrl+D" >&2
  fi
  HOSTS=$(cat $INPUT)

  echo "Host:;Virtual:;Profile:;Profile Type:;Certificate:;Ciphers:;VIP:;Issuer:;Cartificate Expiration:;CN:;SAN:"

  #VIRTS_COUNT=0 #count VIPS

  for HOST in $HOSTS
  do
    ping $HOST -c 1 >/dev/null
    if [ $? -ne 0 ]; then
      echo $HOST unreachable >&2;
      continue
    fi
    echo -en "Connecting to ${HOST}" 1>&2
    echo $PASS | sshpass ssh -q -o ConnectTimeout=5 ${USR}@${HOST} quit >/dev/null 2> /dev/null
    # $? == 127  - bash
    # $? == 0  - tmsh
    # $? == 5  - unable to authenticate
    # $? == other - Other error code
    RET=$?
    if [ $RET -eq 0 ]; then
      # $? == 0  - tmsh
      FUNCT="get_certs_remote_tmsh"
    elif [ $RET -eq 127 ]; then
      FUNCT="get_certs_remote_bash"
      # $? == 127  - bash
    else
      echo $HOST not able to authenticate error code $RET >&2;
      continue
    fi
    echo -en "\r\033[K" 1>&2
    echo -en "Starting procesing host ${HOST}" 1>&2
    if [ -z ${client+x} ] 
    then
      COMMANDSTRING="client-ssl"
      FILTERSTRING="ClientSSL"
      ${FUNCT}
      #VIRTS_COUNT=`expr $VIRTS_COUNT + $?` #count VIPS
    fi

    if [ -z ${server+x} ]
    then
      COMMANDSTRING="server-ssl"
      FILTERSTRING="ServerSSL"
      ${FUNCT}
      #VIRTS_COUNT=`expr $VIRTS_COUNT + $?` #count VIPS
    fi
    echo -e "Processing on ${HOST} finished" 1>&2
  done
}

##TODO
# replace `` with $()

function get_certs_local() { #not used for remote connections
  LIST=`find /config -name bigip.conf -type f |  xargs  awk '$2 == "virtual" {print $3}' 2> /dev/null | sort -u`
  #VIRTS_CNT=0 #count VIPS
  for VIRTS in ${LIST}
  do
    echo -en "\r\033[K" 1>&2
    echo -en "Processing VS ${VIRTS}" 1>&2
    PROF=`tmsh show /ltm virtual ${VIRTS} profiles 2> /dev/null | grep -B 1 " Ltm::${FILTERSTRING} Profile:" | cut -d: -f4 | grep -i "[a-z]" | sed s'/ //'g| sort -u`
    test -n "${PROF}" 2>&- && {
      #VIRTS_CNT=`expr $VIRTS_CNT + 1` #count VIPS
      for PCRT in ${PROF}
      do
        CERT=`tmsh list /ltm profile ${COMMANDSTRING} ${PCRT} |  awk '$1 == "cert" {print $2}' 2> /dev/null | sed '/^\/\|^none$/!s/^/Common\//' | sed 's/^\///' | sort -u`
        test -n "${CERT}" 2>&- && {
          CIPHERS=`tmsh list /ltm profile ${COMMANDSTRING} ${PCRT} ciphers | grep ciphers | awk '{print $2}'`
          if [ "$CERT" = "none" ]
          then
            EXPIRATION="N/A"
            SAN="N/A"
            CN="N/A"
            CA="N/A"
          else
            CARTSTRING=`tmsh -q -c 'cd /; list sys file ssl-cert recursive one-line' | grep "ssl-cert ${CERT}"`
            EXPIRATION=`grep -oP '(?<=expiration-string \").*GMT' <<<"$CARTSTRING"` #Expiration date of certificate
            SAN=`grep -oP '(?<=subject-alternative-name \").*?(?=\")' <<<"$CARTSTRING"` #Subject Alternative Name of certificate
            CN=`grep -oP '(?<=subject \"CN=).*?(?=,)' <<<"$CARTSTRING"` #Certificate Common Name
            CA=`grep -oP '(?<=issuer \"CN=).*?(?=,)' <<<"$CARTSTRING"` #Issuer Common Name (Certificate authority)
            
          fi
          VIP=`tmsh list ltm virtual ${VIRTS} | grep destination | awk '{print $2}'`
          echo "${VIRTS};${PCRT};${FILTERSTRING};${CERT};${CIPHERS};${VIP};${CA};${EXPIRATION};${CN};${SAN}"
        }
      done
    }
  done
  echo -en "\r\033[K" 1>&2
  #return $VIRTS_CNT #count VIPS

}

function get_certs() {

  if command -v tmsh &> /dev/null
  then
    # running on f5 directly

    echo "Virtual:;Profile:;Profile Type:;Certificate:;Ciphers:;VIP:;Issuer:;Cartificate Expiration:;CN:;SAN:"
    if [ -z ${client+x} ] 
    then
      COMMANDSTRING="client-ssl"
      FILTERSTRING="ClientSSL"
      get_certs_local
      #VIRTS_COUNT=`expr $VIRTS_COUNT + $?` #count VIPS
    fi

    if [ -z ${server+x} ]
    then
      COMMANDSTRING="server-ssl"
      FILTERSTRING="ServerSSL"
      get_certs_local
      #VIRTS_COUNT=`expr $VIRTS_COUNT + $?` #count VIPS
    fi

  else
    # not running on F5
    
    get_certs_remote
    

  fi
}




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
 -f specify file from wich the hosts should be taken (not available when executing from F5)"
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
      CSV_EXP=true
      ;;
    f)
      if command -v tmsh &> /dev/null
      then
        echo "Option -f can not be used when executed from F5"  1>&2
        exit 1
      fi
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


if [ "$CSV_EXP" = true ] ; then

  echo "$(get_certs | sed 's/;/","/g' | awk '{ print "\""$0"\""}' 2> /dev/null)"

else

  get_certs | column -t -s\; #| less -S

fi

exit 0
