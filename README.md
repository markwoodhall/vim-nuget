## Purpose

To enable NuGet integration in vim.

## Installation

Install using your favourite plugin manager,
I use [vim-plug](https://github.com/junegunn/vim-plug)

`Plug 'markwoodhall/vim-nuget'`

## Requirements

vim-nuget makes use of [vim-webapi](https://github.com/mattn/webapi-vim) and [fzf.vim](https://github.com/junegunn/fzf.vim).

## Commands

`:SearchPackages query`

![search-packages](http://i.imgur.com/yGSHOj8.gif)

`:InstallPackage package` tab completion is available on the package name

![install-package](http://i.imgur.com/mDSiChI.gif)

## License
Copyright © Mark Woodhall. Distributed under the same terms as Vim itself. See `:help license`
