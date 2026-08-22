terraform {
  backend "s3" {
    bucket       = "openhelp-terraform-platform-state-5739c46b679a"
    key          = "test/platform/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
    kms_key_id   = "arn:aws:kms:us-east-1:720973523623:alias/openhelp-platform-state"
  }
}
