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

# fzf integration (supports older fzf without --fish)
if type -q fzf
    if fzf --help 2>/dev/null | string match -q -- '*--fish*'
        fzf --fish | source
    else
        if test -f /usr/share/doc/fzf/examples/key-bindings.fish
            source /usr/share/doc/fzf/examples/key-bindings.fish
        else if test -f /usr/share/fzf/key-bindings.fish
            source /usr/share/fzf/key-bindings.fish
        end
        if test -f /usr/share/doc/fzf/examples/completion.fish
            source /usr/share/doc/fzf/examples/completion.fish
        else if test -f /usr/share/fzf/completion.fish
            source /usr/share/fzf/completion.fish
        end
    end
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

# Agent helpers
function cdx --description 'Run codex with full sandbox access'
    codex --dangerously-bypass-approvals-and-sandbox $argv
end

function ccx --description 'Run claude with full permissions'
    claude --dangerously-skip-permissions $argv
end

function gmx --description 'Run gemini with full permissions'
    gemini --yolo $argv
end
