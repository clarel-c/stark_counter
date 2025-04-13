#[starknet::interface]
trait ICounter<TContractState> { // Traits are public by default: no need to use pub
    fn get_counter(self: @TContractState) -> u32; // Takes a snapshot of the state (not a reference)
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
}

#[starknet::contract]
mod Counter {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        counter: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, init_value: u32) {
        self.counter.write(init_value);
    }

    #[abi(embed_v0)]
    impl CounterImpl of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            self.counter.write(old_value + 1);
        }

        fn decrease_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            self.counter.write(old_value - 1);
        }

        fn reset_counter(ref self: ContractState) {
            self.counter.write(0);
        }
    }
}
