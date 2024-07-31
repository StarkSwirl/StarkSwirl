use core::pedersen::pedersen;
use core::serde::{Serde};
use cairo_lib::data_structures::mmr::{mmr::{MMR, MMRImpl, MMRTrait}};

#[derive(Serde, Copy, Drop)]
struct Input {
    secret: felt252,
    nullifier: felt252,
    receiver: felt252,
    root: felt252,
    index: usize,
    last_pos: usize,
    peaks: Span<felt252>,
    proof: Span<felt252>
}

#[derive(Copy, Drop)]
pub struct ValidateResult {
    pub receiver: felt252,
    pub nullifier_hash: felt252,
    pub root: felt252
}

pub fn validate(mut input_span: Span<felt252>) -> Result<ValidateResult, felt252> {
    let input: Input = Serde::deserialize(ref input_span).expect('Fail to deserialize');

    let commitment = pedersen(input.secret, input.nullifier);

    let mmr = MMRImpl::new(input.root, input.last_pos);
    mmr.verify_proof(input.index, commitment, input.peaks, input.proof).unwrap();

    let nullifier_hash = pedersen(0, input.nullifier);
    Result::Ok(
        ValidateResult {
            receiver: input.receiver, nullifier_hash: nullifier_hash, root: input.root
        }
    )
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

        let elem1 = PoseidonHasher::hash_double(1, 1);
        let elem2 = PoseidonHasher::hash_double(2, 2);
        let elem3 = PoseidonHasher::hash_double(elem1, elem2);
        let elem4 = PoseidonHasher::hash_double(4, 4);
        let elem5 = PoseidonHasher::hash_double(6, 5);
        let elem6 = PoseidonHasher::hash_double(elem4, elem5);
        let elem7 = PoseidonHasher::hash_double(elem3, elem6);
        let elem8 = PoseidonHasher::hash_double(8, 8);

        let last_pos: usize = 8;

        let mmr = MMRImpl::new(
            root: PoseidonHasher::hash_double(8, PoseidonHasher::hash_double(elem7, elem8)),
            last_pos: last_pos
        );

        let proof = array![elem2, elem6];
        let peaks = array![elem7, elem8];
        let index: usize = 1;
        let receiver: felt252 = 0;

        println!("index {}", index);

        let mut serialized = array![];

        secret.serialize(ref serialized);
        nullifier.serialize(ref serialized);
        receiver.serialize(ref serialized);
        mmr.root.serialize(ref serialized);
        index.serialize(ref serialized);
        last_pos.serialize(ref serialized);
        peaks.span().serialize(ref serialized);
        proof.span().serialize(ref serialized);

        assert(validate(serialized.span()).is_ok(), 'Invalid proof');
    }
}

