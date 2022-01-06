cd /rds/homes/r/rothcarv/covidtracker_surgery/

curl "https://api.coronavirus.data.gov.uk/v2/data?areaType=overview&metric=hospitalCases&format=csv" --output coronavirus.csv

python3 20220106_process_number_cases.py