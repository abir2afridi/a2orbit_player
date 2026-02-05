# A2Orbit Player

A professional offline video and audio player for Android built with Flutter, inspired by MX Player functionality.

## 🚀 Current Status

**✅ Fully Functional Features:**
- Core video playback with hardware acceleration
- Smart file browser with folder filtering
- Complete settings system with themes
- Storage permission handling
- Modern Material 3 UI

**🚧 In Development:**
- Gesture controls (swipe, tap, pinch-to-zoom)
- Background audio playback
- Picture-in-Picture (PiP) mode
- Subtitle support

## Features

### ✅ Implemented Features

#### 🎥 Video Playback
- Play local video files from device storage
- Support for common formats: MP4, MKV, AVI, MOV, WMV, FLV, WebM
- Hardware accelerated playback
- Fullscreen mode with orientation handling
- Playback speed control (0.5x – 2.5x)
- Resume playback from last position
- Auto-hide controls with timer
- Volume and brightness controls

#### 📁 Smart File Browser
- **Smart folder filtering** - Only shows folders containing videos
- **Last-level folder display** - Direct access to video folders
- **Grid/List view toggle** for both folders and videos
- **Recursive video scanning** with performance optimization
- **Search functionality** for folders and videos
- **Video file filtering** by extension
- **Android 13+ permission handling** with proper dialogs
- **Storage scanning optimization** with system path exclusion

#### � Theme & UI
- **Light / Dark / AMOLED themes** with Material 3 design
- **Custom accent colors** support
- **Clean minimal UI** inspired by MX Player
- **Modern home screen** with quick actions
- **Bottom navigation** for easy access
- **Responsive design** for all screen sizes

#### ⚙️ Settings System
- **Player settings**: Background play, PiP, audio only, volume boost
- **Playback controls**: Speed control, seek duration
- **Hardware acceleration** toggle
- **Audio and subtitle language** preferences
- **System settings** with persistent storage
- **Per-video preference** saving

#### �️ Architecture
- **Clean Architecture** with separate layers
- **Riverpod state management** for optimal performance
- **Well-structured project** with feature-based organization
- **Error handling** with custom exceptions
- **Utility functions** for common operations

### 🚧 Features In Development

#### 👆 Gesture Controls
- Swipe left/right → Seek video
- Swipe up/down (left) → Adjust brightness
- Swipe up/down (right) → Adjust volume
- Double-tap → Quick seek
- Pinch-to-zoom functionality

#### 🎵 Audio Features
- Extract and play audio from video files
- Background audio playback when screen is off
- Audio focus handling
- Volume boost support
- Multiple audio track support

#### 🎬 Picture-in-Picture (PiP)
- Floating mini-player when app is minimized
- Auto PiP on home button press
- Continue playback in PiP mode

#### 📝 Subtitle Support
- Load external subtitles (.srt, .ass, .ssa, .vtt)
- Subtitle sync (delay + / -)
- Multiple subtitle tracks
- Custom font size, color, and background

### � Planned Features

#### 🔒 Privacy & Security
- Private folder for hidden videos
- App lock: PIN / Pattern / Fingerprint
- Hide selected videos

#### 🛠️ Additional Tools
- Screenshot capture from video
- A-B repeat loop
- Sleep timer
- Kids lock
- Headset button support

## Tech Stack

- **Flutter**: Latest stable version
- **State Management**: Riverpod
- **Video Player**: video_player package
- **Audio**: just_audio package
- **Storage**: shared_preferences, sqflite
- **Permissions**: permission_handler
- **File Management**: file_picker, path_provider

## Project Structure

```
lib/
├── core/
│   ├── constants/          # App constants
│   ├── errors/            # Custom exceptions
│   ├── providers/         # Riverpod providers
│   ├── theme/             # App themes
│   └── utils/             # Utility functions
├── features/
│   ├── player/            # Video player functionality
│   ├── settings/          # App settings
│   ├── storage/           # File browser and storage
│   ├── services/          # Background services
│   └── ui/                # UI components and screens
└── main.dart              # App entry point
```

## Getting Started

### Prerequisites

- Flutter SDK (>=3.10.0)
- Android SDK
- Android Studio or VS Code with Flutter extensions

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/a2orbit_player.git
cd a2orbit_player
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Build APK

```bash
flutter build apk --release
```

## Permissions Required

### Android 13+ (API 33+)
- `READ_MEDIA_VIDEO`: Access video files
- `READ_MEDIA_AUDIO`: Access audio files  
- `READ_MEDIA_IMAGES`: Access image files

