package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"zdm-proxy-automation/zdm-util/pkg/docker"
	"zdm-proxy-automation/zdm-util/pkg/userinteraction"
)

const (
	UtilityExitingMessage  = "This utility will now exit. Please rectify the problem and re-run. "
)

func main() {

	customConfigFilePath := flag.String("utilConfigFile", "", "This option can be used to specify a custom configuration file for this utility")
	flag.Parse()

	launchUtil(*customConfigFilePath, os.Stdin)
}

func launchUtil(customConfigFilePath string, userInputFile *os.File) {

	reader := bufio.NewReader(userInputFile)

	interactionOrchestrator := userinteraction.NewInteractionOrchestrator(reader)

	err := docker.ValidateDockerPrerequisites()
	if err != nil {
		fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage)
		return
	}

	containerConfig, err := interactionOrchestrator.CreateContainerConfiguration(customConfigFilePath)
	if err != nil {
		fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage)
		return
	}

	ynAcceptAndProceed, err := interactionOrchestrator.DisplayConfigurationAndPromptForConfirmation()
	if err != nil {
		fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage)
		return
	}

	if ynAcceptAndProceed {
		err = docker.CreateAndInitializeContainer(containerConfig, reader)
		if err != nil {
			fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage)
		}
	}

}
