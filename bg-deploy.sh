#!/bin/bash -e

APP_NAME=hello-node
APP_DOMAIN=apps.dhaka.cf-app.com

APP_DOMAIN_PREFIX=$1
if [ -z $APP_DOMAIN_PREFIX ]
then
    echo "Usage: $0 <app-domain-prefix>"
    exit 1
fi
BLUE_APP=${APP_NAME}
GREEN_APP="${APP_NAME}-green"

echo "This script will blue/green deploy with following URLs:"
echo
echo "    BLUE: https://${APP_DOMAIN_PREFIX}-${BLUE_APP}.${APP_DOMAIN}"
echo "    GREEN: https://${APP_DOMAIN_PREFIX}-${GREEN_APP}.${APP_DOMAIN}"
echo
read -p "Are you sure you want to continue? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Nn]$ ]]
then
    exit 0
fi

# push new app with green name and green route
echo "`date` - Pushing the GREEN version"
cf push ${GREEN_APP} -f manifest.yml --no-route
cf map-route ${GREEN_APP} ${APP_DOMAIN} --hostname ${APP_DOMAIN_PREFIX}-${GREEN_APP}

# healthcheck using green route (loop with timeout - check every 5 seconds for 2 minutes)
APP_URL="https://${APP_DOMAIN_PREFIX}-${GREEN_APP}.${APP_DOMAIN}"

for i in {1..24}; do

    echo "`date` - Sleeping for 5 seconds before checking for GREEN app status"
    sleep 5

    GREEN_STATUS=$(curl -s ${APP_URL}/health | jq .status -r)
    if [ ! -z $GREEN_STATUS ] && [ 'UP' == $GREEN_STATUS ]
    then
        echo "`date` - The GREEN app is UP"
        break
    fi
done

# conditional on HEALTHCHECK passing
if [ ! -z $GREEN_STATUS ] && [ 'UP' == $GREEN_STATUS ]
then

    # unmap and delete the green route
    cf unmap-route ${GREEN_APP} ${APP_DOMAIN} --hostname ${APP_DOMAIN_PREFIX}-${GREEN_APP}
    cf delete-route ${APP_DOMAIN} --hostname ${APP_DOMAIN_PREFIX}-${GREEN_APP} -f

    # map blue route to green app
    cf map-route ${GREEN_APP} ${APP_DOMAIN} --hostname ${APP_DOMAIN_PREFIX}-${BLUE_APP}
    sleep 15

    # unmap blue route from blue app so blue route only points to green app
    cf unmap-route ${BLUE_APP} ${APP_DOMAIN} --hostname ${APP_DOMAIN_PREFIX}-${BLUE_APP}
    sleep 15

    # tear down blue app
    cf delete ${BLUE_APP} -f

    # rename green app to blue app name
    cf rename ${GREEN_APP} ${BLUE_APP}
else
    #  fail the script and tear down green app/route
    cf delete ${GREEN_APP} -r -f
    exit 1
fi
