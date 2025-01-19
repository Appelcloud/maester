<#
.SYNOPSIS
    Outlook is configured to display external tags for external emails.

.DESCRIPTION
    Generated on 01/19/2025 05:57:38 by .\build\orca\Update-OrcaTests.ps1

.EXAMPLE
    Test-ORCA240

    Returns true or false

.LINK
    https://maester.dev/docs/commands/Test-ORCA240
#>
function Test-ORCA240{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA240"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA240
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Outlook - External Tags - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Outlook is configured to display external tags for external emails.`n`n%ResultDetail%"
    }else{
        $resultMarkdown += "Your tenant did not pass. `n`n%ResultDetail%"
    }

    $passResult = "`u{2705} Pass"
    $failResult = "`u{274C} Fail"
    $skipResult = "`u{1F5C4}  Skip"
    $resultDetail = "| $($obj.ItemName) | $($obj.DataType) | Result |`n"
    $resultDetail += "| --- | --- | --- |`n"
    foreach($config in $obj.Config){
        switch($config.ResultStandard){
            "Pass" {$itemResult = $passResult}
            "Informational" {$itemResult = $skipResult}
            "None" {$itemResult = $skipResult}
            "Fail" {$itemResult = $failResult}
        }
        $resultDetail += "| $($config.ConfigItem) | $($config.ConfigData) | $itemResult |`n"
    }

    $resultMarkdown = $resultMarkdown -replace "%ResultDetail%", $resultDetail

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
