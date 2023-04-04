#!/usr/bin/env bash

## @file alpine_package_pinner.bash
## @brief pin Alpine Linux versions for packages to a lock file
## @details
## This script will consume a text file (be default, 'apk.txt'),
## find the current package versions for each of the files in
## that list, and write a "lock" file consisting of those same
## packages, but with their versions included.
##
## The goal is to be able to provide a semi-static list of
## Alpine packages in a repository while also allowing one
## to capture and store the versions for those packages
## and store them, too, much like package.json and package-lock.json
## are used in Node
## @author Wes Dean

set -euo pipefail

## @var SCRIPT_PATH
## @brief path to where the script lives
declare SCRIPT_PATH
# shellcheck disable=SC2034
SCRIPT_PATH="${SCRIPT_PATH:-$(cd "$( dirname "${BASH_SOURCE[0]}")"  && pwd -P)}"

## @var LIBRARY_PATH
## @brief location where libraries to be included reside
declare LIBRARY_PATH
LIBRARY_PATH="${LIBRARY_PATH:-${SCRIPT_PATH}/lib/}"

## @var DEFAULT_BRANCH
## @brief the default package repository branch to query
declare DEFAULT_BRANCH
DEFAULT_BRANCH=""

## @var DEFAULT_INPUT_FILENAME
## @brief default file to read
declare DEFAULT_INPUT_FILENAME
DEFAULT_INPUT_FILENAME="${DEFAULT_INPUT_FILENAME:-apk.txt}"

## @var DEFAULT_OUTPUT_FILENAME
## @brief default file to write
declare DEFAULT_OUTPUT_FILENAME
DEFAULT_OUTPUT_FILENAME="${DEFAULT_OUTPUT_FILENAME:-apk-lock.txt}"

## @fn die
## @brief receive a trapped error and display helpful debugging details
## @details
## When called -- presumably by a trap -- die() will provide details
## about what happened, including the filename, the line in the source
## where it happened, and a stack dump showing how we got there.  It
## will then exit with a result code of 1 (failure)
## @retval 1 always returns failure
## @par Example
## @code
## trap die ERR
## @endcode
die() {
  printf "ERROR %s in %s AT LINE %s\n" "$?" "${BASH_SOURCE[0]}" "${BASH_LINENO[0]}" 1>&2

  local i=0
  local FRAMES=${#BASH_LINENO[@]}

  # FRAMES-2 skips main, the last one in arrays
  for ((i = FRAMES - 2; i >= 0; i--)); do
    printf "  File \"%s\", line %s, in %s\n" "${BASH_SOURCE[i + 1]}" "${BASH_LINENO[i]}" "${FUNCNAME[i + 1]}"
    # Grab the source code of the line
    sed -n "${BASH_LINENO[i]}{s/^/    /;p}" "${BASH_SOURCE[i + 1]}"
  done
  exit 1
}

## @fn display_usage
## @brief display some auto-generated usage information
## @details
## This will take two passes over the script -- one to generate
## an overview based on everything between the @file tag and the
## first blank line and another to scan through getopts options
## to extract some hints about how to use the tool.
## @retval 0 if the extraction was successful
## @retval 1 if there was a problem running the extraction
## @par Example
## @code
## for arg in "$@" ; do
##   shift
##   case "$arg" in
##     '--word') set -- "$@" "-w" ;;   ##- see -w
##     '--help') set -- "$@" "-h" ;;   ##- see -h
##     *)        set -- "$@" "$arg" ;;
##   esac
## done
##
## # process short options
## OPTIND=1
###
##
## while getopts "w:h" option ; do
##   case "$option" in
##     w ) word="$OPTARG" ;; ##- set the word value
##     h ) display_usage ; exit 0 ;;
##     * ) printf "Invalid option '%s'" "$option" 2>&1 ; display_usage 1>&2 ; exit 1 ;;
##   esac
## done
## @endcode
display_usage() {
  local overview
  overview="$(sed -Ene '
  /^[[:space:]]*##[[:space:]]*@file/,${/^[[:space:]]*$/q}
  s/[[:space:]]*@author/author:/
  s/^[[:space:]]*##([[:space:]]*@[^[[:space:]]*[[:space:]]*)*//p' < "$0")"

  local usage
  usage="$(
    ( 
      sed -Ene "s/^[[:space:]]*(['\"])([[:alnum:]]*)\1[[:space:]]*\).*##-[[:space:]]*(.*)/\-\2\t\t: \3/p" < "$0"
      sed -Ene "s/^[[:space:]]*(['\"])([-[:alnum:]]*)*\1[[:space:]]*\)[[:space:]]*set[[:space:]]*--[[:space:]]*(['\"])[@$]*\3[[:space:]]*(['\"])(-[[:alnum:]])\4.*##-[[:space:]]*(.*)/\2\t\t: \6/p" < "$0"
    ) | sort --ignore-case
  )"

  if [ -n "$overview" ]; then
    printf "Overview\n%s\n" "$overview"
  fi

  if [ -n "$usage" ]; then
    printf "\nUsage:\n%s\n" "$usage"
  fi
}

