# Whisp - An Oh My Zsh plugin for WhisperX

Whisp is an Oh My Zsh plugin that adds idempotency, convenience features, and speaker diarization to the [WhisperX](https://github.com/m-bain/whisperX) CLI tool. It helps you efficiently transcribe audio files without duplicating work.

## Features

- **Idempotent Processing**: Skip files that already have transcriptions unless explicitly forced
- **Speaker Diarization**: Identify who is speaking with `--diarize` (powered by pyannote.audio)
- **Batch Processing**: Transcribe multiple files with a single command
- **Extension Filtering**: Process files of specific audio types
- **Model Selection**: Easily switch between WhisperX models
- **Recursive Searching**: Optionally find audio files in subdirectories
- **Output Control**: View WhisperX's real-time output or suppress it
- **Resource Management**: Limit thread usage to prevent system slowdown

## Dependencies

- [Oh My Zsh](https://ohmyz.sh/)
- [WhisperX](https://github.com/m-bain/whisperX) CLI tool properly installed and available in your PATH
- For diarization: A [HuggingFace](https://huggingface.co) API token with access to pyannote models

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
# Choose which WhisperX model to use (default is turbo)
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

# Run silently (suppress WhisperX output)
whisp --silent

# Limit threads used (reduces system load)
whisp --cores 2

# Set compute type (default: float32, also: float16, int8)
whisp --compute-type float32

# Combine options
whisp mp3 --model medium --force --subdir --cores 4
```

### Diarization

Speaker diarization identifies who is speaking and when. To use it:

1. Create a [HuggingFace](https://huggingface.co) account
2. Accept the pyannote model agreements:
   - [pyannote/segmentation-3.0](https://huggingface.co/pyannote/segmentation-3.0)
   - [pyannote/speaker-diarization-3.1](https://huggingface.co/pyannote/speaker-diarization-3.1)
3. Create an access token at [HuggingFace Settings](https://huggingface.co/settings/tokens)
4. Either set `HF_TOKEN` in your environment or pass `--hf-token`

```bash
# Transcribe with speaker identification
whisp --diarize meeting.mp3

# Pass HuggingFace token directly
whisp --diarize --hf-token hf_abc123 meeting.mp3

# Specify expected number of speakers
whisp --diarize --min-speakers 2 --max-speakers 4 call.mp3
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

### Transcribe a meeting with speaker diarization
```bash
whisp --diarize --min-speakers 2 meeting.mp3
```

## Support

This has only been tested on macOS Sequoia 15. YMMV.

## License

MIT © Jacob Reiff

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
