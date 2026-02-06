# =============================================================================
# agent.fish - Fish Shell Functions for AI Agent Containers
# =============================================================================
# Install: source this file from config.fish or run install.fish
#
# Functions:
#   agent            - Run AI agent in Docker container (yolo mode)
#   agent-native     - Run agent on macOS with sandbox
#   agent-build      - Build the yolo Docker image
#   agent-spawn      - Create jj workspace + launch agent
#   agent-list       - List active jj workspaces
#   agent-cleanup    - Remove jj workspace
# =============================================================================

# ------------------------------------
# Configuration (override in config.fish)
# ------------------------------------
set -q AGENT_IMAGE; or set -g AGENT_IMAGE "ghcr.io/blacktop/agent-containers/yolo:latest"
set -q AGENT_CPUS; or set -g AGENT_CPUS 4
set -q AGENT_MEMORY; or set -g AGENT_MEMORY "8g"
set -q AGENT_MACOS_DIR; or begin
    set -l _agent_script_dir (dirname (status filename))
    set -g AGENT_MACOS_DIR (realpath "$_agent_script_dir/.." 2>/dev/null; or echo "$_agent_script_dir/..")
end


# ------------------------------------
# agent: Run AI agent in Docker container
# ------------------------------------
function agent -d "Run AI agent (claude/codex/gemini) in Docker container"
    argparse 'h/help' 'w/workspace=' 'c/cpus=' 'm/memory=' 'b/build' 'n/name=' \
             'no-firewall' 'F/foreground' -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: agent [OPTIONS] AGENT [AGENT_ARGS...]"
        echo ""
        echo "Agents:"
        echo "  claude       Run Claude Code (--dangerously-skip-permissions)"
        echo "  codex        Run Codex (--approval-mode full-auto)"
        echo "  gemini       Run Gemini CLI (--yolo)"
        echo "  bash         Interactive bash shell"
        echo "  fish         Interactive fish shell"
        echo "  install-all  Show installed agent versions"
        echo ""
        echo "Options:"
        echo "  -w, --workspace PATH   Workspace directory (default: current dir)"
        echo "  -c, --cpus N           CPU count (default: $AGENT_CPUS)"
        echo "  -m, --memory SIZE      Memory limit (default: $AGENT_MEMORY)"
        echo "  -b, --build            Build image before running"
        echo "  -n, --name NAME        Container name"
        echo "  --no-firewall          Disable network firewall"
        echo "  -h, --help             Show this help"
        echo ""
        echo "Examples:"
        echo "  agent claude                 # Run Claude on current directory"
        echo "  agent -w ~/project codex     # Run Codex on specific workspace"
        echo "  agent --no-firewall gemini   # Run without firewall"
        return 0
    end

    # Check for docker
    if not command -q docker
        echo "Error: docker not found"
        echo "Install OrbStack (recommended) or Docker Desktop"
        return 1
    end

    # Set defaults
    set -l workspace (set -q _flag_workspace; and echo $_flag_workspace; or pwd)
    set -l cpus (set -q _flag_cpus; and echo $_flag_cpus; or echo $AGENT_CPUS)
    set -l memory (set -q _flag_memory; and echo $_flag_memory; or echo $AGENT_MEMORY)

    # Resolve workspace to absolute path
    set workspace (realpath $workspace 2>/dev/null; or echo $workspace)

    # Create workspace if needed
    if not test -d $workspace
        echo "Creating workspace: $workspace"
        mkdir -p $workspace
    end

    # Build if requested
    if set -q _flag_build
        agent-build; or return 1
    end

    # Determine agent from args
    set -l agent_cmd $argv[1]
    if test -z "$agent_cmd"
        set agent_cmd "bash"
    end

    # Build docker command
    set -l cmd docker run -it --rm
    set -a cmd --cpus $cpus --memory $memory
    set -a cmd -w /workspace

    # Add container name if specified
    if set -q _flag_name
        set -a cmd --name $_flag_name
    end

    # Add NET_ADMIN for firewall (unless disabled)
    if not set -q _flag_no_firewall
        set -a cmd --cap-add=NET_ADMIN
    else
        set -a cmd -e FIREWALL_ENABLED=false
    end

    # Mount workspace
    set -a cmd -v "$workspace:/workspace"

    # Mount auth directories
    if test -d "$HOME/.claude"
        set -a cmd -v "$HOME/.claude:/home/dev/.claude"
    end
    if test -d "$HOME/.codex"
        set -a cmd -v "$HOME/.codex:/home/dev/.codex"
    end
    if test -d "$HOME/.gemini"
        set -a cmd -v "$HOME/.gemini:/home/dev/.gemini"
    end

    # Pass through API keys for MCP
    if set -q CONTEXT7_API_KEY
        set -a cmd -e "CONTEXT7_API_KEY=$CONTEXT7_API_KEY"
    end
    if set -q EXA_API_KEY
        set -a cmd -e "EXA_API_KEY=$EXA_API_KEY"
    end

    # Pass through git identity (useful for bot-attributed commits).
    if set -q GIT_USER_NAME
        set -a cmd -e "GIT_USER_NAME=$GIT_USER_NAME"
    end
    if set -q GIT_USER_EMAIL
        set -a cmd -e "GIT_USER_EMAIL=$GIT_USER_EMAIL"
    end

    # Pass through GitHub App credentials for least-privilege git auth.
    if set -q GITHUB_APP_ID
        set -a cmd -e "GITHUB_APP_ID=$GITHUB_APP_ID"
    end
    if set -q GITHUB_APP_INSTALL_ID
        set -a cmd -e "GITHUB_APP_INSTALL_ID=$GITHUB_APP_INSTALL_ID"
    end
    if set -q GITHUB_APP_KEY_BASE64
        set -a cmd -e "GITHUB_APP_KEY_BASE64=$GITHUB_APP_KEY_BASE64"
    end
    if set -q GITHUB_APP_KEY_PATH
        set -a cmd -e "GITHUB_APP_KEY_PATH=$GITHUB_APP_KEY_PATH"
    end

    # Image and args
    set -a cmd $AGENT_IMAGE $argv

    echo "════════════════════════════════════════════"
    echo "Running AI Agent (Yolo Mode)"
    echo "════════════════════════════════════════════"
    echo "Agent:     $agent_cmd"
    echo "Image:     $AGENT_IMAGE"
    echo "Workspace: $workspace"
    echo "Firewall:  "(not set -q _flag_no_firewall; and echo "enabled"; or echo "disabled")
    echo ""

    $cmd
