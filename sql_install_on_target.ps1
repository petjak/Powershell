#Connect installation DVD
   DO {
            Clear-Host 
            $connectiso = Read-Host -Prompt "Do you want to map the installation DVD to the target? Y/N"
           } until ($connectiso -match "^[yYnN]$")
if ($connectiso -match "^[yY]$") {
[string]$login = $env:USERDOMAIN +"\"+ $env:USERNAME
$cred = Get-Credential -UserName $login -Message "Enter valid credentials"
$vm = $env:COMPUTERNAME
       
Clear-Host
$version='2017', '2016', '2014', '2012' #list of available versions of SQL server
Write-Host "Select SQL server version:"
Write-Host "--------------------------"
$menu1=@{}
for ($i=1;$i -le $version.count; $i++) 
{Write-Host "$i. $($version[$i-1])" 
$menu1.Add($i,($version[$i-1]))}
Write-Host ""
[int]$selection = Read-Host -Prompt 'Enter the number>'
$selectedversion = $menu1.Item($selection)

invoke-command -computername kmladm22.bs.kme.intern -scriptblock {Get-VMmapISO -VM $args[0] -actiontype "map" -selectedversion $args[1] -cred $args[2]} -argumentlist $vm, $selectedversion, $cred
}


#Create folders
Clear-host
$listofdrives = Get-WmiObject win32_volume | where DriveType -eq 3 | Where Label -NE "SYSTEM RESERVED" | ForEach-Object {$i=0} {New-Object -TypeName PSObject -property @{
            Nr = $i++; 
            letter = $_.DriveLetter;
            blocksize = $_.BlockSize;
            label = $_.Label;}}
$drivesmenu = $listofdrives | select Nr, letter, label |  Out-String


        write-host $drivesmenu
       DO{
        $Err = $null
        [int]$tempdbdrivesel = Read-host "TempDB drive number>"
        [string]$tempdbdrive = $listofdrives[$tempdbdrivesel].letter
        if ($listofdrives[$tempdbdrivesel].blocksize -ne 65536) {Write-Error 'Bad formating, please format selected drive with 64kb allocation unit size, or select different drive' -ErrorAction Stop -ErrorVariable $Err}
        }until ($Err -eq $null)
        [int]$sqldatadrivesel = Read-host "Data files drive number>"
        [string]$sqldatadrive = $listofdrives[$sqldatadrivesel].letter
        if ($listofdrives[$sqldatadrivesel].blocksize -ne 65536) {Write-Error 'Bad formating, please format selected drive with 64kb allocation unit size, or select different drive' -ErrorAction Stop}
        
        [int]$tlogdrivesel = Read-host "Transaction log drive number>"
        [string]$tlogdrive = $listofdrives[$tlogdrivesel].letter
        if ($listofdrives[$tlogdrivesel].blocksize -ne 65536) {Write-Error 'Bad formating, please format selected drive with 64kb allocation unit size, or select different drive' -ErrorAction Stop}

$tempdbloc = "$tempdbdrive\TEMPDB"
    If ((Test-Path $tempdbloc) -eq '') {New-item -Path $tempdbloc -ItemType directory}
    else {Write-Host 'The folder already exists'}
$sqldata = "$sqldatadrive\SQLDATA"
    If ((Test-Path $sqldata) -eq '') {New-item -Path $sqldata -ItemType directory}
    else {Write-Host 'The folder already exists'}
$sqlbackup = "$sqldatadrive\SQLBACKUP"
    If ((Test-Path $sqlbackup) -eq '') {New-item -Path $sqlbackup -ItemType directory}
    else {Write-Host 'The folder already exists'}
$sqllog = "$tlogdrive\SQLLOG"
    If ((Test-Path $sqllog) -eq '') {New-item -Path $sqllog -ItemType directory}
    else {Write-Host 'The folder already exists'}



CLEAR-HOST

if ($listofdrives.Letter -notcontains "D:") {
    $InstallSharedDir      = '"C:\Program Files\Microsoft SQL Server"'
    $InstallSharedWowDir   = '"C:\Program Files (x86)\Microsoft SQL Server"'
    $InstanceDir           = '"C:\Program Files\Microsoft SQL Server"'
    }
else {
    $InstallSharedDir      = '"D:\Program Files\Microsoft SQL Server"'
    $InstallSharedWowDir   = '"D:\Program Files (x86)\Microsoft SQL Server"'
    $InstanceDir           = '"D:\Program Files\Microsoft SQL Server"'
    }
