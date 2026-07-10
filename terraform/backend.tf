terraform {
  backend "s3" {
    bucket         = "unimart-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "unimart-terraform-lock"
  }
}
