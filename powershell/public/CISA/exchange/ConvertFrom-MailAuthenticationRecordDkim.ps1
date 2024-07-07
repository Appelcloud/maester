﻿<#
.SYNOPSIS
    Returns structured RFC compliant object from DKIM record

.DESCRIPTION

    Adapted from:
    - https://cloudbrothers.info/en/powershell-tip-resolve-spf/
    - https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Modules/Providers/ExportEXOProvider.psm1
    - https://xkln.net/blog/getting-mx-spf-dmarc-dkim-and-smtp-banners-with-powershell/
    - DKIM https://datatracker.ietf.org/doc/html/rfc6376
record      : v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCPkb8bu8RGWeJGk3hJrouZXIdZ+HTp/azRp8IUOHp5wKvPUAi/54PwuLscUjRk4Rh3hjIkMpKRfJJXPxWbrT7eMLric
              7f/S0h+qF4aqIiQqHFCDAYfMnN6V3Wbke2U5EGm0H/cAUYkaf2AtuHJ/rdY/EXaldAm00PgT9QQMez66QIDAQAB;
keyType     : rsa
hash        : {sha1, sha256}
notes       :
publicKey   : MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCPkb8bu8RGWeJGk3hJrouZXIdZ+HTp/azRp8IUOHp5wKvPUAi/54PwuLscUjRk4Rh3hjIkMpKRfJJXPxWbrT7eMLric7f/S0h+qF4aqIiQqHF
              CDAYfMnN6V3Wbke2U5EGm0H/cAUYkaf2AtuHJ/rdY/EXaldAm00PgT9QQMez66QIDAQAB
validBase64 : True
services    : {*}
flags       :
warnings    :

.EXAMPLE
    ConvertFrom-MailAuthenticationRecordDkim -DomainName "microsoft.com"

    Returns [DKIMRecord] or "Failure to obtain record"
#>

Function ConvertFrom-MailAuthenticationRecordDkim {
    [OutputType([DKIMRecord],[System.String])]
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DomainName,

        [ipaddress]$DnsServerIpAddress = "1.1.1.1",

        [string]$DkimSelector = "selector1",

        [switch]$QuickTimeout,

        [switch]$NoHostsFile
    )

    begin {
        #TODO, add additional regexs for additional options, pop selector on call
        #[DKIMRecord]::new("v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCPkb8bu8RGWeJGk3hJrouZXIdZ+HTp/azRp8IUOHp5wKvPUAi/54PwuLscUjRk4Rh3hjIkMpKRfJJXPxWbrT7eMLric7f/S0h+qF4aqIiQqHFCDAYfMnN6V3Wbke2U5EGm0H/cAUYkaf2AtuHJ/rdY/EXaldAm00PgT9QQMez66QIDAQAB;")
        class DKIMRecord {
            [string]$record
            [string]$keyType = "rsa" #k
            [string[]]$hash = @("sha1","sha256") #h
            [string]$notes #n
            [string]$publicKey #p
            [bool]$validBase64
            [string[]]$services = "*" #s (*,email)
            [string[]]$flags #t (y,s)
            [string[]]$warnings

            hidden $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
            hidden $matchRecord = "^v\s*=\s*(?'v'DKIM1)\s*;\s*"
            hidden $matchKeyType = "k\s*=\s*(?'k'[^;]+)\s*;\s*"
            hidden $matchPublicKey = "p\s*=\s*(?'p'[^;]+)\s*;\s*"

            DKIMRecord([string]$record){
                $this.record = $record
                $match = $record -match $this.matchRecord
                if(-not $match){
                    $this.warnings = "v: Record does not match version format"
                    break
                }
                $p = [regex]::Match($record,$this.matchPublicKey,$this.option)
                $this.publicKey = ($p.Groups|Where-Object{$_.Name -eq "p"}).Value
                $bytes = [System.Convert]::FromBase64String(($p.Groups|Where-Object{$_.Name -eq "p"}).Value)
                $this.validBase64 = $null -ne $bytes
            }
        }
    }

    process {
        $dkimPrefix = "$DkimSelector._domainkey."
        $matchRecord = "^v\s*=\s*(?'v'DKIM1)\s*;\s*"

        $dkimSplat = @{
            Name         = "$dkimPrefix$DomainName"
            Type         = "TXT"
            Server       = $DnsServerIpAddress
            NoHostsFile  = $NoHostsFile
            QuickTimeout = $QuickTimeout
            ErrorAction  = "Stop"
        }
        try{
            if($isWindows){
                $dkimRecord = [DKIMRecord]::new((Resolve-DnsName @dkimSplat | `
                    Where-Object {$_.Type -eq "TXT"} | `
                    Where-Object {$_.Strings -match $matchRecord}).Strings)
            }else{
                $cmdletCheck = Get-Command "Resolve-Dns"
                if($cmdletCheck){
                    $dkimSplatAlt = @{
                        Query       = $dkimSplat.Name
                        QueryType   = $dkimSplat.Type
                        NameServer  = $dkimSplat.Server
                        ErrorAction = $dkimSplat.ErrorAction
                    }
                    $dkimRecord = [SPFRecord]::new((Resolve-Dns @dkimSplatAlt | `
                        Where-Object {$_.RecordType -eq "TXT"} | `
                        Where-Object {$_.Text -imatch $matchRecord}).Text)
                }else{
                    Write-Error "`nFor non-Windows platforms, please install DnsClient-PS module."
                    Write-Host "`n    Install-Module DnsClient-PS -Scope CurrentUser`n" -ForegroundColor Yellow
                    return "Missing dependency, Resolve-Dns not available"
                }
            }
        }catch [System.Management.Automation.CommandNotFoundException]{
            Write-Error $_
            return "Unsupported platform, Resolve-DnsName not available"
        }catch{
            Write-Error $_
            return "Failure to obtain record"
        }

        return $dkimRecord
    }
}