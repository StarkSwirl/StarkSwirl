use starknet::ContractAddress;
use cairo_verifier::{StarkProof, StarkProofImpl};

#[starknet::interface]
pub trait IStarkSwirl<TContractState> {
    fn deposit(ref self: TContractState, commitment: felt252);
    fn withdraw(ref self: TContractState, proof: StarkProof, root: felt252, recipient: ContractAddress, nullifier_hash: felt252);
    fn token_address(self: @TContractState) -> ContractAddress;
    fn denominator(self: @TContractState) -> u256;
}
