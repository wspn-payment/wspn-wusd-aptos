#[test_only]
module stablecoin::wusd_tests {
    use std::signer;
    use std::option;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object;
    use aptos_framework::fungible_asset::Metadata;
    use stablecoin::wusd;

    // Test account addresses
    const CREATOR: address = @stablecoin;
    const USER1: address = @0x456;
    const USER2: address = @0x789;

    // Test helper function
    fun setup_test(): signer {
        let creator = account::create_account_for_test(CREATOR);
        wusd::init_for_test(&creator);
        creator
    }

    #[test(creator = @stablecoin)]
    fun test_basic_flow(creator: &signer) {
        // Initialize
        wusd::init_for_test(creator);
        
        // Test minting
        let amount = 1000;
        wusd::mint(creator, signer::address_of(creator), amount);
        let _metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(signer::address_of(creator), _metadata) == amount, 0);

        // Test transfer
        let transfer_amount = 500;
        primary_fungible_store::transfer(creator, _metadata, USER1, transfer_amount);
        assert!(primary_fungible_store::balance(USER1, _metadata) == transfer_amount, 0);
        assert!(primary_fungible_store::balance(signer::address_of(creator), _metadata) == amount - transfer_amount, 0);

        // Test burning
        wusd::burn(creator, transfer_amount);
        assert!(primary_fungible_store::balance(signer::address_of(creator), _metadata) == 0, 0);
    }

    #[test(creator = @stablecoin)]
    fun test_freeze_flow(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Mint tokens
        let amount = 1000;
        wusd::mint(creator, USER1, amount);
        let _metadata = wusd::metadata();

        // Test freezing account
        let accounts = vector[USER1];
        wusd::freeze_accounts(creator, accounts);
        assert!(wusd::is_frozen(USER1), 0);

        // Test unfreezing account
        wusd::unfreeze_accounts(creator, accounts);
        assert!(!wusd::is_frozen(USER1), 0);
    }

    #[test(creator = @stablecoin)]
    #[expected_failure(abort_code = 5)]
    fun test_transfer_when_frozen(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Mint tokens
        let amount = 1000;
        wusd::mint(creator, signer::address_of(creator), amount);
        let _metadata = wusd::metadata();

        // Freeze account
        let accounts = vector[signer::address_of(creator)];
        wusd::freeze_accounts(creator, accounts);

        // Transfer should fail
        primary_fungible_store::transfer(creator, _metadata, USER1, 500);
    }

    #[test(creator = @stablecoin)]
    fun test_pause_flow(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Test pausing
        wusd::set_pause(creator, true);
        assert!(wusd::paused(), 0);

        // Test unpausing
        wusd::set_pause(creator, false);
        assert!(!wusd::paused(), 0);
    }

    #[test(creator = @stablecoin)]
    #[expected_failure(abort_code = 2)]
    fun test_mint_when_paused(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Pause contract
        wusd::set_pause(creator, true);

        // Mint should fail
        wusd::mint(creator, USER1, 1000);
    }

    #[test(creator = @stablecoin)]
    fun test_role_management(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Test adding minter
        wusd::grant_role(creator, 1, USER1); // Role 1 is minter
        assert!(wusd::hasRole(1, USER1), 0);

        // Test revoking minter
        wusd::revoke_role(creator, 1, USER1);
        assert!(!wusd::hasRole(1, USER1), 0);
    }

    #[test(creator = @stablecoin)]
    #[expected_failure(abort_code = 1)]
    fun test_unauthorized_mint(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Create unauthorized user
        let unauthorized = account::create_account_for_test(USER1);
        
        // Mint should fail
        wusd::mint(&unauthorized, USER2, 1000);
    }

    #[test(creator = @stablecoin)]
    fun test_batch_operations(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Test batch minting
        wusd::mint(creator, USER1, 1000);
        wusd::mint(creator, USER2, 2000);
        let _metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(USER1, _metadata) == 1000, 0);
        assert!(primary_fungible_store::balance(USER2, _metadata) == 2000, 0);

        // Test batch freezing
        let accounts = vector[USER1, USER2];
        wusd::freeze_accounts(creator, accounts);
        assert!(wusd::is_frozen(USER1), 0);
        assert!(wusd::is_frozen(USER2), 0);
    }

    #[test(creator = @stablecoin)]
    fun test_edge_cases(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Test minting 0 tokens
        wusd::mint(creator, USER1, 0);
        let _metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(USER1, _metadata) == 0, 0);
        
        // Test burning with minimum amount
        wusd::mint(creator, signer::address_of(creator), 100);
        // Grant burner role to creator
        wusd::grant_role(creator, 5, signer::address_of(creator)); // Role 5 is burner
        wusd::burn(creator, 1); // Burn minimum amount
        assert!(primary_fungible_store::balance(signer::address_of(creator), _metadata) == 99, 0);
    }

    #[test(creator = @stablecoin)]
    fun test_ownership_transfer(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Create new owner account
        let new_owner = account::create_account_for_test(USER1);
        
        // Get the OwnerRole object
        let owner_role_obj = object::address_to_object<wusd::OwnerRole>(wusd::wusd_address());
        
        // Start ownership transfer
        wusd::test_transfer_ownership(creator, owner_role_obj, USER1);
        
        // Verify pending owner
        let pending_owner = wusd::pending_owner(owner_role_obj);
        assert!(option::is_some(&pending_owner), 0);
        assert!(option::borrow(&pending_owner) == &USER1, 0);
        
        // Accept ownership
        wusd::test_accept_ownership(&new_owner, owner_role_obj);
        
        // Verify new owner
        assert!(wusd::owner(owner_role_obj) == USER1, 0);
    }

    #[test(creator = @stablecoin)]
    #[expected_failure(abort_code = 7)] // ENOT_PENDING_OWNER
    fun test_unauthorized_ownership_accept(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Create new owner account
        let new_owner = account::create_account_for_test(USER1);
        
        // Get the OwnerRole object
        let owner_role_obj = object::address_to_object<wusd::OwnerRole>(wusd::wusd_address());
        
        // Start ownership transfer
        wusd::test_transfer_ownership(creator, owner_role_obj, USER1);
        
        // Try to accept ownership with wrong account
        let wrong_account = account::create_account_for_test(USER2);
        wusd::test_accept_ownership(&wrong_account, owner_role_obj);
    }

    #[test(creator = @stablecoin)]
    fun test_role_management_comprehensive(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Create test user
        let user = account::create_account_for_test(USER1);
        let user_addr = signer::address_of(&user);
        
        // Test granting all roles
        wusd::grant_role(creator, 1, user_addr); // Minter
        wusd::grant_role(creator, 2, user_addr); // Pauser
        wusd::grant_role(creator, 3, user_addr); // Denylister
        wusd::grant_role(creator, 4, user_addr); // Recovery
        wusd::grant_role(creator, 5, user_addr); // Burner
        
        // Verify all roles are granted
        assert!(wusd::hasRole(1, user_addr), 0); // Minter
        assert!(wusd::hasRole(2, user_addr), 0); // Pauser
        assert!(wusd::hasRole(3, user_addr), 0); // Denylister
        assert!(wusd::hasRole(4, user_addr), 0); // Recovery
        assert!(wusd::hasRole(5, user_addr), 0); // Burner
        
        // Test revoking all roles
        wusd::revoke_role(creator, 1, user_addr);
        wusd::revoke_role(creator, 2, user_addr);
        wusd::revoke_role(creator, 3, user_addr);
        wusd::revoke_role(creator, 4, user_addr);
        wusd::revoke_role(creator, 5, user_addr);
        
        // Verify all roles are revoked
        assert!(!wusd::hasRole(1, user_addr), 0); // Minter
        assert!(!wusd::hasRole(2, user_addr), 0); // Pauser
        assert!(!wusd::hasRole(3, user_addr), 0); // Denylister
        assert!(!wusd::hasRole(4, user_addr), 0); // Recovery
        assert!(!wusd::hasRole(5, user_addr), 0); // Burner
    }

    #[test(creator = @stablecoin)]
    #[expected_failure(abort_code = 3)] // EALREADY_MINTER
    fun test_grant_duplicate_role(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Create test user
        let user = account::create_account_for_test(USER1);
        let user_addr = signer::address_of(&user);
        
        // Grant role first time
        wusd::grant_role(creator, 1, user_addr);
        
        // Try to grant the same role again
        wusd::grant_role(creator, 1, user_addr);
    }

    #[test(creator = @stablecoin)]
    #[expected_failure(abort_code = 4)] // ENOT_MINTER
    fun test_revoke_nonexistent_role(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Create test user
        let user = account::create_account_for_test(USER1);
        let user_addr = signer::address_of(&user);
        
        // Try to revoke a role that hasn't been granted
        wusd::revoke_role(creator, 1, user_addr);
    }

    #[test(creator = @stablecoin)]
    fun test_master_minter_update(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Create new master minter
        let new_master_minter = account::create_account_for_test(USER1);
        let new_master_minter_addr = signer::address_of(&new_master_minter);
        
        // Update master minter
        wusd::update_master_minter(creator, new_master_minter_addr);
        
        // Verify new master minter
        assert!(wusd::hasRole(1, new_master_minter_addr), 0); // Master minter should have minter role
    }

    #[test(creator = @stablecoin)]
    #[expected_failure(abort_code = 6)] // ENOT_OWNER
    fun test_unauthorized_master_minter_update(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Create unauthorized user
        let unauthorized = account::create_account_for_test(USER1);
        let unauthorized_addr = signer::address_of(&unauthorized);
        
        // Try to update master minter without authorization
        wusd::update_master_minter(&unauthorized, USER2);
    }
}
