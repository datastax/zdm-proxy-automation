package userinteraction

import (
	"bufio"
	"cloudgate-automation/zdm-util/pkg/config"
	"fmt"
	"os"
)

const (
	DefaultConfigurationFilePath    = "ansible_container_init_config"
	DefaultAnsibleInventoryDir      = "/home/ubuntu/"
	DefaultAnsibleInventoryFileName = "cloudgate_inventory"

	DefaultMaxAttempts                = 5
	RequiredParameterNoDefaultMessage = "This is a required parameter and does not have a default value. "
	ProvideValueMessage               = "Please provide a valid value. "

	InventoryHeadingForProxyGroup = "[proxies]"
	InventoryHeadingForMonitoringGroup = "[monitoring]"
	InventoryAddressLineSuffix = "ansible_connection=ssh ansible_user=ubuntu"
)

type InteractionOrchestrator struct {
	containerConfig *config.ContainerInitConfig
	userInputReader *bufio.Reader
}

func NewInteractionOrchestrator(reader *bufio.Reader) *InteractionOrchestrator {
	return &InteractionOrchestrator{
		containerConfig: nil,
		userInputReader: reader,
	}
}

func (o *InteractionOrchestrator) CreateContainerConfiguration(customConfigFilePath string) (*config.ContainerInitConfig, error) {

	printUtilityGeneralPreamble()
	var err error

	o.containerConfig, err = o.loadConfigurationFromExistingFile(customConfigFilePath)
	if err != nil {
		return nil, err
	}

	fmt.Println()

	if !o.containerConfig.IsFullyPopulated() {
		printInteractivePreamble()

		err = o.promptForSshKeyPath()
		if err != nil {
			return nil, err
		}
		fmt.Println()

		err = o.promptForProxyPrivateIpAddressPrefix()
		if err != nil {
			return nil, err
		}
		fmt.Println()

		err = o.promptForAnsibleInventory()
		if err != nil {
			return nil, err
		}
		fmt.Println()

		err = persistCurrentConfigToFile(o.containerConfig)
		if err != nil {
			fmt.Printf("The configuration file %v could not be created due to %v. This utility will continue without persisting its configuration. \n", DefaultConfigurationFilePath, err)
		}
		fmt.Printf("Configuration successfully written to file %v \n", DefaultConfigurationFilePath)
	}

	return o.containerConfig, nil
}

func printUtilityGeneralPreamble() {
	fmt.Println("******************************************************************************* ")
	fmt.Println("*** This utility creates and initializes the Ansible Control Host container *** ")
	fmt.Println("******************************************************************************* ")
	fmt.Println()
}

func (o *InteractionOrchestrator) loadConfigurationFromExistingFile(customConfigFilePath string) (*config.ContainerInitConfig, error) {

	var containerConfig *config.ContainerInitConfig
	existingConfigFilePath := customConfigFilePath

	if existingConfigFilePath == "" {
		// look if a conf file already exists in the current directory
		if config.ValidateFilePathSilently(DefaultConfigurationFilePath) {
			ynUseDefaultFile, err := YesNoPrompt(fmt.Sprintf("Found existing configuration file %v. Do you wish to use this file?", DefaultConfigurationFilePath),
				true, true, o.userInputReader, DefaultMaxAttempts)
			if err != nil {
				return nil, fmt.Errorf("no clear indication was given about whether to use the existing configuration file: %v", err)
			}
			if ynUseDefaultFile {
				existingConfigFilePath = DefaultConfigurationFilePath
			}
			// if err != nil, meaning that the user was not able to confirm whether to use the file or not, the file will not be used and an empty config will be returned
		}
	}

	if existingConfigFilePath != "" {
		containerConfig = populateConfigFromConfigurationFile(existingConfigFilePath)
		if containerConfig.IsEmpty() {
			fmt.Println()
			fmt.Printf("No configuration properties were specified.\n")
		}
		if !containerConfig.IsFullyPopulated() && !containerConfig.IsEmpty() {
			fmt.Println()
			fmt.Println("The configuration file was incomplete or not fully valid. ")
		}
	} else {
		containerConfig = config.NewEmptyContainerInitConfig()
	}
	return containerConfig, nil
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
}

