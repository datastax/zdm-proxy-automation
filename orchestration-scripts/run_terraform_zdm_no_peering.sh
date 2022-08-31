#!/bin/bash

###################################################
### Configuration variables
### Please uncomment and configure as appropriate.
###################################################

## *** REQUIRED Variables ***

# REQUIRED: AWS credentials to be used to provision the ZDM infrastructure.
#zdm_aws_profile=

# REQUIRED: AWS region for the ZDM deployment.
#zdm_aws_region=

# REQUIRED: Number of proxy instances to be deployed. Minimum 3.
#zdm_proxy_instance_count=

# REQUIRED: Name of the locally-generated key pair for the ZDM infrastructure specific to this deployment. Example: zdm-key-<enterprise_name>
#zdm_keypair_name=

## *** OPTIONAL Variables. Leave commented if you are happy with the defaults. ***

# OPTIONAL: IP ranges that must be allowed to connect to any instances within the ZDM VPC over SSH and HTTP (to view monitoring dashboards)
# Typically these are IP ranges (CIDRs) from trusted VPNs. Defaults to the Santa Clara VPC CIDR.
# Multiple CIDRs can be specified as a string containing a comma-separated list of elements, without whitespaces.
whitelisted_inbound_ip_ranges="38.99.104.112/28"

# OPTIONAL: IP ranges to which instances within the ZDM VPC must be able to connect.
# These can be destinations such as Astra, Dockerhub, AWS apt-get mirrors. Defaults to everything (unrestricted).
# Multiple CIDRs can be specified as a string containing a comma-separated list of elements, without whitespaces.
whitelisted_outbound_ip_ranges="0.0.0.0/0"

# OPTIONAL: First two octets of the CIDR used for the ZDM VPC (without trailing period).
# Must not overlap with user's VPC. Defaults to 172.18, which will result in CIDR 172.18.0.0/16.
# zdm_vpc_cidr_prefix=
zdm_vpc_cidr_prefix="172.18"

# OPTIONAL: Suffix to append to the name of each resource that is being provisioned.
# This can be useful to distinguish the resources of different deployments in the same region.
# Defaults to an empty string.
#custom_name_suffix=

# OPTIONAL: AWS instance type to be used for each ZDM proxy. Defaults to c5.xlarge, almost always fine.
#zdm_proxy_instance_type=

# OPTIONAL: AWS instance type to be used for the ZDM monitoring server. Defaults to c5.2xlarge, almost always fine.
#zdm_monitoring_instance_type=

# OPTIONAL: Path to the locally-generated key pair for the ZDM infrastructure. Defaults to ~./ssh.
#zdm_public_key_local_path=

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
    if [ -z "${zdm_aws_profile}" ] || [ -z "${zdm_aws_region}" ] || [ -z "${zdm_proxy_instance_count}" ] || [ -z "${zdm_keypair_name}" ];
    then
      return 1
    else
      return 0
    fi
}

build_terraform_var_str () {
  # Build the string containing all the variables to be passed to the Terraform command

  terraform_vars=" "

  terraform_vars+="-var \"zdm_aws_profile=${zdm_aws_profile}\" "
  terraform_vars+="-var \"zdm_aws_region=${zdm_aws_region}\" "
  terraform_vars+="-var \"zdm_proxy_instance_count=${zdm_proxy_instance_count}\" "
  terraform_vars+="-var \"zdm_keypair_name=${zdm_keypair_name}\" "

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

  if [ -n "${zdm_vpc_cidr_prefix}" ]; then
      terraform_vars+="-var \"zdm_vpc_cidr_prefix=${zdm_vpc_cidr_prefix}\" "
  fi

  if [ -n "${zdm_proxy_instance_type}" ]; then
      terraform_vars+="-var \"zdm_proxy_instance_type=${zdm_proxy_instance_type}\" "
  fi

  if [ -n "${zdm_monitoring_instance_type}" ]; then
      terraform_vars+="-var \"zdm_monitoring_instance_type=${zdm_monitoring_instance_type}\" "
  fi

  if [ -n "${zdm_public_key_local_path}" ]; then
      terraform_vars+="-var \"zdm_public_key_local_path=${zdm_public_key_local_path}\" "
  fi

  if [ -n "${custom_name_suffix}" ]; then
    terraform_vars+="-var \"custom_name_suffix=${custom_name_suffix}\" "
  fi

  echo "${terraform_vars}"
}

###################################################
### Main script
###################################################

cd ../terraform/aws/no-peering-deployment-root-aws || exit

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

check_required_vars_exist
exit_code=$?
if [ "${exit_code}" != 0 ]; then
  echo "Missing required variables. Please specify all required variables before executing this script"
  exit "${exit_code}"
fi

tf_var_str=$(build_terraform_var_str)
echo "${tf_var_str}" > tf_latest_vars.txt
tf_plan_cmd_str="terraform plan ${tf_var_str} -out zdm_plan"
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
  terraform apply zdm_plan

  echo "#### Command apply executed with arguments: " "${tf_var_str}"
fi

terraform output > ../../../zdm_output.txt

chmod -x zdm_ansible_inventory
cp zdm_ansible_inventory ../../../ansible/
echo "ZDM Ansible inventory file created and copied into Ansible directory"
chmod 600 zdm_ssh_config
cp zdm_ssh_config ../../../ansible/
echo "ZDM custom SSH file created and copied into Ansible directory"
