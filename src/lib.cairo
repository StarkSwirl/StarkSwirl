use core::result::ResultTrait;

mod validate_merkle_proof;
use validate_merkle_proof::validate;

fn main(
    secret: felt252,
    nullifier: felt252,
    nullifier_hash: felt252,
    commitment: felt252,
    root: felt252,
    index: usize,
    last_pos: usize,
    peaks: Array<felt252>,
    proof: Array<felt252>
) {
    let result = validate(
        secret, nullifier, nullifier_hash, commitment, root, index, last_pos, peaks, proof
    );
    assert(result.is_ok(), 'Invalid proof');
}

