# ZDM Ansible Container initialization utility

The automation to create and manage a Zero Downtime Migration Proxy deployment is written in Ansible. 
While the playbooks are easy to run, setting up the machine from which they are run (i.e. the Ansible Control Host)
can be involved. Also, the steps required depend on the OS of the machine and the Ansible installation may clash with other
software, or even just other Ansible versions, already present on the machine.

The ZDM Ansible Container initialization utility was developed to simplify this process. This is a simple utility that 
creates, configures and initializes a container with Ansible pre-installed and all the necessary configuration to be able 
to start running playbooks straight away.

For comprehensive instructions on using the ZDM Utility, please refer to [this page](https://docs.datastax.com/en/astra-serverless/docs/migrate/setup-ansible-playbooks.html) in the [official ZDM documentation](https://docs.datastax.com/en/astra-serverless/docs/migrate/introduction.html).