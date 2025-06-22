# ips2set

This script creates an ipset from a file with IP addresses.

## Usage

```sh
```

## Input

This script expects a file with IP addresses, separated by newline.

```sh title="Example for IPv4"
91.189.91.46
91.189.91.47
185.125.190.23
185.125.190.24
185.125.190.75
```

## Output

## Testing

```sh title="testdata_2"
# A comment
91.189.91.46
91.189.91.47
185.125.190.23
185.125.190.24
#185.125.190.75
```

### Testcases

[!TIP]
During the test, the ipset can be monitored with `watch ipset list <SET_NAME>`.

**Testcase 1**: New set
**Command**: `./ips2set.sh -f ipv4 -s test -v` 
**Condition for Success**:

Set *test* of type hash:ip was created with the IP addresses in the file as members. 

```sh title="New set"
Name: test
Type: hash:ip
Revision: 6
Header: family inet hashsize 1024 maxelem 65536 bucketsize 12 initval 0x0774606e
Size in memory: 416
References: 0
Number of entries: 5
Members:
91.189.91.46
91.189.91.47
185.125.190.23
185.125.190.24
185.125.190.75
```

**Testcase 2**: Update of the existing set *test*
**Command**: `./ips2set.sh -f testdata_2 -s test -v` 
**Description**: 185.125.190.75 in file was changed to #185.125.190.75. Because the latter is not a valid IP address, 
185.125.190.75 in set does not exists anymore in file.
**Condition for Success**: 185.125.190.75 is deleted from set *test*.

```sh title="Updated set"
Name: test
Type: hash:ip
Revision: 6
Header: family inet hashsize 1024 maxelem 65536 bucketsize 12 initval 0x0774606e
Size in memory: 376
References: 0
Number of entries: 4
Members:
91.189.91.46
91.189.91.47
185.125.190.23
185.125.190.24
```

**Testcase 3**: Update of the existing set *test*
**Command**: `./ips2set.sh -f ipv4 -s test -v` 
**Description**: 185.125.190.75 is new and must be added in set.
**Condition for Success**: 185.125.190.75 is added in set *test* (see set of ipv4).

**Testcase 4**: Invalid addresses in input file
**Command**: `./ips2set.sh -f ipv4_with_invalid -s test -v` 
**Description**: Input file contains strings which don't match with IPv4 pattern.
**Condition for Success**: Invalid strings do not exists in `ips_in_file`.

```sh title="Updated after update"
Name: test
Type: hash:ip
Revision: 6
Header: family inet hashsize 1024 maxelem 65536 bucketsize 12 initval 0x0774606e
Size in memory: 456
References: 0
Number of entries: 6
Members:
255.255.255.255
127.0.0.1   
1.20.251.69   
192.168.1.1   
1.2.3.4
223.244.235.136
```

```sh title="ips2set.log"
2025-05-24 09:26:35 [INFO] Input file: ipv4s
2025-05-24 09:26:35 [INFO] Set name: test 
2025-05-24 09:26:35 [INFO] --- Read valid addresses from ipv4s ---
2025-05-24 09:26:35 [INFO] Add 192.168.1.1 in array
2025-05-24 09:26:35 [INFO] Add 127.0.0.1 in array
2025-05-24 09:26:35 [INFO] Add 0.0.0.0 in array
2025-05-24 09:26:35 [INFO] Add 255.255.255.255 in array
2025-05-24 09:26:35 [INFO] Entry 256.256.256.256 in line 5 is invalid and will be ignored
2025-05-24 09:26:35 [INFO] Entry 999.999.999.999 in line 6 is invalid and will be ignored
2025-05-24 09:26:35 [INFO] Entry 1.2.3 in line 7 is invalid and will be ignored
2025-05-24 09:26:35 [INFO] Add 1.2.3.4 in array
2025-05-24 09:26:35 [INFO] Add 1.20.251.69 in array
2025-05-24 09:26:35 [INFO] Add 223.244.235.136 in array
2025-05-24 09:26:35 [DEBUG] ips_in_set: 
2025-05-24 09:26:35 [DEBUG] ips_in_file: 192.168.1.1 127.0.0.1 0.0.0.0 255.255.255.255 1.2.3.4 1.20.251.69 223.244.235.136
2025-05-24 09:26:35 [INFO] --- Add addresses in test --- 
2025-05-24 09:26:35 [INFO] 192.168.1.1 in ipv4s added into test
2025-05-24 09:26:35 [INFO] 127.0.0.1 in ipv4s added into test
2025-05-24 09:26:35 [DEBUG] 0.0.0.0 in ipv4s already exists in test
2025-05-24 09:26:35 [INFO] 255.255.255.255 in ipv4s added into test
2025-05-24 09:26:35 [INFO] 1.2.3.4 in ipv4s added into test
2025-05-24 09:26:35 [INFO] 1.20.251.69 in ipv4s added into test
2025-05-24 09:26:35 [INFO] 223.244.235.136 in ipv4s added into test 
```

**Testcase 5**: Create IPv6 set
**Command**: `./ips2set.sh -f ipv6 -s test -v -6` 
**Condition for Success**: Set with IPv6 addresses of file.

```sh title="Set"
Name: test
Type: hash:ip
Revision: 6
Header: family inet6 hashsize 1024 maxelem 65536 bucketsize 12 initval 0x2aa7d4dc
Size in memory: 544
References: 0
Number of entries: 5
Members:
2001:67c:1562::22
2620:2d:4000:1::30
2620:2d:4000:1::2f
2001:67c:1562::21
2620:2d:4000:1::2e
```

**Testcase 6**: Invalid IPv6 addresses in file
**Command**: `./ips2set.sh -f ipv6_with_invalid -s test -v -6` 
**Condition for Success**: Invalid strings do not exists in `ips_in_file`.

**Testcase 8**: IPv4 network addresses in file
**Command**: `./ips2set.sh -f ipv4nets -s test -v -n` 
**Condition for Success**: New set of type hash:net with the network addresses.

```sh title="Set with network addresses"
Name: test
Type: hash:net
Revision: 7
Header: family inet hashsize 1024 maxelem 65536 bucketsize 12 initval 0x578b26f6
Size in memory: 696
References: 0
Number of entries: 5
Members:
162.158.0.0/15
176.0.0.0/13
109.40.0.0/13
103.22.200.0/22
197.234.240.0/22
```

If these conditions are met, the command exits with status 1 without creating a set:

- Input file contains IPv4- or IPv6 network addresses and command will be executed without option `-n`
- Input file contains IPv4- and IPv6-addresses

## Further information

If the IP address is not valid, `ipset add -q <SETNAME> <IP> -exist` returns 1. If the IP address is valid but does not exist in set, it returns 0.

### Dealing with Counters in IPSets

```sh
ipset list "$set_name" | grep -Eo "$IPV4_PATTERN"
```

`-o` is necessary to extract the IP address from a set.
`grep -E` will not return anything if the set also contains counters (see below).

```sh
$ sudo ipset create myset hash:net counters
$ sudo ipset list myset | grep -E $IPV4_PATTERN
192.0.2.1/24 packets 0 bytes 0
```

The patterns for IPv4 / IPv6 must not end with `$` as otherwise there are no matches in a set with counters (see above)

No matches: `IPV4_PATTERN='^...))*$'`
Matches: `IPV4_PATTERN='^...))*'`

## Sources