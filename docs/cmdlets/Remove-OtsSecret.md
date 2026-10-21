---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_receipt_burnsecret
schema: 2.0.0
---

# Remove-OtsSecret

## SYNOPSIS
Burns a secret before anyone reads it.

## SYNTAX

```
Remove-OtsSecret [-ReceiptId] <String[]> [-Passphrase <SecureString>] [-PassThru] [-Connection <Object>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Permanently destroys an unread secret using its receipt identifier (the
creator's handle; the secret identifier in the share link does not
work here).
Returns the updated receipt.
Supports -WhatIf and -Confirm.

## EXAMPLES

### EXAMPLE 1
```
Remove-OtsSecret -ReceiptId rcp5f8d...
```

### EXAMPLE 2
```
Get-OtsReceipt | Where-Object State -eq 'new' | Remove-OtsSecret -Confirm:$false
```

Burns every unread secret the account created in the last 30 days.

### EXAMPLE 3
```
$receipt = New-OtsSecret -Secret 'oops'
$receipt | Remove-OtsSecret -PassThru
```

Creates and immediately burns a secret, returning the burned receipt.

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

### -Passphrase
The passphrase the secret was created with, if any.

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

### -PassThru
Return the updated receipt.
By default nothing is returned, in keeping
with other Remove-* cmdlets.

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

### -ReceiptId
The receipt identifier, or the receipt link it appears in.
Receipt
objects from New-OtsSecret and Get-OtsReceipt bind this from the pipeline.

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

### OnetimeSecret.Receipt (only with -PassThru)
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_receipt_burnsecret](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_receipt_burnsecret)

