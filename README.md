# Github Checkout Branch
~/.bash_profile helper to checkout a git branch quickly 

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

### You need to copy the function to your ~/.bash_profile

This function takes two argument the first one is part of the branch name you want to checkout,
and the second argument (optional) is the index of the found branch if there are more than one branch found

| Paramater | Type   | Status   | Description               |
| :-------- | :----- | :------- | :------------------------ |
| $1        | String | required | Part from the branch name |
| $2        | Int    | optional | Index of the branch you want to checkout if there are more than one branch found |

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
