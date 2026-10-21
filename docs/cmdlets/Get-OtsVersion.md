---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_systemversion
schema: 2.0.0
---

# Get-OtsVersion

## SYNOPSIS
Reports the version of the Onetime Secret server you are connected to.

## SYNTAX

```
Get-OtsVersion [[-Connection] <Object>] [<CommonParameters>]
```

## DESCRIPTION
Calls the version endpoint and returns the server's build version as
a \[version\] plus the server it came from.
Useful for confirming which
release a self-hosted instance runs, or for gating features on it.

The endpoint requires an authenticated connection.
The OpenAPI
document lists it without a security requirement, but the server
(onetimesecret.com and current self-hosted releases) withholds the
build version from anonymous callers because it fingerprints the
install for CVE matching.
Anonymously, or with bad credentials, the
call fails with an AuthenticationError (HTTP 401).
Use Get-OtsStatus
for an unauthenticated health check.

## EXAMPLES

### EXAMPLE 1
```
Get-OtsVersion
```

ServerUri                     Version Locale
---------                     ------- ------
https://eu.onetimesecret.com/ 0.26.5  en

### EXAMPLE 2
```
if ((Get-OtsVersion).Version -lt [version] '0.26.0') { throw 'Server too old.' }
```

Checks the server release before relying on a newer feature.

## PARAMETERS

### -Connection
Connection to use instead of the default from Connect-OtsAccount.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### OnetimeSecret.ServiceVersion
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_systemversion](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_systemversion)

