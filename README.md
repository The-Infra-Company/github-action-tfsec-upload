# github-action-tfsec-upload [![Latest Release](https://img.shields.io/github/release/The-Infra-Company/github-action-tfsec-upload.svg)](https://github.com/The-Infra-Company/github-action-tfsec-upload/releases/latest)

A GitHub Action to run tfsec and post the results to the GitHub Security tab.

![tfsec-findings](https://github.com/user-attachments/assets/b6b13af0-1bf3-40b1-8558-858ce9ee5a39)

## Usage

```yaml
name: tfsec

on:
  pull_request:
    branches: [ 'main' ]
    types: [ opened, synchronize, reopened, closed, labeled, unlabeled ]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Clone repo
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init
        working-directory: "terraform/modules/vpc"

      - name: Run tfsec
        uses: The-Infra-Company/github-action-tfsec-upload@v0.1.0
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          working_directory: "terraform/modules/vpc"
          tfsec_flags: "--exclude aws-iam-no-policy-wildcards"
```

<!-- action-docs-inputs source="action.yml" -->
## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `github_token` | <p>GITHUB_TOKEN</p> | `true` | `${{ github.token }}` |
| `working_directory` | <p>Directory to run the action on, from the repo root. Default is . (root of the repository)</p> | `false` | `.` |
| `tfsec_version` | <p>The version of tfsec to install. Default is latest.</p> | `false` | `latest` |
| `tfsec_flags` | <p>List of arguments to send to tfsec Default is blank.</p> | `false` | `""` |
<!-- action-docs-inputs source="action.yml" -->

<!-- action-docs-outputs source="action.yml" -->
## Outputs

| name | description |
| --- | --- |
| `tfsec-return-code` | <p>tfsec command return code</p> |
<!-- action-docs-outputs source="action.yml" -->
