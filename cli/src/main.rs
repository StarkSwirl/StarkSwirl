extern crate alloc;
extern crate core;

use core::str::FromStr;
use clap::Parser;
use cairo1_run::{Felt252, FuncArg};

use starknet::core::types::{BlockId, EmittedEvent, EventFilter, Felt};
use starknet::providers::jsonrpc::HttpTransport;
use starknet::providers::{JsonRpcClient, Provider, Url};
use starknet::core::utils::get_selector_from_name;
mod run_cairo_program;
use run_cairo_program::run_program;


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
    let cli_args = WithdrawParameters::parse();

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

    let last_event: EmittedEvent = match provider.get_events(deposit_event_filter, None, 1).await {
        Ok(events_page) => events_page.events.first().unwrap().clone(),
        Err(err) => panic!("Error fetching events: {:?}", err)
    };

    let secret_felt = Felt252::from_str(&cli_args.secret).unwrap();
    let nullifier_felt = Felt252::from_str(&cli_args.nullifier).unwrap();

    let args: Vec<FuncArg> = vec![
        FuncArg::Single(secret_felt),
        FuncArg::Single(nullifier_felt),
        FuncArg::Single(Felt252::from_str(&cli_args.receiver).unwrap()),
    ];

    /*
    args.push(FuncArg::Single(Felt252::from_str(root).unwrap()));
    args.push(FuncArg::Single(Felt252::from_str(index).unwrap()));
    args.push(FuncArg::Single(Felt252::from_str(last_pos).unwrap()));
    args.push(FuncArg::Array(peaks.map(|p| Felt252::from_str(p).unwrap())));
    args.push(FuncArg::Array(proof.map(|p| Felt252::from_str(p).unwrap())));
     */

    run_program(&args);
}
