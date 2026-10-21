---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_showsecret
schema: 2.0.0
---

# Get-OtsSecret

## SYNOPSIS
Gets a secret's metadata without revealing its value.

## SYNTAX

```
Get-OtsSecret [-SecretId] <String[]> [-Connection <Object>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Returns state, passphrase requirement and timing for a secret, leaving
the value untouched.
Use Receive-OtsSecret to reveal (and thereby
destroy) it.

The server records this access as a preview on the secret's receipt,
which its creator can see.
For a lighter check that only answers "does
it still exist and what state is it in", use Get-OtsSecretStatus.

## EXAMPLES

### EXAMPLE 1
```
Get-OtsSecret -SecretId 'https://eu.onetimesecret.com/secret/sec3kd9f...'
```

### EXAMPLE 2
```
New-OtsSecret -Secret 'hunter2' | Get-OtsSecret
```

Reads the metadata of a secret just created, via SecretId on the pipeline.

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
The secret identifier, or the full share link it appears in.

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

### OnetimeSecret.Secret
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_showsecret](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_showsecret)

