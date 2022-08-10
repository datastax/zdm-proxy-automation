package config

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
)

const (
	SshKeyPathOnHostPropertyName           = "ssh_key_path_on_host"
	ProxyIpAddressPrefixPropertyName       = "proxy_ip_address_prefix"
	AnsibleInventoryPathOnHostPropertyName = "ansible_inventory_path_on_host"
)

type ContainerInitConfig struct {
	Properties map[string]string
}

func NewEmptyContainerInitConfig() *ContainerInitConfig {
	return &ContainerInitConfig{
		Properties: make(map[string]string, 0),
	}
}

func NewContainerInitConfigFromFile(filePath string) (*ContainerInitConfig, error) {

	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("error opening the specified configuration file: %v ", err)
	}
	defer file.Close()

	containerConfig := &ContainerInitConfig{
		Properties: make(map[string]string, 0),
	}
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if separatorIdx := separatorIndex(line); separatorIdx >= 0 {
			if propertyName := FormatString(line[:separatorIdx]); len(propertyName) > 0 {
				propertyValue := ""
				if len(line) > separatorIdx {
					propertyValue = FormatString(line[separatorIdx+1:])
				}
				containerConfig.ValidateAndAddProperty(propertyName, propertyValue)
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading the specified configuration file: %v ", err)
	}

	return containerConfig, nil
}

func (c *ContainerInitConfig) ValidateAndAddProperty(propertyName string, propertyValue string) {
	c.addPropertyWithOptionalValidation(propertyName, propertyValue, false)
}

func (c *ContainerInitConfig) AddProperty(propertyName string, propertyValue string) {
	c.addPropertyWithOptionalValidation(propertyName, propertyValue, true)
}

// AddProperty sets the value of a property on the container configuration struct, validating the value provided
// It returns whether the property was successfully added (i.e. the value provided was valid and the property existed)
func (c *ContainerInitConfig) addPropertyWithOptionalValidation(name string, value string, skipValidation bool) bool {
	switch name {
	case SshKeyPathOnHostPropertyName:
		if skipValidation || (!skipValidation && ValidateFilePath(value)) {
			absPath, ok := ConvertToAbsolutePath(value)
			if !ok {
				return false
			}
			c.Properties[SshKeyPathOnHostPropertyName] = absPath
			return true
		}
	case ProxyIpAddressPrefixPropertyName:
		if skipValidation || (!skipValidation && ValidateIpAddressPrefix(value)) {
			c.Properties[ProxyIpAddressPrefixPropertyName] = value
			return true
		}
	case AnsibleInventoryPathOnHostPropertyName:
		if skipValidation || (!skipValidation && ValidateFilePath(value)) {
			absPath, ok := ConvertToAbsolutePath(value)
			if !ok {
				return false
			}
			c.Properties[AnsibleInventoryPathOnHostPropertyName] = absPath
			return true
		}
	default:
		fmt.Printf("Unknown property [name: %v, value: %v] found in property file. This property is being ignored. \n", name, value)
	}
	return false
}

func (c *ContainerInitConfig) IsEmpty() bool {
	return len(c.Properties) == 0
}

func (c *ContainerInitConfig) IsFullyPopulated() bool {
	return len(c.Properties) == 3
}

func (c *ContainerInitConfig) PrintProperties() {
	fmt.Printf("Configuration properties: \n")
	for k, v := range c.Properties {
		fmt.Printf(" - %s: %s \n", k, v)
	}
}

// FormatString removes enclosing quotes if present, and any leading / trailing white spaces
func FormatString(s string) string {
	// remove white spaces outside quotes
	s = strings.TrimSpace(s)
	if len(s) > 0 && s[0] == '"' {
		s = s[1:]
	}
	if len(s) > 0 && s[len(s)-1] == '"' {
		s = s[:len(s)-1]
	}
	// remove white spaces inside quotes
	s = strings.TrimSpace(s)
	return s
}

// separatorIndex locates the separator in the string. Valid separators are colon or equal
func separatorIndex(s string) int {
	if index := strings.Index(s, ":"); index > 0 {
		return index
	}
	return strings.Index(s, "=")
}

func ValidateFilePath(path string) bool {

	absPath, ok := ConvertToAbsolutePath(path)
	if !ok {
		return false
	}
	fileInfo, err := os.Stat(absPath)
	if err != nil {
		fmt.Printf("File %v is invalid. Error: %v \n", path, err)
		return false
	}
	if fileInfo.IsDir() {
		fmt.Printf("File %v is actually a directory, not a file \n", path)
		return false
	}
	return true
}

func ValidateIpAddressPrefix(ipPrefix string) bool {

	trimmedIpPrefix := FormatString(ipPrefix)

	prefixComponents := strings.Split(trimmedIpPrefix, ".")

	if len(prefixComponents) == 1 && prefixComponents[0] == trimmedIpPrefix {
		fmt.Printf("Malformed IP Address prefix %v. At least one octet must be specified. Example: 172.* or 172.18.* or 172.18.10.* \n", trimmedIpPrefix)
		return false
	}

	if len(prefixComponents) > 4 {
		fmt.Printf("Malformed IP Address prefix %v. Too many octets were specified. Example: 172.* or 172.18.* or 172.18.10.* \n", trimmedIpPrefix)
		return false
	}

	if prefixComponents[len(prefixComponents)-1] != "*" {
		fmt.Printf("Malformed IP Address prefix %v. The least significant byte must be an asterisk. Example: 172.* or 172.18.* or 172.18.10.*  \n", trimmedIpPrefix)
		return false
	}

	numberOfAsterisks := strings.Count(trimmedIpPrefix, "*")
	if numberOfAsterisks == 0 || numberOfAsterisks > 1 {
		fmt.Printf("Malformed IP Address prefix %v. Exactly one asterisk must be present. Example: 172.* or 172.18.* or 172.18.10.*  \n", trimmedIpPrefix)
		return false
	}

	expandedPrefix := ""
	for i := 0; i < 4; i++ {
		if i < len(prefixComponents) && prefixComponents[i] != "*" {
			if expandedPrefix == "" {
				expandedPrefix = prefixComponents[i]
			} else {
				expandedPrefix = expandedPrefix + "." + prefixComponents[i]
			}
		} else {
			expandedPrefix = expandedPrefix + ".0"
		}
	}

	if !ValidateIPAddress(expandedPrefix) {
		fmt.Printf("Malformed IP Address prefix %v. One or more octets may be out of range. Example: 172.* or 172.18.* or 172.18.10.* \n", trimmedIpPrefix)
		return false
	}
	return true
}

func ValidateIPAddress(ipAddress string) bool {
	if net.ParseIP(ipAddress) == nil {
		fmt.Printf("Invalid IP Address %v \n", ipAddress)
		return false
	}
	return true
}

func ConvertToAbsolutePath(path string) (string, bool){

	pathWithoutTilde := resolveTildeInPathIfPresent(path)

	absPath, err := filepath.Abs(pathWithoutTilde)
	if err != nil {
		fmt.Printf("File path %v could not be converted to an absolute path. Error: %v \n", path, err)
		return "", false
	}
	return absPath, true
}

func resolveTildeInPathIfPresent(path string) string {
	if strings.HasPrefix(path, "~/") {
		dirname, _ := os.UserHomeDir()
		path = filepath.Join(dirname, path[2:])
	}
	return path
}