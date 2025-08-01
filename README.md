# Zebra Technologies Android Imaging Tool for Windows
A GUI application for Windows written in PowerShell to automate the configuration process of Zebra Technologies RF units.

## Supported Models
 - Zebra ET60
 - Zebra MC33
 - Zebra MC3300x
 - Zebra TC8300

Aside: Support for the Zebra TC8000 model was removed from a previous version of this application as the version of Android running on those devices is at EOL.

## Setup Prerequisites
 - Windows computer
 - Per-Model folder structure (referenced below)
 - ADB Tools - download them here
 - Zebra docking station

## Setup
### 1. Download the latest release
The download for the latest release can be found here.
### 2. Specify folder locations
On first launch, you will be prompted to identify the locations of four specific folders. For each Zebra model, feel free to only fill out those that apply.\
The "platform-tools" folder location, however, is required in order for the application to function. This is the folder containing ADB.exe.\
When you are specifying folder locations, you are specifying where the folders themselves are stored. Be sure not to point to a location within the folder.\
--- To remove folder associations, or to re-locate folders, edit or remove C:\Users\<yourusername>\AppData\Roaming\AndroidImagingTool\folderpaths.json ---
### 3. Create the folder structure
### 4. Migrate your files

## Usage
### 1. Reset your device
It is recommended to perform a factory reset of your device prior to reconfigurtion using Android Imaging Tool. This can be done by creating a StageNow barcode using the software found here and scanning it within the StageNow application found on the device.
If this step is skipped, there may be unintended effects on the completion of your image (like steps that are already completed being labeled as having "Failed" within the log).
### 2. Turn on your device and enable USB Debugging
### 3. Seat your device onto a docking station and plug into PC
### 4. Run the Android Imaging Tool
Allow fingerprint on device
### 5. Configure device
Ensure serial number and detected model are correct.
Toggle the License Server box on if you know you are using an Ivanti License Server for distribution of your Velocity Licenses.
Choose the device's Velocity Config file from the drop-down box.
### 6. Image device
Click the "Image" button. Monitor the status box for image completion.
If the image has failed, view the log file located here: C:\Users\<yourusername>\AppData\Roaming\AndroidImagingTool\
### 7. Post-Image
Once the image has completed, you may connect another device and re-scan for devices or exit the application.

