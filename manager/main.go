package main

import (
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"gopkg.in/yaml.v3"
)

var (
	ErrFolderExist     = errors.New("folder already exists")
	ErrServiceNotFound = errors.New("service not found")
)

type CreateServiceRequest struct {
	ServiceName          string `json:"service_name"`
	DockerComposeContent string `json:"docker_compose_content"`
}

type StartServiceRequest struct {
	IsPrivate bool `json:"is_private"`
}

type DeployServiceRequest struct {
	IsPrivate bool `json:"is_private"`
}

func loginToDockerHub() error {
	username := os.Getenv("DOCKER_USERNAME")
	password := os.Getenv("DOCKER_PASSWORD")
	
	if username == "" || password == "" {
		return errors.New("DOCKER_USERNAME and DOCKER_PASSWORD environment variables are required for private images")
	}
	
	cmd := exec.Command("docker", "login", "-u", username, "--password-stdin")
	cmd.Stdin = strings.NewReader(password)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("docker login failed: %v\nOutput: %s", err, string(output))
	}
	
	return nil
}

func getContainerLogs(serviceName string) string {
	servicePath, err := getServicePath(serviceName)
	if err != nil {
		return fmt.Sprintf("Failed to get service path: %v", err)
	}
	cmd := exec.Command("docker", "compose", "logs", "--tail=50")
	cmd.Dir = servicePath
	output, err := cmd.Output()
	if err != nil {
		return fmt.Sprintf("Failed to get logs: %v", err)
	}
	return string(output)
}

func executeDockerCompose(serviceName string) error {
	if !serviceExists(serviceName) {
		return ErrServiceNotFound
	}

	servicePath, err := getServicePath(serviceName)
	if err != nil {
		return fmt.Errorf("failed to get service path: %w", err)
	}

	cmd := exec.Command("docker", "compose", "up", "-d")
	cmd.Dir = servicePath
	output, err := cmd.CombinedOutput()
	if err != nil {
		logs := getContainerLogs(serviceName)
		return fmt.Errorf(
			"docker compose failed: %v\nOutput: %s\nContainer logs:\n%s",
			err,
			string(output),
			logs,
		)
	}
	return nil
}

func validateServiceStarted(serviceName string) error {
	if !serviceExists(serviceName) {
		return ErrServiceNotFound
	}

	servicePath, err := getServicePath(serviceName)
	if err != nil {
		return fmt.Errorf("failed to get service path: %w", err)
	}

	cmd := exec.Command("docker", "compose", "ps", "-q")
	cmd.Dir = servicePath

	output, err := cmd.Output()
	if err != nil {
		logs := getContainerLogs(serviceName)
		return fmt.Errorf(
			"failed to check service status: %w\nContainer logs:\n%s",
			err,
			logs,
		)
	}

	if len(output) == 0 {
		logs := getContainerLogs(serviceName)
		return fmt.Errorf(
			"no containers are running\nContainer logs:\n%s",
			logs,
		)
	}

	return nil
}

func stopAndCleanupService(serviceName string) error {
	if !serviceExists(serviceName) {
		return ErrServiceNotFound
	}

	servicePath, err := getServicePath(serviceName)
	if err != nil {
		return fmt.Errorf("failed to get service path: %w", err)
	}

	cmd := exec.Command("docker", "compose", "down", "--volumes")
	cmd.Dir = servicePath
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("docker compose down failed: %v\nOutput: %s", err, string(output))
	}
	return nil
}

func pruneUnusedDockerResources() error {
	cmd := exec.Command("docker", "system", "prune", "-f")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("docker system prune failed: %v\nOutput: %s", err, string(output))
	}
	return nil
}

func removeServiceFolder(serviceName string) error {
	if !serviceExists(serviceName) {
		return ErrServiceNotFound
	}
	servicePath, err := getServicePath(serviceName)
	if err != nil {
		return fmt.Errorf("failed to get service path: %w", err)
	}
	return os.RemoveAll(servicePath)
}

func deployService(serviceName string, isPrivate bool) error {
	if !serviceExists(serviceName) {
		return ErrServiceNotFound
	}

	if isPrivate {
		if err := loginToDockerHub(); err != nil {
			return fmt.Errorf("failed to login to Docker Hub: %w", err)
		}
	}

	servicePath, err := getServicePath(serviceName)
	if err != nil {
		return fmt.Errorf("failed to get service path: %w", err)
	}

	cmd := exec.Command("docker", "compose", "pull")
	cmd.Dir = servicePath
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("docker compose pull failed: %v\nOutput: %s", err, string(output))
	}

	cmd = exec.Command("docker", "rollout", serviceName)
	output, err = cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("docker rollout failed: %v\nOutput: %s", err, string(output))
	}

	if err := pruneUnusedDockerResources(); err != nil {
		return fmt.Errorf("failed to cleanup unused docker resources: %w", err)
	}

	return nil
}

