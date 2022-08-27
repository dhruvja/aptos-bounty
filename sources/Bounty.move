module Bounty::bounty {

    use std::signer;

    use aptos_framework::account;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use aptos_framework::aptos_account;

    // States
    const PENDING: u64 = 0;
    const REJECTED:u64 = 1;
    const ACCEPTED: u64 = 2;
    const CLOSED: u64 = 3;

    // Resources
    struct BountyNetwork has key{
        admin: address,
        count: u64,
        network_name: vector<u8>,
        resource_cap: account::SignerCapability
    }

    struct Bounty has key {
        title: vector<u8>,
        description: vector<u8>, 
        project_id: vector<u8>,
        reward_amount: u64,
        reward_coin_address: address,
        status: u64,
        submissions: u64,
        resource_cap: account::SignerCapability
    }

    // Errors
    const ERESOURCE_NOT_FOUND: u64 = 0;
    const EBOUNTY_NETWORK_NOT_CREATED: u64 = 1;
    const EINVALID_BALANCE: u64 = 2;
    
    public entry fun initialize_bounty_network(initializer: &signer, network_name: vector<u8>) {
        let (bounty_network_resource, bounty_network_resource_cap) = account::create_resource_account(initializer, network_name);

        move_to(&bounty_network_resource, BountyNetwork{admin: signer::address_of(initializer), count: 0, network_name: network_name, resource_cap: bounty_network_resource_cap});
    }

    public entry fun create_bounty<CoinType>(creator: &signer, bounty_network: address, title: vector<u8>, description: vector<u8>, project_id: vector<u8>, reward_amount: u64) {

        assert!(exists<BountyNetwork>(bounty_network), EBOUNTY_NETWORK_NOT_CREATED);

        let (bounty_resource, bounty_resource_cap) = account::create_resource_account(creator, project_id);
        let bounty_resource_addr = signer::address_of(&bounty_resource);

        coin::register<CoinType>(&bounty_resource);
        coin::transfer<CoinType>(creator, bounty_resource_addr, reward_amount);       

        move_to(&bounty_resource, Bounty{title: title, description: description, project_id: project_id, reward_amount: reward_amount, reward_coin_address: bounty_resource_addr, status: PENDING, submissions: 0, resource_cap: bounty_resource_cap});
    }

    #[test_only]
    public fun get_resource_account(source: address, seed: vector<u8>): address {
        use std::hash;
        use std::bcs;
        use std::vector;
        use aptos_framework::byte_conversions;
        let bytes = bcs::to_bytes(&source);
        vector::append(&mut bytes, seed);
        let addr = byte_conversions::to_address(hash::sha3_256(bytes));
        addr
    }

    #[test_only]
    struct FakeCoin {}

    #[test(alice = @0x2, bob = @0x3, bounty_module= @Bounty)]
    public entry fun end_to_end_testing(alice: signer, bounty_module: signer, bob: signer) {
        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);
        initialize_bounty_network(&alice, b"aptos");
        let bounty_network_addr = get_resource_account(alice_addr, b"aptos");
        assert!(exists<BountyNetwork>(bounty_network_addr), ERESOURCE_NOT_FOUND);

        managed_coin::initialize<FakeCoin>(&bounty_module, b"fake", b"F", 9, false);
        aptos_account::create_account(bob_addr);
        coin::register<FakeCoin>(&bob);
        managed_coin::mint<FakeCoin>(&bounty_module, bob_addr, 10000);
        assert!(coin::balance<FakeCoin>(bob_addr) == 10000, EINVALID_BALANCE);
        create_bounty<FakeCoin>(&bob, bounty_network_addr, b"security flaw", b"person finding a flaw would be rewarded handsomely", b"0001", 100);
        assert!(coin::balance<FakeCoin>(bob_addr) == 9900, EINVALID_BALANCE);
    }

}