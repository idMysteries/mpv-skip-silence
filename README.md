# Automatic speed-up of silent video fragments for mpv player

## Usage guide
1. Install [auto-editor](https://github.com/WyattBlue/auto-editor)
```
pip install auto-editor
```
2. Copy "[autoeditor.lua](https://raw.githubusercontent.com/idMysteries/mpv-skip-silence/main/autoeditor.lua)" script to ["\mpv\scripts"](https://mpv.io/manual/master/#script-location) folder
3. Take a look at "[script-opts\autoeditor.conf](https://github.com/idMysteries/mpv-yt-dlp-files/blob/main/script-opts/autoeditor.conf)" as an example for script parameters. The default settings are in the script.
4. Press Shift+E in the player and you will see a message about the running analysis
5. Press Ctrl+Shift+E in the player and you will see the current settings

## script-opts
```
enabled=no
silence_speed=2.5
threshold="4%"
margin="0.1s,0.2s"
mincut="1s"
```
