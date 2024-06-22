from starknet_py.hash.utils import pedersen_hash

zero_leaf = pedersen_hash(0, 0)
def fill_with_zeros(arr, desired_length):  
    zeros_needed = desired_length - len(arr)
    if zeros_needed > 0:
        arr.extend([zero_leaf] * zeros_needed)
    return arr


tree_size = 16

# known commitments, in order, from the on-chain events
secret, nullifier = 10, 11 # some hard to guess random numbers
known_commitments = pedersen_hash(secret, nullifier)
commitments = [known_commitments]


def create_merkle_tree(data_list):
    """Creates a Merkle tree and returns the root hash."""
    if not data_list:
        return None
    
    result = []
    result.append(data_list)
    
    current_level = data_list
    
    while len(current_level) > 1:
        next_level = []
        
        if len(current_level) % 2 != 0:
            current_level.append(current_level[-1])
        
        for i in range(0, len(current_level), 2):
            combined_hash = pedersen_hash(current_level[i], current_level[i + 1])
            next_level.append(combined_hash)

        result.append(next_level)
        current_level = next_level
    
    # The root hash is the only element left in the current_level
    return result

def generate_proof(merkle_tree, index):
    """Generates a Merkle proof for the leaf at the given index."""
    proof = []
    num_levels = len(merkle_tree)
    
    for level in range(num_levels - 1):
        current_level = merkle_tree[level]
        if index % 2 == 0:
            sibling_index = index + 1
        else:
            sibling_index = index - 1

        if sibling_index < len(current_level):
            proof.append(current_level[sibling_index])
        
        index //= 2  # Move to the next level

    return proof

merkle_tree = create_merkle_tree(fill_with_zeros(commitments, tree_size))

proof = generate_proof(merkle_tree, 0)

args = f'{secret} {nullifier} {pedersen_hash(0, nullifier)} {known_commitments} [' + ' '.join(str(x) for x in proof[:-1]) + f'] {proof[-1]}'
print(args)


