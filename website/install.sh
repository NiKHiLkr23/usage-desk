#!/bin/sh
# Usage Desk source installer. Inspect this file before running it.
# Requires macOS 14+ and an installed Swift 6+ toolchain. No sudo or binary download.
set -eu

stop_spinner() {
    if [ -n "${spinner_pid:-}" ]; then
        kill "$spinner_pid" 2>/dev/null || :
        wait "$spinner_pid" 2>/dev/null || :
        spinner_pid=
        printf '\r\033[K'
    fi
}

fail() {
    stop_spinner
    printf '\nUsage Desk: %s\n' "$*" >&2
    if [ -s "${log_file:-}" ]; then
        keep_log=1
        printf '\nRecent details:\n' >&2
        tail -n 30 "$log_file" >&2
        printf '\nFull install log: %s\n' "$log_file" >&2
    fi
    exit 1
}

cleanup() {
    stop_spinner
    if [ -n "${created_app:-}" ]; then rm -rf -- "$created_app"; fi
    if [ -n "${work_dir:-}" ]; then rm -rf -- "$work_dir"; fi
    if [ -n "${log_file:-}" ] && [ "${keep_log:-0}" -eq 0 ]; then rm -f -- "$log_file"; fi
}

start_step() {
    step_label=$1
    if [ "$animate" -eq 1 ]; then
        (
            trap - 0
            trap 'exit 0' INT TERM HUP
            while :; do
                for frame in '|' '/' '-' '\'; do
                    printf '\r  %s %s' "$frame" "$step_label"
                    sleep 0.12
                done
            done
        ) &
        spinner_pid=$!
    else
        printf '  … %s\n' "$step_label"
    fi
}

finish_step() {
    stop_spinner
    printf '  %s✓%s %s\n' "$green" "$reset" "$1"
}

run_step() {
    label=$1
    error=$2
    shift 2
    start_step "$label"
    if "$@" >> "$log_file" 2>&1; then
        finish_step "$label"
    else
        fail "$error"
    fi
}

download_source() {
    git -C "$source_dir" init -q &&
    git -C "$source_dir" remote add origin "$source_repository" &&
    GIT_TERMINAL_PROMPT=0 git -C "$source_dir" fetch -q --depth 1 origin "$source_commit" &&
    git -C "$source_dir" checkout -q --detach FETCH_HEAD
}

install_app() {
    mkdir -p "$install_dir" || return 1
    # Atomic creation refuses an existing file, directory, or symlink, even if one appeared during the build.
    mkdir "$app_path" || return 1
    created_app="$app_path"
    ditto "$built_app" "$app_path" && codesign --verify --strict "$app_path"
}

show_setup_link() {
    setup_url=https://usage-desk.nikhilkr.in/#how-it-works
    # Explicit hyperlinks only for known supporting terminals; retain the full URL everywhere.
    hyperlinks=0
    if [ "$terminal" -eq 1 ] && [ "${TERM:-dumb}" != dumb ]; then
        case "${TERM_PROGRAM:-}" in iTerm.app|WezTerm|vscode|ghostty) hyperlinks=1 ;; esac
        case "${TERM:-}" in xterm-kitty|wezterm) hyperlinks=1 ;; esac
        # Multiplexers may need passthrough settings; use plain text in those sessions.
        if [ -n "${TMUX:-}${STY:-}" ]; then hyperlinks=0; fi
    fi
    if [ "$hyperlinks" -eq 1 ]; then
        printf '  Setup guide: \033]8;;%s\033\\%s\033]8;;\033\\\n' "$setup_url" "$setup_url"
    else
        printf '  Setup guide: %s\n' "$setup_url"
        printf '  To open it: open "%s"\n' "$setup_url"
    fi
}

offer_launch() {
    # stdin belongs to the curl pipeline. Read only from a controlling terminal,
    # and never prompt or launch when stdout is redirected/non-interactive.
    if [ "$terminal" -eq 1 ] && { exec 3<>/dev/tty; } 2>/dev/null; then
        printf '\n  Open Usage Desk now? [Y/n] ' >&3
        answer=
        if IFS= read -r answer <&3; then
            case "$answer" in
                ''|y|Y|yes|Yes|YES)
                    if open "$app_path" >> "$log_file" 2>&1; then
                        printf '  Look for Usage Desk in your menu bar.\n'
                    else
                        printf '  Installed successfully, but the app could not be opened.\n'
                        printf '  Open Usage desk from your home Applications folder.\n'
                    fi ;;
                *) printf '  Open Usage desk from your home Applications folder when ready.\n' ;;
            esac
        else
            printf '\n  Open Usage desk from your home Applications folder when ready.\n'
        fi
        exec 3>&-
    else
        printf '\n  Open Usage desk from your home Applications folder when ready.\n'
    fi
}

