#!/usr/bin/env bash
# AGI script to stream DECtalk TTS via Named Pipe

TEXT="$1"
if [ -z "$TEXT" ]; then
  TEXT="No text provided."
fi

# Read Asterisk AGI Environment
while read -r line; do
  if [ -z "$line" ]; then
    break
  fi
done

UUID=$(cat /proc/sys/kernel/random/uuid)
FIFO="/tmp/tts_${UUID}.sln"
WAV="/tmp/tts_${UUID}.wav"

mkfifo "$FIFO"

# Generate DECtalk audio.
cd @out@/share/dectalk
./say -fo "$WAV" -a "[:phoneme on] $TEXT" > /dev/null 2>&1

ffmpeg -i "$WAV" -ar 8000 -ac 1 -f s16le "$FIFO" > /dev/null 2>&1 &

echo "STREAM FILE /tmp/tts_${UUID} \"\""
read -r response

rm -f "$FIFO" "$WAV"
