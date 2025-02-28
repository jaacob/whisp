#!/usr/bin/env zsh

# Whisper oh-my-zsh plugin
# Adds idempotency to OpenAI's Whisper CLI tool

# Default model
WHISP_DEFAULT_MODEL="turbo"
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
  local lang_option=""
  
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
  
  # Add language option if specified
  if [[ -n "$language" ]]; then
    lang_option="--language $language"
  fi
  
  # Run whisper command
  echo "Transcribing '$file' with model '$model'..."
  
  if [[ "$silent" == "true" ]]; then
    # Run silently
    eval "whisper \"$file\" --model $model $lang_option --output_format txt --output_dir \"$(dirname "$file")\" &> /dev/null"
  else
    # Show standard output
    eval "whisper \"$file\" --model $model $lang_option --output_format txt --output_dir \"$(dirname "$file")\""
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
  local files=()
  local extensions=()
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
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
      -*)
        echo "Unknown option: $1"
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
      _whisp_process_file "$file" "$model" "$force" "$language" "$silent"
    done
  elif [[ ${#extensions} -gt 0 ]]; then
    # Process files with specified extensions
    local found_files=($(_whisp_find_by_extensions "$subdir" "${extensions[@]}"))
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
      _whisp_process_file "$file" "$model" "$force" "$language" "$silent"
    done
  else
    # Process all audio files in current directory
    local found_files=($(_whisp_find_by_extensions "$subdir" "${SUPPORTED_AUDIO_EXTENSIONS[@]}"))
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
      _whisp_process_file "$file" "$model" "$force" "$language" "$silent"
    done
  fi
  
  return 0
}

# Add command completion
_whisp_completion() {
  local curcontext="$curcontext" state line
  typeset -A opt_args
  
  _arguments \
    '--model[Specify the Whisper model]:model:(tiny base small medium large turbo)' \
    '--force[Force transcription even if one exists]' \
    '--language[Specify language]:language:' \
    '--subdir[Search recursively in subdirectories]' \
    '--silent[Suppress Whisper output to terminal]' \
    '*:file or extension:_files'
}

compdef _whisp_completion whisp