### Android 12 and below
- `READ_EXTERNAL_STORAGE`: Access storage files
- `WRITE_EXTERNAL_STORAGE`: Save screenshots and preferences (maxSdkVersion="28")

### Additional Permissions
- `ACCESS_NETWORK_STATE`: Network state checking
- `WAKE_LOCK`: Keep screen on during playback
- `SYSTEM_ALERT_WINDOW`: Picture-in-Picture mode (future feature)

### Permission Handling
- **Smart permission requests** based on Android version
- **User-friendly dialogs** explaining permission requirements
- **Settings navigation** for permission management
- **Retry mechanisms** for permission failures

## Architecture

The app follows clean architecture principles with separate layers:

- **Presentation Layer**: UI components and screens
- **Domain Layer**: Business logic and use cases
- **Data Layer**: Data sources and repositories

### Key Components

#### ✅ Implemented Components
- **RobustVideoPlayerWidget**: Core video playback with error handling
- **FileBrowserScreen**: Smart file browsing with folder filtering
- **VideoListScreen**: Dedicated video listing for each folder
- **FolderScanService**: Optimized storage scanning service
- **SettingsScreen**: Comprehensive app configuration
- **ThemeProvider**: Theme management with Material 3
- **SettingsProvider**: App settings persistence
- **PermissionHelper**: Android permission handling utility
- **AppUtils**: Common utility functions (duration, file size, etc.)

#### 🚧 Components In Development
- **GestureController**: Gesture detection and handling
- **AudioService**: Background audio playback
- **PiPService**: Picture-in-Picture functionality
- **SubtitleService**: Subtitle loading and rendering

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by MX Player's functionality and UI design
- Built with Flutter and the amazing open-source community
- Thanks to all package maintainers who made this project possible

## 🚧 Development Roadmap

### Current Sprint (In Progress)
- [ ] **Gesture Controls Implementation**
  - [ ] Swipe gestures for seek/volume/brightness
  - [ ] Double-tap for quick seek
  - [ ] Pinch-to-zoom functionality
  - [ ] Gesture customization settings

- [ ] **Background Audio Playback**
  - [ ] Audio extraction from video
  - [ ] Background service implementation
  - [ ] Audio focus handling
  - [ ] Notification controls

- [ ] **Picture-in-Picture (PiP) Mode**
  - [ ] PiP window setup
  - [ ] Auto-PiP on home button
  - [ ] PiP controls and interaction
  - [ ] PiP settings integration

### Next Sprint
- [ ] **Subtitle Support**
  - [ ] External subtitle loading (.srt, .ass, .ssa)
  - [ ] Subtitle rendering engine
  - [ ] Sync controls (delay adjustment)
  - [ ] Multiple subtitle tracks

- [ ] **Audio Track Management**
  - [ ] Multiple audio track detection
  - [ ] Audio track switching
  - [ ] Audio delay sync
  - [ ] Smart audio decoder management

### Future Features
- [ ] **Privacy & Security**
  - [ ] Private folder for hidden videos
  - [ ] App lock (PIN/Pattern/Fingerprint)
  - [ ] Hide selected videos functionality

- [ ] **Additional Tools**
  - [ ] Screenshot capture from video
  - [ ] A-B repeat loop
  - [ ] Sleep timer
  - [ ] Kids lock
  - [ ] Headset button support

- [ ] **Advanced Features**
  - [ ] Aspect ratio control (Fit, Fill, Stretch, 16:9, 4:3)
  - [ ] One-hand mode support
  - [ ] Gesture hints overlay
  - [ ] Equalizer and audio effects

## 📱 Build Status

### ✅ Current Build
- **Flutter Version**: Latest stable
- **Build Status**: ✅ Successfully builds APK
- **Target Platform**: Android (API 21+)
- **Architecture**: arm64-v8a, armeabi-v7a, x86_64
- **APK Size**: ~15MB (debug), ~12MB (release)

### 🧪 Testing Status
- **Unit Tests**: In development
- **Integration Tests**: Planned
- **Manual Testing**: ✅ Core features tested
- **Device Compatibility**: ✅ Android 7.0+ tested

## Support

If you encounter any issues or have suggestions, please:

1. Check the [Issues](https://github.com/your-username/a2orbit_player/issues) page
2. Create a new issue with detailed information
3. Join our community discussions

---

**A2Orbit Player** - Your professional offline video companion 🎬

*Built with ❤️ using Flutter for the best Android video playback experience*
