#!/bin/bash
# 
# Git Checkout branch
# 
# Takes two argument the first one is part of the branch name you want to checkout, 
# and the second argument (optional) is the index of the found branch if there are more than one branch found
# 
# $1 (required) - "Part from the branch name"
# $2 (optional) - "Index of the branch you want to checkout if there are more than one branch found"
# 
# 
# Examples
# 
# If we have these branches: 
# master, develop, release-2.2, release-hotfix
# 
# `gco master` --> checkout `master` branch directly
# `gco release` --> promot you with `release` & `release-hotfix` to choose from them
# `gco release 1` --> checkout `release` branch directly
# `gco release 2` --> checkout `release-hotfix` branch directly
# 
gco() {
    if (( ${#1} == 0 )); then
        echo -e "\033[0;31mERROR - Please enter a branch name\033[0m"
        return
    fi
    
    local branchNames=( `git branch -a | grep -v "\*\|\->" | sed "s/\'/\\\\\'/g" | sed 's/\"/\\\\\"/g' | grep -i "$1" | grep "remotes/origin/" | sed 's/remotes\/origin\///g' | xargs` )
    
    if (( ${#branchNames[@]} == 0 )); then
        echo -e "\033[0;31mERROR - Can't find the branch\033[0m"
    elif (( ${#branchNames[@]} > 1 )); then
        if [ ${2} ]; then
            numberRegrex='^[0-9]+$'
            if [[ $2 =~ $numberRegrex ]]; then # Test if number
                if (( $2 > 0 && $2 <= ${#branchNames[@]} )); then
                    local selectedBranch=${branchNames[$(($2-1))]}
                    echo `git checkout $selectedBranch`
                else
                    echo -e "\033[0;31mERROR - Out of bounds\033[0m\n"
                    gco $1
                fi
            else
                echo -e "\033[0;31mERROR - Please insert a number\033[0m\n"
                gco $1
            fi
        else
            echo -e "\033[0;31mERROR - More than one branch found:\033[0m"
            for i in "${!branchNames[@]}"; do
                echo "$(($i+1)). ${branchNames[$i]}"
            done
            read -p "Please select a branch: " selectedBranch
            gco $1 $selectedBranch
        fi
    else
        echo `git checkout ${branchNames[0]}`
    fi
}
