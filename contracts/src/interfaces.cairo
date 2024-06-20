use starknet::ContractAddress;

#[starknet::interface]
pub trait IStarkSwirl<TContractState> {
    
    fn deposit(ref self: TContractState, commitment: felt252);
    fn withdraw(ref self: TContractState, proof: felt252, root: felt252, recipient: ContractAddress, nullifier_hash: felt252);

    fn leaves(self: @TContractState);
}
