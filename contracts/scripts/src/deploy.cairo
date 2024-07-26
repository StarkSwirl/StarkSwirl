use core::result::ResultTrait;
use core::serde::Serde;

use starknet::{ContractAddress, ClassHash};

use sncast_std::{
    call, declare, deploy, CallResult, DeclareResult, DeployResult, FeeSettings, StrkFeeSettings,
    ScriptCommandError, ErrorData
};

use super::get_input_hash::get_public_input_hash;

#[derive(Serde, Drop)]
struct StarkSwirlConstructorArgs {
    token_address: ContractAddress,
    denominator: u256,
    public_input_hash: felt252
}

fn main() {
    let public_input_hash = get_public_input_hash().expect('Please generate a valid proof');

    let constructor_args = StarkSwirlConstructorArgs {
        token_address: 1.try_into().unwrap(), denominator: 100, public_input_hash: public_input_hash
    };

    let fee_settings = StrkFeeSettings {
        max_fee: Option::None, max_gas: Option::None, max_gas_unit_price: Option::None,
    };

    match declare("StarkSwirl", FeeSettings::Strk(fee_settings.clone()), Option::None) {
        Result::Ok(res) => {
            println!("Contract declared successfully. {}", res);

            let mut args = array![];
            constructor_args.token_address.serialize(ref args);
            constructor_args.denominator.serialize(ref args);
            constructor_args.public_input_hash.serialize(ref args);

            match deploy(
                res.class_hash,
                args,
                Option::None,
                true,
                FeeSettings::Strk(fee_settings.clone()),
                Option::None
            ) {
                Result::Ok(res) => { println!("Contract deployed successfully. {}", res); },
                Result::Err(_) => { println!("Deploy failed"); }
            }
        },
        Result::Err(_) => { println!("Declare failed"); }
    };
}
