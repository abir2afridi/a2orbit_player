# A2Orbit Player

A professional offline video and audio player for Android built with Flutter, inspired by MX Player functionality.

## Features

### 🎥 Video Playback
- Play local video files from device storage
- Support for common formats: MP4, MKV, AVI, MOV, WMV, FLV, WebM
- Hardware accelerated playback
- Fullscreen mode with orientation handling
- Aspect ratio control (Fit, Fill, Stretch, 16:9, 4:3)
- Pinch-to-zoom and double tap seek
- Playback speed control (0.25x – 3.0x)
- Resume playback from last position

### 🎵 Audio Features
- Extract and play audio from video files
- Background audio playback when screen is off
- Audio focus handling
- Volume boost support
- Multiple audio track support

### 🎬 Picture-in-Picture (PiP)
- Floating mini-player when app is minimized
- Auto PiP on home button press
- Continue playback in PiP mode

### 👆 Gesture Controls
- Swipe left/right → Seek video
- Swipe up/down (left) → Adjust brightness
- Swipe up/down (right) → Adjust volume
- Double-tap → Quick seek
- One-hand mode support

### 📝 Subtitle Support
- Load external subtitles (.srt, .ass, .ssa, .vtt)
- Subtitle sync (delay + / -)
- Multiple subtitle tracks
- Custom font size, color, and background

### 📁 File & Library Management
- Scan device storage for videos
- Folder-wise browsing
- Hide specific folders
- Rename or delete files
- Recently played list

### 🎨 Theme & UI
- Light / Dark / AMOLED themes
- Custom accent colors
- Gesture hints overlay (optional)
- Clean minimal UI inspired by MX Player

### 🔒 Privacy & Security
- Private folder for hidden videos
- App lock: PIN / Pattern / Fingerprint
- Hide selected videos

### 🛠️ Additional Tools
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

- `READ_EXTERNAL_STORAGE`: Access video files
- `WRITE_EXTERNAL_STORAGE`: Save screenshots and preferences
- `MANAGE_EXTERNAL_STORAGE`: Full storage access (Android 11+)
- `WAKE_LOCK`: Keep screen on during playback
- `SYSTEM_ALERT_WINDOW`: Picture-in-Picture mode

## Architecture

The app follows clean architecture principles with separate layers:

- **Presentation Layer**: UI components and screens
- **Domain Layer**: Business logic and use cases
- **Data Layer**: Data sources and repositories

### Key Components

- **VideoPlayerWidget**: Core video playback component
- **FileBrowserScreen**: File browsing and management
- **SettingsScreen**: App configuration
- **ThemeProvider**: Theme management
- **SettingsProvider**: App settings persistence

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

## Roadmap

- [ ] Network streaming support (optional)
- [ ] Chromecast support
- [ ] Video editing features
- [ ] Cloud storage integration
- [ ] Playlist management
- [ ] Equalizer and audio effects
- [ ] Gesture customization
- [ ] More subtitle formats support

## Support

If you encounter any issues or have suggestions, please:

1. Check the [Issues](https://github.com/your-username/a2orbit_player/issues) page
2. Create a new issue with detailed information
3. Join our community discussions

---

**A2Orbit Player** - Your professional offline video companion 🎬
