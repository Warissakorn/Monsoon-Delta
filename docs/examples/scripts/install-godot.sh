# macOS
sudo ln -sf /Applications/Godot.app/Contents/MacOS/Godot /usr/local/bin/godot

# Linux
mkdir -p ~/.local/bin && cp Godot_v4.7.2-stable_linux.x86_64 ~/.local/bin/godot

# Windows (Git Bash) — keep both Godot .exe files together in C:\Tools\Godot
mkdir -p ~/bin
printf '#!/bin/sh\nexec "/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" "$@"\n' > ~/bin/godot
chmod +x ~/bin/godot