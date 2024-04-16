variable "project_id" {
  description = "The project ID to deploy to."
}

variable "app_name" {
  type        = string
  description = "application name to propagate to resources"
}

variable "locations" {
  description = "Locations and resources to deploy"
  type        = map(map(string))
}

variable "machine_type" {
  description = "The type of instance the applications are to run on"
  type        = string
}