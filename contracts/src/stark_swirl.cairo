#[starknet::contract]
mod StarkSwirl {
    use core::traits::Into;
    use core::poseidon::PoseidonTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address
    };
    use alexandria_merkle_tree::merkle_tree::{
        Hasher, MerkleTree, pedersen::PedersenHasherImpl, MerkleTreeTrait
    };
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use cairo_verifier::{StarkProof, StarkProofImpl};
    use starkswirl_contracts::interfaces::IStarkSwirl;


    // poseidon_hash(0)
    const POSEIDON_0_HASH: felt252 = 2713945852911138914608023678711237035749237289914711755736801547179254184987; 

    // Controlling how old the root of the tree can be
    const MAX_ROOTS_DEPTH: felt252 = 4;
    // number of levels
    const LEVELS: usize = 4;

    const SECURITY_BITS: felt252 = 50;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        #[key]
        commitment: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        nullifier_hash: felt252,
    }


    #[storage]
    struct Storage {
        denominator: u256, // Amount of tokens that can be deposited
        nullifiers: LegacyMap<felt252, bool>, // Deposits that are already withdrawn
        token_address: ERC20ABIDispatcher, // address of the token in this instance
        merkle_roots: LegacyMap<felt252, felt252>, // history of the merkle roots
        roots_len: felt252, // length of the merkle roots
        commitments: LegacyMap<felt252, bool>, // leavs in the tree
        filled_subtrees: LegacyMap<usize, felt252>,
        next_index: usize // index for the next commitment
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_address: ContractAddress, denominator: u256) {
        assert(!token_address.is_zero(), 'Address 0 not allowed');
        assert(!denominator.is_zero(), '0 amount not allowed');
        self.denominator.write(denominator);

        self.token_address.write(ERC20ABIDispatcher { contract_address: token_address });

        let i: usize = 0;
        while i < LEVELS {
            self.filled_subtrees.write(i, zeros(i));
        };
        self.merkle_roots.write(0, zeros(LEVELS - 1));
        self.roots_len.write(1);
    }


    #[abi(embed_v0)]
    impl StarkSwirl of IStarkSwirl<ContractState> {
        fn token_address(self: @ContractState) -> ContractAddress {
            let ERC20 = self.token_address.read();
            return ERC20.contract_address;
        }
        fn denominator(self: @ContractState) -> u256 {
            self.denominator.read()
        }

        fn deposit(ref self: ContractState, commitment: felt252) {
            assert(self.commitments.read(commitment) == false, 'Commitment already added');

            self
                .token_address
                .read()
                .transfer_from(
                    get_caller_address(), get_contract_address(), self.denominator.read()
                );

            insert(ref self, commitment);

            self.commitments.write(commitment, true);
            self.emit(Deposit { commitment: commitment });
        }

        fn withdraw(
            ref self: ContractState,
            proof: StarkProof,
            root: felt252,
            recipient: ContractAddress,
            nullifier_hash: felt252
        ) {
            assert(self.nullifiers.read(nullifier_hash) == false, 'Nullifier already used');
            assert(find_root(@self, root) == true, 'Root not found');
            proof.verify(SECURITY_BITS);

            self.nullifiers.write(nullifier_hash, true);
            self.token_address.read().transfer(recipient, self.denominator.read());
            self.emit(Withdraw { nullifier_hash: nullifier_hash });
        }
    }

    fn insert(ref self: ContractState, hash: felt252) {
        let mut current_index = self.next_index.read();
        assert(current_index != LEVELS, 'Merkle tree is full');

        let mut current_level_hash = hash;
        let mut left: felt252 = 0;
        let mut right: felt252 = 0;

        let mut hasher = PedersenHasherImpl::new();

        let mut level: usize = 0;
        while level < LEVELS {
            if (current_index % 2 == 0) { // left branch
                left = current_level_hash;
                right = zeros(level);
                self.filled_subtrees.write(level, current_level_hash);
            } else { // right branch
                left = self.filled_subtrees.read(level);
                right = current_level_hash;
            }

            current_level_hash = hasher.hash(left, right);
            current_index /= 2;
            level += 1;
        };

        self.next_index.write(self.next_index.read() + 1);
        self.merkle_roots.write(self.roots_len.read(), current_level_hash);
        self.roots_len.write(self.roots_len.read() + 1);
    }


    fn find_root(self: @ContractState, root: felt252) -> bool {
        let mut current_index = self.roots_len.read();

        let mut root_found: bool = false;

        loop {
            if current_index == 0 {
                break;
            }

            let current_root = self.merkle_roots.read(current_index - 1);

            if current_root == root {
                root_found = true;
                break;
            }

            if current_index == MAX_ROOTS_DEPTH {
                break;
            }

            current_index -= 1;
        };

        return root_found;
    }


    fn zeros(level: usize) -> felt252 {
        match level {
            0 => {
                // pedersen(poseidon(0), poseidon(0))
                return 2494688673636795699140731058621453752305163011358859803833341381092752778782;
            },
            1 => {
                return 2536973504930841035827773298593592681327550267909021527759854774781372267024;
            },
            2 => {
                return 3168820576294055788093137617219701204279874680027811909268770663640987151107;
            },
            3 => {
                return 893557775024593676856405225307484293889203777646349164712834287110724191802;
            },
            4 => {
                return 2457764592963662570314190289271338960169321202535366699950186721239435073247;
            },
            5 => {
                return 3419674558673531377106573994038826960986684925157811978470069836211202381160;
            },
            6 => {
                return 1736706958586788585586261304539002893953495221392708361420953301640134214312;
            },
            7 => {
                return 1936795156746501756241554972601075738475914828179455995787001990322868171639;
            },
            _ => { panic_with_felt252('Unavailable level') }
        }
    }
}
