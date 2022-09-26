package testutils

import (
	"fmt"
	"github.com/stretchr/testify/require"
	"os"
	"path/filepath"
	"testing"
)

func CheckFileExistsForTests(filePath string, t *testing.T) os.FileInfo{
	fileInfo, err := os.Stat(filePath)
	require.Nil(t, err)
	require.False(t, fileInfo.IsDir())
	require.True(t, fileInfo.Size() > 0)
	return fileInfo
}


func CleanUpFileForTests(file *os.File, t *testing.T) {
	if file != nil {
		fileName := file.Name()
		if err := file.Close(); err != nil {
			t.Fatalf("Failed to close temp input file")
		}

		if err := os.Remove(fileName); err != nil {
			t.Fatalf("Could not remove file %v due to %v", fileName, err)
		}
		fmt.Printf("\nFile %v closed and removed \n", fileName)
	}
}

func ConvertRelativePathToAbsoluteForTests(relativePath string) string {
	absolutePath, _ := filepath.Abs(relativePath)
	return absolutePath
}

