# ips2set

This script creates an ipset from a file with IP addresses.

## Usage

```sh
```

## Input

This script expects a file with IP addresses, separated by newline.

``` title="Example for IPv4"
91.189.91.46
91.189.91.47
185.125.190.23
185.125.190.24
185.125.190.75
```

## Output

## Further information

- If the IP address is not valid, `ipset add -q <SETNAME> <IP> -exist` returns 1. If the IP address is valid but does not exist in set, it returns 0.

## Sources