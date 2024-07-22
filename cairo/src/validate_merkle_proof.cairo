use core::pedersen::pedersen;
use core::serde::{Serde};
use cairo_lib::data_structures::mmr::{mmr::{MMR, MMRImpl, MMRTrait}};

#[derive(Serde, Copy, Drop)]
pub struct Input {
    secret: felt252,
    nullifier: felt252,
    nullifier_hash: felt252,
    commitment: felt252,
    pub receiver: felt252,
    root: felt252,
    index: usize,
    last_pos: usize,
    peaks: Span<felt252>,
    proof: Span<felt252>
}

pub fn validate(input: Input) -> Result<bool, felt252> {
    assert(pedersen(0, input.nullifier) == input.nullifier_hash, 'Invalid nullifier');
    assert(pedersen(input.secret, input.nullifier) == input.commitment, 'Invalid commitment');

    let mmr = MMRImpl::new(input.root, input.last_pos);
    mmr.verify_proof(input.index, input.commitment, input.peaks, input.proof)
}

#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use core::pedersen::pedersen;
    use cairo_lib::data_structures::mmr::{mmr::{MMR, MMRImpl}, peaks::Peaks, proof::Proof};
    use cairo_lib::hashing::poseidon::PoseidonHasher;
    use super::{validate, Input};

    #[test]
    fn test_validate_proof() {
        let secret: felt252 = 10;
        let nullifier: felt252 = 11;
        let commitment = pedersen(secret, nullifier);
        let nullifier_hash = pedersen(0, nullifier);

        let elem1 = PoseidonHasher::hash_double(1, 1);
        let elem2 = commitment;
        let elem3 = PoseidonHasher::hash_double(elem1, elem2);
        let elem4 = PoseidonHasher::hash_double(4, 4);
        let elem5 = PoseidonHasher::hash_double(5, 5);
        let elem6 = PoseidonHasher::hash_double(elem4, elem5);
        let elem7 = PoseidonHasher::hash_double(elem3, elem6);
        let elem8 = PoseidonHasher::hash_double(8, 8);

        println!("elem1 {}", elem1);
        println!("elem2 {}", elem2);
        println!("elem3 {}", elem3);
        println!("elem4 {}", elem4);
        println!("elem5 {}", elem5);
        println!("elem6 {}", elem6);
        println!("elem7 {}", elem7);
        println!("elem8 {}", elem8);

        let last_pos = 8;

        let mmr = MMRImpl::new(
            root: PoseidonHasher::hash_double(8, PoseidonHasher::hash_double(elem7, elem8)),
            last_pos: last_pos
        );

        let proof = array![elem2, elem6];
        let peaks = array![elem7, elem8];
        let index = 1;

        println!("index {}", index);

        let input = Input {
            secret: secret,
            nullifier: nullifier,
            nullifier_hash: nullifier_hash,
            commitment: commitment,
            receiver: 0,
            root: mmr.root,
            index: index,
            last_pos: last_pos,
            peaks: peaks.span(),
            proof: proof.span()
        };

        validate(input).expect('Invalid proof');
    }
}

