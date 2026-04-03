# quicksilver-macos

## Setup instructions

### Set up Xcode project workspace
- After pulling updates from github, open Xcode, select "open existing project",
and choose Quicksilver.xcodeproj in the file picker.
- This should automatically open all project files and pull in Swift dependendencies.
### Compile Rust backend and link to the Swift bridge
- Run `cargo build --release` in the root directory.
- This will build our Rust backend: `target/release/libquicksilver.a`
- Drag `libquicksilver.a` to our Xcode project files.
- When prompted, select "Quicksilver" as the only target and choose the "copy" option.
### Check app permissions
- Navigate to the target info by clicking on "Quicksilver" target in the file menu bar
- Open "Signing & Capabilities" tab
- Sign in to our team account (right now Stanley's Apple Developer account)
- Make sure "Signing Certificate" is set to "Development"

## Running the app

### Build
- Build the app by clicking on the "run" button
- This will automatically start running the app

### Grant permissions
- After you click "Analyze" for the first time, MacOS should prompt you to grant our app recording permissions
- Grant permissions in the system settings and click "Quit & Reopen" option that should pop up