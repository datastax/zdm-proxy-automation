package userinteraction

import (
	"bufio"
	"cloudgate-automation/zdm-util/pkg/config"
	"fmt"
	"github.com/stretchr/testify/require"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

type configCreationTest struct {
	name                  string
	configurationFilePath string
	expectedConfig        *config.ContainerInitConfig
	userInputValues       []string
	isExpectedError      bool
	expectedErrorMessage string
	generateInventoryFile bool

}

func TestCreateContainerConfiguration_FromExistingFile(t *testing.T) {
	tests := []configCreationTest{
		{
			name: "Complete and valid configuration file does not result in user interaction",
			configurationFilePath: "../../testResources/testconfigfile_colon",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			userInputValues: []string{},
		},
		{
			name: "Existing but empty configuration file results in full user interaction",
			configurationFilePath: "../../testResources/testconfigfile_empty",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"y",
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory",
			},
		},
		{
			name: "Completely invalid configuration file results in full user interaction",
			configurationFilePath: "../../testResources/testconfigfile_invalid_ip_prefix",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"y",
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory",
			},
		},
		{
			name: "Partly invalid configuration file results in partial user interaction",
			configurationFilePath: "../../testResources/testconfigfile_colon_invalidpaths",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"y",
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			runContainerConfigurationTest(t, tt)
		})
	}
}


func TestCreateContainerConfiguration_UserInteraction_General(t *testing.T) {
	tests := []configCreationTest{
		{
			name: "No configuration file, full user interaction, valid user input",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"y",
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			runContainerConfigurationTest(t, tt)
		})
	}
}

func TestCreateContainerConfiguration_UserInteraction_SshKey(t *testing.T) {
	tests := []configCreationTest{
		{
			name: "User unable to specify ssh key path, exhausts attempts",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{},
			},
			userInputValues: []string{
				"/home/invalid_dir/invalid_ssh_key_1",
				"/home/invalid_dir/invalid_ssh_key_2",
				"/home/invalid_dir/invalid_ssh_key_3",
				"/home/invalid_dir/invalid_ssh_key_4",
				"/home/invalid_dir/invalid_ssh_key_5",
			},
			isExpectedError:      true,
			expectedErrorMessage: "missing required configuration",
		},
		{
			name: "User able to specify ssh key path on fifth attempt",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			userInputValues: []string{
				"/home/invalid_dir/invalid_ssh_key_1",
				"/home/invalid_dir/invalid_ssh_key_2",
				"/home/invalid_dir/invalid_ssh_key_3",
				"/home/invalid_dir/invalid_ssh_key_4",
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"y",
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			runContainerConfigurationTest(t, tt)
		})
	}
}

func TestCreateContainerConfiguration_UserInteraction_ProxyAddressPrefix(t *testing.T) {
	tests := []configCreationTest{
		{
			name: "User unable to specify proxy address prefix, exhausts attempts",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.300.*",
				"*",
				"*.172.18",
				"*.172.18.*",
				"172.18.*.*",
			},
			isExpectedError:      true,
			expectedErrorMessage: "missing required configuration",
		},
		{
			name: "User able to specify proxy address prefix on fifth attempt",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.300.*",
				"*",
				"*.172.18",
				"*.172.18.*",
				"172.18.*",
				"y",
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			runContainerConfigurationTest(t, tt)
		})
	}
}


func TestCreateContainerConfiguration_UserInteraction_GenerateInventory(t *testing.T) {
	tests := []configCreationTest{
		{
			name: "Generate Ansible Inventory interactively, demo, 1 proxy, monitoring, valid",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("cloudgate_inventory"),
				},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"n",
				"y",
				"172.18.12.27\n",
				"172.18.100.42",
			},
			generateInventoryFile: true,
		},
		{
			name: "Generate Ansible Inventory interactively, demo, 1 proxy, no monitoring, valid",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("cloudgate_inventory"),
				},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"n",
				"y",
				"172.18.12.27\n",
			},
			generateInventoryFile: true,
		},
		{
			name:  "Generate Ansible Inventory interactively, demo, no proxies, invalid",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"n",
				"y",
				"\n",
			},
			isExpectedError: true,
			expectedErrorMessage: "missing required configuration",
		},
		{
			name: "Generate Ansible Inventory interactively, 3 proxies, monitoring, valid",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("cloudgate_inventory"),
				},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"n",
				"n",
				"172.18.10.134",
				"172.18.11.65",
				"172.18.12.27\n",
				"172.18.100.42",
			},
			generateInventoryFile: true,
		},
		{
			name: "Generate Ansible Inventory interactively, production, 3 proxies, no monitoring, valid",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: ConvertRelativePathToAbsoluteForTests("cloudgate_inventory"),
				},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"n",
				"n",
				"172.18.10.134",
				"172.18.11.65",
				"172.18.12.27\n",
			},
			generateInventoryFile: true,
		},
		{
			name: "Generate Ansible Inventory interactively, production, no proxies, invalid",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"n",
				"n",
				"\n",
			},
			isExpectedError: true,
			expectedErrorMessage: "missing required configuration",
		},
		{
			name: "Generate Ansible Inventory interactively, production, one proxy, invalid",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"n",
				"n",
				"172.18.10.134\n",
			},
			isExpectedError: true,
			expectedErrorMessage: "missing required configuration",
		},
		{
			name: "Generate Ansible Inventory interactively, production, two proxies, invalid",
			configurationFilePath: "",
			expectedConfig: &config.ContainerInitConfig{
				Properties: map[string]string{},
			},
			userInputValues: []string{
				"../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
				"172.18.*",
				"n",
				"n",
				"172.18.10.134",
				"172.18.11.65\n",
			},
			isExpectedError: true,
			expectedErrorMessage: "missing required configuration",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			runContainerConfigurationTest(t, tt)
		})
	}
}

