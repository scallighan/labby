locals {
  cluster_name = "labby${random_string.unique.result}"
  func_name = "${local.cluster_name}func"
  loc_for_naming = lower(replace(var.location, " ", ""))
  gh_repo = replace(var.gh_repo, "implodingduck/", "")
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
  }
}