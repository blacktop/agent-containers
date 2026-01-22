# Fish shell configuration for Python Agent Sandbox

# Path configuration
set -gx PATH /home/dev/.local/bin $PATH
set -gx PATH /usr/local/share/npm-global/bin $PATH

# Environment
set -gx EDITOR nano
set -gx VISUAL nano
set -gx UV_CACHE_DIR /home/dev/.cache/uv

# Disable greeting
set -g fish_greeting

# fzf integration
if type -q fzf
    fzf --fish | source
end

# Aliases
alias ll "ls -la"
alias la "ls -A"
alias l "ls -CF"
alias g git
alias py python
alias pip "uv pip"
alias uvr "uv run"
alias uvs "uv sync"
