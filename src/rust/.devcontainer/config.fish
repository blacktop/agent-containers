# Fish shell configuration for Rust Agent Sandbox

# Path configuration
set -gx PATH /home/dev/.cargo/bin $PATH
set -gx PATH /home/dev/.local/bin $PATH
set -gx PATH /usr/local/share/npm-global/bin $PATH

# Environment
set -gx EDITOR nano
set -gx VISUAL nano
set -gx CARGO_HOME /home/dev/.cargo
set -gx RUSTUP_HOME /home/dev/.rustup

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
alias c cargo
alias cb "cargo build"
alias cr "cargo run"
alias ct "cargo test"
alias cc "cargo clippy"
alias cf "cargo fmt"
