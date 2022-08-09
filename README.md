# ECX Force Stop for Hyper-V

### Sample Configuration

|  |  |
|--|--|
| Hyper-V #1 host name | pm1 |
| Hyper-V #2 host name | pm2 |
| IP of pm1       | 172.31.255.11 |
| IP of pm2       | 172.31.255.12 |
| VM in pm1 (display name on Hyper-V Manager) | vm1 |
| VM in pm2 (display name on Hyper-V Manager) | vm2 |
| vm1 host name | ws2022-1 |
| vm2 host nmae | ws2022-2 |

EC runs on vm1 and 2.

### Prerequisit

1. Enable WinRM on pm1 and 2.

   On both pm1 and 2, open PowerShell with administrator privilege. Issue

   ```
   Enable-PSRemoting
   ```

2. Register pm2 as trusted host on vm1.

   On vm1, open PowerShell with administrator privilege. Issue `Set-Item WSMan:\localhost\Client\TrustedHosts -Value "IP_of_pm2"`

   ```
   net start WinRM
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value "172.31.255.12"
   ```

3. Register pm1 as trusted host on vm2.

   On vm2, open PowerShell with administrator privilege. Issue `Set-Item WSMan:\localhost\Client\TrustedHosts -Value "IP_of_pm1"`

   ```
   net start WinRM
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value "172.31.255.11"
   ```

### Configuring procedure

1. Open WebUI > Config mode > Cluster Properties > 
2. Account tab > Add > set `administrator` and its password > `OK` >
3. Fencing tab > `Properties` of Forced Stop > Script tab > click `forcestop.bat` > `Edit` > put the following script with editing vm names and Hyper-V host IP addresses >

   ```
   rem ***************************************
   rem *            forcestop.bat            *
   rem ***************************************
   echo START

   echo DOWN SERVER NAME    : %CLP_SERVER_DOWN%
   echo LOCAL SERVER NAME   : %CLP_SERVER_LOCAL%

   if "%CLP_SERVER_DOWN%"=="vm1" (
       echo Turning off vm1
       powershell "Invoke-Command -ComputerName \"172.31.255.11\" -ScriptBlock {Stop-VM vm1 -TurnOff}"
   )
   if "%CLP_SERVER_DOWN%"=="vm2" (
       echo Turning off vm2
       powershell "Invoke-Command -ComputerName \"172.31.255.12\" -ScriptBlock {Stop-VM vm2 -TurnOff}"
   )
   if "%CLP_SERVER_DOWN%"=="" (
       exit 0
   )

   echo EXIT
   ```

4. `OK` > select `administrator` for `Exec User` > `OK` > `OK`

---
2022.07.29 Miyamoto Kazuyuki
