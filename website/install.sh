#!/bin/sh
# Usage Desk source installer. Inspect this file before running it.
# Requires macOS 14+ and an installed Swift 6+ toolchain. No sudo or binary download.
set -eu

fail() {
    printf 'Usage Desk: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [ -n "${created_app:-}" ]; then rm -rf -- "$created_app"; fi
    if [ -n "${work_dir:-}" ]; then rm -rf -- "$work_dir"; fi
}

# Keep execution at the end so a truncated download cannot start installation.
main() {
    [ "$#" -eq 0 ] || fail 'This installer does not accept arguments.'
    [ "$(uname -s)" = Darwin ] || fail 'macOS is required.'
    [ "$(id -u)" -ne 0 ] || fail 'Run this command as your normal user, without sudo.'
    case "${HOME:-}" in
        /) fail 'A user home directory is required.' ;;
        /*) ;;
        *) fail 'An absolute user home directory is required.' ;;
    esac

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

    # Bump only after reviewing and testing a new source commit. Never execute a moving branch.
    source_commit=9366db3b03b1fde7513e1f317e66e454f6d866d2
    source_repository=https://github.com/NiKHiLkr23/usage-desk.git
    umask 077
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/usage-desk-install.XXXXXX")
    created_app=
    trap cleanup 0
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
    source_dir="$work_dir/source"
    mkdir "$source_dir"
    printf 'Downloading Usage Desk source (%s)…\n' "$source_commit"
    git -C "$source_dir" init -q
    git -C "$source_dir" remote add origin "$source_repository"
    GIT_TERMINAL_PROMPT=0 git -C "$source_dir" fetch -q --depth 1 origin "$source_commit" || fail 'Could not download the source from GitHub. Check your connection and try again.'
    git -C "$source_dir" checkout -q --detach FETCH_HEAD
    [ "$(git -C "$source_dir" rev-parse HEAD)" = "$source_commit" ] || fail 'Downloaded source did not match the expected commit.'

    printf 'Building on your Mac. This can take several minutes…\n'
    zsh "$source_dir/scripts/build.sh" || fail 'The build failed. Nothing was installed.'
    built_app="$source_dir/dist/Usage desk.app"
    [ -d "$built_app" ] || fail 'The build did not produce an app.'
    codesign --verify --strict "$built_app" || fail 'The local app signature could not be verified.'

    mkdir -p "$install_dir"
    # Atomic creation refuses an existing file, directory, or symlink, even if one appeared during the build.
    mkdir "$app_path" || fail 'Could not create the app folder. An existing installation may be present.'
    created_app="$app_path"
    ditto "$built_app" "$app_path" || fail 'Could not copy the app. The incomplete installation will be removed.'
    codesign --verify --strict "$app_path" || fail 'The installed app signature could not be verified.'
    created_app=

    printf '\nInstalled: %s\n' "$app_path"
    printf 'Open Usage desk from your home Applications folder.\n'
    printf 'The Codex CLI must also be installed and signed in with your ChatGPT account.\n'
    printf 'Setup: https://usage-desk.nikhilkr.in/#how-it-works\n'
}

main "$@"
