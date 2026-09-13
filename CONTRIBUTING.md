# Contributing

1. Do not apply Terraform against shared AWS from a laptop without a reviewed plan
2. Keep `migration.dry_run: true` unless you are in an approved batch
3. Never add fake Control Tower resources
4. Never add one module per StackSet without a CONSOLIDATE analysis
5. Run `pytest` and `valeotf validate-request` on sample files
6. Run `terraform fmt` before merge
7. Secrets stay out of Git, outputs, and examples (ARNs only)

See [DOCS.md](DOCS.md) for the documentation map. Follow [FLOW.md](FLOW.md); do not reorder GitLab stages without `pipeline/arc.yaml`.
