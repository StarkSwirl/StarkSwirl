use starknet::{ContractAddress, account::Call};
use cairo_verifier::{StarkProofWithSerde, StarkProofImpl};
use cairo_lib::data_structures::mmr::peaks::Peaks;

#[starknet::interface]
pub trait IStarkSwirl<TContractState> {
    fn deposit(ref self: TContractState, commitment: felt252, peaks: Peaks);
    fn withdraw(ref self: TContractState, proof: StarkProofWithSerde);
    fn token_address(self: @TContractState) -> ContractAddress;
    fn denominator(self: @TContractState) -> u256;
}

#[starknet::interface]
pub trait IAccountContract<TContractState> {
    fn __validate__(ref self: TContractState, calls: Array<Call>) -> felt252;
    fn __execute__(ref self: TContractState, calls: Array<Call>) -> Array<Span<felt252>>;
}

