Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms

# Define the XAML UI layout
$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Zebra Configuration Tool" Height="300" Width="500"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Topmost="True"
        WindowStyle="SingleBorderWindow">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <StackPanel Orientation="Vertical" Grid.Row="0">
            <TextBlock Text="Connected Device Serial:" Margin="0,0,0,5"/>
            <TextBox Name="SerialBox" IsReadOnly="True" Height="25"/>
        </StackPanel>

        <StackPanel Orientation="Vertical" Grid.Row="1" Margin="0,10,0,0">
            <TextBlock Text="Select Velocity Config File (.wldep):" Margin="0,0,0,5"/>
            <DockPanel LastChildFill="True">
            <ComboBox Name="RadioCombo" Height="25" Width="325" DockPanel.Dock="Left"/>
            <CheckBox Name="FilterCheck" Content="Use License Server" Margin="10,0,0,0" VerticalAlignment="Center"/>
            </DockPanel>
        </StackPanel>

        <StackPanel Orientation="Horizontal" Grid.Row="2" Margin="0,20,0,0" HorizontalAlignment="Center">
            <Button Name="ProceedButton" Content="Image" Width="100" Margin="5"/>
            <Button Name="RestartButton" Content="Scan for Devices" Width="100" Margin="5"/>
            <Button Name="ExitButton" Content="Exit" Width="100" Margin="5"/>
        </StackPanel>

        <TextBox Name="StatusText"
            Grid.Row="3"
            Margin="0,10,0,0"
            Foreground="Black"
            Background="Transparent"
            BorderThickness="0"
            IsReadOnly="True"
            TextWrapping="Wrap"
            AcceptsReturn="True"
            VerticalScrollBarVisibility="Auto"/>
    </Grid>
</Window>
"@

# Load the XAML using XMLDocument method to avoid rendering artifacts
[xml]$xmlReader = $XAML
$reader = (New-Object System.Xml.XmlNodeReader $xmlReader.DocumentElement)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get WPF controls
$serialBox   = $window.FindName("SerialBox")
$radioCombo  = $window.FindName("RadioCombo")
$statusText  = $window.FindName("StatusText")
$proceedBtn  = $window.FindName("ProceedButton")
$restartBtn  = $window.FindName("RestartButton")
$exitBtn     = $window.FindName("ExitButton")
$filterCheck = $window.FindName("FilterCheck")

# Define settings file path
$settingsFile = "$env:APPDATA\ZebraConfigurationTool\folderpaths.json"
$settingsDir  = Split-Path $settingsFile

# Load saved paths or use defaults
if (Test-Path $settingsFile) {
    $loadedPaths = Get-Content $settingsFile | ConvertFrom-Json
    $RequiredPaths = @{}
    $loadedPaths.PSObject.Properties | ForEach-Object {
        $RequiredPaths[$_.Name] = $_.Value
    }
} else {
    $RequiredPaths = @{
        "TC8300 Folder"             = "Choose a path"
        "ET60 Folder"               = "Choose a path"
        "MC33/3300x Folder"         = "Choose a path"
        "platform-tools Folder"     = "Choose a path"
    }
}

function Show-MissingPathDialog {
    param([hashtable]$missingPaths)

    $xamlInput = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Zebra Configuration Tool" Height="330" Width="500"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Topmost="True">
    <ScrollViewer VerticalScrollBarVisibility="Auto">
    <StackPanel Margin="10">
        <TextBlock Text="Cannot locate folders listed below. Please input folder path(s):" Margin="0,0,0,10"/>
"@

    foreach ($key in $missingPaths.Keys) {
        $sanitizedKey = $key -replace '[^a-zA-Z0-9]', ''
        $xamlInput += @"
        <StackPanel Orientation="Horizontal" Margin="0,5,0,5">
            <StackPanel Width="350">
                <TextBlock Text="$key" />
                <TextBox Name="${sanitizedKey}Box" Width="340" Text="$($missingPaths[$key])" />
            </StackPanel>
            <Button Name="${sanitizedKey}Browse" Content="Browse" Width="75" Margin="5,20,0,0" />
        </StackPanel>
"@
    }

    $xamlInput += @"
        <Button Name="OkButton" Content="Confirm" Width="100" HorizontalAlignment="Center" Margin="10"/>
    </StackPanel>
    </ScrollViewer>
</Window>
"@

    [xml]$inputXml = $xamlInput
    $reader = (New-Object System.Xml.XmlNodeReader $inputXml.DocumentElement)
    $inputWindow = [Windows.Markup.XamlReader]::Load($reader)

    $textBoxes = @{}
    
    # Inside the loop
    foreach ($key in $missingPaths.Keys) {
        $sanitizedKey = $key -replace '[^a-zA-Z0-9]', ''
        if (-not $sanitizedKey) {
            throw "Key '$key' sanitized to empty string. Invalid control name."
        }
    
        $textBox = $inputWindow.FindName("${sanitizedKey}Box")
        $browseButton = $inputWindow.FindName("${sanitizedKey}Browse")
        $textBoxes[$key] = $textBox
    
        # Capture current values in closure
        $browseButton.Add_Click({
            $label = $key
            $tb = $textBox
    
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Choose location for '$label'"
    
            # Optional: set initial path from textbox
            if ($tb.Text -and (Test-Path $tb.Text)) {
                $dialog.SelectedPath = $tb.Text
            }
    
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $tb.Text = $dialog.SelectedPath
            }
        }.GetNewClosure())

        # Find OK button and add click handler
        $okButton = $inputWindow.FindName("OkButton")
        $okButton.Add_Click({
        $inputWindow.DialogResult = $true
        })
    }    

    $null = $inputWindow.ShowDialog()

    # Update RequiredPaths with user-entered values and save to JSON
    foreach ($key in $textBoxes.Keys) {
        $RequiredPaths[$key] = $textBoxes[$key].Text
}

    # Ensure folder exists and save updated settings
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

