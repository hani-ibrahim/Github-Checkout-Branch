#!/bin/zsh
# 
# Git WorkTree
# 
# Checkout the found branch in a work tree
# Clone the repo with "--bare" to create an empty folder
# Example: `git clone --bare git@github.com:your-org/your-repo.git .bare`
#
# Then you can use `gwt` from the same folder or any nested folder and it will create a working tree for that branch if it didn't exsits and go to it.
#
# The script takes two argument the first one is part of the branch name you want to checkout, 
# and the second argument (optional) is the index of the found branch if there are more than one branch found
# 
# $1 (required) - "Part from the branch name"
# $2 (optional) - "Index of the branch you want to checkout if there are more than one branch found"
# 
# 
# Examples
# 
# If we have these branches: 
# main, develop, release-2.2, release-hotfix
# 
# `gwt main` --> checkout `main` branch directly
# `gwt release` --> promot you with `release` & `release-hotfix` to choose from them
# `gwt release 1` --> checkout `release` branch directly
# `gwt release 2` --> checkout `release-hotfix` branch directly
# 
unalias gwt 2>/dev/null
gwt() {
    if (( $# == 0 )); then
        print -P "%F{red}ERROR - Please enter a branch name%f"
        return 1
    fi

    local query="$1"
    local selection="$2"
    local root=""
    local git_dir=""
    local common_dir=""

    if [ -d "$PWD/.bare" ]; then
        root="$PWD"
        git_dir="$root/.bare"
    elif common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
        case "$(basename "$common_dir")" in
            .bare|.git)
                root="$(dirname "$common_dir")"
                git_dir="$common_dir"
                ;;
            *)
                print -P "%F{red}ERROR - Could not determine workspace root%f"
                return 1
                ;;
        esac
    else
        print -P "%F{red}ERROR - Not inside a worktree, and no .bare repo found in the current folder%f"
        return 1
    fi

    if [ ! -d "$git_dir" ]; then
        print -P "%F{red}ERROR - Shared git directory not found at: $git_dir%f"
        return 1
    fi

    git --git-dir="$git_dir" fetch --all --prune >/dev/null 2>&1

    local -a allBranches matches
    allBranches=("${(@f)$(git --git-dir="$git_dir" for-each-ref refs/heads --format='%(refname:strip=2)')}")

    if (( ${#allBranches[@]} == 0 )); then
        print -P "%F{red}ERROR - No branches found%f"
        return 1
    fi

    local b
    for b in "${allBranches[@]}"; do
        [[ -z "$b" ]] && continue
        if [[ "$b" == "$query" ]]; then
            matches=("$b")
            break
        elif [[ "${(L)b}" == *"${(L)query}"* ]]; then
            matches+=("$b")
        fi
    done

    if (( ${#matches[@]} == 0 )); then
        print -P "%F{red}ERROR - Can't find the branch%f"
        return 1
    fi

    local selectedBranch=""
    if (( ${#matches[@]} == 1 )); then
        selectedBranch="${matches[1]}"
    else
        if [ -n "$selection" ]; then
            if [[ "$selection" =~ '^[0-9]+$' ]]; then
                if (( selection >= 1 && selection <= ${#matches[@]} )); then
                    selectedBranch="${matches[$selection]}"
                else
                    print -P "%F{red}ERROR - Out of bounds%f"
                    return 1
                fi
            else
                print -P "%F{red}ERROR - Please insert a number%f"
                return 1
            fi
        else
            print -P "%F{red}More than one branch found:%f"
            local i=1
            for b in "${matches[@]}"; do
                echo "$i. $b"
                ((i++))
            done
            printf "Please select a branch: "
            read selection
            gwt "$query" "$selection"
            return $?
        fi
    fi

    if [[ -z "$selectedBranch" ]]; then
        print -P "%F{red}ERROR - Selected branch is empty%f"
        return 1
    fi

    local targetPath="$root/$selectedBranch"
    local existingPath=""

    existingPath="$(
        git --git-dir="$git_dir" worktree list --porcelain \
        | awk -v branch="refs/heads/$selectedBranch" '
            $1 == "worktree" { path = substr($0, 10) }
            $1 == "branch" && $2 == branch { print path; exit }
        '
    )"

    if [ -n "$existingPath" ]; then
        cd "$existingPath" || return 1
        pwd
        return 0
    fi

    if [ -e "$targetPath" ]; then
        if git -C "$targetPath" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            cd "$targetPath" || return 1
            pwd
            return 0
        else
            print -P "%F{red}ERROR - Target path already exists and is not a valid worktree: $targetPath%f"
            return 1
        fi
    fi

    mkdir -p "$(dirname "$targetPath")" || return 1

    git --git-dir="$git_dir" worktree add "$targetPath" "$selectedBranch" || return 1

    cd "$targetPath" || return 1
    pwd
}