#Service account settings
 DO{
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

#random sa password
$sapwd=-join ((33..126) | Get-Random -Count 32 | % {[char]$_})

Clear-Host

#SQL Server installation settings + initialization
$inputcollation = Read-host "Enter SQL server collation, when You leave it empty, the default collation will be used"
 if ($inputcollation -eq '') {$sqlcollation="SQL_Latin1_General_CP1_CI_AS"}
 else {$sqlcollation=$inputcollation}

Clear-Host

Write-host "Do you want to install some additional features?`n`nAS - Analyses Services`nIS - Integration Services`nRS - Reporting Services`nMDS - Master Data Services`nFulltext - Fulltext Search`nReplication`n`n"#Write-host `n"$selected_features = Read-Host "Enter your selection, comma separated (AS,IS,RS...no spaces). When nothing is entered basic features will be installed"

if (!$selected_features) {$features = $null}
Else {$features = ","+$selected_features}


$config = New-Object -TypeName PSObject -Property @{
    Action                = " /ACTION=Install"
    Features              = " /Features=BC,Conn,SQLEngine"+$features
    UpdateEnabled         = " /UpdateEnabled=True"
    UpdateSource          = " /UpdateSource=\\kmladm22.bs.kme.intern\f$\SQL_INSTALL\$selectedversion"
    InstanceName          = " /INSTANCENAME=MSSQLSERVER"
    InstallSharedDir      = " /INSTALLSHAREDDIR="+$InstallSharedDir
    InstallSharedWowDir   = " /INSTALLSHAREDWOWDIR="+$InstallSharedWowDir
    InstanceDir           = " /INSTANCEDIR="+$InstanceDir
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

Start-Process -FilePath Z:\setup.exe -ArgumentList $arg -Wait

$services = Get-Service -DisplayName *SQL*
IF (!$services) {write-error -Message "SQL Server has not been installed!!! Installation failed from some reason." -Category NotInstalled -RecommendedAction "Check the installation log." -ErrorAction Stop}
ELSE {Write-Host "SQL Server has been Installed successfully" -ForegroundColor Green}


#Unmap installation DVD
invoke-command -computername kmladm22.bs.kme.intern -scriptblock {Get-VMmapISO -VM $args[0] -actiontype "unmap" -cred $args[1]} -argumentlist $vm, $cred


#Disable Microsoft improvement program services
Stop-Service -Name SQLTELEMETRY
Set-Service -name SQLTELEMETRY -StartupType Disabled
Set-Service -name SQLBrowser -StartupType Disabled
$regpath1 = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\"
$regpath2 = "HKCU:\SOFTWARE\Microsoft\Microsoft SQL Server\"

Get-ChildItem -Path $regpath1 -recurse -ea SilentlyContinue | where Property -Contains "Parameters" | ForEach-Object {Set-ItemProperty -Path $_.PSPath -Name "CustomerFeedback" -Value "0"}
Get-ChildItem -Path $regpath1 -recurse -ea SilentlyContinue | where Property -Contains "EnableErrorReporting" | ForEach-Object {Set-ItemProperty -Path $_.PSPath -Name "EnableErrorReporting" -Value "0"}
Get-ChildItem -Path $regpath2 -recurse -ea SilentlyContinue | where Property -Contains "CustomerFeedback" | ForEach-Object {Set-ItemProperty -Path $_.PSPath -Name "CustomerFeedback" -Value "0"}

#Startup parameters / TRACEFLAGS
$argcount = Get-ChildItem -Path $regpath1 -recurse -ea SilentlyContinue | where PSChildName -eq "Parameters" | Select ValueCount 
[int]$argcountint = $argcount.ValueCount
$parampath = Get-ChildItem -Path $regpath1 -recurse -ea SilentlyContinue | where PSChildName -eq "Parameters"

New-ItemProperty -path $parampath.PSPath -Name "SQLArg$argcountint" -Value "-T1117"
$argcountint++
New-ItemProperty -path $parampath.PSPath -Name "SQLArg$argcountint" -Value "-T1118"
$argcountint++
New-ItemProperty -path $parampath.PSPath -Name "SQLArg$argcountint" -Value "-T3226"


#SQL Best practices application$QUERY = "exec sp_configure 'show advanced options', 1;
RECONFIGURE
GO
DECLARE @QSPM VARCHAR(1000) 
DECLARE @NMM DECIMAL(9,0)
DECLARE @OMM DECIMAL(12,0) 
DECLARE @SPM DECIMAL(9,2) 
DECLARE @limit INT 
DECLARE @memOsBase DECIMAL(9,2),
@memOs4_16GB DECIMAL(9,2),
@memOsOver_16GB DECIMAL(9,2),
@memOsTot DECIMAL(9,2),
@memForSql DECIMAL(9,0)
DECLARE @NUMA SMALLINT
DECLARE @CPU INT
DECLARE @MAXDOP INT

IF OBJECT_ID('tempdb..#mem') IS NOT NULL DROP TABLE #mem

CREATE TABLE #mem(mem DECIMAL(9,2)) 

SET @limit = 2147483647
SET @OMM = (SELECT CAST(value AS INT)/1. FROM sys.configurations WHERE name = 'max server memory (MB)')

IF CAST(LEFT(CAST(SERVERPROPERTY('ResourceVersion') AS VARCHAR(20)), 1) AS INT) = 9
SET @QSPM = '(SELECT physical_memory_in_bytes/(1024*1024.) FROM sys.dm_os_sys_info)'
ELSE
   IF CAST(LEFT(CAST(SERVERPROPERTY('ResourceVersion') AS VARCHAR(20)), 2) AS INT) >= 11
     SET @QSPM = '(SELECT physical_memory_kb/(1024.) FROM sys.dm_os_sys_info)'
   ELSE
     SET @QSPM = '(SELECT physical_memory_in_bytes/(1024*1024.) FROM sys.dm_os_sys_info)'

SET @QSPM = 'DECLARE @mem decimal(9,2) SET @mem = (' + @QSPM + ') INSERT INTO #mem(mem) VALUES(@mem)'

EXEC(@QSPM)
SET @SPM = (SELECT MAX(mem) FROM #mem)

SET @memOsBase = 1024
SET @memOs4_16GB =
  CASE
    WHEN @SPM <= 4096 THEN 0
   WHEN @SPM > 4096 AND @SPM <= 16384 THEN (@SPM - 4096) / 4
    WHEN @SPM >= 16384 THEN 3096
  END

SET @memOsOver_16GB =
  CASE
    WHEN @SPM <= 16384 THEN 0
   ELSE (@SPM - 16384) / 8
  END

SET @memOsTot = @memOsBase + @memOs4_16GB + @memOsOver_16GB
SET @NMM = @SPM - @memOsTot

SET @memForSql = (SELECT 'Maximum Server Memory (MB)' = CASE
WHEN @OMM = @limit THEN @NMM
WHEN @OMM < @limit THEN @OMM
END)

SET @MAXDOP = (SELECT CAST(value_in_use AS INT) as actual_value FROM sys.configurations WHERE name = 'Max degree of parallelism')
SET @NUMA = (SELECT COUNT(DISTINCT memory_node_id) FROM master.sys.dm_os_memory_clerks Where  memory_node_id<64)
SET @CPU = (select cpu_count/(SELECT COUNT(DISTINCT memory_node_id) FROM master.sys.dm_os_memory_clerks Where  memory_node_id<64) from sys.dm_os_sys_info)

SET @MAXDOP = (select 'MAXDOP' = CASE
WHEN @MAXDOP > 0 THEN @MAXDOP
WHEN @MAXDOP = 0 AND @NUMA = 1 AND @CPU < 4 THEN 1
WHEN @MAXDOP = 0 AND @NUMA = 1 AND @CPU = 4 THEN 1
WHEN @MAXDOP = 0 AND @NUMA = 1 AND @CPU = 6 THEN 2
WHEN @MAXDOP = 0 AND @NUMA = 1 AND @CPU = 8 THEN 4
WHEN @MAXDOP = 0 AND @NUMA = 1 AND @CPU >  8 THEN 4
WHEN @MAXDOP = 0 AND @NUMA > 1 AND @CPU < 8 THEN 2
WHEN @MAXDOP = 0 AND @NUMA > 1 AND @CPU >= 8 THEN 4
END)



exec sp_configure 'priority boost', 0;
exec sp_configure 'remote admin connections', 1;
exec sp_configure 'remote access', 1;
exec sp_configure 'lightweight pooling', 0;
exec sp_configure 'max degree of parallelism', @MAXDOP;
exec sp_configure 'max server memory (MB)', @memForSql;
exec sp_configure 'show advanced options', 0;
RECONFIGURE
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', REG_DWORD, 14
GO
ALTER LOGIN [sa] DISABLE
GO
"


if (!(get-module SQLPS -ListAvailable)) {
$SQLModulepath = get-ChildItem -path $InstallSharedWowDir.Trim('"') -Directory SQLPS -Recurse
$SQLPSpath = $SQLModulepath.FullName.Trim("SQLPS")
$env:PSModulePath = $env:PSModulePath + ";$SQLPSpath"
Import-Module -name SQLPS}

Invoke-Sqlcmd -ServerInstance . -Database master -Query $QUERY

#SSMS Installation

Clear-Host
DO{
$SSMSprompt = Read-Host -Prompt "Do you want to install SSMS? Y/N"
} until ($SSMSprompt -match "^[yYnN]$")
if ($SSMSprompt -match "^[yY]$") {
Start-Process -FilePath \\kmladm22.bs.kme.intern\f$\SQL_INSTALL\SSMS\SSMS-Setup-ENU.exe -ArgumentList '/install /passive /norestart' -Wait}