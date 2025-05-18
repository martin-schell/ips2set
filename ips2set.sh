#!/usr/bin/env bash                                                                                                                                                     
# if [ "$EUID" -ne 0 ]; then
#   echo "This script must be run as root."
#   exit 1
# fi

SCRIPTNAME=$(basename "$0" | cut -d'.' -f1)
LOG_FILE="$SCRIPTNAME".log

usage() {
    echo "Usage: $0"
    echo "-f, --file FILE       Input file with IP addresses, separated by newline"
    echo "-s, --set-name NAME   Name of IP set"
    echo "-n, --networks        Optional parameter: Only necessary, if input file contents network addresses.
                                If set, then the script creates an IP set of type hash:net (default: hash:ip)."
    echo "-6                    Optional parameter: Only necessary, if input file contensts IPv6 addresses (default: IPv4)."
    echo "-h, --help            Print usage"
}

# Logging function
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$TIMESTAMP [$LEVEL] $MESSAGE" >> "$LOG_FILE"
}

# Default values
family=inet
type=ip

# Check if no parameters were passed
if [ $# -eq 0 ]; then
    echo "Error: No arguments provided."
    usage
    exit 1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
    -f | --file)
        if [[ -z "$2" || "$2" == --* ]]; then
            echo "Error: -f, --file requires a value."
            exit 1
        elif [ ! -f "$2" ]; then
            echo "ERROR" "Input file $2 does not exist" | tee log
            exit 1
        fi
        in_file="$2"
        log "DEBUG" "Input file: $2"
        shift 2
        ;;
    -s | --set-name)
        set_name="$2"
        log "DEBUG" "Set name: $2"
        shift 2
        ;;
    -n | --networks)
        type=net
        log "DEBUG" "Type: $type"
        shift 1
        ;;
    -6)
        family="inet6"
        log "DEBUG" "Family: $family"
        shift 1
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use -h, --help for usage."
        exit 1
        ;;
    esac
done

IPV4_PATTERN='(\b25[0-5]|\b2[0-4][0-9]|\b[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}(\/([1-9]|3[0-2]|[1-2][0-9]))*$'
IPV6_PATTERN='^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|:([0-9a-fA-F]{1,4}:){1,7}|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:))(\/([1-9]|[0-9][0-9]|11[0-9]|12[0-8]))*$'

# Conditions for exit status 1
## If file contents IPv6 addresses and IPv4 addresses.
if grep -E --quiet "$IPV4_PATTERN" "$in_file" && grep -E --quiet "$IPV6_PATTERN" "$in_file"; then
    echo "ERROR: $in_file contains IPv4 and IPv6 addresses"
    echo "Only use files that contain either IPv4 or IPv6 addresses" 
    exit 1
## If file contents IPv6 addresses and option -6 is missing.
elif grep -E --quiet "$IPV6_PATTERN" "$in_file" && [ $family != "inet6" ]; then
    echo "ERROR: $in_file contains IPv6 addresses and option \"-6\" is missing."
    echo "IPv6 requires option \"-6\""
    exit 1
## If file contents IPv4 addresses and option -6 is set.
elif grep -E --quiet "$IPV4_PATTERN" "$in_file" && [ $family == "inet6" ]; then
    echo "ERROR: $in_file contains IPv4 addresses and option \"-6\" is set."
    echo "Only use option \"-6\" for IPv6."
    exit 1
## If file contents IPv4 network addresses, except of netmask /32, and option -n is missing.
elif grep -E --quiet '(/[1-9]|[1-2][0-9]|3[0-1])$' "$in_file" && [ $type != "net" ]; then
    echo "ERROR: $in_file contains IPv4 network addresses and option \"-n\" is missing."
    echo "IPv4 network addresses (except of /32) require option \"-n\"."
    exit 1
fi

# Create array with addresses
ips_in_file=$(cat "$in_file")
log "DEBUG" "ips_in_file: $ips_in_file"

# If set does not exists
if ! ipset list "$set_name" >& /dev/null; then
    log "INFO" "Create $set_name"
    ipset create "$set_name" hash:$type family $family
    new_set=0
else
    new_set=1
fi

# Add valid IP addresses in ipset
for ip in $ips_in_file;
do

    if ipset add -q "$set_name" "$ip" -exist; then
        if ipset add -q "$set_name" "$ip"; then
            ipset add -q "$set_name" "$ip"
            log "INFO" "$ip added into $set_name"
        else
            log "INFO" "$ip already exists in $set_name"
        fi
    else
        log "ERROR" "$ip is not valid and will not be added in $set_name" | tee
    fi

done

if ! $new_set; then
    if [ "$family" == "inet" ]; then
        ips_in_set=$(ipset list "$set_name" | grep -E "$IPV4_PATTERN")
    else
        ips_in_set=$(ipset list "$set_name" | grep -E "$IPV6_PATTERN")
    fi

    for ip in $ips_in_set;
    do
        case $ip in 
        "$ips_in_file")
            log "INFO" "$ip exists in file"
        ;;
        *)
            log "INFO" "$ip does not exists in file and will be deleted from $ips_in_set"
            # ipset delete "$ip" "$ips_in_set"
            echo "Delete $ip"
        esac
    done
fi