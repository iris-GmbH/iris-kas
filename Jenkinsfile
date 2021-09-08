// SPDX-License-Identifier: MIT
// Copyright (C) 2021 iris-GmbH infrared & intelligent sensors

pipeline {
    agent any
    options {
        disableConcurrentBuilds()
        parallelsAlwaysFailFast()
    }
    environment {
        // S3 bucket for saving release artifacts
        S3_BUCKET = 'iris-devops-artifacts-693612562064'

        // S3 bucket for temporary artifacts
        S3_TEMP_BUCKET = 'iris-devops-tempartifacts-693612562064'

        SDK_IMAGE = 'irma6-maintenance'
    }
    stages {
        stage('Preparation Stage') {
            steps {
                // clean workspace
                cleanWs disableDeferredWipeout: true, deleteDirs: true
                // we need to explicitly checkout from SCM after cleaning the workspace
                checkout scm
                // set dynamic environment variables
                script {
                    env.GIT_TAG = sh(script: 'git describe --tag --exact-match 2> /dev/null || true', returnStdout: true).trim()
                    if (env.GIT_TAG) {
                        env.ARTIFACT_NAME = env.GIT_TAG
                    }
                    else {
                        env.ARTIFACT_NAME = env.GIT_COMMIT
                    }
                    // if this is a PR branch, the env variable "CHANGE_BRANCH" will contain the real branch name, which we need for checkout later on
                    if (env.CHANGE_BRANCH) {
                        env.REAL_GIT_BRANCH = env.CHANGE_BRANCH
                    }
                    else {
                        env.REAL_GIT_BRANCH = env.GIT_BRANCH
                    }
                }
                // manually upload kas sources to S3, as to prevent upload conflicts in parallel steps
                zip dir: '', zipFile: 'iris-kas-sources.zip'
                s3Upload acl: 'Private',
                    bucket: "${S3_BUCKET}",
                    file: 'iris-kas-sources.zip',
                    path: "${JOB_NAME}/${GIT_COMMIT}/iris-kas-sources.zip",
                    payloadSigningEnabled: true,
                    sseAlgorithm: 'AES256'
                sh 'printenv | sort'
            }
        }

        stage('Develop: Build Firmware Artifacts') {
            // we assume releases are always tagged
            when {
                expression {
                    env.GIT_TAG == ''
                }
            }
            matrix {
                axes {
                    axis {
                        name 'MULTI_CONF'
                        values 'sc573-gen6', 'imx8mp-evk'
                    }
                    axis {
                        name 'IMAGES'
                        values 'irma6-deploy irma6-maintenance irma6-dev'
                    }
                }
                stages {
                    stage('Develop: Build Firmware Artifacts') {
                        steps {
                            awsCodeBuild buildSpecFile: 'buildspecs/build_firmware_images_develop.yml',
                                projectName: 'iris-devops-kas-large-amd-codebuild',
                                credentialsType: 'keys',
                                downloadArtifacts: 'false',
                                region: 'eu-central-1',
                                sourceControlType: 'project',
                                sourceTypeOverride: 'S3',
                                sourceLocationOverride: "${S3_BUCKET}/${JOB_NAME}/${GIT_COMMIT}/iris-kas-sources.zip",
                                envVariables: "[ { MULTI_CONF, $MULTI_CONF }, { IMAGES, $IMAGES }, { SDK_IMAGE, $SDK_IMAGE }, { HOME, /home/builder }, { JOB_NAME, $JOB_NAME }, { GIT_BRANCH, $REAL_GIT_BRANCH } ]"
                        }
                    }
                }
            }
        }

        stage('Release: Populate Download Mirror & Wipe Release SSTATE Cache') {
            // we assume releases are always tagged
            when {
                expression {
                    env.GIT_TAG != ''
                }
            }
            parallel {
                stage('Release: Populate Download Mirror') {
                    steps {
                        catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                            awsCodeBuild buildSpecFile: 'buildspecs/populate_download_mirror.yml',
                                projectName: 'iris-devops-kas-large-amd-codebuild',
                                credentialsType: 'keys',
                                downloadArtifacts: 'false',
                                region: 'eu-central-1',
                                sourceControlType: 'project',
                                sourceTypeOverride: 'S3',
                                sourceLocationOverride: "${S3_BUCKET}/${JOB_NAME}/${GIT_COMMIT}/iris-kas-sources.zip",
                                envVariables: "[{ TARGETS, 'sc573-gen6:irma6-dev imx8mp-evk:irma6-dev' }, { HOME, /home/builder }]"
                        }
                    }
                }

                stage('Release: Wipe Release SSTATE Cache') {
                    steps {
                        awsCodeBuild buildSpecFile: 'buildspecs/wipe_sstate_release_cache.yml',
                            projectName: 'iris-devops-kas-small-amd-codebuild',
                            credentialsType: 'keys',
                            downloadArtifacts: 'false',
                            region: 'eu-central-1',
                            sourceControlType: 'project',
                            sourceTypeOverride: 'S3',
                            sourceLocationOverride: "${S3_BUCKET}/${JOB_NAME}/${GIT_COMMIT}/iris-kas-sources.zip"
                    }
                }
            }
        }

        stage('Release: License Compliance') {
            // we assume releases are always tagged
            when {
                expression {
                    env.GIT_TAG != ''
                }
            }
            matrix {
                axes {
                    axis {
                        name 'MULTI_CONF'
                        values 'sc573-gen6', 'imx8mp-evk'
                    }
                }
                stages {
                    stage('Release: License Compliance') {
                        steps {
                            awsCodeBuild buildSpecFile: 'buildspecs/license_compliance.yml',
                                projectName: 'iris-devops-kas-large-amd-codebuild',
                                credentialsType: 'keys',
                                downloadArtifacts: 'false',
                                region: 'eu-central-1',
                                sourceControlType: 'project',
                                sourceTypeOverride: 'S3',
                                sourceLocationOverride: "${S3_BUCKET}/${JOB_NAME}/${GIT_COMMIT}/iris-kas-sources.zip",
                                artifactTypeOverride: 'S3',
                                artifactLocationOverride: "${S3_TEMP_BUCKET}",
                                artifactPathOverride: "${JOB_NAME}/${GIT_COMMIT}",
                                artifactNamespaceOverride: 'NONE',
                                artifactNameOverride: "${MULTI_CONF}-base-sources.zip",
                                artifactPackagingOverride: 'ZIP',
                                envVariables: "[{ MULTI_CONF, $MULTI_CONF }, { HOME, /home/builder }]"
                        }
                    }
                }
            }
        }

        stage('Release: Build Firmware Artifacts') {
            // we assume releases are always tagged
            when {
                expression {
                    env.GIT_TAG != ''
                }
            }
            matrix {
                axes {
                    axis {
                        name 'MULTI_CONF'
                        values 'sc573-gen6', 'imx8mp-evk'
                    }
                    axis {
                        name 'IMAGES'
                        values 'irma6-deploy irma6-maintenance irma6-dev'
                    }
                }
                stages {
                    // apperently yocto supports multiple simultaneous builds writing to the sstate cache: https://www.yoctoproject.org/irc/%23yocto.2021-08-27.log.html
                    stage('Release: Build Firmware Artifacts') {
                        steps {
                            awsCodeBuild buildSpecFile: 'buildspecs/build_firmware_images_release.yml',
                                projectName: 'iris-devops-kas-large-amd-codebuild',
                                credentialsType: 'keys',
                                downloadArtifacts: 'false',
                                region: 'eu-central-1',
                                sourceControlType: 'project',
                                sourceTypeOverride: 'S3',
                                sourceLocationOverride: "${S3_BUCKET}/${JOB_NAME}/${GIT_COMMIT}/iris-kas-sources.zip",
                                artifactTypeOverride: 'S3',
                                artifactLocationOverride: "${S3_TEMP_BUCKET}",
                                artifactPathOverride: "${JOB_NAME}/${GIT_COMMIT}",
                                artifactNamespaceOverride: 'NONE',
                                artifactNameOverride: "${MULTI_CONF}-firmware.zip",
                                artifactPackagingOverride: 'ZIP',
                                envVariables: "[ { MULTI_CONF, $MULTI_CONF }, { HOME, /home/builder }, { IMAGES, $IMAGES }, { SDK_IMAGE, $SDK_IMAGE } ]"
                        }
                    }
                }
            }
        }

        stage('Release: Sync SSTATE Caches & Archive Artifacts') {
            // we assume releases are always tagged
            when {
                expression {
                    env.GIT_TAG != ''
                }
            }
            parallel {
                stage('Release: Sync SSTATE Caches') {
                    steps {
                        awsCodeBuild buildSpecFile: 'buildspecs/sync_sstate_caches.yml',
                            projectName: 'iris-devops-kas-small-amd-codebuild',
                            credentialsType: 'keys',
                            downloadArtifacts: 'false',
                            region: 'eu-central-1',
                            sourceControlType: 'project',
                            sourceTypeOverride: 'S3',
                            sourceLocationOverride: "${S3_BUCKET}/${JOB_NAME}/${GIT_COMMIT}/iris-kas-sources.zip",
                            envVariables: "[ { GIT_BRANCH, $REAL_GIT_BRANCH } ]"
                    }
                }

                // prepare artifacts for archiving
                stage('Release: Archive Artifacts') {
                    steps {
                        script {
                            def MULTI_CONFS = ['sc573-gen6', 'imx8mp-evk']

                            for (int i = 0; i < MULTI_CONFS.size(); i++) {

                                // for each multiconfig create folders
                                sh "mkdir -p release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/external release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/internal"

                                // download base sources
                                s3Download bucket: "${S3_TEMP_BUCKET}",
                                    path: "${JOB_NAME}/${GIT_COMMIT}/${MULTI_CONFS[i]}-base-sources.zip",
                                    file: "${MULTI_CONFS[i]}-base-sources.zip",
                                    payloadSigningEnabled: true

                                // download firmware files
                                s3Download bucket: "${S3_TEMP_BUCKET}",
                                    path: "${JOB_NAME}/${GIT_COMMIT}/${MULTI_CONFS[i]}-firmware.zip",
                                    file: "${MULTI_CONFS[i]}-firmware.zip",
                                    payloadSigningEnabled: true

                                // extract base sources
                                unzip zipFile: "${MULTI_CONFS[i]}-base-sources.zip", dir: "${MULTI_CONFS[i]}-base-sources"
                                fileOperations([fileUnTarOperation(filePath: "${MULTI_CONFS[i]}-base-sources/${MULTI_CONFS[i]}-base-sources.tar",
                                    isGZIP: false,
                                    targetLocation: "release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/external/base-sources")])

                                // extract firmware files
                                unzip zipFile: "${MULTI_CONFS[i]}-firmware.zip", dir: "${MULTI_CONFS[i]}-firmware"
                                fileOperations([fileUnTarOperation(filePath: "${MULTI_CONFS[i]}-firmware/${MULTI_CONFS[i]}-deploy.tar",
                                    isGZIP: false,
                                    targetLocation: "release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/internal")])
                                fileOperations([fileUnTarOperation(filePath: "${MULTI_CONFS[i]}-firmware/${MULTI_CONFS[i]}-sources.tar",
                                    isGZIP: false,
                                    targetLocation: "release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/internal")])

                                // this will need to change with swupdate
                                sh "mkdir release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/external/update_files"
                                sh "mv release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/internal/deploy/images/*/update_files/*deploy* release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/external/update_files"

                                sh "mv release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/internal/deploy/licenses release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}/external/licenses"

                                dir("release-${ARTIFACT_NAME}/${MULTI_CONFS[i]}") {
                                    sh "tar -C internal/ -I 'gzip -9' -cf internal.tar.gz . && rm -rf internal"
                                    sh "tar -C external/ -I 'gzip -9' -cf external.tar.gz . && rm -rf external"
                                }
                            }
                        }
                        // upload release to release bucket
                        s3Upload acl: 'Private',
                            bucket: "${S3_BUCKET}",
                            includePathPattern: "release-${ARTIFACT_NAME}/**",
                            excludePathPattern: "release-${ARTIFACT_NAME}/{internal,external}",
                            path: 'releases',
                            payloadSigningEnabled: true,
                            sseAlgorithm: 'AES256'
                    }
                }
            }
        }
    }

    post {
        // Clean after build
        always {
            cleanWs(cleanWhenNotBuilt: false,
                    deleteDirs: true,
                    disableDeferredWipeout: true,
                    notFailBuild: true)
        }
    }
}
