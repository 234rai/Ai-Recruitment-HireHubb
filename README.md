# Ai-Recruitment - HireHubb

Ai-Recruitment - HireHubb is an AI-powered recruitment mobile application designed to streamline hiring processes for companies and candidates. Built entirely with Dart and Flutter, it offers a modern, cross-platform solution for efficient recruitment and seamless user experience.

## Features

- **AI-Driven Candidate Matching:** Uses intelligent algorithms to match candidates to job roles effectively.
- **User Authentication:** Includes modern authentication options (e.g., Google login).
- **Candidate and Recruiter Dashboards:** Organize, filter, and manage candidate applications with ease.
- **Customizable UI:** Clean and modern interface built with Flutter, supporting theming and rapid updates.
- **Asset Management:** Preloaded avatars, images, and logos for demo and presentation purposes.
- **Highly Modular Structure:** Designed for scalability with clear separation of concerns across codebase.

## Tech Stack

- **Language:** Dart (100%)
- **Framework:** Flutter
- **Platforms:** Android (iOS can be supported with Flutter)

## Project Structure

```
.
├── README.md
├── android/
│   ├── app/
│   ├── build.gradle.kts
│   └── settings.gradle.kts
├── assets/
│   ├── candidate1.png
│   ├── candidate2.png
│   ├── candidate3.PNG
│   └── google_logo.png
└── lib/
    ├── main.dart           # App entry point
    ├── Screens/            # App screens and UI
    ├── models/             # Data models for app entities
    ├── navigation/         # App navigation routes and logic
    ├── providers/          # State management (e.g., Provider)
    ├── services/           # Service classes like API, authentication, etc.
    └── theme/              # Theming and style definitions
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Android Studio, VS Code, or another Flutter-compatible IDE

### Setup Instructions

1. **Clone this repository**
   ```bash
   git clone https://github.com/234rai/Ai-Recruitment---HireHubb.git
   cd Ai-Recruitment---HireHubb
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```
   > Make sure an emulator or device is connected.

### Android Build

- Android-specific build scripts and configuration are located in the `android/` directory.
- Modify `build.gradle.kts` and `settings.gradle.kts` for advanced native setup.

## Assets

- Demo candidate images and logos are available in the `assets/` folder.

## Contribution

Contributions are welcome! Fork this repository and submit a pull request, or open issues for bug fixes and feature requests.

---

> **Note:** This project is under active development. Core app structure and features are in place, but more advanced functionality is being continuously added.
