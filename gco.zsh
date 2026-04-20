#!/bin/zsh
#
# Git Checkout / Worktree helper
#
# This helper supports two modes:
#
# 1) Worktree workspace mode
#    - The workspace root contains a shared bare repo in ".bare"
#    - Each branch is opened as its own worktree folder
#
#    Example layout:
#      /path/to/workspace/
#      ├── .bare
#      ├── main
#      ├── develop
#      └── release/4.5.6
#
# 2) Normal repo mode
#    - The current directory is a regular Git repository
#    - The selected branch is checked out in the current repo
#
# Branch discovery:
#
# - Branch search uses the cached remote-tracking refs in `origin/*`
# - This is intended to work together with `gcb`, which refreshes those refs
# - Exact match wins first
# - Otherwise a case-insensitive partial match is used
#
# Examples:
#
#   gco main
#     -> in worktree mode: open/create ./main
#     -> in normal repo mode: switch current repo to main
#
#   gco release
#     -> if multiple branches match, show a list and ask you to choose
#
# Notes:
#
# - This helper expects `gcb` to refresh `origin/*` refs first.
# - If the requested branch is missing from cached origin refs, it will ask you
#   to run `gcb`.
#

unalias gco 2>/dev/null

gco_select_from_list() {
    local prompt="$1"
    shift

    local -a items
    items=("$@")

    if (( ${#items[@]} == 0 )); then
        return 1
    fi

    local i=1
    local choice=""

    for item in "${items[@]}"; do
        echo "$i. $item"
        ((i++))
    done

    while true; do
        printf "%s" "$prompt"
        read choice

        if [[ "$choice" =~ '^[0-9]+$' ]]; then
            if (( choice >= 1 && choice <= ${#items[@]} )); then
                echo "${items[$choice]}"
                return 0
            fi
        fi

        print -P "%F{red}ERROR - Please enter a valid number between 1 and ${#items[@]}%f"
    done
}

gco_match_query() {
    local query="$1"
    shift

    local -a items exact_matches partial_matches
    items=("$@")

    local item=""
    for item in "${items[@]}"; do
        [[ -z "$item" ]] && continue

        if [[ "$item" == "$query" ]]; then
            exact_matches+=("$item")
        elif [[ "${item:l}" == *"${query:l}"* ]]; then
            partial_matches+=("$item")
        fi
    done

    if (( ${#exact_matches[@]} > 0 )); then
        printf '%s\n' "${exact_matches[@]}"
    else
        printf '%s\n' "${partial_matches[@]}"
    fi
}

gco_detect_mode() {
    local root=""
    local git_dir=""
    local common_dir=""

    # Worktree workspace root
    if [ -d ".bare" ]; then
        echo "worktree"
        echo "$PWD"
        echo "$PWD/.bare"
        return 0
    fi

    # Inside any git repo or worktree
    if common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
        case "$(basename "$common_dir")" in
            .bare)
                echo "worktree"
                echo "$(dirname "$common_dir")"
                echo "$common_dir"
                return 0
                ;;
            .git)
                echo "normal"
                echo ""
                echo ""
                return 0
                ;;
        esac
    fi

    print -P "%F{red}ERROR - Not inside a git repository%f" >&2
    return 1
}

gco_get_cached_origin_branches_worktree() {
    local git_dir="$1"

    git --git-dir="$git_dir" for-each-ref refs/remotes/origin --format='%(refname:strip=3)' \
    | grep -v '^HEAD$'
}

gco_get_cached_origin_branches_normal() {
    git for-each-ref refs/remotes/origin --format='%(refname:strip=3)' \
    | grep -v '^HEAD$'
}

gco_get_worktree_path_for_branch() {
    local git_dir="$1"
    local branch="$2"

    git --git-dir="$git_dir" worktree list --porcelain \
    | awk -v branch="refs/heads/$branch" '
        $1 == "worktree" { path = substr($0, 10) }
        $1 == "branch" && $2 == branch { print path; exit }
    '
}

gco() {
    if (( $# == 0 )); then
        print -P "%F{red}ERROR - Please enter a branch name%f"
        return 1
    fi

    local query="$1"
    local -a detected
    local mode=""
    local root=""
    local git_dir=""

    detected=("${(@f)$(gco_detect_mode)}") || return 1
    mode="${detected[1]}"
    root="${detected[2]}"
    git_dir="${detected[3]}"

    local -a cached_branches matching_branches

    if [[ "$mode" == "worktree" ]]; then
        cached_branches=("${(@f)$(gco_get_cached_origin_branches_worktree "$git_dir")}")
    else
        cached_branches=("${(@f)$(gco_get_cached_origin_branches_normal)}")
    fi

    if (( ${#cached_branches[@]} == 0 )); then
        print -P "%F{red}ERROR - No cached origin branches found%f"
        print -P "%F{yellow}Run 'gcb' first to refresh remote branches.%f"
        return 1
    fi

    matching_branches=("${(@f)$(gco_match_query "$query" "${cached_branches[@]}")}")

    if (( ${#matching_branches[@]} == 0 )); then
        print -P "%F{red}ERROR - Can't find the branch in cached origin refs%f"
        print -P "%F{yellow}Run 'gcb' first if the branch was created recently.%f"
        return 1
    fi

    local selected_branch=""
    if (( ${#matching_branches[@]} == 1 )); then
        selected_branch="${matching_branches[1]}"
    else
        print -P "%F{red}More than one branch found:%f"
        selected_branch="$(gco_select_from_list "Please select a branch: " "${matching_branches[@]}")" || return 1
    fi

    if [[ -z "$selected_branch" ]]; then
        print -P "%F{red}ERROR - Selected branch is empty%f"
        return 1
    fi

    #
    # Worktree workspace mode
    #
    if [[ "$mode" == "worktree" ]]; then
        local target_path="$root/$selected_branch"
        local existing_path=""

        existing_path="$(gco_get_worktree_path_for_branch "$git_dir" "$selected_branch")"

        # If the branch is already checked out in an existing worktree, go there.
        if [[ -n "$existing_path" ]]; then
            cd "$existing_path" || return 1
            pwd
            return 0
        fi

        # If the target path already exists, allow it only if it is already a git worktree.
        if [ -e "$target_path" ]; then
            if git -C "$target_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                cd "$target_path" || return 1
                pwd
                return 0
            else
                print -P "%F{red}ERROR - Target path already exists and is not a valid worktree: $target_path%f"
                return 1
            fi
        fi

        mkdir -p "$(dirname "$target_path")" || return 1

        # Refresh/create the local branch from cached origin/<branch>.
        git --git-dir="$git_dir" branch -f "$selected_branch" "refs/remotes/origin/$selected_branch" || return 1

        # Create and open the worktree.
        git --git-dir="$git_dir" worktree add "$target_path" "$selected_branch" || return 1

        cd "$target_path" || return 1
        pwd
        return 0
    fi

    #
    # Normal repo mode
    #
    # If the local branch exists already, switch to it.
    if git show-ref --verify --quiet "refs/heads/$selected_branch"; then
        git switch "$selected_branch" 2>/dev/null || git checkout "$selected_branch"
        return $?
    fi

    # Otherwise create/reset the local branch from cached origin/<branch> and switch to it.
    git branch -f "$selected_branch" "refs/remotes/origin/$selected_branch" || return 1
    git switch "$selected_branch" 2>/dev/null || git checkout "$selected_branch"
}