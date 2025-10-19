terraform {
  backend "s3" {
    bucket = "fraud-detection-bucket-yc"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }
}