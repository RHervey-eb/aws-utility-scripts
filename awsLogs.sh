#!/bin/bash

# This script is to make it easier to start the logging for the different services, mostly by providing friendly names to the different 
#   services to watch.

# Sample command that works well to make it easier to read (note the \ followed by the next line is part of the command)
## awslogs get tango-org-client-account-manager-dev --start='1m' | cut -d ' ' -f 3- | jq  -r '.log' | grep '^{' | jq '.' | sed -e 's/\\t/  /g' -e 's/\\n/\
##/g'

# Verify dependencies
command -v aws &> /dev/null || { echo >&2 "Missing dependency: \"aws\""; exit 1; }
command -v cw &> /dev/null || { echo >&2 "Missing dependency: \"cw\", for info please go to: https://www.lucagrulla.com/cw/"; exit 1; }

# Verify that if the desired profile is used, the command will work
testCommand="aws logs describe-log-groups"
${testCommand} 2>&1 > /dev/null || { echo >&2 "Aws session isn't set, tested with command: \"${testCommand}\". Please setup using the script awsSession.sh"; exit 1; }

helloWorldGroup='tango-organization-client-hello-world-base'
adiosWorldGroup='tango-organization-client-adios-world-base'
accountManagerGroup='tango-org-client-account-manager'


function usage() {
  cat >&2 <<EOF
  Usage: $(basename $0) [options... ] <appName> <environment> (defaults to dev)

  App names available:
    * helloWorld (or "hello")
    * adiosWorld (or "adios")
    * accountManager (or "actMgr")

  Env names available
    * dev
    * qat
    * prd

EOF
}

# $1 - (required) the log group name to aggregate logs from
function activateLogging() {

  if [[ $# < 3 ]]; then
    echo >&2 "The required # of arguments of 3 to activateLogging wasn't met."
    return 1;
  fi

  shortName="${1}"
  groupName="${2}"
  envName="${3}"
  awslogsArgs="${4}"

  oldLine="";
  awslogs get -S -G --watch ${awslogsArgs} "${groupName}-${envName}"  | while read -r line; do 
    if [[ "${line}" == "${oldLine}" ]]; then continue; fi
    logStatement=$(jq -r '.log' <<< $line | grep '^{')
    echo -e "${shortName}-${envName} -> ${logStatement}"
    oldLine="${line}"
  done
  return 0
}

case "${1}" in
  "helloWorld" | "hello") activateLogging "${1}" "${helloWorldGroup}" "${2}" "${3}" ;;
  "adiosWorld" | "adios") activateLogging "${1}" "${adiosWorldGroup}" "${2}" "${3}" ;;
  "accountManager" | "actMgr") activateLogging "${1}" "${accountManagerGroup}" "${2}" "${3}" ;;

  *) echo "Didn't find the group listed: ${1}"; usage ;;
esac
