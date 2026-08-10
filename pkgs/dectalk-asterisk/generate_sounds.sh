#!/usr/bin/env bash

# This script generates Asterisk core sounds using DECtalk

echo "Extracting Asterisk core sounds manifest..."
mkdir -p ../sounds
tar -xf $CORE_SOUNDS -C ../sounds

echo "Generating DECtalk static sound pack..."
cd ../sounds

cat core-sounds-en.txt | while read -r line; do
  if [ -z "$line" ] || [[ "$line" == \;* ]]; then
    continue
  fi
  
  filename=$(echo "$line" | cut -d':' -f1)
  text=$(echo "$line" | cut -d':' -f2- | sed 's/^ *//' | sed 's/\[.*\] //g')
  
  if [ ! -z "$filename" ] && [ ! -z "$text" ]; then
    WAV_TMP="/tmp/${filename}.wav"
    
    # Change dir so DECtalk finds its dictionary files
    (cd @out@/share/dectalk && ./say -fo "$WAV_TMP" -a "[:phoneme on] $text" > /dev/null 2>&1) || true
    
    if [ -f "$WAV_TMP" ]; then
      ffmpeg -i "$WAV_TMP" -ar 8000 -ac 1 -c:a pcm_s16le "@out@/share/asterisk/sounds/dectalk/${filename}.wav" > /dev/null 2>&1 || true
      rm -f "$WAV_TMP"
    fi
  fi
done
