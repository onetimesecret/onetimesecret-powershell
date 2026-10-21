---
external help file: OnetimeSecret-help.xml
Module Name: OnetimeSecret
online version: https://api.onetimesecret.com/doc/api-v2/authentication
schema: 2.0.0
---

# Connect-OtsAccount

## SYNOPSIS
Establishes the connection that other OnetimeSecret cmdlets use.

## SYNTAX

### Credential (Default)
```
Connect-OtsAccount [-ServerUri] <String> -Credential <PSCredential> [-TimeoutSec <Int32>] [-UserAgent <String>]
 [-PassThru] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Anonymous
```
Connect-OtsAccount [-ServerUri] <String> [-Anonymous] [-TimeoutSec <Int32>] [-UserAgent <String>] [-PassThru]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Validates the server URI and credential, then stores the resulting
connection as the module default so subsequent cmdlets need no
-Connection argument.
Use -PassThru to also return the connection object,
which can be passed explicitly when talking to several servers at once.

Authentication is HTTP Basic: the credential's username is your customer
extid (the "ur..." identifier at the bottom of the user menu when signed
in) or your account email, and the password is your API token from the
account's API settings page.

Alternatively, set the ONETIME_BASE_URL, ONETIME_CUSTOMER_EXTID and
ONETIME_API_TOKEN environment variables and skip this cmdlet entirely;
the module connects on first use.

Onetime Secret runs region-isolated deployments, so there is no default
server.
Pick your region's host (https://us.onetimesecret.com,
https://eu.onetimesecret.com, https://ca.onetimesecret.com,
https://uk.onetimesecret.com, https://nz.onetimesecret.com), your
self-hosted instance or your custom domain.

## EXAMPLES

### EXAMPLE 1
```
Connect-OtsAccount -ServerUri https://eu.onetimesecret.com -Credential (Get-Credential -UserName 'ur1abc23def' -Message 'API token')
```

Prompts for the API token and connects as the given customer.

### EXAMPLE 2
```
$token = ConvertTo-SecureString $env:ONETIME_API_TOKEN -AsPlainText -Force
$cred  = [pscredential]::new('ur1abc23def', $token)
Connect-OtsAccount https://us.onetimesecret.com -Credential $cred
```

Connects non-interactively from an automation script.

### EXAMPLE 3
```
$eu = Connect-OtsAccount https://eu.onetimesecret.com -Anonymous -PassThru
New-OtsSecret -Secret 'hunter2' -Connection $eu
```

Uses an explicit anonymous connection for a single call.

## PARAMETERS

### -Anonymous
Connect without credentials.
Only the guest endpoints are available
(create, reveal, burn, show); listing receipts and setting memos are not.

```yaml
Type: SwitchParameter
Parameter Sets: Anonymous
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
PSCredential whose username is the customer extid (or account email) and
whose password is the API token.

```yaml
Type: PSCredential
Parameter Sets: Credential
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Return the connection object in addition to setting it as the default.

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
Base URL of the API host, for example https://eu.onetimesecret.com.
The apex domain onetimesecret.com is the website and is rejected.

```yaml
Type: String
Parameter Sets: (All)
Aliases: BaseUrl, Server, Uri

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeoutSec
Per-request timeout in seconds.
Defaults to 30.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserAgent
Override the User-Agent header.
Defaults to a string identifying this
module and the PowerShell version.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### OnetimeSecret.Connection (only with -PassThru)
## NOTES

## RELATED LINKS

[https://api.onetimesecret.com/doc/api-v2/authentication](https://api.onetimesecret.com/doc/api-v2/authentication)