$RequiredPaths | ConvertTo-Json -Depth 3 | Set-Content -Path $settingsFile -Encoding UTF8

}

# Detect missing folders
$missingPaths = @{}
foreach ($key in $RequiredPaths.Keys) {
    if (-not (Test-Path $RequiredPaths[$key])) {
        $missingPaths[$key] = $RequiredPaths[$key]
    }
}

# Prompt user if necessary
if ($missingPaths.Count -gt 0) {
    Show-MissingPathDialog -missingPaths $missingPaths
}

# Use updated paths
$tc8300Path     = $RequiredPaths["TC8300 Folder"]
$et60Path       = $RequiredPaths["ET60 Folder"]
$mc3300xPath    = $RequiredPaths["MC33/3300x Folder"]
$adbFolder      = $RequiredPaths["platform-tools Folder"]

# Main Folder Paths
$configTCPath     = "$tc8300Path\Config Files\"
$config60Path     = "$et60Path\Config Files\"
$config33Path     = "$mc3300xPath\Config Files\"
$radioTCPath      = "$tc8300Path\RADIO IDs\"
$radioTCLCPath    = "$tc8300Path\RADIO IDs\License Server\"
$radio60Path      = "$et60Path\RADIO IDs\"
$radio60LCPath    = "$et60Path\RADIO IDs\License Server\"
$radio3300xPath   = "$mc3300xPath\RADIO IDs\"
$radio3300xLCPath = "$mc3300xPath\RADIO IDs\License Server\"
# TC8300 Paths
$ehsTCPath        = "$configTCPath\enterprisehomescreen.xml"
# MC33 Paths
$ehs3300xPath     = "$config33Path\enterprisehomescreen.xml"
$dw3300xPath      = "$config33Path\dwprofile_Velocity.db"
# ET60 Paths
$ehs60Path        = "$config60Path\enterprisehomescreen.xml"
$proPath          = "$config60Path\ProGlove.proconfig"
# App Paths
$IMapk            = "$config60Path\InsightMobile_release_1.35.0_12769_091224_0945.apk"
$EHS5apk          = "$config60Path\EHS_050040.apk"
$VCapk            = "$config60Path\Velocity_Zebra_ARM_2.1.8.apk"
$EHS4apk          = "$config33Path\EHS_040005.apk"

function Set-RadioFiles {
    param (
        [string]$deviceModel,
        [System.Windows.Controls.ComboBox]$comboBox,
        [System.Windows.Controls.TextBox]$statusBox
    )

    $comboBox.Items.Clear()

    # Determine path based on checkbox
    $useLicensePath = $filterCheck.IsChecked -eq $true

    try {
        switch ($deviceModel) {
            "ET60" {
                $path = if ($useLicensePath) { $radio60LCPath } else { $radio60Path }
                $wldepFiles = Get-ChildItem -Path $path -Filter *.wldep -ErrorAction Stop
            }
            "MC3300x" {
                $path = if ($useLicensePath) { $radio3300xLCPath } else { $radio3300xPath }
                $wldepFiles = Get-ChildItem -Path $path -Filter *.wldep -ErrorAction Stop
            }
            "MC33" {
                $path = if ($useLicensePath) { $radio3300xLCPath } else { $radio3300xPath }
                $wldepFiles = Get-ChildItem -Path $path -Filter *.wldep -ErrorAction Stop
            }
            "TC8300" {
                $path = if ($useLicensePath) { $radioTCLCPath } else { $radioTCPath }
                $wldepFiles = Get-ChildItem -Path $path -Filter *.wldep -ErrorAction Stop
            }
            default {
                $statusBox.Text = "Please plug in a compatible device."
                return
            }
        }

        foreach ($file in $wldepFiles) {
            [void]$comboBox.Items.Add($file.BaseName)
        }

        if ($comboBox.Items.Count -gt 0) {
            $comboBox.SelectedIndex = -1
        } else {
            $statusBox.Text = "No Velocity Config files found for $deviceModel."
        }
    } catch {
        $statusBox.Text = "Could not access Velocity Config files for $deviceModel."
    }
}

