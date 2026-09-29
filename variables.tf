variable "name" {
  default     = null
  description = "Name of the knowledge base."
}

variable "description" {
  default     = null
  description = "Description of the knowledge base."
}

variable "role_arn" {
  default     = null
  description = "The ARN of the IAM role Bedrock assumes to read the data source, call the embedding model, and write to the vector store."
}

variable "embedding_model_arn" {
  default     = null
  description = "The ARN of the foundation model used to embed chunks, e.g. arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0. The model's output dimension has to match the vector column in your store — see the README."
}

variable "storage_type" {
  default     = "RDS"
  description = "Where vectors are stored. 'RDS' is Aurora PostgreSQL with pgvector and is the default because it can scale toward zero when idle. 'OPENSEARCH_SERVERLESS' is the conventional choice and carries a large standing charge — see the README before picking it."

  validation {
    condition     = contains(["RDS", "OPENSEARCH_SERVERLESS"], var.storage_type)
    error_message = "storage_type must be 'RDS' or 'OPENSEARCH_SERVERLESS'."
  }
}

variable "rds" {
  default     = null
  description = "Aurora PostgreSQL vector store. The cluster, the pgvector extension and the table all have to exist before this applies — Bedrock connects to them, it does not create them. Feed resource_arn from terraform-aws-rds-cluster."
  type = object({
    resource_arn           = string
    credentials_secret_arn = string
    database_name          = string
    table_name             = optional(string, "bedrock_integration.bedrock_kb")
    primary_key_field      = optional(string, "id")
    text_field             = optional(string, "chunks")
    vector_field           = optional(string, "embedding")
    metadata_field         = optional(string, "metadata")
  })
}

variable "opensearch_serverless" {
  default     = null
  description = "OpenSearch Serverless vector store. Only used when storage_type is OPENSEARCH_SERVERLESS."
  type = object({
    collection_arn    = string
    vector_index_name = string
    vector_field      = optional(string, "bedrock-knowledge-base-default-vector")
    text_field        = optional(string, "AMAZON_BEDROCK_TEXT_CHUNK")
    metadata_field    = optional(string, "AMAZON_BEDROCK_METADATA")
  })
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the knowledge base."
}
