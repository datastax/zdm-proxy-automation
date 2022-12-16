package docker

import (
	"bufio"
	"context"
	"fmt"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"
	"github.com/docker/docker/pkg/archive"
	"github.com/pkg/errors"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
	"zdm-proxy-automation/zdm-util/pkg/config"
	"zdm-proxy-automation/zdm-util/pkg/userinteraction"
)

const (
	dockerImageName                 = "datastax/zdm-ansible:2.1.0-rc1"
	dockerContainerName             = "zdm-ansible-container"
	sshKeyPathOnContainer           = "/home/ubuntu/zdm-proxy-ssh-key-dir"
	ansibleInventoryPathOnContainer = "/home/ubuntu"

)

func ValidateDockerPrerequisites() error {

	orchestrator, err := createDockerOrchestrator()
	if err != nil {
		return fmt.Errorf("unable to create a Docker client: %v", err)
	}
	defer orchestrator.CloseDockerClient()

	err = orchestrator.pingServer()
	if err != nil {
		return fmt.Errorf("unable to contact the Docker server due to: %v", err)
	}
	return nil
}

func CreateAndInitializeContainer(containerConfig *config.ContainerInitConfig, userInputReader *bufio.Reader) error {

	orchestrator, err := createDockerOrchestrator()
	if err != nil {
		return fmt.Errorf("unable to create a Docker client: %v", err)
	}
	defer orchestrator.CloseDockerClient()

	err = orchestrator.pullImageIfNotAlreadyPresent(dockerImageName)
	if err != nil {
		return fmt.Errorf("unable to check or pull the docker image: %v", err)
	}

	containerId, isContainerRunning, err := orchestrator.retrieveExistingContainer(dockerContainerName)
	if err != nil {
		return fmt.Errorf("unable to check whether the container already exists: %v", err)
	}

	if containerId != "" {
		if isContainerRunning {
			fmt.Println()
			fmt.Printf("The container %v already exists and is in running state. \n\n", dockerContainerName)
			fmt.Printf("If you are happy to use the existing container, this utility will exit. \n")
			fmt.Printf("Otherwise, this utility will destroy the existing container and recreate it from scratch. Note: in this case, all data and configuration in the container will be lost. \n\n")
			ynUseExistingContainer, ynUseErr := userinteraction.YesNoPrompt("Do you wish to use this existing container?", false, false, userInputReader, userinteraction.DefaultMaxAttempts)
			if ynUseErr != nil {
				return fmt.Errorf("found existing container, but it is not clear whether you wish to use it or recreate it: %v", ynUseErr)
			}
			if ynUseExistingContainer {
				fmt.Printf("You decided to use the existing container. \n")
				return nil
			} else {
				fmt.Println()
				ynDestroyAndRecreateContainer, ynRecreateErr := userinteraction.YesNoPrompt("You decided to remove and recreate the container. All its data and configuration will be lost. Are you sure you want to proceed?",
					true, false, userInputReader, userinteraction.DefaultMaxAttempts)
				if ynRecreateErr != nil {
					return fmt.Errorf("found existing container. You indicated that you do not wish to use it, but no clear confirmation was given about proceeding to destroy and recreate it: %v", ynRecreateErr)
				}
				if ynDestroyAndRecreateContainer {
					err = orchestrator.removeExistingContainer(containerId)
					if err != nil {
						return fmt.Errorf("unable to remove the existing container prior to recreating it: %v", err)
					}
					containerId = ""
					isContainerRunning = false
					fmt.Printf("Container successfully removed \n")
				} else {
					fmt.Printf("You decided to use the existing container. \n")
					return nil
				}
			}
		}
	}

	if containerId == "" {
		containerId, err = orchestrator.createContainer(dockerImageName, dockerContainerName)
		if err != nil {
			return fmt.Errorf("unable to create the Docker container: %v. \n", err)
		}
		fmt.Printf("Container successfully created with ID %v and name %v \n", containerId, dockerContainerName)
	}

	if !isContainerRunning {
		if err = orchestrator.startContainer(containerId); err != nil {
			return fmt.Errorf("unable to start the Docker container with id %v due to %v. \n", containerId, err)
		}
		fmt.Printf("Container successfully started \n")
	}

	sshKeyPathOnHost := containerConfig.Properties[config.SshKeyPathOnHostPropertyName]
	if err = orchestrator.copyFileToContainer(containerId, sshKeyPathOnHost, sshKeyPathOnContainer); err != nil {
		return fmt.Errorf("unable to copy the SSH key %v to the Docker container %v due to %v. \n", sshKeyPathOnHost, dockerContainerName, err)
	}
	fmt.Printf("SSH key %v successfully copied to the Docker container %v \n", sshKeyPathOnHost, dockerContainerName)

	ansibleInventoryPathOnHost := containerConfig.Properties[config.AnsibleInventoryPathOnHostPropertyName]
	if err = orchestrator.copyFileToContainer(containerId, ansibleInventoryPathOnHost, ansibleInventoryPathOnContainer); err != nil {
		return fmt.Errorf("unable to copy the Ansible inventory %v to the Docker container %v due to %v. \n", ansibleInventoryPathOnHost, dockerContainerName, err)
	}
	fmt.Printf("Ansible inventory %v successfully copied to the Docker container %v \n", ansibleInventoryPathOnHost, dockerContainerName)

	if err = orchestrator.initializeContainer(containerId, containerConfig); err != nil {
		return fmt.Errorf("unable to run the initialization script on the Docker container %v due to %v. %v \n", dockerContainerName, err)
	}
	fmt.Printf("Ansible container %v successfully initialized \n", dockerContainerName)

	return nil
}

