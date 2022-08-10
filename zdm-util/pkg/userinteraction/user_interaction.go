package userinteraction

import (
	"bufio"
	"cloudgate-automation/zdm-util/pkg/config"
	"fmt"
	"os"
)

const (
	DefaultConfigurationFilePath    = "ansible_container_init_config"
	DefaultAnsibleInventoryFilePath = "/home/ubuntu/"
	DefaultAnsibleInventoryFileName = "cloudgate_inventory"

	DefaultMaxAttempts                = 5
	RequiredParameterNoDefaultMessage = "This is a required parameter and does not have a default value. "
	ProvideValueMessage               = "Please provide a valid value. "
)

func CreateContainerConfiguration(customConfigFilePath string) (*config.ContainerInitConfig, error) {

	printUtilityGeneralPreamble()
	var err error

	containerConfig := loadConfigurationFromExistingFile(customConfigFilePath)

	fmt.Println()

	if !containerConfig.IsFullyPopulated() {
		printInteractivePreamble()

		err = promptForSshKeyPath(containerConfig)
		if err != nil {
			return nil, err
		}
		fmt.Println()

		err = promptForProxyPrivateIpAddressPrefix(containerConfig)
		if err != nil {
			return nil, err
		}
		fmt.Println()

		err = promptForAnsibleInventory(containerConfig)
		if err != nil {
			return nil, err
		}
		fmt.Println()

		err = persistCurrentConfigToFile(containerConfig)
		if err != nil {
			fmt.Printf("The configuration file %v could not be created due to %v. This utility will continue without persisting its configuration. \n", DefaultConfigurationFilePath, err)
		}
		fmt.Printf("Configuration successfully written to file %v \n", DefaultConfigurationFilePath)
	}

	return containerConfig, nil
}

func printUtilityGeneralPreamble() {
	fmt.Println("******************************************************************************* ")
	fmt.Println("*** This utility creates and initializes the Ansible Control Host container *** ")
	fmt.Println("******************************************************************************* ")
	fmt.Println()
}

func loadConfigurationFromExistingFile(customConfigFilePath string) *config.ContainerInitConfig {

	var containerConfig *config.ContainerInitConfig
	existingConfigFilePath := customConfigFilePath

	if existingConfigFilePath == "" {
		// look if a conf file already exists in the current directory
		if config.ValidateFilePath(DefaultConfigurationFilePath) {
			ynUseDefaultFile := YesNoPrompt(fmt.Sprintf("Found existing configuration file %v. Do you wish to use this file?", DefaultConfigurationFilePath), true, true)
			if ynUseDefaultFile {
				existingConfigFilePath = DefaultConfigurationFilePath
			}
		}
	}

	if existingConfigFilePath != "" {
		containerConfig = populateConfigFromConfigurationFile(existingConfigFilePath)
		if !containerConfig.IsFullyPopulated() && !containerConfig.IsEmpty(){
			fmt.Println()
			fmt.Println("The configuration file was incomplete or not fully valid. ")
		}
	} else {
		containerConfig = config.NewEmptyContainerInitConfig()
	}
	return containerConfig
}

func populateConfigFromConfigurationFile(existingConfigurationFilePath string) *config.ContainerInitConfig {
	containerConfig, err := config.NewContainerInitConfigFromFile(existingConfigurationFilePath)
	if err != nil {
		fmt.Printf("There was an error with the provided configuration file: %v. This utility will now switch to using interactive input instead.\n", err)
		return config.NewEmptyContainerInitConfig()
	}
	fmt.Printf("Configuration file parsed. ")
	return containerConfig
}

func printInteractivePreamble() {
	fmt.Printf("***** Running this utility in interactive mode. ***** \n")
	fmt.Printf("The results will be saved to a configuration file called %v and located in the current execution directory. This file can be passed to this utility if it needs to be run again. \n", DefaultConfigurationFilePath)
	fmt.Println()
}

