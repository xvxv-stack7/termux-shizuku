#!/data/data/com.termux/files/usr/bin/bash
# TTS 语音守护进程——监控文件，有消息就说话
FISH_KEY=$(cat ~/.fish-audio-token 2>/dev/null)
LAST=0
while true; do
  NOW=$(stat -c %Y /sdcard/speak_text.tmp 2>/dev/null || echo 0)
  if [ "$NOW" != "$LAST" ] && [ "$NOW" != "0" ]; then
    LAST=$NOW
    sleep 0.5  # 等文件写完
    text=$(cat /sdcard/speak_text.tmp 2>/dev/null)
    [ -n "$text" ] || continue
    echo "[$(date +%H:%M)] DAEMON: $text" >> /sdcard/speak_debug.log
    f="/sdcard/tts_output.mp3"
    id=$((RANDOM % 9000 + 1000))
    bash ~/.cc-connect/scripts/dashscope_tts.sh "$text" "$f" >> /sdcard/speak_debug.log 2>&1
    echo "CURL=$? SIZE=$(stat -c%s $f 2>/dev/null)" >> /sdcard/speak_debug.log
    termux-media-player play "$f" >> /sdcard/speak_debug.log 2>&1
    echo "PLAY=$?" >> /sdcard/speak_debug.log
    termux-notification --id "$id" --title "🗣️ TTS" --content "$text" \
      --priority max --vibrate "200,100" --sound \
      --button1 "💬 回复" --button1-action 'bash ~/reply-handler.sh' 2>/dev/null
  fi
  sleep 2
done
