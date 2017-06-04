With newer versions of Windows, PowerShell is installed by default but not likely enabled.

Using either Cortana or the 'Run', enter or select 'PowerShell' to launch the PowerShell console. Once the PowerShell console window is displayed enter the following command.

    PS> set-executionpolicy -unrestricted

**Above command use 'Run As Administrator'**

There are basically two ways to install the **Get-JackPot**.  For those not that familiar with PowerShell or Windows, the easiest is to use the **Install-Script** command.

    PS> Install-Script Get-JackPot -Scope currentuser

If the PowerShellGet module is not already installed, there will be a prompt requesting permission to install the module. A selection of 'Yes' is the right answer.

If **Get-JackPot** has already been installed, it can be updated to the latest version by entering the command:
    
    PS> Update-Script Get-JackPot

The other method of installing the script is to use the normal GitHub process of cloning the script to your computer.
