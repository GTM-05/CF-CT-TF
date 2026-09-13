# Architecture

Status: **same factory arc as production, Terraform implementation IN DEVELOPMENT until the first VALIDATED batch**. Legacy AWS orchestration remains the live path until Terraform owns a batch.

## Same arc as the existing factory

The new platform keeps the **same ordered flow** as Valeo production. Only the engines change.

| Order | Existing (today) | New (this repo) |
| --- | --- | --- |
| 1 | User | User |
| 2 | Service Catalog | Git YAML/JSON + schema/policy |
| 3 | Valeo Account Factory + CFN wrapper | `terraform/stacks/account-vending` |
| 4 | Control Tower Account Factory | AWS Control Tower + adapter (no fake TF resources) |
| 5 | EventBridge | GitLab pipeline trigger |
| 6 | Step Functions | GitLab stage DAG + Terraform graph |
| 7 | CodePipeline / CodeBuild | GitLab CI / runner |
| 8 | SCP Step Function | `terraform/stacks/organization` |
| 9 | StackSet Step Function + StackSets | `terraform/stacks/account-baseline` + consolidated modules |
| 10 | Stack instances / stacks | Per-account state + Terraform resources |

```mermaid
flowchart TD
  U[User] --> R[Request]
  R --> AF[Account factory]
  AF --> CT[Control Tower]
  CT --> ORCH[Orchestration]
  ORCH --> SCP[SCP]
  SCP --> BL[Baselines / StackSets]
  BL --> AWS[AWS resources]
```

That diagram is valid for **both** systems. Existing uses Service Catalog + Step Functions + StackSets. New uses Git + GitLab + Terraform. See `pipeline/arc.yaml`.

Terraform is the IaC/orchestration layer. AWS Control Tower is the AWS-native governance boundary. Terraform does not replace Control Tower.

## 1. Current architecture

```mermaid
flowchart TD
  User[User] --> SC[AWS Service Catalog]
  SC --> VAF[Valeo Account Factory]
  VAF --> WRAP[CloudFormation Wrapper]
  WRAP --> CTAF[Control Tower Account Factory]
  CTAF --> EB[EventBridge]
  EB --> SF[Step Functions]
  SF --> CP[CodePipeline]
  CP --> CB[CodeBuild]
  CB --> SCPSF[SCP Step Function]
  CB --> SSSF[StackSet Step Function]
  SCPSF --> ORG[AWS Organizations SCPs]
  SSSF --> SS[~86 CloudFormation StackSets]
  SS --> SI[Stack Instances]
  SI --> STK[CloudFormation Stacks]
  STK --> RES[AWS Resources]
```

## 2. Target architecture

```mermaid
flowchart TD
  User[Platform team] --> YAML[Account request YAML or JSON]
  YAML --> Git[Git repository]
  Git --> Val[Schema and policy validation]
  Val --> Plan[Terraform plan]
  Plan --> Appr[Approval]
  Appr --> Apply[Terraform apply]
  Apply --> CT[AWS Control Tower governance]
  Apply --> State[Terraform state]
  CT --> Acct[Member account]
  Acct --> Role[Cross-account Terraform role]
  Role --> Mods[Terraform modules]
  Mods --> IAM[IAM]
  Mods --> Net[Network]
  Mods --> Sec[Security]
  Mods --> KMS[KMS]
  Mods --> SSM[SSM]
  Mods --> Other[Backup / monitoring / config / EC2 / RDS / logging]
  Other --> AWS[AWS resources]
```

## 3. Existing 579-account migration

Inventory, Control Tower enrollment, and Terraform import are three different processes.

```mermaid
flowchart TD
  Env[Existing environment]
  Env --> Acc[579 accounts]
  Env --> SS[~86 StackSets]
  Acc --> Inv[Inventory]
  SS --> CFN[CloudFormation analysis]
  Inv --> Map[Migration map]
  CFN --> Map
  Map --> TF[Terraform modules]
  TF --> Imp[Import existing]
  Imp --> Plan[Terraform plan]
  Plan --> Val[Validate: stop on destroy or replace]
  Val --> Appr[Approve]
  Appr --> Mgmt[Terraform managed]
  Mgmt --> Decom[Decommission legacy]
```

```mermaid
flowchart LR
  Existing[Existing account]
  Existing --> Inv[Inventory / resource discovery]
  Inv --> Adopt[Terraform adoption]
  Existing --> CT[Control Tower register or enroll]
  CT --> Gov[Governance]
```

Do not import inventory into Control Tower.

## 4. CloudFormation to Terraform migration

```mermaid
flowchart TD
  SS[StackSet] --> SI[Stack instance]
  SI --> STK[CloudFormation stack]
  STK --> RES[AWS resources]
  RES --> Parse[Parse template]
  Parse --> Classify[MIGRATE / CONSOLIDATE / RETAIN / REMOVE / MANUAL REVIEW]
  Classify --> Mod[Terraform module - not 1:1 with StackSets]
  Mod --> Imp[terraform import]
  Imp --> Plan[terraform plan]
  Plan --> Own[Terraform exclusive ownership]
```

