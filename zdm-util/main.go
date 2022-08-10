package main

import (
	"cloudgate-automation/zdm-util/pkg/docker"
	"cloudgate-automation/zdm-util/pkg/userinteraction"
	"flag"
	"fmt"
)

const (
	UtilityExitingMessage  = "This utility will now exit. "
	RectifyAndRerunMessage = "Please rectify the problem and re-run. "
)

func main() {

	customConfigFilePath := flag.String("utilConfigFile", "", "This option can be used to specify a custom configuration file for this utility")
	flag.Parse()

	err := docker.ValidateDockerPrerequisites()
	if err != nil {
		fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage+RectifyAndRerunMessage)
		return
	}

	containerConfig, err := userinteraction.CreateContainerConfiguration(*customConfigFilePath)
	if err != nil {
		fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage+RectifyAndRerunMessage)
		return
	}

	containerConfig.PrintProperties()
	fmt.Println()

	ynAcceptAndProceed := userinteraction.YesNoPrompt("Do you wish to proceed?", true, true)

	if ynAcceptAndProceed {
		err = docker.CreateAndInitializeContainer(containerConfig)
		if err != nil {
			fmt.Printf("ERROR: %v. %v \n", err, UtilityExitingMessage)
		}
	}

}
