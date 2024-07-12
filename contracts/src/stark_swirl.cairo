#[starknet::contract(account)]
mod StarkSwirl {
    use core::{array::{Span, SpanTrait, SpanImpl}, hash::{HashStateTrait, HashStateExTrait}};
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address,
        contract_address_try_from_felt252, account::Call, get_tx_info, info::v2::TxInfo, VALIDATED,
        SyscallResultTrait, syscalls::call_contract_syscall
    };

    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use cairo_verifier::{
        StarkProofWithSerde, StarkProof, CairoVersion, StarkProofImpl,
        air::public_memory::AddrValue, air::public_input::{PublicInput, get_public_input_hash},
        air::layouts::recursive::constants::segments
    };
    use starkswirl_contracts::interfaces::{IStarkSwirl, IAccountContract};

    use cairo_lib::data_structures::mmr::mmr::{MMR, MMRImpl, MMRTrait, MMRDefault};
    use cairo_lib::data_structures::mmr::peaks::{Peaks, PeaksTrait};

    // Controlling how old the root of the tree can be
    const MAX_ROOTS_DEPTH: felt252 = 4;

    const SECURITY_BITS: felt252 = 50;

    // selector('withdraw')
    const WITHDRAW_SELECTOR: felt252 =
        0x015511cc3694f64379908437d6d64458dc76d02482052bfb8a5b33a72c054c77;

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
        public_input_hash: felt252
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        denominator: u256,
        public_input_hash: felt252
    ) {
        assert(!token_address.is_zero(), 'Address 0 not allowed');
        assert(!denominator.is_zero(), '0 amount not allowed');
        assert(!public_input_hash.is_zero(), 'Invalid program input hash');
        self.denominator.write(denominator);

        self.token_address.write(ERC20ABIDispatcher { contract_address: token_address });

        self.mmr.write(MMRDefault::default());

        self.public_input_hash.write(public_input_hash);
    }

    #[abi(embed_v0)]
    impl RelayerImpl of IAccountContract<ContractState> {
        fn __validate__(ref self: ContractState, mut calls: Array<Call>) -> felt252 {
            let this_contract_address = get_contract_address();
            let self_snapshot = @self;
            while let Option::Some(call) = calls
                .pop_front() {
                    assert(call.to == this_contract_address, 'Allow call only to self');
                    assert(call.selector == WITHDRAW_SELECTOR, 'Only withdraw function allowed');
                    let mut calldata_mut = call.calldata;
                    let root = *calldata_mut.pop_front().unwrap();
                    assert(find_root(self_snapshot, root) == true, 'Root not found');
                };

            VALIDATED
        }

        fn __execute__(ref self: ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            assert(starknet::get_caller_address().is_zero(), 'INVALID_CALLER');

            let tx_info = starknet::get_tx_info().unbox();
            assert(tx_info.version != 0, 'INVALID_TX_VERSION');

            let mut result = ArrayTrait::new();
            loop {
                match calls.pop_front() {
                    Option::Some(call) => {
                        let mut res = call_contract_syscall(
                            address: call.to,
                            entry_point_selector: call.selector,
                            calldata: call.calldata
                        )
                            .unwrap_syscall();
                        result.append(res);
                    },
                    Option::None => {
                        break; // Can't break result; because of 'variable was previously moved'
                    },
                };
            };
            result
        }
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
            root: felt252,
            nullifier_hash: felt252,
            proof: StarkProofWithSerde,
        ) {
            let caller_address = get_caller_address();
            let this_contract_address = get_contract_address();
            // if the call is from the same address this check is already performed in the __validate__ function
            if caller_address != this_contract_address {
                assert(find_root(@self, root) == true, 'Root not found');
            }
            assert(self.nullifiers.read(nullifier_hash) == false, 'Nullifier already used');
            
            let stark_proof: StarkProof = proof.into();
            assert_correct_program(@self, @stark_proof.public_input);

            let receiver = get_receiver_from_proof(@stark_proof);
            verify_stark_proof(stark_proof);

            self.nullifiers.write(nullifier_hash, true);
            self.token_address.read().transfer(receiver, self.denominator.read());
            self.emit(Withdraw { nullifier_hash: nullifier_hash });
        }
    }

    // check if the proof was generated for the right cairo program
    fn assert_correct_program(self: @ContractState, public_input: @PublicInput) -> bool {
        let public_input_hash = self.public_input_hash.read();
        get_public_input_hash(public_input) == public_input_hash
    }

    fn verify_stark_proof(proof: StarkProof) {
        proof.verify(SECURITY_BITS);
    }

    // TODO: Check 
    fn get_receiver_from_proof(proof: @StarkProof) -> ContractAddress {
        let begin_addr: felt252 = *proof.public_input.segments.at(segments::OUTPUT).begin_addr;
        let receiver_addr_value: AddrValue = *proof
            .public_input
            .main_page
            .at((begin_addr + 2).try_into().unwrap());

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