func promptForSshKeyPath(containerConfig *config.ContainerInitConfig) error {
	if _, found := containerConfig.Properties[config.SshKeyPathOnHostPropertyName]; !found {

		sshKeyPathOnHost := StringPrompt("Please enter the path and name of the SSH private key to access the proxy hosts",
			RequiredParameterNoDefaultMessage+ProvideValueMessage, false, DefaultMaxAttempts, config.ValidateFilePath)

		if sshKeyPathOnHost == "" {
			fmt.Println()
			fmt.Println("The SSH private key to access the proxy hosts was not provided or was not valid. " + RequiredParameterNoDefaultMessage)
			return fmt.Errorf("missing required configuration")
		}

		if absoluteSshKeyPathOnHost, ok := config.ConvertToAbsolutePath(sshKeyPathOnHost); ok {
			containerConfig.AddProperty(config.SshKeyPathOnHostPropertyName, absoluteSshKeyPathOnHost)
		}
	}
	return nil
}

func promptForProxyPrivateIpAddressPrefix(containerConfig *config.ContainerInitConfig) error {
	if _, found := containerConfig.Properties[config.ProxyIpAddressPrefixPropertyName]; !found {

		proxyPrivateIpAddressPrefix := StringPrompt("Please enter the common prefix of the private IP addresses of the proxy hosts (examples: 172.* or 172.18.* or 172.18.10.*)",
			RequiredParameterNoDefaultMessage+ProvideValueMessage,
			false, DefaultMaxAttempts, config.ValidateIpAddressPrefix)

		if proxyPrivateIpAddressPrefix == "" {
			fmt.Println()
			fmt.Println("The common prefix of the private IP addresses of the proxy hosts was not provided or was not valid. " + RequiredParameterNoDefaultMessage)
			return fmt.Errorf("missing required configuration")
		}
		containerConfig.AddProperty(config.ProxyIpAddressPrefixPropertyName, proxyPrivateIpAddressPrefix)
	}
	return nil
}

func promptForAnsibleInventory(containerConfig *config.ContainerInitConfig) error {
	if _, found := containerConfig.Properties[config.AnsibleInventoryPathOnHostPropertyName]; !found {
		ansibleInventoryPathOnHost := ""
		if ynInventory := YesNoPrompt("Do you have an existing Ansible inventory file?", false, false); ynInventory {
			fmt.Println()
			ansibleInventoryPathOnHost = StringPrompt("Please enter the path and name of your Ansible inventory file. Simply press ENTER if your inventory is "+DefaultAnsibleInventoryFilePath+DefaultAnsibleInventoryFileName,
				"", true, DefaultMaxAttempts, config.ValidateFilePath)

			if ansibleInventoryPathOnHost == "" {
				if config.ValidateFilePath(DefaultAnsibleInventoryFilePath + DefaultAnsibleInventoryFileName) {
					ansibleInventoryPathOnHost = DefaultAnsibleInventoryFilePath + DefaultAnsibleInventoryFileName
				} else {
					fmt.Printf("The Ansible inventory file path %v  is not valid. \n", DefaultAnsibleInventoryFileName)
					return fmt.Errorf("missing required configuration")
				}

			}
		}
		if ansibleInventoryPathOnHost == "" {
			fmt.Println()
			proxyIpsAddresses, monitoringIpAddress := promptForInventoryFileValues()

			err := populateInventoryFile(DefaultAnsibleInventoryFileName, proxyIpsAddresses, monitoringIpAddress)
			if err != nil {
				fmt.Printf("The creation of a new Ansible inventory file with name %v in the current directory failed, due to %v \n", DefaultAnsibleInventoryFileName, err)
				return fmt.Errorf("missing required configuration")
			}

			fmt.Println()

			ansibleInventoryPathOnHost = DefaultAnsibleInventoryFileName
		}

		if absoluteAnsibleInventoryPathOnHost, ok := config.ConvertToAbsolutePath(ansibleInventoryPathOnHost); ok {
			containerConfig.AddProperty(config.AnsibleInventoryPathOnHostPropertyName, absoluteAnsibleInventoryPathOnHost)
		}
	}
	return nil
}

