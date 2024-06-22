use core::pedersen::pedersen;

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
    assert(pedersen(0, nullifier) == nullifier_hash, 'Invalid nullifier');
    assert(pedersen(secret, nullifier) == commitment, 'Invalid commitment');
    let mut merkle_tree: MerkleTree<Hasher> = MerkleTreeTrait::new();

    assert(merkle_tree.verify(root, commitment, merkle_proof.span()) == true, 'Invalid proof');
}

