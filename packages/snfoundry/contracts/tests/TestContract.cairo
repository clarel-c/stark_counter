// Import libraries
use contracts::Counter::{
    Counter, ICounterDispatcher, ICounterDispatcherTrait, ICounterSafeDispatcher,
    ICounterSafeDispatcherTrait,
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress};

fn owner() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn user() -> ContractAddress {
    'user'.try_into().unwrap()
}

// Deploy function
fn __deploy__(init_value: u32) -> (ICounterDispatcher, IOwnableDispatcher, ICounterSafeDispatcher) {
    // declare a contract class
    let contract_class = declare("Counter").expect('failed to declare class').contract_class();

    // Serialize the constructor
    let mut calldata: Array<felt252> = array![];
    init_value.serialize(ref calldata);
    owner().serialize(ref calldata);

    // Deploy the contract
    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    // Get a Counter instance
    let counter = ICounterDispatcher { contract_address: contract_address };
    let ownable = IOwnableDispatcher { contract_address: contract_address };
    let safe_counter = ICounterSafeDispatcher { contract_address: contract_address };

    (counter, ownable, safe_counter)
}

// Test that the contract deploys successfully
#[test]
fn test_counter_deployment() {
    let (counter, ownable, _) = __deploy__(0);
    let counter_value = counter.get_counter();

    assert(counter_value == 0, 'Counter not set');
    assert(ownable.owner() == owner(), 'Owner not set');
}

// Test the increase_counter function
#[test]
fn test_increase_counter() {
    let init_value = 0;
    let (counter, _, _) = __deploy__(init_value);
    let initial_counter_value = counter.get_counter();

    assert(initial_counter_value == 0, 'Counter not set');

    // We now call increase_counter()
    counter.increase_counter();

    // Retrieve the updated counter_value
    let updated_counter_value = counter.get_counter();

    // Asserts that that initial_counter_value is increased by 1
    assert(updated_counter_value == initial_counter_value + 1, 'Counter has not increased');
}

fn test_normal_decrease_counter() {
    let init_value = 4;
    let (counter, _, _) = __deploy__(init_value);
    let initial_counter_value = counter.get_counter();

    assert(initial_counter_value == 4, 'Counter not well set');

    // We now call decrease_counter()
    counter.decrease_counter();

    // Retrieve the updated counter_value
    let updated_counter_value = counter.get_counter();

    // Asserts that that initial_counter_value is decreased by 1
    assert(updated_counter_value == initial_counter_value - 1, 'Counter has not decreased');
}

#[test]
fn test_emitted_increased_event() {
    let init_value = 0;
    let (counter, _, _) = __deploy__(init_value);

    // Get the spy event before calling the function
    let mut spy = spy_events();

    // Mimick a caller
    start_cheat_caller_address(counter.contract_address, user());

    // Call the increase_counter function
    counter.increase_counter();
    //Stop the cheat caller address
    stop_cheat_caller_address(counter.contract_address);

    // Checking if Increased event is emitted for user() account

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: user() }),
                ),
            ],
        );

    // Just a side check to show that we can show an assert_not_emitted
    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: user() }),
                ),
            ],
        );
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_decrease_counter() {
    // Deploy the Counter contract and initialize the counter value to zero
    let (counter, _, safe_counter) = __deploy__(0);

    assert(counter.get_counter() == 0, 'Invalid initial value');

    match safe_counter.decrease_counter() {
        Result::Ok(_) => panic!("Cannot decrease the counter below zero"),
        Result::Err(error) => assert(*error[0] == 'Decreasing Empty counter', *error.at(0)),
    }
}

#[test]
#[should_panic(expected: 'Decreasing Empty counter')]
fn test_panic_decrease_counter() {
    // Deploy the Counter contract and initialize the counter value to zero
    let (counter, _, _) = __deploy__(0);

    assert(counter.get_counter() == 0, 'Invalid initial value');
    counter.decrease_counter();
}

#[test]
fn test_reset_counter() {
    let init_value = 5;
    let (counter, _, _) = __deploy__(init_value);

    assert(counter.get_counter() == 5, 'Invalid initial value');

    // Mimick a caller
    start_cheat_caller_address(counter.contract_address, owner());

    // Call the reset_counter function
    counter.reset_counter();
    //Stop the cheat caller address
    stop_cheat_caller_address(counter.contract_address);
    assert(counter.get_counter() == 0, 'Counter was not reset');
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_reset_counter_by_non_owner() {
    // Deploy the Counter contract and initialize the counter value to 10
    let (counter, _, safe_counter) = __deploy__(10);

    assert(counter.get_counter() == 10, 'Invalid initial value');

    // Mimick a non- owner
    start_cheat_caller_address(counter.contract_address, user());

    match safe_counter.reset_counter() {
        Result::Ok(_) => panic!("Only owner can reset the Counter"),
        Result::Err(error) => assert(*error[0] == 'Caller is not the owner', *error.at(0)),
    }

    //Stop the cheat caller address
    stop_cheat_caller_address(counter.contract_address);
}

