//! Binary entrypoint for `scuro-node`.

fn main() {
    reth_cli_util::sigsegv_handler::install();

    if std::env::var_os("RUST_BACKTRACE").is_none() {
        unsafe { std::env::set_var("RUST_BACKTRACE", "1") };
    }

    if let Err(err) = scuro_node::entrypoint() {
        eprintln!("Error: {err:?}");
        std::process::exit(1);
    }
}
