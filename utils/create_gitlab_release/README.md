# Create Gitlab Release
## What it does

This script does multiple things:

1. It defines the required build artifacts for a release build and ensures that they are present.
2. It extracts customer-cleared install packages from the deploy image folder and moves it into its own archive.
3. It uploads release artifacts to the GitLab package registry.
4. It creates a GitLab release including descriptions for the given release multiconf(s) artifacts, linking to the appropriate package.


## Usage
Typically, this script is automatically called from the GitLab CI, extracting all necessary information from environment variables.
Manually running this script is also possible, although the usefulness outside of a dry-run is limited, at heavily depends on the availability of the GitLab service.

Run `test_create-gitlab_release.py --help` for more information.


## Development and testing
Build requirements during development and testing are managed using [pipenv](https://pipenv.pypa.io/en/latest). After installing pipenv on your system, run `make shell` for creating and activating the python virtual environment and installing all required development packages.

Running the test-suite requires a running GitLab instance on the developers machine. Run `docker-compose up -d` to start a preconfigured local GitLab instance. It will take a few minutes for GitLab to be ready for usage. Then run `make coverage` to run the test-suite.
