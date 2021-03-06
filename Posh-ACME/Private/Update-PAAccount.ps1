function Update-PAAccount {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position=0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$ID
    )

    Begin {
        # make sure we have a server configured
        if (!(Get-PAServer)) {
            throw "No ACME server configured. Run Set-PAServer first."
        }
    }

    Process {

        # grab the account from explicit parameters or the current memory copy
        if (!$ID) {
            if (!$script:Acct -or !$script:Acct.id) {
                throw "No ACME account configured. Run Set-PAAccount or specify an ID."
            }
            $acct = $script:Acct
            $UpdatingCurrent = $true
        } else {
            # even if they specified the account explicitly, we may still be updating the
            # "current" account. So figure that out and set a flag for later.
            if ($script:Acct -and $script:Acct.id -and $script:Acct.id -eq $ID) {
                $UpdatingCurrent = $true
                $acct = $script:Acct
            } else {
                $UpdatingCurrent = $false
                $acct = Get-PAAccount $ID
            }
        }

        Write-Debug "Refreshing account $($acct.id)"

        # hydrate the account key
        $acctKey = $acct.key | ConvertFrom-Jwk

        # build the header
        $header = @{
            alg   = $acct.alg;
            kid   = $acct.location;
            nonce = $script:Dir.nonce;
            url   = $acct.location;
        }

        # empty payload to get the current details
        $payloadJson = '{}'

        # send the request
        try {
            $response = Invoke-ACME $header.url $acctKey $header $payloadJson -EA Stop
        } catch { throw }
        Write-Debug "Response: $($response.Content)"

        $respObj = $response.Content | ConvertFrom-Json

        # update the things that could have changed
        $acct.status = $respObj.status
        $acct.contact = $respObj.contact

        # save it to disk
        $acctFolder = Join-Path $script:DirFolder $acct.id
        $acct | ConvertTo-Json | Out-File (Join-Path $acctFolder 'acct.json') -Force
    }

}