// DockerOrchestrator naming:
// IntelliJ points out that a struct's name should not start with its package name, but we feel that it should be called DockerOrchestrator for clarity
type DockerOrchestrator struct {
	cli *client.Client
	ctx context.Context
}

func createDockerOrchestrator() (*DockerOrchestrator, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, err
	}

	return &DockerOrchestrator{
		cli: cli,
		ctx: context.Background(),
	}, nil
}

func (o *DockerOrchestrator) pingServer() error {
	maxRetries := 5
	delayBetweenRetries := 1 * time.Second

	pingFunction := func(ctx context.Context) error {
		_, err := o.cli.Ping(ctx)
		return err
	}

	retryingPingFunction := Retry(pingFunction, maxRetries, delayBetweenRetries, "The Docker server could not be contacted")
	return retryingPingFunction(o.ctx)
}

type FunctionToBeRetried func(context.Context) error

func Retry(functionToBeRetried FunctionToBeRetried, retries int, delay time.Duration, outputMessage string) FunctionToBeRetried {
	return func(ctx context.Context) error {
		for r := 0; ; r++ {
			err := functionToBeRetried(ctx)
			if err == nil || r >= retries {
				// Return when there is no error or the maximum amount of retries is reached.
				return err
			}

			log.Printf("%s, retrying in %v", outputMessage, delay)

			select {
			case <-time.After(delay):
			case <-ctx.Done():
				return ctx.Err()
			}
		}
	}
}

func (o *DockerOrchestrator) pullImageIfNotAlreadyPresent(imageName string) error {
	imageFilters := filters.NewArgs()
	imageFilters.Add("reference", imageName)
	imageSummaries, err := o.cli.ImageList(o.ctx, types.ImageListOptions{Filters: imageFilters})

	if err != nil {
		return err
	}

	if len(imageSummaries) > 0 {
		fmt.Printf("Found %v images \n", len(imageSummaries))
		for _, imageSummary := range imageSummaries {
			fmt.Printf("Found image with name %v and id %v \n", imageSummary.RepoTags, imageSummary.ID)
		}
		fmt.Println("Docker image is already present and ready to use, so it will not be pulled")
		return nil
	}

	imageReader, err := o.cli.ImagePull(o.ctx, imageName, types.ImagePullOptions{})
	if err != nil {
		return err
	}
	defer CloseImageReader(imageReader)

	_, err = io.Copy(os.Stdout, imageReader)
	if err != nil {
		return err
	}
	return nil
}

