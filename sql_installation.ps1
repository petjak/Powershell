$VM = "KMLDBS114"
Get-VMmapISO -VM $VM -actiontype Map #function from \\kmladm22\Users\P.Jasenak-adm\Documents\WindowsPowerShell\Modules\Custom\VMmapISO.psm1"
$VM #variable filled in function Get-VMmapISO

#Uninstall OLD SQL SERVER
$arguninstall='/ACTION=Uninstall /QUIET="TRUE" /FEATURES=SQLENGINE,FULLTEXT,CONN,BC,BOL,SSMS,ADV_SSMS /INDICATEPROGRESS="TRUE" /INSTANCENAME="MSSQLSERVER"'
Start-Process -FilePath "C:\Program Files\Microsoft SQL Server\110\Setup Bootstrap\SQLServer2012\setup.exe" -ArgumentList $arguninstall

Invoke-Command -ComputerName $VM -ScriptBlock {
$listofdrives = Get-WmiObject win32_logicaldisk | where DriveType -eq 3 | Select -Property DeviceID, VolumeName
        Write-Host "Select drives:"
        Write-Host "--------------------"
        $menu3=@{}
        for ($i=1;$i -le $listofdrives.count; $i++) 
        { Write-Host "$i. $($listofdrives[$i-1].DeviceID) [$($listofdrives[$i-1].VolumeName)]" 
        $menu3.Add($i,($listofdrives[$i-1].DeviceID))}
        Write-Host ""
        [int]$tempdbdrivesel = Read-host "TempDB drive number>"
        [string]$tempdbdrive = $menu3.Item($tempdbdrivesel)
        [int]$sqldatabdrivesel = Read-host "Data files drive number>"
        [string]$sqldatabdrive = $menu3.Item($sqldatabdrivesel)
        [int]$tlogdrivesel = Read-host "Transaction log drive number>"
        [string]$tlogdrive = $menu3.Item($tlogdrivesel)
$tempdbloc = "$tempdbdrive\TEMPDB"
$sqldata = "$sqldatabdrive\SQLDATA"
$sqlbackup = "$sqldatabdrive\BACKUP"
$sqllog = "$tlogdrive\SQLLOG"


    If ((Test-Path $tempdbloc) -eq '') {New-item -Path $tempdbloc -ItemType directory}
    else {Write-Host 'The folder already exists'}
    If ((Test-Path $sqldata) -eq '') {New-item -Path $sqldata -ItemType directory}
    else {Write-Host 'The folder already exists'}
    If ((Test-Path $sqlbackup) -eq '') {New-item -Path $sqlbackup -ItemType directory}
    else {Write-Host 'The folder already exists'}
    If ((Test-Path $sqllog) -eq '') {New-item -Path $sqllog -ItemType directory}
    else {Write-Host 'The folder already exists'}

}

CLEAR-HOST

    do{
       $sqlsysaccount=Read-host -Prompt "Enter the SQL server service account (domain\useraccount), or press enter and LOCAL SYSTEM account will be used"
       #$pwd=if ($credentials.Password -ne '') {"\SQLSVCPASSWORD=$($credentials.Password)"}
            #else {''}
       if ($sqlsysaccount -eq '') {$sqlsysaccount = '"NT AUTHORITY\SYSTEM"';Clear-host; Write-Host "$Sqlsysaccount will be used"
                                   $check = "True"}
       else {
                    $check=$null
                    $username = $sqlsysaccount.Split("{\}")[1]
                    $domain = $sqlsysaccount.Split("{\}")[0]
                    $sqlSysPasswordSecured = Read-Host -assecurestring "Please enter the SQL Server Service Account Password"
                    $sqlsysPasswordBstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlSysPasswordSecured)            
                    $sqlSysPassword     = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($sqlsysPasswordBstr) 
                  
                    
                         Add-Type -AssemblyName System.DirectoryServices.AccountManagement
                         $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
                         $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($ct, $domain)
                         $accvalidation = New-Object PSObject -Property @{
                              UserName = $username;
                              IsValid = $pc.ValidateCredentials($username, $sqlsyspassword).ToString()
                         }
                    
                    $check=$accvalidation.IsValid
                    if ($accvalidation.isvalid -eq $True) {write-verbose "Useraccount '$username' is valid" -Verbose}
                    else {Clear-host; write-verbose "User account or password is invalid!!!" -Verbose}
                    }

       }until($check -eq $True)



$sapwd=-join ((33..126) | Get-Random -Count 32 | % {[char]$_})

#Clear-host
#$saPwdSecured       = Read-Host -assecurestring "Please enter the SA Password" 
#$saPwdBstr          = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($saPwdSecured)            
#$saPwd              = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($saPwdBstr)

Clear-Host
$inputcollation = Read-host "Enter SQL server collation, when You leave it empty, the default collation will be used"
 if ($inputcollation -eq '') {$sqlcollation="SQL_Latin1_General_CP1_CI_AS"}
 else {$sqlcollation=$inputcollation}

