---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_showreceipt
schema: 2.0.0
---

# Get-OtsReceipt

## SYNOPSIS
Gets receipts: the creator-side record of a secret's state and links.

## SYNTAX

### Recent (Default)
```
Get-OtsReceipt [-Connection <Object>] [<CommonParameters>]
```

### ById
```
Get-OtsReceipt [-ReceiptId] <String[]> [-Connection <Object>]
 [<CommonParameters>]
```

## DESCRIPTION
With -ReceiptId, returns the receipt for one or more secrets you
created, including whether the secret has been viewed, burned or has
expired, and the share, receipt and burn URLs.

With no identifier, lists the authenticated account's receipts for
secrets created in the last 30 days (requires a credential).

## EXAMPLES

### EXAMPLE 1
```
Get-OtsReceipt
```

ReceiptId   SecretId   State    Created              Expires
---------   --------   -----    -------              -------
rcp5f8d... 
sec3kd9f... 
new      20/10/2026 14:04:05  27/10/2026 14:04:05
rcp2ab1... 
secxx91c... 
received 19/10/2026 09:12:33

### EXAMPLE 2
```
Get-OtsReceipt -ReceiptId rcp5f8d... | Select-Object State, IsReceived, Received
```

Checks whether a specific secret has been picked up.

### EXAMPLE 3
```
Get-OtsReceipt | Where-Object IsReceived | Format-Table ReceiptId, Received, Recipients
```

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

### -ReceiptId
The receipt identifier, or the receipt link it appears in.

```yaml
Type: String[]
Parameter Sets: ById
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

### OnetimeSecret.Receipt
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_showreceipt](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_showreceipt)

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_listreceipts](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_listreceipts)

