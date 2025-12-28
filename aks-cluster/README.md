```markdown
# Terraform: AKS + AzureAD + Log Analytics (refactor)

This repo provisions:
- Resource Group
- Azure AD group for AKS admins
- Log Analytics workspace
- AKS cluster (system node pool)

Key improvements:
- Cleaner file separation (providers, backend, variables, locals)
- No insecure hard-coded passwords (mark sensitive)
- Recommended provider version pinning
- Tagging via locals
- Remote backend placeholder in backend.tf

Quick usage
1. Install Terraform >= 1.2.0
2. Populate backend.tf with your real backend details (or use CLI -backend-config)
3. Provide secrets via environment variables or `terraform.tfvars` (DO NOT commit)
4. Initialize:
   terraform init
5. Plan:
   terraform plan -out=tfplan
6. Apply:
   terraform apply tfplan

Notes
- Review the `role_based_access_control` / `azure_active_directory` block to match your azurerm provider version. If you use a different major provider version, consult the provider docs for correct attribute names.
- Use modules for production. The `modules/` directory is suggested for future refactor.
```