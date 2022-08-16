package userinteraction

import (
	"bufio"
	"cloudgate-automation/zdm-util/pkg/config"
	"fmt"
	"strings"
)

const (
	EmptyValueMessage = "<value not provided>"
)

// StringPrompt asks for a string value, using the provided prompt message.
// If the value is invalid, the try again message and the value prompt is displayed again for the specified maximum number of attempts.
// If the value is empty and returnOnEmptyValue is true, the empty value is returned, otherwise an empty value is considered invalid
// If the attempts are exhausted, an empty string is returned.
func StringPrompt(promptMessage string, tryAgainMessage string, returnOnEmptyValue bool, maxAttempts int, validateValue func(string) bool, userInputReader *bufio.Reader) string {

	trimmedString := ""

	for remainingAttempts := maxAttempts; remainingAttempts > 0; remainingAttempts-- {
		fmt.Printf("\n" + promptMessage + ": ")
		s, err := userInputReader.ReadString('\n')
		if err != nil {
			fmt.Printf("Error reading line %v \n", err)
		}
		trimmedString = config.FormatString(s)
		if trimmedString != "" {
			if validateValue(trimmedString) {
				return trimmedString
			} else {
				// invalid value message is being printed by the validation function
				fmt.Println()
				if tryAgainMessage != "" && remainingAttempts > 1 {
					fmt.Println(tryAgainMessage)
				}
			}
		} else {
			// empty string
			if returnOnEmptyValue {
				fmt.Println(EmptyValueMessage)
				return trimmedString
			}

			if tryAgainMessage != "" && remainingAttempts > 1 {
				fmt.Println()
				fmt.Println(tryAgainMessage)
			}
			fmt.Println()
		}
	}

	fmt.Println(EmptyValueMessage)
	return ""
}

// StringPromptLoopingForMultipleValues prompts for input repeatedly until it receives an empty input value
func StringPromptLoopingForMultipleValues(promptMessage string, validateValue func(string) bool, userInputReader *bufio.Reader) []string {

	values := make([]string, 0)
	var s string
	for {
		fmt.Printf("\n" + promptMessage + ": ")
		s, _ = userInputReader.ReadString('\n')
		trimmedValue := config.FormatString(s)
		if trimmedValue != "" {
			if validateValue(trimmedValue) {
				values = append(values, trimmedValue)
			} // else continue looping
		} else {
			//empty value is the termination condition
			return values
		}
	}
}

// YesNoPrompt asks yes/no questions using the label.
// If hasDefault is true, it uses the specified default.
func YesNoPrompt(promptMessage string, hasDefault bool, defaultToYes bool, userInputReader *bufio.Reader, maxAttempts int) (bool, error) {
	var choices string
	if hasDefault {
		choices = "Y/n"
		if !defaultToYes {
			choices = "y/N"
		}
	} else {
		choices = "y/n"
	}

	var s string
	for remainingAttempts := maxAttempts; remainingAttempts > 0; remainingAttempts-- {
		fmt.Printf("\n%s (%s) ", promptMessage, choices)
		s, _ = userInputReader.ReadString('\n')
		s = config.FormatString(s)
		if s == "" {
			if hasDefault {
				return defaultToYes, nil
			}
		}
		s = strings.ToLower(s)
		if s == "y" || s == "yes" {
			return true, nil
		}
		if s == "n" || s == "no" {
			return false, nil
		}
	}
	return false, fmt.Errorf("no valid y/n input was provided")
}
