package infrastructure

import (
	"encoding/json"
	"path/filepath"

	bosherr "bosh/errors"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
)

type dummyInfrastructure struct {
	fs                 boshsys.FileSystem
	dirProvider        boshdir.DirectoriesProvider
	platform           boshplatform.Platform
	devicePathResolver boshdpresolv.DevicePathResolver
}

func NewDummyInfrastructure(
	fs boshsys.FileSystem,
	dirProvider boshdir.DirectoriesProvider,
	platform boshplatform.Platform,
	devicePathResolver boshdpresolv.DevicePathResolver,
) (inf dummyInfrastructure) {
	inf.fs = fs
	inf.dirProvider = dirProvider
	inf.platform = platform
	inf.devicePathResolver = devicePathResolver
	return
}

func (inf dummyInfrastructure) GetDevicePathResolver() boshdpresolv.DevicePathResolver {
	return inf.devicePathResolver
}

func (inf dummyInfrastructure) SetupSsh(username string) (err error) {
	return
}

func (inf dummyInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	// dummy-cpi-agent-env.json is written out by dummy CPI.
	settingsPath := filepath.Join(inf.dirProvider.BoshDir(), "dummy-cpi-agent-env.json")
	contents, err := inf.fs.ReadFile(settingsPath)
	if err != nil {
		err = bosherr.WrapError(err, "Read settings file")
		return
	}

	err = json.Unmarshal([]byte(contents), &settings)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshal json settings")
		return
	}

	return
}

func (inf dummyInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	return
}

func (inf dummyInfrastructure) GetEphemeralDiskPath(devicePath string) (realPath string, found bool) {
	return inf.platform.NormalizeDiskPath(devicePath)
}

func (inf dummyInfrastructure) MountPersistentDisk(volumeID string, mountPoint string) (err error) {
	return
}
