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

func TestCreateContainerConfiguration_FromExistingFile(t *testing.T) {
	tests := []struct {
		name                  string
		configurationFilePath string
		expectedConfig        *config.ContainerInitConfig
		userInputValues       []string
	}{
		{
			name:                  "Complete and valid configuration file does not result in user interaction",
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
			name:                  "Empty configuration file results in full user interaction",
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
			name:                  "No configuration file results in full user interaction",
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
		{
			name:                  "Partly invalid configuration file results in partial user interaction",
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
			// always remove any existing config file to isolate each test
			cleanUpDefaultConfigTestFile(t)

			var interactionOrchestrator *InteractionOrchestrator
			var userInputFile *os.File
			var err error
			if len(tt.userInputValues) > 0 {
				userInputFile, err = createSimulatedUserInputFile(tt.userInputValues)
				if err != nil {
					t.Fatalf("Error creating file to simulate user input")
				}
				defer cleanUpTestFile(userInputFile, t)
				interactionOrchestrator = NewInteractionOrchestrator(bufio.NewReader(userInputFile))
			} else {
				interactionOrchestrator = NewInteractionOrchestrator(bufio.NewReader(os.Stdin))
			}

			actualConfig, err := interactionOrchestrator.CreateContainerConfiguration(tt.configurationFilePath)

			if userInputFile != nil {
				if err = userInputFile.Close(); err != nil {
					t.Fatalf("Failed to close temp input file")
				}
			}

			if err != nil {
				t.Fatalf("Unexpected error: %v", err)
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

			}
		})
	}
}

func createSimulatedUserInputFile(userInputValues []string) (*os.File, error) {
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

	// TODO this will have to be moved to each line
	if _, err = userInputFile.Seek(0, io.SeekStart); err != nil {
		return nil, err
	}

	// TODO remove these
	//oldStdin := os.Stdin
	//defer func() { os.Stdin = oldStdin }() // Restore original Stdin

	//os.Stdin = tmpInputFile
	return userInputFile, nil
}

func cleanUpDefaultConfigTestFile(t *testing.T) {
	file, err := os.Open(DefaultConfigurationFilePath)
	if err == nil {
		cleanUpTestFile(file, t)
	}
}

func cleanUpTestFile(file *os.File, t *testing.T) {
	if file != nil {
		if err := os.Remove(file.Name()); err != nil {
			t.Fatalf("Could not remove file %v due to %v", file.Name(), err)
		}
	}
}

//func provideUserInputInTest(userInputMap map[string]string, inputName string) error {
//	content := []byte(userInputMap[inputName])
//	tmpfile, err := ioutil.TempFile("", "example")
//	if err != nil {
//		return err
//	}
//	defer os.Remove(tmpfile.Name()) // clean up
//
//	if _, err = tmpfile.Write(content); err != nil {
//		return err
//	}
//
//	if _, err = tmpfile.Seek(0, 0); err != nil {
//		return err
//	}
//
//	oldStdin := os.Stdin
//	defer func() { os.Stdin = oldStdin }() // Restore original Stdin
//
//	os.Stdin = tmpfile
//	if err := userInput(); err != nil {
//		t.Errorf("userInput failed: %v", err)
//	}
//
//	if err := tmpfile.Close(); err != nil {
//		log.Fatal(err)
//	}
//}

func ConvertRelativePathToAbsoluteForTests(relativePath string) string {
	absolutePath, _ := filepath.Abs(relativePath)
	return absolutePath
}
