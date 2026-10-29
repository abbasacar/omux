#!/bin/zsh
# Builds omux, installs it to /Applications and puts the `omux` command on your PATH.
set -e
cd "$(dirname "$0")"

command -v swift >/dev/null || { echo "Swift not found. Run: xcode-select --install" >&2; exit 1; }
./build.sh

BIN="${OMUX_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN"
ln -sf "$PWD/bin/omux" "$BIN/omux"
echo "Linked $BIN/omux"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "Add $BIN to your PATH to use the omux command: echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.zshrc" ;;
esac
command -v claude >/dev/null || echo "Note: Claude Code isn't installed, so only shell sessions will work. See https://claude.com/claude-code"
echo "Done. Run: omux .   (or open /Applications/omux.app)"