func (o *DockerOrchestrator) retrieveExistingContainer(containerName string) (string, bool, error) {
	containerFilters := filters.NewArgs()
	containerFilters.Add("name", containerName)
	containerListOptions := types.ContainerListOptions{
		All:     true,
		Latest:  true,
		Filters: containerFilters,
	}
	containers, err := o.cli.ContainerList(o.ctx, containerListOptions)
	if err != nil {
		return "", false, err
	}

	switch len(containers) {
	case 0:
		fmt.Printf("The container does not yet exist and will be created \n")
		return "", false, nil
	case 1:

		fmt.Printf("Container found: name %v, id %v, status %v \n", containers[0].Names, containers[0].ID, containers[0].State)
		isRunning := strings.EqualFold(strings.TrimSpace(containers[0].State), "running")
		return containers[0].ID, isRunning, nil
	default:
		return "", false, fmt.Errorf("found %v containers, but only one is expected to exist \n", len(containers))
	}
}

func (o *DockerOrchestrator) removeExistingContainer(containerId string) error {
	containerRemoveOptions := types.ContainerRemoveOptions{
		Force: true,
	}
	return o.cli.ContainerRemove(o.ctx, containerId, containerRemoveOptions)
}

func (o *DockerOrchestrator) createContainer(imageName, containerName string) (string, error) {
	containerCreationResponse, err := o.cli.ContainerCreate(o.ctx,
		&container.Config{
			Image: imageName,
			Tty:   true,
	}, &container.HostConfig{
			RestartPolicy: container.RestartPolicy{
				Name: "unless-stopped",
			},
		}, nil, nil, containerName)
	if err != nil {
		return "", err
	}
	return containerCreationResponse.ID, nil
}

func (o *DockerOrchestrator) startContainer(containerId string) error {
	return o.cli.ContainerStart(o.ctx, containerId, types.ContainerStartOptions{})
}

// copyFileToContainer copies the specified file to the container. Equivalent of docker cp.
// Code based on the copyToContainer() function in https://github.com/docker/cli
func (o *DockerOrchestrator) copyFileToContainer(containerId, srcPath, dstPath string) error {

	srcPath, err := resolveLocalPath(srcPath)
	if err != nil {
		return err
	}

	// Prepare destination copy info by stat-ing the container path.
	dstInfo := archive.CopyInfo{Path: dstPath}
	dstStat, err := o.cli.ContainerStatPath(o.ctx, containerId, dstPath)

	// Validate the destination path
	if err = validateOutputPathFileMode(dstStat.Mode); err != nil {
		return errors.Wrapf(err, `destination "%s:%s" must be a directory or a regular file`, containerId, dstPath)
	}

	// Ignore any error and assume that the parent directory of the destination
	// path exists, in which case the copy may still succeed. If there is any
	// type of conflict (e.g., non-directory overwriting an existing directory
	// or vice versa) the extraction will fail. If the destination simply did
	// not exist, but the parent directory does, the extraction will still
	// succeed.
	if err == nil {
		dstInfo.Exists, dstInfo.IsDir = true, dstStat.Mode.IsDir()
	}

	var (
		content         io.ReadCloser
		resolvedDstPath string
	)

	if srcPath == "-" {
		content = os.Stdin
		resolvedDstPath = dstInfo.Path
		if !dstInfo.IsDir {
			return errors.Errorf("destination \"%s:%s\" must be a directory", containerId, dstPath)
		}
	} else {
		// Prepare source copy info.
		srcInfo, err := archive.CopyInfoSourcePath(srcPath, true)
		if err != nil {
			return err
		}

		srcArchive, err := archive.TarResource(srcInfo)
		if err != nil {
			return err
		}
		defer CloseReadCloser(srcArchive)

		// With the stat info about the local source as well as the
		// destination, we have enough information to know whether we need to
		// alter the archive that we upload so that when the server extracts
		// it to the specified directory in the container we get the desired
		// copy behavior.

		// See comments in the implementation of `archive.PrepareArchiveCopy`
		// for exactly what goes into deciding how and whether the source
		// archive needs to be altered for the correct copy behavior when it is
		// extracted. This function also infers from the source and destination
		// info which directory to extract to, which may be the parent of the
		// destination that the user specified.
		dstDir, preparedArchive, err := archive.PrepareArchiveCopy(srcArchive, srcInfo, dstInfo)
		if err != nil {
			return err
		}
		defer CloseReadCloser(preparedArchive)

		resolvedDstPath = dstDir
		content = preparedArchive
	}

	options := types.CopyToContainerOptions{
		AllowOverwriteDirWithFile: false,
		CopyUIDGID:                false,
	}
	return o.cli.CopyToContainer(o.ctx, containerId, resolvedDstPath, content, options)
}

