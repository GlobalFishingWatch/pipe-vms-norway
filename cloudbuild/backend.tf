terraform {
  backend "gcs" {
    bucket = "gfw-int-infrastructure-tfstate-us-central1"
    prefix = "cloudbuild-pipe-vms-norway" # Not change for this project
  }
}