# Keep execution at the end so a truncated download cannot start installation.
main() {
    spinner_pid=; created_app=; work_dir=; log_file=; keep_log=0
    [ "$#" -eq 0 ] || fail 'This installer does not accept arguments.'
    [ "$(uname -s)" = Darwin ] || fail 'macOS is required.'
    [ "$(id -u)" -ne 0 ] || fail 'Run this command as your normal user, without sudo.'
    case "${HOME:-}" in
        /) fail 'A user home directory is required.' ;;
        /*) ;;
        *) fail 'An absolute user home directory is required.' ;;
    esac

    terminal=0; animate=0; green=; bold=; reset=
    if [ -t 1 ]; then
        terminal=1
        if [ "${TERM:-dumb}" != dumb ]; then
            animate=1
            if [ -z "${NO_COLOR+x}" ]; then
                green=$(printf '\033[32m'); bold=$(printf '\033[1m'); reset=$(printf '\033[0m')
            fi
        fi
    fi
    trap cleanup 0
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
    printf '\n  ┌──────┐\n  │  ┌──────┐   %susage desk%s\n  └──│ %s━%s ─ ─│   Source installer\n     └──────┘\n\n' "$bold" "$reset" "$green" "$reset"
    start_step 'Checking Mac requirements'

    mac_version=$(sw_vers -productVersion)
    mac_major=${mac_version%%.*}
    case "$mac_major" in ''|*[!0-9]*) fail 'Could not identify the macOS version.' ;; esac
    [ "$mac_major" -ge 14 ] || fail 'macOS 14 or later is required.'
    xcode-select -p >/dev/null 2>&1 || fail 'Install Xcode Command Line Tools first: xcode-select --install. Then rerun this command.'
    swift_version=$(xcrun swift --version 2>/dev/null) || fail 'Swift is unavailable. Install Xcode Command Line Tools with Swift 6 or newer.'
    swift_major=$(printf '%s\n' "$swift_version" | sed -n 's/.*[Ss]wift version \([0-9][0-9]*\)\..*/\1/p' | head -n 1)
    case "$swift_major" in ''|*[!0-9]*) fail 'Could not identify the Swift version.' ;; esac
    [ "$swift_major" -ge 6 ] || fail 'Swift 6 or newer is required. Update Xcode Command Line Tools, then rerun this command.'
    for tool in git zsh ditto codesign; do
        command -v "$tool" >/dev/null 2>&1 || fail "Required tool is missing: $tool"
    done

    install_dir="$HOME/Applications"
    app_path="$install_dir/Usage desk.app"
    if [ -e "$app_path" ] || [ -L "$app_path" ]; then
        fail 'Usage desk.app already exists in ~/Applications. Quit the app and move that app to Trash before reinstalling. Account data is retained.'
    fi
    finish_step 'Mac requirements checked'

    # Bump only after reviewing and testing a new source commit. Never execute a moving branch.
    source_commit=8865ed7bdd176a8c184de156a16c91361ee897e1
    source_version=0.1.1
    source_repository=https://github.com/NiKHiLkr23/usage-desk.git
    umask 077
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/usage-desk-install.XXXXXX")
    log_file=$(mktemp "${TMPDIR:-/tmp}/usage-desk-install-log.XXXXXX")
    printf '  Installing Usage Desk %s from verified source.\n' "$source_version"
    printf 'Usage Desk version: %s\nSource commit: %s\n' "$source_version" "$source_commit" > "$log_file"
    source_dir="$work_dir/source"
    mkdir "$source_dir"
    run_step 'Downloading source' 'Could not download the source from GitHub. Check your connection and try again.' download_source
    [ "$(git -C "$source_dir" rev-parse HEAD 2>> "$log_file")" = "$source_commit" ] || fail 'Downloaded source did not match the expected commit.'
    downloaded_version=$(cat "$source_dir/VERSION" 2>> "$log_file") || fail 'Downloaded source is missing its version.'
    [ "$downloaded_version" = "$source_version" ] || fail 'Downloaded source did not match the expected app version.'

    printf '\n  Building locally. This may take several minutes.\n'
    run_step 'Building Usage Desk' 'The build failed. Nothing was installed.' zsh "$source_dir/scripts/build.sh"
    built_app="$source_dir/dist/Usage desk.app"
    [ -d "$built_app" ] || fail 'The build did not produce an app.'
    run_step 'Verifying the app' 'The local app signature could not be verified.' codesign --verify --strict "$built_app"
    run_step 'Installing to ~/Applications' 'Could not install or verify the app. Any incomplete installation will be removed.' install_app
    created_app=

    printf '\n  %sReady.%s Installed: %s\n' "$bold" "$reset" "$app_path"
    printf '  Connect Codex CLI (ChatGPT) or Claude Code CLI (Pro/Max) in Accounts.\n'
    show_setup_link
    offer_launch
    printf '\n'
}

main "$@"