func (o *InteractionOrchestrator) promptForSshKeyPath() error {
	if _, found := o.containerConfig.Properties[config.SshKeyPathOnHostPropertyName]; !found {

		sshKeyPathOnHost := StringPrompt("Please enter the path and name of the SSH private key to access the proxy hosts",
			RequiredParameterNoDefaultMessage+ProvideValueMessage, false, DefaultMaxAttempts, config.ValidateFilePath, o.userInputReader)

		if sshKeyPathOnHost == "" {
			fmt.Println()
			fmt.Println("The SSH private key to access the proxy hosts was not provided or was not valid. " + RequiredParameterNoDefaultMessage)
			err := fmt.Errorf("missing required configuration")
			return err
		}

		if absoluteSshKeyPathOnHost, ok := config.ConvertToAbsolutePath(sshKeyPathOnHost); ok {
			o.containerConfig.AddProperty(config.SshKeyPathOnHostPropertyName, absoluteSshKeyPathOnHost)
		}
	}
	return nil
}

func (o *InteractionOrchestrator) promptForProxyPrivateIpAddressPrefix() error {
	if _, found := o.containerConfig.Properties[config.ProxyIpAddressPrefixPropertyName]; !found {

		proxyPrivateIpAddressPrefix := StringPrompt("Please enter the common prefix of the private IP addresses of the proxy hosts (examples: 172.* or 172.18.* or 172.18.10.*)",
			RequiredParameterNoDefaultMessage+ProvideValueMessage,
			false, DefaultMaxAttempts, config.ValidateIpAddressPrefix, o.userInputReader)

		if proxyPrivateIpAddressPrefix == "" {
			fmt.Println()
			fmt.Println("The common prefix of the private IP addresses of the proxy hosts was not provided or was not valid. " + RequiredParameterNoDefaultMessage)
			return fmt.Errorf("missing required configuration")
		}
		o.containerConfig.AddProperty(config.ProxyIpAddressPrefixPropertyName, proxyPrivateIpAddressPrefix)
	}
	return nil
}

func (o *InteractionOrchestrator) promptForAnsibleInventory() error {
	if _, found := o.containerConfig.Properties[config.AnsibleInventoryPathOnHostPropertyName]; !found {
		ansibleInventoryPathOnHost := ""
		ynInventory, ynErr := YesNoPrompt("Do you have an existing Ansible inventory file?", false, false, o.userInputReader, DefaultMaxAttempts)
		if ynErr != nil {
			return fmt.Errorf("no indication was given about whether an Ansible inventory file exists or should be created interactively: %v", ynErr)
		}
		if ynInventory {
			fmt.Println()
			ansibleInventoryPathOnHost = StringPrompt("Please enter the path and name of your Ansible inventory file. Simply press ENTER if your inventory is "+DefaultAnsibleInventoryDir+DefaultAnsibleInventoryFileName,
				"", true, DefaultMaxAttempts, config.ValidateFilePath, o.userInputReader)

			if ansibleInventoryPathOnHost == "" {
				if config.ValidateFilePath(DefaultAnsibleInventoryDir + DefaultAnsibleInventoryFileName) {
					ansibleInventoryPathOnHost = DefaultAnsibleInventoryDir + DefaultAnsibleInventoryFileName
				} else {
					fmt.Printf("The Ansible inventory file path %v  is not valid. \n", DefaultAnsibleInventoryFileName)
					return fmt.Errorf("missing required configuration")
				}

			}
		}
		if ansibleInventoryPathOnHost == "" {
			fmt.Println()
			proxyIpsAddresses, monitoringIpAddress, err := o.promptForInventoryFileValues()

			if err != nil {
				return err
			}

			err = populateInventoryFile(DefaultAnsibleInventoryFileName, proxyIpsAddresses, monitoringIpAddress)
			if err != nil {
				fmt.Printf("The creation of a new Ansible inventory file with name %v in the current directory failed, due to %v \n", DefaultAnsibleInventoryFileName, err)
				return fmt.Errorf("missing required configuration")
			}

			fmt.Println()

			ansibleInventoryPathOnHost = DefaultAnsibleInventoryFileName
		}

		if absoluteAnsibleInventoryPathOnHost, ok := config.ConvertToAbsolutePath(ansibleInventoryPathOnHost); ok {
			o.containerConfig.AddProperty(config.AnsibleInventoryPathOnHostPropertyName, absoluteAnsibleInventoryPathOnHost)
		}
	}
	return nil
}

