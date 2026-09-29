# terraform-aws-bedrock-knowledge-base

Terraform module for a Bedrock knowledge base, the retrieval half of a
RAG system. It embeds documents with a foundation model and stores the
vectors somewhere they can be queried.

## Cost

The knowledge base resource itself carries no charge. Everything
expensive sits underneath it, and the choice of vector store is the
largest decision here.

Aurora PostgreSQL Serverless v2, the default, is billed per capacity unit
per hour and scales toward zero when idle. OpenSearch Serverless is billed
per OCU-hour against a hard minimum that applies whether or not anything
queries the collection, so an idle collection costs the same as a busy
one. That minimum is the single most expensive thing a Bedrock tutorial
will leave running in an account, and it is why this module defaults to
Aurora rather than to the conventional choice.

On top of the store, embedding model invocations are billed at ingest
time and at query time: ingest cost scales with how much is indexed and
how often it is re-synced, query cost with traffic. Current rates are on
AWS's [Bedrock pricing](https://aws.amazon.com/bedrock/pricing/),
[Aurora pricing](https://aws.amazon.com/rds/aurora/pricing/) and
[OpenSearch Serverless pricing](https://aws.amazon.com/opensearch-service/pricing/)
pages.

## Design

`storage_type` selects the store and the matching object is then
required; the module rejects the half-configured case at plan time rather
than at apply.

### Applying this does not finish the job

Bedrock connects to the database. It does not build it. Before this module
can apply successfully the Aurora cluster has to exist and the database
has to be prepared outside Terraform:

- The `vector` extension must be created in the target database.
- The schema and table named in the configuration must exist, with the
  columns named in the field mapping. The default is
  `bedrock_integration.bedrock_kb`.
- The vector column must have the same dimension the embedding model
  outputs. A mismatch fails at ingest rather than at apply, which is a
  confusing place to discover it.
- A database user Bedrock can authenticate as must exist, with its
  credentials in the secret passed as `credentials_secret_arn`.
- The RDS Data API must be enabled on the cluster. Bedrock reaches Aurora
  through it rather than through an ordinary connection.

None of that is Terraform's to own, so it is a documented bootstrap step
rather than a gap in the module.

### What this module does not create

Not the vector store: use `terraform-aws-rds-cluster`. Not the data to
index: a knowledge base with no data source is an empty index, so add
`terraform-aws-bedrock-data-source`. Not the IAM role: Bedrock needs
permission to read the bucket, invoke the embedding model and reach the
store, and the role is built with `terraform-aws-iam-role`.

## Usage

```hcl
module "knowledge_base" {
  source = "kn47ytv9mv/bedrock-knowledge-base/aws"

  name     = "handbook"
  role_arn = module.knowledge_base_role.arn

  embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"

  rds = {
    resource_arn           = module.vectors.arn
    credentials_secret_arn = module.vectors_secret.arn
    database_name          = "vectors"
  }
}
```

Or directly from this repository:

```hcl
module "knowledge_base" {
  source = "github.com/kn47ytv9mv/terraform-aws-bedrock-knowledge-base"

  name     = "handbook"
  role_arn = module.knowledge_base_role.arn

  embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"

  rds = {
    resource_arn           = module.vectors.arn
    credentials_secret_arn = module.vectors_secret.arn
    database_name          = "vectors"
  }
}
```

With OpenSearch Serverless instead, knowing what its minimum costs:

```hcl
module "knowledge_base" {
  source = "kn47ytv9mv/bedrock-knowledge-base/aws"

  name     = "handbook"
  role_arn = module.knowledge_base_role.arn

  embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"

  storage_type = "OPENSEARCH_SERVERLESS"
  rds          = null

  opensearch_serverless = {
    collection_arn    = module.collection.arn
    vector_index_name = "bedrock-knowledge-base-default-index"
  }
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the knowledge base. | `null` | no |
| description | Description of the knowledge base. | `null` | no |
| role_arn | The ARN of the IAM role Bedrock assumes. | `null` | no |
| embedding_model_arn | The ARN of the foundation model used to embed chunks. | `null` | no |
| storage_type | `RDS` or `OPENSEARCH_SERVERLESS`. | `"RDS"` | no |
| rds | Aurora PostgreSQL vector store. Required when `storage_type` is `RDS`. | `null` | conditional |
| opensearch_serverless | OpenSearch Serverless vector store. Required when `storage_type` is `OPENSEARCH_SERVERLESS`. | `null` | conditional |
| tags | A map of tags to assign to the knowledge base. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the knowledge base. Feed into `terraform-aws-bedrock-data-source`. |
| arn | The ARN of the knowledge base. |
| name | The name of the knowledge base. |

## License

MIT — see [LICENSE.md](LICENSE.md).
