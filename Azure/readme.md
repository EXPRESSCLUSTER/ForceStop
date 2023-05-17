# Quick Start Guide for forced stop resource on Azure environment

## Overview
EXPRESSCLUSTER X 5.1 has a forced stop resource on Azure environment and it requires Certificate-based authentication.
This article shows a sample setup procedure to configure it.

About more details for the forced stop function, please refer EXPRESSCLUSTER Reference Guide:
- [EXPRESSCLUSTER X 5.1 for Windows - Forced stop on Azure environment](https://docs.nec.co.jp/sites/default/files/minisite/static/bed29cb7-e558-41c7-89ef-7912e71ea18d/ecx_x51_windows_en/W51_RG_EN/W_RG_07.html#understanding-forced-stop-on-azure)

## Preparation
- Create VMs on Azure and setup a cluster by EXPRESSCLUSTER X.
- Log in to Azure Portal and confirm the following parameters:
	- Azure Portal login user name ("UserName") and its password ("Password")
	- Tenant ID ("TenantID")
	- Subscription ID ("SubscriptionID")
	- Resource group name ("ResourceGroup")
	- Cluster VM names ("VMnameX")
 
## Setup procedure
### For Windows
1. Install Azure CLI
	- On ALL cluster servers
		1. Install Azure CLI from [Microsoft website](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli-windows?tabs=azure-cli).
		1. Confirm that Azure CLI works by displaying Aure CLI version:  
			```bat
			PS> az --version
			```
		1. Confirm that you can login to Azure by Azure CLI:  
			```bat
			PS> az login -u "UserName" -p "Password"
			```
1. Creare service principal
	1. On Azure Portal
		1. Select [Azure Active Directory] - [Appregistrations].
		1. Select [New registration], set parameters and register it.
			- Application name
				- e.g.) cluster-cli
			- Account
				- Select one which has a permission to operate the cluster nodes.
			- Redirect URI
				- Set as you like (not mandatory)
		1. Select [Azure Active Directory] - [Enterprise applications] and confirm that "cluster-cli" service principal has been displayed.
			- If the service principal does not have a enough permission to operate cluster node VMs, change it. We recommend to assign "Contributor" role.
				- Reference: Microsoft ["Create an Azure Active Directory application and service principal that can access resources"](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)
			- Select "cluster-cli" service principal and confirm the following parameter:
				- Application ID ("AppID")
1. Setup Certificate-based authentication
	1. On Primary node
		1. Start Window PowerShell and login to Azure:
			```bat
			PS> az login -u "UserName" -p "Password"
			```
		1. Create PEM file and confirm PEM file path:
			```bat
			PS> az ad sp create-for-rbac --name "AppID" --role Contributor --scopes /subscriptions/"SubscriptionID"/resourceGroups/"ResourceGroup" --create-cert
			{
			  "appId": "AppID",
			  "displayName": "cluster-cli"
			  "fileWithCertAndPrivateKey": "C:\\Users\\xxxx\\xxxx.pem",
			  "password": "xxxx",
			  "tenant": "xxxx"
			}
			```
		1. Log out:
			```bat
			PS> az logout
			```
		1. In order to confirm that the forced stop function works, try the followings which are used by the resource:
			1. Log in to Azure by the Certificate-based authentication:
				```bat
				PS> az login --service-principal -u "AppID" -p "C:\\Users\\xxxx\\xxxx.pem" --tenant "TenantID"
				```
			1. Reboot a stanby VM:
				```bat
				PS> az vm restart -g "ResourceGroup" -n "VMnameX (Stanby VM)" --force
				```
			1. Log out:
				```bat
				PS> az logout
				```
			1. If any commands fail, settings may not enough. Please check the procedure above.
				- Reference: Microsoft [Create an Azure service principal with the Azure CLI](https://learn.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli)
	1. On all nodes
		1. Create a folder to store the PEM file.
			- e.g.) C:\ECXcert
		1. Copy the PEM file which has been created on Primary node and paste it to the folder on all nodes.
			- C:\ECXcert\xxxx.pem ("PEMfilePath")
			- _Note_  
			The file name and path should be the same on all cluster nodes.
1. Setup cluster configuration
	1. On Cluster WebUI
		1. Open Config Mode.
		1. Select [Cluster Properties] - [Fencing] tab and set the following parameters:
			- Forced Stop Type: Azure
		1. Click [Properties] button and set the following parameters:
			- [Server List] tab
				- Select all servers and click [Add] button, then enter "VMnameX".
			- [Forced Stop] tab
				- Set as you like.
			- [Azure] tab
				- User URI: Enter "AppID"
				- Tenant ID: Enter "TenantID"
				- File Path of Service Principal: Enter "PEMfilePath"
				- Resource Group Name: Enter "ResourceGroup"
		1. Apply the configuration.

## Test procedure
Forced stop function works when failover for heartbeat down occurs.
Therefore, you can confirm that by blocking or stopping heartbeat communication.

1. Confirm that the cluster status is normal and failover group is active on Primary node.
1. Block or stop heartbeat from Primary to Secondary node.
	- You can block or stop heartbeat by following procedure:
		- Close heartbeat port by Firewall or Azure network rules.
		- Stop EXPRESSCLUSTER heartbeat process by the following procedure:
			- For Windows
				- Open Windows Services manager.
				- Right click "EXPRESSCLUSTER Node Manager" and select [Properties].
				- Select [Recovery] tab and change all recovery action to "Take No Action", then click "OK".
				- Stop the "EXPRESSCLUSTER Node Manager" service.
					- *Note:*  
						NOT to FORGET to change all recovery action back to "Restart the Computer" after this test.
1. Confirm that Secondary node detects Primary node heartbeat error and faillover to Secondary occurs.
1. After failover occurs, confirma the followings:
	- Primary node is stopped or rebooted on Azure Portal.
	- Forced stop log is recorded on Cluster WebUI Alert logs.
