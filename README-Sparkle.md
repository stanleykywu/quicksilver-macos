# First time Sparkle installation and bundling steps
## Add Sparkle package dependency
- After opening Quicksilver project in Xcode, click "File" -> "Add package dependency"
- Paste the following url into the url searchbar in the top right corner `github.com/sparkle-project/Sparkle`
- Click "Add package", Xcode will ask you to enter your laptop password, pull from Github, and configure this package
## Update `Info.plist` params
- Add `SUFeedURL` key and set it to a string value of "placeholder" for now
    - This is the link we'll need to update once we make the appcast publicly available
- Add `SUPublicEDKey` key and set it to string value of `0YfxpOxt2FLwShS+v4lvf2h7W5I2HKaVXw5GroQSO04=`
    - This key also has a correponding private key I'll share that will need to be added to the keychain
- Add `SUEnableAutomaticChecks` key and set it to bool value `Yes`
- Add `SUAutomaticallyUpdate` key and set it to bool value `Yes`
- Add `CFBundleShortVersionString` key of type string
    - I set it to `1.0.0`
    - This should be human readable, this number will be seen by users
- Add `CFBundleVersion` key of type string
    - I set it to `100`
    - This is a monotonically increasing number used only by Sparkle
## Build the app
- Go to Product -> Archive and archive this version of the app
- After archival is finished, choose "Distribute" and "Direct Distribution" and wait for Apple to notarize the app
- This version of the app should be distributed

This is all for setup assuming that `SUFeedURL` correctly points to the where the `appcast.xml` file is publicly available (currently it doesn't).

## Update the app (including updating `SUFeedURL`)
- Make code updates / set `SUFeedURL` be a real URL
- Increase `CFBundleVersion` if you want Sparkle to detect this update
- Increase `CFBundleShortVersionString` if you want users to see that app version changed
- Follow "Build the app" steps
- Generate a new `appcast.xml` file
    - After the app was built, compress it with `ditto -c -k --sequesterRsrc --keepParent Quicksilver.app Quicksilver-1.0.zip`
    - Put this .zip file inside an `updates` directory
    - From outside of this directory, run `/path/to/generate_appcast /path/to/updates/directory/`
        - `generate_appcast` should be in Xcode's derived data, somewhere similar to `/Users/username/Library/Developer/Xcode/DerivedData/Quicksilver-gbqftuzbgorawyctfmwuwrwmxiey/SourcePackages/artifacts/sparkle/Sparkle/bin`, though the exact Quicksilver artficat hash may differ on different machines
        - This step needs the private key to be added to the keychain and will request access to it
- Update `appcast.xml` and the app wherever they are hosted online
    - `https://example.com/appcast.xml`
    - `https://example.com/Quicksilver.dmg`

This needs to be done every time we want to push an update.
Note: if using `.dmg`, underlying `.app` file must be in its root folder (not nested).

## Testing
- Ran an older version of the app
- Quit and re-launch
- Updates should happen automatically on relaunch
- To force-update, it should be possible to run `defaults delete your.bundle.id SULastCheckTime`
