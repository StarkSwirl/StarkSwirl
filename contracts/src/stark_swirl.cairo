#[starknet::contract]
mod StarkSwirl {
    use alexandria_merkle_tree::merkle_tree::{
        Hasher, MerkleTree, pedersen::PedersenHasherImpl, MerkleTreeTrait
    };
    use starkswirl_contracts::interfaces::IStarkSwirl;
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address
    };
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

    const MAX_ROOTS_DEPTH: felt252 = 10;

    #[storage]
    struct Storage {
        denominator: u256,
        nullifiers: LegacyMap<felt252, bool>,
        token_address: ERC20ABIDispatcher,
        merkle_roots: LegacyMap<felt252, felt252>,
        roots_len: felt252,
        commitments: LegacyMap<felt252, bool>,
        current_index: felt252
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_address: ContractAddress, denominator: u256) {
        assert(!token_address.is_zero(), 'Address 0 not allowed');
        self.current_index.write(0);
        self.denominator.write(denominator);

        self.token_address.write(ERC20ABIDispatcher { contract_address: token_address });
    }


    #[abi(embed_v0)]
    impl StarkSwirl of IStarkSwirl<ContractState> {
        fn deposit(ref self: ContractState, commitment: felt252) {
            assert(self.commitments.read(commitment) == false, 'Commitment already added');

            self
                .token_address
                .read()
                .transfer_from(
                    get_caller_address(), get_contract_address(), self.denominator.read()
                );
            self.commitments.write(commitment, true);
        }

        fn withdraw(
            ref self: ContractState,
            proof: felt252,
            root: felt252,
            recipient: ContractAddress,
            nullifier_hash: felt252
        ) {
            assert(self.nullifiers.read(nullifier_hash) == false, 'Nullifier already used');
            assert(find_root(@self, root) == true, 'Root not found');

            self.nullifiers.write(nullifier_hash, true);
        }


        fn leaves(self: @ContractState) {}
    }

    fn insert(ref self: ContractState, hash: felt252) {}


    fn find_root(self: @ContractState, root: felt252) -> bool {
        let mut current_index = self.roots_len.read();

        if current_index == 0 { 
            return false;
        }
    
        let mut root_found: bool = false;

        loop {
            if current_index == 0 { 
                break;
            }

            let current_root = self.merkle_roots.read(current_index-1);

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
}