## @fn confirm_distribution()
## @brief determine if we're running the desired OS
## @details
## This will query /etc/os-release (or whatever's requested)
## for the 'ID' field (or whatever's requested) to see
## what distribution is running.
# @param desired_distribtion the Linux distro we want (default is Alpine)
## @retval 0 (True) if we're running the desired distro
## @retval 1 (False) otherwise
## @par Example
## @code
## if confirm_distribtion desired_distribution="Ubuntu" ; then
##   apt-get install -fy bash
## elif confirm_distribution desired_distribtion="Alpine" ; then
##   apk add bash
## else
##   echo "Good luck with that!" 1>&2
##   exit 1
## fi
## @endcode
confirm_distribution() {

  local "$@"

  desired_distribution="${desired_distribution:-Alpine}"
  os_release_filename="${os_release_filename:-/etc/os-release}"

  id="$(get_distribution os_release_filename="${os_release_filename}")"

  if [[ "${id,,}" =~ ${desired_distribution,,} ]]; then
    return 0
  else
    return 1
  fi

}

## @fn get_distribution()
## @brief get the distribution that's running
## @details
## This fetches the distribution that's running, such as 'Alpine' or
## 'Ubuntu' and returns is via STDOUT.
## @param os_release_filename the file to query (default is /etc/os-release)
## @param os_id_field if field to find (default is ID)
## @retval 0 if the query was able to run
## @retval 1 if the query failed
## @par Example
## @code
## echo "You're running '$(get_distribtion)'!"
## @endcode
get_distribution() {

  local "$@"

  os_release_filename="${os_release_filename:-/etc/os-release}"
  os_id_field="${os_id_field:-ID}"

  sed -Ene "s/^${os_id_field}[[:space:]]*=[[:space:]]*(.*)/\1/p" "${os_release_filename}"
}

## @fn get_alpine_release()
## @brief determine the Alpine release that's running
## @details
## This fetches the release version of the operating system.  Currently,
## it returns the major and minor release levels and truncates the patch
## level.  As a result, this works well for Alpine, but not Ubuntu, for
## example.  Therefore, if we determine that we're not running Alpine,
## we quit here and now.  Otherwise (e.g., we're running Alpine),
## we return the release via STDOUT.
## @param os_release_filename the file to query (default is /etc/os-release)
## @retval 0 (True) if we found the Alpine release
## @retval 1 (False) if something went wrong (e.g., not running Alpine)
## @par Example
## @code
## echo "This is Alpine '$(get_alpine_release)'."
## @endcode
get_alpine_release() {

  local "$@"

  os_release_filename="${os_release_filename:-/etc/os-release}"

  if ! confirm_distribution \
    desired_distribtion="Alpine" \
    os_release_filename="${os_release_filename}"; then
    echo "This system is running not running '${desired_distribution}'" 1>&2
    return 1
  fi

  sed -Ene 's/^VERSION_ID[[:space:]]*=[[:space:]]*([[:digit:]]+)\.([[:digit:]]+).*/v\1.\2/p' "${os_release_filename}"
}

## @fn get_package_version()
## @brief given a package name, return the current version
## @details
## This function takes several parameters, constructs a URL corresponding
## to a querty of the Alpine package website, fetches it, and parses the
## output to determine the current version of the specified package.
## The package version is written to STDOUT.
## @param os_release_filename the file to query (default is /etc/os-release)
## @param package_name name of the package to query (REQUIRED)
## @param branch Alpine release to query (default is LSB's VERSION_ID)
## @param arch archectture (defaults to current system's architecture)
## @param repo repository (defaults to any repo; could be main, communit)
## @param maintainer package maintainer (defaults to any maintainer)
## @retval 0 (True) if the package was found
## @retval 1 (False) if the query failed (e.g., missing package)
## @par Example
## @code
## get_package_version branch="v3.17" package_name="nginx"
## @endcode
get_package_version() {

  local "$@"

  os_release_filename="${os_release_filename:-/etc/os-release}"

  branch="$(validate_branch_name branch="${branch}" os_release_filename="${os_release_filename}")"

  package_name="${package_name?No package name specified}"
  arch="${arch:-$(uname -m)}"
  repo="${repo:-}"
  maintainer="${maintainer:-}"

  if [ -z "$branch" ]; then
    echo "Could not determine Alpine version." 1>&2
    return 1
  fi

  url="https://pkgs.alpinelinux.org/packages?name=${package_name}&branch=${branch}&${repo}=&arch=${arch}&maintainer=${maintainer}"

  curl -s "$url" | xmllint --html --xpath '//td[@class="version"]/text()' - 2> /dev/null
}

