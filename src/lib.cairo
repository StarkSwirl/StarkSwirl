use core::result::ResultTrait;
use core::pedersen::pedersen;
use cairo_lib::data_structures::mmr::{
    mmr::{MMR, MMRImpl, MMRTrait}, peaks::{Peaks, PeaksTrait}, proof::{Proof, ProofTrait}
};
use cairo_lib::hashing::poseidon::PoseidonHasher;

fn main(
    secret: felt252,
    nullifier: felt252,
    nullifier_hash: felt252,
    commitment: felt252,
    root: felt252,
    index: usize,
    last_pos: usize,
    peaks: Peaks,
    proof: Proof
) {
    validate_proof(secret, nullifier, nullifier_hash, commitment, root, index, last_pos, peaks, proof);
}

fn validate_proof(
    secret: felt252,
    nullifier: felt252,
    nullifier_hash: felt252,
    commitment: felt252,
    root: felt252,
    index: usize,
    last_pos: usize,
    peaks: Peaks,
    proof: Proof
) {
    assert(pedersen(0, nullifier) == nullifier_hash, 'Invalid nullifier');
    assert(pedersen(secret, nullifier) == commitment, 'Invalid commitment');

    let mut mmr = MMRImpl::new(root, last_pos);
    let result = mmr.verify_proof(index, commitment, peaks, proof);
    assert(result.is_ok(), 'Invalid proof');
}


#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use core::pedersen::pedersen;
    use cairo_lib::data_structures::mmr::{
        mmr::{MMR, MMRImpl, MMRTrait}, peaks::{Peaks, PeaksTrait}, proof::{Proof, ProofTrait}
    };
    use cairo_lib::hashing::poseidon::PoseidonHasher;
    use super::validate_proof;

    #[test]
    fn test_validate_proof() {
        let secret: felt252 = 10;
        let nullifier: felt252 = 11;
        let commitment = pedersen(secret, nullifier);
        let nullifier_hash = pedersen(0, nullifier);

        let elem1 = PoseidonHasher::hash_single(1);
        let elem2 = commitment;
        let elem3 = PoseidonHasher::hash_double(elem1, elem2);
        let elem4 = PoseidonHasher::hash_single(4);
        let elem5 = PoseidonHasher::hash_single(5);
        let elem6 = PoseidonHasher::hash_double(elem4, elem5);
        let elem7 = PoseidonHasher::hash_double(elem3, elem6);
        let elem8 = PoseidonHasher::hash_single(8);

        let mmr = MMRTrait::new(
            root: PoseidonHasher::hash_double(8, PoseidonHasher::hash_double(elem7, elem8)),
            last_pos: 8
        );

        let proof = array![elem2, elem6].span();
        let peaks = array![elem7, elem8].span();
        let index = 1;

        validate_proof(
            secret, nullifier, nullifier_hash, commitment, mmr.root, index, 8, peaks, proof
        );
    }
}