$config = New-Object -TypeName PSObject -Property @{
    Action                = " /ACTION=Install"
    Features              = " /Features=BC,BOL,Conn,SQLEngine,Fulltext"
    UpdateEnabled         = " /UpdateEnabled=True"
    UpdateSource          = " /UpdateSource=\\kmladm22.bs.kme.intern\f$\SQL_INSTALL\2k16"
    InstanceName          = " /INSTANCENAME=MSSQLSERVER"
    InstallSharedDir      = " /INSTALLSHAREDDIR="+ '"D:\Program Files\Microsoft SQL Server"'
    InstallSharedWowDir   = " /INSTALLSHAREDWOWDIR="+ '"D:\Program Files (x86)\Microsoft SQL Server"'
    InstanceDir           = " /INSTANCEDIR="+ '"D:\Program Files\Microsoft SQL Server"'
    SqlBackupDir          = " /SQLBACKUPDIR=$sqlBackup"
    SqlUserDbDir          = " /SQLUSERDBDIR=$sqlData"
    SqlUserDbLogDir       = " /SQLUSERDBLOGDIR=$sqlLog"
    SqlTempDbDir          = " /SQLTEMPDBDIR=$tempDbLoc"
    SqlCollation          = " /SQLCOLLATION=$sqlcollation"
    AgtSvcAccount         = " /AGTSVCACCOUNT="+$sqlSysAccount
    AgtSvcPassword        = if($sqlsysaccount -eq '"NT AUTHORITY\SYSTEM"') {''} else {" /AGTSVCPASSWORD=$sqlSysPassword"}
    AgtSvcStartupType     = " /AGTSVCSTARTUPTYPE=Automatic"
    SqlSvcAccount         = " /SQLSVCACCOUNT="+$sqlSysAccount
    SqlSvcPassword        = if($sqlsysaccount -eq '"NT AUTHORITY\SYSTEM"') {''} else {" /SQLSVCPASSWORD=$sqlSysPassword"}
    TcpEnabled            = " /TCPENABLED=1"
    NpEnabled             = " /NPENABLED=1"
    SqlSysAdminAccounts   = " /SQLSYSADMINACCOUNTS=BS\BS-Administration-SQL-Group"
    SecurityMode          = " /SECURITYMODE=SQL"
    SqlSvcInstantFileInit = " /SQLSVCINSTANTFILEINIT=True" 
    BrowserSvcStartupType = " /BROWSERSVCSTARTUPTYPE=Manual" 
    SapPwd                = " /SAPWD=$saPwd" 
}

$arg='/Q' + $config.Action + ' /IACCEPTSQLSERVERLICENSETERMS /IACCEPTROPENLICENSETERMS /SUPPRESSPRIVACYSTATEMENTNOTICE=True /INDICATEPROGRESS=True' + $config.Features + $config.UpdateEnabled + $config.UpdateSource + $config.InstanceName + $config.InstallSharedDir + $config.InstallSharedWowDir + $config.InstanceDir + $config.SqlBackupDir + $config.SqlUserDbDir + $config.SqlUserDbLogDir + $config.SqlTempDbDir + $config.SqlCollation + $config.AgtSvcAccount + $config.AgtSvcPassword + $config.AgtSvcStartupType + $config.SqlSvcAccount + $config.SqlSvcPassword + $config.TcpEnabled + $config.NpEnabled + $config.SqlSysAdminAccounts + $config.SecurityMode + $config.SqlSvcInstantFileInit + $config.BrowserSvcStartupType + $config.SapPwd 

Start-Process -FilePath Z:\setup.exe -ArgumentList $arg  

Invoke-Command -ComputerName $VM -ScriptBlock {
#Disabling the customer service, telemetry
Stop-Service -Name SQLTELEMETRY
Set-Service -name SQLTELEMETRY -StartupType Disabled
Set-Service -name SQLBrowser -StartupType Disabled
$regpath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\"
Set-ItemProperty -path $regpath\MSSQL13.MSSQLSERVER\CPE -Name "CustomerFeedback" -Value "0"
Set-ItemProperty -path $regpath\MSSQL13.MSSQLSERVER\CPE -Name "EnableErrorReporting" -Value "0"
Set-ItemProperty -path $regpath\130 -Name "CustomerFeedback" -Value "0"
Set-ItemProperty -path $regpath\130 -Name "EnableErrorReporting" -Value "0"
Set-ItemProperty -path "HKCU:\SOFTWARE\Microsoft\Microsoft SQL Server\130" -Name "CustomerFeedback" -Value "0"
}

#Startup parameters / TRACEFLAGS
$regpath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\"
New-ItemProperty -path $regpath\MSSQL13.MSSQLSERVER\MSSQLServer\Parameters -Name "SQLArg3" -Value "-T617"
New-ItemProperty -path $regpath\MSSQL13.MSSQLSERVER\MSSQLServer\Parameters -Name "SQLArg4" -Value "-T1117"
New-ItemProperty -path $regpath\MSSQL13.MSSQLSERVER\MSSQLServer\Parameters -Name "SQLArg5" -Value "-T1118"
New-ItemProperty -path $regpath\MSSQL13.MSSQLSERVER\MSSQLServer\Parameters -Name "SQLArg6" -Value "-T9481"


#SSMS Installation

Start-Process -FilePath \\kmladm22.bs.kme.intern\f$\SQL_INSTALL\SSMS\SSMS-Setup-ENU.exe -ArgumentList '/install /passive /norestart'




Set-DbaSpn -ServiceAccount "bs\bs.lobster-sql-srv"

test-dbaspn -ComputerName KMLDBS114.bs.kme.intern | Where { $_.isSet -eq $false } | Set-DbaSpn


cls

    