function Find-Adb {
    $explicitPath = "$env:USERPROFILE\Zebra Configuration Tool\platform-tools-latest-windows\platform-tools\adb.exe"

        if (Test-Path $explicitPath) {
            return $explicitPath
        }

}

$adbPath = Find-Adb
if (-not $adbPath) {
    new-item -ItemType Directory "$env:USERPROFILE\Zebra Configuration Tool\platform-tools-latest-windows\platform-tools" -Force
    copy-item "$adbFolder\*" "$env:USERPROFILE\Zebra Configuration Tool\platform-tools-latest-windows\platform-tools" -Recurse
    $adbPath = "$env:USERPROFILE\Zebra Configuration Tool\platform-tools-latest-windows\platform-tools\adb.exe"
}

# Get connected device serial
function Get-Serial {
    try {
        & $adbPath start-server | Out-Null
        Start-Sleep -Milliseconds 500
        $adbOutput = & $adbPath devices
        $deviceLine = $adbOutput | Where-Object { $_ -match "^\S+\s+device$" }
        $serial = if ($deviceLine) { ($deviceLine -replace "\s+device", "").Trim() } else { "" }

        return @{
            Serial = $serial
            Output = $adbOutput -join "`n"
        }
    } catch {
        return @{
            Serial = ""
            Output = "Error: ADB not found or failed to run"
        }
    }
}

# Display device product name
function deviceModel {
    & $adbPath start-server *> $null
    $ModelRaw = & $adbPath shell "getprop ro.product.model" 2>$null
    $Model = if ($ModelRaw) { $ModelRaw.Trim() } else { "Unknown Model" }

    return @{ Model = $Model }
}

# Display device manufacturer
function deviceManu {
    & $adbPath start-server *> $null
    $ManuRaw = & $adbPath shell "getprop ro.product.manufacturer" 2>$null
    $Manu = if ($ManuRaw) { $ManuRaw.Trim() } else { "Unknown Manufacturer" }

    return @{ Manu = $Manu }
}

# Filter Check
$filterCheck.Add_Checked({
    $currentModel = deviceModel
    if ($serialBox.Text) {
        Set-RadioFiles -deviceModel $currentModel.Model -comboBox $radioCombo -statusBox $statusText
    } else {
        $statusText.Text = "Please plug in a compatible device."
    }
})

$filterCheck.Add_Unchecked({
    $currentModel = deviceModel
    if ($serialBox.Text) {
        Set-RadioFiles -deviceModel $currentModel.Model -comboBox $radioCombo -statusBox $statusText
    } else {
        $statusText.Text = "Please plug in a compatible device."
    }
})

$window.Add_Loaded({
    Start-Sleep -Milliseconds 100  # Give UI time to display

    # Single call to ADB-related functions
    $serialInfo = Get-Serial
    $model      = deviceModel
    $manu       = deviceManu

    $serialBox.Text = $serialInfo["Serial"]

    if (-not $serialInfo["Serial"]) {
        $statusText.Text = "No device detected."
    } else {
        $statusText.Text = "Device detected: $($manu.Manu) $($model.Model)"
        Set-RadioFiles -deviceModel $model.Model -comboBox $radioCombo -statusBox $statusText
    }
})

# Button event: Restart Scan
$restartBtn.Add_Click({
    $model = deviceModel
    $manu  = deviceManu
    $statusText.Text = "Scanning..."
    $window.Dispatcher.Invoke([Action]{}, 'Render')
    Start-Sleep -Milliseconds 500

    $result = Get-Serial
    $serialBox.Text = $result.Serial

    if (-not $result.Serial) {
        $statusText.Text = "No device detected."
    } else {
        $statusText.Text = "Device detected: $($manu.Manu) $($model.Model)"
        Set-RadioFiles -deviceModel $model.Model -comboBox $radioCombo -statusBox $statusText
    }
})

# Button event: Exit
$exitBtn.Add_Click({
    try {
        & $adbPath kill-server
    } catch {}
    $window.Close()
})

