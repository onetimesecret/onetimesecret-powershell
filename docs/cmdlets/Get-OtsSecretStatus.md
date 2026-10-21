---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_listsecretstatus
schema: 2.0.0
---

# Get-OtsSecretStatus

## SYNOPSIS
Checks whether secrets still exist and what state they are in.

## SYNTAX

```
Get-OtsSecretStatus [-SecretId] <String[]> [-Connection <Object>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
A lightweight, non-consuming check.
Unknown identifiers come back with
State 'unknown' and Exists $false rather than an error, which makes
this the right call for polling ("has the recipient picked it up
yet?").
Several identifiers are checked in a single request.

## EXAMPLES

### EXAMPLE 1
```
Get-OtsSecretStatus -SecretId sec3kd9f..., sec8xy2a...
```

SecretId     State    Exists Expires
--------     -----    ------ -------
sec3kd9f... 
new        True 20/10/2026 15:04:05
sec8xy2a... 
unknown   False

### EXAMPLE 2
```
Get-OtsReceipt | Get-OtsSecretStatus
```

Checks every recent receipt's secret in one request.

## PARAMETERS

### -Connection
Connection to use instead of the default from Connect-OtsAccount.

```yaml
Type: Object
Parameter Sets: (All)
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

### -SecretId
One or more secret identifiers or share links.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Id, Key

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### OnetimeSecret.SecretStatus
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_listsecretstatus](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_listsecretstatus)

