# Github Checkout Branch
~/.bash_profile helper to checkout a git branch quickly 

##### Example
Given that we have the following branches:
- master
- develop
- release
- release-2.2
- ticket-104-fix-readme
- ticket-77-update-translations

Then:

| Command        | Response                                   | Note                     |
| :------------- | :----------------------------------------- | :----------------------- |
| `gco 2.2`      | `git checkout release-2.2`                   | Checkout branch directly |
| `gco dev`      | `git checkout develop`                       | Checkout branch directly |
| `gco 104`      | `git checkout ticket-104-fix-readme`         | Checkout branch directly |
| `gco ticket`   | ERROR - More than one branch found:<br>1. ticket-104-fix-readme<br>2. ticket-77-update-translations | Display list with the available branches |
| `gco ticket 2` | `git checkout ticket-77-update-translations` | Checkout branch directly |


# Usage

### You need to copy the function to your ~/.bash_profile

This function takes two argument the first one is part of the branch name you want to checkout,
and the second argument (optional) is the index of the found branch if there are more than one branch found

| Paramater | Type   | Status   | Description               |
| :-------- | :----- | :------- | :------------------------ |
| $1        | String | required | Part from the branch name |
| $2        | Int    | optional | Index of the branch you want to checkout if there are more than one branch found |

# License
MIT License
