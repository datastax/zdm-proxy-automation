#!/bin/bash

###################################################
### Configuration variables
### Please uncomment and configure as appropriate.
###################################################

## *** REQUIRED Variables ***

# REQUIRED: AWS credentials to be used to provision the Cloudgate infrastructure.
#user_aws_profile=

# REQUIRED: AWS region for the Cloudgate deployment.
#aws_region=

# REQUIRED: Number of proxy instances to be deployed. Minimum 3.
#proxy_instance_count=

# REQUIRED: Name of the locally-generated key pair for the Cloudgate infrastructure specific to this deployment. Example: cloudgate-key-<enterprise_name>
#keypair_name=

# REQUIRED: IDs of all the subnets of the client application instances.
# String containing a comma-separated list of elements, without whitespaces.
#user_subnet_ids=

# REQUIRED: IDs of all the security groups to assign to the proxies.
# String containing a comma-separated list of elements, without whitespaces.
#user_proxy_security_group_ids=

# REQUIRED: IDs of all the security groups to assign to the monitoring instance.
# String containing a comma-separated list of elements, without whitespaces.
#user_monitoring_security_group_ids=

## *** OPTIONAL Variables. Leave commented if you are happy with the defaults. ***

# OPTIONAL: AWS instance type to be used for each proxy. Defaults to c5.xlarge, almost always fine.
#proxy_instance_type=

# OPTIONAL: AWS instance type to be used for the monitoring server. Defaults to c5.2xlarge, almost always fine.
#monitoring_instance_type=

# OPTIONAL: Path to the locally-generated key pair for the Cloudgate infrastructure. Defaults to ~./ssh.
#keypair_localpath=

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
  IFS=',' read -ra str_arr <<< "$1"

  # Turn the array into a new comma-separated string with the elements surrounded by quotes
  local F=0
  cs_string_quotes=""
  for x in "${str_arr[@]}"
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
    if [ -z "${user_aws_profile}" ] || [ -z "${aws_region}" ] || [ -z "${proxy_instance_count}" ] || [ -z "${user_subnet_ids}" ] || [ -z "${user_proxy_security_group_ids}" ] || [ -z "${user_monitoring_security_group_ids}" ] || [ -z "${keypair_name}" ];
    then
      return 1
    else
      return 0
    fi
}

build_terraform_var_str () {
  # Build the string containing all the variables to be passed to the Terraform command

  terraform_vars=" "

  terraform_vars+="-var \"user_aws_profile=${user_aws_profile}\" "
  terraform_vars+="-var \"aws_region=${aws_region}\" "
  terraform_vars+="-var \"proxy_instance_count=${proxy_instance_count}\" "
  terraform_vars+="-var \"keypair_name=${keypair_name}\" "

  # -var 'user_subnet_ids=["subnet-002b6c2dc4ab37ef3","subnet-0c12565bab8227485"]'
  subnets_var="-var 'user_subnet_ids=["
  subnets_var+=$(add_quotes_around_elements "${user_subnet_ids}")
  subnets_var+="]' "
  terraform_vars+="${subnets_var}"

  proxy_sg_var="-var 'user_proxy_security_group_ids=["
  proxy_sg_var+=$(add_quotes_around_elements "${user_proxy_security_group_ids}")
  proxy_sg_var+="]' "
  terraform_vars+="${proxy_sg_var}"

  # -var 'user_subnet_ids=["subnet-002b6c2dc4ab37ef3","subnet-0c12565bab8227485"]'
  monitoring_sg_var="-var 'user_monitoring_security_group_ids=["
  monitoring_sg_var+=$(add_quotes_around_elements "${user_monitoring_security_group_ids}")
  monitoring_sg_var+="]' "
  terraform_vars+="${monitoring_sg_var}"

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

chmod -x cloudgate_inventory
cp cloudgate_inventory ../../../ansible/

