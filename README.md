# Beam

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

A lightning-fast, cross-platform local file transfer application.

<img src="assets/demo.gif" width="100%" alt="Beam Demo" />

## 🚀 Features

*   **Lightning Fast P2P Transfer:** Transfer files directly between devices on your local network without relying on cloud servers or internet connection.
*   **Auto-Discovery:** Seamlessly find other devices on your network using mDNS.
*   **QR Code Pairing:** Quickly and securely connect to devices by scanning a QR code.
*   **Drag & Drop Support:** Easily select files to send by dragging and dropping them into the app (perfect for desktop users).
*   **Transfer History:** Keep track of your past sent and received files with a built-in database.
*   **Data Integrity:** Automatic checksum validation ensures your files arrive perfectly intact without corruption.
*   **Background Transfers:** Continue transferring large files even when the app is minimized or in the background.

## 📱 Supported Platforms

*   🤖 **Android**
*   🐧 **Linux**

## 🛠️ Getting Started

### Prerequisites

*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.11.5 or higher)

### Installation & Build

1.  Clone the repository:
    ```bash
    git clone <repository-url>
    cd beam
    ```

2.  Install Flutter dependencies:
    ```bash
    flutter pub get
    ```

3.  Run the application:
    *   **For Android:** 
        ```bash
        flutter run -d android
        ```
    *   **For Linux:** 
        ```bash
        flutter run -d linux
        ```

## 🏗️ Architecture & Stack

*   **Framework:** Flutter
*   **State Management:** Pico / Flutter Hooks
*   **Local Database:** SQFlite (Transfer History)
*   **Network:** Custom P2P implementation with Bonsoir (mDNS discovery)

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to open an issue or submit a pull request if you have ideas on how to improve Beam.

## 📄 License

This project is licensed under the **MIT License**.
