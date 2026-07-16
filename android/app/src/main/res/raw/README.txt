📌 Place your notification sound here:
File: speakeasy_notification.mp3
Format: MP3, <5 sec, mono recommended

Instructions:
1. Convert your Indian musical tune to MP3
2. Name it speakeasy_notification.mp3
3. Place it in this folder
4. Rebuild the app

For iOS:
ffmpeg -i your_sound.mp3 -c:a aac -b:a 16k -ar 16000 ios/Runner/speakeasy_notification.caf

