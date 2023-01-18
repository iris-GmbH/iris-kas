# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [APR's Version Numbering](https://apr.apache.org/versioning.html).

## [2.1.3]

### Fixed
- Fix issues with firmware certificates in HW rel 2 builds

## [1.1.26]
### Added
- [APC-4244]: Introduce webserver and iris-thirdparty dependencies
- [DEVOPS-511] Build uuu files in Jenkins
- [RDPHOEN-1067] Added R2 build to cloud Jenkins
- [RDPHOEN-1122] Add development keys/certs for further development of Secure Boot
- [DEVOPS-446] Introduce GitLab CI/CD config
- [DEVOPS-522] Add signing of swupdate packages for R2 releases
- [DEVOPS-548] Add signing of roothashes for R2 releases
- [DEVOPS-542] Add HAB signing for R2 releases
- [RD-1240] Add makefile option for setting fixed refspecs on thirdparty meta layers
- [DEVOPS-524] Add netboot image to CI pipeline


### Changed
- [DEVOPS-519] Move basic config from local.conf to distro.conf in meta-iris
- [DEVOPS-531] Split distro configs into deploy and maintenance


### Deprecated


### Removed
- Remove currently unused layers (meta-clang, meta-java)
- dev signing keys have been removed from this repo and moved to meta-iris-base instead
- [DEVOPS-549] Remove Jenkinsfile, Codebuild configuration and Jenkins-related kas configs


### Fixed
- Fix makefile commands for support release and setting fixed refspecs (during release)


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
