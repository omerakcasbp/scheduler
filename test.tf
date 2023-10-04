provider "aws" {
  alias = "aws"
}

module "resource-scheduler" {

  source = "./modules/resource-scheduler"

}
