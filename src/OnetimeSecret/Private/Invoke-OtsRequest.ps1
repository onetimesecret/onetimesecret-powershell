function Invoke-OtsRequest {
    <#
    .SYNOPSIS
        Sends one request to the Onetime Secret API and returns the parsed JSON.
    .DESCRIPTION
        The single HTTP chokepoint for the module. It builds the URL from the
        connection's server URI and API version, applies Basic auth and the
        client identification headers, serialises the body as JSON, retries
        idempotent GETs on 429/502/503/504 with exponential backoff (honouring
        Retry-After), and converts failures into rich ErrorRecords via
        New-OtsErrorRecord.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [string] $Method = 'GET',

        # Path relative to the API root, e.g. 'secret/conceal'.
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary] $Body,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int] $MaxRetry = 2
    )

    $uri = '{0}/api/{1}/{2}' -f $Connection.ServerUri.AbsoluteUri.TrimEnd('/'), $Connection.ApiVersion, $Path.TrimStart('/')

    $headers = @{
        'Accept'           = 'application/json'
        'X-Onetime-Client' = 'powershell:{0}/{1}' -f $PSVersionTable.PSVersion, $script:ModuleVersion
    }

    if (-not $Connection.IsAnonymous) {
        $token = $Connection.Credential.GetNetworkCredential().Password
        $pair = '{0}:{1}' -f $Connection.Credential.UserName, $token
        $headers['Authorization'] = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair))
    }

    $request = @{
        Uri             = $uri
        Method          = $Method
        Headers         = $headers
        UserAgent       = $Connection.UserAgent
        TimeoutSec      = $Connection.TimeoutSec
        UseBasicParsing = $true
        ErrorAction     = 'Stop'
    }

    if ($null -ne $Body) {
        $json = ConvertTo-Json -InputObject $Body -Depth 10 -Compress
        $request['ContentType'] = 'application/json; charset=utf-8'
        $request['Body'] = [System.Text.Encoding]::UTF8.GetBytes($json)
    }

    $attempt = 0
    while ($true) {
        try {
            Write-Verbose ('{0} {1}' -f $Method, $uri)
            $response = Invoke-WebRequest @request

            $content = $response.Content
            if ($content -is [byte[]]) {
                $content = [System.Text.Encoding]::UTF8.GetString($content)
            }
            if ([string]::IsNullOrWhiteSpace($content)) {
                return $null
            }
            return ($content | ConvertFrom-Json)
        }
        catch {
            $failure = ConvertFrom-OtsHttpError -ErrorRecord $_

            $retryable = ($Method -eq 'GET') -and ($failure.StatusCode -in @(429, 502, 503, 504)) -and ($attempt -lt $MaxRetry)

            if ($retryable) {
                $attempt++
                $delay = [math]::Pow(2, $attempt)
                if ($failure.RetryAfter -gt 0) { $delay = [math]::Max($delay, $failure.RetryAfter) }
                Write-Verbose ('{0} from {1}; retry {2}/{3} in {4}s' -f $failure.StatusCode, $uri, $attempt, $MaxRetry, $delay)
                Start-Sleep -Seconds $delay
                continue
            }

            $PSCmdlet.ThrowTerminatingError((New-OtsErrorRecord -Failure $failure -Method $Method -Uri $uri -ErrorRecord $_))
        }
    }
}

function ConvertFrom-OtsHttpError {
    <#
    .SYNOPSIS
        Normalises the differing HTTP error shapes of Windows PowerShell and PowerShell 7.
    .DESCRIPTION
        Windows PowerShell throws System.Net.WebException with an HttpWebResponse;
        PowerShell 7 throws HttpResponseException with an HttpResponseMessage and
        puts the body in ErrorDetails. Connection failures have no response at
        all. All three end up as the same small object.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $statusCode = 0
    $rawBody = $null
    $retryAfter = 0
    $response = $null

    $exception = $ErrorRecord.Exception
    if ($null -ne $exception -and $null -ne $exception.PSObject.Properties['Response']) {
        $response = $exception.Response
    }

    if ($null -ne $response) {
        try { $statusCode = [int] $response.StatusCode } catch { $statusCode = 0 }

        try {
            $responseHeaders = $response.Headers
            if ($responseHeaders -is [System.Net.WebHeaderCollection]) {
                $value = $responseHeaders['Retry-After']
                if ($value -match '^\d+$') { $retryAfter = [int] $value }
            }
            elseif ($null -ne $responseHeaders.PSObject.Properties['RetryAfter'] -and $null -ne $responseHeaders.RetryAfter -and $null -ne $responseHeaders.RetryAfter.Delta) {
                $retryAfter = [int] $responseHeaders.RetryAfter.Delta.TotalSeconds
            }
        }
        catch {
            Write-Debug ('Retry-After could not be read: {0}' -f $_.Exception.Message)
        }
    }

    if ($null -ne $ErrorRecord.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        $rawBody = $ErrorRecord.ErrorDetails.Message
    }
    elseif ($null -ne $response -and $null -ne $response.PSObject.Methods['GetResponseStream']) {
        try {
            $stream = $response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $stream
                $rawBody = $reader.ReadToEnd()
                $reader.Dispose()
            }
        }
        catch {
            Write-Debug ('Error body could not be read: {0}' -f $_.Exception.Message)
        }
    }

    $body = $null
    if (-not [string]::IsNullOrWhiteSpace($rawBody)) {
        try { $body = $rawBody | ConvertFrom-Json } catch { $body = $null }
    }

    return [PSCustomObject] @{
        StatusCode = $statusCode
        Body       = $body
        RawBody    = $rawBody
        RetryAfter = $retryAfter
    }
}

