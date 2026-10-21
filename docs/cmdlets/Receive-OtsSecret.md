---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_secret_revealsecret
schema: 2.0.0
---

# Receive-OtsSecret

## SYNOPSIS
Reveals a secret's value.
This consumes the secret; it cannot be read again.

## SYNTAX

```
Receive-OtsSecret [-SecretId] <String> [-Passphrase <SecureString>] [-AsSecureString] [-Connection <Object>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Retrieves the secret content and destroys it on the server in the same
step.
Supply -Passphrase when the creator set one.
Supports -WhatIf and
-Confirm because the operation is irreversible.

By default Value is a plain string so it can be used directly in
scripts; pass -AsSecureString to receive it as a SecureString instead.

## EXAMPLES

### EXAMPLE 1
```
(Receive-OtsSecret -SecretId 'https://eu.onetimesecret.com/secret/sec3kd9f...').Value
```

Prints the secret content.

### EXAMPLE 2
```
$pass = Read-Host -AsSecureString 'Passphrase'
Receive-OtsSecret sec3kd9f... -Passphrase $pass -AsSecureString
```

Reveals a passphrase-protected secret and keeps the value as a SecureString.

### EXAMPLE 3
```
Receive-OtsSecret sec3kd9f... -WhatIf
```

Shows what would happen without consuming the secret.

## PARAMETERS

### -AsSecureString
Return Value as a SecureString.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

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

### -Passphrase
The passphrase the creator protected the secret with, if any.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SecretId
The secret identifier, or the full share link it appears in.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Id, Key

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### OnetimeSecret.Secret
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_secret_revealsecret](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_secret_revealsecret)

