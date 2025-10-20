provider "google" {
  project = "gfw-int-infrastructure"
}

locals {
  base_image = "us-central1-docker.pkg.dev/gfw-int-infrastructure/pipeline-core/pipe-vms-norway"
}

resource "google_cloudbuild_trigger" "pipe_vms_norway_trigger_tag" {
  name     = "pipe-vms-norway-tag"
  location = "us-central1"


  github {
    name  = "pipe-vms-norway"
    owner = "GlobalFishingWatch"
    push {
      tag       = ".*"
      invert_regex = false
    }

  }


  service_account = "projects/gfw-int-infrastructure/serviceAccounts/cloudbuild@gfw-int-infrastructure.iam.gserviceaccount.com"
  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "build"
      args = [
        "build",
        "-t", "$_BASE_IMAGE_NAME:$TAG_NAME",
        "-t", "$_BASE_IMAGE_NAME:latest",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "test"
      args = [
        "run",
        "--rm",
        "--entrypoint", "py.test",
        "$_BASE_IMAGE_NAME:latest"
      ]
    }

    images = [
      "$_BASE_IMAGE_NAME:$TAG_NAME",
      "$_BASE_IMAGE_NAME:latest",
    ]

    options {
      logging = "CLOUD_LOGGING_ONLY"
      dynamic_substitutions = true
    }

    timeout = "600s"
  }

  substitutions = {
    _BASE_IMAGE_NAME  = "${local.base_image}"
  }
}
