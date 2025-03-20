# Whisp - An Oh My Zsh plugin for OpenAI's Whisper

Whisp is an Oh My Zsh plugin that adds idempotency and convenience features to OpenAI's Whisper CLI tool. It helps you efficiently transcribe audio files without duplicating work.

## Features

- **Idempotent Processing**: Skip files that already have transcriptions unless explicitly forced
- **Batch Processing**: Transcribe multiple files with a single command
- **Extension Filtering**: Process files of specific audio types
- **Model Selection**: Easily switch between Whisper models
- **Recursive Searching**: Optionally find audio files in subdirectories
- **Output Control**: View Whisper's real-time output or suppress it
- **Resource Management**: Limit CPU usage to prevent system slowdown

## Dependencies

- [Oh My Zsh](https://ohmyz.sh/)
- [OpenAI's Whisper](https://github.com/openai/whisper) CLI tool properly installed and available in your PATH

## Installation

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/whisp.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/whisp
   ```

2. Add the plugin to your `.zshrc` file:
   ```bash
   plugins=(... whisp)
   ```

3. Reload your shell:
   ```bash
   source ~/.zshrc
   ```


## Usage

### Basic Commands

```bash
# Transcribe all supported audio files in the current directory
whisp

# Transcribe a specific file
whisp file.mp3

# Transcribe all files with a specific extension
whisp mp3

# Transcribe files with any of multiple extensions
whisp mp3 m4a wav

# Transcribe multiple specific files
whisp file1.mp3 file2.m4a
```

### Options

```bash
# Choose which Whisper model to use (default is turbo)
whisp --model tiny
whisp --model base
whisp --model small
whisp --model medium
whisp --model large
whisp --model turbo

# Force transcription even if a transcription already exists
whisp --force

# Specify language for transcription
whisp --language en

# Search for audio files in subdirectories
whisp --subdir

# Run silently (suppress Whisper output)
whisp --silent

# Limit CPU cores used (reduces system load)
whisp --cores 2

# Combine options
whisp mp3 --model medium --force --subdir --cores 4
```

## Idempotency Behavior

- **Single File Mode**: If a transcription exists, prompts you before creating a new one
- **Batch Mode**: Automatically skips files with existing transcriptions
- **Force Mode**: Creates uniquely named transcriptions without overwriting existing ones

## Supported Audio Formats

- mp3
- mp4
- m4a
- wav
- flac
- aac
- ogg
- wma

## Examples

### Transcribe all MP3 files in the current directory using the medium model
```bash
whisp mp3 --model medium
```

### Transcribe all audio files, including those in subdirectories
```bash
whisp --subdir
```

### Force retranscription of a specific file
```bash
whisp interview.mp3 --force
```

### Process multiple file types silently
```bash
whisp mp3 wav --silent
```

## Support

This has only been tested on macOS Sequoia 15. YMMV.

## License

MIT © Jacob Reiff

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
