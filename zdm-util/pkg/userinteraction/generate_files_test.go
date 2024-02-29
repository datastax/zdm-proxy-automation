package userinteraction

import (
	"bufio"
	"fmt"
	"github.com/stretchr/testify/require"
	"os"
	"strings"
	"testing"
	"zdm-proxy-automation/zdm-util/pkg/config"
	"zdm-proxy-automation/zdm-util/pkg/testutils"
)

const testInventoryFilePath = "tmp_ansible_inventory"

func TestPopulateInventoryFile(t *testing.T) {
	tests := []struct {
		name                string
		proxyIpAddresses    []string
		monitoringIpAddress string
	}{
		{
			name:                "1 proxy, monitoring",
			proxyIpAddresses:    []string{"172.18.10.32"},
			monitoringIpAddress: "172.18.100.45",
		},
		{
			name:                "1 proxy, no monitoring",
			proxyIpAddresses:    []string{"172.18.10.32"},
			monitoringIpAddress: "",
		},
		{
			name:                "3 proxies, monitoring",
			proxyIpAddresses:    []string{"172.18.10.32", "172.18.11.58", "172.18.12.47"},
			monitoringIpAddress: "172.18.100.45",
		},
		{
			name:             "3 proxies, no monitoring",
			proxyIpAddresses: []string{"172.18.10.32", "172.18.11.58", "172.18.12.47"},
		},
		{
			name:                "6 proxies, monitoring",
			proxyIpAddresses:    []string{"172.18.10.32", "172.18.11.58", "172.18.12.47", "172.18.10.15", "172.18.11.134", "172.18.12.206"},
			monitoringIpAddress: "172.18.100.45",
		},
		{
			name:             "6 proxies, no monitoring",
			proxyIpAddresses: []string{"172.18.10.32", "172.18.11.58", "172.18.12.47", "172.18.10.15", "172.18.11.134", "172.18.12.206"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := populateInventoryFile(testInventoryFilePath, tt.proxyIpAddresses, tt.monitoringIpAddress)
			require.Nil(t, err, "Error while populating the inventory file")
			compareGeneratedInventoryFileAndCleanUpForTests(testInventoryFilePath, tt.proxyIpAddresses, tt.monitoringIpAddress, t)
		})
	}
}

func compareGeneratedInventoryFileAndCleanUpForTests(filePath string, proxyIpAddresses []string, monitoringAddress string, t *testing.T) {
	testutils.CheckFileExistsForTests(filePath, t)

	file, err := os.Open(filePath)
	if file != nil {
		defer testutils.CleanUpFileForTests(file, t)
	}
	require.Nil(t, err, "Error opening generated file", filePath, err)

	expectedIndexOfProxyGroupHeading := 0
	expectedIndexOfFirstProxyAddress := 1
	expectedIndexOfLastProxyAddress := len(proxyIpAddresses)
	expectedIndexOfMonitoringGroupHeading := expectedIndexOfLastProxyAddress + 1
	expectedIndexOfMonitoringAddress := expectedIndexOfMonitoringGroupHeading + 1
	inventoryAddressLineSuffix, err := getInventoryAddressLineSuffix()
	require.Nil(t, err, "Error retrieving the inventory address line suffix")

	scanner := bufio.NewScanner(file)

	i := 0
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if line != "" && line != "\n" {
			switch {
			case i == expectedIndexOfProxyGroupHeading:
				require.Equal(t, InventoryHeadingForProxyGroup, line)
			case i >= expectedIndexOfFirstProxyAddress && i <= expectedIndexOfLastProxyAddress:
				require.Equal(t, fmt.Sprintf("%v %v", proxyIpAddresses[i-1], inventoryAddressLineSuffix), line)
			case monitoringAddress != "" && i == expectedIndexOfMonitoringGroupHeading:
				require.Equal(t, InventoryHeadingForMonitoringGroup, line)
			case monitoringAddress != "" && i == expectedIndexOfMonitoringAddress:
				require.Equal(t, fmt.Sprintf("%v %v", monitoringAddress, inventoryAddressLineSuffix), line)
			default:
				t.Fatalf("Unexpected line in generated inventory file: %v", line)
			}
			i++
		}
	}

	numLines := i - 1 // rollback the last increment
	if monitoringAddress != "" {
		require.Equal(t, numLines, expectedIndexOfMonitoringAddress)
	} else {
		require.Equal(t, numLines, expectedIndexOfLastProxyAddress)
	}
}

