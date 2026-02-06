#!/usr/bin/env fish
# =============================================================================
# install.fish - Install agent fish functions
# =============================================================================
# Installs the agent.fish functions to your fish config.
#
# Usage:
#   ./install.fish              # Install via source in config.fish
#   ./install.fish --copy       # Copy functions to ~/.config/fish/functions/
#   ./install.fish --uninstall  # Remove from config
# =============================================================================

set -g _agent_install_script_dir (dirname (status filename))
set -g _agent_install_agent_fish (realpath "$_agent_install_script_dir/agent.fish")
set -g _agent_install_macos_dir (realpath "$_agent_install_script_dir/.." 2>/dev/null; or echo "$_agent_install_script_dir/..")
set -g _agent_install_config_fish "$HOME/.config/fish/config.fish"
set -g _agent_install_functions_dir "$HOME/.config/fish/functions"

function show_help
    echo "Usage: install.fish [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --copy        Copy functions to ~/.config/fish/functions/"
    echo "  --uninstall   Remove agent functions from config"
    echo "  --help        Show this help"
    echo ""
    echo "Default behavior: Add 'source' line to config.fish"
end

function install_via_source
    echo "Installing via source in config.fish..."

    # Check if already installed
    if test -f "$_agent_install_config_fish"
        if grep -q "source.*agent.fish" "$_agent_install_config_fish"
            echo "Already installed in config.fish"
            return 0
        end
    end

    # Create config.fish if it doesn't exist
    mkdir -p (dirname "$_agent_install_config_fish")
    touch "$_agent_install_config_fish"

    # Add source line
    echo "" >> "$_agent_install_config_fish"
    echo "# AI Agent functions" >> "$_agent_install_config_fish"
    echo "source $_agent_install_agent_fish" >> "$_agent_install_config_fish"

    echo "Added to $_agent_install_config_fish:"
    echo "  source $_agent_install_agent_fish"
    echo ""
    echo "Reload your shell or run: source $_agent_install_config_fish"
end

function install_via_copy
    echo "Installing via copy to functions directory..."

    mkdir -p "$_agent_install_functions_dir"

    # Extract individual functions from agent.fish
    set -l agent_functions agent agent-native agent-build agent-spawn agent-list agent-cleanup

    if not test -f "$_agent_install_agent_fish"
        echo "Error: $_agent_install_agent_fish not found"
        return 1
    end

    # Load function definitions so we can emit full bodies
    source "$_agent_install_agent_fish"
    set -l macos_dir_escaped (string escape --style=script -- "$_agent_install_macos_dir")

    for func in $agent_functions
        echo "  Creating $func.fish..."
        set -l function_file "$_agent_install_functions_dir/$func.fish"

        # Write function header
        echo "# Auto-generated from agent.fish" > "$function_file"
        echo "" >> "$function_file"

        # Preserve top-level defaults for copy installs.
        grep -E '^set -q AGENT_(IMAGE|CPUS|MEMORY); or set -g AGENT_' "$_agent_install_agent_fish" >> "$function_file"
        echo "set -q AGENT_MACOS_DIR; or set -g AGENT_MACOS_DIR $macos_dir_escaped" >> "$function_file"
        echo "" >> "$function_file"

        # Emit full function definition (handles nested blocks)
        functions $func >> "$function_file"
    end

    # Copy completions
    echo "  Copying completions..."
    grep "^complete -c" "$_agent_install_agent_fish" >> "$_agent_install_functions_dir/agent.fish" 2>/dev/null || true

    echo ""
    echo "Installed to $_agent_install_functions_dir/"
    echo "Reload your shell to use."
end

function uninstall
    echo "Uninstalling..."

    # Remove from config.fish
    if test -f "$_agent_install_config_fish"
        if grep -q "source.*agent.fish" "$_agent_install_config_fish"
            # Create backup
            cp "$_agent_install_config_fish" "$_agent_install_config_fish.backup"
            # Remove the source line and comment
            grep -v "source.*agent.fish" "$_agent_install_config_fish.backup" | grep -v "^# AI Agent functions" > "$_agent_install_config_fish"
            echo "Removed from $_agent_install_config_fish"
        end
    end

    # Remove function files
    for func in agent agent-native agent-build agent-spawn agent-list agent-cleanup
        if test -f "$_agent_install_functions_dir/$func.fish"
            rm "$_agent_install_functions_dir/$func.fish"
            echo "Removed $_agent_install_functions_dir/$func.fish"
        end
    end

    echo "Uninstall complete."
end

# Parse arguments
argparse 'h/help' 'copy' 'uninstall' -- $argv
or begin
    show_help
    exit 1
end

if set -q _flag_help
    show_help
    exit 0
end

if set -q _flag_uninstall
    uninstall
    exit 0
end

if set -q _flag_copy
    install_via_copy
    exit 0
end

# Default: install via source
install_via_source
