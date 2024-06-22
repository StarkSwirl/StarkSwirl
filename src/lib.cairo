use core::result::ResultTrait;
use core::pedersen::pedersen;
use cairo_lib::data_structures::mmr::mmr::{MMR, MMRImpl};
use cairo_lib::data_structures::mmr::peaks::{Peaks, PeaksTrait};
use cairo_lib::data_structures::mmr::proof::{Proof, ProofTrait};

fn main(
    secret: felt252,
    nullifier: felt252,
    nullifier_hash: felt252,
    commitment: felt252,
    root: felt252,
    index: usize,
    peaks: Peaks,
    proof: Proof
) {
    assert(pedersen(0, nullifier) == nullifier_hash, 'Invalid nullifier');
    assert(pedersen(secret, nullifier) == commitment, 'Invalid commitment');
    
    let mut mmr = MMRImpl::new(root, index);
    let result = mmr.verify_proof(index, commitment, peaks, proof);
    assert(result.is_ok(), 'Invalid proof');
}

