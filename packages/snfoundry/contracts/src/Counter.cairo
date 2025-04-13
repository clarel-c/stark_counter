#[starknet::interface]
trait ICounter<TContractState> { // Traits are public by default: no need to use pub
    fn get_counter(self: @TContractState) -> u32; // Takes a snapshot of the state (not a reference)
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
}

#[starknet::contract]
mod Counter {
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use super::ICounter;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);


    #[storage]
    pub struct Storage {
        counter: u32,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, init_value: u32, owner: ContractAddress) {
        self.counter.write(init_value);
        // Set the initial owner of the contract
        self.ownable.initializer(owner);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Increased: Increased,
        Decreased: Decreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    pub mod Error {
        pub const EMPTY_COUNTER: felt252 = 'Decreasing Empty counter';
    }

    #[derive(Drop, starknet::Event)]
    pub struct Increased {
        account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Decreased {
        account: ContractAddress,
    }

    #[abi(embed_v0)]
    // We will not use any of the following two, and just the third, to avoid duplicates on the front end.
    //impl OwnableTwoStepMixinImpl = OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;
    //impl OwnableTwoStepCamelOnlyImpl = OwnableComponent::OwnableTwoStepCamelOnlyImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            self.counter.write(old_value + 1);

            // Emit an event for the increase.
            self.emit(Increased { account: get_caller_address() })
        }

        fn decrease_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            assert(old_value > 0, Error::EMPTY_COUNTER);
            self.counter.write(old_value - 1);
            self.emit(Decreased { account: get_caller_address() })
        }

        fn reset_counter(ref self: ContractState) {
            // Only the owner can reset the get_counter
            self.ownable.assert_only_owner();

            self.counter.write(0);
        }
    }
}
