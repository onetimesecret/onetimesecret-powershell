---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_concealsecret
schema: 2.0.0
---

# New-OtsSecret

## SYNOPSIS
Creates a one-time secret and returns its receipt, including the share link.

## SYNTAX

### Conceal (Default)
```
New-OtsSecret [-Secret] <String> [-Passphrase <SecureString>] [-Ttl <TimeSpan>] [-Recipient <String[]>]
 [-ShareDomain <String>] [-DisplayType <String>] [-Connection <Object>] [-ProgressAction <ActionPreference>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ConcealSecure
```
New-OtsSecret -SecureSecret <SecureString> [-Passphrase <SecureString>] [-Ttl <TimeSpan>]
 [-Recipient <String[]>] [-ShareDomain <String>] [-DisplayType <String>] [-Connection <Object>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Generate
```
New-OtsSecret [-Generate] [-Length <Int32>] [-CharacterSet <String[]>] [-ExcludeAmbiguous]
 [-Passphrase <SecureString>] [-Ttl <TimeSpan>] [-Recipient <String[]>] [-ShareDomain <String>]
 [-DisplayType <String>] [-Connection <Object>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Conceals a value you supply (-Secret or -SecureSecret), or asks the
server to generate a random one (-Generate).
The returned receipt object
has the ShareUrl to hand to the recipient, the ReceiptId you keep to
check on or burn the secret, and the generated Value when -Generate was
used.

Anonymous connections use the guest endpoints and are subject to the
guest limits (shorter maximum TTL, no custom share domain).

## EXAMPLES

### EXAMPLE 1
```
New-OtsSecret -Secret 'hunter2' -Ttl (New-TimeSpan -Hours 1)
```

ReceiptId          SecretId           State  Expires              ShareUrl
---------          --------           -----  -------              --------
rcp5f8... 
sec3kd... 
new    20/10/2026 15:04:05  https://eu.onetimesecret.com/secret/sec3kd...

### EXAMPLE 2
```
$pass = Read-Host -AsSecureString 'Passphrase'
$link = (New-OtsSecret -Secret $apiKey -Passphrase $pass -Recipient ops@example.com).ShareUrl
```

Protects the secret with a passphrase and emails the link.

### EXAMPLE 3
```
New-OtsSecret -Generate -Length 24 -CharacterSet Uppercase,Lowercase,Numbers | Select-Object Value, ShareUrl
```

Generates a 24-character alphanumeric secret and shows both the value
and the link to share.

### EXAMPLE 4
```
Get-Content ./kubeconfig -Raw | New-OtsSecret -Ttl '2:00:00' -DisplayType markdown
```

Conceals a file's contents from the pipeline.

## PARAMETERS

### -CharacterSet
Character classes to draw the generated secret from: Uppercase,
Lowercase, Numbers, Symbols.
The server default applies when omitted.

```yaml
Type: String[]
Parameter Sets: Generate
Aliases:

Required: False
Position: Named
Default value: None
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

### -DisplayType
How the recipient's page renders the secret: 'text' (default) or
'markdown'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeAmbiguous
Leave out look-alike characters (such as 0/O and 1/l) from a generated
secret.

```yaml
Type: SwitchParameter
Parameter Sets: Generate
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Generate
Have the server generate a random secret instead of supplying one.
The
generated value is returned in the receipt's Value property.
The server
discloses it only once, so New-OtsSecret reads it back immediately;
it will not appear on later Get-OtsReceipt calls.

```yaml
Type: SwitchParameter
Parameter Sets: Generate
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Length
Length of the generated secret (4-128).
The server default applies when
omitted.

```yaml
Type: Int32
Parameter Sets: Generate
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Passphrase
Optional passphrase the recipient must supply to reveal the secret.

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

### -Recipient
Email address(es) to notify with the share link.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Secret
The secret content as plain text.
Accepts pipeline input, so
\`Get-Content token.txt -Raw | New-OtsSecret\` works.

```yaml
Type: String
Parameter Sets: Conceal
Aliases: Value, Content

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -SecureSecret
The secret content as a SecureString, for callers that already hold it
that way.

```yaml
Type: SecureString
Parameter Sets: ConcealSecure
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShareDomain
Custom domain to build the share link on (authenticated accounts with a
verified domain only).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Ttl
How long the secret stays retrievable, as a TimeSpan (for example
(New-TimeSpan -Hours 1) or '01:00:00').
Integers are not accepted
because PowerShell would read them as ticks.
The server default and
plan limits apply when omitted.

```yaml
Type: TimeSpan
Parameter Sets: (All)
Aliases: TimeToLive, ExpiresIn

Required: False
Position: Named
Default value: None
Accept pipeline input: False
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

### OnetimeSecret.Receipt
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_concealsecret](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_concealsecret)

[https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_generatesecret](https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_generatesecret)

