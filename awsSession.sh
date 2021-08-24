#!/bin/bash

# The point of this script is to make it easier to make the session specified be the default session (won't override the session defined by environment)


function usage() {
  cat >&2 <<EOF
Usage: $(basename $0) [options... ] <operation>
Allows the ability to control the aws session information, either copying info from a named profile into the default, or to the session.

Options:
    -p The profile to copy the login info from, this is a friendly name. (defaults to dev) 
                    Excepted values [dev,prd]
    -P Like -p, but uses the exact string for the profile name
    -h Show this help text and exit


EOF
exit 0
}

function unsetAwsEnvVariables() {
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
}


while getopts ":hp:P:" opt; do
case "${opt}" in

  h) usage ;;
  p) "Not yet implemented, hard coded to dev" ;;
  P) "Not yet implemented, hard coded to the -p version of dev";;

  \?) echo >&2 -e "\n${scriptLogPrefix}Invalid option: -$OPTARG"; usage ;;
  *) usage;;

esac
done
shift $(($OPTIND - 1))

# Verify dependencies
command -v aws &> /dev/null || { echo >&2 "Missing dependency: \"aws\""; exit 1; }
# command -v getopts &> /dev/null || { echo >&2 "Missing dependency: \"aws\""; exit 1; }

credsFile="${HOME}/.aws/credentials"
configFile="${HOME}/.aws/config"

awsRegion="us-west-2"

defaultProfileName="default"
devProfileName='374217561360_Apollo-Cloudwatch-ReadOnly'

aws configure set --profile "${defaultProfileName}" region "${awsRegion}" || echo >&2 "Failed to update the default profile with the region"
aws configure set --profile "${devProfileName}" region "${awsRegion}" || { echo >&2 "Failed to set the region for profile: \"${devProfileName}\""; exit 1; }

unsetAwsEnvVariables

# Verify that if the desired profile is used, the command will work
testCommand="aws logs describe-log-groups --profile ${devProfileName}"
${testCommand} 2>&1 > /dev/null || { echo >&2 "Failed the configuration, tested with command: \"${testCommand}\""; exit 1; }

# Read in the credentials file, looking for the line that has the desired profile name
foundProfile="false"
cat "${credsFile}" | while read line; do

  # If the desired profile is found, start reading lines
  if [[ "${line}" == "[${devProfileName}]" ]]; then 
    echo "Found the profile: ${devProfileName}"
    # Read in all the lines until getting to the end of the file or the next profile (starts with a "[")
    foundProfile="true"
    continue
  fi

  if echo "${line}" | grep -q '\['; then
    echo "Done parsing the config settings."
    foundProfile="false"
    break
  fi

  if [[ "${foundProfile}" == "true" ]]; then

    key="$(echo ${line} | cut -f 1 -d '=')"
    value="$(echo ${line} | cut -f 2 -d '=')"

    if [[ "x" != "${key}x" ]]; then

      [[ "${key}" == "aws_access_key_id" ]] && echo "Using aws key id: ${value}"
      [[ "${key}" != "aws_access_key_id" ]] && echo "Other config value: $(echo ${value} | cut -c -4)$(echo ${value} | cut -c 4-15 | sed -e 's/./\./g')"

      aws configure --profile "default" set "${key}" "${value}"
    fi
  fi
done;

# Check if the command works with default profile
testCommand="aws --profile ${defaultProfileName} logs describe-log-groups"
${testCommand} 2>&1 > /dev/null && echo "Successfully configured with profile: \"${devProfileName}\" as the default profile." || 
  { echo >&2 "Failed the configuration, tested with command: \"${testCommand}\""; exit 1; }