// promptForInventoryFileValues asks the user to provide:
//  - the IP addresses of their proxy instances (requesting the appropriate minimum based on the type of deployment)
//  - the IP address of their monitoring instance (optional)
func (o *InteractionOrchestrator) promptForInventoryFileValues() ([]string, string, error) {
	fmt.Printf("This utility will create a new inventory file and populate it interactively.\n")
	fmt.Printf("The file will be called %v and will be located in the current directory \n", DefaultAnsibleInventoryFileName)

	ynDemoEnv, err := YesNoPrompt("Is this proxy deployment for local testing and evaluation?", true, false, o.userInputReader, DefaultMaxAttempts)
	if err != nil {
		fmt.Printf("\nNo valid answer was given, considering this a production deployment.\n")
		ynDemoEnv = false
	}

	fmt.Printf("\nYou will now be prompted for the private IP addresses of all your proxy instances. ")

	var minNumberOfProxies int
	if ynDemoEnv {
		fmt.Printf("At least one proxy instance is required for local testing and evaluation purposes. \n")
		minNumberOfProxies = 1
	} else {
		fmt.Printf("At least three proxy instances are required for general testing and production deployments. \n")
		minNumberOfProxies = 3
	}

	fmt.Println()
	fmt.Println("Please enter one address at a time and press ENTER. When you have finished, simply press ENTER. ")
	proxyIpsAddresses := StringPromptLoopingForMultipleValues("Proxy private IP address", config.ValidateIPAddress, o.userInputReader)
	if len(proxyIpsAddresses) < minNumberOfProxies {
		fmt.Printf("A minimum of %v private IP addresses must be specified\n", minNumberOfProxies)
		return nil, "", fmt.Errorf("missing required configuration")
	}
	fmt.Println()
	monitoringIpAddress := StringPrompt("Please enter the private IP address of your monitoring instance. Simply press ENTER to leave it empty",
		"", true, DefaultMaxAttempts, config.ValidateIPAddress, o.userInputReader)
	fmt.Println()

	return proxyIpsAddresses, monitoringIpAddress, nil
}

// populateInventoryFile creates a new Ansible inventory file populating it with the provided addresses
func populateInventoryFile(filePath string, proxyIpAddresses []string, monitoringIpAddress string) error {
	ansibleInventoryFile, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer closeFile(ansibleInventoryFile)

	w := bufio.NewWriter(ansibleInventoryFile)

	_, err = fmt.Fprintln(w, InventoryHeadingForProxyGroup)
	if err != nil {
		return err
	}

	for _, proxyIpAddress := range proxyIpAddresses {
		//_, err = fmt.Fprintf(w, "%v ansible_connection=ssh ansible_user=ubuntu\n", proxyIpAddress)
		_, err = fmt.Fprintf(w, "%v %v\n", proxyIpAddress, InventoryAddressLineSuffix)
		if err != nil {
			return err
		}
	}
	_, err = fmt.Fprintf(w, "\n")
	if err != nil {
		return err
	}

	if monitoringIpAddress != "" {
		_, err = fmt.Fprintln(w, InventoryHeadingForMonitoringGroup)
		if err != nil {
			return err
		}
		_, err = fmt.Fprintf(w, "%v %v\n", monitoringIpAddress, InventoryAddressLineSuffix)
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

func (o *InteractionOrchestrator) DisplayConfigurationAndPromptForConfirmation() (bool, error) {
	o.containerConfig.PrintProperties()
	fmt.Println()

	ynProceed, err := YesNoPrompt("Do you wish to proceed?", true, true, o.userInputReader, DefaultMaxAttempts)
	if err != nil {
		return false, fmt.Errorf("confirmation could not be obtained: %v", err)
	}
	return ynProceed, nil
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
