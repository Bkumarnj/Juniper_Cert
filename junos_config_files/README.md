# Juniper_Cert for doing Juniper certifications - Junos Configuration files

## Overview
This directory contains the Configuration files, where the configurations are learnt throughout the lab journey.

## Usage
How to run or use the Files after setup.


- **Step 1:** Make sure to set the root authentication as first commit before moving ahead with the Actual Configuration steps
- **Step 2:** Configure a Jummphost and connection via fxp0 to load the configuration on to the appliance. (this step is optional, if you wish to just paste the config via console terminal).
- **Step 3:** Ensure your user configuration is done correctly.

## Passwords for Lab accounts
NedAdmin Password: BKNJadmin@123
AuditOps1 Password: BKNJaudit@123
NOC-Ops1 Password: BKNJnoc1@123

## Disclaimer
These Lab User accounts have the User ID, Password, Public and Private Keys are open to people who can view this repository, so refrain from using these credentials on non lab devices. If used, your security is compromised and only you (the individual who incorporated this) will be held responsible for the Blunderous act.

## Configuration Files
| File Name         | Description                                   |
|-------------------|-----------------------------------------------|
| `vMX01-config_file.conf`       | Configuration of DC Primary Router.                 |
| `vMX02-config_file.conf`       | Configuration of DC Secondary Router.                 |
| `vSRX-DC-Cluster-config_file.conf`       | Configuration of DC Firewall cluster.                 |
| `vQFX01-config_file.conf`       | Configuration of DC Primary Spine L3 switch.                 |
| `vQFX02-config_file.conf`       | Configuration of DC Secondary Spine L3 switch              |
| `vSRX01-config_file.conf`       | Configuration of Site A Gateway Firewall.                 |
| `vSRX02-config_file.conf`       | Configuration of Site B Gateway Firewall.                 |
| `vEX01-A-config_file.conf`       | Configuration of Site A Primary L3 Switch.                 | 
| `vEX02-A-config_file.conf`       | Configuration of Site A Secondary L3 Switch.                 | 
| `vEX01-B-config_file.conf`       | Configuration of Site B Primary L3 Switch.                 | 
