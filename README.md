# oci-a1-retry

Retries an OCI Resource Manager stack **apply** on a schedule until an Ampere A1 instance
can be created (works around "Out of host capacity"). Stops itself after the first success.

All values come from GitHub Secrets; nothing sensitive is stored in this repository.

Secrets: `OCI_USER_OCID`, `OCI_TENANCY_OCID`, `OCI_FINGERPRINT`, `OCI_PRIVATE_KEY`,
`OCI_REGION`, `OCI_STACK_ID`.

After success: delete the OCI API key of the dedicated user and consider deleting this repo.