# Button event: Proceed
$proceedBtn.Add_Click({
    $result = Get-Serial
    $serialBox.Text = $result.Serial

    if (-not $result.Serial) {
        $statusText.Text = "No device detected."
        return
    }

    $selectedRadio = $radioCombo.SelectedItem
    if (-not $selectedRadio) {
        $statusText.Text = "Please select a configuration file."
        return
    }

    $model = deviceModel
    $logFile = Join-Path $env:USERPROFILE "AppData\Roaming\ZebraConfigurationTool\image_log.txt"
    if (-not (Test-Path $logFile)) {
        New-Item -ItemType File -Path $logFile
    }

    # Clear the log file at the beginning
    Clear-Content $logFile

#### - ET60 / Zebra 13
    if ($model.Model -eq "ET60") {
        $basePath = if ($filterCheck.IsChecked -eq $true) { $radio60LCPath } else { $radio60Path }
        $radioFile = Join-Path $basePath "$selectedRadio.wldep"
        $statusText.Text = "Starting image..."
        $window.Dispatcher.Invoke([Action]{}, 'Render')  # Force immediate UI refresh

        # === Begin Runspace Setup ===
        $syncHash = [hashtable]::Synchronized(@{})
        $syncHash.StatusBox = $statusText
        $syncHash.LogFile = $logFile
        $syncHash.Result = $true

        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions = "ReuseThread"
        $runspace.Open()

        $psCmd = [powershell]::Create()
        $psCmd.Runspace = $runspace

        $scriptBlock = { # Image Logic
            param($syncHash, $adbPath, $radioFile, $ehs60Path, $proPath, $IMapk, $EHS5apk, $VCapk)
            
            function Write-Status($msg) {
                $syncHash.StatusBox.Dispatcher.Invoke([Action]{
                    $syncHash.StatusBox.AppendText("$msg`n")
                    $syncHash.StatusBox.ScrollToEnd()
                })
                Add-Content -Path $syncHash.LogFile -Value "$msg"
                Start-Sleep -Seconds 1
            }

            function Get-Success($commandScriptBlock, $successMsg, $failureMsg, [bool]$failGracefully = $false) {
                try {
                    & $commandScriptBlock 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                        Add-Content -Path $syncHash.LogFile -Value "$successMsg"
                    } else {
                        throw "Non-Zero exit code."
                    }
                } catch {
                        Add-Content -Path $syncHash.LogFile -Value "$failureMsg"
                        if (-not $failGracefully) {
                        $syncHash.Result = $false
                        return $false
                    }
                }
            }

            Write-Status "`nBeginning ADB process..."
            Get-Success { & $adbPath kill-server } "Cleaning ADB." "Failed to kill ADB server" | Out-Null
            Get-Success { & $adbPath start-server } "ADB process started." "Failed to start ADB server" | Out-Null
            Start-Sleep -Seconds 2

            Write-Status "Configuring EHS..."
            Get-Success { & $adbPath push $ehs60Path "/storage/emulated/0/Download" } "EHS configuration file pushed." "Failed to push EHS" | Out-Null
            Get-Success { & $adbPath shell "mv /storage/emulated/0/Download/enterprisehomescreen.xml /enterprise/usr" } "EHS file moved." "Failed to move EHS file" | Out-Null
            Start-Sleep -Seconds 2
            Get-Success { & $adbPath shell "chmod 777 /enterprise/usr/enterprisehomescreen.xml" } "EHS permissions set." "Failed to set EHS permissions" | Out-Null

            Write-Status "Configuring Zebra settings..."
            Get-Success { & $adbPath shell "settings put system font_scale 1.15" } "Font scale configured." "Failed to set font scale" | Out-Null
            Get-Success { & $adbPath shell "wm density 280" } "Screen density configured." "Failed to set screen density" | Out-Null
            Get-Success { & $adbPath shell "wm size 1920x1200" } "Screen size configured." "Failed to set screen size" | Out-Null
            Get-Success { & $adbPath shell "settings put system screen_off_timeout 1800000" } "Screen timeout configured." "Failed to set screen timeout" | Out-Null
            Get-Success { & $adbPath shell "cmd bluetooth_manager enable" } "Bluetooth enabled." "Failed to enable Bluetooth" | Out-Null

            Write-Status "Configuring Velocity..."
            Get-Success { & $adbPath shell "mkdir /storage/emulated/0/com.wavelink.velocity" } "Velocity folder created." "Failed to create Velocity folder" | Out-Null
            Get-Success { & $adbPath push $radioFile "/storage/emulated/0/com.wavelink.velocity" } "Velocity RADIO file pushed." "Failed to push Velocity file" | Out-Null

            Write-Status "Configuring Insight Mobile..."
            Get-Success { & $adbPath shell "mkdir -p /storage/emulated/0/Zebra/data/de.proglove.connect/files" } "Insight Mobile folder created." "Failed to create IM folder" | Out-Null
            Get-Success { & $adbPath push $proPath "/storage/emulated/0/Zebra/data/de.proglove.connect/files" } "Insight Mobile configuration file pushed." "Failed to push IM file" | Out-Null

            Write-Status "Installing applications..."
            Get-Success { & $adbPath install $IMapk } "Insight Mobile installed." "Failed to install Insight Mobile" | Out-Null
            Get-Success { & $adbPath install $EHS5apk } "EHS installed." "Failed to install EHS" | Out-Null
            Get-Success { & $adbPath install $VCapk } "Velocity installed." "Failed to install Velocity" | Out-Null

            Write-Status "Setting home application..."
            Get-Success { & $adbPath shell "pm set-home-activity 'com.zebra.mdna.enterprisehomescreen'" } "Home app set." "Failed to set home app" | Out-Null
            Get-Success { & $adbPath shell "am start -n com.zebra.mdna.enterprisehomescreen/.HomeScreenActivity" } "EHS launched." "Failed to launch home app" | Out-Null

            Write-Status "Finalizing..."
            Get-Success { & $adbPath shell "exit" } "Exiting." "Exiting." $true | Out-Null
            Get-Success { & $adbPath kill-server } "ADB process exited cleanly." "Failed to kill ADB server" | Out-Null

            if ($syncHash.Result) {
                Write-Status "Image completed successfully."
            } else {
                Write-Status "Image failed. Please check log file located here:`n$env:APPDATA\ZebraConfigurationTool\"
            }
        }

        $psCmd.AddScript($scriptBlock).
        AddArgument($syncHash).
        AddArgument($adbPath).
        AddArgument($radioFile).
        AddArgument($ehs60Path).
        AddArgument($proPath).
        AddArgument($IMapk).
        AddArgument($EHS5apk).
        AddArgument($VCapk)

        $psCmd.BeginInvoke()
        }

#### - MC3300x / Zebra 11
    if ($model.Model -eq "MC3300x") {
        $basePath = if ($filterCheck.IsChecked -eq $true) { $radio3300xLCPath } else { $radio3300xPath }
        $radioFile = Join-Path $basePath "$selectedRadio.wldep"
        $statusText.Text = "Starting image..."
        $window.Dispatcher.Invoke([Action]{}, 'Render')  # Force immediate UI refresh

        # === Begin Runspace Setup ===
        $syncHash = [hashtable]::Synchronized(@{})
        $syncHash.StatusBox = $statusText
        $syncHash.LogFile = $logFile
        $syncHash.Result = $true

        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions = "ReuseThread"
        $runspace.Open()

        $psCmd = [powershell]::Create()
        $psCmd.Runspace = $runspace

        $scriptBlock = { # Image Logic
            param($syncHash, $adbPath, $radioFile, $dw3300xPath, $ehs3300xPath, $EHS4apk, $VCapk)
            
            function Write-Status($msg) {
                $syncHash.StatusBox.Dispatcher.Invoke([Action]{
                    $syncHash.StatusBox.AppendText("$msg`n")
                    $syncHash.StatusBox.ScrollToEnd()
                })
                Add-Content -Path $syncHash.LogFile -Value "$msg"
                Start-Sleep -Seconds 1
            }

            function Get-Success($commandScriptBlock, $successMsg, $failureMsg, [bool]$failGracefully = $false) {
                try {
                    & $commandScriptBlock 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                        Add-Content -Path $syncHash.LogFile -Value "$successMsg"
                    } else {
                        throw "Non-Zero exit code."
                    }
                } catch {
                        Add-Content -Path $syncHash.LogFile -Value "$failureMsg"
                        if (-not $failGracefully) {
                        $syncHash.Result = $false
                        return $false
                    }
                }
            }

            Write-Status "`nBeginning ADB process..."
            Get-Success { & $adbPath kill-server } "Cleaning ADB." "Failed to kill ADB server" | Out-Null
            Get-Success { & $adbPath start-server } "ADB process started." "Failed to start ADB server" | Out-Null
            Start-Sleep -Seconds 2

            Write-Status "Configuring EHS..."
            Get-Success { & $adbPath push $ehs3300xPath "/storage/emulated/0/Download" } "EHS configuration file pushed." "Failed to push EHS" | Out-Null
            Get-Success { & $adbPath shell "mv /storage/emulated/0/Download/enterprisehomescreen.xml /enterprise/usr" } "EHS file moved." "Failed to move EHS file" | Out-Null
            Start-Sleep -Seconds 2
            Get-Success { & $adbPath shell "chmod 777 /enterprise/usr/enterprisehomescreen.xml" } "EHS permissions set." "Failed to set EHS permissions" | Out-Null

            Write-Status "Configuring Zebra settings..."
            Get-Success { & $adbPath shell "settings put system screen_off_timeout 1800000" } "Screen timeout configured." "Failed to set screen timeout" | Out-Null
            Get-Success { & $adbPath shell "settings put system accelerometer_rotation 0" } "Screen rotation configured." "Failed to disable screen rotation" | Out-Null

            Write-Status "Configuring Velocity..."
            Get-Success { & $adbPath shell "mkdir /storage/emulated/0/Zebra/data/com.wavelink.velocity" } "Velocity folder created." "Failed to create Velocity folder" | Out-Null
            Get-Success { & $adbPath shell "mkdir /storage/emulated/0/Zebra/data/com.wavelink.velocity/files" } "Velocity subfolder created." "Failed to create Velocity subfolder" | Out-Null
            Get-Success { & $adbPath push $radioFile "/storage/emulated/0/Zebra/data/com.wavelink.velocity/files" } "Velocity RADIO file pushed." "Failed to push Velocity file" | Out-Null

            Write-Status "Importing DataWedge profile..."
            Get-Success { & $adbPath push $dw3300xPath "/storage/emulated/0/Download" } "DataWedge profile pushed." "Failed to push DataWedge profile" | Out-Null
            Get-Success { & $adbPath shell "mv /storage/emulated/0/Download/dwprofile_Velocity.db /enterprise/device/settings/datawedge/autoimport" } "DataWedge file moved." "Failed to move DataWedge file" | Out-Null
            Start-Sleep -Seconds 2
            Get-Success { & $adbPath shell "chmod 777 /enterprise/device/settings/datawedge/autoimport/dwprofile_Velocity.db" } "DataWedge permissions set." "Failed to set DataWedge permissions" | Out-Null

            Write-Status "Installing applications..."
            Get-Success { & $adbPath install $EHS4apk } "EHS installed." "Failed to install EHS" | Out-Null
            Get-Success { & $adbPath install $VCapk } "Velocity installed." "Failed to install Velocity" $true | Out-Null

            Write-Status "Setting home application..."
            Get-Success { & $adbPath shell "pm set-home-activity 'com.symbol.enterprisehomescreen'" } "Home app set." "Failed to set home app" | Out-Null
            Get-Success { & $adbPath shell "am start -n com.symbol.enterprisehomescreen/.HomeScreenActivity" } "EHS launched." "Failed to launch home app" | Out-Null

            Write-Status "Finalizing..."
            Get-Success { & $adbPath shell "exit" } "Exiting." "Exiting." $true | Out-Null
            Get-Success { & $adbPath kill-server } "ADB process exited cleanly." "Failed to kill ADB server" | Out-Null

            if ($syncHash.Result) {
                Write-Status "Image completed successfully."
            } else {
                Write-Status "Image failed. Please check log file located here:`n$env:APPDATA\ZebraConfigurationTool\"
            }
        }

        $psCmd.AddScript($scriptBlock).
        AddArgument($syncHash).
        AddArgument($adbPath).
        AddArgument($radioFile).
        AddArgument($dw3300xPath).
        AddArgument($ehs3300xPath).
        AddArgument($EHS4apk).
        AddArgument($VCapk)

        $psCmd.BeginInvoke()

        }

