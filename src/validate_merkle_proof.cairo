use core::pedersen::pedersen;
use cairo_lib::data_structures::mmr::{mmr::{MMR, MMRImpl, MMRTrait}, peaks::Peaks, proof::Proof};

pub fn validate(
    secret: felt252,
    nullifier: felt252,
    nullifier_hash: felt252,
    commitment: felt252,
    root: felt252,
    index: usize,
    last_pos: usize,
    peaks: Array<felt252>,
    proof: Array<felt252>
) -> Result<bool, felt252> {
    assert(pedersen(0, nullifier) == nullifier_hash, 'Invalid nullifier');
    assert(pedersen(secret, nullifier) == commitment, 'Invalid commitment');

    let mmr = MMRImpl::new(root, last_pos);
    mmr.verify_proof(index, commitment, peaks.span(), proof.span())
}

#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use core::pedersen::pedersen;
    use cairo_lib::data_structures::mmr::{mmr::{MMR, MMRImpl}, peaks::Peaks, proof::Proof};
    use cairo_lib::hashing::poseidon::PoseidonHasher;
    use super::validate;

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

        assert(
            validate(
                secret,
                nullifier,
                nullifier_hash,
                commitment,
                mmr.root,
                index,
                last_pos,
                peaks,
                proof
            )
                .is_ok(),
            'Invalid proof'
        );
    }
}

