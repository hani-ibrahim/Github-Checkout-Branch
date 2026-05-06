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
# - If the requested branch is missing from cached origin refs, it can create
#   the branch and push it to origin.
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
        print -u2 -- "$i. $item"
        ((i++))
    done

    while true; do
        printf "%s" "$prompt" >&2
        if [[ ! -t 0 ]]; then
            print -P "%F{red}ERROR - Interactive selection requires a TTY%f" >&2
            return 1
        fi
        read -r choice || {
            print -P "%F{red}ERROR - Selection cancelled%f" >&2
            return 1
        }

        if [[ "$choice" =~ '^[0-9]+$' ]]; then
            if (( choice >= 1 && choice <= ${#items[@]} )); then
                echo "${items[$choice]}"
                return 0
            fi
        fi

        print -P "%F{red}ERROR - Please enter a valid number between 1 and ${#items[@]}%f"
    done
}

gco_select_branch_or_create() {
    local prompt="$1"
    local create_branch="$2"
    shift 2

    local -a items
    items=("$@")

    local i=1
    local choice=""

    for item in "${items[@]}"; do
        print -u2 -- "$i. $item"
        ((i++))
    done
    print -P -- "%F{green}c. Create a new branch \"$create_branch\"%f" >&2

    while true; do
        printf "%s" "$prompt" >&2
        if [[ ! -t 0 ]]; then
            print -P "%F{red}ERROR - Interactive selection requires a TTY%f" >&2
            return 1
        fi
        read -r choice || {
            print -P "%F{red}ERROR - Selection cancelled%f" >&2
            return 1
        }

        if [[ "$choice" =~ '^[0-9]+$' ]]; then
            if (( choice >= 1 && choice <= ${#items[@]} )); then
                echo "${items[$choice]}"
                return 0
            fi
        elif [[ "${choice:l}" == "c" || "${choice:l}" == "create" ]]; then
            echo "__GCO_CREATE__"
            return 0
        fi

        print -P "%F{red}ERROR - Please enter a valid number, c, or create%f"
    done
}

gco_confirm_create_only() {
    local create_branch="$1"
    local choice=""

    print -P "%F{yellow}No matching branch found in cached origin refs.%f" >&2
    print -P -- "%F{green}c. Create a new branch \"$create_branch\"%f" >&2

    printf "Please select an option: " >&2
    if [[ ! -t 0 ]]; then
        print -P "%F{red}ERROR - Interactive selection requires a TTY%f" >&2
        return 1
    fi
    read -r choice || {
        print -P "%F{red}ERROR - Selection cancelled%f" >&2
        return 1
    }

    if [[ "${choice:l}" == "c" || "${choice:l}" == "create" ]]; then
        return 0
    fi

    print -P "%F{red}ERROR - Branch creation cancelled%f" >&2
    return 1
}

gco_normalize_create_branch_name() {
    local branch="$1"

    emulate -L zsh
    setopt extendedglob

    branch="${branch//[^[:alnum:]_-]##/-}"
    branch="${branch//-##/-}"
    branch="${branch##-}"
    branch="${branch%%-}"
    echo "$branch"
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

gco_get_default_branch_name() {
    local mode="$1"
    local git_dir="$2"
    local default_branch=""

    if [[ "$mode" == "worktree" ]]; then
        default_branch="$(
            git --git-dir="$git_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null \
            | sed 's#^origin/##'
        )"
    else
        default_branch="$(
            git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null \
            | sed 's#^origin/##'
        )"
    fi

    if [[ -n "$default_branch" ]]; then
        echo "$default_branch"
        return 0
    fi

    git branch --show-current 2>/dev/null
}

gco_get_current_branch_name() {
    git branch --show-current 2>/dev/null
}

gco_branch_ref_exists() {
    local mode="$1"
    local git_dir="$2"
    local ref="$3"

    if [[ "$mode" == "worktree" ]]; then
        git --git-dir="$git_dir" rev-parse --verify --quiet "$ref^{commit}" >/dev/null
    else
        git rev-parse --verify --quiet "$ref^{commit}" >/dev/null
    fi
}

gco_resolve_remote_branch_ref() {
    local mode="$1"
    local git_dir="$2"
    local branch="$3"
    local ref="refs/remotes/origin/$branch"

    if gco_branch_ref_exists "$mode" "$git_dir" "$ref"; then
        echo "$ref"
        return 0
    fi

    ref="refs/heads/$branch"
    if gco_branch_ref_exists "$mode" "$git_dir" "$ref"; then
        echo "$ref"
        return 0
    fi

    print -P "%F{red}ERROR - Base branch not found: $branch%f" >&2
    return 1
}

gco_select_base_from_entered_branch() {
    local mode="$1"
    local git_dir="$2"
    shift 2

    local -a cached_branches
    cached_branches=("$@")

    local branch_query=""
    printf "Enter base branch: " >&2
    if [[ ! -t 0 ]]; then
        print -P "%F{red}ERROR - Interactive selection requires a TTY%f" >&2
        return 1
    fi
    read -r branch_query || {
        print -P "%F{red}ERROR - Selection cancelled%f" >&2
        return 1
    }

    if [[ -z "$branch_query" ]]; then
        print -P "%F{red}ERROR - Base branch is empty%f" >&2
        return 1
    fi

    local -a matching_branches
    matching_branches=("${(@f)$(gco_match_query "$branch_query" "${cached_branches[@]}")}")
    matching_branches=("${(@)matching_branches:#}")

    if (( ${#matching_branches[@]} == 0 )); then
        print -P "%F{red}ERROR - Can't find the base branch in cached origin refs%f" >&2
        return 1
    fi

    local selected_base=""
    if (( ${#matching_branches[@]} == 1 )); then
        selected_base="${matching_branches[1]}"
    else
        print -P "%F{red}More than one base branch found:%f" >&2
        selected_base="$(gco_select_from_list "Please select a base branch: " "${matching_branches[@]}")" || return 1
    fi

    gco_resolve_remote_branch_ref "$mode" "$git_dir" "$selected_base"
}

gco_select_create_base_ref() {
    local mode="$1"
    local git_dir="$2"
    shift 2

    local -a cached_branches
    cached_branches=("$@")

    local default_branch=""
    local current_branch=""
    local choice=""

    default_branch="$(gco_get_default_branch_name "$mode" "$git_dir")"
    current_branch="$(gco_get_current_branch_name)"

    [[ -z "$default_branch" ]] && default_branch="<unknown>"
    [[ -z "$current_branch" ]] && current_branch="<none>"

    print -u2
    print -u2 -- "Which base branch should the new branch start from?"
    print -u2
    print -u2 -- "1. Default branch \"$default_branch\""
    print -u2 -- "2. Current branch \"$current_branch\""
    print -u2 -- "3. Enter branch"

    while true; do
        printf "Select base branch: " >&2
        if [[ ! -t 0 ]]; then
            print -P "%F{red}ERROR - Interactive selection requires a TTY%f" >&2
            return 1
        fi
        read -r choice || {
            print -P "%F{red}ERROR - Selection cancelled%f" >&2
            return 1
        }

        case "$choice" in
            1)
                if [[ "$default_branch" == "<unknown>" ]]; then
                    print -P "%F{red}ERROR - Default branch could not be detected%f" >&2
                    return 1
                fi
                gco_resolve_remote_branch_ref "$mode" "$git_dir" "$default_branch"
                return $?
                ;;
            2)
                if [[ "$current_branch" == "<none>" ]]; then
                    print -P "%F{red}ERROR - Current branch could not be detected%f" >&2
                    return 1
                fi
                echo "refs/heads/$current_branch"
                return 0
                ;;
            3)
                gco_select_base_from_entered_branch "$mode" "$git_dir" "${cached_branches[@]}"
                return $?
                ;;
        esac

        print -P "%F{red}ERROR - Please enter 1, 2, or 3%f" >&2
    done
}

gco_create_branch() {
    local mode="$1"
    local git_dir="$2"
    local branch="$3"
    shift 3

    local -a cached_branches
    cached_branches=("$@")

    if ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
        print -P "%F{red}ERROR - Invalid branch name: $branch%f" >&2
        return 1
    fi

    local base_ref=""
    base_ref="$(gco_select_create_base_ref "$mode" "$git_dir" "${cached_branches[@]}")" || return 1

    if [[ "$mode" == "worktree" ]]; then
        if git --git-dir="$git_dir" show-ref --verify --quiet "refs/heads/$branch"; then
            print -P "%F{red}ERROR - Local branch already exists: $branch%f" >&2
            return 1
        fi

        git --git-dir="$git_dir" branch --no-track "$branch" "$base_ref" || return 1
        git --git-dir="$git_dir" push -u origin "$branch" || return 1
    else
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            print -P "%F{red}ERROR - Local branch already exists: $branch%f" >&2
            return 1
        fi

        git branch --no-track "$branch" "$base_ref" || return 1
        git push -u origin "$branch" || return 1
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

    local query=""
    query="$(gco_normalize_create_branch_name "$*")"
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
    cached_branches=("${(@)cached_branches:#}")

    if (( ${#cached_branches[@]} == 0 )); then
        print -P "%F{red}ERROR - No cached origin branches found%f"
        print -P "%F{yellow}Run 'gcb' first to refresh remote branches.%f"
        return 1
    fi

    matching_branches=("${(@f)$(gco_match_query "$query" "${cached_branches[@]}")}")
    matching_branches=("${(@)matching_branches:#}")

    local selected_branch=""
    local create_branch=0

    if (( ${#matching_branches[@]} == 0 )); then
        gco_confirm_create_only "$query" || return 1
        selected_branch="$query"
        create_branch=1
    elif (( ${#matching_branches[@]} == 1 )); then
        selected_branch="${matching_branches[1]}"
    else
        print -P "%F{red}More than one branch found:%f"
        selected_branch="$(gco_select_branch_or_create "Please select a branch: " "$query" "${matching_branches[@]}")" || return 1
        if [[ "$selected_branch" == "__GCO_CREATE__" ]]; then
            selected_branch="$query"
            create_branch=1
        fi
    fi

    if (( create_branch )); then
        gco_create_branch "$mode" "$git_dir" "$selected_branch" "${cached_branches[@]}" || return 1
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
        # Stale worktree metadata can point at a directory that was deleted.
        if [[ -n "$existing_path" ]]; then
            if [ -d "$existing_path" ]; then
                cd "$existing_path" || return 1
                pwd
                return 0
            fi

            print -P "%F{yellow}Stale worktree path found, pruning: $existing_path%f" >&2
            git --git-dir="$git_dir" worktree prune || return 1
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

        if (( ! create_branch )); then
            # Refresh/create the local branch from cached origin/<branch>.
            git --git-dir="$git_dir" branch -f "$selected_branch" "refs/remotes/origin/$selected_branch" || return 1
        fi

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
