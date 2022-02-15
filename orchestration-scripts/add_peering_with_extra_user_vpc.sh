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

# REQUIRED: ID of the user's VPC with which the Cloudgate VPC must be peered.
#user_vpc_id=

# REQUIRED: IDs of all the route tables associated with the Origin cluster and client application subnets.
# String containing a comma-separated list of elements, without whitespaces. For example rtb-002b6c2dc4ab37ef3,rtb-0c12565bab8227485
#user_route_table_ids=

## *** OPTIONAL Variables. Leave commented if you are happy with the defaults. ***

# OPTIONAL: AWS credentials to be used to access the user's own infrastructure. Defaults to cloudgate_aws_profile.
#user_aws_profile=
#user_aws_profile="iamtheuser"

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
    if [ -z "${cloudgate_aws_profile}" ] || [ -z "${aws_region}" ] || [ -z "${user_vpc_id}" ] || [ -z "${user_route_table_ids}" ];
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
  terraform_vars+="-var \"user_vpc_id=${user_vpc_id}\" "

  # -var 'user_route_table_ids=["rtb-002b6c2dc4ab37ef3","rtb-0c12565bab8227485"]'
  rt_tbls_var="-var 'user_route_table_ids=["
  rt_tbls_var+=$(add_quotes_around_elements "${user_route_table_ids}")
  rt_tbls_var+="]' "
  terraform_vars+="${rt_tbls_var}"

  if [ -n "${user_aws_profile}" ]; then
      terraform_vars+="-var \"user_aws_profile=${user_aws_profile}\" "
  fi

  echo "${terraform_vars}"
}

###################################################
### Main script
###################################################

cd ../terraform/aws/extra-vpc-peering-root-aws || exit

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
echo "${tf_var_str}" > tf_peer_with_extra_user_vpc.txt
tf_plan_cmd_str="terraform plan ${tf_var_str} -out cloudgate_extra_vpc_peering_plan"
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
  terraform apply cloudgate_extra_vpc_peering_plan

  echo "#### Command apply executed with arguments: " "${tf_var_str}"
fi

terraform output

