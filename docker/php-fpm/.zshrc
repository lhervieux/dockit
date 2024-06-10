# Path to your oh-my-zsh installation.
export ZSH=/root/.oh-my-zsh

ZSH_THEME="kafeitu"
source $ZSH/oh-my-zsh.sh

alias composer='php -c /usr/local/etc/php/php-composer.ini /usr/local/bin/composer'

export COLUMNS=`tput cols`
export LINES=`tput lines`
