# Port-A-Thoughty 🧠

> Capture first, clean later. Port-A-Thoughty keeps your brain clear.

A Flutter mobile app for capturing fleeting thoughts through voice, text, and images, then organizing them into structured Markdown documents with AI assistance.

## ✨ Features

### 🎤 Multi-Modal Capture
- **Voice Recording**: Native speech-to-text with privacy-first offline processing
- **Text Notes**: Quick text input with Markdown support
- **Image OCR**: Capture photos with automatic text extraction
- **File Upload**: Process documents with AI-powered content extraction

### 📋 Smart Organization
- **Project-Based**: Organize notes into custom projects (Inbox, Dev Projects, Creative Writing, etc.)
- **Queue System**: All captures land in a processing queue for later review
- **Batch Processing**: Select multiple notes to process together into cohesive documents

### 🤖 AI-Powered Processing
- **Automatic Summarization**: Convert raw notes into organized bullet points
- **Custom Prompts**: Each project can have its own AI processing instructions
- **Markdown Export**: All processed documents saved as shareable Markdown files

### 🎨 Beautiful UI
- Fixed header design with smooth scrolling
- Material Design 3 theming with gradient backgrounds
- Custom illustrations and icons
- Professional bottom sheets and modals

## 📱 Screenshots

<table>
  <tr>
    <td><img src="docs/Screenshot_20251107_115158.png" width="250"/></td>
    <td><img src="docs/Screenshot_20251107_115212.png" width="250"/></td>
    <td><img src="docs/Screenshot_20251107_115226.png" width="250"/></td>
  </tr>
  <tr>
    <td align="center"><b>Capture Screen</b><br/>Voice recording (idle)</td>
    <td align="center"><b>Recording</b><br/>Active voice capture</td>
    <td align="center"><b>Text Input</b><br/>Quick note composer</td>
  </tr>
</table>

<table>
  <tr>
    <td><img src="docs/Screenshot_20251107_115245.png" width="250"/></td>
    

## 🏗️ Architecture

### State Management
- **Provider**: Single `PortaThoughtyState` class manages the entire app
- Reactive updates across all screens
- Centralized coordination between services

### Database
- **SQLite**: Cross-platform persistence with `sqflite` and `sqflite_common_ffi`
- Schema versioning with migration support
- Three main tables: `projects`, `notes`, `docs`

### Core Services
- **NativeSpeechToTextService**: Voice capture with confidence scoring
- **OcrService**: Google ML Kit for image text extraction
- **DocGenerator**: Markdown file generation with project organization
- **GroqFileProcessor**: AI-powered file content extraction

### Navigation
- Bottom navigation bar with three main screens
- Fixed header stays at top while content scrolls
- No swipe navigation (button-only for precision)

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android SDK / Xcode (for mobile development)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/porta-a-thoughty.git
   cd porta-a-thoughty
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Create environment file**
   ```bash
   # Create .env file in project root
   echo "GROQ_API_KEY=your_api_key_here" > .env
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Minimum SDK: 21
- Target SDK: 34
- Permissions required: Microphone, Camera, Storage

#### Windows/Linux/macOS
- Uses `sqflite_common_ffi` for desktop database support
- Speech recognition may have limited support on desktop

## 🛠️ Development

### Project Structure
```
lib/
├── main.dart                 # App entry point & shell
├── models/                   # Data models
│   ├── note.dart
│   ├── project.dart
│   └── processed_doc.dart
├── screens/                  # Main screens
│   ├── capture_screen.dart
│   ├── queue_screen.dart
│   └── docs_screen.dart
├── services/                 # Business logic
│   ├── local_database.dart
│   ├── native_speech_to_text.dart
│   ├── ocr_service.dart
│   └── doc_generator.dart
├── state/                    # State management
│   └── app_state.dart
├── theme/                    # App theming
│   └── app_theme.dart
└── widgets/                  # Reusable components
    ├── app_header.dart
    └── project_selector.dart
```

### Key Commands
```bash
# Run on specific device
flutter devices
flutter run -d <device-id>

# Hot reload
r  (in running app terminal)

# Build for production
flutter build apk          # Android
flutter build windows      # Windows
flutter build ios          # iOS

# Code analysis
flutter analyze

# Format code
dart format .
```

## 📝 Usage Workflow

1. **Capture Thoughts**: Use voice, text, or camera to quickly capture ideas
2. **Review Queue**: Navigate to "Raw Notes" to see all unprocessed captures
3. **Select & Process**: Choose notes to batch process together
4. **Review Docs**: Check the "Docs" tab for your organized Markdown summaries
5. **Share**: Export and share processed documents

## 🔧 Configuration

### Adding New Projects
Projects are created via the "New project" button with:
- Custom name (4-20 characters)
- Type (Grocery List, Dev Project, Creative Writing, etc.)
- Optional AI processing instructions
- Custom icon and color

### Database Migrations
Current schema version: **2**

To add new columns or tables:
1. Update `onCreate` in `local_database.dart`
2. Increment version number
3. Add migration logic in `onUpgrade`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Google ML Kit for OCR capabilities
- Speech-to-text plugin contributors
- The open source community

## 📞 Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

**Made with ❤️ and Flutter**
