package config

import (
	"cloudgate-automation/zdm-util/pkg/testutils"
	"github.com/stretchr/testify/require"
	"os"
	"path/filepath"
	"testing"
)

func TestConfig_WithExistingFile(t *testing.T) {
	tests := []struct {
		name                 string
		configFilePath       string
		expectedConfig       *ContainerInitConfig
		isErrorExpected      bool
		expectedErrorMessage string
	}{
		{
			name:           "valid path to valid config file with : separator",
			configFilePath: "../../testResources/testconfigfile_colon",
			expectedConfig: &ContainerInitConfig{
				Properties: map[string]string{
					SshKeyPathOnHostPropertyName:           testutils.ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					ProxyIpAddressPrefixPropertyName:       "172.18.*",
					AnsibleInventoryPathOnHostPropertyName: testutils.ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			isErrorExpected: false,
		},
		{
			name:           "valid path to valid config file with : separator and quotes",
			configFilePath: "../../testResources/testconfigfile_colon_quotes",
			expectedConfig: &ContainerInitConfig{
				Properties: map[string]string{
					SshKeyPathOnHostPropertyName:           testutils.ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					ProxyIpAddressPrefixPropertyName:       "172.18.*",
					AnsibleInventoryPathOnHostPropertyName: testutils.ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			isErrorExpected: false,
		},
		{
			name:           "valid path to valid config file with = separator",
			configFilePath: "../../testResources/testconfigfile_equals",
			expectedConfig: &ContainerInitConfig{
				Properties: map[string]string{
					SshKeyPathOnHostPropertyName:           testutils.ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
					ProxyIpAddressPrefixPropertyName:       "172.18.*",
					AnsibleInventoryPathOnHostPropertyName: testutils.ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ansible_inventory"),
				},
			},
			isErrorExpected: false,
		},
		{
			name:                 "valid path to empty config file",
			configFilePath:       "../../testResources/testconfigfile_empty",
			expectedConfig:       &ContainerInitConfig{},
			isErrorExpected:      true,
			expectedErrorMessage: "the specified configuration file was empty",
		},
		{
			name:                 "invalid path to non-existing config file",
			configFilePath:       "/home/invalid_dir/invalid_file",
			expectedConfig:       &ContainerInitConfig{},
			isErrorExpected:      true,
			expectedErrorMessage: "error opening the specified configuration file: open /home/invalid_dir/invalid_file: no such file or directory ",
		},
		{
			name:           "valid path to config file with invalid path variables",
			configFilePath: "../../testResources/testconfigfile_colon_invalidpaths",
			expectedConfig: &ContainerInitConfig{
				Properties: map[string]string{
					ProxyIpAddressPrefixPropertyName: "172.18.*",
				},
			},
			isErrorExpected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			actualConfig, err := NewContainerInitConfigFromFile(tt.configFilePath)

			if err != nil {
				if tt.isErrorExpected {
					require.Equal(t, tt.expectedErrorMessage, err.Error())
				} else {
					t.Fatalf("Unexpected error: %v", err)
				}
			} else {
				require.Equal(t, tt.expectedConfig.Properties[SshKeyPathOnHostPropertyName], actualConfig.Properties[SshKeyPathOnHostPropertyName])
				require.Equal(t, tt.expectedConfig.Properties[ProxyIpAddressPrefixPropertyName], actualConfig.Properties[ProxyIpAddressPrefixPropertyName])
				require.Equal(t, tt.expectedConfig.Properties[AnsibleInventoryPathOnHostPropertyName], actualConfig.Properties[AnsibleInventoryPathOnHostPropertyName])
			}
		})
	}
}

func TestValidateIpAddressPrefix(t *testing.T) {
	tests := []struct {
		name            string
		ipAddressPrefix string
		expectedValid   bool
	}{
		{
			name:            "valid ip prefix, one octet",
			ipAddressPrefix: "172.*",
			expectedValid:   true,
		},
		{
			name:            "valid ip prefix, two octets",
			ipAddressPrefix: "172.18.*",
			expectedValid:   true,
		},
		{
			name:            "valid ip prefix, three octets",
			ipAddressPrefix: "172.18.10.*",
			expectedValid:   true,
		},
		{
			name:            "valid ip prefix, two octets, leading spaces",
			ipAddressPrefix: "     172.18.*",
			expectedValid:   true,
		},
		{
			name:            "valid ip prefix, two octets, trailing spaces",
			ipAddressPrefix: "172.18.*      ",
			expectedValid:   true,
		},
		{
			name:            "valid ip prefix, two octets, leading and trailing spaces",
			ipAddressPrefix: "     172.18.*      ",
			expectedValid:   true,
		},
		{
			name:            "invalid ip prefix, first octet out of range",
			ipAddressPrefix: "300.*",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, second octet out of range",
			ipAddressPrefix: "172.300.*",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, third octet out of range",
			ipAddressPrefix: "172.18.300.*",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, no asterisk",
			ipAddressPrefix: "172.18.10.0",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, asterisk only",
			ipAddressPrefix: "*",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, leading asterisk",
			ipAddressPrefix: "*.18.10.0",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, asterisk in between as second octet",
			ipAddressPrefix: "172.*.10.0",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, asterisk in between as third octet",
			ipAddressPrefix: "172.18.*.0",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, two asterisks",
			ipAddressPrefix: "172.18.*.*",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, three asterisks",
			ipAddressPrefix: "172.*.*.*",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, too many octets, no asterisk",
			ipAddressPrefix: "172.18.10.0.0",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, too many octets, asterisk",
			ipAddressPrefix: "172.18.10.0.*",
			expectedValid:   false,
		},
		{
			name:            "invalid ip prefix, no dots",
			ipAddressPrefix: "17218100",
			expectedValid:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			actualValid := ValidateIpAddressPrefix(tt.ipAddressPrefix)
			require.Equal(t, tt.expectedValid, actualValid)
		})
	}

}

func TestValidateFilePath(t *testing.T) {
	tests := []struct {
		name          string
		filePath      string
		expectedValid bool
	}{
		{
			name:          "valid relative file path",
			filePath:      "../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key",
			expectedValid: true,
		},
		{
			name:          "valid absolute file path",
			filePath:      testutils.ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir/dummy_ssh_key"),
			expectedValid: true,
		},
		{
			name:          "valid relative path but is a directory",
			filePath:      "../../testResources/dummy_dir/dummy_sub_dir",
			expectedValid: false,
		},
		{
			name:          "valid absolute path but is a directory",
			filePath:      testutils.ConvertRelativePathToAbsoluteForTests("../../testResources/dummy_dir/dummy_sub_dir"),
			expectedValid: false,
		},
		{
			name:          "path to file that does not exist",
			filePath:      "../../testResources/dummy_dir/invalid",
			expectedValid: false,
		},
		{
			name:          "path to directory that does not exist",
			filePath:      "../../testResources/invalid_dir",
			expectedValid: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			actualValid := ValidateFilePath(tt.filePath)
			require.Equal(t, tt.expectedValid, actualValid)
		})
	}

}

func TestResolveTildeInPath(t *testing.T) {
	homeDir, _ := os.UserHomeDir()

	tests := []struct {
		name             string
		filePath         string
		expectedFilePath string
	}{
		{
			name:             "path with leading tilde",
			filePath:         "~/my_file",
			expectedFilePath: filepath.Join(homeDir, "my_file"),
		},
		{
			name:             "path without tilde",
			filePath:         "my_dir/my_file",
			expectedFilePath: "my_dir/my_file",
		},
		{
			name:             "path with tilde in the middle",
			filePath:         "my_dir/~/my_file",
			expectedFilePath: "my_dir/~/my_file",
		},
		{
			name:             "path with tilde at the end",
			filePath:         "my_dir/my_file/~",
			expectedFilePath: "my_dir/my_file/~",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			actualFilePath := resolveTildeInPathIfPresent(tt.filePath)
			require.Equal(t, tt.expectedFilePath, actualFilePath)
		})
	}
}