func removeServiceCompletely(serviceName string) error {
	if err := stopAndCleanupService(serviceName); err != nil {
		return fmt.Errorf("failed to stop and cleanup service: %w", err)
	}

	if err := removeServiceFolder(serviceName); err != nil {
		return fmt.Errorf("failed to remove service folder: %w", err)
	}

	if err := pruneUnusedDockerResources(); err != nil {
		return fmt.Errorf("failed to prune unused docker resources: %w", err)
	}

	return nil
}

func main() {
	e := echo.New()

	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(
		middleware.BasicAuth(
			func(username, password string, c echo.Context) (bool, error) {
				if username == os.Getenv("API_USERNAME") &&
					password == os.Getenv("API_PASSWORD") {
					return true, nil
				}
				return false, nil
			},
		),
	)

	e.POST("/services", createService)
	e.POST("/services/:name/start", startService)
	e.DELETE("/services/:name", removeService)
	e.PUT("/services/:name/deploy", deployServiceEndpoint)

	e.Logger.Fatal(e.Start(":8080"))
}

func createService(c echo.Context) error {
	var req CreateServiceRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "invalid JSON payload",
		})
	}

	if req.ServiceName == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "service_name is required",
		})
	}

	if req.DockerComposeContent == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "docker_compose_content is required",
		})
	}

	if err := validateDockerCompose(req.DockerComposeContent); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "invalid docker-compose content: " + err.Error(),
		})
	}

	if err := createServiceWithCompose(req.ServiceName, req.DockerComposeContent); err != nil {
		if errors.Is(err, ErrFolderExist) {
			return c.JSON(http.StatusConflict, map[string]string{
				"error": "service already exists",
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to create service: " + err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, map[string]string{
		"message": "Service created successfully",
		"service": req.ServiceName,
	})
}

func startService(c echo.Context) error {
	serviceName := c.Param("name")

	if serviceName == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "service name is required",
		})
	}

	var req StartServiceRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "invalid JSON payload",
		})
	}

	if req.IsPrivate {
		if err := loginToDockerHub(); err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{
				"error": "failed to login to Docker Hub: " + err.Error(),
			})
		}
	}

	if err := executeDockerCompose(serviceName); err != nil {
		if errors.Is(err, ErrServiceNotFound) {
			return c.JSON(http.StatusNotFound, map[string]string{
				"error": "service not found",
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to start service: " + err.Error(),
		})
	}

	if err := validateServiceStarted(serviceName); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "service failed to start properly: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"message": "Service " + serviceName + " started successfully",
		"service": serviceName,
	})
}

func deployServiceEndpoint(c echo.Context) error {
	serviceName := c.Param("name")

	if serviceName == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "service name is required",
		})
	}

	var req DeployServiceRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "invalid JSON payload",
		})
	}

	if err := deployService(serviceName, req.IsPrivate); err != nil {
		if errors.Is(err, ErrServiceNotFound) {
			return c.JSON(http.StatusNotFound, map[string]string{
				"error": "service not found",
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to deploy service: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"message": "Service " + serviceName + " deployed successfully",
		"service": serviceName,
	})
}

func removeService(c echo.Context) error {
	serviceName := c.Param("name")

	if serviceName == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "service name is required",
		})
	}

	if err := removeServiceCompletely(serviceName); err != nil {
		if errors.Is(err, ErrServiceNotFound) {
			return c.JSON(http.StatusNotFound, map[string]string{
				"error": "service not found",
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to remove service: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"message": "Service " + serviceName + " removed successfully",
		"service": serviceName,
	})
}

func getServicePath(serviceName string) (string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("failed to get home directory: %w", err)
	}
	return filepath.Join(homeDir, serviceName), nil
}

func serviceExists(serviceName string) bool {
	servicePath, err := getServicePath(serviceName)
	if err != nil {
		return false
	}
	_, err = os.Stat(servicePath)
	return !os.IsNotExist(err)
}

func createServiceFolder(serviceName string) error {
	if serviceExists(serviceName) {
		return ErrFolderExist
	}

	servicePath, err := getServicePath(serviceName)
	if err != nil {
		return fmt.Errorf("failed to get service path: %w", err)
	}

	return os.Mkdir(servicePath, 0755)
}

func createDockerComposeFile(serviceName, content string) error {
	servicePath, err := getServicePath(serviceName)
	if err != nil {
		return fmt.Errorf("failed to get service path: %w", err)
	}
	filePath := filepath.Join(servicePath, "docker-compose.yml")
	return os.WriteFile(filePath, []byte(content), 0644)
}

func createServiceWithCompose(serviceName, dockerComposeContent string) error {
	if err := createServiceFolder(serviceName); err != nil {
		return fmt.Errorf("failed to create service folder: %w", err)
	}

	if err := createDockerComposeFile(serviceName, dockerComposeContent); err != nil {
		servicePath, _ := getServicePath(serviceName)
		os.RemoveAll(servicePath)
		return fmt.Errorf("failed to create docker-compose file: %w", err)
	}

	return nil
}

func validateDockerCompose(content string) error {
	var dockerCompose interface{}
	return yaml.Unmarshal([]byte(content), &dockerCompose)
}
