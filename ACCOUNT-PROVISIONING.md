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

## Verification against Valeo production diagram (v1.0 Sep 2026)

Source: *Valeo AWS Control Tower – Complete Account Provisioning and Configuration Flow*.

**Verdict:** Same factory arc (request → CT account → configure → SCP + baselines → ready). Engines change. Step 7 in AWS is **parallel** SCP + StackSets; this repo applies **SCP then baseline** (safer, not identical concurrency).

| Valeo step | Production (diagram) | This repo | Match |
| --- | --- | --- | --- |
| **1 Request** | Service Catalog *Valeo Account Factory v4* (name, email, OU) | Git YAML + schema/policy | Same job, different intake |
| **2 CT Account Factory** | Create/enroll, LZ guardrails, CT baseline | AWS Control Tower **kept** + adapter (no fake TF enroll) | Same AWS control plane |
| **3 CFN wrapper** | `TriggerCoreAccountFactory` + SSM AccountMetadata | `stacks/account-vending` + Git request (no SSM replica yet) | Same job; metadata store differs |
| **4 EventBridge** | `CreateManagedAccount` SUCCEEDED | GitLab on merge of `requests/**` | Same trigger role |
| **5 Config Step Function** | 10 tasks, wait/retry up to 100 | GitLab DAG + Terraform graph | Same role; not 1:1 with all 10 tasks |
| **6 CICT CodePipeline** | Source → Build → SCP → StackSet | GitLab `scp` then `baseline` | Same stages, not CodePipeline |
| **7 Parallel config** | SCP path **and** StackSet path together | Apply SCP **then** baseline | Responsibilities yes; **not parallel** |
| **8 StackSets** | ~86 StackSets → member stack instances | Consolidated `account-baseline` modules | Same baselines, not 86 modules |
| **Ready** | CT + SCPs + StackSets + Valeo governance | Same checklist after proven apply | Target yes; not live-proven |

### Step 5 internals vs Terraform

| SFN task | Covered? | Where |
| --- | --- | --- |
| Enable Hong Kong region | No | Not in this platform |
| Wait/check status retry 100 | Partial | GitLab/Terraform, not a 100-loop waiter |
| Copy account metadata | Partial | Git YAML, not SSM AccountMetadata |
| Trigger CICT | Yes | Next GitLab stages |
| Set alternate contacts | No | Not implemented |
| Assign global roles | Yes | `modules/iam` |
| Share network resources | No | RAM/share not in network module |
| KMS + EBS encryption | Yes | `kms`, `security` |
| SNS topics | Yes | `monitoring` |
| Password policy | Yes | `security` |

### Step 8 member stacks vs modules

EC2 / RDS / Backup / SSM / Monitoring & Logging / Config → matching Terraform modules. Other → `network`, `security`, `kms`, `iam`, `account-resources`.

CloudTrail, CloudWatch, Config, SNS in the poster footer map to `logging`, `monitoring`, `config`.

Do not recreate `ct_account_configurations_step_functions`, `CustomControlTowerServiceControlPolicyMachine`, or `CustomControlTowerStackSetStateMachine`. Keep the **order of work** from the poster.

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
