mock_provider "aws" {}

variables {
  role_arn            = "arn:aws:iam::123456789012:role/example"
  embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"

  rds = {
    resource_arn           = "arn:aws:rds:us-east-1:123456789012:cluster:example"
    credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:example"
    database_name          = "vectors"
  }
}

run "rds_storage_without_an_rds_object_is_rejected" {
  command = plan

  variables {
    rds = null
  }

  expect_failures = [aws_bedrockagent_knowledge_base.resource]
}

run "opensearch_storage_without_its_object_is_rejected" {
  command = plan

  variables {
    storage_type          = "OPENSEARCH_SERVERLESS"
    rds                   = null
    opensearch_serverless = null
  }

  expect_failures = [aws_bedrockagent_knowledge_base.resource]
}

run "an_unknown_storage_type_is_rejected" {
  command = plan

  variables {
    storage_type = "PINECONE"
  }

  expect_failures = [var.storage_type]
}

run "defaults_to_aurora_with_conventional_field_names" {
  command = apply

  assert {
    condition     = aws_bedrockagent_knowledge_base.resource.name == random_uuid.resource.id
    error_message = "With no name given, the knowledge base should use the generated random_uuid."
  }

  assert {
    condition     = aws_bedrockagent_knowledge_base.resource.storage_configuration[0].type == "RDS"
    error_message = "Storage should default to RDS - Aurora with pgvector scales toward zero, OpenSearch Serverless does not."
  }

  assert {
    condition     = length(aws_bedrockagent_knowledge_base.resource.storage_configuration[0].rds_configuration) == 1
    error_message = "An rds_configuration block should be emitted for RDS storage."
  }

  assert {
    condition     = length(aws_bedrockagent_knowledge_base.resource.storage_configuration[0].opensearch_serverless_configuration) == 0
    error_message = "No OpenSearch block should be emitted while storage_type is RDS."
  }

  assert {
    condition     = aws_bedrockagent_knowledge_base.resource.storage_configuration[0].rds_configuration[0].table_name == "bedrock_integration.bedrock_kb"
    error_message = "table_name should default to the schema-qualified table the AWS documentation uses."
  }

  assert {
    condition     = aws_bedrockagent_knowledge_base.resource.storage_configuration[0].rds_configuration[0].field_mapping[0].vector_field == "embedding"
    error_message = "The vector column should default to 'embedding'."
  }

  assert {
    condition     = aws_bedrockagent_knowledge_base.resource.knowledge_base_configuration[0].type == "VECTOR"
    error_message = "The knowledge base configuration should be of type VECTOR."
  }
}

run "explicit_name_overrides_generated_uuid" {
  command = plan

  variables {
    name = "docs"
  }

  assert {
    condition     = aws_bedrockagent_knowledge_base.resource.name == "docs"
    error_message = "An explicit name should be used instead of the generated UUID."
  }
}

run "field_names_can_be_overridden" {
  command = plan

  variables {
    rds = {
      resource_arn           = "arn:aws:rds:us-east-1:123456789012:cluster:example"
      credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:example"
      database_name          = "vectors"
      table_name             = "public.chunks"
      vector_field           = "vec"
    }
  }

  assert {
    condition     = aws_bedrockagent_knowledge_base.resource.storage_configuration[0].rds_configuration[0].table_name == "public.chunks"
    error_message = "An explicit table_name should be passed through."
  }

  assert {
    condition     = aws_bedrockagent_knowledge_base.resource.storage_configuration[0].rds_configuration[0].field_mapping[0].vector_field == "vec"
    error_message = "An explicit vector_field should be passed through."
  }

  assert {
    condition     = aws_bedrockagent_knowledge_base.resource.storage_configuration[0].rds_configuration[0].field_mapping[0].text_field == "chunks"
    error_message = "Unspecified field names should keep their defaults."
  }
}

run "opensearch_serverless_is_supported" {
  command = plan

  variables {
    storage_type = "OPENSEARCH_SERVERLESS"
    rds          = null

    opensearch_serverless = {
      collection_arn    = "arn:aws:aoss:us-east-1:123456789012:collection/abc123"
      vector_index_name = "bedrock-knowledge-base-default-index"
    }
  }

  assert {
    condition     = length(aws_bedrockagent_knowledge_base.resource.storage_configuration[0].opensearch_serverless_configuration) == 1
    error_message = "An OpenSearch Serverless block should be emitted when that storage type is chosen."
  }

  assert {
    condition     = length(aws_bedrockagent_knowledge_base.resource.storage_configuration[0].rds_configuration) == 0
    error_message = "No RDS block should be emitted while storage_type is OPENSEARCH_SERVERLESS."
  }
}
