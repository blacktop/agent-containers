# Fish shell configuration for TypeScript Agent Sandbox

# Path configuration
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
alias ni "npm install"
alias nr "npm run"
alias nt "npm test"
alias nb "npm run build"
alias nd "npm run dev"
alias pi "pnpm install"
alias pr "pnpm run"
alias tsc "npx tsc"