func TestPersistCurrentConfigToFile(t *testing.T) {
	tests := []struct {
		name            string
		configToPersist *config.ContainerInitConfig
	}{
		{
			name: "all properties set",
			configToPersist: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:           "/home/my_path/my_key",
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.AnsibleInventoryPathOnHostPropertyName: "/home/my_path/my_inventory",
				},
			},
		},
		{
			name: "all properties set, reverse order",
			configToPersist: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.AnsibleInventoryPathOnHostPropertyName: "/home/my_path/my_inventory",
					config.ProxyIpAddressPrefixPropertyName:       "172.18.*",
					config.SshKeyPathOnHostPropertyName:           "/home/my_path/my_key",
				},
			},
		},
		{
			name: "only ssh key",
			configToPersist: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName: "/home/my_path/my_key",
				},
			},
		},
		{
			name: "only ssh key and proxy ip address prefix",
			configToPersist: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.SshKeyPathOnHostPropertyName:     "/home/my_path/my_key",
					config.ProxyIpAddressPrefixPropertyName: "172.18.*",
				},
			},
		},
		{
			name: "only ssh key and proxy ip address prefix, reverse order",
			configToPersist: &config.ContainerInitConfig{
				Properties: map[string]string{
					config.ProxyIpAddressPrefixPropertyName: "172.18.*",
					config.SshKeyPathOnHostPropertyName:     "/home/my_path/my_key",
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := persistCurrentConfigToFile(tt.configToPersist)
			require.Nil(t, err, "Error while persisting the configuration to file")
			compareGeneratedConfigurationFileAndCleanUpForTests(DefaultConfigurationFilePath, tt.configToPersist, t)
		})
	}
}

func compareGeneratedConfigurationFileAndCleanUpForTests(filePath string, configToPersist *config.ContainerInitConfig, t *testing.T) {
	testutils.CheckFileExistsForTests(filePath, t)

	file, err := os.Open(filePath)
	if file != nil {
		defer testutils.CleanUpFileForTests(file, t)
	}
	require.Nil(t, err, "Error opening generated file", filePath, err)

	// build a map to track whether each expected property has been found, regardless of order
	foundProperties := make(map[string]bool, 0)
	for k, _ := range configToPersist.Properties {
		foundProperties[k] = false
	}

	scanner := bufio.NewScanner(file)

	i := 0
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if line != "" && line != "\n" {
			lineTokens := strings.Split(line, ":")
			propName := strings.TrimSpace(lineTokens[0])
			// substring line to : or =
			// match prefix to property name
			// check line format
			switch propName {
			case config.SshKeyPathOnHostPropertyName:
				expectedLine := fmt.Sprintf("%v: %v", config.SshKeyPathOnHostPropertyName, configToPersist.Properties[config.SshKeyPathOnHostPropertyName])
				require.Equal(t, expectedLine, line)
				foundProperties[config.SshKeyPathOnHostPropertyName] = true
			case config.ProxyIpAddressPrefixPropertyName:
				expectedLine := fmt.Sprintf("%v: %v", config.ProxyIpAddressPrefixPropertyName, configToPersist.Properties[config.ProxyIpAddressPrefixPropertyName])
				require.Equal(t, expectedLine, line)
				foundProperties[config.ProxyIpAddressPrefixPropertyName] = true
			case config.AnsibleInventoryPathOnHostPropertyName:
				expectedLine := fmt.Sprintf("%v: %v", config.AnsibleInventoryPathOnHostPropertyName, configToPersist.Properties[config.AnsibleInventoryPathOnHostPropertyName])
				require.Equal(t, expectedLine, line)
				foundProperties[config.AnsibleInventoryPathOnHostPropertyName] = true
			default:
				t.Fatalf("Unexpected line in generated inventory file: %v", line)
			}
			i++
		}
	}

	missing := false
	missingKeys := make([]string, 0)
	for k, v := range foundProperties {
		if !v {
			missing = true
			missingKeys = append(missingKeys, k)
		}
	}
	require.False(t, missing, "Missing properties in the file: %v", missingKeys)
}
