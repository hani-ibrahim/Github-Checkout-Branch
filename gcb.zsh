#!/bin/zsh

unalias gcb 2>/dev/null

gcb() {
    local force_delete=0
    local log_prefix=""
    local log_branch=""
    local log_message=""
    local -a checked_out_branches

    log_branch_status() {
        log_prefix="$1"
        log_branch="$2"
        log_message="$3"
        print -r -- "[$log_prefix] $log_branch - $log_message"
    }

    branch_exists_on_origin() {
        git --git-dir="$git_dir" show-ref --verify --quiet "refs/remotes/origin/$1"
    }

    branch_is_checked_out() {
        local branch_name_to_find="$1"
        local checked_out_branch=""

        for checked_out_branch in "${checked_out_branches[@]}"; do
            if [[ "$checked_out_branch" == "$branch_name_to_find" ]]; then
                return 0
            fi
        done

        return 1
    }

    if [[ "$1" == "--force" || "$1" == "-f" ]]; then
        force_delete=1
        shift
    fi

    local root=""
    local git_dir=""
    local common_dir=""
    local mode="normal"

    # Detect worktree workspace vs normal repo.
    if [ -d "$PWD/.bare" ]; then
        mode="worktree"
        root="$PWD"
        git_dir="$root/.bare"
    elif common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
        case "$(basename "$common_dir")" in
            .bare)
                mode="worktree"
                root="$(dirname "$common_dir")"
                git_dir="$common_dir"
                ;;
            .git)
                mode="normal"
                ;;
            *)
                print -P "%F{red}ERROR - Could not determine repository type%f"
                return 1
                ;;
        esac
    else
        print -P "%F{red}ERROR - Not inside a git repository%f"
        return 1
    fi

    if [[ "$mode" == "worktree" ]]; then
        # Keep a normal remote-tracking cache under refs/remotes/origin/*
        git --git-dir="$git_dir" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" || return 1

        # Refresh and prune stale remote-tracking refs
        git --git-dir="$git_dir" fetch origin --prune || return 1
        git --git-dir="$git_dir" worktree prune >/dev/null 2>&1

        # Refresh origin/HEAD so we know the remote default branch
        git --git-dir="$git_dir" remote set-head origin -a >/dev/null 2>&1

        local default_remote_branch=""
        default_remote_branch="$(
            git --git-dir="$git_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null
        )"

        local -a remote_branches
        remote_branches=("${(@f)$(
            git --git-dir="$git_dir" for-each-ref refs/remotes/origin --format='%(refname:strip=3)' \
            | grep -v '^HEAD$'
        )}")
        local default_branch_name="${default_remote_branch#origin/}"

        local wt_path=""
        local wt_branch=""
        local branch_name=""
        local branch_delete_reason=""
        local wt_status=""
        local wt_upstream=""
        local pull_output=""

        checked_out_branches=("${(@f)$(
            git --git-dir="$git_dir" worktree list --porcelain \
            | awk '
                $1 == "branch" {
                    branch = $2
                    sub(/^refs\/heads\//, "", branch)
                    print branch
                }
            '
        )}")

        while IFS= read -r branch_name; do
            [[ -z "$branch_name" ]] && continue
            branch_is_checked_out "$branch_name" && continue

            branch_delete_reason=""

            if ! branch_exists_on_origin "$branch_name"; then
                branch_delete_reason="deleted on origin"
            elif [[ -n "$default_remote_branch" && "$branch_name" != "$default_branch_name" ]]; then
                if git --git-dir="$git_dir" merge-base --is-ancestor \
                    "refs/heads/$branch_name" "refs/remotes/$default_remote_branch" 2>/dev/null; then
                    branch_delete_reason="merged into $default_remote_branch"
                fi
            fi

            if [[ -n "$branch_delete_reason" ]]; then
                if git --git-dir="$git_dir" branch -D "$branch_name" >/dev/null 2>&1; then
                    log_branch_status "DELETE" "$branch_name" "$branch_delete_reason"
                else
                    log_branch_status "WARN" "$branch_name" "failed to delete ($branch_delete_reason)"
                fi
            fi
        done < <(
            git --git-dir="$git_dir" for-each-ref refs/heads --format='%(refname:strip=2)'
        )

        while IFS=$'\t' read -r wt_path wt_branch; do
            [[ -z "$wt_path" || -z "$wt_branch" ]] && continue

            if [[ ! -d "$wt_path" ]]; then
                continue
            fi

            if ! branch_exists_on_origin "$wt_branch"; then
                log_branch_status "SKIP" "$wt_branch" "deleted on origin"
                continue
            fi

            wt_status="$(git -C "$wt_path" status --porcelain 2>/dev/null)"
            if [[ -n "$wt_status" ]]; then
                log_branch_status "SKIP" "$wt_branch" "uncommitted changes"
                continue
            fi

            wt_upstream="$(git -C "$wt_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
            if [[ -z "$wt_upstream" ]]; then
                log_branch_status "SKIP" "$wt_branch" "no upstream configured"
                continue
            fi

            pull_output="$(git -C "$wt_path" pull --rebase 2>&1)"
            if [[ $? -eq 0 ]]; then
                if [[ "$pull_output" == *"Already up to date."* ]]; then
                    log_branch_status "OK" "$wt_branch" "already up to date"
                else
                    log_branch_status "OK" "$wt_branch" "updated"
                fi
            else
                log_branch_status "WARN" "$wt_branch" "failed to update"
            fi
        done < <(
            git --git-dir="$git_dir" worktree list --porcelain \
            | awk '
                $1 == "worktree" { path = substr($0, 10) }
                $1 == "branch" {
                    branch = $2
                    sub(/^refs\/heads\//, "", branch)
                    print path "\t" branch
                }
            '
        )

        git --git-dir="$git_dir" worktree prune >/dev/null 2>&1
        return 0
    fi

    # Normal repo mode
    git fetch origin --prune || return 1

    # Try to determine the remote default branch name from origin/HEAD.
    git remote set-head origin -a >/dev/null 2>&1

    local default_branch=""
    default_branch="$(
        git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##'
    )"

    if [[ -z "$default_branch" ]]; then
        default_branch="$(git branch --show-current)"
    fi

    local current_branch=""
    current_branch="$(git branch --show-current)"

    # Delete local branches merged into the default branch, excluding the current branch and the default branch itself.
    local merged_branch=""
    while IFS= read -r merged_branch; do
        [[ -z "$merged_branch" ]] && continue
        [[ "$merged_branch" == "$current_branch" ]] && continue
        [[ "$merged_branch" == "$default_branch" ]] && continue

        if git branch -d "$merged_branch" >/dev/null 2>&1 || git branch -D "$merged_branch" >/dev/null 2>&1; then
            log_branch_status "DELETE" "$merged_branch" "merged into $default_branch"
        else
            log_branch_status "WARN" "$merged_branch" "failed to delete"
        fi
    done < <(
        git for-each-ref refs/heads --merged="$default_branch" --format='%(refname:strip=2)'
    )

    local repo_status=""
    repo_status="$(git status --porcelain 2>/dev/null)"
    if [[ -n "$repo_status" ]]; then
        log_branch_status "SKIP" "$current_branch" "uncommitted changes"
        return 0
    fi

    local repo_pull_output=""
    repo_pull_output="$(git pull --rebase 2>&1)"
    if [[ $? -eq 0 ]]; then
        if [[ "$repo_pull_output" == *"Already up to date."* ]]; then
            log_branch_status "OK" "$current_branch" "already up to date"
        else
            log_branch_status "OK" "$current_branch" "updated"
        fi
    else
        log_branch_status "WARN" "$current_branch" "failed to update"
        return 1
    fi
}
