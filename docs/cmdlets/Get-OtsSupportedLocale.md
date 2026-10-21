---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_getsupportedlocales
schema: 2.0.0
---

# Get-OtsSupportedLocale

## SYNOPSIS
Lists the locales a Onetime Secret server can serve.

## SYNTAX

### Connection (Default)
```
Get-OtsSupportedLocale [-Connection <Object>] [<CommonParameters>]
```

### ServerUri
```
Get-OtsSupportedLocale [-ServerUri] <String[]> [<CommonParameters>]
```

## DESCRIPTION
Calls the unauthenticated supported-locales endpoint and returns the
locale codes the server has translations for, its default locale, and
the locale it chose for this request.
Useful when building a share
link or notification for a recipient in a given language, or when
checking what a self-hosted instance has enabled.

## EXAMPLES

### EXAMPLE 1
```
Get-OtsSupportedLocale
```

ServerUri                     DefaultLocale Locales
---------                     ------------- -------
https://eu.onetimesecret.com/ en            {ar, bg, ca_ES, cs...}

### EXAMPLE 2
```
(Get-OtsSupportedLocale -ServerUri https://eu.onetimesecret.com).Locales -contains 'de'
```

Checks whether German is available before localising a message.

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

### -ServerUri
Query a server without connecting first.

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

### OnetimeSecret.SupportedLocales
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_getsupportedlocales](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_getsupportedlocales)

