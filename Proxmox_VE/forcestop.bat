@echo off

REM ***********************************************
REM *                forcestop.bat                *
REM *                                             *
REM * Sample force stop script for Guest OS       *
REM *         Cluster for Windows on Proxmox VE.  *
REM *                                             *
REM * Assumption:                                 *
REM *  - All cluster nodes are managed by one     *
REM *    Proxmox VE Server.                       *
REM *  - Each cluster nodes hostname is same as   *
REM *    each VM name.                            *
REM *  - All cluster nodes have the following     *
REM *    software.                                *
REM *    - python3                                *
REM *    - curl                                   *
REM ***********************************************

REM Configuration:
REM change the following values according to your environment

set PVE_HOST_NODENAME=<e.g. pvenode1>
set PVE_HOST_ENDPOINT=<e.g. 192.168.10.200:8006>
set PVE_HOST_USERNAME=<e.g. root@pam>
set PVE_HOST_PASSWORD=<e.g. mypassword>

set CLUSTER_NODE1_NAME=<e.g. node1>
set CLUSTER_NODE1_VMID=<e.g. 101>
set CLUSTER_NODE2_NAME=<e.g. node2>
set CLUSTER_NODE2_VMID=<e.g. 102>
REM If you have more cluster nodes, add pairs of a name and a vmid like above

REM Constants

set JSON_PARSER_COMMAND=python -m json.tool
set FORCESTOP_LOGFILE=%TEMP%\clpforcestop.log

set PVE_RESTAPI_TICKET=/api2/json/access/ticket
set PVE_RESTAPI_QEMU=/api2/json/nodes/%PVE_HOST_NODENAME%/qemu
set PVE_RESTAPI_STATUS_CURRENT=/status/current
set PVE_RESTAPI_STATUS_STOP=/status/stop
set PVE_RESTAPI_STATUS_RESET=/status/reset
set PVE_TICKET_TMPFILE=%TEMP%\pve-ticket.json

goto main


REM Functions

:set_target_vmid
set nodename=%~1
if "%nodename%"=="%CLUSTER_NODE1_NAME%" (
    set TARGET_VMID=%CLUSTER_NODE1_VMID%
) else if "%nodename%"=="%CLUSTER_NODE2_NAME%" (
    set TARGET_VMID=%CLUSTER_NODE2_VMID%
) else (
    REM echo "Unknown node name (%nodename%)" >> %FORCESTOP_LOGFILE%
    exit /b 1
)
exit /b 0

:pve_login
curl -s -k -d "username=%PVE_HOST_USERNAME%" ^
     --data-urlencode "password=%PVE_HOST_PASSWORD%" ^
     https://%PVE_HOST_ENDPOINT%%PVE_RESTAPI_TICKET% ^
     | %JSON_PARSER_COMMAND% > %PVE_TICKET_TMPFILE%

for /f delims^=^"^ tokens^=4 %%a in ('findstr "ticket" %PVE_TICKET_TMPFILE%') do set PVE_TICKET=%%~a
for /f delims^=^"^ tokens^=4 %%a in ('findstr "CSRFPreventionToken" %PVE_TICKET_TMPFILE%') do set PVE_CSRF_TOKEN=%%~a

REM echo "PVE_TICKET: %PVE_TICKET%" >> %FORCESTOP_LOGFILE%
REM echo "PVE_CSRF_TOKEN: %PVE_CSRF_TOKEN%" >> %FORCESTOP_LOGFILE%

del %PVE_TICKET_TMPFILE%
exit /b 0

:pve_check_status
curl -s -X GET -k -b PVEAuthCookie=%PVE_TICKET% ^
    https://%PVE_HOST_ENDPOINT%%PVE_RESTAPI_QEMU%/%TARGET_VMID%%PVE_RESTAPI_STATUS_CURRENT% ^
    | %JSON_PARSER_COMMAND% | findstr /C:"running" > nul

if %errorlevel% equ 0 (
    REM echo "check: OK" >> %FORCESTOP_LOGFILE%
    exit /b 0
) else (
    REM echo "check: NG" >> %FORCESTOP_LOGFILE%
    exit /b 1
)

:pve_vm_stop
curl -s -X POST -k -b "PVEAuthCookie=%PVE_TICKET%" ^
     -H "CSRFPreventionToken: %PVE_CSRF_TOKEN%" ^
     https://%PVE_HOST_ENDPOINT%%PVE_RESTAPI_QEMU%/%TARGET_VMID%%PVE_RESTAPI_STATUS_STOP% ^
     | %JSON_PARSER_COMMAND% | findstr /C:"qmstop" > nul

if %errorlevel% equ 0 (
    REM echo "vm_stop: OK" >> %FORCESTOP_LOGFILE%
) else (
    REM echo "vm_stop: NG" >> %FORCESTOP_LOGFILE%
    exit /b 1
)

for /l %%i in (1,1,5) do (
    curl -s -X GET -k -b "PVEAuthCookie=%PVE_TICKET%" ^
        https://%PVE_HOST_ENDPOINT%%PVE_RESTAPI_QEMU%/%TARGET_VMID%%PVE_RESTAPI_STATUS_CURRENT% ^
        | %JSON_PARSER_COMMAND% | findstr /C:"status" | findstr /C:"stopped" > nul

    if %errorlevel% equ 0 (
        REM echo "vm_status: stopped" >> %FORCESTOP_LOGFILE%
        exit /b 0
    ) else (
        REM echo "vm_status: not stopped" >> %FORCESTOP_LOGFILE%
        timeout 2 > nul
    )
)
REM echo "failed to confirm that vm has been stopped" >> %FORCESTOP_LOGFILE%
exit /b 1


REM Main process

:main
call :pve_login
if "%CLP_FORCESTOP_MODE%"=="0" (
    REM check REST API availability
    call :set_target_vmid %CLP_SERVER_LOCAL%
    call :pve_check_status
) else if "%CLP_FORCESTOP_MODE%"=="1" (
    REM forcibly stop the target node
    call :set_target_vmid %CLP_SERVER_DOWN%
    call :pve_vm_stop
) else (
    REM echo "Unknown mode (%CLP_FORCESTOP_MODE%)" >> %FORCESTOP_LOGFILE%
    exit /b 1
)

exit /b %errorlevel%
