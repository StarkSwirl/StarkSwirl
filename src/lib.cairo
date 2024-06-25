use core::result::ResultTrait;

mod validate_merkle_proof;
use validate_merkle_proof::{validate, Input};
use core::serde::{Serde};
use cairo_lib::data_structures::mmr::{peaks::Peaks, proof::Proof};

fn main(input: Array<felt252>) -> Array<felt252> {
    let mut span = input.span();

    let inputs_struct: Input = Serde::deserialize(ref span).expect('Fail to deserialize');

    validate(inputs_struct).expect('Invalid proof');

    return ArrayTrait::new();
}