func runContainerConfigurationTest(t *testing.T, tt configCreationTest) {
	// always remove any generated config file or inventory file to isolate each test
	defer cleanUpDefaultConfigFileForTests(t)
	defer cleanUpDefaultInventoryFileForTests(t)

	var interactionOrchestrator *InteractionOrchestrator
	var userInputFile *os.File
	var err error
	if len(tt.userInputValues) > 0 {
		userInputFile, err = createSimulatedUserInputFileForTests(tt.userInputValues)
		if err != nil {
			t.Fatalf("Error creating file to simulate user input")
		}
		defer cleanUpFileForTests(userInputFile, t)
		interactionOrchestrator = NewInteractionOrchestrator(bufio.NewReader(userInputFile))
	} else {
		interactionOrchestrator = NewInteractionOrchestrator(bufio.NewReader(os.Stdin))
	}

	actualConfig, err := interactionOrchestrator.CreateContainerConfiguration(tt.configurationFilePath)

	if err != nil {
		if tt.isExpectedError {
			require.Equal(t, tt.expectedErrorMessage, err.Error())
		} else {
			t.Fatalf("Unexpected error: %v", err)
		}
	} else {
		if expectedSshKeyPath, ok := tt.expectedConfig.Properties[config.SshKeyPathOnHostPropertyName]; ok {
			require.Equal(t, expectedSshKeyPath, actualConfig.Properties[config.SshKeyPathOnHostPropertyName])
		}
		if expectedProxyIpPrefix, ok := tt.expectedConfig.Properties[config.ProxyIpAddressPrefixPropertyName]; ok {
			require.Equal(t, expectedProxyIpPrefix, actualConfig.Properties[config.ProxyIpAddressPrefixPropertyName])
		}
		if expectedInventoryPath, ok := tt.expectedConfig.Properties[config.AnsibleInventoryPathOnHostPropertyName]; ok {
			require.Equal(t, expectedInventoryPath, actualConfig.Properties[config.AnsibleInventoryPathOnHostPropertyName])
		}

		if tt.generateInventoryFile {
			checkFileExistsForTests(DefaultAnsibleInventoryFileName, t)
		}
	}
}

func createSimulatedUserInputFileForTests(userInputValues []string) (*os.File, error) {
	userInputFile, err := ioutil.TempFile("", "user_input_test_file")
	if err != nil {
		return nil, err
	}

	w := bufio.NewWriter(userInputFile)
	for _, inputValue := range userInputValues {
		if _, err = fmt.Fprintln(w, inputValue); err != nil {
			return nil, err
		}
	}

	err = w.Flush()
	if err != nil {
		return nil, err
	}

	if _, err = userInputFile.Seek(0, io.SeekStart); err != nil {
		return nil, err
	}

	return userInputFile, nil
}

func checkFileExistsForTests(filePath string, t *testing.T) {
	fileInfo, err := os.Stat(filePath)
	require.Nil(t, err)
	require.False(t, fileInfo.IsDir())
	require.True(t, fileInfo.Size() > 0)
}

func cleanUpDefaultConfigFileForTests(t *testing.T) {
	file, err := os.Open(DefaultConfigurationFilePath)
	if err == nil {
		cleanUpFileForTests(file, t)
	}
}

func cleanUpDefaultInventoryFileForTests(t *testing.T) {
	file, err := os.Open(DefaultAnsibleInventoryFileName)
	if err == nil {
		cleanUpFileForTests(file, t)
	}
}

func cleanUpFileForTests(file *os.File, t *testing.T) {
	if file != nil {
		fileName := file.Name()
		if err := file.Close(); err != nil {
			t.Fatalf("Failed to close temp input file")
		}

		if err := os.Remove(fileName); err != nil {
			t.Fatalf("Could not remove file %v due to %v", fileName, err)
		}
		fmt.Printf("\nFile %v closed and removed \n", fileName)
	}
}

func ConvertRelativePathToAbsoluteForTests(relativePath string) string {
	absolutePath, _ := filepath.Abs(relativePath)
	return absolutePath
}
