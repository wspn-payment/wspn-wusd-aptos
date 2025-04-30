#[test_only]
module stablecoin::wusd_tests {
    use std::signer;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::event;
    use stablecoin::wusd;
    use std::option;

    #[test(creator = @0x08483dc9fca3a6d411662ce73475e8007b9b0104aa28eb3a933cef93c71ed8f6)]
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

    // #[test(creator = @0xcafe)]
    // fun test_initialization(creator: &signer) {
    //     wusd::init_for_test(creator);

    //     let metadata = wusd::metadata();
    //     assert!(fungible_asset::metadata::name(metadata) == b"WUSD", 0);
    //     assert!(fungible_asset::metadata::symbol(metadata) == b"WUSD", 0);
    // }

    #[test(creator = @0x08483dc9fca3a6d411662ce73475e8007b9b0104aa28eb3a933cef93c71ed8f6)]
    fun test_minting(creator: &signer) {
        wusd::init_for_test(creator);

        let receiver = @0xcafe1;

        wusd::mint(creator, receiver, 100);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(receiver, metadata) == 100, 0);
    }

    #[test(creator = @0x08483dc9fca3a6d411662ce73475e8007b9b0104aa28eb3a933cef93c71ed8f6)]
    fun test_burning(creator: &signer) {
        wusd::init_for_test(creator);

        let receiver = @0x08483dc9fca3a6d411662ce73475e8007b9b0104aa28eb3a933cef93c71ed8f6;

        wusd::mint(creator, receiver, 100);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::balance(receiver, metadata) == 100, 0);

        wusd::burn(creator, 50);
        assert!(primary_fungible_store::balance(receiver, metadata) == 50, 0);
    }
    
    #[test(creator = @0x08483dc9fca3a6d411662ce73475e8007b9b0104aa28eb3a933cef93c71ed8f6)]
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

    #[test(creator = @0x08483dc9fca3a6d411662ce73475e8007b9b0104aa28eb3a933cef93c71ed8f6)]
    fun test_denylist(creator: &signer) {
        wusd::init_for_test(creator);

        let account = @0xcafe1;

        wusd::denylist(creator, account);
        let metadata = wusd::metadata();
        assert!(primary_fungible_store::is_frozen(account, metadata), 0);

        wusd::undenylist(creator, account);
        assert!(!primary_fungible_store::is_frozen(account, metadata), 0);
    }
}