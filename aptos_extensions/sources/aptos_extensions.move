module aptos_extensions::aptos_extensions {
    use aptos_framework::resource_account;

    // === Write functions ===

    /// This function consumes the signer capability and drops it because the package is deployed to a resource account
    /// and we want to prevent future changes to the account after the deployment.
    fun init_module(resource_signer: &signer) {
        resource_account::retrieve_resource_account_cap(resource_signer, @deployer);
    }

    // === Test-only ===

    #[test_only]
    public fun test_init_module(resource_acct: &signer) {
        init_module(resource_acct);
    }
}