#### - MC33 / Zebra 8.1
    if ($model.Model -eq "MC33") {
        $basePath = if ($filterCheck.IsChecked -eq $true) { $radio3300xLCPath } else { $radio3300xPath }
        $radioFile = Join-Path $basePath "$selectedRadio.wldep"
        $statusText.Text = "Starting image..."
        $window.Dispatcher.Invoke([Action]{}, 'Render')  # Force immediate UI refresh

        # === Begin Runspace Setup ===
        $syncHash = [hashtable]::Synchronized(@{})
        $syncHash.StatusBox = $statusText
        $syncHash.LogFile = $logFile
        $syncHash.Result = $true

        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions = "ReuseThread"
        $runspace.Open()

        $psCmd = [powershell]::Create()
        $psCmd.Runspace = $runspace

        $scriptBlock = { # Image Logic
            param($syncHash, $adbPath, $radioFile, $dw3300xPath, $ehs3300xPath, $EHS4apk, $VCapk)
            
            function Write-Status($msg) {
                $syncHash.StatusBox.Dispatcher.Invoke([Action]{
                    $syncHash.StatusBox.AppendText("$msg`n")
                    $syncHash.StatusBox.ScrollToEnd()
                })
                Add-Content -Path $syncHash.LogFile -Value "$msg"
                Start-Sleep -Seconds 1
            }

            function Get-Success($commandScriptBlock, $successMsg, $failureMsg, [bool]$failGracefully = $false) {
                try {
                    & $commandScriptBlock 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                        Add-Content -Path $syncHash.LogFile -Value "$successMsg"
                    } else {
                        throw "Non-Zero exit code."
                    }
                } catch {
                        Add-Content -Path $syncHash.LogFile -Value "$failureMsg"
                        if (-not $failGracefully) {
                        $syncHash.Result = $false
                        return $false
                    }
                }
            }

            Write-Status "`nBeginning ADB process..."
            Get-Success { & $adbPath kill-server } "Cleaning ADB." "Failed to kill ADB server" | Out-Null
            Get-Success { & $adbPath start-server } "ADB process started." "Failed to start ADB server" | Out-Null
            Start-Sleep -Seconds 2

            Write-Status "Configuring EHS..."
            Get-Success { & $adbPath push $ehs3300xPath "/storage/emulated/0/Download" } "EHS configuration file pushed." "Failed to push EHS" | Out-Null
            Get-Success { & $adbPath shell "mv /storage/emulated/0/Download/enterprisehomescreen.xml /enterprise/usr" } "EHS file moved." "Failed to move EHS file" | Out-Null
            Start-Sleep -Seconds 2
            Get-Success { & $adbPath shell "chmod 777 /enterprise/usr/enterprisehomescreen.xml" } "EHS permissions set." "Failed to set EHS permissions" | Out-Null

            Write-Status "Configuring Zebra settings..."
            Get-Success { & $adbPath shell "settings put system screen_off_timeout 1800000" } "Screen timeout configured." "Failed to set screen timeout" | Out-Null
            Get-Success { & $adbPath shell "settings put system accelerometer_rotation 0" } "Screen rotation configured." "Failed to disable screen rotation" | Out-Null

            Write-Status "Configuring Velocity..."
            Get-Success { & $adbPath shell "mkdir /storage/emulated/0/com.wavelink.velocity" } "Velocity folder created." "Failed to create Velocity folder" | Out-Null
            Get-Success { & $adbPath push $radioFile "/storage/emulated/0/com.wavelink.velocity" } "Velocity RADIO file pushed." "Failed to push Velocity file" | Out-Null

            Write-Status "Importing DataWedge profile..."
            Get-Success { & $adbPath push $dw3300xPath "/storage/emulated/0/Download" } "DataWedge profile pushed." "Failed to push DataWedge profile" | Out-Null
            Get-Success { & $adbPath shell "mv /storage/emulated/0/Download/dwprofile_Velocity.db /enterprise/device/settings/datawedge/autoimport" } "DataWedge file moved." "Failed to move DataWedge file" | Out-Null
            Start-Sleep -Seconds 2
            Get-Success { & $adbPath shell "chmod 777 /enterprise/device/settings/datawedge/autoimport/dwprofile_Velocity.db" } "DataWedge permissions set." "Failed to set DataWedge permissions" | Out-Null

            Write-Status "Installing applications..."
            Get-Success { & $adbPath install $EHS4apk } "EHS installed." "Failed to install EHS" | Out-Null
            Get-Success { & $adbPath install $VCapk } "Velocity installed." "Failed to install Velocity" $true | Out-Null

            Write-Status "Setting home application..."
            Get-Success { & $adbPath shell "am start -a Zebra.intent.action.MAIN -n com.symbol.enterprisehomescreen/.HomeScreenActivity" } "Home app set." "Failed to set home app" | Out-Null
            Get-Success { & $adbPath shell "cmd package set-home-activity com.symbol.enterprisehomescreen/.HomeScreenActivity" } "EHS launched." "Failed to launch home app" | Out-Null

            Write-Status "Finalizing..."
            Get-Success { & $adbPath shell "exit" } "Exiting." "Exiting." $true | Out-Null
            Get-Success { & $adbPath kill-server } "ADB process exited cleanly." "Failed to kill ADB server" | Out-Null

            if ($syncHash.Result) {
                Write-Status "Image completed successfully."
            } else {
                Write-Status "Image failed. Please check log file located here:`n$env:APPDATA\ZebraConfigurationTool\"
            }
        }

        $psCmd.AddScript($scriptBlock).
        AddArgument($syncHash).
        AddArgument($adbPath).
        AddArgument($radioFile).
        AddArgument($dw3300xPath).
        AddArgument($ehs3300xPath).
        AddArgument($EHS4apk).
        AddArgument($VCapk)

        $psCmd.BeginInvoke()
        
        }

