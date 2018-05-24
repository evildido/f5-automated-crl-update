# Introduction

This script allows to automatically update CRL files installed locally on BIGIP. 
It takes multiple CRLs endpoints URLs in crlupdate.ini and aggregates them in a single PEM file.

it has been tested on 11.5.4

## Prerequisites

* Access to F5 file filesystem (Administrator with advanced shell)
* BIGIP can access to the remote CRL endpoint
* CRL file must be already deployed on BIGIP (the script doesn't create the object but update it)

## Installation

### Deploy the script

Note : On cluster, the script must be deployed on each BIGIP server. 

1- Deploy updateCRL.sh and config.ini.example in /config/ (all content in config is backed up)<br>
2- mv config.ini.example config.ini<br>
3- Add CRL endpoints ini config.ini<br>
4- chmod 740 updateCRL.sh<br>

Note 2 : **crl_threshold** var is the threshold that you specify before a CRL will be updated.

### Create icall script

Using cron is not recommanded because it's not backed up. 
We need to create an icall script which will be called periodically by an handler.

> tmsh create sys icall Update-CRL 

Paste the [icall script](https://github.com/evildido/f5-automated-crl-update/blob/master/icall-script)
*Note : * Edit **tmsh::run** if needed 

### Create periodic handler

Create the periodic handler
> tmsh create sys icall handler periodic updateCRL-periodic first-occurrence 2018-01-01:02:00:00 interval 86400 script Update-CRL

Edit handler, interval and script (icall script name) if needed. 