end


# ------------------------------------
# agent-native: Run agent on macOS with sandbox
# ------------------------------------
function agent-native -d "Run AI agent on macOS with sandbox restrictions"
    argparse 'h/help' 'w/workspace=' 'x/xcode' 'p/pf' 'no-sandbox' -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: agent-native [OPTIONS] AGENT [AGENT_ARGS...]"
        echo ""
        echo "Agents:"
        echo "  claude       Run Claude Code"
        echo "  codex        Run Codex"
        echo "  gemini       Run Gemini CLI"
        echo ""
        echo "Options:"
        echo "  -w, --workspace PATH   Workspace directory (default: current dir)"
        echo "  -x, --xcode            Use Xcode-enabled sandbox profile"
        echo "  -p, --pf               Enable pf firewall (requires sudo)"
        echo "  --no-sandbox           Disable sandbox (development only)"
        echo "  -h, --help             Show this help"
        echo ""
        echo "Examples:"
        echo "  agent-native claude           # Run with basic sandbox"
        echo "  agent-native --xcode claude   # Run with Xcode access"
        echo "  agent-native --pf codex       # Run with pf firewall"
        return 0
    end

    set -l agent_cmd $argv[1]
    if test -z "$agent_cmd"
        echo "Error: AGENT required (claude, codex, or gemini)"
        return 1
    end

    set -l workspace (set -q _flag_workspace; and echo $_flag_workspace; or pwd)
    set workspace (realpath $workspace 2>/dev/null; or echo $workspace)

    if not test -d $workspace
        echo "Creating workspace: $workspace"
        mkdir -p $workspace
    end

    # Resolve helper asset paths from AGENT_MACOS_DIR so copy installs still work.
    set -l macos_dir (realpath "$AGENT_MACOS_DIR" 2>/dev/null; or echo "$AGENT_MACOS_DIR")
    set -l sandbox_profile "$macos_dir/sandbox/agent.sb"
    set -l pf_helper "$macos_dir/pf/install-anchor.sh"
    if set -q _flag_xcode
        set sandbox_profile "$macos_dir/sandbox/agent-xcode.sb"
    end

    if not set -q _flag_no_sandbox
        if not test -f "$sandbox_profile"
            echo "Error: sandbox profile not found: $sandbox_profile"
            return 1
        end
    end

    # Resolve agent binary
    set -l agent_bin
    switch $agent_cmd
        case claude claude-code
            set agent_bin (command -v claude)
            set -l agent_args "--dangerously-skip-permissions"
        case codex
            set agent_bin (command -v codex)
            set -l agent_args "--approval-mode full-auto"
        case gemini
            set agent_bin (command -v gemini)
            set -l agent_args "--yolo"
        case '*'
            echo "Error: Unknown agent: $agent_cmd"
            echo "Supported: claude, codex, gemini"
            return 1
    end

    if test -z "$agent_bin"
        echo "Error: $agent_cmd not found in PATH"
        echo "Install with: npm install -g @anthropic-ai/claude-code"
        return 1
    end

    echo "════════════════════════════════════════════"
    echo "Running AI Agent (Native macOS)"
    echo "════════════════════════════════════════════"
    echo "Agent:     $agent_cmd"
    echo "Binary:    $agent_bin"
    echo "Workspace: $workspace"
    echo "Sandbox:   "(not set -q _flag_no_sandbox; and echo (set -q _flag_xcode; and echo "xcode"; or echo "basic"); or echo "DISABLED")
    echo "pf:        "(set -q _flag_pf; and echo "enabled"; or echo "disabled")
    echo ""

    # Enable pf if requested
    if set -q _flag_pf
        if not test -f "$pf_helper"
            echo "Error: pf helper not found: $pf_helper"
            return 1
        end
        echo "Enabling pf firewall..."
        sudo "$pf_helper" enable
    end

    # Run with or without sandbox
    if set -q _flag_no_sandbox
        echo "WARNING: Running without sandbox"
        switch $agent_cmd
            case claude claude-code
                $agent_bin --dangerously-skip-permissions $argv[2..-1]
            case codex
                $agent_bin --approval-mode full-auto $argv[2..-1]
            case gemini
                $agent_bin --yolo $argv[2..-1]
        end
    else
        switch $agent_cmd
            case claude claude-code
                sandbox-exec \
                    -f $sandbox_profile \
                    -D "WORKSPACE=$workspace" \
                    -D "HOME=$HOME" \
                    $agent_bin --dangerously-skip-permissions $argv[2..-1]
            case codex
                sandbox-exec \
                    -f $sandbox_profile \
                    -D "WORKSPACE=$workspace" \
                    -D "HOME=$HOME" \
                    $agent_bin --approval-mode full-auto $argv[2..-1]
            case gemini
                sandbox-exec \
                    -f $sandbox_profile \
                    -D "WORKSPACE=$workspace" \
                    -D "HOME=$HOME" \
                    $agent_bin --yolo $argv[2..-1]
        end
    end

    # Disable pf if we enabled it
    if set -q _flag_pf
        echo "Disabling pf firewall..."
        sudo "$pf_helper" disable
    end