func (o *DockerOrchestrator) initializeContainer(containerId string, containerConfig *config.ContainerInitConfig) error {

	ipPrefixArg := fmt.Sprintf("-p %s", containerConfig.Properties[config.ProxyIpAddressPrefixPropertyName])
	inventoryArg := fmt.Sprintf("-i %s", filepath.Base(containerConfig.Properties[config.AnsibleInventoryPathOnHostPropertyName]))

	execConfig := &types.ExecConfig{
		User:         "ubuntu",
		Privileged:   false,
		Tty:          true,
		Cmd:          []string{"/home/ubuntu/init_container_internal.sh", ipPrefixArg, inventoryArg},
		Detach:       false,
		WorkingDir:   "/home/ubuntu",
		AttachStdout: true,
		AttachStderr: true,
	}

	if _, err := o.cli.ContainerInspect(o.ctx, containerId); err != nil {
		return err
	}

	response, err := o.cli.ContainerExecCreate(o.ctx, containerId, *execConfig)
	if err != nil {
		return err
	}

	execID := response.ID
	if execID == "" {
		return errors.New("exec ID empty")
	}

	execStartCheck := types.ExecStartCheck{
		Tty: execConfig.Tty,
	}
	resp, err := o.cli.ContainerExecAttach(o.ctx, execID, execStartCheck)
	if err != nil {
		return err
	}
	defer resp.Close()

	_, err = io.Copy(os.Stdout, resp.Reader)
	if err != nil {
		return err
	}
	return nil
}

func (o *DockerOrchestrator) CloseDockerClient() {
	if o.cli != nil {
		err := o.cli.Close()
		if err != nil {
			fmt.Printf("Error closing Docker client: %v \n", err)
		}
	}
}

func CloseImageReader(reader io.ReadCloser) {
	if reader != nil {
		err := reader.Close()
		if err != nil {
			fmt.Printf("Error closing Docker image reader: %v \n", err)
		}
	}
}

func CloseReadCloser(rc io.ReadCloser) {
	if rc != nil {
		err := rc.Close()
		if err != nil {
			fmt.Printf("Error closing Docker image reader: %v \n", err)
		}
	}
}

func resolveLocalPath(localPath string) (absPath string, err error) {
	if absPath, err = filepath.Abs(localPath); err != nil {
		return
	}
	return archive.PreserveTrailingDotOrSeparator(absPath, localPath, filepath.Separator), nil
}

func validateOutputPathFileMode(fileMode os.FileMode) error {
	switch {
	case fileMode&os.ModeDevice != 0:
		return errors.New("got a device")
	case fileMode&os.ModeIrregular != 0:
		return errors.New("got an irregular file")
	}
	return nil
}
