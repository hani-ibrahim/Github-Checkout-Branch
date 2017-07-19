#!/bin/bash

# Git Checkout branch
#
# Takes two argument the first one is part of the branch name you want to checkout, 
# and the second argument (optional) is the index of the found branch if there are more than one branch found
#
# $1 (required) - "Part from the branch name"
# $2 (optional) - "Index of the branch you want to checkout if there are more than one branch found"
#
# Examples
#
# If we have these branches: 
# master, develop, release-2.2, release-hotfix
#
# "goc master" --> checkout master branch directly
# "goc release" --> promot you with `release` & `release-hotfix` to choose from them
# "goc release 1" --> checkout release branch directly
# "goc release 2" --> checkout release-hotfix branch directly 
#
# Note: you need to copy the function to your ~/.bash_profile
#
gco() {
    if (( ${#1} == 0 )); then
        echo -e "\033[0;31mERROR - Please enter branch name\033[0m"
        return
    fi

    local branchesName=`git branch -a | grep -v \* | sed "s/\'/\\\\\'/g" | sed 's/\"/\\\\\"/g' | grep "$1" | grep "remotes/origin/" | sed 's/remotes\/origin\///g' | xargs`
    read -a branchesNameArray <<<$branchesName
    
    if (( ${#branchesNameArray[@]} == 0 )); then
        echo -e "\033[0;31mERROR - Cann't find the branch\033[0m"
    elif (( ${#branchesNameArray[@]} > 1 )); then
        if [ ${2} ]; then
            numberRegrex='^[0-9]+$'
            if [[ $2 =~ $numberRegrex ]]; then # Test if number
                if (( $2 > 0 && $2 <= ${#branchesNameArray[@]} )); then
                    local selectedBranch=${branchesNameArray[$(($2-1))]}
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
            for i in "${!branchesNameArray[@]}"; do
                echo "$(($i+1)). ${branchesNameArray[$i]}"
            done
            read -p "Please select a brach: " selectedBranch
            gco $1 $selectedBranch
        fi
    else
        echo `git checkout ${branchesNameArray[0]}`
    fi
}
