# ZDM Ansible Container initialization utility

The automation to create and manage a Zero Downtime Migration Proxy deployment is written in Ansible. 
While the playbooks are easy to run, setting up the machine from which they are run (i.e. the Ansible Control Host)
can be involved. Also, the steps required depend on the OS of the machine and the Ansible installation may clash with other
software, or even just other Ansible versions, already present on the machine.

The ZDM Ansible Container initialization utility was developed to simplify this process. This is a simple utility that 
creates, configures and initializes a container with Ansible pre-installed and all the necessary configuration to be able 
to start running playbooks straight away.

## Requirements
The ZDM infrastructure must have been provisioned prior to running this utility. See here (TODO add link) for the 
infrastructure requirements.

The machine that will be used as the Ansible Control Host must be able to connect to the proxy machines. 
To be able to run this utility, the following pre-requisites must be in place on this machine:
* The SSH private key needed to access the proxies must be uploaded to this machine
* Optionally, if an Ansible inventory file has already been created for the ZDM infrastructure, it should be uploaded to 
this machine 
* Docker must be installed (see the [Docker documentation](https://docs.docker.com/engine/install/) for instructions for each 
supported OS)
* The OS user that is running the utility must be able to execute docker commands without needing superuser (sudo) privileges.

This utility is written in Golang and will be made available as a self-contained executable, without requiring a go runtime.
***** Note this is still TODO ***** 

## Running this utility

**** NOTE: this is temporary and will change once the utility is distributed as a self-contained executable *****

Current (temporary) steps:
* Ensure that the requirements above are fulfilled
* Make sure Go is installed on the machine you want to use as the Ansible Control Host
* Clone this repository
* Go to  `zdm-ansible-container-init-utility/init-util`
* Run `go build` and run the executable that it creates, or just run `go run main.go` for local evaluation

## How it works

### Configuration input
The first part of this utility gathers the configuration values needed to initialize the container. These are: 
* The private SSH key for the proxies
* The common prefix of the IP addresses of the proxies (e.g. 172.18.*)
* The Ansible inventory file.

First of all, the utility asks whether a configuration file containing these values already exists. This may have been created 
by a previous execution, or even manually. If so, the configuration is loaded from this file and, if all values are present
and valid, the utility moves to creating the container straight away.

If a configuration file is not available, or if part of the configuration is missing or invalid, the utility populates the 
configuration by prompting for the values interactively.

It is possible to specify an existing Ansible inventory file if available. Alternatively, the utility will prompt for the 
necessary IP addresses and create a new inventory file, which it will set in the configuration.

All input is validated. The utility gives meaningful error messages and the possibility to rectify mistakes for a 
pre-defined number of attempts.

Finally, the complete configuration is persisted to a file, which can be passed to the utility again if the execution needs 
to be repeated.

### Container creation and initialization

At this point the utility creates and initializes the container using the configuration gathered previously.

To do this, it performs the following operations:
* It pulls the Docker image from Docker Hub
* It creates a container called `ach-test-container` (TODO this needs to be changed)
* It copies the ssh key and inventory files to the newly created container
* It runs an initialization script (included in the image) directly on the container. This script sets up the SSH key, clones 
the repository containing the Ansible playbooks and copies the inventory file in the appropriate location

The container is now running and ready to use.

## Playbook execution

After running the utility, you can simply open a shell on the running container with the command 
`docker exec -it ach-test-container bash`, go to `zdm-proxy-automation/ansible` and start configuring and executing playbooks.

Each playbook will still require the usual configuration - for example to run the installation playbook you will need to 
populate at least `vars/proxy_core_config_input.yml`. 

Playbooks can be run as usual with the command `ansible-playbook <playbook_name> -i <inventory_name>`.


 
