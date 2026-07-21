#!/data/data/com.termux/files/usr/bin/bash
text=$(cat /sdcard/speak_text.tmp 2>/dev/null)
[ -z "$text" ] && exit
FISH_KEY=$(cat ~/.fish-audio-token 2>/dev/null)

echo "$(date) START: $text" >> /sdcard/speak_debug.log
f="/sdcard/tts_output.mp3"
id=$((RANDOM % 9000 + 1000))

curl -s --max-time 20 -X POST https://api.fish.audio/v1/tts \
  -H "Authorization: Bearer $FISH_KEY" \
  -H "Content-Type: application/json" \
  -H "model: s2.1-pro-free" \
  -d "{\"text\":\"$text\",\"reference_id\":\"a11b63f5025140fbb1fdf6237c5c10df\",\"format\":\"mp3\"}" \
  -o "$f" 2>>/sdcard/speak_debug.log
echo "$(date) CURL_EXIT=$? SIZE=$(stat -c%s $f 2>/dev/null)" >> /sdcard/speak_debug.log
termux-media-player play "$f" 2>>/sdcard/speak_debug.log
echo "$(date) PLAY_EXIT=$?" >> /sdcard/speak_debug.log

termux-notification --id "$id" --title "🗣️ TTS" --content "$text" \
  --priority max --vibrate "200,100" --sound \
  --button1 "💬 回复" --button1-action 'bash ~/reply-handler.sh' 2>/dev/null
