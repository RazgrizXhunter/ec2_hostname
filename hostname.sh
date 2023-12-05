#!/bin/bash

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it and configure it before running this script."
    exit 1
fi

# Fetching the token for AWS metadata API
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetching the availability zone
AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Extracting the region from the availability zone (region is AZ minus the last character)
REGION="${AVAILABILITY_ZONE%?}"

# Fetching the AWS instance ID
AWS_INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Attempt to fetch instance tags to check if metadata tags are enabled
TEST_TAGS=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance)

# Check if fetching tags was successful
if [[ $TEST_TAGS == *"<Code>NotFound</Code>"* ]]; then
    # Metadata tags are not enabled, prompt to enable
    read -p "Instance metadata tags are not enabled. Enable them now? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        aws ec2 modify-instance-metadata-options --instance-id $AWS_INSTANCE_ID --instance-metadata-tags enabled
        echo "Enabled access to instance metadata tags."
        # Wait for changes to take effect
        sleep 10
    else
        echo "Metadata tags not enabled. Script will exit."
        exit 1
    fi
else
    echo "Instance metadata tags are already enabled."
fi

# Fetching the hostname tag
RAW_HOSTNAME_TAG=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$AWS_INSTANCE_ID" "Name=key,Values=Name" --output text | tr ' ' '-' | tr -d ',')

# Extracting the hostname value from the tag output
HOSTNAME=$(echo $RAW_HOSTNAME_TAG | awk '{print $5}')

# Check if the hostname was retrieved and format it
if [ -z "$HOSTNAME" ]; then
    echo "No 'Name' tag found for this instance. Skipping hostname change."
    exit 1
else
    FORMATTED_HOSTNAME=$(echo $HOSTNAME | tr -d '()' | tr ' ' '-')
    # Prompt for hostname change
    read -p "Change hostname to $FORMATTED_HOSTNAME? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo "Setting new hostname: $FORMATTED_HOSTNAME"
        sudo hostnamectl set-hostname "$FORMATTED_HOSTNAME"
        exec bash
    else
        echo "Hostname change declined."
    fi
fi
