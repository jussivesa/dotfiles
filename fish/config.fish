# Dotnet shiiit
# set -x DOTNET_ROOT $HOME/.dotnet
set -x DOTNET_ROOT /usr/local/share/dotnet

# NVM and Node shit done using "fisher install jorgebucaran/nvm.fish"
set --universal nvm_default_version v20.18.3

fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin
fish_add_path $DOTNET_ROOT
fish_add_path $DOTNET_ROOT/tools
fish_add_path /Applications/Docker.app/Contents/Resources/bin
fish_add_path $HOME/Library/Application\ Support/JetBrains/Toolbox/scripts

set -gx DOTNET_WATCH_RESTART_ON_RUDE_EDIT 1

zoxide init fish | source
starship init fish | source

# Tmux keybind (ctrl + f)
set PATH "$PATH":"$HOME/.config/"
bind \cf "tmux_sessionizer"
