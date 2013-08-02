echo $(curl --silent https://api.forecast.io/forecast/$(cat ~/.forecastIoKey)/34.128745,-117.872696 | jq ' 
.currently.temperature, 
.currently.humidity, 
.currently.summary, 
.hourly.summary, 
.daily.data[0].sunriseTime, 
.daily.data[0].sunsetTime, 
.daily.data[1].temperatureMin, 
.daily.data[1].temperatureMinTime, 
.daily.data[1].temperatureMax, 
.daily.data[1].temperatureMaxTime, 
.daily.data[1].sunriseTime, 
.daily.data[1].summary, 
.daily.summary 
') \
| gsed -e 's/\(\$(\)\|`//g' \
| (read meh \
&& eval set -- $meh && temp=$(printf %0.0f $1) && humid=$(printf %0.0f $(bc <<< "$2 * 100")) && current=$3 soon=$4 sunrise=$5 sunset=$6 tomorrowLow=$(printf %0.0f $7) tomorrowLowTime=$(date -r $8 +%H:%M) tomorrowHigh=$(printf %0.0f $9) tomorrowHighTime=$(date -r ${10} +%H:%M) tomorrowSunrise=$(date -r ${11} +%H:%M) tomorrow=${12} week=${13} \
&& echo $current ${temp}F ${humid}%, $soon \
&& echo Tomorrow \| ${tomorrowLow}@[${tomorrowLowTime}]-${tomorrowHigh}@[$tomorrowHighTime] Sunrise[${tomorrowSunrise}] \
&& echo "         | ${tomorrow}" \
&& echo $week 
)


