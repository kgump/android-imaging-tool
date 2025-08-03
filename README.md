# Zebra Technologies Android Configuration Tool for Windows
A GUI application for Windows written in PowerShell to automate the configuration process of Zebra Technologies RF units.\
\
This application leverages use of the adb command line tool to configure Android, push files, set file permissions, side load APKs, and includes log output in AppData for error management.\
\
<img width="506" height="307" alt="image" src="https://github.com/user-attachments/assets/0e66c9e7-9075-4df5-9a96-b90025ce1fa9" />

## Supported Models
 - Zebra ET60
 - Zebra MC33
 - Zebra MC3300x
 - Zebra TC8300

Aside: Support for the Zebra TC8000 model was removed from a previous version of this application as the version of Android running on those devices is at EOL.

## Setup Prerequisites
 - Windows computer
 - Per-Model folder structure ([referenced below](https://github.com/kgump/android-imaging-tool/tree/main?tab=readme-ov-file#3-create-the-folder-structure))
 - ADB Tools - download them [here](https://developer.android.com/tools/releases/platform-tools)
 - Device-compatible docking station
 - [InsightMobile version 1.35](https://docs.proglove.com/en/install-insight-mobile.html)
 - [Enterprise Home Screen versions 5.0 & 4.0](https://www.zebra.com/us/en/support-downloads/software/mobile-computer-software/enterprise-home-screen.html?downloadId=6efb20e5-6c32-48cb-ad7e-84515b296ae0)
 - [Velocity version 2.1.8](https://www.wavelink.com/Download-Velocity_enterprise-app-modernization-Software/)

## Setup
### 1. Download the latest release
The download for the latest release can be found [here](https://github.com/kgump/android-imaging-tool/releases/tag/v1.0.1).
### 2. Specify folder locations
On first launch, you will be prompted to identify the locations of four specific folders. For each Zebra model, feel free to only fill out those that apply.
The `platform-tools` folder location, however, is required in order for the application to function. This is the folder containing ADB.exe.
When you are specifying folder locations, you are specifying where the folders themselves are stored. Be sure not to point to a location within the folder.\
\
To remove folder associations, or to re-locate folders, edit or remove this file: \
`C:\Users\<yourusername>\AppData\Roaming\AndroidImagingTool\folderpaths.json`
### 3. Create the folder structure
For each device model, there must be an associated folder containing the following: A folder named "Config Files", and a folder named "RADIO IDs" with a "License Server" subfolder nested within it.\
\
Here is a visual representation of the folder structure hierarchy, each representing a folder:\
\
<img width="193" height="197" alt="image" src="https://github.com/user-attachments/assets/fdf29067-5bf9-41ac-8a67-63ce3b3dc5b7" />
### 4. Migrate your files
Now that the folders are created, you must populate them with the necessary files. The "RADIO IDs" & "License Server" folders must contain your Velocity config .wldep files, depending on whether you use a Velocity License Server or not.
These files are created using the [Velocity Console](https://www.wavelink.com/Download-Velocity_enterprise-app-modernization-Software/) tool, and contain the configuration read by Velocity on application start-up.\
\
The "Config Files" folder must contain a model-specific:
 - EHS(Enterprise Home Screen) XML file titled "enterprisehomescreen.xml"
 - DataWedge database file titled "dwprofile_Velocity.db" (if applicable)
 - Proglove file titled "ProGlove.proconfig" for InsightMobile application (if applicable)
 - Any of the following APKs:
     - `InsightMobile_release_1.35.0_12769_091224_0945.apk`
     - `EHS_050040.apk` (for ET60 & TC8300)
     - `Velocity_Android_ARM_2.1.8.apk`
     - `EHS_040005.apk` (for MC33 & MC3300x)

The above files assume (with the ET60 devices) that you are using a ProGlove solution. If you are using a different scanner solution, you will have to change this within the source code.

## Usage
### 1. Reset your device
It is recommended to perform a factory reset of your device prior to re-configuration using Android Imaging Tool. This can be done by creating a StageNow barcode using the software found [here](https://www.zebra.com/us/en/support-downloads/software/mobile-computer-software/stagenow.html?downloadId=85083242-9046-4c7e-8dd7-7cb2d23cd168) and scanning it within the StageNow application found on the device.
If this step is skipped, there may be unintended effects on the completion of your image (like steps that are already completed being labeled as having "Failed" within the log).
### 2. Turn on your device and enable USB Debugging
On the Android device, go to `Settings`**>**`About Phone`**>**`Software Information`**>**`Tap "Build Number" seven times`.\
After this, go to `Settings`**>**`Developer Options` and turn on `USB Debugging`.
### 3. Connect your device to a docking station and plug it into a Windows PC
### 4. Run the Android Imaging Tool and allow computer fingerprint
After you run the Android Imaging Tool, you will see a pop up window on your Android device asking you to allow the computer's fingerprint. Select the box that states "Always allow from this computer" and tap "OK".\
\
In the event your device does not show up but is physically connected, click "Scan for Devices".
### 5. Configure device
Ensure serial number and detected model are correct.
Toggle the License Server box on if you know you are using an Ivanti License Server for distribution of your Velocity Licenses.
Choose the device's Velocity Config file from the drop-down box.\
\
The typical setup for Zebra units has one associated configuration file per device, with a unique answer-back specified. Your setup may differ.
### 6. Image device
Click the "Image" button. Monitor the status box for image completion.
If the image has failed, view the log file located here: \
`C:\Users\<yourusername>\AppData\Roaming\AndroidImagingTool\`
### 7. Post-Image
Once the image has completed, you may connect another device and re-scan for devices or exit the application.

