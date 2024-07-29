use core::result::ResultTrait;
use core::serde::Serde;

pub mod validate_merkle_proof;
use validate_merkle_proof::{validate, ValidateResult};


fn main(input: Array<felt252>) -> Array<felt252> {
    let validate_res = validate(input.span()).unwrap();
    return array![validate_res.receiver, validate_res.nullifier_hash, validate_res.root];
}

