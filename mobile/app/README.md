# MyBartenderAI Mobile App

A Flutter-based mobile application for cocktail recommendations and bartender assistance.

## Features

- **Ask the Bartender**: Chat with an AI bartender for cocktail recommendations and drink advice
- **Voice Assistant**: Real-time voice interaction using OpenAI's Realtime API
- **Recipe Vault**: Browse and search thousands of cocktail recipes with filtering options
- **Favorites**: Save and organize your favorite cocktails with one tap
- **My Bar**: Track your ingredient inventory and discover cocktails you can make
- **Offline Mode**: Access your favorite cocktails without an internet connection

## Setup

1. **Install Flutter**: Follow the [Flutter installation guide](https://flutter.dev/docs/get-started/install)

2. **Clone the repository**:
   ```bash
   git clone https://github.com/gwhitley1969/mybartenderAI-MVP.git
   cd mybartenderAI-MVP/mobile/app
   ```

3. **Configure the backend**:
   - For local development, update the `apiBaseUrl` in `lib/main.dart` to point to your local Azure Functions instance
   - For production, obtain a function key from the Azure Portal and configure it securely
   
   **Important**: Never commit API keys or function keys to version control!

4. **Install dependencies**:
   ```bash
   flutter pub get
   ```

5. **Run the app**:
   ```bash
   flutter run
   ```

## Configuration

The app requires the following configuration:

- `apiBaseUrl`: The URL of your Azure Functions backend
- `functionKey`: The Azure Functions host key for authentication

For local development without authentication, you can use the test endpoints:
- `/v1/ask-bartender-simple` instead of `/v1/ask-bartender`
- `/v1/realtime/token-simple` instead of `/v1/realtime/token`

## Development

### Running Tests
```bash
flutter test
```

### Building for Release

**Android**:
```bash
flutter build apk --release
```

**iOS**:
```bash
flutter build ios --release
```

## Architecture

The app follows a clean architecture pattern with:

- **API Layer**: HTTP clients for backend communication
- **Services**: Business logic and state management
- **Features**: UI screens and widgets
- **Providers**: Dependency injection using Riverpod

## Voice Integration

The voice assistant uses OpenAI's Realtime API with WebSocket connections for low-latency audio streaming. Key components:

- `RealtimeWebSocketService`: Manages WebSocket connection and audio streaming
- `AudioRecorderService`: Handles microphone input with proper buffering
- `AudioStreamHandler`: Processes PCM16 audio data for transmission

## Security Notes

- Store sensitive configuration (API keys, function keys) securely
- Use environment variables or secure storage solutions
- Never commit secrets to version control
- Enable authentication for production deployments