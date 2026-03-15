# AWS S3 and IAM Setup for Phoenix/Elixir

Reference for creating S3 buckets, scoped IAM users, and wiring up ExAws in an Elixir application. Covers multi-environment setup, CLI commands, and JSON policy documents.

## Prerequisites

```bash
brew install awscli
aws configure
aws sts get-caller-identity
```

---

## 1. S3 Bucket Creation

### Naming conventions

Use environment suffixes. Bucket names are globally unique.

| Environment | Bucket name |
|-------------|-------------|
| prod | `myproject-uploads` |
| uat | `myproject-uploads-uat` |
| dev | local disk (no bucket) |

### Create and lock down

```bash
aws s3api create-bucket --bucket myproject-uploads --region us-east-1

aws s3api put-public-access-block \
  --bucket myproject-uploads \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Note: `us-east-1` does not accept `--create-bucket-configuration`. For other regions add `--create-bucket-configuration LocationConstraint=eu-central-1`.

### Optional: lifecycle policy

Save as `lifecycle.json`:
```json
{
  "Rules": [
    {
      "ID": "expire-old-files",
      "Status": "Enabled",
      "Filter": { "Prefix": "files/" },
      "Expiration": { "Days": 90 }
    }
  ]
}
```

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket myproject-uploads --lifecycle-configuration file://lifecycle.json
```

### CORS (only for direct browser-to-S3 uploads)

Only needed if you use presigned PUT URLs from the frontend. If uploads go through Phoenix, skip this.

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "HEAD"],
    "AllowedOrigins": ["https://myapp.com", "https://uat.myapp.com"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

---

## 2. IAM User Creation

One IAM user per environment with least-privilege S3 access.

### Create users

```bash
aws iam create-user --user-name myproject-app-prod
aws iam create-user --user-name myproject-app-uat
```

### S3 policy document

Save as `s3-policy-prod.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
      "Resource": "arn:aws:s3:::myproject-uploads"
    },
    {
      "Sid": "ObjectOperations",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::myproject-uploads/*"
    }
  ]
}
```

### Create and attach policies

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-policy \
  --policy-name myproject-s3-prod \
  --policy-document file://s3-policy-prod.json

aws iam attach-user-policy \
  --user-name myproject-app-prod \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/myproject-s3-prod
```

### Generate access keys

```bash
aws iam create-access-key --user-name myproject-app-prod
```

Store `AccessKeyId` and `SecretAccessKey` in the server env file. Never in the repo.

### Rotate keys

```bash
# Create new key first
aws iam create-access-key --user-name myproject-app-prod
# Update server env, then delete old key
aws iam delete-access-key --user-name myproject-app-prod --access-key-id AKIAOLD...
```

---

## 3. ExAws Integration

### Dependencies

```elixir
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.5"},
{:sweet_xml, "~> 0.7"}
```

### Credential chain

ExAws resolves credentials in order:
1. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` env vars
2. EKS Pod Identity
3. EC2/ECS instance role

For local dev with `~/.aws/credentials` profiles, add `{:configparser_ex, "~> 4.0"}` and:
```elixir
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, "default", 30}],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, {:awscli, "default", 30}]
```

### Runtime config

```elixir
# config/runtime.exs
config :ex_aws, region: env!("AWS_REGION", :string, "us-east-1")

config :myapp, MyApp.Storage,
  bucket: env!("S3_BUCKET", :string, "myproject-uploads"),
  region: env!("AWS_REGION", :string, "us-east-1")
```

### Storage module pattern

```elixir
defmodule MyApp.Storage.S3 do
  @behaviour MyApp.Storage

  def store(binary, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "files")
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    key = "#{prefix}/#{uuid()}.#{extension(content_type)}"

    case bucket()
         |> ExAws.S3.put_object(key, binary, content_type: content_type)
         |> ExAws.request() do
      {:ok, _} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  defp config, do: Application.get_env(:myapp, MyApp.Storage, [])
  defp bucket, do: config()[:bucket] || "myproject-uploads"
end
```

### Test config

```elixir
# config/test.exs
config :myapp, MyApp.Storage,
  impl: MyApp.Storage.Local,
  test_dir: Path.join(System.tmp_dir!(), "myapp_test_uploads")
```

---

## 4. Presigned URLs (direct browser upload)

```elixir
def presigned_upload_url(key, content_type, expires_in \\ 300) do
  config = ExAws.Config.new(:s3)
  ExAws.S3.presigned_url(config, :put, bucket(), key,
    expires_in: expires_in,
    query_params: [{"Content-Type", content_type}]
  )
end
```

Only relevant if moving from server-side uploads to direct browser-to-S3 uploads.

---

## 5. Troubleshooting

**403 Forbidden** — IAM policy doesn't grant the action. Check resource ARN matches bucket name.

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT_ID:user/myproject-app-prod \
  --action-names s3:PutObject \
  --resource-arns "arn:aws:s3:::myproject-uploads/*"
```

**NoCredentialProviders** — No env vars found. Check Dotenvy is loading and `Storage.Local` is used in dev/test.

**NoSuchBucket** — Bucket name in `S3_BUCKET` doesn't match. Verify:
```bash
aws s3api list-buckets --query "Buckets[?starts_with(Name, 'myproject')]"
```

**Region mismatch** — `AWS_REGION` doesn't match bucket location:
```bash
aws s3api get-bucket-location --bucket myproject-uploads
```

---

## Sources

- [ExAws GitHub](https://github.com/ex-aws/ex_aws)
- [ExAws.S3 HexDocs](https://hexdocs.pm/ex_aws_s3/ExAws.S3.html)
- [AWS IAM S3 policy examples](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security_iam_id-based-policy-examples.html)
- [AWS S3 CORS](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enabling-cors-examples.html)
- [AWS S3 blocking public access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)
- [AWS IAM manage access keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)
