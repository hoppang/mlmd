//go:build !windows

package backupstatus

import "os"

func replaceFile(source, destination string) error {
	return os.Rename(source, destination)
}
