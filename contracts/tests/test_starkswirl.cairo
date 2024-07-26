use core::serde::Serde;

use starknet::{ContractAddress, contract_address_try_from_felt252};

use snforge_std::{declare, ContractClassTrait};

use starkswirl_contracts::interfaces::IStarkSwirlSafeDispatcher;
use starkswirl_contracts::interfaces::IStarkSwirlSafeDispatcherTrait;
use starkswirl_contracts::interfaces::IStarkSwirlDispatcher;
use starkswirl_contracts::interfaces::IStarkSwirlDispatcherTrait;


#[derive(Serde, Drop)]
struct ERC20ConstructorArgs {
    name: ByteArray,
    symbol: ByteArray,
    initial_supply: u256,
    recipient: ContractAddress
}

#[derive(Serde, Drop)]
struct StarkSwirlConstructorArgs {
    token_address: ContractAddress,
    denominator: u256,
    public_input_hash: felt252
}

fn deploy_erc20(constructor_args: ERC20ConstructorArgs) -> ContractAddress {
    let erc20contract_class = declare("TestERC20").unwrap();

    let mut args = array![];
    constructor_args.name.serialize(ref args);
    constructor_args.symbol.serialize(ref args);
    constructor_args.initial_supply.serialize(ref args);
    constructor_args.recipient.serialize(ref args);

    let (contract_address, _constructor_return) = erc20contract_class
        .deploy(@args)
        .unwrap();

    contract_address
}

fn deploy_stark_swirl(constructor_args: StarkSwirlConstructorArgs) -> ContractAddress {
    let mut args = array![];
    constructor_args.token_address.serialize(ref args);
    constructor_args.denominator.serialize(ref args);
    constructor_args.public_input_hash.serialize(ref args);

    let contract = declare("StarkSwirl").unwrap();
    let (deployed_address, _constructor_return) = contract.deploy(@args).unwrap();

    deployed_address
}


#[test]
fn test_deploy() {
    let token_address: ContractAddress = deploy_erc20(
        ERC20ConstructorArgs {
            name: "Ethereum",
            symbol: "ETH",
            initial_supply: 10000,
            recipient: contract_address_try_from_felt252(1).unwrap()
        }
    );

    let contract_address = deploy_stark_swirl(
        StarkSwirlConstructorArgs {
            token_address: token_address, denominator: 10, public_input_hash: 1
        }
    );
// let dispatcher = IStarkSwirlSafeDispatcher { contract_address };

}
