#[test_only]
module stablecoin::wusd_tests {
    use std::signer;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::account;
    use std::option;
    use aptos_framework::object;
    use stablecoin::wusd;

    // Error codes
    const EUNAUTHORIZED: u64 = 1;
    const EPAUSED: u64 = 2;

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_basic_flow(creator: &signer) {
        wusd::init_for_test(creator);
        let creator_address = signer::address_of(creator);
        let receiver_address = @0xcafe1;

        wusd::mint(creator, creator_address, 100);
        let asset = wusd::metadata();
        assert!(primary_fungible_store::balance(creator_address, asset) == 100, 0);
        primary_fungible_store::transfer(creator, asset, receiver_address, 10);
        assert!(primary_fungible_store::balance(receiver_address, asset) == 10, 0);

        wusd::denylist(creator, creator_address);
        assert!(primary_fungible_store::is_frozen(creator_address, asset), 0);
        wusd::undenylist(creator, creator_address);
        assert!(!primary_fungible_store::is_frozen(creator_address, asset), 0);
        wusd::burn(creator, 90);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_minting(creator: &signer) {
        wusd::init_for_test(creator);

        let receiver = @0xcafe1;

        wusd::mint(creator, receiver, 100);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(receiver, metadata) == 100, 0);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_burning(creator: &signer) {
        wusd::init_for_test(creator);

        let receiver = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b;

        wusd::mint(creator, receiver, 100);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(receiver, metadata) == 100, 0);

        wusd::burn(creator, 50);
        assert!(primary_fungible_store::balance(receiver, metadata) == 50, 0);
    }
    
    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_pausing(creator: &signer) {
        wusd::init_for_test(creator);

        wusd::set_pause(creator, true);
        assert!(wusd::paused(), 0);

        let receiver = @0xcafe1;

        wusd::set_pause(creator, false);
        assert!(!wusd::paused(), 0);

        wusd::mint(creator, receiver, 100);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(receiver, metadata) == 100, 0);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_denylist(creator: &signer) {
        wusd::init_for_test(creator);

        let account = @0xcafe1;

        wusd::denylist(creator, account);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::is_frozen(account, metadata), 0);

        wusd::undenylist(creator, account);
        assert!(!primary_fungible_store::is_frozen(account, metadata), 0);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_recover_tokens(creator: &signer) {
        wusd::init_for_test(creator);

        let admin = signer::address_of(creator);
        let frozen_account = @0xcafe1;

        // Mint tokens to the frozen account
        wusd::mint(creator, frozen_account, 100);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(frozen_account, metadata) == 100, 0);

        // Denylist the account
        wusd::denylist(creator, frozen_account);
        assert!(primary_fungible_store::is_frozen(frozen_account, metadata), 0);

        // Recover tokens from the frozen account
        wusd::recover_tokens(creator, frozen_account, 100);
        assert!(primary_fungible_store::balance(frozen_account, metadata) == 0, 0);
        assert!(primary_fungible_store::balance(admin, metadata) == 100, 0);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_grant_role(creator: &signer) {
        wusd::init_for_test(creator);

        let new_minter = @0xcafe2;

        // Grant the minter role to a new account
        wusd::grant_role(creator, 1, new_minter); // Role 1 corresponds to "Minter"
        assert!(wusd::hasRole(1, new_minter), 0);

        // Verify the new minter can mint tokens
        wusd::mint(creator, new_minter, 50);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(new_minter, metadata) == 50, 0);
    }
    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_revoke_role(creator: &signer) {
        wusd::init_for_test(creator);

        let new_minter = @0xcafe2;

        // Grant the minter role to a new account
        wusd::grant_role(creator, 1, new_minter); // Role 1 corresponds to "Minter"
        assert!(wusd::hasRole(1, new_minter), 0);

        // Revoke the minter role from the new account
        wusd::revoke_role(creator, 1, new_minter);
        assert!(!wusd::hasRole(1, new_minter), 0);

    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_ownership_transfer(creator: &signer) {
        wusd::init_for_test(creator);
        let new_owner = @0xcafe3;
        
        // Test starting ownership transfer
        let owner_role_obj = object::address_to_object<wusd::OwnerRole>(wusd::wusd_address());
        wusd::transfer_ownership(creator, owner_role_obj, new_owner);
        assert!(option::is_some(&wusd::pending_owner(owner_role_obj)), 0);
        
        // Test accepting ownership
        let new_owner_signer = account::create_account_for_test(new_owner);
        wusd::accept_ownership(&new_owner_signer, owner_role_obj);
        assert!(wusd::owner(owner_role_obj) == new_owner, 0);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    #[expected_failure(abort_code = EUNAUTHORIZED)]
    fun test_unauthorized_mint(creator: &signer) {
        wusd::init_for_test(creator);
        let unauthorized = account::create_account_for_test(@0xcafe4);
        wusd::mint(&unauthorized, @0xcafe5, 100);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    #[expected_failure(abort_code = EPAUSED)]
    fun test_mint_when_paused(creator: &signer) {
        wusd::init_for_test(creator);
        wusd::set_pause(creator, true);
        wusd::mint(creator, @0xcafe6, 100);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_update_master_minter(creator: &signer) {
        wusd::init_for_test(creator);
        let new_master_minter = @0xcafe7;
        
        wusd::update_master_minter(creator, new_master_minter);
        assert!(wusd::CONTRACT_ADMIN_ROLE() == new_master_minter, 0);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_batch_operations(creator: &signer) {
        wusd::init_for_test(creator);
        let receiver1 = @0xcafe8;
        let receiver2 = @0xcafe9;
        
        // Test batch minting
        wusd::mint(creator, receiver1, 100);
        wusd::mint(creator, receiver2, 200);
        
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(receiver1, metadata) == 100, 0);
        assert!(primary_fungible_store::balance(receiver2, metadata) == 200, 0);
        
        // Test batch denylisting
        wusd::denylist(creator, receiver1);
        wusd::denylist(creator, receiver2);
        assert!(primary_fungible_store::is_frozen(receiver1, metadata), 0);
        assert!(primary_fungible_store::is_frozen(receiver2, metadata), 0);
    }

    #[test(creator = @0x603f471513629c04d7da1621d5e7af0cf53d125b5b8d4a9ef801fb67aa996b7b)]
    fun test_edge_cases(creator: &signer) {
        wusd::init_for_test(creator);
        
        // Test minting 0 tokens
        wusd::mint(creator, @0xcafe10, 0);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(@0xcafe10, metadata) == 0, 0);
        
        // Test burning 0 tokens
        wusd::mint(creator, signer::address_of(creator), 100);
        wusd::burn(creator, 0);
        assert!(primary_fungible_store::balance(signer::address_of(creator), metadata) == 100, 0);
    }
}