// promptForInventoryFileValues asks the user to provide:
//  - the IP addresses of their proxy instances (requesting the appropriate minimum based on the type of deployment)
//  - the IP address of their monitoring instance (optional)
func promptForInventoryFileValues() ([]string, string) {
	fmt.Printf("This utility will create a new inventory file and populate it interactively.\n")
	fmt.Printf("The file will be called %v and will be located in the current directory \n", DefaultAnsibleInventoryFileName)
	fmt.Println()

	ynDemoEnv := YesNoPrompt("Is this proxy deployment for local testing and evaluation?", false, false)

	fmt.Println("You will now be prompted for the private IP addresses of all your proxy instances.")

	var minNumberOfProxies int
	if ynDemoEnv {
		fmt.Println("At least one proxy instance is required for local testing and evaluation purposes. ")
		minNumberOfProxies = 1
	} else {
		fmt.Println("At least three proxy instances are required for general testing and production deployments. ")
		minNumberOfProxies = 3
	}

	fmt.Println()
	fmt.Println("Please enter one address at a time and press ENTER. When you have finished, simply press ENTER. ")
	proxyIpsAddresses := StringPromptLoopingForMultipleValues("Proxy private IP address", config.ValidateIPAddress)
	if len(proxyIpsAddresses) < minNumberOfProxies {
		fmt.Printf("A minimum of %v private IP addresses must be specified\n", minNumberOfProxies)
	}
	fmt.Println()
	monitoringIpAddress := StringPrompt("Please enter the private IP address of your monitoring instance. Simply press ENTER to leave it empty",
		"", true, DefaultMaxAttempts, config.ValidateIPAddress)
	fmt.Println()

	return proxyIpsAddresses, monitoringIpAddress
}

// populateInventoryFile creates a new Ansible inventory file populating it with the provided addresses
func populateInventoryFile(filePath string, proxyIpAddresses []string, monitoringIpAddress string) error {
	ansibleInventoryFile, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer closeFile(ansibleInventoryFile)

	w := bufio.NewWriter(ansibleInventoryFile)

	_, err = fmt.Fprintf(w, "[proxies]\n")
	if err != nil {
		return err
	}

	for _, proxyIpAddress := range proxyIpAddresses {
		_, err = fmt.Fprintf(w, "%v ansible_connection=ssh ansible_user=ubuntu\n", proxyIpAddress)
		if err != nil {
			return err
		}
	}
	_, err = fmt.Fprintf(w, "\n")
	if err != nil {
		return err
	}

	if monitoringIpAddress != "" {
		_, err = fmt.Fprintf(w, "[monitoring]\n")
		if err != nil {
			return err
		}
		_, err = fmt.Fprintf(w, "%v ansible_connection=ssh ansible_user=ubuntu\n", monitoringIpAddress)
		if err != nil {
			return err
		}
	}

	err = w.Flush()
	if err != nil {
		return err
	}

	fmt.Printf("Ansible Inventory successfully written to file %v \n", filePath)

	return nil
}

// persistCurrentConfigToFile saves to file the configuration values provided interactively
func persistCurrentConfigToFile(containerConfig *config.ContainerInitConfig) error {
	configFile, err := os.Create(DefaultConfigurationFilePath)
	if err != nil {
		return err
	}
	defer closeFile(configFile)

	w := bufio.NewWriter(configFile)

	for propertyName, propertyValue := range containerConfig.Properties {
		_, err = fmt.Fprintf(w, propertyName+": "+propertyValue+"\n")
		if err != nil {
			return err
		}
	}

	w.Flush()
	if err != nil {
		return err
	}

	return nil
}

// TODO unify with closeFile used in the docker utils
func closeFile(f *os.File) {
	if f != nil {
		err := f.Close()
		if err != nil {
			fmt.Printf("Error closing file %v: %v \n", f.Name(), err)
		}
	}
}
