#[starknet::contract]
mod StarkSwirl {
    use core::hash::{HashStateTrait, HashStateExTrait};
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address
    };
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use cairo_verifier::{StarkProof, StarkProofImpl};
    use starkswirl_contracts::interfaces::IStarkSwirl;

    use cairo_lib::data_structures::mmr::mmr::{MMR, MMRImpl, MMRTrait, MMRDefault};
    use cairo_lib::data_structures::mmr::peaks::{Peaks, PeaksTrait};


    // Controlling how old the root of the tree can be
    const MAX_ROOTS_DEPTH: felt252 = 4;

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
        #[key]
        peaks: Peaks,
        #[key]
        new_index : usize,
        #[key]
        new_root: felt252
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
        mmr: MMR,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_address: ContractAddress, denominator: u256) {
        assert(!token_address.is_zero(), 'Address 0 not allowed');
        assert(!denominator.is_zero(), '0 amount not allowed');
        self.denominator.write(denominator);

        self.token_address.write(ERC20ABIDispatcher { contract_address: token_address });

        self.mmr.write(MMRDefault::default());
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

        fn deposit(ref self: ContractState, commitment: felt252, peaks: Peaks) {
            assert(!self.commitments.read(commitment), 'Commitment already added');

            self
                .token_address
                .read()
                .transfer_from(
                    get_caller_address(), get_contract_address(), self.denominator.read()
                );

            let mut mmr = self.mmr.read();
            match mmr.append(commitment, peaks) {
                Result::Ok((new_root, peaks_arr)) => {
                    let new_index = mmr.last_pos+1;
                    add_root_to_history(ref self, new_root);
                    self.mmr.write(mmr);
                    self.emit(Deposit { commitment: commitment, peaks : peaks_arr, new_index, new_root });
                }, 
                Result::Err => {
                    panic_with_felt252('Deposit fail');
                }
            };

            self.commitments.write(commitment, true);
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

    fn add_root_to_history(ref self : ContractState, new_root: felt252) {
        let roots_len = self.roots_len.read();
        self.merkle_roots.write(roots_len, new_root);
        self.roots_len.write(roots_len +1);
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
}
