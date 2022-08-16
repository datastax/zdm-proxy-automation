package main

import (
	"bufio"
	"cloudgate-automation/zdm-util/pkg/docker"
	"cloudgate-automation/zdm-util/pkg/userinteraction"
	"flag"
	"fmt"
	"os"
)

const (
	UtilityExitingMessage  = "This utility will now exit. "
	RectifyAndRerunMessage = "Please rectify the problem and re-run. "
)

func main() {

	customConfigFilePath := flag.String("utilConfigFile", "", "This option can be used to specify a custom configuration file for this utility")
	flag.Parse()

	launchUtil(*customConfigFilePath, os.Stdin)
}

func launchUtil(customConfigFilePath string, userInputFile *os.File) {

	r := bufio.NewReader(userInputFile)

	interactionOrchestrator := userinteraction.NewInteractionOrchestrator(r)

	err := docker.ValidateDockerPrerequisites()
	if err != nil {
		fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage+RectifyAndRerunMessage)
		return
	}

	containerConfig, err := interactionOrchestrator.CreateContainerConfiguration(customConfigFilePath)
	if err != nil {
		fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage+RectifyAndRerunMessage)
		return
	}

	ynAcceptAndProceed, err := interactionOrchestrator.DisplayConfigurationAndPromptForConfirmation()

	if err != nil {
		fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage+RectifyAndRerunMessage)
		return
	}

	if ynAcceptAndProceed {
		err = docker.CreateAndInitializeContainer(containerConfig, userInputFile)
		if err != nil {
			fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage)
		}
	}

}