end


# ------------------------------------
# agent-build: Build the yolo Docker image
# ------------------------------------
function agent-build -d "Build the yolo Docker image"
    argparse 'h/help' 'p/push' 't/tag=' -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: agent-build [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -t, --tag TAG    Image tag (default: $AGENT_IMAGE)"
        echo "  -p, --push       Push to registry after build"
        echo "  -h, --help       Show this help"
        return 0
    end

    set -l tag (set -q _flag_tag; and echo $_flag_tag; or echo $AGENT_IMAGE)

    # Find Dockerfile
    set -l dockerfile_dir "$AGENT_MACOS_DIR/../src/yolo"

    if not test -f "$dockerfile_dir/Dockerfile"
        # Try relative to cwd
        set dockerfile_dir "./src/yolo"
    end
    if not test -f "$dockerfile_dir/Dockerfile"
        echo "Error: Dockerfile not found"
        echo "Run from agent-containers directory"
        return 1
    end

    echo "Building $tag..."
    docker build --tag $tag -f "$dockerfile_dir/Dockerfile" $dockerfile_dir
    or return 1

    if set -q _flag_push
        echo "Pushing $tag..."
        docker push $tag
    end

    echo "Done."
end


# ------------------------------------
# agent-spawn: Create jj workspace + launch agent
# ------------------------------------
function agent-spawn -d "Create jj workspace and launch agent container"
    argparse 'h/help' 'r/revision=' 'c/cpus=' 'm/memory=' 'd/dir=' 'a/agent=' -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: agent-spawn NAME [OPTIONS]"
        echo ""
        echo "Creates a jj workspace and launches an agent container."
        echo ""
        echo "Options:"
        echo "  -a, --agent AGENT      Agent to run (claude/codex/gemini, default: claude)"
        echo "  -r, --revision REV     Base revision (default: @)"
        echo "  -d, --dir PATH         Workspaces directory (default: ../.agent-workspaces)"
        echo "  -c, --cpus N           CPU count (default: $AGENT_CPUS)"
        echo "  -m, --memory SIZE      Memory limit (default: $AGENT_MEMORY)"
        echo "  -h, --help             Show this help"
        echo ""
        echo "Example:"
        echo "  agent-spawn feature-auth -r main"
        echo "  agent-spawn bugfix-api -a codex"
        return 0
    end

    if test (count $argv) -lt 1
        echo "Error: NAME required"
        echo "Usage: agent-spawn NAME [OPTIONS]"
        return 1
    end

    set -l name $argv[1]
    set -l agent_type (set -q _flag_agent; and echo $_flag_agent; or echo "claude")
    set -l revision (set -q _flag_revision; and echo $_flag_revision; or echo "@")
    set -l workspaces_dir (set -q _flag_dir; and echo $_flag_dir; or echo "../.agent-workspaces")
    set -l workspace_path "$workspaces_dir/$name"

    # Check for jj
    if not command -q jj
        echo "Error: jj (Jujutsu) not found"
        echo "Install: brew install jj"
        return 1
    end

    # Check if in jj repo
    if not jj root &>/dev/null
        echo "Error: Not in a jj repository"
        echo "Initialize with: jj git init"
        return 1
    end

    # Create workspaces directory
    mkdir -p $workspaces_dir

    # Check if workspace already exists
    if jj workspace list | grep -q " $name\$"
        echo "Workspace '$name' already exists"
        echo "Use: agent-cleanup $name"
        return 1
    end

    echo "Creating jj workspace '$name' at revision '$revision'..."
    jj workspace add $workspace_path --name $name --revision $revision
    or return 1

    echo ""
    echo "Launching $agent_type agent..."

    # Build agent args
    set -l agent_args -w (realpath $workspace_path)

    if set -q _flag_cpus
        set -a agent_args -c $_flag_cpus
    end
    if set -q _flag_memory
        set -a agent_args -m $_flag_memory
    end

    agent $agent_args $agent_type
end


# ------------------------------------
# agent-list: List active jj workspaces
# ------------------------------------
function agent-list -d "List active jj workspaces"
    if not command -q jj
        echo "Error: jj not found"
        return 1
    end

    if not jj root &>/dev/null
        echo "Error: Not in a jj repository"
        return 1
    end

    echo "Active jj workspaces:"
    echo ""
    jj workspace list
end


# ------------------------------------
# agent-cleanup: Remove jj workspace
# ------------------------------------
function agent-cleanup -d "Remove jj workspace and clean up"
    argparse 'h/help' 'f/force' -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: agent-cleanup NAME [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -f, --force    Remove without confirmation"
        echo "  -h, --help     Show this help"
        return 0
    end

    if test (count $argv) -lt 1
        echo "Error: NAME required"
        echo "Usage: agent-cleanup NAME"
        return 1
    end

    set -l name $argv[1]

    if not command -q jj
        echo "Error: jj not found"
        return 1
    end

    # Check if workspace exists
    if not jj workspace list | grep -q " $name\$"
        echo "Workspace '$name' not found"
        return 1
    end

    # Confirm unless forced
    if not set -q _flag_force
        read -P "Remove workspace '$name'? [y/N] " confirm
        if test "$confirm" != "y" -a "$confirm" != "Y"
            echo "Cancelled"
            return 0
        end
    end

    echo "Removing workspace '$name'..."
    jj workspace forget $name

    # Try to remove the directory
    set -l workspaces_dir "../.agent-workspaces"
    if test -d "$workspaces_dir/$name"
        rm -rf "$workspaces_dir/$name"
        echo "Removed directory: $workspaces_dir/$name"
    end

    echo "Done"
end


# ------------------------------------
# Completions
# ------------------------------------
# agent completions
complete -c agent -s h -l help -d "Show help"
complete -c agent -s w -l workspace -d "Workspace directory" -r
complete -c agent -s c -l cpus -d "CPU count" -r
complete -c agent -s m -l memory -d "Memory limit" -r
complete -c agent -s b -l build -d "Build image first"
complete -c agent -s n -l name -d "Container name" -r
complete -c agent -l no-firewall -d "Disable firewall"
complete -c agent -n "not __fish_seen_subcommand_from claude codex gemini bash fish install-all" -a "claude" -d "Run Claude Code"
complete -c agent -n "not __fish_seen_subcommand_from claude codex gemini bash fish install-all" -a "codex" -d "Run Codex"
complete -c agent -n "not __fish_seen_subcommand_from claude codex gemini bash fish install-all" -a "gemini" -d "Run Gemini CLI"
complete -c agent -n "not __fish_seen_subcommand_from claude codex gemini bash fish install-all" -a "bash" -d "Interactive bash"
complete -c agent -n "not __fish_seen_subcommand_from claude codex gemini bash fish install-all" -a "fish" -d "Interactive fish"
complete -c agent -n "not __fish_seen_subcommand_from claude codex gemini bash fish install-all" -a "install-all" -d "Show versions"

# agent-native completions
complete -c agent-native -s h -l help -d "Show help"
complete -c agent-native -s w -l workspace -d "Workspace directory" -r
complete -c agent-native -s x -l xcode -d "Use Xcode sandbox"
complete -c agent-native -s p -l pf -d "Enable pf firewall"
complete -c agent-native -l no-sandbox -d "Disable sandbox"
complete -c agent-native -n "not __fish_seen_subcommand_from claude codex gemini" -a "claude" -d "Run Claude Code"
complete -c agent-native -n "not __fish_seen_subcommand_from claude codex gemini" -a "codex" -d "Run Codex"
complete -c agent-native -n "not __fish_seen_subcommand_from claude codex gemini" -a "gemini" -d "Run Gemini CLI"

# agent-build completions
complete -c agent-build -s h -l help -d "Show help"
complete -c agent-build -s t -l tag -d "Image tag" -r
complete -c agent-build -s p -l push -d "Push to registry"

# agent-spawn completions
complete -c agent-spawn -s h -l help -d "Show help"
complete -c agent-spawn -s a -l agent -d "Agent to run" -r -a "claude codex gemini"
complete -c agent-spawn -s r -l revision -d "Base revision" -r
complete -c agent-spawn -s d -l dir -d "Workspaces directory" -r
complete -c agent-spawn -s c -l cpus -d "CPU count" -r
complete -c agent-spawn -s m -l memory -d "Memory limit" -r

# agent-cleanup completions
complete -c agent-cleanup -s h -l help -d "Show help"
complete -c agent-cleanup -s f -l force -d "Remove without confirmation"
