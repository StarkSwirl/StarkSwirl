use core::result::ResultTrait;
use core::serde::Serde;

mod validate_merkle_proof;
use validate_merkle_proof::{validate, Input};


fn main(input: Array<felt252>) -> Array<felt252> {
    let mut span = input.span();

    let inputs_struct: Input = Serde::deserialize(ref span).expect('Fail to deserialize');
    validate(inputs_struct).expect('Invalid proof');

    return array![inputs_struct.receiver];
}

