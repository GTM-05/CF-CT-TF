# Account provisioning

New accounts and existing-account adoption share one cloud-neutral request schema: `schemas/account-request.schema.yaml`.

## Architecture (same flow as AWS factory)

One ordered arc. AWS today uses Service Catalog + Step Functions + StackSets. This repo uses Git + GitLab + Terraform. **Control Tower stays AWS.**

```mermaid
flowchart TD
  U[User] --> R[Request]
  R --> AF[Account factory]
  AF --> CT[AWS Control Tower]
  CT --> ORCH[Orchestration]
  ORCH --> SCP[SCP]
  SCP --> BL[Baselines / StackSets]
  BL --> AWS[AWS resources]
```

```mermaid
flowchart LR
  subgraph existing [Existing AWS]
    E1[Service Catalog] --> E2[Valeo Account Factory]
    E2 --> E3[CFN wrapper]
    E3 --> E4[CT Account Factory]
    E4 --> E5[EventBridge]
    E5 --> E6[Step Functions]
    E6 --> E7[CodePipeline / CodeBuild]
    E7 --> E8[SCP Step Function]
    E8 --> E9[StackSet Step Function]
    E9 --> E10[StackSets / stacks]
    E10 --> E11[AWS resources]
  end

  subgraph next [New - same order]
    N1[Git YAML / JSON] --> N2[Schema + policy]
    N2 --> N3[account-vending]
    N3 --> N4[Control Tower adapter]
    N4 --> N5[GitLab trigger]
    N5 --> N6[GitLab stage DAG]
    N6 --> N7[GitLab runner]
    N7 --> N8[organization SCPs]
    N8 --> N9[account-baseline modules]
    N9 --> N10[Per-account state]
    N10 --> N11[AWS resources]
  end
```

```mermaid
flowchart TD
  A[request-validate] --> B[security]
  B --> C[account-factory]
  C --> D[scp]
  D --> E[baseline]
  E --> F[resources]
  F --> G[approval]
  G --> H[apply]
```

## Terraform flow mapped to the arc

GitLab stages stay the factory order. Each Terraform stack is the engine for one arc step. Apply order is the same: vending → SCP → baseline.

```mermaid
flowchart TD
  YAML[Account request YAML] --> VAL[schema + policy]
  VAL --> INIT[terraform init]

  subgraph arc [Same factory arc]
    S1[account-factory]
    S2[scp]
    S3[baseline]
    S4[resources]
    S1 --> S2 --> S3 --> S4
  end

  INIT --> S1
  S1 --> TV[stack: account-vending]
  TV --> MODV[module account-vending]
  MODV --> ORGA[aws_organizations_account]
  TV --> CTAD[module control-tower-adapter]
  CTAD --> CT[AWS Control Tower APIs - not fake TF]

  S2 --> TO[stack: organization]
  TO --> SCP[module organizations-scp]
  SCP --> POL[aws_organizations_policy + attachment]
  TO --> OIDC[module gitlab-oidc optional]

  S3 --> TB[stack: account-baseline]
  TB --> PROV[provider aws.member AssumeRole]
  PROV --> M1[iam plan/apply roles]
  PROV --> M2[kms]
  PROV --> M3[network]
  PROV --> M4[security]
  PROV --> M5[ssm]
  PROV --> M6[backup]
  PROV --> M7[monitoring]
  PROV --> M8[config]
  PROV --> M9[logging]
  PROV --> M10[ec2-baseline]
  PROV --> M11[rds-baseline]

  S4 --> TR[stack: account-resources]
  TR --> EXTRA[extra per-account workloads]

  M1 --> ST[(state per account / env / region / stack)]
  M11 --> ST
  POL --> ST
  ST --> PLAN[terraform plan]
  PLAN --> GATE[valeotf check-plan]
  GATE --> APPR[manual approval]
  APPR --> APPLY1[apply vending]
  APPLY1 --> APPLY2[apply SCP]
  APPLY2 --> APPLY3[apply baseline]
  APPLY3 --> AWS[AWS resources]
```

```mermaid
sequenceDiagram
  participant User
  participant Git
  participant GitLab
  participant TF as Terraform
  participant CT as Control Tower
  participant Member as Member account

  User->>Git: request YAML
  Git->>GitLab: request-validate + security
  GitLab->>TF: account-factory plan<br/>stacks/account-vending
  TF->>CT: adapter contract / enroll APIs
  GitLab->>TF: scp plan<br/>stacks/organization
  GitLab->>TF: baseline plan<br/>stacks/account-baseline
  TF->>Member: AssumeRole aws.member
  GitLab->>User: approval
  User->>GitLab: approve
  GitLab->>TF: apply vending then SCP then baseline
  TF->>Member: modules IAM KMS network ...
```

| Order | Existing AWS | This repo |
| --- | --- | --- |
| 1 | User | User |
| 2 | Service Catalog | Git YAML + schema/policy |
| 3 | Valeo Account Factory + CFN wrapper | `terraform/stacks/account-vending` |
| 4 | Control Tower Account Factory | AWS Control Tower + adapter |
| 5 | EventBridge | GitLab pipeline trigger |
| 6 | Step Functions | GitLab DAG + Terraform graph |
| 7 | CodePipeline / CodeBuild | GitLab CI / runner |
| 8 | SCP Step Function | `terraform/stacks/organization` |
| 9 | StackSet Step Function + StackSets | `terraform/stacks/account-baseline` |
| 10 | Stacks | Per-account state + modules |

Do not use AWS-specific request fields such as `AWSAccountName`. Use `account.name`, `cloud.provider`, `cloud.region`, `account.requested_ou`.

## New account

```text
User → YAML/JSON → Git → schema + policy → terraform plan → approval
  → terraform apply → Control Tower → member account
  → cross-account role → modules → AWS resources
```

Control Tower enrollment that has no Terraform resource is requested through the adapter (`enroll_if_unenrolled`). The adapter does not fake enrollment.

## Adopt existing

Set:

```yaml
account:
  existing_account_id: "123456789012"
migration:
  mode: adopt-existing
  batch_id: batch-001
  dry_run: true
```

This does not recreate the account. It generates variables and import candidates only.

## Pipeline separation

VALIDATION → PLAN → APPROVAL → APPLY

Production apply is a GitLab `when: manual` job.
