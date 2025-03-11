#!/bin/bash
# example
# ./process-mappings.sh -f org-mappings.csv -s https://gitlab.example.com -t https://github.example.com -m organization
#if an error is detected quit the script
set -e

while getopts f:m:s:t: flag
do
    case "${flag}" in
        f) mapping_file=${OPTARG};;
        s) userMappingSourceUrl=${OPTARG};;
        t) userMappingTargetUrl=${OPTARG};;
        m) model_name=${OPTARG};;
    esac
done


#Check for needed flags
if [ -z "$mapping_file" ]; then echo "-f, mapping_file variable needed" >&2; exit 1; fi
if [ -z "$userMappingSourceUrl" ]; then echo "-s, userMappingSourceUrl variable needed" >&2; exit 1; fi
if [ -z "$userMappingTargetUrl" ]; then echo "-t, userMappingTargetUrl variable needed" >&2; exit 1; fi
if [ -z "$model_name" ]; then echo "-m, model_name variable needed" >&2; exit 1; fi
if [[ $model_name != "user" && $model_name != "organization" ]]; then echo "model_name must be user or organization" >&2; exit 1; fi


# Read the mapping file into an associative array
#declare -a mapping
echo "model_name,source_url,target_url,state" > temp.csv
{ 
read
while IFS=, read -r source target || [[ -n "$source" ]]; do
    if [[ "$source" == *"_"* ]]; then
        source=${source//_/-}
    fi
    targetUrl="$userMappingTargetUrl/$target"
    if [[ $model_name == "user" ]]; then
        sourceUrl="$userMappingSourceUrl/$source"
        echo "user,$sourceUrl,$targetUrl,map_or_rename" 
    elif [[ $model_name == "organization" ]]; then
       sourceUrl="$userMappingSourceUrl/groups/$source"
        echo "organization,$sourceUrl,$targetUrl,map_or_rename"
    fi

    
done
} < $mapping_file >> temp.csv

mv "temp.csv" "new-${model_name}-mappings.csv"

echo "Done!"