<#
.SYNOPSIS
    Install MSYS2 on your system.

.DESCRIPTION
    Install MSYS2 on your system in the deploy area by downloading the archive
    and deploying it in the deploy aera.
    Deploying means that the msys2 base install has custom environment, custom config files
    and is upgraded to the latest version its package manager can access.

.PARAMETER deployArea
    Specify where the target directory to install MSYS2 is.

.PARAMETER $pauseAtEnd
    Tell if the script should invoke a pause command before exiting completely.

.NOTES
    Originally, the script was intended to be used by Patoune.
    Last SUCCESSFUL TEST DATE: 2024 11 13
#>

param(
    [Parameter(Mandatory=$true)]
    [Alias("da")]
    [string]$deployArea,
    [Alias("pae")]
    [bool]$pauseAtEnd=$false
)

$msysArchiveBaseName="msys2-base-x86_64-20240727"
$msysXzArchive="$deployArea\$msysArchiveBaseName.tar.xz"
$msysTarName="$deployArea\$msysArchiveBaseName.tar"

$shCmd="$deployArea\msys64\msys2.exe"

function Install-MSYS2 {
    if (Test-Path $deployArea\dne_install_msys2.lock) {
        Write-Warning "Lock file already present. A previous installation has been started but have not finished successfully."
        $confirm = Read-Host -Prompt "Do you want to continue ? [Y/n] "
        if ($confirm -notIn "", "Y", "y") {
            Exit
        }
    }
    New-Item -itemType File -Force $deployArea\dne_install_msys2.lock >> $null
    # step 1
    Write-Host -ForegroundColor Green "INF - [STEP 1/4] Materialize Dependencies"
    step-materialize-dependencies
    # step 2
    Write-Host -ForegroundColor Green "INF - [STEP 2/4] Extract Archive"
    step-extract-archive
    # step 3
    Write-Host -ForegroundColor Green "INF - [STEP 3/4] Setup Install"
    step-setup-install
    # step 4
    Write-Host -ForegroundColor Green "INF - [STEP 4/4] Update Install"
    step-update-install
    Remove-Item -Force $deployArea\dne_install_msys2.lock
    Write-Host -ForegroundColor Green "INF - Install MSYS2 Completed."
}

function step-materialize-dependencies {
    # Don't automatize Microsoft.PowerShell.PSResourceGet installation since it should be here.
    if (-not (Get-Module Microsoft.PowerShell.PSResourceGet)) {
        Write-Error "Microsoft.PowerShell.PSResourceGet module not found."
        Write-Warning "You can install missing resource with the following command:"
        Write-Host -ForegroundColor DarkYellow "PS> Install-PSResource -Name Microsoft.PowerShell.PSResourceGet -Reinstall"
        Write-Host "For more information see: https://www.powershellgallery.com/packages/Microsoft.PowerShell.PSResourceGet"
        Exit
    } else {
        Write-Host "Microsoft.PowerShell.PSResourceGet is here."
    }
    $ProgressPreferenceBackup = $Global:ProgressPreference
    $Global:ProgressPreference = 'SilentlyContinue'
    if (-not(Test-Path $msysXzArchive)) {
        Write-Host -NoNewline "Downloading archive 'http://repo.msys2.org/distrib/x86_64/$msysArchiveBaseName.tar.xz' in '$msysXzArchive'."
        Start-BitsTransfer `
            -Source "http://repo.msys2.org/distrib/x86_64/$msysArchiveBaseName.tar.xz" `
            -Destination $msysXzArchive

        Write-Host " Done."
    } else {
      Write-Host "Archive already downloaded in '$msysXzArchive'"
    }

    if (-not (Get-Command Expand-7Zip -ErrorAction Ignore)) {
        Write-Warning "P7Zip not present, installing it."
        Install-PSResource -Name PS7Zip
    } else {
        Write-Host "PS7Zip already accessible at runtime, nothing to do."
    }
    $Global:ProgressPreference = $ProgressPreferenceBackup
}

function step-extract-archive {
    Write-Host -NoNewline "Extracting archives '$msysXzArchive' to '$deployArea' ..."
    Expand-7Zip -FullName $msysXzArchive -DestinationPath $deployArea > $null
    Expand-7Zip -FullName $msysTarName -DestinationPath $deployArea -Remove > $null
    Write-Host " Done."
}

function step-setup-install {
    # Need a first launch to make default files in order.
    Write-Host -NoNewline "Running msys2.exe for the first time ..."
    Start-Process -Wait -UseNewEnvironment -FilePath $shCmd -ArgumentList 'dash -c exit'
    Write-Host " Done."

    # Patching path ... (Fixme: Find something better than this ugly command line)
    Write-Host -NoNewline "Patching bash path to have C:\\Python39 and C:\\Program Files\\Perforce in path ..."
    Start-Process -Wait -UseNewEnvironment -FilePath $shCmd `
        -ArgumentList 'dash -c "echo ''PATH=$PATH:/c/Python39:/c/Python39/Scripts:/c/Program\ Files/Perforce:/c/Program\ Files/Perforce/DVCS:/c/Program\ Files/Git/cmd; export PATH'' >> ~/.bash_profile"'
    Write-Host " Done."

    Write-Host -NoNewline "Customize mintty cursor ..."
    # Making custom cursor to have a visual marker (blocky cool cyan cursor)
    Start-Process -Wait -UseNewEnvironment -FilePath $shCmd `
        -ArgumentList 'dash -c "echo \"CursorColour=0,128,255\nCursorType=block\nTerm=xterm-256color\" > ~/.minttyrc"'

    Write-Host " Done."
}

function step-update-install {
    Write-Host -NoNewline "Updating base install with potentially downgraded elements ..."
    # To update the system with some conflicts we have to do this ...
    Start-Process -Wait -UseNewEnvironment -FilePath $shCmd -ArgumentList "dash -c 'yes | pacman -Suy'"
    Write-Host " Done."
    Write-Host -NoNewline "Updating base install ..."
    Start-Process -Wait -UseNewEnvironment -FilePath $shCmd -ArgumentList 'pacman -Suy --noconfirm'
    Write-Host "Done."
}

Install-MSYS2
if ($pauseAtEnd) {
    Read-Host -Prompt ": Press enter to close "
}
