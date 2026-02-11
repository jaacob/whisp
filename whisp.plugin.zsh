#!/usr/bin/env zsh

# WhisperX oh-my-zsh plugin
# Adds idempotency to WhisperX CLI tool with diarization support

# Default model
WHISP_DEFAULT_MODEL="turbo"
WHISP_DEFAULT_COMPUTE_TYPE="float32"
SUPPORTED_MODELS=("tiny" "base" "small" "medium" "large" "turbo")
SUPPORTED_AUDIO_EXTENSIONS=("mp3" "mp4" "m4a" "wav" "flac" "aac" "ogg" "wma")

# Function to check if model is valid
_whisp_validate_model() {
  local model=$1
  if [[ ! ${SUPPORTED_MODELS[(ie)$model]} -le ${#SUPPORTED_MODELS} ]]; then
    echo "Error: Invalid model '$model'."
    echo "Supported models: ${SUPPORTED_MODELS[*]}"
    return 1
  fi
  return 0
}

# Function to check if a file has already been transcribed
_whisp_has_transcription() {
  local audio_file=$1
  local txt_file="${audio_file%.*}.txt"
  
  if [[ -f "$txt_file" ]]; then
    return 0  # Transcription exists
  else
    return 1  # No transcription
  fi
}

# Function to generate a unique filename for forced transcriptions
_whisp_get_unique_filename() {
  local base_file=$1
  local txt_file="${base_file%.*}.txt"
  local counter=1
  local new_file="${base_file%.*}_$counter.txt"
  
  while [[ -f "$new_file" ]]; do
    ((counter++))
    new_file="${base_file%.*}_$counter.txt"
  done
  
  echo "$new_file"
}

# Function to process a single file
_whisp_process_file() {
  local file=$1
  local model=$2
  local force=$3
  local language=$4
  local silent=$5
  local cores=$6
  local diarize=$7
  local hf_token=$8
  local min_speakers=$9
  local max_speakers=${10}
  local compute_type=${11}
  
  if [[ ! -f "$file" ]]; then
    echo "Error: File '$file' not found."
    return 1
  fi
  
  # Check if file extension is supported
  local ext="${file##*.}"
  ext="${ext:l}"  # Convert to lowercase
  
  if [[ ! ${SUPPORTED_AUDIO_EXTENSIONS[(ie)$ext]} -le ${#SUPPORTED_AUDIO_EXTENSIONS} ]]; then
    echo "Warning: '$file' does not have a recognized audio extension."
    echo "Supported extensions: ${SUPPORTED_AUDIO_EXTENSIONS[*]}"
    # Continue anyway, as the file might still be valid audio
  fi
  
  # Check for existing transcription
  if _whisp_has_transcription "$file" && [[ "$force" != "true" ]]; then
    # Single file mode, prompt user
    if [[ "$WHISP_BATCH_MODE" != "true" ]]; then
      echo -n "A transcription already exists for '$file'. Create another transcription? (Y/N) "
      read -r response
      if [[ "${response:l}" != "y" ]]; then
        echo "Skipping '$file'."
        return 0
      fi
      force="true"  # User confirmed, force transcription
    else
      # Batch mode, just skip
      echo "Skipping '$file': transcription already exists. Use --force to override."
      return 0
    fi
  fi
  
  # Prepare output filename
  local output_file
  if [[ "$force" == "true" ]] && _whisp_has_transcription "$file"; then
    output_file=$(_whisp_get_unique_filename "$file")
  else
    output_file="${file%.*}.txt"
  fi
  
  # Run whisperx command
  echo "Transcribing '$file' with model '$model'..."

  # Build whisperx options
  local -a whisperx_opts=()
  whisperx_opts+=(--model "$model")
  whisperx_opts+=(--output_format txt)
  whisperx_opts+=(--output_dir "$(dirname "$file")")
  whisperx_opts+=(--compute_type "$compute_type")

  if [[ -n "$cores" && "$cores" -gt 0 ]]; then
    whisperx_opts+=(--threads "$cores")
    if [[ "$silent" != "true" ]]; then
      echo "Limiting to $cores threads"
    fi
  fi

  if [[ -n "$language" ]]; then
    whisperx_opts+=(--language "$language")
  fi

  # Diarization options
  if [[ "$diarize" == "true" ]]; then
    whisperx_opts+=(--diarize)
    whisperx_opts+=(--hf_token "$hf_token")
    if [[ -n "$min_speakers" ]]; then
      whisperx_opts+=(--min_speakers "$min_speakers")
    fi
    if [[ -n "$max_speakers" ]]; then
      whisperx_opts+=(--max_speakers "$max_speakers")
    fi
  fi

  if [[ "$silent" == "true" ]]; then
    whisperx "$file" "${whisperx_opts[@]}" &> /dev/null
  else
    whisperx "$file" "${whisperx_opts[@]}"
  fi
  
  # Rename output file if necessary
  local whisper_output="${file%.*}.txt"
  if [[ "$whisper_output" != "$output_file" ]]; then
    mv "$whisper_output" "$output_file"
  fi
  
  echo "Transcription saved to '$output_file'."
  return 0
}

# Function to find files with specific extensions
_whisp_find_by_extensions() {
  local exts=("$@")
  local recursive=$1
  shift

  local depth_option=""
  if [[ "$recursive" != "true" ]]; then
    depth_option="-maxdepth 1"  # Only search in current directory
  fi
  
  local find_cmd="find . $depth_option -type f"
  
  # Construct the find command with extension filters
  local first=true
  for ext in "${exts[@]}"; do
    ext="${ext:l}"  # Convert to lowercase
    if [[ "$first" == "true" ]]; then
      find_cmd="$find_cmd \( -iname \"*.$ext\""
      first=false
    else
      find_cmd="$find_cmd -o -iname \"*.$ext\""
    fi
  done
  
  if [[ "$first" == "false" ]]; then
    find_cmd="$find_cmd \)"
  else
    # No extensions specified, find all supported audio files
    first=true
    for ext in "${SUPPORTED_AUDIO_EXTENSIONS[@]}"; do
      if [[ "$first" == "true" ]]; then
        find_cmd="$find_cmd \( -iname \"*.$ext\""
        first=false
      else
        find_cmd="$find_cmd -o -iname \"*.$ext\""
      fi
    done
    find_cmd="$find_cmd \)"
  fi
  
  # Execute the find command
  eval "$find_cmd"
}

# Main whisp function
whisp() {
  local model="$WHISP_DEFAULT_MODEL"
  local force=false
  local language=""
  local subdir=false
  local silent=false
  local cores=""
  local diarize=false
  local hf_token=""
  local min_speakers=""
  local max_speakers=""
  local compute_type="$WHISP_DEFAULT_COMPUTE_TYPE"
  local files=()
  local extensions=()
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        cat << 'EOF'
Whisp - An Oh My Zsh plugin for WhisperX with idempotency and diarization

USAGE:
  whisp [OPTIONS] [FILES/EXTENSIONS...]

DESCRIPTION:
  Transcribe audio files using WhisperX with smart idempotency.
  Skips files that already have transcriptions unless --force is used.
  Optionally identify speakers with --diarize.

COMMANDS:
  whisp                          Process all audio files in current directory
  whisp file.mp3                 Process a specific file
  whisp file1.mp3 file2.m4a      Process multiple specific files
  whisp mp3                      Process all .mp3 files in current directory
  whisp mp3 m4a wav              Process files with any of these extensions

OPTIONS:
  --model MODEL                  Specify WhisperX model to use
                                 Options: tiny, base, small, medium, large, turbo
                                 Default: turbo

  --force                        Force transcription even if one already exists
                                 Creates uniquely numbered transcriptions

  --language LANG                Specify source language for transcription
                                 Example: --language en

  --subdir                       Search recursively in subdirectories
                                 Default: current directory only

  --silent                       Suppress WhisperX output to terminal
                                 Default: show full output

  --cores NUM                    Limit threads used by WhisperX
                                 Example: --cores 2

  --diarize                      Enable speaker diarization
                                 Requires a HuggingFace API token

  --hf-token TOKEN               HuggingFace API token for diarization
                                 Falls back to HF_TOKEN environment variable

  --min-speakers NUM             Minimum number of speakers for diarization
                                 Example: --min-speakers 2

  --max-speakers NUM             Maximum number of speakers for diarization
                                 Example: --max-speakers 4

  --compute-type TYPE            Compute type for WhisperX inference
                                 Options: float16, float32, int8
                                 Default: float32

  --help, -h                     Show this help message

SUPPORTED AUDIO FORMATS:
  mp3, mp4, m4a, wav, flac, aac, ogg, wma

DIARIZATION:
  Speaker diarization identifies who is speaking and when. To use it:

  1. Create a HuggingFace account at https://huggingface.co
  2. Accept the pyannote model agreements:
     - https://huggingface.co/pyannote/segmentation-3.0
     - https://huggingface.co/pyannote/speaker-diarization-3.1
  3. Create an access token at https://huggingface.co/settings/tokens
  4. Either set HF_TOKEN in your environment or pass --hf-token

EXAMPLES:
  whisp                          # Process all audio in current directory
  whisp mp3 --model medium       # Process MP3s with medium model
  whisp --subdir --silent        # Process all audio recursively, quietly
  whisp interview.mp3 --force    # Force retranscription of a file
  whisp --cores 2 --model large  # Limit to 2 threads with large model
  whisp --diarize meeting.mp3    # Transcribe with speaker identification
  whisp --diarize --min-speakers 2 --max-speakers 4 call.mp3

IDEMPOTENCY:
  - Single file: Prompts before creating duplicate transcription
  - Batch mode: Automatically skips files with existing transcriptions
  - Use --force to override and create numbered transcriptions

For more information, visit: https://github.com/jaacob/whisp
EOF
        return 0
        ;;
      --model)
        model="$2"
        _whisp_validate_model "$model" || return 1
        shift 2
        ;;
      --force)
        force=true
        shift
        ;;
      --language)
        language="$2"
        shift 2
        ;;
      --subdir)
        subdir=true
        shift
        ;;
      --silent)
        silent=true
        shift
        ;;
      --cores)
        if [[ "$2" =~ ^[0-9]+$ ]]; then
          cores="$2"
          shift 2
        else
          echo "Error: --cores requires a numeric value."
          return 1
        fi
        ;;
      --diarize)
        diarize=true
        shift
        ;;
      --hf-token)
        hf_token="$2"
        shift 2
        ;;
      --min-speakers)
        if [[ "$2" =~ ^[0-9]+$ ]]; then
          min_speakers="$2"
          shift 2
        else
          echo "Error: --min-speakers requires a numeric value."
          return 1
        fi
        ;;
      --max-speakers)
        if [[ "$2" =~ ^[0-9]+$ ]]; then
          max_speakers="$2"
          shift 2
        else
          echo "Error: --max-speakers requires a numeric value."
          return 1
        fi
        ;;
      --compute-type)
        compute_type="$2"
        shift 2
        ;;
      -*)
        echo "Unknown option: $1"
        echo "Use 'whisp --help' for usage information."
        return 1
        ;;
      *)
        # Check if argument is a file
        if [[ -f "$1" ]]; then
          files+=("$1")
        # Check if argument is a known extension
        elif [[ ${#1} -le 4 ]]; then
          extensions+=("$1")
        else
          echo "Error: '$1' is not a valid file or extension."
          return 1
        fi
        shift
        ;;
    esac
  done
  
  # Validate model
  _whisp_validate_model "$model" || return 1

  # Resolve HF token for diarization
  if [[ "$diarize" == "true" ]]; then
    if [[ -z "$hf_token" ]]; then
      hf_token="${HF_TOKEN:-}"
    fi
    if [[ -z "$hf_token" ]]; then
      echo "Error: Diarization requires a HuggingFace API token."
      echo ""
      echo "Either:"
      echo "  1. Pass --hf-token YOUR_TOKEN"
      echo "  2. Set the HF_TOKEN environment variable"
      echo ""
      echo "To get a token:"
      echo "  1. Create an account at https://huggingface.co"
      echo "  2. Accept the pyannote model agreements:"
      echo "     - https://huggingface.co/pyannote/segmentation-3.0"
      echo "     - https://huggingface.co/pyannote/speaker-diarization-3.1"
      echo "  3. Create a token at https://huggingface.co/settings/tokens"
      return 1
    fi
  else
    if [[ -n "$min_speakers" || -n "$max_speakers" ]]; then
      echo "Warning: --min-speakers/--max-speakers have no effect without --diarize"
    fi
  fi

  # Set batch mode if no files are specified explicitly
  if [[ ${#files} -eq 0 ]]; then
    WHISP_BATCH_MODE="true"
  else
    WHISP_BATCH_MODE="false"
  fi
  
  # Process files
  if [[ ${#files} -gt 0 ]]; then
    # Process specified files
    for file in "${files[@]}"; do
      _whisp_process_file "$file" "$model" "$force" "$language" "$silent" "$cores" "$diarize" "$hf_token" "$min_speakers" "$max_speakers" "$compute_type"
    done
  elif [[ ${#extensions} -gt 0 ]]; then
    # Process files with specified extensions
    local _output=$(_whisp_find_by_extensions "$subdir" "${extensions[@]}")
    local -a found_files=()
    [[ -n "$_output" ]] && found_files=("${(f)_output}")
    if [[ ${#found_files} -eq 0 ]]; then
      if [[ "$subdir" == "true" ]]; then
        echo "No matching audio files found in current directory or subdirectories."
      else
        echo "No matching audio files found in current directory."
      fi
      return 0
    fi
    
    if [[ "$subdir" == "true" ]]; then
      echo "Found ${#found_files} files with extensions: ${extensions[*]} (including subdirectories)"
    else
      echo "Found ${#found_files} files with extensions: ${extensions[*]}"
    fi
    
    for file in "${found_files[@]}"; do
      _whisp_process_file "$file" "$model" "$force" "$language" "$silent" "$cores" "$diarize" "$hf_token" "$min_speakers" "$max_speakers" "$compute_type"
    done
  else
    # Process all audio files in current directory
    local _output=$(_whisp_find_by_extensions "$subdir" "${SUPPORTED_AUDIO_EXTENSIONS[@]}")
    local -a found_files=()
    [[ -n "$_output" ]] && found_files=("${(f)_output}")
    if [[ ${#found_files} -eq 0 ]]; then
      if [[ "$subdir" == "true" ]]; then
        echo "No audio files found in current directory or subdirectories."
      else
        echo "No audio files found in current directory."
      fi
      return 0
    fi
    
    if [[ "$subdir" == "true" ]]; then
      echo "Found ${#found_files} audio files in current directory and subdirectories."
    else
      echo "Found ${#found_files} audio files in current directory."
    fi
    
    for file in "${found_files[@]}"; do
      _whisp_process_file "$file" "$model" "$force" "$language" "$silent" "$cores" "$diarize" "$hf_token" "$min_speakers" "$max_speakers" "$compute_type"
    done
  fi
  
  return 0
}

# Add command completion
_whisp_completion() {
  local curcontext="$curcontext" state line
  typeset -A opt_args
  
  _arguments \
    '--model[Specify the WhisperX model]:model:(tiny base small medium large turbo)' \
    '--force[Force transcription even if one exists]' \
    '--language[Specify language]:language:' \
    '--subdir[Search recursively in subdirectories]' \
    '--silent[Suppress WhisperX output to terminal]' \
    '--cores[Limit threads used]:cores:' \
    '--diarize[Enable speaker diarization]' \
    '--hf-token[HuggingFace API token]:token:' \
    '--min-speakers[Minimum number of speakers]:num:' \
    '--max-speakers[Maximum number of speakers]:num:' \
    '--compute-type[Compute type for inference]:type:(float16 float32 int8)' \
    '*:file or extension:_files'
}

compdef _whisp_completion whisp