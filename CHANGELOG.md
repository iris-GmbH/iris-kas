# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [APR's Version Numbering](https://apr.apache.org/versioning.html).

## [1.1.26] -dev (HEAD) - n/a
### Added
- [APC-4244]: Introduce webserver and iris-thirdparty dependencies
- [DEVOPS-511] Build uuu files in Jenkins
- [RDPHOEN-1067] Added R2 build to cloud Jenkins
- [RDPHOEN-1122] Add development keys/certs for further development of Secure Boot
- [DEVOPS-446] Introduce GitLab CI/CD config


### Changed


### Deprecated


### Removed


### Fixed


### Simulation only


### Maintenance only


### Known issues


## [1.1.25]
### Added
- Added appendable KAS configuration file for offline builds

### Changed
- Our KAS config repository is now open source (MIT licensed)
- Introduced meta-iris-base which contains the recipes for building our base Linux image
- Building the platform application is now separated into it's own appendable KAS configuration file
- Updated README to address changes usage changes

### Removed
- License files from the Linux rootfs, as these are not accessable for the customer on deploy images

## [1.1.24]
### Added
- Introduced the KAS repository as meta-layer aggregation and global version tracking repository
