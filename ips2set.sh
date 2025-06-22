#!/usr/bin/env bash                                                                                                                                                     
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
SCRIPTNAME=$(basename "$0" | cut -d'.' -f1)

# If LOG_FILE is set in parent script
if [ -z "$LOG_FILE" ]; then
  LOG_FILE="$SCRIPT_DIR/$SCRIPTNAME".log
fi

function file_ends_with_newline() {
    [[ $(tail -c1 "$1" | wc -l) -gt 0 ]]
}

usage() {
    echo "Usage: $0"
    echo "-f, --file FILE       Input file with IP addresses, separated by newline."
    echo "-s, --set-name NAME   Name of IP set"
    echo "-n, --networks        Optional parameter: Only necessary, if input file contents network addresses.
                                If set, then the script creates an IP set of type hash:net (default: hash:ip)."
    echo "-6                    Optional parameter: Only necessary, if input file contensts IPv6 addresses (default: IPv4)."
    echo "-h, --help            Print usage"
    echo "-v, --verbose         Verbose output"
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
verbose=false

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
        log "INFO" "Input file: $2"
        shift 2
        ;;
    -s | --set-name)
        set_name="$2"
        log "INFO" "Set name: $2"
        shift 2
        ;;
    -n | --networks)
        type=net
        log "INFO" "Type: $type"
        shift 1
        ;;
    -6)
        family="inet6"
        log "INFO" "Family: $family"
        shift 1
        ;;
    -v | --verbose)
        verbose=true
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

IPV4_PATTERN='^(\b25[0-5]|\b2[0-4][0-9]|\b[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}(\/([1-9]|3[0-2]|[1-2][0-9]))*$'
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
elif grep -E --quiet '\/([1-9]|[1-2][0-9]|3[0-1])$' "$in_file" && [ $type != "net" ]; then
    echo "ERROR: $in_file contains IPv4 network addresses and option \"-n\" is missing."
    echo "IPv4 network addresses (except of /32) require option \"-n\"."
    exit 1
fi

# Create set, if it does not exist
ipset create "$set_name" hash:$type family $family -exist

# Init arrays
declare -a ips_in_file
declare -a ips_in_set

# If the file does not end with a newline, then the last line will be ignored in the while loop.
if ! file_ends_with_newline "$in_file"
then
  log "INFO" "Append newline in $in_file"
  echo "" >> "$in_file"
fi

log "INFO" "--- Read valid addresses from $in_file ---"
# Create array with valid addresses
while IFS= read -r line; do
    ((i++))
    if { [ "$family" == "inet" ] && [[ ! "$line" =~ $IPV4_PATTERN ]];} || \
    { [ "$family" == "inet6" ] && [[ ! "$line" =~ $IPV6_PATTERN ]];}; then
        log "INFO" "Entry $line in line $i is invalid and will be ignored"
    elif [ -z "$line" ]; then
        log "INFO" "Line $i is empty and will be ignored"
    else
        log "INFO" "Add $line in array"
        ips_in_file+=("$line")
    fi
done <"$in_file"

# if $verbose; then log "DEBUG" "Content of set $set_name: $(ipset list "$set_name" | grep -E "$IPV4_PATTERN")"; fi

# Create array from addresses in set
if [ "$family" == "inet" ]; then
    for ip in $(ipset list "$set_name" | grep -E "$IPV4_PATTERN");
    do
        ips_in_set+=("$ip")
    done
else
    for ip in $(ipset list "$set_name" | grep -E "$IPV6_PATTERN");
    do
        ips_in_set+=("$ip")
    done
fi

if $verbose; then log "DEBUG" "ips_in_set (${#ips_in_set[@]}): ${ips_in_set[*]}"; fi
if $verbose; then log "DEBUG" "ips_in_file (${#ips_in_file[@]}): ${ips_in_file[*]}"; fi

log "INFO" "--- Add addresses in $set_name ---"
# Add non-existing addresses in set
for ip in "${ips_in_file[@]}";
do

    if ipset add -q "$set_name" "$ip"; then
        ipset add -q "$set_name" "$ip"
        log "INFO" "$ip in $in_file added into $set_name"
    else
        if $verbose; then log "DEBUG" "$ip in $in_file already exists in $set_name"; fi
    fi

done

# If set already exists, compare the addresses in the set with the addresses in the file.
# Addresses in the set, which do not exist in the file, will be deleted from set.
if (( "${#ips_in_set[@]}" > 0 )); then

    log "INFO" "--- Compare addresses in $set_name with addresses in $in_file ---"
    
    for ip_set in "${ips_in_set[@]}";
    do
        match=false
        for ip_file in "${ips_in_file[@]}";
        do
            if [ "$ip_set" = "$ip_file" ]; then
                if $verbose; then log "DEBUG" "$ip_set in $set_name exists in file"; fi
                match=true
                break
            fi
        done

        if ! $match; then
            log "INFO" "$ip_set in $set_name does not exist in file and will be deleted from $set_name"
            ipset del "$set_name" "$ip_set"
        fi

    done

fi