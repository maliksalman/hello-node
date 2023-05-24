#!/bin/bash -x

APP_DOMAIN_PREFIX=samalik
APP_DOMAIN=apps.dhaka.cf-app.com
APP_NAME=hello-node

BLUE_APP=${APP_NAME}
GREEN_APP="${APP_NAME}-green"

# PUSH NEW APP WITH GREEN NAME AND GREEN ROUTE
echo "`date` - Pushing the GREEN version"
cf push ${GREEN_APP} -f manifest.yml --no-route
cf map-route ${GREEN_APP} ${APP_DOMAIN} --hostname ${APP_DOMAIN_PREFIX}-${GREEN_APP}

# HEALTH CHECK CURL TO GREEN ROUTE (LOOP WITH TIMEOUT - CHECK EVERY 15 SECONDS FOR 5 MINUTES)
APP_URL="https://${APP_DOMAIN_PREFIX}-${GREEN_APP}.${APP_DOMAIN}"

for i in {1..20}; do

    echo "`date` - Sleeping for 15 seconds before checking for GREEN app status"
    sleep 15

    GREEN_STATUS=$(curl -s ${APP_URL}/health | jq .status -r)
    if [ ! -z $GREEN_STATUS ] && [ 'UP' == $GREEN_STATUS ]
    then
        echo "`date` - The GREEN app is UP"
        break
    fi
done

if [ ! -z $GREEN_STATUS ] && [ 'UP' == $GREEN_STATUS ]
then

    # IF HEALTH CHECK PASSES, MAP ORIGINAL ROUTE TO GREEN APP WITH "cf map-route"
    cf map-route ${GREEN_APP} ${APP_DOMAIN} --hostname ${APP_DOMAIN_PREFIX}-${BLUE_APP}
    sleep 30

    # REMOVE GREEN ROUTE
    cf unmap-route ${GREEN_APP} ${APP_DOMAIN} --hostname ${APP_DOMAIN_PREFIX}-${GREEN_APP}

    # UNMAP BLUE ROUTE FROM BLUE APP SO BLUE ROUTE ONLY POINTS TO GREEN APP
    cf unmap-route ${BLUE_APP} ${APP_DOMAIN} --hostname ${APP_DOMAIN_PREFIX}-${BLUE_APP}
    sleep 30

    # TEAR DOWN BLUE APP
    cf delete ${BLUE_APP} -f

    # RENAME GREEN APP TO ORIGINAL APP NAME
    cf rename ${GREEN_APP} ${BLUE_APP}
else
    #  FAIL the script AND TEAR DOWN GREEN APP
    cf delete ${GREEN_APP} -r -f
    exit 1
fi