function New-OtsErrorRecord {
    <#
    .SYNOPSIS
        Builds the ErrorRecord thrown for a failed API call.
    .DESCRIPTION
        The API's error envelope is { error, error_type, field, error_id,
        request_id } (ADR-013). Those fields are surfaced three ways so callers
        can branch however they prefer:

          - FullyQualifiedErrorId  "OnetimeSecret.Api.<error_type>" (or Http<status>)
          - ErrorCategory          mapped from the HTTP status
          - Exception.Data         StatusCode, ErrorType, Field, ErrorId, RequestId, Uri, Method, Response
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Builds an in-memory ErrorRecord; nothing outside the process changes.')]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Failure,

        [Parameter(Mandatory)]
        [string] $Method,

        [Parameter(Mandatory)]
        [string] $Uri,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $status = [int] $Failure.StatusCode
    $body = $Failure.Body

    $errorType = [string] (Get-OtsProperty $body 'error_type')
    $field     = [string] (Get-OtsProperty $body 'field')
    $errorId   = [string] (Get-OtsProperty $body 'error_id')
    $requestId = [string] (Get-OtsProperty $body 'request_id')

    $serverMessage = [string] (Get-OtsProperty $body 'error')
    if ([string]::IsNullOrWhiteSpace($serverMessage)) { $serverMessage = [string] (Get-OtsProperty $body 'message') }

    $accountRequired = ($field -eq 'requires_account') -or ($errorType -match 'AccountRequired|RequiresAccount')

    if ($status -eq 0) {
        $category = [System.Management.Automation.ErrorCategory]::ConnectionError
        $message = 'Could not reach {0}: {1}' -f $Uri, $ErrorRecord.Exception.Message
        $fqid = 'OnetimeSecret.ConnectionError'
        $recommended = 'Check the server URI and your network connection.'
    }
    else {
        $category = switch ($status) {
            400 { [System.Management.Automation.ErrorCategory]::InvalidArgument }
            401 { [System.Management.Automation.ErrorCategory]::AuthenticationError }
            403 { [System.Management.Automation.ErrorCategory]::PermissionDenied }
            404 { [System.Management.Automation.ErrorCategory]::ObjectNotFound }
            409 { [System.Management.Automation.ErrorCategory]::ResourceExists }
            422 { [System.Management.Automation.ErrorCategory]::InvalidData }
            429 { [System.Management.Automation.ErrorCategory]::LimitsExceeded }
            default {
                if ($status -ge 500) { [System.Management.Automation.ErrorCategory]::ResourceUnavailable }
                else { [System.Management.Automation.ErrorCategory]::InvalidOperation }
            }
        }
        if ($accountRequired) { $category = [System.Management.Automation.ErrorCategory]::AuthenticationError }

        if ([string]::IsNullOrWhiteSpace($serverMessage)) {
            $serverMessage = switch ($status) {
                401 { 'Authentication required.' }
                403 { 'Permission denied.' }
                404 { 'Not found.' }
                422 { 'The request was rejected by validation.' }
                429 { 'Rate limit exceeded.' }
                default { 'The request failed.' }
            }
        }

        $label = if ($errorType) { $errorType } else { 'HTTP {0}' -f $status }
        $message = 'Onetime Secret API returned {0} ({1}): {2}' -f $status, $label, $serverMessage
        if ($field) { $message += ' [field: {0}]' -f $field }
        if ($requestId) { $message += ' [request_id: {0}]' -f $requestId }

        $fqid = if ($errorType) { 'OnetimeSecret.Api.{0}' -f $errorType } else { 'OnetimeSecret.Api.Http{0}' -f $status }

        $recommended = switch ($status) {
            401 { 'Check the customer extid (username) and API token (password) passed to Connect-OtsAccount.' }
            404 { 'The secret or receipt may have been viewed, burned or expired, or the identifier is wrong.' }
            429 { 'Slow down and retry later.' }
            default { $null }
        }
        if ($accountRequired) { $recommended = 'This operation needs an authenticated account. Run Connect-OtsAccount with a credential.' }
    }

    $exception = New-Object -TypeName System.Exception -ArgumentList $message, $ErrorRecord.Exception
    $exception.Data['StatusCode'] = $status
    $exception.Data['ErrorType']  = $errorType
    $exception.Data['Field']      = $field
    $exception.Data['ErrorId']    = $errorId
    $exception.Data['RequestId']  = $requestId
    $exception.Data['Method']     = $Method
    $exception.Data['Uri']        = $Uri
    $exception.Data['Response']   = $body

    $record = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, $fqid, $category, $Uri
    $record.ErrorDetails = New-Object -TypeName System.Management.Automation.ErrorDetails -ArgumentList $message
    if ($recommended) { $record.ErrorDetails.RecommendedAction = $recommended }

    return $record
}
