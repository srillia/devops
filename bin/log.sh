#!/bin/bash

set +e
set -o noglob

#
# Set Colors
#

bold=; underline=; reset=; red=; green=; white=; tan=; blue=;
#echo "the value of TERM is ${TERM}"
if test ! dumb = "${TERM}" ; then
	bold=$(tput bold)
	underline=$(tput sgr 0 1)
	reset=$(tput sgr0)
	red=$(tput setaf 1)
	green=$(tput setaf 76)
	white=$(tput setaf 7)
	tan=$(tput setaf 3)
	blue=$(tput setaf 25)
fi

#
# Headers and Logging
#

function underline() { printf "${underline}${bold}%s${reset}\n" "$@"
}
function h1() { printf "\n${underline}${bold}${blue}%s${reset}\n" "$@"
}
function h2() { printf "\n${underline}${bold}${white}%s${reset}\n" "$@"
}
function debug() { printf "${white}%s${reset}\n" "$@"
}
function info() { printf "${white}➜ %s${reset}\n" "$@"
}
function success() { printf "${green}✔ %s${reset}\n" "$@"
}
function error() { printf "${red}✖ %s${reset}\n" "$@"
}
function warn() { printf "${tan}➜ %s${reset}\n" "$@"
}
function bold() { printf "${bold}%s${reset}\n" "$@"
}
function note() { printf "\n${underline}${bold}${blue}Note:${reset} ${blue}%s${reset}\n" "$@"
}

set -e
set +o noglob

#h1 '测试h1'
#h2 '测试h2'
#debug '测试debug'
#bold '测试bold'
#note '测试note'
#underline '测试underline'


#warn '测试一个warn日志'
#success '测试一个sucess日志'
#info '测试一个info日志'
#error '测试一个error日志'
