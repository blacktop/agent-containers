# Fish shell configuration for Go Agent Sandbox

# Path configuration
set -gx GOPATH /home/dev/go
set -gx PATH /usr/local/go/bin $PATH
set -gx PATH $GOPATH/bin $PATH
set -gx PATH /home/dev/.local/bin $PATH
set -gx PATH /usr/local/share/npm-global/bin $PATH

# Environment
set -gx EDITOR nano
set -gx VISUAL nano

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
alias gb "go build"
alias gr "go run"
alias gt "go test"
alias gmt "go mod tidy"
alias gmi "go mod init"
