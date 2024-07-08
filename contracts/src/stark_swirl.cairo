#[starknet::contract]
mod StarkSwirl {
    use core::hash::{HashStateTrait, HashStateExTrait};
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address,
        contract_address_try_from_felt252
    };
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use cairo_verifier::{
        StarkProofWithSerde, StarkProof, CairoVersion, StarkProofImpl,
        air::public_memory::AddrValue,
        air::public_input::PublicInput, air::layouts::recursive::constants::segments
    };
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
        new_index: usize,
        #[key]
        new_root: felt252,
        #[key]
        peaks_len: u32,
        #[key]
        peaks: Peaks,
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
                Result::Ok((
                    new_root, peaks_arr
                )) => {
                    let new_index = mmr.last_pos + 1;
                    add_root_to_history(ref self, new_root);
                    self.mmr.write(mmr);
                    self
                        .emit(
                            Deposit {
                                commitment: commitment,
                                new_index,
                                new_root,
                                peaks_len: peaks_arr.len(),
                                peaks: peaks_arr,
                            }
                        );
                },
                Result::Err => { panic_with_felt252('Deposit fail'); }
            };

            self.commitments.write(commitment, true);
        }

        fn withdraw(
            ref self: ContractState,
            proof: StarkProofWithSerde,
            root: felt252,
            nullifier_hash: felt252
        ) {
            assert(self.nullifiers.read(nullifier_hash) == false, 'Nullifier already used');
            assert(find_root(@self, root) == true, 'Root not found');
            let stark_proof: StarkProof = proof.into();
            let receiver = get_receiver_from_proof(@stark_proof);
            verify_stark_proof(stark_proof);

            self.nullifiers.write(nullifier_hash, true);
            self
                .token_address
                .read()
                .transfer(receiver, self.denominator.read());
            self.emit(Withdraw { nullifier_hash: nullifier_hash });
        }
    }

    fn verify_stark_proof(proof: StarkProof) {
        proof.verify(SECURITY_BITS);
    }


    // TODO: Check 
    fn get_receiver_from_proof(proof: @StarkProof) -> ContractAddress {
        let begin_addr: felt252 = *proof.public_input.segments.at(segments::OUTPUT).begin_addr;
        let receiver_addr_value : AddrValue = *proof.public_input.main_page.at((begin_addr + 2).try_into().unwrap());

        contract_address_try_from_felt252(receiver_addr_value.value).unwrap()
    }

    fn add_root_to_history(ref self: ContractState, new_root: felt252) {
        let roots_len = self.roots_len.read();
        self.merkle_roots.write(roots_len, new_root);
        let new_roots_len = roots_len + 1;
        self.roots_len.write(new_roots_len);
        remove_old_root(ref self, new_roots_len);
    }


    // remove the root that is older than allowed
    fn remove_old_root(ref self: ContractState, current_len: felt252) {
        self.merkle_roots.write(current_len - MAX_ROOTS_DEPTH, 0);
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