## @fn validate_branch_name()
## @brief make sure the branch name starts with 'v' if needed
## @details
## The API looks for branch names like 'v3.17' or 'edge', so passing a
## branch named "3.17" (as how it looks in a Dockerfile) looks like it
## would work, but it doesn't -- it results in a URL that returns a 404
## from the API which causes `curl -s` to fail silently which is a PITA
## to track down.  Also, we can't blindly put a 'v' in front of every
## branch name because 'edge' is a legitimate branch name we many need
## to query.  Therefore, if the branch name starts with a digit, we'll
## prepend a 'v' to it; otherwise, we leave it alone.  Also, if we get
## no branch name, we'll attempt to find it.
##
## The validated branch name is returned via STDOUT.
## @param branch the name of the branch to check
## @param os_release_filename the file to query (default is /etc/os-release)
## @retval 0 (True) if we could return something
## @retval 1 (False) if something went wrong
## @par Example
## @code
## branch="$(validate_branch_name "${branch}")"
## @endcode
validate_branch_name() {

  local "$@"

  os_release_filename="${os_release_filename:-/etc/os-release}"

  branch="${branch:-$(get_alpine_release os_release_filename="${os_release_filename}")}"

  if [[ $branch =~ ^[[:digit:]] ]]; then
    branch="v${branch}"
  fi

  echo "${branch}"
}

###
### If there is a library directory (lib/) relative to the
### script's location by default), then attempt to source
### the *.bash files located there.
###

if [ -n "${LIBRARY_PATH}" ] \
  && [ -d "${LIBRARY_PATH}" ]; then
  for library in "${LIBRARY_PATH}"*.bash; do
    if [ -e "${library}" ]; then
      # shellcheck disable=SC1090
      . "${library}"
    fi
  done
fi

## @fn main()
## @brief This is the main program loop.
## @details
## This is where the logic for the program lives; it's
## called when the script is run as a script (i.e., not
## when it's sourced or included).
main() {

  trap die ERR

  ###
  ### set values from their defaults here
  ###

  branch="${DEFAULT_BRANCH}"
  input_filename="${DEFAULT_INPUT_FILENAME}"
  output_filename="${DEFAULT_OUTPUT_FILENAME}"

  ###
  ### process long options here
  ###

  for arg in "$@"; do
    shift
    case "$arg" in
      '--branch')  set -- "$@" "-b" ;; ##- see -b
      '--help') set -- "$@" "-h" ;;   ##- see -h
      '--input') set -- "$@" "-i" ;;   ##- see -i
      '--output') set -- "$@" "-o" ;;   ##- see -o
      *)        set -- "$@" "$arg" ;;
    esac
  done

  ###
  ### process short options here
  ###

  OPTIND=1
  while getopts "b:i:o:h" opt; do
    case "$opt" in
      'b')  branch="$OPTARG" ;;                 ##- set the branch
      'i')  input_filename="$OPTARG" ;;         ##- set the file to read
      'o')  output_filename="$OPTARG" ;;        ##- set the file to write
      'h')
            display_usage
                            exit 0
                                   ;; ##- view the help documentation
      *)
         printf "Invalid option '%s'" "$opt" 1>&2
                                                    display_usage 1>&2
                                                                         exit 1
                                                                                ;;
    esac
  done

  shift "$((OPTIND - 1))"

  ###
  ### program logic goes here
  ###

  tmpfile="$(mktemp -p "${TMPDIR:-/tmp/}")"

  echo "tmpfile = '$tmpfile'" 1>&2

  while read -r package; do
    package_name="$(echo "${package}" | sed -Ee 's/[[:space:]=].*//')"
    package_version="$(get_package_version "${package_name}")"

    if [ -n "${package_version}" ]; then
      echo "${package_name}=${package_version}" >> "${tmpfile}"
    fi
  done < "${input_filename}"

  if [ -s "$tmpfile" ]; then
    mv -f "${tmpfile}" "${output_filename}"
  else
    rm -f "${tmpfile}"
  fi

}

# if we're not being sourced and there's a function named `main`, run it
[[ "$0" == "${BASH_SOURCE[0]}" ]] && [ "$(type -t "main")" = "function" ] && main "$@"
