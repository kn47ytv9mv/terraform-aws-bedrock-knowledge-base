resource "random_uuid" "resource" {}

resource "aws_bedrockagent_knowledge_base" "resource" {
  name        = coalesce(var.name, random_uuid.resource.id)
  description = var.description
  role_arn    = var.role_arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = var.embedding_model_arn
    }
  }

  storage_configuration {
    type = var.storage_type

    dynamic "rds_configuration" {
      for_each = var.storage_type == "RDS" ? var.rds[*] : []

      content {
        resource_arn           = rds_configuration.value.resource_arn
        credentials_secret_arn = rds_configuration.value.credentials_secret_arn
        database_name          = rds_configuration.value.database_name
        table_name             = rds_configuration.value.table_name

        field_mapping {
          primary_key_field = rds_configuration.value.primary_key_field
          text_field        = rds_configuration.value.text_field
          vector_field      = rds_configuration.value.vector_field
          metadata_field    = rds_configuration.value.metadata_field
        }
      }
    }

    dynamic "opensearch_serverless_configuration" {
      for_each = var.storage_type == "OPENSEARCH_SERVERLESS" ? var.opensearch_serverless[*] : []

      content {
        collection_arn    = opensearch_serverless_configuration.value.collection_arn
        vector_index_name = opensearch_serverless_configuration.value.vector_index_name

        field_mapping {
          vector_field   = opensearch_serverless_configuration.value.vector_field
          text_field     = opensearch_serverless_configuration.value.text_field
          metadata_field = opensearch_serverless_configuration.value.metadata_field
        }
      }
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.storage_type != "RDS" || var.rds != null
      error_message = "storage_type is RDS, so the rds object is required. It points Bedrock at an existing Aurora cluster, secret, database and table."
    }

    precondition {
      condition     = var.storage_type != "OPENSEARCH_SERVERLESS" || var.opensearch_serverless != null
      error_message = "storage_type is OPENSEARCH_SERVERLESS, so the opensearch_serverless object is required."
    }
  }
}

output "id" {
  description = "The ID of the knowledge base. Feed this into terraform-aws-bedrock-data-source's knowledge_base_id."
  value       = aws_bedrockagent_knowledge_base.resource.id
}

output "arn" {
  description = "The ARN of the knowledge base."
  value       = aws_bedrockagent_knowledge_base.resource.arn
}

output "name" {
  description = "The name of the knowledge base."
  value       = aws_bedrockagent_knowledge_base.resource.name
}
