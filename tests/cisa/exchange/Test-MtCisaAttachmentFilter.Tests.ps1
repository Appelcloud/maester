Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.9.1", "CISA", "Security", "All" {
    It "MS.EXO.9.1: Emails SHALL be filtered by attachment file types." {

        $result = Test-MtCisaPresetSecurity

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}