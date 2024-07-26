use starknet::core::types::{BlockId, BlockTag, ContractClass, EventFilter, Felt};
use starknet::providers::jsonrpc::HttpTransport;
use starknet::providers::{JsonRpcClient, Provider, Url};

use clap::Parser;
use starknet::core::types::BlockId::Tag;
use starknet::core::utils::get_selector_from_name;
// use cairo_vm::cairo_run;

const SEPOLIA_CONTRACT_ADDRESS: &str =
    "0x0075476f93830558f37a403d632f95d76a0a5350a3b35a7199c858a43960f211";

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

    network: Network,
}

#[derive(clap::ValueEnum, Clone, Default, Debug)]
// Network where the events should be fetched from
enum Network {
    // Sepolia test network
    #[default]
    Testnet,

    // Mainnet network
    Mainnet,

    // Local network
    Local,
}

#[tokio::main]
async fn main() {
    // let args = WithdrawParameters::parse();

    let provider = JsonRpcClient::new(HttpTransport::new(
        Url::parse("http://localhost:9545").unwrap(),
    ));
    let event_selector = get_selector_from_name("Deposit").unwrap();

    let deposit_event_filter = EventFilter {
        from_block: Some(BlockId::Number(0)),
        to_block: None,
        address: Some(Felt::from_hex(SEPOLIA_CONTRACT_ADDRESS).unwrap()),
        keys: Some(vec![vec![event_selector]]),
    };

    match provider.get_events(deposit_event_filter, None, 1).await {
        Ok(events_page) => {
            for event in events_page.events {
                println!("{:?}", event);
            }
        }
        Err(err) => {
            eprintln!("Error fetching events: {:?}", err);
        }
    }
}