#### - TC8300 / Zebra 14
    if ($model.Model -eq "TC8300") {
        $basePath = if ($filterCheck.IsChecked -eq $true) { $radioTCLCPath } else { $radioTCPath }
        $radioFile = Join-Path $basePath "$selectedRadio.wldep"
        $statusText.Text = "Starting image..."
        $window.Dispatcher.Invoke([Action]{}, 'Render')  # Force immediate UI refresh

        # === Begin Runspace Setup ===
        $syncHash = [hashtable]::Synchronized(@{})
        $syncHash.StatusBox = $statusText
        $syncHash.LogFile = $logFile
        $syncHash.Result = $true

        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions = "ReuseThread"
        $runspace.Open()

        $psCmd = [powershell]::Create()
        $psCmd.Runspace = $runspace

        $scriptBlock = { # Image Logic
            param($sync, $adbPath, $radioFile, $ehsTCPath, $proPath, $EHS5apk, $VCapk)
            
            function Write-Status($msg) {
                $syncHash.StatusBox.Dispatcher.Invoke([Action]{
                    $syncHash.StatusBox.AppendText("$msg`n")
                    $syncHash.StatusBox.ScrollToEnd()
                })
                Add-Content -Path $syncHash.LogFile -Value "$msg"
                Start-Sleep -Seconds 1
            }

            function Get-Success($commandScriptBlock, $successMsg, $failureMsg, [bool]$failGracefully = $false) {
                try {
                    & $commandScriptBlock 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                        Add-Content -Path $syncHash.LogFile -Value "$successMsg"
                    } else {
                        throw "Non-Zero exit code."
                    }
                } catch {
                        Add-Content -Path $syncHash.LogFile -Value "$failureMsg"
                        if (-not $failGracefully) {
                        $syncHash.Result = $false
                        return $false
                    }
                }
            }

            Write-Status "`nBeginning ADB process..."
            Get-Success { & $adbPath kill-server } "Cleaning ADB." "Failed to kill ADB server" | Out-Null
            Get-Success { & $adbPath start-server } "ADB process started." "Failed to start ADB server" | Out-Null
            Start-Sleep -Seconds 2

            Write-Status "Configuring EHS..."
            Get-Success { & $adbPath push $ehsTCPath "/storage/emulated/0/Download" } "EHS configuration file pushed." "Failed to push EHS" | Out-Null
            Get-Success { & $adbPath shell "mv /storage/emulated/0/Download/enterprisehomescreen.xml /enterprise/usr" } "EHS file moved." "Failed to move EHS file" | Out-Null
            Start-Sleep -Seconds 2
            Get-Success { & $adbPath shell "chmod 777 /enterprise/usr/enterprisehomescreen.xml" } "EHS permissions set." "Failed to set EHS permissions" | Out-Null

            Write-Status "Configuring Zebra settings..."
            Get-Success { & $adbPath shell "settings put system screen_off_timeout 1800000" } "Screen timeout configured." "Failed to set screen timeout" | Out-Null
            Get-Success { & $adbPath shell "settings put system accelerometer_rotation 0" } "Screen rotation configured." "Failed to disable screen rotation" | Out-Null

            Write-Status "Configuring Velocity..."
            Get-Success { & $adbPath shell "mkdir /storage/emulated/0/Zebra/data/com.wavelink.velocity" } "Velocity folder created." "Failed to create Velocity folder" | Out-Null
            Get-Success { & $adbPath shell "mkdir /storage/emulated/0/Zebra/data/com.wavelink.velocity/files" } "Velocity subfolder created." "Failed to create Velocity subfolder" | Out-Null
            Get-Success { & $adbPath push $radioFile "/storage/emulated/0/Zebra/data/com.wavelink.velocity/files" } "Velocity RADIO file pushed." "Failed to push Velocity file" | Out-Null

            Write-Status "Installing applications..."
            Get-Success { & $adbPath install $EHS5apk } "EHS installed." "Failed to install EHS" | Out-Null
            Get-Success { & $adbPath install $VCapk } "Velocity installed." "Failed to install Velocity" $true | Out-Null

            Write-Status "Setting home application..."
            Get-Success { & $adbPath shell "pm set-home-activity 'com.zebra.mdna.enterprisehomescreen'" } "Home app set." "Failed to set home app" | Out-Null
            Get-Success { & $adbPath shell "am start -n com.zebra.mdna.enterprisehomescreen/.HomeScreenActivity" } "EHS launched." "Failed to launch home app" | Out-Null

            Write-Status "Finalizing..."
            Get-Success { & $adbPath shell "exit" } "Exiting." "Exiting." $true | Out-Null
            Get-Success { & $adbPath kill-server } "ADB process exited cleanly." "Failed to kill ADB server" | Out-Null

            if ($syncHash.Result) {
                Write-Status "Image completed successfully."
            } else {
                Write-Status "Image failed. Please check log file located here:`n$env:APPDATA\ZebraConfigurationTool\"
            }
        }

        $psCmd.AddScript($scriptBlock).
        AddArgument($syncHash).
        AddArgument($adbPath).
        AddArgument($radioFile).
        AddArgument($ehsTCPath).
        AddArgument($proPath).
        AddArgument($EHS5apk).
        AddArgument($VCapk)

        $psCmd.BeginInvoke()

        }
})

# Handle the 'X' button (window close) event
$window.Add_Closing({
    try {
        & $adbPath kill-server
    } catch {}
    [System.Environment]::Exit(0)
})

# Show the GUI
$null = $window.ShowDialog()