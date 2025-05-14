module stablecoin::wusd {
    use aptos_framework::account;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::event;
    use aptos_framework::function_info;
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset, FungibleStore};
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use std::option;
    use std::signer;
    use std::string::{Self, utf8};
    use std::vector;
    use aptos_framework::chain_id;

    /// Caller is not authorized to make this call
    const EUNAUTHORIZED: u64 = 1;
    /// No operations are allowed when contract is paused
    const EPAUSED: u64 = 2;
    /// The account is already a minter
    const EALREADY_MINTER: u64 = 3;
    /// The account is not a minter
    const ENOT_MINTER: u64 = 4;
    /// The account is denylisted
    const EDENYLISTED: u64 = 5;

    const ASSET_SYMBOL: vector<u8> = b"WUSD";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// The current and pending owner addresses state.
    struct OwnerRole has key {
        owner: address,
        pending_owner: Option<address>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Roles has key {
        master_minter: address,
        minters: vector<address>,
        pauser: address,
        denylister: address,
        recover: address,
        burner: address,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Management has key {
        extend_ref: ExtendRef,
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct State has key {
        paused: bool,
    }

    struct Approval has drop {
        owner: address,
        to: address,
        nonce: u64,
        chain_id: u8,
        spender: address,
        amount: u64,
    }

    #[event]
    /// Emitted when the ownership transfer is started.
    struct OwnershipTransferStarted has drop, store {
        obj_address: address,
        old_owner: address,
        new_owner: address
    }

    #[event]
    /// Emitted when the ownership is transferred to a new address.
    struct OwnershipTransferred has drop, store {
        obj_address: address,
        old_owner: address,
        new_owner: address
    }

    #[event]
    /// Emitted when the OwnerRole resource is destroyed.
    struct OwnerRoleDestroyed has drop, store {
        obj_address: address
    }

    #[event]
    struct MasterMinterChanged has drop, store {
        old_master_minter: address,
        new_master_minter: address
    }

    #[event]
    struct Mint has drop, store {
        minter: address,
        to: address,
        amount: u64,
    }

    #[event]
    struct Burn has drop, store {
        minter: address,
        from: address,
        store: Object<FungibleStore>,
        amount: u64,
    }

    #[event]
    struct Pause has drop, store {
        pauser: address,
        is_paused: bool,
    }

    #[event]
    struct Denylist has drop, store {
        denylister: address,
        account: address,
    }

    #[event]
    struct TokensRecovered has drop, store {
        admin: address,
        from: address,
        to: address,
        amount: u64,
    }

    #[view]
    /// Returns the active owner address.
    public fun owner(obj: Object<OwnerRole>): address acquires OwnerRole {
        borrow_global<OwnerRole>(object::object_address(&obj)).owner
    }

    #[view]
    /// Returns the pending owner address.
    public fun pending_owner(obj: Object<OwnerRole>): Option<address> acquires OwnerRole {
        borrow_global<OwnerRole>(object::object_address(&obj)).pending_owner
    }

    #[view]
    public fun wusd_address(): address {
        object::create_object_address(&@stablecoin, ASSET_SYMBOL)
    }

    #[view]
    public fun metadata(): Object<Metadata> {
        object::address_to_object(wusd_address())
    }

    #[view]
    public fun CONTRACT_ADMIN_ROLE(): address {
        @master_minter
    }

    #[view]
    public fun MINTER_ROLE(): address {
        @minter
    }

    #[view]
    public fun PAUSER_ROLE(): address {
        @pauser
    }

    #[view]
    public fun DENYLISTER_ROLE(): address {
        @denylister
    }

    #[view]
    public fun RECOVERY_ROLE(): address {
        @recover
    }

    #[view]
    public fun BURNER_ROLE(): address {
        @burner
    }

    #[view]
    public fun getRoleAdmin(role: u8): vector<address> acquires Roles {
        let roles = borrow_global<Roles>(wusd_address());

        if (role == 1) { // Minter
            return roles.minters
        } else if (role == 2) { // Pauser
            return  vector::singleton(roles.pauser) // Assuming master_minter controls Pauser
        } else if (role == 3) { // Denylister
            return vector::singleton(roles.denylister) // Assuming master_minter controls Denylister
        } else if (role == 4) { // Recovery
            return vector::singleton(roles.master_minter) // Assuming master_minter controls Recovery
        } else if (role == 5) { // Burner
            return vector::singleton(roles.master_minter) // Assuming master_minter controls Burner
        } else {
            abort(EUNAUTHORIZED) // Invalid role identifier
        }
    }

    #[view]
    public fun hasRole(role: u8, account: address): bool acquires Roles {
        let roles = borrow_global<Roles>(wusd_address());

        if (role == 1) { // Minter
            return account == roles.master_minter || vector::contains(&roles.minters, &account)
        } else if (role == 2) { // Pauser
            return account == roles.pauser
        } else if (role == 3) { // Denylister
            return account == roles.denylister
        } else if (role == 4) { // Recovery
            return account == roles.recover
        } else if (role == 5) { // Burner
            return account == roles.burner
        } else {
            abort(EUNAUTHORIZED) // Invalid role identifier
        }
    }

    #[view]
    public fun paused(): bool acquires State {
        let state = borrow_global<State>(wusd_address());
        return state.paused
    }
    /// Aborts if the caller is not the owner of the input object
    public fun assert_is_owner(caller: &signer) acquires OwnerRole {
        let obj = wusd_address();
        assert!(owner(obj) == signer::address_of(caller), ENOT_OWNER);
    }

    /// Called as part of deployment to initialize the stablecoin.
    /// Note: The signer has to be the account where the module is published.
    /// Create a stablecoin token (a new Fungible Asset)
    /// Ensure any stores for the stablecoin are untransferable.
    /// Store Roles, Management and State resources in the Metadata object.
    /// Override deposit and withdraw functions of the newly created asset/token to add custom denylist logic.
    fun init_module(wusd_signer: &signer) {
        // Create the stablecoin with primary store support.
        let constructor_ref = &object::create_named_object(wusd_signer, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(ASSET_SYMBOL), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"https://wspn.io/"), /* project */
        );

        // Set ALL stores for the fungible asset to untransferable.
        fungible_asset::set_untransferable(constructor_ref);

        // All resources created will be kept in the asset metadata object.
        let metadata_object_signer = &object::generate_signer(constructor_ref);
        
        move_to(metadata_object_signer, OwnerRole {
            owner: @wusd_signer,
            pending_owner: option::none(),
        });

        // Create the stablecoin's object container.
        move_to(metadata_object_signer, Roles {
            master_minter: @master_minter,
            minters: vector[],
            pauser: @pauser,
            denylister: @denylister,
            recover: @recover,
            burner: @burner,
        });

        // Create mint/burn/transfer refs to allow creator to manage the stablecoin.
        move_to(metadata_object_signer, Management {
            extend_ref: object::generate_extend_ref(constructor_ref),
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
            transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
        });

        move_to(metadata_object_signer, State {
            paused: false,
        });

        // Override the deposit and withdraw functions which mean overriding transfer.
        // This ensures all transfer will call withdraw and deposit functions in this module and perform the necessary
        // checks.
        let deposit = function_info::new_function_info(
            wusd_signer,
            string::utf8(b"wusd"),
            string::utf8(b"deposit"),
        );
        let withdraw = function_info::new_function_info(
            wusd_signer,
            string::utf8(b"wusd"),
            string::utf8(b"withdraw"),
        );
        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw),
            option::some(deposit),
            option::none(),
        );
    }

    /// Starts the ownership transfer of the object by setting the pending owner to the new_owner address.
    entry fun transfer_ownership(caller: &signer, obj: Object<OwnerRole>, new_owner: address) acquires OwnerRole {
        let obj_address = object::object_address(&obj);
        let owner_role = borrow_global_mut<OwnerRole>(obj_address);
        assert!(owner_role.owner == signer::address_of(caller), ENOT_OWNER);

        owner_role.pending_owner = option::some(new_owner);

        event::emit(OwnershipTransferStarted { obj_address, old_owner: owner_role.owner, new_owner });
    }

    /// Transfers the ownership of the object by setting the owner to the pending owner address.
    entry fun accept_ownership(caller: &signer, obj: Object<OwnerRole>) acquires OwnerRole {
        let obj_address = object::object_address(&obj);
        let owner_role = borrow_global_mut<OwnerRole>(obj_address);
        assert!(option::is_some(&owner_role.pending_owner), EPENDING_OWNER_NOT_SET);
        assert!(
            option::contains(&owner_role.pending_owner, &signer::address_of(caller)),
            ENOT_PENDING_OWNER
        );

        let old_owner = owner_role.owner;
        let new_owner = option::extract(&mut owner_role.pending_owner);

        owner_role.owner = new_owner;

        event::emit(OwnershipTransferred { obj_address, old_owner, new_owner });
    }

    /// Removes the OwnerRole resource from the caller.
    public fun destroy(caller: &signer) acquires OwnerRole {
        let OwnerRole { owner: _, pending_owner: _ } = move_from<OwnerRole>(signer::address_of(caller));

        event::emit(OwnerRoleDestroyed { obj_address: signer::address_of(caller) });
    }

    /// Deposit function override to ensure that the account is not denylisted and the stablecoin is not paused.
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &TransferRef,
    ) acquires State {
        assert_not_paused();
        assert_not_denylisted(object::owner(store));
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }

    /// Withdraw function override to ensure that the account is not denylisted and the stablecoin is not paused.
    public fun withdraw<T: key>(
        store: Object<T>,
        amount: u64,
        transfer_ref: &TransferRef,
    ): FungibleAsset acquires State {
        assert_not_paused();
        assert_not_denylisted(object::owner(store));
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    public entry fun grant_role(
        admin: &signer,
        role: u8,
        account: address
    ) acquires Roles {
        let roles = borrow_global_mut<Roles>(wusd_address());
        assert!(signer::address_of(admin) == roles.master_minter, EUNAUTHORIZED);

        if (role == 1) { // Minter
            assert!(!vector::contains(&roles.minters, &account), EALREADY_MINTER);
            vector::push_back(&mut roles.minters, account);
        } else if (role == 2) { // Pauser
            roles.pauser = account;
        } else if (role == 3) { // Denylister
            roles.denylister = account;
        } else if (role == 4) { // Recover
            roles.recover = account;
        } else if (role == 5) { // Burner
            roles.burner = account;
        } else {
            abort(EUNAUTHORIZED)
        }
    }

    public entry fun revoke_role(
        admin: &signer,
        role: u8,
        account: address
    ) acquires Roles {
        let roles = borrow_global_mut<Roles>(wusd_address());
        assert!(signer::address_of(admin) == roles.master_minter, EUNAUTHORIZED);

        if (role == 1) { // Minter
            let (found, index) = vector::index_of(&roles.minters, &account);
            assert!(found, ENOT_MINTER);
            vector::remove(&mut roles.minters, index);
        } else if (role == 2) { // Pauser
            assert!(roles.pauser == account, EUNAUTHORIZED);
            roles.pauser = signer::address_of(admin);
        } else if (role == 3) { // Denylister
            assert!(roles.denylister == account, EUNAUTHORIZED);
            roles.denylister = signer::address_of(admin);
        } else if (role == 4) { // Recover
            assert!(roles.recover == account, EUNAUTHORIZED);
            roles.recover = signer::address_of(admin);
        } else if (role == 5) { // Burner
            assert!(roles.burner == account, EUNAUTHORIZED);
            roles.burner = signer::address_of(admin);
        } else {
            abort(EUNAUTHORIZED)
        }
    }

    public entry fun recover_tokens(
        admin: &signer,
        from: address,
        amount: u64
    ) acquires Management, Roles, State {
        // Ensure the contract is not paused
        assert_not_paused();

        // Ensure the caller has the "RECOVERY_ROLE"
        let roles = borrow_global<Roles>(wusd_address());
        assert!(signer::address_of(admin) == roles.recover, EUNAUTHORIZED);

        // Ensure the `from` account exists and is not allowed to hold tokens
        let metadata = metadata();
        assert!(primary_fungible_store::primary_store_exists_inlined(from, metadata), EDENYLISTED);
        let from_store = primary_fungible_store::primary_store_inlined(from, metadata);
        assert!(fungible_asset::is_frozen(from_store), EDENYLISTED);

        // Ensure the `amount` is greater than 0 and less than or equal to the balance of the `from` account
        assert!(amount > 0, EUNAUTHORIZED);
        assert!(fungible_asset::balance(from_store) >= amount, EUNAUTHORIZED);

        // Ensure the `admin` account has a primary store
        let admin_address = signer::address_of(admin);
        let admin_store = primary_fungible_store::ensure_primary_store_exists(admin_address, metadata);

        // Perform the token transfer
        let management = borrow_global<Management>(wusd_address());
        primary_fungible_store::transfer_with_ref(
            &management.transfer_ref,
            object::owner(from_store),
            object::owner(admin_store),
            amount
        );

        // Emit a `TokensRecovered` event
        event::emit(TokensRecovered {
            admin: object::owner(admin_store),
            from,
            to: object::owner(admin_store),
            amount,
        });
    }

    /// Mint new tokens to the specified account. This checks that the caller is a minter, the stablecoin is not paused,
    /// and the account is not denylisted.
    public entry fun mint(minter: &signer, to: address, amount: u64) acquires Management, Roles, State {
        assert_not_paused();
        assert_is_minter(minter);
        assert!(to != @0x0, EUNAUTHORIZED);
        assert_not_denylisted(to);
        if (amount == 0) { return };

        let management = borrow_global<Management>(wusd_address());
        let tokens = fungible_asset::mint(&management.mint_ref, amount);
        // Ensure not to call pfs::deposit or dfa::deposit directly in the module.
        deposit(primary_fungible_store::ensure_primary_store_exists(to, metadata()), tokens, &management.transfer_ref);

        event::emit(Mint {
            minter: signer::address_of(minter),
            to,
            amount,
        });
    }

    /// Burn tokens from the caller's own account.
    /// This function checks that the caller has the "BURNER_ROLE" and that the stablecoin is not paused.
    public entry fun burn(
        burner: &signer,
        amount: u64
    ) acquires Management, Roles, State {
        // Ensure the contract is not paused
        assert_not_paused();

        // Ensure the caller has the "BURNER_ROLE"
        let roles = borrow_global<Roles>(wusd_address());
        assert!(signer::address_of(burner) == roles.burner, EUNAUTHORIZED);

        // Ensure the amount is greater than 0
        if (amount == 0) {
            abort(EUNAUTHORIZED)
        };

        // Ensure the caller has a primary store
        let burner_address = signer::address_of(burner);
        let burner_store = primary_fungible_store::ensure_primary_store_exists(burner_address, metadata());

        // Perform the burn operation
        let management = borrow_global<Management>(wusd_address());
        let tokens = fungible_asset::withdraw_with_ref(
            &management.transfer_ref,
            burner_store,
            amount
        );
        fungible_asset::burn(&management.burn_ref, tokens);

        // Emit a Burn event
        event::emit(Burn {
            minter: burner_address, // In this context, the burner is the one performing the burn
            from: burner_address,
            store: burner_store,
            amount,
        });
    }

    /// Update master minter role
    public entry fun update_master_minter(caller: &signer, new_master_minter: address) acquires Roles {

        assert_is_owner(caller, wusd_address());
        let roles = borrow_global_mut<Roles>(wusd_address());

        let old_master_minter = roles.master_minter;
        roles.master_minter = new_master_minter;

        event::emit(MasterMinterChanged { old_master_minter, new_master_minter });
    }

    /// Pause or unpause the stablecoin. This checks that the caller is the pauser.
    public entry fun set_pause(pauser: &signer, paused: bool) acquires Roles, State {
        let roles = borrow_global<Roles>(wusd_address());
        assert!(signer::address_of(pauser) == roles.pauser, EUNAUTHORIZED);
        let state = borrow_global_mut<State>(wusd_address());
        state.paused = paused;

        event::emit(Pause {
            pauser: signer::address_of(pauser),
            is_paused: paused,
        });
    }

    /// Add an account to the denylist. This checks that the caller is the denylister.
    public entry fun denylist(denylister: &signer, account: address) acquires Management, Roles, State {
        assert_not_paused();
        let roles = borrow_global<Roles>(wusd_address());
        assert!(signer::address_of(denylister) == roles.denylister, EUNAUTHORIZED);

        let freeze_ref = &borrow_global<Management>(wusd_address()).transfer_ref;
        primary_fungible_store::set_frozen_flag(freeze_ref, account, true);

        event::emit(Denylist {
            denylister: signer::address_of(denylister),
            account,
        });
    }

    /// Remove an account from the denylist. This checks that the caller is the denylister.
    public entry fun undenylist(denylister: &signer, account: address) acquires Management, Roles, State {
        assert_not_paused();
        let roles = borrow_global<Roles>(wusd_address());
        assert!(signer::address_of(denylister) == roles.denylister, EUNAUTHORIZED);

        let freeze_ref = &borrow_global<Management>(wusd_address()).transfer_ref;
        primary_fungible_store::set_frozen_flag(freeze_ref, account, false);

        event::emit(Denylist {
            denylister: signer::address_of(denylister),
            account,
        });
    }

    /// Add a new minter. This checks that the caller is the master minter and the account is not already a minter.
    public entry fun add_minter(admin: &signer, minter: address) acquires Roles, State {
        assert_not_paused();
        let roles = borrow_global_mut<Roles>(wusd_address());
        assert!(signer::address_of(admin) == roles.master_minter, EUNAUTHORIZED);
        assert!(!vector::contains(&roles.minters, &minter), EALREADY_MINTER);
        vector::push_back(&mut roles.minters, minter);
    }

    fun assert_is_minter(minter: &signer) acquires Roles {
        let roles = borrow_global<Roles>(wusd_address());
        let minter_addr = signer::address_of(minter);
        assert!(minter_addr == roles.master_minter || vector::contains(&roles.minters, &minter_addr), EUNAUTHORIZED);
    }

    fun assert_not_paused() acquires State {
        let state = borrow_global<State>(wusd_address());
        assert!(!state.paused, EPAUSED);
    }

    // Check that the account is not denylisted by checking the frozen flag on the primary store
    fun assert_not_denylisted(account: address) {
        let metadata = metadata();
        // CANNOT call into pfs::store_exists in our withdraw/deposit hooks as it creates possibility of a circular dependency.
        // Instead, we will call the inlined version of the function.
        if (primary_fungible_store::primary_store_exists_inlined(account, metadata)) {
            assert!(!fungible_asset::is_frozen(primary_fungible_store::primary_store_inlined(account, metadata)), EDENYLISTED);
        }
    }

    #[test_only]
    public fun init_for_test(wusd_signer: &signer) {
        init_module(wusd_signer);
    }

    #[test_only]
    public fun test_OwnershipTransferStarted_event(
        obj_address: address, old_owner: address, new_owner: address
    ): OwnershipTransferStarted {
        OwnershipTransferStarted { obj_address, old_owner, new_owner }
    }

    #[test_only]
    public fun test_OwnershipTransferred_event(
        obj_address: address, old_owner: address, new_owner: address
    ): OwnershipTransferred {
        OwnershipTransferred { obj_address, old_owner, new_owner }
    }

    #[test_only]
    public fun test_OwnerRoleDestroyed_event(obj_address: address): OwnerRoleDestroyed {
        OwnerRoleDestroyed { obj_address }
    }

    #[test_only]
    public fun test_transfer_ownership(
        caller: &signer, obj: Object<OwnerRole>, new_owner: address
    ) acquires OwnerRole {
        transfer_ownership(caller, obj, new_owner);
    }

    #[test_only]
    public fun test_accept_ownership(caller: &signer, obj: Object<OwnerRole>) acquires OwnerRole {
        accept_ownership(caller, obj);
    }

    #[test_only]
    public fun set_owner_for_testing(obj_address: address, owner: address) acquires OwnerRole {
        let role = borrow_global_mut<OwnerRole>(obj_address);
        role.owner = owner;
    }

    #[test_only]
    public fun set_pending_owner_for_testing(obj_address: address, pending_owner: address) acquires OwnerRole {
        let role = borrow_global_mut<OwnerRole>(obj_address);
        role.pending_owner = option::some(pending_owner);
    }
}
