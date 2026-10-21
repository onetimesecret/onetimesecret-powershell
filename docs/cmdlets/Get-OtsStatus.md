---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_systemstatus
schema: 2.0.0
---

# Get-OtsStatus

## SYNOPSIS
Reports whether the Onetime Secret service is up.

## SYNTAX

### Connection (Default)
```
Get-OtsStatus [-Connection <Object>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ServerUri
```
Get-OtsStatus [-ServerUri] <String[]> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Calls the unauthenticated status endpoint and returns the service's
own health report plus the server it came from.
Useful as a connectivity
check before a batch of operations, or in monitoring.

## EXAMPLES

### EXAMPLE 1
```
Get-OtsStatus
```

ServerUri                     Status  IsHealthy
---------                     ------  ---------
https://eu.onetimesecret.com/ nominal      True

### EXAMPLE 2
```
'https://us.onetimesecret.com', 'https://eu.onetimesecret.com' | Get-OtsStatus
```

Checks several regions without connecting.

## PARAMETERS

### -Connection
Connection to use instead of the default from Connect-OtsAccount.

```yaml
Type: Object
Parameter Sets: Connection
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ServerUri
Check a server without connecting first.

```yaml
Type: String[]
Parameter Sets: ServerUri
Aliases: BaseUrl, Server

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### OnetimeSecret.ServiceStatus
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_systemstatus](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_systemstatus)

