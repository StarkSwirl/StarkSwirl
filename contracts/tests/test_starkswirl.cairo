use core::{serde::Serde, pedersen::pedersen};

use starknet::{
    ContractAddress, get_contract_address, contract_address_try_from_felt252,
    contract_address_to_felt252
};

use cairo_lib::{
    data_structures::mmr::peaks::{Peaks, PeaksTrait}, hashing::poseidon::PoseidonHasher
};

use openzeppelin::{
    token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait},
    access::ownable::interface::{OwnableABIDispatcher, OwnableABIDispatcherTrait}
};
use snforge_std::{declare, ContractClassTrait, spy_events, EventSpyAssertionsTrait};

use contracts::interfaces::{IStarkSwirlDispatcherTrait, IStarkSwirlDispatcher};
use contracts::stark_swirl::StarkSwirl;

fn deploy_erc20(
    name: ByteArray, symbol: ByteArray, initial_supply: u256, recipient: ContractAddress
) -> ContractAddress {
    let erc20contract_class = declare("TestERC20").unwrap();

    let mut args = ArrayTrait::new();
    name.serialize(ref args);
    symbol.serialize(ref args);
    initial_supply.serialize(ref args);
    recipient.serialize(ref args);

    let (contract_address, _constructor_return) = erc20contract_class.deploy(@args).unwrap();

    contract_address
}

fn deploy_stark_swirl(
    token_address: ContractAddress,
    denominator: u256,
    public_input_hash: felt252,
    fee_percent: u256,
    owner: Option<ContractAddress>
) -> ContractAddress {
    let mut args = array![];
    token_address.serialize(ref args);
    denominator.serialize(ref args);
    public_input_hash.serialize(ref args);
    fee_percent.serialize(ref args);
    owner.serialize(ref args);

    let contract = declare("StarkSwirl").unwrap();
    let (deployed_address, _constructor_return) = contract.deploy(@args).unwrap();

    deployed_address
}


#[test]
fn test_deploy() {
    let initial_supply = 10000;
    let token_address: ContractAddress = deploy_erc20(
        "Ethereum", "ETH", initial_supply, get_contract_address()
    );

    let mut spy = spy_events();

    let starkswirl_address = deploy_stark_swirl(token_address, 1000, 1, 5, Option::None);

    spy
        .assert_emitted(
            @array![
                (
                    starkswirl_address,
                    StarkSwirl::Event::FeesChanged(StarkSwirl::FeesChanged { new_fees: 5 })
                )
            ]
        );

    let owner = OwnableABIDispatcher { contract_address: starkswirl_address }.owner();
    assert_eq!(owner, get_contract_address());

    let current_fees = IStarkSwirlDispatcher { contract_address: starkswirl_address }
        .current_fees();
    assert_eq!(current_fees, 5_u256);
    println!("{}", contract_address_to_felt252(owner));
}

#[test]
fn test_deposit() {
    let initial_supply = 10000;
    let token_address: ContractAddress = deploy_erc20(
        "Ethereum", "ETH", initial_supply, get_contract_address()
    );

    let starkswirl_address = deploy_stark_swirl(token_address, 1000, 1, 5, Option::None);
    ERC20ABIDispatcher { contract_address: token_address }
        .approve(starkswirl_address, initial_supply);

    let secret = 9;
    let nullifier = 10;
    let commitment = pedersen(secret, nullifier);

    let mut spy = spy_events();
    IStarkSwirlDispatcher { contract_address: starkswirl_address }
        .deposit(commitment, array![].span());

    spy
        .assert_emitted(
            @array![
                (
                    starkswirl_address,
                    StarkSwirl::Event::Deposit(
                        StarkSwirl::Deposit {
                            commitment: commitment,
                            new_index: 2,
                            new_root: PoseidonHasher::hash_double(1, commitment),
                            peaks_len: 1,
                            peaks: array![commitment].span(),
                        }
                    )
                )
            ]
        );
}
