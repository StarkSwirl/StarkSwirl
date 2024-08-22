#[starknet::contract(account)]
mod StarkSwirl {
    use core::{
        array::{Span, SpanTrait, SpanImpl}, hash::{HashStateTrait, HashStateExTrait},
        option::OptionTrait, num::traits::Zero
    };

    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, account::Call, get_tx_info,
        TxInfo, VALIDATED, SyscallResultTrait, syscalls::call_contract_syscall,
        storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry}
    };

    use openzeppelin::{
        token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait},
        access::ownable::OwnableComponent
    };

    use cairo_verifier::{
        PublicInputImpl, StarkProofWithSerde, StarkProof, CairoVersion, StarkProofImpl,
        air::public_memory::AddrValue,
        air::public_input::{PublicInput, PublicInputTrait, get_public_input_hash},
        air::layouts::recursive::constants::segments
    };

    use cairo_lib::data_structures::mmr::{
        mmr::{MMR, MMRImpl, MMRTrait, MMRDefault}, peaks::{Peaks, PeaksTrait}
    };

    use contracts::interfaces::{IStarkSwirl, IAccountContract};
    use cli::validate_merkle_proof::ValidateResult;

    // Controlling how old the root of the tree can be
    const MAX_ROOTS_DEPTH: felt252 = 4;

    const SECURITY_BITS: felt252 = 50;

    // selector('withdraw')
    const WITHDRAW_SELECTOR: felt252 =
        0x015511cc3694f64379908437d6d64458dc76d02482052bfb8a5b33a72c054c77;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
        OwnableEvent: OwnableComponent::Event,
        FeesChanged: FeesChanged,
        FeesCollected: FeesCollected,
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

    #[derive(Drop, starknet::Event)]
    struct FeesChanged {
        #[key]
        new_fees: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct FeesCollected {
        #[key]
        collected_fees: u256,
    }

    #[storage]
    struct Storage {
        denominator: u256, // Amount of tokens that can be deposited
        nullifiers: Map<felt252, bool>, // Deposits that are already withdrawn
        token_address: ERC20ABIDispatcher, // address of the token in this instance
        merkle_roots: Map<felt252, felt252>, // history of the merkle roots
        roots_len: felt252, // length of the merkle roots
        commitments: Map<felt252, bool>, // leavs in the tree
        mmr: MMR,
        public_input_hash: felt252,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        fee_amount: u256,
        uncollected_fees: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        denominator: u256,
        public_input_hash: felt252,
        fee_percent: u256, // multiplied by 10
        owner: Option<ContractAddress>
    ) {
        assert(!token_address.is_zero(), 'Address 0 not allowed');
        assert(!denominator.is_zero(), '0 amount not allowed');
        assert(!public_input_hash.is_zero(), 'Invalid program input hash');

        self.denominator.write(denominator);
        self.token_address.write(ERC20ABIDispatcher { contract_address: token_address });
        self.mmr.write(MMRDefault::default());
        self.public_input_hash.write(public_input_hash);

        match owner {
            Option::Some(addr) => self.ownable.initializer(addr),
            Option::None => {
                let addr = get_caller_address();
                self.ownable.initializer(addr);
            }
        }

        self.set_fees(fee_percent);
    }

    #[abi(embed_v0)]
    impl RelayerImpl of IAccountContract<ContractState> {
        fn __validate__(ref self: ContractState, mut calls: Array<Call>) -> felt252 {
            let this_contract_address = get_contract_address();
            while let Option::Some(call) = calls.pop_front() {
                assert(call.to == this_contract_address, 'Allow call only to self');
                assert(call.selector == WITHDRAW_SELECTOR, 'Only withdraw function allowed');
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

        fn current_fees(self: @ContractState) -> u256 {
            self.fee_amount.read()
        }

        fn deposit(ref self: ContractState, commitment: felt252, peaks: Peaks) {
            assert(!self.commitments.entry(commitment).read(), 'Commitment already added');

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
                Result::Err => { panic!("Deposit fail"); }
            };

            self.commitments.entry(commitment).write(true);
        }

        fn withdraw(ref self: ContractState, proof: StarkProofWithSerde,) {
            let caller_address = get_caller_address();
            let this_contract_address = get_contract_address();

            let stark_proof: StarkProof = proof.into();
            let validate_output: ValidateResult = get_program_output(@stark_proof);

            // if the call is from the same address this check is already performed in the
            // __validate__ function
            if caller_address != this_contract_address {
                assert(find_root(@self, validate_output.root) == true, 'Root not found');
            }
            assert(
                self.nullifiers.entry(validate_output.nullifier_hash).read() == false,
                'Nullifier already used'
            );

            assert_correct_program(@self, @stark_proof.public_input);

            verify_stark_proof(stark_proof);

            let receiver: ContractAddress = validate_output
                .receiver
                .try_into()
                .expect('Invalid receiver address');

            self.nullifiers.entry(validate_output.nullifier_hash).write(true);
            self
                .token_address
                .read()
                .transfer(receiver, self.denominator.read() - self.fee_amount.read());
            add_uncollected_fee(ref self);
            self.emit(Withdraw { nullifier_hash: validate_output.nullifier_hash });
        }


        // percent is multiplied by 10
        fn set_fees(ref self: ContractState, fee_percent: u256) {
            self.ownable.assert_only_owner();
            let denominator = self.denominator.read();
            let new_fees = (fee_percent * denominator) / 1000;
            self.fee_amount.write(new_fees);

            self.emit(FeesChanged { new_fees });
        }

        fn collect_fees(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let uncollected_fees = self.uncollected_fees.read();
            self.token_address.read().transfer(self.ownable.owner(), uncollected_fees);
            self.uncollected_fees.write(0);

            self.emit(FeesCollected { collected_fees: uncollected_fees });
        }
    }

    fn add_uncollected_fee(ref self: ContractState) {
        let current_fee = self.fee_amount.read();
        let current_uncollected_fees = self.uncollected_fees.read();

        self.uncollected_fees.write(current_uncollected_fees + current_fee);
    }


    // check if the proof was generated for the right cairo program
    fn assert_correct_program(self: @ContractState, public_input: @PublicInput) -> bool {
        let public_input_hash = self.public_input_hash.read();

        let (_program_hash, _output_hash) = public_input.verify_cairo1();
        get_public_input_hash(public_input) == public_input_hash
    }

    fn verify_stark_proof(proof: StarkProof) {
        proof.verify(SECURITY_BITS);
    }

    // TODO: Check
    fn get_program_output(proof: @StarkProof) -> ValidateResult {
        let begin_addr: felt252 = *proof.public_input.segments.at(segments::OUTPUT).begin_addr;
        let main_page = proof.public_input.main_page;

        let output_size = *main_page.at((begin_addr + 1).try_into().unwrap());
        assert(output_size.value == 3, 'Invalid output size');

        let receiver: felt252 = *main_page.at((begin_addr + 2).try_into().unwrap()).value;
        let nullifier_hash: felt252 = *main_page.at((begin_addr + 3).try_into().unwrap()).value;
        let root: felt252 = *main_page.at((begin_addr + 4).try_into().unwrap()).value;

        ValidateResult { receiver, nullifier_hash, root }
    }

    fn add_root_to_history(ref self: ContractState, new_root: felt252) {
        let roots_len = self.roots_len.read();
        self.merkle_roots.entry(roots_len).write(new_root);
        let new_roots_len = roots_len + 1;
        self.roots_len.write(new_roots_len);
        remove_old_root(ref self, new_roots_len);
    }

    // remove the root that is older than allowed
    fn remove_old_root(ref self: ContractState, current_len: felt252) {
        self.merkle_roots.entry(current_len - MAX_ROOTS_DEPTH).write(0);
    }

    fn find_root(self: @ContractState, root: felt252) -> bool {
        let mut current_index = self.roots_len.read();

        let mut root_found: bool = false;

        loop {
            if current_index == 0 {
                break;
            }

            let current_root = self.merkle_roots.entry(current_index - 1).read();

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
