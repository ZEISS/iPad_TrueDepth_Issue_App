# iPad TrueDepth Data Recording and Depth Overlay app


## How to Use
1. In the Xcode project directory, with a `Terminal` run `pod install`.
2. Open `iPad_TrueDepth_Issue_App.xcworkspace` in Xcode.
3. If there are any issues with dependency resolution, use `pod update` in the project directory or `pod install` if any Pods are missing.

## How to Run
1. Build and run the application on the iPhone device.
2. In the main screen, 2 modes of operation is displayed, `Record` and `Depth Overlay`.
3. The main screen also provides a button `Clear Data`, to clear previously recorded app data.
### Record Mode
A dataset can be recorded by tapping on `Start` inside the `Record` mode.
The number of images and delay between images can be set.

### Depth Overlay Mode
There are buttons to switch between `AVSession` and `ARKit`.
Additional meta data read from the corresponding API is shown directly on the screen.

## How to Access the Datasets
Because apple devices have a very restricted, sandboxed environment, it is not easy to access the files and varies based on the OS being used:
(NOTE: WiFi method involves compressing the datasets into a single file. Direct transfer method, if available, is better)

### macOS

#### Method 1 - Xcode
The iPhone must be connected to the Mac through USB.
1. In Xcode, select the menu item `Windows`, select `Devices and Simulators`.
    This will show a list of applications installed on the iPhone.
2. Click on `iPad_TrueDepth_Issue_App`, and then click the gear (or settings) icon below the list of applications.
    Click `Download Container..` and select a location.
3. Once downloaded, right click on the `xcappdata` file, click `Show Package Contents`.
4. Navigate to `AppData -> Documents -> AppData`. The datasets will be stored in this location.

#### Method 2 - Finder
The iPhone must be connected to the Mac through USB.
1. Open Finder, in the sidebar open the iPhone device under `Locations` group.
2. Select the `Files` tab. Expand `iPad_TrueDepth_Issue_App` application (triangle icon).
3. The saved files will be displayed. Drag and drop the appropriate file/folder into another Finder location.

#### Method 3 - WiFi
1. There should be a common network.
2. A server is hosted on the iPhone.
    The URL of the server is shown by a label at the bottom of the application (`Server running on http://ip_address:port`)
3. Visit this URL, click on `Download the Datasets`. An archive containing all the datasets will be served.

### Windows
#### Method 1 - iTunes
The iPhone must be connected to the Windows through USB.
1. Open iTunes. Click on the iPhone icon on the top left of the window (to the right of drop down selection).
2. Click on `File Sharing`. Under `Apps`, click `iPad_TrueDepth_Issue_App`, select the file to be copied.
3. Click `Save...` below the list of files. Select the appropriate folder and save the file.

#### Method 2 - WiFi
1. There should be a common network.
    If not, you can create a `Mobile hotspot` on your Windows 10 system and connect the iPhone to this network.
2. A server is hosted on the iPhone.
    The URL of the server is shown by a label at the bottom of the application (`Server running on http://ip_address:port`)
3. Visit this URL, click on `Download the Datasets`. An archive containing all the datasets will be served.

### Linux
The WiFi method works similar to Windows [Method 2 - WiFi](#Method-2---WiFi), provided that there's a common network or the machine supports hotspot creation.

## Metadata Onformation
Some metadata information is captured from the iPhone device and stored with each dataset:
- DepthMetadata.json and CameraMetadata.json files contain information relating to the depth and rgb camera, respectively. The files contain JSON arrays of metadata, where each data element was recorded when the respective depth-rgb image was captured.

## Tools
1. There are some instructions to help running macOS as a VM in Windows (& probably Linux).
1. Building IPA from the existing Xcode workspace.
1. Instructions for using `AltServer` to install IPAs using Windows.

## Issues
1. WiFi needs to be enabled for using the web server in iPhone.
1. WiFi method for transferring dataset can cause the app to crash if the total size of the datasets exceeds ~50-70% of the device's RAM.

# Contributing
To contribute you must sign the **ZEISS CLA** depending if your are acting as an [individual](zeiss_indv_cla.txt) or represent a [company](zeiss_corp_cla.txt).
