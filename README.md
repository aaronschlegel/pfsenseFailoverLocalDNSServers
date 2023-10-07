# Enable Failover NAT DNS Rules for pfSense Firewall

## Description

This project consists of scripts designed to monitor priamry DNS server responses on a pfSense firewall and will failover to another set of DNS servers via enabling NAT rules if they are unresponsive. Once the primary servers become responsive again the rules are disabled, and the primary servers are used again.

## Prerequisites

Before running the scripts, you must:

1. Create 4 NAT rules in your pfSense firewall to forward ports 53 and 853 to the failover DNS server.

![requiredRules](https://github.com/aaronschlegel/pfsenseFailoverLocalDNSServers/assets/18273845/2b52f7c3-7eaa-47f9-af83-905eb000f802)


2. Identify the rule IDs for these NAT rules. To find a rule ID, click the 'Edit' button for the rule in pfSense. The rule ID will be in the URL. Append an 'n' to this ID when using it as a parameter (e.g., if the ID is 5, use `n5`).

![ruleID](https://github.com/aaronschlegel/pfsenseFailoverLocalDNSServers/assets/18273845/faec393f-6da9-451a-a843-ec0f147fd9c3)


## Installation

1. Clone the repository into the desired directory. (e.g., /usr/sbin)
2. Grant executable permissions to the scripts:

   ```bash
   chmod +x dns_failover_check.sh
   chmod +x fwrule_toggle.php
   ```

## Usage
### Create a cron job

Create a cron job so the script automatically detects DNS failover scenarios. If you wish to have the script run more than once per minute, use the SECONDS_DELAY to offset the start time.

![image](https://github.com/aaronschlegel/pfsenseFailoverLocalDNSServers/assets/18273845/dad5cff5-3ddc-4d46-84b4-a855cbabf51c)

### dns_failover_check.sh

Run the script with the following arguments:

```bash
bash dns_failover_check.sh <DNS1_IP> <DNS2_IP> <TEST_DOMAIN> <EXPECTED_IP> <RULE_ID1> <RULE_ID2> <RULE_ID3> <RULE_ID4> <SECONDS_DELAY>
```

- `DNS1_IP` and `DNS2_IP`: IP addresses of the DNS servers to test.
- `TEST_DOMAIN`: The domain name to resolve for the DNS test.
- `EXPECTED_IP`: The expected IP address that should be returned.
- `RULE_ID1`, `RULE_ID2`, `RULE_ID3`, `RULE_ID4`: IDs of the NAT rules to toggle.
- `SECONDS_DELAY`: Sleep at the begining of script so that it can be ran more frequently than once per minute via a cron job.
### fwrule_toggle.php

This script toggles the state of a given NAT rule and is invoked by `dns_failover_check.sh`.

```bash
php fwrule_toggle.php <RULE_ID> <enable|disable>
```

- `RULE_ID`: The ID of the NAT rule to toggle.
- `enable|disable`: The state to set the rule to.

## Contributing

Feel free to fork the project and submit pull requests for any enhancements or fixes. Please adhere to the existing coding style.

## License

This project is open-source and available under the MIT License.