## 5. New account provisioning

```mermaid
flowchart TD
  U[User] --> R[YAML / JSON]
  R --> G[Git]
  G --> P[Schema + policy]
  P --> TP[Terraform plan]
  TP --> A[Approval]
  A --> TA[Terraform apply]
  TA --> CT[Control Tower]
  CT --> M[Member account]
  M --> Role[Cross-account Terraform role]
  Role --> Mods[Terraform modules]
  Mods --> AWS[AWS resources]
```

## 6. Cross-account Terraform execution

```mermaid
flowchart TD
  Runner[GitLab runner] --> TF[Terraform]
  TF --> STS[STS AssumeRole]
  STS --> Role[Dedicated Terraform role or AWSControlTowerExecution]
  Role --> Member[Member account]
  Member --> Prov[AWS provider alias member]
  Prov --> Res[AWS resources]
```

Execution stays centralized. Credentials are never hardcoded.

## 7. Terraform state architecture

```mermaid
flowchart TD
  Backend[Configurable S3 backend + DynamoDB lock]
  Backend --> Acc[Per account]
  Acc --> Env[Per environment]
  Env --> Region[Per region]
  Region --> Stack[Per platform stack]
  Stack --> File["aws/account-ID/env/region/baseline.tfstate"]
```

See [TERRAFORM-STATE.md](TERRAFORM-STATE.md). One state file for 579 accounts is rejected.

## 8. CI/CD flow

```mermaid
flowchart TD
  Push[Git push / MR] --> V[validate]
  V --> S[security]
  S --> Init[terraform-init]
  Init --> Plan[terraform-plan]
  Plan --> Gate[Destructive-change detector]
  Gate --> Manual[Manual approval - production]
  Manual --> Apply[terraform-apply]
  Drift[Scheduled pipeline] --> PlanOnly[terraform plan]
  PlanOnly --> Report[Drift report]
  Report --> NoAuto[No automatic overwrite]
```

## 9. Control Tower boundary

```mermaid
flowchart LR
  subgraph ct [Control Tower]
    Enroll[Enrollment / registration]
    OU[OU governance]
    LZ[Landing zone]
    Guard[Guardrails / controls]
  end
  subgraph tf [Terraform]
    Res[IAM SCP KMS SSM Backup Monitoring Config Network Baselines]
    State[State]
  end
  Adapter[Control Tower adapter]
  tf --> Adapter
  Adapter -.->|only supported APIs or documented external integration| ct
```

Unsupported Control Tower APIs are **not** implemented as fake Terraform resources. The adapter documents the limitation and lists approved external options.

## 10. Final end-to-end architecture

```mermaid
flowchart TD
  USER[USER] --> REQ[ACCOUNT REQUEST YAML / JSON]
  REQ --> GIT[GIT REPOSITORY]
  GIT --> CHK[Schema + policy check]
  CHK --> PLAN[TERRAFORM PLAN]
  PLAN --> APPROVAL[APPROVAL]
  APPROVAL --> APPLY[TERRAFORM APPLY]
  APPLY --> CT[AWS CONTROL TOWER]
  APPLY --> ST[TERRAFORM STATE]
  CT --> MEMBER[MEMBER ACCOUNT]
  MEMBER --> XROLE[CROSS-ACCOUNT ROLE]
  XROLE --> MODS[TERRAFORM MODULES]
  MODS --> IAM[IAM]
  MODS --> NET[Network]
  MODS --> SEC[Security]
  MODS --> KMS[KMS]
  MODS --> SSM[SSM]
  MODS --> REST[Backup / monitoring / config / EC2 / RDS / logging]
  REST --> AWS[AWS RESOURCES]
```

## Mapping of legacy orchestration

| Legacy | Replacement |
| --- | --- |
| Service Catalog custom workflow | Git account request |
| CloudFormation wrapper | Terraform account configuration |
| EventBridge | GitLab pipeline trigger |
| Step Functions | Terraform dependency graph |
| CodePipeline | GitLab CI/CD |
| CodeBuild | GitLab runner |
| SCP Step Function | `aws_organizations_policy` |
| StackSet Step Function | Terraform modules |
| CloudFormation StackSets | Consolidated Terraform modules |
| CloudFormation stacks | Terraform-managed resources |

## Responsibilities

| Layer | Owns |
| --- | --- |
| Control Tower | Account governance, enrollment, OUs, landing zone, CT controls |
| Terraform | Platform resources with provider support, SCPs, baselines, state |
| GitLab | Validation, plan, approval, apply, drift plan jobs |
| Inventory CLI | What exists |
| Terraform state | What Terraform manages |

## Status of this codebase

| Area | Status |
| --- | --- |
| Request schema, policy, CI skeleton | IN DEVELOPMENT |
| Terraform modules | IN DEVELOPMENT (skeletons; dry_run disables apply) |
| Inventory | Fixtures + optional live Organizations list |
| StackSet analysis | Sample catalog, not 86 live StackSets |
| Import / cutover | PROPOSED workflow only |
| Decommission of Service Catalog / Step Functions | Not started |
