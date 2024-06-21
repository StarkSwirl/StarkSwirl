use core::poseidon::PoseidonTrait;
use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};

mod merkle_tree;
use merkle_tree::{
    Hasher, MerkleTree, MerkleTreeTrait, MerkleTreeImpl, pedersen::PedersenHasherImpl
};

fn main(
    secret: felt252,
    nullifier: felt252,
    nullifier_hash: felt252,
    commitment: felt252,
    merkle_proof: Array<felt252>,
    root: felt252
) {

    let new_nullifier_hash = PoseidonTrait::new().update_with(nullifier).finalize();
    assert(new_nullifier_hash == nullifier_hash, 'Invalid nullifier');
    let secret_hash = PoseidonTrait::new().update_with(secret).finalize();
    let new_commitment = PedersenTrait::new(new_nullifier_hash).update_with(secret_hash).finalize();
    assert(commitment == new_commitment, 'Invalid commitment');

    let mut merkle_tree: MerkleTree<Hasher> = MerkleTreeTrait::new();

    assert(merkle_tree.verify(root, commitment, merkle_proof.span()) == true, 'Invalid proof');
}

