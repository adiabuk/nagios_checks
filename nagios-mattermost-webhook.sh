#!/bin/bash

# This script is used by Nagios to post alerts into a Slack channel
# using the Incoming WebHooks integration. Create the channel, botname
# and integration first and then add this notification script in your
# Nagios configuration.
#

# nagios-mattermost.sh - Webhook integration for slack & mattermost
# Copyright (C) 2017  Nathan Snow
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Initialize vars
versionNumber='1.0.0'
platform="slack"
webhookURL=""
webhookChannel=""
webhookUsername=""
webhookIcon="http://i.imgur.com/Eu91Ory.jpg"
webhookColor=""
nagiosHost=""
nagiosHostAlias=""
nagiosHostState=""
nagiosHostOutput=""
nagiosHostNotes=""
nagiosServiceDesc=""
nagiosServiceState=""
nagiosServiceOutput=""
nagiosServiceNotes=""
nagiosNotificationType=""
nagiosServiceOrHost=""

args=("$@")
usage="
If service:
    nagios-mattermost-webhook.sh
    --nagioshost        \$(echo \$HOSTNAME) (used to build the nagios link URLs. Must be your ngios host fqdn. Ex. nagios.example.com)
    --hostalias         \"\$HOSTNAME\$\"
    --servicedesc       \"\$SERVICEDESC\$\"
    --servicestate      \"\$SERVICESTATE\$\"
    --serviceoutput     \"\$SERVICEOUTPUT\$\"
    --servicenotes      \"\$SERVICENOTES\$\"
    --notificationtype  \"\$NOTIFICATIONTYPE\$\"
    --serviceorhost     service
    --webhookusername   <username>
    --webhookchannel    '<#channel>' (must use single quotes or escape the #)
    --webhookurl        http://<nagios or mattermost webhook url>
    --platform          Chat platform type: slack, synchat

If Host:
    nagios-mattermost-webhook.sh
    --nagioshost        \$(echo \$HOSTNAME) (used to build the nagios link URLs. Must be your ngios host fqdn. Ex. nagios.example.com)
    --hostalias         \"\$HOSTNAME\$\"
    --hoststate         \"\$HOSTSTATE\$\"
    --hostoutput        \"\$HOSTOUTPUT\$\"
    --hostnotes         \"\$HOSTNOTES\$\"
    --notificationtype  \"\$NOTIFICATIONTYPE\$\"
    --serviceorhost     host
    --webhookusername   <username>
    --webhookchannel    '<#channel>' (must use single quotes or escape the #)
    --webhookurl        http://<nagios or mattermost webhook url>
    --platform          Chat platform type: slack, synchat
"
version="
$0 - $versionNumber

$0  Copyright (C) 2017  Nathan Snow
This program comes with ABSOLUTELY NO WARRANTY; for details type 'less LICENSE.md'.
This is free software, and you are welcome to redistribute it.
"

debugMode=false
debugSwitch=""
for ((arg=0;arg<"${#args[@]}";arg++)); do
    [ "${args[$arg]}" == "-v" ] && debugMode=true && debugSwitch="${args[$arg]}"
done




# in bash functions have to be on top :/
# I set the log file to the tmp dir as peopel don't always install nagios in the same place.
# Also, it's another arg I'd have to pass if it were set up that way...
function Logger {
    if [ $debugMode = true ]; then
        for var in "$@"; do
    	    echo -e "${var}"
    	    echo -e "${var}" >> /tmp/nagios-mattermost-webhook.log
    	done
    fi
}
if [ $debugMode = true ]; then
    Logger "\n\n ------------------------------------------------" "$(date)"
fi




# Escape backslashes for incoming arguments. Without this alerts like "C:\ is critical" will break CURL below
# Post a bug on gitlab if other characters need to be escaped. I couldn't exactly find a list of characters curl doesn't like...
for ((arg=0;arg<"${#args[@]}";arg++)); do
    args[$arg]=$(sed 's.\\.\\\\.g' <<< ${args[$arg]})
    if [ $debugMode = true ]; then
        Logger "${args[$arg]}"
    fi
done

# Argument handler
for ((arg=0;arg<"${#args[@]}";arg++)); do
    [ "${args[$arg]}" == "--help" ] && echo -e "$usage" && exit
    [ "${args[$arg]}" == "--version" ] && echo -e "$version" && exit
    [ "${args[$arg]}" == "--webhookurl" ] && webhookURL=${args[$arg+1]}
    [ "${args[$arg]}" == "--platform" ] && platform=${args[$arg+1]}
    [ "${args[$arg]}" == "--webhookchannel" ] && webhookChannel=${args[$arg+1]}
    [ "${args[$arg]}" == "--webhookusername" ] && webhookUsername=${args[$arg+1]}
    [ "${args[$arg]}" == "--webhookiconurl" ] && webhookIcon=${args[$arg+1]}
    [ "${args[$arg]}" == "--nagioshost" ] && nagiosHost=${args[$arg+1]}
    [ "${args[$arg]}" == "--hostalias" ] && nagiosHostAlias=${args[$arg+1]}
    [ "${args[$arg]}" == "--hoststate" ] && nagiosHostState=${args[$arg+1]}
    [ "${args[$arg]}" == "--hostoutput" ] && nagiosHostOutput=${args[$arg+1]}
    [ "${args[$arg]}" == "--hostnotes" ] && nagiosHostNotes=${args[$arg+1]}
    [ "${args[$arg]}" == "--servicedesc" ] && nagiosServiceDesc=${args[$arg+1]}
    [ "${args[$arg]}" == "--servicestate" ] && nagiosServiceState=${args[$arg+1]}
    [ "${args[$arg]}" == "--serviceoutput" ] && nagiosServiceOutput=${args[$arg+1]}
    [ "${args[$arg]}" == "--servicenotes" ] && nagiosServiceNotes=${args[$arg+1]}
    [ "${args[$arg]}" == "--notificationtype" ] && nagiosNotificationType=${args[$arg+1]}
    [ "${args[$arg]}" == "--serviceorhost" ] && nagiosServiceOrHost=${args[$arg+1]}
done

# Determine if we are sending a host or service aelert
if [ "$nagiosServiceOrHost" == "host" ]; then

    #Set the message color based on Nagios host state
    if [ "$nagiosHostState" = "DOWN" ]; then
        webhookColor="#ff0000"
    elif [ "$nagiosHostState" = "UP" ]; then
        webhookColor="#008000"
    elif [ "$nagiosHostState" = "UNREACHABLE" ]; then
        webhookColor="#ffa500"
    else
        webhookColor="#0000ff"
    fi

    #Send message to Slack
    if [ "$platform" == "slack" ]; then
      curl -X POST \
      -H 'Content-type: application/json' --data \
      "{ \
          \"channel\": \"${webhookChannel}\", \
          \"username\": \"${webhookUsername}\", \
          \"icon_url\": \"${webhookIcon}\", \
          \"attachments\": [ \
              { \
                  \"fallback\": \"${nagiosNotificationType}: ${nagiosHostAlias} IS ${nagiosHostState} \n${nagiosHostOutput}\", \
                  \"color\": \"${webhookColor}\", \
                  \"text\": \"${nagiosHostOutput}\", \
                  \"author_name\": \"${nagiosHost}\", \
                  \"author_icon\": \"${webhookIcon}\", \
                  \"author_link\": \"http://${nagiosHost}/nagios\", \
                  \"title\": \"${nagiosNotificationType}: ${nagiosHostAlias} IS ${nagiosHostState}\", \
                  \"title_link\": \"http://${nagiosHost}/nagios/cgi-bin/status.cgi?host=${nagiosHostAlias}\" \
              } \
          ] \
      }" ${webhookURL} $debugSwitch
    elif [ "$platform" == 'synchat' ]; then
      curl -X POST \
      -H 'Content-type: application/json' --data \
      "payload={\
        \"text\": \"${nagiosNotificationType}: ${nagiosHostAlias} IS ${nagiosHostState} \n${nagiosHostOutput}\"
      }" ${webhookURL} $debugSwitch
    fi


elif [ "$nagiosServiceOrHost" == "service" ]; then

    #Set the message color based on Nagios service state
    if [ "$nagiosServiceState" = "CRITICAL" ]; then
        webhookColor="#ff0000"
    elif [ "$nagiosServiceState" = "WARNING" ]; then
        webhookColor="#ffa500"
    elif [ "$nagiosServiceState" = "OK" ]; then
        webhookColor="#008000"
    elif [ "$nagiosServiceState" = "UNKNOWN" ]; then
        webhookColor="#ffff00"
    else
        webhookColor="#0000ff"
    fi

    #Send message to Slack
    if [ "$platform" == "slack" ]; then
      curl -X POST \
      -H 'Content-type: application/json' --data \
      "{ \
          \"channel\": \"${webhookChannel}\", \
          \"username\": \"${webhookUsername}\", \
          \"icon_url\": \"${webhookIcon}\", \
          \"attachments\": [ \
              { \
                  \"fallback\": \"${nagiosNotificationType}: ${nagiosHostAlias} - ${nagiosServiceDesc} IS ${nagiosServiceState} \n${nagiosServiceOutput}\", \
                  \"color\": \"${webhookColor}\", \
                  \"text\": \"${nagiosServiceOutput}\", \
                  \"author_name\": \"${nagiosHost}\", \
                  \"author_icon\": \"${webhookIcon}\", \
                  \"author_link\": \"http://${nagiosHost}/nagios\", \
                  \"title\": \"${nagiosNotificationType}: ${nagiosHostAlias} - ${nagiosServiceDesc} IS ${nagiosServiceState}\", \
                  \"title_link\": \"http://${nagiosHost}/nagios/cgi-bin/status.cgi?host=${nagiosHostAlias}\" \
              } \
          ] \
      }" ${webhookURL} $debugSwitch
    elif [ "$platform" == 'synchat' ]; then
      curl -X POST \
      -H 'Content-type: application/json' --data \
      "payload={\
        \"text\": \"${nagiosNotificationType}: ${nagiosHostAlias} - ${nagiosServiceDesc} IS ${nagiosServiceState} \n${nagiosServiceOutput}\"
      }" ${webhookURL} $debugSwitch
    fi

else
    Logger "Please specify if this is a host or service alert with --serviceorhost"
    Logger "$usage"
fi

