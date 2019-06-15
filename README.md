# Github Checkout Branch
terminal helper to checkout a git branch quickly 

### Example
Given that we have the following branches:
- master
- develop
- release
- release-2.2
- ticket-104-fix-readme
- ticket-77-update-translations

#### Then:

| Command        | Response                                   | Note                     |
| :------------- | :----------------------------------------- | :----------------------- |
| `gco 2.2`      | `git checkout release-2.2`                   | Checkout branch directly |
| `gco dev`      | `git checkout develop`                       | Checkout branch directly |
| `gco 104`      | `git checkout ticket-104-fix-readme`         | Checkout branch directly |
| `gco ticket`   | ERROR - More than one branch found:<br>1. ticket-104-fix-readme<br>2. ticket-77-update-translations | Display list with the available branches |
| `gco ticket 2` | `git checkout ticket-77-update-translations` | Checkout branch directly |


# Usage

This function takes two argument the first one is part of the branch name you want to checkout,
and the second argument (optional) is the index of the found branch if there are more than one branch found

| Paramater | Type   | Status   | Description               |
| :-------- | :----- | :------- | :------------------------ |
| $1        | String | required | Part from the branch name |
| $2        | Int    | optional | Index of the branch you want to checkout if there are more than one branch found |

# Installation

## Install for bash terminal

1. clone repo
```sh
git clone git@github.com:hani-ibrahim/Github-Checkout-Branch.git ~/Desktop/Github-Checkout-Branch
cd ~/Desktop/Github-Checkout-Branch
```
2. copy `gco.sh` to home directory 
```sh
cp gco.sh ~/.gco.sh
```
3. source `gco.sh` into your `bash_profile` file
```sh
echo "source ~/.gco.sh" >> ~/.bash_profile
```
4. refresh `bash_profile` file
```sh
. ~/.bash_profile
```
5. (optional) delete the repo
```sh
rm -rf ~/Desktop/Github-Checkout-Branch
```

## Install for zsh terminal

1. clone repo
```sh
git clone git@github.com:hani-ibrahim/Github-Checkout-Branch.git ~/Desktop/Github-Checkout-Branch
cd ~/Desktop/Github-Checkout-Branch
```
2. copy `gco.zsh` to home directory 
```sh
cp gco.zsh ~/.gco.zsh
```
3. source `gco.zsh` into your `zshrc` file
```sh
echo "source ~/.gco.zsh" >> ~/.zshrc
```
4. refresh `zshrc` file
```sh
. ~/.zshrc
```
5. (optional) delete the repo
```sh
rm -rf ~/Desktop/Github-Checkout-Branch
```

# License
MIT License

> Copyright (c) 2017 Hani Ibrahim
> 
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
> 
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.
