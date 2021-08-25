#!/bin/bash

###################################################
### Configuration variables
### Please uncomment and configure as appropriate.
###################################################

## *** REQUIRED Variables ***

# REQUIRED: AWS credentials to be used to provision the Cloudgate infrastructure.
#cloudgate_aws_profile=

# REQUIRED: AWS region for the Cloudgate deployment.
#aws_region=

# REQUIRED: Number of proxy instances to be deployed. Minimum 3.
#proxy_instance_count=

# REQUIRED: Name of the locally-generated key pair for the Cloudgate infrastructure specific to this deployment. Example: cloudgate-key-<enterprise_name>
#cloudgate_keypair_name=

## *** OPTIONAL Variables. Leave commented if you are happy with the defaults. ***

# OPTIONAL: IP ranges that must be allowed to connect to any instances within the Cloudgate VPC over SSH and HTTP (to view monitoring dashboards)
# Typically these are IP ranges (CIDRs) from trusted VPNs. Defaults to the Santa Clara VPC CIDR.
# Multiple CIDRs can be specified as a string containing a comma-separated list of elements, without whitespaces.
whitelisted_inbound_ip_ranges="38.99.104.112/28"

# OPTIONAL: IP ranges to which instances within the Cloudgate VPC must be able to connect.
# These can be destinations such as Astra, Dockerhub, AWS apt-get mirrors. Defaults to everything (unrestricted).
# Multiple CIDRs can be specified as a string containing a comma-separated list of elements, without whitespaces.
whitelisted_outbound_ip_ranges="0.0.0.0/0"

# OPTIONAL: First two octets of the CIDR used for the Cloudgate VPC (without trailing period).
# Must not overlap with user's VPC. Defaults to 172.18, which will result in CIDR 172.18.0.0/16.
# aws_cloudgate_vpc_cidr_prefix=
aws_cloudgate_vpc_cidr_prefix="172.18"

# OPTIONAL: AWS instance type to be used for each proxy. Defaults to c5.xlarge, almost always fine.
#proxy_instance_type=
proxy_instance_type="t2.micro"

# OPTIONAL: AWS instance type to be used for the monitoring server. Defaults to c5.2xlarge, almost always fine.
#monitoring_instance_type=
monitoring_instance_type="t2.large"

# OPTIONAL: Path to the locally-generated key pair for the Cloudgate infrastructure. Defaults to ~./ssh.
#cloudgate_public_key_localpath=

###################################################
### End of configuration variables
###################################################

###################################################
### Functions
###################################################
add_quotes_around_elements () {
  # Argument #1 is a comma-separated string containing multiple elements, each not surrounded by quotes
  # Usage: add_quotes_around_elements ", " "$cs_string_noquotes"

  # Break the provided comma-separated string into an array
  IFS=',' read -ra rt_tbls_arr <<< "$1"

  # Turn the array into a new comma-separated string with the elements surrounded by quotes
  local F=0
  cs_string_quotes=""
  for x in "${rt_tbls_arr[@]}"
    do
        if [[ F -eq 1 ]]
        then
            cs_string_quotes+=","
        else
            F=1
        fi
        cs_string_quotes+="\"$x\""
    done
    # "return" the value
    echo "${cs_string_quotes}"
}

check_required_vars_exist() {
    # Check that all required variables have been specified
    if [ -z "${cloudgate_aws_profile}" ] || [ -z "${aws_region}" ] || [ -z "${proxy_instance_count}" ] || [ -z "${cloudgate_keypair_name}" ];
    then
      return 1
    else
      return 0
    fi
}

build_terraform_var_str () {
  # Build the string containing all the variables to be passed to the Terraform command

  terraform_vars=" "

  terraform_vars+="-var \"cloudgate_aws_profile=${cloudgate_aws_profile}\" "
  terraform_vars+="-var \"aws_region=${aws_region}\" "
  terraform_vars+="-var \"proxy_instance_count=${proxy_instance_count}\" "
  terraform_vars+="-var \"cloudgate_keypair_name=${cloudgate_keypair_name}\" "

  if [ -n "${whitelisted_inbound_ip_ranges}" ]; then
      wl_inbound_var="-var 'whitelisted_inbound_ip_ranges=["
      wl_inbound_var+=$(add_quotes_around_elements "${whitelisted_inbound_ip_ranges}")
      wl_inbound_var+="]' "
      terraform_vars+="${wl_inbound_var}"
  fi

  if [ -n "${whitelisted_outbound_ip_ranges}" ]; then
      wl_outbound_var="-var 'whitelisted_outbound_ip_ranges=["
      wl_outbound_var+=$(add_quotes_around_elements "${whitelisted_outbound_ip_ranges}")
      wl_outbound_var+="]' "
      terraform_vars+="${wl_outbound_var}"
  fi

  if [ -n "${aws_cloudgate_vpc_cidr_prefix}" ]; then
      terraform_vars+="-var \"aws_cloudgate_vpc_cidr_prefix=${aws_cloudgate_vpc_cidr_prefix}\" "
  fi

  if [ -n "${proxy_instance_type}" ]; then
      terraform_vars+="-var \"proxy_instance_type=${proxy_instance_type}\" "
  fi

  if [ -n "${monitoring_instance_type}" ]; then
      terraform_vars+="-var \"monitoring_instance_type=${monitoring_instance_type}\" "
  fi

  if [ -n "${cloudgate_public_key_localpath}" ]; then
      terraform_vars+="-var \"cloudgate_public_key_localpath=${cloudgate_public_key_localpath}\" "
  fi

  echo "${terraform_vars}"
}

###################################################
### Main script
###################################################

cd ../terraform/aws/self-contained-deployment-root-aws || exit

echo "##################################"
echo "# Initialize Terraform ..."
echo "##################################"
echo
terraform init
echo

echo
echo "##################################"
echo "# Calculate the Terraform plan ..."
echo "##################################"
echo

$(check_required_vars_exist)
exit_code=$?
if [ "${exit_code}" != 0 ]; then
  echo "Missing required variables. Please specify all required variables before executing this script"
  exit "${exit_code}"
fi

tf_var_str=$(build_terraform_var_str)
echo "${tf_var_str}" > tf_latest_vars.txt
tf_plan_cmd_str="terraform plan ${tf_var_str} -out cloudgate_plan"
echo "Executing command:"
echo " ${tf_plan_cmd_str}"
echo
eval " ${tf_plan_cmd_str} "
echo

echo -n "Do you want to apply the plan and continue (yes or no)? "
echo
read -r yesno
if [[ "$yesno" == "yes" ]]; then
  echo
  echo "##################################"
  echo "# Apply the Terraform plan ..."
  echo "##################################"
  echo
  terraform apply cloudgate_plan

  echo "#### Command apply executed with arguments: " "${tf_var_str}"
fi

terraform output > cloudgate_output.txt

cp cloudgate_inventory ../../../ansible/

