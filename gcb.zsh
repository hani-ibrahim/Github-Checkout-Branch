#!/bin/zsh

unalias gcb 2>/dev/null

gcb() {
    local force_delete=0

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

        local -A remote_branch_map
        local rb=""
        for rb in "${remote_branches[@]}"; do
            remote_branch_map["$rb"]=1
        done

        local current_worktree=""
        current_worktree="$(pwd -P)"

        local wt_path=""
        local wt_branch=""
        local remove_reason=""

        while IFS=$'\t' read -r wt_path wt_branch; do
            [[ -z "$wt_path" || -z "$wt_branch" ]] && continue

            # Never remove the current worktree.
            if [[ "$wt_path" == "$current_worktree" ]]; then
                continue
            fi

            remove_reason=""

            # Remove if branch no longer exists on origin
            if [[ -z "${remote_branch_map[$wt_branch]}" ]]; then
                remove_reason="deleted on origin"
            # Remove if branch is merged into the remote default branch
            elif [[ -n "$default_remote_branch" ]]; then
                if git --git-dir="$git_dir" merge-base --is-ancestor \
                    "refs/heads/$wt_branch" "refs/remotes/$default_remote_branch" 2>/dev/null; then
                    remove_reason="merged into $default_remote_branch"
                fi
            fi

            if [[ -n "$remove_reason" ]]; then
                echo "Removing worktree: $wt_branch ($remove_reason)"
                if (( force_delete == 1 )); then
                    git --git-dir="$git_dir" worktree remove --force "$wt_path" || \
                        print -P "%F{yellow}WARNING - Failed to force-remove: $wt_path%f"
                else
                    git --git-dir="$git_dir" worktree remove "$wt_path" || \
                        print -P "%F{yellow}WARNING - Skipped dirty worktree: $wt_path (use gcb --force)%f"
                fi
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

        git --git-dir="$git_dir" worktree prune

        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            git pull --rebase
        else
            echo "Remote refs refreshed. Not inside a checked-out worktree, so no pull was run."
        fi

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

        git branch -d "$merged_branch" 2>/dev/null || git branch -D "$merged_branch"
    done < <(
        git for-each-ref refs/heads --merged="$default_branch" --format='%(refname:strip=2)'
    )

    git pull --rebase
}