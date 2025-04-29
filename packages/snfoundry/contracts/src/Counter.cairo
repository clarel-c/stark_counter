#[starknet::interface]
pub trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32; // Takes a snapshot of the state (not a reference)
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
    fn get_win_number(self: @TContractState) -> u32;
}

#[starknet::contract]
pub mod Counter {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use super::ICounter;


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // STRK token address on StarkNet
    pub const FELT_STRK_CONTRACT: felt252 =
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;

    // Win number - when counter reaches this, caller gets all STRK
    pub const WIN_NUMBER: u32 = 5;


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
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Decreased {
        pub account: ContractAddress,
    }

    #[abi(embed_v0)]
    // We will not use any of the following two, and just the third, to avoid duplicates on the
    // front end.
    //impl OwnableTwoStepMixinImpl = OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;
    //impl OwnableTwoStepCamelOnlyImpl =
    //OwnableComponent::OwnableTwoStepCamelOnlyImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            let mut old_value = self.counter.read();
            if(old_value == WIN_NUMBER) {
                old_value = 0;
            }

            let new_value = old_value + 1;
            self.counter.write(new_value);

            // Emit an event for the increase.
            self.emit(Increased { account: get_caller_address() });

            // Check if counter reached the win number
            if new_value == WIN_NUMBER {
                let caller = get_caller_address();
                let strk_contract_address: ContractAddress = FELT_STRK_CONTRACT.try_into().unwrap();

                // Get STRK token dispatcher
                let strk_dispatcher = IERC20Dispatcher { contract_address: strk_contract_address };

                // Get contract's STRK balance
                let balance = strk_dispatcher.balance_of(get_contract_address());

                if balance > 0 {
                    // Transfer all STRK from contract to caller
                    strk_dispatcher.transfer(caller, balance);
                }
            }
        }

        fn decrease_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            assert(old_value > 0, Error::EMPTY_COUNTER);
            self.counter.write(old_value - 1);
            self.emit(Decreased { account: get_caller_address() })
        }

        fn reset_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.counter.write(0);
        }

        fn get_win_number(self: @ContractState) -> u32 {
            WIN_NUMBER //This is the number which stops the game
        }
    }
}
