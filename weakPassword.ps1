Write-Output "It's only possible to detect whether user accounts have blank passwords if the minimum password length is 0.";

$PasswordMinimumLength = 0;
Write-Output "Implementing new minimum password length of $PasswordMinimumLength...";

$Secedit_CFGFile_Path = [System.IO.Path]::GetTempFileName();
$Secedit_Path = "$env:SystemRoot\system32\secedit.exe";
$Secedit_Arguments_Export = "/export /cfg $Secedit_CFGFile_Path /quiet";
$Secedit_Arguments_Import = "/configure /db $env:SystemRoot\Security\local.sdb /cfg $Secedit_CFGFile_Path /areas SecurityPolicy";

Start-Process -FilePath $Secedit_Path -ArgumentList $Secedit_Arguments_Export -Wait;

$SecurityPolicy_Old = Get-Content $Secedit_CFGFile_Path;

$SecurityPolicy_New = $SecurityPolicy_Old -Replace "MinimumPasswordLength = \d+", "MinimumPasswordLength = $PasswordMinimumLength";

Set-Content -Path $Secedit_CFGFile_Path -Value $SecurityPolicy_New;

Try {
    Start-Process -FilePath $Secedit_Path -ArgumentList $Secedit_Arguments_Import -Wait;
} Catch {
    Write-Output "...FAILED.";
    Break;
}
If ($?){
    Write-Output "...Success.";
}
Write-Output "";
Write-Output "----------------------------------------------------------------";
Write-Output "";

Write-Output "Searching for user accounts with blank passwords...";

$BlankPasswordsFoundWording_PreUsername = "Found user account";
$BlankPasswordsFoundWording_PostUsername = "with a blank password.";
$NoBlankPasswordsFoundWording = "No user accounts with blank passwords found.";

$VBS_IdentifyBlankPasswords_Commands = @"
On Error Resume Next

Dim strComputerName
Dim strPassword

strComputerName = WScript.CreateObject("WScript.Network").ComputerName
strPassword = ""

Set LocalAccounts = GetObject("WinNT://" & strComputerName)
LocalAccounts.Filter = Array("user")

Dim Flag
Flag = 0 

For Each objUser In LocalAccounts
    objUser.ChangePassword strPassword, strPassword
    If Err = 0 or Err = -2147023569 Then
        Flag = 1
        Wscript.Echo "$BlankPasswordsFoundWording_PreUsername """ & objUser.Name & """ $BlankPasswordsFoundWording_PostUsername"
    End If
    Err.Clear
Next

If Flag = 0 Then
    WScript.Echo "$NoBlankPasswordsFoundWording"
End If
"@
# The above here-string terminator cannot be indented.;

# cscript won't accept / process a file with extension ".tmp" so ".vbs" needs to be appended.;
$VBS_IdentifyBlankPasswords_File_Path_TMP = [System.IO.Path]::GetTempFileName();
$VBS_IdentifyBlankPasswords_File_Directory = (Get-ChildItem $VBS_IdentifyBlankPasswords_File_Path_TMP).DirectoryName;
$VBS_IdentifyBlankPasswords_File_Name_TMP = (Get-ChildItem $VBS_IdentifyBlankPasswords_File_Path_TMP).Name;
$VBS_IdentifyBlankPasswords_File_Name_VBS = $VBS_IdentifyBlankPasswords_File_Name_TMP + ".vbs";
$VBS_IdentifyBlankPasswords_File_Path_VBS = "$VBS_IdentifyBlankPasswords_File_Directory\$VBS_IdentifyBlankPasswords_File_Name_VBS";

Set-Content -Path $VBS_IdentifyBlankPasswords_File_Path_VBS -Value $VBS_IdentifyBlankPasswords_Commands;

$VBS_IdentifyBlankPasswords_Output = & cscript /nologo $VBS_IdentifyBlankPasswords_File_Path_VBS;
# Write-Output $VBS_IdentifyBlankPasswords_Output;

$UsersWithBlankPasswords = $VBS_IdentifyBlankPasswords_Output | Select-String -Pattern "$BlankPasswordsFoundWording_PreUsername";

If ($UsersWithBlankPasswords -NE $Null){
    ForEach ($UserWithBlankPassword in $UsersWithBlankPasswords){
        $Username = [regex]::match($UserWithBlankPassword, '"([^"]+)"').Groups[1].Value;

        Write-Output "...$BlankPasswordsFoundWording_PreUsername ""$Username"" $BlankPasswordsFoundWording_PostUsername";
    }
} ElseIf ($UsersWithBlankPasswords -Eq $Null){
    Write-Output "$NoBlankPasswordsFoundWording";
}

Write-Output "";
Write-Output "----------------------------------------------------------------";
Write-Output "";

Write-Output "Implementing original minimum password length...";

Set-Content -Path $Secedit_CFGFile_Path -Value $SecurityPolicy_Old;

Try {
    Start-Process -FilePath $Secedit_Path -ArgumentList $Secedit_Arguments_Import -Wait;
} Catch {
    Write-Output "...FAILED.";
    Break;
}
If ($?){
    Write-Output "...Success.";
}
