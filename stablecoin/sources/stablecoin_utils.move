module stablecoin::stablecoin_utils {
    use aptos_framework::object;

    friend stablecoin::blocklistable;
    friend stablecoin::metadata;
    friend stablecoin::stablecoin;
    friend stablecoin::treasury;

    const STABLECOIN_OBJ_SEED: vector<u8> = b"stablecoin";

    /// Returns the stablecoin's named object seed value.
    public(friend) fun stablecoin_obj_seed(): vector<u8> {
        STABLECOIN_OBJ_SEED
    }

    /// Returns the stablecoin's object address.
    public(friend) fun stablecoin_address(): address {
        object::create_object_address(&@stablecoin, STABLECOIN_OBJ_SEED)
    }

    // === Test Only ===

    #[test_only]
    friend stablecoin::stablecoin_utils_tests;
    #[test_only]
    friend stablecoin::stablecoin_tests;
    #[test_only]
    friend stablecoin::stablecoin_e2e_tests;
    #[test_only]
    friend stablecoin::blocklistable_tests;
    #[test_only]
    friend stablecoin::treasury_tests;
    #[test_only]
    friend stablecoin::metadata_tests;
    #[test_only]
    friend stablecoin::fungible_asset_tests;
}