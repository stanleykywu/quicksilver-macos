# Quicksilver MacOS
This is a MacOS app for the [Quicksilver browser extension](https://github.com/stanleykywu/quicksilver-browser-extension), which allows users to quickly check if music they are listening to is AI-generated. This app works by directly analyzing music audio from your computer for artifacts music commonly found in AI-generated music. In other words, if your computer can play it, Quicksilver can directly classify the audio without you needing to download it or upload it anywhere. If you are looking for our browser extension, please look [here](https://github.com/stanleykywu/quicksilver-browser-extension).

## Downloading
You can download the latest version of our app [here](https://github.com/stanleykywu/quicksilver-macos/releases/latest)

## Development Instructions

### Set up Xcode project workspace
- After pulling updates from github, open Xcode, select "open existing project",
and choose Quicksilver.xcodeproj in the file picker.
- This should automatically open all project files and pull in Swift dependendencies.
### Compile Rust backend and link to the Swift bridge
- Run `sh build.sh` in the root directory.
- This will build our Rust backend: `libquicksilver_universal.a`
- Drag `libquicksilver_universal.a` to our Xcode project files.
- When prompted, select "Quicksilver" as the only target and choose the "copy" option.

## Running the app

### Build
- Build the app by clicking on the "run" button
- This will automatically start running the app

### Grant permissions
- After you click "Analyze" for the first time, MacOS should prompt you to grant our app recording permissions
- Grant permissions in the system settings and click "Quit & Reopen" option that should pop up