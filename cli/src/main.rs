use clap::Parser;

#[derive(Parser, Debug)]
struct WithdrawParameters {
    // Secret value that is part of the commitment
    #[arg(short, long)]
    secret: String,

    // Nullifier value that is part of the commitment
    #[arg(short, long)]
    nullifier: String,

    // Address that will receive the withdrawal
    #[arg(short, long)]
    receiver: String,

    network: Network
}

#[derive(clap::ValueEnum, Clone, Default, Debug)]
enum Network {
    // Sepolia test network
    #[default]
    Testnet,

    // Mainnet network
    Mainnet,
}

#[tokio::main]
async fn main() {
    let args = WithdrawParameters::parse();

}
