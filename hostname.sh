# Fetching the token for AWS metadata API
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetching the availability zone
AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Extracting the region from the availability zone (region is AZ minus the last character)
REGION="${AVAILABILITY_ZONE%?}"

# Fetching the AWS instance ID
AWS_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

HOSTNAME=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$AWS_INSTANCE_ID" "Name=key,Values=Name" --output text | cut -f5)
FORMATTED_HOSTNAME=$(echo $HOSTNAME | tr -d '()' | tr ' ' '-')

read -p "Change hostname to $FORMATTED_HOSTNAME? [Y/n] " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]
then
    echo "Setting new hostname: $FORMATTED_HOSTNAME"
    sudo hostnamectl set-hostname "$FORMATTED_HOSTNAME"

    exec bash
else
    echo "Hostname change declined."
fi