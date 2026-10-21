---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/authentication
schema: 2.0.0
---

# Get-OtsConnection

## SYNOPSIS
Returns the connection the module is currently using.

## SYNTAX

```
Get-OtsConnection [<CommonParameters>]
```

## DESCRIPTION
Returns the default connection set by Connect-OtsAccount, or one built
from the ONETIME_* environment variables when nothing has been set yet.
Returns nothing when neither exists.

## EXAMPLES

### EXAMPLE 1
```
Get-OtsConnection
```

ServerUri                      Username     IsAnonymous
---------                      --------     -----------
https://eu.onetimesecret.com/  ur1abc23def        False

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### OnetimeSecret.Connection
## NOTES

## RELATED LINKS
