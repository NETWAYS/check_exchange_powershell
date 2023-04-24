Icinga Check Microsoft Exchange
===============================

This is a collection of Powershell Scripts designed to check a Microsoft Exchange Setup from
Icinga 2 with the agent running on the Exchange Windows Servers.

## Checks

For `CheckCommand` definitions see [icinga2-commands.conf](icinga2-commands.conf).

### check_exchange_health

Checks the server health of Microsoft Exchange by calling `Get-ServerHealth`

```
OK: All 159 scenarios are fine
```

### check_exchange_queues

```
OK: All 10 queues are fine
[OK] EX01\Submission: Ready, deferred (0), locked (0), messages (0)
[OK] EX01\Shadow\6: Ready, deferred (0), locked (0), messages (32)
[OK] EX01\50: Ready, deferred (0), locked (0), messages (0)
[OK] EX01\Shadow\3: Ready, deferred (0), locked (0), messages (355)
[OK] EX01\8: Ready, deferred (0), locked (0), messages (0)
[OK] EX01\Shadow\7: Ready, deferred (0), locked (0), messages (33)
[OK] EX01\4: Ready, deferred (0), locked (0), messages (0)
[OK] EX01\Shadow\51: Ready, deferred (0), locked (0), messages (1)
[OK] EX01\5: Ready, deferred (0), locked (0), messages (0)
[OK] EX01\Shadow\58: Ready, deferred (0), locked (0), messages (1)
| 'EX01_Submission::deferred'=0;5;10;0 'EX01_Submission::locked'=0;5;10;0 'EX01_Submission::count'=0;20;50;0 'EX01_Shadow_6::deferred'=0;5;10;0 'F
R02641VMA_Shadow_6::locked'=0;5;10;0 'EX01_Shadow_6::count'=32;;;0 'EX01_50::deferred'=0;5;10;0 'EX01_50::locked'=0;5;10;0 'EX01_50::count'=0;20;5
0;0 'EX01_Shadow_3::deferred'=0;5;10;0 'EX01_Shadow_3::locked'=0;5;10;0 'EX01_Shadow_3::count'=355;;;0 'EX01_8::deferred'=0;5;10;0 'EX01_8::
locked'=0;5;10;0 'EX01_8::count'=0;20;50;0 'EX01_Shadow_7::deferred'=0;5;10;0 'EX01_Shadow_7::locked'=0;5;10;0 'EX01_Shadow_7::count'=33;;;0 'FR02
641VMA_4::deferred'=0;5;10;0 'EX01_4::locked'=0;5;10;0 'EX01_4::count'=0;20;50;0 'EX01_Shadow_51::deferred'=0;5;10;0 'EX01_Shadow_51::locked'=0;5;
10;0 'EX01_Shadow_51::count'=1;;;0 'EX01_5::deferred'=0;5;10;0 'EX01_5::locked'=0;5;10;0 'EX01_5::count'=0;20;50;0 'EX01_Shadow_58::deferred
'=0;5;10;0 'EX01_Shadow_58::locked'=0;5;10;0 'EX01_Shadow_58::count'=1;;;0
```

### check_exchange_mailbox_databases

Checks the availability and health of Exchange Databases with `Get-MailboxDatabase`

```
OK: All 1 databases are fine
[OK] Mailbox Database 123456
```

### check_exchange_webservices

Checks the availablitity of EWS and other web services with `Test-OutlookWebServices`

**Note:** This require mailbox credentials - see script help inside.

```
OK: All 4 scenarios are fine
[OK] OfflineAddressBook: Success
[OK] AvailabilityService: Success
[OK] ExchangeWebServices: Success
[OK] AutoDiscoverOutlookProvider: Success
| 'OfflineAddressBook::latency'=74ms;500;1000;0 'AvailabilityService::latency'=62ms;500;1000;0 'ExchangeWebServices::latency'=32ms;500;1000;0 'AutoDiscoverOutlookProvider
::latency'=98ms;500;1000;0
```

### check_exchange_edge_synchronization

Checks the status of Exchange Edge Synchronization by calling `Get-EdgeSubscription` and `Test-EdgeSynchronization`

```
OK: All 2 Edge Synchronizations are fine
[OK] EX01: Normal, sync 1 minutes old
[OK] EX02: Normal, sync 1 minutes old
| 'EX01::sync_age'=28s;300;600;0 'EX02::sync_age'=28s;300;600;0
```

## Known Issues

### Import-Clixml

```
Command: Get-Credential | Export-CliXml .\MailboxCredential.xml
->
Import-Clixml : Key not valid for use in specified state
```

Solution: Needs to run as user "SYSTEM" (Example: via `PsExec`).

## Contributing

Feel free to ask questions and open issues. Feedback is always welcome and appreciated.

## License

    Copyright (C) 2018 Markus Frosch <markus.frosch@netways.de>
	              2018 NETWAYS GmbH <info@netways.de>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
