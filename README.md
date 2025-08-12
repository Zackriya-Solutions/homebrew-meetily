<div align="center" style="border-bottom: none">
    <h1>
        <img src="docs/Meetily-6.png" style="border-radius: 10px;" />
        <br>
        Meetily - AI-Powered Meeting Assistant
    </h1>
    <a href="https://trendshift.io/repositories/13272" target="_blank"><img src="https://trendshift.io/api/badge/repositories/13272" alt="Zackriya-Solutions%2Fmeeting-minutes | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>
    <br>
    <br>
    <a href="https://github.com/Zackriya-Solutions/meeting-minutes/releases/"><img src="https://img.shields.io/badge/Pre_Release-Link-brightgreen" alt="Pre-Release"></a>
    <a href="https://github.com/Zackriya-Solutions/meeting-minutes/releases/tag/v0.0.3"><img src="https://img.shields.io/badge/Stars-4k+-red" alt="Stars"></a>
    <a href="https://github.com/Zackriya-Solutions/meeting-minutes/releases/tag/v0.0.3"><img src="https://img.shields.io/badge/License-MIT-blue" alt="License"></a>
    <a href="https://github.com/Zackriya-Solutions/meeting-minutes/releases/tag/v0.0.3"><img src="https://img.shields.io/badge/Supported_OS-macOS,_Windows-yellow" alt="Supported OS"></a>
    <br>
    <h3>
    <br>
    Open source Ai Assistant for taking meeting notes
    </h3>
    <p align="center">
    Get latest <a href="https://www.zackriya.com/meetily-subscribe/"><b>Product updates</b></a> <br><br>
    <a href="https://meetily.zackriya.com"><b>Website</b></a> •
    <a href="https://in.linkedin.com/company/zackriya-solutions"><b>Authors</b></a>
    •
    <a href="https://discord.gg/crRymMQBFH"><b>Discord Channel</b></a>
</p>


<br>
</div>




Meetily is a powerful meeting transcription and analysis tool that helps you extract key insights from your meetings. It consists of two main components:

1. **Meetily Backend**: A FastAPI-based service that provides automatic transcription and intelligent analysis of meetings
2. **Meetily Frontend**: A desktop application that provides a user-friendly interface for managing and analyzing your meetings

## Features

- **Automatic Speech Recognition**: Powered by Whisper.cpp for fast, accurate transcription
- **Meeting Analysis**: Generates summaries, action items, and key points
- **API-First Design**: Easy integration with frontend applications or other services
- **Multiple AI Options**: Support for Anthropic Claude, Groq, and local Ollama models

## System Requirements

- macOS Monterey or higher (Apple Silicon recommended)
- Python 3.9 or higher
- FFmpeg (installed automatically as a dependency)
- 2GB+ of free disk space (for models and application)
- 4GB+ of RAM recommended

## Installation

Installing Meetily is a simple two-step process:

### Step 1: Install Meetily Backend

Brew Tap

```bash
# Add the custom tap
brew tap zackriya-solutions/meetily
```

Install the Cask (The backend will be automatically installed.)
```bash
# Install the frontend application (requires the tap from step 1)
brew install --cask meetily
```
**To update existing installation:**
```bash
# Update Homebrew and get latest package information
brew update

# Update to latest version
brew upgrade --cask meetily
brew upgrade meetily-backend
```


## Usage

### Starting the Backend Server

```bash
# Start with default settings
meetily-server

# Specify a different model
meetily-server --model medium

# Specify a language (default is English)
meetily-server --language fr

# Use both options together
meetily-server --model large-v3 --language de

# Use short options
meetily-server -m small -l es
```

Available options:
- `-m, --model NAME`: Specify the model name to use (tiny, base, small, medium, large-v3)
- `-l, --language LANG`: Specify the language code (default: en)
- `-h, --help`: Show help message

This command:
- Starts the Whisper transcription server on port 8178
- Starts the FastAPI backend on port 5167
- Automatically downloads the specified model if it's not found

You should see output confirming both services are running:
```
Meetily backend started!
Whisper Server running on http://localhost:8178
FastAPI Backend running on http://localhost:5167
API Documentation available at http://localhost:5167/docs
Press Ctrl+C to stop all services
```

### Using the Frontend Application

1. **Start the backend server** first (as described above)
2. **Launch the Meetily application** from your Applications folder or Spotlight
3. The application will automatically connect to the backend at http://localhost:5167

#### Frontend Features

- **Upload Meetings**: Drag and drop or select audio/video files for transcription
- **View Transcriptions**: See timestamped transcripts with speaker identification
- **Generate Analysis**: Create summaries, action items, and key points from your meetings
- **Export Results**: Save transcriptions and analyses in various formats
- **Manage History**: Access your previous meeting transcriptions and analyses

## API Documentation

For detailed API documentation, visit the Swagger UI at:
```
http://localhost:5167/docs
```

This interactive documentation allows you to:
- Explore all available endpoints
- Test API calls directly from your browser
- View request/response schemas and examples

## Troubleshooting

### Backend Issues

#### Model Problems

If you encounter issues with the Whisper model:

```bash
# Try a different model size
meetily-download-model small

# Verify model installation
ls -la $(brew --prefix)/opt/meetily-backend/backend/whisper-server-package/models/
```

#### Server Connection Issues

If the server fails to start:

1. Check if ports 8178 and 5167 are available:
   ```bash
   lsof -i :8178
   lsof -i :5167
   ```

2. Verify that FFmpeg is installed correctly:
   ```bash
   which ffmpeg
   ffmpeg -version
   ```

3. Check the logs for specific error messages when running `meetily-server`

4. Try running the Whisper server manually:
   ```bash
   cd $(brew --prefix)/opt/meetily-backend/backend/whisper-server-package/
   ./run-server.sh --model models/ggml-medium.bin
   ```

### Frontend Issues

If the frontend application doesn't connect to the backend:

1. Ensure the backend server is running (`meetily-server`)
2. Check if the application can access localhost:5167
3. Restart the application after starting the backend

If the application fails to launch:

```bash
# Clear quarantine attributes
xattr -cr /Applications/meeting-minutes-frontend.app
```

## Uninstallation

To completely remove Meetily:

```bash
# Remove the frontend
brew uninstall --cask meetily

# Remove the backend
brew uninstall meetily-backend

# Optional: remove the taps
brew untap zackriya-solutions/meetily
brew untap zackriya-solutions/meetily-backend

# Optional: remove Ollama if no longer needed
brew uninstall ollama
```

## Development and Contributions

Meetily is an open-source project. Visit our GitHub repository to contribute:
https://github.com/Zackriya-Solutions/meeting-minutes

## License

MIT License
